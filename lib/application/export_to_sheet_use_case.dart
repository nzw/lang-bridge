import '../domain/repositories.dart';

class ExportToSheetUseCase {
  const ExportToSheetUseCase(this._userRepository, this._syncRepository);

  final UserDictionaryRepository _userRepository;
  final SyncRepository _syncRepository;

  Future<int> execute() async {
    final entries = await _userRepository.listAll();
    final rows = <List<String>>[
      ['ソース言語', 'ターゲット言語', 'メモ', 'カテゴリ'],
      ...entries.map((e) => [e.lang1, e.lang2, e.memo, e.categories.join('//')]),
    ];
    await _syncRepository.exportRows(rows);
    return entries.length;
  }
}
