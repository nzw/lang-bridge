import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/saved_sync_url.dart';
import '../../infrastructure/local/saved_urls_store.dart';

class SavedUrlsNotifier extends StateNotifier<List<SavedSyncUrl>> {
  SavedUrlsNotifier(this._store) : super(const []) {
    _load();
  }

  final SavedUrlsStore _store;

  Future<void> _load() async {
    state = await _store.load();
  }

  Future<void> add(SavedSyncUrl entry) async {
    state = [...state, entry];
    await _store.save(state);
  }

  Future<void> remove(String id) async {
    state = state.where((e) => e.id != id).toList();
    await _store.save(state);
  }

  Future<void> updateTitle(String id, String newTitle) async {
    state = [
      for (final e in state) if (e.id == id) e.copyWith(title: newTitle) else e
    ];
    await _store.save(state);
  }

  Future<void> updateTitleAndUrl(
      String id, String newTitle, String newUrl) async {
    state = [
      for (final e in state)
        if (e.id == id) e.copyWith(title: newTitle, url: newUrl) else e
    ];
    await _store.save(state);
  }

  Future<void> updateLastImportedAt(String url) async {
    final now = DateTime.now();
    state = [
      for (final e in state)
        if (e.url == url) e.copyWith(lastImportedAt: now) else e
    ];
    await _store.save(state);
  }

  Future<void> updateLastExportedAt(String url) async {
    final now = DateTime.now();
    state = [
      for (final e in state)
        if (e.url == url) e.copyWith(lastExportedAt: now) else e
    ];
    await _store.save(state);
  }

  Future<void> updateAutoSyncSettings(
    String id, {
    required AutoSyncSchedule schedule,
    required AutoSyncMode mode,
    String? sheetName,
  }) async {
    state = [
      for (final e in state)
        if (e.id == id)
          e.copyWith(
            autoSyncSchedule: schedule,
            autoSyncMode: mode,
            autoSyncSheetName: sheetName,
          )
        else
          e
    ];
    await _store.save(state);
  }

  Future<void> updateLastAutoSyncAt(String id) async {
    final now = DateTime.now();
    state = [
      for (final e in state)
        if (e.id == id) e.copyWith(lastAutoSyncAt: now) else e
    ];
    await _store.save(state);
  }

  Future<void> upsertByUrl(String url, String title) async {
    final existing = state.where((e) => e.url == url).firstOrNull;
    if (existing != null) {
      await updateTitle(existing.id, title);
    } else {
      await add(
        SavedSyncUrl(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: title.isNotEmpty ? title : '（タイトル未取得）',
          url: url,
          createdAt: DateTime.now(),
        ),
      );
    }
  }
}

final savedUrlsStoreProvider =
    Provider<SavedUrlsStore>((ref) => SavedUrlsStore());

final savedUrlsProvider =
    StateNotifierProvider<SavedUrlsNotifier, List<SavedSyncUrl>>(
  (ref) => SavedUrlsNotifier(ref.watch(savedUrlsStoreProvider)),
);
