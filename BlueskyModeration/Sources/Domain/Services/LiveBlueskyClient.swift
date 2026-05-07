import Foundation

struct BlueskySession: Sendable {
    let did: String
    let handle: String
    let accessJWT: String
    let refreshJWT: String?
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
    private let baseURL: URL
    private let session: URLSession

    init(
        baseURL: URL = URL(string: "https://bsky.social")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    func clearCache() {
        session.configuration.urlCache?.removeAllCachedResponses()
        URLCache.shared.removeAllCachedResponses()
    }

    func authenticate(handle: String, appPassword: String) async throws -> BlueskySession {
        let requestBody = CreateSessionRequest(identifier: handle, password: appPassword)
        let response: CreateSessionResponse = try await send(
            path: "com.atproto.server.createSession",
            method: "POST",
            body: requestBody,
            accessToken: nil
        )

        return BlueskySession(
            did: response.did,
            handle: response.handle,
            accessJWT: response.accessJWT,
            refreshJWT: response.refreshJWT
        )
    }

    func fetchLists(for account: AppAccount, appPassword: String) async throws -> [BlueskyList] {
        let authSession = try await authenticate(handle: account.handle, appPassword: appPassword)
        let response: GetListsResponse = try await send(
            path: "app.bsky.graph.getLists",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "actor", value: authSession.did),
                URLQueryItem(name: "limit", value: "100")
            ],
            accessToken: authSession.accessJWT
        )

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

    func fetchListMembers(
        list: BlueskyList,
        account: AppAccount,
        appPassword: String
    ) async throws -> [BlueskyListMember] {
        let authSession = try await authenticate(handle: account.handle, appPassword: appPassword)
        let response: GetListResponse = try await send(
            path: "app.bsky.graph.getList",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "list", value: list.id),
                URLQueryItem(name: "limit", value: "100")
            ],
            accessToken: authSession.accessJWT
        )

        return response.items.map {
            BlueskyListMember(
                recordURI: $0.uri,
                actor: BlueskyActor(
                    did: $0.subject.did,
                    handle: $0.subject.handle,
                    displayName: $0.subject.displayName,
                    avatarURL: URL(string: $0.subject.avatar ?? "")
                )
            )
        }
    }

    func searchActors(
        query: String,
        account: AppAccount,
        appPassword: String
    ) async throws -> [BlueskyActor] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return []
        }

        let authSession = try await authenticate(handle: account.handle, appPassword: appPassword)
        let response: SearchActorsResponse = try await send(
            path: "app.bsky.actor.searchActorsTypeahead",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "q", value: trimmedQuery),
                URLQueryItem(name: "limit", value: "12")
            ],
            accessToken: authSession.accessJWT
        )

        return response.actors.map {
            BlueskyActor(
                did: $0.did,
                handle: $0.handle,
                displayName: $0.displayName,
                avatarURL: URL(string: $0.avatar ?? "")
            )
        }
    }

    func addActor(
        did actorDID: String,
        to list: BlueskyList,
        account: AppAccount,
        appPassword: String
    ) async throws {
        let authSession = try await authenticate(handle: account.handle, appPassword: appPassword)
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
            accessToken: authSession.accessJWT
        )
    }

    func removeMember(
        recordURI: String,
        account: AppAccount,
        appPassword: String
    ) async throws {
        let authSession = try await authenticate(handle: account.handle, appPassword: appPassword)
        let record = try parseATURI(recordURI)
        let body = DeleteRecordRequest(
            repo: authSession.did,
            collection: record.collection,
            rkey: record.rkey
        )

        let _: EmptyResponse = try await send(
            path: "com.atproto.repo.deleteRecord",
            method: "POST",
            body: body,
            accessToken: authSession.accessJWT
        )
    }

    func updateListMetadata(
        list: BlueskyList,
        title: String,
        description: String,
        account: AppAccount,
        appPassword: String
    ) async throws -> BlueskyList {
        let authSession = try await authenticate(handle: account.handle, appPassword: appPassword)
        let record = try parseATURI(list.id)
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

        let _: CreateRecordResponse = try await send(
            path: "com.atproto.repo.putRecord",
            method: "POST",
            body: body,
            accessToken: authSession.accessJWT
        )

        return BlueskyList(
            id: list.id,
            name: title,
            description: description.isEmpty ? list.kind.title : description,
            memberCount: list.memberCount,
            kind: list.kind
        )
    }

    func fetchProfile(
        did actorDID: String,
        account: AppAccount,
        appPassword: String
    ) async throws -> BlueskyProfile {
        let authSession = try await authenticate(handle: account.handle, appPassword: appPassword)
        let response: ProfileViewDetailed = try await send(
            path: "app.bsky.actor.getProfile",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "actor", value: actorDID)
            ],
            accessToken: authSession.accessJWT
        )

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
        let authSession = try await authenticate(handle: account.handle, appPassword: appPassword)
        let actor = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !actor.isEmpty else {
            throw BlueskyAPIError.server("Enter a Bluesky handle or DID.")
        }

        async let profileResponse: ProfileViewDetailed = send(
            path: "app.bsky.actor.getProfile",
            method: "GET",
            queryItems: [URLQueryItem(name: "actor", value: actor)],
            accessToken: authSession.accessJWT
        )
        async let listMembershipResponse: ListsWithMembershipResponse = send(
            path: "app.bsky.graph.getListsWithMembership",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "actor", value: actor),
                URLQueryItem(name: "limit", value: "100")
            ],
            accessToken: authSession.accessJWT
        )
        async let starterPackMembershipResponse: StarterPacksWithMembershipResponse = send(
            path: "app.bsky.graph.getStarterPacksWithMembership",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "actor", value: actor),
                URLQueryItem(name: "limit", value: "100")
            ],
            accessToken: authSession.accessJWT
        )

        let profile = try await profileResponse
        let lists = try await listMembershipResponse
        let starterPacks = try await starterPackMembershipResponse

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
                    isMember: $0.listItem != nil
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
        accessToken: String?
    ) async throws -> Response {
        guard var components = URLComponents(url: baseURL.appendingPathComponent("xrpc/\(path)"), resolvingAgainstBaseURL: false) else {
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
        accessToken: String?
    ) async throws -> Response {
        try await send(
            path: path,
            method: method,
            queryItems: queryItems,
            body: Optional<String>.none,
            accessToken: accessToken
        )
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

    enum CodingKeys: String, CodingKey {
        case did
        case handle
        case accessJWT = "accessJwt"
        case refreshJWT = "refreshJwt"
    }
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
    let actors: [ActorView]
}

private struct CreateRecordRequest: Encodable {
    let repo: String
    let collection: String
    let record: ListItemRecord
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
