import 'package:flutter/material.dart';

class BookingConfirmedScreen extends StatelessWidget {
  final String bookingRef;
  final int queueNumber;
  final String centreName;
  final String slotTime;

  const BookingConfirmedScreen({
    super.key,
    required this.bookingRef,
    required this.queueNumber,
    required this.centreName,
    required this.slotTime,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Confirmed!'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded, size: 90, color: Color(0xFF1B5E20)),
              const SizedBox(height: 16),
              const Text(
                'Slot Booked Successfully!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
              ),
              const SizedBox(height: 12),
              Text(
                'Reference: $bookingRef',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1B5E20), width: 2),
                ),
                child: Column(
                  children: [
                    const Text('YOUR QUEUE NUMBER', style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      '#$queueNumber',
                      style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                    ),
                    const SizedBox(height: 8),
                    Text(centreName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(slotTime),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
