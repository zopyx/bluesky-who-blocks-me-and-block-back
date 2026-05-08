import XCTest
@testable import BlueskyModeration

@MainActor
final class ModerationWorkspaceStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "ModerationWorkspaceStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() async throws {
        if let suiteName {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults = nil
        suiteName = nil
        try await super.tearDown()
    }

    func testDuplicateSnapshotCaptureDoesNotAppendHistory() {
        let store = ModerationWorkspaceStore(defaults: defaults)
        let list = BlueskyList(
            id: "at://list/1",
            name: "Safety",
            description: "Test list",
            memberCount: nil,
            kind: .moderation
        )
        let members = [
            BlueskyListMember(
                recordURI: "at://item/1",
                actor: BlueskyActor(did: "did:plc:alice", handle: "alice.bsky.social")
            )
        ]

        let firstSummary = store.captureSnapshot(for: list, members: members)
        let secondSummary = store.captureSnapshot(for: list, members: members)

        XCTAssertEqual(store.snapshotHistory(for: list.id).count, 1)
        XCTAssertEqual(secondSummary.snapshotID, firstSummary.snapshotID)
        XCTAssertEqual(secondSummary.currentCaptureDate, firstSummary.currentCaptureDate)
        XCTAssertFalse(secondSummary.hasChanges)
    }

    func testSnapshotHistoryTrimsToRetentionLimit() {
        let store = ModerationWorkspaceStore(defaults: defaults)
        let list = BlueskyList(
            id: "at://list/retention",
            name: "Retention",
            description: "Retention list",
            memberCount: nil,
            kind: .moderation
        )

        for index in 0..<13 {
            let members = (0...index).map { memberIndex in
                BlueskyListMember(
                    recordURI: "at://item/\(index)-\(memberIndex)",
                    actor: BlueskyActor(
                        did: "did:plc:\(index)-\(memberIndex)",
                        handle: "user\(index)-\(memberIndex).bsky.social"
                    )
                )
            }
            _ = store.captureSnapshot(for: list, members: members)
        }

        let history = store.snapshotHistory(for: list.id)
        XCTAssertEqual(history.count, 12)
        XCTAssertEqual(history.first?.members.count, 13)
        XCTAssertEqual(history.last?.members.count, 2)
    }

    func testOperationLogKeepsNewestEntriesFirst() {
        let store = ModerationWorkspaceStore(defaults: defaults)

        for index in 0..<26 {
            store.recordOperation(
                ModerationOperationLogEntry(
                    title: "Operation \(index)",
                    summary: "Summary \(index)",
                    succeededHandles: ["ok\(index)"],
                    failedHandles: []
                )
            )
        }

        XCTAssertEqual(store.operationLog.count, 25)
        XCTAssertEqual(store.operationLog.first?.title, "Operation 25")
        XCTAssertEqual(store.operationLog.last?.title, "Operation 1")
    }
}
