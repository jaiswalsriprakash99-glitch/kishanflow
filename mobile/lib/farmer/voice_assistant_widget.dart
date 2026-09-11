import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class VoiceAssistantWidget extends StatefulWidget {
  final bool isSpeechAvailable;
  final int? queueNumber;
  final double? estimatedWaitMinutes;
  final String? recommendedArrivalTime;

  const VoiceAssistantWidget({
    super.key,
    this.isSpeechAvailable = false,
    this.queueNumber = 7,
    this.estimatedWaitMinutes = 25.0,
    this.recommendedArrivalTime = "10:15 AM",
  });

  @override
  State<VoiceAssistantWidget> createState() => _VoiceAssistantWidgetState();
}

class _VoiceAssistantWidgetState extends State<VoiceAssistantWidget> {
  bool _isListening = false;
  String _spokenText = '';
  String _responseMessage = '';

  void _handleVoiceCommand(String command) {
    final lower = command.toLowerCase();
    if (lower.contains('turn') || lower.contains('wait') || lower.contains('बारी') || lower.contains('कब')) {
      setState(() {
        _responseMessage = 'Your estimated wait time is ${widget.estimatedWaitMinutes} minutes. Recommended arrival: ${widget.recommendedArrivalTime}.';
      });
    } else if (lower.contains('number') || lower.contains('queue') || lower.contains('नंबर')) {
      setState(() {
        _responseMessage = 'Your queue ticket number is #${widget.queueNumber}.';
      });
    } else {
      setState(() {
        _responseMessage = 'Sorry, I did not recognize that query. Try asking "when is my turn".';
      });
    }
  }

  void _toggleListening() {
    if (!widget.isSpeechAvailable) {
      setState(() {
        _responseMessage = 'Speech recognition unavailable on this device. Using text mode.';
      });
      return;
    }

    setState(() {
      _isListening = !_isListening;
    });

    if (_isListening) {
      // Simulate speech recognition result after 1 second
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _isListening = false;
            _spokenText = 'When is my turn?';
          });
          _handleVoiceCommand(_spokenText);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      color: Colors.green.shade50,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: widget.isSpeechAvailable ? const Color(0xFF1B5E20) : Colors.grey,
                  child: IconButton(
                    icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white),
                    onPressed: _toggleListening,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Voice Assistance (Optional)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        widget.isSpeechAvailable
                            ? (_isListening ? 'Listening...' : 'Tap mic to ask "When is my turn"')
                            : 'Speech recognition unavailable',
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_spokenText.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('You asked: "$_spokenText"', style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
            if (_responseMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1B5E20)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.volume_up, color: Color(0xFF1B5E20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _responseMessage,
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
