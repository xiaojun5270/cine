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
    @State private var rawConfigBody = ""
    @State private var rawCategoryRulesBody = ""
    @State private var rawSubClassifyBody = "{}"

    private let buttonColumns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

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
            configEditorCard
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
                .appLiquidNavigationChrome()
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("关闭") { showDetail = false } } }
            }
        }
    }

    private var toolbarMenu: some View {
        Menu {
            Button { seedConfigBody() } label: {
                Label("填入配置 JSON", systemImage: "square.and.pencil")
            }
            Button { Task { await saveConfig() } } label: {
                Label("保存配置 JSON", systemImage: "square.and.arrow.down")
            }
            Divider()
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
            Button { Task { await metadataRepairTVLibraries() } } label: {
                Label("元数据修复 TV 库", systemImage: "tv")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private var configEditorCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("配置编辑").font(.headline)
                TextField("媒体整理配置 JSON", text: $rawConfigBody, axis: .vertical)
                    .lineLimit(3...10)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("分类规则 JSON", text: $rawCategoryRulesBody, axis: .vertical)
                    .lineLimit(3...10)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("子分类 JSON", text: $rawSubClassifyBody, axis: .vertical)
                    .lineLimit(2...8)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "填配置", systemImage: "square.and.pencil") { seedConfigBody() }
                    ModuleActionButton(title: "保存配置", systemImage: "square.and.arrow.down", prominent: true) {
                        Task { await saveConfig() }
                    }
                    ModuleActionButton(title: "读取规则", systemImage: "tag") {
                        Task { await loadCategoryRulesIntoEditor() }
                    }
                    ModuleActionButton(title: "保存规则", systemImage: "tag.fill") {
                        Task { await saveCategoryRules() }
                    }
                    ModuleActionButton(title: "保存子分类", systemImage: "square.stack.3d.up") {
                        Task { await saveSubClassify() }
                    }
                }
            }
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
    private func metadataRepairTVLibraries() async {
        do { detail = try await service.metadataRepairTVLibraries(); detailTitle = "元数据修复 TV 库"; showDetail = true }
        catch { toast = error.localizedDescription }
    }
    private func seedConfigBody() {
        rawConfigBody = config?.prettyJSONString() ?? """
        {"drive_index":0,"source_cid":"0","source_name":"根目录","target_cid":"0","target_name":"根目录","scrape_enabled":true}
        """
    }
    private func saveConfig() async {
        do {
            guard !rawConfigBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写媒体整理配置 JSON"])
            }
            detail = try await service.saveConfig(try JSONValue.parse(rawConfigBody))
            detailTitle = "配置保存"
            showDetail = true
            await load()
        } catch { toast = error.localizedDescription }
    }
    private func loadCategoryRulesIntoEditor() async {
        do {
            let rules = try await service.categoryRules()
            rawCategoryRulesBody = rules.prettyJSONString()
            detail = rules
            detailTitle = "分类规则"
            showDetail = true
        } catch { toast = error.localizedDescription }
    }
    private func saveCategoryRules() async {
        do {
            guard !rawCategoryRulesBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写分类规则 JSON"])
            }
            detail = try await service.saveCategoryRules(try JSONValue.parse(rawCategoryRulesBody))
            detailTitle = "分类规则保存"
            showDetail = true
        } catch { toast = error.localizedDescription }
    }
    private func saveSubClassify() async {
        do {
            detail = try await service.saveSubClassify(try JSONValue.parseObjectOrEmpty(rawSubClassifyBody))
            detailTitle = "子分类保存"
            showDetail = true
        } catch { toast = error.localizedDescription }
    }
}

struct OrganizeHistoryView: View {
    private let service = OrganizeHistoryService()
    @State private var records: [JSONValue] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?
    @State private var keyword = ""
    @State private var detail: JSONValue?
    @State private var detailTitle = "结果"
    @State private var showDetail = false
    @State private var mediaSearchQuery = ""
    @State private var mediaSearchType = "auto"
    @State private var mediaSearchYear = ""
    @State private var historyIDsInput = ""
    @State private var redoReason = ""
    @State private var summaryDays = "7"
    @State private var tmdbIDInput = ""
    @State private var clearCategoriesInput = ""

    var body: some View {
        ModuleScaffold(title: "整理历史", isLoading: isLoading && records.isEmpty, error: records.isEmpty ? error : nil,
                       emptyTitle: "暂无记录", emptyIcon: "clock", onRetry: { Task { await load() } },
                       toolbarContent: AnyView(toolbarMenu)) {
            historyToolsCard
            if records.isEmpty {
                EmptyStateView(systemImage: "clock", title: "暂无记录")
                    .frame(minHeight: 180)
            } else {
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
                                    ModuleActionButton(title: "AI重做", systemImage: "wand.and.stars") {
                                        Task { await aiRedo(id) }
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
        }
        .searchable(text: $keyword, prompt: "搜索历史")
        .onSubmit(of: .search) { Task { await load() } }
        .task { await load() }
        .toast($toast)
        .sheet(isPresented: $showDetail) { JSONResultSheet(title: detailTitle, json: detail) }
    }

    private var toolbarMenu: some View {
        Menu {
            Button { Task { await showSummary() } } label: {
                Label("查看概览", systemImage: "chart.bar")
            }
            Button { Task { await mediaSearch() } } label: {
                Label("媒体搜索", systemImage: "magnifyingglass")
            }
            Button { Task { await redoBatch(ai: false) } } label: {
                Label("批量重做", systemImage: "arrow.clockwise")
            }
            Button { Task { await redoBatch(ai: true) } } label: {
                Label("AI 批量重做", systemImage: "wand.and.stars")
            }
            Button(role: .destructive) { Task { await clearCategories() } } label: {
                Label("清理分类", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private var historyToolsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("历史工具").font(.headline)
                TextField("媒体搜索关键词", text: $mediaSearchQuery)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                HStack(spacing: 10) {
                    TextField("media_type", text: $mediaSearchType)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("年份", text: $mediaSearchYear)
                        .keyboardType(.numberPad)
                    TextField("概览天数", text: $summaryDays)
                        .keyboardType(.numberPad)
                }
                .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("history_ids（逗号分隔）", text: $historyIDsInput, axis: .vertical)
                    .lineLimit(1...4)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                HStack(spacing: 10) {
                    TextField("重做原因", text: $redoReason)
                    TextField("TMDB ID", text: $tmdbIDInput)
                        .keyboardType(.numberPad)
                }
                .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("清理 categories（逗号分隔）", text: $clearCategoriesInput)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "概览", systemImage: "chart.bar", prominent: true) {
                        Task { await showSummary() }
                    }
                    ModuleActionButton(title: "搜索", systemImage: "magnifyingglass") {
                        Task { await mediaSearch() }
                    }
                    ModuleActionButton(title: "重做", systemImage: "arrow.clockwise") {
                        Task { await redoBatch(ai: false) }
                    }
                    ModuleActionButton(title: "AI重做", systemImage: "wand.and.stars") {
                        Task { await redoBatch(ai: true) }
                    }
                    ModuleActionButton(title: "分集组", systemImage: "rectangle.stack") {
                        Task { await episodeGroups() }
                    }
                    ModuleActionButton(title: "清分类", systemImage: "trash", role: .destructive) {
                        Task { await clearCategories() }
                    }
                }
            }
        }
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
            detail = try await service.redoRecord(id: id)
            detailTitle = "重新整理"
            showDetail = true
            toast = "已提交重新整理"
            await load()
        } catch { toast = error.localizedDescription }
    }
    private func aiRedo(_ id: String) async {
        do {
            detail = try await service.aiRedoRecord(id: id)
            detailTitle = "AI 重做"
            showDetail = true
            toast = "已提交 AI 重做"
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
    private func showSummary() async {
        do {
            detail = try await service.summary(days: Int(summaryDays) ?? 7, keyword: keyword.isEmpty ? nil : keyword)
            detailTitle = "整理概览"
            showDetail = true
        } catch { toast = error.localizedDescription }
    }
    private func mediaSearch() async {
        do {
            guard !mediaSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写媒体搜索关键词"])
            }
            detail = try await service.mediaSearch(
                query: mediaSearchQuery,
                mediaType: mediaSearchType.isEmpty ? "auto" : mediaSearchType,
                year: mediaSearchYear.isEmpty ? nil : mediaSearchYear
            )
            detailTitle = "媒体搜索"
            showDetail = true
        } catch { toast = error.localizedDescription }
    }
    private func redoBatch(ai: Bool) async {
        do {
            let ids = csvValues(historyIDsInput)
            guard !ids.isEmpty else { throw APIError.validation(["请先填写 history_ids"]) }
            if ai {
                detail = try await service.aiRedo(historyIDs: ids, reason: redoReason.isEmpty ? nil : redoReason)
            } else {
                detail = try await service.redo(historyIDs: ids, reason: redoReason.isEmpty ? nil : redoReason)
            }
            detailTitle = ai ? "AI 批量重做" : "批量重做"
            showDetail = true
            toast = "已提交"
            await load()
        } catch { toast = error.localizedDescription }
    }
    private func episodeGroups() async {
        do {
            guard !tmdbIDInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写 TMDB ID"])
            }
            detail = try await service.episodeGroups(tmdbID: tmdbIDInput)
            detailTitle = "分集组"
            showDetail = true
        } catch { toast = error.localizedDescription }
    }
    private func clearCategories() async {
        do {
            let categories = csvValues(clearCategoriesInput)
            guard !categories.isEmpty else { throw APIError.validation(["请先填写 categories"]) }
            try await service.clear(categories: categories)
            toast = "已清理分类"
            await load()
        } catch { toast = error.localizedDescription }
    }
    private func csvValues(_ text: String) -> [String] {
        text.split { $0 == "," || $0 == "\n" || $0 == " " }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct StrmView: View {
    private let service = StrmService()
    @State private var config: JSONValue?
    @State private var progress: JSONValue?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?
    @State private var rawConfigBody = ""
    @State private var result: JSONValue?
    @State private var resultTitle = "结果"
    @State private var showResult = false

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
                        ModuleActionButton(title: "补齐元数据", systemImage: "sparkles.rectangle.stack") {
                            Task { await startMetadata() }
                        }
                    }
                }
            }
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("配置编辑").font(.headline)
                    TextField("STRM 配置 JSON", text: $rawConfigBody, axis: .vertical)
                        .lineLimit(3...10)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                    HStack(spacing: 10) {
                        ModuleActionButton(title: "填入当前", systemImage: "square.and.pencil") { seedConfigBody() }
                        ModuleActionButton(title: "保存配置", systemImage: "square.and.arrow.down", prominent: true) {
                            Task { await saveConfig() }
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
        .sheet(isPresented: $showResult) { JSONResultSheet(title: resultTitle, json: result) }
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
    private func startMetadata() async {
        do { try await service.startMetadata(); toast = "已开始元数据补齐" }
        catch { toast = error.localizedDescription }
    }
    private func stop(_ runID: String) async {
        do { try await service.stop(runID: runID); toast = "已停止"; await load() }
        catch { toast = error.localizedDescription }
    }
    private func seedConfigBody() {
        rawConfigBody = config?.prettyJSONString() ?? """
        {"sync_tasks":[]}
        """
    }
    private func saveConfig() async {
        do {
            guard !rawConfigBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写 STRM 配置 JSON"])
            }
            result = try await service.saveConfig(try JSONValue.parse(rawConfigBody))
            resultTitle = "STRM 配置保存"
            showResult = true
            await load()
        } catch { toast = error.localizedDescription }
    }
}
