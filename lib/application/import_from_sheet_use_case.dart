import '../domain/dictionary_entry.dart';
import '../domain/import_validation_error.dart';
import '../domain/repositories.dart';
import 'validate_import_format_use_case.dart';

class ImportFromSheetUseCase {
  const ImportFromSheetUseCase(this._syncRepository, this._userRepository, this._validator);

  final SyncRepository _syncRepository;
  final UserDictionaryRepository _userRepository;
  final ValidateImportFormatUseCase _validator;

  Future<int> execute() async {
    final rows = await _syncRepository.importRows();
    if (rows.isEmpty) {
      return 0;
    }

    final format = _validator.execute(rows.first);
    var missingCount = 0;
    var imported = 0;

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final lang1 = _valueAt(row, format.lang1Index);
      final lang2 = _valueAt(row, format.lang2Index);
      if (lang1.isEmpty || lang2.isEmpty) {
        missingCount++;
        continue;
      }

      final memo = format.memoIndex == null ? '' : _valueAt(row, format.memoIndex!);
      final categories = format.categoryIndexes.map((idx) => _valueAt(row, idx)).where((e) => e.isNotEmpty).toList();

      await _userRepository.upsert(
        DictionaryEntry(
          id: 'sheet-$i-$lang1-$lang2',
          lang1: lang1,
          lang2: lang2,
          memo: memo,
          categories: categories,
          sourceType: EntrySourceType.userSheet,
        ),
      );
      imported++;
    }

    if (missingCount > 0) {
      throw ImportValidationError(
        message: '取込は完了しましたが、一部行は必須列が不足していたためスキップされました。',
        missingRequiredCellCount: missingCount,
      );
    }
    return imported;
  }

  String _valueAt(List<String> row, int index) {
    if (index < 0 || index >= row.length) {
      return '';
    }
    return row[index].trim();
  }
}
