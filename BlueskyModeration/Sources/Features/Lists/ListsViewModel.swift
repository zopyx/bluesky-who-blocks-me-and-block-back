import Foundation

@MainActor
final class ListsViewModel: ObservableObject {
    @Published private(set) var listsByKind: [BlueskyList.Kind: [BlueskyList]] = [:]
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    func load(
        for account: AppAccount?,
        appPassword: String?,
        using service: BlueskyListServicing
    ) async {
        guard let account else {
            listsByKind = [:]
            return
        }

        guard let appPassword, !appPassword.isEmpty else {
            listsByKind = [:]
            errorMessage = BlueskyAPIError.missingCredentials.localizedDescription
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let lists = try await service.fetchLists(for: account, appPassword: appPassword)
            listsByKind = Dictionary(grouping: lists, by: \.kind)
        } catch {
            listsByKind = [:]
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
