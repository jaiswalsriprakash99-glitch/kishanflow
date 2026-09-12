import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminReportsView extends StatefulWidget {
  const AdminReportsView({super.key});

  @override
  State<AdminReportsView> createState() => _AdminReportsViewState();
}

class _AdminReportsViewState extends State<AdminReportsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _reportsData;
  List<dynamic> _auditLogs = [];
  List<dynamic> _alerts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final reports = await ApiService().getReports();
      final logs = await ApiService().getAuditLogs();
      final alerts = await ApiService().getAlerts();
      if (mounted) {
        setState(() {
          _reportsData = reports;
          _auditLogs = logs;
          _alerts = alerts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1B5E20),
          indicatorColor: const Color(0xFF1B5E20),
          tabs: const [
            Tab(icon: Icon(Icons.description, size: 18), text: 'Reports'),
            Tab(icon: Icon(Icons.notifications_active, size: 18), text: 'Alerts'),
            Tab(icon: Icon(Icons.security, size: 18), text: 'Audit Trail'),
          ],
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20)))
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 40),
                          const SizedBox(height: 12),
                          Text(_error!),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _loadAll, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildReportsTab(),
                        _buildAlertsTab(),
                        _buildAuditLogsTab(),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildReportsTab() {
    final r = _reportsData ?? {};
    final title = r['report_title'] ?? 'Operations Report';
    final generatedAt = r['generated_at'] ?? '';
    final summary = r['executive_summary'] ?? '';
    final kpis = (r['kpis'] as Map<String, dynamic>?) ?? {};
    final exports = (r['available_exports'] as List<dynamic>?) ?? [];

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: const Color(0xFF1B5E20),
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: const Color(0xFFE8F5E9),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1B5E20))),
                  const SizedBox(height: 4),
                  Text('Generated: $generatedAt', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                  const Divider(height: 16),
                  Text(summary, style: const TextStyle(fontSize: 13, height: 1.3)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text('Executive Operations Metrics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _KpiBox(
                  label: 'Registered Farmers',
                  value: '${kpis['total_registered_farmers'] ?? 50}',
                  icon: Icons.people,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _KpiBox(
                  label: 'Slots Booked',
                  value: '${kpis['total_slots_booked'] ?? 50}',
                  icon: Icons.calendar_today,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _KpiBox(
                  label: 'Procured Volume',
                  value: '${kpis['procured_volume_quintals'] ?? 0} Qtl',
                  icon: Icons.scale,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _KpiBox(
                  label: 'Disbursed (INR)',
                  value: '₹${kpis['total_disbursement_inr'] ?? 0}',
                  icon: Icons.currency_rupee,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          const Text('Available Official Reports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...exports.map((e) {
            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.file_present_outlined, color: Color(0xFF1B5E20)),
                title: Text(e['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('Format: ${e['format']}', style: const TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.visibility, size: 18, color: Color(0xFF1B5E20)),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Viewing ${e['name']} in mobile app.'),
                      backgroundColor: const Color(0xFF1B5E20),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAlertsTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      color: const Color(0xFF1B5E20),
      child: _alerts.isEmpty
          ? const Center(child: Text('No active operational alerts.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _alerts.length,
              itemBuilder: (context, index) {
                final al = _alerts[index] as Map<String, dynamic>;
                final level = al['level'] ?? 'LOW';
                final title = al['title'] ?? '';
                final msg = al['message'] ?? '';
                final ts = al['timestamp'] ?? '';

                Color alertColor;
                IconData alertIcon;
                switch (level) {
                  case 'HIGH':
                    alertColor = Colors.red;
                    alertIcon = Icons.error;
                    break;
                  case 'MEDIUM':
                    alertColor = Colors.orange;
                    alertIcon = Icons.warning;
                    break;
                  default:
                    alertColor = Colors.green;
                    alertIcon = Icons.check_circle_outline;
                }

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: alertColor.withOpacity(0.5)),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(alertIcon, color: alertColor, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: alertColor)),
                              const SizedBox(height: 4),
                              Text(msg, style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 6),
                              Text(ts, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildAuditLogsTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      color: const Color(0xFF1B5E20),
      child: _auditLogs.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('No administrative mutations recorded in audit log yet. Operational actions like centre pausing will appear here.'),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _auditLogs.length,
              itemBuilder: (context, index) {
                final log = _auditLogs[index] as Map<String, dynamic>;
                final action = log['action'] ?? '';
                final res = log['resource'] ?? '';
                final ts = log['timestamp'] ?? '';
                final userRole = log['user_role'] ?? 'ADMIN';

                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F5E9),
                      child: Icon(Icons.history_edu, color: Color(0xFF1B5E20), size: 18),
                    ),
                    title: Text(action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('Resource: $res · Role: $userRole\nTimestamp: $ts', style: const TextStyle(fontSize: 11)),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }
}

class _KpiBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _KpiBox({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF1B5E20)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
