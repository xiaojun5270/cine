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
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Circle()
                        .fill(source.enabled ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(source.name).font(.headline).lineLimit(1)
                    Spacer()
                    GlassPill(source.typeLabel)
                }
                if !source.rssURL.isEmpty {
                    Text(source.rssURL).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                HStack(spacing: 12) {
                    Label(source.subscriptionTarget, systemImage: "target").font(.caption2)
                    if !source.cron.isEmpty {
                        Label(source.cron, systemImage: "clock").font(.caption2)
                    }
                }
                .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button { Task { await model.sync(source) } } label: {
                        Label("同步", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .appGlassButtonStyle().tint(Theme.accent).controlSize(.small)

                    Button { editing = source; showEditor = true } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    .appGlassButtonStyle().controlSize(.small)

                    Spacer()

                    Button(role: .destructive) { Task { await model.delete(source) } } label: {
                        Image(systemName: "trash")
                    }
                    .appGlassButtonStyle().controlSize(.small)
                }
                .font(.caption.weight(.semibold))
            }
        }
    }
}
