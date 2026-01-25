import SwiftUI
import WebKit
import AVFoundation

struct YouTubePlayerView: UIViewRepresentable {
    @ObservedObject var viewModel: MusicViewModel

    func makeUIView(context: Context) -> WKWebView {
        // --- WKWebView設定 ---
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = [] // 自動再生を許可
        configuration.allowsPictureInPictureMediaPlayback = false
        configuration.allowsAirPlayForMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.translatesAutoresizingMaskIntoConstraints = false

        // Coordinator に webView と viewModel を渡す（重要）
        context.coordinator.webView = webView
        context.coordinator.viewModel = viewModel
        viewModel.webViewInterface = context.coordinator

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 更新処理があればここに
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate, YouTubePlayerInterface {
        weak var viewModel: MusicViewModel?
        weak var webView: WKWebView?
        private var currentVideoId: String?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            self.webView = webView
            print("✅ WebView読み込み完了")
            // ページロード完了直後に確実に play コマンドを送る
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.callPlaySafely()
            }
        }

        private func callPlaySafely() {
            // 2回試す（確実性向上）
            webView?.evaluateJavaScript("if(window.playVideo) { playVideo(); }") { res, err in
                if let err = err {
                    print("⚠️ evaluateJavaScript playVideo() エラー: \(err)")
                } else {
                    print("▶️ JS playVideo() 実行（1回目）")
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self.webView?.evaluateJavaScript("if(window.playVideo) { playVideo(); }") { res, err in
                    if let err = err {
                        print("⚠️ evaluateJavaScript playVideo() エラー(2): \(err)")
                    } else {
                        print("▶️ JS playVideo() 実行（2回目）")
                    }
                }
            }
        }

        // MARK: - YouTubePlayerInterface
        func loadVideo(videoId: String) {
            currentVideoId = videoId

            let htmlString = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <style>
                    * { margin: 0; padding: 0; }
                    html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
                    #player { width: 100%; height: 100%; }
                </style>
            </head>
            <body>
                <div id="player"></div>
                <script>
                    var tag = document.createElement('script');
                    tag.src = "https://www.youtube.com/iframe_api";
                    var firstScriptTag = document.getElementsByTagName('script')[0];
                    firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

                    var player;
                    function onYouTubeIframeAPIReady() {
                        player = new YT.Player('player', {
                            height: '100%',
                            width: '100%',
                            videoId: '\(videoId)',
                            playerVars: {
                                'playsinline': 1,
                                'controls': 1,
                                'modestbranding': 1,
                                'rel': 0,
                                'autoplay': 1,
                                'mute': 0
                            },
                            events: {
                                'onReady': onPlayerReady,
                                'onStateChange': onPlayerStateChange
                            }
                        });
                    }

                    function onPlayerReady(event) {
                        console.log('Player ready');
                        try {
                            player.setVolume(100);
                            player.unMute();
                            event.target.playVideo();
                        } catch(e) {
                            console.log('onPlayerReady error', e);
                        }
                    }

                    function onPlayerStateChange(event) {
                        if (event.data == YT.PlayerState.PLAYING) {
                            console.log('Playing');
                        } else if (event.data == YT.PlayerState.PAUSED) {
                            console.log('Paused');
                        } else if (event.data == YT.PlayerState.ENDED) {
                            console.log('Ended');
                        }
                    }

                    function playVideo() {
                        try {
                            if (player && player.playVideo) {
                                player.unMute();
                                player.setVolume(100);
                                player.playVideo();
                                console.log('Play command sent');
                            }
                        } catch(e) {
                            console.log('playVideo error', e);
                        }
                    }

                    function pauseVideo() {
                        try {
                            if (player && player.pauseVideo) {
                                player.pauseVideo();
                                console.log('Pause command sent');
                            }
                        } catch(e) {
                            console.log('pauseVideo error', e);
                        }
                    }
                </script>
            </body>
            </html>
            """

            if let wv = webView {
                wv.loadHTMLString(htmlString, baseURL: URL(string: "https://www.youtube.com"))
                print("📺 動画読み込み開始: \(videoId)")
            } else {
                print("⚠️ Coordinator.webView が nil のため load を遅延します: \(videoId)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.loadVideo(videoId: videoId)
                }
            }
        }

        func play() {
            webView?.evaluateJavaScript("playVideo();") { result, error in
                if let error = error {
                    print("❌ 再生エラー: \(error)")
                } else {
                    print("▶️ 再生コマンド送信")
                }
            }
        }

        func pause() {
            webView?.evaluateJavaScript("pauseVideo();") { result, error in
                if let error = error {
                    print("❌ 一時停止エラー: \(error)")
                } else {
                    print("⏸ 一時停止コマンド送信")
                }
            }
        }
    }
}

// YouTube Player とのインターフェース
protocol YouTubePlayerInterface {
    func loadVideo(videoId: String)
    func play()
    func pause()
}
