import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/background_gps_service.dart';
import '../services/offline_map_service.dart';
import '../models/trip_point.dart';
import '../widgets/hud_overlay.dart';
import '../widgets/map_controls.dart';
import 'offline_manager_screen.dart';

// ═══════════════════════════════════════════════════════
// ESTILOS DE MAPA DISPONIBLES
// ═══════════════════════════════════════════════════════
class _MapStyles {
  static const String standard =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String night =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
  static const String terrain =
      'https://tile.opentopomap.org/{z}/{x}/{y}.png';
}

// ═══════════════════════════════════════════════════════
// PANTALLA PRINCIPAL DEL MAPA
// ═══════════════════════════════════════════════════════
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with TickerProviderStateMixin {

  // ─────────────────────────────────────────────────
  // CONTROLADORES
  // ─────────────────────────────────────────────────
  final MapController _mapController = MapController();
  late AnimationController _centerAnimController;

  // ─────────────────────────────────────────────────
  // ESTADO GPS
  // ─────────────────────────────────────────────────
  LatLng? _currentPosition;
  double _currentSpeed    = 0.0;  // km/h
  double _currentHeading  = 0.0;  // grados 0-360
  double _currentAltitude = 0.0;  // metros
  double _accuracy        = 0.0;  // metros

  // ─────────────────────────────────────────────────
  // ESTADO DE TRACKING
  // ─────────────────────────────────────────────────
  bool _isTracking   = false;
  bool _followUser   = true;   // Auto-centra el mapa en el usuario
  bool _isHudVisible = true;
  bool _isNightMode  = false;

  // ─────────────────────────────────────────────────
  // DATOS DE RUTA
  // ─────────────────────────────────────────────────
  final List<LatLng>    _routePoints = [];
  final List<TripPoint> _tripPoints  = [];
  double _totalDistanceKm = 0.0;
  DateTime? _trackingStartTime;
  final Distance _distanceCalc = const Distance();

  // ─────────────────────────────────────────────────
  // CONFIGURACIÓN DEL MAPA
  // ─────────────────────────────────────────────────
  double _zoomLevel = 16.0;

  // ─────────────────────────────────────────────────
  // SUSCRIPCIONES A STREAMS
  // ─────────────────────────────────────────────────
  StreamSubscription? _locationSub;
  StreamSubscription? _errorSub;

  // ─────────────────────────────────────────────────
  // POSICIÓN INICIAL — Ciudad de México como fallback
  // ─────────────────────────────────────────────────
  static const LatLng _defaultPosition = LatLng(19.4326, -99.1332);

  @override
  void initState() {
    super.initState();

    _centerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Pantalla siempre encendida durante navegación
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();

    _subscribeToGps();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _errorSub?.cancel();
    _centerAnimController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  // ─────────────────────────────────────────────────
  // SUSCRIBIRSE AL GPS DEL SERVICIO BACKGROUND
  // ─────────────────────────────────────────────────
  void _subscribeToGps() {
    _locationSub = BackgroundGpsService.locationStream.listen((data) {
      if (data == null || !mounted) return;
      _onLocationUpdate(data);
    });

    _errorSub = BackgroundGpsService.errorStream.listen((data) {
      if (data == null || !mounted) return;
      _showSnack('GPS: ${data['error']}', isError: true);
    });
  }

  // ─────────────────────────────────────────────────
  // PROCESAR NUEVA POSICIÓN
  // ─────────────────────────────────────────────────
  void _onLocationUpdate(Map<String, dynamic> data) {
    final newPos = LatLng(
      data['lat'] as double,
      data['lng'] as double,
    );

    // Calcular distancia incremental filtrando saltos erráticos (> 500m)
    if (_routePoints.isNotEmpty && _isTracking) {
      final segment = _distanceCalc.as(
        LengthUnit.Kilometer,
        _routePoints.last,
        newPos,
      );
      if (segment < 0.5) {
        _totalDistanceKm += segment;
      }
    }

    setState(() {
      _currentPosition = newPos;
      _currentSpeed    = (data['speedKmh']  as double).clamp(0.0, 350.0);
      _currentHeading  = data['heading']  as double;
      _currentAltitude = data['altitude'] as double;
      _accuracy        = data['accuracy'] as double;

      if (_isTracking) {
        _routePoints.add(newPos);
        _tripPoints.add(TripPoint(
          position : newPos,
          speed    : _currentSpeed,
          altitude : _currentAltitude,
          heading  : _currentHeading,
          timestamp: DateTime.parse(data['timestamp'] as String),
        ));
      }
    });

    if (_followUser) _animateMapTo(newPos);
  }

  // ─────────────────────────────────────────────────
  // ANIMACIÓN SUAVE DE CENTRADO
  // ─────────────────────────────────────────────────
  void _animateMapTo(LatLng destination) {
    final current = _mapController.camera.center;

    final latTween = Tween<double>(
      begin: current.latitude,
      end: destination.latitude,
    );
    final lngTween = Tween<double>(
      begin: current.longitude,
      end: destination.longitude,
    );

    final anim = CurvedAnimation(
      parent: _centerAnimController,
      curve: Curves.easeInOut,
    );

    _centerAnimController.reset();
    anim.addListener(() {
      if (mounted) {
        _mapController.move(
          LatLng(latTween.evaluate(anim), lngTween.evaluate(anim)),
          _zoomLevel,
        );
      }
    });
    _centerAnimController.forward();
  }

  // ─────────────────────────────────────────────────
  // INICIAR / DETENER TRACKING
  // ─────────────────────────────────────────────────
  Future<void> _toggleTracking() async {
    if (_isTracking) {
      await BackgroundGpsService.stopTracking();
      setState(() => _isTracking = false);
      _showTripSummary();
    } else {
      final started = await BackgroundGpsService.startTracking();
      if (started) {
        setState(() {
          _isTracking        = true;
          _trackingStartTime = DateTime.now();
          _routePoints.clear();
          _tripPoints.clear();
          _totalDistanceKm   = 0.0;
        });
      } else {
        _showSnack('No se pudo iniciar el tracking GPS.', isError: true);
      }
    }
  }

  // ─────────────────────────────────────────────────
  // RESUMEN AL TERMINAR EL VIAJE
  // ─────────────────────────────────────────────────
  void _showTripSummary() {
    final duration = _trackingStartTime != null
        ? DateTime.now().difference(_trackingStartTime!)
        : Duration.zero;

    final avgSpeed = duration.inSeconds > 0
        ? (_totalDistanceKm / (duration.inSeconds / 3600))
        : 0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TripSummarySheet(
        distanceKm: _totalDistanceKm,
        duration: duration,
        avgSpeedKmh: avgSpeed,
        pointCount: _tripPoints.length,
        onSave: () {
          Navigator.pop(context);
          _showSnack('Ruta guardada. ✅');
          // TODO: Integrar con AppDatabase y GpxService
        },
        onDiscard: () => Navigator.pop(context),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? Colors.red.shade800 : Colors.green.shade800,
      duration: const Duration(seconds: 3),
    ));
  }

  // ─────────────────────────────────────────────────
  // BUILD PRINCIPAL
  // ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [

          // ── Capa 1: Mapa base ──────────────────────
          _buildMap(),

          // ── Capa 2: HUD de velocidad y datos ──────
          if (_isHudVisible)
            HudOverlay(
              speed: _currentSpeed,
              altitude: _currentAltitude,
              distanceKm: _totalDistanceKm,
              isTracking: _isTracking,
              accuracy: _accuracy,
            ),

          // ── Capa 3: Controles flotantes ────────────
          MapControls(
            isTracking: _isTracking,
            followUser: _followUser,
            isNightMode: _isNightMode,
            isHudVisible: _isHudVisible,
            onTrackingToggle: _toggleTracking,
            onFollowToggle: () =>
                setState(() => _followUser = !_followUser),
            onZoomIn: () {
              setState(() => _zoomLevel = (_zoomLevel + 1).clamp(1.0, 19.0));
              _mapController.move(
                  _mapController.camera.center, _zoomLevel);
            },
            onZoomOut: () {
              setState(() => _zoomLevel = (_zoomLevel - 1).clamp(1.0, 19.0));
              _mapController.move(
                  _mapController.camera.center, _zoomLevel);
            },
            onNightModeToggle: () =>
                setState(() => _isNightMode = !_isNightMode),
            onHudToggle: () =>
                setState(() => _isHudVisible = !_isHudVisible),
            onCenterUser: () {
              if (_currentPosition != null) {
                setState(() => _followUser = true);
                _animateMapTo(_currentPosition!);
              }
            },
            onOpenOfflineManager: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OfflineManagerScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // WIDGET DEL MAPA CON FLUTTER_MAP
  // ─────────────────────────────────────────────────
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentPosition ?? _defaultPosition,
        initialZoom: _zoomLevel,
        maxZoom: 19.0,
        minZoom: 3.0,
        onPositionChanged: (position, hasGesture) {
          // Desactiva el auto-follow si el usuario mueve el mapa
          if (hasGesture && _followUser) {
            setState(() => _followUser = false);
          }
        },
      ),
      children: [

        // Tile layer con caché offline automático
        TileLayer(
          urlTemplate: _isNightMode
              ? _MapStyles.night
              : _MapStyles.standard,
          userAgentPackageName: 'com.tuempresa.motogps',
          // FMTCTileProvider sirve desde caché local si no hay internet
          tileProvider: OfflineMapService.getTileProvider(),
          maxZoom: 19,
          // Mantener tiles viejos visibles mientras carga el nuevo
          keepBuffer: 5,
          panBuffer: 2,
        ),

        // Polilínea naranja de la ruta grabada
        if (_routePoints.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                strokeWidth: 4.0,
                color: Colors.orange.withOpacity(0.85),
                borderColor: Colors.deepOrange.shade900,
                borderStrokeWidth: 1.0,
              ),
            ],
          ),

        // Marcador de posición actual con flecha direccional
        if (_currentPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _currentPosition!,
                width: 60,
                height: 60,
                child: _LocationMarker(
                  heading: _currentHeading,
                  isTracking: _isTracking,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
// MARCADOR GPS — Flecha que rota con el heading
// ═══════════════════════════════════════════════════════
class _LocationMarker extends StatelessWidget {
  final double heading;
  final bool isTracking;

  const _LocationMarker({
    required this.heading,
    required this.isTracking,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: heading * (3.14159265 / 180)),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (_, rotation, __) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Aura de precisión GPS
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(0.12),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.35),
                  width: 1,
                ),
              ),
            ),
            // Flecha de dirección
            Transform.rotate(
              angle: rotation,
              child: Icon(
                Icons.navigation_rounded,
                color: isTracking ? Colors.orange : Colors.blue,
                size: 30,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════
// BOTTOM SHEET — RESUMEN DEL VIAJE
// ═══════════════════════════════════════════════════════
class _TripSummarySheet extends StatelessWidget {
  final double distanceKm;
  final Duration duration;
  final double avgSpeedKmh;
  final int pointCount;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  const _TripSummarySheet({
    required this.distanceKm,
    required this.duration,
    required this.avgSpeedKmh,
    required this.pointCount,
    required this.onSave,
    required this.onDiscard,
  });

  String get _durationFormatted {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    final s = duration.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '🏍️ Viaje Terminado',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Estadísticas del viaje en grid 2×2
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(
                label: 'Distancia',
                value: '${distanceKm.toStringAsFixed(2)} km',
                icon: Icons.route_rounded,
              ),
              _StatItem(
                label: 'Duración',
                value: _durationFormatted,
                icon: Icons.timer_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(
                label: 'Vel. Promedio',
                value: '${avgSpeedKmh.toStringAsFixed(1)} km/h',
                icon: Icons.speed_rounded,
              ),
              _StatItem(
                label: 'Puntos GPS',
                value: '$pointCount',
                icon: Icons.gps_fixed_rounded,
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Botones de acción
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDiscard,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Descartar',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.save_rounded, color: Colors.white),
                  label: const Text(
                    'Guardar Ruta',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.orange, size: 26),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────
// STUB temporal para WakelockPlus
// Reemplazar con: wakelock_plus: ^1.0.0 en pubspec.yaml
// ─────────────────────────────────────────────────────
class WakelockPlus {
  static Future<void> enable() async {}
  static Future<void> disable() async {}
}
