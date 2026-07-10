import SwiftUI

struct DockerView: View {
    private let service = DockerService()
    @State private var status: JSONValue?
    @State private var containers: [JSONValue] = []
    @State private var images: [JSONValue] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?
    @State private var logs: String?
    @State private var showLogs = false
    @State private var result: JSONValue?
    @State private var resultTitle = "操作结果"
    @State private var showResult = false
    @State private var pullImageName = ""
    @State private var registryUsername = ""
    @State private var registryToken = ""
    @State private var updateRunID = ""
    @State private var iconURL = ""
    @State private var selectedContainerID = ""
    @State private var selectedContainerImage = ""
    @State private var autoUpdateEnabled = true
    @State private var ignoreUpdate = false
    @State private var restartEnabled = true
    @State private var restartMode = "time"
    @State private var restartTime = "03:30"
    @State private var memoryLimitMB = "0"
    @State private var memoryDurationMinutes = "15"

    private let buttonColumns = [GridItem(.adaptive(minimum: 92), spacing: 8)]

    var body: some View {
        ModuleScaffold(title: "Docker 管理", isLoading: isLoading && containers.isEmpty,
                       error: containers.isEmpty ? error : nil,
                       isEmpty: !isLoading && containers.isEmpty && images.isEmpty && error == nil, emptyTitle: "无容器",
                       emptyIcon: "shippingbox", onRetry: { Task { await load() } },
                       toolbarContent: AnyView(toolbarMenu)) {
            if let status { JSONKeyValueCard(title: "Docker 状态", json: status, limit: 12) }
            imageStatusCard
            registryAuthCard
            containerPolicyCard
            iconResolveCard
            if !containers.isEmpty { SectionHeader(title: "容器") }
            ForEach(Array(containers.enumerated()), id: \.offset) { _, c in
                containerCard(c)
            }
            if !images.isEmpty {
                SectionHeader(title: "镜像")
                ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                    imageCard(image)
                }
            }
        }
        .task { await load() }
        .toast($toast)
        .sheet(isPresented: $showLogs) {
            NavigationStack {
                ScrollView {
                    Text(logs ?? "无日志")
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .background(Theme.backgroundGradient.ignoresSafeArea())
                .navigationTitle("容器日志").navigationBarTitleDisplayMode(.inline)
                .appLiquidNavigationChrome()
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("关闭") { showLogs = false } } }
            }
        }
        .sheet(isPresented: $showResult) { JSONResultSheet(title: resultTitle, json: result) }
    }

    private var imageStatusCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("镜像与状态").font(.headline)
                TextField("镜像名，例如 linuxserver/emby:latest", text: $pullImageName)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("update run_id", text: $updateRunID)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "状态", systemImage: "gauge") {
                        Task { await showStatus() }
                    }
                    ModuleActionButton(title: "拉取镜像", systemImage: "arrow.down.circle", prominent: true) {
                        Task { await pullImage() }
                    }
                    ModuleActionButton(title: "检查更新", systemImage: "arrow.triangle.2.circlepath") {
                        Task { await checkUpdates() }
                    }
                    ModuleActionButton(title: "更新任务", systemImage: "clock.arrow.circlepath") {
                        Task { await updateTask() }
                    }
                }
            }
        }
    }

    private var registryAuthCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("仓库认证").font(.headline)
                TextField("用户名", text: $registryUsername)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                SecureField("Token", text: $registryToken)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "读取", systemImage: "key") {
                        Task { await readRegistryAuth() }
                    }
                    ModuleActionButton(title: "保存", systemImage: "square.and.arrow.down", prominent: true) {
                        Task { await saveRegistryAuth() }
                    }
                    ModuleActionButton(title: "删除", systemImage: "trash", role: .destructive) {
                        Task { await deleteRegistryAuth() }
                    }
                }
            }
        }
    }

    private var containerPolicyCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("容器策略").font(.headline)
                TextField("container_id", text: $selectedContainerID)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("镜像 / compose_image", text: $selectedContainerImage)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                Toggle("自动更新", isOn: $autoUpdateEnabled)
                Toggle("忽略更新", isOn: $ignoreUpdate)
                HStack(spacing: 10) {
                    TextField("重启时间", text: $restartTime)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("内存 MB", text: $memoryLimitMB)
                        .keyboardType(.decimalPad)
                    TextField("持续分钟", text: $memoryDurationMinutes)
                        .keyboardType(.numberPad)
                }
                .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                Picker("重启模式", selection: $restartMode) {
                    Text("时间").tag("time")
                    Text("内存").tag("memory")
                }
                .pickerStyle(.segmented)
                Toggle("启用重启策略", isOn: $restartEnabled)
                LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "自动更新", systemImage: "arrow.down.to.line", prominent: true) {
                        Task { await setAutoUpdate() }
                    }
                    ModuleActionButton(title: "忽略更新", systemImage: "bell.slash") {
                        Task { await setIgnoreUpdate() }
                    }
                    ModuleActionButton(title: "Compose镜像", systemImage: "shippingbox.and.arrow.backward") {
                        Task { await setComposeImage() }
                    }
                    ModuleActionButton(title: "自动重启", systemImage: "arrow.clockwise.circle") {
                        Task { await setRestart(scheduled: false) }
                    }
                    ModuleActionButton(title: "定时重启", systemImage: "timer") {
                        Task { await setRestart(scheduled: true) }
                    }
                }
            }
        }
    }

    private var iconResolveCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("图标解析").font(.headline)
                TextField("图标 URL", text: $iconURL)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                ModuleActionButton(title: "解析图标", systemImage: "photo.badge.checkmark", prominent: true) {
                    Task { await resolveIcon() }
                }
            }
        }
    }

    private var toolbarMenu: some View {
        Menu {
            Button {
                Task { await showStatus() }
            } label: {
                Label("Docker 状态", systemImage: "gauge")
            }
            Button {
                Task { await pullImage() }
            } label: {
                Label("拉取镜像", systemImage: "arrow.down.circle")
            }
            Button {
                Task { await readRegistryAuth() }
            } label: {
                Label("读取仓库认证", systemImage: "key")
            }
            Button {
                Task { await checkUpdates() }
            } label: {
                Label("检查镜像更新", systemImage: "arrow.down.circle")
            }
            Button(role: .destructive) {
                Task { await pruneUnused() }
            } label: {
                Label("清理未使用镜像", systemImage: "trash")
            }
            Button(role: .destructive) {
                Task { await pruneUntagged() }
            } label: {
                Label("清理无标签镜像", systemImage: "tag.slash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private func containerCard(_ c: JSONValue) -> some View {
        let name = c.firstString("name", "Name", "names") ?? "容器"
        let id = c.firstString("id", "Id", "container_id") ?? ""
        let image = containerImage(c)
        let state = c.firstString("state", "State", "status", "Status") ?? ""
        let running = state.lowercased().contains("run") || state.lowercased().contains("up")
        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Circle().fill(running ? .green : .gray).frame(width: 8, height: 8)
                    Text(name).font(.subheadline.weight(.medium)).lineLimit(1)
                    Spacer()
                    Text(state).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                if !image.isEmpty {
                    Text(image).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "启动", systemImage: "play.fill", prominent: true) { Task { await action(id, "start") } }
                    ModuleActionButton(title: "停止", systemImage: "stop.fill") { Task { await action(id, "stop") } }
                    ModuleActionButton(title: "重启", systemImage: "arrow.clockwise") { Task { await action(id, "restart") } }
                    ModuleActionButton(title: "日志", systemImage: "doc.text") { Task { await loadLogs(id) } }
                    ModuleActionButton(title: "填入", systemImage: "square.and.pencil") { fillContainer(id: id, image: image) }
                    ModuleActionButton(title: "重建", systemImage: "hammer") { Task { await action(id, "recreate") } }
                    ModuleActionButton(title: "删除", systemImage: "trash", role: .destructive) { Task { await action(id, "remove") } }
                }
            }
        }
    }

    private func imageCard(_ image: JSONValue) -> some View {
        let id = image.firstString("id", "Id", "image_id") ?? ""
        let repo = image.firstString("repository", "Repository", "repo", "name") ?? "<none>"
        let tag = image.firstString("tag", "Tag") ?? ""
        let size = image.firstString("size", "Size")
        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "shippingbox")
                        .foregroundStyle(Theme.accent)
                    Text(tag.isEmpty ? repo : "\(repo):\(tag)")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Spacer()
                }
                HStack {
                    if let size { Text(size).font(.caption2).foregroundStyle(.secondary) }
                    Spacer()
                    ModuleActionButton(title: "填入", systemImage: "square.and.pencil") {
                        pullImageName = tag.isEmpty ? repo : "\(repo):\(tag)"
                        selectedContainerImage = pullImageName
                    }
                    ModuleActionButton(title: "删除", systemImage: "trash", role: .destructive) {
                        Task { await deleteImage(id) }
                    }
                    .disabled(id.isEmpty)
                }
            }
        }
    }

    private func load() async {
        isLoading = true; error = nil
        async let s = service.status()
        async let c = service.containers()
        async let i = service.images()
        do { containers = try await c } catch { self.error = error }
        status = try? await s
        images = (try? await i) ?? []
        isLoading = false
    }
    private func action(_ id: String, _ act: String) async {
        guard !id.isEmpty else { return }
        do {
            let response = try await service.containerAction(id: id, action: act)
            toast = "已执行：\(act)"
            if !response.isNull { show("容器操作", response) }
            await load()
        }
        catch { toast = error.localizedDescription }
    }
    private func loadLogs(_ id: String) async {
        do {
            let json = try await service.logs(id: id)
            logs = json.string ?? json["logs"].string ?? json.firstString("content", "output") ?? "无日志"
            showLogs = true
        } catch { toast = error.localizedDescription }
    }

    private func showStatus() async {
        do {
            status = try await service.status()
            show("Docker 状态", status)
        } catch { toast = error.localizedDescription }
    }

    private func checkUpdates() async {
        let names = containers.compactMap { $0.firstString("image", "Image") }
        guard !names.isEmpty else {
            toast = "未找到可检查的镜像"
            return
        }
        do {
            show("镜像更新", try await service.checkUpdates(images: names))
        } catch { toast = error.localizedDescription }
    }

    private func pullImage() async {
        do {
            guard !pullImageName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写镜像名"])
            }
            show("拉取镜像", try await service.pullImage(pullImageName))
            await load()
        } catch { toast = error.localizedDescription }
    }

    private func readRegistryAuth() async {
        do {
            let auth = try await service.registryAuth()
            registryUsername = auth.firstString("username", "user") ?? registryUsername
            show("仓库认证", auth)
        } catch { toast = error.localizedDescription }
    }

    private func saveRegistryAuth() async {
        do {
            show("仓库认证保存", try await service.saveRegistryAuth(username: registryUsername, token: registryToken))
        } catch { toast = error.localizedDescription }
    }

    private func deleteRegistryAuth() async {
        do {
            show("仓库认证删除", try await service.deleteRegistryAuth())
            registryUsername = ""
            registryToken = ""
        } catch { toast = error.localizedDescription }
    }

    private func updateTask() async {
        do {
            guard !updateRunID.isEmpty else { throw APIError.validation(["请填写 run_id"]) }
            show("更新任务", try await service.updateTask(runID: updateRunID))
        } catch { toast = error.localizedDescription }
    }

    private func resolveIcon() async {
        do {
            guard !iconURL.isEmpty else { throw APIError.validation(["请填写图标 URL"]) }
            show("图标解析", try await service.resolveIcon(url: iconURL))
        } catch { toast = error.localizedDescription }
    }

    private func setAutoUpdate() async {
        do {
            let id = try selectedID()
            show("自动更新", try await service.setAutoUpdate(id: id, enabled: autoUpdateEnabled, image: selectedContainerImage.isEmpty ? nil : selectedContainerImage))
            await load()
        } catch { toast = error.localizedDescription }
    }

    private func setIgnoreUpdate() async {
        do {
            let id = try selectedID()
            show("忽略更新", try await service.setIgnoreUpdate(id: id, ignored: ignoreUpdate))
            await load()
        } catch { toast = error.localizedDescription }
    }

    private func setComposeImage() async {
        do {
            let id = try selectedID()
            guard !selectedContainerImage.isEmpty else { throw APIError.validation(["请填写镜像"]) }
            show("Compose 镜像", try await service.setComposeImage(id: id, image: selectedContainerImage))
            await load()
        } catch { toast = error.localizedDescription }
    }

    private func setRestart(scheduled: Bool) async {
        do {
            let id = try selectedID()
            let memory = Double(memoryLimitMB) ?? 0
            let duration = Int(memoryDurationMinutes) ?? 15
            let response: JSONValue
            if scheduled {
                response = try await service.setScheduledRestart(id: id, enabled: restartEnabled, mode: restartMode, time: restartTime, memoryLimitMB: memory, memoryDurationMinutes: duration)
            } else {
                response = try await service.setAutoRestart(id: id, enabled: restartEnabled, mode: restartMode, time: restartTime, memoryLimitMB: memory, memoryDurationMinutes: duration)
            }
            show(scheduled ? "定时重启" : "自动重启", response)
            await load()
        } catch { toast = error.localizedDescription }
    }

    private func pruneUnused() async {
        do { try await service.pruneUnused(); toast = "已清理未使用镜像"; await load() }
        catch { toast = error.localizedDescription }
    }

    private func pruneUntagged() async {
        do { try await service.pruneUntagged(); toast = "已清理无标签镜像"; await load() }
        catch { toast = error.localizedDescription }
    }

    private func deleteImage(_ id: String) async {
        guard !id.isEmpty else { return }
        do { try await service.deleteImage(id: id, force: true); toast = "已删除镜像"; await load() }
        catch { toast = error.localizedDescription }
    }

    private func selectedID() throws -> String {
        guard !selectedContainerID.isEmpty else { throw APIError.validation(["请先选择或填写 container_id"]) }
        return selectedContainerID
    }

    private func fillContainer(id: String, image: String) {
        selectedContainerID = id
        selectedContainerImage = image
        pullImageName = image
    }

    private func containerImage(_ json: JSONValue) -> String {
        json.firstString("image", "Image", "compose_image", "repository") ?? ""
    }

    private func show(_ title: String, _ json: JSONValue?) {
        resultTitle = title
        result = json
        showResult = true
    }
}
