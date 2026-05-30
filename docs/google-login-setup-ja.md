# Google ログインを通すまで（最短チェックリスト）

アプリ側は `google_sign_in` + Sheets スコープでログイン済みです。**うまくいかないときはほぼ Google Cloud / Firebase の登録漏れ**です。

---

## エミュレータで Google ログインが失敗するとき（やる順番）

logcat に **`SERVICE_VERSION_UPDATE_REQUIRED`** や **`Google Play services out of date`** / **`Requires … but found …`** が出ている場合は、**クラウド設定の前に**次をそのまま実行してください。

1. **使っている仮想端末（AVD）を確認する**  
   Android Studio → **Device Manager**（デバイスマネージャー）→ 該当デバイスの **システムイメージ名** を見る。  
   - **Play ストアのアイコン（Google Play）付き**のイメージであること。  
   - **Google APIs のみ**（Play マークなし）だと、サービス更新ができず同じエラーが抜けられないことがあります。

2. **Google Play 開発者サービスを新しくする**（エミュレータの画面で操作）  
   - **Chrome などブラウザで `play.google.com` を開いてインストールしようとしないでください。** エミュレータでは「エラーが発生しました」になりやすく、**通常はそこからは入れられません**。  
   - ホーム画面のアプリ一覧から **Play ストア**（Google の三角形の店アイコン）を起動する。  
   - Play ストアに **Google アカウントでログイン**する。  
   - ストア内の検索で **「Google Play 開発者サービス」** または **「Google Play サービス」** を開き、**更新**が出ていれば実行する。  
   - 項目が「開く」だけで更新が無い場合もある。そのときは手順 4 で **新しいシステムイメージの AVD** に切り替えるのが確実。  
   - 補助として **設定 → アプリ → Google Play 開発者サービス** を開き、表示される案内に従う（端末によって名前が少し違います）。

3. **アプリを完全に止めてから再度実行する**  
   - ホットリスタートだけに頼らず、実行中の `flutter run` を止めるかエミュレータ上でアプリを終了し、改めて  
     `flutter run -d <デバイスID>`  
     で起動する。  
   - `SharedPreferencesApi` の channel-error が出ていた場合も、ここで消えることが多いです。

4. **まだ同じログが出る場合**  
   - Android Studio の **Settings**（macOS では **Preferences** のこともあり）→ **Languages & Frameworks → Android SDK** を開く。**SDK Platforms** タブで **Google Play** 付きの **新しい API レベル**（例: Android 15 / API 35）が入っているか確認し、無ければ **Show Package Details** で該当イメージにチェックを入れて **Apply** でダウンロードする。  
   - **Device Manager** → **Create Device** で端末を選び、システムイメージ一覧で **Google Play** 列にアイコンがある行だけを選ぶ → **新しい AVD** を作成して起動し、手順 3 からアプリを入れ直す。  
   - 古い AVD は削除してよい。  
   - または **USB デバッグした実機**で試す（実機の Play サービスは通常、エミュより新しい）。

**要点**: ローカルエミュレータでテスト**できます**。足りないのはアプリのソースではなく、**そのエミュレータ内の「Google Play 開発者サービス」のバージョン**です。Play ストアの話は「仮想端末の中のその部品を更新するため」に出てきます。

---

## Play ストアアプリが無いとき（Google Play 付き AVD の作り方）

**Play ストアが無い = 今の仮想端末が「Google APIs のみ」のシステムイメージです。** この種類には **Play ストアは最初から入りません**。別途「**Google Play**」付きのシステムイメージで **新しい AVD を作り直す**必要があります（既存 AVD に後から足すことはできません）。

### Settings に「Android SDK」が無いとき（重要）

**IntelliJ IDEA など「Android Studio 以外」の IDE** で **Settings / Preferences** を開いていると、**Languages & Frameworks** に **Dart / Flutter** はあっても **Android SDK** は **出ないことがあります**（Android 用プラグインや SDK 統合が無い構成のため）。**Android SDK の管理 UI は Android Studio に含まれている**のが一般的です。

1. **Android Studio** をインストールする（未導入なら [Android Studio のダウンロード](https://developer.android.com/studio)）。  
2. Dock やアプリ一覧から **緑のロケットのアイコン「Android Studio」** を起動する（**いま IDE を開いている画面のまま探しても、別アプリ側のメニューです**）。  
3. Welcome 画面なら右上 **⋮ More Actions**（その他）から **SDK Manager** / **Virtual Device Manager** へ。  
   プロジェクトを開いているならメニュー **Tools → SDK Manager** / **Tools → Device Manager**。  
4. 以降は下の「手順 A」「手順 B」と同じ。

Android Studio を入れずに済ませたい場合は、このドキュメント末尾付近の **コマンドライン（sdkmanager）** の節を使う方法もあります。

### 手順 A: システムイメージを SDK に入れる（一覧に「Google Play」が出ないとき先に実施）

1. **Android Studio** を開く（上記のとおり **Android Studio アプリ**であること）。  
2. **Settings** を開く（Windows/Linux: **File → Settings**。macOS: **Android Studio → Settings** または **Preferences**）。  
3. 左の **Languages & Frameworks → Android SDK**。  
4. **SDK Platforms** タブを開く。  
5. 右下の **Show Package Details**（パッケージの詳細を表示）にチェック。  
6. 一覧で **少し新しい Android**（例: **Android 15.0** や **Android 14.0**）の行を **展開**する。  
7. 名前に **Google Play** と入っている行にチェックを入れる。例:  
   - `Google Play Intel x86_64 Atom System Image`（Intel Mac / 多くの Windows）  
   - `Google Play ARM 64 v8a System Image`（**Apple Silicon Mac** ではこちら系を選ぶ）  
   ※ **Google APIs Intel …** だけにチェックを入れない。**Google Play** が付いた行であること。  
8. **Apply** → ダウンロードが終わるまで待つ。

### 手順 B: Google Play 付きの仮想端末（AVD）を新規作成

1. Android Studio のメニュー **Tools → Device Manager**（日本語UI: **ツール → デバイスマネージャー**）。Welcome 画面だけのときは **More Actions → Virtual Device Manager** などから同じ画面へ。  
2. **Create Device**（デバイスを作成 / + アイコン）。  
3. 端末の型を選ぶ（例: **Pixel 8**）→ **Next**。  
4. **System Image** の画面で、一覧の各行を見る。  
   - **Google Play** と表示されている行、または **Play ストアのアイコン**が付いている行だけを選ぶ。  
   - **Download** と出ていれば押して、完了してからその行を選ぶ。  
   - **Google APIs** とだけ書いて **Google Play が付いていない行は選ばない**（ここを間違えるとまた Play ストアが無い）。  
5. **Next** → 必要なら AVD 名を変えて **Finish**。  
6. 一覧の **▶** でこの **新しい AVD** を起動する。  
7. エミュレータの **アプリドロワー**（上にスワイプした画面の丸いアイコン列）に **Play ストア** が出ていれば成功。

### アプリの実行先を切り替える

ターミナルで:

```bash
flutter devices
```

新しいエミュレータの ID（例: `emulator-5556`）を確認し:

```bash
flutter run -d emulator-5556
```

古い「Play ストア無し」の AVD は **Device Manager から Delete** してよい。

### コマンドラインだけで入れる（Android Studio の画面が使えないとき）

ターミナルで SDK の場所を確認する:

```bash
flutter doctor -v
```

出力の **Android toolchain** に `Android SDK at` としてパスが出ます（macOS の例: `/Users/あなたの名前/Library/Android/sdk`）。以降これを `ANDROID_HOME` とします。

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
SM="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
```

`cmdline-tools/latest` が無い場合は、一度 **Android Studio** を入れて起動するか、[Command line tools only](https://developer.android.com/studio#command-line-tools-only) を SDK 内に展開してください。

**Apple Silicon Mac** の例（API 35・Play ストア付きイメージ）:

```bash
yes | "$SM" --install "platform-tools" "emulator" "system-images;android-35;google_apis_playstore;arm64-v8a"
"$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager" create avd -n Pixel35Play -k "system-images;android-35;google_apis_playstore;arm64-v8a" -d pixel_8
```

**Intel Mac / 多くの Windows（x86_64 エミュレータ）** の例:

```bash
yes | "$SM" --install "platform-tools" "emulator" "system-images;android-35;google_apis_playstore;x86_64"
"$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager" create avd -n Pixel35Play -k "system-images;android-35;google_apis_playstore;x86_64" -d pixel_8
```

`avdmanager` が対話で聞いてきたら **no**（カスタムハードウェア無し）でよいことが多いです。作成後:

```bash
flutter emulators
flutter emulators --launch Pixel35Play
```

利用可能な `system-images;…` の名前は `sdkmanager --list` で `google_apis_playstore` を検索すると確認できます。

---

## 1. デバッグ用 SHA-1 を取る（Android）

プロジェクトで:

```bash
cd android && ./gradlew :app:signingReport
```

`Variant: debug` の **SHA1** をコピーする。

## 2. Google Cloud で Android 用 OAuth クライアントを作る

1. [Google Cloud Console](https://console.cloud.google.com/) → 本アプリのプロジェクト  
2. **API とサービス** → **認証情報** → **OAuth クライアント ID を作成**  
3. 種類: **Android**  
4. **パッケージ名**: `jp.langbridge`（`android/app/build.gradle.kts` の `applicationId` と一致）  
5. **SHA-1**: 手順 1 の値を貼る  

※ **同じプロジェクト**で、次の「ウェブ」クライアントと揃えること。

## 3. 「ウェブアプリケーション」OAuth クライアント ID（必須）

Android の Google ログインでは **ウェブ用クライアント ID** が `serverClientId` として必要です。

1. 同じく **認証情報** → **OAuth クライアント ID を作成**  
2. 種類: **ウェブアプリケーション**  
3. 作成後に表示される **クライアント ID**（`….apps.googleusercontent.com`）をコピー  

次の **どちらか** に反映する:

- `android/app/src/main/res/values/sign_in_config.xml` の `default_web_client_id`  
- またはビルド時: `--dart-define=GOOGLE_SERVER_CLIENT_ID=そのクライアントID`

`lib/app/app_config.dart` の `googleServerClientId` 既定値と **同じプロジェクトのウェブ ID** になっているか確認する。

## 4. Sheets API を有効にする

**API とサービス** → **ライブラリ** → **Google Sheets API** → **有効**

## 5. OAuth 同意画面とテストユーザー

アプリが「テスト中」のとき、ログインする Google アカウントを **テストユーザー** に追加する。

**Google Auth Platform** → **ブランディング / 対象**（または従来の OAuth 同意画面）から設定。

## 6. よくあるエラー

| 現象 | 対処 |
|------|------|
| logcat に `Google Play services out of date` / `Requires … but found …` / `SERVICE_VERSION_UPDATE_REQUIRED` | **端末の Google Play 開発者サービス（Google Play サービス）が古い**。エミュレータは **Google Play アイコン付き** システムイメージを使い、**Play ストア** を開いて **Google Play 開発者サービス** を更新する。更新できない AVD は捨てて、API レベルが新しい **Google Play** イメージで作り直す。実機なら Play ストアから同じく更新。 |
| Hot restart 直後に `SharedPreferencesApi.getAll` の channel-error | ネイティブ側が不安定なときに出る。**アプリを完全終了**してから `flutter run` し直す（ホットリスタートだけでは直らないことがある）。 |
| `getCredentialAsync no provider dependencies found` | アプリに `credentials-play-services-auth` 等が入っているか確認（本リポジトリの `android/app/build.gradle.kts` を参照）。あわせて上の **GMS 更新** も確認。 |
| `ApiException: 10` / `DEVELOPER_ERROR` | SHA-1 未登録 or パッケージ名不一致。手順 1–2 |
| `serverClientId` 系 | ウェブ用クライアント ID が未設定 or 別プロジェクト。手順 3 |
| ログイン後も Sheets が失敗 | Sheets API 未有効、またはスコープ・同意画面。手順 4–5 |

## iOS

`Info.plist` の `GIDClientID`、または `--dart-define=GOOGLE_IOS_CLIENT_ID=…` で **iOS 用 OAuth クライアント ID** を渡す。詳細は `integration.md` の iOS 節。

---

**補足**: リポジトリの `android/app/google-services.json` に `oauth_client` が空でも、上記の **手動の `sign_in_config.xml` + Dart の serverClientId** で動かせます。Firebase に SHA-1 を登録して JSON を再取得すると、別経路で埋まることもあります。
