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
| `flutter/.fvmrc` | Flutter SDK（FVM） |
| `*/gradle/wrapper/gradle-wrapper.properties` | Gradle |

## CI

- 実装ごとにワークフローを分け、`paths` で対象ディレクトリの変更時だけ走らせる。
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
