import 'package:flutter/material.dart';

class PaymentStatusScreen extends StatefulWidget {
  final String bookingRef;

  const PaymentStatusScreen({
    super.key,
    required this.bookingRef,
  });

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> {
  String _status = 'INITIATED';
  String _ref = 'SIM-DBT-202609-AB1234';
  double _amount = 43660.0;
  bool _isLoading = false;

  void _progressPayment() {
    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_status == 'INITIATED') {
            _status = 'PROCESSING';
          } else if (_status == 'PROCESSING') {
            _status = 'CREDITED';
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCredited = _status == 'CREDITED';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Status (DBT Direct Transfer)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // PROMINENT DEMO / SIMULATED BADGE
            Container(
              key: const Key('simulatedBadgeWidget'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade800, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.science, color: Colors.amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Demo / Simulated Payment System',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text('TOTAL MSP PAYMENT AMOUNT', style: TextStyle(color: Colors.grey, letterSpacing: 1.1)),
                    const SizedBox(height: 8),
                    Text(
                      '₹${_amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                    ),
                    const SizedBox(height: 12),
                    Text('Reference: $_ref', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCredited ? Colors.green.shade100 : Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'STATUS: $_status',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isCredited ? Colors.green.shade900 : Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            if (!isCredited) ...[
              ElevatedButton(
                key: const Key('progressPaymentBtn'),
                onPressed: _isLoading ? null : _progressPayment,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Simulate Step: Move to ${_status == "INITIATED" ? "PROCESSING" : "CREDITED"}'),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1B5E20)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle, color: Color(0xFF1B5E20)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Payment credited directly to linked bank account via DBT.',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
