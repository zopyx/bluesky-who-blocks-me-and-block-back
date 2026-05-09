import SwiftUI

@main
struct BlueskyModerationApp: App {
    @StateObject private var deps = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(deps.accountStore)
                .environmentObject(deps.listService)
                .environmentObject(deps.profileService)
                .environmentObject(deps.workspaceStore)
                .environmentObject(deps.actionPresetStore)
                .environmentObject(deps.profileNotesStore)
                .environmentObject(deps.blueskyClient)
                .task {
                    await deps.blueskyClient.restoreSessions(for: deps.accountStore.accounts)
                }
        }
    }
}
