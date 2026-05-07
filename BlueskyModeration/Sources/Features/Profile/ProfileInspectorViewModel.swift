import Foundation

@MainActor
final class ProfileInspectorViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var inspection: ProfileInspection?
    @Published private(set) var isLoading = false
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
}
