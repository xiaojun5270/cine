import SwiftUI

/// Hub for the extended modules that don't warrant a top-level tab.
struct MoreView: View {
    private enum Route: Hashable {
        case settings
        case notify
        case embyUsers
        case embyTasks
        case mediaOrganize
        case organizeHistory
        case strm
        case moviePilot
        case rss
        case forward
        case transfer
        case resources
        case drive115Upload
        case drive115Cleanup
        case config302
        case docker
        case systemHealth
        case aiResolver
        case fnosSign
        case webhook
        case upgrade
        case apiConsole
    }

    private struct Item: Identifiable {
        var id: Route { route }
        let title: String
        let icon: String
        let tint: Color
        let route: Route
    }

    private struct Group: Identifiable {
        var id: String { header }
        let header: String
        let items: [Item]
    }

    private var groups: [Group] {
        [
            Group(header: "账户", items: [
                Item(title: "设置", icon: "gearshape.fill", tint: .gray, route: .settings),
                Item(title: "通知配置", icon: "bell.badge.fill", tint: .red, route: .notify)
            ]),
            Group(header: "媒体库", items: [
                Item(title: "Emby 用户", icon: "person.2.fill", tint: .green, route: .embyUsers),
                Item(title: "Emby 任务", icon: "arrow.triangle.2.circlepath", tint: .green, route: .embyTasks),
                Item(title: "媒体整理", icon: "folder.badge.gearshape", tint: Theme.accent, route: .mediaOrganize),
                Item(title: "整理历史", icon: "clock.arrow.circlepath", tint: Theme.accent, route: .organizeHistory),
                Item(title: "STRM 同步", icon: "link.badge.plus", tint: .cyan, route: .strm)
            ]),
            Group(header: "资源与转发", items: [
                Item(title: "MoviePilot 订阅", icon: "airplane.circle.fill", tint: .blue, route: .moviePilot),
                Item(title: "RSS 原生源", icon: "antenna.radiowaves.left.and.right", tint: .orange, route: .rss),
                Item(title: "资源转发", icon: "arrowshape.turn.up.right.fill", tint: .pink, route: .forward),
                Item(title: "手动转移", icon: "tray.and.arrow.down.fill", tint: .teal, route: .transfer),
                Item(title: "海报套件", icon: "photo.stack.fill", tint: .purple, route: .resources)
            ]),
            Group(header: "115 网盘", items: [
                Item(title: "115 上传", icon: "arrow.up.circle.fill", tint: Theme.accentWarm, route: .drive115Upload),
                Item(title: "115 清理", icon: "trash.circle.fill", tint: .red, route: .drive115Cleanup),
                Item(title: "302 / 115 配置", icon: "externaldrive.badge.plus", tint: Theme.accentWarm, route: .config302)
            ]),
            Group(header: "系统与运维", items: [
                Item(title: "Docker 管理", icon: "shippingbox.fill", tint: .blue, route: .docker),
                Item(title: "系统健康", icon: "waveform.path.ecg", tint: .green, route: .systemHealth),
                Item(title: "AI 剧集识别", icon: "brain.head.profile", tint: Theme.accent, route: .aiResolver),
                Item(title: "飞牛签到", icon: "checkmark.seal.fill", tint: .mint, route: .fnosSign),
                Item(title: "Webhook", icon: "bolt.horizontal.circle.fill", tint: .yellow, route: .webhook),
                Item(title: "检查更新", icon: "arrow.down.circle.fill", tint: .indigo, route: .upgrade),
                Item(title: "接口总控", icon: "point.3.connected.trianglepath.dotted", tint: Theme.accentWarm, route: .apiConsole)
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
                                    NavigationLink(value: item.route) { tile(item) }
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
            .navigationDestination(for: Route.self) { route in
                destination(for: route)
            }
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .settings: SettingsView()
        case .notify: NotifyView()
        case .embyUsers: EmbyUsersView()
        case .embyTasks: EmbyTasksView()
        case .mediaOrganize: MediaOrganizeView()
        case .organizeHistory: OrganizeHistoryView()
        case .strm: StrmView()
        case .moviePilot: MoviePilotView()
        case .rss: RssView()
        case .forward: ForwardView()
        case .transfer: TransferView()
        case .resources: ResourcesView()
        case .drive115Upload: Drive115UploadView()
        case .drive115Cleanup: Drive115CleanupView()
        case .config302: Config302View()
        case .docker: DockerView()
        case .systemHealth: SystemHealthView()
        case .aiResolver: AIResolverView()
        case .fnosSign: FnosSignView()
        case .webhook: WebhookView()
        case .upgrade: UpgradeView()
        case .apiConsole: APIConsoleView()
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
