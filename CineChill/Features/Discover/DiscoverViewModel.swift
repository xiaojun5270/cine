import SwiftUI

@MainActor
@Observable
final class DiscoverViewModel {
    struct LoadedRow: Identifiable { let row: DiscoverService.Row; var items: [MediaItem]; var id: String { row.id } }

    var rows: [LoadedRow] = []
    var isLoading = false
    var error: Error?

    // Search
    var searchText = ""
    var searchType = "movie"
    var searchResults: [MediaItem] = []
    var isSearching = false

    private let service = DiscoverService()

    func loadRows() async {
        guard rows.isEmpty else { return }
        isLoading = true
        error = nil
        var loaded: [LoadedRow] = []
        for row in DiscoverService.homeRows {
            if let items = try? await service.fetchRow(row), !items.isEmpty {
                loaded.append(LoadedRow(row: row, items: items))
            }
        }
        rows = loaded
        if loaded.isEmpty { error = APIError.transport("暂无发现内容") }
        isLoading = false
    }

    func runSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { searchResults = []; return }
        isSearching = true
        defer { isSearching = false }
        searchResults = (try? await service.search(query: query, type: searchType)) ?? []
    }

    func imageURL(for item: MediaItem) -> URL? {
        if let path = item.posterPath, let url = service.imageURL(for: path) { return url }
        if let tmdb = item.tmdbID { return service.posterURL(mediaType: item.mediaType, tmdbID: tmdb) }
        return nil
    }
}
