import 'package:flutter/material.dart';
import 'staff_service.dart';

class StaffDashboardScreen extends StatefulWidget {
  final VoidCallback? onNavigateToSchedule;
  final VoidCallback? onNavigateToQueue;

  const StaffDashboardScreen({
    super.key,
    this.onNavigateToSchedule,
    this.onNavigateToQueue,
  });

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _dashboardData;
  List<dynamic> _counters = [];

  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final centreId = StaffService().centreId ?? 1;

    try {
      final summary = await StaffService().getDashboardSummary(centreId);
      final countersList = await StaffService().getCounters(centreId);

      if (mounted) {
        setState(() {
          _dashboardData = summary;
          _counters = countersList;
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

  Future<void> _showPauseDialog(bool currentPausedState) async {
    _reasonController.clear();
    final isPausing = !currentPausedState;

    if (!isPausing) {
      // Resuming centre
      try {
        final centreId = StaffService().centreId ?? 1;
        await StaffService().pauseResumeCentre(centreId, false, 'Resumed by staff');
        _loadDashboardData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
      }
      return;
    }

    // Pausing requires mandatory delay reason
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pause Centre Operations'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter mandatory delay reason (e.g. Weighbridge Maintenance, Lunch Break, System Issue):',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('delayReasonInput'),
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Mandatory Delay Reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirmPauseBtn'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final reason = _reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Mandatory delay reason cannot be empty.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.of(ctx).pop();
              try {
                final centreId = StaffService().centreId ?? 1;
                await StaffService().pauseResumeCentre(centreId, true, reason);
                _loadDashboardData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('PAUSE CENTRE'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleCounter(int counterId, bool currentActive) async {
    try {
      await StaffService().toggleCounter(counterId, !currentActive);
      _loadDashboardData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF1B5E20)),
              SizedBox(height: 16),
              Text('Fetching live dashboard data...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Failed to Load Dashboard',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadDashboardData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isPaused = _dashboardData?['is_paused'] ?? false;
    final delayReason = _dashboardData?['delay_reason'];
    final centreName = _dashboardData?['centre_name'] ?? 'Procurement Centre';

    return Scaffold(
      appBar: AppBar(
        title: Text(centreName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh Dashboard',
          ),
          IconButton(
            icon: Icon(
              isPaused ? Icons.play_arrow : Icons.pause_circle_filled,
              color: isPaused ? Colors.green : Colors.amber,
            ),
            onPressed: () => _showPauseDialog(isPaused),
            tooltip: isPaused ? 'Resume Operations' : 'Pause Operations',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPaused) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CENTRE OPERATIONS PAUSED',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                            if (delayReason != null && delayReason.toString().isNotEmpty)
                              Text(
                                'Reason: $delayReason',
                                style: const TextStyle(color: Colors.red, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Live Status Summary Cards
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.6,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _DashboardCard(
                    title: 'Total Bookings',
                    value: '${_dashboardData?['total_farmers_today'] ?? 0}',
                    icon: Icons.calendar_today,
                    color: Colors.blue.shade700,
                  ),
                  _DashboardCard(
                    title: 'Waiting Queue',
                    value: '${_dashboardData?['waiting_count'] ?? 0}',
                    icon: Icons.people_alt,
                    color: Colors.amber.shade800,
                  ),
                  _DashboardCard(
                    title: 'Processing',
                    value: '${_dashboardData?['processing_count'] ?? 0}',
                    icon: Icons.hourglass_top,
                    color: Colors.orange.shade700,
                  ),
                  _DashboardCard(
                    title: 'Completed',
                    value: '${_dashboardData?['completed_count'] ?? 0}',
                    icon: Icons.check_circle,
                    color: Colors.green.shade700,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Current & Next Tokens Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('Current Serving Token', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            _dashboardData?['current_token'] ?? 'None',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                          ),
                        ],
                      ),
                      Container(height: 40, width: 1, color: Colors.grey.shade300),
                      Column(
                        children: [
                          const Text('Next Token in Line', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            _dashboardData?['next_token'] ?? 'None',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Active Counters Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Operational Counters (${_counters.where((c) => c['is_active'] == true).length}/${_counters.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Chip(
                    avatar: const Icon(Icons.speed, size: 16, color: Colors.white),
                    label: Text(
                      'Avg: ${_dashboardData?['average_wait_minutes'] ?? 15.0}m',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    backgroundColor: const Color(0xFF1B5E20),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_counters.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No active counters configured for this centre.'),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _counters.length,
                  itemBuilder: (context, idx) {
                    final counter = _counters[idx];
                    final isActive = counter['is_active'] ?? true;
                    final currentToken = counter['current_token'];
                    final currentFarmer = counter['current_farmer'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isActive ? const Color(0xFF1B5E20) : Colors.grey,
                          child: Text(
                            '#${counter['counter_number']}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(counter['counter_name'] ?? 'Counter'),
                        subtitle: Text(
                          isActive
                              ? (currentToken != null
                                  ? 'Serving Token $currentToken ($currentFarmer)'
                                  : 'Status: IDLE / Ready')
                              : 'Status: INACTIVE',
                        ),
                        trailing: Switch(
                          value: isActive,
                          activeColor: const Color(0xFF1B5E20),
                          onChanged: (val) => _toggleCounter(counter['id'], isActive),
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 24),
              // Navigation Quick Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.schedule),
                      label: const Text("TODAY'S SCHEDULE"),
                      onPressed: widget.onNavigateToSchedule,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.play_circle_fill),
                      label: const Text('LIVE QUEUE'),
                      onPressed: widget.onNavigateToQueue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _DashboardCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Text(
                  value,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
