import 'package:flutter/material.dart';

class PacsCollectionScreen extends StatefulWidget {
  const PacsCollectionScreen({super.key});

  @override
  State<PacsCollectionScreen> createState() => _PacsCollectionScreenState();
}

class _PacsCollectionScreenState extends State<PacsCollectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _farmerPhoneController = TextEditingController(text: '9876543201');
  final _quantityController = TextEditingController(text: '30.0');
  final _amountController = TextEditingController(text: '65490.0');
  String _selectedCrop = 'Paddy';

  bool _isForwarded = false;
  String? _forwardedStatus;

  void _submitCollection() {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _forwardedStatus = 'Collected at PACS (Receipt Issued to Farmer)';
    });
  }

  void _forwardToCentre() {
    setState(() {
      _isForwarded = true;
      _forwardedStatus = 'FORWARDED_TO_CENTRE (Mandya Main Mandi)';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PACS Collection & Forwarding'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_forwardedStatus != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isForwarded ? Colors.green.shade100 : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _forwardedStatus!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isForwarded ? Colors.green.shade900 : Colors.blue.shade900,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _farmerPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Farmer Mobile Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCrop,
                decoration: const InputDecoration(
                  labelText: 'Crop Type',
                  border: OutlineInputBorder(),
                ),
                items: ['Paddy', 'Wheat', 'Maize', 'Cotton'].map((c) {
                  return DropdownMenuItem(value: c, child: Text(c));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCrop = val);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity Collected (Quintals)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Calculated Amount (₹)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                key: const Key('saveCollectionBtn'),
                onPressed: _submitCollection,
                child: const Text('Record Collection & Print Ack Receipt'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('forwardCentreBtn'),
                onPressed: _forwardedStatus == null ? null : _forwardToCentre,
                child: const Text('Forward Batch to Main Procurement Centre'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
