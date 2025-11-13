import Foundation

struct YouTubeVideo: Identifiable, Codable {
    let id: String
    let title: String
    let channelTitle: String?
    let videoId: String
    let thumbnailURL: String?
    
    var embedURL: String {
        return "https://www.youtube.com/embed/\(videoId)?playsinline=1&enablejsapi=1"
    }
    
    var thumbnail: String {
        return thumbnailURL ?? "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg"
    }
}

struct YouTubeSearchResponse: Codable {
    let items: [YouTubeSearchItem]
}

struct YouTubeSearchItem: Codable {
    let id: YouTubeVideoId
    let snippet: YouTubeSnippet
}

struct YouTubeVideoId: Codable {
    let videoId: String?
}

struct YouTubeSnippet: Codable {
    let title: String
    let channelTitle: String
    let thumbnails: YouTubeThumbnails?
}

struct YouTubeThumbnails: Codable {
    let high: YouTubeThumbnail?
    let medium: YouTubeThumbnail?
    let `default`: YouTubeThumbnail?
}

struct YouTubeThumbnail: Codable {
    let url: String
}
