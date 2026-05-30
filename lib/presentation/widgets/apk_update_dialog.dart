import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_config.dart';
import '../../infrastructure/update/update_info.dart';

enum _Phase { idle, downloading, launching, error }

class ApkUpdateDialog extends StatefulWidget {
  const ApkUpdateDialog({super.key, required this.info});

  final UpdateInfo info;

  @override
  State<ApkUpdateDialog> createState() => _ApkUpdateDialogState();
}

class _ApkUpdateDialogState extends State<ApkUpdateDialog> {
  _Phase _phase = _Phase.idle;
  double? _progress;
  String? _apkPath;

  static const _channel = MethodChannel('jp.langbridge/install_apk');

  Future<void> _openChangelog() async {
    final uri = Uri.parse(AppConfig.changelogUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _phase = _Phase.downloading;
      _progress = null;
    });
    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/LangBridge_update.apk';

      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(widget.info.downloadUrl));
      final res = await req.close();

      final total = res.contentLength;
      var received = 0;
      final file = File(savePath);
      final sink = file.openWrite();
      await for (final chunk in res) {
        sink.add(chunk);
        received += chunk.length;
        if (mounted) {
          setState(() => _progress = total > 0 ? received / total : null);
        }
      }
      await sink.close();
      client.close();

      if (!mounted) return;
      _apkPath = savePath;
      setState(() {
        _phase = _Phase.launching;
        _progress = 1.0;
      });
      await _channel.invokeMethod<void>('installApk', {'path': savePath});
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _relaunchInstaller() async {
    if (_apkPath == null) return;
    try {
      await _channel.invokeMethod<void>('installApk', {'path': _apkPath!});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isForce = info.isForceUpdate;
    final isIdle = _phase == _Phase.idle;
    final isDownloading = _phase == _Phase.downloading;
    final isLaunching = _phase == _Phase.launching;
    final isError = _phase == _Phase.error;

    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // アイコン
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : isLaunching
                      ? Icons.check_circle_outline_rounded
                      : Icons.system_update_rounded,
              size: 38,
              color: isError
                  ? cs.error
                  : isLaunching
                      ? Colors.green
                      : cs.primary,
            ),
            const SizedBox(height: 10),

            // タイトル
            Text(
              isError
                  ? 'ダウンロード失敗'
                  : isDownloading
                      ? 'ダウンロード中'
                      : isLaunching
                          ? 'インストール準備完了'
                          : isForce
                              ? '必須アップデートがあります'
                              : 'アップデートがあります',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // アイドル: バージョン比較 + 更新内容 + リリースノート
            if (isIdle) ...[
              _VersionCompareRow(
                currentVersion: AppConfig.appVersion,
                latestVersion: info.latestVersion,
                colorScheme: cs,
                textTheme: theme.textTheme,
              ),
              if (info.releaseNotes != null && info.releaseNotes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'v${info.latestVersion} の変更内容',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...info.releaseNotes!.map(
                        (note) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.fiber_manual_record,
                                  size: 7,
                                  color: cs.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(note,
                                    style: theme.textTheme.bodySmall),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: _openChangelog,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '変更履歴を見る',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.primary,
                            decoration: TextDecoration.underline,
                            decorationColor: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(Icons.open_in_new_rounded,
                            size: 13, color: cs.primary),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],

            // ダウンロード中
            if (isDownloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 10,
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _progress != null
                    ? '${((_progress!) * 100).toStringAsFixed(0)}% ダウンロード済み'
                    : 'ダウンロードを開始しています...',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
            ],

            // インストール準備完了
            if (isLaunching) ...[
              Text(
                'ダウンロードが完了しました。\nシステムのインストーラーが開きます。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
            ],

            // エラー
            if (isError) ...[
              Text(
                'ネットワーク接続を確認して、\nもう一度お試しください。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
      actions: [
        if (!isForce && (isIdle || isError))
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('後で'),
          ),
        if (isIdle)
          FilledButton.icon(
            onPressed: _startDownload,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('今すぐインストール'),
          ),
        if (isError)
          FilledButton(
            onPressed: _startDownload,
            child: const Text('再試行'),
          ),
        if (isLaunching) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
          if (_apkPath != null)
            FilledButton.icon(
              onPressed: _relaunchInstaller,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('インストーラーを再度開く'),
            ),
        ],
      ],
    );
  }
}

class _VersionCompareRow extends StatelessWidget {
  const _VersionCompareRow({
    required this.currentVersion,
    required this.latestVersion,
    required this.colorScheme,
    required this.textTheme,
  });

  final String currentVersion;
  final String latestVersion;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _VersionBlock(
            label: '現在',
            version: 'v$currentVersion',
            colorScheme: colorScheme,
            textTheme: textTheme,
            highlight: false,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Icon(Icons.arrow_forward_rounded,
                color: colorScheme.primary, size: 22),
          ),
          _VersionBlock(
            label: '最新',
            version: 'v$latestVersion',
            colorScheme: colorScheme,
            textTheme: textTheme,
            highlight: true,
          ),
        ],
      ),
    );
  }
}

class _VersionBlock extends StatelessWidget {
  const _VersionBlock({
    required this.label,
    required this.version,
    required this.colorScheme,
    required this.textTheme,
    required this.highlight,
  });

  final String label;
  final String version;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: textTheme.labelSmall
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          version,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: highlight ? colorScheme.primary : colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
