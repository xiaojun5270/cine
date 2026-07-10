import Foundation

/// media_organize group.
struct MediaOrganizeService {
    let client = APIClient.shared
    func config() async throws -> JSONValue { try await client.request(.get, "/api/media_organize/get") }
    func defaults() async throws -> JSONValue { try await client.request(.get, "/api/media_organize/defaults") }
    func saveConfig(_ body: JSONValue) async throws -> JSONValue {
        try await client.request(.post, "/api/media_organize/save", body: body)
    }
    func organize(mediaType: String, isBluray: Bool, overwrite: Bool) async throws -> JSONValue {
        try await client.request(.post, "/api/media_organize/organize",
            body: JSONValue.obj(["media_type": mediaType, "is_bluray": isBluray, "overwrite": overwrite]))
    }
    func identifyTest(input: String, folderName: String?, fileName: String?, mediaType: String?) async throws -> JSONValue {
        try await client.request(.post, "/api/media_organize/identify_test",
            body: JSONValue.obj(["input": input, "folder_name": folderName, "file_name": fileName, "media_type": mediaType]))
    }
    func categoryRules() async throws -> JSONValue { try await client.request(.get, "/api/media_organize/category_rules/get") }
    func categoryRuleDefaults() async throws -> JSONValue {
        try await client.request(.get, "/api/media_organize/category_rules/defaults")
    }
    func saveCategoryRules(_ body: JSONValue) async throws -> JSONValue {
        try await client.request(.post, "/api/media_organize/category_rules/save", body: body)
    }
    func saveSubClassify(_ body: JSONValue) async throws -> JSONValue {
        try await client.request(.post, "/api/media_organize/category_rules/sub_classify/save", body: body)
    }
    func refreshEmbyCache() async throws { _ = try await client.request(.post, "/api/media_organize/emby_lib_cache/refresh") }
    func backfillCollections() async throws -> JSONValue {
        try await client.request(.post, "/api/media_organize/collections/backfill")
    }
    func fixLocaleDefaults() async throws -> JSONValue {
        try await client.request(.post, "/api/media_organize/emby_libraries/fix_locale_defaults",
                                 body: JSONValue.obj([:]))
    }
    func syncScrapers(enabled: Bool = false) async throws -> JSONValue {
        try await client.request(.post, "/api/media_organize/emby_libraries/sync_scrapers",
                                 body: JSONValue.obj(["enabled": enabled, "refresh_cache": true]))
    }
    func metadataRepairTVLibraries() async throws -> JSONValue {
        try await client.request(.get, "/api/media_organize/metadata_repair/tv_libraries")
    }
}

/// OrganizeHistory group.
struct OrganizeHistoryService {
    let client = APIClient.shared
    func records(category: String? = nil, keyword: String? = nil, page: Int = 1, pageSize: Int = 30, days: Int? = nil) async throws -> JSONValue {
        try await client.request(.get, "/api/organize-history/records",
            query: ["category": category, "keyword": keyword, "page": String(page),
                    "page_size": String(pageSize), "days": days.map(String.init), "compact": "true"])
    }
    func summary(days: Int = 30, keyword: String? = nil) async throws -> JSONValue {
        try await client.request(.get, "/api/organize-history/summary",
            query: ["days": String(days), "keyword": keyword])
    }
    func mediaSearch(query: String, mediaType: String = "auto", year: String? = nil, limit: Int = 10) async throws -> JSONValue {
        try await client.request(.get, "/api/organize-history/media-search",
            query: ["query": query, "media_type": mediaType, "year": year, "limit": String(limit)])
    }
    func deleteRecords(ids: [String]) async throws {
        _ = try await client.request(.post, "/api/organize-history/records/delete", body: JSONValue.obj(["ids": ids]))
    }
    @discardableResult
    func redo(historyIDs: [String], reason: String?) async throws -> JSONValue {
        try await client.request(.post, "/api/organize-history/records/redo",
            body: JSONValue.obj(["history_ids": historyIDs, "reason": reason]))
    }
    @discardableResult
    func aiRedo(historyIDs: [String], reason: String?) async throws -> JSONValue {
        try await client.request(.post, "/api/organize-history/records/ai-redo",
            body: JSONValue.obj(["history_ids": historyIDs, "reason": reason]))
    }
    @discardableResult
    func redoRecord(id: String, body: JSONValue = .obj([:])) async throws -> JSONValue {
        try await client.request(.post, "/api/organize-history/records/\(id)/redo", body: body)
    }
    @discardableResult
    func aiRedoRecord(id: String, body: JSONValue = .obj([:])) async throws -> JSONValue {
        try await client.request(.post, "/api/organize-history/records/\(id)/ai-redo", body: body)
    }
    func clear(categories: [String]) async throws {
        _ = try await client.request(.post, "/api/organize-history/records/clear", body: JSONValue.obj(["categories": categories]))
    }
    func episodeGroups(tmdbID: String) async throws -> JSONValue {
        try await client.request(.get, "/api/organize-history/tmdb/\(tmdbID)/episode-groups")
    }
}

/// strm group.
struct StrmService {
    let client = APIClient.shared
    func config() async throws -> JSONValue { try await client.request(.get, "/api/strm/get") }
    func progress() async throws -> JSONValue { try await client.request(.get, "/api/strm/progress") }
    func saveConfig(_ body: JSONValue) async throws -> JSONValue {
        try await client.request(.post, "/api/strm/save", body: body)
    }
    func start(taskIndex: Int, mode: String) async throws {
        _ = try await client.request(.post, "/api/strm/start", body: JSONValue.obj(["task_index": taskIndex, "mode": mode]))
    }
    func startMetadata(taskIndex: Int = 0, mode: String = "full") async throws {
        _ = try await client.request(.post, "/api/strm/metadata/start",
                                     body: JSONValue.obj(["task_index": taskIndex, "mode": mode]))
    }
    func stop(runID: String) async throws {
        _ = try await client.request(.post, "/api/strm/stop", body: JSONValue.obj(["run_id": runID]))
    }
}

/// Transfer group.
struct TransferService {
    let client = APIClient.shared
    func history() async throws -> JSONValue { try await client.request(.get, "/api/transfer/history") }
    func clearHistory() async throws { _ = try await client.request(.delete, "/api/transfer/history") }
    func manual(link: String) async throws -> JSONValue {
        try await client.request(.post, "/api/transfer/manual", body: JSONValue.obj(["link": link]))
    }
}

/// SystemHealth group.
struct SystemHealthService {
    let client = APIClient.shared
    func health(targetID: String? = nil) async throws -> JSONValue {
        try await client.request(.get, "/api/system_health", query: ["target_id": targetID])
    }
    func targets() async throws -> JSONValue { try await client.request(.get, "/api/system_health/targets") }
    func network(targetID: String? = nil, full: Bool = false) async throws -> JSONValue {
        try await client.request(.get, "/api/system_health/network", query: ["target_id": targetID, "full": String(full)])
    }
    func lastNetwork() async throws -> JSONValue { try await client.request(.get, "/api/system_health/network/last") }
    func networkTargets(full: Bool = false) async throws -> JSONValue {
        try await client.request(.get, "/api/system_health/network/targets", query: ["full": String(full)])
    }
}

/// Upgrade group.
struct UpgradeService {
    let client = APIClient.shared
    func status() async throws -> JSONValue { try await client.request(.get, "/api/upgrade/status") }
    func check(force: Bool = false) async throws -> JSONValue {
        try await client.request(.post, "/api/upgrade/check", body: JSONValue.obj(["force": force]))
    }
    func start() async throws { _ = try await client.request(.post, "/api/upgrade/start", body: JSONValue.obj([:])) }
}

/// Webhook group.
struct WebhookService {
    let client = APIClient.shared
    func trigger() async throws -> JSONValue { try await client.request(.post, "/api/webhook") }
    func config() async throws -> JSONValue { try await client.request(.get, "/api/webhook/config") }
    func queue() async throws -> JSONValue { try await client.request(.get, "/api/webhook/queue") }
    func saveConfig(_ body: JSONValue) async throws -> JSONValue {
        try await client.request(.post, "/api/webhook/config", body: body)
    }
    func saveConfig(enabled: Bool, engine: String?, preset: String?, mode: String?, deleteSync: Bool) async throws {
        _ = try await client.request(.post, "/api/webhook/config",
            body: JSONValue.obj(["enabled": enabled, "engine": engine, "preset": preset, "mode": mode, "delete_sync_enabled": deleteSync]))
    }
}

/// Misc / public / 未分组.
struct MiscService {
    let client = APIClient.shared
    func version() async throws -> JSONValue { try await client.request(.get, "/api/version") }
    func loginPosters() async throws -> JSONValue { try await client.request(.get, "/api/public/login-posters") }
    func loginPosterURL(itemID: String, tag: String? = nil) throws -> JSONValue {
        guard let url = client.mediaURL("/api/public/login-posters/\(itemID)/poster", query: ["tag": tag]) else {
            throw APIError.notConfigured
        }
        return JSONValue.obj(["url": url.absoluteString])
    }
    func frontendIndexURL() throws -> JSONValue {
        guard let url = client.mediaURL("/index.html") else { throw APIError.notConfigured }
        return JSONValue.obj(["url": url.absoluteString])
    }
    func frontendLoginURL() throws -> JSONValue {
        guard let url = client.mediaURL("/login.html") else { throw APIError.notConfigured }
        return JSONValue.obj(["url": url.absoluteString])
    }
}
