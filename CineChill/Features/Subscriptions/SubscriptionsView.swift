import SwiftUI

struct SubscriptionsView: View {
    @State private var model = SubscriptionsViewModel()
    @State private var editing: RssSource?
    @State private var showEditor = false
    @State private var panel: SubscriptionPanel?

    private enum SubscriptionPanel: Identifiable, Equatable {
        case activity
        case events

        var id: String {
            switch self {
            case .activity: "activity"
            case .events: "events"
            }
        }

        var title: String {
            switch self {
            case .activity: "订阅活动"
            case .events: "订阅事件"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading && model.sources.isEmpty {
                    LoadingView()
                } else if let error = model.error, model.sources.isEmpty {
                    ErrorStateView(error: error) { Task { await model.load() } }
                } else if model.sources.isEmpty {
                    EmptyStateView(systemImage: "dot.radiowaves.up.forward",
                                   title: "还没有订阅源",
                                   message: "点右上角 + 添加一个 RSS 订阅")
                } else {
                    list
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("订阅")
            .appLiquidNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            editing = nil; showEditor = true
                        } label: {
                            Label("添加订阅源", systemImage: "plus")
                        }
                        Button {
                            Task {
                                await model.loadActivity()
                                panel = .activity
                            }
                        } label: {
                            Label("查看活动", systemImage: "clock")
                        }
                        Button {
                            Task {
                                await model.loadEvents()
                                panel = .events
                            }
                        } label: {
                            Label("查看事件", systemImage: "list.bullet.rectangle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .refreshable { await model.load() }
            .task { if model.sources.isEmpty { await model.load() } }
            .sheet(isPresented: $showEditor) {
                RssSourceEditor(source: editing) { payload in
                    await model.save(existing: editing, payload: payload)
                }
            }
            .sheet(item: $panel) { panel in
                NavigationStack {
                    ScrollView {
                        let json = panel == .activity ? model.activity : model.events
                        if let json {
                            let items = json.items()
                            if items.isEmpty {
                                JSONKeyValueCard(title: nil, json: json, limit: 80)
                                    .padding(Theme.screenPadding)
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                                        JSONKeyValueCard(title: "#\(index + 1)", json: item, limit: 24)
                                    }
                                }
                                .padding(Theme.screenPadding)
                            }
                        } else {
                            EmptyStateView(systemImage: "tray", title: "暂无内容")
                        }
                    }
                    .background(Theme.backgroundGradient.ignoresSafeArea())
                    .navigationTitle(panel.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .appLiquidNavigationChrome()
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("关闭") { self.panel = nil } } }
                }
            }
            .alert("提示", isPresented: Binding(
                get: { model.toast != nil },
                set: { if !$0 { model.toast = nil } }
            )) { Button("好", role: .cancel) {} } message: { Text(model.toast ?? "") }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(model.sources) { source in
                    sourceCard(source)
                }
            }
            .padding(Theme.screenPadding)
        }
    }

    private func sourceCard(_ source: RssSource) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    IconBadge(systemImage: source.enabled ? "dot.radiowaves.up.forward" : "pause.circle.fill",
                              tint: source.enabled ? Theme.accent : .gray,
                              size: 42)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(source.name)
                            .font(.headline)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                            .allowsTightening(true)
                        if !source.rssURL.isEmpty {
                            Text(source.rssURL)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.76)
                        }
                    }
                    .layoutPriority(1)
                    Spacer()
                    GlassPill(source.enabled ? "启用" : "停用",
                              systemImage: source.enabled ? "checkmark.circle.fill" : "pause.circle",
                              tint: source.enabled ? Theme.success : .gray)
                }
                HStack(spacing: 12) {
                    GlassPill(source.typeLabel, systemImage: source.mediaType == "movie" ? "film" : "tv")
                    Label(source.subscriptionTarget, systemImage: "target").font(.caption2)
                    if !source.cron.isEmpty {
                        Label(source.cron, systemImage: "clock").font(.caption2)
                    }
                }
                .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 8)], alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "同步", systemImage: "arrow.triangle.2.circlepath", prominent: true) {
                        Task { await model.sync(source) }
                    }
                    ModuleActionButton(title: "编辑", systemImage: "square.and.pencil") {
                        editing = source
                        showEditor = true
                    }
                    ModuleActionButton(title: "删除", systemImage: "trash", role: .destructive) {
                        Task { await model.delete(source) }
                    }
                }
            }
        }
    }
}
