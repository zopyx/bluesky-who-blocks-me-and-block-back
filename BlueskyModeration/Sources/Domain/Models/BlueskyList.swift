import Foundation

struct BlueskyList: Identifiable, Hashable {
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
    }

    let id: String
    let name: String
    let description: String
    let memberCount: Int?
    let kind: Kind
}
