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
    @State private var config: JSONValue?
    @State private var presets: JSONValue?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?
    @State private var showPresets = false

    var body: some View {
        ModuleScaffold(title: "RSS 原生源", isLoading: isLoading && tasks.isEmpty, error: tasks.isEmpty ? error : nil,
                       isEmpty: !isLoading && tasks.isEmpty && error == nil, emptyTitle: "暂无 RSS 任务",
                       emptyIcon: "antenna.radiowaves.left.and.right", onRetry: { Task { await load() } },
                       toolbarContent: AnyView(toolbarMenu)) {
            if let config { JSONKeyValueCard(title: "全局配置", json: config, limit: 10) }
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
                            ModuleActionButton(title: "立即运行", systemImage: "play.fill", prominent: true) {
                                Task { await runNow(id: id) }
                            }
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
        .sheet(isPresented: $showPresets) {
            NavigationStack {
                ScrollView {
                    if let presets {
                        JSONKeyValueCard(title: nil, json: presets, limit: 80)
                            .padding(Theme.screenPadding)
                    } else {
                        EmptyStateView(systemImage: "link", title: "暂无预设")
                    }
                }
                .background(Theme.backgroundGradient.ignoresSafeArea())
                .navigationTitle("链接预设").navigationBarTitleDisplayMode(.inline)
                .appLiquidNavigationChrome()
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("关闭") { showPresets = false } } }
            }
        }
    }

    private var toolbarMenu: some View {
        Menu {
            Button {
                Task { await runNow(id: nil) }
            } label: {
                Label("立即运行全部", systemImage: "play.fill")
            }
            Button {
                Task {
                    await loadPresets()
                    showPresets = true
                }
            } label: {
                Label("查看链接预设", systemImage: "link")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private func load() async {
        isLoading = true; error = nil
        async let t = service.tasks()
        async let c = service.config()
        do { tasks = try await t } catch { self.error = error }
        config = try? await c
        isLoading = false
    }
    private func runNow(id: String?) async {
        let body: JSONValue = id.map { JSONValue.obj(["id": $0]) } ?? .obj([:])
        do { try await service.runNow(body); toast = "已触发 RSS 运行" }
        catch { toast = error.localizedDescription }
    }
    private func loadPresets() async {
        do { presets = try await service.linkPresets() }
        catch { toast = error.localizedDescription }
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
    @State private var templates: JSONValue?
    @State private var layouts: JSONValue?
    @State private var fonts: JSONValue?
    @State private var translations: JSONValue?
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
            if let templates { JSONKeyValueCard(title: "模板", json: templates, limit: 12) }
            if let layouts { JSONKeyValueCard(title: "布局", json: layouts, limit: 12) }
            if let translations { JSONKeyValueCard(title: "翻译", json: translations, limit: 12) }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true; error = nil
        async let s = service.suites()
        async let f = service.fonts()
        async let t = service.templates()
        async let l = service.layouts()
        async let tr = service.translations()
        do { suites = try await s } catch { self.error = error }
        fonts = try? await f
        templates = try? await t
        layouts = try? await l
        translations = try? await tr
        isLoading = false
    }
}
