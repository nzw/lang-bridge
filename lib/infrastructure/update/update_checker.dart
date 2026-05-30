import 'package:dio/dio.dart';

import '../../app/app_config.dart';
import 'update_info.dart';

class UpdateChecker {
  const UpdateChecker(this._dio);

  final Dio _dio;

  Future<UpdateInfo?> check() async {
    try {
      final res = await _dio.get<String>(
        AppConfig.changelogUrl,
        options: Options(
          responseType: ResponseType.plain,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final html = res.data;
      if (html == null) return null;
      return UpdateInfo.fromHtml(html);
    } catch (_) {
      return null;
    }
  }
}
