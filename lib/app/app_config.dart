class AppConfig {
  static const appVersion = '1.3.3';

  static const changelogUrl =
      'https://nzw.jp/static/changelog-langbridge.html';

  /// APK 配布ビルドでのみ true にする（例: `--dart-define=APK_BUILD=true`）。
  /// true の場合、起動時に changelog をポーリングして更新案内を出す。
  static const isApkBuild = bool.fromEnvironment(
    'APK_BUILD',
    defaultValue: false,
  );

  static const nzwJpAuthUrl = String.fromEnvironment(
    'NZWJP_AUTH_URL',
    defaultValue: 'https://nzw.jp',
  );
  static const nzwJpApiUrl = String.fromEnvironment(
    'NZWJP_API_URL',
    defaultValue: 'https://api.nzw.jp',
  );

  static const externalDictBaseUrl = String.fromEnvironment(
    'EXTERNAL_DICT_BASE_URL',
    defaultValue: '',
  );
  static const externalDictApiKey = String.fromEnvironment(
    'EXTERNAL_DICT_API_KEY',
    defaultValue: '',
  );

  /// 既定は **true**（`flutter run` だけで Google 同期を試せる）。
  /// CI やオフライン用にモックだけ使うときだけ `--dart-define=USE_REAL_SHEETS=false`。
  static const useRealSheets = bool.fromEnvironment(
    'USE_REAL_SHEETS',
    defaultValue: true,
  );
  static const googleSpreadsheetId = String.fromEnvironment(
    'GOOGLE_SPREADSHEET_ID',
    defaultValue: '',
  );
  static const googleSheetName = String.fromEnvironment(
    'GOOGLE_SHEET_NAME',
    defaultValue: 'Sheet1',
  );
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );

  /// Android（Credential Manager）で必須の **ウェブアプリケーション** OAuth クライアント ID。
  /// [android/app/src/main/res/values/sign_in_config.xml] の `default_web_client_id` と同じ値にすること。
  /// 別プロジェクトに差し替えるときは `--dart-define=GOOGLE_SERVER_CLIENT_ID=…` で上書き。
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '61266455889-vs4toq99nm03p72avc72dfu6dt1j19u2.apps.googleusercontent.com',
  );
}
