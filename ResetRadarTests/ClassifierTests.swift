import XCTest
@testable import ResetRadar

final class ClassifierTests: XCTestCase {
    private let classifier = AnnouncementClassifier()
    private let fetched = ISO8601DateFormatter().date(from: "2026-09-09T08:00:00Z")!

    func testBankedResetIsNotAutomaticReset() throws {
        let item = FeedItem(id: "1", title: "Codex usage reset", body: "Some Plus users get a banked reset. Lands by end of day. Source: https://x.com/thsottiaux/status/12345", url: nil, publishedAt: fetched)
        let event = try XCTUnwrap(classifier.classify(item, source: source("modelyard"), fetchedAt: fetched))
        XCTAssertEqual(event.kind, .bankedResetGrant)
        XCTAssertNil(event.targetAt)
        XCTAssertEqual(event.audience, "partial")
        XCTAssertEqual(event.id, "status-12345")
        XCTAssertEqual(event.bestEvidence?.url?.host, "x.com")
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
