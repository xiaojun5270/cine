import Foundation

// MARK: - Dashboard

/// Loosely parsed dashboard statistics. Keys are guessed from common naming;
/// unknown values simply fall back to nil / 0.
struct DashboardStats {
    var raw: JSONValue
    init(_ json: JSONValue) { self.raw = json }

    var movieCount: Int? { raw["movie_count"].int ?? raw["movies"].int ?? raw["movie"].int }
    var tvCount: Int? { raw["tv_count"].int ?? raw["series_count"].int ?? raw["tv"].int ?? raw["series"].int }
    var episodeCount: Int? { raw["episode_count"].int ?? raw["episodes"].int }
    var subscriptionCount: Int? { raw["subscription_count"].int ?? raw["subscriptions"].int }

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

    var cpuPercent: Double? { raw["cpu"].double ?? raw["cpu_percent"].double ?? raw["cpu_usage"].double }
    var memoryPercent: Double? { raw["memory"].double ?? raw["memory_percent"].double ?? raw["mem_percent"].double
        ?? raw["memory"]["percent"].double }
    var diskPercent: Double? { raw["disk"].double ?? raw["disk_percent"].double ?? raw["disk"]["percent"].double }
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
