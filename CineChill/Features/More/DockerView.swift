import SwiftUI

struct DockerView: View {
    private let service = DockerService()
    @State private var containers: [JSONValue] = []
    @State private var images: [JSONValue] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?
    @State private var logs: String?
    @State private var showLogs = false
    @State private var result: JSONValue?
    @State private var showResult = false

    var body: some View {
        ModuleScaffold(title: "Docker 管理", isLoading: isLoading && containers.isEmpty,
                       error: containers.isEmpty ? error : nil,
                       isEmpty: !isLoading && containers.isEmpty && images.isEmpty && error == nil, emptyTitle: "无容器",
                       emptyIcon: "shippingbox", onRetry: { Task { await load() } },
                       toolbarContent: AnyView(toolbarMenu)) {
            if !containers.isEmpty { SectionHeader(title: "容器") }
            ForEach(Array(containers.enumerated()), id: \.offset) { _, c in
                containerCard(c)
            }
            if !images.isEmpty {
                SectionHeader(title: "镜像")
                ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                    imageCard(image)
                }
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
                .appLiquidNavigationChrome()
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("关闭") { showLogs = false } } }
            }
        }
        .sheet(isPresented: $showResult) {
            NavigationStack {
                ScrollView {
                    if let result {
                        JSONKeyValueCard(title: nil, json: result, limit: 80)
                            .padding(Theme.screenPadding)
                    } else {
                        EmptyStateView(systemImage: "doc.text", title: "暂无结果")
                    }
                }
                .background(Theme.backgroundGradient.ignoresSafeArea())
                .navigationTitle("操作结果").navigationBarTitleDisplayMode(.inline)
                .appLiquidNavigationChrome()
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("关闭") { showResult = false } } }
            }
        }
    }

    private var toolbarMenu: some View {
        Menu {
            Button {
                Task { await checkUpdates() }
            } label: {
                Label("检查镜像更新", systemImage: "arrow.down.circle")
            }
            Button(role: .destructive) {
                Task { await pruneUnused() }
            } label: {
                Label("清理未使用镜像", systemImage: "trash")
            }
            Button(role: .destructive) {
                Task { await pruneUntagged() }
            } label: {
                Label("清理无标签镜像", systemImage: "tag.slash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
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

    private func imageCard(_ image: JSONValue) -> some View {
        let id = image.firstString("id", "Id", "image_id") ?? ""
        let repo = image.firstString("repository", "Repository", "repo", "name") ?? "<none>"
        let tag = image.firstString("tag", "Tag") ?? ""
        let size = image.firstString("size", "Size")
        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "shippingbox")
                        .foregroundStyle(Theme.accent)
                    Text(tag.isEmpty ? repo : "\(repo):\(tag)")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Spacer()
                }
                HStack {
                    if let size { Text(size).font(.caption2).foregroundStyle(.secondary) }
                    Spacer()
                    ModuleActionButton(title: "删除", systemImage: "trash", role: .destructive) {
                        Task { await deleteImage(id) }
                    }
                    .disabled(id.isEmpty)
                }
            }
        }
    }

    private func load() async {
        isLoading = true; error = nil
        async let c = service.containers()
        async let i = service.images()
        do { containers = try await c } catch { self.error = error }
        images = (try? await i) ?? []
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

    private func checkUpdates() async {
        let names = containers.compactMap { $0.firstString("image", "Image") }
        guard !names.isEmpty else {
            toast = "未找到可检查的镜像"
            return
        }
        do {
            result = try await service.checkUpdates(images: names)
            showResult = true
        } catch { toast = error.localizedDescription }
    }

    private func pruneUnused() async {
        do { try await service.pruneUnused(); toast = "已清理未使用镜像"; await load() }
        catch { toast = error.localizedDescription }
    }

    private func pruneUntagged() async {
        do { try await service.pruneUntagged(); toast = "已清理无标签镜像"; await load() }
        catch { toast = error.localizedDescription }
    }

    private func deleteImage(_ id: String) async {
        guard !id.isEmpty else { return }
        do { try await service.deleteImage(id: id, force: true); toast = "已删除镜像"; await load() }
        catch { toast = error.localizedDescription }
    }
}
