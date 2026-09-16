# benchmark-mobile-app-crossplatform

クロスプラットフォームのフレームワークで**アプリ全体**を作ったときの起動時間・応答速度・メモリ・アプリサイズを、
ネイティブアプリと比べるベンチマークです。

題材は「GitHub のリポジトリを検索して一覧表示し、結果を前の画面に返す」2 画面のアプリです。
これを native（SwiftUI / Jetpack Compose）、Flutter、Expo（React Native）の 3 通りで実装し、
同じ画面構成・同じ操作・同じ計測手順で比べます。

前身の [benchmark-mobile-app-framework-embedding](https://github.com/mitsuharu/benchmark-mobile-app-framework-embedding)
は、既存のネイティブアプリに**画面だけを埋め込んだ**（brownfield）ときの比較でした。
こちらは同じ題材・同じ計測条件のまま、**アプリ全体をそのフレームワークで作った**場合を見ます。

## 構成

```
.
├── native/    # 基準。iOS は SwiftUI、Android は Jetpack Compose
│   ├── ios/
│   └── android/
├── flutter/   # Flutter のアプリ 1 つで iOS / Android
├── expo/      # Expo（React Native）のアプリ 1 つで iOS / Android
└── bench/     # モックサーバ、agent-device による計測ランナー
```

機能の仕様、計測マーカー、コーディング規約は [AGENTS.md](AGENTS.md) にまとめています。

## 動作の様子

計測用ビルド（検索先はモックサーバ）を agent-device で操作した画面の録画です。
ホーム画面 → 検索画面を開く → 「リポジトリを検索」→ キーワードを `swift` に差し替える → ホームに戻り、受け取った結果を表示する、の順です。

| | native | Flutter | Expo |
| --- | --- | --- | --- |
| iOS | ![iOS native](docs/media/ios-native.gif) | ![iOS Flutter](docs/media/ios-flutter.gif) | ![iOS Expo](docs/media/ios-expo.gif) |
| Android | ![Android native](docs/media/android-native.gif) | ![Android Flutter](docs/media/android-flutter.gif) | ![Android Expo](docs/media/android-expo.gif) |

録画は `node bench/demo.mjs` で撮り直せます（[bench/README.md](bench/README.md)）。

## 各実装の作り方

| | [native](native/README.md) | [flutter](flutter/README.md) | [expo](expo/README.md) |
| --- | --- | --- | --- |
| iOS の画面 | SwiftUI | Flutter（Skia / Impeller で自前描画） | React Native（UIKit のビュー） |
| Android の画面 | Jetpack Compose | 同上 | React Native（Android View） |
| 画面遷移 | iOS: `NavigationStack` の push / Android: `startActivity` | `Navigator.push` | `@react-navigation/native-stack` |
| 画面どうしの通信 | Swift / Kotlin の値をそのまま（`AppChannel`） | Dart の broadcast ストリーム | TypeScript のイベントバス |
| HTTP | `URLSession` / `HttpURLConnection` | `package:http` | `fetch` |
| ランタイム | なし | Flutter エンジン + Dart | Hermes + React Native |
| ネイティブコード | アプリ全体 | 計測マーカーのみ | 計測マーカーのみ（ローカル Expo モジュール） |

## 計測環境

すべての結果に共通です。

| | |
| --- | --- |
| Mac | MacBook Air（M3, 2024 / Mac15,12）、メモリ 16 GB、macOS 26.6.2 |
| iOS シミュレータ | Xcode 26.6、iPhone 17 シミュレータ（iOS 26.5） |
| Android エミュレータ | Android Emulator 37.1.11、AVD Pixel 9（API 36, Google APIs, arm64-v8a） |
| iOS 実機 | iPhone XR（A12 Bionic、iOS 18.7） |
| Android 実機 | Rakuten Hand 5G（Snapdragon 480 5G、Android 11） |
| ツール | agent-device 0.21.1、Node.js 24.13.0 |
| フレームワーク | Flutter 3.47.4、Expo SDK 57（React Native 0.86.3） |

実機はどちらも数年前の機種で、開発機の上で動くシミュレータ / エミュレータより CPU が遅い点に注意してください。

## 計測条件

結果は、ビルドの種類と端末の組み合わせで 3 つあります。

| 結果 | ビルド | 端末 | 何のための計測か |
| --- | --- | --- | --- |
| [1. デバッグビルド](#1-デバッグビルド) | デバッグ | iOS シミュレータ / Android エミュレータ | 開発中（Xcode / Android Studio から動かすとき）の体感 |
| [2. リリースビルド](#2-リリースビルド) | リリース | iOS シミュレータ / Android エミュレータ | **フレームワーク間の比較の基準** |
| [3. 実機](#3-実機) | リリース | iPhone XR / Rakuten Hand 5G | シミュレータ / エミュレータの傾向が実機でも同じか |

ビルドの種類ごとの中身は次のとおりです。

| | デバッグビルド | リリースビルド |
| --- | --- | --- |
| native | Xcode の Debug 構成 / Android の debug ビルドタイプ | Release 構成 / release ビルドタイプ（R8 有効、デバッグ鍵で署名） |
| Flutter | JIT | Android・iOS 実機: AOT。**iOS シミュレータ: JIT**（下記） |
| Expo | JS は Metro から読み込む（Android は `adb reverse tcp:8081`） | JS（Hermes バイトコード）は成果物に同梱 |

**iOS シミュレータの Flutter は、リリースビルドでもデバッグ（JIT）の Flutter です。**
AOT の Flutter エンジンはシミュレータ向けのスライスに Dart のコードを持たず、シミュレータでは動かせないためです。
そのため iOS シミュレータの Flutter はデバッグとリリースで同じビルドで、
[2. リリースビルド](#2-リリースビルド) の Flutter / iOS の「デバッグ → リリース」の行だけは差が出ません。
**iOS の Flutter のリリース（AOT）の値は [3. 実機](#3-実機) にあります。**

どの結果も、次の条件は共通です。

- **操作**: [agent-device](https://github.com/callstack/agent-device) ですべて自動化する。1 回の計測は
  「コールド起動 → 検索画面を開く → 検索 → キーワードを差し替える → 戻る → もう一度開く → 戻る」。
- **回数**: 各実装 5 回の中央値。インストール直後の 1 回（ウォームアップ）は除く。
- **並べる 3 実装は続けて計測する**: エミュレータの値は起動してからの時間で変わるので、
  1 つの表に並ぶ 3 実装は同じセッションのうちに続けて測り、日をまたいだ値は混ぜません。
- **時間**: agent-device の操作時間を含めないよう、アプリ内で出力するマーカー（`BENCH|<name>|<epochMs>`）の差で測る。
  コールドスタートはプロセスの開始（iOS は `p_starttime`、Android は `Process.getStartUptimeMillis()`）から数えるので、
  OS がプロセスを起こす時間も入ります。
- **メモリ**: agent-device の `perf memory sample`。iOS はプロセスの RSS、Android は PSS で、指標が違います。プラットフォームをまたいで比べないでください。
- **通信**: GitHub API の代わりに [bench/mock-server](bench/README.md) が固定の 20 件を返す。つなぎ方は、iOS シミュレータは Mac のループバック、
  Android（エミュレータ / 実機）は USB などの `adb reverse`、iPhone 実機は Mac の LAN のアドレス（Wi‑Fi 経由）です。
- **アプリサイズ**: Android の APK は複数の ABI を含む 1 つの APK です。ストアで ABI ごとに配信した場合の大きさではありません。

### 「フレームの後」の測り方には、1 フレームぶんの差がある

描画の完了（`homeFirstFrame` / `searchFirstFrame` / `searchRendered` / `keywordApplied`）は、
各フレームワークで最も近い手段を使っています（Compose: `withFrameNanos`、Flutter: `addPostFrameCallback`、
SwiftUI: `onAppear` の次のメインループ、React Native: コミット後の `requestAnimationFrame`）。
これらは「描いたフレームの終わり」と「次のフレームの始まり」のどちらかで、**実装によって最大 1 フレーム（60 Hz で約 16 ms）ずれます**。

**20 ms 前後の差は、この計測方法の差に埋もれます。**
たとえばコールドスタートで Flutter が native をわずかに下回る結果が出ていますが（エミュレータ 62 ms / 80 ms、
Rakuten Hand 143 ms / 172 ms）、これは「Flutter のほうが速い」ではなく「ほぼ同じ」と読んでください。
桁が変わるような差（Expo のデバッグビルドのコールドスタート、メモリ、アプリサイズなど）が、この計測で意味のある差です。

## 1. デバッグビルド

開発中に Xcode / Android Studio から動かすときの構成で、iOS シミュレータと Android エミュレータで計測したものです。

<!-- bench:results:debug:start -->

### iOS：iPhone 17 シミュレータ（iOS 26.5）

デバッグビルド。5 回の中央値（ウォームアップ 1 回を除く）。

#### 時間

|  | native | Flutter | Expo |
| --- | ---: | ---: | ---: |
| コールドスタート（プロセス開始 → ホーム画面） | 874 ms | 1097 ms | 1228 ms |
| 検索画面の表示（初回） | 59 ms | 33 ms | 27 ms |
| 検索画面の表示（2 回目） | 21 ms | 27 ms | 16 ms |
| 検索 → 結果の描画 | 58 ms | 100 ms | 56 ms |
| 検索 → ホーム画面が結果を受信 | 22 ms | 52 ms | 33 ms |
| ホーム画面 → 検索画面へのキーワード差し替え | 7 ms | 10 ms | 16 ms |

#### メモリ（RSS）

|  | native | Flutter | Expo |
| --- | ---: | ---: | ---: |
| ホーム画面の表示後 | 276.0 MB | 393.3 MB | 415.3 MB |
| 検索画面の表示後 | 312.2 MB | 420.5 MB | 446.5 MB |
| 検索後 | 333.4 MB | 444.3 MB | 470.1 MB |
| ホーム画面に戻った後 | 335.3 MB | 459.4 MB | 468.6 MB |

#### アプリサイズ

|  | native | Flutter | Expo |
| --- | ---: | ---: | ---: |
| .app（シミュレータ向け） | 19.9 MB | 139.6 MB | 182.7 MB |

### Android：Pixel 9 エミュレータ（API 36）

デバッグビルド。5 回の中央値（ウォームアップ 1 回を除く）。

#### 時間

|  | native | Flutter | Expo |
| --- | ---: | ---: | ---: |
| コールドスタート（プロセス開始 → ホーム画面） | 590 ms | 819 ms | 2067 ms |
| 検索画面の表示（初回） | 175 ms | 227 ms | 129 ms |
| 検索画面の表示（2 回目） | 66 ms | 20 ms | 33 ms |
| 検索 → 結果の描画 | 119 ms | 116 ms | 144 ms |
| 検索 → ホーム画面が結果を受信 | 19 ms | 56 ms | 38 ms |
| ホーム画面 → 検索画面へのキーワード差し替え | 22 ms | 21 ms | 19 ms |

#### メモリ（PSS）

|  | native | Flutter | Expo |
| --- | ---: | ---: | ---: |
| ホーム画面の表示後 | 73.0 MB | 227.6 MB | 211.7 MB |
| 検索画面の表示後 | 75.2 MB | 228.7 MB | 218.6 MB |
| 検索後 | 79.6 MB | 240.2 MB | 231.3 MB |
| ホーム画面に戻った後 | 80.3 MB | 244.4 MB | 231.2 MB |

#### アプリサイズ

|  | native | Flutter | Expo |
| --- | ---: | ---: | ---: |
| APK | 11.4 MB | 143.6 MB | 155.3 MB |

<!-- bench:results:debug:end -->

### デバッグビルドの結果の読み方

- **Expo のデバッグビルドは、コールドスタートが極端に遅くなります。** Android で約 2.1 秒（リリースは約 135 ms）、
  iOS で約 1.2 秒（リリースは約 920 ms）です。ホーム画面が React Native の画面なので、
  Metro から開発用の JS バンドルを読み終わるまで最初のフレームが出ません。
  埋め込みの比較では「ホスト画面はネイティブ、JS の読み込みは埋め込み画面を開くとき」でしたが、
  アプリ全体を React Native で作ると、この待ちが**起動そのもの**に乗ります。
- **Android のデバッグビルドは全体に遅く、メモリも多く使います。** debuggable なアプリは ART の事前コンパイルを使わず、
  インタプリタと JIT で動くためです。native でもコールドスタートが約 590 ms、検索 → 描画が約 120 ms かかります。
- **メモリはデバッグビルドでは比較になりません。** Android では Flutter・Expo とも約 230 MB（native の約 3 倍）ですが、
  リリースでは 79 MB / 100 MB（native の 2.4〜3 倍）に下がります。
- デバッグビルドの差は「開発中の体感」の目安です。フレームワークの性能の比較には [2. リリースビルド](#2-リリースビルド) を使ってください。

## 2. リリースビルド

アプリとして配布するときの構成で、iOS シミュレータと Android エミュレータで計測したものです。**フレームワーク間の比較の基準**にしています。
各プラットフォームの最後の表は、[1. デバッグビルド](#1-デバッグビルド) からリリースビルドにしたときの変化です。

<!-- bench:results:release:start -->

### iOS：iPhone 17 シミュレータ（iOS 26.5）

リリースビルド。5 回の中央値（ウォームアップ 1 回を除く）。

#### 時間

|  | native | Flutter | Expo |
| --- | ---: | ---: | ---: |
| コールドスタート（プロセス開始 → ホーム画面） | 913 ms | 1122 ms | 924 ms |
| 検索画面の表示（初回） | 65 ms | 33 ms | 16 ms |
| 検索画面の表示（2 回目） | 22 ms | 27 ms | 16 ms |
| 検索 → 結果の描画 | 62 ms | 100 ms | 39 ms |
| 検索 → ホーム画面が結果を受信 | 21 ms | 52 ms | 32 ms |
| ホーム画面 → 検索画面へのキーワード差し替え | 8 ms | 10 ms | 16 ms |

#### メモリ（RSS）

|  | native | Flutter | Expo |
| --- | ---: | ---: | ---: |
| ホーム画面の表示後 | 271.9 MB | 392.3 MB | 274.2 MB |
| 検索画面の表示後 | 308.0 MB | 417.9 MB | 304.3 MB |
| 検索後 | 328.9 MB | 443.7 MB | 337.1 MB |
| ホーム画面に戻った後 | 331.0 MB | 459.6 MB | 340.5 MB |

#### アプリサイズ

|  | native | Flutter | Expo |
| --- | ---: | ---: | ---: |
| .app（シミュレータ向け） | 0.9 MB | 139.6 MB | 54.9 MB |

#### デバッグビルドからの変化（デバッグ → リリース）

|  | native | Flutter | Expo |
| --- | ---: | ---: | ---: |
| コールドスタート（プロセス開始 → ホーム画面） | 874 ms → 913 ms | 1097 ms → 1122 ms | 1228 ms → 924 ms |
| 検索画面の表示（初回） | 59 ms → 65 ms | 33 ms → 33 ms | 27 ms → 16 ms |
| 検索画面の表示（2 回目） | 21 ms → 22 ms | 27 ms → 27 ms | 16 ms → 16 ms |
| 検索 → 結果の描画 | 58 ms → 62 ms | 100 ms → 100 ms | 56 ms → 39 ms |
| 検索 → ホーム画面が結果を受信 | 22 ms → 21 ms | 52 ms → 52 ms | 33 ms → 32 ms |
| ホーム画面 → 検索画面へのキーワード差し替え | 7 ms → 8 ms | 10 ms → 10 ms | 16 ms → 16 ms |
| メモリ（RSS、検索後） | 333.4 MB → 328.9 MB | 444.3 MB → 443.7 MB | 470.1 MB → 337.1 MB |
| アプリサイズ | 19.9 MB → 0.9 MB | 139.6 MB → 139.6 MB | 182.7 MB → 54.9 MB |

### Android：Pixel 9 エミュレータ（API 36）

リリースビルド。5 回の中央値（ウォームアップ 1 回を除く）。

#### 時間

|  | native | Flutter | Expo |
| --- | ---: | ---: | ---: |
| コールドスタート（プロセス開始 → ホーム画面） | 80 ms | 62 ms | 135 ms |
| 検索画面の表示（初回） | 106 ms | 56 ms | 82 ms |
| 検索画面の表示（2 回目） | 48 ms | 8 ms | 21 ms |
| 検索 → 結果の描画 | 44 ms | 25 ms | 60 ms |
| 検索 → ホーム画面が結果を受信 | 6 ms | 5 ms | 31 ms |
| ホーム画面 → 検索画面へのキーワード差し替え | 27 ms | 13 ms | 18 ms |

#### メモリ（PSS）

|  | native | Flutter | Expo |
| --- | ---: | ---: | ---: |
| ホーム画面の表示後 | 21.9 MB | 72.9 MB | 70.5 MB |
| 検索画面の表示後 | 30.5 MB | 74.8 MB | 73.2 MB |
| 検索後 | 33.5 MB | 78.7 MB | 100.0 MB |
| ホーム画面に戻った後 | 33.9 MB | 79.0 MB | 99.4 MB |

#### アプリサイズ

|  | native | Flutter | Expo |
| --- | ---: | ---: | ---: |
| APK（R8 有効） | 1.2 MB | 46.5 MB | 73.9 MB |

#### デバッグビルドからの変化（デバッグ → リリース）

|  | native | Flutter | Expo |
| --- | ---: | ---: | ---: |
| コールドスタート（プロセス開始 → ホーム画面） | 590 ms → 80 ms | 819 ms → 62 ms | 2067 ms → 135 ms |
| 検索画面の表示（初回） | 175 ms → 106 ms | 227 ms → 56 ms | 129 ms → 82 ms |
| 検索画面の表示（2 回目） | 66 ms → 48 ms | 20 ms → 8 ms | 33 ms → 21 ms |
| 検索 → 結果の描画 | 119 ms → 44 ms | 116 ms → 25 ms | 144 ms → 60 ms |
| 検索 → ホーム画面が結果を受信 | 19 ms → 6 ms | 56 ms → 5 ms | 38 ms → 31 ms |
| ホーム画面 → 検索画面へのキーワード差し替え | 22 ms → 27 ms | 21 ms → 13 ms | 19 ms → 18 ms |
| メモリ（PSS、検索後） | 79.6 MB → 33.5 MB | 240.2 MB → 78.7 MB | 231.3 MB → 100.0 MB |
| アプリサイズ | 11.4 MB → 1.2 MB | 143.6 MB → 46.5 MB | 155.3 MB → 73.9 MB |

<!-- bench:results:release:end -->

### リリースビルドの結果の読み方

シミュレータ / エミュレータ上の数値です。実機の絶対値ではなく、同じ環境でのフレームワーク間の差として読んでください。

Android:

- **コールドスタートは 3 実装とも 60〜135 ms で、大きな差はありません。** native 80 ms、Flutter 62 ms、Expo 135 ms。
  埋め込みの比較では Flutter と Expo が起動時にランタイムを初期化するぶん遅くなっていましたが、
  アプリ全体で作った場合はホーム画面を描くまでが起動なので、ランタイムの初期化は「起動に含まれるが、その中で終わる」形になります。
- **画面遷移は、むしろクロスプラットフォームのほうが速いです。** 検索画面の初回表示は native 106 ms に対し Flutter 56 ms、Expo 82 ms。
  2 回目は native 48 ms に対し Flutter 8 ms、Expo 21 ms。
  native の Android は画面ごとに `Activity` を起こしますが、Flutter と Expo は 1 つの Activity の中でルートを積むだけだからです。
  「ネイティブだから速い」とは限らない、分かりやすい例です。
- **検索 → 結果の描画**は Flutter が最も短く（25 ms）、native 44 ms、Expo 60 ms。20 件のリストを描くところは Flutter の描画が速いです。
- **検索 → ホーム画面が結果を受信** は native 6 ms・Flutter 5 ms に対し Expo 31 ms。
  Expo では結果を渡す処理が検索画面の再描画と同じ JS の実行に乗るので、そのぶん遅れて見えていると思われます。
- **メモリ（PSS、検索後）は native 33.5 MB、Flutter 78.7 MB、Expo 100.0 MB** で、native の 2.4〜3 倍です。
  ここは埋め込みのときと同じ傾向で、ランタイムを載せるコストがそのまま出ます。
- **アプリサイズは native 1.2 MB、Flutter 46.5 MB、Expo 73.9 MB。** 複数 ABI を含むユニバーサル APK での比較です。

iOS:

- **Flutter はデバッグ（JIT）の Flutter での値です**（[計測条件](#計測条件)）。コールドスタート・メモリ・アプリサイズは
  リリースより不利に出ており、特にアプリサイズ（約 140 MB）はリリースの目安になりません。
  実機（iPhone XR）のリリース（AOT）では約 15 MB でした（[3. 実機](#3-実機)）。
- **コールドスタートは native 913 ms、Expo 924 ms でほぼ同じ**です。シミュレータがプロセスを起こす時間が大半を占めるので、
  Android より大きく出ます。Flutter（1122 ms）は JIT のぶん 200 ms ほど長くなります。
- **画面遷移は Expo が最も速く**（初回 16 ms、2 回目 16 ms）、Flutter 33 / 27 ms、native 65 / 22 ms。
  native の初回が長いのは、SwiftUI の `NavigationStack` に新しい画面と `List` を作るぶんです。
- **検索 → 結果の描画**は Expo 39 ms、native 62 ms、Flutter 100 ms。JIT の Flutter が不利に出ています。
- **メモリ（RSS、検索後）は native 328.9 MB、Expo 337.1 MB でほぼ同じ**、Flutter は 443.7 MB（JIT のぶん）。
  iOS シミュレータの RSS はシステムフレームワークも含むので、native でも 330 MB ほどになります。

## 3. 実機

[2. リリースビルド](#2-リリースビルド) の傾向が実機でも同じかを、リリースビルドで確かめたものです。
端末は [計測環境](#計測環境) のとおり iPhone XR と Rakuten Hand 5G で、iPhone は実機向けに開発用の証明書で署名したビルド（**Flutter もリリース（AOT）**）、
Android はエミュレータと同じ APK です。各プラットフォームの最後の表は、シミュレータ / エミュレータから実機にしたときの変化です。

<!-- bench:results:release-device:start -->

### iOS：iPhone XR 実機（iOS 18.7）

リリースビルド。5 回の中央値（ウォームアップ 1 回を除く）。

#### 時間

|  | native | Flutter | Expo |
| --- | ---: | ---: | ---: |
| コールドスタート（プロセス開始 → ホーム画面） | 281 ms | 265 ms | 234 ms |
| 検索画面の表示（初回） | 55 ms | 45 ms | 22 ms |
| 検索画面の表示（2 回目） | 39 ms | 30 ms | 13 ms |
| 検索 → 結果の描画 | 208 ms | 118 ms | 126 ms |
| 検索 → ホーム画面が結果を受信 | 176 ms | 73 ms | 101 ms |
| ホーム画面 → 検索画面へのキーワード差し替え | 28 ms | 8 ms | 14 ms |

#### メモリ（RSS）

|  | native | Flutter | Expo |
| --- | ---: | ---: | ---: |
| ホーム画面の表示後 | 87.2 MB | 104.9 MB | 92.6 MB |
| 検索画面の表示後 | 92.4 MB | 107.6 MB | 95.0 MB |
| 検索後 | 101.7 MB | 115.7 MB | 114.3 MB |
| ホーム画面に戻った後 | 102.7 MB | 117.5 MB | 116.0 MB |

#### アプリサイズ

|  | native | Flutter | Expo |
| --- | ---: | ---: | ---: |
| .app（実機向け） | 0.5 MB | 15.3 MB | 28.8 MB |

#### シミュレータ / エミュレータからの変化（シミュレータ・エミュレータ → 実機）

|  | native | Flutter | Expo |
| --- | ---: | ---: | ---: |
| コールドスタート（プロセス開始 → ホーム画面） | 913 ms → 281 ms | 1122 ms → 265 ms | 924 ms → 234 ms |
| 検索画面の表示（初回） | 65 ms → 55 ms | 33 ms → 45 ms | 16 ms → 22 ms |
| 検索画面の表示（2 回目） | 22 ms → 39 ms | 27 ms → 30 ms | 16 ms → 13 ms |
| 検索 → 結果の描画 | 62 ms → 208 ms | 100 ms → 118 ms | 39 ms → 126 ms |
| 検索 → ホーム画面が結果を受信 | 21 ms → 176 ms | 52 ms → 73 ms | 32 ms → 101 ms |
| ホーム画面 → 検索画面へのキーワード差し替え | 8 ms → 28 ms | 10 ms → 8 ms | 16 ms → 14 ms |
| メモリ（RSS、検索後） | 328.9 MB → 101.7 MB | 443.7 MB → 115.7 MB | 337.1 MB → 114.3 MB |
| アプリサイズ | 0.9 MB → 0.5 MB | 139.6 MB → 15.3 MB | 54.9 MB → 28.8 MB |

### Android：Rakuten Hand 5G 実機（Android 11）

リリースビルド。5 回の中央値（ウォームアップ 1 回を除く）。

#### 時間

|  | native | Flutter | Expo |
| --- | ---: | ---: | ---: |
| コールドスタート（プロセス開始 → ホーム画面） | 172 ms | 143 ms | 455 ms |
| 検索画面の表示（初回） | 93 ms | 20 ms | 60 ms |
| 検索画面の表示（2 回目） | 86 ms | 12 ms | 35 ms |
| 検索 → 結果の描画 | 85 ms | 49 ms | 216 ms |
| 検索 → ホーム画面が結果を受信 | 29 ms | 15 ms | 101 ms |
| ホーム画面 → 検索画面へのキーワード差し替え | 22 ms | 9 ms | 24 ms |

#### メモリ（PSS）

|  | native | Flutter | Expo |
| --- | ---: | ---: | ---: |
| ホーム画面の表示後 | 39.1 MB | 79.2 MB | 77.7 MB |
| 検索画面の表示後 | 40.2 MB | 88.1 MB | 89.3 MB |
| 検索後 | 50.7 MB | 91.0 MB | 105.8 MB |
| ホーム画面に戻った後 | 44.3 MB | 91.9 MB | 106.0 MB |

#### アプリサイズ

|  | native | Flutter | Expo |
| --- | ---: | ---: | ---: |
| APK（R8 有効） | 1.2 MB | 46.5 MB | 73.9 MB |

#### シミュレータ / エミュレータからの変化（シミュレータ・エミュレータ → 実機）

|  | native | Flutter | Expo |
| --- | ---: | ---: | ---: |
| コールドスタート（プロセス開始 → ホーム画面） | 80 ms → 172 ms | 62 ms → 143 ms | 135 ms → 455 ms |
| 検索画面の表示（初回） | 106 ms → 93 ms | 56 ms → 20 ms | 82 ms → 60 ms |
| 検索画面の表示（2 回目） | 48 ms → 86 ms | 8 ms → 12 ms | 21 ms → 35 ms |
| 検索 → 結果の描画 | 44 ms → 85 ms | 25 ms → 49 ms | 60 ms → 216 ms |
| 検索 → ホーム画面が結果を受信 | 6 ms → 29 ms | 5 ms → 15 ms | 31 ms → 101 ms |
| ホーム画面 → 検索画面へのキーワード差し替え | 27 ms → 22 ms | 13 ms → 9 ms | 18 ms → 24 ms |
| メモリ（PSS、検索後） | 33.5 MB → 50.7 MB | 78.7 MB → 91.0 MB | 100.0 MB → 105.8 MB |
| アプリサイズ | 1.2 MB → 1.2 MB | 46.5 MB → 46.5 MB | 73.9 MB → 73.9 MB |

<!-- bench:results:release-device:end -->

### 実機の結果の読み方

iOS（iPhone XR、A12 Bionic）:

- **Flutter をリリース（AOT）で計測できた唯一の iOS の結果です。** アプリサイズは 15.3 MB（シミュレータのデバッグ版は約 140 MB）、
  メモリ（検索後）は 115.7 MB で native（101.7 MB）に近づきます。
- **コールドスタートは 3 実装とも 234〜281 ms に収まり、順位を読めるほどの差はありません**
  （native 281 ms、Flutter 265 ms、Expo 234 ms。[計測方法の 1 フレーム](#フレームの後の測り方には1-フレームぶんの差がある)も入ります）。
  埋め込みの比較では Flutter が約 810 ms と突出していましたが、あちらは「ネイティブのホスト画面を出すのと並行して
  Flutter エンジンを起動する」構成で、測っていたものが違います。アプリ全体を Flutter で作った場合、
  エンジンの起動から最初の画面までがひと続きで、ネイティブと同程度に収まりました。
- **画面遷移は Expo が最も速く**（初回 22 ms、2 回目 13 ms）、native（55 / 39 ms）より短いです。Flutter は 45 / 30 ms。
- **検索の 2 つの指標には、iPhone から Mac のモックサーバへの Wi‑Fi の往復が入ります**（Android は USB 経由）。
  native の「検索 → ホーム画面が受信」が 176 ms と長いのもここが大きく、フレームワークの差としては読めません。
- **メモリ（RSS、検索後）は 101.7 / 115.7 / 114.3 MB** と、3 実装の差が 15 MB ほどに収まります。
  シミュレータで見えた Flutter の大きな差は JIT のぶんだったことになります。

Android（Rakuten Hand 5G、Snapdragon 480 5G）:

- **Expo だけ実機で大きく遅くなります。** コールドスタート 455 ms（エミュレータ 135 ms）、
  検索 → 描画 216 ms（同 60 ms）、検索 → ホーム画面が受信 101 ms（同 31 ms）。
  JS の実行とブリッジの往復が、CPU の遅い端末で目立ちます。native（172 / 85 / 29 ms）や Flutter（143 / 49 / 15 ms）との差は
  エミュレータより開きます。
- **Flutter は実機でも native と同程度か、画面遷移では速い**です（初回表示 20 ms / native 93 ms、2 回目 12 ms / native 86 ms）。
  エミュレータと同じく、`Activity` を起こす native より 1 つの Activity の中でルートを積む Flutter が有利です。
- **メモリ（PSS、検索後）は native 50.7 MB、Flutter 91.0 MB、Expo 105.8 MB** で、エミュレータと同じ並びです。
- **コールドスタート**は native 172 ms、Flutter 143 ms、Expo 455 ms。native と Flutter の差は
  [計測方法の 1 フレーム](#フレームの後の測り方には1-フレームぶんの差がある)の範囲です。

## まとめ

- **アプリ全体をクロスプラットフォームで作る場合、起動時間はネイティブとほぼ変わりません。**
  埋め込み（brownfield）では、ネイティブのホスト画面を出すのと並行してランタイムを起動するぶんが丸ごと乗っていましたが、
  最初の画面がフレームワークの画面なら、その初期化は起動の中で終わります。
  例外は Expo のデバッグビルドで、Metro から JS を読むぶん起動が数倍になります。
- **画面遷移は、むしろクロスプラットフォームのほうが速い**ことがあります。とくに Android の native は
  画面ごとに `Activity` を起こすため、1 つの Activity の中でルートを積む Flutter / Expo より遅く出ます。
- **変わらないのはメモリとアプリサイズです。** リリースビルドのメモリは native の 2〜3 倍、
  アプリサイズは Android で 1.2 MB → 46.5 MB（Flutter）/ 73.9 MB（Expo）、iOS 実機で 0.5 MB → 15.3 MB / 28.8 MB。
  ランタイムを載せるコストは、アプリ全体で作っても埋め込んでも同じだけかかります。
- **CPU の遅い実機では Expo（React Native）の JS 実行が効いてきます。** Rakuten Hand 5G では検索 → 描画が
  native の 2.5 倍、検索結果の受け渡しが 3.5 倍でした。Flutter にはこの傾向が出ません。

## 計測をやり直す

手順は [run-benchmark スキル](.claude/skills/run-benchmark/SKILL.md) にまとめています。概略は次のとおりです。

```bash
cd bench
npm ci
npm run mock-server -- --quiet &
./scripts/build.sh <native|flutter|expo> <ios|android>   # 計測用ビルド
node run.mjs --platform ios --framework all --iterations 5
node run.mjs --platform android --framework all --iterations 5
node report.mjs --write
```

デバッグビルドは `./scripts/build.sh <framework> <platform> debug` で作り、Expo 用に Metro を起動してから
`node run.mjs --platform <ios|android> --framework all --build debug` で計測します。
実機は `--physical` を付けて計測します。端末の表示名は `--device-label` で渡せます（[bench/README.md](bench/README.md)）。
