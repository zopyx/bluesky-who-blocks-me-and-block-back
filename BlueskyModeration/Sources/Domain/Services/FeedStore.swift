import Foundation

@MainActor
final class FeedStore: ObservableObject {
    @Published var customFeedURI: String? {
        didSet {
            UserDefaults.standard.set(customFeedURI, forKey: "customFeedURI")
        }
    }

    @Published var customFeedName: String {
        didSet {
            UserDefaults.standard.set(customFeedName, forKey: "customFeedName")
        }
    }

    var isUsingCustomFeed: Bool {
        guard let uri = customFeedURI, !uri.isEmpty else { return false }
        return true
    }

    init() {
        customFeedURI = UserDefaults.standard.string(forKey: "customFeedURI")
        customFeedName = UserDefaults.standard.string(forKey: "customFeedName") ?? loc("timeline.following")
    }

    func setFeed(uri: String?, name: String) {
        customFeedURI = uri
        customFeedName = name
    }

    func resetToFollowing() {
        customFeedURI = nil
        customFeedName = loc("timeline.following")
    }
}
