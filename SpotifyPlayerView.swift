import SwiftUI
import AVFoundation

// SpotifyPlayerInterface / MusicViewModel は既に定義済みと仮定

struct SpotifyPlayerView: UIViewRepresentable {
    @ObservedObject var viewModel: MusicViewModel

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        // ViewModelにPlayerへのアクセスを提供
        context.coordinator.viewModel = viewModel
        viewModel.playerInterface = context.coordinator
        
        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // 必要に応じて更新処理を追加
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, SpotifyPlayerInterface {
        weak var viewModel: MusicViewModel?
        private var audioPlayer: AVPlayer?
        private var currentTrackId: String?

        // MARK: - SpotifyPlayerInterface
        
        func loadTrack(track: SpotifyTrack) {
            // 現在のViewModelによる直接再生に移行したため、
            // ここでのAVPlayer管理は将来的なSDK導入時のために予約
            print("📺 SpotifyPlayerView: トラック読み込み通知 - \(track.title)")
        }

        func play() {
            viewModel?.playCurrentTrack()
        }

        func pause() {
            viewModel?.pauseCurrentTrack()
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

// Spotify Player とのインターフェース
protocol SpotifyPlayerInterface {
    func loadTrack(track: SpotifyTrack)
    func play()
    func pause()
}
