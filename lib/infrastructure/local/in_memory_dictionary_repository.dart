import '../../domain/dictionary_entry.dart';
import '../../domain/repositories.dart';
import '../../domain/search_query.dart';
import '../external/hokujiro/hokujiro_api_client.dart';

class InMemoryDictionaryRepository implements DictionaryRepository {
  InMemoryDictionaryRepository(this._externalDictClient);

  final HokujiroApiClient _externalDictClient;
  final List<DictionaryEntry> _entries = [
    DictionaryEntry(
      id: '1',
      lang1: '炊飯器',
      lang2: '电锅',
      memo: '',
      categories: const ['生活'],
      sourceType: EntrySourceType.userSheet,
    ),
    DictionaryEntry(
      id: '2',
      lang1: '湯たんぽ',
      lang2: '热水袋',
      memo: '',
      categories: const ['生活'],
      sourceType: EntrySourceType.userSheet,
    ),
  ];

  @override
  Future<DictionaryEntry?> getById(String id) async {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<DictionaryEntry>> listAll() async {
    return List.unmodifiable(_entries);
  }

  @override
  Future<void> saveAll(List<DictionaryEntry> entries) async {
    for (final entry in entries) {
      final index = _entries.indexWhere((e) => e.id == entry.id);
      if (index >= 0) {
        _entries[index] = entry;
      } else {
        _entries.add(entry);
      }
    }
  }

  @override
  Future<List<DictionaryEntry>> search(SearchQuery query) async {
    final scored = _entries.map((entry) {
      final score = _score(entry, query.normalized);
      return (entry: entry, score: score);
    }).where((e) => e.score > 0).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    final local = scored.map((e) => e.entry).toList();
    if (local.length >= 10) {
      return local.take(10).toList();
    }

    final remote = await _externalDictClient.search(query.raw);
    return [...local, ...remote];
  }

  int _score(DictionaryEntry e, String q) {
    final l1 = e.lang1.toLowerCase();
    final l2 = e.lang2.toLowerCase();
    final memo = e.memo.toLowerCase();
    var score = 0;
    if (l1.startsWith(q) || l2.startsWith(q)) {
      score += 100;
    }
    if (l1.contains(q) || l2.contains(q)) {
      score += 50;
    }
    if (memo.contains(q)) {
      score += 10;
    }
    return score;
  }
}
