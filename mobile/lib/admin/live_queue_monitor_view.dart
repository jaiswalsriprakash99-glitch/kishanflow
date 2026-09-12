import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LiveQueueMonitorView extends StatefulWidget {
  final int centreId;
  final String centreName;

  const LiveQueueMonitorView({
    super.key,
    required this.centreId,
    required this.centreName,
  });

  @override
  State<LiveQueueMonitorView> createState() => _LiveQueueMonitorViewState();
}

class _LiveQueueMonitorViewState extends State<LiveQueueMonitorView> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _queueEntries = [];
  WebSocket? _webSocket;
  bool _isWsConnected = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchQueue();
    _connectWebSocket();
    // 10-second background polling fallback
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchQueue(silent: true));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _webSocket?.close();
    super.dispose();
  }

  Future<void> _fetchQueue({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final res = await ApiService().getCentreDetails(widget.centreId);
      if (mounted) {
        setState(() {
          _queueEntries = (res['live_queue'] as List<dynamic>?) ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _connectWebSocket() async {
    try {
      _webSocket = await ApiService().connectQueueWebSocket(
        widget.centreId,
        onMessage: (message) {
          if (mounted) {
            _fetchQueue(silent: true);
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() => _isWsConnected = false);
          }
        },
        onDone: () {
          if (mounted) {
            setState(() => _isWsConnected = false);
          }
        },
      );

      if (_webSocket != null && mounted) {
        setState(() => _isWsConnected = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isWsConnected = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final waitingEntries = _queueEntries.where((e) => e['status'] == 'WAITING').toList();
    final processingEntries = _queueEntries.where((e) => e['status'] == 'PROCESSING').toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.centreName, style: const TextStyle(fontSize: 16)),
            Text(
              _isWsConnected ? '● Live WebSocket Stream' : '○ REST Polling (10s sync)',
              style: TextStyle(
                fontSize: 11,
                color: _isWsConnected ? Colors.lightGreenAccent : Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchQueue(),
            tooltip: 'Sync Queue',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 40, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: () => _fetchQueue(), child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchQueue,
                  color: const Color(0xFF1B5E20),
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      // Overview Banner
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: const Color(0xFFE8F5E9),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _SummaryStat(
                                label: 'Currently Processing',
                                value: '${processingEntries.length}',
                                color: Colors.indigo,
                              ),
                              Container(width: 1, height: 36, color: Colors.grey.shade300),
                              _SummaryStat(
                                label: 'Waiting in Queue',
                                value: '${waitingEntries.length}',
                                color: waitingEntries.length > 5 ? Colors.orange : const Color(0xFF1B5E20),
                              ),
                              Container(width: 1, height: 36, color: Colors.grey.shade300),
                              _SummaryStat(
                                label: 'Est. Queue Wait',
                                value: '${waitingEntries.length * 15}m',
                                color: Colors.teal,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Section: Currently Called at Counters
                      const Text(
                        'Active Counters (Being Served)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (processingEntries.isEmpty)
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: Text(
                                'No farmer currently being served at counters.',
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ),
                          ),
                        )
                      else
                        ...processingEntries.map((item) {
                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: Colors.indigo, width: 1.5),
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.indigo.shade50,
                                child: Text(
                                  '#${item['queue_number']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                                ),
                              ),
                              title: Text(item['farmer_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '${item['crop_name']} (${item['estimated_quantity']} Qtl) · Counter #${item['counter_id'] ?? 1}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'PROCESSING',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo),
                                ),
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 20),

                      // Section: Waiting Queue
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Queue Line (Ordered by Position)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text('${waitingEntries.length} waiting', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (waitingEntries.isEmpty)
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: const Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Center(
                              child: Text(
                                'The queue is currently clear.',
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ),
                          ),
                        )
                      else
                        ...waitingEntries.map((item) {
                          final pos = item['position'] ?? 0;
                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFE8F5E9),
                                child: Text(
                                  '$pos',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                                ),
                              ),
                              title: Text(item['farmer_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                'Token #${item['queue_number']} · Ref: ${item['booking_reference']}\n${item['crop_name']} · ${item['estimated_quantity']} Quintals',
                                style: const TextStyle(fontSize: 12),
                              ),
                              isThreeLine: true,
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.orange.shade300),
                                    ),
                                    child: const Text(
                                      'WAITING',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange),
                                    ),
                                  ),
                                  if (item['check_in_time'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text('In: ${item['check_in_time']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
