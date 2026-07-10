import Foundation

/// Discover group: browsing (Douban / TMDB), search and media detail.
struct DiscoverService {
    let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    // MARK: Browsing rows

    /// A named home row backed by a discover endpoint.
    struct Row: Identifiable {
        let id: String
        let title: String
        let path: String
        let defaultType: String
    }

    /// Curated set of home rows using stable, parameter-free endpoints.
    static let homeRows: [Row] = [
        Row(id: "trending", title: "本周趋势", path: "/api/discover/tmdb/trending", defaultType: "movie"),
        Row(id: "hot_movies", title: "豆瓣热门电影", path: "/api/discover/douban/hot_movies", defaultType: "movie"),
        Row(id: "hot_tv", title: "豆瓣热门剧集", path: "/api/discover/douban/hot_tv", defaultType: "tv"),
        Row(id: "showing", title: "正在热映", path: "/api/discover/douban/showing", defaultType: "movie"),
        Row(id: "hot_anime", title: "热门动画", path: "/api/discover/douban/hot_anime", defaultType: "tv"),
        Row(id: "popular_tv", title: "TMDB 热门剧集", path: "/api/discover/tmdb/popular_tv", defaultType: "tv"),
        Row(id: "top250", title: "豆瓣 Top 250", path: "/api/discover/douban/top250", defaultType: "movie")
    ]

    func fetchRow(_ row: Row) async throws -> [MediaItem] {
        let json = try await client.request(.get, row.path)
        return MediaItem.list(from: json, defaultType: row.defaultType)
    }

    func todayPicks() async throws -> [MediaItem] {
        let json = try await client.request(.get, "/api/discover/today_picks")
        return MediaItem.list(from: json)
    }

    // MARK: Search

    func search(query: String, type: String = "movie", page: Int = 1) async throws -> [MediaItem] {
        let json = try await client.request(.get, "/api/discover/search",
            query: ["query": query, "type": type, "page": String(page)])
        return MediaItem.list(from: json, defaultType: type)
    }

    // MARK: Detail

    func detail(tmdbID: Int) async throws -> JSONValue {
        try await client.request(.get, "/api/discover/detail/\(tmdbID)")
    }

    func seasonDetail(tmdbID: Int, season: Int) async throws -> JSONValue {
        try await client.request(.get, "/api/discover/tv/\(tmdbID)/season/\(season)")
    }

    func libraryStatus(tmdbID: Int) async throws -> JSONValue {
        try await client.request(.get, "/api/discover/library/series/\(tmdbID)")
    }

    // MARK: Image URLs

    /// Resolves a poster path to a displayable URL. Full URLs are passed through;
    /// otherwise routed through the TMDB image proxy.
    func imageURL(for path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("http://") || path.hasPrefix("https://") { return URL(string: path) }
        return client.mediaURL("/api/discover/tmdb_img", query: ["url": path, "path": path])
    }

    func posterURL(mediaType: String, tmdbID: Int) -> URL? {
        client.mediaURL("/api/discover/tmdb_poster/\(mediaType)/\(tmdbID)")
    }

    func backdropURL(mediaType: String, tmdbID: Int) -> URL? {
        client.mediaURL("/api/discover/tmdb_backdrop/\(mediaType)/\(tmdbID)")
    }
}
