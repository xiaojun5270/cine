import SwiftUI

/// Standard screen scaffold for the "更多" modules: applies background, title,
/// pull-to-refresh, and loading / error placeholders around content.
struct ModuleScaffold<Content: View>: View {
    let title: String
    var isLoading: Bool
    var error: Error?
    var isEmpty: Bool = false
    var emptyTitle: String = "暂无数据"
    var emptyIcon: String = "tray"
    var onRetry: (() -> Void)? = nil
    var toolbarContent: AnyView? = nil
    @ViewBuilder var content: Content

    var body: some View {
        Group {
            if isLoading {
                LoadingView()
            } else if let error {
                ErrorStateView(error: error, retry: onRetry)
            } else if isEmpty {
                EmptyStateView(systemImage: emptyIcon, title: emptyTitle)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        content
                    }
                    .padding(Theme.screenPadding)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .appLiquidNavigationChrome()
        .toolbar {
            if let toolbarContent {
                ToolbarItem(placement: .topBarTrailing) { toolbarContent }
            }
        }
    }
}

/// Renders an arbitrary JSON object as a readable key/value glass card.
struct JSONKeyValueCard: View {
    let title: String?
    let json: JSONValue
    var limit: Int = 40

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                if let title { Text(title).font(.headline) }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.0)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(row.1)
                            .font(.caption)
                            .textSelection(.enabled)
                            .lineLimit(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Divider().opacity(0.15)
                }
            }
        }
    }

    private var rows: [(String, String)] {
        guard let obj = json.object else {
            return [("值", json.string ?? "—")]
        }
        return obj.sorted { $0.key < $1.key }.prefix(limit).map { key, value in
            (prettify(key), display(value))
        }
    }

    private func prettify(_ s: String) -> String {
        s.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func display(_ v: JSONValue) -> String {
        switch v {
        case .string(let s): return s.isEmpty ? "—" : s
        case .number(let n): return n.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(n)) : String(format: "%.2f", n)
        case .bool(let b): return b ? "是" : "否"
        case .null: return "—"
        case .array(let a): return "\(a.count) 项"
        case .object: return "{…}"
        }
    }
}

/// Small status chip.
struct StatusChip: View {
    let text: String
    var ok: Bool
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(ok ? Color.green : Color.orange)
    }
}

/// Shared JSON result viewer for module actions.
struct JSONResultSheet: View {
    let title: String
    let json: JSONValue?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch json {
                    case .none, .some(.null):
                        EmptyStateView(systemImage: "doc.text", title: "暂无结果")
                            .frame(minHeight: 220)
                    case .some(.string(let text)):
                        Text(text.isEmpty ? "暂无结果" : text)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    case .some(let json):
                        let items = json.items()
                        if items.isEmpty {
                            JSONKeyValueCard(title: nil, json: json, limit: 120)
                        } else {
                            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                                JSONKeyValueCard(title: "#\(index + 1)", json: item, limit: 32)
                            }
                        }
                    }
                }
                .padding(Theme.screenPadding)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .appLiquidNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

/// A reusable action button used across module cards.
struct ModuleActionButton: View {
    let title: String
    var systemImage: String
    var prominent: Bool = false
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            VStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(buttonTint.opacity(prominent ? 0.24 : 0.16))
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                }
                .foregroundStyle(prominent ? Color.white : buttonTint)
                .frame(width: 26, height: 24)

                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.74)
                    .allowsTightening(true)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, height: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(ModuleActionTileButtonStyle(prominent: prominent, tint: buttonTint))
    }

    private var buttonTint: Color {
        role == .destructive ? Theme.danger : (prominent ? Theme.accent : Theme.accentBlue)
    }
}

private struct ModuleActionTileButtonStyle: ButtonStyle {
    var prominent: Bool
    var tint: Color
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(prominent ? tint.opacity(0.22) : Theme.cardTint)
            }
            .appGlassCard(cornerRadius: 12)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(tint.opacity(prominent ? 0.34 : 0.18), lineWidth: 0.8)
            }
            .shadow(color: tint.opacity(prominent ? 0.22 : 0.10), radius: prominent ? 12 : 8, y: 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .saturation(isEnabled ? 1 : 0.25)
            .opacity(isEnabled ? (configuration.isPressed ? 0.88 : 1) : 0.48)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.14), value: isEnabled)
    }
}

/// Simple toast/alert bound to an optional message string.
extension View {
    func appLiquidNavigationChrome() -> some View {
        toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tint(Theme.accent)
    }

    func toast(_ message: Binding<String?>) -> some View {
        alert("提示", isPresented: Binding(
            get: { message.wrappedValue != nil },
            set: { if !$0 { message.wrappedValue = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
