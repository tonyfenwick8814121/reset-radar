import XCTest
import Foundation
@testable import ResetRadar

// Independent acceptance probes. Run in a temporary checkout, not against user state.
// They captured the original audit gaps and now remain as remediation regression checks.
final class AcceptanceAuditTests: XCTestCase {
    let now = ISO8601DateFormatter().date(from: "2026-09-09T12:00:00Z")!
    let target = ISO8601DateFormatter().date(from: "2026-09-09T21:00:00Z")!

    func source(_ id: String = "modelyard") -> FeedSource {
        FeedSource(id: id, name: id, url: URL(string: "https://example.test/feed")!, kind: .communityFeed, interval: 300)
    }
    func event(_ body: String, sourceID: String = "modelyard", id: String = "audit") throws -> ResetEvent {
        try XCTUnwrap(AnnouncementClassifier().classify(
            FeedItem(id: id, title: "Codex usage news", body: body, url: URL(string: "https://x.com/a/status/123456"), publishedAt: now),
            source: source(sourceID), fetchedAt: now
        ))
    }
    func temporaryStore() -> (LocalStore, URL) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rr-acceptance-" + UUID().uuidString)
        return (LocalStore(directory: url), url)
    }

    func testA01GrantExpiryMustNotBecomeAutomaticTarget() throws {
        let e = try event("Your banked reset expires on September 9, 2026 at 14:00 PT.")
        XCTAssertEqual(e.kind, .bankedResetGrant)
        XCTAssertNil(e.targetAt, "Expiry must not be the automatic-reset clock")
        XCTAssertEqual(e.expiresAt, target)
    }
    func testA02GrantDistributionTimeMustNotBecomeAutomaticTarget() throws {
        let e = try event("A banked reset will arrive on September 9, 2026 at 14:00 PT.")
        XCTAssertNil(e.targetAt, "Grant availability is not an automatic quota reset")
    }
    func testA03CancellationMustSuppressScheduledReset() throws {
        let e = try event("CANCELLED: Codex reset on September 9, 2026 at 14:00 PT will not happen.")
        XCTAssertEqual(e.state, .cancelled)
    }
    func testA04SpeculativeForecastMustNotGenerateExactCountdown() throws {
        let e = try event("71% probability: Codex reset on September 9, 2026 at 14:00 PT.")
        XCTAssertNotEqual(e.state, .scheduled)
    }
    func testA05CommunityFeedTitleCannotProveCompletion() throws {
        let e = try event("This reset post is a joke. Never gonna give you up. Thanks.", sourceID: "codex-reset")
        XCTAssertNotEqual(e.state, .announcedComplete)
    }
    func testA06QuotedOriginalMustOverrideConflictingSummary() throws {
        let e = try event("A reset on September 9, 2026 at 14:00 PT. Source text: No reset is planned. Source: https://x.com/a/status/123456")
        XCTAssertNotEqual(e.state, .scheduled)
    }
    func testA07ISO8601OffsetTimestampResolves() {
        XCTAssertEqual(TimeResolver().resolve("Codex reset 2026-09-09T14:00:00-07:00"), .exact(target))
    }
    func testA08Invalid14pmMustRemainUnresolved() {
        let result = TimeResolver().resolve("Reset tomorrow at 14pm PT", publishedAt: now, verifiedContextZone: "America/Los_Angeles")
        guard case .unresolved = result else { return XCTFail("14pm was accepted as an exact time: \(result)") }
    }
    func testA09FractionalAtomPublicationMustParse() throws {
        let xml = "<feed xmlns='http://www.w3.org/2005/Atom'><entry><id>a</id><title>Codex reset</title><updated>2026-09-09T06:30:00.000Z</updated><summary>Done</summary></entry></feed>"
        let item = try XCTUnwrap(XMLFeedParser().parse(Data(xml.utf8)).first)
        XCTAssertNotNil(item.publishedAt ?? item.updatedAt)
    }
    func testA10CDATAContentMustSurvive() throws {
        let xml = "<rss><channel><item><guid>a</guid><title>Codex news</title><description><![CDATA[Codex banked reset expires soon]]></description></item></channel></rss>"
        XCTAssertEqual(try XMLFeedParser().parse(Data(xml.utf8)).first?.body, "Codex banked reset expires soon")
    }
    func testA11NestedAtomContentMustPreserveLeadingWords() throws {
        let xml = "<feed><entry><id>a</id><title>Codex</title><content type='xhtml'><div xmlns='http://www.w3.org/1999/xhtml'>Codex reset <b>tomorrow</b> at 2pm PT</div></content></entry></feed>"
        let item = try XCTUnwrap(XMLFeedParser().parse(Data(xml.utf8)).first)
        XCTAssertTrue(item.body.contains("reset tomorrow"), "Body lost text: \(item.body)")
    }
    @MainActor func testA12ExpiredGrantMustNotRemainActiveBecauseFresh() throws {
        var e = try event("Some users receive a banked reset")
        e.expiresAt = now.addingTimeInterval(-1)
        XCTAssertNil(MonitorModel.selectActiveEvent([e], now: now))
    }
    @MainActor func testA13FutureResetTakesPriority() throws {
        let e = try event("Reset on September 9, 2026 at 14:00 PT")
        let grant = try event("Some users receive a banked reset", id: "grant")
        XCTAssertEqual(MonitorModel.selectActiveEvent([grant, e], now: now)?.targetAt, target)
    }
    @MainActor func testA14Automatic24HourDisplayCharacterization() throws {
        let e = try event("Reset on September 9, 2026 at 14:00 PT")
        XCTAssertNotNil(MonitorModel.selectActiveEvent([e], now: target.addingTimeInterval(1)))
        XCTAssertNotNil(MonitorModel.selectActiveEvent([e], now: target.addingTimeInterval(86_400)))
        XCTAssertNil(MonitorModel.selectActiveEvent([e], now: target.addingTimeInterval(86_401)))
        XCTAssertEqual(e.state, .scheduled, "Selection is not an archival state transition")
    }
    @MainActor func testA15UndatedGrant24HourDisplayCharacterization() throws {
        let e = try event("Some users receive a banked reset")
        XCTAssertNotNil(MonitorModel.selectActiveEvent([e], now: now.addingTimeInterval(86_400)))
        XCTAssertNil(MonitorModel.selectActiveEvent([e], now: now.addingTimeInterval(86_401)))
    }
    func testA16ConflictingSourcesMustNotOverwriteConfirmedTime() throws {
        let a = try event("Reset on September 9, 2026 at 14:00 PT")
        let b = try event("Reset on September 9, 2026 at 15:00 PT", sourceID: "codex-reset")
        var events = [a]
        _ = EventReconciler().merge(b, into: &events)
        XCTAssertEqual(events[0].state, .unresolved, "Conflict should require review")
    }
    func testA17AudienceCorrectionsMustPersist() throws {
        let a = try event("Reset on September 9, 2026 at 14:00 PT for all users")
        var b = a
        b.audience = "partial"
        var events = [a]
        _ = EventReconciler().merge(b, into: &events)
        XCTAssertEqual(events[0].audience, "partial")
    }
    func testA18ExpiryCorrectionsMustPersist() throws {
        var a = try event("Some users receive a banked reset")
        a.expiresAt = target
        var b = a
        b.expiresAt = target.addingTimeInterval(7200)
        var events = [a]
        _ = EventReconciler().merge(b, into: &events)
        XCTAssertEqual(events[0].expiresAt, b.expiresAt)
    }
    func testA19SameTextFromTwoSourcesRetainsBothProvenances() throws {
        let a = try event("Some users receive a banked reset")
        let b = try event("Some users receive a banked reset", sourceID: "codex-reset")
        var events = [a]
        _ = EventReconciler().merge(b, into: &events)
        XCTAssertEqual(events[0].evidence.count, 2)
    }
    func testA20OlderPreferencesPreserveLocale() async throws {
        let (store, dir) = temporaryStore()
        try await store.savePreferences(.defaults)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: dir.appendingPathComponent("preferences.json"))) as? [String: Any])
        object["locale"] = "en"
        object.removeValue(forKey: "launchAtLogin")
        try JSONSerialization.data(withJSONObject: object).write(to: dir.appendingPathComponent("preferences.json"))
        let loaded = await store.loadPreferences()
        XCTAssertEqual(loaded.locale, .en)
    }
    func testA21UnsupportedPreferenceSchemaIsNotAccepted() async throws {
        let (store, _) = temporaryStore()
        var prefs = UserPreferences.defaults
        prefs.schemaVersion = 999
        try await store.savePreferences(prefs)
        let loaded = await store.loadPreferences()
        XCTAssertNotEqual(loaded.schemaVersion, 999)
    }
    func testA22RecoveredBackupMustSurviveNextSave() async throws {
        let (store, dir) = temporaryStore()
        var prefs = UserPreferences.defaults
        prefs.locale = .en
        try await store.savePreferences(prefs)
        try await store.savePreferences(prefs)
        let file = dir.appendingPathComponent("preferences.json")
        try Data("broken".utf8).write(to: file)
        let recovered = await store.loadPreferences()
        XCTAssertEqual(recovered.locale, .en)
        try await store.savePreferences(recovered)
        try Data("broken again".utf8).write(to: file)
        let secondRecovery = await store.loadPreferences()
        XCTAssertEqual(secondRecovery.locale, .en)
    }
    @MainActor func testA23UndatedGrantShouldTriggerDiscoveryCallback() async throws {
        AuditURLProtocol.kind = .grant
        let model = mockModel()
        var discoveries = 0
        model.onNewActionableEvent = { _ in discoveries += 1 }
        await model.refresh()
        XCTAssertNotNil(model.activeEvent)
        XCTAssertGreaterThan(discoveries, 0, "A hidden app will never surface this opportunity")
    }
    @MainActor func testA24RetryAfterMustBeHonored() async throws {
        AuditURLProtocol.kind = .rateLimit
        let model = mockModel()
        let began = Date()
        await model.refresh()
        let retry = try XCTUnwrap(model.statuses.first { $0.sourceID == "modelyard" }?.nextCheckAt)
        XCTAssertGreaterThanOrEqual(retry.timeIntervalSince(began), 3500)
    }
    @MainActor func testA25ManualRefreshCannotBypassActiveRateLimit() async throws {
        AuditURLProtocol.kind = .rateLimit
        AuditURLProtocol.requestCount = 0
        let model = mockModel()
        await model.refresh()
        let requests = AuditURLProtocol.requestCount
        await model.refresh(force: true)
        XCTAssertEqual(AuditURLProtocol.requestCount, requests)
    }
    @MainActor func testA26FreshTransportDoesNotAdvanceUnknownUpstream() async {
        AuditURLProtocol.kind = .empty
        let model = mockModel()
        await model.refresh()
        XCTAssertTrue(model.statuses.allSatisfy { $0.lastTransportSuccessAt != nil && $0.latestCoveredPublicationAt == nil })
    }
    @MainActor private func mockModel() -> MonitorModel {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AuditURLProtocol.self]
        return MonitorModel(store: temporaryStore().0, client: FeedClient(session: URLSession(configuration: config)))
    }
}

private final class AuditURLProtocol: URLProtocol {
    enum ResponseKind { case grant, rateLimit, empty }
    static var kind = ResponseKind.empty
    static var requestCount = 0
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requestCount += 1
        let status = Self.kind == .rateLimit ? 429 : 200
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Retry-After": "3600", "Content-Type": "application/rss+xml"])!
        let date = ISO8601DateFormatter().string(from: Date())
        let entries = Self.kind == .grant ? "<item><guid>fresh-grant</guid><title>Codex reset news</title><description>Some users receive a banked reset</description><pubDate>\(date)</pubDate></item>" : ""
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("<rss><channel>\(entries)</channel></rss>".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
