import 'package:flutter/material.dart';
import 'predicted_vs_actual_widget.dart';

class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Executive Dashboard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Performance & Queue Analytics',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
            ),
            const SizedBox(height: 16),
            Row(
              children: const [
                Expanded(child: _MetricCard(title: 'Total Farmers', value: '50', icon: Icons.people)),
                SizedBox(width: 12),
                Expanded(child: _MetricCard(title: 'Bookings', value: '50', icon: Icons.bookmark)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                Expanded(child: _MetricCard(title: 'Avg Wait', value: '28.5 min', icon: Icons.timer)),
                SizedBox(width: 12),
                Expanded(child: _MetricCard(title: 'No-Show Rate', value: '4.2%', icon: Icons.cancel)),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Procurement Status Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: const [
                    _ProgressRow(label: 'Accepted / Completed', count: 42, color: Colors.green),
                    SizedBox(height: 8),
                    _ProgressRow(label: 'In Verification', count: 5, color: Colors.orange),
                    SizedBox(height: 8),
                    _ProgressRow(label: 'Quality Rejected', count: 3, color: Colors.red),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('AI Predictions Accuracy Evaluation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const PredictedVsActualWidget(),
            const SizedBox(height: 24),
            const Text('Crop-wise Procurement Volume', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: const [
                  ListTile(title: Text('Paddy'), trailing: Text('450.0 Quintals', style: TextStyle(fontWeight: FontWeight.bold))),
                  Divider(height: 1),
                  ListTile(title: Text('Wheat'), trailing: Text('320.0 Quintals', style: TextStyle(fontWeight: FontWeight.bold))),
                  Divider(height: 1),
                  ListTile(title: Text('Maize'), trailing: Text('180.0 Quintals', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MetricCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF1B5E20)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _ProgressRow({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
          child: Text('$count records', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
