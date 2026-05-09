import Foundation

@MainActor
final class AppDependencies: ObservableObject {
    let accountStore: AccountStore
    let listService: BlueskyListService
    let profileService: BlueskyProfileService
    let workspaceStore: ModerationWorkspaceStore
    let actionPresetStore: ActionPresetStore
    let blueskyClient: LiveBlueskyClient

    init() {
        let requestExecutor = BlueskyRequestExecutor()
        let keychain = KeychainService()
        let sessionService = BlueskySessionService(requestExecutor: requestExecutor, keychain: keychain)

        self.accountStore = AccountStore(keychain: keychain)
        self.listService = BlueskyListService(requestExecutor: requestExecutor, sessionService: sessionService)
        self.profileService = BlueskyProfileService(requestExecutor: requestExecutor, sessionService: sessionService)
        self.workspaceStore = ModerationWorkspaceStore()
        self.actionPresetStore = ActionPresetStore()
        self.blueskyClient = LiveBlueskyClient(
            requestExecutor: requestExecutor,
            sessionService: sessionService
        )
    }
}
