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

    func testOlderPreferencesKeepKnownValuesAndUseDefaultsForNewFields() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let json = #"{"schemaVersion":1,"locale":"en","displayTimeZone":"America/New_York","audioEnabled":false,"volume":0.4,"reminderOffsets":[300],"detailsExpanded":true,"windowMode":"mini"}"#
        try Data(json.utf8).write(to: directory.appendingPathComponent("preferences.json"))
        let loaded = await LocalStore(directory: directory).loadPreferences()
        XCTAssertEqual(loaded.locale, .en)
        XCTAssertEqual(loaded.launchAtLogin, false)
        XCTAssertEqual(loaded.schemaVersion, UserPreferences.currentSchemaVersion)
        try? FileManager.default.removeItem(at: directory)
    }

    func testUnsupportedPreferenceSchemaFallsBackToDefaults() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = LocalStore(directory: directory)
        var preferences = UserPreferences.defaults
        preferences.schemaVersion = 999
        preferences.locale = .en
        try await store.savePreferences(preferences)
        let loaded = await store.loadPreferences()
        XCTAssertEqual(loaded, .defaults)
        try? FileManager.default.removeItem(at: directory)
    }

    func testRecoveredBackupSurvivesNextSave() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = LocalStore(directory: directory)
        var preferences = UserPreferences.defaults
        preferences.locale = .en
        try await store.savePreferences(preferences)
        try await store.savePreferences(preferences)
        let primary = directory.appendingPathComponent("preferences.json")
        try Data("broken".utf8).write(to: primary)
        let recovered = await store.loadPreferences()
        try await store.savePreferences(recovered)
        try Data("broken again".utf8).write(to: primary)
        let secondRecovery = await store.loadPreferences()
        XCTAssertEqual(secondRecovery.locale, .en)
        try? FileManager.default.removeItem(at: directory)
    }

    func testEventsWithoutTimeMeaningMigrate() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let json = #"[{"id":"old","revision":1,"kind":"automaticReset","state":"scheduled","precision":"exact","title":"Reset","titleEN":"Reset","targetAt":"2026-09-09T21:00:00Z","products":["codex"],"audience":"all","evidence":[],"firstSeenAt":"2026-09-09T12:00:00Z","updatedAt":"2026-09-09T12:00:00Z"}]"#
        try Data(json.utf8).write(to: directory.appendingPathComponent("events.json"))
        let events = await LocalStore(directory: directory).loadEvents()
        XCTAssertEqual(events.first?.timeMeaning, .automaticReset)
        try? FileManager.default.removeItem(at: directory)
    }

    func testUnrecoverablePrimaryReportsIssueInsteadOfLookingLikeValidEmptyData() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("broken".utf8).write(to: directory.appendingPathComponent("events.json"))
        let result = await LocalStore(directory: directory).loadEventsResult()
        XCTAssertTrue(result.value.isEmpty)
        XCTAssertNotNil(result.issue)
        try? FileManager.default.removeItem(at: directory)
    }
}
