import 'ai_mode.dart';

class AiModeSettings {
  const AiModeSettings({
    required this.orderedModes,
    required this.hiddenModes,
    required this.autoExecuteTop,
    required this.availableLanguages,
  });

  final List<AiMode> orderedModes;
  final Set<AiMode> hiddenModes;
  final bool autoExecuteTop;
  final List<String> availableLanguages;

  static AiModeSettings get defaults => AiModeSettings(
        orderedModes: AiMode.values.toList(),
        hiddenModes: const {},
        autoExecuteTop: false,
        availableLanguages: aiModeDefaultLanguages.toList(),
      );

  List<AiMode> get visibleModes =>
      orderedModes.where((m) => !hiddenModes.contains(m)).toList();

  /// autoExecuteTop が ON の場合、まとめて（comprehensive）モードを返す。OFF なら null。
  AiMode? get effectiveFixedMode =>
      autoExecuteTop ? AiMode.comprehensive : null;

  AiModeSettings copyWith({
    List<AiMode>? orderedModes,
    Set<AiMode>? hiddenModes,
    bool? autoExecuteTop,
    List<String>? availableLanguages,
  }) =>
      AiModeSettings(
        orderedModes: orderedModes ?? this.orderedModes,
        hiddenModes: hiddenModes ?? this.hiddenModes,
        autoExecuteTop: autoExecuteTop ?? this.autoExecuteTop,
        availableLanguages: availableLanguages ?? this.availableLanguages,
      );

  Map<String, dynamic> toJson() => {
        'orderedModes': orderedModes.map((m) => m.name).toList(),
        'hiddenModes': hiddenModes.map((m) => m.name).toList(),
        'autoExecuteTop': autoExecuteTop,
        'availableLanguages': availableLanguages,
      };

  factory AiModeSettings.fromJson(Map<String, dynamic> json) {
    AiMode? parseMode(String? name) {
      if (name == null) return null;
      try {
        return AiMode.values.firstWhere((m) => m.name == name);
      } catch (_) {
        return null;
      }
    }

    final ordered = (json['orderedModes'] as List<dynamic>?)
            ?.map((e) => parseMode(e as String?))
            .whereType<AiMode>()
            .toList() ??
        [];
    final missing = AiMode.values.where((m) => !ordered.contains(m));
    final orderedModes = [...ordered, ...missing];

    final hidden = (json['hiddenModes'] as List<dynamic>?)
            ?.map((e) => parseMode(e as String?))
            .whereType<AiMode>()
            .toSet() ??
        {};

    final langs = (json['availableLanguages'] as List<dynamic>?)
            ?.whereType<String>()
            .toList() ??
        aiModeDefaultLanguages.toList();

    // 旧フォーマット(fixedMode)からのマイグレーション
    final autoExecuteTop = json['autoExecuteTop'] as bool? ??
        (json['fixedMode'] != null);

    return AiModeSettings(
      orderedModes: orderedModes,
      hiddenModes: hidden,
      autoExecuteTop: autoExecuteTop,
      availableLanguages: langs,
    );
  }
}
