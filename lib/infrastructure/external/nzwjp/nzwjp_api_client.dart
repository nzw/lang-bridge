import 'package:dio/dio.dart';

import '../../../app/app_config.dart';
import '../../../domain/gemini_result.dart';
import 'nzwjp_exceptions.dart';

class NzwJpApiClient {
  NzwJpApiClient(this._dio);

  final Dio _dio;

  Future<({int used, int remaining, int limit, String? resetDate})> getGeminiUsage(String jwt) async {
    try {
      final response = await _dio.get<dynamic>(
        '${AppConfig.nzwJpApiUrl}/v1/gemini/usage',
        options: Options(
          headers: {'Authorization': 'Bearer $jwt'},
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final data = response.data;
      if (data is Map) {
        return (
          used: (data['used'] as num?)?.toInt() ?? 0,
          remaining: (data['remaining'] as num?)?.toInt() ?? -1,
          limit: (data['limit'] as num?)?.toInt() ?? -1,
          resetDate: data['reset_date'] as String?,
        );
      }
      throw const NzwJpApiException('予期しないレスポンス形式です');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) throw const NzwJpUnauthorizedException();
      if (status == 403) throw const NzwJpForbiddenException();
      throw NzwJpApiException(e.message ?? e.toString());
    }
  }

  Future<GeminiResult> getGeminiResponse(String prompt, String jwt) async {
    try {
      final response = await _dio.get<dynamic>(
        '${AppConfig.nzwJpApiUrl}/v1/gemini',
        queryParameters: {'q': prompt},
        options: Options(
          headers: {'Authorization': 'Bearer $jwt'},
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final data = response.data;
      if (data is Map && data['message'] is String) {
        return GeminiResult(
          text: data['message'] as String,
          remaining: (data['remaining'] as num?)?.toInt() ?? -1,
          limit: (data['limit'] as num?)?.toInt() ?? -1,
          resetDate: data['reset_date'] as String?,
        );
      }
      throw const NzwJpApiException('予期しないレスポンス形式です');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) throw const NzwJpUnauthorizedException();
      if (status == 403) throw const NzwJpForbiddenException();
      if (status == 429) throw const NzwJpRateLimitException();
      throw NzwJpApiException(e.message ?? e.toString());
    }
  }
}
