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

## 計測環境

<!-- 計測後に記入 -->

## 計測条件

<!-- 計測後に記入 -->

## 1. デバッグビルド

<!-- bench:results:debug:start -->
<!-- bench:results:debug:end -->

## 2. リリースビルド

<!-- bench:results:release:start -->
<!-- bench:results:release:end -->

## 3. 実機

<!-- bench:results:release-device:start -->
<!-- bench:results:release-device:end -->

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
