import SwiftUI

@MainActor
@Observable
final class NotifyViewModel {
    var channels: [NotifyChannel] = []
    var telegramConnected = false
    var wechatEnabled = false
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
        let channels = try? await ch
        let tgStatus = try? await tg
        let wcConfig = try? await wc
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
}

struct NotifyView: View {
    @State private var model = NotifyViewModel()

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

                        if !model.channels.isEmpty {
                            SectionHeader(title: "通知渠道")
                            ForEach(model.channels) { channel in
                                GlassCard {
                                    HStack {
                                        Text(channel.name).font(.subheadline.weight(.medium))
                                        Spacer()
                                        Text(channel.enabled ? "已启用" : "未启用")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(channel.enabled ? Color.green : .secondary)
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
        .refreshable { await model.load() }
        .task { if model.channels.isEmpty { await model.load() } }
        .alert("提示", isPresented: Binding(
            get: { model.toast != nil }, set: { if !$0 { model.toast = nil } }
        )) { Button("好", role: .cancel) {} } message: { Text(model.toast ?? "") }
    }

    private func integrationCard(title: String, icon: String, connected: Bool, test: @escaping () async -> Void) -> some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44)
                    .appGlassCircle()
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(connected ? "已连接" : "未连接")
                        .font(.caption)
                        .foregroundStyle(connected ? Color.green : .secondary)
                }
                Spacer()
                Button("测试") { Task { await test() } }
                    .appGlassButtonStyle().controlSize(.small).tint(Theme.accent)
            }
        }
    }
}
