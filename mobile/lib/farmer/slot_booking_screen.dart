import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'booking_confirmation_screen.dart';

class SlotBookingScreen extends StatefulWidget {
  final int centreId;
  final String centreName;
  final int? cropId;
  final String? cropName;

  const SlotBookingScreen({
    super.key,
    required this.centreId,
    required this.centreName,
    this.cropId,
    this.cropName,
  });

  @override
  State<SlotBookingScreen> createState() => _SlotBookingScreenState();
}

class _SlotBookingScreenState extends State<SlotBookingScreen> {
  int? _selectedSlotId;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isDemoFallback = false;
  List<dynamic> _slots = [];

  @override
  void initState() {
    super.initState();
    _fetchSlots();
  }

  Future<void> _fetchSlots() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isDemoFallback = false;
      _selectedSlotId = null;
    });

    try {
      final slots = await ApiService().getCentreSlots(
        widget.centreId,
        cropId: widget.cropId,
      );
      if (mounted) {
        setState(() {
          _slots = slots;
          _isLoading = false;
          _isDemoFallback = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Backend connection issue: $e';
          _isDemoFallback = true;
          // Clearly labeled demo fallback data in case of offline/backend failure
          _slots = [
            {
              'id': 9001,
              'centre_id': widget.centreId,
              'crop_id': widget.cropId ?? 1,
              'slot_date': '2026-09-12',
              'start_time': '09:00',
              'end_time': '13:00',
              'capacity': 25,
              'booked_count': 5,
              'available_seats': 20,
              'is_active': true,
            },
            {
              'id': 9002,
              'centre_id': widget.centreId,
              'crop_id': widget.cropId ?? 1,
              'slot_date': '2026-09-12',
              'start_time': '14:00',
              'end_time': '18:00',
              'capacity': 25,
              'booked_count': 25,
              'available_seats': 0,
              'is_active': true,
            },
          ];
          _isLoading = false;
        });
      }
    }
  }

  String _formatTime(String time) {
    if (time.contains('AM') || time.contains('PM')) return time;
    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final min = parts.length > 1 ? parts[1] : '00';
      final ampm = hour >= 12 ? 'PM' : 'AM';
      final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$h12:$min $ampm';
    } catch (_) {
      return time;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.centreName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Slots',
            onPressed: _fetchSlots,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.green.shade50,
            child: Row(
              children: [
                const Icon(Icons.eco, color: Color(0xFF1B5E20), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Booking for Crop: ${widget.cropName ?? 'Selected Crop'}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                  ),
                ),
                if (!_isLoading)
                  Text(
                    '${_slots.length} Slots',
                    style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (_isDemoFallback)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.amber.shade100,
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage != null
                          ? 'DEMO DATA FALLBACK — $_errorMessage'
                          : 'DEMO DATA FALLBACK — Showing offline preview slots',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.brown),
                    ),
                  ),
                  TextButton(
                    onPressed: _fetchSlots,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 24)),
                    child: const Text('Retry', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _buildSlotsList(),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              key: const Key('proceedToConfirmBtn'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
              ),
              onPressed: _selectedSlotId == null
                  ? null
                  : () {
                      final chosenSlot = _slots.firstWhere(
                        (s) => (s['id'] as num).toInt() == _selectedSlotId,
                        orElse: () => null,
                      );
                      if (chosenSlot == null) return;

                      final slotDate = chosenSlot['slot_date']?.toString() ?? 'Today';
                      final startTime = _formatTime(chosenSlot['start_time']?.toString() ?? '');
                      final endTime = _formatTime(chosenSlot['end_time']?.toString() ?? '');
                      final slotTimeDisplay = '$slotDate ($startTime - $endTime)';

                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => BookingConfirmationScreen(
                            slotId: (chosenSlot['id'] as num).toInt(),
                            centreId: widget.centreId,
                            centreName: widget.centreName,
                            slotTime: slotTimeDisplay,
                            cropId: widget.cropId,
                            cropName: widget.cropName,
                          ),
                        ),
                      );
                    },
              child: const Text('Proceed to Confirm Booking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotsList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF1B5E20)),
            SizedBox(height: 16),
            Text('Loading slots from backend...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_slots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'No Available Slots Found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'There are currently no active slots scheduled for ${widget.cropName ?? 'this crop'} at ${widget.centreName}.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _fetchSlots,
                icon: const Icon(Icons.refresh),
                label: const Text('Check Again'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _slots.length,
      itemBuilder: (context, idx) {
        final s = _slots[idx];
        final id = (s['id'] as num).toInt();
        final slotDate = s['slot_date']?.toString() ?? '';
        final startTime = _formatTime(s['start_time']?.toString() ?? '');
        final endTime = _formatTime(s['end_time']?.toString() ?? '');
        final avail = (s['available_seats'] as num?)?.toInt() ?? 0;
        final capacity = (s['capacity'] as num?)?.toInt() ?? 25;
        final isFull = avail <= 0;
        final isSelected = _selectedSlotId == id;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isSelected ? 3 : 1,
          color: isSelected ? Colors.green.shade50 : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? const Color(0xFF1B5E20) : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Row(
              children: [
                const Icon(Icons.schedule, size: 18, color: Color(0xFF1B5E20)),
                const SizedBox(width: 8),
                Text(
                  '$slotDate | $startTime - $endTime',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isFull ? Colors.red.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isFull ? Colors.red.shade300 : Colors.green.shade300,
                      ),
                    ),
                    child: Text(
                      isFull ? 'FULLY BOOKED' : '$avail of $capacity seats available',
                      style: TextStyle(
                        color: isFull ? Colors.red.shade700 : Colors.green.shade800,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            trailing: isFull
                ? const Icon(Icons.block, color: Colors.grey)
                : Radio<int>(
                    value: id,
                    groupValue: _selectedSlotId,
                    activeColor: const Color(0xFF1B5E20),
                    onChanged: (val) {
                      setState(() {
                        _selectedSlotId = val;
                      });
                    },
                  ),
            onTap: isFull
                ? null
                : () {
                    setState(() {
                      _selectedSlotId = id;
                    });
                  },
          ),
        );
      },
    );
  }
}
