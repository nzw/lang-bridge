import 'dictionary_entry.dart';
import 'search_query.dart';

abstract class DictionaryRepository {
  Future<List<DictionaryEntry>> search(SearchQuery query);
  Future<List<DictionaryEntry>> listAll();
  Future<DictionaryEntry?> getById(String id);
  Future<void> saveAll(List<DictionaryEntry> entries);
}

abstract class UserDictionaryRepository {
  Future<List<DictionaryEntry>> listAll();
  Future<DictionaryEntry?> getById(String id);
  Future<void> upsert(DictionaryEntry entry);
  /// 複数エントリをまとめて upsert し、ディスク書込みを1回にまとめる。
  Future<void> upsertMany(List<DictionaryEntry> entries);
  Future<void> deleteById(String id);
  Future<void> deleteManyByIds(List<String> ids);
  Future<void> deleteAll();
  Future<void> deleteBySessionId(String sessionId);
}

typedef SheetListResult = ({String? title, List<String> sheetNames});

abstract class SyncRepository {
  Future<List<List<String>>> importRows();
  Future<void> exportRows(List<List<String>> rows);
  Future<SheetListResult> listSheetNames(String spreadsheetUrlOrId);
  Future<List<List<String>>> importRowsFromSheet({
    required String spreadsheetUrlOrId,
    required String sheetName,
  });
  Future<String> exportRowsToNewSheet({
    required String spreadsheetUrlOrId,
    required String newSheetName,
    required List<List<String>> rows,
  });
  Future<String> exportRowsToNewSpreadsheet({
    required String title,
    required String initialSheetName,
    required List<List<String>> rows,
  });
}
