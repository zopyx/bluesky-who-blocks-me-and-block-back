import Foundation

@MainActor
final class BlueskyProfileViewModel: ObservableObject {
    @Published private(set) var profile: BlueskyProfile?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    func load(
        did actorDID: String,
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async {
        isLoading = true
        errorMessage = nil

        do {
            profile = try await client.fetchProfile(
                did: actorDID,
                account: account,
                appPassword: appPassword
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
