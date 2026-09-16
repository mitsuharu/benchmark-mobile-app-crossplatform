# expo

アプリ全体を Expo（React Native）で書いた実装です。1 つのプロジェクトが iOS と Android の両方を作ります。

```
expo/
└── app/
    ├── App.tsx                  # ナビゲーション（native-stack）
    ├── src/                     # ホーム画面・検索画面・API クライアント・アプリ内チャンネル
    ├── modules/bench-marker/    # 計測マーカーを出すローカル Expo モジュール
    └── plugins/                 # ループバックへの平文通信を許す config plugin
```

画面遷移は `@react-navigation/native-stack`（iOS は `UINavigationController`、Android は
`androidx` の Fragment に載る「本物の」画面遷移）です。画面どうしのやり取りは `AppChannel`
（TypeScript のイベントバス）で、JS の中で完結しています。

ネイティブ側のプロジェクト（`ios/` / `android/`）は `expo prebuild` が作るのでコミットしていません。

## ネイティブ側に足したもの

計測マーカーだけです。

- `modules/bench-marker/`: ローカルの Expo モジュール。`mark(name, epochMs)` と
  `markLaunch(name, epochMs)` を同期の `Function` で公開し、`BENCH|<name>|<epochMs>` を
  `Logger` / `Log.i` に書きます。時刻は JS 側で取り、`processStart`（プロセスの開始時刻）だけは
  JS から見えないのでネイティブ側で取ります。
- `console.log` を使わないのは、リリースビルドでアプリのログに届かないためです
  （計測ランナーは agent-device のアプリログを読みます）。

ほかに、計測のために次を入れています。

- `plugins/withCleartextLoopback.js`: Android のループバック（`127.0.0.1` / `10.0.2.2` / `localhost`）だけに
  平文通信を許す `network_security_config.xml` を書き出し、マニフェストから参照させる config plugin。
  `expo-build-properties` の `usesCleartextTraffic` は全ホストに対して許可してしまうので、
  native / Flutter と同じ条件にするためにこちらを使っています。
- `app.json` の `ios.infoPlist`: `NSAllowsLocalNetworking` と `NSLocalNetworkUsageDescription`

## アプリ名が `ExpoApp` な理由

`app.json` の `name` は Xcode のプロジェクト名（= Swift のモジュール名）になります。
`Expo` にすると、`expo prebuild` が生成する `ExpoModulesProvider.swift` の
`internal import Expo`（Expo の Pod）と衝突し、`cannot find 'ExpoFetchModule' in scope` でビルドが落ちます。

## ビルドと実行

```bash
cd expo/app
npm ci
npm run lint
npm run typecheck
npm test            # 30 件
npm run ios         # expo run:ios
```

## 計測用ビルド

API の向き先は `EXPO_PUBLIC_BENCH_API_BASE_URL` で差し替えます。Metro がバンドル時に値を埋め込むので、
**リリースビルドでは xcodebuild / Gradle を走らせるときの環境変数**、
**デバッグビルドでは Metro を起動するときの環境変数**として渡します。

```bash
EXPO_PUBLIC_BENCH_API_BASE_URL=http://127.0.0.1:8787 npx expo prebuild --platform android --clean
EXPO_PUBLIC_BENCH_API_BASE_URL=http://127.0.0.1:8787 (cd android && ./gradlew assembleRelease)
```

`bench/scripts/build.sh expo <ios|android>` が同じことをして、成果物を `bench/artifacts/` に置きます。
