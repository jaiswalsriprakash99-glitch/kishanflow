import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'live_queue_monitor_view.dart';

class CentreDetailsSheet extends StatefulWidget {
  final int centreId;
  final VoidCallback onUpdated;

  const CentreDetailsSheet({super.key, required this.centreId, required this.onUpdated});

  @override
  State<CentreDetailsSheet> createState() => _CentreDetailsSheetState();
}

class _CentreDetailsSheetState extends State<CentreDetailsSheet> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _details;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await ApiService().getCentreDetails(widget.centreId);
      if (mounted) {
        setState(() {
          _details = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '').replaceFirst('HttpException: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmToggleCentreStatus(bool currentlyActive) async {
    final reasonController = TextEditingController(text: currentlyActive ? 'Maintenance & Calibration' : '');
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(currentlyActive ? 'Pause Centre Operations' : 'Resume Centre Operations'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currentlyActive
                    ? 'Pausing operations will temporarily stop counter calling. An audit log will be created.'
                    : 'Resume operations will allow counters to resume calling farmers.',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              if (currentlyActive) ...[
                TextFormField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Operational Reason (Mandatory)',
                    hintText: 'e.g. Weighbridge calibration, power outage',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Reason is required' : null,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: currentlyActive ? Colors.orange.shade800 : const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (currentlyActive && !formKey.currentState!.validate()) return;
              Navigator.of(ctx).pop(true);
            },
            child: Text(currentlyActive ? 'Confirm Pause' : 'Confirm Resume'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService().updateCentreStatus(
          widget.centreId,
          isActive: !currentlyActive,
          delayReason: reasonController.text.trim(),
        );
        widget.onUpdated();
        _loadDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(currentlyActive ? 'Centre paused successfully.' : 'Centre resumed successfully.'),
              backgroundColor: const Color(0xFF1B5E20),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _toggleCounter(int counterId, bool currentlyActive) async {
    try {
      await ApiService().updateCentreCounters(widget.centreId, counterId: counterId, isActive: !currentlyActive);
      widget.onUpdated();
      _loadDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!currentlyActive ? 'Counter activated.' : 'Counter deactivated.'),
            backgroundColor: const Color(0xFF1B5E20),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 400,
        child: Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20))),
      );
    }

    if (_error != null) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 40),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _loadDetails, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final data = _details!;
    final centre = data['centre'] as Map<String, dynamic>;
    final counters = (data['counters'] as List<dynamic>?) ?? [];
    final linkedPacs = data['linked_pacs'] as Map<String, dynamic>?;
    final staff = (data['assigned_staff'] as List<dynamic>?) ?? [];
    final liveQ = (data['live_queue'] as List<dynamic>?) ?? [];
    final procSummary = (data['procurement_summary'] as Map<String, dynamic>?) ?? {};

    final isActive = centre['is_active'] == true;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      centre['name'] ?? '',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${centre['district']}, ${centre['state']} (${centre['code']})',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isActive ? Colors.green : Colors.red),
                ),
                child: Text(
                  isActive ? 'OPERATIONAL' : 'PAUSED / CLOSED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Operational Controls Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _confirmToggleCentreStatus(isActive),
                  icon: Icon(isActive ? Icons.pause_circle_outline : Icons.play_circle_outline),
                  label: Text(isActive ? 'Pause Operations' : 'Resume Operations'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isActive ? Colors.orange.shade800 : const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => LiveQueueMonitorView(
                        centreId: widget.centreId,
                        centreName: centre['name'] ?? 'Procurement Centre',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.people_alt_outlined),
                label: const Text('Live Queue'),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1B5E20)),
              ),
            ],
          ),
          const Divider(height: 28),

          // Procurement Summary row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '${procSummary['total_procured_quintals'] ?? 0} Qtl',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B5E20)),
                    ),
                    const Text('Total Procured', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                Container(height: 24, width: 1, color: Colors.grey.shade300),
                Column(
                  children: [
                    Text(
                      '₹${procSummary['total_amount_distributed'] ?? 0}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B5E20)),
                    ),
                    const Text('MSP Value', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                Container(height: 24, width: 1, color: Colors.grey.shade300),
                Column(
                  children: [
                    Text(
                      '${procSummary['records_count'] ?? 0}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B5E20)),
                    ),
                    const Text('Transactions', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Counters Section
          Text('Procurement Counters (${counters.length}) • Staff (${staff.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: counters.map((cnt) {
              final cActive = cnt['is_active'] == true;
              final cId = cnt['id'] as int;
              return FilterChip(
                label: Text('${cnt['counter_name']} ${cActive ? '(Active)' : '(Off)'}'),
                selected: cActive,
                selectedColor: Colors.green.shade100,
                checkmarkColor: const Color(0xFF1B5E20),
                onSelected: (_) => _toggleCounter(cId, cActive),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Linked PACS info
          if (linkedPacs != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.storefront, color: Colors.blueAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Linked Primary Agricultural Society: ${linkedPacs['name']}',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Quick Queue Snapshot
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Live Waiting Queue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('${liveQ.length} in line', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          if (liveQ.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('No farmers currently waiting in active queue.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
          else
            ...liveQ.take(3).map((item) {
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFFE8F5E9),
                  child: Text('#${item['queue_number']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                ),
                title: Text(item['farmer_name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text('${item['crop_name']} - ${item['estimated_quantity']} Qtl', style: const TextStyle(fontSize: 11)),
                trailing: Text(item['status'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
              );
            }),
        ],
      ),
    );
  }
}
