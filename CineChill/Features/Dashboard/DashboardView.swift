import SwiftUI

struct DashboardView: View {
    @Environment(SessionStore.self) private var session
    @State private var model = DashboardViewModel()
    @State private var showRawData = false

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    greeting

                    if model.isLoading && model.stats == nil {
                        LoadingView().frame(height: 240)
                    } else {
                        statsGrid
                        metricsSection
                        todaySection
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("首页")
            .appLiquidNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showRawData = true
                        } label: {
                            Label("查看原始数据", systemImage: "doc.text.magnifyingglass")
                        }
                        Button {
                            Task { await model.load() }
                        } label: {
                            Label("刷新首页", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .refreshable { await model.load() }
            .task { if model.stats == nil { await model.load() } }
            .sheet(isPresented: $showRawData) {
                JSONResultSheet(title: "首页原始数据", json: model.debugPayload)
            }
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("你好，\(session.username ?? "用户")")
                .font(.title2.bold())
            Text(session.server?.displayString ?? "")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            statCard("电影", value: model.stats?.movieCount, icon: "film.fill", tint: Theme.accent)
            statCard("剧集", value: model.stats?.tvCount, icon: "tv.fill", tint: Theme.accentWarm)
            statCard("剧集集数", value: model.stats?.episodeCount, icon: "square.stack.3d.up.fill", tint: .cyan)
            statCard("订阅", value: model.stats?.subscriptionCount, icon: "dot.radiowaves.up.forward", tint: .pink)
        }
    }

    private func statCard(_ title: String, value: Int?, icon: String, tint: Color) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon).font(.title2).foregroundStyle(tint)
                Text(value.map(String.init) ?? "—")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text(title).font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var metricsSection: some View {
        if let m = model.metrics, (m.cpuPercent != nil || m.memoryPercent != nil || m.diskPercent != nil) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "设备状态")
                GlassCard {
                    HStack(spacing: 20) {
                        MetricRing(title: "CPU", percent: m.cpuPercent, tint: Theme.accent)
                        MetricRing(title: "内存", percent: m.memoryPercent, tint: Theme.accentWarm)
                        MetricRing(title: "磁盘", percent: m.diskPercent, tint: .cyan)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private var todaySection: some View {
        if !model.todayPicks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "今日推荐")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(model.todayPicks) { item in
                            NavigationLink(value: item) {
                                MediaPosterCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationDestination(for: MediaItem.self) { MediaDetailView(item: $0) }
        }
    }
}

/// Circular percentage ring for device metrics.
struct MetricRing: View {
    let title: String
    let percent: Double?
    var tint: Color

    private var fraction: Double {
        guard let p = percent else { return 0 }
        return min(max(p > 1 ? p / 100 : p, 0), 1)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(.white.opacity(0.10), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(percent.map { "\(Int($0 > 1 ? $0 : $0 * 100))%" } ?? "—")
                    .font(.caption.bold())
            }
            .frame(width: 64, height: 64)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }
}
