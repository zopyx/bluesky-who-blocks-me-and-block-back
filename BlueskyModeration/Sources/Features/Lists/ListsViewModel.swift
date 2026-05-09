import Foundation

@MainActor
final class ListsViewModel: ObservableObject {
    @Published private(set) var listsByKind: [BlueskyList.Kind: [BlueskyList]] = [:]
    @Published private(set) var activeProfile: BlueskyProfile?
    @Published private(set) var blockingCount = 0
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
            blockingCount = 0
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

        do {
            let blocked = try await client.fetchBlockedActors(account: account, appPassword: appPassword)
            blockingCount = blocked.count
        } catch {
            AppLogger.moderation.debug("Failed to fetch blocked actors: \(error.localizedDescription, privacy: .public)")
        }

        isLoading = false
    }

    func addList(_ list: BlueskyList) {
        var updated = listsByKind
        updated[list.kind, default: []].append(list)
        updated[list.kind]?.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        listsByKind = updated
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
