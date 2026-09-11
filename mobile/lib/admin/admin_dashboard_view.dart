import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminDashboardView extends StatefulWidget {
  final Function(int tabIndex) onNavigateTab;

  const AdminDashboardView({super.key, required this.onNavigateTab});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stats = await ApiService().getDashboardStats();
      if (mounted) {
        setState(() {
          _stats = stats;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF1B5E20)),
            SizedBox(height: 16),
            Text('Fetching live system metrics from backend...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 56, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                'Failed to Load Dashboard Data',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadStats,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final s = _stats ?? {};
    final totalCentres = s['total_centres'] ?? 0;
    final openCentres = s['open_centres'] ?? 0;
    final busyCentres = s['busy_centres'] ?? 0;
    final closedCentres = s['closed_centres'] ?? 0;
    final totalBookings = s['total_bookings_today'] ?? 0;
    final waiting = s['farmers_waiting'] ?? 0;
    final processing = s['farmers_processing'] ?? 0;
    final completed = s['completed_procurements'] ?? 0;
    final acceptedQuintals = (s['accepted_quintals'] ?? 0.0).toDouble();
    final rejectedQuintals = (s['rejected_quintals'] ?? 0.0).toDouble();
    final pendingProc = s['pending_procurement'] ?? 0;
    final payPending = s['payment_pending'] ?? 0;
    final payCompleted = s['payment_completed'] ?? 0;
    final payTotalVal = (s['payment_amount_total'] ?? 0.0).toDouble();
    final alertsCount = s['active_alerts_count'] ?? 0;

    return RefreshIndicator(
      onRefresh: _loadStats,
      color: const Color(0xFF1B5E20),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Welcome Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: const Color(0xFFE8F5E9),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFF1B5E20),
                      child: Icon(Icons.shield, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ApiService().adminFullName ?? 'Administrator',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'KisanFlow State Procurement Grid',
                            style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Color(0xFF1B5E20)),
                      onPressed: _loadStats,
                      tooltip: 'Refresh Metrics',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Active Alert Banner if any
            if (alertsCount > 0) ...[
              InkWell(
                onTap: () => widget.onNavigateTab(4), // Navigate to alerts/reports
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade700),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$alertsCount Operational Alert${alertsCount > 1 ? 's' : ''} Require Attention',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 13),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 14, color: Colors.amber.shade900),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Section: Centre Operations Status
            const Text(
              'Procurement Centre Status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StatusCard(
                    title: 'Total Centres',
                    value: '$totalCentres',
                    color: Colors.teal,
                    icon: Icons.store,
                    onTap: () => widget.onNavigateTab(1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatusCard(
                    title: 'Open / Active',
                    value: '$openCentres',
                    color: Colors.green,
                    icon: Icons.check_circle_outline,
                    onTap: () => widget.onNavigateTab(1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatusCard(
                    title: 'Busy / Congested',
                    value: '$busyCentres',
                    color: busyCentres > 0 ? Colors.orange : Colors.grey,
                    icon: Icons.hourglass_top,
                    onTap: () => widget.onNavigateTab(1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatusCard(
                    title: 'Closed / Paused',
                    value: '$closedCentres',
                    color: closedCentres > 0 ? Colors.red : Colors.grey,
                    icon: Icons.pause_circle_outline,
                    onTap: () => widget.onNavigateTab(1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section: Live Queue Metrics
            const Text(
              'Real-Time Queue Operations',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    title: 'Total Bookings',
                    value: '$totalBookings',
                    subtitle: 'Scheduled across grid',
                    icon: Icons.calendar_month,
                    accentColor: Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricTile(
                    title: 'In Queue (Waiting)',
                    value: '$waiting',
                    subtitle: 'Arrived at centres',
                    icon: Icons.people_outline,
                    accentColor: waiting > 5 ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    title: 'At Counters (Active)',
                    value: '$processing',
                    subtitle: 'Verification & weighment',
                    icon: Icons.scale,
                    accentColor: Colors.indigo,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricTile(
                    title: 'Completed Today',
                    value: '$completed',
                    subtitle: 'Procurement finalized',
                    icon: Icons.done_all,
                    accentColor: const Color(0xFF1B5E20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section: Procurement & Grain Quantities
            const Text(
              'Procurement Volume & Quality',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Accepted Grain Quantity:', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '$acceptedQuintals Qtl',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1B5E20)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (acceptedQuintals + rejectedQuintals) > 0
                            ? (acceptedQuintals / (acceptedQuintals + rejectedQuintals)).clamp(0.0, 1.0)
                            : 0.9,
                        minHeight: 8,
                        backgroundColor: Colors.red.shade100,
                        color: const Color(0xFF1B5E20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(width: 10, height: 10, color: const Color(0xFF1B5E20)),
                            const SizedBox(width: 6),
                            const Text('Accepted / Quality Passed', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        Row(
                          children: [
                            Container(width: 10, height: 10, color: Colors.red.shade400),
                            const SizedBox(width: 6),
                            Text('Rejected: $rejectedQuintals Qtl', style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Section: Payment Lifecycle Analytics
            const Text(
              'Direct Benefit Transfer (DBT) Payments',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Disbursed Amount:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        Text(
                          '₹${payTotalVal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1B5E20)),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _PaymentMetric(label: 'Credited', count: payCompleted, color: Colors.green),
                        _PaymentMetric(label: 'Pending / Processing', count: payPending, color: Colors.orange),
                        _PaymentMetric(label: 'Unassigned', count: pendingProc, color: Colors.grey),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Quick Actions Navigation Grid
            const Text('Operational Shortcuts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => widget.onNavigateTab(1),
                    icon: const Icon(Icons.location_city),
                    label: const Text('Centres'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: const Color(0xFF1B5E20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => widget.onNavigateTab(2),
                    icon: const Icon(Icons.search),
                    label: const Text('Search'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: const Color(0xFF1B5E20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => widget.onNavigateTab(3),
                    icon: const Icon(Icons.analytics),
                    label: const Text('Analytics'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: const Color(0xFF1B5E20),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _StatusCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const _MetricTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                Icon(icon, size: 18, color: accentColor),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: accentColor)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _PaymentMetric extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _PaymentMetric({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
