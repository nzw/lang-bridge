import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/ai_history_entry.dart';

class AiHistoryStore {
  static const _key = 'ai_history_v1';
  static const _maxEntries = 50;

  Future<List<AiHistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map(AiHistoryEntry.fromJson)
        .toList();
  }

  Future<void> save(List<AiHistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = entries.take(_maxEntries).toList();
    await prefs.setString(_key, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
  }
}
