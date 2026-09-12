import 'package:flutter/material.dart';
import '../services/api_service.dart';

class FarmerBookingSearchView extends StatefulWidget {
  const FarmerBookingSearchView({super.key});

  @override
  State<FarmerBookingSearchView> createState() => _FarmerBookingSearchViewState();
}

class _FarmerBookingSearchViewState extends State<FarmerBookingSearchView> {
  final _searchController = TextEditingController(text: 'Ramesh');
  bool _isLoading = false;
  String? _error;
  List<dynamic> _results = [];
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _performSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _hasSearched = true;
    });

    try {
      final res = await ApiService().search(query);
      if (mounted) {
        setState(() {
          _results = res;
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
    return Column(
      children: [
        // Search Input Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by Farmer, Booking ref, or Phone...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _results = []);
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _performSearch(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _performSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Search'),
              ),
            ],
          ),
        ),

        // Result list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20)))
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(_error!, style: const TextStyle(color: Colors.red)),
                      ),
                    )
                  : _results.isEmpty && _hasSearched
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text('No records matched your search query.'),
                              const SizedBox(height: 4),
                              Text('Try searching "Gowda", "SYNTH", or "PAY"', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final item = _results[index] as Map<String, dynamic>;
                            final type = item['type'] as String? ?? 'RECORD';
                            final title = item['title'] as String? ?? '';
                            final subtitle = item['subtitle'] as String? ?? '';
                            final ref = item['reference'] as String? ?? '';
                            final status = item['status'] as String? ?? '';

                            IconData icon;
                            Color iconColor;

                            switch (type) {
                              case 'FARMER':
                                icon = Icons.person;
                                iconColor = Colors.green;
                                break;
                              case 'BOOKING':
                                icon = Icons.confirmation_number_outlined;
                                iconColor = Colors.blue;
                                break;
                              case 'PAYMENT':
                                icon = Icons.currency_rupee;
                                iconColor = Colors.orange;
                                break;
                              default:
                                icon = Icons.folder_open;
                                iconColor = Colors.purple;
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: iconColor.withOpacity(0.12),
                                  child: Icon(icon, color: iconColor),
                                ),
                                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text(ref.isNotEmpty ? '$subtitle • $ref' : subtitle, style: const TextStyle(fontSize: 12)),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Text(type, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: status == 'COMPLETED' || status == 'CREDITED' || status == 'ACTIVE' ? Colors.green : Colors.orange)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
