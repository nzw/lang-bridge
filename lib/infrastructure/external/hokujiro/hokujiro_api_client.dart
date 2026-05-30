import 'package:dio/dio.dart';

import '../../../app/app_config.dart';
import '../../../domain/dictionary_entry.dart';

/// 外部辞書 API クライアント。
/// [AppConfig.externalDictBaseUrl] が空の場合は API を呼ばず空リストを返す。
/// レスポンス形式: `{"results": [{"japanese": "...", "chinese": "..."}]}`
/// または `[{"ja": "...", "zh": "..."}]` のどちらも受け付ける。
class HokujiroApiClient {
  HokujiroApiClient(this._dio);

  final Dio _dio;

  Future<List<DictionaryEntry>> search(String query) async {
    if (AppConfig.externalDictBaseUrl.isEmpty) return const [];

    try {
      final response = await _dio.get<dynamic>(
        AppConfig.externalDictBaseUrl,
        queryParameters: {'q': query},
        options: Options(
          headers: {
            if (AppConfig.externalDictApiKey.isNotEmpty)
              'Authorization': 'Bearer ${AppConfig.externalDictApiKey}',
          },
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 6),
        ),
      );
      return _parseEntries(response.data);
    } catch (_) {
      return const [];
    }
  }

  List<DictionaryEntry> _parseEntries(dynamic data) {
    final items = switch (data) {
      {'results': final List<dynamic> results} => results,
      final List<dynamic> list => list,
      _ => <dynamic>[],
    };

    final entries = <DictionaryEntry>[];
    for (final raw in items) {
      if (raw is! Map) continue;
      final map = raw.cast<dynamic, dynamic>();
      final lang1 = (map['japanese'] ?? map['ja'] ?? '').toString().trim();
      final lang2 = (map['chinese'] ?? map['zh'] ?? '').toString().trim();
      if (lang1.isEmpty || lang2.isEmpty) continue;
      final memo = (map['memo'] ?? map['description'] ?? '').toString();
      entries.add(DictionaryEntry(
        id: (map['id'] ?? 'ext-$lang1-$lang2').toString(),
        lang1: lang1,
        lang2: lang2,
        memo: memo,
        categories: const ['API'],
        sourceType: EntrySourceType.external,
      ));
    }
    return entries;
  }
}
