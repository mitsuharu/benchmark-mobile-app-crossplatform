# native

ベンチマークの**基準**です。2 つの画面を iOS は SwiftUI、Android は Jetpack Compose だけで書いた、
ふつうのネイティブアプリです。Flutter / Expo との差が「アプリ全体をクロスプラットフォームで作るコスト」になります。

```
native/
├── ios/
│   ├── project.yml          # XcodeGen
│   ├── NativeApp/           # ホーム画面 + 検索画面
│   └── NativeAppTests/
└── android/
    └── app/                 # ホーム画面（MainActivity）と検索画面（RepoSearchActivity）
```

画面遷移は、iOS が `NavigationStack` の push、Android が `startActivity` です。
画面どうしのやり取りは `AppChannel`（プロセス内のイベントバス）を通ります。
値をそのまま渡すだけで、シリアライズも境界の往復もありません。これが他の 2 実装の比較対象になります。

## 他の実装との違い

| | native | Flutter / Expo |
| --- | --- | --- |
| 画面のランタイム | なし（UIKit / Android View の上で直接動く） | Flutter エンジン / React Native（Hermes） |
| 画面どうしの通信 | 同じプロセス内の Swift / Kotlin の値をそのまま渡す | Dart / JavaScript の中で完結（ネイティブ側には出ない） |
| HTTP | `URLSession` / `HttpURLConnection` | `package:http` / `fetch` |
| マーカーの出力 | そのまま `Logger` / `Log.i` | Dart / JS で時刻を取り、ネイティブの薄い層に渡して出す |

## ビルドと実行

### iOS

```bash
cd native/ios
xcodegen generate
open NativeApp.xcodeproj
```

テスト（27 件）:

```bash
xcodebuild test -project NativeApp.xcodeproj -scheme NativeApp \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

### Android

```bash
cd native/android
./gradlew installDebug
./gradlew testDebugUnitTest   # 26 件
```

## 計測用ビルド

API の向き先はビルド時に差し替えます。何も指定しなければ本物の GitHub API を使います。

```bash
# iOS（シミュレータ向け Release）
xcodebuild build -project NativeApp.xcodeproj -scheme NativeApp -configuration Release \
  -sdk iphonesimulator BENCH_API_BASE_URL=http://127.0.0.1:8787

# Android（R8 有効の Release。デバッグ鍵で署名）
./gradlew assembleRelease -PbenchApiBaseUrl=http://127.0.0.1:8787
```

`bench/scripts/build.sh native <ios|android>` が同じことをして、成果物を `bench/artifacts/` に置きます。
