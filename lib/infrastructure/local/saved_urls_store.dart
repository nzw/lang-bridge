import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/saved_sync_url.dart';

const _kSavedUrlsKey = 'saved_sync_urls_v1';

class SavedUrlsStore {
  Future<List<SavedSyncUrl>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kSavedUrlsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SavedSyncUrl.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<SavedSyncUrl> urls) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _kSavedUrlsKey,
      jsonEncode(urls.map((e) => e.toJson()).toList()),
    );
  }
}
