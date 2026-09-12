import 'package:flutter/material.dart';

class PacsReceiptScreen extends StatelessWidget {
  final Map<String, dynamic> collectionReceipt;
  final VoidCallback onDone;

  const PacsReceiptScreen({
    super.key,
    required this.collectionReceipt,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final recordId = collectionReceipt['id'] ?? 0;
    final farmerName = collectionReceipt['farmer_name'] ?? 'Farmer';
    final farmerPhone = collectionReceipt['farmer_phone'] ?? '';
    final cropName = collectionReceipt['crop_name'] ?? 'Paddy';
    final quantity = collectionReceipt['quantity_quintals'] ?? 0.0;
    final totalAmount = collectionReceipt['total_amount'] ?? 0.0;
    final pacsName = collectionReceipt['pacs_name'] ?? 'PACS Centre';
    final createdAt = collectionReceipt['created_at'] ?? '';
    final statusStr = collectionReceipt['status'] ?? 'COLLECTED_AT_PACS';

    return Scaffold(
      appBar: AppBar(
        title: const Text('PACS Collection Receipt'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade400),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, size: 36, color: Colors.green),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Collection Record Persisted',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                        ),
                        Text(
                          'Official PACS acknowledgement receipt generated.',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          const Icon(Icons.storefront, size: 48, color: Color(0xFF1B5E20)),
                          const SizedBox(height: 4),
                          Text(
                            pacsName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                          const Text(
                            'Primary Agricultural Credit Society Acknowledgement Receipt',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 32),
                    _ReceiptRow(label: 'Receipt / Collection ID', value: 'PACS-COL-#$recordId', isBold: true),
                    _ReceiptRow(label: 'Status', value: statusStr),
                    _ReceiptRow(label: 'Date & Time', value: createdAt),
                    const Divider(height: 24),
                    _ReceiptRow(label: 'Farmer Name', value: farmerName, isBold: true),
                    _ReceiptRow(label: 'Mobile Number', value: farmerPhone),
                    const Divider(height: 24),
                    _ReceiptRow(label: 'Crop Collected', value: cropName),
                    _ReceiptRow(label: 'Quantity Collected', value: '$quantity Quintals', isBold: true),
                    _ReceiptRow(label: 'Total Value (MSP)', value: '₹$totalAmount', isBold: true),
                    const Divider(height: 32),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Note: This collection receipt confirms physical receipt at PACS. Forwarding to the central mandi for weighing and payment processing is tracked in the app.',
                        style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              key: const Key('printReceiptBtn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.print),
              label: const Text('Print Acknowledgement Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Simulated printing PACS receipt...')),
                );
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('returnDashboardBtn'),
              onPressed: onDone,
              child: const Text('Return to PACS Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _ReceiptRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? const Color(0xFF1B5E20) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
