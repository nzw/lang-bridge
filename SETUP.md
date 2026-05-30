# LangBridge セットアップガイド

このガイドでは、LangBridge を開発環境でビルドするための手順を説明します。

## 前提条件

- Flutter SDK (3.x 以上)
- Firebase CLI (`npm install -g firebase-tools`)
- FlutterFire CLI (`dart pub global activate flutterfire_cli`)

## 1. リポジトリのクローン

```bash
git clone https://github.com/nzw/lang-bridge.git
cd lang-bridge
flutter pub get
```

## 2. Firebase プロジェクトの作成

### 2-1. Firebase コンソールでプロジェクトを作成

[Firebase コンソール](https://console.firebase.google.com/) にアクセスし、新しいプロジェクトを作成します。

### 2-2. 必要なサービスを有効化

Firebase コンソールで以下を有効にします：

- **Authentication** → Google サインインを有効化
- **Firestore Database** → データベースを作成

### 2-3. FlutterFire で設定ファイルを生成

```bash
firebase login
flutterfire configure --project=<your-firebase-project-id> --platforms=android,ios,web
```

これにより、以下のファイルが自動生成されます：

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

### 2-4. Android デバッグキーストアの生成

```bash
keytool -genkey -v \
  -keystore android/app/debug.keystore \
  -storepass android \
  -alias androiddebugkey \
  -keypass android \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

## 3. アプリのビルド

```bash
# 開発ビルド
flutter run

# リリース APK（Android）
flutter build apk --release --dart-define=APK_BUILD=true

# Web
flutter build web
```

## 4. Firestore セキュリティルール

`firestore.rules` をそのまま使用するか、Firebase コンソールからデプロイします：

```bash
firebase deploy --only firestore:rules
```

## トラブルシューティング

**Q: `firebase_options.dart` が見つからないエラーが出る**

A: 手順 2-3 の FlutterFire 設定を実行してください。

**Q: Google サインインが失敗する**

A: Firebase コンソールの Authentication → Sign-in method → Google でサポートメールを設定してください。
   また、`android/app/google-services.json` に OAuth クライアント ID が正しく含まれているか確認してください。
