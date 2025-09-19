// lib/services/tts_service.dart
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _inited = false;

  Future<void> _ensureInit() async {
    if (_inited) return;
    // Hindi voice
    await _tts.setLanguage('hi-IN');
    await _tts.setSpeechRate(0.9);   // slower for clarity
    await _tts.setPitch(1.0);
    _inited = true;
  }

  Future<void> speakHindi(String text) async {
    if (text.trim().isEmpty) return;
    await _ensureInit();
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}