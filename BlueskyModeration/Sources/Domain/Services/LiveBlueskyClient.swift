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

enum BlueskyAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case missingCredentials
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The Bluesky endpoint URL is invalid."
        case .invalidResponse:
            return "Bluesky returned an unexpected response."
        case .unauthorized:
            return "Bluesky rejected the credentials. Check the handle and app password."
        case .missingCredentials:
            return "No saved app password was found for this account."
        case .server(let message):
            return message
        }
    }
}

@MainActor
protocol BlueskyAuthenticating {
    func authenticate(handle: String, appPassword: String) async throws -> BlueskySession
}

@MainActor
class LiveBlueskyClient: ObservableObject, BlueskyAuthenticating, BlueskyListServicing {
    private let entrywayURL: URL
    private let session: URLSession
    private let keychain: KeychainServicing
    private var cachedSessions: [String: BlueskySession] = [:]
    private let persistedSessionService = "com.ajung.BlueskyModeration.session"

    init(
        baseURL: URL = URL(string: "https://bsky.social")!,
        session: URLSession = .shared,
        keychain: KeychainServicing = KeychainService()
    ) {
        self.entrywayURL = baseURL
        self.session = session
        self.keychain = keychain
    }

    func clearCache() {
        session.configuration.urlCache?.removeAllCachedResponses()
        URLCache.shared.removeAllCachedResponses()
        cachedSessions.removeAll()
    }

    func authenticate(handle: String, appPassword: String) async throws -> BlueskySession {
        let requestBody = CreateSessionRequest(identifier: handle, password: appPassword)
        let authURL = try await authenticationURL(forHandle: handle)
        let response: CreateSessionResponse = try await send(
            path: "com.atproto.server.createSession",
            method: "POST",
            body: requestBody,
            accessToken: nil,
            hostURL: authURL
        )

        let pdsURL = try await resolvedPDSURL(
            from: response.didDoc,
            did: response.did,
            fallback: authURL
        )

        return BlueskySession(
            did: response.did,
            handle: response.handle,
            accessJWT: response.accessJWT,
            refreshJWT: response.refreshJWT,
            pdsURL: pdsURL
        )
    }

    func persistSession(_ authSession: BlueskySession, for account: AppAccount) async throws {
        let data = try JSONEncoder().encode(authSession)
        guard let value = String(data: data, encoding: .utf8) else {
            throw BlueskyAPIError.invalidResponse
        }
        try keychain.save(value, service: persistedSessionService, account: account.id.uuidString)
        cachedSessions[account.id.uuidString] = authSession
    }

    func deletePersistedSession(for account: AppAccount) throws {
        cachedSessions.removeValue(forKey: account.id.uuidString)
        try keychain.delete(service: persistedSessionService, account: account.id.uuidString)
    }

    func restoreSessions(for accounts: [AppAccount]) async {
        for account in accounts {
            _ = try? await cachedSession(for: account, appPassword: nil)
        }
    }

    func fetchLists(for account: AppAccount, appPassword: String) async throws -> [BlueskyList] {
        let response: GetListsResponse = try await performAuthenticatedRequest(
            account: account,
            appPassword: appPassword
        ) { authSession in
            try await send(
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
        appPassword: String
    ) async throws -> BlueskyList? {
        let lists = try await fetchLists(for: account, appPassword: appPassword)
        return lists.first { $0.id == uri }
    }

    func fetchListMembers(
        list: BlueskyList,
        account: AppAccount,
        appPassword: String
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
        appPassword: String
    ) async throws -> PagedListMembers {
        let response: GetListResponse = try await performAuthenticatedRequest(
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

            return try await send(
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
        appPassword: String
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
        appPassword: String
    ) async throws -> PagedActorSearch {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return PagedActorSearch(actors: [], cursor: nil)
        }

        let response: SearchActorsResponse = try await performAuthenticatedRequest(
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

            return try await send(
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
        appPassword: String
    ) async throws {
        let _: EmptyResponse = try await performAuthenticatedRequest(
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

            let _: CreateRecordResponse = try await send(
                path: "com.atproto.repo.createRecord",
                method: "POST",
                body: body,
                accessToken: authSession.accessJWT,
                hostURL: authSession.pdsURL
            )

            return EmptyResponse()
        }
    }

    func removeMember(
        recordURI: String,
        account: AppAccount,
        appPassword: String
    ) async throws {
        let record = try parseATURI(recordURI)
        let _: EmptyResponse = try await performAuthenticatedRequest(
            account: account,
            appPassword: appPassword
        ) { authSession in
            let body = DeleteRecordRequest(
                repo: authSession.did,
                collection: record.collection,
                rkey: record.rkey
            )

            return try await send(
                path: "com.atproto.repo.deleteRecord",
                method: "POST",
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
        appPassword: String
    ) async throws -> BlueskyList {
        let record = try parseATURI(list.id)
        let _: CreateRecordResponse = try await performAuthenticatedRequest(
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

            return try await send(
                path: "com.atproto.repo.putRecord",
                method: "POST",
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
        appPassword: String
    ) async throws {
        let _: EmptyResponse = try await performAuthenticatedRequest(
            account: account,
            appPassword: appPassword
        ) { authSession in
            let body = CreateGenericRecordRequest(
                repo: authSession.did,
                collection: "app.bsky.graph.block",
                record: SubjectRecord(type: "app.bsky.graph.block", subject: actorDID)
            )

            let _: CreateRecordResponse = try await send(
                path: "com.atproto.repo.createRecord",
                method: "POST",
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
        appPassword: String
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
        appPassword: String
    ) async throws {
        let _: EmptyResponse = try await performAuthenticatedRequest(
            account: account,
            appPassword: appPassword
        ) { authSession in
            let body = ActorReferenceRequest(actor: actorDID)
            return try await send(
                path: "app.bsky.graph.muteActor",
                method: "POST",
                body: body,
                accessToken: authSession.accessJWT,
                hostURL: authSession.pdsURL
            )
        }
    }

    func unmuteActor(
        did actorDID: String,
        account: AppAccount,
        appPassword: String
    ) async throws {
        let _: EmptyResponse = try await performAuthenticatedRequest(
            account: account,
            appPassword: appPassword
        ) { authSession in
            let body = ActorReferenceRequest(actor: actorDID)
            return try await send(
                path: "app.bsky.graph.unmuteActor",
                method: "POST",
                body: body,
                accessToken: authSession.accessJWT,
                hostURL: authSession.pdsURL
            )
        }
    }

    func fetchProfile(
        did actorDID: String,
        account: AppAccount,
        appPassword: String
    ) async throws -> BlueskyProfile {
        let response: ProfileViewDetailed = try await performAuthenticatedRequest(
            account: account,
            appPassword: appPassword
        ) { authSession in
            try await send(
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

    func inspectProfile(
        query: String,
        account: AppAccount,
        appPassword: String
    ) async throws -> ProfileInspection {
        let actor = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !actor.isEmpty else {
            throw BlueskyAPIError.server("Enter a Bluesky handle or DID.")
        }

        let (profile, lists, starterPacks): (ProfileViewDetailed, ListsWithMembershipResponse, StarterPacksWithMembershipResponse) =
            try await performAuthenticatedRequest(
                account: account,
                appPassword: appPassword
            ) { authSession in
                async let profileResponse: ProfileViewDetailed = send(
                    path: "app.bsky.actor.getProfile",
                    method: "GET",
                    queryItems: [URLQueryItem(name: "actor", value: actor)],
                    accessToken: authSession.accessJWT,
                    hostURL: authSession.pdsURL
                )
                async let listMembershipResponse: ListsWithMembershipResponse = send(
                    path: "app.bsky.graph.getListsWithMembership",
                    method: "GET",
                    queryItems: [
                        URLQueryItem(name: "actor", value: actor),
                        URLQueryItem(name: "limit", value: "100")
                    ],
                    accessToken: authSession.accessJWT,
                    hostURL: authSession.pdsURL
                )
                async let starterPackMembershipResponse: StarterPacksWithMembershipResponse = send(
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

    private func send<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Body?,
        accessToken: String?,
        hostURL: URL? = nil
    ) async throws -> Response {
        let targetURL = hostURL ?? entrywayURL
        guard var components = URLComponents(url: targetURL.appendingPathComponent("xrpc/\(path)"), resolvingAgainstBaseURL: false) else {
            throw BlueskyAPIError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw BlueskyAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BlueskyAPIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw BlueskyAPIError.unauthorized
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            if let errorPayload = try? JSONDecoder().decode(APIErrorPayload.self, from: data) {
                throw BlueskyAPIError.server(errorPayload.message ?? errorPayload.error ?? "Bluesky request failed.")
            }
            throw BlueskyAPIError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw BlueskyAPIError.invalidResponse
        }
    }

    private func send<Response: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        accessToken: String?,
        hostURL: URL? = nil
    ) async throws -> Response {
        try await send(
            path: path,
            method: method,
            queryItems: queryItems,
            body: Optional<String>.none,
            accessToken: accessToken,
            hostURL: hostURL
        )
    }

    private func performAuthenticatedRequest<Response>(
        account: AppAccount,
        appPassword: String,
        operation: (BlueskySession) async throws -> Response
    ) async throws -> Response {
        var authSession = try await cachedSession(for: account, appPassword: appPassword)

        do {
            return try await operation(authSession)
        } catch BlueskyAPIError.unauthorized {
            authSession = try await recoverSession(
                currentSession: authSession,
                for: account,
                appPassword: appPassword
            )
            return try await operation(authSession)
        }
    }

    private func cachedSession(
        for account: AppAccount,
        appPassword: String?
    ) async throws -> BlueskySession {
        let sessionKey = account.id.uuidString
        if let cachedSession = cachedSessions[sessionKey] {
            if shouldRefresh(cachedSession.accessJWT) {
                return try await recoverSession(
                    currentSession: cachedSession,
                    for: account,
                    appPassword: appPassword
                )
            }
            return cachedSession
        }

        if let restoredSession = try restoredSession(for: account) {
            cachedSessions[sessionKey] = restoredSession
            if shouldRefresh(restoredSession.accessJWT) {
                return try await recoverSession(
                    currentSession: restoredSession,
                    for: account,
                    appPassword: appPassword
                )
            }
            return restoredSession
        }

        guard let appPassword else {
            throw BlueskyAPIError.missingCredentials
        }

        let newSession = try await authenticate(handle: account.handle, appPassword: appPassword)
        cachedSessions[sessionKey] = newSession
        try await persistSession(newSession, for: account)
        return newSession
    }

    private func recoverSession(
        currentSession: BlueskySession,
        for account: AppAccount,
        appPassword: String?
    ) async throws -> BlueskySession {
        let sessionKey = account.id.uuidString

        if let refreshedSession = try await refreshSession(currentSession) {
            cachedSessions[sessionKey] = refreshedSession
            try await persistSession(refreshedSession, for: account)
            return refreshedSession
        }

        guard let appPassword else {
            throw BlueskyAPIError.unauthorized
        }

        let recreatedSession = try await authenticate(handle: account.handle, appPassword: appPassword)
        cachedSessions[sessionKey] = recreatedSession
        try await persistSession(recreatedSession, for: account)
        return recreatedSession
    }

    private func refreshSession(_ existingSession: BlueskySession) async throws -> BlueskySession? {
        guard let refreshJWT = existingSession.refreshJWT, !refreshJWT.isEmpty else {
            return nil
        }

        do {
            let response: CreateSessionResponse = try await send(
                path: "com.atproto.server.refreshSession",
                method: "POST",
                body: Optional<String>.none,
                accessToken: refreshJWT,
                hostURL: existingSession.pdsURL
            )

            let pdsURL = try await resolvedPDSURL(
                from: response.didDoc,
                did: response.did,
                fallback: existingSession.pdsURL
            )

            return BlueskySession(
                did: response.did,
                handle: response.handle,
                accessJWT: response.accessJWT,
                refreshJWT: response.refreshJWT ?? refreshJWT,
                pdsURL: pdsURL
            )
        } catch BlueskyAPIError.unauthorized {
            return nil
        }
    }

    private func restoredSession(for account: AppAccount) throws -> BlueskySession? {
        guard let value = try keychain.read(service: persistedSessionService, account: account.id.uuidString),
              let data = value.data(using: .utf8) else {
            return nil
        }

        var restored = try JSONDecoder().decode(BlueskySession.self, from: data)
        if restored.pdsURL.absoluteString.isEmpty, let pdsURL = account.pdsURL {
            restored = BlueskySession(
                did: restored.did,
                handle: restored.handle,
                accessJWT: restored.accessJWT,
                refreshJWT: restored.refreshJWT,
                pdsURL: pdsURL
            )
        }
        return restored
    }

    private func authenticationURL(forHandle handle: String) async throws -> URL {
        if handle.lowercased().hasSuffix(".bsky.social") {
            return entrywayURL
        }

        if let did = try? await resolveHandle(handle),
           let pdsURL = try? await resolvePDSURL(forDID: did) {
            return pdsURL
        }

        return entrywayURL
    }

    private func resolveHandle(_ handle: String) async throws -> String {
        let response: ResolveHandleResponse = try await send(
            path: "com.atproto.identity.resolveHandle",
            method: "GET",
            queryItems: [URLQueryItem(name: "handle", value: handle)],
            accessToken: nil,
            hostURL: entrywayURL
        )
        return response.did
    }

    private func resolvePDSURL(forDID did: String) async throws -> URL {
        let didDocument: DIDDocument = try await send(
            path: "com.atproto.identity.resolveDid",
            method: "GET",
            queryItems: [URLQueryItem(name: "did", value: did)],
            accessToken: nil,
            hostURL: entrywayURL
        )
        return try await resolvedPDSURL(from: didDocument, did: did, fallback: nil)
    }

    private func resolvedPDSURL(
        from didDocument: DIDDocument?,
        did: String,
        fallback: URL?
    ) async throws -> URL {
        if let serviceEndpoint = didDocument?.services.first(where: {
            $0.id.contains("#atproto_pds") || $0.type == "AtprotoPersonalDataServer"
        })?.serviceEndpoint {
            return serviceEndpoint
        }

        if let fallback {
            return fallback
        }

        return try await resolvePDSURL(forDID: did)
    }

    private func shouldRefresh(_ jwt: String) -> Bool {
        guard let expiry = jwtExpiryDate(jwt) else {
            return false
        }

        return expiry <= Date().addingTimeInterval(60)
    }

    private func jwtExpiryDate(_ jwt: String) -> Date? {
        let segments = jwt.split(separator: ".")
        guard segments.count >= 2 else { return nil }
        var payload = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = payload.count % 4
        if remainder != 0 {
            payload += String(repeating: "=", count: 4 - remainder)
        }
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return nil
        }
        return Date(timeIntervalSince1970: exp)
    }
}

private struct CreateSessionRequest: Encodable {
    let identifier: String
    let password: String
}

private struct CreateSessionResponse: Decodable {
    let did: String
    let handle: String
    let accessJWT: String
    let refreshJWT: String?
    let didDoc: DIDDocument?

    enum CodingKeys: String, CodingKey {
        case did
        case handle
        case accessJWT = "accessJwt"
        case refreshJWT = "refreshJwt"
        case didDoc
    }
}

private struct ResolveHandleResponse: Decodable {
    let did: String
}

private struct DIDDocument: Codable {
    let services: [DIDService]

    enum CodingKeys: String, CodingKey {
        case services = "service"
    }
}

private struct DIDService: Codable {
    let id: String
    let type: String
    let serviceEndpoint: URL
}

private struct GetListsResponse: Decodable {
    let lists: [ListView]
}

private struct ListsWithMembershipResponse: Decodable {
    let listsWithMembership: [ListWithMembership]
}

private struct StarterPacksWithMembershipResponse: Decodable {
    let starterPacksWithMembership: [StarterPackWithMembership]
}

private struct GetListResponse: Decodable {
    let cursor: String?
    let items: [ListItemView]
}

private struct ListView: Decodable {
    let uri: String
    let name: String
    let description: String?
    let purpose: ListPurpose
    let listItemCount: Int?
}

private struct ListViewBasic: Decodable {
    let uri: String
    let name: String
    let purpose: ListPurpose
    let listItemCount: Int?
}

private struct ListWithMembership: Decodable {
    let list: ListViewBasic
    let listItem: ListItemView?
}

private struct ListItemView: Decodable {
    let uri: String
    let subject: ActorView
}

private struct StarterPackWithMembership: Decodable {
    let starterPack: StarterPackViewBasic
    let listItem: ListItemView?
}

private struct StarterPackViewBasic: Decodable {
    let uri: String
    let name: String?
    let listItemCount: Int?
    let joinedAllTimeCount: Int?
}

private struct ActorView: Decodable {
    let did: String
    let handle: String
    let displayName: String?
    let avatar: String?
}

private struct SearchActorsResponse: Decodable {
    let cursor: String?
    let actors: [ActorView]
}

private struct CreateRecordRequest: Encodable {
    let repo: String
    let collection: String
    let record: ListItemRecord
}

private struct CreateGenericRecordRequest<Record: Encodable>: Encodable {
    let repo: String
    let collection: String
    let record: Record
}

private struct PutRecordRequest: Encodable {
    let repo: String
    let collection: String
    let rkey: String
    let record: ListRecord
}

private struct ListItemRecord: Encodable {
    let createdAt: String
    let list: String
    let subject: String

    enum CodingKeys: String, CodingKey {
        case createdAt
        case list
        case subject
    }
}

private struct ListRecord: Encodable {
    let type: String
    let purpose: String
    let name: String
    let description: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case purpose
        case name
        case description
        case createdAt
    }
}

private struct SubjectRecord: Encodable {
    let type: String
    let subject: String
    let createdAt: String

    init(type: String, subject: String, createdAt: String = ISO8601DateFormatter().string(from: .now)) {
        self.type = type
        self.subject = subject
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case subject
        case createdAt
    }
}

private struct ActorReferenceRequest: Encodable {
    let actor: String
}

private struct CreateRecordResponse: Decodable {
    let uri: String
    let cid: String
}

private struct DeleteRecordRequest: Encodable {
    let repo: String
    let collection: String
    let rkey: String
}

private struct EmptyResponse: Decodable {}

private struct ProfileViewDetailed: Decodable {
    let did: String
    let handle: String
    let displayName: String?
    let description: String?
    let website: String?
    let avatar: String?
    let banner: String?
    let followersCount: Int?
    let followsCount: Int?
    let postsCount: Int?
    let associated: ProfileAssociated?
    let createdAt: String?
    let labels: [ProfileLabel]?
    let viewer: ProfileViewerState?
}

private struct ProfileAssociated: Decodable {
    let lists: Int?
    let starterPacks: Int?
}

private struct ProfileLabel: Decodable {
    let val: String
}

private struct ProfileViewerState: Decodable {
    let muted: Bool?
    let blockedBy: Bool?
    let blocking: String?
    let following: String?
    let followedBy: String?
    let mutedByList: ListViewBasic?
    let blockingByList: ListViewBasic?
}

private struct ATURIComponents {
    let repo: String
    let collection: String
    let rkey: String
}

private func parseATURI(_ uri: String) throws -> ATURIComponents {
    guard uri.hasPrefix("at://") else {
        throw BlueskyAPIError.invalidResponse
    }

    let value = String(uri.dropFirst(5))
    let segments = value.split(separator: "/")
    guard segments.count >= 3 else {
        throw BlueskyAPIError.invalidResponse
    }

    return ATURIComponents(
        repo: String(segments[0]),
        collection: String(segments[1]),
        rkey: String(segments[2])
    )
}

private func parseDate(_ value: String?) -> Date? {
    guard let value else { return nil }
    return ISO8601DateFormatter().date(from: value)
}

private func mapViewerState(_ viewer: ProfileViewerState?) -> BlueskyViewerState? {
    guard let viewer else { return nil }

    return BlueskyViewerState(
        muted: viewer.muted ?? false,
        blockedBy: viewer.blockedBy ?? false,
        isBlocking: viewer.blocking != nil,
        blockingRecordURI: viewer.blocking,
        isFollowing: viewer.following != nil,
        followsYou: viewer.followedBy != nil,
        mutedByListName: viewer.mutedByList?.name,
        blockingByListName: viewer.blockingByList?.name
    )
}

private enum ListPurpose: String, Decodable {
    case curate = "app.bsky.graph.defs#curatelist"
    case mod = "app.bsky.graph.defs#modlist"

    var kind: BlueskyList.Kind {
        switch self {
        case .curate:
            return .regular
        case .mod:
            return .moderation
        }
    }

    var displayTitle: String {
        switch self {
        case .curate:
            return "Curation list"
        case .mod:
            return "Moderation list"
        }
    }
}

private struct APIErrorPayload: Decodable {
    let error: String?
    let message: String?
}
