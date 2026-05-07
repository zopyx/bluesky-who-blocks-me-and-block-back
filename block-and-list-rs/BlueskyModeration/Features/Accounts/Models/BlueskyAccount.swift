import Foundation
import SwiftData

@Model
class BlueskyAccount {
    @Attribute(.unique) var id: UUID
    var handle: String
    var did: String?
    var pdsEndpoint: String?
    var createdAt: Date
    var lastUsedAt: Date?
    var isActive: Bool

    init(
        id: UUID = UUID(),
        handle: String,
        did: String? = nil,
        pdsEndpoint: String? = nil,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil,
        isActive: Bool = false
    ) {
        self.id = id
        self.handle = handle
        self.did = did
        self.pdsEndpoint = pdsEndpoint
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.isActive = isActive
    }
}
