import Foundation

struct AccountSession: Sendable, Equatable {
    let accountId: UUID
    let accessJwt: String
    let did: String
    let handle: String
    let pdsEndpoint: String
}
