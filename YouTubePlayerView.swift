import SwiftUI
import WebKit
import AVFoundation

// YouTubePlayerInterface / MusicViewModel は既に定義済みと仮定

struct YouTubePlayerView: UIViewRepresentable {
    @ObservedObject var viewModel: MusicViewModel

    func makeUIView(context: Context) -> WKWebView {
        // --- AVAudioSession設定（冗長でもここで確実に） ---
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try session.setActive(true)
            print("✅ AVAudioSession 設定完了")
        } catch {
            print("⚠️ AVAudioSession設定エラー: \(error)")
        }

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
        // もし ViewModel 側から videoId 指定で再生するならここで検知して loadVideo 呼ぶ等
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
            // ページロード完了直後に確実に play コマンドを送る（タイミング対策）
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
                    /* 小さな透明のボタンを用意しておく手法（ユーザー操作を模す） */
                    #autoplaybtn{ position:absolute; left:0; top:0; width:1px; height:1px; opacity:0; pointer-events:none; }
                </style>
            </head>
            <body>
                <div id="player"></div>
                <button id="autoplaybtn" onclick="tryAutoplay();"></button>
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
                                'controls': 0,
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

                    // fallback: 外部からの programmatic click を受けるための関数
                    function tryAutoplay() {
                        try {
                            playVideo();
                        } catch(e) {
                            console.log('tryAutoplay error', e);
                        }
                    }

                    // iOS向けのタイミング対策に備え、ページロード後すぐに tryAutoplay を2回呼ぶ
                    setTimeout(function(){ tryAutoplay(); }, 200);
                    setTimeout(function(){ tryAutoplay(); }, 700);
                </script>
            </body>
            </html>
            """

            // webView を確実に使う（makeUIView で coordinator.webView をセットしている）
            if let wv = webView {
                wv.loadHTMLString(htmlString, baseURL: URL(string: "https://www.youtube.com"))
                print("📺 動画読み込み開始: \(videoId)")
            } else {
                // webView が nil の場合はログを出して待機（通常は makeUIView でセット済み）
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
