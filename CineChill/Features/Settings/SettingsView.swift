import SwiftUI

struct SettingsView: View {
    @Environment(SessionStore.self) private var session
    @State private var showChangePassword = false
    @State private var showServerConfig = false
    @State private var showServerTools = false
    @State private var showLogoutConfirm = false
    @State private var showRestartConfirm = false
    @State private var toast: String?
    @State private var serverConfig: JSONValue?
    @State private var rawServerConfig = ""

    var body: some View {
        List {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.username ?? "用户").font(.headline)
                            Text(session.server?.displayString ?? "").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("通知") {
                    NavigationLink { NotifyView() } label: {
                        Label("通知配置", systemImage: "bell.badge.fill")
                    }
                }

                Section("账号与服务器") {
                    Button { showChangePassword = true } label: {
                        Label("修改账号 / 密码", systemImage: "key.fill")
                    }
                    Button { Task { await openServerConfig() } } label: {
                        Label("编辑服务器配置", systemImage: "slider.horizontal.3")
                    }
                    Button { showServerTools = true } label: {
                        Label("服务器接口工具", systemImage: "wrench.and.screwdriver")
                    }
                    Button { session.forgetServer() } label: {
                        Label("更换服务器", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button(role: .destructive) { showRestartConfirm = true } label: {
                        Label("重启服务器", systemImage: "power")
                    }
                }

                Section {
                    Button(role: .destructive) { showLogoutConfirm = true } label: {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                Section {
                    HStack {
                        Text("版本"); Spacer()
                        Text("CineChill Mobile 1.0.0").foregroundStyle(.secondary)
                    }
                    .font(.footnote)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("设置")
            .appLiquidNavigationChrome()
            .sheet(isPresented: $showChangePassword) { ChangePasswordView() }
            .sheet(isPresented: $showServerConfig) { serverConfigSheet }
            .sheet(isPresented: $showServerTools) { ServerToolsSheet() }
            .confirmationDialog("确定退出登录？", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("退出登录", role: .destructive) { session.logout() }
                Button("取消", role: .cancel) {}
            }
            .confirmationDialog("确定重启服务器？", isPresented: $showRestartConfirm, titleVisibility: .visible) {
                Button("重启", role: .destructive) { Task { await restart() } }
                Button("取消", role: .cancel) {}
            }
            .alert("提示", isPresented: Binding(
                get: { toast != nil }, set: { if !$0 { toast = nil } }
            )) { Button("好", role: .cancel) {} } message: { Text(toast ?? "") }
    }

    private var serverConfigSheet: some View {
        NavigationStack {
            ScrollView {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("服务器配置").font(.headline)
                        TextField("服务器配置 JSON", text: $rawServerConfig, axis: .vertical)
                            .lineLimit(8...20)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .font(.system(.caption, design: .monospaced))
                            .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                        if let serverConfig {
                            JSONKeyValueCard(title: "当前配置", json: serverConfig, limit: 20)
                        }
                    }
                }
                .padding(Theme.screenPadding)
            }
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("服务器配置")
            .navigationBarTitleDisplayMode(.inline)
            .appLiquidNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { showServerConfig = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await saveServerConfig() } }
                        .disabled(rawServerConfig.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func openServerConfig() async {
        do {
            serverConfig = try await ServerService().loadConfig()
            rawServerConfig = serverConfig?.prettyJSONString() ?? "{}"
            showServerConfig = true
        } catch { toast = error.localizedDescription }
    }

    private func saveServerConfig() async {
        do {
            serverConfig = try await ServerService().saveConfig(try JSONValue.parse(rawServerConfig))
            toast = "服务器配置已保存"
            showServerConfig = false
        } catch { toast = error.localizedDescription }
    }

    private func restart() async {
        do { try await ServerService().restart(); toast = "已发送重启指令" }
        catch { toast = error.localizedDescription }
    }
}

private struct ServerToolsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var rawConnectBody = ""
    @State private var rawProxyBody = ""
    @State private var rawSearchBody = ""
    @State private var rawImagesBody = ""
    @State private var rawRandomPoolBody = ""
    @State private var rawLibraryCoversBody = ""
    @State private var loginPosterID = ""
    @State private var loginPosterTag = ""
    @State private var result: JSONValue?
    @State private var resultTitle = "结果"
    @State private var showResult = false
    @State private var toast: String?

    private let service = ServerService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    connectionCard
                    embyCard
                }
                .padding(Theme.screenPadding)
            }
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("服务器接口工具")
            .navigationBarTitleDisplayMode(.inline)
            .appLiquidNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .toast($toast)
            .sheet(isPresented: $showResult) {
                JSONResultSheet(title: resultTitle, json: result)
            }
        }
    }

    private var connectionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("连接与代理").font(.headline)
                TextField("Connect JSON", text: $rawConnectBody, axis: .vertical)
                    .lineLimit(2...6)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .font(.system(.caption, design: .monospaced))
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("Proxy Test JSON", text: $rawProxyBody, axis: .vertical)
                    .lineLimit(2...6)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .font(.system(.caption, design: .monospaced))
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                HStack(spacing: 10) {
                    TextField("login poster item_id", text: $loginPosterID)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("tag", text: $loginPosterTag)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "连接模板", systemImage: "doc.badge.plus") { seedConnectBody() }
                    ModuleActionButton(title: "连接测试", systemImage: "link", prominent: true) {
                        Task { await runJSON("连接测试", text: rawConnectBody) { try await service.connect($0) } }
                    }
                    ModuleActionButton(title: "代理模板", systemImage: "doc.badge.gearshape") { seedProxyBody() }
                    ModuleActionButton(title: "代理测试", systemImage: "network") {
                        Task { await runJSON("代理测试", text: rawProxyBody) { try await service.proxyTest($0) } }
                    }
                    ModuleActionButton(title: "海报URL", systemImage: "photo") {
                        Task { await loginPosterURL() }
                    }
                    ModuleActionButton(title: "首页URL", systemImage: "house") {
                        showMiscURL("前端首页 URL") { try MiscService().frontendIndexURL() }
                    }
                    ModuleActionButton(title: "登录URL", systemImage: "person.crop.circle") {
                        showMiscURL("前端登录 URL") { try MiscService().frontendLoginURL() }
                    }
                }
            }
        }
    }

    private var embyCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Emby 工具").font(.headline)
                TextField("Emby Search JSON", text: $rawSearchBody, axis: .vertical)
                    .lineLimit(2...6)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .font(.system(.caption, design: .monospaced))
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("Emby Get Images JSON", text: $rawImagesBody, axis: .vertical)
                    .lineLimit(2...6)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .font(.system(.caption, design: .monospaced))
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("Emby Random Pool JSON", text: $rawRandomPoolBody, axis: .vertical)
                    .lineLimit(2...6)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .font(.system(.caption, design: .monospaced))
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("Library Covers JSON", text: $rawLibraryCoversBody, axis: .vertical)
                    .lineLimit(2...6)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .font(.system(.caption, design: .monospaced))
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "搜索模板", systemImage: "doc.text") { seedSearchBody() }
                    ModuleActionButton(title: "Emby搜索", systemImage: "magnifyingglass", prominent: true) {
                        Task { await runJSON("Emby 搜索", text: rawSearchBody) { try await service.embySearch($0) } }
                    }
                    ModuleActionButton(title: "图片模板", systemImage: "doc.on.doc") { seedImagesBody() }
                    ModuleActionButton(title: "取图片", systemImage: "photo") {
                        Task { await runJSON("Emby 图片", text: rawImagesBody) { try await service.embyGetImages($0) } }
                    }
                    ModuleActionButton(title: "随机模板", systemImage: "shuffle") { seedRandomPoolBody() }
                    ModuleActionButton(title: "随机池", systemImage: "rectangle.stack") {
                        Task { await runJSON("Emby 随机池", text: rawRandomPoolBody) { try await service.embyRandomPool($0) } }
                    }
                    ModuleActionButton(title: "封面模板", systemImage: "rectangle.on.rectangle") { seedLibraryCoversBody() }
                    ModuleActionButton(title: "库封面", systemImage: "photo.stack") {
                        Task { await runJSON("媒体库封面", text: rawLibraryCoversBody) { try await service.libraryCovers($0) } }
                    }
                }
            }
        }
    }

    private func runJSON(_ title: String, text: String, operation: (JSONValue) async throws -> JSONValue) async {
        do {
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写 \(title) JSON"])
            }
            result = try await operation(try JSONValue.parse(text))
            resultTitle = title
            showResult = true
        } catch { toast = error.localizedDescription }
    }

    private func loginPosterURL() async {
        do {
            guard !loginPosterID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写 login poster item_id"])
            }
            result = try MiscService().loginPosterURL(
                itemID: loginPosterID,
                tag: loginPosterTag.isEmpty ? nil : loginPosterTag
            )
            resultTitle = "登录海报 URL"
            showResult = true
        } catch { toast = error.localizedDescription }
    }

    private func showMiscURL(_ title: String, operation: () throws -> JSONValue) {
        do {
            result = try operation()
            resultTitle = title
            showResult = true
        } catch { toast = error.localizedDescription }
    }

    private func seedConnectBody() {
        rawConnectBody = """
        {"url":"","key":""}
        """
    }

    private func seedProxyBody() {
        rawProxyBody = """
        {"enabled":false,"url":"","username":"","password":""}
        """
    }

    private func seedSearchBody() {
        rawSearchBody = """
        {"url":"","key":"","query":"","library_id":"","type":"Primary"}
        """
    }

    private func seedImagesBody() {
        rawImagesBody = """
        {"url":"","key":"","item_id":"","type":"Backdrop"}
        """
    }

    private func seedRandomPoolBody() {
        rawRandomPoolBody = """
        {"url":"","key":"","library_id":"","type":"Backdrop","limit":50}
        """
    }

    private func seedLibraryCoversBody() {
        rawLibraryCoversBody = """
        {"url":"","key":""}
        """
    }
}

/// Change username / password via /api/change_auth.
struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session

    @State private var oldPassword = ""
    @State private var newUsername = ""
    @State private var newPassword = ""
    @State private var isSaving = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("当前") {
                    SecureField("当前密码", text: $oldPassword)
                }
                Section("新账号") {
                    TextField("新用户名", text: $newUsername)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("新密码", text: $newPassword)
                }
                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red).font(.footnote) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("修改账号")
            .navigationBarTitleDisplayMode(.inline)
            .appLiquidNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await save() } }
                        .disabled(oldPassword.isEmpty || newUsername.isEmpty || newPassword.isEmpty || isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await AuthService().changeAuth(oldPassword: oldPassword, newUsername: newUsername, newPassword: newPassword)
            // Credentials changed — require fresh login.
            session.logout()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
