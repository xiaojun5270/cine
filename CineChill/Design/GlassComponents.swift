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
            .symbolRenderingMode(.hierarchical)
    }
}

extension View {
    func appGlassCard(cornerRadius: CGFloat = Theme.cardCorner) -> some View {
        glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }

    func appInputFieldChrome(cornerRadius: CGFloat = 10) -> some View {
        padding(12)
            .background(.white.opacity(0.075), in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 0.7)
            }
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
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.cardTint)
            }
            .appGlassCard(cornerRadius: cornerRadius)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.cardStroke, lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
    }
}

/// Reusable glassy icon container for feature tiles and dense control surfaces.
struct IconBadge: View {
    let systemImage: String
    var tint: Color = Theme.accent
    var size: CGFloat = 44
    var cornerRadius: CGFloat = 13

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Theme.tintGradient(tint))
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.white.opacity(0.20))
                        .frame(height: size * 0.42)
                        .mask(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.24), lineWidth: 0.8)
                }
            Image(systemName: systemImage)
                .font(.system(size: size * 0.44, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .fixedSize()
        .shadow(color: tint.opacity(0.28), radius: 14, y: 8)
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
            if let systemImage {
                Image(systemName: systemImage)
                    .frame(width: 13)
            }
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .layoutPriority(1)
        }
        .font(.footnote.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background {
            Capsule(style: .continuous)
                .fill(tint.opacity(0.13))
        }
        .appGlassCapsule(tint: tint)
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(tint.opacity(0.22), lineWidth: 0.7)
        }
        .symbolRenderingMode(.hierarchical)
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
                HStack(spacing: 8) {
                    Capsule(style: .continuous)
                        .fill(Theme.accent)
                        .frame(width: 4, height: 18)
                    Text(title)
                        .font(.title3.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .allowsTightening(true)
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .layoutPriority(1)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
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
