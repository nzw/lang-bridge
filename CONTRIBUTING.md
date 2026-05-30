# Contributing to LangBridge

まず LangBridge への貢献に興味を持っていただきありがとうございます。

## 開発環境のセットアップ

[SETUP.md](SETUP.md) を参照してください。

## アーキテクチャ

LangBridge はドメイン駆動設計（DDD）と Clean Architecture に基づいています。

```text
lib/
├── app/             # アプリ起動・テーマ・設定定数
├── di/              # 依存性注入（Riverpod プロバイダ）
├── domain/          # ドメイン層：エンティティ・値オブジェクト・リポジトリインターフェース
│   └── services/    # ドメインサービス
├── application/     # アプリケーション層：ユースケース
├── infrastructure/  # インフラ層：外部サービス・DB・API の実装
│   ├── local/       # SharedPreferences / メモリ
│   ├── firestore/   # Firebase Firestore
│   ├── sync/        # Google Sheets 同期
│   └── external/    # 外部 API (辞書 API, nzw.jp)
└── presentation/    # プレゼンテーション層：UI ウィジェット・ページ
    └── state/       # StateNotifier（UI 状態管理）
```

### 依存の方向

```text
presentation → di → application → domain ← infrastructure
```

- domain は他の層に依存しない
- infrastructure は domain のインターフェースを実装する
- application は domain のみに依存する
- presentation は di 経由でユースケースを利用する

## コントリビューションの流れ

1. Issue を作成して変更内容を議論する
2. `main` からブランチを切る (`feature/xxx`, `fix/xxx`)
3. 変更を実装する
4. Pull Request を作成する

## コーディング規約

- Dart の公式スタイルガイドに従う (`dart format` を実行)
- 静的解析を通す (`dart analyze`)
- 新機能にはテストを追加する（`test/` ディレクトリ）
- コメントは必要最小限に（WHY が自明でない場合のみ）

## Pull Request のガイドライン

- 変更の目的を PR 説明に記載する
- スクリーンショットや動画があると助かります（UI 変更の場合）
- 1つの PR は1つの目的に絞る

## ライセンス

このプロジェクトへの貢献は MIT ライセンスのもとで行われます。
