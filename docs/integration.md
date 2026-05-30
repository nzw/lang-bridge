# LangBridge 連携ガイド（Google ログイン・外部辞書 API）

このドキュメントでは、本アプリで使う **Google ログイン（Sheets 同期）** と **外部辞書 API（検索）** の設定方法をまとめます。

---

## Google ログイン（Sign in with Google）

### このアプリで使う Google まわりの役割と違い

| 名前 | 何をするか | このアプリでの用途 |
|------|------------|-------------------|
| **Google Sheets API** | スプレッドシートの行を読み書きする **Google の HTTP API** | インポート／エクスポートでシートを操作するときに利用。**Cloud で API を有効化**し、ユーザーに **OAuth で `spreadsheets` スコープ**を許可してもらう必要がある。 |
| **Firebase** | アプリ登録・`google-services.json`・Analytics など **モバイル向けの設定をまとめるサービス**（裏は同じ **Google Cloud プロジェクト**） | Android のパッケージ名・SHA-1 の登録先になりやすい。Authentication で **Google サインインを有効**にすると、`google-services.json` に **OAuth クライアント情報が追記**されることがある。**Firebase 自体がシートを読むわけではない。** |
| **OAuth 2.0 クライアント（種類別）** | Google が「どのアプリからログインしてよいか」を識別する ID | **Android 用**（パッケージ名 + SHA-1）、**iOS 用**（バンドル ID）、**ウェブアプリケーション用**（`serverClientId` / `default_web_client_id` に使う）が別クライアントとして必要になる。 |

**いま足りていなかった典型パターン（今回のエラー）**

- Android の `google_sign_in`（Credential Manager 経由）では **`serverClientId`（＝ウェブアプリケーション用クライアント ID）が必須**。
- `google-services.json` の **`oauth_client` が空 `[]`** のままだと、プラグインが **自動で `default_web_client_id` を埋められない** → `serverClientId must be provided on Android` になる。

**対処（どちらか一方でよい）**

1. **`android/app/src/main/res/values/sign_in_config.xml`** の `default_web_client_id` を、Cloud で作った **ウェブアプリケーション**のクライアント ID に差し替える（リポジトリにプレースホルダを置いてある）。  
2. または **`--dart-define=GOOGLE_SERVER_CLIENT_ID=...`** で同じウェブ用 ID を渡す。  
3. または Firebase で **SHA-1 登録 + Authentication の Google 有効化** 後に **`google-services.json` を再取得**し、`oauth_client` に **client_type: 3（Web）** が入るようにする。

**Android でログインしたあと Sheets を触るために追加で必要なこと**

- 同じ Cloud プロジェクトで **Google Sheets API を有効**にする。  
- **OAuth 同意画面**を完成させ、テスト中なら **テストユーザー**に自分の Google アカウントを入れる。  
- **デバッグ用 SHA-1** を Firebase または Cloud の **Android クライアント**に登録（未登録だと **ApiException: 10** になりやすい）。

### レギュレーション

ボタン見た目・文言・ロゴの扱いは [Sign in with Google のブランディングガイドライン](https://developers.google.com/identity/branding-guidelines)に従ってください。承認済み素材は [signin-assets.zip](https://developers.google.com/static/identity/images/signin-assets.zip) から入手できます。本リポジトリの `assets/branding/google_g_mark.svg` はその ZIP 内 `ios_light_sq_na.svg` の G マークに由来します（`assets/branding/SOURCE.txt` 参照）。

### クライアント ID について

- **iOS 用の OAuth クライアント ID**（例: `1234567890-xxx.apps.googleusercontent.com`）は **アプリに埋め込んでもよい公開情報**です（秘密鍵や client secret ではありません）。
- **Google Sheets API** を有効にし、OAuth 同意画面を構成したうえで、iOS / Android 用のクライアントを [Google Cloud Console](https://console.cloud.google.com/) または [Firebase Console](https://console.firebase.google.com/) から作成します。

### Flutter アプリ側の設定（dart-define）

`lib/app/app_config.dart` から読み取る主な定義は次のとおりです。

| 定義 | 説明 |
|------|------|
| `USE_REAL_SHEETS` | **省略時は `true`（既定）。** そのまま `flutter run` で Google Sheets／ログインを試せる。オフラインや CI でモックだけ使うときだけ `USE_REAL_SHEETS=false`。 |
| `GOOGLE_IOS_CLIENT_ID=...` | **iOS のみ** `GoogleSignIn.initialize(clientId: …)` に渡す OAuth クライアント ID |
| `GOOGLE_SERVER_CLIENT_ID=...` | **Android 任意** — `initialize(serverClientId: …)` に渡す **ウェブアプリケーション**用 OAuth クライアント ID。省略時はネイティブ側が `default_web_client_id`（`res/values/sign_in_config.xml` または `google-services.json` 由来）を読む。 |
| `GOOGLE_SPREADSHEET_ID=...` | **コード内の別経路**（`importRows` / `exportRows` ユースケースや `syncRepositoryProvider` の実リポジトリ切替）用。**手動同期画面の「インポート」では不要** — そこでは **スプレッドシートの URL を画面に貼り付け**ればよい。 |
| `GOOGLE_SHEET_NAME=Sheet1` | 上記のデフォルトシート名（任意） |

実行例:

```bash
flutter run \
  --dart-define=GOOGLE_IOS_CLIENT_ID=YOUR_IOS_CLIENT_ID.apps.googleusercontent.com
```

（`GOOGLE_SPREADSHEET_ID` は固定シート経路を使うときだけ。手動同期の URL 入力だけなら不要。）

`GoogleService-Info.plist` の `CLIENT_ID` をそのまま `GOOGLE_IOS_CLIENT_ID` に使えます。

### iOS（Info.plist）

`google_sign_in` / Google Sign-In SDK は **`GIDClientID`** を参照します。次のいずれかで設定してください。

1. **Xcode / Info.plist** に `GIDClientID` キーで iOS クライアント ID を記載する  
2. 上記のとおり **`GOOGLE_IOS_CLIENT_ID`** を dart-define で渡し、アプリ起動時に `GoogleSignIn.initialize(clientId: ...)` で初期化する（本プロジェクトはこの経路をサポート）

URL スキーム（`REVERSED_CLIENT_ID`）が必要な構成の場合は、[公式の Flutter 手順](https://pub.dev/packages/google_sign_in)に従って `Info.plist` と URL Types を追加してください。

### Android（この順でやると通りやすい）

`google_sign_in_android` の仕様では、**次のどちらか**が必要です。

- **A. Firebase 方式** — `google-services.json` を `android/app/` に置き、Gradle に Google Services プラグインを入れる。JSON 内に **ウェブ用** `oauth_client`（`client_type: 3`）が含まれると、Dart で `serverClientId` を省略できる場合があります。手順: [Firebase Android セットアップ](https://firebase.google.com/docs/android/setup)。
- **B. 本プロジェクトの dart-define 方式（Firebase なし）** — 次をすべて実施する。

#### 本リポジトリの Firebase（方式 A）について

- 設定ファイル: **`android/app/google-services.json`**（プロジェクトルートからの相対パス）。
- Gradle: `android/settings.gradle.kts` に `com.google.gms.google-services` **4.4.4**（`apply false`）、`android/app/build.gradle.kts` に同プラグインと **Firebase BoM 34.12.0**、`firebase-analytics` を追加済み（[公式 Android セットアップ](https://firebase.google.com/docs/android/setup)に準拠）。
- Android の **`applicationId` / `namespace`** は Firebase コンソールに登録した **パッケージ名と一致**させます。現在は **`jp.langbridge`**（`android/app/build.gradle.kts`）。
- ダウンロード直後の JSON で **`oauth_client` が空配列 `[]` のまま**のことがあります。その場合は Google サインイン用のクライアントがまだ JSON に含まれていません。次のいずれかで対応してください。
  1. [Firebase Console](https://console.firebase.google.com/) → **プロジェクトの設定** → 該当 Android アプリに **デバッグ用 SHA-1** を追加 → **Authentication** → **Sign-in method** で **Google** を有効化 → **`google-services.json` を再ダウンロード**して `android/app/` に上書きする。  
  2. または、方式 B と同様に **`GOOGLE_SERVER_CLIENT_ID`**（ウェブ用 OAuth クライアント ID）を dart-define で渡す。

#### 手順 B-1: Google Cloud で API を有効化

1. 同じプロジェクトで **Google Sheets API** を有効にする。  
2. **OAuth 同意画面**（テストユーザーなど）を埋める。

#### 手順 B-2: 「Android」用 OAuth クライアントを作成

1. [認証情報](https://console.cloud.google.com/apis/credentials) → **OAuth クライアント ID を作成**。  
2. アプリケーションの種類: **Android**。  
3. **パッケージ名** — このアプリの `applicationId` と **完全一致**（Firebase 利用時は **`jp.langbridge`**。`android/app/build.gradle.kts` の `defaultConfig` を確認）。  
4. **SHA-1** — ダミー不可。ターミナルでデバッグ用を取得:

   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```

   表示された **SHA1** をコンソールに貼り付ける。リリース用キーで配布する場合は、そのキーストアの SHA-1 も後から追加する。

#### 手順 B-3: 「ウェブアプリケーション」用 OAuth クライアントを作成

1. 再度 **OAuth クライアント ID を作成** → 種類: **ウェブアプリケーション**。  
2. 作成後に表示される **クライアント ID**（`…apps.googleusercontent.com`）をコピーする。  
3. **`client_secret` が書かれた JSON はアプリや Git に入れない**（サーバー専用）。アプリに必要なのは **クライアント ID 文字列だけ**。

> ダウンロードした `client_secret_….json` が **installed** 型で `client_secret` が無いものだけの場合、公式 README が求める **ウェブ** クライアント ID と一致するとは限りません。**ウェブアプリケーション**として別途作成するのが確実です。

#### 手順 B-4: アプリを起動する

`GOOGLE_SERVER_CLIENT_ID` に **手順 B-3 のウェブ用クライアント ID** を渡す（Android では `initialize` の `serverClientId` に使われます）。

```bash
flutter run -d android \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

（`oauth_client` が埋まった `google-services.json` を置けば `GOOGLE_SERVER_CLIENT_ID` は省略できる場合があります。）

参考: [google_sign_in_android の Integration](https://pub.dev/packages/google_sign_in_android#integration)。

#### Android で Google ログインが動かないとき（チェックリスト）

1. **意図的に `USE_REAL_SHEETS=false` にしていないか**  
   既定は **実 Sheets 連携オン**。モックだけにしたい開発者向けビルドだけ `false` にします。

2. **`google-services.json` の `oauth_client` が `[]` のまま**  
   今のリポジトリの JSON は多くの場合こうなっています。そのとき Android では **`GOOGLE_SERVER_CLIENT_ID`（ウェブ用 OAuth クライアント ID）** を dart-define で渡すか、Firebase で SHA-1 登録＋Google ログイン有効化後に JSON を再ダウンロードして `oauth_client` を埋める必要があります。

3. **デバッグ用 SHA-1 を Firebase に登録**  
   [プロジェクトの設定] → あなたの Android アプリ → **SHA 証明書フィンガープリント** に、`keytool` で取った **SHA-1** を追加。未登録だと **ApiException: 10**（DEVELOPER_ERROR）になりがちです。

4. **エミュレータは Google Play 入りイメージ推奨**  
   「Google APIs」または **Play Store 付き** AVD を使うと、Google ログインまわりが安定しやすいです。

5. **OAuth 同意画面とテストユーザー**  
   アプリが「テスト中」のとき、ログインする Google アカウントを **テストユーザー**に追加しておく。

### スコープ

同期では Spreadsheets の読み書きのため、`https://www.googleapis.com/auth/spreadsheets` を要求します（`sync_page.dart` の `authenticate` 参照）。

---

## 外部辞書 API（検索）

### 役割

検索画面などで、設定された HTTP エンドポイントにクエリを送り、単語エントリの候補を取得します。実装: `lib/infrastructure/external/hokujiro/hokujiro_api_client.dart`（プラグイン可能な設計で、今後さまざまな辞書 API に対応予定）。

### dart-define

| 定義 | 説明 |
|------|------|
| `EXTERNAL_DICT_BASE_URL` | GET リクエストのベース URL（例: `https://api.example.com/search`）。**空のときは API を呼ばず**、ローカル向けのフォールバック候補のみ返します。 |
| `EXTERNAL_DICT_API_KEY` | 任意。空でなければ `Authorization: Bearer <キー>` ヘッダーを付与します。 |

実行例:

```bash
flutter run \
  --dart-define=EXTERNAL_DICT_BASE_URL=https://your-api.example.com/v1/lookup \
  --dart-define=EXTERNAL_DICT_API_KEY=your_secret_token
```

**注意:** `EXTERNAL_DICT_API_KEY` は秘密情報です。リポジトリにコミットせず、CI やローカル実行時の環境変数・dart-define で渡してください。

### HTTP 仕様（アプリが期待する形）

- **メソッド:** `GET`
- **クエリ:** `q` — 検索文字列（ユーザー入力）
- **ヘッダー（任意）:** `Authorization: Bearer ${EXTERNAL_DICT_API_KEY}`（キーが設定されている場合のみ）
- **タイムアウト:** 送信 4 秒 / 受信 6 秒程度（実装参照）

### レスポンス JSON（パース）

次のいずれかの形を解釈します。

1. **オブジェクト**で、`results` が配列の場合: `{ "results": [ ... ] }`
2. **トップレベルが配列**の場合: `[ ... ]`

各要素は **オブジェクト**で、次のキーからソース言語・ターゲット言語を読み取ります（フォールバックキー付き）。

| フィールド | 読み取るキー（優先順） |
| ---------- | ---------------------- |
| ソース言語（lang1） | `japanese` → `ja` |
| ターゲット言語（lang2） | `chinese` → `zh` |
| メモ（任意） | `memo` → `description` |
| ID（任意） | `id`（なければ自動生成） |

**ソース言語・ターゲット言語の両方が空でない要素だけ**が採用されます。1 件も解釈できない場合は、フォールバックのダミー候補が返ります。

### バックエンド実装のヒント

自前 API を差し込む場合は、上記の JSON 形に合わせるのが最も手早いです。CORS はモバイルのネイティブ HTTP では通常不要ですが、Web ビルドで同じクライアントを使う場合は考慮してください。

---

## 参考リンク

- [Sign in with Google — Branding](https://developers.google.com/identity/branding-guidelines)
- [Google Sheets API](https://developers.google.com/sheets/api)
- [package:google_sign_in](https://pub.dev/packages/google_sign_in)
- [package:url_launcher](https://pub.dev/packages/url_launcher)
