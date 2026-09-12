import 'package:flutter/material.dart';
import 'pacs_service.dart';
import 'pacs_receipt_screen.dart';

class PacsCollectionScreen extends StatefulWidget {
  final Map<String, dynamic>? initialFarmer;

  const PacsCollectionScreen({
    super.key,
    this.initialFarmer,
  });

  @override
  State<PacsCollectionScreen> createState() => _PacsCollectionScreenState();
}

class _PacsCollectionScreenState extends State<PacsCollectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _farmerPhoneController = TextEditingController();
  final _quantityController = TextEditingController(text: '30.0');
  final _amountController = TextEditingController();

  int? _selectedFarmerId;
  String _selectedFarmerName = '';
  int _selectedCropId = 1;
  String _selectedCropName = 'Paddy';
  double _mspPerQuintal = 2183.0;

  bool _isSubmitting = false;
  String? _errorMessage;
  Map<String, dynamic>? _createdReceipt;

  @override
  void initState() {
    super.initState();
    if (widget.initialFarmer != null) {
      _selectedFarmerId = widget.initialFarmer!['id'];
      _selectedFarmerName = widget.initialFarmer!['full_name'] ?? '';
      _farmerPhoneController.text = widget.initialFarmer!['phone_number'] ?? '';
    } else {
      _farmerPhoneController.text = '9876543201';
      _selectedFarmerId = 1;
      _selectedFarmerName = 'PACS Farmer';
    }
    _recalculateAmount();
  }

  void _recalculateAmount() {
    final qty = double.tryParse(_quantityController.text) ?? 0.0;
    final total = qty * _mspPerQuintal;
    _amountController.text = total.toStringAsFixed(2);
  }

  Future<void> _handleVerifyAndSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final qty = double.tryParse(_quantityController.text) ?? 0.0;
    if (qty <= 0) {
      setState(() {
        _errorMessage = 'Quantity must be greater than zero.';
      });
      return;
    }

    // Step 13: Lightweight Verification Modal
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified, color: Color(0xFF1B5E20)),
            SizedBox(width: 8),
            Text('Verify PACS Collection'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Farmer: ${_selectedFarmerName.isNotEmpty ? _selectedFarmerName : "Phone: ${_farmerPhoneController.text}"}'),
            const SizedBox(height: 6),
            Text('Crop: $_selectedCropName'),
            const SizedBox(height: 6),
            Text('Quantity: $qty Quintals'),
            const SizedBox(height: 6),
            Text('Calculated Value: ₹${_amountController.text}'),
            const SizedBox(height: 12),
            const Text(
              'Confirm that physical weight matches entry before submitting.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Edit Details'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm & Record'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final res = await PacsService().createCollection(
      farmerId: _selectedFarmerId ?? 1,
      cropId: _selectedCropId,
      quantityQuintals: qty,
      totalAmount: double.tryParse(_amountController.text),
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (res['success'] == true) {
        setState(() {
          _createdReceipt = res['data'];
        });
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Collection recording failed';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_createdReceipt != null) {
      return PacsReceiptScreen(
        collectionReceipt: _createdReceipt!,
        onDone: () {
          setState(() {
            _createdReceipt = null;
            _quantityController.text = '30.0';
            _recalculateAmount();
          });
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record PACS Collection Entry'),
      ),
      body: SingleChildScrollView(
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
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextFormField(
                controller: _farmerPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Farmer Mobile Number',
                  prefixIcon: Icon(Icons.phone_android),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter farmer mobile number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<int>(
                initialValue: _selectedCropId,
                decoration: const InputDecoration(
                  labelText: 'Select Crop',
                  prefixIcon: Icon(Icons.grass),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Paddy (Grade A) - ₹2183/Qtl')),
                  DropdownMenuItem(value: 2, child: Text('Wheat (FAQ) - ₹2275/Qtl')),
                  DropdownMenuItem(value: 3, child: Text('Maize - ₹2090/Qtl')),
                  DropdownMenuItem(value: 4, child: Text('Cotton - ₹6620/Qtl')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCropId = val;
                      if (val == 1) {
                        _selectedCropName = 'Paddy';
                        _mspPerQuintal = 2183.0;
                      } else if (val == 2) {
                        _selectedCropName = 'Wheat';
                        _mspPerQuintal = 2275.0;
                      } else if (val == 3) {
                        _selectedCropName = 'Maize';
                        _mspPerQuintal = 2090.0;
                      } else {
                        _selectedCropName = 'Cotton';
                        _mspPerQuintal = 6620.0;
                      }
                      _recalculateAmount();
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                key: const Key('pacsQuantityField'),
                controller: _quantityController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Measured Quantity Collected (Quintals)',
                  prefixIcon: Icon(Icons.scale),
                  suffixText: 'Quintals',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _recalculateAmount(),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter quantity';
                  final q = double.tryParse(val);
                  if (q == null || q <= 0) return 'Quantity must be greater than zero';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _amountController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Calculated MSP Value (₹)',
                  prefixIcon: Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(),
                  filled: true,
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                key: const Key('saveCollectionBtn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _isSubmitting ? null : _handleVerifyAndSubmit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Verify & Submit PACS Collection',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
