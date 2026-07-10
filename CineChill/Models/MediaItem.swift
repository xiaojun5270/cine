import Foundation

/// A unified media entry parsed defensively from the various discover
/// endpoints (TMDB / Douban / Emby / search). Field names differ per source,
/// so parsing tries several keys.
struct MediaItem: Identifiable, Hashable {
    let id: String
    var tmdbID: Int?
    var doubanID: String?
    var title: String
    var originalTitle: String?
    var overview: String?
    var posterPath: String?      // may be full URL or a proxy-relative path
    var backdropPath: String?
    var rating: Double?
    var year: String?
    var mediaType: String        // "movie" | "tv"
    var raw: JSONValue

    /// Best-effort construction from a single JSON object.
    init?(json: JSONValue, defaultType: String = "movie") {
        guard case .object = json else { return nil }
        self.raw = json

        let tmdb = json["tmdb_id"].int ?? json["id"].int ?? json["tmdbid"].int
        self.tmdbID = tmdb
        self.doubanID = json.firstString("douban_id", "doubanId")

        let title = json.firstString("title", "name", "cn_name", "original_title") ?? "未知"
        self.title = title
        self.originalTitle = json.firstString("original_title", "original_name")
        self.overview = json.firstString("overview", "summary", "intro", "description")

        self.posterPath = json.firstString("poster_path", "poster", "cover", "cover_url", "img", "image")
        self.backdropPath = json.firstString("backdrop_path", "backdrop", "background")

        self.rating = json["rating"].double ?? json["vote_average"].double ?? json["score"].double
            ?? json["rating"]["value"].double

        self.year = json.firstString("year", "release_date", "first_air_date", "air_date")
            .map { String($0.prefix(4)) }

        let type = json.firstString("media_type", "type") ?? defaultType
        self.mediaType = (type == "tv" || type == "series") ? "tv" : (type == "movie" ? "movie" : type)

        // Stable identity.
        if let tmdb { self.id = "tmdb-\(tmdb)" }
        else if let d = doubanID { self.id = "douban-\(d)" }
        else { self.id = "\(title)-\(self.year ?? "")-\(UUID().uuidString.prefix(8))" }
    }

    var ratingText: String? {
        guard let rating, rating > 0 else { return nil }
        return String(format: "%.1f", rating)
    }

    var typeLabel: String { mediaType == "tv" ? "剧集" : "电影" }
}

extension MediaItem {
    /// Extracts a list of media items from a variety of container shapes:
    /// a bare array, or an object wrapping `items`/`results`/`data`/`list`.
    static func list(from json: JSONValue, defaultType: String = "movie") -> [MediaItem] {
        json.items("subjects", "movies", "tv", "media", "contents")
            .compactMap { MediaItem(json: $0, defaultType: defaultType) }
    }
}
