// ExperienceLifecycle — feature 188 T-U02-005 and T-U02-011 (FR-U02-001 to FR-U02-006; data-model sections 1 and 2;
// Auto-Creator.md section 11.3). The lifecycle of an experience as a pure value. It sits above the render host's own
// lifecycle (`RenderLifecycle`) and follows the same pattern: a transition table, a counter of refusals and a bounded
// history, so the whole table is tested on the Mac host.
import Foundation

/// The lifecycle states of an experience.
public enum ExperienceLifecycleState: String, Sendable, Codable, CaseIterable {
    /// Known to the app; nothing built yet.
    case registered
    /// The domain state is being built from the seed.
    case preparing
    /// The domain state exists; the first frame can be drawn.
    case ready
    /// Steps run and actions are carried out.
    case active
    /// Clocks are stopped; the state is kept.
    case suspended
    /// The experience is being left; only teardown still reaches it.
    case deactivating
    /// Left; every resource is released. It can be prepared again.
    case inactive
    /// An error ended preparation, setup, drawing or teardown. It can be prepared again or left.
    case failed
}

/// The operations of the experience contract.
public enum ExperienceOperation: String, Sendable, Codable, CaseIterable {
    case prepare, activate, update, action, snapshot, restore, reset, setQualityTier, shedCaches, suspend, resume, deactivate
}

/// One recorded transition attempt.
public struct ExperienceLifecycleEvent: Sendable, Codable, Equatable {
    /// State before the attempt.
    public let from: ExperienceLifecycleState
    /// Requested state.
    public let to: ExperienceLifecycleState
    /// Whether the transition was legal and applied.
    public let accepted: Bool

    /// Creates an event record.
    public init(from: ExperienceLifecycleState, to: ExperienceLifecycleState, accepted: Bool) {
        self.from = from
        self.to = to
        self.accepted = accepted
    }
}

/// The lifecycle of an experience as a pure value: the transition table, the table of legal operations, the last
/// error, the counters of refusals and a bounded history of transition attempts.
public struct ExperienceLifecycle: Sendable, Equatable {
    /// The current state; a new lifecycle starts in `registered`.
    public private(set) var state: ExperienceLifecycleState = .registered
    /// The failure stored when `failed` was entered; readable until a preparation succeeds (preparing → ready).
    public private(set) var lastError: ExperienceFailure?
    /// The most recent transition attempts, accepted and rejected, oldest first (at most `historyLimit`).
    public private(set) var history: [ExperienceLifecycleEvent] = []
    /// The number of rejected transition attempts since creation.
    public private(set) var rejectedTransitions = 0
    /// The number of operations refused by `permit(_:)` since creation.
    public private(set) var rejectedOperations = 0
    /// The largest number of events kept in `history` (at least 1; default 64).
    public let historyLimit: Int

    /// Creates a lifecycle in `registered` with no error and an empty history; `historyLimit` is clamped to ≥ 1.
    public init(historyLimit: Int = 64) {
        self.historyLimit = max(1, historyLimit)
    }

    /// Whether `from → to` is one of the 20 legal transitions. A state to itself is never allowed.
    public static func isAllowed(from: ExperienceLifecycleState, to: ExperienceLifecycleState) -> Bool {
        switch from {
        case .registered: to == .preparing || to == .failed
        case .preparing: to == .ready || to == .deactivating || to == .failed
        case .ready: to == .active || to == .deactivating || to == .failed
        case .active: to == .suspended || to == .deactivating || to == .failed
        case .suspended: to == .active || to == .deactivating || to == .failed
        case .deactivating: to == .inactive || to == .failed
        case .inactive: to == .preparing || to == .failed
        case .failed: to == .preparing || to == .deactivating
        }
    }

    /// Whether `operation` is legal in `state` (28 legal cells of 96).
    public static func isLegal(_ operation: ExperienceOperation, in state: ExperienceLifecycleState) -> Bool {
        switch operation {
        case .prepare: state == .registered || state == .inactive || state == .failed
        case .activate: state == .ready
        case .update, .action, .suspend: state == .active
        case .snapshot, .restore, .reset, .setQualityTier, .shedCaches:
            state == .ready || state == .active || state == .suspended
        case .resume: state == .suspended
        case .deactivate:
            state == .preparing || state == .ready || state == .active || state == .suspended || state == .failed
        }
    }

    /// Attempts a transition and answers whether it was applied. A rejected attempt keeps the state, adds one to
    /// `rejectedTransitions` and is recorded with `accepted == false`. Entering `failed` this way stores a failure
    /// with the code `experience.unspecified`; an accepted preparing → ready clears `lastError`.
    @discardableResult
    public mutating func transition(to next: ExperienceLifecycleState) -> Bool {
        apply(next, failure: ExperienceFailure(code: ExperienceFailure.unspecifiedCode, message: ""))
    }

    /// Stores `failure` as `lastError` and moves to `failed`. Rejected, counted and recorded when the state is
    /// already `failed`; the stored error is then kept.
    @discardableResult
    public mutating func fail(_ failure: ExperienceFailure) -> Bool {
        apply(.failed, failure: failure)
    }

    /// Checks that `operation` is legal in the current state. Otherwise adds one to `rejectedOperations` and throws
    /// `ExperienceError.illegalOperation(operation, in: state)`. The state and the history never change.
    public mutating func permit(_ operation: ExperienceOperation) throws(ExperienceError) {
        guard Self.isLegal(operation, in: state) else {
            rejectedOperations += 1
            throw .illegalOperation(operation, in: state)
        }
    }

    private mutating func apply(_ next: ExperienceLifecycleState, failure: ExperienceFailure) -> Bool {
        let accepted = Self.isAllowed(from: state, to: next)
        history.append(ExperienceLifecycleEvent(from: state, to: next, accepted: accepted))
        if history.count > historyLimit { history.removeFirst(history.count - historyLimit) }
        guard accepted else {
            rejectedTransitions += 1
            return false
        }
        if next == .failed {
            lastError = failure
        } else if state == .preparing, next == .ready {
            lastError = nil
        }
        state = next
        return true
    }
}
