import SwiftUI

@main
struct BlueskyModerationApp: App {
    @StateObject private var accountStore = AccountStore()
    @StateObject private var blueskyClient = LiveBlueskyClient()
    @StateObject private var workspaceStore = ModerationWorkspaceStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(accountStore)
                .environmentObject(blueskyClient)
                .environmentObject(workspaceStore)
                .task {
                    await blueskyClient.restoreSessions(for: accountStore.accounts)
                }
        }
    }
}
