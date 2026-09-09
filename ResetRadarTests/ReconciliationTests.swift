import XCTest
@testable import ResetRadar

final class ReconciliationTests: XCTestCase {
    func testCrossSourceEvidenceDoesNotDuplicateEvent() {
        let now = Date()
        var events: [ResetEvent] = [event(source: "rss", hash: "one", target: now.addingTimeInterval(3600))]
        let incoming = event(source: "atom", hash: "two", target: now.addingTimeInterval(3600))
        let outcome = EventReconciler().merge(incoming, into: &events)
        XCTAssertEqual(outcome, .unchanged)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].evidence.count, 2)
        XCTAssertEqual(events[0].revision, 1)
    }

    func testTimeCorrectionIncrementsRevision() {
        let now = Date()
        var events = [event(source: "rss", hash: "one", target: now.addingTimeInterval(3600))]
        let outcome = EventReconciler().merge(event(source: "rss", hash: "two", target: now.addingTimeInterval(7200)), into: &events)
        XCTAssertEqual(outcome, .revised)
        XCTAssertEqual(events[0].revision, 2)
    }

    @MainActor
    func testGrantWithoutExpiryCannotBecomeActiveEvent() {
        let now = Date()
        var grant = event(source: "rss", hash: "grant", target: now.addingTimeInterval(3600))
        grant.kind = .bankedResetGrant
        grant.targetAt = nil
        grant.expiresAt = nil
        XCTAssertNil(MonitorModel.selectActiveEvent([grant], now: now))

        grant.expiresAt = now.addingTimeInterval(3600)
        XCTAssertEqual(MonitorModel.selectActiveEvent([grant], now: now)?.id, grant.id)
    }

    @MainActor
    func testFreshGrantWithoutExpiryIsVisibleBriefly() {
        let now = Date()
        var grant = event(source: "rss", hash: "grant", target: now.addingTimeInterval(3600))
        grant.kind = .bankedResetGrant
        grant.targetAt = nil
        grant.expiresAt = nil
        grant.evidence = [Evidence(sourceID: "rss", itemID: "fresh", sourceKind: .communityFeed, url: nil, publishedAt: now.addingTimeInterval(-60), fetchedAt: now, excerpt: "", contentHash: "fresh")]
        XCTAssertEqual(MonitorModel.selectActiveEvent([grant], now: now)?.id, grant.id)
    }

    @MainActor
    func testRecentlyDueEventRemainsVisibleAtZero() {
        let now = Date()
        var due = event(source: "rss", hash: "due", target: now.addingTimeInterval(-60))
        due.state = .dueUnconfirmed
        XCTAssertEqual(MonitorModel.selectActiveEvent([due], now: now)?.id, due.id)
        due.targetAt = now.addingTimeInterval(-90_000)
        XCTAssertNil(MonitorModel.selectActiveEvent([due], now: now))
    }

    private func event(source: String, hash: String, target: Date) -> ResetEvent {
        let now = Date(timeIntervalSince1970: 1_000)
        return ResetEvent(id: "same", revision: 1, kind: .automaticReset, state: .scheduled, precision: .exact, title: "Reset", titleEN: "Reset", targetAt: target, windowStart: nil, windowEnd: nil, expiresAt: nil, products: ["codex"], audience: "all", evidence: [Evidence(sourceID: source, itemID: source, sourceKind: .communityFeed, url: nil, publishedAt: now, fetchedAt: now, excerpt: "", contentHash: hash)], firstSeenAt: now, updatedAt: now)
    }
}
