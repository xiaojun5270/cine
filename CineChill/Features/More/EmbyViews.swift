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
    @State private var showDetail = false

    var body: some View {
        ModuleScaffold(title: "Emby 用户", isLoading: isLoading && users.isEmpty, error: users.isEmpty ? error : nil,
                       isEmpty: !isLoading && users.isEmpty && error == nil, emptyTitle: "暂无用户",
                       onRetry: { Task { await load() } },
                       toolbarContent: AnyView(Button { showCreate = true } label: { Image(systemName: "plus") })) {
            ForEach(Array(users.enumerated()), id: \.offset) { _, user in
                userCard(user)
            }
        }
        .task { await load() }
        .toast($toast)
        .sheet(isPresented: $showCreate) { createSheet }
        .sheet(isPresented: $showDetail) { detailSheet(title: "用户详情", json: detail) }
    }

    private func userCard(_ user: JSONValue) -> some View {
        let name = user.firstString("Name", "name") ?? "用户"
        let id = user.firstString("Id", "id", "user_id") ?? ""
        let disabled = user["Policy"]["IsDisabled"].bool ?? user["disabled"].bool ?? false
        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "person.crop.circle.fill").foregroundStyle(Theme.accent)
                    Text(name).font(.headline)
                    Spacer()
                    StatusChip(text: disabled ? "已禁用" : "启用中", ok: !disabled)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 8)], spacing: 8) {
                    ModuleActionButton(title: "详情", systemImage: "info.circle") {
                        Task { await showUser(id: id) }
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
            Form {
                Section("新用户") {
                    TextField("用户名", text: $newName)
                    SecureField("初始密码（可选）", text: $newPassword)
                }
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
        do { detail = try await service.detail(userID: id); showDetail = true }
        catch { toast = error.localizedDescription }
    }
    private func bind(id: String) async {
        do { try await service.bind(userID: id); toast = "已绑定用户"; await load() }
        catch { toast = error.localizedDescription }
    }
}

struct EmbyTasksView: View {
    private let service = EmbyTasksService()
    @State private var tasks: [JSONValue] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?
    @State private var detail: JSONValue?
    @State private var showDetail = false

    var body: some View {
        ModuleScaffold(title: "Emby 任务", isLoading: isLoading && tasks.isEmpty, error: tasks.isEmpty ? error : nil,
                       isEmpty: !isLoading && tasks.isEmpty && error == nil, emptyTitle: "暂无任务",
                       onRetry: { Task { await load() } }) {
            ForEach(Array(tasks.enumerated()), id: \.offset) { _, task in
                let name = task.firstString("Name", "name") ?? "任务"
                let id = task.firstString("Id", "id") ?? ""
                let state = task.firstString("State", "state", "status")
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(name).font(.subheadline.weight(.medium)).lineLimit(1)
                            Spacer()
                            if let state { GlassPill(state, systemImage: "info.circle") }
                        }
                        HStack(spacing: 10) {
                            ModuleActionButton(title: "运行", systemImage: "play.fill", prominent: true) {
                                Task { await run(id: id) }
                            }
                            ModuleActionButton(title: "停止", systemImage: "stop.fill") {
                                Task { await stop(id: id) }
                            }
                            ModuleActionButton(title: "触发器", systemImage: "clock.badge") {
                                Task { await showTriggers(id: id) }
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .task { await load() }
        .toast($toast)
        .sheet(isPresented: $showDetail) { detailSheet(title: "触发器", json: detail) }
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
        do { detail = try await service.triggers(taskID: id); showDetail = true }
        catch { toast = error.localizedDescription }
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
