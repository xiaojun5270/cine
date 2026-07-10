import SwiftUI

struct EmbyUsersView: View {
    private let service = EmbyUsersService()
    @State private var users: [JSONValue] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?
    @State private var showCreate = false
    @State private var newName = ""
    @State private var newPassword = ""
    @State private var detail: JSONValue?
    @State private var detailTitle = "用户详情"
    @State private var showDetail = false
    @State private var selectedUserID = ""
    @State private var rawUserBody = ""
    @State private var passwordCurrent = ""
    @State private var passwordNew = ""
    @State private var resetPassword = true

    private let buttonColumns = [GridItem(.adaptive(minimum: 78), spacing: 8)]

    var body: some View {
        ModuleScaffold(title: "Emby 用户", isLoading: isLoading && users.isEmpty, error: users.isEmpty ? error : nil,
                       isEmpty: !isLoading && users.isEmpty && error == nil, emptyTitle: "暂无用户",
                       onRetry: { Task { await load() } },
                       toolbarContent: AnyView(Button { showCreate = true } label: { Image(systemName: "plus") })) {
            userEditorCard
            ForEach(Array(users.enumerated()), id: \.offset) { _, user in
                userCard(user)
            }
        }
        .task { await load() }
        .toast($toast)
        .sheet(isPresented: $showCreate) { createSheet }
        .sheet(isPresented: $showDetail) { detailSheet(title: detailTitle, json: detail) }
    }

    private var userEditorCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("用户编辑").font(.headline)
                TextField("user_id", text: $selectedUserID)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("用户更新 JSON", text: $rawUserBody, axis: .vertical)
                    .lineLimit(3...10)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                HStack(spacing: 10) {
                    SecureField("当前密码（可选）", text: $passwordCurrent)
                    SecureField("新密码", text: $passwordNew)
                }
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                Toggle("重置密码", isOn: $resetPassword)
                LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "模板", systemImage: "doc.badge.plus") { seedUserTemplate() }
                    ModuleActionButton(title: "保存用户", systemImage: "square.and.arrow.down", prominent: true) {
                        Task { await updateUser() }
                    }
                    .disabled(selectedUserID.isEmpty)
                    ModuleActionButton(title: "改密码", systemImage: "key") {
                        Task { await setPassword() }
                    }
                    .disabled(selectedUserID.isEmpty || passwordNew.isEmpty)
                }
            }
        }
    }

    private func userCard(_ user: JSONValue) -> some View {
        let name = user.firstString("Name", "name") ?? "用户"
        let id = user.firstString("Id", "id", "user_id") ?? ""
        let disabled = user["Policy"]["IsDisabled"].bool ?? user["disabled"].bool ?? false
        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    IconBadge(systemImage: disabled ? "person.crop.circle.badge.xmark" : "person.crop.circle.fill",
                              tint: disabled ? .gray : Theme.accent,
                              size: 38)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(name)
                            .font(.headline)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                            .allowsTightening(true)
                        if !id.isEmpty {
                            Text(id)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
                        }
                    }
                    .layoutPriority(1)
                    Spacer()
                    GlassPill(disabled ? "已禁用" : "启用中",
                              systemImage: disabled ? "pause.circle" : "checkmark.circle.fill",
                              tint: disabled ? .gray : Theme.success)
                }
                LazyVGrid(columns: buttonColumns, spacing: 8) {
                    ModuleActionButton(title: "详情", systemImage: "info.circle") {
                        Task { await showUser(id: id) }
                    }
                    ModuleActionButton(title: "编辑", systemImage: "square.and.pencil") {
                        fillUser(user)
                    }
                    ModuleActionButton(title: "绑定", systemImage: "link") {
                        Task { await bind(id: id) }
                    }
                    ModuleActionButton(title: disabled ? "启用" : "禁用",
                                       systemImage: disabled ? "checkmark.circle" : "nosign") {
                        Task { await setDisabled(id: id, disabled: !disabled) }
                    }
                    ModuleActionButton(title: "删除", systemImage: "trash", role: .destructive) {
                        Task { await delete(id: id) }
                    }
                }
            }
        }
    }

    private var createSheet: some View {
        NavigationStack {
            ScrollView {
                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            IconBadge(systemImage: "person.crop.circle.badge.plus", tint: Theme.accent, size: 44)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("新用户").font(.headline)
                                Text("创建 Emby 用户并可设置初始密码").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        TextField("用户名", text: $newName)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.username)
                            .appInputFieldChrome()
                        SecureField("初始密码（可选）", text: $newPassword)
                            .textContentType(.newPassword)
                            .appInputFieldChrome()
                    }
                }
                .padding(Theme.screenPadding)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("创建用户").navigationBarTitleDisplayMode(.inline)
            .appLiquidNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { showCreate = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") { Task { await create() } }.disabled(newName.isEmpty)
                }
            }
        }
    }

    private func load() async {
        isLoading = true; error = nil
        do { users = try await service.list() } catch { self.error = error }
        isLoading = false
    }
    private func create() async {
        do {
            try await service.create(name: newName, templateUserID: nil, password: newPassword.isEmpty ? nil : newPassword)
            showCreate = false; newName = ""; newPassword = ""
            await load()
        } catch { toast = error.localizedDescription }
    }
    private func setDisabled(id: String, disabled: Bool) async {
        do { try await service.setDisabled(userID: id, disabled: disabled); await load() }
        catch { toast = error.localizedDescription }
    }
    private func delete(id: String) async {
        do { try await service.delete(userID: id); await load() }
        catch { toast = error.localizedDescription }
    }
    private func showUser(id: String) async {
        do {
            detail = try await service.detail(userID: id)
            detailTitle = "用户详情"
            showDetail = true
        }
        catch { toast = error.localizedDescription }
    }
    private func bind(id: String) async {
        do { try await service.bind(userID: id); toast = "已绑定用户"; await load() }
        catch { toast = error.localizedDescription }
    }
    private func fillUser(_ user: JSONValue) {
        selectedUserID = user.firstString("Id", "id", "user_id") ?? selectedUserID
        rawUserBody = user.prettyJSONString()
    }
    private func seedUserTemplate() {
        rawUserBody = """
        {"Name":"","Policy":{},"Configuration":{}}
        """
    }
    private func updateUser() async {
        do {
            guard !selectedUserID.isEmpty else { throw APIError.validation(["请先填写 user_id"]) }
            guard !rawUserBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写用户更新 JSON"])
            }
            detail = try await service.update(userID: selectedUserID, try JSONValue.parse(rawUserBody))
            detailTitle = "用户保存"
            showDetail = true
            await load()
        } catch { toast = error.localizedDescription }
    }
    private func setPassword() async {
        do {
            guard !selectedUserID.isEmpty else { throw APIError.validation(["请先填写 user_id"]) }
            guard !passwordNew.isEmpty else { throw APIError.validation(["请填写新密码"]) }
            detail = try await service.setPassword(
                userID: selectedUserID,
                newPassword: passwordNew,
                currentPassword: passwordCurrent.isEmpty ? nil : passwordCurrent,
                reset: resetPassword
            )
            detailTitle = "密码保存"
            showDetail = true
            passwordCurrent = ""
            passwordNew = ""
        } catch { toast = error.localizedDescription }
    }
}

struct EmbyTasksView: View {
    private let service = EmbyTasksService()
    @State private var tasks: [JSONValue] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?
    @State private var detail: JSONValue?
    @State private var detailTitle = "触发器"
    @State private var showDetail = false
    @State private var selectedTaskID = ""
    @State private var rawTriggersBody = ""

    private let buttonColumns = [GridItem(.adaptive(minimum: 78), spacing: 8)]

    var body: some View {
        ModuleScaffold(title: "Emby 任务", isLoading: isLoading && tasks.isEmpty, error: tasks.isEmpty ? error : nil,
                       isEmpty: !isLoading && tasks.isEmpty && error == nil, emptyTitle: "暂无任务",
                       onRetry: { Task { await load() } }) {
            triggerEditorCard
            ForEach(Array(tasks.enumerated()), id: \.offset) { _, task in
                let name = task.firstString("Name", "name") ?? "任务"
                let id = task.firstString("Id", "id") ?? ""
                let state = task.firstString("State", "state", "status")
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(name)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(2)
                                .minimumScaleFactor(0.82)
                                .allowsTightening(true)
                                .layoutPriority(1)
                            Spacer()
                            if let state { GlassPill(state, systemImage: "info.circle") }
                        }
                        LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                            ModuleActionButton(title: "运行", systemImage: "play.fill", prominent: true) {
                                Task { await run(id: id) }
                            }
                            ModuleActionButton(title: "停止", systemImage: "stop.fill") {
                                Task { await stop(id: id) }
                            }
                            ModuleActionButton(title: "触发器", systemImage: "clock.badge") {
                                Task { await showTriggers(id: id) }
                            }
                            ModuleActionButton(title: "编辑", systemImage: "square.and.pencil") {
                                Task { await editTriggers(id: id) }
                            }
                        }
                    }
                }
            }
        }
        .task { await load() }
        .toast($toast)
        .sheet(isPresented: $showDetail) { detailSheet(title: detailTitle, json: detail) }
    }

    private var triggerEditorCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("触发器编辑").font(.headline)
                TextField("task_id", text: $selectedTaskID)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("触发器 JSON（数组或包含 triggers 的对象）", text: $rawTriggersBody, axis: .vertical)
                    .lineLimit(3...10)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                LazyVGrid(columns: buttonColumns, alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "模板", systemImage: "doc.badge.plus") { rawTriggersBody = "[]" }
                    ModuleActionButton(title: "读取", systemImage: "clock.badge") {
                        Task { await editTriggers(id: selectedTaskID) }
                    }
                    .disabled(selectedTaskID.isEmpty)
                    ModuleActionButton(title: "保存", systemImage: "square.and.arrow.down", prominent: true) {
                        Task { await saveTriggers() }
                    }
                    .disabled(selectedTaskID.isEmpty)
                }
            }
        }
    }

    private func load() async {
        isLoading = true; error = nil
        do { tasks = try await service.list() } catch { self.error = error }
        isLoading = false
    }
    private func run(id: String) async {
        do { try await service.run(taskID: id); toast = "已开始运行" } catch { toast = error.localizedDescription }
    }
    private func stop(id: String) async {
        do { try await service.stop(taskID: id); toast = "已停止" } catch { toast = error.localizedDescription }
    }
    private func showTriggers(id: String) async {
        do {
            detail = try await service.triggers(taskID: id)
            detailTitle = "触发器"
            showDetail = true
        }
        catch { toast = error.localizedDescription }
    }
    private func editTriggers(id: String) async {
        guard !id.isEmpty else { return }
        do {
            selectedTaskID = id
            detail = try await service.triggers(taskID: id)
            rawTriggersBody = detail?.prettyJSONString() ?? ""
            detailTitle = "触发器"
            showDetail = true
        } catch { toast = error.localizedDescription }
    }
    private func saveTriggers() async {
        do {
            guard !selectedTaskID.isEmpty else { throw APIError.validation(["请先填写 task_id"]) }
            guard !rawTriggersBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写触发器 JSON"])
            }
            let json = try JSONValue.parse(rawTriggersBody)
            let triggers = json["triggers"].isNull ? json : json["triggers"]
            try await service.saveTriggers(taskID: selectedTaskID, triggers: triggers)
            toast = "触发器已保存"
            await load()
        } catch { toast = error.localizedDescription }
    }
}

private func detailSheet(title: String, json: JSONValue?) -> some View {
    NavigationStack {
        ScrollView {
            if let json {
                JSONKeyValueCard(title: nil, json: json, limit: 80)
                    .padding(Theme.screenPadding)
            } else {
                EmptyStateView(systemImage: "doc.text", title: "暂无内容")
            }
        }
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .appLiquidNavigationChrome()
    }
}
