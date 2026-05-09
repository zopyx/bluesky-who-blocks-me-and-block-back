import XCTest
@testable import BlueskyModeration

@MainActor
final class AccountStoreTests: XCTestCase {
    func testAddAccountPersistsAppPassword() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let keychain = MockKeychainService()
        let store = AccountStore(defaults: defaults, keychain: keychain)
        let client = MockAuthenticatingClient()

        let didAdd = await store.addAccount(
            handle: "moderator.bsky.social",
            appPassword: "abcd-efgh-ijkl-mnop",
            client: client
        )

        XCTAssertTrue(didAdd)
        XCTAssertEqual(store.accounts.count, 1)

        guard let account = store.activeAccount else {
            return XCTFail("Expected active account")
        }

        XCTAssertEqual(
            keychain.savedValues["com.ajung.BlueskyModeration.password:\(account.id.uuidString)"],
            "abcd-efgh-ijkl-mnop"
        )
        XCTAssertEqual(store.appPassword(for: account), "abcd-efgh-ijkl-mnop")
    }

    func testListsViewModelLoadsWithoutAppPasswordWhenClientCanServeSession() async {
        let viewModel = ListsViewModel()
        let client = PreviewBlueskyClient()
        let account = AppAccount(handle: "moderator.bsky.social")

        await viewModel.load(
            for: account,
            appPassword: nil,
            using: client
        )

        XCTAssertFalse(viewModel.listsByKind.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }
}

private final class MockKeychainService: KeychainServicing {
    var savedValues: [String: String] = [:]

    func save(_ value: String, service: String, account: String) throws {
        savedValues["\(service):\(account)"] = value
    }

    func read(service: String, account: String) throws -> String? {
        savedValues["\(service):\(account)"]
    }

    func delete(service: String, account: String) throws {
        savedValues.removeValue(forKey: "\(service):\(account)")
    }
}

@MainActor
private final class MockAuthenticatingClient: BlueskyAuthenticating {
    func authenticate(handle: String, appPassword: String, entrywayURL: URL? = nil) async throws -> BlueskySession {
        BlueskySession(
            did: "did:plc:test",
            handle: handle,
            accessJWT: "access",
            refreshJWT: "refresh",
            pdsURL: URL(string: "https://bsky.social")!
        )
    }

    func persistSession(_ session: BlueskySession, for account: AppAccount) async throws {}

    func deletePersistedSession(for account: AppAccount) throws {}
}
