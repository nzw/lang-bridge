import 'package:flutter_test/flutter_test.dart';
import 'package:langbridge_cn_jp/application/validate_import_format_use_case.dart';
import 'package:langbridge_cn_jp/domain/import_validation_error.dart';
import 'package:langbridge_cn_jp/domain/search_query.dart';

void main() {
  test('SearchQueryは空白と大文字を正規化する', () {
    final query = SearchQuery('  Model  Arts  ');
    expect(query.normalized, 'model arts');
  });

  test('ヘッダー正常時は検証を通過する', () {
    const useCase = ValidateImportFormatUseCase();
    final result = useCase.execute(['カテゴリ', '日本語', '中国語', 'メモ']);
    expect(result.jpIndex, 1);
    expect(result.zhIndex, 2);
  });

  test('必須ヘッダー不足時はエラーを返す', () {
    const useCase = ValidateImportFormatUseCase();
    expect(
      () => useCase.execute(['カテゴリ', 'メモ']),
      throwsA(isA<ImportValidationError>()),
    );
  });
}
