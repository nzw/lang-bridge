import 'package:shared_preferences/shared_preferences.dart';

class AiTranslationPrefsStore {
  static const _key = 'ai_translation_selected_langs_v1';

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? ['英語'];
  }

  Future<void> save(List<String> langs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, langs);
  }
}
