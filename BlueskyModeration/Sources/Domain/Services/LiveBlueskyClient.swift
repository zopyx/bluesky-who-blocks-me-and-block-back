import Foundation

struct BlueskySession: Codable, Sendable {
    let did: String
    let handle: String
    let accessJWT: String
    let refreshJWT: String?
    let pdsURL: URL
}

struct PagedListMembers {
    let members: [BlueskyListMember]
    let cursor: String?
}

struct PagedActorSearch {
    let actors: [BlueskyActor]
    let cursor: String?
}

@MainActor
protocol BlueskyAuthenticating {
    func authenticate(handle: String, appPassword: String, entrywayURL: URL?) async throws -> BlueskySession
    func persistSession(_ session: BlueskySession, for account: AppAccount) async throws
    func deletePersistedSession(for account: AppAccount) throws
}

@MainActor
class LiveBlueskyClient: ObservableObject, BlueskyAuthenticating, BlueskyListServicing, BlueskyProfileInspecting {
    private let session: URLSession
    private let requestExecutor: BlueskyRequestExecuting
    private let sessionService: BlueskySessionServicing

    init(
        baseURL: URL = URL(string: "https://bsky.social")!,
        session: URLSession = .shared,
        keychain: KeychainServicing = KeychainService(),
        requestExecutor: BlueskyRequestExecuting? = nil,
        sessionService: BlueskySessionServicing? = nil
    ) {
        self.session = session
        let executor = requestExecutor ?? BlueskyRequestExecutor(baseURL: baseURL, session: session)
        self.requestExecutor = executor
        self.sessionService = sessionService ?? BlueskySessionService(
            baseURL: baseURL,
            requestExecutor: executor,
            keychain: keychain
        )
    }

    func clearCache() {
        session.configuration.urlCache?.removeAllCachedResponses()
        URLCache.shared.removeAllCachedResponses()
        sessionService.clearSessionCache()
    }

    func authenticate(handle: String, appPassword: String, entrywayURL: URL? = nil) async throws -> BlueskySession {
        try await sessionService.authenticate(handle: handle, appPassword: appPassword, entrywayURL: entrywayURL)
    }

    func persistSession(_ authSession: BlueskySession, for account: AppAccount) async throws {
        try await sessionService.persistSession(authSession, for: account)
    }

    func deletePersistedSession(for account: AppAccount) throws {
        try sessionService.deletePersistedSession(for: account)
    }

    func restoreSessions(for accounts: [AppAccount]) async {
        await sessionService.restoreSessions(for: accounts)
    }

    func fetchLists(for account: AppAccount, appPassword: String?) async throws -> [BlueskyList] {
        let response: GetListsResponse = try await sessionService.performAuthenticatedRequest(
            account: account,
            appPassword: appPassword
        ) { authSession in
            try await requestExecutor.send(
                path: "app.bsky.graph.getLists",
                method: "GET",
                queryItems: [
                    URLQueryItem(name: "actor", value: authSession.did),
                    URLQueryItem(name: "limit", value: "100")
                ],
                accessToken: authSession.accessJWT,
                hostURL: authSession.pdsURL
            )
        }

        return response.lists.map { item in
            BlueskyList(
                id: item.uri,
                name: item.name,
                description: item.description ?? item.purpose.displayTitle,
                memberCount: item.listItemCount,
                kind: item.purpose.kind
            )
        }
    }

    func fetchList(
        uri: String,
        account: AppAccount,
        appPassword: String?
    ) async throws -> BlueskyList? {
        let lists = try await fetchLists(for: account, appPassword: appPassword)
        return lists.first { $0.id == uri }
    }

    func fetchListMembers(
        list: BlueskyList,
        account: AppAccount,
        appPassword: String?
    ) async throws -> [BlueskyListMember] {
        var allMembers: [BlueskyListMember] = []
        var cursor: String?

        repeat {
            let page = try await fetchListMembersPage(
                list: list,
                cursor: cursor,
                account: account,
                appPassword: appPassword
            )
            allMembers.append(contentsOf: page.members)
            cursor = page.cursor
        } while cursor != nil

        return allMembers
    }

    func fetchListMembersPage(
        list: BlueskyList,
        cursor: String?,
        account: AppAccount,
        appPassword: String?
    ) async throws -> PagedListMembers {
        let response: GetListResponse = try await sessionService.performAuthenticatedRequest(
            account: account,
            appPassword: appPassword
        ) { authSession in
            var queryItems = [
                URLQueryItem(name: "list", value: list.id),
                URLQueryItem(name: "limit", value: "100")
            ]
            if let cursor {
                queryItems.append(URLQueryItem(name: "cursor", value: cursor))
            }

            return try await requestExecutor.send(
                path: "app.bsky.graph.getList",
                method: "GET",
                queryItems: queryItems,
                accessToken: authSession.accessJWT,
                hostURL: authSession.pdsURL
            )
        }

        return PagedListMembers(
            members: response.items.map {
                BlueskyListMember(
                    recordURI: $0.uri,
                    actor: BlueskyActor(
                        did: $0.subject.did,
                        handle: $0.subject.handle,
                        displayName: $0.subject.displayName,
                        avatarURL: URL(string: $0.subject.avatar ?? "")
                    )
                )
            },
            cursor: response.cursor
        )
    }

    func searchActors(
        query: String,
        account: AppAccount,
        appPassword: String?
    ) async throws -> [BlueskyActor] {
        let page = try await searchActorsPage(
            query: query,
            cursor: nil,
            account: account,
            appPassword: appPassword
        )
        return page.actors
    }

    func searchActorsPage(
        query: String,
        cursor: String?,
        account: AppAccount,
        appPassword: String?
    ) async throws -> PagedActorSearch {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return PagedActorSearch(actors: [], cursor: nil)
        }

        let response: SearchActorsResponse = try await sessionService.performAuthenticatedRequest(
            account: account,
            appPassword: appPassword
        ) { authSession in
            var queryItems = [
                URLQueryItem(name: "q", value: trimmedQuery),
                URLQueryItem(name: "limit", value: "25")
            ]
            if let cursor {
                queryItems.append(URLQueryItem(name: "cursor", value: cursor))
            }

            return try await requestExecutor.send(
                path: "app.bsky.actor.searchActorsTypeahead",
                method: "GET",
                queryItems: queryItems,
                accessToken: authSession.accessJWT,
                hostURL: authSession.pdsURL
            )
        }

        return PagedActorSearch(
            actors: response.actors.map {
                BlueskyActor(
                    did: $0.did,
                    handle: $0.handle,
                    displayName: $0.displayName,
                    avatarURL: URL(string: $0.avatar ?? "")
                )
            },
            cursor: response.cursor
        )
    }

    func addActor(
        did actorDID: String,
        to list: BlueskyList,
        account: AppAccount,
        appPassword: String?
    ) async throws -> String {
        let response: CreateRecordResponse = try await sessionService.performAuthenticatedRequest(
            account: account,
            appPassword: appPassword
        ) { authSession in
            let body = CreateRecordRequest(
                repo: authSession.did,
                collection: "app.bsky.graph.listitem",
                record: ListItemRecord(
                    createdAt: ISO8601DateFormatter().string(from: .now),
                    list: list.id,
                    subject: actorDID
                )
            )

            let response: CreateRecordResponse = try await requestExecutor.send(
                path: "com.atproto.repo.createRecord",
                method: "POST",
                queryItems: [],
                body: body,
                accessToken: authSession.accessJWT,
                hostURL: authSession.pdsURL
            )

            return response
        }
        return response.uri
    }

    func removeMember(
        recordURI: String,
        account: AppAccount,
        appPassword: String?
    ) async throws {
        let record = try parseATURI(recordURI)
        let _: EmptyResponse = try await sessionService.performAuthenticatedRequest(
            account: account,
            appPassword: appPassword
        ) { authSession in
            let body = DeleteRecordRequest(
                repo: authSession.did,
                collection: record.collection,
                rkey: record.rkey
            )

            return try await requestExecutor.send(
                path: "com.atproto.repo.deleteRecord",
                method: "POST",
                queryItems: [],
                body: body,
                accessToken: authSession.accessJWT,
                hostURL: authSession.pdsURL
            )
        }
    }

    func createList(
        name: String,
        description: String,
        kind: BlueskyList.Kind,
        account: AppAccount,
        appPassword: String?
    ) async throws -> BlueskyList {
        let response: CreateRecordResponse = try await sessionService.performAuthenticatedRequest(
            account: account,
            appPassword: appPassword
        ) { authSession in
            let body = CreateGenericRecordRequest(
                repo: authSession.did,
                collection: "app.bsky.graph.list",
                record: ListRecord(
                    type: "app.bsky.graph.list",
                    purpose: kind.purposeIdentifier,
                    name: name,
                    description: description.isEmpty ? nil : description,
                    createdAt: ISO8601DateFormatter().string(from: .now)
                )
            )
            return try await requestExecutor.send(
                path: "com.atproto.repo.createRecord",
                method: "POST",
                queryItems: [],
                body: body,
                accessToken: authSession.accessJWT,
                hostURL: authSession.pdsURL
            )
        }

        return BlueskyList(
            id: response.uri,
            name: name,
            description: description.isEmpty ? kind.title : description,
            memberCount: 0,
            kind: kind
        )
    }

    func deleteList(
        list: BlueskyList,
        account: AppAccount,
        appPassword: String?
    ) async throws {
        let record = try parseATURI(list.id)
        let _: EmptyResponse = try await sessionService.performAuthenticatedRequest(
            account: account,
            appPassword: appPassword
        ) { authSession in
            let body = DeleteRecordRequest(
                repo: authSession.did,
                collection: record.collection,
                rkey: record.rkey
            )
            return try await requestExecutor.send(
                path: "com.atproto.repo.deleteRecord",
                method: "POST",
                queryItems: [],
                body: body,
                accessToken: authSession.accessJWT,
                hostURL: authSession.pdsURL
            )
        }
    }

    func updateListMetadata(
        list: BlueskyList,
        title: String,
        description: String,
        account: AppAccount,
        appPassword: String?
    ) async throws -> BlueskyList {
        let record = try parseATURI(list.id)
        let _: CreateRecordResponse = try await sessionService.performAuthenticatedRequest(
            account: account,
            appPassword: appPassword
        ) { authSession in
            let body = PutRecordRequest(
                repo: authSession.did,
                collection: record.collection,
                rkey: record.rkey,
                record: ListRecord(
                    type: "app.bsky.graph.list",
                    purpose: list.kind.purposeIdentifier,
                    name: title,
                    description: description.isEmpty ? nil : description,
                    createdAt: ISO8601DateFormatter().string(from: .now)
                )
            )

            return try await requestExecutor.send(
                path: "com.atproto.repo.putRecord",
                method: "POST",
                queryItems: [],
                body: body,
                accessToken: authSession.accessJWT,
                hostURL: authSession.pdsURL
            )
        }

        return BlueskyList(
            id: list.id,
            name: title,
            description: description.isEmpty ? list.kind.title : description,
            memberCount: list.memberCount,
            kind: list.kind
        )
    }

    func blockActor(
        did actorDID: String,
        account: AppAccount,
        appPassword: String?
    ) async throws {
        let _: EmptyResponse = try await sessionService.performAuthenticatedRequest(
            account: account,
            appPassword: appPassword
        ) { authSession in
            let body = CreateGenericRecordRequest(
                repo: authSession.did,
                collection: "app.bsky.graph.block",
                record: SubjectRecord(type: "app.bsky.graph.block", subject: actorDID)
            )

            let _: CreateRecordResponse = try await requestExecutor.send(
                path: "com.atproto.repo.createRecord",
                method: "POST",
                queryItems: [],
                body: body,
                accessToken: authSession.accessJWT,
                hostURL: authSession.pdsURL
            )

            return EmptyResponse()
        }
    }

    func unblockActor(
        recordURI: String,
        account: AppAccount,
        appPassword: String?
    ) async throws {
        try await removeMember(
            recordURI: recordURI,
            account: account,
            appPassword: appPassword
        )
    }

    func muteActor(
        did actorDID: String,
        account: AppAccount,
        appPassword: String?
    ) async throws {
        let _: EmptyResponse = try await sessionService.performAuthenticatedRequest(
            account: account,
            appPassword: appPassword
        ) { authSession in
            let body = ActorReferenceRequest(actor: actorDID)
            return try await requestExecutor.send(
                path: "app.bsky.graph.muteActor",
                method: "POST",
                queryItems: [],
                body: body,
                accessToken: authSession.accessJWT,
                hostURL: authSession.pdsURL
            )
        }
    }

    func unmuteActor(
        did actorDID: String,
        account: AppAccount,
        appPassword: String?
    ) async throws {
        let _: EmptyResponse = try await sessionService.performAuthenticatedRequest(
            account: account,
            appPassword: appPassword
        ) { authSession in
            let body = ActorReferenceRequest(actor: actorDID)
            return try await requestExecutor.send(
                path: "app.bsky.graph.unmuteActor",
                method: "POST",
                queryItems: [],
                body: body,
                accessToken: authSession.accessJWT,
                hostURL: authSession.pdsURL
            )
        }
    }

    func fetchProfile(
        did actorDID: String,
        account: AppAccount,
        appPassword: String?
    ) async throws -> BlueskyProfile {
        let response: ProfileViewDetailed = try await sessionService.performAuthenticatedRequest(
            account: account,
            appPassword: appPassword
        ) { authSession in
            try await requestExecutor.send(
                path: "app.bsky.actor.getProfile",
                method: "GET",
                queryItems: [
                    URLQueryItem(name: "actor", value: actorDID)
                ],
                accessToken: authSession.accessJWT,
                hostURL: authSession.pdsURL
            )
        }

        return BlueskyProfile(
            id: response.did,
            did: response.did,
            handle: response.handle,
            displayName: response.displayName,
            description: response.description,
            websiteURL: URL(string: response.website ?? ""),
            avatarURL: URL(string: response.avatar ?? ""),
            bannerURL: URL(string: response.banner ?? ""),
            followersCount: response.followersCount,
            followsCount: response.followsCount,
            postsCount: response.postsCount
            ,
            listsCount: response.associated?.lists,
            starterPacksCount: response.associated?.starterPacks,
            createdAt: parseDate(response.createdAt),
            labels: response.labels?.map(\.val) ?? [],
            viewerState: mapViewerState(response.viewer)
        )
    }

    func fetchBlockedActors(
        account: AppAccount,
        appPassword: String?
    ) async throws -> [BlueskyActor] {
        var all: [BlueskyActor] = []
        var cursor: String?
        repeat {
            let response: GetBlocksResponse = try await sessionService.performAuthenticatedRequest(
                account: account,
                appPassword: appPassword
            ) { authSession in
                var queryItems = [URLQueryItem(name: "limit", value: "100")]
                if let cursor {
                    queryItems.append(URLQueryItem(name: "cursor", value: cursor))
                }
                return try await requestExecutor.send(
                    path: "app.bsky.graph.getBlocks",
                    method: "GET",
                    queryItems: queryItems,
                    accessToken: authSession.accessJWT,
                    hostURL: authSession.pdsURL
                )
            }
            all.append(contentsOf: response.blocks.map {
                BlueskyActor(
                    did: $0.did,
                    handle: $0.handle,
                    displayName: $0.displayName,
                    avatarURL: URL(string: $0.avatar ?? "")
                )
            })
            cursor = response.cursor
        } while cursor != nil
        return all
    }

    func fetchPLCAuditLog(did: String) async throws -> [PLCAuditLogEntry] {
        guard let url = URL(string: "https://plc.directory/\(did)/log/audit") else {
            throw BlueskyAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue("Rulyx Moderation App", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw BlueskyAPIError.invalidResponse
        }
        return try JSONDecoder().decode([PLCAuditLogEntry].self, from: data)
    }

    func fetchFollowers(
        actor actorDID: String,
        account: AppAccount,
        appPassword: String?
    ) async throws -> [BlueskyActor] {
        var all: [BlueskyActor] = []
        var cursor: String?
        var pageCount = 0
        let maxPages = 50
        var lastError: Error?
        repeat {
            do {
                let page = try await fetchFollowersPage(actor: actorDID, cursor: cursor, account: account, appPassword: appPassword)
                all.append(contentsOf: page.actors)
                cursor = page.cursor
                pageCount += 1
                if pageCount >= maxPages { break }
                lastError = nil
            } catch {
                lastError = error
                if cursor == nil { throw error }
                break
            }
        } while cursor != nil
        if all.isEmpty, let lastError { throw lastError }
        return all
    }

    func fetchFollowersPage(
        actor actorDID: String,
        cursor: String?,
        account: AppAccount,
        appPassword: String?
    ) async throws -> PagedActorSearch {
        let response: GetFollowersResponse = try await sessionService.performAuthenticatedRequest(
            account: account,
            appPassword: appPassword
        ) { authSession in
            var queryItems = [
                URLQueryItem(name: "actor", value: actorDID),
                URLQueryItem(name: "limit", value: "100")
            ]
            if let cursor {
                queryItems.append(URLQueryItem(name: "cursor", value: cursor))
            }
            return try await requestExecutor.send(
                path: "app.bsky.graph.getFollowers",
                method: "GET",
                queryItems: queryItems,
                accessToken: authSession.accessJWT,
                hostURL: authSession.pdsURL
            )
        }
        return PagedActorSearch(
            actors: response.followers.map {
                BlueskyActor(
                    did: $0.did,
                    handle: $0.handle,
                    displayName: $0.displayName,
                    avatarURL: URL(string: $0.avatar ?? ""),
                    createdAt: parseDate($0.createdAt)
                )
            },
            cursor: response.cursor
        )
    }

    func fetchFollowing(
        actor actorDID: String,
        account: AppAccount,
        appPassword: String?
    ) async throws -> [BlueskyActor] {
        var all: [BlueskyActor] = []
        var cursor: String?
        var pageCount = 0
        let maxPages = 50
        var lastError: Error?
        repeat {
            do {
                let page = try await fetchFollowingPage(actor: actorDID, cursor: cursor, account: account, appPassword: appPassword)
                all.append(contentsOf: page.actors)
                cursor = page.cursor
                pageCount += 1
                if pageCount >= maxPages { break }
                lastError = nil
            } catch {
                lastError = error
                if cursor == nil { throw error }
                break
            }
        } while cursor != nil
        if all.isEmpty, let lastError { throw lastError }
        return all
    }

    func fetchFollowingPage(
        actor actorDID: String,
        cursor: String?,
        account: AppAccount,
        appPassword: String?
    ) async throws -> PagedActorSearch {
        let response: GetFollowsResponse = try await sessionService.performAuthenticatedRequest(
            account: account,
            appPassword: appPassword
        ) { authSession in
            var queryItems = [
                URLQueryItem(name: "actor", value: actorDID),
                URLQueryItem(name: "limit", value: "100")
            ]
            if let cursor {
                queryItems.append(URLQueryItem(name: "cursor", value: cursor))
            }
            return try await requestExecutor.send(
                path: "app.bsky.graph.getFollows",
                method: "GET",
                queryItems: queryItems,
                accessToken: authSession.accessJWT,
                hostURL: authSession.pdsURL
            )
        }
        return PagedActorSearch(
            actors: response.follows.map {
                BlueskyActor(did: $0.did, handle: $0.handle, displayName: $0.displayName, avatarURL: URL(string: $0.avatar ?? ""), createdAt: parseDate($0.createdAt))
            },
            cursor: response.cursor
        )
    }

    func inspectProfile(
        query: String,
        account: AppAccount,
        appPassword: String?
    ) async throws -> ProfileInspection {
        let actor = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !actor.isEmpty else {
            throw BlueskyAPIError.server("Enter a Bluesky handle or DID.")
        }

        let (profile, lists, starterPacks): (ProfileViewDetailed, ListsWithMembershipResponse, StarterPacksWithMembershipResponse) =
            try await sessionService.performAuthenticatedRequest(
                account: account,
                appPassword: appPassword
            ) { authSession in
                async let profileResponse: ProfileViewDetailed = requestExecutor.send(
                    path: "app.bsky.actor.getProfile",
                    method: "GET",
                    queryItems: [URLQueryItem(name: "actor", value: actor)],
                    accessToken: authSession.accessJWT,
                    hostURL: authSession.pdsURL
                )
                async let listMembershipResponse: ListsWithMembershipResponse = requestExecutor.send(
                    path: "app.bsky.graph.getListsWithMembership",
                    method: "GET",
                    queryItems: [
                        URLQueryItem(name: "actor", value: actor),
                        URLQueryItem(name: "limit", value: "100")
                    ],
                    accessToken: authSession.accessJWT,
                    hostURL: authSession.pdsURL
                )
                async let starterPackMembershipResponse: StarterPacksWithMembershipResponse = requestExecutor.send(
                    path: "app.bsky.graph.getStarterPacksWithMembership",
                    method: "GET",
                    queryItems: [
                        URLQueryItem(name: "actor", value: actor),
                        URLQueryItem(name: "limit", value: "100")
                    ],
                    accessToken: authSession.accessJWT,
                    hostURL: authSession.pdsURL
                )

                return try await (profileResponse, listMembershipResponse, starterPackMembershipResponse)
            }

        let mappedProfile = BlueskyProfile(
            id: profile.did,
            did: profile.did,
            handle: profile.handle,
            displayName: profile.displayName,
            description: profile.description,
            websiteURL: URL(string: profile.website ?? ""),
            avatarURL: URL(string: profile.avatar ?? ""),
            bannerURL: URL(string: profile.banner ?? ""),
            followersCount: profile.followersCount,
            followsCount: profile.followsCount,
            postsCount: profile.postsCount,
            listsCount: profile.associated?.lists,
            starterPacksCount: profile.associated?.starterPacks,
            createdAt: parseDate(profile.createdAt),
            labels: profile.labels?.map(\.val) ?? [],
            viewerState: mapViewerState(profile.viewer)
        )

        return ProfileInspection(
            profile: mappedProfile,
            listMemberships: lists.listsWithMembership.map {
                ProfileListMembership(
                    listURI: $0.list.uri,
                    name: $0.list.name,
                    kind: $0.list.purpose.kind,
                    memberCount: $0.list.listItemCount,
                    isMember: $0.listItem != nil,
                    listItemRecordURI: $0.listItem?.uri
                )
            },
            starterPackMemberships: starterPacks.starterPacksWithMembership.map {
                ProfileStarterPackMembership(
                    uri: $0.starterPack.uri,
                    name: $0.starterPack.name ?? $0.starterPack.uri,
                    memberCount: $0.starterPack.listItemCount,
                    joinedAllTimeCount: $0.starterPack.joinedAllTimeCount,
                    isMember: $0.listItem != nil
                )
            }
        )
    }
}

