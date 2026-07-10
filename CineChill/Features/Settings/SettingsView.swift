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
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                accountHeader
                settingsGroup("通知") {
                    NavigationLink { NotifyView() } label: {
                        settingsRow(title: "通知配置", subtitle: "Telegram、企业微信、模板", icon: "bell.badge.fill", tint: Theme.accentPink)
                    }
                    .buttonStyle(.plain)
                }
                settingsGroup("账号与服务器") {
                    Button { showChangePassword = true } label: {
                        settingsRow(title: "修改账号 / 密码", subtitle: "更新当前登录凭据", icon: "key.fill", tint: Theme.accentWarm)
                    }
                    Button { Task { await openServerConfig() } } label: {
                        settingsRow(title: "编辑服务器配置", subtitle: "读取和保存全局 JSON", icon: "slider.horizontal.3", tint: Theme.accent)
                    }
                    Button { showServerTools = true } label: {
                        settingsRow(title: "服务器接口工具", subtitle: "Emby、代理、海报 URL", icon: "wrench.and.screwdriver.fill", tint: Theme.accentBlue)
                    }
                    Button { session.forgetServer() } label: {
                        settingsRow(title: "更换服务器", subtitle: "回到服务器连接页", icon: "arrow.triangle.2.circlepath", tint: .cyan)
                    }
                    Button(role: .destructive) { showRestartConfirm = true } label: {
                        settingsRow(title: "重启服务器", subtitle: "发送后端重启指令", icon: "power", tint: Theme.danger)
                    }
                }
                settingsGroup("会话") {
                    Button(role: .destructive) { showLogoutConfirm = true } label: {
                        settingsRow(title: "退出登录", subtitle: "清除当前登录状态", icon: "rectangle.portrait.and.arrow.right", tint: Theme.danger)
                    }
                }
                versionCard
            }
            .padding(Theme.screenPadding)
            .padding(.bottom, 36)
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

    private var accountHeader: some View {
        GlassCard {
            HStack(spacing: 14) {
                IconBadge(systemImage: "person.crop.circle.fill", tint: Theme.accent, size: 54, cornerRadius: 17)
                VStack(alignment: .leading, spacing: 5) {
                    Text(session.username ?? "用户")
                        .font(.title3.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(session.server?.displayString ?? "未连接服务器")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .layoutPriority(1)
                Spacer()
                GlassPill("在线", systemImage: "checkmark.circle.fill", tint: Theme.success)
            }
        }
    }

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: title)
            GlassCard {
                VStack(spacing: 2) {
                    content()
                }
            }
        }
    }

    private func settingsRow(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            IconBadge(systemImage: icon, tint: tint, size: 38, cornerRadius: 12)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .allowsTightening(true)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .layoutPriority(1)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(.primary)
        .padding(.vertical, 7)
    }

    private var versionCard: some View {
        GlassCard {
            HStack {
                GlassPill("CineChill Mobile", systemImage: "app.badge")
                Spacer()
                Text("1.0.0").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            }
        }
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
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 12) {
                                IconBadge(systemImage: "key.fill", tint: Theme.accentWarm, size: 44)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("修改登录凭据").font(.headline)
                                    Text("保存后需要重新登录").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            SecureField("当前密码", text: $oldPassword)
                                .textContentType(.password)
                                .appInputFieldChrome()
                            TextField("新用户名", text: $newUsername)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textContentType(.username)
                                .appInputFieldChrome()
                            SecureField("新密码", text: $newPassword)
                                .textContentType(.newPassword)
                                .appInputFieldChrome()
                        }
                    }
                    if let errorText {
                        GlassCard {
                            Label(errorText, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(Theme.danger)
                        }
                    }
                }
                .padding(Theme.screenPadding)
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
