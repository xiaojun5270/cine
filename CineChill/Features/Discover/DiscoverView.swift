import SwiftUI

struct DiscoverView: View {
    @State private var model = DiscoverViewModel()
    @State private var showTools = false
    private let gridColumns = [GridItem(.adaptive(minimum: 108), spacing: 12)]

    var body: some View {
        NavigationStack {
            Group {
                if model.searchText.isEmpty {
                    browseContent
                } else {
                    searchContent
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("发现")
            .appLiquidNavigationChrome()
            .navigationDestination(for: MediaItem.self) { MediaDetailView(item: $0) }
            .searchable(text: $model.searchText, prompt: "搜索电影、剧集")
            .searchScopes($model.searchType) {
                Text("电影").tag("movie")
                Text("剧集").tag("tv")
            }
            .onSubmit(of: .search) { Task { await model.runSearch() } }
            .onChange(of: model.searchType) { _, _ in Task { await model.runSearch() } }
            .task { await model.loadRows() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showTools = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $showTools) { DiscoverToolsSheet() }
        }
    }

    // MARK: Browse

    @ViewBuilder
    private var browseContent: some View {
        if model.isLoading && model.rows.isEmpty {
            LoadingView()
        } else if let error = model.error, model.rows.isEmpty {
            ErrorStateView(error: error) { Task { await model.loadRows() } }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    ForEach(model.rows) { loaded in
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: loaded.row.title)
                                .padding(.horizontal, Theme.screenPadding)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(loaded.items) { item in
                                        NavigationLink(value: item) { MediaPosterCard(item: item) }
                                            .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, Theme.screenPadding)
                            }
                        }
                    }
                }
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: Search

    @ViewBuilder
    private var searchContent: some View {
        if model.isSearching {
            LoadingView(label: "搜索中…")
        } else if model.searchResults.isEmpty {
            EmptyStateView(systemImage: "magnifyingglass",
                           title: "没有结果",
                           message: "换个关键词试试")
        } else {
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 18) {
                    ForEach(model.searchResults) { item in
                        NavigationLink(value: item) { MediaPosterCard(item: item, width: 108) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(Theme.screenPadding)
            }
        }
    }
}

private struct DiscoverToolsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var result: JSONValue?
    @State private var resultTitle = "结果"
    @State private var showResult = false
    @State private var toast: String?
    @State private var genreID = ""
    @State private var genreMediaType = "movie"
    @State private var genrePage = "1"
    @State private var providerKey = ""
    @State private var taskCoverKey = ""
    @State private var embyServerIndex = "0"
    @State private var embyItemID = ""
    @State private var imageProxyKind = "douban"
    @State private var imageProxySourceURL = ""
    @State private var embyCoverTimestamp = ""
    @State private var embyCoverSignature = ""
    @State private var rawResolveBody = ""
    @State private var rawTMDBDiscoverBody = ""
    @State private var rawArtworkBody = ""
    @State private var rawManualCompleteBody = ""
    @State private var rawDeleteEmbyBody = ""

    private let service = DiscoverService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    quickToolsCard
                    lookupToolsCard
                    jsonToolsCard
                }
                .padding(Theme.screenPadding)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("发现工具")
            .navigationBarTitleDisplayMode(.inline)
            .appLiquidNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .toast($toast)
            .sheet(isPresented: $showResult) {
                JSONResultSheet(title: resultTitle, json: result)
            }
        }
    }

    private var quickToolsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("基础数据").font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 94), spacing: 8)], alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "事件", systemImage: "dot.radiowaves.left.and.right", prominent: true) {
                        Task { await run("实时事件") { try await service.events() } }
                    }
                    ModuleActionButton(title: "类型", systemImage: "tag") {
                        Task { await run("媒体类型") { try await service.genres() } }
                    }
                    ModuleActionButton(title: "来源", systemImage: "square.stack.3d.up") {
                        Task { await run("发现来源") { try await service.sources() } }
                    }
                    ModuleActionButton(title: "缺集统计", systemImage: "exclamationmark.triangle") {
                        Task { await run("缺集统计") { try await service.missingEpisodeStats(refresh: false, summaryOnly: false) } }
                    }
                    ModuleActionButton(title: "刷新缺集", systemImage: "arrow.clockwise") {
                        Task { await run("刷新缺集统计") { try await service.missingEpisodeStats(refresh: true, summaryOnly: false) } }
                    }
                }
            }
        }
    }

    private var lookupToolsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("查询工具").font(.headline)
                HStack(spacing: 10) {
                    TextField("genre_id", text: $genreID)
                        .keyboardType(.numberPad)
                    TextField("media_type", text: $genreMediaType)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("page", text: $genrePage)
                        .keyboardType(.numberPad)
                }
                .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                HStack(spacing: 10) {
                    TextField("provider source_key", text: $providerKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("task cover key", text: $taskCoverKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                HStack(spacing: 10) {
                    TextField("Emby server_idx", text: $embyServerIndex)
                        .keyboardType(.numberPad)
                    TextField("Emby item_id", text: $embyItemID)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                HStack(spacing: 10) {
                    TextField("图片代理 kind", text: $imageProxyKind)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("图片 URL", text: $imageProxySourceURL)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                HStack(spacing: 10) {
                    TextField("cover ts", text: $embyCoverTimestamp)
                        .keyboardType(.numberPad)
                    TextField("cover sig", text: $embyCoverSignature)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 94), spacing: 8)], alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "按类型", systemImage: "line.3.horizontal.decrease.circle", prominent: true) {
                        Task { await discoverByGenre() }
                    }
                    ModuleActionButton(title: "Provider", systemImage: "shippingbox") {
                        Task { await provider() }
                    }
                    ModuleActionButton(title: "封面URL", systemImage: "photo") {
                        Task { await taskCover() }
                    }
                    ModuleActionButton(title: "Emby URL", systemImage: "link") {
                        Task { await embyWebURL() }
                    }
                    ModuleActionButton(title: "图片代理", systemImage: "photo.badge.arrow.down") {
                        Task { await imageProxyURL() }
                    }
                    ModuleActionButton(title: "Cover URL", systemImage: "rectangle.portrait") {
                        Task { await embyCoverURL() }
                    }
                }
            }
        }
    }

    private var jsonToolsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("JSON 动作").font(.headline)
                TextField("Resolve TMDB JSON", text: $rawResolveBody, axis: .vertical)
                    .lineLimit(2...7)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .font(.system(.caption, design: .monospaced))
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("TMDB Discover 查询 JSON", text: $rawTMDBDiscoverBody, axis: .vertical)
                    .lineLimit(2...7)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .font(.system(.caption, design: .monospaced))
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("TMDB Artwork Batch JSON", text: $rawArtworkBody, axis: .vertical)
                    .lineLimit(2...7)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .font(.system(.caption, design: .monospaced))
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("Manual Complete Missing JSON", text: $rawManualCompleteBody, axis: .vertical)
                    .lineLimit(2...7)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .font(.system(.caption, design: .monospaced))
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                TextField("Delete Emby Items JSON", text: $rawDeleteEmbyBody, axis: .vertical)
                    .lineLimit(2...7)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .font(.system(.caption, design: .monospaced))
                    .padding(12).background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 94), spacing: 8)], alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "解析模板", systemImage: "doc.badge.plus") {
                        seedResolveBody()
                    }
                    ModuleActionButton(title: "解析TMDB", systemImage: "sparkles", prominent: true) {
                        Task { await resolveTMDB() }
                    }
                    ModuleActionButton(title: "发现模板", systemImage: "doc.on.doc") {
                        seedTMDBDiscoverBody()
                    }
                    ModuleActionButton(title: "TMDB发现", systemImage: "rectangle.grid.2x2") {
                        Task { await tmdbDiscover() }
                    }
                    ModuleActionButton(title: "图片模板", systemImage: "doc.badge.gearshape") {
                        seedArtworkBody()
                    }
                    ModuleActionButton(title: "图片批量", systemImage: "photo.on.rectangle") {
                        Task { await artworkBatch() }
                    }
                    ModuleActionButton(title: "缺集模板", systemImage: "doc.text") {
                        seedManualCompleteBody()
                    }
                    ModuleActionButton(title: "手动补齐", systemImage: "checkmark.circle") {
                        Task { await manualComplete() }
                    }
                    ModuleActionButton(title: "删除模板", systemImage: "doc.badge.minus") {
                        seedDeleteEmbyBody()
                    }
                    ModuleActionButton(title: "删Emby", systemImage: "trash", role: .destructive) {
                        Task { await deleteEmbyItems() }
                    }
                }
            }
        }
    }

    private func run(_ title: String, operation: () async throws -> JSONValue) async {
        do {
            result = try await operation()
            resultTitle = title
            showResult = true
        } catch { toast = error.localizedDescription }
    }

    private func discoverByGenre() async {
        await run("按类型发现") {
            guard !genreID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写 genre_id"])
            }
            return try await service.discoverByGenre(
                genreID: genreID,
                mediaType: genreMediaType.isEmpty ? "movie" : genreMediaType,
                page: Int(genrePage) ?? 1
            )
        }
    }

    private func provider() async {
        await run("发现 Provider") {
            guard !providerKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写 source_key"])
            }
            return try await service.provider(sourceKey: providerKey)
        }
    }

    private func taskCover() async {
        await run("任务封面 URL") {
            guard !taskCoverKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写 key"])
            }
            return try await service.taskCover(key: taskCoverKey)
        }
    }

    private func embyWebURL() async {
        await run("Emby Web URL") {
            guard !embyItemID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写 item_id"])
            }
            return try await service.embyWebURL(serverIndex: Int(embyServerIndex) ?? 0, itemID: embyItemID)
        }
    }

    private func imageProxyURL() async {
        await run("发现图片代理 URL") {
            guard !imageProxySourceURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写图片 URL"])
            }
            return try service.imageProxyURL(kind: imageProxyKind, sourceURL: imageProxySourceURL)
        }
    }

    private func embyCoverURL() async {
        await run("Emby Cover URL") {
            guard !embyItemID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写 item_id"])
            }
            guard !embyCoverTimestamp.isEmpty, !embyCoverSignature.isEmpty else {
                throw APIError.validation(["请填写 cover ts 和 sig"])
            }
            return try service.embyCoverURL(
                serverIndex: embyServerIndex,
                itemID: embyItemID,
                timestamp: embyCoverTimestamp,
                signature: embyCoverSignature
            )
        }
    }

    private func resolveTMDB() async {
        await runJSON("解析 TMDB", text: rawResolveBody) { try await service.resolveTMDB($0) }
    }

    private func tmdbDiscover() async {
        await runJSON("TMDB 通用发现", text: rawTMDBDiscoverBody) { try await service.tmdbDiscover($0) }
    }

    private func artworkBatch() async {
        await runJSON("TMDB 图片批量", text: rawArtworkBody) { try await service.tmdbArtworkBatch($0) }
    }

    private func manualComplete() async {
        await runJSON("缺集手动补齐", text: rawManualCompleteBody) { try await service.manualCompleteMissing($0) }
    }

    private func deleteEmbyItems() async {
        await runJSON("删除 Emby 项", text: rawDeleteEmbyBody) { try await service.deleteEmbyItems($0) }
    }

    private func runJSON(_ title: String, text: String, operation: (JSONValue) async throws -> JSONValue) async {
        do {
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError.validation(["请先填写 \(title) JSON"])
            }
            result = try await operation(try JSONValue.parse(text))
            resultTitle = title
            showResult = true
        } catch { toast = error.localizedDescription }
    }

    private func seedResolveBody() {
        rawResolveBody = """
        {"source":"douban","media_type":"movie","items":[]}
        """
    }

    private func seedTMDBDiscoverBody() {
        rawTMDBDiscoverBody = """
        {"media_type":"movie","sort_by":"popularity.desc","with_genres":"","with_keywords":"","with_original_language":"","with_watch_providers":"","vote_average":0,"vote_count":10,"release_date":"","page":1}
        """
    }

    private func seedArtworkBody() {
        rawArtworkBody = """
        {"items":[],"media_type":"movie","overwrite":false}
        """
    }

    private func seedManualCompleteBody() {
        rawManualCompleteBody = """
        {"tmdb_id":"","season_number":1,"episode_numbers":[],"manual_complete":true}
        """
    }

    private func seedDeleteEmbyBody() {
        rawDeleteEmbyBody = """
        {"server_idx":0,"item_ids":[]}
        """
    }
}
