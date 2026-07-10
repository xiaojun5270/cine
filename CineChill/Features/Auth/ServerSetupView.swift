import SwiftUI

/// First-run screen: capture the CineChill server address.
struct ServerSetupView: View {
    @Environment(SessionStore.self) private var session

    @State private var address: String = ""
    @State private var useHTTPS = false
    @State private var isTesting = false
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header

                GlassCard {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("服务器地址", systemImage: "server.rack")
                                .font(.subheadline.weight(.semibold))
                            TextField("例如 192.168.1.10:5256", text: $address)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .padding(12)
                                .background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                            Text("默认端口 5256。可填 IP、域名，或带 http(s):// 的完整地址。")
                                .font(.caption).foregroundStyle(.secondary)
                        }

                        Toggle(isOn: $useHTTPS) {
                            Label("使用 HTTPS", systemImage: "lock.fill")
                                .font(.subheadline)
                        }
                        .tint(Theme.accent)

                        if let errorText {
                            Text(errorText)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        GlassPrimaryButton(title: "连接服务器", systemImage: "bolt.horizontal.circle",
                                           isLoading: isTesting) {
                            Task { await connect() }
                        }
                    }
                }
                .padding(.horizontal, Theme.screenPadding)

                Spacer(minLength: 40)
            }
            .padding(.top, 60)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "film.stack.fill")
                .font(.system(size: 52))
                .foregroundStyle(Theme.accent)
                .padding(22)
                .appGlassCircle()
            Text("CineChill")
                .font(.largeTitle.bold())
            Text("连接你的媒体管理服务")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private func connect() async {
        errorText = nil
        var raw = address.trimmingCharacters(in: .whitespaces)
        if useHTTPS, !raw.contains("://") { raw = "https://" + raw }
        guard var config = ServerConfig(raw: raw) else {
            errorText = "地址格式无效，请检查后重试。"
            return
        }
        if useHTTPS { config.scheme = "https" }
        guard config.isValid else {
            errorText = "地址格式无效，请检查后重试。"
            return
        }

        isTesting = true
        defer { isTesting = false }

        // Configure then probe reachability. A 401 still means the host is up.
        APIClient.shared.configure(server: config)
        do {
            try await AuthService().ping()
            session.setServer(config)
        } catch APIError.unauthorized {
            // Reachable but not logged in — expected. Proceed to login.
            session.setServer(config)
        } catch {
            errorText = "无法连接：\(error.localizedDescription)"
        }
    }
}
