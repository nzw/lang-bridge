import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ai_mode.dart';
import '../../domain/ai_mode_settings.dart';
import '../../infrastructure/local/ai_mode_settings_store.dart';

class AiModeSettingsNotifier extends StateNotifier<AiModeSettings> {
  AiModeSettingsNotifier(this._store) : super(AiModeSettings.defaults) {
    _load();
  }

  final AiModeSettingsStore _store;

  Future<void> _load() async {
    state = await _store.load();
  }

  Future<void> _save() => _store.save(state);

  void setAutoExecuteTop(bool value) {
    state = state.copyWith(autoExecuteTop: value);
    _save();
  }

  void toggleVisibility(AiMode mode) {
    final hidden = Set<AiMode>.from(state.hiddenModes);
    if (hidden.contains(mode)) {
      hidden.remove(mode);
    } else {
      hidden.add(mode);
    }
    state = state.copyWith(hiddenModes: hidden);
    _save();
  }

  void reorder(int oldIndex, int newIndex) {
    final list = [...state.orderedModes];
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = state.copyWith(orderedModes: list);
    _save();
  }

  void setTopLanguages(List<String> selected) {
    final rest =
        state.availableLanguages.where((l) => !selected.contains(l)).toList();
    state = state.copyWith(availableLanguages: [...selected, ...rest]);
    _save();
  }

  void addLanguage(String lang) {
    final trimmed = lang.trim();
    if (trimmed.isEmpty || state.availableLanguages.contains(trimmed)) return;
    state = state.copyWith(
        availableLanguages: [...state.availableLanguages, trimmed]);
    _save();
  }

  void removeLanguage(String lang) {
    state = state.copyWith(
        availableLanguages:
            state.availableLanguages.where((l) => l != lang).toList());
    _save();
  }

  void reorderLanguage(int oldIndex, int newIndex) {
    final list = [...state.availableLanguages];
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = state.copyWith(availableLanguages: list);
    _save();
  }
}

final aiModeSettingsProvider =
    StateNotifierProvider<AiModeSettingsNotifier, AiModeSettings>(
  (ref) => AiModeSettingsNotifier(AiModeSettingsStore()),
);
