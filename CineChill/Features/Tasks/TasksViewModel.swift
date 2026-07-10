import SwiftUI

@MainActor
@Observable
final class TasksViewModel {
    var tasks: [TaskItem] = []
    var isLoading = false
    var error: Error?
    var toast: String?
    var runningIDs: Set<String> = []

    private let service = TaskService()

    func load() async {
        isLoading = true
        error = nil
        do { tasks = try await service.listTasks() }
        catch { self.error = error }
        isLoading = false
    }

    func run(_ task: TaskItem) async {
        runningIDs.insert(task.id)
        defer { runningIDs.remove(task.id) }
        do { try await service.runSavedTask(id: task.id); toast = "已开始运行：\(task.name)" }
        catch { self.error = error }
    }

    func stop(_ task: TaskItem) async {
        do { try await service.stopTask(id: task.id); toast = "已停止：\(task.name)" }
        catch { self.error = error }
    }

    func toggle(_ task: TaskItem, enabled: Bool) async {
        do {
            try await service.toggleTask(id: task.id, enabled: enabled)
            await load()
        } catch { self.error = error; await load() }
    }
}
