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
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let lists = try await client.fetchLists(for: account, appPassword: appPassword)
            listsByKind = Dictionary(grouping: lists, by: \.kind)
        } catch {
            listsByKind = [:]
            errorMessage = AppError.userMessage(from: error)
        }

        do {
            activeProfile = try await client.fetchProfile(
                did: account.did ?? account.handle,
                account: account,
                appPassword: appPassword
            )
        } catch {
            AppLogger.moderation.debug("Failed to fetch account profile: \(error.localizedDescription, privacy: .public)")
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
