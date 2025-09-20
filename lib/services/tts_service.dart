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

  Future<void> setRate(double rate) async {
    // flutter_tts expects 0.0–1.0 (platform normalizes)
    final clamped = rate.clamp(0.1, 1.0);
    await _tts.setSpeechRate(clamped);
  }

  Future<void> speakHindi(String text, {double? rate}) async {
    if (rate != null) await setRate(rate);
    await _tts.setLanguage('hi-IN');
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}