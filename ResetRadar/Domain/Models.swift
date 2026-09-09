import Foundation

enum ResetKind: String, Codable, Sendable {
    case automaticReset
    case bankedResetGrant
    case limitChange
    case lead
}

enum EventState: String, Codable, Sendable {
    case unresolved
    case scheduled
    case dueUnconfirmed
    case announcedComplete
    case cancelled
    case archived
}

enum TimePrecision: String, Codable, Sendable {
    case exact
    case approximate
    case range
    case dateOnly
    case unknown
}

enum SourceKind: String, Codable, Sendable {
    case communityFeed
    case officialFeed
    case manual
}

struct Evidence: Codable, Hashable, Sendable {
    let sourceID: String
    let itemID: String
    let sourceKind: SourceKind
    let url: URL?
    let publishedAt: Date?
    let fetchedAt: Date
    let excerpt: String
    let contentHash: String
}

struct ResetEvent: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var revision: Int
    var kind: ResetKind
    var state: EventState
    var precision: TimePrecision
    var title: String
    var titleEN: String
    var targetAt: Date?
    var windowStart: Date?
    var windowEnd: Date?
    var expiresAt: Date?
    var products: [String]
    var audience: String
    var evidence: [Evidence]
    var firstSeenAt: Date
    var updatedAt: Date

    var bestEvidence: Evidence? {
        evidence.sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }.first
    }
}

enum SourceResult: String, Codable, Sendable {
    case notConnected
    case checking
    case success
    case partial
    case failed
    case stale
}

struct SourceStatus: Identifiable, Codable, Hashable, Sendable {
    var id: String { sourceID }
    let sourceID: String
    var enabled: Bool
    var lastAttemptAt: Date?
    var lastTransportSuccessAt: Date?
    var latestCoveredPublicationAt: Date?
    var nextCheckAt: Date?
    var result: SourceResult
    var message: String?
    var consecutiveFailures: Int
    var etag: String?
    var lastModified: String?
}

enum AppLocale: String, Codable, CaseIterable, Sendable {
    case zhHans = "zh-Hans"
    case en
}

struct UserPreferences: Codable, Equatable, Sendable {
    var schemaVersion = 1
    var locale: AppLocale = .zhHans
    var displayTimeZone = "Asia/Shanghai"
    var audioEnabled = true
    var volume = 0.65
    var launchAtLogin = false
    var reminderOffsets: [TimeInterval] = [1800, 300]
    var detailsExpanded = false
    var windowMode = "main"

    static let defaults = UserPreferences()
}

struct FeedItem: Hashable, Sendable {
    let id: String
    let title: String
    let body: String
    let url: URL?
    let publishedAt: Date?
}

struct FeedBatch: Sendable {
    let items: [FeedItem]
    let fetchedAt: Date
    let etag: String?
    let lastModified: String?
    let notModified: Bool
}

enum FeedError: LocalizedError {
    case invalidResponse
    case http(Int)
    case oversized
    case malformedXML

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response"
        case .http(let code): return "HTTP \(code)"
        case .oversized: return "Feed is too large"
        case .malformedXML: return "Malformed RSS/Atom"
        }
    }
}
