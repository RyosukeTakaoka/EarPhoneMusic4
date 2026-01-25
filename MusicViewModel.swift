import SwiftUI
import AVFoundation

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

    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    private var proximityObserver: NSObjectProtocol?

    override init() {
        super.init()
        setupAudioSession()
        setupProximitySensor()
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
            // 耳が近づいたことを検知（表示のみ）
            print("👂 耳が近づきました")
            // 注意: 他のアプリの音楽再生を邪魔しないため、オーディオセッションは変更しません
        } else {
            // 耳から離れたことを検知（表示のみ）
            print("👋 耳から離れました")
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
            print("📌 [7] webBrowserURL に設定完了")
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
            print("📌 [7] webBrowserURL に設定完了: \(url.absoluteString)")
            showWebBrowser = true
            print("🚀 [8] showWebBrowser = true（ブラウザ表示開始）")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━")
        } else {
            print("❌ URL作成失敗: urlStringが無効です")
        }
    }
}
