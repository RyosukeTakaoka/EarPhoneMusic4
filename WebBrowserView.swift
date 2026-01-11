import SwiftUI
import WebKit

struct WebBrowserView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @StateObject private var webViewModel = WebViewModel()

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
    @ObservedObject var viewModel: WebViewModel

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // アプリに飛ばないようにする設定
        configuration.preferences.javaScriptEnabled = true
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // ViewModelにwebViewを設定
        viewModel.webView = webView

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // 初回のみURLをロード
        if webView.url == nil {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let viewModel: WebViewModel

        init(viewModel: WebViewModel) {
            self.viewModel = viewModel
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            viewModel.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            viewModel.isLoading = false
            viewModel.canGoBack = webView.canGoBack
            viewModel.canGoForward = webView.canGoForward
            viewModel.currentURL = webView.url
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            viewModel.isLoading = false
        }

        // アプリに飛ばないようにする重要な設定
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                // spotify:// や youtube:// などのカスタムURLスキームをブロック
                if url.scheme == "spotify" || url.scheme == "youtube" || url.scheme == "music" {
                    print("⚠️ アプリへの遷移をブロック: \(url.absoluteString)")
                    decisionHandler(.cancel)
                    return
                }

                // HTTP/HTTPSのみ許可
                if url.scheme == "http" || url.scheme == "https" {
                    decisionHandler(.allow)
                    return
                }
            }

            decisionHandler(.cancel)
        }
    }
}
