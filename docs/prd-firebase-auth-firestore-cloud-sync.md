# PRD: Firebase Auth + Firestore クラウド同期 (v1.4.0)

## 概要

LangBridge のユーザー辞書データをデバイスローカル（SharedPreferences）からクラウド（Firestore）へ移行し、複数端末・プラットフォーム間でのシームレスなデータ同期を実現する。認証基盤も `google_sign_in` パッケージから `firebase_auth` へ刷新し、コードベースを大幅に簡素化する。

---

## 背景と動機

### 現状の課題

| 課題 | 詳細 |
|------|------|
| **データの端末閉じ込め** | 登録単語は SharedPreferences に保存されるため、機種変更やアプリ再インストール時にデータが消失する |
| **マルチデバイス非対応** | Android・iOS・Web・Mac で同じ単語リストを使えない |
| **認証コードの複雑性** | `google_sign_in` の platform-specific な初期化（iOS clientId, Web GIS, serverClientId）が各ページに散在し、バグの温床になっていた |
| **Sheets 依存の同期** | 現在のクラウド同期は Google Sheets 経由のみで、操作が重くオフライン非対応 |

### なぜ今か

- v1.3.x でカテゴリ・フラッシュカード機能が安定し、ユーザーが本格的に単語を蓄積し始めるフェーズに入った
- Firebase プロジェクト（silver-adapter-493009-s8）は既にセットアップ済み
- Firebase Auth + Firestore を同時に導入することで認証とストレージを一元化でき、将来の機能追加（通知、共有辞書など）の土台になる

---

## ゴール

1. Googleアカウントでサインインすると、登録単語が Firestore にリアルタイム保存・同期される
2. 既存のローカルデータは初回サインイン時に自動でクラウドへ移行され、データ損失ゼロ
3. 未サインイン時は従来通りローカル保存で動作し、ダウングレードなし
4. 認証フローが全プラットフォームで統一される（Web/Android/iOS でコード共通化）
5. 複数端末で同一アカウントを使うと単語リストがリアルタイムに反映される

## 非ゴール

- **オフラインキャッシュの実装**（Firestore の組み込みキャッシュに依存する。明示的な offline-first 実装はスコープ外）
- **共有辞書・公開単語帳**（個人の単語データのみ対象）
- **Firestore セキュリティルールの完全な多ユーザー対応**（単一ユーザー `users/{uid}/entries` パスのみ）
- **データエクスポート / バックアップ UI**（Sheets 連携は継続して提供）

---

## ユーザーストーリー

### 主要シナリオ

**U-01 初回サインイン（ローカルデータあり）**  
> 既存ユーザーが「Googleでログイン」を押すと、今まで登録した単語がそのままクラウドに移行され、何も失われない

**U-02 新規サインイン（ローカルデータなし）**  
> 新規ユーザーがサインインすると、Firestore に空のコレクションが作られ、以降の登録はすべてクラウドに保存される

**U-03 マルチデバイス同期**  
> スマホで登録した単語が Web 版で即座に（ページリロード不要で）反映される

**U-04 未サインインで使う**  
> サインインしなくても、従来通りローカルに単語を登録・管理できる。機能制限なし

**U-05 サインアウト**  
> サインアウトするとクラウドへの書き込みが止まり、ローカル保存モードに切り替わる。クラウドデータは削除されない

**U-06 再サインイン**  
> 別デバイスや再インストール後にサインインすると、クラウドのデータが自動で読み込まれる

---

## 技術要件

### アーキテクチャ変更

```
Before:
  UserDictionaryRepository
    └── SharedPrefsUserDictionaryRepository (常時)

After:
  UserDictionaryRepository (interface)
    ├── FirestoreUserDictionaryRepository  ← サインイン中
    └── SharedPrefsUserDictionaryRepository ← 未サインイン
```

### データモデル（Firestore）

```
Firestore
└── users/
    └── {uid}/
        └── entries/          ← CollectionReference
            └── {entry.id}/   ← DictionaryEntry.toJson()
```

- ドキュメント ID は既存の `DictionaryEntry.id`（UUID）をそのまま使用
- `DictionaryEntry.toJson()` / `fromJson()` は既存実装を流用
- Write batch は 490 操作単位で分割（Firestore の 500 ops 上限に対応）

### 認証フロー

```
Before:
  GoogleSignIn.initialize() → authenticate() → GoogleSignInAccount
    ├── Web: GIS renderButton / FedCM
    ├── iOS: IosClientId 指定
    └── Android: serverClientId のみ

After:
  GoogleAuthProvider() + scope追加
    ├── Web: FirebaseAuth.signInWithPopup()
    └── native: FirebaseAuth.signInWithProvider()
  → UserCredential → OAuthCredential.accessToken（Sheets API 用）
  → FirebaseAuth.authStateChanges() ストリームで状態管理
```

### Riverpod プロバイダ構成

| プロバイダ | 型 | 役割 |
|-----------|-----|------|
| `firebaseUserProvider` | `StreamProvider<User?>` | Firebase Auth 状態。null = 未サインイン |
| `sheetsAccessTokenProvider` | `StateProvider<String?>` | OAuthCredential から取得した Sheets 用 access token |
| `currentUserInfoProvider` | `Provider<...?>` | UI 表示用（email, photoUrl, displayName） |
| `userRepositoryProvider` | `Provider<UserDictionaryRepository>` | サインイン状態に応じて Firestore/SharedPrefs を切り替え |
| `userEntriesStreamProvider` | `StreamProvider<List<DictionaryEntry>>` | Firestore リアルタイム snapshot（未サインイン時は空ストリーム） |

### データ移行（LocalDataMigrator）

- `SharedPreferences` の `firestore_migrated_v1` フラグを確認
- 未移行かつローカルデータが存在する場合のみ `upsertMany()` を実行
- 移行完了後フラグをセット（2回目以降はスキップ）
- サインイン検知は `firebaseUserProvider` の `prev == null && next != null` で判定

### 削除されるコード

- `google_sign_in` パッケージ依存（pubspec.yaml から除去）
- `GoogleSignInBrandButton` ウィジェット
- `GoogleWebSignIn` / `GoogleWebSignInImpl` / `GoogleWebSignInStub`
- `googleSignInProvider` / `googleSignInInitializedProvider` / `googleAccountProvider`
- 各ページの `_iosClientIdOrNull()` / `_initGoogleSignIn()` メソッド群

---

## 実装スコープ（ファイル別）

| ファイル | 変更種別 | 主な変更内容 |
|---------|---------|-------------|
| `pubspec.yaml` | 更新 | `firebase_auth`, `cloud_firestore` 追加。`google_sign_in` 削除 |
| `lib/firebase_options.dart` | 新規 | `flutterfire configure` 生成ファイル（要手動実行） |
| `lib/infrastructure/firestore/firestore_user_dictionary_repository.dart` | 新規 | Firestore CRUD + batch 処理 |
| `lib/infrastructure/firestore/local_data_migrator.dart` | 新規 | SharedPrefs → Firestore 一回限り移行 |
| `lib/app/providers.dart` | 更新 | Firebase Auth プロバイダ群追加、`userRepositoryProvider` 切り替えロジック |
| `lib/app/app.dart` | 更新 | `_initGoogleSignIn()` 削除、`_listenForMigration()` に置き換え |
| `lib/presentation/widgets/account_menu_button.dart` | 更新 | `FirebaseAuth.signInWithPopup/Provider()` に移行 |
| `lib/presentation/sync_page.dart` | 更新 | 同上（Sheets 連携ページのサインインバナー） |
| `lib/presentation/settings_page.dart` | 更新 | アカウント表示を `firebaseUserProvider` ベースに |
| `lib/presentation/widgets/google_sign_in_brand_button.dart` | 削除 | 不要 |
| `lib/presentation/widgets/google_web_sign_in*.dart` | 削除 | 不要 |

---

## 受け入れ基準

| # | 条件 |
|---|------|
| AC-1 | ローカルデータがある状態でサインインすると、全エントリが Firestore に書き込まれる |
| AC-2 | 2回目以降のサインイン（同一端末）では移行処理がスキップされる |
| AC-3 | サインイン後の単語登録・編集・削除が Firestore に即座に反映される |
| AC-4 | 同一アカウントで別端末（または Web）を開くと、リアルタイムに単語が同期される |
| AC-5 | 未サインイン状態でも全機能（検索・登録・フラッシュカード）が動作する |
| AC-6 | サインアウトするとローカル保存モードに切り替わり、以降の操作はローカルに保存される |
| AC-7 | Android / iOS / Web いずれのプラットフォームでもサインインが完了する |
| AC-8 | Google Sheets 同期が引き続き動作する（access token が OAuthCredential から取得できる） |

---

## 既知のリスクと対策

| リスク | 影響 | 対策 |
|--------|------|------|
| `flutterfire configure` の実行漏れ | Firebase 初期化失敗（起動クラッシュ） | `firebase_options.dart` に TODO コメントと手順を明記。CI で placeholder 検出 |
| Firestore セキュリティルール未設定 | 全ユーザーのデータが相互参照可能 | `users/{uid}/entries` を `request.auth.uid == uid` でガードするルールを必ず設定 |
| OAuthCredential が null になるケース | Sheets 同期が「未ログイン」扱いになる | `sheetsAccessTokenProvider` が null のとき同期ページで再サインインを促すバナーを表示（既存実装で対応済み） |
| ローカルデータの移行漏れ | 移行前に削除した SharedPrefs データが Firestore に届かない | 移行フラグは「移行完了」後にセット。移行失敗時はフラグを立てずリトライ可能にする |
| 500エントリ超のバッチ書き込み失敗 | 大量データ保有ユーザーの移行失敗 | `_batchLimit = 490` で分割コミット済み |

---

## マイルストーン

| フェーズ | 内容 | 状態 |
|---------|------|------|
| 1. 基盤実装 | `FirestoreUserDictionaryRepository` / `LocalDataMigrator` 新規作成 | ✅ 完了 |
| 2. プロバイダ刷新 | `providers.dart` で Firebase Auth + Repository 切り替えロジック | ✅ 完了 |
| 3. 認証 UI 移行 | `AccountMenuButton` / `SyncPage` を `firebase_auth` ベースに | ✅ 完了 |
| 4. 旧コード削除 | `google_sign_in` 依存・削除対象ウィジェット除去 | ✅ 完了 |
| 5. Firebase 設定 | `flutterfire configure` 実行・Firestore セキュリティルール設定 | ⏳ 要対応 |
| 6. テスト・検証 | AC-1〜AC-8 の手動検証（Android / Web） | ⏳ 要対応 |
| 7. リリース | changelog 更新、APK ビルド・配布 | ⏳ 要対応 |

---

## 未対応事項（リリース前に必須）

1. **`flutterfire configure` の実行**  
   `firebase_options.dart` の `REPLACE_WITH_*` プレースホルダーを実際の値に置き換える

2. **Firestore セキュリティルール**  
   ```js
   match /users/{uid}/entries/{entryId} {
     allow read, write: if request.auth != null && request.auth.uid == uid;
   }
   ```

3. **iOS `GoogleService-Info.plist` の配置**  
   `flutterfire configure` 実行後に `ios/Runner/` へコピー

4. **Android `google-services.json` の配置**  
   同上、`android/app/` へコピー

5. **changelog-langbridge.html への v1.4.0 エントリ追加**

---

## 参考

- Firestore データパス: `users/{uid}/entries/{entry.id}`
- Firebase プロジェクト ID: `silver-adapter-493009-s8`
- 実装ブランチ: `main`（現在 uncommitted changes）
- 関連ファイル:
  - [firestore_user_dictionary_repository.dart](lib/infrastructure/firestore/firestore_user_dictionary_repository.dart)
  - [local_data_migrator.dart](lib/infrastructure/firestore/local_data_migrator.dart)
  - [providers.dart](lib/app/providers.dart)
