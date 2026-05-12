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
    let avatar: String?
}

struct ListViewBasic: Decodable {
    let uri: String
    let name: String
    let purpose: ListPurpose
    let listItemCount: Int?
    let avatar: String?
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
    let createdAt: String?
    let viewer: ProfileViewerState?
}

struct GetBlocksResponse: Decodable {
    let cursor: String?
    let blocks: [ActorView]
}

struct GetProfilesResponse: Decodable {
    let profiles: [ProfileViewDetailed]
}

struct ClearskyBlocklistResponse: Decodable {
    let data: ClearskyBlocklistData
}

struct ClearskyBlocklistData: Decodable {
    let blocklist: [ClearskyBlocklistEntry]
}

struct ClearskyBlocklistEntry: Decodable {
    let did: String
    let blockedDate: String

    enum CodingKeys: String, CodingKey {
        case did
        case blockedDate = "blocked_date"
    }
}

struct ClearskyBlocklistTotalResponse: Decodable {
    let data: ClearskyBlocklistTotalData
}

struct ClearskyBlocklistTotalData: Decodable {
    let count: Int
}

struct GetFollowersResponse: Decodable {
    let cursor: String?
    let followers: [ActorView]
}

struct GetFollowsResponse: Decodable {
    let cursor: String?
    let follows: [ActorView]
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
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
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

// MARK: - PLC Directory

struct PLCAuditLogEntry: Decodable {
    let did: String
    let operation: PLCOperation
    let cid: String?
    let nullified: Bool?
    let createdAt: String
}

struct PLCOperation: Decodable {
    let type: String?
    let alsoKnownAs: [String]?
    let services: [String: PLCServiceEntry]?
}

struct PLCServiceEntry: Decodable {
    let type: String?
    let endpoint: String?
}

struct HandleChange: Identifiable {
    let id: String
    let handle: String
    let date: Date
    let isCurrent: Bool
}

func parseHandleChanges(from auditLog: [PLCAuditLogEntry], currentHandle: String) -> [HandleChange] {
    let entries = auditLog
        .filter { !($0.nullified ?? false) }
        .compactMap { entry -> (handle: String, date: Date)? in
            guard let alsoKnownAs = entry.operation.alsoKnownAs,
                  let atHandle = alsoKnownAs.first(where: { $0.hasPrefix("at://") }),
                  let date = parseDate(entry.createdAt)
            else {
                return nil
            }
            let handle = String(atHandle.dropFirst(5))
            return (handle, date)
        }
        .sorted { $0.date < $1.date }

    var seen = Set<String>()
    var result: [HandleChange] = []
    for (handle, date) in entries {
        if seen.insert(handle).inserted {
            result.append(HandleChange(
                id: "\(handle)-\(date.timeIntervalSince1970)",
                handle: handle,
                date: date,
                isCurrent: handle == currentHandle
            ))
        }
    }
    return result
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

// MARK: - Feed / Author Feed (for image download)

struct GetAuthorFeedResponse: Decodable {
    let cursor: String?
    let feed: [FeedViewPost]
}

struct FeedViewPost: Decodable {
    let post: PostView
}

struct PostView: Decodable {
    let uri: String
    let embed: EmbedView?
}

struct EmbedView: Decodable {
    let images: [EmbedImageItem]?
}

struct EmbedImageItem: Decodable {
    let fullsize: String
    let alt: String?
}

// MARK: - Rich Feed / Author Feed (for post browser)

struct RichFeedResponse: Decodable {
    let cursor: String?
    let feed: [RichFeedEntry]
}

struct RichFeedEntry: Decodable {
    let post: RichPost
}

struct RichPost: Decodable {
    let uri: String
    let author: RichAuthor?
    let record: RichRecord?
    let embed: RichEmbed?
    let replyCount: Int?
    let repostCount: Int?
    let likeCount: Int?
    let indexedAt: String?

    var safeAuthor: RichAuthor {
        author ?? RichAuthor(did: "", handle: "unknown", displayName: nil, avatar: nil)
    }

    var safeRecord: RichRecord {
        record ?? RichRecord(text: "", createdAt: "")
    }
}

struct RichAuthor: Decodable {
    let did: String?
    let handle: String?
    let displayName: String?
    let avatar: String?
}

struct RichRecord: Decodable {
    let text: String?
    let createdAt: String?
}

struct RichEmbed: Decodable {
    let images: [RichEmbedImage]?
}

struct RichEmbedImage: Decodable {
    let fullsize: String?
    let alt: String?
}

// MARK: - Post Thread

struct GetPostThreadResponse: Decodable {
    let thread: ThreadNode
}

final class ThreadNode: Decodable {
    let post: ThreadPostNode
    let parent: ThreadNode?
    let replies: [ThreadNode]?

    init(post: ThreadPostNode, parent: ThreadNode?, replies: [ThreadNode]?) {
        self.post = post
        self.parent = parent
        self.replies = replies
    }
}

struct ThreadPostNode: Decodable {
    let uri: String?
    let author: RichAuthor?
    let record: RichRecord?
    let replyCount: Int?
    let repostCount: Int?
    let likeCount: Int?
    let indexedAt: String?
}
