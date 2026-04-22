import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_record.dart';

class PrefsSource {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  // ── Avatar ────────────────────────────────────────────
  Future<void> saveAvatar(Uint8List bytes) async {
    final prefs = await _instance;
    await prefs.setString('user_avatar', base64Encode(bytes));
  }

  Future<Uint8List?> loadAvatar() async {
    final prefs = await _instance;
    final raw = prefs.getString('user_avatar');
    if (raw == null) return null;
    return base64Decode(raw);
  }

  // ── Viajes ────────────────────────────────────────────
  Future<void> saveTrips(List<TripRecord> trips) async {
    final prefs = await _instance;
    await prefs.setString(
      'trip_records',
      json.encode(trips.map((t) => t.toJson()).toList()),
    );
  }

  Future<List<TripRecord>> loadTrips() async {
    final prefs = await _instance;
    final raw = prefs.getString('trip_records');
    if (raw == null) return [];
    final data = json.decode(raw) as List;
    return data.map((e) => TripRecord.fromJson(e)).toList();
  }
}
