import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// ──────────────────────────────────────────────────────────────
// IMPORTANTE: Después de cualquier cambio en las tablas ejecuta:
//   dart run build_runner build --delete-conflicting-outputs
// Esto genera el archivo app_database.g.dart
// ──────────────────────────────────────────────────────────────
part 'app_database.g.dart';

// ═══════════════════════════════════════════════════════
// TABLA: TRIPS — Resumen de cada viaje
// ═══════════════════════════════════════════════════════
class Trips extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  RealColumn get distanceKm => real()();
  RealColumn get maxSpeed => real()();
  RealColumn get avgSpeed => real()();
  IntColumn get durationSeconds => integer()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime()();
  TextColumn get notes => text().nullable()();
}

// ═══════════════════════════════════════════════════════
// TABLA: TRIP_POINTS — Puntos GPS de cada viaje
// ═══════════════════════════════════════════════════════
class TripPoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tripId => integer().references(Trips, #id)();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  RealColumn get altitude => real()();
  RealColumn get speed => real()();
  RealColumn get heading => real()();
  DateTimeColumn get timestamp => dateTime()();
}

// ═══════════════════════════════════════════════════════
// TABLA: WAYPOINTS — POIs guardados manualmente
// ═══════════════════════════════════════════════════════
class Waypoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().nullable()();
  RealColumn get lat => real()();
  RealColumn get lng => real()();

  // Categorías: gasolinera, hotel, restaurante, taller, general
  TextColumn get category =>
      text().withDefault(const Constant('general'))();
  DateTimeColumn get createdAt => dateTime()();
}

// ═══════════════════════════════════════════════════════
// BASE DE DATOS PRINCIPAL
// ═══════════════════════════════════════════════════════
@DriftDatabase(tables: [Trips, TripPoints, Waypoints])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // ─────────────────────────────────────────────────
  // TRIPS
  // ─────────────────────────────────────────────────

  Future<List<Trip>> getAllTrips() => (select(trips)
        ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
      .get();

  Stream<List<Trip>> watchAllTrips() => (select(trips)
        ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
      .watch();

  Future<Trip?> getTripById(int id) =>
      (select(trips)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertTrip(TripsCompanion trip) =>
      into(trips).insert(trip);

  Future<bool> updateTrip(Trip trip) => update(trips).replace(trip);

  Future<int> deleteTrip(int id) =>
      (delete(trips)..where((t) => t.id.equals(id))).go();

  // ─────────────────────────────────────────────────
  // TRIP POINTS
  // ─────────────────────────────────────────────────

  /// Inserta todos los puntos de un viaje en un solo batch (eficiente)
  Future<void> insertTripPoints(List<TripPointsCompanion> points) async {
    await batch((b) {
      b.insertAll(tripPoints, points);
    });
  }

  Future<List<TripPoint>> getTripPoints(int tripId) =>
      (select(tripPoints)
            ..where((p) => p.tripId.equals(tripId))
            ..orderBy([(p) => OrderingTerm.asc(p.timestamp)]))
          .get();

  Future<int> deleteTripPoints(int tripId) =>
      (delete(tripPoints)..where((p) => p.tripId.equals(tripId))).go();

  // ─────────────────────────────────────────────────
  // WAYPOINTS
  // ─────────────────────────────────────────────────

  Future<List<Waypoint>> getAllWaypoints() => select(waypoints).get();

  Stream<List<Waypoint>> watchAllWaypoints() => select(waypoints).watch();

  Future<int> insertWaypoint(WaypointsCompanion waypoint) =>
      into(waypoints).insert(waypoint);

  Future<bool> updateWaypoint(Waypoint waypoint) =>
      update(waypoints).replace(waypoint);

  Future<int> deleteWaypoint(int id) =>
      (delete(waypoints)..where((w) => w.id.equals(id))).go();

  // ─────────────────────────────────────────────────
  // UTILIDADES
  // ─────────────────────────────────────────────────

  /// Elimina un viaje y todos sus puntos GPS
  Future<void> deleteTripWithPoints(int tripId) async {
    await deleteTripPoints(tripId);
    await deleteTrip(tripId);
  }
}

// ─────────────────────────────────────────────────────
// CONEXIÓN SQLITE — usa archivo en documentos de la app
// ─────────────────────────────────────────────────────
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'motogps.db'));
    return NativeDatabase.createInBackground(file);
  });
}
