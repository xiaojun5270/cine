import SwiftUI

struct SystemHealthView: View {
    private let service = SystemHealthService()
    @State private var health: JSONValue?
    @State private var network: JSONValue?
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        ModuleScaffold(title: "系统健康", isLoading: isLoading && health == nil, error: health == nil ? error : nil,
                       onRetry: { Task { await load() } }) {
            if let health { JSONKeyValueCard(title: "系统状态", json: health, limit: 24) }
            if let network { JSONKeyValueCard(title: "网络", json: network, limit: 16) }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true; error = nil
        async let h = service.health()
        async let n = service.lastNetwork()
        do { health = try await h } catch { self.error = error }
        network = try? await n
        isLoading = false
    }
}

struct UpgradeView: View {
    private let service = UpgradeService()
    @State private var status: JSONValue?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?

    var body: some View {
        ModuleScaffold(title: "检查更新", isLoading: isLoading && status == nil, error: status == nil ? error : nil,
                       onRetry: { Task { await load() } }) {
            if let status { JSONKeyValueCard(title: "版本状态", json: status, limit: 16) }
            GlassCard {
                VStack(spacing: 10) {
                    GlassPrimaryButton(title: "检查更新", systemImage: "arrow.down.circle") { Task { await check() } }
                    ModuleActionButton(title: "开始升级", systemImage: "square.and.arrow.down", prominent: true) { Task { await start() } }
                }
            }
        }
        .task { await load() }
        .toast($toast)
    }

    private func load() async {
        isLoading = true; error = nil
        do { status = try await service.status() } catch { self.error = error }
        isLoading = false
    }
    private func check() async {
        do { status = try await service.check(force: true); toast = "检查完成" } catch { toast = error.localizedDescription }
    }
    private func start() async {
        do { try await service.start(); toast = "已开始升级" } catch { toast = error.localizedDescription }
    }
}

struct WebhookView: View {
    private let service = WebhookService()
    @State private var config: JSONValue?
    @State private var queue: JSONValue?
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        ModuleScaffold(title: "Webhook", isLoading: isLoading && config == nil, error: config == nil ? error : nil,
                       onRetry: { Task { await load() } }) {
            if let config { JSONKeyValueCard(title: "配置", json: config, limit: 16) }
            if let queue { JSONKeyValueCard(title: "队列", json: queue, limit: 12) }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true; error = nil
        async let c = service.config()
        async let q = service.queue()
        do { config = try await c } catch { self.error = error }
        queue = try? await q
        isLoading = false
    }
}

struct TransferView: View {
    private let service = TransferService()
    @State private var history: JSONValue?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?
    @State private var link = ""

    var body: some View {
        ModuleScaffold(title: "手动转移", isLoading: isLoading && history == nil, error: history == nil ? error : nil,
                       onRetry: { Task { await load() } }) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("手动添加链接").font(.headline)
                    TextField("分享 / 资源链接", text: $link)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                    GlassPrimaryButton(title: "提交转移", systemImage: "tray.and.arrow.down") { Task { await submit() } }
                        .disabled(link.isEmpty)
                }
            }
            if let history { JSONKeyValueCard(title: "转移历史", json: history, limit: 20) }
        }
        .task { await load() }
        .toast($toast)
    }

    private func load() async {
        isLoading = true; error = nil
        do { history = try await service.history() } catch { self.error = error }
        isLoading = false
    }
    private func submit() async {
        do { _ = try await service.manual(link: link); toast = "已提交"; link = ""; await load() }
        catch { toast = error.localizedDescription }
    }
}
