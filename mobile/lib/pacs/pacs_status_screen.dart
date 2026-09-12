import 'package:flutter/material.dart';
import 'pacs_service.dart';

class PacsStatusScreen extends StatefulWidget {
  const PacsStatusScreen({super.key});

  @override
  State<PacsStatusScreen> createState() => _PacsStatusScreenState();
}

class _PacsStatusScreenState extends State<PacsStatusScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _dispatches = [];
  List<dynamic> _payments = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStatusData();
  }

  Future<void> _loadStatusData() async {
    setState(() {
      _isLoading = true;
    });

    final pacs = PacsService();
    final dRes = await pacs.getDispatches();
    final pRes = await pacs.getPayments();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _dispatches = dRes;
        _payments = pRes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Procurement & Payment Status'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.timeline), text: 'Procurement Lifecycle'),
            Tab(icon: Icon(Icons.payments), text: 'Payment Status'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Procurement Lifecycle
                RefreshIndicator(
                  onRefresh: _loadStatusData,
                  child: _dispatches.isEmpty
                      ? const Center(child: Text('No procurement records found.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _dispatches.length,
                          itemBuilder: (context, index) {
                            final item = _dispatches[index] as Map<String, dynamic>;
                            final status = item['status'] as String? ?? 'COLLECTED_AT_PACS';

                            return Card(
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Record #${item["id"]} — ${item["farmer_name"]}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade100,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              color: Colors.green.shade900,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text('Crop: ${item["crop_name"]} | Quantity: ${item["quantity_quintals"]} Qtl'),
                                    Text('Value: ₹${item["total_amount"]} | Centre: ${item["centre_name"] ?? "Mandi Hub"}'),
                                    const SizedBox(height: 12),

                                    // Lifecycle Progress Bar
                                    Row(
                                      children: [
                                        _StatusDot(label: 'PACS', isDone: true),
                                        Expanded(child: Container(height: 2, color: Colors.green)),
                                        _StatusDot(label: 'Forwarded', isDone: item["is_forwarded"] == true),
                                        Expanded(child: Container(height: 2, color: status != 'COLLECTED_AT_PACS' ? Colors.green : Colors.grey.shade300)),
                                        _StatusDot(label: 'Mandi Receipt', isDone: status == 'RECEIVED_AT_CENTRE' || status == 'ACCEPTED' || status == 'COMPLETED'),
                                        Expanded(child: Container(height: 2, color: status == 'ACCEPTED' || status == 'COMPLETED' ? Colors.green : Colors.grey.shade300)),
                                        _StatusDot(label: 'Accepted', isDone: status == 'ACCEPTED' || status == 'COMPLETED'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Tab 2: Payment Status (Read-Only Demo Mode)
                RefreshIndicator(
                  onRefresh: _loadStatusData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Mandatory Section 18 Demo/Simulated Badge
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            border: Border.all(color: Colors.amber.shade400),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.amber.shade900),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Demo / Simulated Payment Workflow',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 14),
                                    ),
                                    const Text(
                                      'Payment status is read-only. Sourced from the backend simulated DBT payment pipeline.',
                                      style: TextStyle(fontSize: 12, color: Colors.black87),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (_payments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Center(child: Text('No payment records available.')),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _payments.length,
                            itemBuilder: (context, index) {
                              final pmt = _payments[index] as Map<String, dynamic>;
                              return Card(
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFE8F5E9),
                                    child: Icon(Icons.account_balance_wallet, color: Color(0xFF1B5E20)),
                                  ),
                                  title: Text(
                                    '${pmt["farmer_name"]} — ₹${pmt["amount"]}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    'Ref: ${pmt["payment_reference"]} | Crop: ${pmt["crop_name"]}',
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          border: Border.all(color: Colors.blue.shade300),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          pmt['status'] ?? 'SIMULATED',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Read-Only',
                                        style: TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final String label;
  final bool isDone;

  const _StatusDot({required this.label, required this.isDone});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          isDone ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: isDone ? Colors.green : Colors.grey,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: isDone ? Colors.green.shade900 : Colors.grey),
        ),
      ],
    );
  }
}
