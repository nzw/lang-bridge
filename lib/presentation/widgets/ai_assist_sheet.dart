import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di/providers.dart';
import '../../domain/ai_mode.dart';
import '../../domain/dictionary_entry.dart';
import '../../domain/gemini_result.dart';
import '../../infrastructure/external/nzwjp/gemini_prompt_builder.dart';
import '../../infrastructure/external/nzwjp/nzwjp_exceptions.dart';

class AiAssistSheet extends ConsumerStatefulWidget {
  const AiAssistSheet({
    super.key,
    required this.word,
    this.autoExecuteMode,
    this.onSuccess,
    this.onForbidden,
    this.onRateLimit,
  });

  final String word;
  final AiMode? autoExecuteMode;
  final void Function(GeminiResult)? onSuccess;
  final VoidCallback? onForbidden;
  final VoidCallback? onRateLimit;

  @override
  ConsumerState<AiAssistSheet> createState() => _AiAssistSheetState();
}

class _AiAssistSheetState extends ConsumerState<AiAssistSheet> {
  AiMode? _mode;
  Future<GeminiResult>? _future;
  bool _showingLanguagePicker = false;
  List<String> _selectedLanguages = [];

  bool _pendingDismiss = false;
  void Function()? _pendingCallback;

  @override
  void initState() {
    super.initState();
    final auto = widget.autoExecuteMode;
    if (auto != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _execute(auto);
      });
    }
  }

  void _selectMode(AiMode mode) {
    if (mode == AiMode.translation) {
      final langs = ref.read(aiModeSettingsProvider).availableLanguages;
      setState(() {
        _selectedLanguages = langs.take(3).toList();
        _showingLanguagePicker = true;
      });
      return;
    }
    _execute(mode);
  }

  void _execute(AiMode mode) {
    final prompt = _buildPrompt(mode);
    final useCase = ref.read(getAiExplanationUseCaseProvider);
    setState(() {
      _mode = mode;
      _future = useCase.executeCustom(prompt).then((v) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onSuccess?.call(v);
        });
        return v;
      }, onError: (Object e) {
        if (e is NzwJpForbiddenException) {
          _pendingCallback = widget.onForbidden;
          if (mounted) setState(() => _pendingDismiss = true);
        } else if (e is NzwJpRateLimitException) {
          _pendingCallback = widget.onRateLimit;
          if (mounted) setState(() => _pendingDismiss = true);
        }
        throw e;
      });
    });
  }

  String _buildPrompt(AiMode mode) {
    switch (mode) {
      case AiMode.dictionary:
        return GeminiPromptBuilder.forDictionarySearch(widget.word);
      case AiMode.examples:
        return GeminiPromptBuilder.forExamples(widget.word);
      case AiMode.definition:
        return GeminiPromptBuilder.forDefinition(widget.word);
      case AiMode.synonyms:
        return GeminiPromptBuilder.forSynonyms(widget.word);
      case AiMode.translation:
        return GeminiPromptBuilder.forTranslation(widget.word, _selectedLanguages);
      case AiMode.comprehensive:
        return GeminiPromptBuilder.forComprehensive(widget.word);
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('コピーしました'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 2),
    ));
  }

  Future<void> _register(String response) async {
    final lang1 = TextEditingController(text: widget.word);
    final lang2 = TextEditingController();
    final memo = TextEditingController(text: response);
    final category = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('単語を登録'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: lang1, decoration: const InputDecoration(labelText: 'ソース言語')),
              TextField(controller: lang2, decoration: const InputDecoration(labelText: 'ターゲット言語')),
              TextField(controller: memo, decoration: const InputDecoration(labelText: 'メモ'), maxLines: 3),
              TextField(controller: category, decoration: const InputDecoration(labelText: 'カテゴリ(//区切り)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () async {
              final now = DateTime.now();
              final entry = DictionaryEntry(
                id: 'user-${now.microsecondsSinceEpoch}',
                lang1: lang1.text.trim(),
                lang2: lang2.text.trim(),
                memo: memo.text.trim(),
                categories: category.text.split('//').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                sourceType: EntrySourceType.manual,
                createdAt: now,
                updatedAt: now,
              );
              await ref.read(createOrUpdateUserEntryUseCaseProvider).execute(entry);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _goBack() => setState(() {
        _mode = null;
        _future = null;
        _showingLanguagePicker = false;
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_pendingDismiss) {
      _pendingDismiss = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pendingCallback?.call();
        _pendingCallback = null;
        Navigator.pop(context);
      });
    }

    final showBack = _mode != null || _showingLanguagePicker;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '「${widget.word}」',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_mode != null)
                        Text(
                          aiModeLabels[_mode!]!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (showBack)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    visualDensity: VisualDensity.compact,
                    tooltip: '選択に戻る',
                    onPressed: _goBack,
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Builder(builder: (context) {
              final settings = ref.watch(aiModeSettingsProvider);
              if (_mode != null) return _buildResult(theme, scrollController);
              if (_showingLanguagePicker) {
                return _buildLanguagePicker(
                    theme, scrollController, settings.availableLanguages);
              }
              return _buildModeSelection(
                  theme, scrollController, settings.visibleModes);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelection(ThemeData theme, ScrollController scrollController,
      List<AiMode> visibleModes) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final mode in visibleModes) ...[
            _ModeButton(
              icon: aiModeIcons[mode]!,
              label: aiModeLabels[mode]!,
              description: aiModeDescriptions[mode]!,
              highlighted: mode == AiMode.comprehensive,
              needsSubSelection: mode == AiMode.translation,
              onTap: () => _selectMode(mode),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildLanguagePicker(ThemeData theme, ScrollController scrollController,
      List<String> availableLanguages) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('翻訳先の言語を選択（最大3つ）',
                    style: theme.textTheme.labelLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final lang in availableLanguages)
                      FilterChip(
                        label: Text(lang),
                        selected: _selectedLanguages.contains(lang),
                        onSelected: (_selectedLanguages.contains(lang) ||
                                _selectedLanguages.length < 3)
                            ? (v) {
                                setState(() {
                                  if (v) {
                                    _selectedLanguages.add(lang);
                                  } else {
                                    _selectedLanguages.remove(lang);
                                  }
                                });
                              }
                            : null,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            icon: const Icon(Icons.translate),
            label: Text(_selectedLanguages.isEmpty
                ? '言語を選択してください'
                : '${_selectedLanguages.length}言語に翻訳'),
            onPressed: _selectedLanguages.isEmpty
                ? null
                : () {
                    ref
                        .read(aiModeSettingsProvider.notifier)
                        .setTopLanguages(_selectedLanguages);
                    _execute(AiMode.translation);
                  },
          ),
        ),
      ],
    );
  }

  Widget _buildResult(ThemeData theme, ScrollController scrollController) {
    return FutureBuilder<GeminiResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              snapshot.error.toString(),
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
            ),
          );
        }
        final response = snapshot.data?.text ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(response,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _copy(response),
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    label: const Text('コピー'),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: () => _register(response),
                    icon: const Icon(Icons.add_circle_outline, size: 16),
                    label: const Text('単語登録'),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.highlighted,
    required this.needsSubSelection,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool highlighted;
  final bool needsSubSelection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bg = highlighted ? cs.primaryContainer : cs.surfaceContainerHighest;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: highlighted ? cs.onPrimaryContainer : cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: highlighted ? cs.onPrimaryContainer : cs.onSurface,
                        )),
                    Text(
                      needsSubSelection ? '$description →' : description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: highlighted ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (needsSubSelection)
                Icon(Icons.chevron_right,
                    size: 18,
                    color: highlighted ? cs.onPrimaryContainer : cs.onSurfaceVariant)
              else
                Icon(Icons.send_rounded,
                    size: 15,
                    color: highlighted ? cs.onPrimaryContainer : cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}
