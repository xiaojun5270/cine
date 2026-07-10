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
                    VStack(alignment: .leading, spacing: 14) {
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
                    HStack(alignment: .top) {
                        Text(row.0)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 12)
                        Text(row.1)
                            .font(.caption)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(3)
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

/// A reusable action button used across module cards.
struct ModuleActionButton: View {
    let title: String
    var systemImage: String
    var prominent: Bool = false
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Group {
            if prominent {
                Button(role: role, action: action) {
                    Label(title, systemImage: systemImage)
                }
                .appGlassButtonStyle(prominent: true)
            } else {
                Button(role: role, action: action) {
                    Label(title, systemImage: systemImage)
                }
                .appGlassButtonStyle()
            }
        }
        .controlSize(.small)
        .tint(Theme.accent)
        .font(.caption.weight(.semibold))
    }
}

/// Simple toast/alert bound to an optional message string.
extension View {
    func appLiquidNavigationChrome() -> some View {
        toolbarBackground(.visible, for: .navigationBar)
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
