import SwiftUI

// MARK: - Glass helpers

struct AppGlassButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .background {
                if prominent {
                    Capsule(style: .continuous)
                        .fill(Theme.accent.gradient)
                } else {
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(.white.opacity(prominent ? 0.22 : 0.16), lineWidth: 1)
            }
            .shadow(color: .black.opacity(prominent ? 0.22 : 0.12), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

extension View {
    func appGlassCard(cornerRadius: CGFloat = Theme.cardCorner) -> some View {
        glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }

    func appGlassCircle() -> some View {
        glassEffect(.regular, in: .circle)
    }

    func appGlassCapsule(tint: Color = Theme.accent) -> some View {
        glassEffect(.regular.tint(tint.opacity(0.22)).interactive(), in: .capsule)
    }

    @ViewBuilder
    func appGlassButtonStyle(prominent: Bool = false) -> some View {
        if prominent {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.glass)
        }
    }
}

/// A rounded content card rendered with native Liquid Glass.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = Theme.cardCorner
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .appGlassCard(cornerRadius: cornerRadius)
    }
}

/// A compact pill used for stats / tags, rendered as interactive glass.
struct GlassPill: View {
    let systemImage: String?
    let title: String
    var tint: Color = Theme.accent

    init(_ title: String, systemImage: String? = nil, tint: Color = Theme.accent) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage) }
            Text(title)
        }
        .font(.footnote.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .appGlassCapsule(tint: tint)
    }
}

/// Section header used across feature screens.
struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title3.bold())
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .tint(Theme.accent)
            }
        }
    }
}

/// Primary call-to-action styled with prominent glass.
struct GlassPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().controlSize(.small).tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .appGlassButtonStyle(prominent: true)
        .tint(Theme.accent)
        .disabled(isLoading)
    }
}

// MARK: - State views

struct LoadingView: View {
    var label: String = "加载中…"
    var body: some View {
        VStack(spacing: 12) {
            ProgressView().controlSize(.large)
            Text(label).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyStateView: View {
    var systemImage: String = "tray"
    var title: String
    var message: String? = nil
    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let message { Text(message) }
        }
    }
}

struct ErrorStateView: View {
    let error: Error
    var retry: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(Theme.accentWarm)
            Text("出错了").font(.headline)
            Text(error.localizedDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            if let retry {
                Button("重试", action: retry)
                    .appGlassButtonStyle()
                    .tint(Theme.accent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
