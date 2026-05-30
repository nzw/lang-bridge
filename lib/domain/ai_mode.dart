import 'package:flutter/material.dart';

enum AiMode {
  dictionary,
  examples,
  definition,
  synonyms,
  translation,
  comprehensive,
}

const aiModeLabels = {
  AiMode.dictionary: '辞書検索',
  AiMode.examples: '例文集',
  AiMode.definition: '意味・解説',
  AiMode.synonyms: '類義語',
  AiMode.translation: '他言語訳',
  AiMode.comprehensive: 'まとめて',
};

const aiModeDescriptions = {
  AiMode.dictionary: '意味・ニュアンス + 日中例文',
  AiMode.examples: '豊富な例文（日中各3つ）',
  AiMode.definition: '詳しい定義・語源・使用場面',
  AiMode.synonyms: '類義語・反義語・関連表現',
  AiMode.translation: '設定リスト上位3言語に翻訳',
  AiMode.comprehensive: '意味・例文・類義語・豆知識を一括表示',
};

const aiModeIcons = {
  AiMode.dictionary: Icons.menu_book_outlined,
  AiMode.examples: Icons.format_list_bulleted,
  AiMode.definition: Icons.info_outline,
  AiMode.synonyms: Icons.compare_arrows,
  AiMode.translation: Icons.translate,
  AiMode.comprehensive: Icons.auto_awesome,
};

const aiModeDefaultLanguages = [
  '日本語', '英語', '韓国語', 'フランス語', 'スペイン語',
  'ドイツ語', 'ポルトガル語', 'イタリア語', 'ロシア語',
  'ベトナム語', 'タイ語', 'インドネシア語', 'アラビア語',
];
