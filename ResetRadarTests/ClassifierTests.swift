import XCTest
@testable import ResetRadar

final class ClassifierTests: XCTestCase {
    private let classifier = AnnouncementClassifier()
    private let fetched = ISO8601DateFormatter().date(from: "2026-09-09T08:00:00Z")!

    func testBankedResetIsNotAutomaticReset() throws {
        let item = FeedItem(id: "1", title: "Codex usage reset", body: "Some Plus users get a banked reset. Lands by end of day. Source: https://x.com/thsottiaux/status/12345", url: nil, publishedAt: fetched)
        let event = try XCTUnwrap(classifier.classify(item, source: source("modelyard"), fetchedAt: fetched))
        XCTAssertEqual(event.kind, .bankedResetGrant)
        XCTAssertEqual(event.timeMeaning, .grantAvailability)
        XCTAssertNil(event.targetAt)
        XCTAssertEqual(event.audience, "partial")
        XCTAssertEqual(event.id, "status-12345")
        XCTAssertEqual(event.bestEvidence?.url?.host, "x.com")
    }

    func testGrantExpiryUsesExpiresAtInsteadOfAutomaticTarget() throws {
        let item = FeedItem(id: "expiry", title: "Codex usage reset", body: "Your banked reset expires on September 9, 2026 at 14:00 PT.", url: nil, publishedAt: fetched)
        let event = try XCTUnwrap(classifier.classify(item, source: source("modelyard"), fetchedAt: fetched))
        XCTAssertEqual(event.kind, .bankedResetGrant)
        XCTAssertEqual(event.timeMeaning, .grantExpiry)
        XCTAssertNil(event.targetAt)
        XCTAssertEqual(event.expiresAt, ISO8601DateFormatter().date(from: "2026-09-09T21:00:00Z"))
        XCTAssertEqual(event.state, .available)
    }

    func testGrantAvailabilityDateDoesNotBecomeCountdown() throws {
        let item = FeedItem(id: "arrival", title: "Codex usage reset", body: "A banked reset will arrive on September 9, 2026 at 14:00 PT.", url: nil, publishedAt: fetched)
        let event = try XCTUnwrap(classifier.classify(item, source: source("modelyard"), fetchedAt: fetched))
        XCTAssertEqual(event.timeMeaning, .grantAvailability)
        XCTAssertNil(event.targetAt)
        XCTAssertNil(event.expiresAt)
    }

    func testCancelledAndSpeculativeAnnouncementsDoNotSchedule() throws {
        for body in [
            "CANCELLED: Codex reset on September 9, 2026 at 14:00 PT will not happen.",
            "71% probability: Codex reset on September 9, 2026 at 14:00 PT.",
            "A reset on September 9, 2026 at 14:00 PT. Source text: No reset is planned."
        ] {
            let event = try XCTUnwrap(classifier.classify(FeedItem(id: body, title: "Codex usage news", body: body, url: nil, publishedAt: fetched), source: source("modelyard"), fetchedAt: fetched))
            XCTAssertNil(event.targetAt)
            XCTAssertTrue(event.state == .cancelled || event.state == .unresolved)
        }
    }

    func testFeedIdentityAloneDoesNotProveCompletion() throws {
        let item = FeedItem(id: "joke", title: "Codex reset news", body: "This reset post is a joke. Never gonna give you up. Thanks.", url: nil, publishedAt: fetched)
        let event = try XCTUnwrap(classifier.classify(item, source: source("codex-reset"), fetchedAt: fetched))
        XCTAssertNotEqual(event.state, .announcedComplete)
    }

    func testCompletedFeedEntryDoesNotBecomeFutureLead() throws {
        let item = FeedItem(id: "2", title: "Official Codex reset announcement", body: "Usage limits reset for all paid ChatGPT users.", url: URL(string: "https://x.com/a/status/9"), publishedAt: fetched)
        let event = try XCTUnwrap(classifier.classify(item, source: source("codex-reset"), fetchedAt: fetched))
        XCTAssertEqual(event.state, .announcedComplete)
        XCTAssertEqual(event.kind, .automaticReset)
    }

    func testUnrelatedStatusIncidentIsIgnored() {
        let item = FeedItem(id: "3", title: "Login incident resolved", body: "ChatGPT service restored", url: nil, publishedAt: fetched)
        XCTAssertNil(classifier.classify(item, source: source("openai-status"), fetchedAt: fetched))
    }

    private func source(_ id: String) -> FeedSource {
        FeedSource(id: id, name: id, url: URL(string: "https://example.com/feed")!, kind: .communityFeed, interval: 300)
    }
}
