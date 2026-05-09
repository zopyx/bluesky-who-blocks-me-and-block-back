import XCTest
@testable import BlueskyModeration

final class URLBlueskyTests: XCTestCase {
    func testBskySocialURL() {
        XCTAssertEqual(URL.bskySocial.absoluteString, "https://bsky.social")
    }
}
