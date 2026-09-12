import 'package:flutter/material.dart';

class PredictedVsActualWidget extends StatelessWidget {
  final double maeMinutes;
  final double accuracyPercent;
  final int totalPredictions;
  final List<Map<String, dynamic>> comparisonItems;

  const PredictedVsActualWidget({
    super.key,
    this.maeMinutes = 4.2,
    this.accuracyPercent = 94.0,
    this.totalPredictions = 50,
    this.comparisonItems = const [
      {
        'farmer_name': 'Ramesh Gowda',
        'predicted': 35.0,
        'actual': 32.0,
        'diff': 3.0,
        'centre': 'Mandya Mandi'
      },
      {
        'farmer_name': 'Suresh Patil',
        'predicted': 45.0,
        'actual': 48.0,
        'diff': -3.0,
        'centre': 'Mysore PACS'
      },
      {
        'farmer_name': 'Ganesh Pujari',
        'predicted': 20.0,
        'actual': 22.0,
        'diff': -2.0,
        'centre': 'Hassan Hub'
      },
    ],
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_graph, color: Color(0xFF1B5E20), size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'AI Predicted vs Actual Wait Times',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${accuracyPercent.toStringAsFixed(1)}% (±15m)',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${maeMinutes.toStringAsFixed(1)} min',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Mean Abs Error (MAE)',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$totalPredictions',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Total Evaluated',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Recent Booking Comparisons:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...comparisonItems.map((item) {
              final pred = (item['predicted'] as num).toDouble();
              final act = (item['actual'] as num).toDouble();
              final farmer = item['farmer_name'] as String;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(farmer, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text(
                          'Pred: ${pred.toInt()}m | Act: ${act.toInt()}m',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (pred / 90.0).clamp(0.0, 1.0),
                              color: Colors.blue,
                              backgroundColor: Colors.blue.shade50,
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (act / 90.0).clamp(0.0, 1.0),
                              color: Colors.green,
                              backgroundColor: Colors.green.shade50,
                              minHeight: 6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
