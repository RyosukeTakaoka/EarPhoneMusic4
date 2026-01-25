import SwiftUI
import WebKit
import AVFoundation

struct WebBrowserView: View {
    let url: URL
    let mode: AppMode
    @Environment(\.dismiss) private var dismiss
    @StateObject private var webViewModel = WebViewModel()

    init(url: URL, mode: AppMode) {
        self.url = url
        self.mode = mode
        print("🌐 [9] WebBrowserView 初期化")
        print("📍 初期URL: \(url.absoluteString)")
        print("🎯 モード: \(mode.rawValue)")

        // オーディオセッション変更の通知を監視
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { notification in
            print("🔔 [WebBrowser] オーディオ割り込み通知を受信")
            if let userInfo = notification.userInfo,
               let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
               let type = AVAudioSession.InterruptionType(rawValue: typeValue) {
                switch type {
                case .began:
                    print("   ⚠️ [割り込み開始] オーディオが中断されました")
                case .ended:
                    print("   ✅ [割り込み終了] オーディオ再開可能")
                    if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                        if options.contains(.shouldResume) {
                            print("   ▶️ [自動再開] オーディオを再開すべき")
                        }
                    }
                @unknown default:
                    print("   ❓ [不明な割り込みタイプ]")
                }
            }
        }

        // ルート変更の通知を監視
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { notification in
            print("🔔 [WebBrowser] オーディオルート変更通知を受信")
            if let userInfo = notification.userInfo,
               let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
               let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) {
                print("   📝 変更理由: \(reason.rawValue)")
                switch reason {
                case .newDeviceAvailable:
                    print("   🎧 新しいデバイスが利用可能")
                case .oldDeviceUnavailable:
                    print("   ❌ 古いデバイスが利用不可")
                case .categoryChange:
                    print("   🔄 カテゴリ変更")
                case .override:
                    print("   ⚡ オーバーライド（出力先変更）")
                case .routeConfigurationChange:
                    print("   ⚙️ ルート設定変更")
                default:
                    print("   ❓ その他の理由: \(reason.rawValue)")
                }

                let session = AVAudioSession.sharedInstance()
                print("   📊 現在の出力: \(session.currentRoute.outputs.map { $0.portType.rawValue }.joined(separator: ", "))")
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // URLバー
                HStack {
                    Text(webViewModel.currentURL?.absoluteString ?? url.absoluteString)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .onChange(of: webViewModel.currentURL) { newValue in
                            print("🖥️ [URLバー更新]")
                            print("    表示URL: \(newValue?.absoluteString ?? "nil")")
                            print("    初期URL: \(url.absoluteString)")
                        }

                    if webViewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)

                // WebView
                WebView(
                    url: url,
                    mode: mode,
                    viewModel: webViewModel
                )
                .ignoresSafeArea(edges: .bottom)

                // ナビゲーションツールバー
                HStack(spacing: 30) {
                    Button(action: {
                        webViewModel.goBack()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(webViewModel.canGoBack ? .blue : .gray)
                    }
                    .disabled(!webViewModel.canGoBack)

                    Button(action: {
                        webViewModel.goForward()
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .foregroundColor(webViewModel.canGoForward ? .blue : .gray)
                    }
                    .disabled(!webViewModel.canGoForward)

                    Button(action: {
                        webViewModel.reload()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }

                    Spacer()

                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// WebViewのViewModel
class WebViewModel: ObservableObject {
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var currentURL: URL?

    var webView: WKWebView?

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }

    func reload() {
        webView?.reload()
    }
}

// WKWebViewをSwiftUIで使用するためのラッパー
struct WebView: UIViewRepresentable {
    let url: URL
    let mode: AppMode
    @ObservedObject var viewModel: WebViewModel

    func makeUIView(context: Context) -> WKWebView {
        print("🔧 [10] WKWebView 作成開始")
        let configuration = WKWebViewConfiguration()

        // アプリに飛ばないようにする設定
        configuration.preferences.javaScriptEnabled = true
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // ViewModelにwebViewを設定
        viewModel.webView = webView

        // URLプロパティの変更を監視
        webView.addObserver(context.coordinator, forKeyPath: "URL", options: [.new, .old], context: nil)

        print("✅ [11] WKWebView 作成完了")
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // 初回のみURLをロード
        if webView.url == nil {
            print("🚀 [12] URLリクエスト作成: \(url.absoluteString)")
            let request = URLRequest(url: url)
            print("📤 [13] WKWebView.load() 実行開始")
            webView.load(request)
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.removeObserver(coordinator, forKeyPath: "URL")
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, initialURL: url, mode: mode)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let viewModel: WebViewModel
        let initialURL: URL
        let mode: AppMode

        init(viewModel: WebViewModel, initialURL: URL, mode: AppMode) {
            self.viewModel = viewModel
            self.initialURL = initialURL
            self.mode = mode
        }

        // KVO: URLプロパティの変更を監視
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            if keyPath == "URL" {
                if let webView = object as? WKWebView,
                   let newURL = change?[.newKey] as? URL,
                   let oldURL = change?[.oldKey] as? URL {
                    print("🔔 [URL変更通知 - KVO] モード: \(mode.rawValue)")
                    print("    旧URL: \(oldURL.absoluteString)")
                    print("    新URL: \(newURL.absoluteString)")
                    print("    初期URL: \(initialURL.absoluteString)")

                    if mode == .spotify && newURL.absoluteString != initialURL.absoluteString {
                        print("⚠️ [JavaScriptによるURL変更検出] Spotifyモード")
                        print("🔄 URLが変更されようとしています！")
                    } else if mode == .youtube {
                        print("✅ [YouTube] URL変更を許可")
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("⏳ [14] ページ読み込み開始")
            viewModel.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ [15] ページ読み込み完了")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📊 [URL状態確認] モード: \(mode.rawValue)")
            print("    初期URL: \(initialURL.absoluteString)")
            print("    現在のURL: \(webView.url?.absoluteString ?? "不明")")

            // Spotifyの場合のみ厳格なURL制御
            if mode == .spotify {
                // URLが変わっているかチェック
                if let currentURL = webView.url, currentURL.absoluteString != initialURL.absoluteString {
                    print("⚠️ [URL変更検出] ページが初期URLと異なります！")
                    print("    初期: \(initialURL.absoluteString)")
                    print("    現在: \(currentURL.absoluteString)")
                    print("🔄 [強制リダイレクト] 初期URLに戻します...")

                    // 初期URLに戻す
                    let request = URLRequest(url: initialURL)
                    webView.load(request)
                } else {
                    print("✅ [URL一致] 初期URLのままです")
                }
            } else {
                // YouTubeの場合は自由に遷移可能
                print("✅ [YouTube] URL遷移を許可")
            }

            viewModel.isLoading = false
            viewModel.canGoBack = webView.canGoBack
            viewModel.canGoForward = webView.canGoForward
            viewModel.currentURL = webView.url
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ [ERROR] ページ読み込み失敗: \(error.localizedDescription)")
            viewModel.isLoading = false
        }

        // アプリに飛ばないようにする重要な設定
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                print("🔍 [判定] URL遷移リクエスト (\(mode.rawValue)): \(url.absoluteString)")
                print("📋 スキーム: \(url.scheme ?? "なし")")

                // spotify:// や youtube:// などのカスタムURLスキームをブロック
                if url.scheme == "spotify" || url.scheme == "youtube" || url.scheme == "music" {
                    print("🚫 [ブロック] カスタムURLスキーム検出: \(url.scheme ?? "")")
                    print("⚠️ アプリへの遷移をブロックしました")
                    decisionHandler(.cancel)
                    return
                }

                // aboutスキームは常に許可（ブラウザ内部処理に必要）
                if url.scheme == "about" {
                    print("✅ [許可] ブラウザ内部処理 (about)")
                    decisionHandler(.allow)
                    return
                }

                // HTTP/HTTPSの場合
                if url.scheme == "http" || url.scheme == "https" {
                    if mode == .spotify {
                        // Spotifyモード: 初期URLのみ許可
                        if url.absoluteString == initialURL.absoluteString {
                            print("🎯 [初期URL] このURLは最初に渡されたURLです")
                            print("✅ [許可] 初期URL (Spotifyモード)")
                            decisionHandler(.allow)
                            return
                        } else {
                            print("🔄 [別のURL] 初期URLと異なります")
                            print("   初期URL: \(initialURL.absoluteString)")
                            print("   現在URL: \(url.absoluteString)")
                            print("🚫 [ブロック] Spotifyモード: 初期URL以外への遷移をブロックしました")
                            decisionHandler(.cancel)
                            return
                        }
                    } else {
                        // YouTubeモード: すべてのHTTP/HTTPSを許可
                        print("✅ [許可] HTTP/HTTPS URL (YouTubeモード)")
                        decisionHandler(.allow)
                        return
                    }
                }

                print("🚫 [ブロック] 不明なスキーム: \(url.scheme ?? "なし")")
            }

            decisionHandler(.cancel)
        }
    }
}
