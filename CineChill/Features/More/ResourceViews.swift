import SwiftUI
import UniformTypeIdentifiers

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
            ScrollView {
                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            IconBadge(systemImage: "airplane.departure", tint: Theme.accentBlue, size: 44)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("MoviePilot").font(.headline)
                                Text("连接地址和登录凭据").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        TextField("地址", text: $mpURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .textContentType(.URL)
                            .appInputFieldChrome()
                        TextField("用户名", text: $mpUsername)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.username)
                            .appInputFieldChrome()
                        SecureField("密码", text: $mpPassword)
                            .textContentType(.password)
                            .appInputFieldChrome()
                    }
                }
                .padding(Theme.screenPadding)
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
            ScrollView {
                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            IconBadge(systemImage: "plus.circle.fill", tint: Theme.accent, size: 44)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("订阅信息").font(.headline)
                                Text("按 TMDB ID 创建 MoviePilot 订阅").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        TextField("TMDB ID", text: $subscribeTMDB)
                            .keyboardType(.numberPad)
                            .appInputFieldChrome()
                        Picker("类型", selection: $subscribeType) {
                            Text("电影").tag("movie")
                            Text("剧集").tag("tv")
                        }
                        .pickerStyle(.segmented)
                        TextField("季（剧集可选）", text: $subscribeSeason)
                            .keyboardType(.numberPad)
                            .appInputFieldChrome()
                        TextField("名称（可选）", text: $subscribeName)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .appInputFieldChrome()
                        TextField("年份（可选）", text: $subscribeYear)
                            .keyboardType(.numberPad)
                            .appInputFieldChrome()
                    }
                }
                .padding(Theme.screenPadding)
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
    @State private var result: JSONValue?
    @State private var resultTitle = "结果"
    @State private var showResult = false
    @State private var rssURL = ""
    @State private var contentType = "movies"
    @State private var previewLimit = "10"
    @State private var taskID = ""
    @State private var taskName = ""
    @State private var taskCron = "0 */6 * * *"
    @State private var targetServerIndex = "0"
    @State private var taskEnabled = true
    @State private var syncMissingToMP = false
    @State private var rawTaskBody = ""
    @State private var sourceRoot = ""
    @State private var linkRoot = ""
    @State private var presetID = ""
    @State private var buildParamsBody = "{}"
    @State private var buildProxy = true
    @State private var nativePath = "/api/rss/native/tmdb/trending"
    @State private var nativeQueryBody = "{\"media_type\":\"movie\",\"time_window\":\"week\",\"language\":\"zh-CN\",\"page_limit\":1,\"max_items\":50}"
    @State private var rssImageProxyURL = ""

    private let buttonColumns = [GridItem(.adaptive(minimum: 92), spacing: 8)]

    var body: some View {
        ModuleScaffold(title: "RSS 原生源", isLoading: isLoading && tasks.isEmpty, error: tasks.isEmpty ? error : nil,
                       isEmpty: !isLoading && tasks.isEmpty && error == nil, emptyTitle: "暂无 RSS 任务",
                       emptyIcon: "antenna.radiowaves.left.and.right", onRetry: { Task { await load() } },
                       toolbarContent: AnyView(toolbarMenu)) {
            if let config { JSONKeyValueCard(title: "全局配置", json: config, limit: 10) }
            rssTaskEditorCard
            rssConfigCard
            nativeSourceCard
            taskList
        }
        .task { await load() }
        .toast($toast)
        .sheet(isPresented: $showResult) { JSONResultSheet(title: resultTitle, json: result) }
    }

    private var rssTaskEditorCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("RSS 预览与任务").font(.headline)
                TextField("RSS URL", text: $rssURL, axis: .vertical)
                    .lineLimit(1...4)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                Picker("内容类型", selection: $contentType) {
                    Text("电影").tag("movies")
                    Text("剧集").tag("series")
                    Text("混合").tag("mixed")
                }
                .pickerStyle(.segmented)
                HStack(spacing: 10) {
                    TextField("任务名", text: $taskName)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Cron", text: $taskCron)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                HStack(spacing: 10) {
                    TextField("任务 ID（更新可选）", text: $taskID)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("预览数量", text: $previewLimit)
                        .keyboardType(.numberPad)
                }
                .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                Toggle("启用任务", isOn: $taskEnabled)
                Toggle("缺失同步到 MoviePilot", isOn: $syncMissingToMP)
                TextField("完整任务 JSON（可选）", text: $rawTaskBody, axis: .vertical)
                    .lineLimit(2...8)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "预览", systemImage: "eye", prominent: true) {
                        Task { await preview() }
                    }
                    ModuleActionButton(title: "创建", systemImage: "plus.circle") {
                        Task { await createTask() }
                    }
                    ModuleActionButton(title: "更新", systemImage: "square.and.pencil") {
                        Task { await updateTask() }
                    }
                    ModuleActionButton(title: "任务模板", systemImage: "doc.badge.plus") {
                        seedTaskBody()
                    }
                }
            }
        }
    }

    private var rssConfigCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("全局配置与链接预设").font(.headline)
                HStack(spacing: 10) {
                    TextField("source_root", text: $sourceRoot)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("link_root", text: $linkRoot)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("preset_id", text: $presetID)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("构建 URL 参数 JSON", text: $buildParamsBody, axis: .vertical)
                    .lineLimit(2...6)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                Toggle("代理生成链接", isOn: $buildProxy)
                LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "保存配置", systemImage: "square.and.arrow.down", prominent: true) {
                        Task { await saveConfig() }
                    }
                    ModuleActionButton(title: "链接预设", systemImage: "link") {
                        Task { await loadPresets(show: true) }
                    }
                    ModuleActionButton(title: "构建 URL", systemImage: "wand.and.stars") {
                        Task { await buildURL() }
                    }
                    ModuleActionButton(title: "填入配置", systemImage: "doc.badge.gearshape") {
                        seedConfigFields()
                    }
                }
            }
        }
    }

    private var nativeSourceCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("原生源").font(.headline)
                TextField("原生源路径", text: $nativePath)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("查询参数 JSON", text: $nativeQueryBody, axis: .vertical)
                    .lineLimit(2...8)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("RSS 图片 URL", text: $rssImageProxyURL)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                    nativePresetButtons
                }
            }
        }
    }

    @ViewBuilder
    private var nativePresetButtons: some View {
        Group {
            ModuleActionButton(title: "读取", systemImage: "antenna.radiowaves.left.and.right", prominent: true) {
                Task { await nativeFeed(title: "原生源") }
            }
            ModuleActionButton(title: "TMDB趋势", systemImage: "chart.line.uptrend.xyaxis") {
                Task { await runNativePreset("TMDB 趋势", path: "/api/rss/native/tmdb/trending", query: "{\"media_type\":\"movie\",\"time_window\":\"week\",\"language\":\"zh-CN\",\"page_limit\":1,\"max_items\":50}") }
            }
            ModuleActionButton(title: "TMDB发现", systemImage: "sparkle.magnifyingglass") {
                Task { await runNativePreset("TMDB 发现", path: "/api/rss/native/tmdb/discover", query: "{\"media_type\":\"movie\",\"watch_region\":\"US\",\"sort_by\":\"popularity.desc\",\"language\":\"zh-CN\",\"page_limit\":1,\"max_items\":50}") }
            }
            ModuleActionButton(title: "豆瓣分类", systemImage: "star.circle") {
                Task { await runNativePreset("豆瓣分类", path: "/api/rss/native/douban/classification", query: "{\"sort\":\"U\",\"score\":0,\"tags\":\"\",\"page_limit\":1}") }
            }
            ModuleActionButton(title: "豆瓣上映", systemImage: "calendar") {
                Task { await runNativePreset("豆瓣即将上映", path: "/api/rss/native/douban/coming", query: "{}") }
            }
            ModuleActionButton(title: "豆瓣推荐", systemImage: "hand.thumbsup") {
                Task { await runNativePreset("豆瓣推荐", path: "/api/rss/native/douban/recommended", query: "{\"subject_type\":\"movie\",\"score\":0,\"playable\":0}") }
            }
        }
        Group {
            ModuleActionButton(title: "豆瓣片单", systemImage: "list.bullet.rectangle") {
                Task { await runNativePreset("豆瓣片单", path: "/api/rss/native/douban/list", query: "{\"collection_id\":\"movie_showing\",\"media_type\":\"movie\",\"score\":0,\"playable\":0,\"page_limit\":1}") }
            }
            ModuleActionButton(title: "爱奇艺榜", systemImage: "chart.bar") {
                Task { await runNativePreset("爱奇艺榜单", path: "/api/rss/native/iqiyi/rank", query: "{\"category\":\"movie\",\"rank\":\"hot\",\"page_limit\":1}") }
            }
            ModuleActionButton(title: "猫眼电影", systemImage: "ticket") {
                Task { await runNativePreset("猫眼电影", path: "/api/rss/native/maoyan/movie", query: "{\"kind\":\"hot\"}") }
            }
            ModuleActionButton(title: "猫眼平台", systemImage: "tv") {
                Task { await runNativePreset("猫眼平台", path: "/api/rss/native/maoyan/platform", query: "{\"platform\":\"tencent\",\"rank\":\"series\",\"page_limit\":1}") }
            }
            ModuleActionButton(title: "国内平台", systemImage: "play.tv") {
                Task { await runNativePreset("国内平台", path: "/api/rss/native/domestic/tencent", query: "{\"mtype\":\"movie\",\"page_limit\":1}") }
            }
            ModuleActionButton(title: "图片代理", systemImage: "photo.badge.arrow.down") {
                Task { await rssImageProxy() }
            }
        }
    }

    @ViewBuilder
    private var taskList: some View {
        ForEach(Array(tasks.enumerated()), id: \.offset) { _, t in
            rssTaskCard(t)
        }
    }

    private func rssTaskCard(_ task: JSONValue) -> some View {
        let name = task.firstString("name") ?? "RSS 任务"
        let id = task.firstString("id") ?? ""
        let enabled = task["enabled"].bool ?? true
        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Circle().fill(enabled ? .green : .gray).frame(width: 8, height: 8)
                    Text(name).font(.subheadline.weight(.medium)).lineLimit(1)
                    Spacer()
                }
                LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "立即运行", systemImage: "play.fill", prominent: true) {
                        Task { await runNow(id: id) }
                    }
                    ModuleActionButton(title: "填入", systemImage: "square.and.pencil") {
                        fillTask(task)
                    }
                    ModuleActionButton(title: "预览", systemImage: "eye") {
                        Task {
                            fillTask(task)
                            await preview()
                        }
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

    private var toolbarMenu: some View {
        Menu {
            Button {
                Task { await runNow(id: nil) }
            } label: {
                Label("立即运行全部", systemImage: "play.fill")
            }
            Button {
                Task { await loadPresets(show: true) }
            } label: {
                Label("查看链接预设", systemImage: "link")
            }
            Button {
                Task { await nativeFeed(title: "原生源") }
            } label: {
                Label("读取原生源", systemImage: "antenna.radiowaves.left.and.right")
            }
            Button {
                Task { await load() }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
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
        do {
            show("RSS 运行", try await service.runNow(body))
            await load()
        }
        catch { toast = error.localizedDescription }
    }
    private func loadPresets(show: Bool = false) async {
        do {
            presets = try await service.linkPresets()
            if show { self.show("链接预设", presets) }
        }
        catch { toast = error.localizedDescription }
    }
    private func toggle(_ id: String, _ en: Bool) async { do { try await service.toggleTask(id: id, enabled: en); await load() } catch { toast = error.localizedDescription } }
    private func del(_ id: String) async { do { try await service.deleteTask(id: id); await load() } catch { toast = error.localizedDescription } }

    private func preview() async {
        do {
            guard !rssURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写 RSS URL"])
            }
            show("RSS 预览", try await service.preview(rssURL: rssURL, contentType: contentType, limit: Int(previewLimit) ?? 10))
        } catch { toast = error.localizedDescription }
    }

    private func createTask() async {
        do {
            show("创建任务", try await service.createTask(try taskBody(requireID: false)))
            await load()
        } catch { toast = error.localizedDescription }
    }

    private func updateTask() async {
        do {
            show("更新任务", try await service.updateTask(try taskBody(requireID: true)))
            await load()
        } catch { toast = error.localizedDescription }
    }

    private func saveConfig() async {
        do {
            guard !sourceRoot.isEmpty, !linkRoot.isEmpty else {
                throw APIError.validation(["请填写 source_root 和 link_root"])
            }
            show("RSS 配置保存", try await service.saveConfig(sourceRoot: sourceRoot, linkRoot: linkRoot))
            await load()
        } catch { toast = error.localizedDescription }
    }

    private func buildURL() async {
        do {
            guard !presetID.isEmpty else { throw APIError.validation(["请填写 preset_id"]) }
            show("构建 URL", try await service.buildURL(presetID: presetID, params: try decodeJSONOrEmpty(buildParamsBody), proxy: buildProxy))
        } catch { toast = error.localizedDescription }
    }

    private func nativeFeed(title: String) async {
        do {
            show(title, try await service.native(nativePath, query: try queryFromJSON(nativeQueryBody)))
        } catch { toast = error.localizedDescription }
    }

    private func rssImageProxy() async {
        do {
            guard !rssImageProxyURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写 RSS 图片 URL"])
            }
            show("RSS 图片代理 URL", try service.imageProxyURL(sourceURL: rssImageProxyURL))
        } catch { toast = error.localizedDescription }
    }

    private func runNativePreset(_ title: String, path: String, query: String) async {
        nativePath = path
        nativeQueryBody = query
        await nativeFeed(title: title)
    }

    private func seedConfigFields() {
        sourceRoot = config?.firstString("source_root", "sourceRoot") ?? sourceRoot
        linkRoot = config?.firstString("link_root", "linkRoot") ?? linkRoot
    }

    private func seedTaskBody() {
        rawTaskBody = taskDraft().prettyJSONString()
        resultTitle = "任务 JSON"
        result = .string(rawTaskBody)
        showResult = true
    }

    private func fillTask(_ json: JSONValue) {
        taskID = json.firstString("id") ?? taskID
        taskName = json.firstString("name", "title") ?? taskName
        rssURL = json.firstString("rss_url", "rssURL", "url") ?? rssURL
        taskCron = json.firstString("cron") ?? taskCron
        contentType = json.firstString("content_type", "contentType") ?? contentType
        targetServerIndex = json["target_server_idx"].string ?? targetServerIndex
        taskEnabled = json["enabled"].bool ?? taskEnabled
        syncMissingToMP = json["sync_library_missing_to_mp"].bool ?? syncMissingToMP
        rawTaskBody = json.prettyJSONString()
    }

    private func taskBody(requireID: Bool) throws -> JSONValue {
        if !rawTaskBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let body = try decodeJSON(rawTaskBody)
            if requireID, body["id"].string == nil, taskID.isEmpty {
                throw APIError.validation(["更新任务需要 id"])
            }
            return body
        }
        if requireID, taskID.isEmpty { throw APIError.validation(["更新任务需要 id"]) }
        guard !taskName.isEmpty else { throw APIError.validation(["请填写任务名"]) }
        guard !rssURL.isEmpty else { throw APIError.validation(["请填写 RSS URL"]) }
        guard !taskCron.isEmpty else { throw APIError.validation(["请填写 Cron"]) }
        return taskDraft()
    }

    private func taskDraft() -> JSONValue {
        JSONValue.obj([
            "id": taskID.isEmpty ? nil : taskID,
            "name": taskName,
            "rss_url": rssURL,
            "cron": taskCron,
            "target_server_idx": Int(targetServerIndex) ?? 0,
            "content_type": contentType,
            "sync_library_missing_to_mp": syncMissingToMP,
            "enabled": taskEnabled
        ])
    }

    private func show(_ title: String, _ json: JSONValue?) {
        resultTitle = title
        result = json
        showResult = true
    }

    private func queryFromJSON(_ text: String) throws -> [String: String?] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [:] }
        guard let object = try decodeJSON(text).object else { throw APIError.validation(["查询参数必须是 JSON 对象"]) }
        return object.mapValues { value in
            switch value {
            case .null: return nil
            case .string(let string): return string
            case .number, .bool: return value.string
            case .array, .object: return value.prettyJSONString()
            }
        }
    }

    private func decodeJSONOrEmpty(_ text: String) throws -> JSONValue {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .obj([:]) : try decodeJSON(text)
    }

    private func decodeJSON(_ text: String) throws -> JSONValue {
        guard let data = text.data(using: .utf8) else { throw APIError.decoding("JSON 不是 UTF-8 文本") }
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }
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
    @State private var forwardToken = ""
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
                        ModuleActionButton(title: "流式搜", systemImage: "dot.radiowaves.left.and.right") {
                            Task { await searchStream() }
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
                    TextField("token（播放/组件可选）", text: $forwardToken)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
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
                        ModuleActionButton(title: "播放URL", systemImage: "play.rectangle") {
                            Task { await showPlayURL() }
                        }
                        ModuleActionButton(title: "组件URL", systemImage: "curlybraces.square") {
                            Task { await showWidgetURL() }
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

    private func searchStream() async {
        do {
            let id = try parsedTMDB()
            result = try await service.searchResourcesStream(
                type: forwardType,
                tmdbID: id,
                title: title.isEmpty ? nil : title,
                year: year.isEmpty ? nil : year,
                sources: selectedSources
            )
            resultTitle = "流式搜索"
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

    private func showPlayURL() async {
        do {
            result = try service.playURL(token: forwardToken, source: source, type: forwardType, tmdbID: tmdbID)
            resultTitle = "播放 URL"
            showResult = true
        } catch { toast = error.localizedDescription }
    }

    private func showWidgetURL() async {
        do {
            result = try service.widgetURL(token: forwardToken)
            resultTitle = "组件 URL"
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
    @State private var showFontImporter = false
    @State private var isUploadingFont = false
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
                        ModuleActionButton(title: isUploadingFont ? "上传中" : "上传字体", systemImage: "square.and.arrow.up") {
                            showFontImporter = true
                        }
                        .disabled(isUploadingFont)
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
        .fileImporter(isPresented: $showFontImporter, allowedContentTypes: [.data], allowsMultipleSelection: false) { response in
            switch response {
            case .success(let urls):
                if let url = urls.first {
                    Task { await uploadFont(url) }
                }
            case .failure(let error):
                toast = error.localizedDescription
            }
        }
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

    private func uploadFont(_ url: URL) async {
        isUploadingFont = true
        defer { isUploadingFont = false }
        do {
            result = try await service.uploadFont(fileURL: url)
            resultTitle = "上传字体"
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
