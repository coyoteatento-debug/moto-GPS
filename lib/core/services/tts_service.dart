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
  if (text.isEmpty) return;
  if (_isSpeaking) return;
  if (text == _lastSpoken) return;
  _isSpeaking = true;
  _lastSpoken = text;
  try {
    await _tts.speak(text);
  } catch (_) {
    // Si falla, limpiamos para permitir reintento
    _lastSpoken = '';
  } finally {
    _isSpeaking = false;
    // Pequeño delay para evitar solapamiento entre instrucciones
    await Future.delayed(const Duration(milliseconds: 300));
  }
}

  Future<void> stop() async {
    _isSpeaking = false;       // ← agrega esta línea
    _lastSpoken = '';
    await _tts.stop();
  }

  void resetLastSpoken() => _lastSpoken = '';
}
