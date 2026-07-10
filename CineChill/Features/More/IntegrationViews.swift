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
    @State private var memory: JSONValue?
    @State private var reminders: [JSONValue] = []
    @State private var audit: [JSONValue] = []
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        ModuleScaffold(title: "AI 剧集识别", isLoading: isLoading && config == nil, error: config == nil ? error : nil,
                       onRetry: { Task { await load() } }) {
            if let runtime { JSONKeyValueCard(title: "运行时", json: runtime, limit: 12) }
            if let config { JSONKeyValueCard(title: "配置", json: config, limit: 20) }
            if !reminders.isEmpty {
                SectionHeader(title: "提醒")
                ForEach(Array(reminders.prefix(10).enumerated()), id: \.offset) { _, reminder in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(reminder.firstString("title", "message", "content", "text") ?? "提醒")
                                .font(.subheadline.weight(.medium)).lineLimit(2)
                            if let status = reminder.firstString("status", "state") {
                                StatusChip(text: status, ok: status != "cancelled")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            if let memory { JSONKeyValueCard(title: "助手记忆", json: memory, limit: 20) }
            if !audit.isEmpty {
                SectionHeader(title: "审计记录")
                ForEach(Array(audit.prefix(20).enumerated()), id: \.offset) { _, a in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(a.firstString("action", "type", "event", "title") ?? "记录")
                                .font(.subheadline.weight(.medium)).lineLimit(1)
                            if let t = a.firstString("time", "created_at", "timestamp") {
                                Text(t).font(.caption2).foregroundStyle(.secondary)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true; error = nil
        async let c = service.config()
        async let r = service.runtime()
        async let a = service.audit()
        async let m = service.memory()
        async let reminders = service.reminders()
        do { config = try await c } catch { self.error = error }
        runtime = try? await r
        audit = (try? await a)?.items() ?? []
        memory = try? await m
        self.reminders = (try? await reminders)?.items() ?? []
        isLoading = false
    }
}
