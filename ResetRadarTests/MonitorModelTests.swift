import XCTest
import Foundation
@testable import ResetRadar

@MainActor
final class MonitorModelTests: XCTestCase {
    func testFreshUndatedGrantTriggersDiscovery() async {
        MonitorURLProtocol.mode = .grant
        let scheduler = RecordingScheduler()
        let model = makeModel(scheduler: scheduler)
        var discoveries = 0
        model.onNewActionableEvent = { _ in discoveries += 1 }

        await model.refresh()

        XCTAssertEqual(discoveries, 1)
        XCTAssertEqual(model.activeEvent?.kind, .bankedResetGrant)
    }

    func testRetryAfterAndManualRefreshRespectCooldown() async throws {
        MonitorURLProtocol.mode = .rateLimit
        MonitorURLProtocol.requestCount = 0
        let model = makeModel()
        let began = Date()

        await model.refresh()
        let firstCount = MonitorURLProtocol.requestCount
        let retry = try XCTUnwrap(model.statuses.first { $0.sourceID == "modelyard" }?.nextCheckAt)
        XCTAssertGreaterThanOrEqual(retry.timeIntervalSince(began), 3_500)

        await model.refresh(force: true)
        XCTAssertEqual(MonitorURLProtocol.requestCount, firstCount)
    }

    func testOrdinaryFailuresUseOneMinuteFirstRetry() async throws {
        MonitorURLProtocol.mode = .serverError
        let model = makeModel()
        let began = Date()
        await model.refresh()
        let retry = try XCTUnwrap(model.statuses.first?.nextCheckAt?.timeIntervalSince(began))
        XCTAssertGreaterThanOrEqual(retry, 55)
        XCTAssertLessThan(retry, 90)
    }

    func testStartReconcilesRemindersForPersistedFutureEvent() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = LocalStore(directory: directory)
        let now = Date()
        let event = ResetEvent(id: "persisted", revision: 2, kind: .automaticReset, timeMeaning: .automaticReset, state: .scheduled, precision: .exact, title: "Reset", titleEN: "Reset", targetAt: now.addingTimeInterval(3600), windowStart: nil, windowEnd: nil, expiresAt: nil, products: ["codex"], audience: "all", evidence: [], firstSeenAt: now, updatedAt: now)
        try await store.saveEvents([event])
        try await store.saveStatuses(FeedSource.defaults.map { source in
            SourceStatus(sourceID: source.id, enabled: true, lastAttemptAt: now, lastTransportSuccessAt: now, latestCoveredPublicationAt: nil, nextCheckAt: now.addingTimeInterval(3600), result: .success, message: nil, consecutiveFailures: 0, etag: nil, lastModified: nil)
        })
        let scheduler = RecordingScheduler()
        let model = MonitorModel(store: store, client: makeClient(), scheduler: scheduler)

        await model.start().value

        let snapshots = await scheduler.snapshots
        XCTAssertTrue(snapshots.contains { $0.contains("persisted") })
        model.stop()
        try? FileManager.default.removeItem(at: directory)
    }

    func testManualGrantCanBeMarkedUsedAndReturnsToIdle() {
        let model = makeModel()
        model.addManualEvent(ManualEntryDraft(text: "https://example.com/reset", kind: .bankedResetGrant, date: Date().addingTimeInterval(3600), product: "codex", audience: "partial"))
        let id = model.activeEvent?.id
        XCTAssertEqual(model.activeEvent?.timeMeaning, .grantExpiry)
        XCTAssertNotNil(model.activeEvent?.expiresAt)

        model.markEvent(id!, as: .used)

        XCTAssertNil(model.activeEvent)
        XCTAssertEqual(model.events.first { $0.id == id }?.state, .used)
    }

    private func makeModel(scheduler: RecordingScheduler = RecordingScheduler()) -> MonitorModel {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return MonitorModel(store: LocalStore(directory: directory), client: makeClient(), scheduler: scheduler)
    }

    private func makeClient() -> FeedClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MonitorURLProtocol.self]
        return FeedClient(session: URLSession(configuration: configuration))
    }
}

actor RecordingScheduler: ReminderScheduling {
    private(set) var snapshots: [[String]] = []
    func reconcile(events: [ResetEvent], preferences: UserPreferences, now: Date) async {
        snapshots.append(events.map(\.id))
    }
    func cancelAll() async {}
}

private final class MonitorURLProtocol: URLProtocol {
    enum Mode { case empty, grant, rateLimit, serverError }
    static var mode: Mode = .empty
    static var requestCount = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requestCount += 1
        let status = Self.mode == .rateLimit ? 429 : (Self.mode == .serverError ? 500 : 200)
        let headers = ["Retry-After": "3600", "Content-Type": "application/rss+xml"]
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        let published = formatter.string(from: Date())
        let item = Self.mode == .grant ? "<item><guid>fresh-grant</guid><title>Codex reset news</title><description>Some users receive a banked reset</description><pubDate>\(published)</pubDate></item>" : ""
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("<rss><channel>\(item)</channel></rss>".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
