import Foundation

@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [AppAccount] = []
    @Published private(set) var activeAccountID: AppAccount.ID?
    @Published var errorMessage: String?
    @Published private(set) var isAddingAccount = false

    var activeAccount: AppAccount? {
        accounts.first { $0.id == activeAccountID }
    }

    private let defaults: UserDefaults
    private let keychain: KeychainServicing
    private let accountsKey = "bluesky.savedAccounts"
    private let activeAccountKey = "bluesky.activeAccountID"
    private let passwordService = "com.ajung.BlueskyModeration.password"

    init(
        defaults: UserDefaults = .standard,
        keychain: KeychainServicing = KeychainService(),
        preview: Bool = false
    ) {
        self.defaults = defaults
        self.keychain = keychain

        if preview {
            accounts = [
                AppAccount(handle: "team-alpha.bsky.social", displayName: "Team Alpha"),
                AppAccount(handle: "safety-lab.bsky.social", displayName: "Safety Lab")
            ]
            activeAccountID = accounts.first?.id
            return
        }

        load()
    }

    func addAccount(
        handle: String,
        appPassword: String,
        authenticator: BlueskyAuthenticating
    ) async -> Bool {
        let trimmedHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = appPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedHandle.isEmpty, !trimmedPassword.isEmpty else {
            errorMessage = "Handle and app password are required."
            return false
        }

        if accounts.contains(where: { $0.handle.caseInsensitiveCompare(trimmedHandle) == .orderedSame }) {
            errorMessage = "This account already exists."
            return false
        }

        isAddingAccount = true
        defer { isAddingAccount = false }

        do {
            let session = try await authenticator.authenticate(handle: trimmedHandle, appPassword: trimmedPassword)
            let account = AppAccount(
                handle: session.handle,
                displayName: session.handle,
                did: session.did
            )
            try keychain.save(trimmedPassword, service: passwordService, account: account.id.uuidString)
            accounts.insert(account, at: 0)
            activeAccountID = account.id
            persist()
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func removeAccount(_ account: AppAccount) {
        do {
            try keychain.delete(service: passwordService, account: account.id.uuidString)
        } catch {
            errorMessage = "Failed to delete secure credentials."
        }

        accounts.removeAll { $0.id == account.id }

        if activeAccountID == account.id {
            activeAccountID = accounts.first?.id
        }

        persist()
    }

    func setActiveAccount(_ account: AppAccount) {
        guard accounts.contains(account) else { return }

        activeAccountID = account.id
        if let index = accounts.firstIndex(of: account) {
            accounts[index].lastUsedAt = .now
        }
        persist()
    }

    func appPassword(for account: AppAccount) -> String? {
        try? keychain.read(service: passwordService, account: account.id.uuidString)
    }

    private func load() {
        guard let data = defaults.data(forKey: accountsKey) else {
            return
        }

        do {
            accounts = try JSONDecoder().decode([AppAccount].self, from: data)
            if let activeIDString = defaults.string(forKey: activeAccountKey),
               let activeID = UUID(uuidString: activeIDString),
               accounts.contains(where: { $0.id == activeID }) {
                activeAccountID = activeID
            } else {
                activeAccountID = accounts.first?.id
            }
        } catch {
            errorMessage = "Failed to restore saved accounts."
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(accounts)
            defaults.set(data, forKey: accountsKey)
            defaults.set(activeAccountID?.uuidString, forKey: activeAccountKey)
        } catch {
            errorMessage = "Failed to save accounts."
        }
    }
}
