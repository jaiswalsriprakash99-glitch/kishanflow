import 'dart:async';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'staff_service.dart';
import 'procurement_workflow_screen.dart';

class StaffLiveQueueScreen extends StatefulWidget {
  const StaffLiveQueueScreen({super.key});

  @override
  State<StaffLiveQueueScreen> createState() => _StaffLiveQueueScreenState();
}

class _StaffLiveQueueScreenState extends State<StaffLiveQueueScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  List<dynamic> _schedule = [];
  List<dynamic> _counters = [];
  int _selectedCounterId = 1;

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  bool _isWsConnected = false;
  Timer? _reconnectTimer;

  @override
  void initState() {
    super.initState();
    _loadQueueData();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    _reconnectTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadQueueData() async {
    final centreId = StaffService().centreId ?? 1;

    try {
      final summary = await StaffService().getDashboardSummary(centreId);
      final items = await StaffService().getSchedule(centreId, statusFilter: 'WAITING');
      final countersList = await StaffService().getCounters(centreId);

      if (mounted) {
        setState(() {
          _dashboardData = summary;
          _schedule = items;
          _counters = countersList;
          if (_counters.isNotEmpty) {
            _selectedCounterId = _counters.first['id'] ?? 1;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _connectWebSocket() {
    final centreId = StaffService().centreId ?? 1;
    try {
      _wsChannel = StaffService().connectLiveQueueWebSocket(centreId);
      setState(() => _isWsConnected = true);

      _wsSubscription = _wsChannel!.stream.listen(
        (message) {
          debugPrint('Live Queue WS Event: $message');
          _loadQueueData();
        },
        onError: (error) {
          debugPrint('WS Error: $error');
          setState(() => _isWsConnected = false);
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('WS Closed');
          setState(() => _isWsConnected = false);
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('WS Connect Exception: $e');
      setState(() => _isWsConnected = false);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_isWsConnected) {
        _connectWebSocket();
      }
    });
  }

  Future<void> _callNextFarmer() async {
    final centreId = StaffService().centreId ?? 1;
    try {
      final result = await StaffService().callNextFarmer(centreId, _selectedCounterId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Called next farmer successfully!'),
            backgroundColor: const Color(0xFF1B5E20),
          ),
        );
        _loadQueueData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openWorkflowScreen(Map<String, dynamic> booking) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProcurementWorkflowScreen(
          bookingData: booking,
          onWorkflowCompleted: _loadQueueData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPaused = _dashboardData?['is_paused'] ?? false;
    final currentToken = _dashboardData?['current_token'] ?? 'None';
    final nextToken = _dashboardData?['next_token'] ?? 'None';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Queue Terminal'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: Chip(
              avatar: Icon(
                _isWsConnected ? Icons.wifi : Icons.wifi_off,
                size: 14,
                color: Colors.white,
              ),
              label: Text(
                _isWsConnected ? 'LIVE' : 'RECONNECTING',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              backgroundColor: _isWsConnected ? const Color(0xFF1B5E20) : Colors.orange.shade800,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadQueueData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadQueueData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isPaused) ...[
                Container(
                  color: Colors.red.shade100,
                  padding: const EdgeInsets.all(12),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'PAUSED: Centre operations are currently paused.',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Serving Terminal Display
              Card(
                color: const Color(0xFF1B5E20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Text(
                        'CURRENTLY SERVING TOKEN',
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentToken,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.next_plan, color: Colors.amber, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Next Token: $nextToken',
                            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // CALL NEXT FARMER Control Panel
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Queue Control Operator',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (_counters.isNotEmpty)
                        DropdownButtonFormField<int>(
                          value: _selectedCounterId,
                          decoration: const InputDecoration(
                            labelText: 'Assign to Active Counter',
                            border: OutlineInputBorder(),
                          ),
                          items: _counters.map((c) {
                            return DropdownMenuItem<int>(
                              value: c['id'],
                              child: Text('${c['counter_name']} (Counter #${c['counter_number']})'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCounterId = val);
                          },
                        ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        key: const Key('callNextFarmerBtn'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.record_voice_over, size: 24),
                        label: const Text(
                          'CALL NEXT FARMER',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        onPressed: isPaused ? null : _callNextFarmer,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Waiting Queue List',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20)))
              else if (_schedule.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'No farmers currently waiting in queue.',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _schedule.length,
                  itemBuilder: (context, idx) {
                    final item = Map<String, dynamic>.from(_schedule[idx]);
                    final token = item['token_number'];
                    final farmerName = item['farmer_name'] ?? 'Farmer';
                    final crop = item['crop_name'] ?? 'Crop';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF1B5E20),
                          child: Text(
                            '#$token',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(farmerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Crop: $crop | Status: ${item['queue_status']}'),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _openWorkflowScreen(item),
                          child: const Text('Process'),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
