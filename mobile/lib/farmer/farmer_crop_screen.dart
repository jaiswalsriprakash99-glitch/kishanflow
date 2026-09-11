import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class FarmerCropScreen extends StatefulWidget {
  final bool isOffline;

  const FarmerCropScreen({
    super.key,
    this.isOffline = false,
  });

  @override
  State<FarmerCropScreen> createState() => _FarmerCropScreenState();
}

class _FarmerCropScreenState extends State<FarmerCropScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCrop = 'Paddy';
  final _qtyController = TextEditingController();
  final _areaController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  final List<String> _cropsList = ['Paddy', 'Wheat', 'Maize', 'Cotton', 'Mustard'];

  Future<void> _submitCropEntry() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 600));

    if (widget.isOffline) {
      setState(() {
        _isLoading = false;
        _successMessage = 'Crop entry saved to offline cache';
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _successMessage = 'Crop record registered successfully!';
      _qtyController.clear();
      _areaController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Registration'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              if (_successMessage != null) ...[
                Container(
                  key: const Key('successMsg'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_successMessage!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
              ],
              DropdownButtonFormField<String>(
                key: const Key('cropDropdown'),
                value: _selectedCrop,
                decoration: const InputDecoration(
                  labelText: 'Select Crop Type',
                  border: OutlineInputBorder(),
                ),
                items: _cropsList.map((crop) {
                  return DropdownMenuItem(value: crop, child: Text(crop));
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedCrop = val);
                },
                validator: (val) => val == null ? 'Please select a crop' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('qtyField'),
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Estimated Produce Quantity (Quintals)',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Quantity is required';
                  }
                  final parsed = double.tryParse(val);
                  if (parsed == null || parsed <= 0) {
                    return 'Please enter a valid positive quantity';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('areaField'),
                controller: _areaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cultivated Land Area (Acres)',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Land area is required';
                  }
                  final parsed = double.tryParse(val);
                  if (parsed == null || parsed <= 0) {
                    return 'Please enter valid acreage';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                key: const Key('submitCropBtn'),
                onPressed: _isLoading ? null : _submitCropEntry,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Register Crop Details'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
