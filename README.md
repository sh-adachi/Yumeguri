# ゆめぐり

温泉を探し、「行きたい」と「行った」を残す、iPhone向けの温泉手帖です。iOS 17以降に対応しています。

実装した機能：

- Appleのマップで温泉名・地名を検索し、地図のピンや一覧から詳細を開く。
- 地図を移動して「このエリアの温泉を探す」。現在地ボタンで近くへ移動してから、周辺を検索する。
- 「行きたい」「行った」の保存・変更、訪問日・メモの記録。
- 訪問済みの温泉に「良い・普通・悪い」の個人評価を設定。評価は未選択でも保存可能。
- 保存した記録を名前・住所・メモで絞り込み、訪問済みは評価でも絞り込む。更新順・名前順の切り替え。
- 記録の編集・削除、アプリを終了した後の再読み込み。詳細からAppleのマップや施設のWebサイトを開く。
- 温泉ごとに写真ライブラリから最大10枚を添付。写真のプレビュー・左右スワイプ・削除、保存リストのサムネイル表示。

「行った」を「行きたい」に戻して保存すると、評価と訪問日が消え、メモと写真は残ります。

写真は温泉の詳細画面で「湯めぐりの写真」までスクロールし、追加ボタンから選び、右上の「保存」で確定します。編集を破棄すると、写真の追加・削除も取り消されます。削除するのは記録に添付したコピーだけで、写真ライブラリの元の画像は残ります。

初期表示の10か所は温泉街・ランドマークの代表地点を示すサンプルです。実際の入口や入浴可能な施設を保証するものではありません。個人の訪問履歴・評価は空の状態から始まります。

Xcodeで試すには、次のプロジェクトを開き、Schemeを `Yumeguri`、実行先を `iPhone 17 Pro` などのiPhoneシミュレータにして、Run（⌘R）を押してください。XcodeとiOS SDK・シミュレータランタイムが必要です。

```sh
# cloneしたリポジトリに移動
cd Yumeguri
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

実機向けのTeam IDは、Git管理外の `Config/Signing.local.xcconfig` に設定します。初回のみ次のテンプレートをコピーし、`DEVELOPMENT_TEAM` に自分のTeam IDを入力してください。Xcodeと実機導入スクリプトが自動的に読み込みます。シミュレータではこの設定は不要です。

```sh
cp -n Config/Signing.local.xcconfig.example Config/Signing.local.xcconfig
```

XcodeにApple Accountを登録し、端末との信頼設定と開発者モードを有効にしてください。別の開発者が利用する場合は、必要に応じてBundle Identifierも自身のものに変更します。実機では `CODE_SIGNING_ALLOWED=NO` を指定しません。

ターミナルで再インストールする場合は、`xcrun xctrace list devices` で実機のUDIDを確認して実行します。署名期限が切れた場合も、同じ手順でビルド・インストールし直します。

```sh
bash Scripts/deploy_iphone.sh <iPhoneのUDID>
```

検証用コマンド：

```sh
swift test --scratch-path .build/swift-tests

# 写真テストの準備：対象シミュレータを起動し、テスト用画像を写真ライブラリへ追加
xcrun simctl addmedia booted App/Assets.xcassets/AppIcon.appiconset/AppIcon.png

xcodebuild \
  -project Yumeguri.xcodeproj \
  -scheme Yumeguri \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .build/DerivedData \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Swift Packageのテストはモデル・JSON保存・写真ファイルの保存を対象とします。旧データの互換性、保存失敗時の再試行、編集取り消し、不要ファイルの削除も検証します。UIテストはサンプル地点による保存・全3評価の変更・再起動後の復元・削除に加え、Apple Mapsへの実際の検索と検索結果の保存、システムの写真ピッカーを使った写真の追加・表示・削除を確認します。写真テストには、シミュレータの写真ライブラリに1枚以上の画像が必要です。UIテスト用の保存先は通常の記録と分離しています。通信が必要なテストを除く場合は、xcodebuild に `-skip-testing:YumeguriUITests/YumeguriUITests/testLiveAppleMapsSearchAndSave` を追加します。通信断・位置情報の許可と拒否・実機GPS・iCloud写真のダウンロード中断は手動確認項目です。

実装はSwiftUI、MapKit、CoreLocation、Observation、Foundation、PhotosUI、ImageIO、UIKitなどApple標準のフレームワークで構成しています。外部ライブラリ、APIキー、バックエンドの準備は不要です。Swift 5言語モードで、共有ロジックはSwift Packageとしてもテストできます。

```text
Yumeguri.xcodeproj/       アプリ・UIテストのXcodeプロジェクト
App/
  YumeguriApp.swift       アプリの起動・日本語表示設定
  AppStore.swift          記録の管理と保存エラー処理
  Views/                 探索・保存リスト・詳細画面・共通デザイン
  Services/              Apple Maps検索・現在地取得・写真の読み込みと圧縮
  Info.plist             位置情報の利用目的など
Core/
  OnsenModels.swift      温泉・ステータス・評価・記録
  OnsenIdentity.swift    名前・位置による同一地点の照合
  OnsenCatalog.swift     初期表示用の代表地点
  RecordRepository.swift JSON読み書き・データ検証
  PhotoRepository.swift  写真ファイル・編集用一時ファイルの管理
Tests/OnsenCoreTests/    共有ロジックのテスト
UITests/                iPhone画面を操作するテスト
Package.swift           共有ロジックのSwift Package定義
Scripts/                アイコン生成用スクリプト
```

記録はアプリ専用領域の `Library/Application Support/Yumeguri/records.json` に保存します。JSONはアトミックに書き換え、読み込みに失敗した既存ファイルを空の記録で上書きしない構成です。アプリを削除すると記録も削除されます。

添付写真は同じ領域の `Photos/` にJPEG形式で保存します。システムの写真ピッカーで選択した画像だけを読み込み、長辺最大1600pxに縮小します。画像の向きを適用し、元画像のEXIF・GPSメタデータはコピーしません。Live Photosやアニメーションは静止画として扱います。1枚の入力上限は50MBです。追加途中の画像は `Photos/Drafts/` に置き、写真ファイルの保存後にJSONを更新するため、保存失敗時も再試行できます。既存の写真なしの記録も引き続き読み込めます。

地図・施設検索にはインターネット接続が必要です。Appleの検索結果には温泉街・旅館・関連施設などが含まれ、検索エリアは結果を優先するための指定で、厳密な境界ではありません。最新の営業状況は施設の公式情報で確認してください。

クラウド同期、サーバーへの写真アップロード、アカウント、公開レビュー・他の利用者の評価、記録のエクスポートは未実装です。写真と評価はこの端末の自分の記録に保存します。

実装時に確認したAppleの資料は、[MapKitの自然言語検索と検索エリア](https://developer.apple.com/documentation/mapkit/mklocalsearch/request)、[位置情報の利用許可](https://developer.apple.com/documentation/corelocation/cllocationmanager/requestwheninuseauthorization%28%29)、[一度だけの位置情報取得](https://developer.apple.com/documentation/corelocation/cllocationmanager/requestlocation%28%29)、[Foundationのアトミック書き込み](https://developer.apple.com/documentation/foundation/nsdata/writingoptions/atomic)です。

検証結果（2026年9月5日）：Xcode 26.3、iPhone 17 Proシミュレータ（iOS 26.3.1）で写真対応版のビルド成功。単体テスト28件、既存のUIテスト3件、写真用UIテスト2件が成功しました。写真用テストではシステムピッカーからの取り込み、プレビュー、再起動後の復元、削除、変更の破棄を確認しています。Apple Mapsの実検索テストは前回の実装時に成功済みです。写真対応版では署名付き実機ビルド・インストール・起動を確認しました。実機での写真選択・GPS取得・iCloud写真のダウンロードは手動確認項目です。

画面の記録：[探索](Artifacts/discover.png)、[詳細・評価](Artifacts/detail.png)、[訪問履歴](Artifacts/visited.png)、[実際の検索](Artifacts/live-search.png)。保存済みの画面にあるメモや評価は、通常データとは別の自動テスト用データです。テスト結果は `Artifacts/VerifiedUITests.xcresult` に保存しています。

写真用UIテストの成功結果とスクリーンショットは、ローカルの `Artifacts/PhotoPickerVerification.xcresult` に保存しています。iOS 26のシステムピッカーは表示中の画像でもXCTestに操作不可と報告するため、テストでは検出した画像要素の中央座標をタップしています。

表記違いによる重複保存の確認も追加しました。「草津温泉・湯畑」とApple Mapsの「湯畑」を同じ記録として扱うことを、実通信を使うUIテストで再確認済みです（`Artifacts/IdentityIntegration.xcresult`）。同一地点の照合は、意味のある名前の一致と100m以内の位置を併用します。
