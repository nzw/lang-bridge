import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/dict_link_settings.dart';
import '../domain/repositories.dart';
import '../infrastructure/external/hokujiro/hokujiro_api_client.dart';
import '../infrastructure/external/nzwjp/nzwjp_api_client.dart';
import '../infrastructure/external/nzwjp/nzwjp_auth_repository.dart';
import '../infrastructure/local/dict_link_settings_notifier.dart';
import '../infrastructure/local/in_memory_dictionary_repository.dart';
import '../infrastructure/local/library_search_prefs_store.dart';
import '../infrastructure/update/update_checker.dart';
import '../infrastructure/update/update_info.dart';

final dioProvider = Provider<Dio>((ref) => Dio());

final updateCheckerProvider =
    Provider<UpdateChecker>((ref) => UpdateChecker(ref.watch(dioProvider)));

final updateInfoProvider = FutureProvider<UpdateInfo?>((ref) async {
  return ref.watch(updateCheckerProvider).check();
});

final externalDictClientProvider = Provider<HokujiroApiClient>(
    (ref) => HokujiroApiClient(ref.watch(dioProvider)));

final dictionaryRepositoryProvider = Provider<DictionaryRepository>(
    (ref) => InMemoryDictionaryRepository(ref.watch(externalDictClientProvider)));

final librarySearchPrefsStoreProvider =
    Provider<LibrarySearchPrefsStore>((ref) => LibrarySearchPrefsStore());

final dictLinkSettingsProvider =
    StateNotifierProvider<DictLinkSettingsNotifier, DictLinkSettings>(
        (ref) => DictLinkSettingsNotifier());

final nzwJpAuthRepositoryProvider = Provider<NzwJpAuthRepository>(
    (ref) => NzwJpAuthRepository(ref.watch(dioProvider)));

final nzwJpApiClientProvider =
    Provider<NzwJpApiClient>((ref) => NzwJpApiClient(ref.watch(dioProvider)));
