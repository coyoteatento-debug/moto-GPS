import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Detecta si hay internet disponible.
/// Permite a la app decidir si usar tiles de red o caché local.
class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();
  static final StreamController<bool> _controller =
      StreamController<bool>.broadcast();

  static StreamSubscription? _subscription;
  static bool _isOnline = true;

  // ─────────────────────────────────────────────────
  // ESTADO ACTUAL
  // ─────────────────────────────────────────────────
  static bool get isOnline => _isOnline;

  // ─────────────────────────────────────────────────
  // STREAM DE CAMBIOS
  // ─────────────────────────────────────────────────
  static Stream<bool> get onConnectivityChanged => _controller.stream;

  // ─────────────────────────────────────────────────
  // INICIALIZAR — Llamar en main() antes de runApp()
  // ─────────────────────────────────────────────────
  static Future<void> initialize() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = _isConnected(result);

    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      final online = _isConnected(result);
      if (online != _isOnline) {
        _isOnline = online;
        _controller.add(_isOnline);
      }
    });
  }

  static bool _isConnected(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);
  }

  static void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
