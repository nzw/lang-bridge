import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FilterCategoriesNotifier extends StateNotifier<Set<String>> {
  FilterCategoriesNotifier() : super(const {}) {
    _load();
  }

  static const _key = 'filter_categories_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key);
    if (saved != null && mounted) state = saved.toSet();
  }

  Future<void> update(Set<String> cats) async {
    state = cats;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, cats.toList());
  }
}

final filterCategoriesProvider =
    StateNotifierProvider<FilterCategoriesNotifier, Set<String>>(
  (ref) => FilterCategoriesNotifier(),
);
