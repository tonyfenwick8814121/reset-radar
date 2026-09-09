import Foundation

actor FeedClient {
    private let session: URLSession
    private let maximumBytes = 2_000_000

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(_ source: FeedSource, previous: SourceStatus?) async throws -> FeedBatch {
        var request = URLRequest(url: source.url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 15)
        request.setValue("ResetRadar/0.1 (+https://github.com/)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/rss+xml, application/atom+xml, application/xml, text/xml", forHTTPHeaderField: "Accept")
        if let etag = previous?.etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        if let modified = previous?.lastModified { request.setValue(modified, forHTTPHeaderField: "If-Modified-Since") }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FeedError.invalidResponse }
        if http.statusCode == 304 {
            return FeedBatch(items: [], fetchedAt: Date(), etag: previous?.etag, lastModified: previous?.lastModified, notModified: true)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw FeedError.http(http.statusCode, retryAfter: Self.retryDelay(http.value(forHTTPHeaderField: "Retry-After")))
        }
        guard data.count <= maximumBytes else { throw FeedError.oversized }
        let items = try XMLFeedParser().parse(data)
        return FeedBatch(
            items: items,
            fetchedAt: Date(),
            etag: http.value(forHTTPHeaderField: "ETag"),
            lastModified: http.value(forHTTPHeaderField: "Last-Modified"),
            notModified: false
        )
    }

    private static func retryDelay(_ value: String?) -> TimeInterval? {
        guard let value else { return nil }
        if let seconds = TimeInterval(value.trimmingCharacters(in: .whitespacesAndNewlines)) { return max(0, seconds) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: value).map { max(0, $0.timeIntervalSinceNow) }
    }
}
