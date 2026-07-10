import SwiftUI

@MainActor
@Observable
final class SubscriptionsViewModel {
    var sources: [RssSource] = []
    var isLoading = false
    var error: Error?
    var toast: String?

    private let service = SubscriptionService()

    func load() async {
        isLoading = true
        error = nil
        do { sources = try await service.listSources() }
        catch { self.error = error }
        isLoading = false
    }

    func save(existing: RssSource?, payload: RssSourcePayload) async -> Bool {
        do {
            if let existing {
                try await service.updateSource(id: existing.id, payload)
            } else {
                try await service.createSource(payload)
            }
            await load()
            return true
        } catch {
            self.error = error
            return false
        }
    }

    func delete(_ source: RssSource) async {
        do { try await service.deleteSource(id: source.id); await load() }
        catch { self.error = error }
    }

    func sync(_ source: RssSource) async {
        do { try await service.syncSource(id: source.id); toast = "已触发同步：\(source.name)" }
        catch { self.error = error }
    }
}
