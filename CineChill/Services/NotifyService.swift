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
    func saveTelegramConfig(_ body: JSONValue) async throws -> JSONValue {
        try await client.request(.post, "/api/telegram-notify/config", body: body)
    }
    func telegramDialogs() async throws -> JSONValue {
        try await client.request(.get, "/api/telegram-notify/dialogs")
    }
    func saveTelegramDialogs(_ body: JSONValue) async throws -> JSONValue {
        try await client.request(.post, "/api/telegram-notify/dialogs", body: body)
    }
    func telegramTest() async throws {
        _ = try await client.request(.post, "/api/telegram-notify/test")
    }
    func telegramSend(message: String) async throws -> JSONValue {
        try await client.request(.post, "/api/telegram-notify/send",
                                 query: ["message": message.isEmpty ? nil : message])
    }
    func telegramSendCode(_ body: JSONValue) async throws -> JSONValue {
        try await client.request(.post, "/api/telegram-notify/send-code", body: body)
    }
    func telegramSignIn(_ body: JSONValue) async throws -> JSONValue {
        try await client.request(.post, "/api/telegram-notify/sign-in", body: body)
    }
    func telegramLogout() async throws -> JSONValue {
        try await client.request(.post, "/api/telegram-notify/logout")
    }
    func telegramAvatarURL(filename: String) throws -> JSONValue {
        guard let url = client.mediaURL("/api/telegram-notify/avatar/\(filename)") else {
            throw APIError.notConfigured
        }
        return JSONValue.obj(["url": url.absoluteString])
    }

    // WeChat
    func wechatConfig() async throws -> JSONValue {
        try await client.request(.get, "/api/wechat-notify/config")
    }
    func wechatTest() async throws {
        _ = try await client.request(.post, "/api/wechat-notify/test")
    }
    func saveWechatConfig(_ body: JSONValue) async throws -> JSONValue {
        try await client.request(.post, "/api/wechat-notify/config", body: body)
    }
    func wechatSend(message: String) async throws -> JSONValue {
        try await client.request(.post, "/api/wechat-notify/send",
                                 query: ["message": message.isEmpty ? nil : message])
    }
    func wechatTypes() async throws -> JSONValue {
        try await client.request(.get, "/api/wechat-notify/types")
    }
    func wechatCallbackVerify(signature: String, timestamp: String, nonce: String, echostr: String) async throws -> JSONValue {
        try await client.request(.get, "/api/wechat-notify/callback",
            query: ["msg_signature": signature, "timestamp": timestamp, "nonce": nonce, "echostr": echostr])
    }
    func wechatCallbackMessage() async throws -> JSONValue {
        try await client.request(.post, "/api/wechat-notify/callback")
    }
}
