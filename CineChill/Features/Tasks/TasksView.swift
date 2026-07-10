import SwiftUI

struct TasksView: View {
    @State private var model = TasksViewModel()

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
            .refreshable { await model.load() }
            .task { if model.tasks.isEmpty { await model.load() } }
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
                    .buttonStyle(AppGlassButtonStyle(prominent: true)).tint(Theme.accent).controlSize(.small)
                    .disabled(model.runningIDs.contains(task.id))

                    Button { Task { await model.stop(task) } } label: {
                        Label("停止", systemImage: "stop.fill")
                    }
                    .buttonStyle(AppGlassButtonStyle()).controlSize(.small)
                    Spacer()
                }
                .font(.caption.weight(.semibold))
            }
        }
    }
}
