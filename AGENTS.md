# AGENTS.md

クロスプラットフォームのフレームワークで**アプリ全体**を作ったときの性能を、ネイティブアプリと比べる
ベンチマークのリポジトリです。同じ「GitHub リポジトリ検索」アプリを native / Flutter / Expo の 3 通りで実装し、
起動時間・応答速度・メモリ・アプリサイズを同じ手順で測ります。

前身の [benchmark-mobile-app-framework-embedding](https://github.com/mitsuharu/benchmark-mobile-app-framework-embedding)
は、ネイティブアプリに**画面だけを埋め込んだ**ときの比較でした。こちらは同じ題材・同じ計測条件のまま、
アプリ全体をそのフレームワークで作った場合を見ます。

作業前に `README.md` と、変更するディレクトリの README を読んでください。

## ディレクトリ

| パス | 内容 |
| --- | --- |
| `native/` | 基準。iOS は SwiftUI、Android は Jetpack Compose のアプリ |
| `flutter/` | Flutter のアプリ 1 つで iOS / Android の両方 |
| `expo/` | Expo（React Native）のアプリ 1 つで iOS / Android の両方 |
| `bench/` | モックサーバ、agent-device による計測ランナー、結果の集計 |

`native/` だけが `ios/` と `android/` に分かれます。Flutter と Expo は 1 つのアプリが両プラットフォームを作ります。

## 機能の仕様（全実装で揃える）

比較の前提になるので、ここを変えるときは全実装を同時に直します。
画面は 2 つで、ホーム画面から検索画面をスタックに積みます。

- **ホーム画面**: 検索ワードの入力欄、検索画面を開くボタン、検索画面から受け取った結果
  （キーワード・件数・上位 3 件）
- **検索画面**: 受け取ったキーワードで GitHub Search API
  （`/search/repositories?q=<keyword>&sort=stars&order=desc&per_page=20`）を叩いて一覧表示する。
  「リポジトリを検索」「ホームに戻る」の 2 ボタンと、キーワードを差し替えるボタンの列。
  ナビゲーションバー（タイトルバー）は出さない。1 つの実装にだけ出すと、その分が
  `searchFirstFrame` に入って比較にならないため
- **ホーム → 検索**: 画面生成時に渡すキーワードと、表示中の画面へのキーワード差し替えコマンド `setKeyword`
- **検索 → ホーム**: `searchSucceeded`（`keyword`, `repositories[id, fullName, stars, language]`）と
  `searchFailed`（`keyword`, `message`）
- **API のベース URL** は差し替えられるようにする。既定は `https://api.github.com`、
  計測時は `bench/mock-server`（iOS / Android とも `http://127.0.0.1:8787`。Android は `adb reverse` で端末内に転送する）

画面どうしのやり取りは、埋め込みのときのブリッジと同じ形（イベントとコマンド）を、
それぞれのフレームワークの中だけで完結させて実装します。プロセスをまたぐ通信はありません。

### 画面の文言と識別子

計測ランナーは agent-device でこれらを探して操作するので、全実装で同じにします。

| 要素 | 文言 | 識別子（iOS: accessibilityIdentifier / Android: resource-id） |
| --- | --- | --- |
| 検索ワード入力欄 | placeholder `keyword` | `keywordField` |
| 検索画面を開くボタン | 実装ごとに自由 | `openSearch` |
| 検索ボタン | `リポジトリを検索` | — |
| 戻るボタン | `ホームに戻る` | — |
| 受け取った件数 | `件数` / `20` | — |
| キーワード差し替え | 検索画面の上部に並ぶボタン。候補は `expo` / `swift` / `kotlin` | — |
| 適用中のキーワード | `keyword: <キーワード>` | — |

Android の Compose では `Modifier.testTag` を resource-id として公開するため、
ルートに `semantics { testTagsAsResourceId = true }` を付けます。

## 計測マーカー

時間の計測はアプリ内のマーカーで行います。agent-device の操作にかかる時間を含めないためです。
すべての実装が次の形式で 1 行ずつ出力します。

```text
BENCH|<name>|<epochMs>
```

- iOS: `Logger(subsystem: "bench", category: "marker")` に `privacy: .public` で出す
  （既定の `private` だとリリースビルドで `<private>` に伏せられる）。実機ではアプリのログに統合ログが入らないので
  stderr にも書く
- Android: `Log.i("Bench", ...)`
- Dart / JavaScript の時刻はその場で取り、ネイティブ側の薄い層に渡してログに出す。
  どちらも壁時計のミリ秒なので同じプロセス内で比較できる

| name | タイミング |
| --- | --- |
| `processStart` | プロセスの開始時刻。iOS は `sysctl` の `p_starttime`、Android は `Process.getStartUptimeMillis()` を壁時計に換算。`homeFirstFrame` と同時に出力する |
| `homeFirstFrame` | ホーム画面の最初のフレームの後 |
| `searchOpenTapped` | 検索画面を開くボタンのタップ時 |
| `searchFirstFrame` | 検索画面の最初のフレームの後 |
| `searchTapped` | 「リポジトリを検索」のタップ時 |
| `searchRendered` | 検索結果を描画したフレームの後 |
| `resultsReceived` | ホーム画面が `searchSucceeded` を受け取った時 |
| `commandSent` | `setKeyword` を送った時 |
| `keywordApplied` | 差し替えたキーワードを描画したフレームの後 |

「フレームの後」は各フレームワークで最も近い手段を使います
（Compose: `withFrameNanos`、Flutter: `addPostFrameCallback`、SwiftUI: `onAppear` の次のメインループ、
React Native: コミット後の `requestAnimationFrame`）。

## コーディング規約

### 共通

- コードコメントとコミットメッセージは英語、UI の文言とドキュメントは日本語。
- インデントは 2 スペース（Swift / Kotlin / TypeScript / Dart / YAML）。
- コメントには「何を」より「なぜ」を書く。実際に踏んだ落とし穴は README かコメントに残す。
- 生成物はコミットしない（`native/ios` の `.xcodeproj`、`expo prebuild` の出力、ビルド出力）。
  例外は Flutter の `ios/` と `android/`。Flutter のテンプレートの一部で、マーカーを出すコードを手で入れている。
- 依存を追加するときはバージョンを固定する。

### Swift

- swift-format（Xcode 同梱）。ルートの [`.swift-format`](.swift-format) を使い、
  `./scripts/swift-format.sh`（`--fix` で自動修正）で検査する。
- `native/ios` の Xcode プロジェクトは XcodeGen の `project.yml` から生成する。`.xcodeproj` はコミットしない。
- iOS 16.4 以上、SwiftUI。テストは XCTest。

### Kotlin

- Kotlin 公式スタイルに 2 スペースのインデント。UI は Jetpack Compose。
- JDK 17 でビルドする。
- テストは JUnit + Robolectric。

### TypeScript / JavaScript

- Biome（シングルクォート、セミコロンなし）。`npm run lint` で検査する。

### Dart

- `dart format` と `flutter analyze`（`flutter_lints`）。Flutter のバージョンは FVM で固定する。

## バージョンの固定

| ファイル | 用途 |
| --- | --- |
| `.node-version` | Node.js。`actions/setup-node` の `node-version-file` も読む |
| `.xcode-version` | Xcode。CI ではランナー同梱の `xcodes` で選択する |
| `flutter/.fvmrc` / `qr/flutter/.fvmrc` | Flutter SDK（FVM）。2 つのアプリは同じ版に揃える |
| `*/gradle/wrapper/gradle-wrapper.properties` | Gradle |

## CI

- 実装ごとにワークフローを分け、`paths` で対象ディレクトリの変更時だけ走らせる。
  QR のベンチマーク（`qr/`）は `qr.yml` にまとめる。
- アクションはコミット SHA で固定し、行末にバージョンをコメントで書く。
- npm は [Aikido Safe Chain](.github/actions/setup-safe-chain) を通し、`.npmrc` の `min-release-age=3` で
  公開直後のバージョンを避ける。

## 自動操作

シミュレータ / エミュレータ / 実機の操作は、すべて [agent-device](https://github.com/callstack/agent-device) で行います
（`bench/` の devDependency）。`simctl` / `adb` はビルド成果物の確認やログの読み取りなど、
UI 操作以外にとどめます。

## Git / Pull Request

- ブランチは `feature/<topic>`。`main` へ直接コミットしない。
- コミットは目的・機能単位。メッセージは英語の命令形で、何のための変更かが分かるように書く。
- PR には概要と確認方法を書く。画面に変化がある場合は `gh pr create --attach` でスクリーンショットを添付する。
- CI が通り、セルフレビューで問題がないことを確認してから `gh pr merge --merge` でマージする。

## QR デコードのベンチマーク（`qr/`）

同じ題材の 2 つ目の計測です。カメラを使うと人手が要るので、アプリに同梱した QR 画像を連続でデコードして測ります。
**実機のリリースビルドだけ**を計測します。

### 使うライブラリ

「React Native は `react-native-nitro-zxing`、ほかは各スタックの標準」という方針です。
中のエンジンが実装ごとに違うので、同じアルゴリズムの比較ではありません。

| 実装 | ライブラリ | エンジン |
| --- | --- | --- |
| `qr/native/ios` | Vision（`VNDetectBarcodesRequest`） | Apple Vision |
| `qr/native/android` | ML Kit Barcode Scanning（bundled） | ML Kit |
| `qr/flutter` | `mobile_scanner` | iOS: Apple Vision / Android: ML Kit |
| `qr/expo` | `react-native-nitro-zxing` | zxing-cpp（Nitro の C++） |

### 画像

`bench/scripts/make-qr-images.swift` が 512×512 の PNG を 500 枚作ります（Core Image / ImageIO だけを使う）。
中身は `https://example.com/benchmark/qr/<3 桁>` で 1 枚ずつ違い、デコード結果が正しいかを番号で照合できます。

正本は `qr/images/` だけをコミットし、各アプリのアセットへのコピーは
`qr/scripts/sync-images.sh` が作ります（`qr/.gitignore` で無視）。`bench/scripts/build.sh` がビルド前に走らせます。

### 機能の仕様（全実装で揃える）

画面は 1 つです。

- **準備**: 起動したら、同梱の 500 枚をアプリの書き込み領域（Documents / filesDir）へ展開する。
  展開が終わったら `準備完了: 500 枚` と表示し、開始ボタンを出す。ここは計測に含めない。
- **デコード**: 開始ボタンを押したら、展開したファイルを 1 枚ずつ**ファイルパスから**デコードする。
  1 枚終わったら次、の直列。デコード結果が期待する文字列と一致した数を数える。
- **進捗**: デコード中は `デコード中: <済み> / 500` と `経過: <秒> 秒` を出す。
  ループはカウンタを増やすだけにして、画面の更新は 100 ms ごとの別のタイマーから行う。
  1 枚ごとに再描画するとその時間が計測に入るため。4 実装とも同じ間隔にする。
- **結果**: `デコード完了: <成功数> / 500`、合計ミリ秒、1 枚あたりのミリ秒を表示する。

ファイルパスを入口に揃えているのは、`mobile_scanner.analyzeImage()` がパスしか受け取らないからです。
そのぶん PNG のデコードも計測に入りますが、4 実装とも同じ条件です。

### 画面の文言と識別子

| 要素 | 文言 | 識別子 |
| --- | --- | --- |
| 準備完了 | `準備完了: 500 枚` | — |
| 開始ボタン | `デコードを開始` | `startDecode` |
| 進捗 | `デコード中: <済み> / 500` / `経過: <秒> 秒` | — |
| 完了 | `デコード完了: 500 / 500` | — |

完了の文言を `完了` で始めないのは、`準備完了` にも含まれてしまい、計測ランナーの
`wait text` が準備の段階で通ってしまうためです。

### 計測マーカー

`BENCH|<name>|<epochMs>` の形式は同じです。**時刻はメモリに貯めて、ループが終わってからまとめて出力します**。
ログ出力を計測区間に入れないためです。

| name | タイミング |
| --- | --- |
| `processStart` / `homeFirstFrame` | 既存の計測と同じ |
| `decodeStarted` | 開始ボタンのタップ時（ループに入る直前） |
| `decodeFinished` | ループを抜けた時刻 |

1 枚ごとの時間は、マーカーではなく**値の行**で出します。1 枚が 1 ms を切ると同じミリ秒のマーカーが
重複して消えてしまうこと、500 行を出すと読み取りが重いことの 2 つが理由です。

```text
BENCHVAL|<name>|<value>
```

| name | 値 |
| --- | --- |
| `decodedCount` | 期待どおりデコードできた枚数 |
| `decodeDurationsUs` | 1 枚ごとのマイクロ秒をカンマで並べたもの（500 個） |

時間はアプリ側で単調増加クロック（iOS: `CFAbsoluteTime` ではなく `DispatchTime` / Android: `System.nanoTime`）で測り、
中央値などの集計は計測ランナー側（JavaScript）でまとめて行います。集計の実装を 1 か所に寄せるためです。

指標は `decodeStarted` → `decodeFinished` の合計と、`decodeDurationsUs` の中央値（1 枚あたり）です。
