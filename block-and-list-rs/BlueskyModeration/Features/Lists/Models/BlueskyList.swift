import Foundation

struct BlueskyList: Identifiable, Sendable, Equatable, Hashable {
    var id: String { uri }
    let uri: String
    let cid: String
    let name: String
    let description: String?
    let purpose: ListPurpose
    let creatorHandle: String
    let creatorDid: String
    let indexedAt: Date?

    enum ListPurpose: String, Sendable, Equatable {
        case curation = "app.bsky.graph.defs#curatelist"
        case moderation = "app.bsky.graph.defs#modlist"
    }

    var displayPurpose: String {
        switch purpose {
        case .curation:
            return "Curation"
        case .moderation:
            return "Moderation"
        }
    }

    var iconName: String {
        switch purpose {
        case .curation:
            return "list.star"
        case .moderation:
            return "shield.lefthalf.filled"
        }
    }

    var iconColor: String {
        switch purpose {
        case .curation:
            return "blue"
        case .moderation:
            return "orange"
        }
    }
}

extension BlueskyList {
    init(from proto: ATProtoList) {
        self.uri = proto.uri
        self.cid = proto.cid
        self.name = proto.name
        self.description = proto.description
        self.purpose = ListPurpose(rawValue: proto.purpose) ?? .curation
        self.creatorHandle = proto.creator.handle
        self.creatorDid = proto.creator.did

        let indexedAt = proto.indexedAt
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.indexedAt = formatter.date(from: indexedAt) ?? ISO8601DateFormatter().date(from: indexedAt)
    }
}
