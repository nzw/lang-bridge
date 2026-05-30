import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/googleapis_auth.dart' as gauth;
import 'package:http/http.dart' as http;

import '../../domain/repositories.dart';

class GoogleSheetsSyncRepository implements SyncRepository {
  GoogleSheetsSyncRepository({
    required String? Function() accessTokenGetter,
    required String spreadsheetId,
    required String sheetName,
  })  : _accessTokenGetter = accessTokenGetter,
        _spreadsheetId = spreadsheetId,
        _sheetName = sheetName;

  final String? Function() _accessTokenGetter;
  final String _spreadsheetId;
  final String _sheetName;

  static const _sheetsScope =
      'https://www.googleapis.com/auth/spreadsheets';

  @override
  Future<List<List<String>>> importRows() async {
    final api = await _sheetsApi();
    final range = '$_sheetName!A:Z';
    final response =
        await api.spreadsheets.values.get(_spreadsheetId, range);
    final values = response.values ?? const [];
    return values
        .map((row) => row.map((cell) => cell.toString()).toList())
        .toList();
  }

  @override
  Future<void> exportRows(List<List<String>> rows) async {
    final api = await _sheetsApi();
    final range = '$_sheetName!A1';
    final body = sheets.ValueRange(values: rows);
    await api.spreadsheets.values.update(
      body,
      _spreadsheetId,
      range,
      valueInputOption: 'RAW',
    );
  }

  @override
  Future<SheetListResult> listSheetNames(String spreadsheetUrlOrId) async {
    final api = await _sheetsApi();
    final spreadsheetId = _extractSpreadsheetId(spreadsheetUrlOrId);
    try {
      final spreadsheet = await api.spreadsheets.get(spreadsheetId);
      final sheetNames = (spreadsheet.sheets ?? const [])
          .map((sheet) => sheet.properties?.title)
          .whereType<String>()
          .toList();
      return (title: spreadsheet.properties?.title, sheetNames: sheetNames);
    } catch (e) {
      if (e.toString().contains('not supported for this document')) {
        throw UnsupportedError(
          'このURLのファイルはGoogle スプレッドシート形式に対応していません。\n\n'
          'Excel ファイル（.xlsx）などをアップロードした場合は、Google ドライブ上で '
          '右クリック →「アプリで開く」→「Google スプレッドシート」で変換してから、'
          '変換後のURLを使用してください。',
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<List<String>>> importRowsFromSheet({
    required String spreadsheetUrlOrId,
    required String sheetName,
  }) async {
    final api = await _sheetsApi();
    final spreadsheetId = _extractSpreadsheetId(spreadsheetUrlOrId);
    final range = '$sheetName!A:Z';
    final response =
        await api.spreadsheets.values.get(spreadsheetId, range);
    final values = response.values ?? const [];
    return values
        .map((row) => row.map((cell) => cell.toString()).toList())
        .toList();
  }

  @override
  Future<String> exportRowsToNewSheet({
    required String spreadsheetUrlOrId,
    required String newSheetName,
    required List<List<String>> rows,
  }) async {
    final api = await _sheetsApi();
    final spreadsheetId = _extractSpreadsheetId(spreadsheetUrlOrId);
    await api.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(
        requests: [
          sheets.Request(
            addSheet: sheets.AddSheetRequest(
              properties: sheets.SheetProperties(title: newSheetName),
            ),
          ),
        ],
      ),
      spreadsheetId,
    );
    await api.spreadsheets.values.update(
      sheets.ValueRange(values: rows),
      spreadsheetId,
      '$newSheetName!A1',
      valueInputOption: 'RAW',
    );
    return 'https://docs.google.com/spreadsheets/d/$spreadsheetId/edit';
  }

  @override
  Future<String> exportRowsToNewSpreadsheet({
    required String title,
    required String initialSheetName,
    required List<List<String>> rows,
  }) async {
    final api = await _sheetsApi();
    final created = await api.spreadsheets.create(
      sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(title: title),
        sheets: [
          sheets.Sheet(
              properties: sheets.SheetProperties(title: initialSheetName)),
        ],
      ),
    );
    final spreadsheetId = created.spreadsheetId;
    if (spreadsheetId == null || spreadsheetId.isEmpty) {
      throw StateError('スプレッドシート作成に失敗しました。');
    }
    await api.spreadsheets.values.update(
      sheets.ValueRange(values: rows),
      spreadsheetId,
      '$initialSheetName!A1',
      valueInputOption: 'RAW',
    );
    return 'https://docs.google.com/spreadsheets/d/$spreadsheetId/edit';
  }

  Future<sheets.SheetsApi> _sheetsApi() async {
    final token = _accessTokenGetter();
    if (token == null || token.isEmpty) {
      throw StateError(
        'Google アカウントにサインインしていません。\n'
        '右上のアカウントアイコンからサインインしてください。',
      );
    }

    if (kDebugMode) {
      debugPrint('[SheetsRepo] accessToken prefix='
          '"${token.length > 20 ? token.substring(0, 20) : token}"');
    }

    // access token が切れていると 401 になるが、その場合は呼び出し側で
    // 再サインインを促すエラーとして処理する。
    final expiry = DateTime.now().add(const Duration(hours: 1)).toUtc();
    final credentials = gauth.AccessCredentials(
      gauth.AccessToken('Bearer', token, expiry),
      null, // refresh token なし（Firebase Auth が管理）
      [_sheetsScope],
    );
    final client = gauth.authenticatedClient(http.Client(), credentials);
    return sheets.SheetsApi(client);
  }

  String _extractSpreadsheetId(String urlOrId) {
    final value = urlOrId.trim();
    final uri = Uri.tryParse(value);
    if (uri != null && uri.pathSegments.contains('d')) {
      final idx = uri.pathSegments.indexOf('d');
      if (idx >= 0 && idx + 1 < uri.pathSegments.length) {
        return uri.pathSegments[idx + 1];
      }
    }
    return value;
  }
}
