import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'centre_details_sheet.dart';
import 'live_queue_monitor_view.dart';

class CentreMonitoringView extends StatefulWidget {
  const CentreMonitoringView({super.key});

  @override
  State<CentreMonitoringView> createState() => _CentreMonitoringViewState();
}

class _CentreMonitoringViewState extends State<CentreMonitoringView> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _centres = [];
  String _filter = 'ALL'; // ALL, ACTIVE, PAUSED

  @override
  void initState() {
    super.initState();
    _loadCentres();
  }

  Future<void> _loadCentres() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await ApiService().getCentres();
      if (mounted) {
        setState(() {
          _centres = res;
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

  void _showDetails(int centreId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CentreDetailsSheet(
        centreId: centreId,
        onUpdated: _loadCentres,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadCentres, child: const Text('Retry')),
          ],
        ),
      );
    }

    final filtered = _centres.filter((c) {
      if (_filter == 'ACTIVE') return c['is_active'] == true;
      if (_filter == 'PAUSED') return c['is_active'] == false;
      return true;
    }).toList();

    return Column(
      children: [
        // Filter bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              FilterChip(
                label: Text('All (${_centres.length})'),
                selected: _filter == 'ALL',
                onSelected: (_) => setState(() => _filter = 'ALL'),
                selectedColor: const Color(0xFFE8F5E9),
                checkmarkColor: const Color(0xFF1B5E20),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text('Open (${_centres.where((c) => c['is_active'] == true).length})'),
                selected: _filter == 'ACTIVE',
                onSelected: (_) => setState(() => _filter = 'ACTIVE'),
                selectedColor: Colors.green.shade100,
                checkmarkColor: Colors.green.shade800,
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text('Paused (${_centres.where((c) => c['is_active'] == false).length})'),
                selected: _filter == 'PAUSED',
                onSelected: (_) => setState(() => _filter = 'PAUSED'),
                selectedColor: Colors.red.shade100,
                checkmarkColor: Colors.red.shade800,
              ),
            ],
          ),
        ),

        // List of Centres
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadCentres,
            color: const Color(0xFF1B5E20),
            child: filtered.isEmpty
                ? const Center(child: Text('No centres match the selected filter.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final c = filtered[index] as Map<String, dynamic>;
                      final isActive = c['is_active'] == true;
                      final queueCount = c['active_queue_count'] ?? 0;
                      final activeCounters = c['active_counters'] ?? 0;
                      final totalCounters = c['total_counters'] ?? 2;
                      final avgTime = (c['average_processing_time'] ?? 15.0).toDouble();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isActive ? const Color(0xFFE8F5E9) : Colors.red.shade50,
                                    child: Icon(
                                      Icons.location_on,
                                      color: isActive ? const Color(0xFF1B5E20) : Colors.red,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c['name'] ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${c['district']}, ${c['state']} · Type: ${c['centre_type']}',
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: isActive ? Colors.green : Colors.red),
                                    ),
                                    child: Text(
                                      isActive ? 'OPEN' : 'PAUSED',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isActive ? Colors.green.shade800 : Colors.red.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),

                              // Quick metrics row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _InfoColumn(
                                    title: 'Queue Length',
                                    value: '$queueCount',
                                    color: queueCount > 5 ? Colors.orange : const Color(0xFF1B5E20),
                                  ),
                                  _InfoColumn(
                                    title: 'Counters',
                                    value: '$activeCounters / $totalCounters',
                                    color: Colors.blueAccent,
                                  ),
                                  _InfoColumn(
                                    title: 'Avg Service',
                                    value: '${avgTime.toInt()}m',
                                    color: Colors.teal,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Action buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showDetails(c['id']),
                                      icon: const Icon(Icons.tune, size: 16),
                                      label: const Text('Manage Operations'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF1B5E20),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (ctx) => LiveQueueMonitorView(
                                              centreId: c['id'],
                                              centreName: c['name'] ?? 'Procurement Centre',
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.radar, size: 16),
                                      label: const Text('Live Tracker'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1B5E20),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                    ),
                                  ),
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
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _InfoColumn({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

extension _FilterExt on List<dynamic> {
  List<dynamic> filter(bool Function(dynamic) test) {
    return where(test).toList();
  }
}
