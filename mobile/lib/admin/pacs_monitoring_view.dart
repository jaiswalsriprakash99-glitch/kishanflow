import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PacsMonitoringView extends StatefulWidget {
  const PacsMonitoringView({super.key});

  @override
  State<PacsMonitoringView> createState() => _PacsMonitoringViewState();
}

class _PacsMonitoringViewState extends State<PacsMonitoringView> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _pacsData;

  @override
  void initState() {
    super.initState();
    _loadPacs();
  }

  Future<void> _loadPacs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await ApiService().getPACSOverview();
      if (mounted) {
        setState(() {
          _pacsData = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20)));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadPacs, child: const Text('Retry')),
          ],
        ),
      );
    }

    final d = _pacsData!;
    final totalPacs = d['total_pacs'] ?? 0;
    final vol = (d['total_collection_volume_quintals'] ?? 0.0).toDouble();
    final pacsList = (d['pacs'] as List<dynamic>?) ?? [];

    return RefreshIndicator(
      onRefresh: _loadPacs,
      color: const Color(0xFF1B5E20),
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Banner
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: const Color(0xFFE8F5E9),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF1B5E20),
                    child: Icon(Icons.storefront, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Primary Agricultural Credit Societies',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalPacs Active PACS · $vol Qtl Collected',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text('Registered PACS Collection Hubs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          ...pacsList.map((p) {
            final pName = p['name'] ?? '';
            final pCode = p['code'] ?? '';
            final district = p['district'] ?? '';
            final state = p['state'] ?? '';
            final linkedCentre = p['linked_centre_name'] ?? 'Direct Mandi';
            final pVol = (p['collection_volume_quintals'] ?? 0.0).toDouble();
            final farmers = p['total_farmers'] ?? 0;
            final fwdStatus = p['forwarding_status'] ?? 'FORWARDED';

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.only(bottom: 12),
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
                            pName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Text(
                            fwdStatus,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('$district, $state ($pCode)', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Linked Govt Mandi:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text(linkedCentre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Collection Volume:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text('$pVol Qtl ($farmers Farmers)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1B5E20))),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
