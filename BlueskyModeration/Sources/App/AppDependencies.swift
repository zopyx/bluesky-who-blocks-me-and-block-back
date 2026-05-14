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
    let mutedWordsStore: MutedWordsStore
    let analyticsStore: AnalyticsStore

    init() {
        if CommandLine.arguments.contains("--uitesting") {
            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
            UserDefaults.standard.set("en", forKey: "selectedLanguage")
            accountStore = AccountStore(preview: true)
            listService = BlueskyListService(requestExecutor: BlueskyRequestExecutor(), sessionService: BlueskySessionService(requestExecutor: BlueskyRequestExecutor(), keychain: KeychainService()))
            profileService = BlueskyProfileService(requestExecutor: BlueskyRequestExecutor(), sessionService: BlueskySessionService(requestExecutor: BlueskyRequestExecutor(), keychain: KeychainService()))
            workspaceStore = ModerationWorkspaceStore()
            actionPresetStore = ActionPresetStore()
            blueskyClient = PreviewBlueskyClient()
            localizationManager = LocalizationManager.shared
            mutedWordsStore = MutedWordsStore()
            analyticsStore = AnalyticsStore()
        } else {
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
            mutedWordsStore = MutedWordsStore()
            analyticsStore = AnalyticsStore()
        }
    }
}
