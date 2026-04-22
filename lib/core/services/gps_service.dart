import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class GpsService {
  const GpsService();

  // ── Permisos ──────────────────────────────────────────
  Future<bool> requestPermissions() async {
    final status = await Permission.locationWhenInUse.request();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    return status.isGranted;
  }

  // ── Posición inicial ──────────────────────────────────
  Future<Position?> getInitialPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Stream de posición continua ───────────────────────
  StreamSubscription<Position> startTracking(
      void Function(Position position) onPosition) {
    return Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(milliseconds: 800),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: 'MotoGPS activo',
          notificationTitle: 'Navegación en curso',
          enableWakeLock: true,
        ),
      ),
    ).listen(onPosition);
  }
}
