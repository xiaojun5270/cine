import Foundation

/// EmbyUsers group: /api/emby/users ...
struct EmbyUsersService {
    let client = APIClient.shared

    func list() async throws -> [JSONValue] {
        try await client.request(.get, "/api/emby/users").items()
    }
    func detail(userID: String) async throws -> JSONValue {
        try await client.request(.get, "/api/emby/users/\(userID)")
    }
    func create(name: String, templateUserID: String?, password: String?) async throws {
        _ = try await client.request(.post, "/api/emby/users/create",
            body: JSONValue.obj(["name": name, "template_user_id": templateUserID, "password": password]))
    }
    func delete(userID: String) async throws {
        _ = try await client.request(.delete, "/api/emby/users/\(userID)")
    }
    func setDisabled(userID: String, disabled: Bool) async throws {
        _ = try await client.request(.post, "/api/emby/users/\(userID)/disabled",
            body: JSONValue.obj(["disabled": disabled]))
    }
    func setPassword(userID: String, newPassword: String, currentPassword: String?, reset: Bool) async throws {
        _ = try await client.request(.post, "/api/emby/users/\(userID)/password",
            body: JSONValue.obj(["new_password": newPassword, "current_password": currentPassword, "reset_password": reset]))
    }
    func bind(userID: String) async throws {
        _ = try await client.request(.post, "/api/emby/users/\(userID)/bind")
    }
    func avatarURL(userID: String, tag: String? = nil) -> URL? {
        client.mediaURL("/api/emby/users/\(userID)/avatar", query: ["tag": tag])
    }
}

/// EmbyTasks group: /api/emby_tasks ...
struct EmbyTasksService {
    let client = APIClient.shared
    func list() async throws -> [JSONValue] {
        try await client.request(.get, "/api/emby_tasks").items()
    }
    func run(taskID: String) async throws { _ = try await client.request(.post, "/api/emby_tasks/\(taskID)/run") }
    func stop(taskID: String) async throws { _ = try await client.request(.post, "/api/emby_tasks/\(taskID)/stop") }
    func triggers(taskID: String) async throws -> JSONValue {
        try await client.request(.get, "/api/emby_tasks/\(taskID)/triggers")
    }
    func saveTriggers(taskID: String, triggers: JSONValue) async throws {
        _ = try await client.request(.post, "/api/emby_tasks/\(taskID)/triggers",
            body: JSONValue.obj(["triggers": triggers]))
    }
}
