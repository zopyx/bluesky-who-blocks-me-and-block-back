import Foundation

@MainActor
final class PreviewBlueskyClient: LiveBlueskyClient {
    override func authenticate(handle: String, appPassword: String) async throws -> BlueskySession {
        BlueskySession(
            did: "did:plc:previewaccount",
            handle: handle,
            accessJWT: "preview-access",
            refreshJWT: nil,
            pdsURL: URL(string: "https://bsky.social")!
        )
    }

    override func fetchLists(for account: AppAccount, appPassword: String) async throws -> [BlueskyList] {
        try await Task.sleep(for: .milliseconds(150))

        let seed = abs(account.handle.hashValue)
        let regularBase = 2 + (seed % 4)
        let moderationBase = 1 + (seed % 3)

        return [
            BlueskyList(
                id: "\(account.handle)-mod-1",
                name: "Spam Watch",
                description: "Accounts frequently reported for spam patterns.",
                memberCount: 120 + moderationBase,
                kind: .moderation
            ),
            BlueskyList(
                id: "\(account.handle)-mod-2",
                name: "Reply Filters",
                description: "Aggressive reply actors tracked for moderation review.",
                memberCount: 42 + moderationBase,
                kind: .moderation
            ),
            BlueskyList(
                id: "\(account.handle)-list-1",
                name: "Trusted Sources",
                description: "Accounts curated for signal over noise.",
                memberCount: 65 + regularBase,
                kind: .regular
            ),
            BlueskyList(
                id: "\(account.handle)-list-2",
                name: "Community Core",
                description: "People to monitor for community health updates.",
                memberCount: 18 + regularBase,
                kind: .regular
            ),
            BlueskyList(
                id: "\(account.handle)-list-3",
                name: "New Reports",
                description: "Freshly observed accounts pending deeper review.",
                memberCount: 7 + regularBase,
                kind: .regular
            )
        ]
    }

    override func fetchListMembers(
        list: BlueskyList,
        account: AppAccount,
        appPassword: String
    ) async throws -> [BlueskyListMember] {
        try await Task.sleep(for: .milliseconds(120))

        return [
            BlueskyListMember(
                recordURI: "at://did:plc:preview/app.bsky.graph.listitem/1",
                actor: BlueskyActor(did: "did:plc:1", handle: "alice.bsky.social", displayName: "Alice Chen")
            ),
            BlueskyListMember(
                recordURI: "at://did:plc:preview/app.bsky.graph.listitem/2",
                actor: BlueskyActor(did: "did:plc:2", handle: "moderator.bsky.social", displayName: "Moderator Desk")
            ),
            BlueskyListMember(
                recordURI: "at://did:plc:preview/app.bsky.graph.listitem/3",
                actor: BlueskyActor(did: "did:plc:3", handle: "safetylab.bsky.social", displayName: "Safety Lab")
            )
        ]
    }

    override func searchActors(
        query: String,
        account: AppAccount,
        appPassword: String
    ) async throws -> [BlueskyActor] {
        try await Task.sleep(for: .milliseconds(120))

        let all = [
            BlueskyActor(did: "did:plc:1", handle: "alice.bsky.social", displayName: "Alice Chen"),
            BlueskyActor(did: "did:plc:2", handle: "moderator.bsky.social", displayName: "Moderator Desk"),
            BlueskyActor(did: "did:plc:3", handle: "safetylab.bsky.social", displayName: "Safety Lab"),
            BlueskyActor(did: "did:plc:4", handle: "bskynews.bsky.social", displayName: "Bluesky News"),
            BlueskyActor(did: "did:plc:5", handle: "curation.team", displayName: "Curation Team")
        ]

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }

        return all.filter {
            $0.handle.lowercased().contains(trimmed) ||
            ($0.displayName?.lowercased().contains(trimmed) ?? false)
        }
    }

    override func addActor(
        did actorDID: String,
        to list: BlueskyList,
        account: AppAccount,
        appPassword: String
    ) async throws {
        try await Task.sleep(for: .milliseconds(100))
    }

    override func removeMember(
        recordURI: String,
        account: AppAccount,
        appPassword: String
    ) async throws {
        try await Task.sleep(for: .milliseconds(100))
    }

    override func updateListMetadata(
        list: BlueskyList,
        title: String,
        description: String,
        account: AppAccount,
        appPassword: String
    ) async throws -> BlueskyList {
        try await Task.sleep(for: .milliseconds(120))

        return BlueskyList(
            id: list.id,
            name: title,
            description: description.isEmpty ? list.kind.title : description,
            memberCount: list.memberCount,
            kind: list.kind
        )
    }

    override func fetchProfile(
        did actorDID: String,
        account: AppAccount,
        appPassword: String
    ) async throws -> BlueskyProfile {
        try await Task.sleep(for: .milliseconds(120))

        return BlueskyProfile(
            id: actorDID,
            did: actorDID,
            handle: "alice.bsky.social",
            displayName: "Alice Chen",
            description: "Community moderation and list curation.",
            websiteURL: URL(string: "https://example.com"),
            avatarURL: nil,
            bannerURL: nil,
            followersCount: 1200,
            followsCount: 340,
            postsCount: 89,
            listsCount: 3,
            starterPacksCount: 1,
            createdAt: .now.addingTimeInterval(-86_400 * 200),
            labels: ["spam", "bot"],
            viewerState: BlueskyViewerState(
                muted: false,
                blockedBy: false,
                isBlocking: false,
                isFollowing: true,
                followsYou: false,
                mutedByListName: nil,
                blockingByListName: nil
            )
        )
    }

    override func inspectProfile(
        query: String,
        account: AppAccount,
        appPassword: String
    ) async throws -> ProfileInspection {
        try await Task.sleep(for: .milliseconds(150))

        return ProfileInspection(
            profile: BlueskyProfile(
                id: "did:plc:preview-inspect",
                did: "did:plc:preview-inspect",
                handle: query.isEmpty ? "example.bsky.social" : query,
                displayName: "Example Profile",
                description: "Preview inspector data modeled after a ClearSky-style lookup.",
                websiteURL: URL(string: "https://bsky.app"),
                avatarURL: nil,
                bannerURL: nil,
                followersCount: 5400,
                followsCount: 420,
                postsCount: 128,
                listsCount: 4,
                starterPacksCount: 2,
                createdAt: .now.addingTimeInterval(-86_400 * 500),
                labels: ["bot", "spam"],
                viewerState: BlueskyViewerState(
                    muted: false,
                    blockedBy: false,
                    isBlocking: true,
                    isFollowing: true,
                    followsYou: false,
                    mutedByListName: nil,
                    blockingByListName: "Reply Filters"
                )
            ),
            listMemberships: [
                ProfileListMembership(
                    listURI: "at://did:plc:preview/app.bsky.graph.list/1",
                    name: "Reply Filters",
                    kind: .moderation,
                    memberCount: 42,
                    isMember: true
                ),
                ProfileListMembership(
                    listURI: "at://did:plc:preview/app.bsky.graph.list/2",
                    name: "Trusted Sources",
                    kind: .regular,
                    memberCount: 67,
                    isMember: false
                )
            ],
            starterPackMemberships: [
                ProfileStarterPackMembership(
                    uri: "at://did:plc:preview/app.bsky.graph.starterpack/1",
                    name: "Safety Starter Pack",
                    memberCount: 25,
                    joinedAllTimeCount: 340,
                    isMember: true
                )
            ]
        )
    }
}
