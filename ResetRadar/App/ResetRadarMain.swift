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
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = MonitorModel()
        panelController = FloatingPanelController(model: model)
        model.onNewActionableEvent = { [weak self] _ in
            self?.panelController.showMain(center: true)
            if self?.model.preferences.audioEnabled == true { SoundService.preview(volume: self?.model.preferences.volume ?? 0.65) }
        }
        setupMenuBar()
        UNUserNotificationCenter.current().delegate = self
        model.start(loadPreview: ProcessInfo.processInfo.arguments.contains("--preview"))
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(clockChanged), name: NSNotification.Name.NSSystemClockDidChange, object: nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "scope", accessibilityDescription: "Reset Radar")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePanel)

        let menu = NSMenu()
        menu.addItem(withTitle: "显示 / Show", action: #selector(showPanel), keyEquivalent: "")
        menu.addItem(withTitle: "立即查询 / Check now", action: #selector(refresh), keyEquivalent: "r")
        menu.addItem(withTitle: "载入演示预告 / Load preview", action: #selector(loadPreview), keyEquivalent: "")
        menu.addItem(withTitle: "清除演示预告 / Clear preview", action: #selector(clearPreview), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 Reset Radar / Quit", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        statusItem.menu = menu
    }

    @objc private func togglePanel() { panelController.toggleVisible() }
    @objc private func showPanel() { panelController.showMain() }
    @objc private func refresh() { Task { await model.refresh() } }
    @objc private func loadPreview() { model.addPreviewEvent(); panelController.showMain(center: true) }
    @objc private func clearPreview() { model.clearPreviewEvent(); panelController.showMain() }
    @objc private func didWake() { Task { await model.handleWake() } }
    @objc private func clockChanged() { Task { await model.handleWake() } }
    @objc private func quit() { NSApplication.shared.terminate(nil) }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
