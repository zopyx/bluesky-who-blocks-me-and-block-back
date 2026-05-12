import Foundation

@MainActor
final class ListsViewModel: ObservableObject {
    @Published private(set) var listsByKind: [BlueskyList.Kind: [BlueskyList]] = [:]
    @Published private(set) var activeProfile: BlueskyProfile?
    @Published private(set) var blockingCount = 0
    @Published private(set) var blockedByCount = 0
    @Published private(set) var isLoading = false
    @Published private(set) var isFromCache = false
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
            blockedByCount = 0
            errorMessage = nil
            return
        }

        let cacheKey = account.did ?? account.handle
        if let cached = DashboardCache.load(forKey: cacheKey) {
            applyCached(cached)
            isFromCache = true
        }

        isLoading = true
        errorMessage = nil

        do {
            let lists = try await client.fetchLists(for: account, appPassword: appPassword)
            listsByKind = Dictionary(grouping: lists, by: \.kind)
        } catch {
            if listsByKind.isEmpty {
                listsByKind = [:]
                errorMessage = AppError.userMessage(from: error)
            }
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
            blockingCount = try await client.fetchBlockingCount(for: account)
        } catch {
            AppLogger.moderation.debug("Failed to fetch blocking count: \(error.localizedDescription, privacy: .public)")
        }

        do {
            blockedByCount = try await client.fetchBlockedByCount(for: account)
        } catch {
            AppLogger.moderation.debug("Failed to fetch blocked-by count: \(error.localizedDescription, privacy: .public)")
        }

        persistCache(forKey: cacheKey)
        isFromCache = false
        isLoading = false
    }

    private func applyCached(_ cached: DashboardCacheData) {
        listsByKind = Dictionary(grouping: cached.lists, by: \.kind)
        activeProfile = cached.profile
        blockingCount = cached.blockingCount
        blockedByCount = cached.blockedByCount
    }

    private func persistCache(forKey key: String) {
        let data = DashboardCacheData(
            lists: Array(listsByKind.values.flatMap { $0 }),
            profile: activeProfile,
            blockingCount: blockingCount,
            blockedByCount: blockedByCount
        )
        DashboardCache.save(data, forKey: key)
    }

    func addList(_ list: BlueskyList) {
        var updated = listsByKind
        updated[list.kind, default: []].append(list)
        updated[list.kind]?.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        listsByKind = updated
        persistCache(forKey: didCacheKey ?? "")
    }

    func updateList(_ updatedList: BlueskyList) {
        var updated = listsByKind
        guard var lists = updated[updatedList.kind],
              let index = lists.firstIndex(where: { $0.id == updatedList.id })
        else {
            return
        }

        lists[index] = updatedList
        updated[updatedList.kind] = lists
        listsByKind = updated
        persistCache(forKey: didCacheKey ?? "")
    }

    private var didCacheKey: String? {
        activeProfile?.did ?? activeProfile?.handle
    }
}
