import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class CentreDiscoveryScreen extends StatefulWidget {
  const CentreDiscoveryScreen({super.key});

  @override
  State<CentreDiscoveryScreen> createState() => _CentreDiscoveryScreenState();
}

class _CentreDiscoveryScreenState extends State<CentreDiscoveryScreen> {
  bool _isLoading = false;
  String _selectedCrop = 'Paddy';

  final List<Map<String, dynamic>> _mockCentres = [
    {
      'id': 1,
      'name': 'Mandya District Main Mandi',
      'code': 'MND_CENTRE_01',
      'type': 'GOVT_MANDI',
      'distance_km': 4.2,
      'queue_length': 3,
      'counters': 3,
      'est_wait_min': 15.0,
      'score': 7.68,
    },
    {
      'id': 2,
      'name': 'Mysore PACS Collection Point',
      'code': 'MYS_PACS_01',
      'type': 'PACS',
      'distance_km': 12.8,
      'queue_length': 1,
      'counters': 2,
      'est_wait_min': 7.5,
      'score': 8.32,
    },
    {
      'id': 3,
      'name': 'Hassan Sub-Procurement Hub',
      'code': 'HSN_SUB_01',
      'type': 'PRIVATE_SUB',
      'distance_km': 35.6,
      'queue_length': 8,
      'counters': 2,
      'est_wait_min': 60.0,
      'score': 39.84,
    },
  ];

  @override
  Widget build(BuildContext context) {
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
                    if (val != null) setState(() => _selectedCrop = val);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _mockCentres.length,
              itemBuilder: (context, idx) {
                final item = _mockCentres[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
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
                                item['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: item['type'] == 'PACS'
                                    ? Colors.orange.shade100
                                    : Colors.green.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item['type'],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: item['type'] == 'PACS'
                                      ? Colors.orange.shade900
                                      : Colors.green.shade900,
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
                              label: '${item['distance_km']} km away',
                            ),
                            _InfoChip(
                              icon: Icons.people_outline,
                              label: '${item['queue_length']} in queue',
                            ),
                            _InfoChip(
                              icon: Icons.timer_outlined,
                              label: '${item['est_wait_min']} min wait',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Rank #${idx + 1} (Score: ${item['score']})',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        Icon(icon, size: 16, color: const Color(0xFF1B5E20)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
