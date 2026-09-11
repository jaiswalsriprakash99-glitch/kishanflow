import 'package:flutter/material.dart';

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  bool _isPaused = false;
  String _delayReason = '';
  final _reasonController = TextEditingController();

  List<Map<String, dynamic>> _liveQueue = [
    {
      'booking_id': 101,
      'farmer_name': 'Ramesh Gowda',
      'ticket': '#1',
      'crop': 'Paddy',
      'status': 'WAITING',
      'position': 1,
    },
    {
      'booking_id': 102,
      'farmer_name': 'Suresh Patil',
      'ticket': '#2',
      'crop': 'Wheat',
      'status': 'WAITING',
      'position': 2,
    },
    {
      'booking_id': 103,
      'farmer_name': 'Mahesh Kumar',
      'ticket': '#3',
      'crop': 'Maize',
      'status': 'WAITING',
      'position': 3,
    },
  ];

  void _completeFarmer(int bookingId) {
    setState(() {
      _liveQueue.removeWhere((item) => item['booking_id'] == bookingId);
      for (int i = 0; i < _liveQueue.length; i++) {
        _liveQueue[i]['position'] = i + 1;
      }
    });
  }

  void _showPauseDialog() {
    _reasonController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pause Centre Operations'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter mandatory delay reason (e.g. Weighbridge Maintenance):'),
            const SizedBox(height: 12),
            TextField(
              key: const Key('delayReasonInput'),
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Delay Reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirmPauseBtn'),
            onPressed: () {
              if (_reasonController.text.trim().isEmpty) return;
              setState(() {
                _isPaused = true;
                _delayReason = _reasonController.text.trim();
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('Pause Centre'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mandya Mandi - Staff Operator'),
        actions: [
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause_circle_filled, color: Colors.amber),
            onPressed: () {
              if (_isPaused) {
                setState(() {
                  _isPaused = false;
                  _delayReason = '';
                });
              } else {
                _showPauseDialog();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isPaused) ...[
            Container(
              color: Colors.red.shade100,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'PAUSED: $_delayReason',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatBadge(title: 'Active Queue', value: '${_liveQueue.length}'),
                const _StatBadge(title: 'Completed', value: '14'),
                const _StatBadge(title: 'Active Counters', value: '2/3'),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Live Queue Terminal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              key: const Key('liveQueueListView'),
              padding: const EdgeInsets.all(16),
              itemCount: _liveQueue.length,
              itemBuilder: (context, idx) {
                final item = _liveQueue[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF1B5E20),
                      child: Text(
                        item['ticket'],
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(item['farmer_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Crop: ${item['crop']} | Pos: ${item['position']}'),
                    trailing: ElevatedButton(
                      key: Key('completeBtn_${item['booking_id']}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _completeFarmer(item['booking_id']),
                      child: const Text('Mark Done'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String title;
  final String value;

  const _StatBadge({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
