import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recording.dart';

const _kKey = 'recordings_v1';
const _kRetentionDays = 10;

class RecordingsRepository {
  RecordingsRepository(this._prefs);

  final SharedPreferences _prefs;

  List<Recording> loadAll() {
    final raw = _prefs.getString(_kKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Recording.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(Recording recording) async {
    final all = loadAll();
    all.insert(0, recording);
    await _persist(all);
  }

  Future<void> update(Recording recording) async {
    final all = loadAll();
    final idx = all.indexWhere((r) => r.id == recording.id);
    if (idx != -1) all[idx] = recording;
    await _persist(all);
  }

  Future<void> delete(String id) async {
    final all = loadAll();
    final removed = all.firstWhere((r) => r.id == id, orElse: () => all.first);
    all.removeWhere((r) => r.id == id);
    if (removed.audioPath != null) {
      final file = File(removed.audioPath!);
      if (await file.exists()) await file.delete();
    }
    await _persist(all);
  }

  Future<void> purgeExpired() async {
    final cutoff = DateTime.now().subtract(const Duration(days: _kRetentionDays));
    final all = loadAll();
    final expired = all.where((r) => r.createdAt.isBefore(cutoff)).toList();
    for (final r in expired) {
      if (r.audioPath != null) {
        final file = File(r.audioPath!);
        if (await file.exists()) await file.delete();
      }
    }
    final fresh = all.where((r) => r.createdAt.isAfter(cutoff)).toList();
    await _persist(fresh);
  }

  Future<void> _persist(List<Recording> all) async {
    await _prefs.setString(_kKey, jsonEncode(all.map((r) => r.toJson()).toList()));
  }
}
