import SwiftUI

struct Drive115UploadView: View {
    private let service = Drive115UploadService()
    @State private var tasks: [JSONValue] = []
    @State private var status: JSONValue?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?

    var body: some View {
        ModuleScaffold(title: "115 上传", isLoading: isLoading && tasks.isEmpty, error: tasks.isEmpty ? error : nil,
                       isEmpty: !isLoading && tasks.isEmpty && error == nil, emptyTitle: "暂无上传任务",
                       emptyIcon: "arrow.up.circle", onRetry: { Task { await load() } }) {
            if let status, let obj = status.object, !obj.isEmpty {
                JSONKeyValueCard(title: "总体状态", json: status, limit: 8)
            }
            ForEach(Array(tasks.enumerated()), id: \.offset) { _, t in taskCard(t) }
        }
        .task { await load() }
        .toast($toast)
    }

    private func taskCard(_ t: JSONValue) -> some View {
        let name = t.firstString("name", "task_name") ?? "任务"
        let id = t.firstString("id", "task_id") ?? ""
        let enabled = t["enabled"].bool ?? true
        let folder = t.firstString("local_folder", "target_path")
        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Circle().fill(enabled ? .green : .gray).frame(width: 8, height: 8)
                    Text(name).font(.subheadline.weight(.medium)).lineLimit(1)
                    Spacer()
                }
                if let folder { Text(folder).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                HStack(spacing: 8) {
                    ModuleActionButton(title: "扫描", systemImage: "arrow.triangle.2.circlepath", prominent: true) { Task { await scan(id) } }
                    ModuleActionButton(title: "停止", systemImage: "stop.fill") { Task { await stop(id) } }
                    ModuleActionButton(title: enabled ? "禁用" : "启用", systemImage: enabled ? "pause" : "play") { Task { await toggle(id, !enabled) } }
                }
            }
        }
    }

    private func load() async {
        isLoading = true; error = nil
        async let t = service.tasks()
        async let s = service.status()
        do { tasks = try await t } catch { self.error = error }
        status = try? await s
        isLoading = false
    }
    private func scan(_ id: String) async { do { try await service.scan(id: id); toast = "已触发扫描"; await load() } catch { toast = error.localizedDescription } }
    private func stop(_ id: String) async { do { try await service.stop(id: id); toast = "已停止" } catch { toast = error.localizedDescription } }
    private func toggle(_ id: String, _ en: Bool) async { do { try await service.toggle(id: id, enabled: en); await load() } catch { toast = error.localizedDescription } }
}

struct Drive115CleanupView: View {
    private let service = Drive115CleanupService()
    @State private var tasks: [JSONValue] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?

    var body: some View {
        ModuleScaffold(title: "115 清理", isLoading: isLoading && tasks.isEmpty, error: tasks.isEmpty ? error : nil,
                       isEmpty: !isLoading && tasks.isEmpty && error == nil, emptyTitle: "暂无清理任务",
                       emptyIcon: "trash", onRetry: { Task { await load() } }) {
            ForEach(Array(tasks.enumerated()), id: \.offset) { _, t in
                let name = t.firstString("name") ?? "清理任务"
                let id = t.firstString("id", "task_id") ?? ""
                let enabled = t["enabled"].bool ?? true
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Circle().fill(enabled ? .green : .gray).frame(width: 8, height: 8)
                            Text(name).font(.subheadline.weight(.medium))
                            Spacer()
                        }
                        HStack(spacing: 8) {
                            ModuleActionButton(title: "运行", systemImage: "play.fill", prominent: true) { Task { await run(id) } }
                            ModuleActionButton(title: enabled ? "禁用" : "启用", systemImage: enabled ? "pause" : "play") { Task { await toggle(id, !enabled) } }
                            ModuleActionButton(title: "删除", systemImage: "trash", role: .destructive) { Task { await del(id) } }
                        }
                    }
                }
            }
        }
        .task { await load() }
        .toast($toast)
    }

    private func load() async {
        isLoading = true; error = nil
        do { tasks = try await service.tasks() } catch { self.error = error }
        isLoading = false
    }
    private func run(_ id: String) async { do { try await service.run(id: id); toast = "已开始清理" } catch { toast = error.localizedDescription } }
    private func toggle(_ id: String, _ en: Bool) async { do { try await service.toggle(id: id, enabled: en); await load() } catch { toast = error.localizedDescription } }
    private func del(_ id: String) async { do { try await service.delete(id: id); await load() } catch { toast = error.localizedDescription } }
}
