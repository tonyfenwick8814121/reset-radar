import Foundation

enum CopyKey {
    case announced, opportunity, vagueLead, noAnnouncement, monitoring, expected, lastCheck, never, sources, sourceReachable, sourceFailed, refresh, details, collapse, minimize, hide, statusUnknown, communityRelay, preview, querySuccess, queryPartial, queryFailed, sound, testSound, launchAtLogin
}

struct Copy {
    static func text(_ key: CopyKey, _ locale: AppLocale) -> String {
        let zh: [CopyKey: String] = [
            .announced: "发现额度重置预告", .opportunity: "发现重置机会", .vagueLead: "发现预告 · 时间待确认", .noAnnouncement: "暂无重置预告",
            .monitoring: "正在安静监测公开来源", .expected: "预计", .lastCheck: "最近查询", .never: "尚未查询",
            .sources: "来源状态", .sourceReachable: "可达", .sourceFailed: "失败", .refresh: "立即查询",
            .details: "展开详情", .collapse: "收起详情", .minimize: "收起到右上角", .hide: "隐藏",
            .statusUnknown: "上游覆盖未知", .communityRelay: "社区转引", .preview: "演示数据", .querySuccess: "查询成功", .queryPartial: "部分来源失败", .queryFailed: "查询失败", .sound: "提醒声音", .testSound: "试听", .launchAtLogin: "登录时启动"
        ]
        let en: [CopyKey: String] = [
            .announced: "Quota reset announced", .opportunity: "Reset opportunity found", .vagueLead: "Announcement found · Time pending", .noAnnouncement: "No reset announcement",
            .monitoring: "Quietly monitoring public sources", .expected: "Expected", .lastCheck: "Last checked", .never: "Not checked yet",
            .sources: "Source status", .sourceReachable: "Reachable", .sourceFailed: "Failed", .refresh: "Check now",
            .details: "Show details", .collapse: "Hide details", .minimize: "Move to top right", .hide: "Hide",
            .statusUnknown: "Upstream coverage unknown", .communityRelay: "Community relay", .preview: "DEMO DATA", .querySuccess: "Check succeeded", .queryPartial: "Some sources failed", .queryFailed: "Check failed", .sound: "Reminder sound", .testSound: "Preview", .launchAtLogin: "Launch at login"
        ]
        return (locale == .zhHans ? zh : en)[key] ?? ""
    }
}
