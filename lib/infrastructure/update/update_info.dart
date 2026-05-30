import '../../app/app_config.dart';

class UpdateInfo {
  const UpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    this.minRequiredVersion,
    this.releaseNotes,
  });

  final String latestVersion;
  final String downloadUrl;
  final String? minRequiredVersion;
  // セミコロン区切りのリリースノート項目
  final List<String>? releaseNotes;

  /// changelog HTML から <meta name="langbridge:*"> を読み取って生成する。
  ///
  /// 必須タグ:
  ///   <meta name="langbridge:version" content="1.2.3">
  ///   <meta name="langbridge:download-url" content="https://...">
  /// 任意タグ:
  ///   <meta name="langbridge:min-version" content="1.1.0">
  ///   <meta name="langbridge:release-notes" content="変更1;変更2;変更3">
  static UpdateInfo? fromHtml(String html) {
    String? meta(String name) {
      final m = RegExp(
        '<meta\\s+name="$name"\\s+content="([^"]+)"',
        caseSensitive: false,
      ).firstMatch(html);
      return m?.group(1);
    }

    final version = meta('langbridge:version');
    final downloadUrl = meta('langbridge:download-url');
    if (version == null || downloadUrl == null) return null;

    final notesRaw = meta('langbridge:release-notes');
    final notes = notesRaw
        ?.split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return UpdateInfo(
      latestVersion: version,
      downloadUrl: downloadUrl,
      minRequiredVersion: meta('langbridge:min-version'),
      releaseNotes: notes,
    );
  }

  bool get isUpdateAvailable =>
      _compare(latestVersion, AppConfig.appVersion) > 0;

  bool get isForceUpdate =>
      minRequiredVersion != null &&
      _compare(minRequiredVersion!, AppConfig.appVersion) > 0;

  static int _compare(String a, String b) {
    final ap = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final bp = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final av = i < ap.length ? ap[i] : 0;
      final bv = i < bp.length ? bp[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }
}
