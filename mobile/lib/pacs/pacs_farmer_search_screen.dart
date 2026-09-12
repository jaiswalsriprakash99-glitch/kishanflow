import 'package:flutter/material.dart';
import 'pacs_service.dart';

class PacsFarmerSearchScreen extends StatefulWidget {
  final Function(Map<String, dynamic> farmer) onFarmerSelected;

  const PacsFarmerSearchScreen({
    super.key,
    required this.onFarmerSelected,
  });

  @override
  State<PacsFarmerSearchScreen> createState() => _PacsFarmerSearchScreenState();
}

class _PacsFarmerSearchScreenState extends State<PacsFarmerSearchScreen> {
  final _searchController = TextEditingController(text: '98765');
  bool _isLoading = false;
  List<dynamic> _farmers = [];

  @override
  void initState() {
    super.initState();
    _performSearch();
  }

  Future<void> _performSearch() async {
    setState(() {
      _isLoading = true;
    });

    final results = await PacsService().searchFarmers(_searchController.text.trim());

    if (mounted) {
      setState(() {
        _isLoading = false;
        _farmers = results;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmer Search (PACS Scope)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              key: const Key('farmerSearchInput'),
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by Farmer Phone / Name / ID',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _performSearch,
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_farmers.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      const Text(
                        'No authorized farmers found matching search query.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _performSearch,
                        child: const Text('Refresh Search'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _farmers.length,
                  itemBuilder: (context, index) {
                    final farmer = _farmers[index] as Map<String, dynamic>;
                    return Card(
                      key: Key('farmerCard_${farmer["id"]}'),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE8F5E9),
                          child: Icon(Icons.person, color: Color(0xFF1B5E20)),
                        ),
                        title: Text(
                          farmer['full_name'] ?? 'Unknown Farmer',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Phone: ${farmer["phone_number"]} | Village: ${farmer["village"] ?? "Mysore Village"}',
                        ),
                        trailing: ElevatedButton(
                          key: Key('selectFarmerBtn_${farmer["id"]}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => widget.onFarmerSelected(farmer),
                          child: const Text('Select'),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
