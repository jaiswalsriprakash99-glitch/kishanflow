import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class FarmerProfileScreen extends StatefulWidget {
  final bool isOffline;
  final String? cachedTimestamp;

  const FarmerProfileScreen({
    super.key,
    this.isOffline = false,
    this.cachedTimestamp,
  });

  @override
  State<FarmerProfileScreen> createState() => _FarmerProfileScreenState();
}

class _FarmerProfileScreenState extends State<FarmerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Ramesh Gowda');
  final _villageController = TextEditingController(text: 'Srirangapatna');
  final _districtController = TextEditingController(text: 'Mandya');
  final _stateController = TextEditingController(text: 'Karnataka');
  final _acreageController = TextEditingController(text: '5.5');
  final _bankController = TextEditingController(text: '501002349801');
  final _ifscController = TextEditingController(text: 'SBIN0001234');

  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isSuccess = false;
    });

    await Future.delayed(const Duration(milliseconds: 800));

    if (widget.isOffline) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Saved to local offline cache (Sync pending)';
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _isSuccess = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmer Profile Setup'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isOffline) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade700),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off, color: Colors.amber),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Offline Mode - Cached at ${widget.cachedTimestamp ?? "10:30 AM"}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade900)),
                ),
                const SizedBox(height: 16),
              ],
              if (_isSuccess) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Profile saved successfully!', style: TextStyle(color: Colors.green)),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                key: const Key('nameField'),
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter full name' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _villageController,
                      decoration: const InputDecoration(labelText: 'Village', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _districtController,
                      decoration: const InputDecoration(labelText: 'District', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('acreageField'),
                controller: _acreageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total Land Acreage (Acres)', border: OutlineInputBorder()),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter acreage';
                  if (double.tryParse(val) == null || double.parse(val) <= 0) return 'Invalid acreage';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bankController,
                decoration: const InputDecoration(labelText: 'Bank Account Number', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ifscController,
                decoration: const InputDecoration(labelText: 'IFSC Code', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                key: const Key('saveProfileBtn'),
                onPressed: _isLoading ? null : _saveProfile,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Profile Details'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
