import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/app_config.dart';
import 'nzwjp_exceptions.dart';

class NzwJpAuthRepository {
  NzwJpAuthRepository(this._dio);

  final Dio _dio;

  static const _jwtKey = 'nzwjp_jwt_v1';

  Future<String> authenticate(String idToken) async {
    try {
      final response = await _dio.post<dynamic>(
        '${AppConfig.nzwJpAuthUrl}/auth/google',
        data: {'id_token': idToken},
        options: Options(
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final data = response.data;
      String? jwt;
      if (data is Map && data['token'] is String) {
        jwt = data['token'] as String;
      }
      // JWTがbodyに含まれない場合はSet-Cookieヘッダーから取得を試みる
      jwt ??= _extractJwtFromCookie(response.headers);
      if (jwt == null) {
        throw const NzwJpApiException('JWT取得に失敗しました');
      }
      await _saveJwt(jwt);
      return jwt;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) throw const NzwJpUnauthorizedException();
      if (status == 403) throw const NzwJpForbiddenException();
      throw NzwJpApiException(e.message ?? e.toString());
    }
  }

  // JWTのexpクレームをデコードして有効期限内かどうかを確認する。
  // 署名検証は行わない（サーバー側でGeminiリクエスト時に検証される）。
  Future<String?> getValidJwt() async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString(_jwtKey);
    if (jwt == null) return null;
    if (_isJwtExpiredOrNearExpiry(jwt)) {
      await clearJwt();
      return null;
    }
    return jwt;
  }

  Future<void> clearJwt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_jwtKey);
  }

  Future<void> saveJwt(String jwt) => _saveJwt(jwt);

  Future<void> _saveJwt(String jwt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_jwtKey, jwt);
  }

  // JWTのexpクレームをローカルデコードして、有効期限5分以内ならtrueを返す。
  bool _isJwtExpiredOrNearExpiry(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return true;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final exp = map['exp'];
      if (exp is! int) return true;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiry.subtract(const Duration(minutes: 5)));
    } catch (_) {
      return true;
    }
  }

  String? _extractJwtFromCookie(Headers headers) {
    final setCookies = headers.map['set-cookie'];
    if (setCookies == null) return null;
    for (final cookie in setCookies) {
      final parts = cookie.split(';');
      for (final part in parts) {
        final kv = part.trim().split('=');
        if (kv.length >= 2 && kv[0].trim() == 'token') {
          return kv.sublist(1).join('=');
        }
      }
    }
    return null;
  }
}
