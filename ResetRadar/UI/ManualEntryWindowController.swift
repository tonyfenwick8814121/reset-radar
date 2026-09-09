import AppKit
import SwiftUI

@MainActor
final class ManualEntryWindowController {
    private var window: NSWindow?

    func show(locale: AppLocale, timeZoneID: String, onSave: @escaping (ManualEntryDraft) -> Void) {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        window = nil
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 430),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = locale == .zhHans ? "手动添加公告" : "Add announcement"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: ManualEntryView(locale: locale, timeZoneID: timeZoneID) { [weak self] draft in
            onSave(draft)
            self?.close()
        } onCancel: { [weak self] in
            self?.close()
        })
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func close() {
        window?.close()
        window = nil
    }
}

private struct ManualEntryView: View {
    let locale: AppLocale
    let timeZoneID: String
    let onSave: (ManualEntryDraft) -> Void
    let onCancel: () -> Void
    @State private var text = ""
    @State private var kind: ResetKind = .automaticReset
    @State private var hasDate = true
    @State private var date = Date().addingTimeInterval(3600)
    @State private var product = "codex"
    @State private var audience = "unknown"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(locale == .zhHans ? "手动添加公告" : "Add announcement")
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text(locale == .zhHans ? "粘贴公告文字或链接，并确认它代表哪一种重置。应用不会读取或操作你的账户。" : "Paste the announcement text or link, then confirm what kind of reset it describes. The app does not read or operate your account.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Picker("", selection: $kind) {
                Text(locale == .zhHans ? "自动额度重置" : "Automatic quota reset").tag(ResetKind.automaticReset)
                Text(locale == .zhHans ? "可手动使用的机会" : "Manual reset opportunity").tag(ResetKind.bankedResetGrant)
            }.pickerStyle(.segmented)
            TextEditor(text: $text)
                .font(.system(size: 12)).frame(minHeight: 100)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))
            Toggle(kind == .bankedResetGrant
                   ? (locale == .zhHans ? "公告提供了失效时间" : "The announcement includes an expiry time")
                   : (locale == .zhHans ? "公告提供了预计重置时间" : "The announcement includes an estimated reset time"), isOn: $hasDate)
            if hasDate {
                HStack {
                    DatePicker("", selection: $date).labelsHidden()
                    Text(timeZoneID).font(.system(size: 9)).foregroundStyle(.secondary)
                }
                .environment(\.timeZone, TimeZone(identifier: timeZoneID) ?? .current)
            }
            HStack {
                Picker(locale == .zhHans ? "产品" : "Product", selection: $product) {
                    Text("Codex").tag("codex")
                    Text("ChatGPT").tag("chatgpt")
                    Text("ChatGPT Work").tag("chatgpt-work")
                }
                Picker(locale == .zhHans ? "人群" : "Audience", selection: $audience) {
                    Text(locale == .zhHans ? "未知" : "Unknown").tag("unknown")
                    Text(locale == .zhHans ? "全部用户" : "All users").tag("all")
                    Text(locale == .zhHans ? "部分用户" : "Some users").tag("partial")
                }
            }
            Spacer()
            HStack {
                Spacer()
                Button(locale == .zhHans ? "取消" : "Cancel", action: onCancel)
                Button(locale == .zhHans ? "保存" : "Save") {
                    onSave(ManualEntryDraft(text: text.trimmingCharacters(in: .whitespacesAndNewlines), kind: kind, date: hasDate ? date : nil, product: product, audience: audience))
                }
                .keyboardShortcut(.defaultAction)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (kind == .automaticReset && !hasDate))
            }
        }
        .padding(22)
        .frame(width: 430, height: 430)
    }
}
