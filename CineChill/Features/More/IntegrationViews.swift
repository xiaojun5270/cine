import SwiftUI

struct Config302View: View {
    private let service = Config302Service()
    @State private var config: JSONValue?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?
    @State private var cookie = ""
    @State private var qrApp = "115android"
    @State private var localMediaRoot = ""
    @State private var detail: JSONValue?
    @State private var detailTitle = "结果"
    @State private var showDetail = false

    var body: some View {
        ModuleScaffold(title: "302 / 115 配置", isLoading: isLoading && config == nil, error: config == nil ? error : nil,
                       onRetry: { Task { await load() } }, toolbarContent: AnyView(toolbarMenu)) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("115 Cookie 测试").font(.headline)
                    TextField("粘贴 115 Cookie", text: $cookie, axis: .vertical)
                        .lineLimit(1...4)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                    HStack(spacing: 10) {
                        ModuleActionButton(title: "测试 Cookie", systemImage: "checkmark.shield", prominent: true) {
                            Task { await testCookie() }
                        }
                        ModuleActionButton(title: "全部签到", systemImage: "checkmark.seal") {
                            Task { await signinAll() }
                        }
                    }
                }
            }
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("115 扫码登录").font(.headline)
                    TextField("App 标识，例如 115android", text: $qrApp)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                    HStack(spacing: 10) {
                        ModuleActionButton(title: "应用列表", systemImage: "list.bullet") {
                            Task { await showApps() }
                        }
                        ModuleActionButton(title: "生成二维码", systemImage: "qrcode", prominent: true) {
                            Task { await startQRCode() }
                        }
                    }
                }
            }
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("目录拓扑").font(.headline)
                    TextField("本地媒体根目录", text: $localMediaRoot)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                    ModuleActionButton(title: "创建标准目录", systemImage: "folder.badge.plus", prominent: true) {
                        Task { await ensureDirs() }
                    }
                    .disabled(localMediaRoot.isEmpty)
                }
            }
            if let config { JSONKeyValueCard(title: "当前配置", json: config, limit: 20) }
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
            Button {
                Task { await signinAll() }
            } label: {
                Label("全部签到", systemImage: "checkmark.seal")
            }
            Button(role: .destructive) {
                Task { await manualCleanup() }
            } label: {
                Label("手动清理 115", systemImage: "trash")
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
    private func testCookie() async {
        guard !cookie.isEmpty else { return }
        do { let r = try await service.test115(cookie: cookie); toast = r.firstString("message", "msg") ?? "测试完成" }
        catch { toast = error.localizedDescription }
    }
    private func signinAll() async {
        do { try await service.manualSigninAll(); toast = "已触发全部签到" } catch { toast = error.localizedDescription }
    }
    private func showApps() async {
        do {
            detail = try await service.qrcodeApps()
            detailTitle = "扫码应用"
            showDetail = true
        } catch { toast = error.localizedDescription }
    }
    private func startQRCode() async {
        do {
            detail = try await service.qrcodeStart(app: qrApp.isEmpty ? "115android" : qrApp)
            detailTitle = "扫码二维码"
            showDetail = true
        } catch { toast = error.localizedDescription }
    }
    private func ensureDirs() async {
        do {
            detail = try await service.ensureStandardDirs(localMediaRoot: localMediaRoot)
            detailTitle = "目录创建结果"
            showDetail = true
        } catch { toast = error.localizedDescription }
    }
    private func manualCleanup() async {
        do {
            detail = try await service.manualCleanup()
            detailTitle = "清理结果"
            showDetail = true
        } catch { toast = error.localizedDescription }
    }
}

struct FnosSignView: View {
    private let service = FnosSignService()
    @State private var state: JSONValue?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?
    @State private var cookie = ""

    var body: some View {
        ModuleScaffold(title: "飞牛签到", isLoading: isLoading && state == nil, error: state == nil ? error : nil,
                       onRetry: { Task { await load() } }) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("操作").font(.headline)
                    HStack(spacing: 10) {
                        ModuleActionButton(title: "立即签到", systemImage: "checkmark.seal.fill", prominent: true) {
                            Task { await run() }
                        }
                        ModuleActionButton(title: "清空历史", systemImage: "trash", role: .destructive) {
                            Task { await clearHistory() }
                        }
                    }
                    TextField("测试 Cookie（可选）", text: $cookie, axis: .vertical)
                        .lineLimit(1...3)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                    ModuleActionButton(title: "测试 Cookie", systemImage: "checkmark.shield") {
                        Task { await testCookie() }
                    }
                }
            }
            if let state { JSONKeyValueCard(title: "签到状态", json: state, limit: 20) }
        }
        .task { await load() }
        .toast($toast)
    }

    private func load() async {
        isLoading = true; error = nil
        do { state = try await service.state() } catch { self.error = error }
        isLoading = false
    }
    private func run() async {
        do { _ = try await service.run(force: true); toast = "已触发签到"; await load() } catch { toast = error.localizedDescription }
    }
    private func testCookie() async {
        guard !cookie.isEmpty else { return }
        do { let r = try await service.testCookie(cookie); toast = r.firstString("message", "msg") ?? "测试完成" }
        catch { toast = error.localizedDescription }
    }
    private func clearHistory() async {
        do { try await service.clearHistory(); toast = "已清空签到历史"; await load() }
        catch { toast = error.localizedDescription }
    }
}

struct AIResolverView: View {
    private let service = AIResolverService()
    @State private var config: JSONValue?
    @State private var runtime: JSONValue?
    @State private var context: JSONValue?
    @State private var memory: JSONValue?
    @State private var memoryProfile: JSONValue?
    @State private var toolPermissions: JSONValue?
    @State private var reminders: [JSONValue] = []
    @State private var audit: [JSONValue] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?
    @State private var result: JSONValue?
    @State private var resultTitle = "结果"
    @State private var showResult = false
    @State private var rawConfigBody = ""
    @State private var rawTestBody = ""
    @State private var rawPermissionBody = ""
    @State private var rawMemoryProfileBody = ""
    @State private var rawReminderBody = ""
    @State private var reminderID = ""

    private let buttonColumns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        ModuleScaffold(title: "AI 剧集识别", isLoading: isLoading && config == nil, error: config == nil ? error : nil,
                       onRetry: { Task { await load() } }, toolbarContent: AnyView(toolbarMenu)) {
            Group {
                operationCard
                configJSONCard
                memoryToolsCard
                reminderEditorCard
                if let runtime { JSONKeyValueCard(title: "运行时", json: runtime, limit: 12) }
                if let context { JSONKeyValueCard(title: "上下文", json: context, limit: 12) }
                if let config { JSONKeyValueCard(title: "配置", json: config, limit: 20) }
            }
            Group {
                reminderList
                if let memory { JSONKeyValueCard(title: "助手记忆", json: memory, limit: 20) }
                if let memoryProfile { JSONKeyValueCard(title: "记忆画像", json: memoryProfile, limit: 20) }
                if let toolPermissions { JSONKeyValueCard(title: "工具权限", json: toolPermissions, limit: 20) }
                auditList
            }
        }
        .task { await load() }
        .toast($toast)
        .sheet(isPresented: $showResult) { JSONResultSheet(title: resultTitle, json: result) }
    }

    private var operationCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("接口操作").font(.headline)
                LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "运行时", systemImage: "gauge") { Task { await showRuntime() } }
                    ModuleActionButton(title: "上下文", systemImage: "text.bubble") { Task { await showContext() } }
                    ModuleActionButton(title: "模型列表", systemImage: "cpu") { Task { await models() } }
                    ModuleActionButton(title: "测试", systemImage: "checkmark.shield", prominent: true) { Task { await testResolver() } }
                    ModuleActionButton(title: "工具权限", systemImage: "wrench.and.screwdriver") { Task { await showToolPermissions() } }
                    ModuleActionButton(title: "记忆画像", systemImage: "person.text.rectangle") { Task { await showMemoryProfile() } }
                }
            }
        }
    }

    private var configJSONCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("配置与测试 JSON").font(.headline)
                TextField("配置 JSON", text: $rawConfigBody, axis: .vertical)
                    .lineLimit(2...8)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("模型/测试 JSON（可留空）", text: $rawTestBody, axis: .vertical)
                    .lineLimit(2...6)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "填入配置", systemImage: "doc.badge.gearshape") { seedConfigBody() }
                    ModuleActionButton(title: "保存配置", systemImage: "square.and.arrow.down", prominent: true) { Task { await saveConfig() } }
                    ModuleActionButton(title: "模型列表", systemImage: "list.bullet.rectangle") { Task { await models() } }
                    ModuleActionButton(title: "测试识别", systemImage: "wand.and.stars") { Task { await testResolver() } }
                }
            }
        }
    }

    private var memoryToolsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("工具与记忆").font(.headline)
                TextField("工具权限 JSON", text: $rawPermissionBody, axis: .vertical)
                    .lineLimit(2...8)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("记忆画像 JSON", text: $rawMemoryProfileBody, axis: .vertical)
                    .lineLimit(2...8)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "读取权限", systemImage: "lock.doc") { Task { await showToolPermissions() } }
                    ModuleActionButton(title: "保存权限", systemImage: "lock.shield", prominent: true) { Task { await saveToolPermissions() } }
                    ModuleActionButton(title: "读取画像", systemImage: "person.text.rectangle") { Task { await showMemoryProfile() } }
                    ModuleActionButton(title: "保存画像", systemImage: "person.crop.circle.badge.checkmark") { Task { await saveMemoryProfile() } }
                }
            }
        }
    }

    private var reminderEditorCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("提醒操作").font(.headline)
                TextField("reminder_id（更新/取消/删除时填写）", text: $reminderID)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("提醒 JSON", text: $rawReminderBody, axis: .vertical)
                    .lineLimit(2...8)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "模板", systemImage: "doc.badge.plus") { seedReminderBody() }
                    ModuleActionButton(title: "创建", systemImage: "plus.circle", prominent: true) { Task { await createReminder() } }
                    ModuleActionButton(title: "更新", systemImage: "square.and.pencil") { Task { await updateReminder() } }
                        .disabled(reminderID.isEmpty)
                    ModuleActionButton(title: "取消", systemImage: "xmark.circle") { Task { await cancelReminder(reminderID) } }
                        .disabled(reminderID.isEmpty)
                    ModuleActionButton(title: "删除", systemImage: "trash", role: .destructive) { Task { await deleteReminder(reminderID) } }
                        .disabled(reminderID.isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private var reminderList: some View {
        if !reminders.isEmpty {
            SectionHeader(title: "提醒")
            ForEach(Array(reminders.prefix(10).enumerated()), id: \.offset) { _, reminder in
                reminderCard(reminder)
            }
        }
    }

    private func reminderCard(_ reminder: JSONValue) -> some View {
        let id = reminder.firstString("id", "reminder_id", "_id") ?? ""
        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(reminder.firstString("title", "message", "content", "text") ?? "提醒")
                    .font(.subheadline.weight(.medium)).lineLimit(2)
                HStack(spacing: 8) {
                    if let status = reminder.firstString("status", "state") {
                        StatusChip(text: status, ok: status != "cancelled")
                    }
                    if let time = reminder.firstString("time", "due_at", "created_at", "updated_at") {
                        Text(time).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "填入", systemImage: "square.and.pencil") {
                        reminderID = id
                        rawReminderBody = reminder.prettyJSONString()
                    }
                    ModuleActionButton(title: "取消", systemImage: "xmark.circle") {
                        Task { await cancelReminder(id) }
                    }
                    .disabled(id.isEmpty)
                    ModuleActionButton(title: "删除", systemImage: "trash", role: .destructive) {
                        Task { await deleteReminder(id) }
                    }
                    .disabled(id.isEmpty)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var auditList: some View {
        if !audit.isEmpty {
            SectionHeader(title: "审计记录")
            ForEach(Array(audit.prefix(20).enumerated()), id: \.offset) { _, item in
                auditCard(item)
            }
        }
    }

    private func auditCard(_ item: JSONValue) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.firstString("action", "type", "event", "title") ?? "记录")
                    .font(.subheadline.weight(.medium)).lineLimit(1)
                if let time = item.firstString("time", "created_at", "timestamp") {
                    Text(time).font(.caption2).foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var toolbarMenu: some View {
        Menu {
            Button {
                seedConfigBody()
            } label: {
                Label("填入配置 JSON", systemImage: "doc.badge.gearshape")
            }
            Button {
                Task { await showContext() }
            } label: {
                Label("读取上下文", systemImage: "text.bubble")
            }
            Button {
                Task { await showToolPermissions() }
            } label: {
                Label("读取工具权限", systemImage: "wrench.and.screwdriver")
            }
            Button {
                Task { await load() }
            } label: {
                Label("刷新全部", systemImage: "arrow.clockwise")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private func load() async {
        isLoading = true; error = nil
        async let c = service.config()
        async let r = service.runtime()
        async let a = service.audit()
        async let m = service.memory()
        async let p = service.memoryProfile()
        async let perms = service.toolPermissions()
        async let reminders = service.reminders()
        do { config = try await c } catch { self.error = error }
        runtime = try? await r
        audit = (try? await a)?.items() ?? []
        memory = try? await m
        memoryProfile = try? await p
        toolPermissions = try? await perms
        self.reminders = (try? await reminders)?.items() ?? []
        isLoading = false
    }

    private func showRuntime() async {
        do {
            runtime = try await service.runtime()
            show("运行时", runtime)
        } catch { toast = error.localizedDescription }
    }

    private func showContext() async {
        do {
            context = try await service.context()
            show("上下文", context)
        } catch { toast = error.localizedDescription }
    }

    private func showToolPermissions() async {
        do {
            toolPermissions = try await service.toolPermissions()
            rawPermissionBody = toolPermissions?.prettyJSONString() ?? ""
            show("工具权限", toolPermissions)
        } catch { toast = error.localizedDescription }
    }

    private func showMemoryProfile() async {
        do {
            memoryProfile = try await service.memoryProfile()
            rawMemoryProfileBody = memoryProfile?.prettyJSONString() ?? ""
            show("记忆画像", memoryProfile)
        } catch { toast = error.localizedDescription }
    }

    private func models() async {
        do {
            let body = try decodeJSONOrEmpty(rawTestBody)
            show("模型列表", try await service.models(body))
        } catch { toast = error.localizedDescription }
    }

    private func testResolver() async {
        do {
            show("测试结果", try await service.test(try decodeJSONOrEmpty(rawTestBody)))
        } catch { toast = error.localizedDescription }
    }

    private func saveConfig() async {
        do {
            guard !rawConfigBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填入配置 JSON"])
            }
            show("配置保存", try await service.saveConfig(try decodeJSON(rawConfigBody)))
            await load()
        } catch { toast = error.localizedDescription }
    }

    private func saveToolPermissions() async {
        do {
            guard !rawPermissionBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先读取或填写工具权限 JSON"])
            }
            show("权限保存", try await service.saveToolPermissions(try decodeJSON(rawPermissionBody)))
            await load()
        } catch { toast = error.localizedDescription }
    }

    private func saveMemoryProfile() async {
        do {
            guard !rawMemoryProfileBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先读取或填写记忆画像 JSON"])
            }
            show("画像保存", try await service.saveMemoryProfile(try decodeJSON(rawMemoryProfileBody)))
            await load()
        } catch { toast = error.localizedDescription }
    }

    private func createReminder() async {
        do {
            guard !rawReminderBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写提醒 JSON"])
            }
            show("提醒创建", try await service.createReminder(try decodeJSON(rawReminderBody)))
            await load()
        } catch { toast = error.localizedDescription }
    }

    private func updateReminder() async {
        do {
            guard !reminderID.isEmpty else { throw APIError.validation(["请先填写 reminder_id"]) }
            guard !rawReminderBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写提醒 JSON"])
            }
            show("提醒更新", try await service.updateReminder(id: reminderID, try decodeJSON(rawReminderBody)))
            await load()
        } catch { toast = error.localizedDescription }
    }

    private func cancelReminder(_ id: String) async {
        do {
            guard !id.isEmpty else { throw APIError.validation(["请先填写 reminder_id"]) }
            show("提醒取消", try await service.cancelReminder(id: id))
            await load()
        } catch { toast = error.localizedDescription }
    }

    private func deleteReminder(_ id: String) async {
        do {
            guard !id.isEmpty else { throw APIError.validation(["请先填写 reminder_id"]) }
            show("提醒删除", try await service.deleteReminder(id: id))
            await load()
        } catch { toast = error.localizedDescription }
    }

    private func seedConfigBody() {
        rawConfigBody = config?.prettyJSONString() ?? """
        {"enabled":true,"proxy_enabled":false,"media_identity_enabled":true,"tmdb_episode_verify_enabled":true,"assistant_tools_enabled":true,"assistant_context_compression_enabled":true,"assistant_context_compression_threshold":0.5,"assistant_context_target_ratio":0.2,"assistant_context_protect_recent":20,"assistant_context_protect_head":3,"model_context_length":0,"base_url":"","api_key":"","model":""}
        """
    }

    private func seedReminderBody() {
        rawReminderBody = """
        {"title":"","message":"","due_at":"","metadata":{}}
        """
    }

    private func show(_ title: String, _ json: JSONValue?) {
        resultTitle = title
        result = json
        showResult = true
    }

    private func decodeJSONOrEmpty(_ text: String) throws -> JSONValue {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .obj([:]) : try decodeJSON(text)
    }

    private func decodeJSON(_ text: String) throws -> JSONValue {
        guard let data = text.data(using: .utf8) else { throw APIError.decoding("JSON 不是 UTF-8 文本") }
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }
}
