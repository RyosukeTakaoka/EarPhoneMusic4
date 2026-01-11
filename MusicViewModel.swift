import SwiftUI
import AVFoundation
import Combine
import MediaPlayer

enum AppMode: String, CaseIterable, Identifiable {
    case spotify = "Spotify"
    case youtube = "YouTube"
    var id: String { self.rawValue }
}

class MusicViewModel: NSObject, ObservableObject {
    @Published var appMode: AppMode = .spotify
    @Published var searchResults: [SpotifyTrack] = []
    @Published var playlist: [SpotifyTrack] = []
    @Published var currentTrack: SpotifyTrack?
    @Published var isPlaying: Bool = false
    @Published var isNearEar: Bool = false
    @Published var showWebBrowser: Bool = false
    @Published var webBrowserURL: URL?

    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    private var proximityObserver: NSObjectProtocol?
    private var audioPlayer: AVPlayer?

    // Spotify Player Interface
    var playerInterface: SpotifyPlayerInterface?
    
    override init() {
        super.init()
        setupAudioSession()
        setupProximitySensor()
        setupRemoteTransportControls()
        loadPlaylist()
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
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            print("✅ オーディオセッション設定完了")
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
            // 耳が近づいたことを検知
            print("👂 耳が近づきました")

            // 【最適化】耳に当てた時：レシーバーから再生
            // 最速でレシーバーモードに切り替えるため、以下を実装：
            // 1. setCategory と overrideOutputAudioPort を連続して呼び出す
            // 2. setActive(true) は1回だけ呼び出す
            // 3. エラーハンドリングを簡略化
            do {
                // .voiceChat モードは通話用に最適化されており、レシーバー出力に最速
                try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [])
                try audioSession.overrideOutputAudioPort(.none) // レシーバーに明示的に切り替え
                try audioSession.setActive(true, options: [])
                print("🎧 レシーバーモード（最速切り替え）")
            } catch {
                print("❌ レシーバーモード切り替えエラー: \(error)")
            }

            if currentTrack != nil && !isPlaying {
                playCurrentTrack()
            }
        } else {
            // 耳から離れたことを検知
            print("👋 耳から離れました")

            // 耳から離した時：通常のスピーカーに戻す
            do {
                try audioSession.setCategory(.playback, mode: .default, options: [])
                try audioSession.setActive(true, options: [])
                print("🔊 スピーカーモード")
            } catch {
                print("❌ スピーカーモード切り替えエラー: \(error)")
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
    
    // MARK: - Playback Control
    
    func playTrack(_ track: SpotifyTrack) {
        currentTrack = track
        
        // 既存の再生を停止
        audioPlayer?.pause()
        
        if let previewURLString = track.previewURL,
           let previewURL = URL(string: previewURLString) {
            
            print("🔊 再生開始: \(track.title)")
            let playerItem = AVPlayerItem(url: previewURL)
            audioPlayer = AVPlayer(playerItem: playerItem)
            
            // SpotifyPlayerView側のCoordinatorをスキップし、ViewModelで直接制御
            if isNearEar {
                playCurrentTrack()
            }
            
            // 再生終了の通知を監視
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(playerDidFinishPlaying),
                name: .AVPlayerItemDidPlayToEndTime,
                object: playerItem
            )
        } else {
            print("⚠️ プレビューURLがありません")
        }
        
        updateNowPlayingInfo()
    }
    
    @objc private func playerDidFinishPlaying() {
        isPlaying = false
        playNextTrack()
    }
    
    func playCurrentTrack() {
        audioPlayer?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    func pauseCurrentTrack() {
        audioPlayer?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    func togglePlayPause() {
        if isPlaying {
            pauseCurrentTrack()
        } else {
            playCurrentTrack()
        }
    }
    
    // MARK: - Playlist Management
    
    func addToPlaylist(_ track: SpotifyTrack) {
        if !playlist.contains(where: { $0.id == track.id }) {
            playlist.append(track)
            savePlaylist()
        }
    }
    
    func removeFromPlaylist(at offsets: IndexSet) {
        playlist.remove(atOffsets: offsets)
        savePlaylist()
    }
    
    private func savePlaylist() {
        if let encoded = try? JSONEncoder().encode(playlist) {
            UserDefaults.standard.set(encoded, forKey: "savedPlaylist")
        }
    }
    
    private func loadPlaylist() {
        if let data = UserDefaults.standard.data(forKey: "savedPlaylist"),
           let decoded = try? JSONDecoder().decode([SpotifyTrack].self, from: data) {
            playlist = decoded
        }
    }
    
    // MARK: - Remote Control & Now Playing
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] event in
            self?.playCurrentTrack()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] event in
            self?.pauseCurrentTrack()
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] event in
            self?.togglePlayPause()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] event in
            self?.playNextTrack()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] event in
            self?.playPreviousTrack()
            return .success
        }
        
        print("✅ メディアコントロール設定完了")
    }
    
    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.artistName ?? "Unknown Artist"
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = track.albumName ?? ""
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        // アルバムアートを設定（オプション）
        if let thumbnailURL = track.thumbnailURL,
           let url = URL(string: thumbnailURL) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    DispatchQueue.main.async {
                        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                        info[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                    }
                }
            }.resume()
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        print("✅ Now Playing更新: \(track.title)")
    }
    
    // MARK: - Playlist Navigation
    
    private func playNextTrack() {
        guard let current = currentTrack,
              let currentIndex = playlist.firstIndex(where: { $0.id == current.id }),
              currentIndex + 1 < playlist.count else {
            return
        }
        
        let nextTrack = playlist[currentIndex + 1]
        playTrack(nextTrack)
    }
    
    private func playPreviousTrack() {
        guard let current = currentTrack,
              let currentIndex = playlist.firstIndex(where: { $0.id == current.id }),
              currentIndex > 0 else {
            return
        }
        
        let previousTrack = playlist[currentIndex - 1]
        playTrack(previousTrack)
    }
}
