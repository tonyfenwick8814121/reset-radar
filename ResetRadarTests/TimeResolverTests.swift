import XCTest
@testable import ResetRadar

final class TimeResolverTests: XCTestCase {
    private let resolver = TimeResolver()
    private let iso = ISO8601DateFormatter()

    func testSummerPT() {
        assertExact("Reset on September 9, 2026 at 14:00 PT.", equals: "2026-09-09T21:00:00Z")
    }

    func testWinterPT() {
        assertExact("Reset on December 9, 2026 at 14:00 PT.", equals: "2026-12-09T22:00:00Z")
    }

    func testTomorrowUsesPublishedDateInSourceZone() {
        let published = iso.date(from: "2026-09-09T06:30:00Z")!
        let result = resolver.resolve("Reset tomorrow at 2pm PT.", publishedAt: published, verifiedContextZone: "America/Los_Angeles")
        XCTAssertEqual(result, .exact(iso.date(from: "2026-09-09T21:00:00Z")!))
    }

    func testPSTConflictInSummerIsUnresolved() {
        let result = resolver.resolve("Reset on September 9, 2026 at 14:00 PST.", verifiedContextZone: "America/Los_Angeles")
        guard case .unresolved = result else { return XCTFail("Expected unresolved") }
    }

    func testRelativeDateWithoutZoneIsUnresolved() {
        let result = resolver.resolve("Reset tomorrow at 2pm.", publishedAt: iso.date(from: "2026-09-09T06:30:00Z"))
        guard case .unresolved = result else { return XCTFail("Expected unresolved") }
    }

    func testDSTGapAndRepeatAreUnresolved() {
        for value in ["2026-03-08 02:30 America/Los_Angeles", "2026-11-01 01:30 America/Los_Angeles"] {
            guard case .unresolved = resolver.resolve(value) else { return XCTFail("Expected unresolved for \(value)") }
        }
    }

    func testISO8601OffsetTimestampIsExact() {
        XCTAssertEqual(resolver.resolve("Codex reset 2026-09-09T14:00:00-07:00"), .exact(iso.date(from: "2026-09-09T21:00:00Z")!))
    }

    func testInvalidMeridiemHourIsUnresolved() {
        let result = resolver.resolve("Reset tomorrow at 14pm PT", publishedAt: iso.date(from: "2026-09-09T12:00:00Z"), verifiedContextZone: "America/Los_Angeles")
        guard case .unresolved = result else { return XCTFail("Expected invalid 14pm to remain unresolved") }
    }

    private func assertExact(_ input: String, equals expected: String) {
        XCTAssertEqual(resolver.resolve(input), .exact(iso.date(from: expected)!))
    }
}
