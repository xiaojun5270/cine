import SwiftUI

/// Main app shell.
struct MainTabView: View {
    @State private var selection: AppTab = .dashboard

    enum AppTab: Hashable { case dashboard, discover, subscriptions, tasks, more }

    var body: some View {
        TabView(selection: $selection) {
            DashboardView()
                .tabItem { Label("首页", systemImage: "square.grid.2x2.fill") }
                .tag(AppTab.dashboard)

            DiscoverView()
                .tabItem { Label("发现", systemImage: "sparkles.tv.fill") }
                .tag(AppTab.discover)

            SubscriptionsView()
                .tabItem { Label("订阅", systemImage: "dot.radiowaves.up.forward") }
                .tag(AppTab.subscriptions)

            TasksView()
                .tabItem { Label("任务", systemImage: "checklist") }
                .tag(AppTab.tasks)

            MoreView()
                .tabItem { Label("更多", systemImage: "square.grid.3x3.fill") }
                .tag(AppTab.more)
        }
    }
}
