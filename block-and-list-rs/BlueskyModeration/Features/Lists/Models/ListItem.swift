import Foundation

struct ListItem: Identifiable, Sendable, Equatable {
    let id: String
    let uri: String
    let did: String
    let handle: String
    let displayName: String?
    let avatar: String?
    let createdAt: Date?
}

extension ListItem {
    init(from proto: ATProtoListItem) {
        self.id = proto.uri
        self.uri = proto.uri
        self.did = proto.subject.did
        self.handle = proto.subject.handle
        self.displayName = proto.subject.displayName
        self.avatar = proto.subject.avatar

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.createdAt = formatter.date(from: proto.createdAt) ?? ISO8601DateFormatter().date(from: proto.createdAt)
    }
}
