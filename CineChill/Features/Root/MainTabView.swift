import SwiftUI

/// Main app shell rendered with the native iOS 26 Liquid Glass tab bar.
struct MainTabView: View {
    @State private var selection: AppTab = .dashboard

    enum AppTab: Hashable { case dashboard, discover, subscriptions, tasks, more }

    var body: some View {
        TabView(selection: $selection) {
            Tab("首页", systemImage: "square.grid.2x2.fill", value: .dashboard) {
                DashboardView()
            }
            Tab("发现", systemImage: "sparkles.tv.fill", value: .discover) {
                DiscoverView()
            }
            Tab("订阅", systemImage: "dot.radiowaves.up.forward", value: .subscriptions) {
                SubscriptionsView()
            }
            Tab("任务", systemImage: "checklist", value: .tasks) {
                TasksView()
            }
            Tab("更多", systemImage: "square.grid.3x3.fill", value: .more) {
                MoreView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
