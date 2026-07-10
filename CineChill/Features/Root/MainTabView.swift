import SwiftUI

/// Main app shell. iOS 26 uses the native Liquid Glass tab bar when the app is
/// built with the matching SDK; older SDKs keep a compatible TabView fallback.
struct MainTabView: View {
    @State private var selection: AppTab = .dashboard

    enum AppTab: Hashable { case dashboard, discover, subscriptions, tasks, more }

    var body: some View {
        tabs
    }

    @ViewBuilder
    private var tabs: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            liquidGlassTabs
        } else {
            compatibleTabs
        }
        #else
        compatibleTabs
        #endif
    }

    #if compiler(>=6.2)
    @available(iOS 26.0, *)
    private var liquidGlassTabs: some View {
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
    }
    #endif

    private var compatibleTabs: some View {
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
