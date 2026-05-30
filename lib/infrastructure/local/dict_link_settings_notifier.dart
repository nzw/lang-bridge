import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/dict_link_settings.dart';

const _kKey = 'dict_link_settings_v1';

class DictLinkSettingsNotifier extends StateNotifier<DictLinkSettings> {
  DictLinkSettingsNotifier() : super(const DictLinkSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    state = DictLinkSettings.fromJsonString(raw);
  }

  Future<void> update(DictLinkSettings next) async {
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(next.toJson()));
  }
}
