enum EntrySourceType { external, userSheet, manual }

class DictionaryEntry {
  const DictionaryEntry({
    required this.id,
    required this.lang1,
    required this.lang2,
    this.memo = '',
    this.categories = const [],
    this.isFavorite = false,
    this.reviewScore = 0,
    required this.sourceType,
    this.sourceUrl,
    this.importSessionId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String lang1;
  final String lang2;
  final String memo;
  final List<String> categories;
  final bool isFavorite;
  final int reviewScore;
  final EntrySourceType sourceType;
  /// スプレッドシート取込時の元URL
  final String? sourceUrl;
  /// 同一インポート操作を識別するID（インポートボタンを押すたびに新しい値）
  final String? importSessionId;
  /// 取込（作成）日時
  final DateTime? createdAt;
  /// 最終更新日時
  final DateTime? updatedAt;

  DictionaryEntry copyWith({
    String? id,
    String? lang1,
    String? lang2,
    String? memo,
    List<String>? categories,
    bool? isFavorite,
    int? reviewScore,
    EntrySourceType? sourceType,
    String? sourceUrl,
    String? importSessionId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DictionaryEntry(
      id: id ?? this.id,
      lang1: lang1 ?? this.lang1,
      lang2: lang2 ?? this.lang2,
      memo: memo ?? this.memo,
      categories: categories ?? this.categories,
      isFavorite: isFavorite ?? this.isFavorite,
      reviewScore: reviewScore ?? this.reviewScore,
      sourceType: sourceType ?? this.sourceType,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      importSessionId: importSessionId ?? this.importSessionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lang1': lang1,
        'lang2': lang2,
        'memo': memo,
        'categories': categories,
        'isFavorite': isFavorite,
        'reviewScore': reviewScore,
        'sourceType': sourceType.name,
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
        if (importSessionId != null) 'importSessionId': importSessionId,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory DictionaryEntry.fromJson(Map<String, dynamic> json) =>
      DictionaryEntry(
        id: json['id'] as String,
        lang1: json['lang1'] as String,
        lang2: json['lang2'] as String,
        memo: (json['memo'] as String?) ?? '',
        categories: (json['categories'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        isFavorite: (json['isFavorite'] as bool?) ?? false,
        reviewScore: (json['reviewScore'] as int?) ?? 0,
        sourceType: EntrySourceType.values.firstWhere(
          (e) => e.name == json['sourceType'],
          orElse: () => EntrySourceType.userSheet,
        ),
        sourceUrl: json['sourceUrl'] as String?,
        importSessionId: json['importSessionId'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
      );

  /// エンティティの同一性は id で判断する。
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DictionaryEntry && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'DictionaryEntry(id: $id, lang1: $lang1, lang2: $lang2)';
}
