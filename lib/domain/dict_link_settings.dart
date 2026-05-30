import 'dart:convert';

const _kDefaultOrder = [
  'aiAssist', 'super',
  'google', 'weblioJp', 'weblioEj', 'weblioCj', 'kotobank', 'wikipedia', 'ctrans',
];

/// 検索結果上部に表示する外部辞書リンクの ON/OFF・並び順設定。
class DictLinkSettings {
  const DictLinkSettings({
    this.showAiAssist = true,
    this.showSuper = true,
    this.showGoogle = true,
    this.showWeblioJp = true,
    this.showWeblioEj = false,
    this.showWeblioCj = false,
    this.showKotobank = false,
    this.showWikipedia = false,
    this.showCtrans = false,
    this.order = const [
      'aiAssist', 'super',
      'google', 'weblioJp', 'weblioEj', 'weblioCj', 'kotobank', 'wikipedia', 'ctrans',
    ],
  });

  final bool showAiAssist;
  final bool showSuper;
  final bool showGoogle;
  final bool showWeblioJp;
  final bool showWeblioEj;
  final bool showWeblioCj;
  final bool showKotobank;
  final bool showWikipedia;
  final bool showCtrans;
  /// チップの表示順。
  final List<String> order;

  /// 保存データに含まれない新 ID を末尾に補完した有効な順序リストを返す。
  List<String> effectiveOrder() {
    final missing = _kDefaultOrder.where((id) => !order.contains(id));
    return [...order, ...missing];
  }

  bool isEnabled(String id) => switch (id) {
        'aiAssist' => showAiAssist,
        'super' => showSuper,
        'google' => showGoogle,
        'weblioJp' => showWeblioJp,
        'weblioEj' => showWeblioEj,
        'weblioCj' => showWeblioCj,
        'kotobank' => showKotobank,
        'wikipedia' => showWikipedia,
        'ctrans' => showCtrans,
        _ => false,
      };

  DictLinkSettings setEnabled(String id, bool v) => switch (id) {
        'aiAssist' => copyWith(showAiAssist: v),
        'super' => copyWith(showSuper: v),
        'google' => copyWith(showGoogle: v),
        'weblioJp' => copyWith(showWeblioJp: v),
        'weblioEj' => copyWith(showWeblioEj: v),
        'weblioCj' => copyWith(showWeblioCj: v),
        'kotobank' => copyWith(showKotobank: v),
        'wikipedia' => copyWith(showWikipedia: v),
        'ctrans' => copyWith(showCtrans: v),
        _ => this,
      };

  DictLinkSettings copyWith({
    bool? showAiAssist,
    bool? showSuper,
    bool? showGoogle,
    bool? showWeblioJp,
    bool? showWeblioEj,
    bool? showWeblioCj,
    bool? showKotobank,
    bool? showWikipedia,
    bool? showCtrans,
    List<String>? order,
  }) =>
      DictLinkSettings(
        showAiAssist: showAiAssist ?? this.showAiAssist,
        showSuper: showSuper ?? this.showSuper,
        showGoogle: showGoogle ?? this.showGoogle,
        showWeblioJp: showWeblioJp ?? this.showWeblioJp,
        showWeblioEj: showWeblioEj ?? this.showWeblioEj,
        showWeblioCj: showWeblioCj ?? this.showWeblioCj,
        showKotobank: showKotobank ?? this.showKotobank,
        showWikipedia: showWikipedia ?? this.showWikipedia,
        showCtrans: showCtrans ?? this.showCtrans,
        order: order ?? this.order,
      );

  Map<String, dynamic> toJson() => {
        'showAiAssist': showAiAssist,
        'showSuper': showSuper,
        'showGoogle': showGoogle,
        'showWeblioJp': showWeblioJp,
        'showWeblioEj': showWeblioEj,
        'showWeblioCj': showWeblioCj,
        'showKotobank': showKotobank,
        'showWikipedia': showWikipedia,
        'showCtrans': showCtrans,
        'order': order,
      };

  factory DictLinkSettings.fromJson(Map<String, dynamic> j) => DictLinkSettings(
        showAiAssist: (j['showAiAssist'] as bool?) ?? true,
        showSuper: (j['showSuper'] as bool?) ?? true,
        showGoogle: (j['showGoogle'] as bool?) ?? true,
        showWeblioJp: (j['showWeblioJp'] as bool?) ?? true,
        showWeblioEj: (j['showWeblioEj'] as bool?) ?? false,
        showWeblioCj: (j['showWeblioCj'] as bool?) ?? false,
        showKotobank: (j['showKotobank'] as bool?) ?? false,
        showWikipedia: (j['showWikipedia'] as bool?) ?? false,
        showCtrans: (j['showCtrans'] as bool?) ?? false,
        order: (j['order'] as List<dynamic>?)?.cast<String>() ?? const [
          'aiAssist', 'super',
          'google', 'weblioJp', 'weblioEj', 'weblioCj', 'kotobank', 'wikipedia', 'ctrans',
        ],
      );

  factory DictLinkSettings.fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return const DictLinkSettings();
    try {
      return DictLinkSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const DictLinkSettings();
    }
  }
}
