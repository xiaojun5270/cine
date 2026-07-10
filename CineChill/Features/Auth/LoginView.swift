import SwiftUI

struct LoginView: View {
    @Environment(SessionStore.self) private var session

    @State private var username = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var errorText: String?
    @FocusState private var focused: Field?

    enum Field { case username, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header

                GlassCard {
                    VStack(spacing: 16) {
                        field(icon: "person.fill", placeholder: "用户名", text: $username, isSecure: false)
                            .focused($focused, equals: .username)
                            .submitLabel(.next)
                            .onSubmit { focused = .password }

                        field(icon: "lock.fill", placeholder: "密码", text: $password, isSecure: true)
                            .focused($focused, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { Task { await login() } }

                        if let errorText {
                            Text(errorText).font(.footnote).foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        GlassPrimaryButton(title: "登录", systemImage: "arrow.right.circle.fill",
                                           isLoading: isLoggingIn) {
                            Task { await login() }
                        }
                        .disabled(username.isEmpty || password.isEmpty)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)

                Button {
                    session.forgetServer()
                } label: {
                    Label("更换服务器（\(session.server?.displayString ?? "")）", systemImage: "arrow.triangle.2.circlepath")
                        .font(.footnote)
                }
                .tint(.secondary)

                Spacer(minLength: 40)
            }
            .padding(.top, 60)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "film.stack.fill")
                .font(.system(size: 46))
                .foregroundStyle(Theme.accent)
                .padding(20)
                .appGlassCircle()
            Text("欢迎回来").font(.title.bold())
            Text("登录 CineChill 账号").font(.callout).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func field(icon: String, placeholder: String, text: Binding<String>, isSecure: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 20)
            if isSecure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .padding(12)
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
    }

    private func login() async {
        guard !username.isEmpty, !password.isEmpty else { return }
        errorText = nil
        isLoggingIn = true
        defer { isLoggingIn = false }
        do {
            try await AuthService().login(username: username, password: password)
            session.markLoggedIn(username: username)
        } catch {
            errorText = error.localizedDescription
        }
    }
}
