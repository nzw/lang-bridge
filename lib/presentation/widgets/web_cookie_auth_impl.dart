import 'dart:convert';

import 'package:web/web.dart' as web;

({String email, String? name, String? photoUrl})? readNzwJpAuthFromBrowser() {
  final token = _parseCookie(web.document.cookie, 'token');
  if (token == null) return null;

  final parts = token.split('.');
  if (parts.length != 3) return null;

  try {
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final map = jsonDecode(payload) as Map<String, dynamic>;

    final exp = map['exp'];
    if (exp is! int) return null;
    if (DateTime.now().isAfter(
      DateTime.fromMillisecondsSinceEpoch(exp * 1000),
    )) {
      return null;
    }

    final email = map['sub'] as String?;
    if (email == null || email.isEmpty) return null;

    final name = map['name'] as String?;
    final photoUrl = web.window.localStorage.getItem('picture');

    return (
      email: email,
      name: name,
      photoUrl: (photoUrl != null && photoUrl.isNotEmpty) ? photoUrl : null,
    );
  } catch (_) {
    return null;
  }
}

String? readNzwJpToken() => _parseCookie(web.document.cookie, 'token');

String? _parseCookie(String cookies, String name) {
  for (final part in cookies.split(';')) {
    final idx = part.indexOf('=');
    if (idx < 0) continue;
    final key = part.substring(0, idx).trim();
    if (key != name) continue;
    return part.substring(idx + 1).trim();
  }
  return null;
}
