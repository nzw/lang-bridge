import '../domain/dictionary_entry.dart';
import '../domain/repositories.dart';
import '../domain/search_query.dart';
import '../domain/services/entry_search_ranker.dart';

class SearchEntriesUseCase {
  const SearchEntriesUseCase(
    this._dictionaryRepository,
    this._userDictionaryRepository, {
    EntrySearchRanker ranker = const EntrySearchRanker(),
  }) : _ranker = ranker;

  final DictionaryRepository _dictionaryRepository;
  final UserDictionaryRepository _userDictionaryRepository;
  final EntrySearchRanker _ranker;

  Future<List<DictionaryEntry>> execute(String rawQuery) async {
    final query = SearchQuery(rawQuery);
    if (query.isEmpty) return [];

    final all = await _userDictionaryRepository.listAll();
    final fromUser = _ranker.rank(all, query.normalized);
    final fromDict = await _dictionaryRepository.search(query);

    final seen = <String>{};
    final out = <DictionaryEntry>[];
    for (final e in [...fromUser, ...fromDict]) {
      if (seen.add(e.id)) out.add(e);
    }
    return out;
  }
}
