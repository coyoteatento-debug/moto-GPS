import 'package:flutter/material.dart';

/// HUD — Heads Up Display para uso en moto.
/// Diseñado para ser legible con guantes y bajo sol directo:
/// - Texto grande y contrastado
/// - Fondo semitransparente oscuro
/// - Color de velocidad cambia según el rango
class HudOverlay extends StatelessWidget {
  final double speed;       // km/h
  final double altitude;    // metros
  final double distanceKm;  // km recorridos
  final bool isTracking;
  final double accuracy;    // metros de precisión GPS

  const HudOverlay({
    super.key,
    required this.speed,
    required this.altitude,
    required this.distanceKm,
    required this.isTracking,
    required this.accuracy,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Column(
        children: [
          _buildSpeedometer(),
          const SizedBox(height: 8),
          _buildDataBar(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // VELOCÍMETRO — Grande y legible
  // Verde < 80 | Naranja 80-120 | Rojo > 120
  // ─────────────────────────────────────────────────
  Widget _buildSpeedometer() {
    final Color speedColor = speed > 120
        ? Colors.red
        : speed > 80
            ? Colors.orange
            : Colors.white;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: speedColor.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              speed.toStringAsFixed(0),
              style: TextStyle(
                color: speedColor,
                fontSize: 72,
                fontWeight: FontWeight.w900,
                height: 1.0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 6),
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'km/h',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // BARRA DE DATOS SECUNDARIOS
  // ─────────────────────────────────────────────────
  Widget _buildDataBar() {
    final accuracyColor = accuracy < 10
        ? Colors.green
        : accuracy < 30
            ? Colors.orange
            : Colors.red;

    final distanceLabel = distanceKm >= 1
        ? '${distanceKm.toStringAsFixed(1)} km'
        : '${(distanceKm * 1000).toStringAsFixed(0)} m';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.70),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _DataChip(
            icon: Icons.terrain_rounded,
            value: '${altitude.toStringAsFixed(0)} m',
            label: 'Altitud',
          ),
          _VerticalDivider(),
          _DataChip(
            icon: Icons.route_rounded,
            value: distanceLabel,
            label: 'Recorrido',
          ),
          _VerticalDivider(),
          _DataChip(
            icon: Icons.gps_fixed_rounded,
            value: '±${accuracy.toStringAsFixed(0)} m',
            label: 'Precisión',
            color: accuracyColor,
          ),
          _VerticalDivider(),
          _DataChip(
            icon: isTracking
                ? Icons.fiber_manual_record
                : Icons.stop_circle_outlined,
            value: isTracking ? 'REC' : 'STOP',
            label: 'Estado',
            color: isTracking ? Colors.red : Colors.white38,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// WIDGETS AUXILIARES
// ─────────────────────────────────────────────────────
class _DataChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _DataChip({
    required this.icon,
    required this.value,
    required this.label,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      width: 1,
      color: Colors.white12,
    );
  }
}
