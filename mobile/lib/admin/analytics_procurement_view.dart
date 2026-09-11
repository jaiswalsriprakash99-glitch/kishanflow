import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AnalyticsProcurementView extends StatefulWidget {
  const AnalyticsProcurementView({super.key});

  @override
  State<AnalyticsProcurementView> createState() => _AnalyticsProcurementViewState();
}

class _AnalyticsProcurementViewState extends State<AnalyticsProcurementView> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await ApiService().getProcurementAnalytics();
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
            ElevatedButton(onPressed: _loadAnalytics, child: const Text('Retry')),
          ],
        ),
      );
    }

    final d = _data!;
    final totalAccepted = (d['total_accepted_quintals'] ?? 0.0).toDouble();
    final totalInr = (d['total_disbursed_inr'] ?? 0.0).toDouble();
    final cropWise = (d['crop_wise'] as List<dynamic>?) ?? [];
    final centreWise = (d['centre_wise'] as List<dynamic>?) ?? [];

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      color: const Color(0xFF1B5E20),
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Total Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: const Color(0xFFE8F5E9),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Procured Grain', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          '$totalAccepted Quintals',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('MSP Value (INR)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          '₹${totalInr.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Crop-wise Breakdown
          const Text('Crop-wise Procurement & MSP Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...cropWise.map((c) {
            final name = c['crop_name'] ?? '';
            final msp = (c['msp_per_quintal'] ?? 0.0).toDouble();
            final count = c['procurement_count'] ?? 0;
            final accQ = (c['accepted_quintals'] ?? 0.0).toDouble();
            final inrVal = (c['total_value_inr'] ?? 0.0).toDouble();

            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                          '$accQ Qtl',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B5E20)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('MSP: ₹${msp.toInt()} / Qtl · $count Bookings', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        Text('Total: ₹${inrVal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.indigo)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 20),

          // Centre-wise Breakdown
          const Text('Centre-wise Procurement Volume', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...centreWise.map((cw) {
            final cName = cw['centre_name'] ?? '';
            final count = cw['procurement_count'] ?? 0;
            final q = (cw['accepted_quintals'] ?? 0.0).toDouble();

            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.warehouse, color: Color(0xFF1B5E20)),
                title: Text(cName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text('$count Procurements Recorded', style: const TextStyle(fontSize: 12)),
                trailing: Text('$q Qtl', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1B5E20))),
              ),
            );
          }),
        ],
      ),
    );
  }
}
