import '../domain/import_format.dart';
import '../domain/import_validation_error.dart';

class FormatValidationResult {
  const FormatValidationResult(this.lang1Index, this.lang2Index, this.memoIndex, this.categoryIndexes);

  final int lang1Index;
  final int lang2Index;
  final int? memoIndex;
  final List<int> categoryIndexes;
}

class ValidateImportFormatUseCase {
  const ValidateImportFormatUseCase();

  FormatValidationResult execute(List<String> header) {
    final normalized = header.map((e) => e.trim()).toList();
    final unknownHeaders = normalized
        .where(
          (h) =>
              h.isNotEmpty &&
              !ImportFormat.supported.lang1Headers.contains(h) &&
              !ImportFormat.supported.lang2Headers.contains(h) &&
              !ImportFormat.supported.memoHeaders.contains(h) &&
              !ImportFormat.supported.categoryHeaders.contains(h),
        )
        .toList();

    int findFirst(Set<String> names) => normalized.indexWhere(names.contains);

    final lang1 = findFirst(ImportFormat.supported.lang1Headers);
    final lang2 = findFirst(ImportFormat.supported.lang2Headers);
    final memo = findFirst(ImportFormat.supported.memoHeaders);
    final categoryIndexes = <int>[];
    for (var i = 0; i < normalized.length; i++) {
      if (ImportFormat.supported.categoryHeaders.contains(normalized[i])) {
        categoryIndexes.add(i);
      }
    }

    final missing = <String>[];
    if (lang1 < 0) {
      missing.add('ソース言語');
    }
    if (lang2 < 0) {
      missing.add('ターゲット言語');
    }

    if (missing.isNotEmpty) {
      throw ImportValidationError(
        message: '取込に失敗しました。指定フォーマットと一致しません。',
        missingHeaders: missing,
        unknownHeaders: unknownHeaders,
      );
    }

    return FormatValidationResult(lang1, lang2, memo >= 0 ? memo : null, categoryIndexes);
  }
}
