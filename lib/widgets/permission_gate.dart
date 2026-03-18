import 'package:flutter/material.dart';
import '../services/permission_service.dart';

/// Widget que bloquea la app hasta que todos los permisos
/// necesarios están concedidos. Se pone como home en MaterialApp.
class PermissionGate extends StatefulWidget {
  final Widget child;

  const PermissionGate({super.key, required this.child});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate>
    with WidgetsBindingObserver {
  LocationPermissionStatus? _status;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Detectar cuando el usuario regresa de Settings
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reverificar al volver de Settings
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);
    final status = await PermissionService.checkStatus();
    if (mounted) setState(() {
      _status = status;
      _isLoading = false;
    });
  }

  Future<void> _requestPermissions() async {
    setState(() => _isLoading = true);
    final status = await PermissionService.requestAllPermissions();
    if (mounted) setState(() {
      _status = status;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.orange),
              SizedBox(height: 16),
              Text(
                'Verificando permisos...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    // Permisos OK — mostrar la app
    if (_status?.canProceed == true) return widget.child;

    // Pantalla de solicitud de permisos
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_off_rounded,
                size: 80,
                color: Colors.orange,
              ),
              const SizedBox(height: 24),
              const Text(
                'Permisos Necesarios',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _status?.message ?? 'Se requieren permisos de ubicación.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              // GPS apagado
              if (_status?.result == PermissionResult.gpsDisabled)
                _PermissionButton(
                  label: 'Activar GPS',
                  icon: Icons.gps_fixed,
                  color: Colors.blue,
                  onTap: () async => PermissionService.openGpsSettings(),
                ),

              // Denegado permanentemente
              if (_status?.result == PermissionResult.deniedForever)
                _PermissionButton(
                  label: 'Abrir Configuración',
                  icon: Icons.settings_rounded,
                  color: Colors.orange,
                  onTap: () async => PermissionService.openAppSettings(),
                ),

              // Primera vez o denegado
              if (_status?.result == PermissionResult.deniedOnce)
                _PermissionButton(
                  label: 'Conceder Permisos',
                  icon: Icons.location_on_rounded,
                  color: Colors.green,
                  onTap: _requestPermissions,
                ),

              const SizedBox(height: 16),
              TextButton(
                onPressed: _checkPermissions,
                child: const Text(
                  'Ya lo hice, reintentar',
                  style: TextStyle(color: Colors.white38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PermissionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
