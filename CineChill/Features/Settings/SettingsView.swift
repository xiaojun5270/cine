import SwiftUI

struct SettingsView: View {
    @Environment(SessionStore.self) private var session
    @State private var showChangePassword = false
    @State private var showLogoutConfirm = false
    @State private var showRestartConfirm = false
    @State private var toast: String?

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

    private func restart() async {
        do { try await ServerService().restart(); toast = "已发送重启指令" }
        catch { toast = error.localizedDescription }
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
