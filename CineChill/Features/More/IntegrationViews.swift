import SwiftUI

struct Config302View: View {
    private let service = Config302Service()
    @State private var config: JSONValue?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?
    @State private var cookie = ""

    var body: some View {
        ModuleScaffold(title: "302 / 115 配置", isLoading: isLoading && config == nil, error: config == nil ? error : nil,
                       onRetry: { Task { await load() } }) {
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
            if let config { JSONKeyValueCard(title: "当前配置", json: config, limit: 20) }
        }
        .task { await load() }
        .toast($toast)
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
}

struct AIResolverView: View {
    private let service = AIResolverService()
    @State private var config: JSONValue?
    @State private var runtime: JSONValue?
    @State private var audit: [JSONValue] = []
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        ModuleScaffold(title: "AI 剧集识别", isLoading: isLoading && config == nil, error: config == nil ? error : nil,
                       onRetry: { Task { await load() } }) {
            if let runtime { JSONKeyValueCard(title: "运行时", json: runtime, limit: 12) }
            if let config { JSONKeyValueCard(title: "配置", json: config, limit: 20) }
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
        do { config = try await c } catch { self.error = error }
        runtime = try? await r
        audit = (try? await a)?.items() ?? []
        isLoading = false
    }
}
