import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auto_sync_use_case.dart';
import '../application/create_or_update_user_entry_use_case.dart';
import '../application/export_to_sheet_use_case.dart';
import '../application/get_ai_explanation_use_case.dart';
import '../application/get_entry_detail_use_case.dart';
import '../application/import_from_sheet_use_case.dart';
import '../application/list_flashcards_use_case.dart';
import '../application/search_entries_use_case.dart';
import '../application/validate_import_format_use_case.dart';
import '../domain/dictionary_entry.dart';
import 'infrastructure_providers.dart';
import 'repository_providers.dart';

export '../application/auto_sync_use_case.dart' show AutoSyncResult, AutoSyncConflict;

final searchResultsProvider =
    StateProvider<List<DictionaryEntry>>((ref) => []);

final searchEntriesUseCaseProvider = Provider<SearchEntriesUseCase>(
  (ref) => SearchEntriesUseCase(
    ref.watch(dictionaryRepositoryProvider),
    ref.watch(userRepositoryProvider),
  ),
);

final listFlashcardsUseCaseProvider = Provider<ListFlashcardsUseCase>(
    (ref) => ListFlashcardsUseCase(ref.watch(userRepositoryProvider)));

final getEntryDetailUseCaseProvider = Provider<GetEntryDetailUseCase>(
  (ref) => GetEntryDetailUseCase(
    ref.watch(dictionaryRepositoryProvider),
    ref.watch(userRepositoryProvider),
  ),
);

final createOrUpdateUserEntryUseCaseProvider =
    Provider<CreateOrUpdateUserEntryUseCase>(
  (ref) => CreateOrUpdateUserEntryUseCase(
    ref.watch(userRepositoryProvider),
    ref.watch(dictionaryRepositoryProvider),
  ),
);

final validateImportFormatUseCaseProvider =
    Provider<ValidateImportFormatUseCase>((ref) => const ValidateImportFormatUseCase());

final importFromSheetUseCaseProvider = Provider<ImportFromSheetUseCase>(
  (ref) => ImportFromSheetUseCase(
    ref.watch(syncRepositoryProvider),
    ref.watch(userRepositoryProvider),
    ref.watch(validateImportFormatUseCaseProvider),
  ),
);

final exportToSheetUseCaseProvider = Provider<ExportToSheetUseCase>(
  (ref) => ExportToSheetUseCase(
    ref.watch(userRepositoryProvider),
    ref.watch(syncRepositoryProvider),
  ),
);

final autoSyncUseCaseProvider = Provider<AutoSyncUseCase>(
  (ref) => AutoSyncUseCase(
    syncRepo: ref.watch(syncRepositoryProvider),
    userRepo: ref.watch(userRepositoryProvider),
    validator: ref.watch(validateImportFormatUseCaseProvider),
  ),
);

final getAiExplanationUseCaseProvider = Provider<GetAiExplanationUseCase>(
  (ref) => GetAiExplanationUseCase(
    authRepo: ref.watch(nzwJpAuthRepositoryProvider),
    apiClient: ref.watch(nzwJpApiClientProvider),
    idTokenGetter: () =>
        FirebaseAuth.instance.currentUser?.getIdToken() ?? Future.value(null),
  ),
);
