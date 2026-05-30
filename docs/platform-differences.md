# プラットフォーム別実装差異

iOS・APK（Android）・Web の3プラットフォームにおける主な実装差異をまとめます。

---

## 認証

### Google サインイン方式

| プラットフォーム | メソッド | 備考 |
|---|---|---|
| Web | `FirebaseAuth.signInWithPopup(provider)` | ブラウザポップアップ |
| iOS | `FirebaseAuth.signInWithProvider(provider)` | Safari ASWebAuthSession |
| Android | `FirebaseAuth.signInWithProvider(provider)` | Credential Manager 経由 |

`sync_page.dart`・`settings_page.dart`・`account_menu_button.dart` の各サインイン箇所で `kIsWeb` で分岐。

### Web 専用：nzw.jp JWT Cookie からの自動復元

`app.dart` の `_tryInitFromCookie()` が Web のみ（`kIsWeb`）で実行される。  
nzw.jp ログインページがセットした `token` Cookie を解析し、`webCookieUserProvider` へキャッシュ。  
Firebase Auth 未サインインでも AI 機能が使えるのはこの Cookie 認証のため。

実装：`lib/presentation/widgets/web_cookie_auth.dart`（条件付きエクスポート）

```
web_cookie_auth.dart
  └─ if (dart.library.js_interop)
       ├─ web_cookie_auth_impl.dart  ← Web: document.cookie / localStorage にアクセス
       └─ web_cookie_auth_stub.dart  ← iOS/Android: 常に null
```

### Android 専用：OAuth クライアント ID

Credential Manager は **Web アプリケーション** の OAuth クライアント ID が必須。  
`android/app/src/main/res/values/sign_in_config.xml` と以下の dart-define を一致させること。

```
GOOGLE_SERVER_CLIENT_ID=808345279721-sm4nbjunh13n9qbmqcho860qmkvaq1e5.apps.googleusercontent.com
```

---

## データストレージ

### ユーザー辞書データ

`userRepositoryProvider`（`providers.dart`）がサインイン状態で自動切り替え。

| 状態 | 保存先 | 実装クラス |
|---|---|---|
| Firebase サインイン済み | Cloud Firestore | `FirestoreUserDictionaryRepository` |
| 未サインイン | SharedPreferences | `SharedPrefsUserDictionaryRepository` |

初回サインイン時に SharedPreferences → Firestore へ自動移行（`LocalDataMigrator`）。

### その他のローカルデータ

以下はすべてのプラットフォームで SharedPreferences に保存（Firestore と無関係）。

- AI 利用履歴 / 検索履歴 / 保存済み Sheets URL
- AI モード設定 / フィルタカテゴリ / nzw.jp JWT

---

## Google Sheets 同期

認証方式はプラットフォームで異なるが、同期リポジトリ自体（`GoogleSheetsSyncRepository`）は共通。  
OAuth access token を `sheetsAccessTokenProvider`（StateProvider）経由で渡す。

```dart
// サインイン成功後に accessToken を保存
final token = (cred.credential as OAuthCredential).accessToken;
ref.read(sheetsAccessTokenProvider.notifier).state = token;
```

---

## APK 専用機能

### バージョン更新チェック

`search_page.dart` で以下の条件をすべて満たす場合のみ起動時にポーリング実行。

```dart
!kIsWeb && defaultTargetPlatform == TargetPlatform.android && AppConfig.isApkBuild
```

配布用 APK ビルド時は `--dart-define=APK_BUILD=true` を付与すること。

---

## dart-define フラグ一覧

| フラグ | 既定値 | 用途 |
|---|---|---|
| `APK_BUILD` | `false` | APK配布ビルド判定（更新チェック有効化） |
| `USE_REAL_SHEETS` | `true` | `false` にするとモック実装を使用（オフライン開発用） |
| `NZWJP_AUTH_URL` | `https://nzw.jp` | nzw.jp 認証エンドポイント |
| `NZWJP_API_URL` | `https://api.nzw.jp` | nzw.jp API エンドポイント |
| `GOOGLE_SERVER_CLIENT_ID` | （既定値あり） | Android Credential Manager 用 Web OAuth クライアント ID |
| `GOOGLE_IOS_CLIENT_ID` | （空） | iOS 向け Google Sign-In クライアント ID |
| `GOOGLE_SPREADSHEET_ID` | （空） | 固定先スプレッドシート ID（手動同期は URL 入力で上書き可） |
| `GOOGLE_SHEET_NAME` | `Sheet1` | 対象シート名 |

### 代表的なビルドコマンド

```bash
# Web（通常）
flutter build web

# APK 配布版
flutter build apk --dart-define=APK_BUILD=true

# オフライン開発（Sheets モック）
flutter run --dart-define=USE_REAL_SHEETS=false
```

---

## 差異サマリ

| 機能 | Web | iOS | Android (APK) |
|---|---|---|---|
| Google サインイン | `signInWithPopup` | `signInWithProvider` | `signInWithProvider` |
| nzw.jp Cookie 認証 | あり | なし | なし |
| APK 更新チェック | なし | なし | APK_BUILD=true 時のみ |
| OAuth クライアント ID | Web 用 ID | iOS 用 ID | Web 用 ID（Credential Manager 必須） |
| ユーザー辞書 | Firestore / SharedPrefs | 同左 | 同左 |
| Sheets 同期 | 共通実装 | 同左 | 同左 |
