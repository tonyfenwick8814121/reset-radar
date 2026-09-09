import XCTest
@testable import ResetRadar

final class CountdownTests: XCTestCase {
    func testCountdownRoundsUpAndNeverGoesNegative() {
        XCTAssertEqual(CountdownView.remaining(0.2), "00:00:01")
        XCTAssertEqual(CountdownView.remaining(-1), "00:00:00")
        XCTAssertEqual(CountdownView.remaining(3_661), "01:01:01")
        XCTAssertEqual(CountdownView.remaining(360_000), "4天 04:00:00")
    }

    func testFormattingDoesNotMutateDate() {
        let date = Date(timeIntervalSince1970: 1_789_012_800)
        _ = CountdownView.format(date, zoneID: "Asia/Shanghai", locale: .zhHans)
        _ = CountdownView.format(date, zoneID: "America/New_York", locale: .en)
        XCTAssertEqual(date.timeIntervalSince1970, 1_789_012_800)
    }
}
