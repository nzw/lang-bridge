import '../domain/gemini_result.dart';
import '../infrastructure/external/nzwjp/gemini_prompt_builder.dart';
import '../infrastructure/external/nzwjp/nzwjp_api_client.dart';
import '../infrastructure/external/nzwjp/nzwjp_auth_repository.dart';
import '../infrastructure/external/nzwjp/nzwjp_exceptions.dart';

class GetAiExplanationUseCase {
  GetAiExplanationUseCase({
    required this.authRepo,
    required this.apiClient,
    required this.idTokenGetter,
  });

  final NzwJpAuthRepository authRepo;
  final NzwJpApiClient apiClient;
  final Future<String?> Function() idTokenGetter;

  Future<GeminiResult> execute(String word) =>
      _query(GeminiPromptBuilder.forDictionaryWord(word));

  Future<GeminiResult> executeSuper(String word) =>
      _query(GeminiPromptBuilder.forSuperSearch(word));

  Future<GeminiResult> executeCustom(String prompt) => _query(prompt);

  Future<GeminiResult> _query(String prompt) async {
    var jwt = await authRepo.getValidJwt();
    if (jwt == null) {
      final idToken = await idTokenGetter();
      if (idToken == null) throw const NzwJpUnauthorizedException();
      jwt = await authRepo.authenticate(idToken);
    }

    try {
      return await apiClient.getGeminiResponse(prompt, jwt);
    } on NzwJpUnauthorizedException {
      await authRepo.clearJwt();
      final idToken = await idTokenGetter();
      if (idToken == null) rethrow;
      final newJwt = await authRepo.authenticate(idToken);
      return await apiClient.getGeminiResponse(prompt, newJwt);
    }
  }
}
