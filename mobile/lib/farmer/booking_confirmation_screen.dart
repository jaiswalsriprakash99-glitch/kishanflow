import 'package:flutter/material.dart';
import 'booking_confirmed_screen.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final int slotId;
  final String centreName;
  final String slotTime;

  const BookingConfirmationScreen({
    super.key,
    required this.slotId,
    required this.centreName,
    required this.slotTime,
  });

  @override
  State<BookingConfirmationScreen> createState() => _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  final _qtyController = TextEditingController(text: '20');
  bool _isSubmitting = false;
  bool _hasSubmitted = false;

  Future<void> _confirmBooking() async {
    // Idempotency check: prevent double-tap double-booking
    if (_isSubmitting || _hasSubmitted) return;

    setState(() {
      _isSubmitting = true;
      _hasSubmitted = true;
    });

    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => BookingConfirmedScreen(
            bookingRef: 'BK-MND-20260912-0042',
            queueNumber: 7,
            centreName: widget.centreName,
            slotTime: widget.slotTime,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Booking'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Centre: ${widget.centreName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Slot: ${widget.slotTime}'),
                    const SizedBox(height: 8),
                    const Text('Crop: Paddy (A-Grade)'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Estimated Quantity (Quintals)',
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              key: const Key('confirmBookingBtn'),
              onPressed: _isSubmitting ? null : _confirmBooking,
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Confirm & Issue Queue Ticket'),
            ),
          ],
        ),
      ),
    );
  }
}
