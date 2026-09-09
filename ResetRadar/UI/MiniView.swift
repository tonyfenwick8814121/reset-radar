import SwiftUI

struct MiniView: View {
    @ObservedObject var model: MonitorModel
    let onExpand: () -> Void
    let onHide: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 8) {
                HStack {
                    Circle().fill(accent).frame(width: 8, height: 8)
                    Text("Reset Radar").font(.system(size: 11, weight: .bold, design: .rounded))
                    if model.activeEvent?.evidence.contains(where: { $0.sourceID == "preview" }) == true {
                        Text("DEMO").font(.system(size: 7, weight: .bold)).foregroundStyle(.purple)
                    }
                    Spacer()
                    localeButton("中", .zhHans)
                    localeButton("EN", .en)
                    Button(action: onExpand) { Image(systemName: "arrow.up.left.and.arrow.down.right") }.buttonStyle(.plain)
                    Button(action: onHide) { Image(systemName: "xmark") }.buttonStyle(.plain)
                }.foregroundStyle(.secondary)
                Text(countdown(now: context.date))
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                Text(targetText).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(16)
            .frame(width: 260, height: 145)
            .background(miniBackground)
            .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 23, style: .continuous).stroke(.white.opacity(0.18)))
            .shadow(color: accent.opacity(0.18), radius: 24, y: 10)
            .padding(10)
        }
    }

    @ViewBuilder private var miniBackground: some View {
        if #available(macOS 26.0, *) { Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 23)) }
        else { Rectangle().fill(.ultraThinMaterial) }
    }

    private func localeButton(_ title: String, _ value: AppLocale) -> some View {
        Button(title) { model.setLocale(value) }.buttonStyle(.plain)
            .font(.system(size: 9, weight: model.preferences.locale == value ? .bold : .regular))
            .foregroundStyle(model.preferences.locale == value ? accent : .secondary)
    }

    private func countdown(now: Date) -> String {
        guard let target = model.activeEvent?.targetAt else { return "––:––:––" }
        return CountdownView.remaining(target.timeIntervalSince(now))
    }

    private var targetText: String {
        guard let target = model.activeEvent?.targetAt else {
            return Copy.text(.monitoring, model.preferences.locale)
        }
        return CountdownView.format(target, zoneID: model.preferences.displayTimeZone, locale: model.preferences.locale)
    }

    private var accent: Color {
        if model.activeEvent?.kind == .bankedResetGrant { return .green }
        if let date = model.activeEvent?.targetAt, date.timeIntervalSinceNow < 300 { return .red }
        return model.activeEvent == nil ? .gray : .orange
    }
}
