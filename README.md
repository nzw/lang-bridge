# LangBridge

2言語対応の語学学習 Flutter アプリ。スプレッドシートからの一括取込・フラッシュカード学習・AI 辞書アシストをひとつにまとめています。

対応プラットフォーム: **Android / iOS / Web**

---

## 主な機能

| 機能 | 説明 |
| ---- | ---- |
| **検索** | 前方一致・部分一致・曖昧検索。外部辞書 API（プラグイン可）があればその結果も表示。音声入力対応。 |
| **単語登録** | 母語・学習語・メモ・カテゴリを手動入力して即登録。 |
| **マイ単語一覧** | 登録済み単語の絞り込み検索。一致方式・対象フィールドをアコーディオンで設定。 |
| **単語詳細** | 編集・削除・お気に入り・習熟度表示・ソース URL リンク。 |
| **フラッシュカード学習** | 表面言語・メモ表示・シャッフル・お気に入りフィルタを設定可能。 |
| **Google Sheets 同期** | スプレッドシートからインポート（自動/一括/シートごと）・エクスポート（既存シート追加/新規作成）。 |
| **AI 辞書アシスト** | Google アカウントでサインイン後、検索語を AI API（Gemini）に送り解説をボトムシートで表示。履歴保存あり。 |
| **辞書リンク設定** | 外部辞書サイトへのリンク ON/OFF を個別に設定可能。 |
| **クラウド同期** | Firebase Firestore によるデバイス間リアルタイム同期。 |

---

## セットアップ

Firebase プロジェクトの作成から各プラットフォームのビルドまで、[SETUP.md](SETUP.md) を参照してください。

---

## アーキテクチャ

DDD（ドメイン駆動設計）と Clean Architecture を採用しています。詳細は [docs/architecture.md](docs/architecture.md) を参照してください。

```text
lib/
├── app/             # アプリ起動・テーマ・設定定数
├── di/              # 依存性注入（Riverpod Provider）
├── domain/          # エンティティ・リポジトリ抽象・ドメインサービス
├── application/     # ユースケース
├── infrastructure/  # 外部サービス・DB・API の実装
└── presentation/    # UI ウィジェット・ページ・StateNotifier
```

状態管理: **Riverpod 2.x** / クラウド: **Firebase Firestore** / HTTP: **Dio**

---

## ビルド

```bash
flutter pub get
flutter analyze
flutter test

# Android
flutter build apk --release

# iOS
flutter build ipa

# Web
flutter build web --release
```

---

## dart-define 一覧

| 定義 | 既定値 | 説明 |
| ---- | ------ | ---- |
| `USE_REAL_SHEETS` | `true` | `false` でオフラインモック動作 |
| `GOOGLE_IOS_CLIENT_ID` | （空） | iOS / macOS 用 OAuth クライアント ID |
| `GOOGLE_SERVER_CLIENT_ID` | （空） | Android 用ウェブ OAuth クライアント ID |
| `EXTERNAL_DICT_BASE_URL` | （空） | 外部辞書 API のベース URL。空の場合は API 呼び出しなし |
| `EXTERNAL_DICT_API_KEY` | （空） | 外部辞書 API の Bearer トークン（任意） |
| `NZWJP_AUTH_URL` | `https://nzw.jp` | AI 機能の認証エンドポイント |
| `NZWJP_API_URL` | `https://api.nzw.jp` | AI 機能の API エンドポイント |
| `APK_BUILD` | `false` | `true` で起動時に更新チェックを行う（APK 直配布ビルド用） |

---

## エントリのソース種別

| `EntrySourceType` | 説明 |
| ----------------- | ---- |
| `userSheet` | スプレッドシートから取込 |
| `manual` | 手動登録 |
| `external` | 外部辞書 API の検索結果（永続化なし） |

---

## コントリビューション

### 辞書 API 連携を一緒に開発しませんか

LangBridge では今後、さまざまな辞書 API との連携を進めていきたいと考えています。

- 「このAPIを繋げたい」「こんな辞書サービスに対応してほしい」というアイデアがあれば、ぜひ **Issue** を立ててください。
- 実装の PR も大歓迎です。小さな改善から始めていただいて構いません。

一緒に開発してくれる方をお待ちしています。

詳しくは [CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。

---

## ライセンス

MIT
