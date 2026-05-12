import Foundation

@MainActor
final class BlueskyProfileViewModel: ObservableObject {
    @Published private(set) var inspection: ProfileInspection?
    @Published private(set) var isLoading = false
    @Published private(set) var isUpdatingModeration = false
    @Published private(set) var handleHistory: [HandleChange] = []
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    var profile: BlueskyProfile? {
        inspection?.profile
    }

    var listMemberships: [ProfileListMembership] {
        inspection?.listMemberships ?? []
    }

    func load(
        did actorDID: String,
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async {
        isLoading = true
        errorMessage = nil
        statusMessage = nil

        do {
            inspection = try await client.inspectProfile(
                query: actorDID,
                account: account,
                appPassword: appPassword
            )
            if let profile {
                let auditLog = try? await client.fetchPLCAuditLog(did: profile.did)
                if let auditLog {
                    handleHistory = parseHandleChanges(from: auditLog, currentHandle: profile.handle)
                }
            }
        } catch {
            inspection = nil
            handleHistory = []
            errorMessage = AppError.userMessage(from: error)
        }

        isLoading = false
    }

    func toggleMute(
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async {
        guard let profile else { return }

        isUpdatingModeration = true
        defer { isUpdatingModeration = false }

        do {
            if profile.viewerState?.muted == true {
                try await client.unmuteActor(
                    did: profile.did,
                    account: account,
                    appPassword: appPassword
                )
                statusMessage = "Account unmuted."
            } else {
                try await client.muteActor(
                    did: profile.did,
                    account: account,
                    appPassword: appPassword
                )
                statusMessage = "Account muted."
            }

            await load(
                did: profile.did,
                account: account,
                appPassword: appPassword,
                using: client
            )
        } catch {
            errorMessage = AppError.userMessage(from: error)
        }
    }

    func toggleBlock(
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async {
        guard let profile else { return }

        isUpdatingModeration = true
        defer { isUpdatingModeration = false }

        do {
            if let recordURI = profile.viewerState?.blockingRecordURI,
               profile.viewerState?.isBlocking == true
            {
                try await client.unblockActor(
                    recordURI: recordURI,
                    account: account,
                    appPassword: appPassword
                )
                statusMessage = "Account unblocked."
            } else {
                try await client.blockActor(
                    did: profile.did,
                    account: account,
                    appPassword: appPassword
                )
                statusMessage = "Account blocked."
            }

            await load(
                did: profile.did,
                account: account,
                appPassword: appPassword,
                using: client
            )
        } catch {
            errorMessage = AppError.userMessage(from: error)
        }
    }

    @Published var isBlockingFollowers = false
    @Published var blockFollowersProgress: BatchProgress?

    func blockAllFollowers(
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient,
        queue: ActionQueueStore
    ) async {
        guard let profile else { return }

        isBlockingFollowers = true
        defer { isBlockingFollowers = false }

        do {
            let followers = try await client.fetchFollowers(
                actor: profile.did,
                account: account,
                appPassword: appPassword
            )

            guard !followers.isEmpty else {
                statusMessage = "No followers to block."
                return
            }

            statusMessage = "Queued \(followers.count) followers for blocking."

            queue.enqueue(QueuedAction(
                title: "Block followers of \(profile.handle)",
                actors: followers,
                operation: .block
            ) { actor in
                try await client.blockActor(
                    did: actor.did,
                    account: account,
                    appPassword: appPassword
                )
            })
        } catch {
            errorMessage = AppError.userMessage(from: error)
        }
    }

    func toggleListMembership(
        _ membership: ProfileListMembership,
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async {
        guard let profile else { return }

        isUpdatingModeration = true
        defer { isUpdatingModeration = false }

        do {
            if membership.isMember, let recordURI = membership.listItemRecordURI {
                try await client.removeMember(
                    recordURI: recordURI,
                    account: account,
                    appPassword: appPassword
                )
                statusMessage = "Removed from \(membership.name)."
            } else {
                guard let list = try await client.fetchList(
                    uri: membership.listURI,
                    account: account,
                    appPassword: appPassword
                ) else {
                    throw BlueskyAPIError.server("That list could not be loaded.")
                }

                _ = try await client.addActor(
                    did: profile.did,
                    to: list,
                    account: account,
                    appPassword: appPassword
                )
                statusMessage = "Added to \(membership.name)."
            }

            await load(
                did: profile.did,
                account: account,
                appPassword: appPassword,
                using: client
            )
        } catch {
            errorMessage = AppError.userMessage(from: error)
        }
    }
}
