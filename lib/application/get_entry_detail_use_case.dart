import '../domain/dictionary_entry.dart';
import '../domain/repositories.dart';

class GetEntryDetailUseCase {
  const GetEntryDetailUseCase(
    this._dictionaryRepository,
    this._userDictionaryRepository,
  );

  final DictionaryRepository _dictionaryRepository;
  final UserDictionaryRepository _userDictionaryRepository;

  Future<DictionaryEntry?> execute(String id) async {
    final fromDict = await _dictionaryRepository.getById(id);
    if (fromDict != null) {
      return fromDict;
    }
    return _userDictionaryRepository.getById(id);
  }
}
