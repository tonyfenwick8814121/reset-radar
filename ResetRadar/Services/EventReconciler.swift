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
        let existingHashes = Set(stored.evidence.map(\.contentHash))
        for evidence in incoming.evidence where !existingHashes.contains(evidence.contentHash) {
            stored.evidence.append(evidence)
        }
        let meaningChanged = stored.kind != incoming.kind || stored.state != incoming.state || stored.targetAt != incoming.targetAt || stored.precision != incoming.precision
        if meaningChanged {
            stored.revision += 1
            stored.kind = incoming.kind
            stored.state = incoming.state
            stored.precision = incoming.precision
            stored.targetAt = incoming.targetAt
            stored.updatedAt = incoming.updatedAt
            stored.title = incoming.title
            stored.titleEN = incoming.titleEN
            events[index] = stored
            return .revised
        }
        events[index] = stored
        return .unchanged
    }
}
