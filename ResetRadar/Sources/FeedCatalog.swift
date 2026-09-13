import Foundation

struct FeedSource: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let url: URL
    let kind: SourceKind
    let interval: TimeInterval

    static let defaults: [FeedSource] = [
        FeedSource(id: "codex-reset-json", name: "Codex Reset / Public JSON",
                   url: URL(string: "https://codex-reset.com/api/feed")!, kind: .communityFeed, interval: 600),
        FeedSource(
            id: "modelyard",
            name: "ModelYard / Tibo",
            url: URL(string: "https://tibo.modelyard.dev/feed.xml")!,
            kind: .communityFeed,
            interval: 300
        ),
        FeedSource(
            id: "codex-reset",
            name: "Codex Reset",
            url: URL(string: "https://codex-reset.com/feed.xml")!,
            kind: .communityFeed,
            interval: 300
        ),
        FeedSource(
            id: "openai-news",
            name: "OpenAI News",
            url: URL(string: "https://openai.com/news/rss.xml")!,
            kind: .officialFeed,
            interval: 1800
        ),
        FeedSource(
            id: "openai-status",
            name: "OpenAI Status",
            url: URL(string: "https://status.openai.com/history.rss")!,
            kind: .officialFeed,
            interval: 900
        )
    ]
}
