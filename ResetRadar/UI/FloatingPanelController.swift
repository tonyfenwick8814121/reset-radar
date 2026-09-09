import AppKit
import SwiftUI

@MainActor
final class FloatingPanelController {
    private let model: MonitorModel
    private let panel: NSPanel
    private let onManualEntry: () -> Void
    private var mode = "main"
    private var moveObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?

    init(model: MonitorModel, onManualEntry: @escaping () -> Void = {}) {
        self.model = model
        self.onManualEntry = onManualEntry
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 436, height: 318),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.animationBehavior = .utilityWindow
        panel.setAccessibilityTitle("Reset Radar")
        showMain(center: true, persistMode: false)
        moveObserver = NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.saveCurrentFrame() }
        }
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.clampToVisibleScreen() }
        }
    }

    deinit {
        if let moveObserver { NotificationCenter.default.removeObserver(moveObserver) }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }

    func showMain(center: Bool = false, persistMode: Bool = true) {
        let wasMini = mode == "mini"
        mode = "main"
        if persistMode { model.setWindowMode(mode) }
        let height: CGFloat = model.preferences.detailsExpanded ? 634 : 318
        panel.setContentSize(NSSize(width: 436, height: height))
        panel.contentView = NSHostingView(rootView: CountdownView(
            model: model,
            onMiniimize: { [weak self] in self?.showMini() },
            onHide: { [weak self] in self?.hide() },
            onManualEntry: onManualEntry,
            onExpansionChange: { [weak self] _ in self?.refreshSize() }
        ))
        if center { centerOnPointerScreen() }
        else if let frame = model.preferences.mainWindowFrame { applySavedFrame(frame) }
        else if wasMini { centerOnPointerScreen() }
        clampToVisibleScreen()
        if persistMode { saveCurrentFrame() }
        panel.orderFrontRegardless()
    }

    func showMini() {
        mode = "mini"
        model.setWindowMode(mode)
        panel.setContentSize(NSSize(width: 280, height: 165))
        panel.contentView = NSHostingView(rootView: MiniView(
            model: model,
            onExpand: { [weak self] in self?.showMain() },
            onHide: { [weak self] in self?.hide() }
        ))
        if let frame = model.preferences.miniWindowFrame { applySavedFrame(frame) }
        else { moveToTopRight() }
        clampToVisibleScreen()
        saveCurrentFrame()
        panel.orderFrontRegardless()
    }

    func restoreSavedMode() {
        model.preferences.windowMode == "mini" ? showMini() : showMain()
    }

    func toggleVisible() {
        panel.isVisible ? hide() : (mode == "mini" ? showMini() : showMain())
    }

    func hide() { panel.orderOut(nil) }

    func refreshSize() {
        guard mode == "main" else { return }
        let origin = panel.frame.origin
        showMain()
        panel.setFrameOrigin(origin)
        clampToVisibleScreen()
        saveCurrentFrame()
    }

    private func pointerScreen() -> NSScreen {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private func centerOnPointerScreen() {
        let visible = pointerScreen().visibleFrame
        panel.setFrameOrigin(NSPoint(x: visible.midX - panel.frame.width / 2, y: visible.midY - panel.frame.height / 2))
    }

    private func moveToTopRight() {
        let visible = pointerScreen().visibleFrame
        panel.setFrameOrigin(NSPoint(x: visible.maxX - panel.frame.width - 18, y: visible.maxY - panel.frame.height - 18))
    }

    private func applySavedFrame(_ saved: WindowFrame) {
        panel.setFrame(NSRect(x: saved.x, y: saved.y, width: panel.frame.width, height: panel.frame.height), display: false)
    }

    private func saveCurrentFrame() {
        let frame = panel.frame
        model.setWindowFrame(WindowFrame(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: frame.height), mode: mode)
    }

    private func clampToVisibleScreen() {
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(panel.frame) }) ?? pointerScreen()
        let visible = screen.visibleFrame
        var origin = panel.frame.origin
        origin.x = min(max(origin.x, visible.minX), max(visible.minX, visible.maxX - panel.frame.width))
        origin.y = min(max(origin.y, visible.minY), max(visible.minY, visible.maxY - panel.frame.height))
        panel.setFrameOrigin(origin)
    }
}
