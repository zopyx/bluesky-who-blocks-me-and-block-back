import Foundation

// MARK: - Session

struct CreateSessionRequest: Encodable {
    let identifier: String
    let password: String
}

struct CreateSessionResponse: Decodable {
    let accessJwt: String
    let refreshJwt: String
    let handle: String
    let did: String
    let email: String?
    let emailConfirmed: Bool?
    let emailAuthFactor: Bool?
    let active: Bool?
    let status: String?
}

// MARK: - Lists

struct GetListsResponse: Decodable {
    let cursor: String?
    let lists: [ATProtoList]
}

struct ATProtoList: Decodable, Identifiable, Sendable {
    var id: String { uri }
    let uri: String
    let cid: String
    let creator: ATProtoCreator
    let name: String
    let purpose: String
    let description: String?
    let descriptionFacets: [ATProtoFacet]?
    let avatar: String?
    let indexedAt: String
    let viewer: ATProtoListViewer?
}

struct ATProtoCreator: Decodable, Sendable {
    let did: String
    let handle: String
    let displayName: String?
    let avatar: String?
    let viewer: ATProtoProfileViewer?
}

struct ATProtoListViewer: Decodable, Sendable {
    let muted: Bool?
}

struct ATProtoProfileViewer: Decodable, Sendable {
    let muted: Bool?
    let blockedBy: Bool?
    let following: String?
}

struct ATProtoFacet: Decodable, Sendable {
    let index: ATProtoByteSlice
    let features: [ATProtoFacetFeature]
}

struct ATProtoByteSlice: Decodable, Sendable {
    let byteStart: Int
    let byteEnd: Int
}

struct ATProtoFacetFeature: Decodable, Sendable {
    let type: String

    enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
}

// MARK: - List Detail

struct GetListResponse: Decodable {
    let cursor: String?
    let list: ATProtoList
    let items: [ATProtoListItem]
}

struct ATProtoListItem: Decodable, Identifiable, Sendable {
    var id: String { uri }
    let uri: String
    let cid: String
    let subject: ATProtoCreator
    let createdAt: String
}

// MARK: - DID Resolution

struct DIDDocument: Decodable {
    let id: String
    let alsoKnownAs: [String]?
    let service: [DIDService]?
}

struct DIDService: Decodable {
    let id: String
    let type: String
    let serviceEndpoint: String
}

// MARK: - Handle Resolution

struct ResolveHandleResponse: Decodable {
    let did: String
}
