import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var viewModel = MusicViewModel()

    var body: some View {
        TabView {
            // Spotifyページ
            SpotifySearchView(viewModel: viewModel)
                .tag(0)

            // YouTubeページ
            YouTubeSearchView(viewModel: viewModel)
                .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .ignoresSafeArea()
        .sheet(isPresented: $viewModel.showWebBrowser) {
            if let url = viewModel.webBrowserURL {
                WebBrowserView(url: url)
            }
        }
        .onTapGesture {
            // キーボードを閉じる
            hideKeyboard()
        }
    }
}

// MARK: - Spotifyページ（黒背景+緑）
struct SpotifySearchView: View {
    @ObservedObject var viewModel: MusicViewModel
    @State private var searchText = ""

    var body: some View {
        ZStack {
            // Spotify黒背景
            Color(hex: "#191414")
                .ignoresSafeArea()
                .onTapGesture {
                    hideKeyboard()
                }

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)

                // Spotifyロゴ（Assetsから読み込み）
                // Assets.xcassetsに "spotifyIcon" という名前で画像を追加してください
                Group {
                    if let _ = UIImage(named: "spotifyImage") {
                        Image("spotifyImage")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        // フォールバック: SF Symbols
                        Image(systemName: "music.note.list")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(Color(hex: "#1DB954"))
                    }
                }
                .frame(width: 120, height: 120)
                .padding(.bottom, 20)

                Text("Spotify")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(Color(hex: "#1DB954"))
                    .padding(.bottom, 60)

                // 検索バー
                HStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(Color(hex: "#1DB954"))

                    TextField("", text: $searchText, prompt: Text("曲を検索...").foregroundColor(.white.opacity(0.6)))
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .accentColor(Color(hex: "#1DB954"))
                        .onSubmit {
                            viewModel.appMode = .spotify
                            viewModel.search(query: searchText)
                        }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 50)
                        .fill(Color.white.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 50)
                                .stroke(Color(hex: "#1DB954").opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 40)

                Spacer()

                // 近接センサー表示
                ProximityIndicator(isNearEar: viewModel.isNearEar, accentColor: Color(hex: "#1DB954"))
                    .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - YouTubeページ（白背景+赤）
struct YouTubeSearchView: View {
    @ObservedObject var viewModel: MusicViewModel
    @State private var searchText = ""

    var body: some View {
        ZStack {
            // YouTube白背景
            Color.white
                .ignoresSafeArea()
                .onTapGesture {
                    hideKeyboard()
                }

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)

                // YouTubeロゴ（Assetsから読み込み）
                // Assets.xcassetsに "youtubeIcon" という名前で画像を追加してください
                Group {
                    if let _ = UIImage(named: "youtubeImage") {
                        Image("youtubeImage")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        // フォールバック: SF Symbols
                        Image(systemName: "play.rectangle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(Color(hex: "#FF0000"))
                    }
                }
                .frame(width: 120, height: 120)
                .padding(.bottom, 20)

                Text("YouTube")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(Color(hex: "#FF0000"))
                    .padding(.bottom, 60)

                // 検索バー
                HStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(Color(hex: "#FF0000"))

                    TextField("", text: $searchText, prompt: Text("動画を検索...").foregroundColor(.black.opacity(0.4)))
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.black)
                        .accentColor(Color(hex: "#FF0000"))
                        .onSubmit {
                            viewModel.appMode = .youtube
                            viewModel.search(query: searchText)
                        }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 50)
                        .fill(Color.black.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 50)
                                .stroke(Color(hex: "#FF0000").opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 40)

                Spacer()

                // 近接センサー表示
                ProximityIndicator(isNearEar: viewModel.isNearEar, accentColor: Color(hex: "#FF0000"))
                    .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - 近接センサーインジケーター
struct ProximityIndicator: View {
    let isNearEar: Bool
    let accentColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isNearEar ? "ear.fill" : "ear")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(isNearEar ? accentColor : accentColor.opacity(0.3))

            Circle()
                .fill(isNearEar ? accentColor : accentColor.opacity(0.3))
                .frame(width: 12, height: 12)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(accentColor.opacity(0.15))
        )
    }
}

// MARK: - キーボードを閉じる関数
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - カラー拡張（Hex対応）
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
