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
        let subtitle: String
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
                Item(title: "设置", subtitle: "账号与服务器", icon: "gearshape.fill", tint: .gray, route: .settings),
                Item(title: "通知配置", subtitle: "Telegram / 企业微信", icon: "bell.badge.fill", tint: Theme.accentPink, route: .notify)
            ]),
            Group(header: "媒体库", items: [
                Item(title: "Emby 用户", subtitle: "权限与密码", icon: "person.2.fill", tint: Theme.success, route: .embyUsers),
                Item(title: "Emby 任务", subtitle: "计划与触发器", icon: "arrow.triangle.2.circlepath", tint: Theme.success, route: .embyTasks),
                Item(title: "媒体整理", subtitle: "识别与规则", icon: "folder.badge.gearshape", tint: Theme.accent, route: .mediaOrganize),
                Item(title: "整理历史", subtitle: "重做与追踪", icon: "clock.arrow.circlepath", tint: Theme.accentBlue, route: .organizeHistory),
                Item(title: "STRM 同步", subtitle: "生成与刮削", icon: "link.badge.plus", tint: .cyan, route: .strm)
            ]),
            Group(header: "资源与转发", items: [
                Item(title: "MoviePilot 订阅", subtitle: "检查与订阅", icon: "airplane.circle.fill", tint: Theme.accentBlue, route: .moviePilot),
                Item(title: "RSS 原生源", subtitle: "任务与预览", icon: "antenna.radiowaves.left.and.right", tint: Theme.accentWarm, route: .rss),
                Item(title: "资源转发", subtitle: "搜索与转存", icon: "arrowshape.turn.up.right.fill", tint: Theme.accentPink, route: .forward),
                Item(title: "手动转移", subtitle: "链接入库", icon: "tray.and.arrow.down.fill", tint: .teal, route: .transfer),
                Item(title: "海报套件", subtitle: "模板与字体", icon: "photo.stack.fill", tint: .purple, route: .resources)
            ]),
            Group(header: "115 网盘", items: [
                Item(title: "115 上传", subtitle: "秒传与任务", icon: "arrow.up.circle.fill", tint: Theme.accentWarm, route: .drive115Upload),
                Item(title: "115 清理", subtitle: "规则与执行", icon: "trash.circle.fill", tint: Theme.danger, route: .drive115Cleanup),
                Item(title: "302 / 115 配置", subtitle: "扫码与签到", icon: "externaldrive.badge.plus", tint: Theme.accentWarm, route: .config302)
            ]),
            Group(header: "系统与运维", items: [
                Item(title: "Docker 管理", subtitle: "容器与镜像", icon: "shippingbox.fill", tint: Theme.accentBlue, route: .docker),
                Item(title: "系统健康", subtitle: "网络与指标", icon: "waveform.path.ecg", tint: Theme.success, route: .systemHealth),
                Item(title: "AI 剧集识别", subtitle: "上下文与提醒", icon: "brain.head.profile", tint: Theme.accent, route: .aiResolver),
                Item(title: "飞牛签到", subtitle: "账号签到", icon: "checkmark.seal.fill", tint: .mint, route: .fnosSign),
                Item(title: "Webhook", subtitle: "队列与触发", icon: "bolt.horizontal.circle.fill", tint: .yellow, route: .webhook),
                Item(title: "检查更新", subtitle: "版本升级", icon: "arrow.down.circle.fill", tint: .indigo, route: .upgrade),
                Item(title: "接口总控", subtitle: "305 个接口", icon: "point.3.connected.trianglepath.dotted", tint: Theme.accentWarm, route: .apiConsole)
            ])
        ]
    }

    private let columns = [GridItem(.adaptive(minimum: 162), spacing: 12)]

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
                IconBadge(systemImage: item.icon, tint: item.tint, size: 42)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(item.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
