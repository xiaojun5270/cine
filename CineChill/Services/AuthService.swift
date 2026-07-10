import Foundation

/// Auth group: /api/login, /api/logout, /api/user_info, /api/change_auth.
struct AuthService {
    let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    struct LoginBody: Encodable { let username: String; let password: String }
    struct ChangeAuthBody: Encodable {
        let old_password: String
        let new_username: String
        let new_password: String
    }

    @discardableResult
    func login(username: String, password: String) async throws -> JSONValue {
        try await client.request(.post, "/api/login", body: LoginBody(username: username, password: password))
    }

    func logout() async throws {
        _ = try await client.request(.post, "/api/logout")
    }

    func userInfo() async throws -> JSONValue {
        try await client.request(.get, "/api/user_info")
    }

    func changeAuth(oldPassword: String, newUsername: String, newPassword: String) async throws {
        _ = try await client.request(.post, "/api/change_auth",
            body: ChangeAuthBody(old_password: oldPassword, new_username: newUsername, new_password: newPassword))
    }

    /// Probes reachability of a freshly-configured server (best effort).
    func ping() async throws {
        _ = try await client.rawData(.get, "/api/user_info")
    }
}
