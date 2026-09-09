import AppKit
import Foundation

// Temporary UI harness. Replace App/ResetRadarMain.swift only in an isolated checkout.
// Uses production model/views with synthetic cached events, no feed or notification calls.
@main struct AuditAppMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AuditAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}

@MainActor final class AuditAppDelegate: NSObject, NSApplicationDelegate {
    private var model: MonitorModel?
    private var panel: FloatingPanelController?
    private let manualEntry = ManualEntryWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let root = NSMenuItem()
        let cases = NSMenu(title: "Reset Radar Audit")
        for name in ["Automatic countdown", "Grant expiry countdown", "Undated grant", "English 100 hours", "Empty"] {
            let item = NSMenuItem(title: name, action: #selector(selectScenario(_:)), keyEquivalent: "")
            item.target = self
            cases.addItem(item)
        }
        cases.addItem(.separator())
        let quit = NSMenuItem(title: "Quit audit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        cases.addItem(quit)
        root.submenu = cases
        menu.addItem(root)
        NSApp.mainMenu = menu
        install("Grant expiry countdown")
    }

    @objc private func selectScenario(_ sender: NSMenuItem) { install(sender.title) }
    @objc private func quit() { NSApp.terminate(nil) }

    private func install(_ scenario: String) {
        panel?.hide()
        model?.stop()
        Task {
            let now = Date()
            let store = LocalStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("rr-ui-audit-" + UUID().uuidString))
            let isGrant = scenario.contains("Grant") || scenario == "Undated grant"
            let target: Date? = scenario == "Undated grant" ? nil : now.addingTimeInterval(scenario == "English 100 hours" ? 360_001 : 20)
            let event = ResetEvent(
                id: "audit-fixture", revision: 1, kind: isGrant ? .bankedResetGrant : .automaticReset,
                timeMeaning: isGrant ? (target == nil ? .grantAvailability : .grantExpiry) : .automaticReset,
                state: isGrant ? .available : (target == nil ? .unresolved : .scheduled), precision: target == nil ? .unknown : .exact,
                title: "验收夹具", titleEN: "Audit fixture", targetAt: isGrant ? nil : target,
                windowStart: nil, windowEnd: nil, expiresAt: isGrant ? target : nil, products: ["codex"], audience: "partial",
                evidence: [Evidence(sourceID: "audit", itemID: "fixture", sourceKind: .manual, url: nil, publishedAt: now, fetchedAt: now, excerpt: "Synthetic acceptance fixture", contentHash: "fixture")],
                firstSeenAt: now, updatedAt: now
            )
            try! await store.saveEvents(scenario == "Empty" ? [] : [event])
            try! await store.saveStatuses(FeedSource.defaults.map {
                SourceStatus(sourceID: $0.id, enabled: true, lastAttemptAt: now, lastTransportSuccessAt: now,
                    latestCoveredPublicationAt: nil, nextCheckAt: now.addingTimeInterval(86_400), result: .success,
                    message: "QA fixture", consecutiveFailures: 0, etag: nil, lastModified: nil)
            })
            var preferences = UserPreferences.defaults
            preferences.audioEnabled = false
            preferences.locale = scenario == "English 100 hours" ? .en : .zhHans
            try! await store.savePreferences(preferences)
            let value = MonitorModel(store: store, scheduler: AuditScheduler())
            model = value
            value.start()
            while value.statuses.isEmpty { await Task.yield() }
            panel = FloatingPanelController(model: value) { [weak self, weak value] in
                guard let self, let value else { return }
                self.manualEntry.show(locale: value.preferences.locale, timeZoneID: value.preferences.displayTimeZone) { draft in
                    value.addManualEvent(draft)
                }
            }
        }
    }
}

actor AuditScheduler: ReminderScheduling {
    func reconcile(events: [ResetEvent], preferences: UserPreferences, now: Date) async {}
    func cancelAll() async {}
}
