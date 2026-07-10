import Foundation

// MARK: - Dashboard

/// Loosely parsed dashboard statistics. Keys are guessed from common naming;
/// unknown values simply fall back to nil / 0.
struct DashboardStats {
    var raw: JSONValue
    init(_ json: JSONValue) { self.raw = json }

    var movieCount: Int? {
        raw.firstInt(
            "movie_count", "movieCount", "movies_count", "moviesCount",
            "movie_total", "movieTotal", "movies_total", "moviesTotal",
            "movie", "movies", "film_count", "filmCount"
        )
        ?? raw.firstInt(labeled: "电影", "影片", "movie", "movies", "film")
    }

    var tvCount: Int? {
        raw.firstInt(
            "tv_count", "tvCount", "series_count", "seriesCount",
            "show_count", "showCount", "shows_count", "showsCount",
            "tv_total", "series_total", "tv", "series", "shows"
        )
        ?? raw.firstInt(labeled: "剧集", "电视剧", "tv", "series", "shows")
    }

    var episodeCount: Int? {
        raw.firstInt(
            "episode_count", "episodeCount", "episodes_count", "episodesCount",
            "episode_total", "episodeTotal", "episodes_total", "episodesTotal",
            "episode", "episodes", "episode_file_count", "episodeFileCount"
        )
        ?? raw.firstInt(labeled: "剧集集数", "集数", "分集", "episode", "episodes")
    }

    var subscriptionCount: Int? {
        raw.firstInt(
            "subscription_count", "subscriptionCount", "subscriptions_count", "subscriptionsCount",
            "subscription_total", "subscriptionTotal", "subscriptions_total", "subscriptionsTotal",
            "subscription", "subscriptions", "rss_count", "rssCount", "rss_sources", "rssSources",
            "moviepilot_subscriptions", "moviepilotSubscriptions"
        )
        ?? raw.firstInt(labeled: "订阅", "订阅源", "subscription", "subscriptions", "rss")
    }

    /// Generic numeric metrics for a flexible grid, when specific keys are absent.
    var metrics: [(key: String, value: String)] {
        guard let obj = raw.object else { return [] }
        return obj.compactMap { key, value in
            if let i = value.int { return (prettify(key), String(i)) }
            if let d = value.double { return (prettify(key), String(format: "%.1f", d)) }
            if let s = value.string, s.count < 24 { return (prettify(key), s) }
            return nil
        }
        .sorted { $0.0 < $1.0 }
    }

    private func prettify(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

/// Device / host metrics (CPU, memory, disk).
struct DeviceMetrics {
    var raw: JSONValue
    init(_ json: JSONValue) { self.raw = json }

    var cpuPercent: Double? {
        raw.firstDouble(
            "cpu", "cpu_percent", "cpuPercent", "cpu_usage", "cpuUsage",
            "cpu_usage_percent", "cpuUsagePercent", "cpu_used_percent", "cpuUsedPercent",
            "processor", "processor_percent", "processorPercent"
        )
        ?? raw.firstDouble(labeled: "CPU", "processor")
    }

    var memoryPercent: Double? {
        raw.firstDouble(
            "memory", "memory_percent", "memoryPercent", "memory_usage", "memoryUsage",
            "memory_usage_percent", "memoryUsagePercent", "mem_percent", "memPercent",
            "mem_usage", "memUsage", "ram", "ram_percent", "ramPercent"
        )
        ?? raw.firstDouble(labeled: "内存", "memory", "mem", "ram")
    }

    var diskPercent: Double? {
        raw.firstDouble(
            "disk", "disk_percent", "diskPercent", "disk_usage", "diskUsage",
            "disk_usage_percent", "diskUsagePercent", "storage", "storage_percent",
            "storagePercent", "storage_usage", "storageUsage"
        )
        ?? raw.firstDouble(labeled: "磁盘", "硬盘", "disk", "storage")
    }
}

// MARK: - Subscriptions (RSS sources)

struct RssSource: Identifiable, Hashable {
    let id: String
    var name: String
    var rssURL: String
    var mediaType: String
    var subscriptionTarget: String
    var cron: String
    var enabled: Bool
    var raw: JSONValue

    init?(json: JSONValue) {
        guard case .object = json else { return nil }
        raw = json
        id = json.firstString("id", "source_id", "_id") ?? UUID().uuidString
        name = json.firstString("name", "title") ?? "未命名订阅"
        rssURL = json.firstString("rss_url", "url") ?? ""
        mediaType = json.firstString("media_type", "type") ?? "tv"
        subscriptionTarget = json.firstString("subscription_target", "target") ?? "moviepilot"
        cron = json.firstString("cron", "schedule") ?? ""
        enabled = json["enabled"].bool ?? true
    }

    var typeLabel: String { mediaType == "tv" ? "剧集" : "电影" }
}

/// Request body for creating / updating an RSS subscription source.
struct RssSourcePayload: Encodable {
    var name: String
    var rss_url: String
    var media_type: String
    var subscription_target: String
    var cron: String
    var enabled: Bool
}

// MARK: - Tasks

struct TaskItem: Identifiable, Hashable {
    let id: String
    var name: String
    var type: String?
    var enabled: Bool
    var status: String?
    var cron: String?
    var raw: JSONValue

    init?(json: JSONValue) {
        guard case .object = json else { return nil }
        raw = json
        id = json.firstString("id", "task_id", "_id", "name") ?? UUID().uuidString
        name = json.firstString("name", "title", "task_name") ?? "任务"
        type = json.firstString("type", "task_type", "category")
        enabled = json["enabled"].bool ?? json["active"].bool ?? true
        status = json.firstString("status", "state")
        cron = json.firstString("cron", "schedule")
    }
}

// MARK: - Notify

struct NotifyChannel: Identifiable, Hashable {
    let id: String
    var name: String
    var enabled: Bool
    var raw: JSONValue

    init?(json: JSONValue) {
        guard case .object = json else { return nil }
        raw = json
        id = json.firstString("key", "id", "name", "channel") ?? UUID().uuidString
        name = json.firstString("name", "label", "title", "channel_name") ?? id
        enabled = json["enabled"].bool ?? false
    }
}
