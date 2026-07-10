import SwiftUI

/// Top-level router driven by `SessionStore.phase`.
struct RootView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

            switch session.phase {
            case .needsServer:
                ServerSetupView()
                    .transition(.opacity)
            case .needsLogin:
                LoginView()
                    .transition(.opacity)
            case .authenticated:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: session.phase)
    }
}
