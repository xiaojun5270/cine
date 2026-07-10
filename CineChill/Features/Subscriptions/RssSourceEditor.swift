import SwiftUI

/// Create / edit sheet for an RSS subscription source.
struct RssSourceEditor: View {
    let source: RssSource?
    let onSave: (RssSourcePayload) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var rssURL = ""
    @State private var mediaType = "tv"
    @State private var target = "moviepilot"
    @State private var cron = "0 */12 * * *"
    @State private var enabled = true
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("基本信息", systemImage: "antenna.radiowaves.left.and.right")
                                .font(.headline)
                            formField("名称", text: $name, icon: "textformat")
                            formField("RSS 地址", text: $rssURL, icon: "link")
                                .keyboardType(.URL)
                        }
                    }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("订阅设置", systemImage: "slider.horizontal.3")
                                .font(.headline)
                            Picker("类型", selection: $mediaType) {
                                Text("剧集").tag("tv")
                                Text("电影").tag("movie")
                            }
                            .pickerStyle(.segmented)
                            formField("订阅目标", text: $target, icon: "target")
                            formField("Cron 表达式", text: $cron, icon: "clock")
                            Toggle(isOn: $enabled) {
                                Label("启用", systemImage: enabled ? "checkmark.circle.fill" : "pause.circle")
                            }
                            .tint(Theme.accent)
                        }
                    }
                }
                .padding(Theme.screenPadding)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle(source == nil ? "新增订阅" : "编辑订阅")
            .navigationBarTitleDisplayMode(.inline)
            .appLiquidNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await save() } }
                        .disabled(rssURL.isEmpty || isSaving)
                }
            }
            .onAppear(perform: populate)
        }
    }

    private func formField(_ placeholder: String, text: Binding<String>, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.accent)
                .frame(width: 20)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .appInputFieldChrome()
    }

    private func populate() {
        guard let source else { return }
        name = source.name
        rssURL = source.rssURL
        mediaType = source.mediaType
        target = source.subscriptionTarget
        cron = source.cron.isEmpty ? cron : source.cron
        enabled = source.enabled
    }

    private func save() async {
        isSaving = true
        let payload = RssSourcePayload(
            name: name, rss_url: rssURL, media_type: mediaType,
            subscription_target: target, cron: cron, enabled: enabled
        )
        let ok = await onSave(payload)
        isSaving = false
        if ok { dismiss() }
    }
}
