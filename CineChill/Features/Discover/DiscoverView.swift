import SwiftUI

struct DiscoverView: View {
    @State private var model = DiscoverViewModel()
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
            .navigationDestination(for: MediaItem.self) { MediaDetailView(item: $0) }
            .searchable(text: $model.searchText, prompt: "搜索电影、剧集")
            .searchScopes($model.searchType) {
                Text("电影").tag("movie")
                Text("剧集").tag("tv")
            }
            .onSubmit(of: .search) { Task { await model.runSearch() } }
            .onChange(of: model.searchType) { _, _ in Task { await model.runSearch() } }
            .task { await model.loadRows() }
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
