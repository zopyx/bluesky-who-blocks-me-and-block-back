import Foundation

@MainActor
final class ProfileInspectorViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var searchResults: [BlueskyActor] = []
    @Published private(set) var inspection: ProfileInspection?
    @Published private(set) var isLoading = false
    @Published private(set) var isSearching = false
    @Published var errorMessage: String?

    func inspect(
        account: AppAccount?,
        appPassword: String?,
        using client: LiveBlueskyClient
    ) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter a Bluesky handle or DID."
            return
        }
        guard let account else {
            errorMessage = "Select an active account first."
            return
        }
        guard let appPassword, !appPassword.isEmpty else {
            errorMessage = BlueskyAPIError.missingCredentials.localizedDescription
            return
        }

        isLoading = true
        errorMessage = nil
        searchResults = []

        do {
            inspection = try await client.inspectProfile(
                query: trimmed,
                account: account,
                appPassword: appPassword
            )
        } catch {
            inspection = nil
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func search(
        account: AppAccount?,
        appPassword: String?,
        using client: LiveBlueskyClient
    ) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }

        guard let account else {
            searchResults = []
            return
        }

        guard let appPassword, !appPassword.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true

        do {
            let actors = try await client.searchActors(
                query: trimmed,
                account: account,
                appPassword: appPassword
            )

            let lowered = trimmed.lowercased()
            searchResults = actors.filter {
                $0.handle.lowercased().contains(lowered) ||
                ($0.displayName?.lowercased().contains(lowered) ?? false) ||
                $0.did.lowercased().contains(lowered)
            }
        } catch {
            errorMessage = error.localizedDescription
            searchResults = []
        }

        isSearching = false
    }

    func inspect(
        actor: BlueskyActor,
        account: AppAccount?,
        appPassword: String?,
        using client: LiveBlueskyClient
    ) async {
        query = actor.handle
        await inspect(query: actor.did, account: account, appPassword: appPassword, using: client)
    }

    private func inspect(
        query: String,
        account: AppAccount?,
        appPassword: String?,
        using client: LiveBlueskyClient
    ) async {
        guard let account else {
            errorMessage = "Select an active account first."
            return
        }
        guard let appPassword, !appPassword.isEmpty else {
            errorMessage = BlueskyAPIError.missingCredentials.localizedDescription
            return
        }

        isLoading = true
        errorMessage = nil
        searchResults = []

        do {
            inspection = try await client.inspectProfile(
                query: query,
                account: account,
                appPassword: appPassword
            )
        } catch {
            inspection = nil
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
