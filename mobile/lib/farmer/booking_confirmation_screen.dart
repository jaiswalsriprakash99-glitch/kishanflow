import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'booking_confirmed_screen.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final int slotId;
  final int? centreId;
  final String centreName;
  final String slotTime;
  final int? cropId;
  final String? cropName;

  const BookingConfirmationScreen({
    super.key,
    required this.slotId,
    this.centreId,
    required this.centreName,
    required this.slotTime,
    this.cropId,
    this.cropName,
  });

  @override
  State<BookingConfirmationScreen> createState() => _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  final _qtyController = TextEditingController(text: '20');
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _confirmBooking() async {
    if (_isSubmitting) return;

    final qtyText = _qtyController.text.trim();
    final qty = double.tryParse(qtyText);
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid estimated quantity (> 0 quintals)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      // REAL BACKEND API CALL: POST /bookings with Authorization: Bearer <FARMER_TOKEN>
      final res = await ApiService().createBooking(
        slotId: widget.slotId,
        cropId: widget.cropId ?? 1,
        quantityQuintals: qty,
      );

      if (mounted) {
        final bookingRef = res['booking_reference']?.toString() ?? 'BK-CONFIRMED';
        final queueNum = (res['queue_number'] as num?)?.toInt() ?? 1;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => BookingConfirmedScreen(
              bookingRef: bookingRef,
              queueNumber: queueNum,
              centreName: widget.centreName,
              slotTime: widget.slotTime,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('Exception: ')) {
          msg = msg.replaceAll('Exception: ', '');
        }
        setState(() {
          _isSubmitting = false;
          _submitError = msg;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking failed: $msg'),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Booking'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFF1B5E20)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.centreName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Slot: ${widget.slotTime}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.eco, size: 18, color: Color(0xFF1B5E20)),
                        const SizedBox(width: 8),
                        Text(
                          'Crop: ${widget.cropName ?? 'Paddy'}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    if (ApiService().farmerPhone != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.phone_android, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            'Farmer: ${ApiService().farmerPhone}',
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Estimated Quantity (Quintals)',
                hintText: 'e.g. 25.0',
                prefixIcon: const Icon(Icons.scale_outlined),
                suffixText: 'Quintals',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Queue number will be generated immediately and locked for your arrival window.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            if (_submitError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _submitError!,
                        style: TextStyle(fontSize: 13, color: Colors.red.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              key: const Key('confirmBookingBtn'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isSubmitting ? null : _confirmBooking,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text(
                      'Confirm & Issue Queue Ticket',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
