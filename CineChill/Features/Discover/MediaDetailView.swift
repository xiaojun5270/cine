import SwiftUI

struct MediaDetailView: View {
    let item: MediaItem

    @State private var detail: JSONValue?
    @State private var isLoading = false
    @State private var toast: String?
    @State private var result: JSONValue?
    @State private var resultTitle = "结果"
    @State private var showResult = false
    @State private var seasonInput = "1"
    @State private var source = "aiying"
    @State private var resourceID = ""
    private let service = DiscoverService()
    private let moviePilot = MoviePilotService()
    private let forward = ForwardService()

    private var backdropURL: URL? {
        if let path = item.backdropPath, let url = service.imageURL(for: path) { return url }
        if let tmdb = item.tmdbID { return service.backdropURL(mediaType: item.mediaType, tmdbID: tmdb) }
        return nil
    }
    private var posterURL: URL? {
        if let path = item.posterPath, let url = service.imageURL(for: path) { return url }
        if let tmdb = item.tmdbID { return service.posterURL(mediaType: item.mediaType, tmdbID: tmdb) }
        return nil
    }

    private var overview: String? {
        detail?.firstString("overview", "summary", "intro") ?? item.overview
    }
    private var genres: [String] {
        guard let arr = detail?["genres"].array else { return [] }
        return arr.compactMap { $0.firstString("name") ?? $0.string }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                VStack(alignment: .leading, spacing: 20) {
                    titleBlock
                    if item.tmdbID != nil {
                        actionCard
                    }
                    if !genres.isEmpty {
                        FlowTags(tags: genres)
                    }
                    if let overview, !overview.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("简介").font(.headline)
                            Text(overview)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
            }
            .padding(.bottom, 40)
        }
        .ignoresSafeArea(edges: .top)
        .scrollContentBackground(.hidden)
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .appLiquidNavigationChrome()
        .task { await loadDetail() }
        .toast($toast)
        .sheet(isPresented: $showResult) { JSONResultSheet(title: resultTitle, json: result) }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(url: backdropURL)
                .frame(height: 260)
                .clipped()
                .overlay(
                    LinearGradient(colors: [.clear, .black.opacity(0.85)],
                                   startPoint: .center, endPoint: .bottom)
                )
            HStack(alignment: .bottom, spacing: 14) {
                PosterTile(url: posterURL, width: 92)
                VStack(alignment: .leading, spacing: 6) {
                    if let rating = item.ratingText {
                        GlassPill(rating, systemImage: "star.fill", tint: Theme.accentWarm)
                    }
                    HStack(spacing: 6) {
                        GlassPill(item.typeLabel, systemImage: item.mediaType == "tv" ? "tv" : "film")
                        if let year = item.year { GlassPill(year, systemImage: "calendar") }
                    }
                }
                Spacer()
            }
            .padding(Theme.screenPadding)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title).font(.title2.bold())
            if let original = item.originalTitle, original != item.title {
                Text(original).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var actionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("接口动作").font(.headline)
                if item.mediaType == "tv" {
                    TextField("季", text: $seasonInput)
                        .keyboardType(.numberPad)
                        .padding(12)
                        .background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                }
                HStack(spacing: 10) {
                    TextField("source", text: $source)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("resource_id（可选）", text: $resourceID)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                .padding(12)
                .background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
                    ModuleActionButton(title: "馆藏", systemImage: "checkmark.circle", prominent: true) {
                        Task { await libraryExists() }
                    }
                    ModuleActionButton(title: "MP检查", systemImage: "airplane") {
                        Task { await checkSubscription() }
                    }
                    ModuleActionButton(title: "MP订阅", systemImage: "plus.circle") {
                        Task { await subscribeMoviePilot() }
                    }
                    ModuleActionButton(title: "搜资源", systemImage: "magnifyingglass") {
                        Task { await searchForward() }
                    }
                    ModuleActionButton(title: "资源列表", systemImage: "list.bullet.rectangle") {
                        Task { await forwardResources() }
                    }
                    ModuleActionButton(title: "测试", systemImage: "checkmark.shield") {
                        Task { await testForward() }
                    }
                    ModuleActionButton(title: "预览", systemImage: "eye") {
                        Task { await runResourceAction("资源预览") { try await forward.previewResource($0) } }
                    }
                    ModuleActionButton(title: "转存", systemImage: "tray.and.arrow.down") {
                        Task { await runResourceAction("资源转存") { try await forward.transferResource($0) } }
                    }
                    if item.mediaType == "tv" {
                        ModuleActionButton(title: "季详情", systemImage: "tv") {
                            Task { await seasonDetail() }
                        }
                        ModuleActionButton(title: "剧集状态", systemImage: "rectangle.stack") {
                            Task { await libraryStatus() }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func loadDetail() async {
        guard let tmdb = item.tmdbID, detail == nil else { return }
        isLoading = true
        detail = try? await service.detail(tmdbID: tmdb, mediaType: item.mediaType)
        isLoading = false
    }

    private func libraryExists() async {
        do {
            let tmdb = try requiredTMDB()
            result = try await service.libraryExists(tmdbID: tmdb, mediaType: item.mediaType)
            resultTitle = "馆藏检查"
            showResult = true
        } catch { toast = error.localizedDescription }
    }

    private func libraryStatus() async {
        do {
            let tmdb = try requiredTMDB()
            result = try await service.libraryStatus(tmdbID: tmdb)
            resultTitle = "剧集状态"
            showResult = true
        } catch { toast = error.localizedDescription }
    }

    private func seasonDetail() async {
        do {
            let tmdb = try requiredTMDB()
            guard let season = Int(seasonInput) else { throw APIError.validation(["请填写季数"]) }
            result = try await service.seasonDetail(tmdbID: tmdb, season: season)
            resultTitle = "第 \(season) 季"
            showResult = true
        } catch { toast = error.localizedDescription }
    }

    private func checkSubscription() async {
        do {
            let tmdb = try requiredTMDB()
            result = try await moviePilot.checkSubscription(tmdbID: tmdb, typeName: item.mediaType, season: seasonValue)
            resultTitle = "订阅检查"
            showResult = true
        } catch { toast = error.localizedDescription }
    }

    private func subscribeMoviePilot() async {
        do {
            let tmdb = try requiredTMDB()
            try await moviePilot.subscribe(tmdbID: tmdb, typeName: item.mediaType, season: seasonValue, name: item.title, year: item.year)
            toast = "已提交 MoviePilot 订阅"
        } catch { toast = error.localizedDescription }
    }

    private func searchForward() async {
        do {
            let tmdb = try requiredTMDB()
            result = try await forward.searchResources(
                type: item.mediaType,
                tmdbID: tmdb,
                title: item.title,
                year: item.year,
                season: seasonValue,
                episode: nil,
                sources: nil
            )
            resultTitle = "资源搜索"
            showResult = true
        } catch { toast = error.localizedDescription }
    }

    private func forwardResources() async {
        do {
            let tmdb = try requiredTMDB()
            result = try await forward.resources(type: item.mediaType, tmdbID: tmdb)
            resultTitle = "资源列表"
            showResult = true
        } catch { toast = error.localizedDescription }
    }

    private func testForward() async {
        do {
            let tmdb = try requiredTMDB()
            result = try await forward.testResources(type: item.mediaType, tmdbID: tmdb)
            resultTitle = "资源测试"
            showResult = true
        } catch { toast = error.localizedDescription }
    }

    private func runResourceAction(_ title: String, action: (JSONValue) async throws -> JSONValue) async {
        do {
            result = try await action(resourceBody())
            resultTitle = title
            showResult = true
        } catch { toast = error.localizedDescription }
    }

    private func resourceBody() throws -> JSONValue {
        let tmdb = try requiredTMDB()
        return JSONValue.obj([
            "source": source.isEmpty ? "aiying" : source,
            "resource_id": resourceID,
            "type": item.mediaType,
            "tmdb_id": String(tmdb),
            "title": item.title,
            "year": item.year ?? ""
        ])
    }

    private func requiredTMDB() throws -> Int {
        guard let tmdb = item.tmdbID else { throw APIError.validation(["当前条目缺少 TMDB ID"]) }
        return tmdb
    }

    private var seasonValue: Int? {
        item.mediaType == "tv" ? Int(seasonInput) : nil
    }
}

/// Simple wrapping tag layout.
struct FlowTags: View {
    let tags: [String]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { GlassPill($0) }
            }
        }
    }
}
