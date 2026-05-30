import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/dictionary_entry.dart';
import '../../domain/repositories.dart';

const _kKey = 'user_dictionary_v1';

// compute() に渡す関数はトップレベルである必要がある。
// jsonDecode/jsonEncode はCPUバウンドなのでバックグラウンドアイソレートで実行し、
// メインスレッドのブロックを防ぐ。
List<DictionaryEntry> _decodeEntries(String raw) {
  final list = jsonDecode(raw) as List<dynamic>;
  return list.map((e) => DictionaryEntry.fromJson(e as Map<String, dynamic>)).toList();
}

String _encodeEntries(List<DictionaryEntry> entries) =>
    jsonEncode(entries.map((e) => e.toJson()).toList());

/// ユーザー単語帳を shared_preferences に JSON で永続化するリポジトリ。
/// アプリ再起動後もデータが保持される。
class SharedPrefsUserDictionaryRepository implements UserDictionaryRepository {
  // メモリキャッシュ（起動時に一度だけ読み込む）
  List<DictionaryEntry>? _cache;
  // SharedPreferences インスタンスをキャッシュし、getInstance() の重複呼び出しを防ぐ。
  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<List<DictionaryEntry>> _load() async {
    if (_cache != null) return _cache!;
    final prefs = await _getPrefs();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) {
      _cache = [];
      return _cache!;
    }
    try {
      // jsonDecode + エントリ変換をバックグラウンドアイソレートで実行
      _cache = await compute(_decodeEntries, raw);
    } catch (_) {
      _cache = [];
    }
    return _cache!;
  }

  Future<void> _persist() async {
    final prefs = await _getPrefs();
    // jsonEncode をバックグラウンドアイソレートで実行してメインスレッドをブロックしない
    final encoded = await compute(_encodeEntries, List<DictionaryEntry>.from(_cache!));
    await prefs.setString(_kKey, encoded);
  }

  @override
  Future<List<DictionaryEntry>> listAll() async {
    return List.unmodifiable(await _load());
  }

  @override
  Future<DictionaryEntry?> getById(String id) async {
    final entries = await _load();
    try {
      return entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(DictionaryEntry entry) async {
    final entries = await _load();
    final idx = entries.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      entries[idx] = entry;
    } else {
      entries.add(entry);
    }
    await _persist();
  }

  /// 複数エントリを一括 upsert し、最後に1回だけ _persist する。
  @override
  Future<void> upsertMany(List<DictionaryEntry> newEntries) async {
    final entries = await _load();
    for (final entry in newEntries) {
      final idx = entries.indexWhere((e) => e.id == entry.id);
      if (idx >= 0) {
        entries[idx] = entry;
      } else {
        entries.add(entry);
      }
    }
    await _persist();
  }

  @override
  Future<void> deleteById(String id) async {
    final entries = await _load();
    entries.removeWhere((e) => e.id == id);
    await _persist();
  }

  @override
  Future<void> deleteManyByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final idSet = ids.toSet();
    final entries = await _load();
    entries.removeWhere((e) => idSet.contains(e.id));
    await _persist();
  }

  @override
  Future<void> deleteAll() async {
    _cache = [];
    await _persist();
  }

  @override
  Future<void> deleteBySessionId(String sessionId) async {
    final entries = await _load();
    entries.removeWhere((e) => e.importSessionId == sessionId);
    await _persist();
  }
}
