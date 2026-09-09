import CryptoKit
import Foundation

struct AnnouncementClassifier {
    private let resolver = TimeResolver()

    func classify(_ item: FeedItem, source: FeedSource, fetchedAt: Date) -> ResetEvent? {
        let combined = "\(item.title) \(item.body)"
        let lower = combined.lowercased()
        let resetWords = lower.contains("reset") || lower.contains("额度重置")
        let productWords = lower.contains("chatgpt") || lower.contains("codex") || lower.contains("usage limit") || lower.contains("weekly limit")
        guard resetWords && productWords else { return nil }

        let isGrant = lower.contains("banked reset") || lower.contains("reset grant") || lower.contains("重置机会")
        let forwardMarkers = [" will ", "lands ", "landing ", "tomorrow", "later today", "end of day", "planned", "upcoming", "next hour"]
        let isForwardLooking = forwardMarkers.contains { lower.contains($0) }
        let completeMarkers = ["it is done", "already reset", "returned to 100%", "back to 100%", "reset propagated", "limits reset for", "usage reset for"]
        let isComplete = source.id == "codex-reset" || (!isForwardLooking && completeMarkers.contains { lower.contains($0) })
        let resolution = resolver.resolve(combined, publishedAt: item.publishedAt, verifiedContextZone: inferredContextZone(lower))
        let target: Date?
        let state: EventState
        let precision: TimePrecision
        switch resolution {
        case .exact(let date):
            target = date
            state = date > fetchedAt ? .scheduled : .dueUnconfirmed
            precision = .exact
        case .unresolved:
            target = nil
            state = isComplete ? .announcedComplete : .unresolved
            precision = .unknown
        }
        let kind: ResetKind = isGrant ? .bankedResetGrant : (isForwardLooking && target == nil ? .lead : .automaticReset)
        let hash = SHA256.hash(data: Data(combined.utf8)).map { String(format: "%02x", $0) }.joined()
        let originalURL = originalPostURL(in: combined)
        let canonical = canonicalID(item, originalURL: originalURL)
        let evidence = Evidence(
            sourceID: source.id,
            itemID: item.id,
            sourceKind: source.kind,
            url: originalURL ?? item.url,
            publishedAt: item.publishedAt,
            fetchedAt: fetchedAt,
            excerpt: String(combined.prefix(280)),
            contentHash: hash
        )
        return ResetEvent(
            id: canonical,
            revision: 1,
            kind: kind,
            state: state,
            precision: precision,
            title: isGrant ? "发现重置机会" : "额度重置预告",
            titleEN: isGrant ? "Reset opportunity" : "Quota reset announced",
            targetAt: target,
            windowStart: nil,
            windowEnd: nil,
            expiresAt: nil,
            products: lower.contains("codex") ? ["codex"] : ["chatgpt"],
            audience: lower.contains("all users") ? "all" : ((isGrant && lower.contains("some ")) || lower.contains("some users") || lower.contains("500k") ? "partial" : "unknown"),
            evidence: [evidence],
            firstSeenAt: fetchedAt,
            updatedAt: fetchedAt
        )
    }

    private func inferredContextZone(_ text: String) -> String? {
        text.contains(" pt") || text.contains("pst") || text.contains("pdt") ? "America/Los_Angeles" : nil
    }

    private func canonicalID(_ item: FeedItem, originalURL: URL?) -> String {
        if let url = originalURL ?? item.url {
            let path = url.path.lowercased()
            if let match = path.range(of: #"status/\d+"#, options: .regularExpression) {
                return String(path[match]).replacingOccurrences(of: "/", with: "-")
            }
        }
        return SHA256.hash(data: Data(item.id.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    private func originalPostURL(in text: String) -> URL? {
        let pattern = #"https://(?:x\.com|twitter\.com)/[^\s/]+/status/\d+"#
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        return URL(string: String(text[range]))
    }
}
