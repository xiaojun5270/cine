import Foundation

/// Tasks group: list, run, stop, toggle and progress.
struct TaskService {
    let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func listTasks() async throws -> [TaskItem] {
        let json = try await client.request(.get, "/api/tasks")
        return json.items("saved_tasks", "savedTasks")
            .compactMap { TaskItem(json: $0) }
    }

    func progress() async throws -> JSONValue {
        try await client.request(.get, "/api/progress")
    }

    struct IDBody: Encodable { let id: String }
    struct ToggleBody: Encodable { let id: String; let enabled: Bool }
    struct RunBody: Encodable { let tasks: [String] }

    func runSavedTask(id: String) async throws {
        _ = try await client.request(.post, "/api/run_saved_task", body: IDBody(id: id))
    }

    func stopTask(id: String) async throws {
        _ = try await client.request(.post, "/api/stop_task", body: IDBody(id: id))
    }

    func toggleTask(id: String, enabled: Bool) async throws {
        _ = try await client.request(.post, "/api/toggle_task", body: ToggleBody(id: id, enabled: enabled))
    }

    func createTask(_ body: JSONValue) async throws -> JSONValue {
        try await client.request(.post, "/api/create_task", body: body)
    }

    func updateTask(_ body: JSONValue) async throws -> JSONValue {
        try await client.request(.post, "/api/update_task", body: body)
    }

    func runTaskBatch(_ body: JSONValue) async throws -> JSONValue {
        try await client.request(.post, "/api/run_task", body: body)
    }

    func deleteTask(id: String) async throws {
        _ = try await client.request(.post, "/api/delete_task", body: IDBody(id: id))
    }

    func clearTaskProgress() async throws {
        _ = try await client.request(.post, "/api/clear_task_progress", body: JSONValue.obj([:]))
    }

    func clearSystemLogs() async throws {
        _ = try await client.request(.post, "/api/clear_system_logs")
    }

    func systemLogs(limit: Int = 200) async throws -> JSONValue {
        try await client.request(.get, "/api/system_logs", query: ["limit": String(limit)])
    }

    func systemLogsStreamURL() throws -> JSONValue {
        guard let url = client.mediaURL("/api/system_logs/stream") else { throw APIError.notConfigured }
        return JSONValue.obj(["url": url.absoluteString])
    }
}
