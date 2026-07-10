import Foundation

/// DockerManager group: /api/docker ...
struct DockerService {
    let client = APIClient.shared

    func status() async throws -> JSONValue { try await client.request(.get, "/api/docker/status") }
    func containers() async throws -> [JSONValue] { try await client.request(.get, "/api/docker/containers").items() }
    func images() async throws -> [JSONValue] { try await client.request(.get, "/api/docker/images").items() }

    /// action: "start" | "stop" | "restart" | "remove" | "recreate" ...
    @discardableResult
    func containerAction(id: String, action: String, force: Bool = false, image: String? = nil) async throws -> JSONValue {
        try await client.request(.post, "/api/docker/containers/\(id)/action",
            body: JSONValue.obj(["action": action, "force": force, "image": image]))
    }
    func logs(id: String, tail: Int = 200) async throws -> JSONValue {
        try await client.request(.get, "/api/docker/containers/\(id)/logs", query: ["tail": String(tail)])
    }
    @discardableResult
    func setAutoUpdate(id: String, enabled: Bool, image: String?) async throws -> JSONValue {
        try await client.request(.post, "/api/docker/containers/\(id)/auto_update",
            body: JSONValue.obj(["enabled": enabled, "image": image]))
    }
    func setAutoRestart(id: String, enabled: Bool, mode: String, time: String, memoryLimitMB: Double, memoryDurationMinutes: Int) async throws -> JSONValue {
        try await client.request(.post, "/api/docker/containers/\(id)/auto_restart",
            body: JSONValue.obj(["enabled": enabled, "mode": mode, "time": time,
                                 "memory_limit_mb": memoryLimitMB,
                                 "memory_duration_minutes": memoryDurationMinutes]))
    }
    func setScheduledRestart(id: String, enabled: Bool, mode: String, time: String, memoryLimitMB: Double, memoryDurationMinutes: Int) async throws -> JSONValue {
        try await client.request(.post, "/api/docker/containers/\(id)/scheduled_restart",
            body: JSONValue.obj(["enabled": enabled, "mode": mode, "time": time,
                                 "memory_limit_mb": memoryLimitMB,
                                 "memory_duration_minutes": memoryDurationMinutes]))
    }
    func setIgnoreUpdate(id: String, ignored: Bool) async throws -> JSONValue {
        try await client.request(.post, "/api/docker/containers/\(id)/ignore_update",
            body: JSONValue.obj(["ignored": ignored]))
    }
    func setComposeImage(id: String, image: String) async throws -> JSONValue {
        try await client.request(.post, "/api/docker/containers/\(id)/compose_image",
            body: JSONValue.obj(["image": image]))
    }
    func checkUpdates(images: [String]) async throws -> JSONValue {
        try await client.request(.post, "/api/docker/containers/check_updates",
            body: JSONValue.obj(["images": images]))
    }
    func pullImage(_ image: String) async throws -> JSONValue {
        try await client.request(.post, "/api/docker/images/pull", body: JSONValue.obj(["image": image]))
    }
    func resolveIcon(url: String) async throws -> JSONValue {
        try await client.request(.post, "/api/docker/icons/resolve", body: JSONValue.obj(["url": url]))
    }
    func registryAuth() async throws -> JSONValue { try await client.request(.get, "/api/docker/registry_auth") }
    func saveRegistryAuth(username: String, token: String) async throws -> JSONValue {
        try await client.request(.put, "/api/docker/registry_auth", body: JSONValue.obj(["username": username, "token": token]))
    }
    func deleteRegistryAuth() async throws -> JSONValue { try await client.request(.delete, "/api/docker/registry_auth") }
    func updateTask(runID: String) async throws -> JSONValue {
        try await client.request(.get, "/api/docker/update_tasks/\(runID)")
    }
    func pruneUnused() async throws { _ = try await client.request(.post, "/api/docker/images/prune_unused") }
    func pruneUntagged() async throws { _ = try await client.request(.post, "/api/docker/images/prune_untagged") }
    func deleteImage(id: String, force: Bool = false) async throws {
        _ = try await client.request(.delete, "/api/docker/images/\(id)", query: ["force": String(force)])
    }
}

/// Drive115Upload group.
struct Drive115UploadService {
    let client = APIClient.shared
    func status() async throws -> JSONValue { try await client.request(.get, "/api/drive115_upload/status") }
    func tasks() async throws -> [JSONValue] { try await client.request(.get, "/api/drive115_upload/tasks").items() }
    func taskStatus(id: String) async throws -> JSONValue { try await client.request(.get, "/api/drive115_upload/tasks/\(id)/status") }
    func toggle(id: String, enabled: Bool) async throws {
        _ = try await client.request(.post, "/api/drive115_upload/tasks/\(id)/toggle", body: JSONValue.obj(["enabled": enabled]))
    }
    func scan(id: String) async throws { _ = try await client.request(.post, "/api/drive115_upload/tasks/\(id)/scan", body: JSONValue.obj([:])) }
    func stop(id: String) async throws { _ = try await client.request(.post, "/api/drive115_upload/tasks/\(id)/stop") }
    func retry(id: String, jobID: String?) async throws {
        _ = try await client.request(.post, "/api/drive115_upload/tasks/\(id)/retry", body: JSONValue.obj(["job_id": jobID]))
    }
    func delete(id: String) async throws { _ = try await client.request(.delete, "/api/drive115_upload/tasks/\(id)") }
    func threadSettings() async throws -> JSONValue { try await client.request(.get, "/api/drive115_upload/thread_settings") }
    func browse115(cid: String?) async throws -> JSONValue {
        try await client.request(.post, "/api/drive115_upload/browse115", body: JSONValue.obj(["cid": cid]))
    }
    func clearHistory() async throws { _ = try await client.request(.post, "/api/drive115_upload/history/clear") }
}

/// Drive115Cleanup group.
struct Drive115CleanupService {
    let client = APIClient.shared
    func tasks() async throws -> [JSONValue] { try await client.request(.get, "/api/drive115_cleanup/tasks").items() }
    func run(id: String) async throws { _ = try await client.request(.post, "/api/drive115_cleanup/tasks/\(id)/run") }
    func toggle(id: String, enabled: Bool) async throws {
        _ = try await client.request(.post, "/api/drive115_cleanup/tasks/\(id)/toggle", body: JSONValue.obj(["enabled": enabled]))
    }
    func delete(id: String) async throws { _ = try await client.request(.delete, "/api/drive115_cleanup/tasks/\(id)") }
    func browse115(cid: String?) async throws -> JSONValue {
        try await client.request(.post, "/api/drive115_cleanup/browse115", body: JSONValue.obj(["cid": cid]))
    }
}
