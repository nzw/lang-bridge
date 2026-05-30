import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/ai_mode_settings.dart';

class AiModeSettingsStore {
  static const _key = 'ai_mode_settings_v1';

  Future<AiModeSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return AiModeSettings.defaults;
    try {
      return AiModeSettings.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return AiModeSettings.defaults;
    }
  }

  Future<void> save(AiModeSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}
