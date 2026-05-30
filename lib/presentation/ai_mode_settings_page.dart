import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';

class AiModeSettingsPage extends ConsumerStatefulWidget {
  const AiModeSettingsPage({super.key});

  @override
  ConsumerState<AiModeSettingsPage> createState() => _AiModeSettingsPageState();
}

class _AiModeSettingsPageState extends ConsumerState<AiModeSettingsPage> {
  final _langController = TextEditingController();

  @override
  void dispose() {
    _langController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(aiModeSettingsProvider);
    final notifier = ref.read(aiModeSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('AI モード設定')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 32 + MediaQuery.of(context).padding.bottom),
        children: [
          // ── モード管理 ─────────────────────────────────
          _sectionTitle(theme, 'モード管理'),
          Text(
            '長押しして並び替え。スイッチで表示/非表示を切り替えます。',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              dense: true,
              secondary: Icon(
                Icons.auto_awesome,
                size: 20,
                color: settings.autoExecuteTop
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              title: const Text('まとめ実行'),
              subtitle: Text(
                settings.autoExecuteTop
                    ? '「まとめて」を選択画面なしで即実行'
                    : '毎回モード選択',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              value: settings.autoExecuteTop,
              onChanged: notifier.setAutoExecuteTop,
            ),
          ),
          const SizedBox(height: 24),

          // ── 翻訳言語 ───────────────────────────────────
          _sectionTitle(theme, '翻訳言語'),
          Text(
            '「他言語訳」で選択できる言語を管理します。長押しで並び替え可能です。',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorderItem: notifier.reorderLanguage,
              children: [
                for (final lang in settings.availableLanguages)
                  ListTile(
                    key: ValueKey(lang),
                    dense: true,
                    title: Text(lang),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 18,
                              color: theme.colorScheme.error),
                          visualDensity: VisualDensity.compact,
                          tooltip: '削除',
                          onPressed: () => notifier.removeLanguage(lang),
                        ),
                        const Icon(Icons.drag_handle,
                            size: 20),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _langController,
                  decoration: const InputDecoration(
                    labelText: '言語を追加',
                    hintText: '例: タガログ語',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (v) {
                    notifier.addLanguage(v);
                    _langController.clear();
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () {
                  notifier.addLanguage(_langController.text);
                  _langController.clear();
                },
                child: const Text('追加'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String title) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      );
}
