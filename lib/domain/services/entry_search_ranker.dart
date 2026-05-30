import '../dictionary_entry.dart';

/// 検索クエリに対するエントリのスコアリングを担うドメインサービス。
///
/// スコアリングルール:
/// - lang1/lang2 が前方一致: +100
/// - lang1/lang2 が部分一致: +50
/// - categories が部分一致: +20
/// - memo が部分一致: +10
class EntrySearchRanker {
  const EntrySearchRanker();

  /// スコアが 0 より大きいエントリをスコア降順で返す。
  List<DictionaryEntry> rank(List<DictionaryEntry> entries, String query) {
    final q = query.toLowerCase();
    final scored = <({DictionaryEntry entry, int score})>[];

    for (final e in entries) {
      final s = _score(e, q);
      if (s > 0) scored.add((entry: e, score: s));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((x) => x.entry).toList();
  }

  int _score(DictionaryEntry e, String q) {
    final l1 = e.lang1.toLowerCase();
    final l2 = e.lang2.toLowerCase();
    final memo = e.memo.toLowerCase();
    final cats = e.categories.map((c) => c.toLowerCase()).join(' ');
    var score = 0;
    if (l1.startsWith(q) || l2.startsWith(q)) score += 100;
    if (l1.contains(q) || l2.contains(q)) score += 50;
    if (cats.contains(q)) score += 20;
    if (memo.contains(q)) score += 10;
    return score;
  }
}
