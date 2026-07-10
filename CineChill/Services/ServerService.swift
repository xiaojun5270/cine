import Foundation

/// Server group: dashboard stats, device metrics, Emby overview, 115 account,
/// config load/save and restart.
struct ServerService {
    let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func dashboardStats() async throws -> DashboardStats {
        DashboardStats(try await client.request(.get, "/api/dashboard_stats"))
    }

    func deviceMetrics() async throws -> DeviceMetrics {
        DeviceMetrics(try await client.request(.get, "/api/dashboard_device_metrics"))
    }

    func account115() async throws -> JSONValue {
        try await client.request(.get, "/api/dashboard_115_account")
    }

    struct EmptyBody: Encodable {}

    func embyOverview() async throws -> JSONValue {
        try await client.request(.post, "/api/dashboard_emby_overview", body: EmptyBody())
    }

    func loadConfig() async throws -> JSONValue {
        try await client.request(.get, "/api/load")
    }

    func saveConfig(_ body: JSONValue) async throws -> JSONValue {
        try await client.request(.post, "/api/save", body: body)
    }

    func connect(_ body: JSONValue) async throws -> JSONValue {
        try await client.request(.post, "/api/connect", body: body)
    }

    func embyGetImages(_ body: JSONValue) async throws -> JSONValue {
        try await client.request(.post, "/api/emby/get_images", body: body)
    }

    func embyRandomPool(_ body: JSONValue) async throws -> JSONValue {
        try await client.request(.post, "/api/emby/random_pool", body: body)
    }

    func embySearch(_ body: JSONValue) async throws -> JSONValue {
        try await client.request(.post, "/api/emby/search", body: body)
    }

    func libraryCovers(_ body: JSONValue) async throws -> JSONValue {
        try await client.request(.post, "/api/library_covers", body: body)
    }

    func proxyTest(_ body: JSONValue) async throws -> JSONValue {
        try await client.request(.post, "/api/proxy/test", body: body)
    }

    func restart() async throws {
        _ = try await client.request(.post, "/api/server/restart")
    }
}
