import SwiftUI

struct MediaDetailView: View {
    let item: MediaItem

    @State private var detail: JSONValue?
    @State private var isLoading = false
    private let service = DiscoverService()

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

    private func loadDetail() async {
        guard let tmdb = item.tmdbID, detail == nil else { return }
        isLoading = true
        detail = try? await service.detail(tmdbID: tmdb)
        isLoading = false
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
