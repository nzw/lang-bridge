import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_config.dart';
import '../domain/dictionary_entry.dart';
import '../domain/repositories.dart';
import '../infrastructure/firestore/firestore_user_dictionary_repository.dart';
import '../infrastructure/local/shared_prefs_user_dictionary_repository.dart';
import '../infrastructure/sync/google_sheets_sync_repository.dart';
import '../infrastructure/sync/mock_sheet_sync_repository.dart';
import 'auth_providers.dart';

/// サインイン中は Firestore、未サインイン時はローカル SharedPrefs を使用。
final userRepositoryProvider = Provider<UserDictionaryRepository>((ref) {
  final user = ref.watch(firebaseUserProvider).valueOrNull;
  if (user != null) {
    return FirestoreUserDictionaryRepository(uid: user.uid);
  }
  return SharedPrefsUserDictionaryRepository();
});

/// リアルタイム同期用 StreamProvider。
/// サインイン中は Firestore の snapshot を流す。未サインイン時は空ストリーム。
final userEntriesStreamProvider = StreamProvider<List<DictionaryEntry>>((ref) {
  final user = ref.watch(firebaseUserProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('users/${user.uid}/entries')
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((doc) => DictionaryEntry.fromJson(doc.data()))
            .toList(),
      );
});

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  if (!AppConfig.useRealSheets) {
    return MockSheetSyncRepository();
  }
  final id = AppConfig.googleSpreadsheetId.isEmpty
      ? '_unused_manual_sync_only'
      : AppConfig.googleSpreadsheetId;
  return GoogleSheetsSyncRepository(
    accessTokenGetter: () => ref.read(sheetsAccessTokenProvider),
    spreadsheetId: id,
    sheetName: AppConfig.googleSheetName,
  );
});
