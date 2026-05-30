import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase Auth の認証状態ストリーム。null = 未サインイン。
final firebaseUserProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Sheets API 用 Google OAuth access token。
final sheetsAccessTokenProvider = StateProvider<String?>((ref) => null);

/// UI 用アカウント情報（email/photo）。
final currentUserInfoProvider =
    Provider<({String email, String? photoUrl, String? displayName})?>(
  (ref) {
    final user = ref.watch(firebaseUserProvider).valueOrNull;
    if (user == null) return null;
    return (
      email: user.email ?? '',
      photoUrl: user.photoURL,
      displayName: user.displayName,
    );
  },
);

/// nzw.jp バックエンドの JWT クッキーから復元したユーザー情報（Web のみ）。
final webCookieUserProvider =
    StateProvider<({String email, String? name, String? photoUrl})?>(
  (ref) => null,
);

final nzwJpAiEnabledProvider = StateProvider<bool?>((ref) => null);

final nzwJpAiUsageProvider =
    StateProvider<({int remaining, int limit, String? resetDate})?>(
  (ref) => null,
);
