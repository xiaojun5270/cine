import SwiftUI

@MainActor
@Observable
final class NotifyViewModel {
    var channels: [NotifyChannel] = []
    var telegramConnected = false
    var wechatEnabled = false
    var telegramConfig: JSONValue?
    var wechatConfig: JSONValue?
    var telegramDialogs: JSONValue?
    var types: JSONValue?
    var defaultTemplates: JSONValue?
    var isLoading = false
    var error: Error?
    var toast: String?

    private let service = NotifyService()

    func load() async {
        isLoading = true
        error = nil
        async let ch = service.channels()
        async let tg = service.telegramStatus()
        async let wc = service.wechatConfig()
        async let tgConfig = service.telegramConfig()
        async let dialogs = service.telegramDialogs()
        async let types = service.types()
        async let templates = service.defaultTemplates()
        let channels = try? await ch
        let tgStatus = try? await tg
        let wcConfig = try? await wc
        telegramConfig = try? await tgConfig
        telegramDialogs = try? await dialogs
        self.types = try? await types
        defaultTemplates = try? await templates
        wechatConfig = wcConfig
        self.channels = channels ?? []
        telegramConnected = tgStatus?["connected"].bool ?? tgStatus?["logged_in"].bool ?? false
        wechatEnabled = wcConfig?["enabled"].bool ?? false
        if channels == nil && tgStatus == nil && wcConfig == nil {
            error = APIError.transport("无法获取通知配置")
        }
        isLoading = false
    }

    func testTelegram() async {
        do { try await service.telegramTest(); toast = "已发送 Telegram 测试消息" }
        catch { self.error = error }
    }
    func testWechat() async {
        do { try await service.wechatTest(); toast = "已发送微信测试消息" }
        catch { self.error = error }
    }
    func saveTelegram(_ body: JSONValue) async {
        do {
            telegramConfig = try await service.saveTelegramConfig(body)
            toast = "Telegram 配置已保存"
            await load()
        } catch { toast = error.localizedDescription }
    }
    func saveWechat(_ body: JSONValue) async {
        do {
            wechatConfig = try await service.saveWechatConfig(body)
            toast = "企业微信配置已保存"
            await load()
        } catch { toast = error.localizedDescription }
    }
    func saveTelegramDialogs(_ body: JSONValue) async {
        do {
            telegramDialogs = try await service.saveTelegramDialogs(body)
            toast = "Telegram 对话已保存"
            await load()
        } catch { toast = error.localizedDescription }
    }
}

struct NotifyView: View {
    @State private var model = NotifyViewModel()
    @State private var rawTelegramBody = ""
    @State private var rawWechatBody = ""
    @State private var rawDialogsBody = ""
    @State private var rawTelegramCodeBody = ""
    @State private var rawTelegramSignInBody = ""
    @State private var telegramMessage = ""
    @State private var telegramAvatarFilename = ""
    @State private var wechatMessage = ""
    @State private var wechatCallbackSignature = ""
    @State private var wechatCallbackTimestamp = ""
    @State private var wechatCallbackNonce = ""
    @State private var wechatCallbackEcho = ""
    @State private var result: JSONValue?
    @State private var resultTitle = "结果"
    @State private var showResult = false

    private let service = NotifyService()

    var body: some View {
        Group {
            if model.isLoading && model.channels.isEmpty {
                LoadingView()
            } else if let error = model.error, model.channels.isEmpty {
                ErrorStateView(error: error) { Task { await model.load() } }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        integrationCard(
                            title: "Telegram",
                            icon: "paperplane.fill",
                            connected: model.telegramConnected,
                            test: { await model.testTelegram() }
                        )
                        integrationCard(
                            title: "企业微信",
                            icon: "message.fill",
                            connected: model.wechatEnabled,
                            test: { await model.testWechat() }
                        )

                        configEditorCard
                        notificationToolsCard

                        if let config = model.telegramConfig {
                            JSONKeyValueCard(title: "Telegram 配置", json: config, limit: 12)
                        }
                        if let config = model.wechatConfig {
                            JSONKeyValueCard(title: "企业微信配置", json: config, limit: 12)
                        }
                        if let dialogs = model.telegramDialogs {
                            JSONKeyValueCard(title: "Telegram 对话", json: dialogs, limit: 12)
                        }
                        if let types = model.types {
                            JSONKeyValueCard(title: "通知类型", json: types, limit: 18)
                        }
                        if let templates = model.defaultTemplates {
                            JSONKeyValueCard(title: "默认模板", json: templates, limit: 18)
                        }

                        if !model.channels.isEmpty {
                            SectionHeader(title: "通知渠道")
                            ForEach(model.channels) { channel in
                                GlassCard {
                                    HStack(spacing: 12) {
                                        IconBadge(systemImage: channel.enabled ? "bell.badge.fill" : "bell.slash.fill",
                                                  tint: channel.enabled ? Theme.accent : .gray,
                                                  size: 38)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(channel.name)
                                                .font(.subheadline.weight(.semibold))
                                                .lineLimit(2)
                                                .minimumScaleFactor(0.82)
                                                .allowsTightening(true)
                                            Text(channel.enabled ? "可用于发送通知" : "当前未启用")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                        .layoutPriority(1)
                                        Spacer()
                                        GlassPill(channel.enabled ? "已启用" : "未启用",
                                                  systemImage: channel.enabled ? "checkmark.circle.fill" : "pause.circle",
                                                  tint: channel.enabled ? Theme.success : .gray)
                                    }
                                }
                            }
                        }
                    }
                    .padding(Theme.screenPadding)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .navigationTitle("通知")
        .appLiquidNavigationChrome()
        .refreshable { await model.load() }
        .task { if model.channels.isEmpty { await model.load() } }
        .sheet(isPresented: $showResult) { JSONResultSheet(title: resultTitle, json: result) }
        .alert("提示", isPresented: Binding(
            get: { model.toast != nil }, set: { if !$0 { model.toast = nil } }
        )) { Button("好", role: .cancel) {} } message: { Text(model.toast ?? "") }
    }

    private var configEditorCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("通知配置编辑").font(.headline)
                TextField("Telegram 配置 JSON", text: $rawTelegramBody, axis: .vertical)
                    .lineLimit(2...8)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("企业微信配置 JSON", text: $rawWechatBody, axis: .vertical)
                    .lineLimit(2...8)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("Telegram 对话 JSON", text: $rawDialogsBody, axis: .vertical)
                    .lineLimit(2...8)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "填 Telegram", systemImage: "square.and.pencil") {
                        rawTelegramBody = model.telegramConfig?.prettyJSONString() ?? telegramTemplate
                    }
                    ModuleActionButton(title: "保存 Telegram", systemImage: "paperplane", prominent: true) {
                        Task { await saveTelegram() }
                    }
                    ModuleActionButton(title: "填微信", systemImage: "square.and.pencil") {
                        rawWechatBody = model.wechatConfig?.prettyJSONString() ?? wechatTemplate
                    }
                    ModuleActionButton(title: "保存微信", systemImage: "message.fill") {
                        Task { await saveWechat() }
                    }
                    ModuleActionButton(title: "填对话", systemImage: "bubble.left.and.bubble.right") {
                        rawDialogsBody = model.telegramDialogs?.prettyJSONString() ?? dialogsTemplate
                    }
                    ModuleActionButton(title: "保存对话", systemImage: "tray.and.arrow.down") {
                        Task { await saveDialogs() }
                    }
                }
            }
        }
    }

    private var notificationToolsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("通知动作").font(.headline)
                HStack(spacing: 10) {
                    TextField("Telegram 消息", text: $telegramMessage)
                    TextField("企业微信消息", text: $wechatMessage)
                }
                .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("Telegram avatar filename", text: $telegramAvatarFilename)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("Telegram 发验证码 JSON", text: $rawTelegramCodeBody, axis: .vertical)
                    .lineLimit(2...5)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("Telegram 登录 JSON", text: $rawTelegramSignInBody, axis: .vertical)
                    .lineLimit(2...5)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                HStack(spacing: 10) {
                    TextField("msg_signature", text: $wechatCallbackSignature)
                    TextField("timestamp", text: $wechatCallbackTimestamp)
                }
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                HStack(spacing: 10) {
                    TextField("nonce", text: $wechatCallbackNonce)
                    TextField("echostr", text: $wechatCallbackEcho)
                }
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 94), spacing: 8)], alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "TG发送", systemImage: "paperplane", prominent: true) {
                        Task { await sendTelegram() }
                    }
                    ModuleActionButton(title: "发码模板", systemImage: "doc.badge.plus") {
                        seedTelegramCode()
                    }
                    ModuleActionButton(title: "发验证码", systemImage: "number.circle") {
                        Task { await sendTelegramCode() }
                    }
                    ModuleActionButton(title: "登录模板", systemImage: "doc.badge.gearshape") {
                        seedTelegramSignIn()
                    }
                    ModuleActionButton(title: "登录", systemImage: "person.crop.circle.badge.checkmark") {
                        Task { await signInTelegram() }
                    }
                    ModuleActionButton(title: "登出", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        Task { await logoutTelegram() }
                    }
                    ModuleActionButton(title: "头像URL", systemImage: "person.crop.square") {
                        Task { await telegramAvatarURL() }
                    }
                    ModuleActionButton(title: "微信发送", systemImage: "message", prominent: true) {
                        Task { await sendWechat() }
                    }
                    ModuleActionButton(title: "微信类型", systemImage: "list.bullet") {
                        Task { await showWechatTypes() }
                    }
                    ModuleActionButton(title: "回调验证", systemImage: "checkmark.shield") {
                        Task { await verifyWechatCallback() }
                    }
                    ModuleActionButton(title: "回调POST", systemImage: "arrowshape.turn.up.left") {
                        Task { await postWechatCallback() }
                    }
                }
            }
        }
    }

    private func integrationCard(title: String, icon: String, connected: Bool, test: @escaping () async -> Void) -> some View {
        GlassCard {
            HStack(spacing: 14) {
                IconBadge(systemImage: icon,
                          tint: connected ? Theme.accent : .gray,
                          size: 46)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    GlassPill(connected ? "已连接" : "未连接",
                              systemImage: connected ? "checkmark.circle.fill" : "exclamationmark.circle",
                              tint: connected ? Theme.success : .gray)
                }
                .layoutPriority(1)
                Spacer()
                Button("测试") { Task { await test() } }
                    .appGlassButtonStyle().controlSize(.small).tint(Theme.accent)
            }
        }
    }

    private var telegramTemplate: String {
        """
        {"enabled":false,"name":"Telegram","bot_token":"","chat_id":"","account_monitor_enabled":false,"api_id":"","api_hash":"","phone":"","selected_dialogs":[],"monitor_reply_enabled":false,"monitor_transfer_mode":"all","transfer_dir_mode":"system","transfer_dir":"","notify_types":{},"templates":{}}
        """
    }

    private var wechatTemplate: String {
        """
        {"enabled":false,"name":"微信","channel_name":"","corp_id":"","app_secret":"","token":"","agent_id":"","proxy_url":"","encoding_aes_key":"","admin_whitelist":"","notify_types":{},"templates":{}}
        """
    }

    private var dialogsTemplate: String {
        """
        {"selected_dialogs":[]}
        """
    }

    private func seedTelegramCode() {
        rawTelegramCodeBody = """
        {"api_id":"","api_hash":"","phone":""}
        """
    }

    private func seedTelegramSignIn() {
        rawTelegramSignInBody = """
        {"code":"","password":""}
        """
    }

    @MainActor
    private func saveTelegram() async {
        do {
            guard !rawTelegramBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写 Telegram 配置 JSON"])
            }
            await model.saveTelegram(try JSONValue.parse(rawTelegramBody))
        } catch { model.toast = error.localizedDescription }
    }

    @MainActor
    private func saveWechat() async {
        do {
            guard !rawWechatBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写企业微信配置 JSON"])
            }
            await model.saveWechat(try JSONValue.parse(rawWechatBody))
        } catch { model.toast = error.localizedDescription }
    }

    @MainActor
    private func sendTelegram() async {
        await runTool("Telegram 发送") {
            try await service.telegramSend(message: telegramMessage)
        }
    }

    @MainActor
    private func sendTelegramCode() async {
        do {
            if rawTelegramCodeBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                seedTelegramCode()
            }
            let body = try JSONValue.parse(rawTelegramCodeBody)
            await runTool("Telegram 验证码") {
                try await service.telegramSendCode(body)
            }
        } catch { model.toast = error.localizedDescription }
    }

    @MainActor
    private func signInTelegram() async {
        do {
            if rawTelegramSignInBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                seedTelegramSignIn()
            }
            let body = try JSONValue.parse(rawTelegramSignInBody)
            await runTool("Telegram 登录") {
                try await service.telegramSignIn(body)
            }
            await model.load()
        } catch { model.toast = error.localizedDescription }
    }

    @MainActor
    private func logoutTelegram() async {
        await runTool("Telegram 登出") {
            try await service.telegramLogout()
        }
        await model.load()
    }

    @MainActor
    private func telegramAvatarURL() async {
        await runTool("Telegram 头像 URL") {
            guard !telegramAvatarFilename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写 avatar filename"])
            }
            return try service.telegramAvatarURL(filename: telegramAvatarFilename)
        }
    }

    @MainActor
    private func sendWechat() async {
        await runTool("企业微信发送") {
            try await service.wechatSend(message: wechatMessage)
        }
    }

    @MainActor
    private func showWechatTypes() async {
        await runTool("企业微信类型") {
            try await service.wechatTypes()
        }
    }

    @MainActor
    private func verifyWechatCallback() async {
        await runTool("企业微信回调验证") {
            try await service.wechatCallbackVerify(
                signature: wechatCallbackSignature,
                timestamp: wechatCallbackTimestamp,
                nonce: wechatCallbackNonce,
                echostr: wechatCallbackEcho
            )
        }
    }

    @MainActor
    private func postWechatCallback() async {
        await runTool("企业微信回调 POST") {
            try await service.wechatCallbackMessage()
        }
    }

    @MainActor
    private func runTool(_ title: String, operation: () async throws -> JSONValue) async {
        do {
            result = try await operation()
            resultTitle = title
            showResult = true
            model.toast = "已执行：\(title)"
        } catch { model.toast = error.localizedDescription }
    }

    @MainActor
    private func saveDialogs() async {
        do {
            guard !rawDialogsBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写 Telegram 对话 JSON"])
            }
            await model.saveTelegramDialogs(try JSONValue.parse(rawDialogsBody))
        } catch { model.toast = error.localizedDescription }
    }
}
