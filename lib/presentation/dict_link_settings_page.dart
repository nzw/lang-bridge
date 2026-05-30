import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';

class DictLinkSettingsPage extends ConsumerWidget {
  const DictLinkSettingsPage({super.key});

  static const _titles = {
    'aiAssist': 'AI',
    'google': 'Google 検索',
    'weblioJp': 'Weblio 国語',
    'weblioEj': 'Weblio 英和・和英',
    'weblioCj': 'Weblio 日中・中日',
    'kotobank': 'コトバンク',
    'wikipedia': 'Wikipedia',
    'ctrans': 'ctrans.org',
  };

  static const _subtitles = {
    'aiAssist': 'Gemini AI による意味・例文・類義語をボトムシートに表示',
    'google': 'google.com/search?q=…',
    'weblioJp': 'weblio.jp/content/…',
    'weblioEj': 'ejje.weblio.jp/content/…',
    'weblioCj': 'cjjc.weblio.jp/content/…',
    'kotobank': 'kotobank.jp/word/…',
    'wikipedia': 'ja.wikipedia.org/wiki/…',
    'ctrans': 'ctrans.org/search.php?word=…&optext=中国語前方一致',
  };

  static const _aiFeatureIds = {'aiAssist'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(dictLinkSettingsProvider);
    final aiEnabled = ref.watch(nzwJpAiEnabledProvider);
    final order = settings.effectiveOrder();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('外部辞書の設定')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // AI機能セクションのヘッダー
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 14),
                const SizedBox(width: 6),
                Text(
                  'AI 機能（利用者限定）',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                if (aiEnabled == false)
                  Chip(
                    label: const Text('このアカウントは対象外'),
                    labelStyle: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.onErrorContainer),
                    backgroundColor: cs.errorContainer,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ReorderableListView(
              onReorderItem: (oldIndex, newIndex) {
                final next = List<String>.from(order);
                next.insert(newIndex, next.removeAt(oldIndex));
                ref
                    .read(dictLinkSettingsProvider.notifier)
                    .update(settings.copyWith(order: next));
              },
              children: [
                for (var i = 0; i < order.length; i++)
                  _DictLinkTile(
                    key: ValueKey(order[i]),
                    index: i,
                    title: _titles[order[i]] ?? order[i],
                    subtitle: _subtitles[order[i]] ?? '',
                    value: settings.isEnabled(order[i]),
                    isAiFeature: _aiFeatureIds.contains(order[i]),
                    onChanged: (v) => ref
                        .read(dictLinkSettingsProvider.notifier)
                        .update(settings.setEnabled(order[i], v)),
                    subtitleStyle: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DictLinkTile extends StatelessWidget {
  const _DictLinkTile({
    super.key,
    required this.index,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.isAiFeature,
    this.subtitleStyle,
  });

  final int index;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isAiFeature;
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SwitchListTile(
      dense: true,
      contentPadding: const EdgeInsets.fromLTRB(16, 2, 12, 2),
      tileColor: isAiFeature ? cs.primaryContainer.withValues(alpha: 0.3) : null,
      secondary: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_handle, size: 20),
      ),
      title: Row(
        children: [
          if (isAiFeature) ...[
            const Icon(Icons.auto_awesome, size: 14),
            const SizedBox(width: 4),
          ],
          Text(title),
        ],
      ),
      subtitle: Text(subtitle, style: subtitleStyle),
      value: value,
      onChanged: onChanged,
    );
  }
}
