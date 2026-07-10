import SwiftUI

struct MediaOrganizeView: View {
    private let service = MediaOrganizeService()
    @State private var config: JSONValue?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?
    @State private var mediaType = "movie"
    @State private var overwrite = false
    @State private var isBluray = false

    var body: some View {
        ModuleScaffold(title: "媒体整理", isLoading: isLoading && config == nil, error: config == nil ? error : nil,
                       onRetry: { Task { await load() } }) {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("执行整理").font(.headline)
                    Picker("类型", selection: $mediaType) {
                        Text("电影").tag("movie"); Text("剧集").tag("tv")
                    }.pickerStyle(.segmented)
                    Toggle("蓝光原盘", isOn: $isBluray).tint(Theme.accent)
                    Toggle("覆盖已存在", isOn: $overwrite).tint(Theme.accent)
                    GlassPrimaryButton(title: "开始整理", systemImage: "folder.badge.gearshape") {
                        Task { await organize() }
                    }
                }
            }
            if let config {
                JSONKeyValueCard(title: "当前配置", json: config, limit: 24)
            }
            ModuleActionButton(title: "刷新 Emby 库缓存", systemImage: "arrow.clockwise") {
                Task { await refreshCache() }
            }
        }
        .task { await load() }
        .toast($toast)
    }

    private func load() async {
        isLoading = true; error = nil
        do { config = try await service.config() } catch { self.error = error }
        isLoading = false
    }
    private func organize() async {
        do { _ = try await service.organize(mediaType: mediaType, isBluray: isBluray, overwrite: overwrite); toast = "已开始整理" }
        catch { toast = error.localizedDescription }
    }
    private func refreshCache() async {
        do { try await service.refreshEmbyCache(); toast = "已刷新缓存" } catch { toast = error.localizedDescription }
    }
}

struct OrganizeHistoryView: View {
    private let service = OrganizeHistoryService()
    @State private var records: [JSONValue] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?
    @State private var keyword = ""

    var body: some View {
        ModuleScaffold(title: "整理历史", isLoading: isLoading && records.isEmpty, error: records.isEmpty ? error : nil,
                       isEmpty: !isLoading && records.isEmpty && error == nil, emptyTitle: "暂无记录",
                       emptyIcon: "clock", onRetry: { Task { await load() } }) {
            ForEach(Array(records.enumerated()), id: \.offset) { _, r in
                let title = r.firstString("title", "name", "media_name", "file_name", "target_name") ?? "记录"
                let category = r.firstString("category", "type", "status")
                let time = r.firstString("created_at", "time", "organized_at", "finished_at")
                GlassCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title).font(.subheadline.weight(.medium)).lineLimit(2)
                        HStack(spacing: 8) {
                            if let category { GlassPill(category, systemImage: "tag") }
                            if let time { Text(time).font(.caption2).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
        }
        .searchable(text: $keyword, prompt: "搜索历史")
        .onSubmit(of: .search) { Task { await load() } }
        .task { await load() }
        .toast($toast)
    }

    private func load() async {
        isLoading = true; error = nil
        do {
            let json = try await service.records(keyword: keyword.isEmpty ? nil : keyword)
            records = json.items()
        } catch { self.error = error }
        isLoading = false
    }
}

struct StrmView: View {
    private let service = StrmService()
    @State private var config: JSONValue?
    @State private var progress: JSONValue?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var toast: String?

    var body: some View {
        ModuleScaffold(title: "STRM 同步", isLoading: isLoading && config == nil, error: config == nil ? error : nil,
                       onRetry: { Task { await load() } }) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("同步操作").font(.headline)
                    HStack(spacing: 10) {
                        ModuleActionButton(title: "生成 STRM", systemImage: "play.fill", prominent: true) {
                            Task { await start(mode: "strm") }
                        }
                        ModuleActionButton(title: "刮削元数据", systemImage: "wand.and.stars") {
                            Task { await start(mode: "metadata") }
                        }
                    }
                }
            }
            if let progress, let obj = progress.object, !obj.isEmpty {
                JSONKeyValueCard(title: "进度", json: progress, limit: 12)
            }
            if let config {
                JSONKeyValueCard(title: "配置", json: config, limit: 20)
            }
        }
        .task { await load() }
        .toast($toast)
    }

    private func load() async {
        isLoading = true; error = nil
        async let c = service.config()
        async let p = service.progress()
        do { config = try await c } catch { self.error = error }
        progress = try? await p
        isLoading = false
    }
    private func start(mode: String) async {
        do { try await service.start(taskIndex: 0, mode: mode); toast = "已开始：\(mode)" }
        catch { toast = error.localizedDescription }
    }
}
