import SwiftUI
import WebKit
import AVFoundation

struct ContentView: View {
    @StateObject private var viewModel = MusicViewModel()
    @State private var searchText = ""
    @State private var showingSearch = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 検索バー
                HStack {
                    TextField("YouTube動画を検索", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    Button(action: {
                        viewModel.searchYouTube(query: searchText)
                    }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.blue)
                            .padding(.trailing)
                    }
                }
                .padding(.vertical, 8)
                
                // 再生中の動画情報
                if let currentVideo = viewModel.currentVideo {
                    VStack(spacing: 12) {
                        // サムネイル
                        AsyncImage(url: URL(string: currentVideo.thumbnail)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(height: 200)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 200)
                                    .clipped()
                                    .cornerRadius(12)
                            case .failure:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 200)
                                    .cornerRadius(12)
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .font(.system(size: 50))
                                            .foregroundColor(.gray)
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .shadow(radius: 5)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("再生中")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text(currentVideo.title)
                                .font(.headline)
                                .lineLimit(2)
                            
                            if let channel = currentVideo.channelTitle {
                                Text(channel)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            HStack(spacing: 20) {
                                Button(action: {
                                    viewModel.togglePlayPause()
                                }) {
                                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.blue)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    viewModel.addToPlaylist(currentVideo)
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(16)
                    .shadow(radius: 3)
                    .padding(.horizontal)
                }
                
                // 近接センサーのステータス
                HStack {
                    Circle()
                        .fill(viewModel.isNearEar ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                    
                    Text(viewModel.isNearEar ? "耳に当てています" : "耳から離れています")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 4)
                
                // タブ切り替え
                Picker("表示切替", selection: $showingSearch) {
                    Text("検索結果").tag(true)
                    Text("プレイリスト").tag(false)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // コンテンツエリア
                if showingSearch {
                    // 検索結果リスト
                    if viewModel.searchResults.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("動画を検索してください")
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(viewModel.searchResults) { video in
                            VideoRow(video: video, onPlay: {
                                viewModel.playVideo(video)
                            }, onAddToPlaylist: {
                                viewModel.addToPlaylist(video)
                            })
                        }
                    }
                } else {
                    // プレイリスト
                    if viewModel.playlist.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("プレイリストが空です")
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(viewModel.playlist) { video in
                                VideoRow(video: video, onPlay: {
                                    viewModel.playVideo(video)
                                }, onAddToPlaylist: nil)
                            }
                            .onDelete { indexSet in
                                viewModel.removeFromPlaylist(at: indexSet)
                            }
                        }
                    }
                }
                
                // YouTube Player (非表示)
                YouTubePlayerView(viewModel: viewModel)
                    .frame(width: 1, height: 1)
                    .hidden()
            }
            .navigationTitle("EarPhone Music")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct VideoRow: View {
    let video: YouTubeVideo
    let onPlay: () -> Void
    let onAddToPlaylist: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 12) {
            // サムネイル
            AsyncImage(url: URL(string: video.thumbnail)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 120, height: 68)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 68)
                        .clipped()
                        .cornerRadius(8)
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 120, height: 68)
                        .cornerRadius(8)
                        .overlay(
                            Image(systemName: "play.rectangle")
                                .foregroundColor(.gray)
                        )
                @unknown default:
                    EmptyView()
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.subheadline)
                    .lineLimit(2)
                
                if let channel = video.channelTitle {
                    Text(channel)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Button(action: onPlay) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            
            if let addAction = onAddToPlaylist {
                Button(action: addAction) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 8)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
