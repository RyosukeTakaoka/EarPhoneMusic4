import SwiftUI
import AVFoundation
import MediaPlayer

enum AppMode: String, CaseIterable, Identifiable {
    case spotify = "Spotify"
    case youtube = "YouTube"
    var id: String { self.rawValue }
}

class MusicViewModel: NSObject, ObservableObject {
    @Published var appMode: AppMode = .spotify
    @Published var isNearEar: Bool = false
    @Published var showWebBrowser: Bool = false
    @Published var webBrowserURL: URL?
    @Published var webBrowserMode: AppMode = .spotify

    // 動画再生機能
    @Published var currentVideo: YouTubeVideo?
    @Published var isPlaying: Bool = false

    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    private var proximityObserver: NSObjectProtocol?

    var webViewInterface: YouTubePlayerInterface?
    
    override init() {
        super.init()
        setupAudioSession()
        setupProximitySensor()
        setupRemoteTransportControls()
    }
    
    deinit {
        if let observer = proximityObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        UIDevice.current.isProximityMonitoringEnabled = false
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        do {
            // 他のアプリの音楽再生を邪魔しないように設定
            try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            print("✅ オーディオセッション設定完了（他のアプリとミックス可能）")
        } catch {
            print("❌ オーディオセッションの設定に失敗: \(error)")
        }
    }
    
    // MARK: - Proximity Sensor
    
    private func setupProximitySensor() {
        UIDevice.current.isProximityMonitoringEnabled = true
        
        proximityObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.proximityStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isNearEar = UIDevice.current.proximityState
                self.handleProximityChange()
            }
        }
    }
    
    private func handleProximityChange() {
        if isNearEar {
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("👂 [近接センサー] 耳が近づきました")
            print("📊 [状態確認]")
            print("   - WebBrowser表示中: \(showWebBrowser)")
            print("   - 現在のカテゴリ: \(audioSession.category.rawValue)")
            print("   - 現在のモード: \(audioSession.mode.rawValue)")
            print("   - 現在のオプション: \(audioSession.categoryOptions.rawValue)")

            // 【最適化】耳に当てた時：レシーバーから再生
            // YouTubeやSpotifyを止めずにレシーバーモードに切り替え
            do {
                print("🔄 [変更開始] オーディオセッション変更を開始...")

                // STEP 1: カテゴリ変更
                print("   [STEP 1] setCategory(.playAndRecord, mode: .voiceChat, options: [.mixWithOthers, .allowBluetoothA2DP])")
                try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.mixWithOthers, .allowBluetoothA2DP])
                print("   ✅ カテゴリ変更成功")

                // STEP 2: 出力先変更
                print("   [STEP 2] overrideOutputAudioPort(.none) - レシーバーに切り替え")
                try audioSession.overrideOutputAudioPort(.none)
                print("   ✅ 出力先変更成功")

                // STEP 3: アクティブ化
                print("   [STEP 3] setActive(true, options: [.notifyOthersOnDeactivation])")
                try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
                print("   ✅ アクティブ化成功")

                print("📊 [変更後の状態]")
                print("   - カテゴリ: \(audioSession.category.rawValue)")
                print("   - モード: \(audioSession.mode.rawValue)")
                print("   - オプション: \(audioSession.categoryOptions.rawValue)")
                print("   - 出力ルート: \(audioSession.currentRoute.outputs.map { $0.portType.rawValue }.joined(separator: ", "))")

                if showWebBrowser {
                    print("🎧 [完了] レシーバーモード（WebBrowser内の音楽は継続再生）")
                } else {
                    print("🎧 [完了] レシーバーモード（他のアプリの音楽は継続）")
                }

                // 動画が選択されていて、再生中でない場合は再生開始
                if currentVideo != nil && !isPlaying {
                    print("▶️ [動画再生] currentVideoが存在するため再生開始")
                    playCurrentVideo()
                }
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━")
            } catch {
                print("❌ [エラー] レシーバーモード切り替えエラー: \(error)")
                print("   エラー詳細: \(error.localizedDescription)")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━")
            }
        } else {
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("👋 [近接センサー] 耳から離れました")
            print("📊 [状態確認]")
            print("   - WebBrowser表示中: \(showWebBrowser)")
            print("   - 現在のカテゴリ: \(audioSession.category.rawValue)")

            // 耳から離した時：通常のスピーカーに戻す
            do {
                print("🔄 [変更開始] スピーカーモードに戻します...")

                print("   [STEP 1] setCategory(.playback, mode: .default, options: [.mixWithOthers])")
                try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                print("   ✅ カテゴリ変更成功")

                print("   [STEP 2] setActive(true, options: [.notifyOthersOnDeactivation])")
                try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
                print("   ✅ アクティブ化成功")

                print("📊 [変更後の状態]")
                print("   - カテゴリ: \(audioSession.category.rawValue)")
                print("   - モード: \(audioSession.mode.rawValue)")
                print("   - 出力ルート: \(audioSession.currentRoute.outputs.map { $0.portType.rawValue }.joined(separator: ", "))")

                if showWebBrowser {
                    print("🔊 [完了] スピーカーモード（WebBrowser内の音楽は継続再生）")
                } else {
                    print("🔊 [完了] スピーカーモード（他のアプリの音楽は継続）")
                }
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━")
            } catch {
                print("❌ [エラー] スピーカーモード切り替えエラー: \(error)")
                print("   エラー詳細: \(error.localizedDescription)")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━")
            }
        }
    }
    
    // MARK: - Search
    
    func search(query: String) {
        if appMode == .spotify {
            searchSpotify(query: query)
        } else {
            searchYouTube(query: query)
        }
    }
    
    // WebBrowser表示用のYouTube検索
    func searchYouTube(query: String) {
        print("🔍 [2] searchYouTube() 呼び出し")

        guard !query.isEmpty else {
            print("⚠️ 検索テキストが空です")
            return
        }

        print("🔤 [3] URLエンコード前: \(query)")
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        print("🔐 [4] URLエンコード後: \(encodedQuery)")

        let urlString = "https://www.youtube.com/results?search_query=\(encodedQuery)"
        print("🌐 [5] 生成されたURL: \(urlString)")

        if let url = URL(string: urlString) {
            print("✅ [6] URL オブジェクト作成成功")
            webBrowserURL = url
            webBrowserMode = .youtube
            print("📌 [7] webBrowserURL に設定完了（YouTubeモード）")
            showWebBrowser = true
            print("🚀 [8] showWebBrowser = true（ブラウザ表示開始）")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━")
        } else {
            print("❌ URL作成失敗")
        }
    }
    
    func searchSpotify(query: String) {
        print("🔍 [2] searchSpotify() 呼び出し")

        guard !query.isEmpty else {
            print("⚠️ 検索テキストが空です")
            return
        }

        print("🔤 [3] URLエンコード前の生の検索テキスト:")
        print("    テキスト: '\(query)'")
        print("    文字数: \(query.count)")
        print("    文字コード: \(query.utf8.map { String(format: "%02X", $0) }.joined(separator: " "))")

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        print("🔐 [4] URLエンコード後:")
        print("    エンコード結果: '\(encodedQuery)'")
        print("    文字数: \(encodedQuery.count)")

        let urlString = "https://open.spotify.com/search/results/\(encodedQuery)"
        print("🌐 [5] 生成された完全なURL文字列:")
        print("    URL: '\(urlString)'")

        if let url = URL(string: urlString) {
            print("✅ [6] URL オブジェクト作成成功")
            print("    url.absoluteString: '\(url.absoluteString)'")
            print("    url.path: '\(url.path)'")
            print("    url.query: '\(url.query ?? "なし")'")
            webBrowserURL = url
            webBrowserMode = .spotify
            print("📌 [7] webBrowserURL に設定完了（Spotifyモード）: \(url.absoluteString)")
            showWebBrowser = true
            print("🚀 [8] showWebBrowser = true（ブラウザ表示開始）")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━")
        } else {
            print("❌ URL作成失敗: urlStringが無効です")
        }
    }

    // MARK: - Playback Control

    func playVideo(_ video: YouTubeVideo) {
        currentVideo = video
        webViewInterface?.loadVideo(videoId: video.videoId)

        // Now Playing情報を更新
        updateNowPlayingInfo()

        if isNearEar {
            playCurrentVideo()
        }
    }

    func playCurrentVideo() {
        webViewInterface?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    func pauseCurrentVideo() {
        webViewInterface?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }

    func togglePlayPause() {
        if isPlaying {
            pauseCurrentVideo()
        } else {
            playCurrentVideo()
        }
    }


    // MARK: - Remote Control & Now Playing

    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // 再生ボタン
        commandCenter.playCommand.addTarget { [weak self] event in
            self?.playCurrentVideo()
            return .success
        }

        // 一時停止ボタン
        commandCenter.pauseCommand.addTarget { [weak self] event in
            self?.pauseCurrentVideo()
            return .success
        }

        // トグル再生/一時停止
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] event in
            self?.togglePlayPause()
            return .success
        }

        // 次の曲（無効化）
        commandCenter.nextTrackCommand.isEnabled = false

        // 前の曲（無効化）
        commandCenter.previousTrackCommand.isEnabled = false

        print("✅ メディアコントロール設定完了")
    }

    private func updateNowPlayingInfo() {
        guard let video = currentVideo else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = video.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = video.channelTitle ?? "Unknown Artist"
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

        print("✅ Now Playing更新: \(video.title)")
    }

}
