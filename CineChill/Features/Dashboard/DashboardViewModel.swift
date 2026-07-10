import SwiftUI

@MainActor
@Observable
final class DashboardViewModel {
    var stats: DashboardStats?
    var metrics: DeviceMetrics?
    var todayPicks: [MediaItem] = []
    var isLoading = false
    var error: Error?

    private let server = ServerService()
    private let discover = DiscoverService()

    func load() async {
        isLoading = true
        error = nil
        // Fetch independent resources concurrently; individual failures are tolerated.
        async let statsTask = server.dashboardStats()
        async let metricsTask = server.deviceMetrics()
        async let picksTask = discover.todayPicks()

        let s = try? await statsTask
        let m = try? await metricsTask
        let p = try? await picksTask
        stats = s
        metrics = m
        todayPicks = p ?? []

        if s == nil && m == nil && p == nil {
            error = APIError.transport("无法获取仪表盘数据")
        }
        isLoading = false
    }
}
