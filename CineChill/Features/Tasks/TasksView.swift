import SwiftUI

struct TasksView: View {
    @State private var model = TasksViewModel()
    @State private var panel: TaskPanel?
    @State private var taskToDelete: TaskItem?
    @State private var showTaskEditor = false
    @State private var showBatchRunner = false
    @State private var editingTaskID = ""
    @State private var rawTaskBody = ""
    @State private var rawBatchBody = ""
    private let actionColumns = [GridItem(.adaptive(minimum: 82), spacing: 8)]

    private enum TaskPanel: Identifiable, Equatable {
        case progress
        case logs
        case batch

        var id: String {
            switch self {
            case .progress: "progress"
            case .logs: "logs"
            case .batch: "batch"
            }
        }

        var title: String {
            switch self {
            case .progress: "任务进度"
            case .logs: "系统日志"
            case .batch: "批量运行结果"
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
                            editingTaskID = ""
                            rawTaskBody = taskTemplate
                            showTaskEditor = true
                        } label: {
                            Label("新建任务", systemImage: "plus.circle")
                        }
                        Button {
                            rawBatchBody = batchRunTemplate
                            showBatchRunner = true
                        } label: {
                            Label("批量运行", systemImage: "play.rectangle.on.rectangle")
                        }
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
                        Button {
                            Task {
                                await model.loadLogStreamURL()
                                panel = .logs
                            }
                        } label: {
                            Label("日志流 URL", systemImage: "dot.radiowaves.left.and.right")
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
                        json: panelJSON(panel)
                    )
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("关闭") { self.panel = nil }
                        }
                    }
                }
            }
            .sheet(isPresented: $showTaskEditor) { taskEditorSheet }
            .sheet(isPresented: $showBatchRunner) { batchRunnerSheet }
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

    private func panelJSON(_ panel: TaskPanel) -> JSONValue? {
        switch panel {
        case .progress: model.progress
        case .logs: model.logs
        case .batch: model.batchResult
        }
    }

    private func taskCard(_ task: TaskItem) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    IconBadge(systemImage: task.enabled ? "checklist" : "pause.circle.fill",
                              tint: task.enabled ? Theme.accent : .gray,
                              size: 42)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.name)
                            .font(.headline)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                            .allowsTightening(true)
                        if let status = task.status {
                            Text(status)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .layoutPriority(1)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { task.enabled },
                        set: { newValue in Task { await model.toggle(task, enabled: newValue) } }
                    ))
                    .labelsHidden()
                    .tint(Theme.accent)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let type = task.type { GlassPill(type, systemImage: "tag") }
                        if let cron = task.cron { GlassPill(cron, systemImage: "clock") }
                    }
                }
                LazyVGrid(columns: actionColumns, alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "运行", systemImage: "play.fill", prominent: true) {
                        Task { await model.run(task) }
                    }
                    .disabled(model.runningIDs.contains(task.id))
                    ModuleActionButton(title: "停止", systemImage: "stop.fill") {
                        Task { await model.stop(task) }
                    }
                    ModuleActionButton(title: "编辑", systemImage: "square.and.pencil") {
                        edit(task)
                    }
                    ModuleActionButton(title: "删除", systemImage: "trash", role: .destructive) {
                        taskToDelete = task
                    }
                }
            }
        }
    }

    private var taskEditorSheet: some View {
        NavigationStack {
            ScrollView {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(editingTaskID.isEmpty ? "新建任务" : "编辑任务").font(.headline)
                        TextField("任务 JSON", text: $rawTaskBody, axis: .vertical)
                            .lineLimit(8...18)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .font(.system(.caption, design: .monospaced))
                            .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                        ModuleActionButton(title: "填入模板", systemImage: "doc.badge.plus") {
                            rawTaskBody = taskTemplate
                        }
                    }
                }
                .padding(Theme.screenPadding)
            }
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle(editingTaskID.isEmpty ? "新建任务" : "编辑任务")
            .navigationBarTitleDisplayMode(.inline)
            .appLiquidNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { showTaskEditor = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await saveTaskEditor() } }
                        .disabled(rawTaskBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var batchRunnerSheet: some View {
        NavigationStack {
            ScrollView {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("批量运行").font(.headline)
                        TextField("批量任务 JSON", text: $rawBatchBody, axis: .vertical)
                            .lineLimit(8...18)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .font(.system(.caption, design: .monospaced))
                            .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                        ModuleActionButton(title: "填入模板", systemImage: "doc.badge.plus") {
                            rawBatchBody = batchRunTemplate
                        }
                    }
                }
                .padding(Theme.screenPadding)
            }
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("批量运行")
            .navigationBarTitleDisplayMode(.inline)
            .appLiquidNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { showBatchRunner = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("运行") { Task { await runBatchEditor() } }
                        .disabled(rawBatchBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var taskTemplate: String {
        """
        {"name":"","cron":"0 2 * * *","preset_filename":"","targets":[],"mode":"random","enabled":true,"auto_include_new_libraries":false}
        """
    }

    private var batchRunTemplate: String {
        """
        {"preset_filename":"","targets":[],"mode":"random"}
        """
    }

    private func edit(_ task: TaskItem) {
        editingTaskID = task.id
        rawTaskBody = task.raw.prettyJSONString()
        showTaskEditor = true
    }

    @MainActor
    private func saveTaskEditor() async {
        do {
            let body = try taskBodyWithIDIfNeeded()
            if editingTaskID.isEmpty {
                await model.createTask(body)
            } else {
                await model.updateTask(body)
            }
            if model.error == nil { showTaskEditor = false }
        } catch { model.error = error }
    }

    private func taskBodyWithIDIfNeeded() throws -> JSONValue {
        let parsed = try JSONValue.parse(rawTaskBody)
        guard !editingTaskID.isEmpty else { return parsed }
        guard var object = parsed.object else { return parsed }
        if object["id"] == nil || object["id"]?.isNull == true {
            object["id"] = .string(editingTaskID)
        }
        return .object(object)
    }

    @MainActor
    private func runBatchEditor() async {
        do {
            let body = try JSONValue.parse(rawBatchBody)
            await model.runBatch(body)
            if model.error == nil {
                showBatchRunner = false
                panel = .batch
            }
        } catch { model.toast = error.localizedDescription }
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
