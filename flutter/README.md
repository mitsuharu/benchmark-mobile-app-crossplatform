# flutter

アプリ全体を Flutter で書いた実装です。1 つのプロジェクトが iOS と Android の両方を作ります。

```
flutter/
├── .fvmrc               # Flutter SDK のバージョン（FVM）
└── app/
    ├── lib/             # ホーム画面と検索画面（Dart）
    ├── test/            # flutter_test
    ├── ios/             # Runner（BenchMarker.swift を足している）
    └── android/         # MainActivity（BenchMarker.kt を足している）
```

画面遷移は `Navigator.push`、画面どうしのやり取りは `AppChannel`（Dart の broadcast ストリーム）です。
どちらも Dart の中で完結していて、ネイティブ側には出ません。

## ネイティブ側に足したもの

計測マーカーだけです。それ以外は `flutter create` のテンプレートのままです。

- `ios/Runner/BenchMarker.swift` と `android/.../BenchMarker.kt`:
  `bench/marker` のメソッドチャンネルを受けて `BENCH|<name>|<epochMs>` をログに出す。
  時刻は Dart 側で取り、ここはログに書くだけです。`processStart`（プロセスの開始時刻）だけは
  Dart から見えないのでネイティブ側で取ります。
- Dart の `print` を使わないのは、リリースビルドでアプリのログに確実には届かないためです
  （計測ランナーは agent-device のアプリログを読みます）。

ほかに、計測のために次を変えています。

- Android: `AndroidManifest.xml` に `INTERNET`（Flutter は debug / profile のマニフェストにしか入れません）と、
  ループバックへの平文通信を許す `network_security_config.xml`
- iOS: `Info.plist` に `NSAllowsLocalNetworking` と `NSLocalNetworkUsageDescription`、画面は縦のみ

`ios/` と `android/` をコミットしているのは、この手書きのコードが入っているからです。

## ビルドと実行

```bash
cd flutter/app
fvm flutter pub get
fvm flutter run

fvm dart format --output=none --set-exit-if-changed lib test
fvm flutter analyze
fvm flutter test
```

## 計測用ビルド

API の向き先は `--dart-define` で差し替えます。何も指定しなければ本物の GitHub API を使います。

```bash
fvm flutter build apk --release --dart-define=BENCH_API_BASE_URL=http://127.0.0.1:8787
fvm flutter build ios --debug --simulator --dart-define=BENCH_API_BASE_URL=http://127.0.0.1:8787
```

`bench/scripts/build.sh flutter <ios|android>` が同じことをして、成果物を `bench/artifacts/` に置きます。

### iOS シミュレータはデバッグ（JIT）だけ

**Flutter はシミュレータ向けのリリース（AOT）ビルドを作れません。** AOT のエンジンのシミュレータ用スライスには
Dart のコードが入らないためです。そのため iOS シミュレータの計測は、リリースの表でも Debug（JIT）の Flutter です。
リリース（AOT）の iOS の値は実機（iPhone XR）の結果を見てください。

実機向けのビルドは `flutter build ios --config-only` で Xcode の設定を作ってから `xcodebuild` を呼びます。
`BENCH_IOS_TEAM_ID` で署名する必要があり、`flutter build ios` にはそれを渡す口がないためです。
