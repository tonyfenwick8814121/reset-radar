import AppKit
import SwiftUI

@MainActor
final class FloatingPanelController {
    private let model: MonitorModel
    private let panel: NSPanel
    private var mode = "main"

    init(model: MonitorModel) {
        self.model = model
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
        showMain(center: true)
    }

    func showMain(center: Bool = false) {
        mode = "main"
        model.setWindowMode(mode)
        let height: CGFloat = model.preferences.detailsExpanded ? 524 : 318
        panel.setContentSize(NSSize(width: 436, height: height))
        panel.contentView = NSHostingView(rootView: CountdownView(
            model: model,
            onMiniimize: { [weak self] in self?.showMini() },
            onHide: { [weak self] in self?.hide() },
            onExpansionChange: { [weak self] _ in self?.refreshSize() }
        ))
        if center { centerOnPointerScreen() }
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
        moveToTopRight()
        panel.orderFrontRegardless()
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
}
