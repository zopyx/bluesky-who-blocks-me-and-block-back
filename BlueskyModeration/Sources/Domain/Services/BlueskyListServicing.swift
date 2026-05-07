import Foundation

@MainActor
protocol BlueskyListServicing {
    func fetchLists(for account: AppAccount, appPassword: String) async throws -> [BlueskyList]
}
