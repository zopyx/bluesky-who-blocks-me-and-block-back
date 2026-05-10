import SwiftUI

@main
struct BlueskyModerationApp: App {
    @StateObject private var deps = AppDependencies()
    @StateObject private var appLockManager = AppLockManager.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                if appLockManager.isLocked {
                    LockScreenView()
                        .environmentObject(appLockManager)
                        .transition(.opacity)
                } else {
                    RootView()
                        .environmentObject(deps.accountStore)
                        .environmentObject(deps.workspaceStore)
                        .environmentObject(deps.blueskyClient)
                        .environmentObject(deps.localizationManager)
                        .environmentObject(appLockManager)
                }
            }
            .animation(UIAccessibility.isReduceMotionEnabled ? nil : .default, value: appLockManager.isLocked)
            .task {
                await deps.blueskyClient.restoreSessions(for: deps.accountStore.accounts)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                appLockManager.appDidEnterBackground()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                appLockManager.appDidBecomeActive()
            }
        }
    }
}
