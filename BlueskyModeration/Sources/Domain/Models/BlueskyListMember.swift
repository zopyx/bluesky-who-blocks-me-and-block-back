import Foundation

struct BlueskyListMember: Identifiable, Hashable, Sendable {
    let id: String
    let recordURI: String
    let actor: BlueskyActor

    init(recordURI: String, actor: BlueskyActor) {
        self.id = recordURI
        self.recordURI = recordURI
        self.actor = actor
    }
}
