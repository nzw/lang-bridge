import '../../domain/dictionary_entry.dart';
import '../../domain/repositories.dart';

class InMemoryUserDictionaryRepository implements UserDictionaryRepository {
  final List<DictionaryEntry> _entries = [];

  @override
  Future<void> deleteById(String id) async {
    _entries.removeWhere((e) => e.id == id);
  }

  @override
  Future<void> deleteManyByIds(List<String> ids) async {
    final idSet = ids.toSet();
    _entries.removeWhere((e) => idSet.contains(e.id));
  }

  @override
  Future<List<DictionaryEntry>> listAll() async {
    return List.unmodifiable(_entries);
  }

  @override
  Future<DictionaryEntry?> getById(String id) async {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(DictionaryEntry entry) async {
    final idx = _entries.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      _entries[idx] = entry;
      return;
    }
    _entries.add(entry);
  }

  @override
  Future<void> upsertMany(List<DictionaryEntry> entries) async {
    for (final entry in entries) {
      await upsert(entry);
    }
  }

  @override
  Future<void> deleteAll() async {
    _entries.clear();
  }

  @override
  Future<void> deleteBySessionId(String sessionId) async {
    _entries.removeWhere((e) => e.importSessionId == sessionId);
  }
}
