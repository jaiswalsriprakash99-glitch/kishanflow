import 'package:flutter/material.dart';

class ProcurementTimelineScreen extends StatelessWidget {
  final String bookingRef;
  final String currentStatus;
  final String? rejectionReason;

  const ProcurementTimelineScreen({
    super.key,
    required this.bookingRef,
    required this.currentStatus,
    this.rejectionReason,
  });

  final List<Map<String, String>> _steps = const [
    {'name': 'Registered', 'desc': 'Crop & Farmer registration completed'},
    {'name': 'Slot Booked', 'desc': 'Time slot assigned & queue ticket issued'},
    {'name': 'Arrived', 'desc': 'Checked in at procurement centre gate'},
    {'name': 'In Queue', 'desc': 'Assigned to active queue counter'},
    {'name': 'Verification', 'desc': 'Land & identity documents verified'},
    {'name': 'Quality Check', 'desc': 'Moisture, foreign matter & grade inspection'},
    {'name': 'Weighing', 'desc': 'Net weight measurement at weighbridge'},
    {'name': 'Accepted', 'desc': 'Produce accepted for government procurement'},
    {'name': 'Procurement Completed', 'desc': 'Receipt generated & DBT payment initiated'},
  ];

  @override
  Widget build(BuildContext context) {
    final isRejected = currentStatus == 'QUALITY_REJECTED';

    return Scaffold(
      appBar: AppBar(
        title: Text('Procurement Status: $bookingRef'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isRejected) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade700, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.cancel, color: Colors.red, size: 28),
                        SizedBox(width: 10),
                        Text(
                          'Quality Check Rejected',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Reason: ${rejectionReason ?? "Moisture content exceeded threshold (18.5%)"}',
                      style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            const Text(
              'Procurement Progress Lifecycle',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _steps.length,
              itemBuilder: (context, idx) {
                final s = _steps[idx];
                final isDone = idx <= 4;
                final isCurrent = idx == 5;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: isDone
                              ? const Color(0xFF1B5E20)
                              : (isCurrent ? Colors.amber.shade700 : Colors.grey.shade300),
                          child: Icon(
                            isDone ? Icons.check : (isCurrent ? Icons.play_arrow : Icons.circle),
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                        if (idx < _steps.length - 1)
                          Container(
                            width: 2,
                            height: 36,
                            color: isDone ? const Color(0xFF1B5E20) : Colors.grey.shade300,
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s['name']!,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isDone || isCurrent ? Colors.black : Colors.grey,
                              ),
                            ),
                            Text(
                              s['desc']!,
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
