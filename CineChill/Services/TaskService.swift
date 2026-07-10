import Foundation

/// Tasks group: list, run, stop, toggle and progress.
struct TaskService {
    let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func listTasks() async throws -> [TaskItem] {
        let json = try await client.request(.get, "/api/tasks")
        let arr = json.array ?? json["tasks"].array ?? json["items"].array ?? json["data"].array ?? []
        return arr.compactMap { TaskItem(json: $0) }
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

    func deleteTask(id: String) async throws {
        _ = try await client.request(.post, "/api/delete_task", body: IDBody(id: id))
    }

    func systemLogs(limit: Int = 200) async throws -> JSONValue {
        try await client.request(.get, "/api/system_logs", query: ["limit": String(limit)])
    }
}
