import Foundation

struct GetListsResponse: Decodable {
    let lists: [ListView]
}

struct ListsWithMembershipResponse: Decodable {
    let listsWithMembership: [ListWithMembership]
}

struct StarterPacksWithMembershipResponse: Decodable {
    let starterPacksWithMembership: [StarterPackWithMembership]
}

struct GetListResponse: Decodable {
    let cursor: String?
    let items: [ListItemView]
}

struct ListView: Decodable {
    let uri: String
    let name: String
    let description: String?
    let purpose: ListPurpose
    let listItemCount: Int?
}

struct ListViewBasic: Decodable {
    let uri: String
    let name: String
    let purpose: ListPurpose
    let listItemCount: Int?
}

struct ListWithMembership: Decodable {
    let list: ListViewBasic
    let listItem: ListItemView?
}

struct ListItemView: Decodable {
    let uri: String
    let subject: ActorView
}

struct StarterPackWithMembership: Decodable {
    let starterPack: StarterPackViewBasic
    let listItem: ListItemView?
}

struct StarterPackViewBasic: Decodable {
    let uri: String
    let name: String?
    let listItemCount: Int?
    let joinedAllTimeCount: Int?
}

struct ActorView: Decodable {
    let did: String
    let handle: String
    let displayName: String?
    let avatar: String?
}

struct SearchActorsResponse: Decodable {
    let cursor: String?
    let actors: [ActorView]
}

struct CreateRecordRequest: Encodable {
    let repo: String
    let collection: String
    let record: ListItemRecord
}

struct CreateGenericRecordRequest<Record: Encodable>: Encodable {
    let repo: String
    let collection: String
    let record: Record
}

struct PutRecordRequest: Encodable {
    let repo: String
    let collection: String
    let rkey: String
    let record: ListRecord
}

struct ListItemRecord: Encodable {
    let createdAt: String
    let list: String
    let subject: String

    enum CodingKeys: String, CodingKey {
        case createdAt
        case list
        case subject
    }
}

struct ListRecord: Encodable {
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

struct SubjectRecord: Encodable {
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

struct ActorReferenceRequest: Encodable {
    let actor: String
}

struct CreateRecordResponse: Decodable {
    let uri: String
    let cid: String
}

struct DeleteRecordRequest: Encodable {
    let repo: String
    let collection: String
    let rkey: String
}

struct EmptyResponse: Decodable {}

struct ProfileViewDetailed: Decodable {
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

struct ProfileAssociated: Decodable {
    let lists: Int?
    let starterPacks: Int?
}

struct ProfileLabel: Decodable {
    let val: String
}

struct ProfileViewerState: Decodable {
    let muted: Bool?
    let blockedBy: Bool?
    let blocking: String?
    let following: String?
    let followedBy: String?
    let mutedByList: ListViewBasic?
    let blockingByList: ListViewBasic?
}

struct ATURIComponents {
    let repo: String
    let collection: String
    let rkey: String
}

func parseATURI(_ uri: String) throws -> ATURIComponents {
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

func parseDate(_ value: String?) -> Date? {
    guard let value else { return nil }
    return ISO8601DateFormatter().date(from: value)
}

func mapViewerState(_ viewer: ProfileViewerState?) -> BlueskyViewerState? {
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

enum ListPurpose: String, Decodable {
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
