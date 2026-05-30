enum AutoSyncSchedule { none, daily, weekly }

enum AutoSyncMode { addOnly, forceApply, mergeConfirm }

class SavedSyncUrl {
  const SavedSyncUrl({
    required this.id,
    required this.title,
    required this.url,
    required this.createdAt,
    this.lastImportedAt,
    this.lastExportedAt,
    this.autoSyncSchedule = AutoSyncSchedule.none,
    this.autoSyncMode = AutoSyncMode.addOnly,
    this.autoSyncSheetName,
    this.lastAutoSyncAt,
  });

  final String id;
  final String title;
  final String url;
  final DateTime createdAt;
  final DateTime? lastImportedAt;
  final DateTime? lastExportedAt;
  final AutoSyncSchedule autoSyncSchedule;
  final AutoSyncMode autoSyncMode;
  final String? autoSyncSheetName; // null = 全シート自動検出
  final DateTime? lastAutoSyncAt;

  bool get isAutoSyncEnabled => autoSyncSchedule != AutoSyncSchedule.none;

  /// 次回自動同期予定日時。スケジュールが none の場合は null。
  DateTime? get nextAutoSyncAt {
    if (autoSyncSchedule == AutoSyncSchedule.none) return null;
    final base = lastAutoSyncAt ?? createdAt;
    return switch (autoSyncSchedule) {
      AutoSyncSchedule.daily => base.add(const Duration(hours: 24)),
      AutoSyncSchedule.weekly => base.add(const Duration(days: 7)),
      AutoSyncSchedule.none => null,
    };
  }

  SavedSyncUrl copyWith({
    String? title,
    String? url,
    DateTime? lastImportedAt,
    DateTime? lastExportedAt,
    AutoSyncSchedule? autoSyncSchedule,
    AutoSyncMode? autoSyncMode,
    Object? autoSyncSheetName = _sentinel,
    DateTime? lastAutoSyncAt,
  }) {
    return SavedSyncUrl(
      id: id,
      title: title ?? this.title,
      url: url ?? this.url,
      createdAt: createdAt,
      lastImportedAt: lastImportedAt ?? this.lastImportedAt,
      lastExportedAt: lastExportedAt ?? this.lastExportedAt,
      autoSyncSchedule: autoSyncSchedule ?? this.autoSyncSchedule,
      autoSyncMode: autoSyncMode ?? this.autoSyncMode,
      autoSyncSheetName: autoSyncSheetName == _sentinel
          ? this.autoSyncSheetName
          : autoSyncSheetName as String?,
      lastAutoSyncAt: lastAutoSyncAt ?? this.lastAutoSyncAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'createdAt': createdAt.toIso8601String(),
        'lastImportedAt': lastImportedAt?.toIso8601String(),
        'lastExportedAt': lastExportedAt?.toIso8601String(),
        'autoSyncSchedule': autoSyncSchedule.name,
        'autoSyncMode': autoSyncMode.name,
        'autoSyncSheetName': autoSyncSheetName,
        'lastAutoSyncAt': lastAutoSyncAt?.toIso8601String(),
      };

  factory SavedSyncUrl.fromJson(Map<String, dynamic> map) => SavedSyncUrl(
        id: map['id'] as String,
        title: map['title'] as String,
        url: map['url'] as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
        lastImportedAt: map['lastImportedAt'] != null
            ? DateTime.parse(map['lastImportedAt'] as String)
            : null,
        lastExportedAt: map['lastExportedAt'] != null
            ? DateTime.parse(map['lastExportedAt'] as String)
            : null,
        autoSyncSchedule: AutoSyncSchedule.values.firstWhere(
          (e) => e.name == map['autoSyncSchedule'],
          orElse: () => AutoSyncSchedule.none,
        ),
        autoSyncMode: AutoSyncMode.values.firstWhere(
          (e) => e.name == map['autoSyncMode'],
          orElse: () => AutoSyncMode.addOnly,
        ),
        autoSyncSheetName: map['autoSyncSheetName'] as String?,
        lastAutoSyncAt: map['lastAutoSyncAt'] != null
            ? DateTime.parse(map['lastAutoSyncAt'] as String)
            : null,
      );
}

// copyWith で nullable フィールドを明示的に null にセットするためのセンチネル。
const _sentinel = Object();
