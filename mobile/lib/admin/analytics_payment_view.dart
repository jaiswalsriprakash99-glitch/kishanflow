import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AnalyticsPaymentView extends StatefulWidget {
  const AnalyticsPaymentView({super.key});

  @override
  State<AnalyticsPaymentView> createState() => _AnalyticsPaymentViewState();
}

class _AnalyticsPaymentViewState extends State<AnalyticsPaymentView> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await ApiService().getPaymentAnalytics();
      if (mounted) {
        setState(() {
          _data = res;
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20)));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadPayments, child: const Text('Retry')),
          ],
        ),
      );
    }

    final d = _data!;
    final totalAmount = (d['total_payments_amount'] ?? 0.0).toDouble();
    final statusBreakdown = (d['status_breakdown'] as Map<String, dynamic>?) ?? {};
    final recentPayments = (d['recent_payments'] as List<dynamic>?) ?? [];

    return RefreshIndicator(
      onRefresh: _loadPayments,
      color: const Color(0xFF1B5E20),
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Total Disbursed Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: const Color(0xFFE8F5E9),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Direct Benefit Transfer (DBT) Disbursed', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    '₹${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                  ),
                  const SizedBox(height: 6),
                  const Text('Direct bank transfer under State MSP Procurement Policy', style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Lifecycle Breakdown Card
          const Text('Payment Settlement Pipeline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _StatusProgressRow(
                    title: 'Credited (Settled)',
                    data: statusBreakdown['CREDITED'] as Map<String, dynamic>?,
                    color: Colors.green,
                  ),
                  const Divider(height: 20),
                  _StatusProgressRow(
                    title: 'Processing (Bank ACH)',
                    data: statusBreakdown['PROCESSING'] as Map<String, dynamic>?,
                    color: Colors.orange,
                  ),
                  const Divider(height: 20),
                  _StatusProgressRow(
                    title: 'Initiated (Pending Approval)',
                    data: statusBreakdown['INITIATED'] as Map<String, dynamic>?,
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Recent Payments Ledger
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Payment Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${recentPayments.length} transactions', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          ...recentPayments.map((p) {
            final ref = p['payment_reference'] ?? '';
            final fName = p['farmer_name'] ?? '';
            final amt = (p['amount'] ?? 0.0).toDouble();
            final st = p['status'] ?? '';
            final dt = p['initiated_at'] ?? '';

            final isSuccess = st == 'CREDITED';

            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: isSuccess ? Colors.green.shade50 : Colors.orange.shade50,
                  child: Icon(
                    isSuccess ? Icons.check_circle : Icons.hourglass_empty,
                    color: isSuccess ? Colors.green : Colors.orange,
                    size: 18,
                  ),
                ),
                title: Text(fName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('Ref: $ref · $dt', style: const TextStyle(fontSize: 11)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${amt.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1B5E20))),
                    Text(st, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSuccess ? Colors.green : Colors.orange)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StatusProgressRow extends StatelessWidget {
  final String title;
  final Map<String, dynamic>? data;
  final Color color;

  const _StatusProgressRow({required this.title, required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    final count = data?['count'] ?? 0;
    final amt = (data?['amount'] ?? 0.0).toDouble();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 2),
            Text('$count transactions', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        Text(
          '₹${amt.toStringAsFixed(2)}',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
        ),
      ],
    );
  }
}
