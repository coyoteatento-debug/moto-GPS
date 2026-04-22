import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  String _lastSpoken = '';

  Future<void> init() async {
    await _tts.setLanguage('es-MX');
    await _tts.setSpeechRate(0.52);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> speak(String text) async {
    if (text.isEmpty || text == _lastSpoken) return;
    if (_isSpeaking) return;
    _lastSpoken = text;
    _isSpeaking = true;
    try {
      await _tts.speak(text);
    } catch (_) {
      _lastSpoken = '';
    } finally {
      _isSpeaking = false;
    }
  }

  Future<void> stop() async {
    await _tts.stop();
    _lastSpoken = '';
  }

  void resetLastSpoken() => _lastSpoken = '';
}
