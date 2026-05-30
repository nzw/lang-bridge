import '../../domain/repositories.dart';

class MockSheetSyncRepository implements SyncRepository {
  MockSheetSyncRepository({List<List<String>>? initialRows})
      : _rows = initialRows ??
            [
              ['ソース言語', 'ターゲット言語', 'メモ', 'カテゴリ'],
              ['インスリン', '胰岛素', '', '病'],
              ['ペスト', '黑死病', '皮膚が黒くなって死ぬ。未根絶', '病'],
            ];

  List<List<String>> _rows;

  @override
  Future<void> exportRows(List<List<String>> rows) async {
    _rows = rows;
  }

  @override
  Future<List<List<String>>> importRows() async {
    return _rows;
  }

  @override
  Future<SheetListResult> listSheetNames(String spreadsheetUrlOrId) async {
    return (title: 'モックスプレッドシート', sheetNames: ['Sheet1', '学習用', '業務用']);
  }

  @override
  Future<List<List<String>>> importRowsFromSheet({
    required String spreadsheetUrlOrId,
    required String sheetName,
  }) async {
    return _rows;
  }

  @override
  Future<String> exportRowsToNewSheet({
    required String spreadsheetUrlOrId,
    required String newSheetName,
    required List<List<String>> rows,
  }) async {
    _rows = rows;
    return 'mock-sheet-created:$newSheetName';
  }

  @override
  Future<String> exportRowsToNewSpreadsheet({
    required String title,
    required String initialSheetName,
    required List<List<String>> rows,
  }) async {
    _rows = rows;
    return 'https://docs.google.com/spreadsheets/d/mock-spreadsheet-id/edit#gid=0';
  }
}
