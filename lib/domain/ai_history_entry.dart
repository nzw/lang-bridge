class AiHistoryEntry {
  const AiHistoryEntry({
    required this.id,
    required this.word,
    required this.response,
    required this.createdAt,
  });

  final String id;
  final String word;
  final String response;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'word': word,
        'response': response,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AiHistoryEntry.fromJson(Map<String, dynamic> json) => AiHistoryEntry(
        id: json['id'] as String,
        word: json['word'] as String,
        response: json['response'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
