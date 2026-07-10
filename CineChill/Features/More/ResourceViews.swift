import SwiftUI

struct MoviePilotView: View {
    private let service = MoviePilotService()
    @State private var subs: JSONValue?
    @State private var config: JSONValue?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?
    @State private var showConfig = false
    @State private var showSubscribe = false
    @State private var result: JSONValue?
    @State private var showResult = false
    @State private var mpURL = ""
    @State private var mpUsername = ""
    @State private var mpPassword = ""
    @State private var subscribeTMDB = ""
    @State private var subscribeType = "movie"
    @State private var subscribeSeason = ""
    @State private var subscribeName = ""
    @State private var subscribeYear = ""

    var body: some View {
        ModuleScaffold(title: "MoviePilot 订阅", isLoading: isLoading && subs == nil, error: subs == nil ? error : nil,
                       onRetry: { Task { await load() } }, toolbarContent: AnyView(toolbarMenu)) {
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
                    let tmdbID = s["tmdbid"].int ?? s["tmdb_id"].int ?? s["tmdbID"].int
                    let season = s["season"].int
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(name).font(.subheadline.weight(.medium)).lineLimit(1)
                                Spacer()
                                if let type { GlassPill(type, systemImage: "film") }
                            }
                            HStack(spacing: 8) {
                                ModuleActionButton(title: "检查", systemImage: "checkmark.circle") {
                                    Task { await check(tmdbID: tmdbID, type: type, season: season) }
                                }
                                .disabled(tmdbID == nil)
                                ModuleActionButton(title: "退订", systemImage: "trash", role: .destructive) {
                                    Task { await unsubscribe(tmdbID: tmdbID, type: type, season: season) }
                                }
                                .disabled(tmdbID == nil)
                            }
                        }
                    }
                }
            }
        }
        .task { await load() }
        .toast($toast)
        .sheet(isPresented: $showConfig) { configSheet }
        .sheet(isPresented: $showSubscribe) { subscribeSheet }
        .sheet(isPresented: $showResult) { JSONResultSheet(title: "MoviePilot 结果", json: result) }
    }

    private var toolbarMenu: some View {
        Menu {
            Button {
                seedConfigForm()
                showConfig = true
            } label: {
                Label("编辑配置", systemImage: "slider.horizontal.3")
            }
            Button {
                showSubscribe = true
            } label: {
                Label("手动订阅", systemImage: "plus.circle")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private var configSheet: some View {
        NavigationStack {
            Form {
                Section("MoviePilot") {
                    TextField("地址", text: $mpURL)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("用户名", text: $mpUsername)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("密码", text: $mpPassword)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("MoviePilot 配置")
            .navigationBarTitleDisplayMode(.inline)
            .appLiquidNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { showConfig = false } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { Task { await saveConfig() } } }
            }
        }
    }

    private var subscribeSheet: some View {
        NavigationStack {
            Form {
                Section("订阅信息") {
                    TextField("TMDB ID", text: $subscribeTMDB)
                        .keyboardType(.numberPad)
                    Picker("类型", selection: $subscribeType) {
                        Text("电影").tag("movie")
                        Text("剧集").tag("tv")
                    }
                    TextField("季（剧集可选）", text: $subscribeSeason)
                        .keyboardType(.numberPad)
                    TextField("名称（可选）", text: $subscribeName)
                    TextField("年份（可选）", text: $subscribeYear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("手动订阅")
            .navigationBarTitleDisplayMode(.inline)
            .appLiquidNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { showSubscribe = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("订阅") { Task { await subscribe() } }
                        .disabled(Int(subscribeTMDB) == nil)
                }
            }
        }
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
        do {
            result = try await service.test()
            showResult = true
        } catch { toast = error.localizedDescription }
    }
    private func seedConfigForm() {
        mpURL = config?.firstString("mp_url", "url") ?? ""
        mpUsername = config?.firstString("mp_username", "username") ?? ""
        mpPassword = ""
    }
    private func saveConfig() async {
        do {
            try await service.saveConfig(url: mpURL, username: mpUsername, password: mpPassword)
            toast = "MoviePilot 配置已保存"
            showConfig = false
            await load()
        } catch { toast = error.localizedDescription }
    }
    private func subscribe() async {
        guard let tmdbID = Int(subscribeTMDB) else { return }
        do {
            try await service.subscribe(
                tmdbID: tmdbID,
                typeName: subscribeType,
                season: Int(subscribeSeason),
                name: subscribeName.isEmpty ? nil : subscribeName,
                year: subscribeYear.isEmpty ? nil : subscribeYear
            )
            toast = "已提交订阅"
            showSubscribe = false
            await load()
        } catch { toast = error.localizedDescription }
    }
    private func check(tmdbID: Int?, type: String?, season: Int?) async {
        guard let tmdbID else { return }
        do {
            result = try await service.checkSubscription(tmdbID: tmdbID, typeName: type ?? "movie", season: season)
            showResult = true
        } catch { toast = error.localizedDescription }
    }
    private func unsubscribe(tmdbID: Int?, type: String?, season: Int?) async {
        guard let tmdbID else { return }
        do {
            try await service.unsubscribe(tmdbID: tmdbID, typeName: type ?? "movie", season: season)
            toast = "已退订"
            await load()
        } catch { toast = error.localizedDescription }
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
    @State private var toast: String?
    @State private var result: JSONValue?
    @State private var resultTitle = "结果"
    @State private var showResult = false
    @State private var forwardType = "movie"
    @State private var tmdbID = ""
    @State private var title = ""
    @State private var year = ""
    @State private var season = ""
    @State private var episode = ""
    @State private var sourcesInput = ""
    @State private var source = "aiying"
    @State private var resourceID = ""
    @State private var rawResourceBody = ""
    @State private var rawConfigBody = ""

    private let buttonColumns = [GridItem(.adaptive(minimum: 92), spacing: 8)]

    var body: some View {
        ModuleScaffold(title: "资源转发", isLoading: isLoading && config == nil, error: config == nil ? error : nil,
                       onRetry: { Task { await load() } }, toolbarContent: AnyView(toolbarMenu)) {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("资源检索").font(.headline)
                    Picker("类型", selection: $forwardType) {
                        Text("电影").tag("movie")
                        Text("剧集").tag("tv")
                    }
                    .pickerStyle(.segmented)
                    TextField("TMDB ID", text: $tmdbID)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                    HStack(spacing: 10) {
                        TextField("标题（可选）", text: $title)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        TextField("年份", text: $year)
                            .keyboardType(.numberPad)
                    }
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                    if forwardType == "tv" {
                        HStack(spacing: 10) {
                            TextField("季", text: $season).keyboardType(.numberPad)
                            TextField("集", text: $episode).keyboardType(.numberPad)
                        }
                        .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                    }
                    TextField("搜索源 key，逗号分隔（可选）", text: $sourcesInput)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                    LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                        ModuleActionButton(title: "搜索", systemImage: "magnifyingglass", prominent: true) {
                            Task { await search() }
                        }
                        ModuleActionButton(title: "资源列表", systemImage: "list.bullet.rectangle") {
                            Task { await resources() }
                        }
                        ModuleActionButton(title: "测试资源", systemImage: "checkmark.shield") {
                            Task { await testResources() }
                        }
                    }
                }
            }
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("资源操作").font(.headline)
                    HStack(spacing: 10) {
                        TextField("source", text: $source)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        TextField("resource_id", text: $resourceID)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                    TextField("完整资源 JSON（可选，留空使用上方字段）", text: $rawResourceBody, axis: .vertical)
                        .lineLimit(2...8)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                    LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                        ModuleActionButton(title: "预览", systemImage: "eye") {
                            Task { await runResourceAction("预览结果") { try await service.previewResource($0) } }
                        }
                        ModuleActionButton(title: "下载", systemImage: "arrow.down.circle", prominent: true) {
                            Task { await runResourceAction("下载结果") { try await service.downloadResource($0) } }
                        }
                        ModuleActionButton(title: "转存", systemImage: "tray.and.arrow.down") {
                            Task { await runResourceAction("转存结果") { try await service.transferResource($0) } }
                        }
                    }
                }
            }
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("转发配置").font(.headline)
                    TextField("配置 JSON", text: $rawConfigBody, axis: .vertical)
                        .lineLimit(2...8)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                    LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                        ModuleActionButton(title: "生成模板", systemImage: "doc.badge.gearshape") {
                            seedConfigBody()
                        }
                        ModuleActionButton(title: "保存配置", systemImage: "square.and.arrow.down", prominent: true) {
                            Task { await saveConfig() }
                        }
                    }
                }
            }
            if let config { JSONKeyValueCard(title: "转发配置", json: config, limit: 16) }
            let items = sources?.items() ?? []
            if !items.isEmpty {
                SectionHeader(title: "搜索源", subtitle: "\(items.count) 个")
                ForEach(Array(items.enumerated()), id: \.offset) { _, s in
                    let key = s.firstString("key", "id", "name") ?? ""
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(s.firstString("name", "key", "id") ?? "源").font(.subheadline)
                                Spacer()
                                if let enabled = s["enabled"].bool {
                                    StatusChip(text: enabled ? "启用" : "停用", ok: enabled)
                                }
                            }
                            HStack {
                                if !key.isEmpty {
                                    Text(key).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                ModuleActionButton(title: "选用", systemImage: "checkmark.circle") {
                                    appendSource(key)
                                }
                                .disabled(key.isEmpty)
                            }
                        }
                    }
                }
            }
        }
        .task { await load() }
        .toast($toast)
        .sheet(isPresented: $showResult) { JSONResultSheet(title: resultTitle, json: result) }
    }

    private var toolbarMenu: some View {
        Menu {
            Button {
                Task { await refreshToken() }
            } label: {
                Label("刷新组件令牌", systemImage: "key")
            }
            Button {
                seedConfigBody()
            } label: {
                Label("生成配置 JSON", systemImage: "doc.badge.gearshape")
            }
            Button {
                Task { await saveConfig() }
            } label: {
                Label("保存配置 JSON", systemImage: "square.and.arrow.down")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private func load() async {
        isLoading = true; error = nil
        async let c = service.config()
        async let s = service.searchSources()
        do { config = try await c } catch { self.error = error }
        sources = try? await s
        isLoading = false
    }

    private func search() async {
        do {
            let id = try parsedTMDB()
            result = try await service.searchResources(
                type: forwardType,
                tmdbID: id,
                title: title.isEmpty ? nil : title,
                year: year.isEmpty ? nil : year,
                season: Int(season),
                episode: Int(episode),
                sources: selectedSources
            )
            resultTitle = "搜索结果"
            showResult = true
        } catch { toast = error.localizedDescription }
    }

    private func resources() async {
        do {
            let id = try parsedTMDB()
            result = try await service.resources(type: forwardType, tmdbID: id)
            resultTitle = "资源列表"
            showResult = true
        } catch { toast = error.localizedDescription }
    }

    private func testResources() async {
        do {
            let id = try parsedTMDB()
            result = try await service.testResources(type: forwardType, tmdbID: id)
            resultTitle = "资源测试"
            showResult = true
        } catch { toast = error.localizedDescription }
    }

    private func runResourceAction(_ title: String, action: (JSONValue) async throws -> JSONValue) async {
        do {
            result = try await action(resourceBody())
            resultTitle = title
            showResult = true
        } catch { toast = error.localizedDescription }
    }

    private func refreshToken() async {
        do {
            result = try await service.refreshToken()
            resultTitle = "令牌刷新"
            showResult = true
        } catch { toast = error.localizedDescription }
    }

    private func seedConfigBody() {
        rawConfigBody = """
        {"enabled":true,"public_base_url":"","library_enabled":true,"transfer_mode":"series","aiying_enabled":true,"aiying_tg_id":"","aiying_chill_token":""}
        """
        result = .string(rawConfigBody)
        resultTitle = "配置 JSON"
        showResult = true
    }

    private func saveConfig() async {
        do {
            guard !rawConfigBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先生成或填写配置 JSON"])
            }
            result = try await service.saveConfig(try decodeJSON(rawConfigBody))
            resultTitle = "配置保存"
            showResult = true
            await load()
        } catch { toast = error.localizedDescription }
    }

    private var selectedSources: [String]? {
        let values = sourcesInput
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return values.isEmpty ? nil : values
    }

    private func appendSource(_ key: String) {
        guard !key.isEmpty else { return }
        var values = selectedSources ?? []
        if !values.contains(key) { values.append(key) }
        sourcesInput = values.joined(separator: ",")
    }

    private func parsedTMDB() throws -> Int {
        guard let id = Int(tmdbID.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw APIError.validation(["请填写 TMDB ID"])
        }
        return id
    }

    private func resourceBody() throws -> JSONValue {
        if !rawResourceBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return try decodeJSON(rawResourceBody)
        }
        let id = try parsedTMDB()
        return JSONValue.obj([
            "source": source.isEmpty ? "aiying" : source,
            "resource_id": resourceID,
            "type": forwardType,
            "tmdb_id": String(id),
            "title": title,
            "year": year
        ])
    }

    private func decodeJSON(_ text: String) throws -> JSONValue {
        guard let data = text.data(using: .utf8) else { throw APIError.decoding("JSON 不是 UTF-8 文本") }
        return try JSONDecoder().decode(JSONValue.self, from: data)
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
    @State private var toast: String?
    @State private var result: JSONValue?
    @State private var resultTitle = "结果"
    @State private var showResult = false
    @State private var suiteName = ""
    @State private var templateName = ""
    @State private var fontName = ""
    @State private var rawApplyBody = ""
    @State private var rawSuiteBody = ""
    @State private var rawTemplateBody = ""
    @State private var rawTranslationsBody = ""

    private let buttonColumns = [GridItem(.adaptive(minimum: 92), spacing: 8)]

    var body: some View {
        ModuleScaffold(title: "海报套件", isLoading: isLoading && suites == nil, error: suites == nil ? error : nil,
                       onRetry: { Task { await load() } }, toolbarContent: AnyView(toolbarMenu)) {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("套件操作").font(.headline)
                    TextField("suite_name", text: $suiteName)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                    TextField("创建/恢复套件 JSON（含 url/key/suite_name）", text: $rawSuiteBody, axis: .vertical)
                        .lineLimit(2...8)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                    LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                        ModuleActionButton(title: "内容", systemImage: "doc.text") {
                            Task { await suiteContent(suiteName) }
                        }
                        .disabled(suiteName.isEmpty)
                        ModuleActionButton(title: "创建", systemImage: "plus.circle", prominent: true) {
                            Task { await runJSONAction("创建套件", rawSuiteBody) { try await service.createSuite($0) } }
                        }
                        ModuleActionButton(title: "恢复", systemImage: "arrow.clockwise") {
                            Task { await runJSONAction("恢复套件", rawSuiteBody) { try await service.restoreSuite($0) } }
                        }
                        ModuleActionButton(title: "删除", systemImage: "trash", role: .destructive) {
                            Task { await deleteSuite(suiteName) }
                        }
                        .disabled(suiteName.isEmpty)
                    }
                }
            }
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("预览与应用").font(.headline)
                    TextField("预览/应用 JSON（含 url/key/library_id/config）", text: $rawApplyBody, axis: .vertical)
                        .lineLimit(3...10)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                    LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                        ModuleActionButton(title: "预览", systemImage: "eye", prominent: true) {
                            Task { await runJSONAction("预览结果", rawApplyBody) { try await service.preview($0) } }
                        }
                        ModuleActionButton(title: "应用", systemImage: "checkmark.seal") {
                            Task { await runJSONAction("应用结果", rawApplyBody) { try await service.apply($0) } }
                        }
                    }
                }
            }
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("模板与字体").font(.headline)
                    TextField("template_name", text: $templateName)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                    TextField("font_name", text: $fontName)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                    TextField("保存模板 JSON", text: $rawTemplateBody, axis: .vertical)
                        .lineLimit(2...8)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                    LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                        ModuleActionButton(title: "保存模板", systemImage: "square.and.arrow.down", prominent: true) {
                            Task { await runJSONAction("模板保存", rawTemplateBody) { try await service.saveTemplate($0) } }
                        }
                        ModuleActionButton(title: "删模板", systemImage: "trash", role: .destructive) {
                            Task { await deleteTemplate(templateName) }
                        }
                        .disabled(templateName.isEmpty)
                        ModuleActionButton(title: "删字体", systemImage: "textformat", role: .destructive) {
                            Task { await deleteFont(fontName) }
                        }
                        .disabled(fontName.isEmpty)
                    }
                }
            }
            let suiteItems = suites?.items() ?? []
            SectionHeader(title: "套件（\(suiteItems.count)）")
            ForEach(Array(suiteItems.enumerated()), id: \.offset) { _, s in
                let name = s.firstString("name", "suite_name", "title") ?? s.string ?? "套件"
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(name)
                            .font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                        HStack(spacing: 8) {
                            ModuleActionButton(title: "内容", systemImage: "doc.text") {
                                Task { await suiteContent(name) }
                            }
                            ModuleActionButton(title: "填入", systemImage: "square.and.pencil") {
                                suiteName = name
                            }
                            ModuleActionButton(title: "删除", systemImage: "trash", role: .destructive) {
                                Task { await deleteSuite(name) }
                            }
                        }
                    }
                }
            }
            if let fonts { JSONKeyValueCard(title: "字体", json: fonts, limit: 10) }
            if let templates { JSONKeyValueCard(title: "模板", json: templates, limit: 12) }
            if let layouts { JSONKeyValueCard(title: "布局", json: layouts, limit: 12) }
            if let translations { JSONKeyValueCard(title: "翻译", json: translations, limit: 12) }
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("翻译保存").font(.headline)
                    TextField("翻译 JSON", text: $rawTranslationsBody, axis: .vertical)
                        .lineLimit(2...8)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                    ModuleActionButton(title: "保存翻译", systemImage: "globe.asia.australia", prominent: true) {
                        Task { await runJSONAction("翻译保存", rawTranslationsBody) { try await service.saveTranslations($0) } }
                    }
                }
            }
        }
        .task { await load() }
        .toast($toast)
        .sheet(isPresented: $showResult) { JSONResultSheet(title: resultTitle, json: result) }
    }

    private var toolbarMenu: some View {
        Menu {
            Button {
                seedApplyBody()
            } label: {
                Label("生成预览模板", systemImage: "doc.badge.plus")
            }
            Button {
                seedSuiteBody()
            } label: {
                Label("生成套件模板", systemImage: "shippingbox")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
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

    private func suiteContent(_ name: String) async {
        guard !name.isEmpty else { return }
        do {
            result = try await service.suiteContent(name: name)
            resultTitle = "套件内容"
            showResult = true
        } catch { toast = error.localizedDescription }
    }

    private func deleteSuite(_ name: String) async {
        guard !name.isEmpty else { return }
        do {
            result = try await service.deleteSuite(name: name)
            resultTitle = "删除套件"
            showResult = true
            await load()
        } catch { toast = error.localizedDescription }
    }

    private func deleteTemplate(_ name: String) async {
        guard !name.isEmpty else { return }
        do {
            result = try await service.deleteTemplate(name: name)
            resultTitle = "删除模板"
            showResult = true
            await load()
        } catch { toast = error.localizedDescription }
    }

    private func deleteFont(_ name: String) async {
        guard !name.isEmpty else { return }
        do {
            result = try await service.deleteFont(name: name)
            resultTitle = "删除字体"
            showResult = true
            await load()
        } catch { toast = error.localizedDescription }
    }

    private func runJSONAction(_ title: String, _ text: String, action: (JSONValue) async throws -> JSONValue) async {
        do {
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请填写 JSON 请求体"])
            }
            result = try await action(decodeJSON(text))
            resultTitle = title
            showResult = true
            await load()
        } catch { toast = error.localizedDescription }
    }

    private func seedApplyBody() {
        rawApplyBody = """
        {"url":"","key":"","library_id":"","config":{},"mode":"random"}
        """
    }

    private func seedSuiteBody() {
        rawSuiteBody = """
        {"url":"","key":"","suite_name":"\(suiteName.isEmpty ? "default" : suiteName)","target_ids":[]}
        """
    }

    private func decodeJSON(_ text: String) throws -> JSONValue {
        guard let data = text.data(using: .utf8) else { throw APIError.decoding("JSON 不是 UTF-8 文本") }
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }
}
