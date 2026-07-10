import Foundation

/// MoviePilot group.
struct MoviePilotService {
    let client = APIClient.shared
    func config() async throws -> JSONValue { try await client.request(.get, "/api/moviepilot/config") }
    func saveConfig(url: String, username: String, password: String) async throws {
        _ = try await client.request(.post, "/api/moviepilot/config",
            body: JSONValue.obj(["mp_url": url, "mp_username": username, "mp_password": password]))
    }
    func test() async throws -> JSONValue { try await client.request(.post, "/api/moviepilot/test") }
    func subscriptions() async throws -> JSONValue { try await client.request(.get, "/api/moviepilot/subscribe") }
    func checkSubscription(tmdbID: Int, typeName: String, season: Int?) async throws -> JSONValue {
        try await client.request(.get, "/api/moviepilot/subscribe/check",
                                 query: ["tmdbid": String(tmdbID),
                                         "type_name": typeName,
                                         "season": season.map(String.init)])
    }
    func subscribe(tmdbID: Int, typeName: String, season: Int?, name: String?, year: String?) async throws {
        _ = try await client.request(.post, "/api/moviepilot/subscribe",
            body: JSONValue.obj(["tmdbid": tmdbID, "type_name": typeName, "season": season, "name": name, "year": year]))
    }
    func unsubscribe(tmdbID: Int, typeName: String, season: Int?) async throws {
        _ = try await client.request(.delete, "/api/moviepilot/subscribe",
            query: ["tmdbid": String(tmdbID), "type_name": typeName, "season": season.map(String.init)])
    }
}

/// FnosSign group (飞牛论坛签到).
struct FnosSignService {
    let client = APIClient.shared
    func state() async throws -> JSONValue { try await client.request(.get, "/api/fnos_sign/state") }
    func run(force: Bool = false) async throws -> JSONValue {
        try await client.request(.post, "/api/fnos_sign/run", body: JSONValue.obj(["force": force]))
    }
    func saveConfig(enabled: Bool, notify: Bool, cookie: String, cron: String, maxRetries: Int, retryInterval: Int, historyDays: Int) async throws {
        _ = try await client.request(.post, "/api/fnos_sign/config",
            body: JSONValue.obj(["enabled": enabled, "notify": notify, "cookie": cookie, "cron": cron,
                                 "max_retries": maxRetries, "retry_interval": retryInterval, "history_days": historyDays]))
    }
    func testCookie(_ cookie: String) async throws -> JSONValue {
        try await client.request(.post, "/api/fnos_sign/test_cookie", body: JSONValue.obj(["cookie": cookie]))
    }
    func clearHistory() async throws { _ = try await client.request(.delete, "/api/fnos_sign/history") }
}

/// config_302 group (302 直链 / 115 配置).
struct Config302Service {
    let client = APIClient.shared
    func config() async throws -> JSONValue { try await client.request(.get, "/api/config_302/get") }
    func test115(cookie: String) async throws -> JSONValue {
        try await client.request(.post, "/api/config_302/test_115", body: JSONValue.obj(["cookie": cookie]))
    }
    func manualSigninAll() async throws { _ = try await client.request(.post, "/api/config_302/manual_signin_all") }
    func manualCleanup() async throws -> JSONValue {
        try await client.request(.post, "/api/config_302/manual_cleanup", body: JSONValue.obj([:]))
    }
    func ensureStandardDirs(localMediaRoot: String, remoteRootName: String = "影视库") async throws -> JSONValue {
        try await client.request(.post, "/api/config_302/ensure_standard_topology_dirs",
                                 body: JSONValue.obj(["local_media_root": localMediaRoot,
                                                      "remote_root_name": remoteRootName]))
    }
    func qrcodeApps() async throws -> JSONValue { try await client.request(.get, "/api/config_302/115_qrcode/apps") }
    func qrcodeStart(app: String) async throws -> JSONValue {
        try await client.request(.post, "/api/config_302/115_qrcode/start", body: JSONValue.obj(["app": app]))
    }
    func qrcodeResult(uid: String, app: String) async throws -> JSONValue {
        try await client.request(.post, "/api/config_302/115_qrcode/result",
                                 body: JSONValue.obj(["uid": uid, "app": app]))
    }
}

/// ForwardAiying group (资源转发 / 搜索).
struct ForwardService {
    let client = APIClient.shared
    func config() async throws -> JSONValue { try await client.request(.get, "/api/forward/config") }
    func saveConfig(_ body: JSONValue) async throws -> JSONValue {
        try await client.request(.post, "/api/forward/config", body: body)
    }
    func searchSources() async throws -> JSONValue { try await client.request(.get, "/api/forward/search_sources") }
    func searchResources(type: String, tmdbID: Int, title: String?, year: String?, season: Int?, episode: Int?, sources: [String]?) async throws -> JSONValue {
        try await client.request(.post, "/api/forward/search_resources",
            body: JSONValue.obj(["type": type, "tmdb_id": tmdbID, "title": title, "year": year,
                                 "season": season, "episode": episode, "sources": sources]))
    }
    func resources(type: String, tmdbID: Int) async throws -> JSONValue {
        try await client.request(.post, "/api/forward/resources",
                                 body: JSONValue.obj(["type": type, "tmdb_id": tmdbID]))
    }
    func testResources(type: String, tmdbID: Int) async throws -> JSONValue {
        try await client.request(.post, "/api/forward/test_resources", body: JSONValue.obj(["type": type, "tmdb_id": tmdbID]))
    }
    func previewResource(_ body: JSONValue) async throws -> JSONValue {
        try await client.request(.post, "/api/forward/preview_resource", body: body)
    }
    func downloadResource(_ body: JSONValue) async throws -> JSONValue {
        try await client.request(.post, "/api/forward/download_resource", body: body)
    }
    func transferResource(_ body: JSONValue) async throws -> JSONValue {
        try await client.request(.post, "/api/forward/transfer_resource", body: body)
    }
    func refreshToken() async throws -> JSONValue {
        try await client.request(.post, "/api/forward/token/refresh")
    }
}

/// AIEpisodeResolver group.
struct AIResolverService {
    let client = APIClient.shared
    func config() async throws -> JSONValue { try await client.request(.get, "/api/ai-episode-resolver/config") }
    func runtime() async throws -> JSONValue { try await client.request(.get, "/api/ai-episode-resolver/runtime") }
    func audit(limit: Int = 50) async throws -> JSONValue {
        try await client.request(.get, "/api/ai-episode-resolver/audit", query: ["limit": String(limit)])
    }
    func reminders(status: String? = nil, limit: Int = 50) async throws -> JSONValue {
        try await client.request(.get, "/api/ai-episode-resolver/reminders", query: ["status": status, "limit": String(limit)])
    }
    func memory() async throws -> JSONValue { try await client.request(.get, "/api/ai-episode-resolver/memory") }
    func saveConfig(_ body: JSONValue) async throws {
        _ = try await client.request(.post, "/api/ai-episode-resolver/config", body: body)
    }
}

/// Resources group (海报套件 / 模板 / 字体).
struct ResourcesService {
    let client = APIClient.shared
    func suites() async throws -> JSONValue { try await client.request(.get, "/api/list_suites") }
    func templates() async throws -> JSONValue { try await client.request(.get, "/api/templates_v2") }
    func layouts() async throws -> JSONValue { try await client.request(.get, "/api/layouts") }
    func fonts() async throws -> JSONValue { try await client.request(.get, "/api/fonts") }
    func translations() async throws -> JSONValue { try await client.request(.get, "/api/translations") }
    func suiteContent(name: String) async throws -> JSONValue {
        try await client.request(.post, "/api/get_suite_content", body: JSONValue.obj(["suite_name": name]))
    }
    func preview(_ body: JSONValue) async throws -> JSONValue { try await client.request(.post, "/api/preview", body: body) }
    func apply(_ body: JSONValue) async throws -> JSONValue { try await client.request(.post, "/api/apply", body: body) }
    func createSuite(_ body: JSONValue) async throws -> JSONValue { try await client.request(.post, "/api/create_suite", body: body) }
    func restoreSuite(_ body: JSONValue) async throws -> JSONValue { try await client.request(.post, "/api/restore_suite", body: body) }
    func deleteSuite(name: String) async throws -> JSONValue {
        try await client.request(.post, "/api/delete_suite", body: JSONValue.obj(["suite_name": name]))
    }
    func deleteTemplate(name: String) async throws -> JSONValue {
        try await client.request(.post, "/api/delete_template", body: JSONValue.obj(["template_name": name, "name": name]))
    }
    func deleteFont(name: String) async throws -> JSONValue {
        try await client.request(.post, "/api/delete_font", body: JSONValue.obj(["font_name": name, "name": name]))
    }
    func saveTemplate(_ body: JSONValue) async throws -> JSONValue {
        try await client.request(.post, "/api/save_template", body: body)
    }
    func saveTranslations(_ body: JSONValue) async throws -> JSONValue {
        try await client.request(.post, "/api/save_translations", body: body)
    }
}

/// RSS group (原生 RSS 任务 + 内置源).
struct RssService {
    let client = APIClient.shared
    func config() async throws -> JSONValue { try await client.request(.get, "/api/rss/config") }
    func tasks() async throws -> [JSONValue] { try await client.request(.get, "/api/rss/tasks").items() }
    func linkPresets() async throws -> JSONValue { try await client.request(.get, "/api/rss/link_presets") }
    func toggleTask(id: String, enabled: Bool) async throws {
        _ = try await client.request(.post, "/api/rss/toggle_task", body: JSONValue.obj(["id": id, "enabled": enabled]))
    }
    func runNow(_ body: JSONValue = .obj([:])) async throws {
        _ = try await client.request(.post, "/api/rss/run_now", body: body)
    }
    func deleteTask(id: String) async throws {
        _ = try await client.request(.post, "/api/rss/delete_task", body: JSONValue.obj(["id": id]))
    }
    func preview(rssURL: String, contentType: String?, limit: Int = 20) async throws -> JSONValue {
        try await client.request(.post, "/api/rss/preview",
            body: JSONValue.obj(["rss_url": rssURL, "content_type": contentType, "limit": limit]))
    }
}
