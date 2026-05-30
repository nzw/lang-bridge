import '../domain/dictionary_entry.dart';
import '../domain/repositories.dart';

class CreateOrUpdateUserEntryUseCase {
  const CreateOrUpdateUserEntryUseCase(this._userRepository, this._dictionaryRepository);

  final UserDictionaryRepository _userRepository;
  final DictionaryRepository _dictionaryRepository;

  Future<void> execute(DictionaryEntry entry) async {
    await _userRepository.upsert(entry);
    await _dictionaryRepository.saveAll([entry]);
  }
}
