import Foundation

@MainActor
final class ListsViewModel: ObservableObject {
    @Published private(set) var listsByKind: [BlueskyList.Kind: [BlueskyList]] = [:]
    @Published private(set) var activeProfile: BlueskyProfile?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    func load(
        for account: AppAccount?,
        appPassword: String?,
        using client: LiveBlueskyClient
    ) async {
        guard let account else {
            listsByKind = [:]
            activeProfile = nil
            return
        }

        guard let appPassword, !appPassword.isEmpty else {
            listsByKind = [:]
            activeProfile = nil
            errorMessage = AppError.userMessage(from: BlueskyAPIError.missingCredentials)
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            async let listsTask = client.fetchLists(for: account, appPassword: appPassword)
            async let profileTask = client.fetchProfile(
                did: account.did ?? account.handle,
                account: account,
                appPassword: appPassword
            )

            let lists = try await listsTask
            listsByKind = Dictionary(grouping: lists, by: \.kind)
            activeProfile = try await profileTask
        } catch {
            listsByKind = [:]
            activeProfile = nil
            errorMessage = AppError.userMessage(from: error)
        }

        isLoading = false
    }

    func updateList(_ updatedList: BlueskyList) {
        var updated = listsByKind
        guard var lists = updated[updatedList.kind],
              let index = lists.firstIndex(where: { $0.id == updatedList.id }) else {
            return
        }

        lists[index] = updatedList
        updated[updatedList.kind] = lists
        listsByKind = updated
    }
}
