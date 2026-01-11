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
    
    private func searchYouTube(query: String) {
        guard !query.isEmpty else { return }
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://www.youtube.com/results?search_query=\(encodedQuery)"

        if let url = URL(string: urlString) {
            webBrowserURL = url
            showWebBrowser = true
        }
    }

    func searchSpotify(query: String) {
        guard !query.isEmpty else { return }
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://open.spotify.com/search/\(encodedQuery)"

        if let url = URL(string: urlString) {
            webBrowserURL = url
            showWebBrowser = true
        }
    }
}
