import Foundation

@MainActor
final class ListDetailViewModel: ObservableObject {
    @Published private(set) var members: [BlueskyListMember] = []
    @Published private(set) var searchResults: [BlueskyActor] = []
    @Published private(set) var isLoadingMembers = false
    @Published private(set) var isSearching = false
    @Published private(set) var isUpdatingMetadata = false
    @Published private(set) var addingActorIDs: Set<String> = []
    @Published private(set) var removingMemberIDs: Set<String> = []
    @Published var errorMessage: String?

    func loadMembers(
        for list: BlueskyList,
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async {
        isLoadingMembers = true
        errorMessage = nil

        do {
            members = try await client.fetchListMembers(
                list: list,
                account: account,
                appPassword: appPassword
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingMembers = false
    }

    func search(
        query: String,
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true

        do {
            let actors = try await client.searchActors(
                query: trimmed,
                account: account,
                appPassword: appPassword
            )
            let existing = Set(members.map(\.actor.did))
            searchResults = actors.filter { !existing.contains($0.did) }
        } catch {
            errorMessage = error.localizedDescription
            searchResults = []
        }

        isSearching = false
    }

    func add(
        actor: BlueskyActor,
        to list: BlueskyList,
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async {
        addingActorIDs.insert(actor.did)
        defer { addingActorIDs.remove(actor.did) }

        do {
            try await client.addActor(
                did: actor.did,
                to: list,
                account: account,
                appPassword: appPassword
            )
            searchResults.removeAll { $0.did == actor.did }
            await loadMembers(for: list, account: account, appPassword: appPassword, using: client)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove(
        member: BlueskyListMember,
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async {
        removingMemberIDs.insert(member.id)
        defer { removingMemberIDs.remove(member.id) }

        do {
            try await client.removeMember(
                recordURI: member.recordURI,
                account: account,
                appPassword: appPassword
            )
            members.removeAll { $0.id == member.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateMetadata(
        for list: BlueskyList,
        title: String,
        description: String,
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async -> BlueskyList? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            errorMessage = "List title is required."
            return nil
        }

        isUpdatingMetadata = true
        defer { isUpdatingMetadata = false }

        do {
            let updatedList = try await client.updateListMetadata(
                list: list,
                title: trimmedTitle,
                description: trimmedDescription,
                account: account,
                appPassword: appPassword
            )
            errorMessage = nil
            return updatedList
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func isAdding(_ actor: BlueskyActor) -> Bool {
        addingActorIDs.contains(actor.did)
    }

    func isRemoving(_ member: BlueskyListMember) -> Bool {
        removingMemberIDs.contains(member.id)
    }

    func filteredMembers(matching query: String) -> [BlueskyListMember] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            return members
        }

        return members.filter {
            $0.actor.handle.lowercased().contains(trimmed) ||
            ($0.actor.displayName?.lowercased().contains(trimmed) ?? false)
        }
    }
}
