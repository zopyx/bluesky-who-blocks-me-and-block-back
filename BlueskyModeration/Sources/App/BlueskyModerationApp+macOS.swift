import SwiftUI

#if os(macOS)
    @main
    struct BlueskyModerationMac: App {
        @StateObject private var deps = AppDependencies()

        var body: some Scene {
            WindowGroup {
                RootView()
                    .environmentObject(deps.accountStore)
                    .environmentObject(deps.listService)
                    .environmentObject(deps.profileService)
                    .environmentObject(deps.workspaceStore)
                    .environmentObject(deps.actionPresetStore)
                    .environmentObject(deps.blueskyClient)
                    .task {
                        await deps.blueskyClient.restoreSessions(for: deps.accountStore.accounts)
                    }
                    .frame(minWidth: 800, minHeight: 600)
            }
            .windowStyle(.titleBar)
            .windowResizability(.contentSize)
        }
    }
#endif
