import SwiftUI

struct DockerView: View {
    private let service = DockerService()
    @State private var containers: [JSONValue] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?
    @State private var logs: String?
    @State private var showLogs = false

    var body: some View {
        ModuleScaffold(title: "Docker 管理", isLoading: isLoading && containers.isEmpty,
                       error: containers.isEmpty ? error : nil,
                       isEmpty: !isLoading && containers.isEmpty && error == nil, emptyTitle: "无容器",
                       emptyIcon: "shippingbox", onRetry: { Task { await load() } }) {
            ForEach(Array(containers.enumerated()), id: \.offset) { _, c in
                containerCard(c)
            }
        }
        .task { await load() }
        .toast($toast)
        .sheet(isPresented: $showLogs) {
            NavigationStack {
                ScrollView {
                    Text(logs ?? "无日志")
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .background(Theme.backgroundGradient.ignoresSafeArea())
                .navigationTitle("容器日志").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("关闭") { showLogs = false } } }
            }
        }
    }

    private func containerCard(_ c: JSONValue) -> some View {
        let name = c.firstString("name", "Name", "names") ?? "容器"
        let id = c.firstString("id", "Id", "container_id") ?? ""
        let state = c.firstString("state", "State", "status", "Status") ?? ""
        let running = state.lowercased().contains("run") || state.lowercased().contains("up")
        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Circle().fill(running ? .green : .gray).frame(width: 8, height: 8)
                    Text(name).font(.subheadline.weight(.medium)).lineLimit(1)
                    Spacer()
                    Text(state).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                HStack(spacing: 8) {
                    ModuleActionButton(title: "启动", systemImage: "play.fill", prominent: true) { Task { await action(id, "start") } }
                    ModuleActionButton(title: "停止", systemImage: "stop.fill") { Task { await action(id, "stop") } }
                    ModuleActionButton(title: "重启", systemImage: "arrow.clockwise") { Task { await action(id, "restart") } }
                }
                ModuleActionButton(title: "查看日志", systemImage: "doc.text") { Task { await loadLogs(id) } }
            }
        }
    }

    private func load() async {
        isLoading = true; error = nil
        do { containers = try await service.containers() } catch { self.error = error }
        isLoading = false
    }
    private func action(_ id: String, _ act: String) async {
        do { try await service.containerAction(id: id, action: act); toast = "已执行：\(act)"; await load() }
        catch { toast = error.localizedDescription }
    }
    private func loadLogs(_ id: String) async {
        do {
            let json = try await service.logs(id: id)
            logs = json.string ?? json["logs"].string ?? json.firstString("content", "output") ?? "无日志"
            showLogs = true
        } catch { toast = error.localizedDescription }
    }
}
