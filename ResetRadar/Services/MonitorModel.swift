import AppKit
import Foundation
import UserNotifications

@MainActor
final class MonitorModel: ObservableObject {
    @Published private(set) var events: [ResetEvent] = []
    @Published private(set) var statuses: [SourceStatus] = []
    @Published private(set) var isRefreshing = false
    @Published var preferences: UserPreferences = .defaults
    @Published private(set) var launchAtLoginMessage: String?

    private let store: LocalStore
    private let client: FeedClient
    private let classifier = AnnouncementClassifier()
    private let reconciler = EventReconciler()
    private var pollTask: Task<Void, Never>?
    var onNewActionableEvent: ((ResetEvent) -> Void)?

    init(store: LocalStore = LocalStore(), client: FeedClient = FeedClient()) {
        self.store = store
        self.client = client
    }

    var activeEvent: ResetEvent? {
        Self.selectActiveEvent(events, now: Date())
    }

    static func selectActiveEvent(_ events: [ResetEvent], now: Date) -> ResetEvent? {
        let future = events.filter { event in
            event.state == .scheduled && event.targetAt.map { $0 > now } == true
        }.sorted { ($0.targetAt ?? .distantFuture) < ($1.targetAt ?? .distantFuture) }
        if let next = future.first { return next }
        let recentlyDue = events.filter { event in
            guard let target = event.targetAt else { return false }
            return (event.state == .dueUnconfirmed || event.state == .scheduled) && target <= now && target >= now.addingTimeInterval(-86_400)
        }.sorted { ($0.targetAt ?? .distantPast) > ($1.targetAt ?? .distantPast) }
        if let due = recentlyDue.first { return due }
        let validGrants = events.filter {
            $0.kind == .bankedResetGrant &&
            $0.state != .archived &&
            $0.state != .cancelled &&
            ($0.expiresAt.map { $0 > now } == true ||
             $0.bestEvidence?.publishedAt.map { $0 >= now.addingTimeInterval(-86_400) } == true)
        }
            .sorted { $0.updatedAt > $1.updatedAt }
        if let grant = validGrants.first { return grant }
        return events.filter {
            $0.kind == .lead &&
            $0.state == .unresolved &&
            $0.bestEvidence?.publishedAt.map { $0 >= now.addingTimeInterval(-86_400) } == true
        }.sorted { $0.updatedAt > $1.updatedAt }.first
    }

    var mostRecentAttempt: Date? { statuses.compactMap(\.lastAttemptAt).max() }
    var mostRecentSuccess: Date? { statuses.compactMap(\.lastTransportSuccessAt).max() }
    var failedSourceCount: Int { statuses.filter { $0.result == .failed }.count }

    func start(loadPreview: Bool = false) {
        Task {
            async let savedEvents = store.loadEvents()
            async let savedStatuses = store.loadStatuses()
            async let savedPreferences = store.loadPreferences()
            events = await savedEvents
            statuses = await savedStatuses
            preferences = await savedPreferences
            preferences.launchAtLogin = LaunchAtLoginService.isEnabled
            if loadPreview { addPreviewEvent() }
            await refresh(force: false)
            beginPolling()
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh(force: Bool = true) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        for source in FeedSource.defaults {
            let previous = status(for: source)
            if !force, let next = previous.nextCheckAt, next > Date() { continue }
            updateStatus(source) { status in
                status.result = .checking
                status.lastAttemptAt = Date()
                status.message = nil
            }
            do {
                let batch = try await client.fetch(source, previous: previous)
                updateStatus(source) { status in
                    status.result = .success
                    status.lastTransportSuccessAt = batch.fetchedAt
                    status.latestCoveredPublicationAt = batch.items.compactMap(\.publishedAt).max() ?? status.latestCoveredPublicationAt
                    status.nextCheckAt = batch.fetchedAt.addingTimeInterval(source.interval)
                    status.consecutiveFailures = 0
                    status.etag = batch.etag ?? status.etag
                    status.lastModified = batch.lastModified ?? status.lastModified
                    status.message = batch.notModified ? "304 · cached" : "\(batch.items.count) items"
                }
                guard !batch.notModified else { continue }
                for item in batch.items {
                    guard let candidate = classifier.classify(item, source: source, fetchedAt: batch.fetchedAt) else { continue }
                    let outcome = reconciler.merge(candidate, into: &events)
                    if outcome != .unchanged, candidate.targetAt.map({ $0 > Date() }) == true {
                        await ReminderScheduler.shared.schedule(candidate, preferences: preferences)
                        onNewActionableEvent?(candidate)
                    }
                }
            } catch {
                updateStatus(source) { status in
                    status.result = .failed
                    status.consecutiveFailures += 1
                    status.nextCheckAt = Date().addingTimeInterval(backoff(for: status.consecutiveFailures, base: source.interval))
                    status.message = error.localizedDescription
                }
            }
        }
        events = events.sorted { $0.updatedAt > $1.updatedAt }
        try? await store.saveEvents(events)
        try? await store.saveStatuses(statuses)
    }

    func setLocale(_ locale: AppLocale) {
        preferences.locale = locale
        persistPreferences()
    }

    func setTimeZone(_ identifier: String) {
        preferences.displayTimeZone = identifier
        persistPreferences()
    }

    func setExpanded(_ expanded: Bool) {
        preferences.detailsExpanded = expanded
        persistPreferences()
    }

    func setAudioEnabled(_ enabled: Bool) {
        preferences.audioEnabled = enabled
        persistPreferences()
    }

    func setVolume(_ volume: Double) {
        preferences.volume = min(max(volume, 0), 1)
        persistPreferences()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginService.setEnabled(enabled)
            preferences.launchAtLogin = LaunchAtLoginService.isEnabled
            launchAtLoginMessage = nil
            persistPreferences()
        } catch {
            preferences.launchAtLogin = LaunchAtLoginService.isEnabled
            launchAtLoginMessage = error.localizedDescription
        }
    }

    func setWindowMode(_ mode: String) {
        preferences.windowMode = mode
        persistPreferences()
    }

    func addPreviewEvent(seconds: TimeInterval = 3672) {
        let now = Date()
        let event = ResetEvent(
            id: "preview-event",
            revision: 1,
            kind: .automaticReset,
            state: .scheduled,
            precision: .exact,
            title: "额度重置预告",
            titleEN: "Quota reset announced",
            targetAt: now.addingTimeInterval(seconds),
            windowStart: nil,
            windowEnd: nil,
            expiresAt: nil,
            products: ["codex"],
            audience: "all",
            evidence: [Evidence(sourceID: "preview", itemID: "preview", sourceKind: .manual, url: nil, publishedAt: now, fetchedAt: now, excerpt: "Synthetic preview event", contentHash: "preview")],
            firstSeenAt: now,
            updatedAt: now
        )
        _ = reconciler.merge(event, into: &events)
        let snapshot = events
        Task { try? await store.saveEvents(snapshot) }
    }


    func clearPreviewEvent() {
        events.removeAll { $0.id == "preview-event" }
        let snapshot = events
        Task { try? await store.saveEvents(snapshot) }
    }

    func handleWake() async {
        await refresh(force: true)
        if let event = activeEvent, event.targetAt.map({ $0 > Date() }) == true {
            await ReminderScheduler.shared.schedule(event, preferences: preferences)
        }
    }

    private func beginPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                await self?.refresh(force: false)
            }
        }
    }

    private func status(for source: FeedSource) -> SourceStatus {
        statuses.first(where: { $0.sourceID == source.id }) ?? SourceStatus(
            sourceID: source.id,
            enabled: true,
            result: .notConnected,
            consecutiveFailures: 0
        )
    }

    private func updateStatus(_ source: FeedSource, mutate: (inout SourceStatus) -> Void) {
        var value = status(for: source)
        mutate(&value)
        if let index = statuses.firstIndex(where: { $0.sourceID == source.id }) { statuses[index] = value }
        else { statuses.append(value) }
    }

    private func persistPreferences() {
        let value = preferences
        Task { try? await store.savePreferences(value) }
    }

    private func backoff(for failures: Int, base: TimeInterval) -> TimeInterval {
        min(base * pow(2, Double(max(0, failures - 1))), 3600)
    }
}

private extension SourceStatus {
    init(sourceID: String, enabled: Bool, result: SourceResult, consecutiveFailures: Int) {
        self.init(
            sourceID: sourceID,
            enabled: enabled,
            lastAttemptAt: nil,
            lastTransportSuccessAt: nil,
            latestCoveredPublicationAt: nil,
            nextCheckAt: nil,
            result: result,
            message: nil,
            consecutiveFailures: consecutiveFailures,
            etag: nil,
            lastModified: nil
        )
    }
}
