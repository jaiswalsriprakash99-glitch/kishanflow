import 'package:flutter/material.dart';
import 'pacs_service.dart';

class PacsDispatchScreen extends StatefulWidget {
  const PacsDispatchScreen({super.key});

  @override
  State<PacsDispatchScreen> createState() => _PacsDispatchScreenState();
}

class _PacsDispatchScreenState extends State<PacsDispatchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  List<dynamic> _pendingCollections = [];
  List<dynamic> _dispatches = [];
  List<dynamic> _destinationCentres = [];

  int? _selectedCentreId;
  bool _isForwarding = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final pacs = PacsService();
    final pendingRes = await pacs.getPendingCollections();
    final dispatchRes = await pacs.getDispatches();
    final centresRes = await pacs.getDestinationCentres();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _pendingCollections = pendingRes;
        _dispatches = dispatchRes;
        _destinationCentres = centresRes;
        if (_destinationCentres.isNotEmpty && _selectedCentreId == null) {
          _selectedCentreId = _destinationCentres.first['id'];
        }
      });
    }
  }

  Future<void> _forwardRecord(int recordId) async {
    if (_selectedCentreId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select destination procurement centre first.')),
      );
      return;
    }

    setState(() {
      _isForwarding = true;
    });

    final res = await PacsService().forwardCollection(
      procurementRecordId: recordId,
      destinationCentreId: _selectedCentreId!,
    );

    if (mounted) {
      setState(() {
        _isForwarding = false;
      });

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Collection forwarded to procurement centre successfully!')),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Forwarding failed: ${res["message"]}')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'COLLECTED_AT_PACS':
        return Colors.blue;
      case 'FORWARDED_TO_CENTRE':
        return Colors.orange;
      case 'RECEIVED_AT_CENTRE':
        return Colors.purple;
      case 'ACCEPTED':
      case 'COMPLETED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PACS Forwarding & Dispatch'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.pending_actions), text: 'Pending Forwarding'),
            Tab(icon: Icon(Icons.local_shipping), text: 'Dispatch Tracking'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Pending Forwarding
                RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Destination Mandi Hub Assignment',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B5E20)),
                                ),
                                const SizedBox(height: 8),
                                if (_destinationCentres.isEmpty)
                                  const Text('No destination procurement centres found.', style: TextStyle(color: Colors.grey))
                                else
                                  DropdownButtonFormField<int>(
                                    initialValue: _selectedCentreId,
                                    decoration: const InputDecoration(
                                      labelText: 'Destination Procurement Centre',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.location_city),
                                    ),
                                    items: _destinationCentres.map((c) {
                                      return DropdownMenuItem<int>(
                                        value: c['id'] as int,
                                        child: Text('${c["name"]} (${c["district"]})'),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedCentreId = val);
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        const Text(
                          'PACS Collections Awaiting Dispatch',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),

                        if (_pendingCollections.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Center(
                              child: Text('No pending collections awaiting forwarding.'),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _pendingCollections.length,
                            itemBuilder: (context, index) {
                              final item = _pendingCollections[index] as Map<String, dynamic>;
                              final recordId = item['id'];
                              return Card(
                                key: Key('pendingCollectionCard_$recordId'),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFFFF3E0),
                                    child: Icon(Icons.inventory, color: Colors.orange),
                                  ),
                                  title: Text(
                                    '${item["farmer_name"]} (${item["crop_name"]})',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    'Qty: ${item["quantity_quintals"]} Qtl | Value: ₹${item["total_amount"]} | Status: ${item["status"]}',
                                  ),
                                  trailing: ElevatedButton.icon(
                                    key: Key('forwardBtn_$recordId'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1B5E20),
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.send, size: 16),
                                    label: const Text('Forward'),
                                    onPressed: _isForwarding ? null : () => _forwardRecord(recordId),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                // Tab 2: Dispatch Tracking
                RefreshIndicator(
                  onRefresh: _loadData,
                  child: _dispatches.isEmpty
                      ? const Center(child: Text('No dispatches recorded yet.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _dispatches.length,
                          itemBuilder: (context, index) {
                            final d = _dispatches[index] as Map<String, dynamic>;
                            final statusStr = d['status'] as String? ?? 'UNKNOWN';
                            final statusColor = _getStatusColor(statusStr);

                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: statusColor.withOpacity(0.15),
                                  child: Icon(Icons.local_shipping, color: statusColor),
                                ),
                                title: Text(
                                  'Record #${d["id"]} — ${d["farmer_name"]}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  'Crop: ${d["crop_name"]} | Destination: ${d["centre_name"] ?? "Mandi Hub"}',
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    border: Border.all(color: statusColor),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    statusStr,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
