import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var viewModel = MusicViewModel()
    @State private var searchText = ""
    @State private var showingSearch = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景のモダンなグラデーション
                MeshGradientBackground()
                    .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // モードセレクター
                Picker("モード", selection: $viewModel.appMode) {
                    Label("Spotify", systemImage: "music.note.list").tag(AppMode.spotify)
                    Label("YouTube", systemImage: "play.rectangle.fill").tag(AppMode.youtube)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 8)

                // 検索バー
                HStack {
                    HStack {
                        Image(systemName: viewModel.appMode == .spotify ? "magnifyingglass" : "play.rectangle.fill")
                            .foregroundColor(.secondary)
                        TextField(viewModel.appMode == .spotify ? "Spotifyで楽曲を検索" : "YouTubeで動画を検索", text: $searchText)
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    Button(action: {
                        viewModel.search(query: searchText)
                    }) {
                        Text("検索")
                            .fontWeight(.semibold)
                    }
                    .padding(.trailing)
                }
                .padding(.vertical, 12)

                ScrollView {
                    VStack(spacing: 20) {
                        // 再生中の楽曲情報
                        if let currentTrack = viewModel.currentTrack {
                            VStack(spacing: 16) {
                                // サムネイル（アルバムアート）
                                AsyncImage(url: URL(string: currentTrack.thumbnail)) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(width: 260, height: 260)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 260, height: 260)
                                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                                    case .failure:
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .fill(.ultraThinMaterial)
                                            .frame(width: 260, height: 260)
                                            .overlay(
                                                Image(systemName: "music.note")
                                                    .font(.system(size: 60))
                                                    .foregroundColor(.secondary)
                                            )
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .padding(.top, 10)
                                
                                VStack(spacing: 8) {
                                    Text(currentTrack.title)
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                    
                                    if let artist = currentTrack.artistName {
                                        Text(artist)
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if let album = currentTrack.albumName {
                                        Text(album)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary.opacity(0.8))
                                    }
                                }
                                .padding(.horizontal)
                                
                   // Spotify認証はURL遷移方式に変更されたため、エラー表示を削除
                
                                // コントロール
                                HStack(spacing: 40) {
                                    Button(action: {
                                        viewModel.togglePlayPause()
                                    }) {
                                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                            .symbolRenderingMode(.hierarchical)
                                            .font(.system(size: 72))
                                            .foregroundStyle(.blue)
                                    }
                                    
                                    Button(action: {
                                        viewModel.addToPlaylist(currentTrack)
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                            .symbolRenderingMode(.hierarchical)
                                            .font(.system(size: 44))
                                            .foregroundStyle(.green)
                                    }
                                }
                                .padding(.bottom, 10)
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }
                        
                        // 近接センサーのステータス
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.isNearEar ? "ear.fill" : "ear")
                                .foregroundColor(viewModel.isNearEar ? .green : .secondary)
                            
                            Text(viewModel.isNearEar ? "耳に当てています" : "耳から離れています")
                                .font(.footnote)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        
                        // タブ切り替え
                        Picker("表示切替", selection: $showingSearch) {
                            Text("検索結果").tag(true)
                            Text("プレイリスト").tag(false)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        
                        // コンテンツエリア
                        VStack {
                            if showingSearch {
                                if viewModel.searchResults.isEmpty {
                                    EmptyStateView(icon: "magnifyingglass", message: "楽曲を検索してください")
                                } else {
                                    LazyVStack(spacing: 12) {
                                        ForEach(viewModel.searchResults) { track in
                                            TrackRow(track: track, onPlay: {
                                                viewModel.playTrack(track)
                                            }, onAddToPlaylist: {
                                                viewModel.addToPlaylist(track)
                                            })
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            } else {
                                if viewModel.playlist.isEmpty {
                                    EmptyStateView(icon: "music.note.list", message: "プレイリストが空です")
                                } else {
                                    LazyVStack(spacing: 12) {
                                        ForEach(Array(viewModel.playlist.enumerated()), id: \.element.id) { index, track in
                                            TrackRow(track: track, onPlay: {
                                                viewModel.playTrack(track)
                                            }, onAddToPlaylist: nil, onRemove: {
                                                viewModel.removeFromPlaylist(at: IndexSet(integer: index))
                                            })
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            }
            .navigationTitle("EarPhone Music")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $viewModel.showWebBrowser) {
                if let url = viewModel.webBrowserURL {
                    WebBrowserView(url: url)
                }
            }
        }
    }
}

// AppMode enumはMusicViewModel.swiftで定義されているため、ここでは削除しました。
// デザイン用補助ビュー
struct MeshGradientBackground: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            
            Circle()
                .fill(Color.blue.opacity(0.15))
                .blur(radius: 70)
                .offset(x: -150, y: -200)
            
            Circle()
                .fill(Color.purple.opacity(0.15))
                .blur(radius: 70)
                .offset(x: 150, y: 200)
            
            Circle()
                .fill(Color.green.opacity(0.1))
                .blur(radius: 70)
                .offset(x: 0, y: 0)
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.secondary)
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

struct TrackRow: View {
    let track: SpotifyTrack
    let onPlay: () -> Void
    let onAddToPlaylist: (() -> Void)?
    var onRemove: (() -> Void)? = nil
    
    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 16) {
                // サムネイル（アルバムアート）
                AsyncImage(url: URL(string: track.thumbnail)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 60, height: 60)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    case .failure:
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(.secondary)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if let artist = track.artistName {
                        Text(artist)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if let addAction = onAddToPlaylist {
                    Button(action: addAction) {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .font(.system(size: 28))
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                if let removeAction = onRemove {
                    Button(action: removeAction) {
                        Image(systemName: "minus.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .font(.system(size: 28))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Image(systemName: "play.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
