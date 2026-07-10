import SwiftUI

/// Hub for the extended modules that don't warrant a top-level tab.
struct MoreView: View {
    private struct Item: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let tint: Color
        let destination: AnyView
    }

    private struct Group: Identifiable {
        let id = UUID()
        let header: String
        let items: [Item]
    }

    private var groups: [Group] {
        [
            Group(header: "账户", items: [
                Item(title: "设置", icon: "gearshape.fill", tint: .gray, destination: AnyView(SettingsView())),
                Item(title: "通知配置", icon: "bell.badge.fill", tint: .red, destination: AnyView(NotifyView()))
            ]),
            Group(header: "媒体库", items: [
                Item(title: "Emby 用户", icon: "person.2.fill", tint: .green, destination: AnyView(EmbyUsersView())),
                Item(title: "Emby 任务", icon: "arrow.triangle.2.circlepath", tint: .green, destination: AnyView(EmbyTasksView())),
                Item(title: "媒体整理", icon: "folder.badge.gearshape", tint: Theme.accent, destination: AnyView(MediaOrganizeView())),
                Item(title: "整理历史", icon: "clock.arrow.circlepath", tint: Theme.accent, destination: AnyView(OrganizeHistoryView())),
                Item(title: "STRM 同步", icon: "link.badge.plus", tint: .cyan, destination: AnyView(StrmView()))
            ]),
            Group(header: "资源与转发", items: [
                Item(title: "MoviePilot 订阅", icon: "airplane.circle.fill", tint: .blue, destination: AnyView(MoviePilotView())),
                Item(title: "RSS 原生源", icon: "antenna.radiowaves.left.and.right", tint: .orange, destination: AnyView(RssView())),
                Item(title: "资源转发", icon: "arrowshape.turn.up.right.fill", tint: .pink, destination: AnyView(ForwardView())),
                Item(title: "手动转移", icon: "tray.and.arrow.down.fill", tint: .teal, destination: AnyView(TransferView())),
                Item(title: "海报套件", icon: "photo.stack.fill", tint: .purple, destination: AnyView(ResourcesView()))
            ]),
            Group(header: "115 网盘", items: [
                Item(title: "115 上传", icon: "arrow.up.circle.fill", tint: Theme.accentWarm, destination: AnyView(Drive115UploadView())),
                Item(title: "115 清理", icon: "trash.circle.fill", tint: .red, destination: AnyView(Drive115CleanupView())),
                Item(title: "302 / 115 配置", icon: "externaldrive.badge.plus", tint: Theme.accentWarm, destination: AnyView(Config302View()))
            ]),
            Group(header: "系统与运维", items: [
                Item(title: "Docker 管理", icon: "shippingbox.fill", tint: .blue, destination: AnyView(DockerView())),
                Item(title: "系统健康", icon: "waveform.path.ecg", tint: .green, destination: AnyView(SystemHealthView())),
                Item(title: "AI 剧集识别", icon: "brain.head.profile", tint: Theme.accent, destination: AnyView(AIResolverView())),
                Item(title: "飞牛签到", icon: "checkmark.seal.fill", tint: .mint, destination: AnyView(FnosSignView())),
                Item(title: "Webhook", icon: "bolt.horizontal.circle.fill", tint: .yellow, destination: AnyView(WebhookView())),
                Item(title: "检查更新", icon: "arrow.down.circle.fill", tint: .indigo, destination: AnyView(UpgradeView())),
                Item(title: "接口总控", icon: "point.3.connected.trianglepath.dotted", tint: Theme.accentWarm, destination: AnyView(APIConsoleView()))
            ])
        ]
    }

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: group.header)
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(group.items) { item in
                                    NavigationLink { item.destination } label: { tile(item) }
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(Theme.screenPadding)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("更多")
            .appLiquidNavigationChrome()
        }
    }

    private func tile(_ item: Item) -> some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.title3)
                    .foregroundStyle(item.tint)
                    .frame(width: 40, height: 40)
                    .appGlassCircle()
                Text(item.title).font(.subheadline.weight(.medium))
                Spacer(minLength: 0)
            }
        }
    }
}
