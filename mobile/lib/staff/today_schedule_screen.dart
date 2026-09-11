import 'package:flutter/material.dart';
import 'staff_service.dart';
import 'procurement_workflow_screen.dart';

class TodayScheduleScreen extends StatefulWidget {
  const TodayScheduleScreen({super.key});

  @override
  State<TodayScheduleScreen> createState() => _TodayScheduleScreenState();
}

class _TodayScheduleScreenState extends State<TodayScheduleScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _schedule = [];
  List<dynamic> _filteredSchedule = [];

  String _selectedFilter = 'ALL';
  final _searchController = TextEditingController();

  final List<String> _filters = ['ALL', 'WAITING', 'ARRIVED', 'PROCESSING', 'COMPLETED', 'NO_SHOW'];

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final centreId = StaffService().centreId ?? 1;

    try {
      final items = await StaffService().getSchedule(
        centreId,
        statusFilter: _selectedFilter == 'ALL' ? null : _selectedFilter,
      );

      if (mounted) {
        setState(() {
          _schedule = items;
          _applySearch();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _applySearch() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredSchedule = List.from(_schedule);
    } else {
      _filteredSchedule = _schedule.where((item) {
        final name = (item['farmer_name'] ?? '').toString().toLowerCase();
        final token = (item['token_number'] ?? '').toString();
        final ref = (item['booking_reference'] ?? '').toString().toLowerCase();
        final crop = (item['crop_name'] ?? '').toString().toLowerCase();
        return name.contains(query) || token.contains(query) || ref.contains(query) || crop.contains(query);
      }).toList();
    }
  }

  Future<void> _markArrived(int bookingId) async {
    try {
      await StaffService().markArrived(bookingId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Farmer successfully marked ARRIVED!'),
            backgroundColor: Color(0xFF1B5E20),
          ),
        );
        _loadSchedule();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openWorkflowScreen(Map<String, dynamic> booking) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProcurementWorkflowScreen(
          bookingData: booking,
          onWorkflowCompleted: _loadSchedule,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ARRIVED':
      case 'WAITING':
        return Colors.amber.shade800;
      case 'PROCESSING':
      case 'IN_QUEUE':
      case 'VERIFICATION':
      case 'QUALITY_CHECK':
      case 'WEIGHING':
        return Colors.orange.shade700;
      case 'ACCEPTED':
      case 'COMPLETED':
      case 'PROCUREMENT_COMPLETED':
        return const Color(0xFF1B5E20);
      case 'QUALITY_REJECTED':
      case 'CANCELLED':
      case 'NO_SHOW':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Schedule"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSchedule,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    selectedColor: const Color(0xFF1B5E20),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                        _loadSchedule();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Search Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Farmer Name, Token #, or Ref...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _applySearch());
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
              onChanged: (val) => setState(() => _applySearch()),
            ),
          ),
          const Divider(),

          // Body Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20)))
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 12),
                              Text(_errorMessage!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadSchedule,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _filteredSchedule.isEmpty
                        ? const Center(
                            child: Text(
                              'No scheduled farmers found for this filter.',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadSchedule,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredSchedule.length,
                              itemBuilder: (context, idx) {
                                final item = Map<String, dynamic>.from(_filteredSchedule[idx]);
                                final bookingId = item['booking_id'];
                                final token = item['token_number'];
                                final farmerName = item['farmer_name'] ?? 'Farmer';
                                final crop = item['crop_name'] ?? 'Crop';
                                final qty = item['estimated_quantity_quintals'] ?? 0.0;
                                final slotTime = item['slot_time'] ?? '09:00-13:00';
                                final arrStatus = item['arrival_status'] ?? 'NOT_ARRIVED';
                                final procStatus = item['procurement_status'] ?? 'REGISTERED';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 18,
                                                    backgroundColor: const Color(0xFF1B5E20),
                                                    child: Text(
                                                      '#$token',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          farmerName,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                        Text(
                                                          'Ref: ${item['booking_reference']}',
                                                          overflow: TextOverflow.ellipsis,
                                                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(procStatus).withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: _getStatusColor(procStatus)),
                                              ),
                                              child: Text(
                                                procStatus,
                                                style: TextStyle(
                                                  color: _getStatusColor(procStatus),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Crop: $crop ($qty Qtl)', style: const TextStyle(fontSize: 13)),
                                            Text('Slot: $slotTime', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            if (arrStatus == 'NOT_ARRIVED') ...[
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.amber.shade800,
                                                    foregroundColor: Colors.white,
                                                  ),
                                                  icon: const Icon(Icons.location_on, size: 16),
                                                  label: const Text('MARK ARRIVED'),
                                                  onPressed: () => _markArrived(bookingId),
                                                ),
                                              ),
                                            ] else ...[
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF1B5E20),
                                                    foregroundColor: Colors.white,
                                                  ),
                                                  icon: const Icon(Icons.arrow_forward, size: 16),
                                                  label: const Text('OPEN TERMINAL'),
                                                  onPressed: () => _openWorkflowScreen(item),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
