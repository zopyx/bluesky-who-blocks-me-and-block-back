import Foundation

struct BlueskyActor: Identifiable, Hashable, Sendable {
    let id: String
    let did: String
    let handle: String
    let displayName: String?
    let avatarURL: URL?

    init(
        id: String? = nil,
        did: String,
        handle: String,
        displayName: String? = nil,
        avatarURL: URL? = nil
    ) {
        self.id = id ?? did
        self.did = did
        self.handle = handle
        self.displayName = displayName
        self.avatarURL = avatarURL
    }

    var title: String {
        if let displayName, !displayName.isEmpty {
            return displayName
        }

        return handle
    }
}
