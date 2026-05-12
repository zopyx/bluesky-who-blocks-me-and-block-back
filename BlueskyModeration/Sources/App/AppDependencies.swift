import Foundation

@MainActor
final class AppDependencies: ObservableObject {
    let accountStore: AccountStore
    let listService: BlueskyListService
    let profileService: BlueskyProfileService
    let workspaceStore: ModerationWorkspaceStore
    let actionPresetStore: ActionPresetStore
    let blueskyClient: LiveBlueskyClient
    let localizationManager: LocalizationManager

    init() {
        let requestExecutor = BlueskyRequestExecutor()
        let keychain = KeychainService()
        let sessionService = BlueskySessionService(requestExecutor: requestExecutor, keychain: keychain)

        accountStore = AccountStore(keychain: keychain)
        listService = BlueskyListService(requestExecutor: requestExecutor, sessionService: sessionService)
        profileService = BlueskyProfileService(requestExecutor: requestExecutor, sessionService: sessionService)
        workspaceStore = ModerationWorkspaceStore()
        actionPresetStore = ActionPresetStore()
        blueskyClient = LiveBlueskyClient(
            requestExecutor: requestExecutor,
            sessionService: sessionService
        )
        localizationManager = LocalizationManager.shared
    }
}
