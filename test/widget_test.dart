// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:langbridge_cn_jp/app/app.dart';
import 'package:langbridge_cn_jp/presentation/flashcard_page.dart';

void main() {
  testWidgets('検索UIが表示される', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: DictionaryApp()));
    expect(find.text('日中辞書'), findsOneWidget);
    expect(find.text('検索 (曖昧検索)'), findsOneWidget);
  });

  testWidgets('単語カード画面へ遷移できる', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: DictionaryApp()));
    await tester.tap(find.byTooltip('単語カード'));
    await tester.pumpAndSettle();
    expect(find.byType(FlashcardPage), findsOneWidget);
    expect(find.text('単語カード学習'), findsOneWidget);
  });
}
