import Foundation

struct SpotifyTrack: Identifiable, Codable {
    let id: String
    let title: String
    let artistName: String?
    let albumName: String?
    let trackId: String
    let thumbnailURL: String?
    let previewURL: String?
    let uri: String
    
    var thumbnail: String {
        return thumbnailURL ?? ""
    }
}

// MARK: - Spotify API Response Models

struct SpotifySearchResponse: Codable {
    let tracks: SpotifyTracksResponse
}

struct SpotifyTracksResponse: Codable {
    let items: [SpotifyTrackItem]
}

struct SpotifyTrackItem: Codable {
    let id: String
    let name: String
    let uri: String
    let preview_url: String?
    let artists: [SpotifyArtist]
    let album: SpotifyAlbum
}

struct SpotifyArtist: Codable {
    let name: String
}

struct SpotifyAlbum: Codable {
    let name: String
    let images: [SpotifyImage]
}

struct SpotifyImage: Codable {
    let url: String
    let height: Int?
    let width: Int?
}

// MARK: - Spotify Auth Response

struct SpotifyAuthResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
}
