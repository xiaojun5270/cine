import SwiftUI

struct MoviePilotView: View {
    private let service = MoviePilotService()
    @State private var subs: JSONValue?
    @State private var config: JSONValue?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?

    var body: some View {
        ModuleScaffold(title: "MoviePilot 订阅", isLoading: isLoading && subs == nil, error: subs == nil ? error : nil,
                       onRetry: { Task { await load() } }) {
            GlassCard {
                HStack {
                    VStack(alignment: .leading) {
                        Text("MoviePilot").font(.headline)
                        Text(config?.firstString("mp_url") ?? "未配置").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    ModuleActionButton(title: "测试连接", systemImage: "bolt.horizontal") { Task { await test() } }
                }
            }
            let items = subs?.items() ?? []
            if items.isEmpty {
                EmptyStateView(systemImage: "airplane", title: "暂无订阅").frame(height: 160)
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { _, s in
                    let name = s.firstString("name", "title") ?? "订阅"
                    let type = s.firstString("type_name", "type")
                    GlassCard {
                        HStack {
                            Text(name).font(.subheadline.weight(.medium)).lineLimit(1)
                            Spacer()
                            if let type { GlassPill(type, systemImage: "film") }
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
        async let s = service.subscriptions()
        async let c = service.config()
        do { subs = try await s } catch { self.error = error }
        config = try? await c
        isLoading = false
    }
    private func test() async {
        do { _ = try await service.test(); toast = "连接测试完成" } catch { toast = error.localizedDescription }
    }
}

struct RssView: View {
    private let service = RssService()
    @State private var tasks: [JSONValue] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?

    var body: some View {
        ModuleScaffold(title: "RSS 原生源", isLoading: isLoading && tasks.isEmpty, error: tasks.isEmpty ? error : nil,
                       isEmpty: !isLoading && tasks.isEmpty && error == nil, emptyTitle: "暂无 RSS 任务",
                       emptyIcon: "antenna.radiowaves.left.and.right", onRetry: { Task { await load() } }) {
            ForEach(Array(tasks.enumerated()), id: \.offset) { _, t in
                let name = t.firstString("name") ?? "RSS 任务"
                let id = t.firstString("id") ?? ""
                let enabled = t["enabled"].bool ?? true
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Circle().fill(enabled ? .green : .gray).frame(width: 8, height: 8)
                            Text(name).font(.subheadline.weight(.medium)).lineLimit(1)
                            Spacer()
                        }
                        HStack(spacing: 8) {
                            ModuleActionButton(title: enabled ? "禁用" : "启用", systemImage: enabled ? "pause" : "play") {
                                Task { await toggle(id, !enabled) }
                            }
                            ModuleActionButton(title: "删除", systemImage: "trash", role: .destructive) {
                                Task { await del(id) }
                            }
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
    private func toggle(_ id: String, _ en: Bool) async { do { try await service.toggleTask(id: id, enabled: en); await load() } catch { toast = error.localizedDescription } }
    private func del(_ id: String) async { do { try await service.deleteTask(id: id); await load() } catch { toast = error.localizedDescription } }
}

struct ForwardView: View {
    private let service = ForwardService()
    @State private var config: JSONValue?
    @State private var sources: JSONValue?
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        ModuleScaffold(title: "资源转发", isLoading: isLoading && config == nil, error: config == nil ? error : nil,
                       onRetry: { Task { await load() } }) {
            if let config { JSONKeyValueCard(title: "转发配置", json: config, limit: 16) }
            let items = sources?.items() ?? []
            if !items.isEmpty {
                SectionHeader(title: "搜索源")
                ForEach(Array(items.enumerated()), id: \.offset) { _, s in
                    GlassCard {
                        HStack {
                            Text(s.firstString("name", "key", "id") ?? "源").font(.subheadline)
                            Spacer()
                            if let enabled = s["enabled"].bool {
                                StatusChip(text: enabled ? "启用" : "停用", ok: enabled)
                            }
                        }
                    }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true; error = nil
        async let c = service.config()
        async let s = service.searchSources()
        do { config = try await c } catch { self.error = error }
        sources = try? await s
        isLoading = false
    }
}

struct ResourcesView: View {
    private let service = ResourcesService()
    @State private var suites: JSONValue?
    @State private var fonts: JSONValue?
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        ModuleScaffold(title: "海报套件", isLoading: isLoading && suites == nil, error: suites == nil ? error : nil,
                       onRetry: { Task { await load() } }) {
            let suiteItems = suites?.items() ?? []
            SectionHeader(title: "套件（\(suiteItems.count)）")
            ForEach(Array(suiteItems.enumerated()), id: \.offset) { _, s in
                GlassCard {
                    Text(s.firstString("name", "suite_name", "title") ?? s.string ?? "套件")
                        .font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if let fonts { JSONKeyValueCard(title: "字体", json: fonts, limit: 10) }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true; error = nil
        async let s = service.suites()
        async let f = service.fonts()
        do { suites = try await s } catch { self.error = error }
        fonts = try? await f
        isLoading = false
    }
}
