import SwiftUI
import AVFoundation
import Combine
import MediaPlayer

class MusicViewModel: NSObject, ObservableObject {
    @Published var searchResults: [YouTubeVideo] = []
    @Published var playlist: [YouTubeVideo] = []
    @Published var currentVideo: YouTubeVideo?
    @Published var isPlaying: Bool = false
    @Published var isNearEar: Bool = false
    
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    private var proximityObserver: NSObjectProtocol?
    
    var webViewInterface: YouTubePlayerInterface?
    
    // YouTube Data API Key（実際のAPIキーに置き換える必要があります）
    private let apiKey = "AIzaSyCkOMm0qR8RkN7L6Pq-FFB6t94_fFqi7UU"
    
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
            // シンプルなバックグラウンド再生設定
            try audioSession.setCategory(.playback)
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
            // 耳に当てた時：レシーバーから再生するように設定
            do {
                try audioSession.setCategory(.playAndRecord, mode: .voiceChat)
                try audioSession.setActive(true)
                print("🎧 レシーバーモード")
            } catch {
                print("❌ レシーバーモード切り替えエラー: \(error)")
            }
            
            if currentVideo != nil && !isPlaying {
                playCurrentVideo()
            }
        } else {
            // 耳から離した時：通常のスピーカーに戻す
            do {
                try audioSession.setCategory(.playback)
                try audioSession.setActive(true)
                print("🔊 スピーカーモード")
            } catch {
                print("❌ スピーカーモード切り替えエラー: \(error)")
            }
        }
    }
    // MARK: - YouTube Search
    
    func searchYouTube(query: String) {
        guard !query.isEmpty else { return }
        
        // 実際のYouTube Data API v3を使用する場合
        let urlString = "https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&key=\(apiKey)&maxResults=20"
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                print("検索エラー: \(error?.localizedDescription ?? "不明")")
                // ダミーデータを使用（APIキーがない場合のデモ用）
                DispatchQueue.main.async {
                    self?.loadDummySearchResults(query: query)
                }
                return
            }
            
            do {
                let searchResponse = try JSONDecoder().decode(YouTubeSearchResponse.self, from: data)
                let videos = searchResponse.items.compactMap { item -> YouTubeVideo? in
                    guard let videoId = item.id.videoId else { return nil }
                    let thumbnailURL = item.snippet.thumbnails?.high?.url
                        ?? item.snippet.thumbnails?.medium?.url
                        ?? item.snippet.thumbnails?.default?.url
                    
                    return YouTubeVideo(
                        id: videoId,
                        title: item.snippet.title,
                        channelTitle: item.snippet.channelTitle,
                        videoId: videoId,
                        thumbnailURL: thumbnailURL
                    )
                }
                
                DispatchQueue.main.async {
                    self?.searchResults = videos
                }
            } catch {
                print("デコードエラー: \(error)")
                DispatchQueue.main.async {
                    self?.loadDummySearchResults(query: query)
                }
            }
        }.resume()
    }
    
    // ダミーデータ（APIキーなしでもテストできるように）
    private func loadDummySearchResults(query: String) {
        searchResults = [
            YouTubeVideo(id: "1", title: "検索結果: \(query) - サンプル曲1", channelTitle: "Sample Artist 1", videoId: "dQw4w9WgXcQ", thumbnailURL: nil),
            YouTubeVideo(id: "2", title: "検索結果: \(query) - サンプル曲2", channelTitle: "Sample Artist 2", videoId: "9bZkp7q19f0", thumbnailURL: nil),
            YouTubeVideo(id: "3", title: "検索結果: \(query) - サンプル曲3", channelTitle: "Sample Artist 3", videoId: "kJQP7kiw5Fk", thumbnailURL: nil),
            YouTubeVideo(id: "4", title: "検索結果: \(query) - サンプル曲4", channelTitle: "Sample Artist 4", videoId: "YQHsXMglC9A", thumbnailURL: nil),
        ]
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
    
    // MARK: - Playlist Management
    
    func addToPlaylist(_ video: YouTubeVideo) {
        if !playlist.contains(where: { $0.id == video.id }) {
            playlist.append(video)
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
           let decoded = try? JSONDecoder().decode([YouTubeVideo].self, from: data) {
            playlist = decoded
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
        
        // 次の曲（オプション）
        commandCenter.nextTrackCommand.addTarget { [weak self] event in
            self?.playNextTrack()
            return .success
        }
        
        // 前の曲（オプション）
        commandCenter.previousTrackCommand.addTarget { [weak self] event in
            self?.playPreviousTrack()
            return .success
        }
        
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
    
    // MARK: - Playlist Navigation
    
    private func playNextTrack() {
        guard let current = currentVideo,
              let currentIndex = playlist.firstIndex(where: { $0.id == current.id }),
              currentIndex + 1 < playlist.count else {
            return
        }
        
        let nextVideo = playlist[currentIndex + 1]
        playVideo(nextVideo)
    }
    
    private func playPreviousTrack() {
        guard let current = currentVideo,
              let currentIndex = playlist.firstIndex(where: { $0.id == current.id }),
              currentIndex > 0 else {
            return
        }
        
        let previousVideo = playlist[currentIndex - 1]
        playVideo(previousVideo)
    }
}

// YouTube Player とのインターフェース
protocol YouTubePlayerInterface {
    func loadVideo(videoId: String)
    func play()
    func pause()
}
