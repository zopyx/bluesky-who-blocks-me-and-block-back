import XCTest
@testable import BlueskyModeration

@MainActor
final class LiveBlueskyClientTests: XCTestCase {
    private var client: LiveBlueskyClient!
    private var sessionService: MockSessionService!
    private var requestExecutor: MockRequestExecutor!

    override func setUp() {
        super.setUp()
        sessionService = MockSessionService()
        requestExecutor = MockRequestExecutor()
        client = LiveBlueskyClient(
            requestExecutor: requestExecutor,
            sessionService: sessionService
        )
    }

    func testFetchPLCAuditLog() async throws {
        let json = """
        [{"did": "did:plc:test", "operation": {"type": "plc_operation", "alsoKnownAs": ["at://handle.bsky.social"]}, "cid": "cid1", "nullified": false, "createdAt": "2024-01-01T00:00:00Z"}]
        """.data(using: .utf8)!
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }
        let auditedClient = LiveBlueskyClient(
            baseURL: URL(string: "https://bsky.social")!,
            session: URLSession(configuration: config)
        )

        let entries = try await auditedClient.fetchPLCAuditLog(did: "did:plc:test")
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].did, "did:plc:test")
        MockURLProtocol.requestHandler = nil
    }

    func testClearCache() {
        client.clearCache()
    }

    func testAuthenticateDelegates() async throws {
        let session = makeSession()
        sessionService.sessionToReturn = session
        let result = try await client.authenticate(handle: "test.bsky.social", appPassword: "pass")
        XCTAssertEqual(result.did, session.did)
    }

    func testPersistSessionDelegates() async throws {
        let session = makeSession()
        let account = makeAccount()
        try await client.persistSession(session, for: account)
        XCTAssertEqual(sessionService.persistedSessions[account.id.uuidString]?.did, session.did)
    }

    func testDeletePersistedSessionDelegates() throws {
        let account = makeAccount()
        try client.deletePersistedSession(for: account)
    }

    func testRestoreSessionsDelegates() async {
        await client.restoreSessions(for: [makeAccount()])
    }

    func testFetchBlocks() async throws {
        sessionService.onAuthenticatedRequest = { _, _ in
            let json = """
            {"blocks": [{"did": "did:plc:b1", "handle": "blocked.bsky.social"}]}
            """.data(using: .utf8)!
            return try JSONDecoder().decode(GetBlocksResponse.self, from: json)
        }

        let blocked = try await client.fetchBlockedActors(account: makeAccount(), appPassword: "pass")
        XCTAssertEqual(blocked.count, 1)
        XCTAssertEqual(blocked[0].handle, "blocked.bsky.social")
    }

    func testFetchBlocksEmpty() async throws {
        sessionService.onAuthenticatedRequest = { _, _ in
            let json = """
            {"blocks": []}
            """.data(using: .utf8)!
            return try JSONDecoder().decode(GetBlocksResponse.self, from: json)
        }

        let blocked = try await client.fetchBlockedActors(account: makeAccount(), appPassword: "pass")
        XCTAssertTrue(blocked.isEmpty)
    }
}
