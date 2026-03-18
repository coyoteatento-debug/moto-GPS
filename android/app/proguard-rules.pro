# ── flutter_background_service ──────────────────────────────
-keep class id.flutter.flutter_background_service.** { *; }

# ── geolocator ──────────────────────────────────────────────
-keep class com.baseflow.geolocator.** { *; }

# ── flutter_tts ─────────────────────────────────────────────
-keep class com.tundralabs.fluttertts.** { *; }

# ── permission_handler ──────────────────────────────────────
-keep class com.baseflow.permissionhandler.** { *; }

# ── flutter_map_tile_caching ────────────────────────────────
-keep class dev.jns.flutter_map_tile_caching.** { *; }

# ── drift / sqlite ──────────────────────────────────────────
-keep class com.tekartik.sqflite.** { *; }

# ── Flutter core ────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**
