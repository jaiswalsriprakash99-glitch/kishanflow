import 'package:flutter/material.dart';
import 'booking_confirmation_screen.dart';

class SlotBookingScreen extends StatefulWidget {
  final int centreId;
  final String centreName;

  const SlotBookingScreen({
    super.key,
    required this.centreId,
    required this.centreName,
  });

  @override
  State<SlotBookingScreen> createState() => _SlotBookingScreenState();
}

class _SlotBookingScreenState extends State<SlotBookingScreen> {
  int? _selectedSlotId;

  final List<Map<String, dynamic>> _slots = [
    {
      'id': 101,
      'date': '2026-09-12',
      'time': '09:00 AM - 11:00 AM',
      'available': 5,
      'capacity': 25,
    },
    {
      'id': 102,
      'date': '2026-09-12',
      'time': '11:00 AM - 01:00 PM',
      'available': 12,
      'capacity': 25,
    },
    {
      'id': 103,
      'date': '2026-09-12',
      'time': '02:00 PM - 04:00 PM',
      'available': 0, // Fully booked
      'capacity': 25,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Available Slots: ${widget.centreName}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _slots.length,
              itemBuilder: (context, idx) {
                final s = _slots[idx];
                final isFull = s['available'] == 0;
                final isSelected = _selectedSlotId == s['id'];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isSelected ? Colors.green.shade50 : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF1B5E20) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(
                      '${s['date']} | ${s['time']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isFull ? 'FULLY BOOKED' : '${s['available']} of ${s['capacity']} seats available',
                      style: TextStyle(
                        color: isFull ? Colors.red : Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: isFull
                        ? const Icon(Icons.block, color: Colors.grey)
                        : Radio<int>(
                            value: s['id'],
                            groupValue: _selectedSlotId,
                            onChanged: (val) {
                              setState(() => _selectedSlotId = val);
                            },
                          ),
                    onTap: isFull
                        ? null
                        : () {
                            setState(() => _selectedSlotId = s['id']);
                          },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: _selectedSlotId == null
                  ? null
                  : () {
                      final chosenSlot = _slots.firstWhere((s) => s['id'] == _selectedSlotId);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => BookingConfirmationScreen(
                            slotId: chosenSlot['id'],
                            centreName: widget.centreName,
                            slotTime: '${chosenSlot['date']} ${chosenSlot['time']}',
                          ),
                        ),
                      );
                    },
              child: const Text('Proceed to Confirm Booking'),
            ),
          ),
        ],
      ),
    );
  }
}
