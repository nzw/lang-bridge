import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di/providers.dart';
import '../../domain/dictionary_entry.dart';
import '../../domain/gemini_result.dart';
import '../../infrastructure/external/nzwjp/nzwjp_exceptions.dart';

class AiExplanationBottomSheet extends ConsumerStatefulWidget {
  const AiExplanationBottomSheet({
    super.key,
    required this.word,
    required this.fetchExplanation,
    this.onSuccess,
    this.onForbidden,
    this.onRateLimit,
  });

  final String word;
  final Future<GeminiResult> Function() fetchExplanation;
  final void Function(GeminiResult result)? onSuccess;
  final VoidCallback? onForbidden;
  final VoidCallback? onRateLimit;

  @override
  ConsumerState<AiExplanationBottomSheet> createState() =>
      _AiExplanationBottomSheetState();
}

class _AiExplanationBottomSheetState
    extends ConsumerState<AiExplanationBottomSheet> {
  late Future<GeminiResult> _future;

  // エラー時の自動クローズを FutureBuilder ビルドサイクル内で行うためのフラグ。
  // initState の非同期コールバックから直接 Navigator.pop を呼ぶと
  // InheritedElement のdeactivate と競合して _dependents.isEmpty アサーションが
  // 発生するため、ここで状態を持って build 側に委譲する。
  bool _pendingDismiss = false;
  void Function()? _pendingCallback;

  @override
  void initState() {
    super.initState();
    _future = widget.fetchExplanation().then((v) {
      // 親ウィジェットへの通知はポストフレームで行うが、
      // このシート自体の操作（pop）は行わない。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onSuccess?.call(v);
      });
      return v;
    }, onError: (Object e) {
      // 自動クローズが必要なエラーは状態変数にセットし、
      // build() → FutureBuilder 内でポストフレームコールバックを登録する。
      if (e is NzwJpForbiddenException) {
        _pendingCallback = widget.onForbidden;
        if (mounted) setState(() => _pendingDismiss = true);
      } else if (e is NzwJpRateLimitException) {
        _pendingCallback = widget.onRateLimit;
        if (mounted) setState(() => _pendingDismiss = true);
      }
      throw e;
    });
  }

  Future<void> _copy(String response) async {
    await Clipboard.setData(ClipboardData(text: response));
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
              TextField(
                  controller: lang1,
                  decoration: const InputDecoration(labelText: 'ソース言語')),
              TextField(
                  controller: lang2,
                  decoration: const InputDecoration(labelText: 'ターゲット言語')),
              TextField(
                  controller: memo,
                  decoration: const InputDecoration(labelText: 'メモ'),
                  maxLines: 3),
              TextField(
                  controller: category,
                  decoration:
                      const InputDecoration(labelText: 'カテゴリ(//区切り)')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル')),
          FilledButton(
            onPressed: () async {
              final now = DateTime.now();
              final entry = DictionaryEntry(
                id: 'user-${now.microsecondsSinceEpoch}',
                lang1: lang1.text.trim(),
                lang2: lang2.text.trim(),
                memo: memo.text.trim(),
                categories: category.text
                    .split('//')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList(),
                sourceType: EntrySourceType.manual,
                createdAt: now,
                updatedAt: now,
              );
              await ref
                  .read(createOrUpdateUserEntryUseCaseProvider)
                  .execute(entry);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // エラー自動クローズのフラグが立っていればポストフレームでポップする。
    // build() 内で直接 Navigator.pop を呼ぶと InheritedElement の
    // deactivate と競合するため、次フレームへ委譲する。
    if (_pendingDismiss) {
      _pendingDismiss = false; // setState 不要 — 次ビルドを再トリガーしない
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pendingCallback?.call();
        _pendingCallback = null;
        Navigator.pop(context);
      });
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
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
                  child: Text(
                    '「${widget.word}」',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
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
            child: FutureBuilder<GeminiResult>(
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
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                  );
                }
                final result = snapshot.data;
                final response = result?.text ?? '';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Text(
                          response,
                          style:
                              theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                        ),
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
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const SizedBox(width: 4),
                          TextButton.icon(
                            onPressed: () => _register(response),
                            icon: const Icon(Icons.add_circle_outline, size: 16),
                            label: const Text('単語登録'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
