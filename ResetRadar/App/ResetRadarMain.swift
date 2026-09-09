import AppKit
import SwiftUI
import UserNotifications

@main
struct ResetRadarMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var model: MonitorModel!
    private var panelController: FloatingPanelController!
    private let manualEntryController = ManualEntryWindowController()
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = MonitorModel()
        panelController = FloatingPanelController(model: model) { [weak self] in
            guard let self else { return }
            self.manualEntryController.show(locale: self.model.preferences.locale, timeZoneID: self.model.preferences.displayTimeZone) { [weak self] draft in
                self?.model.addManualEvent(draft)
            }
        }
        model.onNewActionableEvent = { [weak self] _ in
            self?.panelController.showMain(center: true)
            if self?.model.preferences.audioEnabled == true { SoundService.preview(volume: self?.model.preferences.volume ?? 0.65) }
        }
        model.onPreferencesChanged = { [weak self] _ in self?.setupMenuBar() }
        setupMenuBar()
        UNUserNotificationCenter.current().delegate = self
        let startTask = model.start(loadPreview: ProcessInfo.processInfo.arguments.contains("--preview"))
        Task { [weak self] in
            await startTask.value
            self?.panelController.restoreSavedMode()
        }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(clockChanged), name: NSNotification.Name.NSSystemClockDidChange, object: nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    private func setupMenuBar() {
        if statusItem == nil { statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength) }
        statusItem.button?.image = NSImage(systemSymbolName: "scope", accessibilityDescription: "Reset Radar")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePanel)

        let zh = model?.preferences.locale != .en
        let menu = NSMenu()
        menu.addItem(withTitle: zh ? "显示" : "Show", action: #selector(showPanel), keyEquivalent: "")
        menu.addItem(withTitle: zh ? "立即查询" : "Check now", action: #selector(refresh), keyEquivalent: "r")
        menu.addItem(withTitle: zh ? "手动添加公告…" : "Add announcement…", action: #selector(manualEntry), keyEquivalent: "n")
        menu.addItem(withTitle: zh ? "载入演示预告" : "Load preview", action: #selector(loadPreview), keyEquivalent: "")
        menu.addItem(withTitle: zh ? "清除演示预告" : "Clear preview", action: #selector(clearPreview), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: zh ? "退出 Reset Radar" : "Quit Reset Radar", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        statusItem.menu = menu
    }

    @objc private func togglePanel() { panelController.toggleVisible() }
    @objc private func showPanel() { panelController.showMain() }
    @objc private func refresh() { Task { await model.refresh() } }
    @objc private func manualEntry() {
        manualEntryController.show(locale: model.preferences.locale, timeZoneID: model.preferences.displayTimeZone) { [weak self] draft in self?.model.addManualEvent(draft) }
    }
    @objc private func loadPreview() { model.addPreviewEvent(); panelController.showMain(center: true) }
    @objc private func clearPreview() { model.clearPreviewEvent(); panelController.showMain() }
    @objc private func didWake() { Task { await model.handleWake() } }
    @objc private func clockChanged() { Task { await model.handleWake() } }
    @objc private func quit() {
        Task {
            await model.cancelPendingReminders()
            NSApplication.shared.terminate(nil)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
