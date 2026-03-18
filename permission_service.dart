import 'package:latlong2/latlong.dart';

/// Representa un punto GPS capturado durante un viaje.
/// Contiene todos los datos necesarios para reconstruir la ruta
/// y exportar a formato GPX.
class TripPoint {
  final LatLng position;
  final double speed;    // km/h
  final double altitude; // metros
  final double heading;  // grados 0-360
  final DateTime timestamp;

  const TripPoint({
    required this.position,
    required this.speed,
    required this.altitude,
    required this.heading,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'lat': position.latitude,
        'lng': position.longitude,
        'speed': speed,
        'altitude': altitude,
        'heading': heading,
        'timestamp': timestamp.toIso8601String(),
      };

  factory TripPoint.fromJson(Map<String, dynamic> json) => TripPoint(
        position: LatLng(
          json['lat'] as double,
          json['lng'] as double,
        ),
        speed: (json['speed'] as num).toDouble(),
        altitude: (json['altitude'] as num).toDouble(),
        heading: (json['heading'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  @override
  String toString() =>
      'TripPoint(${position.latitude.toStringAsFixed(6)}, '
      '${position.longitude.toStringAsFixed(6)}, '
      '${speed.toStringAsFixed(1)} km/h)';
}
