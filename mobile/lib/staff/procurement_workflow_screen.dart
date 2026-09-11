import 'package:flutter/material.dart';
import 'staff_service.dart';

class ProcurementWorkflowScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final VoidCallback? onWorkflowCompleted;

  const ProcurementWorkflowScreen({
    super.key,
    required this.bookingData,
    this.onWorkflowCompleted,
  });

  @override
  State<ProcurementWorkflowScreen> createState() => _ProcurementWorkflowScreenState();
}

class _ProcurementWorkflowScreenState extends State<ProcurementWorkflowScreen> {
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Verification Form State
  bool _isVerified = true;
  final _verificationReasonController = TextEditingController();

  // Quality Check Form State
  final _moistureController = TextEditingController(text: '14.0');
  final _foreignMatterController = TextEditingController(text: '1.0');
  final _brokenGrainsController = TextEditingController(text: '2.0');
  String _selectedGrade = 'Grade A';
  final _rejectionReasonController = TextEditingController();

  // Weighment Form State
  final _grossWeightController = TextEditingController();
  final _tareWeightController = TextEditingController(text: '50.0');
  final _bagsCountController = TextEditingController(text: '50');
  double _computedNetKg = 0.0;
  double _computedNetQuintals = 0.0;

  @override
  void initState() {
    super.initState();
    final declQty = (widget.bookingData['estimated_quantity_quintals'] ?? 20.0) as double;
    final estimatedGrossKg = (declQty * 100.0) + 50.0;
    _grossWeightController.text = estimatedGrossKg.toStringAsFixed(1);
    _calculateNetWeight();
  }

  @override
  void dispose() {
    _verificationReasonController.dispose();
    _moistureController.dispose();
    _foreignMatterController.dispose();
    _brokenGrainsController.dispose();
    _rejectionReasonController.dispose();
    _grossWeightController.dispose();
    _tareWeightController.dispose();
    _bagsCountController.dispose();
    super.dispose();
  }

  void _calculateNetWeight() {
    final gross = double.tryParse(_grossWeightController.text.trim()) ?? 0.0;
    final tare = double.tryParse(_tareWeightController.text.trim()) ?? 0.0;
    final net = gross - tare;
    setState(() {
      _computedNetKg = net > 0 ? net : 0.0;
      _computedNetQuintals = _computedNetKg / 100.0;
    });
  }

  Future<void> _handleVerification() async {
    final bookingId = widget.bookingData['booking_id'];
    setState(() => _isSubmitting = true);
    try {
      await StaffService().verifyTicket(
        bookingId,
        _isVerified,
        failureReason: _isVerified ? null : _verificationReasonController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _currentStep = 1; // Move to Quality Check
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleQualityCheck(bool passed) async {
    final bookingId = widget.bookingData['booking_id'];
    final moisture = double.tryParse(_moistureController.text.trim()) ?? 14.0;
    final foreign = double.tryParse(_foreignMatterController.text.trim()) ?? 1.0;
    final broken = double.tryParse(_brokenGrainsController.text.trim()) ?? 2.0;
    final rejectionReason = _rejectionReasonController.text.trim();

    if (!passed && rejectionReason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rejection reason is mandatory when rejecting batch.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await StaffService().submitQualityCheck(
        bookingId: bookingId,
        moisturePercent: moisture,
        foreignMatterPercent: foreign,
        brokenGrainsPercent: broken,
        grade: _selectedGrade,
        passed: passed,
        rejectionReason: passed ? null : rejectionReason,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (passed) {
          setState(() => _currentStep = 2); // Move to Weighment
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Batch Marked QUALITY_REJECTED'), backgroundColor: Colors.red),
          );
          widget.onWorkflowCompleted?.call();
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleWeighment() async {
    final bookingId = widget.bookingData['booking_id'];
    final gross = double.tryParse(_grossWeightController.text.trim()) ?? 0.0;
    final tare = double.tryParse(_tareWeightController.text.trim()) ?? 0.0;
    final bags = int.tryParse(_bagsCountController.text.trim()) ?? 1;

    if (gross <= tare) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gross weight must be greater than tare weight.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await StaffService().submitWeighment(
        bookingId: bookingId,
        grossWeightKg: gross,
        tareWeightKg: tare,
        bagsCount: bags,
      );
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _currentStep = 3; // Move to Completion
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleCompletion() async {
    final bookingId = widget.bookingData['booking_id'];
    setState(() => _isSubmitting = true);
    try {
      await StaffService().completeProcurement(bookingId);
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Procurement Successfully Completed!'),
            backgroundColor: Color(0xFF1B5E20),
          ),
        );
        widget.onWorkflowCompleted?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmerName = widget.bookingData['farmer_name'] ?? 'Farmer';
    final token = widget.bookingData['token_number'] ?? 0;
    final ref = widget.bookingData['booking_reference'] ?? 'REF';
    final crop = widget.bookingData['crop_name'] ?? 'Crop';
    final declQty = widget.bookingData['estimated_quantity_quintals'] ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Processing Token #$token'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Farmer / Ticket Summary Card
            Card(
              elevation: 3,
              color: const Color(0xFFE8F5E9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          farmerName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                        ),
                        Chip(
                          label: Text('#$token', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          backgroundColor: const Color(0xFF1B5E20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Ref: $ref', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Crop: $crop', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('Declared: $declQty Qtl', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Stepper Workflow
            Stepper(
              physics: const NeverScrollableScrollPhysics(),
              currentStep: _currentStep,
              onStepTapped: (step) {
                if (step <= _currentStep) {
                  setState(() => _currentStep = step);
                }
              },
              controlsBuilder: (context, details) => const SizedBox.shrink(),
              steps: [
                // STEP 1: VERIFICATION
                Step(
                  title: const Text('1. Ticket Verification', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Verify farmer ID and slot booking'),
                  isActive: _currentStep >= 0,
                  state: _currentStep > 0 ? StepState.complete : StepState.editing,
                  content: Column(
                    children: [
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        title: const Text('Farmer Identity & QR Ticket Verified'),
                        subtitle: const Text('Documents match farmer details'),
                        value: _isVerified,
                        activeColor: const Color(0xFF1B5E20),
                        onChanged: (val) => setState(() => _isVerified = val ?? true),
                      ),
                      if (!_isVerified)
                        TextField(
                          controller: _verificationReasonController,
                          decoration: const InputDecoration(
                            labelText: 'Failure Reason',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_circle_outline),
                        label: const Text('CONFIRM VERIFICATION'),
                        onPressed: _isSubmitting ? null : _handleVerification,
                      ),
                    ],
                  ),
                ),

                // STEP 2: QUALITY CHECK
                Step(
                  title: const Text('2. Quality Inspection', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Record moisture, foreign matter & grade'),
                  isActive: _currentStep >= 1,
                  state: _currentStep > 1 ? StepState.complete : (_currentStep == 1 ? StepState.editing : StepState.disabled),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _moistureController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Moisture (%)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _foreignMatterController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Foreign Matter (%)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _brokenGrainsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Broken Grains (%)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedGrade,
                              decoration: const InputDecoration(
                                labelText: 'Grade',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Grade A', child: Text('Grade A')),
                                DropdownMenuItem(value: 'Grade B', child: Text('Grade B')),
                                DropdownMenuItem(value: 'Standard', child: Text('Standard')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedGrade = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _rejectionReasonController,
                        decoration: const InputDecoration(
                          labelText: 'Rejection Reason (If rejecting)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1B5E20),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.thumb_up),
                              label: const Text('PASS QUALITY'),
                              onPressed: _isSubmitting ? null : () => _handleQualityCheck(true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.thumb_down),
                              label: const Text('REJECT BATCH'),
                              onPressed: _isSubmitting ? null : () => _handleQualityCheck(false),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // STEP 3: WEIGHMENT
                Step(
                  title: const Text('3. Weighbridge Measurement', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Record gross & tare weights'),
                  isActive: _currentStep >= 2,
                  state: _currentStep > 2 ? StepState.complete : (_currentStep == 2 ? StepState.editing : StepState.disabled),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _grossWeightController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Gross Weight (kg)',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (val) => _calculateNetWeight(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _tareWeightController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Tare Weight (kg)',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (val) => _calculateNetWeight(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _bagsCountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Bags Count',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Computed Net Quantity:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              '${_computedNetKg.toStringAsFixed(1)} kg (${_computedNetQuintals.toStringAsFixed(2)} Qtl)',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.scale),
                        label: const Text('SUBMIT WEIGHMENT'),
                        onPressed: _isSubmitting ? null : _handleWeighment,
                      ),
                    ],
                  ),
                ),

                // STEP 4: COMPLETE PROCUREMENT
                Step(
                  title: const Text('4. Complete Procurement', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Finalize record & generate receipt'),
                  isActive: _currentStep >= 3,
                  state: _currentStep == 3 ? StepState.editing : StepState.disabled,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.verified, size: 48, color: Color(0xFF1B5E20)),
                            const SizedBox(height: 8),
                            const Text(
                              'Ready for Procurement Completion',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text('Net Weight: ${_computedNetQuintals.toStringAsFixed(2)} Quintals'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 22),
                        label: const Text('COMPLETE PROCUREMENT & ADVANCE QUEUE'),
                        onPressed: _isSubmitting ? null : _handleCompletion,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
