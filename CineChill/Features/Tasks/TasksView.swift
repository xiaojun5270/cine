import SwiftUI

struct TasksView: View {
    @State private var model = TasksViewModel()
    @State private var panel: TaskPanel?
    @State private var taskToDelete: TaskItem?

    private enum TaskPanel: Identifiable, Equatable {
        case progress
        case logs

        var id: String {
            switch self {
            case .progress: "progress"
            case .logs: "logs"
            }
        }

        var title: String {
            switch self {
            case .progress: "任务进度"
            case .logs: "系统日志"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading && model.tasks.isEmpty {
                    LoadingView()
                } else if let error = model.error, model.tasks.isEmpty {
                    ErrorStateView(error: error) { Task { await model.load() } }
                } else if model.tasks.isEmpty {
                    EmptyStateView(systemImage: "checklist", title: "暂无任务")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(model.tasks) { task in taskCard(task) }
                        }
                        .padding(Theme.screenPadding)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("任务")
            .appLiquidNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task {
                                await model.loadProgress()
                                panel = .progress
                            }
                        } label: {
                            Label("查看进度", systemImage: "gauge.with.dots.needle.50percent")
                        }
                        Button {
                            Task {
                                await model.loadLogs()
                                panel = .logs
                            }
                        } label: {
                            Label("查看系统日志", systemImage: "doc.text")
                        }
                        Divider()
                        Button(role: .destructive) {
                            Task { await model.clearProgress() }
                        } label: {
                            Label("清空任务进度", systemImage: "gauge.with.dots.needle.0percent")
                        }
                        Button(role: .destructive) {
                            Task { await model.clearLogs() }
                        } label: {
                            Label("清空系统日志", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .refreshable { await model.load() }
            .task { if model.tasks.isEmpty { await model.load() } }
            .sheet(item: $panel) { panel in
                NavigationStack {
                    TaskJSONSheet(
                        title: panel.title,
                        json: panel == .progress ? model.progress : model.logs
                    )
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("关闭") { self.panel = nil }
                        }
                    }
                }
            }
            .confirmationDialog("确定删除这个任务？", isPresented: Binding(
                get: { taskToDelete != nil },
                set: { if !$0 { taskToDelete = nil } }
            ), titleVisibility: .visible) {
                if let taskToDelete {
                    Button("删除「\(taskToDelete.name)」", role: .destructive) {
                        Task {
                            await model.delete(taskToDelete)
                            self.taskToDelete = nil
                        }
                    }
                }
                Button("取消", role: .cancel) { taskToDelete = nil }
            }
            .alert("提示", isPresented: Binding(
                get: { model.toast != nil }, set: { if !$0 { model.toast = nil } }
            )) { Button("好", role: .cancel) {} } message: { Text(model.toast ?? "") }
        }
    }

    private func taskCard(_ task: TaskItem) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(task.name).font(.headline).lineLimit(1)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { task.enabled },
                        set: { newValue in Task { await model.toggle(task, enabled: newValue) } }
                    ))
                    .labelsHidden()
                    .tint(Theme.accent)
                }
                HStack(spacing: 10) {
                    if let type = task.type { GlassPill(type, systemImage: "tag") }
                    if let status = task.status { GlassPill(status, systemImage: "info.circle") }
                    if let cron = task.cron { GlassPill(cron, systemImage: "clock") }
                }
                HStack(spacing: 10) {
                    Button { Task { await model.run(task) } } label: {
                        Label("运行", systemImage: "play.fill")
                    }
                    .appGlassButtonStyle(prominent: true).tint(Theme.accent).controlSize(.small)
                    .disabled(model.runningIDs.contains(task.id))

                    Button { Task { await model.stop(task) } } label: {
                        Label("停止", systemImage: "stop.fill")
                    }
                    .appGlassButtonStyle().controlSize(.small)

                    Button(role: .destructive) { taskToDelete = task } label: {
                        Label("删除", systemImage: "trash")
                    }
                    .appGlassButtonStyle().controlSize(.small)
                    Spacer()
                }
                .font(.caption.weight(.semibold))
            }
        }
    }
}

private struct TaskJSONSheet: View {
    let title: String
    let json: JSONValue?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                switch json {
                case .none, .some(.null):
                    EmptyStateView(systemImage: "doc.text", title: "暂无内容")
                        .frame(minHeight: 220)
                case .some(.string(let text)):
                    Text(text.isEmpty ? "暂无内容" : text)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .some(let json):
                    let items = json.items()
                    if items.isEmpty {
                        JSONKeyValueCard(title: nil, json: json, limit: 80)
                    } else {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            JSONKeyValueCard(title: "#\(index + 1)", json: item, limit: 24)
                        }
                    }
                }
            }
            .padding(Theme.screenPadding)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .appLiquidNavigationChrome()
    }
}
