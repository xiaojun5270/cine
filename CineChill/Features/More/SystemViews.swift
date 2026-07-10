import SwiftUI

struct SystemHealthView: View {
    private let service = SystemHealthService()
    @State private var health: JSONValue?
    @State private var network: JSONValue?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?
    @State private var targetID = ""
    @State private var result: JSONValue?
    @State private var resultTitle = "结果"
    @State private var showResult = false

    var body: some View {
        ModuleScaffold(title: "系统健康", isLoading: isLoading && health == nil, error: health == nil ? error : nil,
                       onRetry: { Task { await load() } }, toolbarContent: AnyView(toolbarMenu)) {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("目标检测").font(.headline)
                    TextField("target_id（留空检测默认目标）", text: $targetID)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
                        ModuleActionButton(title: "健康检测", systemImage: "waveform.path.ecg", prominent: true) {
                            Task { await healthCheck() }
                        }
                        ModuleActionButton(title: "网络快检", systemImage: "network") {
                            Task { await networkCheck(full: false) }
                        }
                        ModuleActionButton(title: "网络全检", systemImage: "antenna.radiowaves.left.and.right") {
                            Task { await networkCheck(full: true) }
                        }
                    }
                }
            }
            if let health { JSONKeyValueCard(title: "系统状态", json: health, limit: 24) }
            if let network { JSONKeyValueCard(title: "网络", json: network, limit: 16) }
        }
        .task { await load() }
        .toast($toast)
        .sheet(isPresented: $showResult) { JSONResultSheet(title: resultTitle, json: result) }
    }

    private var toolbarMenu: some View {
        Menu {
            Button {
                Task { await showTargets() }
            } label: {
                Label("健康目标列表", systemImage: "list.bullet.rectangle")
            }
            Button {
                Task { await showNetworkTargets() }
            } label: {
                Label("网络目标列表", systemImage: "point.3.connected.trianglepath.dotted")
            }
            Button {
                Task { await networkCheck(full: true) }
            } label: {
                Label("立即全量网络检测", systemImage: "bolt.horizontal")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private func load() async {
        isLoading = true; error = nil
        async let h = service.health()
        async let n = service.lastNetwork()
        do { health = try await h } catch { self.error = error }
        network = try? await n
        isLoading = false
    }

    private func healthCheck() async {
        do {
            result = try await service.health(targetID: targetID.isEmpty ? nil : targetID)
            resultTitle = "健康检测"
            showResult = true
            health = result
        } catch { toast = error.localizedDescription }
    }

    private func networkCheck(full: Bool) async {
        do {
            result = try await service.network(targetID: targetID.isEmpty ? nil : targetID, full: full)
            resultTitle = full ? "网络全检" : "网络快检"
            showResult = true
            network = result
        } catch { toast = error.localizedDescription }
    }

    private func showTargets() async {
        do {
            result = try await service.targets()
            resultTitle = "健康目标"
            showResult = true
        } catch { toast = error.localizedDescription }
    }

    private func showNetworkTargets() async {
        do {
            result = try await service.networkTargets(full: true)
            resultTitle = "网络目标"
            showResult = true
        } catch { toast = error.localizedDescription }
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
    @State private var toast: String?
    @State private var rawConfigBody = ""
    @State private var result: JSONValue?
    @State private var showResult = false

    var body: some View {
        ModuleScaffold(title: "Webhook", isLoading: isLoading && config == nil, error: config == nil ? error : nil,
                       onRetry: { Task { await load() } }) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("配置编辑").font(.headline)
                    TextField("Webhook 配置 JSON", text: $rawConfigBody, axis: .vertical)
                        .lineLimit(3...8)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
                        ModuleActionButton(title: "测试事件", systemImage: "bolt.horizontal.circle") {
                            Task { await trigger() }
                        }
                        ModuleActionButton(title: "填入当前", systemImage: "square.and.pencil") {
                            seedConfigBody()
                        }
                        ModuleActionButton(title: "保存配置", systemImage: "square.and.arrow.down", prominent: true) {
                            Task { await saveConfig() }
                        }
                    }
                }
            }
            if let config { JSONKeyValueCard(title: "配置", json: config, limit: 16) }
            if let queue { JSONKeyValueCard(title: "队列", json: queue, limit: 12) }
        }
        .task { await load() }
        .toast($toast)
        .sheet(isPresented: $showResult) { JSONResultSheet(title: "Webhook 结果", json: result) }
    }

    private func load() async {
        isLoading = true; error = nil
        async let c = service.config()
        async let q = service.queue()
        do { config = try await c } catch { self.error = error }
        queue = try? await q
        isLoading = false
    }
    private func trigger() async {
        do { _ = try await service.trigger(); toast = "已发送测试事件"; await load() }
        catch { toast = error.localizedDescription }
    }
    private func seedConfigBody() {
        rawConfigBody = config?.prettyJSONString() ?? """
        {"enabled":false,"engine":"classic","preset":"","mode":"random","delete_sync_enabled":true}
        """
    }
    private func saveConfig() async {
        do {
            guard !rawConfigBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写 Webhook 配置 JSON"])
            }
            result = try await service.saveConfig(try JSONValue.parse(rawConfigBody))
            showResult = true
            await load()
        } catch { toast = error.localizedDescription }
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
                       onRetry: { Task { await load() } }, toolbarContent: AnyView(toolbarMenu)) {
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

    private var toolbarMenu: some View {
        Menu {
            Button(role: .destructive) {
                Task { await clearHistory() }
            } label: {
                Label("清空转移历史", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
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
    private func clearHistory() async {
        do { try await service.clearHistory(); toast = "已清空转移历史"; await load() }
        catch { toast = error.localizedDescription }
    }
}
