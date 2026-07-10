import SwiftUI

struct MediaOrganizeView: View {
    private let service = MediaOrganizeService()
    @State private var config: JSONValue?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?
    @State private var mediaType = "movie"
    @State private var overwrite = false
    @State private var isBluray = false
    @State private var identifyInput = ""
    @State private var detail: JSONValue?
    @State private var detailTitle = "结果"
    @State private var showDetail = false

    var body: some View {
        ModuleScaffold(title: "媒体整理", isLoading: isLoading && config == nil, error: config == nil ? error : nil,
                       onRetry: { Task { await load() } }, toolbarContent: AnyView(toolbarMenu)) {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("执行整理").font(.headline)
                    Picker("类型", selection: $mediaType) {
                        Text("电影").tag("movie"); Text("剧集").tag("tv")
                    }.pickerStyle(.segmented)
                    Toggle("蓝光原盘", isOn: $isBluray).tint(Theme.accent)
                    Toggle("覆盖已存在", isOn: $overwrite).tint(Theme.accent)
                    GlassPrimaryButton(title: "开始整理", systemImage: "folder.badge.gearshape") {
                        Task { await organize() }
                    }
                }
            }
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("识别测试").font(.headline)
                    TextField("输入文件名或路径", text: $identifyInput, axis: .vertical)
                        .lineLimit(1...3)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                    ModuleActionButton(title: "测试识别", systemImage: "wand.and.stars", prominent: true) {
                        Task { await identify() }
                    }
                    .disabled(identifyInput.isEmpty)
                }
            }
            if let config {
                JSONKeyValueCard(title: "当前配置", json: config, limit: 24)
            }
        }
        .task { await load() }
        .toast($toast)
        .sheet(isPresented: $showDetail) {
            NavigationStack {
                ScrollView {
                    if let detail {
                        JSONKeyValueCard(title: nil, json: detail, limit: 80)
                            .padding(Theme.screenPadding)
                    } else {
                        EmptyStateView(systemImage: "doc.text", title: "暂无结果")
                    }
                }
                .background(Theme.backgroundGradient.ignoresSafeArea())
                .navigationTitle(detailTitle).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("关闭") { showDetail = false } } }
            }
        }
    }

    private var toolbarMenu: some View {
        Menu {
            Button { Task { await showDefaults() } } label: {
                Label("查看默认配置", systemImage: "doc.text")
            }
            Button { Task { await showCategoryRules() } } label: {
                Label("查看分类规则", systemImage: "tag")
            }
            Button { Task { await showCategoryRuleDefaults() } } label: {
                Label("查看默认分类规则", systemImage: "tag.circle")
            }
            Divider()
            Button { Task { await refreshCache() } } label: {
                Label("刷新 Emby 库缓存", systemImage: "arrow.clockwise")
            }
            Button { Task { await backfillCollections() } } label: {
                Label("补齐电影合集", systemImage: "rectangle.stack.badge.plus")
            }
            Button { Task { await fixLocaleDefaults() } } label: {
                Label("修复媒体库语言", systemImage: "globe.asia.australia")
            }
            Button { Task { await syncScrapers() } } label: {
                Label("同步刮削器设置", systemImage: "arrow.triangle.2.circlepath")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private func load() async {
        isLoading = true; error = nil
        do { config = try await service.config() } catch { self.error = error }
        isLoading = false
    }
    private func organize() async {
        do { _ = try await service.organize(mediaType: mediaType, isBluray: isBluray, overwrite: overwrite); toast = "已开始整理" }
        catch { toast = error.localizedDescription }
    }
    private func refreshCache() async {
        do { try await service.refreshEmbyCache(); toast = "已刷新缓存" } catch { toast = error.localizedDescription }
    }
    private func identify() async {
        do {
            detail = try await service.identifyTest(input: identifyInput, folderName: nil, fileName: nil, mediaType: mediaType)
            detailTitle = "识别结果"
            showDetail = true
        } catch { toast = error.localizedDescription }
    }
    private func showDefaults() async {
        do { detail = try await service.defaults(); detailTitle = "默认配置"; showDetail = true }
        catch { toast = error.localizedDescription }
    }
    private func showCategoryRules() async {
        do { detail = try await service.categoryRules(); detailTitle = "分类规则"; showDetail = true }
        catch { toast = error.localizedDescription }
    }
    private func showCategoryRuleDefaults() async {
        do { detail = try await service.categoryRuleDefaults(); detailTitle = "默认分类规则"; showDetail = true }
        catch { toast = error.localizedDescription }
    }
    private func backfillCollections() async {
        do { detail = try await service.backfillCollections(); detailTitle = "合集补齐"; showDetail = true }
        catch { toast = error.localizedDescription }
    }
    private func fixLocaleDefaults() async {
        do { detail = try await service.fixLocaleDefaults(); detailTitle = "语言修复"; showDetail = true }
        catch { toast = error.localizedDescription }
    }
    private func syncScrapers() async {
        do { detail = try await service.syncScrapers(); detailTitle = "刮削器同步"; showDetail = true }
        catch { toast = error.localizedDescription }
    }
}

struct OrganizeHistoryView: View {
    private let service = OrganizeHistoryService()
    @State private var records: [JSONValue] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?
    @State private var keyword = ""

    var body: some View {
        ModuleScaffold(title: "整理历史", isLoading: isLoading && records.isEmpty, error: records.isEmpty ? error : nil,
                       isEmpty: !isLoading && records.isEmpty && error == nil, emptyTitle: "暂无记录",
                       emptyIcon: "clock", onRetry: { Task { await load() } }) {
            ForEach(Array(records.enumerated()), id: \.offset) { _, r in
                let title = r.firstString("title", "name", "media_name", "file_name", "target_name") ?? "记录"
                let id = r.firstString("id", "record_id", "_id") ?? ""
                let category = r.firstString("category", "type", "status")
                let time = r.firstString("created_at", "time", "organized_at", "finished_at")
                GlassCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title).font(.subheadline.weight(.medium)).lineLimit(2)
                        HStack(spacing: 8) {
                            if let category { GlassPill(category, systemImage: "tag") }
                            if let time { Text(time).font(.caption2).foregroundStyle(.secondary) }
                        }
                        if !id.isEmpty {
                            HStack(spacing: 8) {
                                ModuleActionButton(title: "重新整理", systemImage: "arrow.clockwise", prominent: true) {
                                    Task { await redo(id) }
                                }
                                ModuleActionButton(title: "删除", systemImage: "trash", role: .destructive) {
                                    Task { await delete(id) }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            }
        }
        .searchable(text: $keyword, prompt: "搜索历史")
        .onSubmit(of: .search) { Task { await load() } }
        .task { await load() }
        .toast($toast)
    }

    private func load() async {
        isLoading = true; error = nil
        do {
            let json = try await service.records(keyword: keyword.isEmpty ? nil : keyword)
            records = json.items()
        } catch { self.error = error }
        isLoading = false
    }
    private func redo(_ id: String) async {
        do {
            try await service.redo(historyIDs: [id], reason: nil)
            toast = "已提交重新整理"
            await load()
        } catch { toast = error.localizedDescription }
    }
    private func delete(_ id: String) async {
        do {
            try await service.deleteRecords(ids: [id])
            toast = "已删除记录"
            await load()
        } catch { toast = error.localizedDescription }
    }
}

struct StrmView: View {
    private let service = StrmService()
    @State private var config: JSONValue?
    @State private var progress: JSONValue?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?

    var body: some View {
        ModuleScaffold(title: "STRM 同步", isLoading: isLoading && config == nil, error: config == nil ? error : nil,
                       onRetry: { Task { await load() } }) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("同步操作").font(.headline)
                    HStack(spacing: 10) {
                        ModuleActionButton(title: "生成 STRM", systemImage: "play.fill", prominent: true) {
                            Task { await start(mode: "strm") }
                        }
                        ModuleActionButton(title: "刮削元数据", systemImage: "wand.and.stars") {
                            Task { await start(mode: "metadata") }
                        }
                    }
                }
            }
            if let progress, let obj = progress.object, !obj.isEmpty {
                JSONKeyValueCard(title: "进度", json: progress, limit: 12)
                if let runID = progress.firstString("run_id", "id", "task_id") {
                    ModuleActionButton(title: "停止当前任务", systemImage: "stop.fill", role: .destructive) {
                        Task { await stop(runID) }
                    }
                }
            }
            if let config {
                JSONKeyValueCard(title: "配置", json: config, limit: 20)
            }
        }
        .task { await load() }
        .toast($toast)
    }

    private func load() async {
        isLoading = true; error = nil
        async let c = service.config()
        async let p = service.progress()
        do { config = try await c } catch { self.error = error }
        progress = try? await p
        isLoading = false
    }
    private func start(mode: String) async {
        do { try await service.start(taskIndex: 0, mode: mode); toast = "已开始：\(mode)" }
        catch { toast = error.localizedDescription }
    }
    private func stop(_ runID: String) async {
        do { try await service.stop(runID: runID); toast = "已停止"; await load() }
        catch { toast = error.localizedDescription }
    }
}
