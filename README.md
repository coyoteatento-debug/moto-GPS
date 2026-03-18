# 🏍️ MotoGPS — Flutter Android App

GPS para viajes en motocicleta con tracking en background, mapas offline y HUD de velocidad.

---

## 📁 Estructura del Proyecto

```
motogps/
├── android/
│   ├── app/
│   │   ├── src/main/
│   │   │   ├── AndroidManifest.xml
│   │   │   └── kotlin/com/tuempresa/motogps/
│   │   │       ├── MainActivity.kt
│   │   │       └── BootReceiver.kt
│   │   ├── build.gradle
│   │   └── proguard-rules.pro
│   ├── build.gradle
│   ├── settings.gradle
│   └── gradle.properties
│
├── lib/
│   ├── main.dart                          ← Punto de entrada
│   │
│   ├── models/
│   │   └── trip_point.dart                ← Modelo de punto GPS
│   │
│   ├── database/
│   │   └── app_database.dart              ← SQLite con Drift (rutas, waypoints)
│   │
│   ├── services/
│   │   ├── background_gps_service.dart    ← GPS en background (Foreground Service)
│   │   ├── permission_service.dart        ← Manejo de permisos Android
│   │   ├── offline_map_service.dart       ← Caché de tiles (FMTC)
│   │   └── connectivity_service.dart      ← Detección de internet
│   │
│   ├── widgets/
│   │   ├── permission_gate.dart           ← Bloquea app hasta tener permisos
│   │   ├── hud_overlay.dart               ← Velocímetro + datos para moto
│   │   └── map_controls.dart             ← Botones flotantes del mapa
│   │
│   └── screens/
│       ├── map_screen.dart                ← Pantalla principal del mapa
│       └── offline_manager_screen.dart    ← Gestión de regiones offline
│
└── pubspec.yaml
```

---

## 🚀 Pasos para Compilar

### 1. Pre-requisitos
```bash
flutter --version   # Requiere Flutter 3.19+ / Dart 3.3+
```

### 2. Instalar dependencias
```bash
flutter pub get
```

### 3. Generar código de Drift (base de datos)
```bash
dart run build_runner build --delete-conflicting-outputs
```
> ⚠️ Esto genera `lib/database/app_database.g.dart`
> Sin este paso el proyecto NO compila.

### 4. Compilar en debug
```bash
flutter run
```

### 5. Compilar APK release
```bash
flutter build apk --release
# APK en: build/app/outputs/flutter-apk/app-release.apk
```

### 6. Compilar App Bundle (Play Store)
```bash
flutter build appbundle --release
```

---

## ⚠️ Notas Importantes

### Permiso de Background Location en Android 11+
Al solicitar `ACCESS_BACKGROUND_LOCATION`, Android abre automáticamente
la pantalla de Settings. El usuario debe seleccionar manualmente:
> **"Permitir todo el tiempo"**

### applicationId
Cambia `com.tuempresa.motogps` en `android/app/build.gradle` por tu ID real.

### Keystore para Release
Reemplaza `signingConfig = signingConfigs.debug` en `build.gradle`
con tu keystore de producción antes de publicar.

### Drift / build_runner
Cada vez que modifiques las tablas en `app_database.dart` debes ejecutar:
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## 📦 Dependencias Principales

| Paquete | Versión | Uso |
|---|---|---|
| flutter_map | ^7.0.2 | Mapa OpenStreetMap |
| flutter_map_tile_caching | ^9.1.0 | Tiles offline |
| geolocator | ^13.0.2 | GPS preciso |
| flutter_background_service | ^5.0.5 | GPS en background |
| permission_handler | ^11.3.1 | Permisos Android |
| flutter_tts | ^4.0.2 | Voz turn-by-turn |
| drift | ^2.18.0 | Base de datos SQLite |
| connectivity_plus | ^6.0.3 | Estado de red |

---

## 🗺️ Estilos de Mapa Disponibles

| Estilo | URL | Uso |
|---|---|---|
| Standard | tile.openstreetmap.org | Día (default) |
| Night | basemaps.cartocdn.com/dark_all | Noche |
| Terrain | tile.opentopomap.org | Montaña |
| Satellite | arcgisonline.com/World_Imagery | Satélite |

---

## 📊 Estimación Espacio Offline

| Zoom | Tiles (ciudad) | Tamaño |
|---|---|---|
| 8–12 | ~500 | ~12 MB |
| 8–14 | ~2,000 | ~50 MB |
| 8–16 | ~8,000 | ~200 MB ← Recomendado |
| 8–17 | ~25,000 | ~600 MB |
