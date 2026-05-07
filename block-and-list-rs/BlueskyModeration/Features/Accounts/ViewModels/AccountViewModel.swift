import Foundation
import SwiftData
import Observation

@Observable
final class AccountViewModel {
    var accounts: [BlueskyAccount] = []
    var activeSession: AccountSession?
    var isLoading = false
    var errorMessage: String?

    private let apiService: any BlueskyAPIProtocol
    private let keychain: any KeychainProtocol
    private var modelContext: ModelContext?

    init(
        apiService: any BlueskyAPIProtocol = BlueskyAPIService.shared,
        keychain: any KeychainProtocol = KeychainService.shared
    ) {
        self.apiService = apiService
        self.keychain = keychain
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadAccounts()
    }

    // MARK: - Account Management

    func loadAccounts() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<BlueskyAccount>(sortBy: [SortDescriptor(\.createdAt)])
        do {
            accounts = try context.fetch(descriptor)
            if let active = accounts.first(where: \.isActive) {
                Task { await restoreSession(for: active) }
            }
        } catch {
            errorMessage = "Failed to load accounts"
        }
    }

    func addAccount(handle: String, appPassword: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let cleanHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanHandle.isEmpty else {
                await MainActor.run { self.errorMessage = "Handle is required" }
                return
            }

            // Resolve DID and PDS
            guard let did = try? await apiService.resolveHandle(cleanHandle) else {
                await MainActor.run { self.errorMessage = "Could not resolve handle." }
                return
            }
            guard let pds = try? await apiService.getPDS(did: did) else {
                await MainActor.run { self.errorMessage = "Could not resolve PDS endpoint." }
                return
            }

            // Authenticate
            let session = try await apiService.createSession(
                identifier: cleanHandle,
                password: appPassword,
                pds: pds
            )

            // Check for duplicate
            if accounts.contains(where: { $0.handle.lowercased() == session.handle.lowercased() }) {
                await MainActor.run { self.errorMessage = "Account already exists" }
                return
            }

            let account = BlueskyAccount(
                handle: session.handle,
                did: session.did,
                pdsEndpoint: pds
            )

            // Save to Keychain
            do {
                try await keychain.saveAppPassword(appPassword, for: account.id)
                try await keychain.saveAccessToken(session.accessJwt, for: account.id)
            } catch {
                await MainActor.run { self.errorMessage = "Failed to save credentials: \(error.localizedDescription)" }
                return
            }

            // Save to SwiftData
            guard let context = modelContext else {
                await MainActor.run { self.errorMessage = "Database not available" }
                return
            }

            // Deactivate others
            for existing in accounts { existing.isActive = false }
            account.isActive = true
            account.lastUsedAt = Date()

            context.insert(account)
            do {
                try context.save()
            } catch {
                await MainActor.run { self.errorMessage = "Failed to save account: \(error.localizedDescription)" }
                return
            }

            await MainActor.run {
                self.accounts.append(account)
                self.activeSession = AccountSession(
                    accountId: account.id,
                    accessJwt: session.accessJwt,
                    did: session.did,
                    handle: session.handle,
                    pdsEndpoint: pds
                )
            }

        } catch let error as ATProtoError {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        } catch {
            await MainActor.run { self.errorMessage = "Failed to add account: \(error.localizedDescription)" }
        }
    }

    func switchAccount(to account: BlueskyAccount) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Try to use cached token first
            if let token = try? await keychain.getAccessToken(for: account.id),
               let did = account.did,
               let pds = account.pdsEndpoint {
                await MainActor.run {
                    self.activeSession = AccountSession(
                        accountId: account.id,
                        accessJwt: token,
                        did: did,
                        handle: account.handle,
                        pdsEndpoint: pds
                    )
                    self.updateActiveState(account)
                }
                return
            }

            // Re-authenticate with stored password
            guard let password = try? await keychain.getAppPassword(for: account.id) else {
                await MainActor.run {
                    self.errorMessage = "App password not found. Please remove and re-add this account."
                }
                return
            }

            let session = try await apiService.createSession(
                identifier: account.handle,
                password: password,
                pds: account.pdsEndpoint
            )

            try await keychain.saveAccessToken(session.accessJwt, for: account.id)

            await MainActor.run {
                self.activeSession = AccountSession(
                    accountId: account.id,
                    accessJwt: session.accessJwt,
                    did: session.did,
                    handle: session.handle,
                    pdsEndpoint: account.pdsEndpoint ?? "https://bsky.social"
                )
                self.updateActiveState(account)
            }

        } catch let error as ATProtoError {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to switch account"
            }
        }
    }

    func removeAccount(_ account: BlueskyAccount) {
        guard let context = modelContext else { return }

        // Remove from Keychain
        Task {
            try? await keychain.deleteAllCredentials(for: account.id)
        }

        // Remove from SwiftData
        context.delete(account)

        do {
            try context.save()
            accounts.removeAll { $0.id == account.id }

            if account.isActive {
                activeSession = nil
                if let next = accounts.first {
                    Task { await switchAccount(to: next) }
                }
            }
        } catch {
            errorMessage = "Failed to remove account"
        }
    }

    // MARK: - Private

    private func restoreSession(for account: BlueskyAccount) async {
        do {
            guard let token = try? await keychain.getAccessToken(for: account.id),
                  let did = account.did,
                  let pds = account.pdsEndpoint else {
                return
            }

            await MainActor.run {
                self.activeSession = AccountSession(
                    accountId: account.id,
                    accessJwt: token,
                    did: did,
                    handle: account.handle,
                    pdsEndpoint: pds
                )
            }
        }
    }

    private func updateActiveState(_ active: BlueskyAccount) {
        guard let context = modelContext else { return }
        for account in accounts {
            account.isActive = (account.id == active.id)
            if account.id == active.id {
                account.lastUsedAt = Date()
            }
        }
        try? context.save()
    }
}
