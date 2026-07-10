import Foundation

/// Notify group: channels, types, Telegram / WeChat configuration & tests.
struct NotifyService {
    let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func channels() async throws -> [NotifyChannel] {
        let json = try await client.request(.get, "/api/notify/channels")
        let arr = json.array ?? json["channels"].array ?? json["items"].array ?? json["data"].array ?? []
        return arr.compactMap { NotifyChannel(json: $0) }
    }

    func types() async throws -> JSONValue {
        try await client.request(.get, "/api/notify/types")
    }

    func defaultTemplates() async throws -> JSONValue {
        try await client.request(.get, "/api/notify/default-templates")
    }

    // Telegram
    func telegramStatus() async throws -> JSONValue {
        try await client.request(.get, "/api/telegram-notify/status")
    }
    func telegramConfig() async throws -> JSONValue {
        try await client.request(.get, "/api/telegram-notify/config")
    }
    func telegramTest() async throws {
        _ = try await client.request(.post, "/api/telegram-notify/test")
    }

    // WeChat
    func wechatConfig() async throws -> JSONValue {
        try await client.request(.get, "/api/wechat-notify/config")
    }
    func wechatTest() async throws {
        _ = try await client.request(.post, "/api/wechat-notify/test")
    }
    func saveWechatConfig(_ body: JSONValue) async throws {
        _ = try await client.request(.post, "/api/wechat-notify/config", body: body)
    }
}
