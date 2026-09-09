import XCTest
@testable import ResetRadar

final class ReminderPlannerTests: XCTestCase {
    func testOnlyFutureThresholdsAreScheduled() {
        let now = Date(timeIntervalSince1970: 10_000)
        let target = now.addingTimeInterval(180)
        let reminders = ReminderPlanner.plan(target: target, offsets: [1800, 300, 60], now: now)
        XCTAssertEqual(reminders.map(\.offset), [60, 0])
        XCTAssertEqual(reminders.last?.fireDate, target)
    }

    func testDueTargetProducesNoFutureRequest() {
        let now = Date(timeIntervalSince1970: 10_000)
        XCTAssertTrue(ReminderPlanner.plan(target: now, offsets: [300], now: now).isEmpty)
    }
}
