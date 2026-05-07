import Foundation
import SwiftData
import Testing
@testable import BlueskyModeration

// MARK: - Helpers

private func makeInMemoryContext() throws -> ModelContext {
    let schema = Schema([BlueskyAccount.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    return ModelContext(container)
}

// MARK: - Mock Services

actor MockBlueskyAPIService: BlueskyAPIProtocol {
    private var resolveHandleResult: String?
    private var resolveHandleError: Error?

    private var getPDSResult: String?
    private var getPDSError: Error?

    private var createSessionResult: CreateSessionResponse?
    private var createSessionError: Error?

    func setResolveHandleResult(_ value: String?) { resolveHandleResult = value }
    func setResolveHandleError(_ value: Error?) { resolveHandleError = value }
    func setGetPDSResult(_ value: String?) { getPDSResult = value }
    func setGetPDSError(_ value: Error?) { getPDSError = value }
    func setCreateSessionResult(_ value: CreateSessionResponse?) { createSessionResult = value }
    func setCreateSessionError(_ value: Error?) { createSessionError = value }

    func resolveHandle(_ handle: String) async throws -> String {
        if let error = resolveHandleError { throw error }
        return resolveHandleResult ?? "did:plc:mock"
    }

    func getPDS(did: String) async throws -> String {
        if let error = getPDSError { throw error }
        return getPDSResult ?? "https://mock.pds"
    }

    func createSession(identifier: String, password: String, pds: String?) async throws -> CreateSessionResponse {
        if let error = createSessionError { throw error }
        return createSessionResult ?? CreateSessionResponse(
            accessJwt: "mock-access-jwt",
            refreshJwt: "mock-refresh-jwt",
            handle: identifier,
            did: "did:plc:mock",
            email: nil,
            emailConfirmed: nil,
            emailAuthFactor: nil,
            active: nil,
            status: nil
        )
    }

    func getLists(actor: String, accessJwt: String, pds: String?) async throws -> [ATProtoList] {
        []
    }

    func getList(listUri: String, accessJwt: String, pds: String?) async throws -> GetListResponse {
        fatalError("Unexpected call to getList in AccountViewModel test")
    }
}

actor MockKeychainService: KeychainProtocol {
    private var passwords: [UUID: String] = [:]
    private var tokens: [UUID: String] = [:]

    func saveAppPassword(_ password: String, for accountId: UUID) async throws {
        passwords[accountId] = password
    }

    func getAppPassword(for accountId: UUID) async throws -> String {
        guard let password = passwords[accountId] else {
            throw KeychainError.itemNotFound
        }
        return password
    }

    func deleteAppPassword(for accountId: UUID) async throws {
        passwords.removeValue(forKey: accountId)
    }

    func saveAccessToken(_ token: String, for accountId: UUID) async throws {
        tokens[accountId] = token
    }

    func getAccessToken(for accountId: UUID) async throws -> String {
        guard let token = tokens[accountId] else {
            throw KeychainError.itemNotFound
        }
        return token
    }

    func deleteAccessToken(for accountId: UUID) async throws {
        tokens.removeValue(forKey: accountId)
    }

    func deleteAllCredentials(for accountId: UUID) async throws {
        passwords.removeValue(forKey: accountId)
        tokens.removeValue(forKey: accountId)
    }
}

// MARK: - Tests

@Suite("AccountViewModel: Add Account + Password")
struct AccountViewModelAddAccountTests {

    @Test("Successfully adds a new account with app password")
    func testAddAccountSuccess() async throws {
        let mockAPI = MockBlueskyAPIService()
        let mockKeychain = MockKeychainService()
        let viewModel = AccountViewModel(apiService: mockAPI, keychain: mockKeychain)
        let context = try makeInMemoryContext()
        viewModel.setModelContext(context)

        await viewModel.addAccount(handle: "testuser.bsky.social", appPassword: "my-app-password-123")

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.accounts.count == 1)

        let account = viewModel.accounts.first!
        #expect(account.handle == "testuser.bsky.social")
        #expect(account.did == "did:plc:mock")
        #expect(account.pdsEndpoint == "https://mock.pds")
        #expect(account.isActive == true)

        let savedPassword = try await mockKeychain.getAppPassword(for: account.id)
        #expect(savedPassword == "my-app-password-123")

        let savedToken = try await mockKeychain.getAccessToken(for: account.id)
        #expect(savedToken == "mock-access-jwt")

        #expect(viewModel.activeSession != nil)
        #expect(viewModel.activeSession?.handle == "testuser.bsky.social")
        #expect(viewModel.activeSession?.accessJwt == "mock-access-jwt")
    }

    @Test("Rejects empty handle")
    func testAddAccountEmptyHandle() async throws {
        let mockAPI = MockBlueskyAPIService()
        let mockKeychain = MockKeychainService()
        let viewModel = AccountViewModel(apiService: mockAPI, keychain: mockKeychain)
        let context = try makeInMemoryContext()
        viewModel.setModelContext(context)

        await viewModel.addAccount(handle: "   ", appPassword: "some-password")

        #expect(viewModel.errorMessage == "Handle is required")
        #expect(viewModel.accounts.isEmpty)
    }

    @Test("Rejects duplicate account")
    func testAddAccountDuplicate() async throws {
        let mockAPI = MockBlueskyAPIService()
        let mockKeychain = MockKeychainService()
        let viewModel = AccountViewModel(apiService: mockAPI, keychain: mockKeychain)
        let context = try makeInMemoryContext()
        viewModel.setModelContext(context)

        await viewModel.addAccount(handle: "testuser.bsky.social", appPassword: "password1")
        #expect(viewModel.accounts.count == 1)
        #expect(viewModel.errorMessage == nil)

        await viewModel.addAccount(handle: "testuser.bsky.social", appPassword: "password2")

        #expect(viewModel.errorMessage == "Account already exists")
        #expect(viewModel.accounts.count == 1)
    }

    @Test("Handles authentication failure")
    func testAddAccountAuthFailure() async throws {
        let mockAPI = MockBlueskyAPIService()
        await mockAPI.setCreateSessionError(ATProtoError.authenticationFailed)
        let mockKeychain = MockKeychainService()
        let viewModel = AccountViewModel(apiService: mockAPI, keychain: mockKeychain)
        let context = try makeInMemoryContext()
        viewModel.setModelContext(context)

        await viewModel.addAccount(handle: "testuser.bsky.social", appPassword: "wrong-password")

        #expect(viewModel.errorMessage == ATProtoError.authenticationFailed.localizedDescription)
        #expect(viewModel.accounts.isEmpty)
    }

    @Test("Handles handle resolution failure")
    func testAddAccountResolveHandleFailure() async throws {
        let mockAPI = MockBlueskyAPIService()
        await mockAPI.setResolveHandleError(ATProtoError.invalidHandle)
        let mockKeychain = MockKeychainService()
        let viewModel = AccountViewModel(apiService: mockAPI, keychain: mockKeychain)
        let context = try makeInMemoryContext()
        viewModel.setModelContext(context)

        await viewModel.addAccount(handle: "badhandle", appPassword: "password")

        #expect(viewModel.errorMessage == "Could not resolve handle.")
        #expect(viewModel.accounts.isEmpty)
    }

    @Test("Handles PDS resolution failure")
    func testAddAccountPDSFailure() async throws {
        let mockAPI = MockBlueskyAPIService()
        await mockAPI.setGetPDSError(ATProtoError.pdsNotFound)
        let mockKeychain = MockKeychainService()
        let viewModel = AccountViewModel(apiService: mockAPI, keychain: mockKeychain)
        let context = try makeInMemoryContext()
        viewModel.setModelContext(context)

        await viewModel.addAccount(handle: "testuser.bsky.social", appPassword: "password")

        #expect(viewModel.errorMessage == "Could not resolve PDS endpoint.")
        #expect(viewModel.accounts.isEmpty)
    }
}
