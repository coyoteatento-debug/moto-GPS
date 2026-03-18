import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

// ═══════════════════════════════════════════════════════
// MODELOS DE RESULTADO
// ═══════════════════════════════════════════════════════
enum PermissionResult {
  granted,
  deniedOnce,
  deniedForever,
  gpsDisabled,
  restricted,
}

class LocationPermissionStatus {
  final PermissionResult result;
  final String message;
  final bool canProceed;

  const LocationPermissionStatus({
    required this.result,
    required this.message,
    required this.canProceed,
  });
}

// ═══════════════════════════════════════════════════════
// SERVICIO DE PERMISOS
// ═══════════════════════════════════════════════════════
class PermissionService {
  // ─────────────────────────────────────────────────
  // VERIFICAR si el GPS hardware está activo
  // ─────────────────────────────────────────────────
  static Future<bool> isGpsEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // ─────────────────────────────────────────────────
  // VERIFICAR estado actual sin pedir permisos
  // ─────────────────────────────────────────────────
  static Future<LocationPermissionStatus> checkStatus() async {
    final gpsEnabled = await isGpsEnabled();
    if (!gpsEnabled) {
      return const LocationPermissionStatus(
        result: PermissionResult.gpsDisabled,
        message: 'El GPS del dispositivo está apagado.',
        canProceed: false,
      );
    }

    final status = await Permission.location.status;

    if (status.isGranted) {
      if (Platform.isAndroid) {
        final bgStatus = await Permission.locationAlways.status;
        if (bgStatus.isGranted) {
          return const LocationPermissionStatus(
            result: PermissionResult.granted,
            message: 'Permisos completos concedidos.',
            canProceed: true,
          );
        }
        return const LocationPermissionStatus(
          result: PermissionResult.deniedOnce,
          message: 'Falta permiso de ubicación en segundo plano.',
          canProceed: false,
        );
      }
      return const LocationPermissionStatus(
        result: PermissionResult.granted,
        message: 'Permisos concedidos.',
        canProceed: true,
      );
    }

    if (status.isPermanentlyDenied) {
      return const LocationPermissionStatus(
        result: PermissionResult.deniedForever,
        message: 'Permiso denegado permanentemente. '
            'Debes habilitarlo en Configuración.',
        canProceed: false,
      );
    }

    if (status.isRestricted) {
      return const LocationPermissionStatus(
        result: PermissionResult.restricted,
        message: 'Permiso restringido por el sistema.',
        canProceed: false,
      );
    }

    return const LocationPermissionStatus(
      result: PermissionResult.deniedOnce,
      message: 'Permiso de ubicación aún no solicitado.',
      canProceed: false,
    );
  }

  // ─────────────────────────────────────────────────
  // SOLICITAR ubicación en primer plano
  // Siempre debe pedirse ANTES que background
  // ─────────────────────────────────────────────────
  static Future<LocationPermissionStatus> requestForegroundLocation() async {
    final gpsEnabled = await isGpsEnabled();
    if (!gpsEnabled) {
      return const LocationPermissionStatus(
        result: PermissionResult.gpsDisabled,
        message: 'Activa el GPS del dispositivo para continuar.',
        canProceed: false,
      );
    }

    final currentStatus = await Permission.location.status;

    if (currentStatus.isGranted) {
      return const LocationPermissionStatus(
        result: PermissionResult.granted,
        message: 'Permiso de ubicación ya concedido.',
        canProceed: true,
      );
    }

    if (currentStatus.isPermanentlyDenied) {
      return const LocationPermissionStatus(
        result: PermissionResult.deniedForever,
        message: 'Debes habilitarlo manualmente en Configuración.',
        canProceed: false,
      );
    }

    final result = await Permission.location.request();

    if (result.isGranted) {
      return const LocationPermissionStatus(
        result: PermissionResult.granted,
        message: 'Permiso de ubicación concedido.',
        canProceed: true,
      );
    }

    if (result.isPermanentlyDenied) {
      return const LocationPermissionStatus(
        result: PermissionResult.deniedForever,
        message: 'Permiso denegado permanentemente.',
        canProceed: false,
      );
    }

    return const LocationPermissionStatus(
      result: PermissionResult.deniedOnce,
      message: 'Permiso de ubicación denegado.',
      canProceed: false,
    );
  }

  // ─────────────────────────────────────────────────
  // SOLICITAR ubicación en background
  // Android 11+: abre Settings automáticamente
  // Usuario debe elegir "Permitir todo el tiempo"
  // ─────────────────────────────────────────────────
  static Future<LocationPermissionStatus> requestBackgroundLocation() async {
    final foregroundStatus = await Permission.location.status;
    if (!foregroundStatus.isGranted) {
      return const LocationPermissionStatus(
        result: PermissionResult.deniedOnce,
        message: 'Debes conceder ubicación en primer plano primero.',
        canProceed: false,
      );
    }

    final bgStatus = await Permission.locationAlways.status;
    if (bgStatus.isGranted) {
      return const LocationPermissionStatus(
        result: PermissionResult.granted,
        message: 'Permiso de background ya concedido.',
        canProceed: true,
      );
    }

    if (bgStatus.isPermanentlyDenied) {
      return const LocationPermissionStatus(
        result: PermissionResult.deniedForever,
        message: 'Ve a: Configuración → Apps → MotoGPS → '
            'Permisos → Ubicación → "Permitir todo el tiempo"',
        canProceed: false,
      );
    }

    // Android 11+ abre directamente la pantalla de Settings
    final result = await Permission.locationAlways.request();

    if (result.isGranted) {
      return const LocationPermissionStatus(
        result: PermissionResult.granted,
        message: 'Permiso de background concedido. ¡Listo para trackear!',
        canProceed: true,
      );
    }

    return const LocationPermissionStatus(
      result: PermissionResult.deniedOnce,
      message: 'Permiso de background no concedido.',
      canProceed: false,
    );
  }

  // ─────────────────────────────────────────────────
  // SOLICITAR notificaciones (Android 13+)
  // ─────────────────────────────────────────────────
  static Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    final result = await Permission.notification.request();
    return result.isGranted;
  }

  // ─────────────────────────────────────────────────
  // FLUJO COMPLETO — pide todos los permisos en orden
  // ─────────────────────────────────────────────────
  static Future<LocationPermissionStatus> requestAllPermissions() async {
    // 1. Notificaciones (Android 13+)
    await requestNotificationPermission();

    // 2. Ubicación en primer plano
    final foreground = await requestForegroundLocation();
    if (!foreground.canProceed) return foreground;

    // 3. Ubicación en background (solo Android)
    if (Platform.isAndroid) {
      final background = await requestBackgroundLocation();
      if (!background.canProceed) return background;
    }

    return const LocationPermissionStatus(
      result: PermissionResult.granted,
      message: '¡Todos los permisos concedidos!',
      canProceed: true,
    );
  }

  // ─────────────────────────────────────────────────
  // ABRIR Settings de la app
  // ─────────────────────────────────────────────────
  static Future<void> openAppSettings() async {
    await openAppSettings();
  }

  // ─────────────────────────────────────────────────
  // ABRIR Settings de GPS del sistema
  // ─────────────────────────────────────────────────
  static Future<void> openGpsSettings() async {
    await Geolocator.openLocationSettings();
  }
}
