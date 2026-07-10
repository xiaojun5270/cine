import SwiftUI

@main
struct CineChillApp: App {
    @State private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
        }
    }
}
