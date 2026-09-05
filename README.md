# ゆめぐり

温泉を探し、「行きたい」と「行った」を残す、iPhone向けの温泉手帖です。iOS 17以降に対応しています。

実装した機能：

- Appleのマップで温泉名・地名を検索し、地図のピンや一覧から詳細を開く。
- 地図を移動して「このエリアの温泉を探す」。現在地ボタンで近くへ移動してから、周辺を検索する。
- 「行きたい」「行った」の保存・変更、訪問日・メモの記録。
- 訪問済みの温泉に「良い・普通・悪い」の個人評価を設定。評価は未選択でも保存可能。
- 保存した記録を名前・住所・メモで絞り込み、訪問済みは評価でも絞り込む。更新順・名前順の切り替え。
- 記録の編集・削除、アプリを終了した後の再読み込み。詳細からAppleのマップや施設のWebサイトを開く。

「行った」を「行きたい」に戻して保存すると、評価と訪問日が消え、メモは残ります。

初期表示の10か所は温泉街・ランドマークの代表地点を示すサンプルです。実際の入口や入浴可能な施設を保証するものではありません。個人の訪問履歴・評価は空の状態から始まります。

Xcodeで試すには、次のプロジェクトを開き、Schemeを `Yumeguri`、実行先を `iPhone 17 Pro` などのiPhoneシミュレータにして、Run（⌘R）を押してください。XcodeとiOS SDK・シミュレータランタイムが必要です。

```sh
cd /Users/adachi/Developer/Yumeguri
open Yumeguri.xcodeproj
```

ターミナルからビルドする場合：

```sh
xcodebuild \
  -project Yumeguri.xcodeproj \
  -scheme Yumeguri \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

指定したシミュレータがない場合は、Xcodeで追加するか、インストール済みの機種名に置き換えます。位置情報は「現在地」を押したときだけ許可を求めます。シミュレータでは位置情報のシミュレーション設定が必要な場合があります。許可しなくても地名検索を利用できます。

実機のiPhoneでは、XcodeにApple Accountを追加し、アプリターゲットの Signing & Capabilities でTeamと自動署名を設定します。必要に応じてBundle Identifierを自分専用の値に変更し、iPhoneの開発者モードを有効にして実機をRunの実行先に指定してください。シミュレータ用コマンドの `CODE_SIGNING_ALLOWED=NO` は実機の署名設定に使用しません。実機実行の手順は[Appleの公式ドキュメント](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)と[開発者モードの説明](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)を参照してください。App Storeへの申請・公開は行っていません。

検証用コマンド：

```sh
swift test --scratch-path .build/swift-tests

xcodebuild \
  -project Yumeguri.xcodeproj \
  -scheme Yumeguri \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .build/DerivedData \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Swift Packageのテストはモデル・JSON保存を対象とします。UIテストはサンプル地点による保存・全3評価の変更・再起動後の復元・削除に加え、Apple Mapsへの実際の検索と検索結果の保存を確認します。UIテスト用の保存先は通常の記録と分離しています。通信が必要なテストを除く場合は、xcodebuild に `-skip-testing:YumeguriUITests/YumeguriUITests/testLiveAppleMapsSearchAndSave` を追加します。通信断・位置情報の許可と拒否・実機GPSは手動確認項目です。

実装はSwiftUI、MapKit、CoreLocation、Observation、Foundationのみで構成しています。外部ライブラリ、APIキー、バックエンドの準備は不要です。Swift 5言語モードで、共有ロジックはSwift Packageとしてもテストできます。

```text
Yumeguri.xcodeproj/       アプリ・UIテストのXcodeプロジェクト
App/
  YumeguriApp.swift       アプリの起動・日本語表示設定
  AppStore.swift          記録の管理と保存エラー処理
  Views/                 探索・保存リスト・詳細画面・共通デザイン
  Services/              Apple Maps検索・現在地取得
  Info.plist             位置情報の利用目的など
Core/
  OnsenModels.swift      温泉・ステータス・評価・記録
  OnsenIdentity.swift    名前・位置による同一地点の照合
  OnsenCatalog.swift     初期表示用の代表地点
  RecordRepository.swift JSON読み書き・データ検証
Tests/OnsenCoreTests/    共有ロジックのテスト
UITests/                iPhone画面を操作するテスト
Package.swift           共有ロジックのSwift Package定義
Scripts/                アイコン生成用スクリプト
```

記録はアプリ専用領域の `Library/Application Support/Yumeguri/records.json` に保存します。JSONはアトミックに書き換え、読み込みに失敗した既存ファイルを空の記録で上書きしない構成です。アプリを削除すると記録も削除されます。

地図・施設検索にはインターネット接続が必要です。Appleの検索結果には温泉街・旅館・関連施設などが含まれ、検索エリアは結果を優先するための指定で、厳密な境界ではありません。最新の営業状況は施設の公式情報で確認してください。

クラウド同期、アカウント、公開レビュー・他の利用者の評価、写真の保存、記録のエクスポートは未実装です。評価はこの端末の自分の記録にのみ保存します。

実装時に確認したAppleの資料は、[MapKitの自然言語検索と検索エリア](https://developer.apple.com/documentation/mapkit/mklocalsearch/request)、[位置情報の利用許可](https://developer.apple.com/documentation/corelocation/cllocationmanager/requestwheninuseauthorization%28%29)、[一度だけの位置情報取得](https://developer.apple.com/documentation/corelocation/cllocationmanager/requestlocation%28%29)、[Foundationのアトミック書き込み](https://developer.apple.com/documentation/foundation/nsdata/writingoptions/atomic)です。

検証結果（2026年9月5日）：Xcode 26.3、iPhone 17 Proシミュレータ（iOS 26.3.1）でアプリのビルド成功、単体テスト15件・UIテスト4件がすべて成功しました。Apple Mapsの実検索から保存するテストも成功しています。実機のインストールとGPS取得は未検証です。

画面の記録：[探索](Artifacts/discover.png)、[詳細・評価](Artifacts/detail.png)、[訪問履歴](Artifacts/visited.png)、[実際の検索](Artifacts/live-search.png)。保存済みの画面にあるメモや評価は、通常データとは別の自動テスト用データです。テスト結果は `Artifacts/VerifiedUITests.xcresult` に保存しています。

表記違いによる重複保存の確認も追加しました。「草津温泉・湯畑」とApple Mapsの「湯畑」を同じ記録として扱うことを、実通信を使うUIテストで再確認済みです（`Artifacts/IdentityIntegration.xcresult`）。同一地点の照合は、意味のある名前の一致と100m以内の位置を併用します。
