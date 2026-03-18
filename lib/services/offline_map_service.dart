import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';

// ═══════════════════════════════════════════════════════
// MODELOS
// ═══════════════════════════════════════════════════════

enum DownloadStatus { idle, downloading, completed, failed }

class DownloadProgress {
  final int tilesCompleted;
  final int tilesTotal;
  final double percentage;
  final double estimatedMB;
  final DownloadStatus status;
  final String? error;

  const DownloadProgress({
    required this.tilesCompleted,
    required this.tilesTotal,
    required this.percentage,
    required this.estimatedMB,
    required this.status,
    this.error,
  });

  @override
  String toString() =>
      'DownloadProgress($tilesCompleted/$tilesTotal '
      '— ${percentage.toStringAsFixed(1)}% — $status)';
}

class StoreInfo {
  final String name;
  final int tiles;
  final double sizeMB;

  const StoreInfo({
    required this.name,
    required this.tiles,
    required this.sizeMB,
  });
}

// ═══════════════════════════════════════════════════════
// SERVICIO DE MAPAS OFFLINE
// ═══════════════════════════════════════════════════════
class OfflineMapService {
  static const String _defaultStore = 'moto_offline';

  static const String _osmUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _nightUrl =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';

  // ─────────────────────────────────────────────────
  // INICIALIZAR — Llamar en main() antes de runApp()
  // ─────────────────────────────────────────────────
  static Future<void> initialize() async {
    await FMTCObjectBoxBackend().initialise();
    await FMTCStore(_defaultStore).manage.create();
  }

  // ─────────────────────────────────────────────────
  // TILE PROVIDER con caché automático
  // CacheFirst: sirve desde caché si existe,
  //             descarga si no existe o expiró
  // ─────────────────────────────────────────────────
  static TileProvider getTileProvider({String? storeName}) {
    return FMTCStore(storeName ?? _defaultStore).getTileProvider(
      settings: FMTCTileProviderSettings(
        behavior: CacheBehavior.cacheFirst,
        cachedValidDuration: const Duration(days: 30),
        // Máximo 5000 tiles por store para controlar espacio
        maxStoreLength: 5000,
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // DESCARGAR REGIÓN RECTANGULAR
  // Recibe las coordenadas del área visible del mapa
  // ─────────────────────────────────────────────────
  static Stream<DownloadProgress> downloadRegion({
    required String storeName,
    required LatLngBounds bounds,
    int minZoom = 8,
    int maxZoom = 16,
    String urlTemplate = _osmUrl,
  }) async* {
    final store = FMTCStore(storeName);
    await store.manage.create();

    final region = RectangleRegion(bounds);
    final downloadable = region.toDownloadable(
      minZoom: minZoom,
      maxZoom: maxZoom,
      options: TileLayer(urlTemplate: urlTemplate),
    );

    final tileCount = downloadable.approxTiles;
    // Estimación: ~25 KB por tile promedio
    final estimatedMB = (tileCount * 25) / 1024;

    yield DownloadProgress(
      tilesCompleted: 0,
      tilesTotal: tileCount,
      percentage: 0,
      estimatedMB: estimatedMB,
      status: DownloadStatus.downloading,
    );

    int completed = 0;

    try {
      await for (final event in store.download.startForeground(
        region: downloadable,
        parallelThreads: 3,
        maxBufferLength: 100,
        skipExistingTiles: true,
        retryFailedRequestTiles: true,
      )) {
        if (event is TileEvent && event.result.category.isPositive) {
          completed++;
          yield DownloadProgress(
            tilesCompleted: completed,
            tilesTotal: tileCount,
            percentage: tileCount > 0 ? (completed / tileCount) * 100 : 100,
            estimatedMB: estimatedMB,
            status: DownloadStatus.downloading,
          );
        }
      }

      yield DownloadProgress(
        tilesCompleted: tileCount,
        tilesTotal: tileCount,
        percentage: 100,
        estimatedMB: estimatedMB,
        status: DownloadStatus.completed,
      );
    } catch (e) {
      yield DownloadProgress(
        tilesCompleted: completed,
        tilesTotal: tileCount,
        percentage: tileCount > 0 ? (completed / tileCount) * 100 : 0,
        estimatedMB: estimatedMB,
        status: DownloadStatus.failed,
        error: e.toString(),
      );
    }
  }

  // ─────────────────────────────────────────────────
  // LISTAR STORES con tamaño y cantidad de tiles
  // ─────────────────────────────────────────────────
  static Future<List<StoreInfo>> listStores() async {
    final storeNames = await FMTCRoot.stats.storesAvailable;
    final List<StoreInfo> result = [];

    for (final name in storeNames) {
      final store = FMTCStore(name);
      final tiles = await store.stats.length;
      final sizeKib = await store.stats.size;

      result.add(StoreInfo(
        name: name,
        tiles: tiles,
        sizeMB: sizeKib / 1024,
      ));
    }

    return result;
  }

  // ─────────────────────────────────────────────────
  // ELIMINAR STORE (liberar espacio)
  // ─────────────────────────────────────────────────
  static Future<void> deleteStore(String name) async {
    await FMTCStore(name).manage.delete();
  }

  // ─────────────────────────────────────────────────
  // ESPACIO TOTAL USADO por todos los stores
  // ─────────────────────────────────────────────────
  static Future<double> totalSizeMB() async {
    final sizeKib = await FMTCRoot.stats.size;
    return sizeKib / 1024;
  }

  // ─────────────────────────────────────────────────
  // LIMPIAR tiles expirados (> 30 días sin uso)
  // ─────────────────────────────────────────────────
  static Future<void> cleanOldTiles({String? storeName}) async {
    final name = storeName ?? _defaultStore;
    await FMTCStore(name).manage.clean(
          strategy: CleaningStrategy.recentlyUsed,
        );
  }

  // ─────────────────────────────────────────────────
  // PAUSAR descarga activa
  // ─────────────────────────────────────────────────
  static Future<void> pauseDownload(String storeName) async {
    await FMTCStore(storeName).download.pause();
  }

  // ─────────────────────────────────────────────────
  // CANCELAR descarga activa
  // ─────────────────────────────────────────────────
  static Future<void> cancelDownload(String storeName) async {
    await FMTCStore(storeName).download.cancel();
  }
}
