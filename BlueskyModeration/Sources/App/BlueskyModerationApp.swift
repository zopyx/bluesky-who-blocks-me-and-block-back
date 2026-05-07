import SwiftUI

@main
struct BlueskyModerationApp: App {
    @StateObject private var accountStore = AccountStore()
    @StateObject private var blueskyClient = LiveBlueskyClient()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(accountStore)
                .environmentObject(blueskyClient)
        }
    }
}
