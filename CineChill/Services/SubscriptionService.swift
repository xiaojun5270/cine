import Foundation

/// Subscriptions group: RSS source CRUD + sync.
struct SubscriptionService {
    let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func listSources() async throws -> [RssSource] {
        let json = try await client.request(.get, "/api/subscriptions/rss_sources")
        let arr = json.array ?? json["items"].array ?? json["sources"].array ?? json["data"].array ?? []
        return arr.compactMap { RssSource(json: $0) }
    }

    @discardableResult
    func createSource(_ payload: RssSourcePayload) async throws -> JSONValue {
        try await client.request(.post, "/api/subscriptions/rss_sources", body: payload)
    }

    @discardableResult
    func updateSource(id: String, _ payload: RssSourcePayload) async throws -> JSONValue {
        try await client.request(.patch, "/api/subscriptions/rss_sources/\(id)", body: payload)
    }

    func deleteSource(id: String) async throws {
        _ = try await client.request(.delete, "/api/subscriptions/rss_sources/\(id)")
    }

    func syncSource(id: String) async throws {
        _ = try await client.request(.post, "/api/subscriptions/rss_sources/\(id)/sync")
    }

    func activity() async throws -> JSONValue {
        try await client.request(.get, "/api/subscriptions/activity")
    }

    func events() async throws -> JSONValue {
        try await client.request(.get, "/api/subscriptions/events")
    }
}
