import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/library_search_options.dart';

const _kLibrarySearchPrefsKey = 'library_search_options_v1';

class LibrarySearchPrefsStore {
  Future<LibrarySearchOptions> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kLibrarySearchPrefsKey);
    if (raw == null || raw.isEmpty) {
      return const LibrarySearchOptions();
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return LibrarySearchOptions.fromJson(map);
    } catch (_) {
      return const LibrarySearchOptions();
    }
  }

  Future<void> save(LibrarySearchOptions options) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLibrarySearchPrefsKey, jsonEncode(options.toJson()));
  }
}
