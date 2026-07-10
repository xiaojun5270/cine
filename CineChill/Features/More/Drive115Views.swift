import SwiftUI

struct Drive115UploadView: View {
    private let service = Drive115UploadService()
    @State private var tasks: [JSONValue] = []
    @State private var status: JSONValue?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?
    @State private var detail: JSONValue?
    @State private var detailTitle = "详情"
    @State private var showDetail = false
    @State private var selectedTaskID = ""
    @State private var rawTaskBody = ""
    @State private var rawThreadSettingsBody = ""
    @State private var localBrowsePath = "/"
    @State private var browse115CID = "0"
    @State private var rawCloudBrowseBody = ""
    @State private var rawRapidTransferBody = ""
    @State private var cloudJobID = ""
    @State private var rawHistoryDeleteBody = ""

    private let buttonColumns = [GridItem(.adaptive(minimum: 82), spacing: 8)]

    var body: some View {
        ModuleScaffold(title: "115 上传", isLoading: isLoading && tasks.isEmpty, error: tasks.isEmpty ? error : nil,
                       isEmpty: !isLoading && tasks.isEmpty && error == nil, emptyTitle: "暂无上传任务",
                       emptyIcon: "arrow.up.circle", onRetry: { Task { await load() } },
                       toolbarContent: AnyView(toolbarMenu)) {
            if let status, let obj = status.object, !obj.isEmpty {
                JSONKeyValueCard(title: "总体状态", json: status, limit: 8)
            }
            taskEditorCard
            threadSettingsCard
            storageToolsCard
            ForEach(Array(tasks.enumerated()), id: \.offset) { _, t in taskCard(t) }
        }
        .task { await load() }
        .toast($toast)
        .sheet(isPresented: $showDetail) {
            NavigationStack {
                ScrollView {
                    if let detail {
                        JSONKeyValueCard(title: nil, json: detail, limit: 80)
                            .padding(Theme.screenPadding)
                    } else {
                        EmptyStateView(systemImage: "doc.text", title: "暂无内容")
                    }
                }
                .background(Theme.backgroundGradient.ignoresSafeArea())
                .navigationTitle(detailTitle).navigationBarTitleDisplayMode(.inline)
                .appLiquidNavigationChrome()
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("关闭") { showDetail = false } } }
            }
        }
    }

    private var toolbarMenu: some View {
        Menu {
            Button {
                seedUploadTaskTemplate()
            } label: {
                Label("新建任务模板", systemImage: "doc.badge.plus")
            }
            Button {
                Task { await saveThreadSettings() }
            } label: {
                Label("保存线程设置", systemImage: "square.and.arrow.down")
            }
            Button {
                Task { await showThreadSettings() }
            } label: {
                Label("线程设置", systemImage: "slider.horizontal.3")
            }
            Divider()
            Button {
                seedCloudBrowseTemplate()
            } label: {
                Label("云端浏览模板", systemImage: "folder.badge.gearshape")
            }
            Button {
                seedRapidTransferTemplate()
            } label: {
                Label("秒传模板", systemImage: "bolt.circle")
            }
            Button {
                seedHistoryDeleteTemplate()
            } label: {
                Label("历史删除模板", systemImage: "trash.slash")
            }
            Button(role: .destructive) {
                Task { await clearHistory() }
            } label: {
                Label("清空上传历史", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private var taskEditorCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("任务编辑").font(.headline)
                TextField("task_id（更新时填写）", text: $selectedTaskID)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("上传任务 JSON", text: $rawTaskBody, axis: .vertical)
                    .lineLimit(3...10)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "模板", systemImage: "doc.badge.plus") { seedUploadTaskTemplate() }
                    ModuleActionButton(title: "创建", systemImage: "plus.circle", prominent: true) {
                        Task { await createTask() }
                    }
                    ModuleActionButton(title: "保存", systemImage: "square.and.arrow.down") {
                        Task { await updateTask() }
                    }
                    .disabled(selectedTaskID.isEmpty)
                }
            }
        }
    }

    private var threadSettingsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("线程设置").font(.headline)
                TextField("线程设置 JSON", text: $rawThreadSettingsBody, axis: .vertical)
                    .lineLimit(2...6)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "读取", systemImage: "slider.horizontal.3") {
                        Task { await showThreadSettings() }
                    }
                    ModuleActionButton(title: "模板", systemImage: "doc.badge.plus") { seedThreadSettingsTemplate() }
                    ModuleActionButton(title: "保存", systemImage: "square.and.arrow.down", prominent: true) {
                        Task { await saveThreadSettings() }
                    }
                }
            }
        }
    }

    private var storageToolsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("浏览与秒传").font(.headline)
                HStack(spacing: 10) {
                    TextField("本地路径", text: $localBrowsePath)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("115 cid", text: $browse115CID)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("云端浏览 JSON", text: $rawCloudBrowseBody, axis: .vertical)
                    .lineLimit(2...6)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("云秒传 JSON", text: $rawRapidTransferBody, axis: .vertical)
                    .lineLimit(3...8)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                HStack(spacing: 10) {
                    TextField("云秒传 job_id", text: $cloudJobID)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("历史删除 JSON", text: $rawHistoryDeleteBody, axis: .vertical)
                        .lineLimit(1...4)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "本地", systemImage: "folder") {
                        Task { await browseLocal() }
                    }
                    ModuleActionButton(title: "115", systemImage: "externaldrive") {
                        Task { await browse115() }
                    }
                    ModuleActionButton(title: "云模板", systemImage: "doc.badge.plus") {
                        seedCloudBrowseTemplate()
                    }
                    ModuleActionButton(title: "云浏览", systemImage: "icloud.and.arrow.down") {
                        Task { await browseCloud() }
                    }
                    ModuleActionButton(title: "秒传模板", systemImage: "bolt.badge.clock") {
                        seedRapidTransferTemplate()
                    }
                    ModuleActionButton(title: "秒传", systemImage: "bolt.circle", prominent: true) {
                        Task { await rapidTransfer() }
                    }
                    ModuleActionButton(title: "查任务", systemImage: "magnifyingglass.circle") {
                        Task { await showCloudJob() }
                    }
                    .disabled(cloudJobID.isEmpty)
                    ModuleActionButton(title: "取消任务", systemImage: "xmark.circle", role: .destructive) {
                        Task { await cancelCloudJob() }
                    }
                    .disabled(cloudJobID.isEmpty)
                    ModuleActionButton(title: "历史模板", systemImage: "doc.text") {
                        seedHistoryDeleteTemplate()
                    }
                    ModuleActionButton(title: "删历史", systemImage: "trash.slash", role: .destructive) {
                        Task { await deleteHistoryRecord() }
                    }
                }
            }
        }
    }

    private func taskCard(_ t: JSONValue) -> some View {
        let name = t.firstString("name", "task_name") ?? "任务"
        let id = t.firstString("id", "task_id") ?? ""
        let enabled = t["enabled"].bool ?? true
        let folder = t.firstString("local_folder", "target_path")
        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Circle().fill(enabled ? .green : .gray).frame(width: 8, height: 8)
                    Text(name).font(.subheadline.weight(.medium)).lineLimit(1)
                    Spacer()
                }
                if let folder { Text(folder).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                LazyVGrid(columns: buttonColumns, spacing: 8) {
                    ModuleActionButton(title: "扫描", systemImage: "arrow.triangle.2.circlepath", prominent: true) { Task { await scan(id) } }
                    ModuleActionButton(title: "停止", systemImage: "stop.fill") { Task { await stop(id) } }
                    ModuleActionButton(title: "状态", systemImage: "info.circle") { Task { await showStatus(id) } }
                    ModuleActionButton(title: "编辑", systemImage: "square.and.pencil") { fillTask(t) }
                    ModuleActionButton(title: "重试", systemImage: "arrow.clockwise") { Task { await retry(id) } }
                    ModuleActionButton(title: enabled ? "禁用" : "启用", systemImage: enabled ? "pause" : "play") { Task { await toggle(id, !enabled) } }
                    ModuleActionButton(title: "清历史", systemImage: "clock.badge.xmark") { Task { await clearTaskHistory(id) } }
                    ModuleActionButton(title: "删除", systemImage: "trash", role: .destructive) { Task { await delete(id) } }
                }
            }
        }
    }

    private func load() async {
        isLoading = true; error = nil
        async let t = service.tasks()
        async let s = service.status()
        do { tasks = try await t } catch { self.error = error }
        status = try? await s
        isLoading = false
    }
    private func scan(_ id: String) async { do { try await service.scan(id: id); toast = "已触发扫描"; await load() } catch { toast = error.localizedDescription } }
    private func stop(_ id: String) async { do { try await service.stop(id: id); toast = "已停止" } catch { toast = error.localizedDescription } }
    private func toggle(_ id: String, _ en: Bool) async { do { try await service.toggle(id: id, enabled: en); await load() } catch { toast = error.localizedDescription } }
    private func retry(_ id: String) async { do { try await service.retry(id: id, jobID: nil); toast = "已触发重试"; await load() } catch { toast = error.localizedDescription } }
    private func delete(_ id: String) async { do { try await service.delete(id: id); toast = "已删除任务"; await load() } catch { toast = error.localizedDescription } }
    private func clearHistory() async { do { try await service.clearHistory(); toast = "已清空上传历史" } catch { toast = error.localizedDescription } }
    private func clearTaskHistory(_ id: String) async {
        do {
            detail = try await service.clearTaskHistory(id: id)
            detailTitle = "任务历史清理"
            showDetail = true
        } catch { toast = error.localizedDescription }
    }
    private func showStatus(_ id: String) async {
        do {
            detail = try await service.taskStatus(id: id)
            detailTitle = "任务状态"
            showDetail = true
        } catch { toast = error.localizedDescription }
    }
    private func showThreadSettings() async {
        do {
            detail = try await service.threadSettings()
            rawThreadSettingsBody = detail?.prettyJSONString() ?? rawThreadSettingsBody
            detailTitle = "线程设置"
            showDetail = true
        } catch { toast = error.localizedDescription }
    }
    private func fillTask(_ task: JSONValue) {
        selectedTaskID = task.firstString("id", "task_id") ?? selectedTaskID
        rawTaskBody = task.prettyJSONString()
    }
    private func seedUploadTaskTemplate() {
        rawTaskBody = """
        {"name":"","enabled":true,"local_folder":"","target_cid":"0","target_name":"","target_path":"","watch_mode":"realtime","include_existing_on_start":true,"delete_local_after_success":true,"skip_upload_when_no_rapid_resource":false}
        """
    }
    private func seedThreadSettingsTemplate() {
        rawThreadSettingsBody = """
        {"verify_concurrency":5,"rapid_concurrency":5,"upload_concurrency":5}
        """
    }
    private func seedCloudBrowseTemplate() {
        rawCloudBrowseBody = """
        {"cookie":"","cid":"0","include_files":true}
        """
    }
    private func seedRapidTransferTemplate() {
        rawRapidTransferBody = """
        {"source_cookie":"","target_cookie":"","target_cid":"0","target_path":"","concurrency":4,"items":[]}
        """
    }
    private func seedHistoryDeleteTemplate() {
        rawHistoryDeleteBody = """
        {"status":"success","task_id":"","job_id":"","key":"","path":"","relative_path":"","filename":""}
        """
    }
    private func browseLocal() async {
        do {
            detail = try await service.browseLocal(path: localBrowsePath)
            detailTitle = "本地浏览"
            showDetail = true
        } catch { toast = error.localizedDescription }
    }
    private func browse115() async {
        do {
            detail = try await service.browse115(cid: browse115CID.isEmpty ? "0" : browse115CID)
            detailTitle = "115 浏览"
            showDetail = true
        } catch { toast = error.localizedDescription }
    }
    private func browseCloud() async {
        do {
            if rawCloudBrowseBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                seedCloudBrowseTemplate()
            }
            detail = try await service.browseCloud(try JSONValue.parse(rawCloudBrowseBody))
            detailTitle = "云端浏览"
            showDetail = true
        } catch { toast = error.localizedDescription }
    }
    private func rapidTransfer() async {
        do {
            if rawRapidTransferBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                seedRapidTransferTemplate()
            }
            detail = try await service.rapidTransfer(try JSONValue.parse(rawRapidTransferBody))
            detailTitle = "云秒传"
            showDetail = true
        } catch { toast = error.localizedDescription }
    }
    private func showCloudJob() async {
        do {
            guard !cloudJobID.isEmpty else { throw APIError.validation(["请先填写 job_id"]) }
            detail = try await service.cloudJob(id: cloudJobID)
            detailTitle = "云秒传任务"
            showDetail = true
        } catch { toast = error.localizedDescription }
    }
    private func cancelCloudJob() async {
        do {
            guard !cloudJobID.isEmpty else { throw APIError.validation(["请先填写 job_id"]) }
            detail = try await service.cancelCloudJob(id: cloudJobID)
            detailTitle = "取消云秒传"
            showDetail = true
        } catch { toast = error.localizedDescription }
    }
    private func deleteHistoryRecord() async {
        do {
            if rawHistoryDeleteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                seedHistoryDeleteTemplate()
            }
            detail = try await service.deleteHistory(try JSONValue.parse(rawHistoryDeleteBody))
            detailTitle = "删除历史"
            showDetail = true
        } catch { toast = error.localizedDescription }
    }
    private func createTask() async {
        do {
            guard !rawTaskBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写上传任务 JSON"])
            }
            detail = try await service.createTask(try JSONValue.parse(rawTaskBody))
            detailTitle = "创建上传任务"
            showDetail = true
            await load()
        } catch { toast = error.localizedDescription }
    }
    private func updateTask() async {
        do {
            guard !selectedTaskID.isEmpty else { throw APIError.validation(["请先填写 task_id"]) }
            guard !rawTaskBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写上传任务 JSON"])
            }
            detail = try await service.updateTask(id: selectedTaskID, try JSONValue.parse(rawTaskBody))
            detailTitle = "保存上传任务"
            showDetail = true
            await load()
        } catch { toast = error.localizedDescription }
    }
    private func saveThreadSettings() async {
        do {
            if rawThreadSettingsBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                seedThreadSettingsTemplate()
            }
            detail = try await service.saveThreadSettings(try JSONValue.parse(rawThreadSettingsBody))
            detailTitle = "线程设置保存"
            showDetail = true
        } catch { toast = error.localizedDescription }
    }
}

struct Drive115CleanupView: View {
    private let service = Drive115CleanupService()
    @State private var tasks: [JSONValue] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?
    @State private var detail: JSONValue?
    @State private var detailTitle = "结果"
    @State private var showDetail = false
    @State private var selectedTaskID = ""
    @State private var rawTaskBody = ""

    private let buttonColumns = [GridItem(.adaptive(minimum: 82), spacing: 8)]

    var body: some View {
        ModuleScaffold(title: "115 清理", isLoading: isLoading && tasks.isEmpty, error: tasks.isEmpty ? error : nil,
                       isEmpty: !isLoading && tasks.isEmpty && error == nil, emptyTitle: "暂无清理任务",
                       emptyIcon: "trash", onRetry: { Task { await load() } },
                       toolbarContent: AnyView(toolbarMenu)) {
            taskEditorCard
            ForEach(Array(tasks.enumerated()), id: \.offset) { _, t in
                let name = t.firstString("name") ?? "清理任务"
                let id = t.firstString("id", "task_id") ?? ""
                let enabled = t["enabled"].bool ?? true
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Circle().fill(enabled ? .green : .gray).frame(width: 8, height: 8)
                            Text(name).font(.subheadline.weight(.medium))
                            Spacer()
                        }
                        LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                            ModuleActionButton(title: "运行", systemImage: "play.fill", prominent: true) { Task { await run(id) } }
                            ModuleActionButton(title: "编辑", systemImage: "square.and.pencil") { fillTask(t) }
                            ModuleActionButton(title: enabled ? "禁用" : "启用", systemImage: enabled ? "pause" : "play") { Task { await toggle(id, !enabled) } }
                            ModuleActionButton(title: "删除", systemImage: "trash", role: .destructive) { Task { await del(id) } }
                        }
                    }
                }
            }
        }
        .task { await load() }
        .toast($toast)
        .sheet(isPresented: $showDetail) { JSONResultSheet(title: detailTitle, json: detail) }
    }

    private var toolbarMenu: some View {
        Menu {
            Button { seedCleanupTaskTemplate() } label: {
                Label("新建任务模板", systemImage: "doc.badge.plus")
            }
            Button { Task { await createTask() } } label: {
                Label("创建任务", systemImage: "plus.circle")
            }
            Button { Task { await updateTask() } } label: {
                Label("保存任务", systemImage: "square.and.arrow.down")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private var taskEditorCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("任务编辑").font(.headline)
                TextField("task_id（更新时填写）", text: $selectedTaskID)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("清理任务 JSON", text: $rawTaskBody, axis: .vertical)
                    .lineLimit(3...10)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "模板", systemImage: "doc.badge.plus") { seedCleanupTaskTemplate() }
                    ModuleActionButton(title: "创建", systemImage: "plus.circle", prominent: true) {
                        Task { await createTask() }
                    }
                    ModuleActionButton(title: "保存", systemImage: "square.and.arrow.down") {
                        Task { await updateTask() }
                    }
                    .disabled(selectedTaskID.isEmpty)
                }
            }
        }
    }

    private func load() async {
        isLoading = true; error = nil
        do { tasks = try await service.tasks() } catch { self.error = error }
        isLoading = false
    }
    private func run(_ id: String) async { do { try await service.run(id: id); toast = "已开始清理" } catch { toast = error.localizedDescription } }
    private func toggle(_ id: String, _ en: Bool) async { do { try await service.toggle(id: id, enabled: en); await load() } catch { toast = error.localizedDescription } }
    private func del(_ id: String) async { do { try await service.delete(id: id); await load() } catch { toast = error.localizedDescription } }
    private func fillTask(_ task: JSONValue) {
        selectedTaskID = task.firstString("id", "task_id") ?? selectedTaskID
        rawTaskBody = task.prettyJSONString()
    }
    private func seedCleanupTaskTemplate() {
        rawTaskBody = """
        {"name":"","cron":"0 3 * * *","enabled":true,"clear_recycle_bin":true,"folders":[]}
        """
    }
    private func createTask() async {
        do {
            guard !rawTaskBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写清理任务 JSON"])
            }
            detail = try await service.createTask(try JSONValue.parse(rawTaskBody))
            detailTitle = "创建清理任务"
            showDetail = true
            await load()
        } catch { toast = error.localizedDescription }
    }
    private func updateTask() async {
        do {
            guard !selectedTaskID.isEmpty else { throw APIError.validation(["请先填写 task_id"]) }
            guard !rawTaskBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写清理任务 JSON"])
            }
            detail = try await service.updateTask(id: selectedTaskID, try JSONValue.parse(rawTaskBody))
            detailTitle = "保存清理任务"
            showDetail = true
            await load()
        } catch { toast = error.localizedDescription }
    }
}
