import Foundation

struct AppAccount: Identifiable, Codable, Hashable {
    let id: UUID
    var handle: String
    var displayName: String
    var did: String?
    var avatarURL: URL?
    var pdsURL: URL?
    var entrywayURL: URL?
    var createdAt: Date
    var lastUsedAt: Date

    init(
        id: UUID = UUID(),
        handle: String,
        displayName: String? = nil,
        did: String? = nil,
        avatarURL: URL? = nil,
        pdsURL: URL? = nil,
        entrywayURL: URL? = nil,
        createdAt: Date = .now,
        lastUsedAt: Date = .now
    ) {
        self.id = id
        self.handle = handle
        self.displayName = displayName ?? handle
        self.did = did
        self.avatarURL = avatarURL
        self.pdsURL = pdsURL
        self.entrywayURL = entrywayURL
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
}
