# EarPhone Music

YouTubeの音楽を電話のように耳に当てて聴けるiOSアプリ

## 機能

- 📱 **近接センサー対応**: iPhoneを耳に当てると自動的にレシーバー（通話用スピーカー）から音楽が流れます
- 🔍 **YouTube検索**: キーワードで動画を検索
- 📝 **プレイリスト**: お気に入りの動画を保存
- ▶️ **再生コントロール**: 再生/一時停止の基本操作

## Xcodeでのセットアップ手順

### 1. 新規プロジェクト作成
1. Xcodeを開く
2. "Create a new Xcode project"を選択
3. "iOS" → "App"を選択
4. 以下の設定で作成:
   - Product Name: `EarPhoneMusic`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - Storage: `None`

### 2. ファイルの追加
以下のファイルをプロジェクトに追加してください:

- `EarPhoneMusicApp.swift` (既存のApp.swiftを置き換え)
- `ContentView.swift` (既存のContentView.swiftを置き換え)
- `MusicViewModel.swift`
- `YouTubeVideo.swift`
- `YouTubePlayerView.swift`

### 3. Info.plistの設定
Info.plistに以下を追加:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>

<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

### 4. YouTube Data API キーの取得（オプション）

本格的に使用する場合は、YouTube Data API v3のキーが必要です:

1. [Google Cloud Console](https://console.cloud.google.com/)にアクセス
2. 新しいプロジェクトを作成
3. "YouTube Data API v3"を有効化
4. 認証情報からAPIキーを作成
5. `MusicViewModel.swift`の`apiKey`変数に設定:
   ```swift
   private let apiKey = "YOUR_ACTUAL_API_KEY"
   ```

**注意**: APIキーなしでも動作しますが、ダミーデータが表示されます。

### 5. ビルドと実行

1. 実機を接続（シミュレーターでは近接センサーが動作しません）
2. Signing & Capabilitiesで開発チームを選択
3. ビルドして実行 (⌘+R)

## 使い方

1. **検索**: 上部の検索バーにキーワードを入力して検索ボタンをタップ
2. **再生**: 検索結果の再生ボタンをタップ
3. **耳に当てる**: iPhoneを耳に当てると自動的に再生開始
4. **プレイリスト追加**: ＋ボタンでプレイリストに追加
5. **プレイリスト表示**: 下部のセグメントコントロールで切り替え

## 技術仕様

- **近接センサー**: `UIDevice.proximityMonitoringEnabled`
- **オーディオセッション**: `AVAudioSession`を`playAndRecord`モードで使用
- **YouTube再生**: WebViewでYouTube Embed APIを使用
- **データ永続化**: UserDefaultsでプレイリストを保存

## 注意事項

- 実機でのみ動作します（シミュレーターは近接センサー非対応）
- バックグラウンド再生には追加の設定が必要です
- YouTubeの利用規約を遵守してください
- App Storeで公開する場合は、YouTubeの公式APIを使用してください

## トラブルシューティング

### 音が出ない
- 音量を確認
- マナーモードを解除
- オーディオセッションの設定を確認

### 近接センサーが反応しない
- 実機で実行していることを確認
- センサー部分（画面上部）に物を近づける
- 画面保護フィルムがセンサーを塞いでいないか確認

### 検索結果が表示されない
- APIキーが正しく設定されているか確認
- インターネット接続を確認
- APIキーなしの場合はダミーデータが表示されます

## ライセンス

個人利用・学習目的でご使用ください。
