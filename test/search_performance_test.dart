import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langbridge_cn_jp/domain/search_query.dart';
import 'package:langbridge_cn_jp/infrastructure/external/hokujiro/hokujiro_api_client.dart';
import 'package:langbridge_cn_jp/infrastructure/local/in_memory_dictionary_repository.dart';

void main() {
  test('ローカル検索は短時間で応答する', () async {
    final repo = InMemoryDictionaryRepository(HokujiroApiClient(Dio()));
    final watch = Stopwatch()..start();
    await repo.search(SearchQuery('炊飯'));
    watch.stop();
    expect(watch.elapsedMilliseconds < 500, isTrue);
  });
}
