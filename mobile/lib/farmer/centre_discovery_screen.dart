import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'slot_booking_screen.dart';

class CentreDiscoveryScreen extends StatefulWidget {
  const CentreDiscoveryScreen({super.key});

  @override
  State<CentreDiscoveryScreen> createState() => _CentreDiscoveryScreenState();
}

class _CentreDiscoveryScreenState extends State<CentreDiscoveryScreen> {
  bool _isLoading = false;
  String _selectedCrop = 'Paddy';
  List<Map<String, dynamic>> _centres = [];

  final List<Map<String, dynamic>> _fallbackCentres = [
    {
      'id': 1,
      'name': 'Mandya District Main Mandi',
      'code': 'MND_CENTRE_01',
      'type': 'GOVT_MANDI',
      'distance_km': 4.2,
      'queue_length': 0,
      'counters': 3,
      'est_wait_min': 0.0,
      'score': 7.68,
    },
    {
      'id': 2,
      'name': 'Mysore PACS Collection Point',
      'code': 'MYS_PACS_01',
      'type': 'PACS',
      'distance_km': 12.8,
      'queue_length': 0,
      'counters': 2,
      'est_wait_min': 0.0,
      'score': 8.32,
    },
    {
      'id': 3,
      'name': 'Hassan Sub-Procurement Hub',
      'code': 'HSN_SUB_01',
      'type': 'PRIVATE_SUB',
      'distance_km': 35.6,
      'queue_length': 0,
      'counters': 2,
      'est_wait_min': 0.0,
      'score': 39.84,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadCentres();
  }

  int _cropNameToId(String name) {
    switch (name) {
      case 'Paddy':
        return 1;
      case 'Wheat':
        return 2;
      case 'Maize':
        return 3;
      case 'Cotton':
        return 4;
      case 'Mustard':
        return 5;
      default:
        return 1;
    }
  }

  Future<void> _loadCentres() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService().getRankedCentres(cropType: _selectedCrop);
      if (mounted) {
        if (res.isNotEmpty) {
          setState(() {
            _centres = res.map((c) => Map<String, dynamic>.from(c as Map)).toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _centres = List.from(_fallbackCentres);
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _centres = List.from(_fallbackCentres);
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayCentres = _centres.isNotEmpty ? _centres : _fallbackCentres;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Centre Discovery & Comparison'),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.green.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.tune, color: Color(0xFF1B5E20)),
                const SizedBox(width: 12),
                const Text('Filter Crop: ', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: _selectedCrop,
                  items: ['Paddy', 'Wheat', 'Maize', 'Cotton'].map((c) {
                    return DropdownMenuItem(value: c, child: Text(c));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedCrop = val);
                      _loadCentres();
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20)))
                : RefreshIndicator(
                    onRefresh: _loadCentres,
                    color: const Color(0xFF1B5E20),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: displayCentres.length,
                      itemBuilder: (context, idx) {
                        final item = displayCentres[idx];
                        final centreType = (item['centre_type'] ?? item['type'] ?? 'CENTRE').toString();
                        final isPacs = centreType == 'PACS';
                        final dist = (item['distance_km'] ?? 0.0).toString();
                        final qLen = (item['current_queue_length'] ?? item['queue_length'] ?? 0).toString();
                        final waitMin = (item['estimated_wait_minutes'] ?? item['est_wait_min'] ?? 0.0).toString();
                        final score = (item['ranking_score'] ?? item['score'] ?? 0.0).toString();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['name']?.toString() ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isPacs ? Colors.orange.shade100 : Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        centreType,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isPacs ? Colors.orange.shade900 : Colors.green.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _InfoChip(
                                      icon: Icons.navigation_outlined,
                                      label: '$dist km away',
                                    ),
                                    _InfoChip(
                                      icon: Icons.people_outline,
                                      label: '$qLen in queue',
                                    ),
                                    _InfoChip(
                                      icon: Icons.timer_outlined,
                                      label: '$waitMin min wait',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Text(
                                      'Rank #${idx + 1} (Score: $score)',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                    const Spacer(),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => SlotBookingScreen(
                                              centreId: (item['id'] as num).toInt(),
                                              centreName: item['name']?.toString() ?? 'Centre',
                                              cropId: _cropNameToId(_selectedCrop),
                                              cropName: _selectedCrop,
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        backgroundColor: const Color(0xFF1B5E20),
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('View Slots & Book'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
      ],
    );
  }
}
