import 'package:flutter/material.dart';
import 'pacs_service.dart';

class PacsDashboardScreen extends StatefulWidget {
  final VoidCallback onNavigateToCollection;
  final VoidCallback onNavigateToForwarding;
  final VoidCallback onNavigateToPayments;

  const PacsDashboardScreen({
    super.key,
    required this.onNavigateToCollection,
    required this.onNavigateToForwarding,
    required this.onNavigateToPayments,
  });

  @override
  State<PacsDashboardScreen> createState() => _PacsDashboardScreenState();
}

class _PacsDashboardScreenState extends State<PacsDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await PacsService().getDashboardSummary();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['success'] == true) {
          _summary = res['data'];
        } else {
          _errorMessage = res['message'] ?? 'Failed to load PACS metrics';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pacs = PacsService();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // PACS Header Card
              Card(
                color: const Color(0xFF1B5E20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              pacs.pacsName ?? 'Mysore PACS',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade700,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle, size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'OPERATIONAL',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Operator: ${pacs.fullName ?? "Operator"} (${pacs.username ?? "operator1"})',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PACS Code: ${_summary?["pacs_code"] ?? "PACS_MYS_01"} | District: ${_summary?["district"] ?? "Mysore"}',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (_isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()))
              else if (_errorMessage != null)
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(_errorMessage!, style: TextStyle(color: Colors.red.shade900)),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _loadDashboardData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // Metrics Grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.45,
                  children: [
                    _MetricCard(
                      title: "Today's Collections",
                      value: '${_summary?["today_collections_count"] ?? 0}',
                      subtitle: 'Farmer Entries',
                      icon: Icons.inventory_2_outlined,
                      color: Colors.blue,
                    ),
                    _MetricCard(
                      title: 'Collected Quantity',
                      value: '${_summary?["collected_quantity_quintals"] ?? 0} Qtl',
                      subtitle: 'Total Volume',
                      icon: Icons.scale_outlined,
                      color: Colors.teal,
                    ),
                    _MetricCard(
                      title: 'Pending Forwarding',
                      value: '${_summary?["pending_forwarding_count"] ?? 0}',
                      subtitle: 'Ready for Mandi',
                      icon: Icons.local_shipping_outlined,
                      color: Colors.orange,
                    ),
                    _MetricCard(
                      title: 'Dispatched Quantity',
                      value: '${_summary?["dispatched_quantity_quintals"] ?? 0} Qtl',
                      subtitle: 'In Transit / Delivered',
                      icon: Icons.task_alt_outlined,
                      color: Colors.green,
                    ),
                    _MetricCard(
                      title: 'Registered Farmers',
                      value: '${_summary?["registered_farmers_count"] ?? 0}',
                      subtitle: 'PACS Beneficiaries',
                      icon: Icons.people_outline,
                      color: Colors.purple,
                    ),
                    _MetricCard(
                      title: 'Total Procurement',
                      value: '₹${_summary?["total_amount_rupees"] ?? 0}',
                      subtitle: 'Total Value',
                      icon: Icons.account_balance_wallet_outlined,
                      color: Colors.indigo,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Quick Action Cards
                const Text(
                  'PACS Operational Actions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  key: const Key('startCollectionActionBtn'),
                  title: 'Record Farmer Collection',
                  subtitle: 'Search farmer, verify crop, enter weight & print receipt',
                  icon: Icons.add_shopping_cart,
                  btnText: 'New Collection Entry',
                  onPressed: widget.onNavigateToCollection,
                ),
                const SizedBox(height: 10),
                _ActionCard(
                  key: const Key('forwardBatchActionBtn'),
                  title: 'Forward Batch to Procurement Centre',
                  subtitle: 'Dispatch pending PACS collections to main mandi hub',
                  icon: Icons.local_shipping,
                  btnText: 'Forwarding & Dispatch',
                  onPressed: widget.onNavigateToForwarding,
                ),
                const SizedBox(height: 10),
                _ActionCard(
                  key: const Key('viewPaymentsActionBtn'),
                  title: 'Payment & Procurement Status',
                  subtitle: 'Track payment settlement status (Read-Only Demo Mode)',
                  icon: Icons.receipt_long,
                  btnText: 'View Status',
                  onPressed: widget.onNavigateToPayments,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final MaterialColor color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: color.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color.shade900),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String btnText;
  final VoidCallback onPressed;

  const _ActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.btnText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE8F5E9),
          child: Icon(icon, color: const Color(0xFF1B5E20)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1B5E20),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onPressed: onPressed,
          child: Text(btnText, style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}
