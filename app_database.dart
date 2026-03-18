import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/offline_map_service.dart';
import '../services/connectivity_service.dart';

/// Pantalla para gestionar las regiones de mapa descargadas.
/// Permite descargar la vista actual del mapa y gestionar el espacio usado.
class OfflineManagerScreen extends StatefulWidget {
  const OfflineManagerScreen({super.key});

  @override
  State<OfflineManagerScreen> createState() => _OfflineManagerScreenState();
}

class _OfflineManagerScreenState extends State<OfflineManagerScreen> {
  final MapController _mapController = MapController();
  List<StoreInfo> _stores = [];
  bool _isLoading = false;
  bool _isDownloading = false;
  DownloadProgress? _progress;
  String? _activeDownloadStore;

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    setState(() => _isLoading = true);
    final stores = await OfflineMapService.listStores();
    if (mounted) setState(() {
      _stores = stores;
      _isLoading = false;
    });
  }

  // ─────────────────────────────────────────────────
  // DESCARGAR ÁREA VISIBLE ACTUAL
  // ─────────────────────────────────────────────────
  Future<void> _downloadCurrentView() async {
    if (!ConnectivityService.isOnline) {
      _showSnack(
        'Sin internet. Necesitas conexión para descargar.',
        isError: true,
      );
      return;
    }

    final bounds = _mapController.camera.visibleBounds;
    final zoom   = _mapController.camera.zoom.round();
    final name   = 'region_${DateTime.now().millisecondsSinceEpoch}';

    setState(() {
      _isDownloading      = true;
      _activeDownloadStore = name;
      _progress = const DownloadProgress(
        tilesCompleted: 0,
        tilesTotal: 1,
        percentage: 0,
        estimatedMB: 0,
        status: DownloadStatus.downloading,
      );
    });

    try {
      await for (final p in OfflineMapService.downloadRegion(
        storeName: name,
        bounds: bounds,
        minZoom: (zoom - 2).clamp(6, 14),
        maxZoom: (zoom + 2).clamp(8, 17),
      )) {
        if (!mounted) return;
        setState(() => _progress = p);

        if (p.status == DownloadStatus.completed) {
          _showSnack('✅ Descarga completada — ${p.tilesTotal} tiles');
          await _loadStores();
        }

        if (p.status == DownloadStatus.failed) {
          _showSnack('Error: ${p.error ?? "desconocido"}', isError: true);
        }
      }
    } catch (e) {
      _showSnack('Error al descargar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _cancelDownload() async {
    if (_activeDownloadStore != null) {
      await OfflineMapService.cancelDownload(_activeDownloadStore!);
      setState(() => _isDownloading = false);
      _showSnack('Descarga cancelada.');
    }
  }

  Future<void> _deleteStore(StoreInfo store) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          '¿Eliminar región?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Se eliminarán ${store.tiles} tiles '
          '(${store.sizeMB.toStringAsFixed(1)} MB).',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await OfflineMapService.deleteStore(store.name);
      await _loadStores();
      _showSnack('Región eliminada.');
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        title: const Text('Mapas Offline'),
        actions: [
          // Indicador de conectividad en tiempo real
          StreamBuilder<bool>(
            stream: ConnectivityService.onConnectivityChanged,
            initialData: ConnectivityService.isOnline,
            builder: (_, snap) {
              final online = snap.data ?? false;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  children: [
                    Icon(
                      online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                      color: online ? Colors.green : Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      online ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: online ? Colors.green : Colors.red,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [

          // ── Mapa interactivo para seleccionar área ──
          SizedBox(
            height: 260,
            child: _buildSelectionMap(),
          ),

          // ── Instrucciones ───────────────────────────
          Container(
            color: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: Colors.white38, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mueve y ajusta el mapa al área que deseas descargar, '
                    'luego presiona Descargar Vista.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // ── Progreso de descarga activa ─────────────
          if (_isDownloading && _progress != null)
            _buildProgressCard(),

          // ── Botón de descarga ───────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isDownloading ? null : _downloadCurrentView,
                    icon: const Icon(Icons.download_rounded),
                    label: Text(
                      _isDownloading ? 'Descargando...' : 'Descargar Vista Actual',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.orange.withOpacity(0.4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                if (_isDownloading) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _cancelDownload,
                    icon: const Icon(Icons.cancel_rounded, color: Colors.red),
                    tooltip: 'Cancelar',
                  ),
                ],
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // ── Lista de regiones descargadas ───────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.orange))
                : _buildStoresList(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // MAPA DE SELECCIÓN
  // ─────────────────────────────────────────────────
  Widget _buildSelectionMap() {
    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: LatLng(19.4326, -99.1332),
        initialZoom: 10.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.tuempresa.motogps',
          tileProvider: OfflineMapService.getTileProvider(),
        ),
        // Overlay semitransparente mostrando el área que se descargará
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.orange.withOpacity(0.08),
            BlendMode.srcOver,
          ),
          child: Container(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // CARD DE PROGRESO DE DESCARGA
  // ─────────────────────────────────────────────────
  Widget _buildProgressCard() {
    final p = _progress!;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Descargando tiles...',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Text(
                '${p.percentage.toStringAsFixed(1)}%',
                style: const TextStyle(
                    color: Colors.orange, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: p.percentage / 100,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${p.tilesCompleted} / ${p.tilesTotal} tiles'
            '  •  ~${p.estimatedMB.toStringAsFixed(1)} MB estimados',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // LISTA DE STORES DESCARGADOS
  // ─────────────────────────────────────────────────
  Widget _buildStoresList() {
    if (_stores.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined,
                  color: Colors.white24, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Sin regiones descargadas',
                style: TextStyle(color: Colors.white38, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Mueve el mapa al área que quieres usar sin internet\n'
                'y presiona "Descargar Vista Actual".',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white24, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<double>(
      future: OfflineMapService.totalSizeMB(),
      builder: (_, totalSnap) {
        return Column(
          children: [
            // Header con espacio total
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_stores.length} región(es) guardada(s)',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 13),
                  ),
                  Text(
                    'Total: ${(totalSnap.data ?? 0).toStringAsFixed(1)} MB',
                    style: const TextStyle(
                        color: Colors.orange, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: _stores.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: Colors.white12, height: 1),
                itemBuilder: (_, i) {
                  final store = _stores[i];
                  // Nombre legible: quitar prefijo timestamp
                  final displayName =
                      store.name.startsWith('region_')
                          ? 'Región ${i + 1}'
                          : store.name;

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.map_rounded,
                        color: Colors.orange,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      displayName,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                    ),
                    subtitle: Text(
                      '${store.tiles} tiles  •  '
                      '${store.sizeMB.toStringAsFixed(1)} MB',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red,
                      ),
                      onPressed: () => _deleteStore(store),
                      tooltip: 'Eliminar',
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
