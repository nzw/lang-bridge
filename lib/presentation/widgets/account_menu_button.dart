import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../app/app_config.dart';
import '../../di/providers.dart';
import '../settings_page.dart';

/// 全画面の AppBar 右端で使うアカウントメニューボタン。
///
/// - ログイン中  → アバター（写真 or イニシャル）
/// - 未ログイン  → account_circle_outlined アイコン
class AccountMenuButton extends ConsumerStatefulWidget {
  const AccountMenuButton({super.key, this.showGoHome = false});

  /// true にするとメニューに「ホーム」項目を表示し、タップでルートまで戻る。
  final bool showGoHome;

  @override
  ConsumerState<AccountMenuButton> createState() => _AccountMenuButtonState();
}

class _AccountMenuButtonState extends ConsumerState<AccountMenuButton> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..addScope('https://www.googleapis.com/auth/spreadsheets');
        final cred = await FirebaseAuth.instance.signInWithPopup(provider);
        final oAuth = cred.credential as OAuthCredential?;
        if (oAuth?.accessToken != null) {
          ref.read(sheetsAccessTokenProvider.notifier).state = oAuth!.accessToken;
        }
      } else {
        const sheetsScope = 'https://www.googleapis.com/auth/spreadsheets';
        final account = await GoogleSignIn.instance.authenticate(
          scopeHint: [sheetsScope],
        );
        final authz = await account.authorizationClient.authorizeScopes([sheetsScope]);
        final credential = GoogleAuthProvider.credential(
          idToken: account.authentication.idToken,
          accessToken: authz.accessToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
        ref.read(sheetsAccessTokenProvider.notifier).state = authz.accessToken;
      }
    } on GoogleSignInException catch (e) {
      if (mounted) {
        _showError('ログインに失敗しました\nGoogle Sign-In エラー: ${e.code.name}');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showError('ログインに失敗しました\n${e.code}: ${e.message ?? ""}');
      }
    } catch (e) {
      if (mounted) {
        _showError('ログインに失敗しました\n$e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await Future.wait([
        FirebaseAuth.instance.signOut(),
        if (!kIsWeb) GoogleSignIn.instance.signOut(),
      ]);
      ref.read(sheetsAccessTokenProvider.notifier).state = null;
      ref.read(webCookieUserProvider.notifier).state = null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final userInfo = ref.watch(currentUserInfoProvider);
    final cookieUser = ref.watch(webCookieUserProvider);
    final theme = Theme.of(context);

    final String? displayEmail = userInfo?.email ?? cookieUser?.email;
    final String? displayPhoto = userInfo?.photoUrl ?? cookieUser?.photoUrl;
    final bool isSignedIn = userInfo != null || cookieUser != null;

    final Widget avatar;
    if (_busy) {
      avatar = SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: theme.colorScheme.primary,
        ),
      );
    } else if (!isSignedIn) {
      avatar = Icon(
        Icons.account_circle_outlined,
        color: theme.colorScheme.onSurfaceVariant,
        size: 26,
      );
    } else {
      avatar = CircleAvatar(
        radius: 14,
        backgroundColor: theme.colorScheme.primaryContainer,
        backgroundImage:
            displayPhoto != null ? NetworkImage(displayPhoto) : null,
        child: displayPhoto == null
            ? Text(
                (displayEmail ?? '?').substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              )
            : null,
      );
    }

    return PopupMenuButton<_AccountMenuAction>(
      tooltip: displayEmail ?? 'アカウント',
      offset: const Offset(0, 48),
      onSelected: (action) {
        switch (action) {
          case _AccountMenuAction.goHome:
            Navigator.of(context).popUntil((route) => route.isFirst);
          case _AccountMenuAction.settings:
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            );
          case _AccountMenuAction.signIn:
            _signIn();
          case _AccountMenuAction.signOut:
            _signOut();
        }
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<_AccountMenuAction>>[];
        if (widget.showGoHome) {
          items.addAll([
            const PopupMenuItem<_AccountMenuAction>(
              value: _AccountMenuAction.goHome,
              child: _MenuItem(icon: Icons.home_outlined, label: 'ホーム'),
            ),
            const PopupMenuDivider(),
          ]);
        }
        items.addAll([
          const PopupMenuItem<_AccountMenuAction>(
            value: _AccountMenuAction.settings,
            child: _MenuItem(icon: Icons.settings_outlined, label: '設定'),
          ),
          const PopupMenuDivider(),
        ]);
        if (!isSignedIn) {
          if (AppConfig.useRealSheets) {
            items.add(const PopupMenuItem<_AccountMenuAction>(
              value: _AccountMenuAction.signIn,
              child: _MenuItem(icon: Icons.login, label: 'Googleでログイン'),
            ));
          }
        } else {
          items.add(const PopupMenuItem<_AccountMenuAction>(
            value: _AccountMenuAction.signOut,
            child: _MenuItem(
              icon: Icons.logout,
              label: 'ログアウト',
              isDestructive: true,
            ),
          ));
        }
        return items;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: avatar,
      ),
    );
  }
}

enum _AccountMenuAction { goHome, settings, signIn, signOut }

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color =
        isDestructive ? Theme.of(context).colorScheme.error : null;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: color != null ? TextStyle(color: color) : null),
      ],
    );
  }
}
