class GeminiPromptBuilder {
  static String forDictionarySearch(String word) =>
      '「$word」について以下を教えてください：\n'
      '1. 意味・ニュアンス\n'
      '2. 日本語例文（1つ）\n'
      '3. 中国語例文（1つ）';

  static String forExamples(String word) =>
      '「$word」を使った自然な例文を示してください：\n'
      '日本語例文（3つ）と中国語例文（3つ）を番号付きで。\n'
      '中国語例文には日本語訳を添えてください。';

  static String forDefinition(String word) =>
      '「$word」について以下を詳しく説明してください：\n'
      '1. 詳細な意味・定義\n'
      '2. 語源・由来（分かる場合）\n'
      '3. 使用場面・ニュアンス・注意点';

  static String forSynonyms(String word) =>
      '「$word」について以下を示してください：\n'
      '1. 類義語（3〜5個）と使い分けのポイント\n'
      '2. 反義語（あれば）\n'
      '3. 関連する表現・慣用句';

  static String forTranslation(String word, List<String> languages) {
    final langList = languages.join('、');
    return '「$word」を以下の言語に翻訳してください：$langList\n'
        '各言語について ① 翻訳語 ② 読み方（カナまたはローマ字）③ 例文（1つ）を示してください。';
  }

  static String forComprehensive(String word) =>
      '「$word」について以下をまとめて教えてください：\n'
      '1. 意味・ニュアンス\n'
      '2. 日本語例文（2つ）\n'
      '3. 中国語例文（2つ）\n'
      '4. 類義語・反義語\n'
      '5. 語源・豆知識（あれば）';

  // 後方互換
  static String forDictionaryWord(String word) => forDictionarySearch(word);
  static String forSuperSearch(String word) => forComprehensive(word);
}
