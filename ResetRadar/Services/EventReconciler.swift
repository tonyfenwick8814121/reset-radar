import Foundation

enum ReconcileOutcome: Equatable {
    case inserted
    case revised
    case unchanged
}

struct EventReconciler {
    func merge(_ incoming: ResetEvent, into events: inout [ResetEvent]) -> ReconcileOutcome {
        guard let index = events.firstIndex(where: { $0.id == incoming.id }) else {
            events.append(incoming)
            return .inserted
        }
        var stored = events[index]
        let existingEvidence = Set(stored.evidence.map(Self.evidenceIdentity))
        for evidence in incoming.evidence where !existingEvidence.contains(Self.evidenceIdentity(evidence)) {
            stored.evidence.append(evidence)
        }
        let existingSources = Set(events[index].evidence.map(\.sourceID))
        let incomingSources = Set(incoming.evidence.map(\.sourceID))
        let unresolvedCrossSourceConflict = stored.state == .unresolved &&
            stored.precision == .unknown && stored.targetAt == nil &&
            existingSources.count > 1 && existingSources.isDisjoint(with: incomingSources)
        if unresolvedCrossSourceConflict {
            stored.updatedAt = max(stored.updatedAt, incoming.updatedAt)
            events[index] = stored
            return .unchanged
        }
        let crossSourceTimeConflict = stored.targetAt != nil && incoming.targetAt != nil &&
            stored.targetAt != incoming.targetAt && existingSources.isDisjoint(with: incomingSources)
        if crossSourceTimeConflict {
            stored.revision += 1
            stored.targetAt = nil
            stored.state = .unresolved
            stored.precision = .unknown
            stored.updatedAt = max(stored.updatedAt, incoming.updatedAt)
            events[index] = stored
            return .revised
        }

        let audienceChanged = incoming.audience != "unknown" && stored.audience != incoming.audience
        let expiryChanged = incoming.expiresAt != nil && stored.expiresAt != incoming.expiresAt
        let windowChanged = (incoming.windowStart != nil && stored.windowStart != incoming.windowStart) ||
            (incoming.windowEnd != nil && stored.windowEnd != incoming.windowEnd)
        let meaningChanged = stored.kind != incoming.kind || stored.timeMeaning != incoming.timeMeaning ||
            stored.state != incoming.state || stored.targetAt != incoming.targetAt ||
            stored.precision != incoming.precision || audienceChanged || expiryChanged || windowChanged
        if meaningChanged {
            stored.revision += 1
            stored.kind = incoming.kind
            stored.timeMeaning = incoming.timeMeaning
            stored.state = incoming.state
            stored.precision = incoming.precision
            stored.targetAt = incoming.targetAt
            if let value = incoming.windowStart { stored.windowStart = value }
            if let value = incoming.windowEnd { stored.windowEnd = value }
            if let value = incoming.expiresAt { stored.expiresAt = value }
            if incoming.audience != "unknown" { stored.audience = incoming.audience }
            stored.products = Array(Set(stored.products + incoming.products)).sorted()
            stored.updatedAt = incoming.updatedAt
            stored.title = incoming.title
            stored.titleEN = incoming.titleEN
            events[index] = stored
            return .revised
        }
        events[index] = stored
        return .unchanged
    }

    private static func evidenceIdentity(_ evidence: Evidence) -> String {
        "\(evidence.sourceID)|\(evidence.itemID)|\(evidence.url?.absoluteString ?? "")"
    }
}
