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
            Form {
                Section("基本信息") {
                    TextField("名称", text: $name)
                    TextField("RSS 地址", text: $rssURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }
                Section("媒体类型") {
                    Picker("类型", selection: $mediaType) {
                        Text("剧集").tag("tv")
                        Text("电影").tag("movie")
                    }
                    .pickerStyle(.segmented)
                }
                Section("订阅设置") {
                    TextField("订阅目标", text: $target)
                        .textInputAutocapitalization(.never)
                    TextField("Cron 表达式", text: $cron)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Toggle("启用", isOn: $enabled).tint(Theme.accent)
                }
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
