import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ai_history_entry.dart';
import '../../infrastructure/local/ai_history_store.dart';

class AiHistoryNotifier extends StateNotifier<List<AiHistoryEntry>> {
  AiHistoryNotifier(this._store) : super([]) {
    _load();
  }

  final AiHistoryStore _store;

  Future<void> _load() async {
    state = await _store.load();
  }

  Future<void> add(AiHistoryEntry entry) async {
    state = [entry, ...state];
    await _store.save(state);
  }

  Future<void> remove(String id) async {
    state = state.where((e) => e.id != id).toList();
    await _store.save(state);
  }

  Future<void> clear() async {
    state = [];
    await _store.save(state);
  }
}

final aiHistoryStoreProvider = Provider<AiHistoryStore>((ref) => AiHistoryStore());

final aiHistoryProvider =
    StateNotifierProvider<AiHistoryNotifier, List<AiHistoryEntry>>(
  (ref) => AiHistoryNotifier(ref.watch(aiHistoryStoreProvider)),
);
