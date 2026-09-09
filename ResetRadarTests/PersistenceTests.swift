import XCTest
@testable import ResetRadar

final class PersistenceTests: XCTestCase {
    func testPreferencesRoundTrip() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = LocalStore(directory: directory)
        var preferences = UserPreferences.defaults
        preferences.locale = .en
        preferences.displayTimeZone = "America/New_York"
        try await store.savePreferences(preferences)
        let loaded = await store.loadPreferences()
        XCTAssertEqual(loaded, preferences)
        try? FileManager.default.removeItem(at: directory)
    }

    func testCorruptPrimaryFallsBackToBackup() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = LocalStore(directory: directory)
        var first = UserPreferences.defaults
        first.locale = .en
        try await store.savePreferences(first)
        var second = first
        second.displayTimeZone = "Asia/Tokyo"
        try await store.savePreferences(second)
        try Data("broken".utf8).write(to: directory.appendingPathComponent("preferences.json"))
        let loaded = await store.loadPreferences()
        XCTAssertEqual(loaded, first)
        try? FileManager.default.removeItem(at: directory)
    }
}
