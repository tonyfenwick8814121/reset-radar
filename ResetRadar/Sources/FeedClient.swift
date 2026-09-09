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
        guard (200..<300).contains(http.statusCode) else { throw FeedError.http(http.statusCode) }
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
}
