import Foundation
import SwiftUI

/// Persists connection + auth state and drives the top-level navigation
/// (server setup → login → main app). Session cookies returned by
/// `POST /api/login` are kept in `HTTPCookieStorage` used by the shared
/// `APIClient`, so we only persist lightweight metadata here.
@MainActor
@Observable
final class SessionStore {
    enum Phase: Equatable {
        case needsServer      // no server configured
        case needsLogin       // server ok, not authenticated
        case authenticated    // logged in
    }

    private let defaults = UserDefaults.standard
    private let serverKey = "cc.server.config"
    private let userKey = "cc.auth.username"
    private let loggedInKey = "cc.auth.loggedIn"

    private(set) var server: ServerConfig?
    private(set) var username: String?
    private(set) var phase: Phase = .needsServer

    init() { restore() }

    private func restore() {
        if let data = defaults.data(forKey: serverKey),
           let cfg = try? JSONDecoder().decode(ServerConfig.self, from: data) {
            server = cfg
            APIClient.shared.configure(server: cfg)
        }
        username = defaults.string(forKey: userKey)
        let loggedIn = defaults.bool(forKey: loggedInKey)
        recomputePhase(loggedIn: loggedIn)
    }

    private func recomputePhase(loggedIn: Bool) {
        if server == nil || server?.isValid != true {
            phase = .needsServer
        } else if !loggedIn {
            phase = .needsLogin
        } else {
            phase = .authenticated
        }
    }

    func setServer(_ config: ServerConfig) {
        server = config
        APIClient.shared.configure(server: config)
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: serverKey)
        }
        recomputePhase(loggedIn: defaults.bool(forKey: loggedInKey))
    }

    func markLoggedIn(username: String) {
        self.username = username
        defaults.set(username, forKey: userKey)
        defaults.set(true, forKey: loggedInKey)
        phase = .authenticated
    }

    func validateStoredLogin() async {
        guard phase == .authenticated else { return }
        do {
            let info = try await AuthService().userInfo()
            if let name = info.firstString("username", "user", "name", "account") {
                username = name
                defaults.set(name, forKey: userKey)
            }
        } catch APIError.unauthorized {
            logout()
        } catch {
            // Keep the current screen for transient network failures.
        }
    }

    func logout() {
        defaults.set(false, forKey: loggedInKey)
        APIClient.shared.clearCookies()
        phase = .needsLogin
    }

    /// Full reset — forget the server too.
    func forgetServer() {
        defaults.removeObject(forKey: serverKey)
        defaults.set(false, forKey: loggedInKey)
        APIClient.shared.clearCookies()
        server = nil
        phase = .needsServer
    }
}
