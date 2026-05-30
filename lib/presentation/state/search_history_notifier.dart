import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/search_history_entry.dart';
import '../../infrastructure/local/search_history_store.dart';

class SearchHistoryNotifier extends StateNotifier<List<SearchHistoryEntry>> {
  SearchHistoryNotifier(this._store) : super([]) {
    _load();
  }

  final SearchHistoryStore _store;

  Future<void> _load() async {
    state = await _store.load();
  }

  Future<void> record(
    String query,
    int resultCount,
    List<String> topLang1s,
  ) async {
    final normalized = query.trim().toLowerCase();
    final next =
        state.where((e) => e.query.trim().toLowerCase() != normalized).toList();
    final entry = SearchHistoryEntry(
      query: query.trim(),
      resultCount: resultCount,
      topLang1s: topLang1s,
      searchedAt: DateTime.now(),
    );
    state = [entry, ...next];
    await _store.save(state);
  }

  Future<void> remove(String query) async {
    state = state.where((e) => e.query != query).toList();
    await _store.save(state);
  }

  Future<void> clear() async {
    state = [];
    await _store.save(state);
  }
}

final searchHistoryStoreProvider =
    Provider<SearchHistoryStore>((ref) => SearchHistoryStore());

final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<SearchHistoryEntry>>(
  (ref) => SearchHistoryNotifier(ref.watch(searchHistoryStoreProvider)),
);
