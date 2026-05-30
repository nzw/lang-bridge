import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/search_history_entry.dart';

class SearchHistoryStore {
  static const _key = 'search_history_v1';
  static const _max = 100;

  Future<List<SearchHistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SearchHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<SearchHistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final clamped = entries.take(_max).toList();
    await prefs.setString(
      _key,
      jsonEncode(clamped.map((e) => e.toJson()).toList()),
    );
  }
}
