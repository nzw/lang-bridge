import 'package:shared_preferences/shared_preferences.dart';

import '../local/shared_prefs_user_dictionary_repository.dart';
import 'firestore_user_dictionary_repository.dart';

/// SharedPreferences のローカルデータを Firestore に一度だけ移行するヘルパー。
/// 移行済みフラグを SharedPreferences に保存し、2回目以降は何もしない。
class LocalDataMigrator {
  static const _migratedKey = 'firestore_migrated_v1';

  static Future<void> migrateIfNeeded(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedKey) == true) return;

    final localRepo = SharedPrefsUserDictionaryRepository();
    final entries = await localRepo.listAll();

    if (entries.isNotEmpty) {
      final firestoreRepo = FirestoreUserDictionaryRepository(uid: uid);
      await firestoreRepo.upsertMany(List.from(entries));
    }

    await prefs.setBool(_migratedKey, true);
  }
}
