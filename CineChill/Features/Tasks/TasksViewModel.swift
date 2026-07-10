import SwiftUI

@MainActor
@Observable
final class TasksViewModel {
    var tasks: [TaskItem] = []
    var isLoading = false
    var error: Error?
    var toast: String?
    var runningIDs: Set<String> = []
    var progress: JSONValue?
    var logs: JSONValue?
    var batchResult: JSONValue?

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

    func createTask(_ body: JSONValue) async {
        do {
            _ = try await service.createTask(body)
            toast = "任务已创建"
            await load()
        } catch { self.error = error }
    }

    func updateTask(_ body: JSONValue) async {
        do {
            _ = try await service.updateTask(body)
            toast = "任务已保存"
            await load()
        } catch { self.error = error }
    }

    func runBatch(_ body: JSONValue) async {
        error = nil
        do {
            batchResult = try await service.runTaskBatch(body)
            toast = "批量任务已提交"
        } catch {
            self.error = error
            toast = error.localizedDescription
        }
    }

    func delete(_ task: TaskItem) async {
        do {
            try await service.deleteTask(id: task.id)
            toast = "已删除：\(task.name)"
            await load()
        } catch { self.error = error }
    }

    func loadProgress() async {
        do {
            progress = try await service.progress()
        } catch { self.error = error }
    }

    func loadLogs() async {
        do {
            logs = try await service.systemLogs()
        } catch { self.error = error }
    }

    func loadLogStreamURL() async {
        do {
            logs = try service.systemLogsStreamURL()
            toast = "已生成日志流 URL"
        } catch { self.error = error }
    }

    func clearProgress() async {
        do {
            try await service.clearTaskProgress()
            progress = .null
            toast = "已清空任务进度"
        } catch { self.error = error }
    }

    func clearLogs() async {
        do {
            try await service.clearSystemLogs()
            logs = .null
            toast = "已清空系统日志"
        } catch { self.error = error }
    }
}
