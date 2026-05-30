import '../domain/dictionary_entry.dart';
import '../domain/repositories.dart';

class ListFlashcardsUseCase {
  const ListFlashcardsUseCase(this._repository);

  final UserDictionaryRepository _repository;

  Future<List<DictionaryEntry>> execute() async {
    return _repository.listAll();
  }
}
