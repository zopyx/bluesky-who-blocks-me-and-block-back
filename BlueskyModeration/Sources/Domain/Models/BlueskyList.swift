import Foundation

struct BlueskyList: Identifiable, Hashable, Sendable {
    enum Kind: String, CaseIterable, Hashable {
        case moderation
        case regular

        var title: String {
            switch self {
            case .moderation:
                "Moderation Lists"
            case .regular:
                "Lists"
            }
        }

        var symbolName: String {
            switch self {
            case .moderation:
                "shield.lefthalf.filled"
            case .regular:
                "person.3"
            }
        }

        var purposeIdentifier: String {
            switch self {
            case .moderation:
                "app.bsky.graph.defs#modlist"
            case .regular:
                "app.bsky.graph.defs#curatelist"
            }
        }
    }

    let id: String
    var name: String
    var description: String
    let memberCount: Int?
    let kind: Kind
}
