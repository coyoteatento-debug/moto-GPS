import 'package:flutter/material.dart';

/// Controles flotantes del mapa.
/// Botones grandes (48px mínimo) aptos para uso con guantes de moto.
class MapControls extends StatelessWidget {
  final bool isTracking;
  final bool followUser;
  final bool isNightMode;
  final bool isHudVisible;

  final VoidCallback onTrackingToggle;
  final VoidCallback onFollowToggle;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onNightModeToggle;
  final VoidCallback onHudToggle;
  final VoidCallback onCenterUser;
  final VoidCallback onOpenOfflineManager;

  const MapControls({
    super.key,
    required this.isTracking,
    required this.followUser,
    required this.isNightMode,
    required this.isHudVisible,
    required this.onTrackingToggle,
    required this.onFollowToggle,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onNightModeToggle,
    required this.onHudToggle,
    required this.onCenterUser,
    required this.onOpenOfflineManager,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Controles derecha: Zoom + Centrar ─────────
        Positioned(
          right: 12,
          bottom: 110,
          child: Column(
            children: [
              _MapButton(
                icon: Icons.add_rounded,
                onTap: onZoomIn,
                tooltip: 'Acercar',
              ),
              const SizedBox(height: 8),
              _MapButton(
                icon: Icons.remove_rounded,
                onTap: onZoomOut,
                tooltip: 'Alejar',
              ),
              const SizedBox(height: 8),
              _MapButton(
                icon: followUser
                    ? Icons.my_location_rounded
                    : Icons.location_searching_rounded,
                color: followUser ? Colors.blue : null,
                onTap: onCenterUser,
                tooltip: 'Centrar en mí',
              ),
            ],
          ),
        ),

        // ── Controles izquierda: Noche + HUD + Offline ─
        Positioned(
          left: 12,
          bottom: 110,
          child: Column(
            children: [
              _MapButton(
                icon: isNightMode
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                color: isNightMode ? Colors.yellow : null,
                onTap: onNightModeToggle,
                tooltip: isNightMode ? 'Modo día' : 'Modo noche',
              ),
              const SizedBox(height: 8),
              _MapButton(
                icon: isHudVisible
                    ? Icons.speed_rounded
                    : Icons.speed_outlined,
                color: isHudVisible ? Colors.orange : null,
                onTap: onHudToggle,
                tooltip: 'HUD',
              ),
              const SizedBox(height: 8),
              _MapButton(
                icon: Icons.download_for_offline_rounded,
                onTap: onOpenOfflineManager,
                tooltip: 'Mapas offline',
              ),
            ],
          ),
        ),

        // ── Botón principal: INICIAR / DETENER ────────
        // 80px — apto para guantes de moto
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: onTrackingToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isTracking ? Colors.red.shade700 : Colors.orange,
                  boxShadow: [
                    BoxShadow(
                      color: (isTracking ? Colors.red : Colors.orange)
                          .withOpacity(0.55),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  isTracking ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            ),
          ),
        ),

        // ── Indicador de grabación activa (top) ───────
        if (isTracking)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: _RecordingBadge(),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────
// BOTÓN CIRCULAR DEL MAPA
// ─────────────────────────────────────────────────────
class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color? color;

  const _MapButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(
            icon,
            color: color ?? Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// BADGE PARPADEANTE DE GRABACIÓN ACTIVA
// ─────────────────────────────────────────────────────
class _RecordingBadge extends StatefulWidget {
  @override
  State<_RecordingBadge> createState() => _RecordingBadgeState();
}

class _RecordingBadgeState extends State<_RecordingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.85),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
            SizedBox(width: 6),
            Text(
              'GRABANDO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
