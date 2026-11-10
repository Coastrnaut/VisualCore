// RenderLifecycle.swift — the render-host state machine (feature 003 T-F204; FR-F203).
// Contract: specs/002-architecture-contracts/contracts/render-lifecycle.md. A pure value type, so the
// whole transition table is tested on the Mac host; the iOS RenderHost drives it on the main thread.

/// Lifecycle states of a VisualCore render host (Constitution III).
public enum RenderLifecycleState: String, Sendable, Codable, CaseIterable {
    case uninitialized, surfaceReady, active, suspended, surfaceInvalid, reinitialized, destroyed
}

/// One recorded transition attempt.
public struct RenderLifecycleEvent: Sendable, Codable, Equatable {
    public let from: RenderLifecycleState
    public let to: RenderLifecycleState
    /// Context generation after the transition (unchanged when rejected).
    public let generation: Int
    public let accepted: Bool

    public init(from: RenderLifecycleState, to: RenderLifecycleState, generation: Int, accepted: Bool) {
        self.from = from
        self.to = to
        self.generation = generation
        self.accepted = accepted
    }
}

/// The allowed-transition table, the context generation and a bounded history.
public struct RenderLifecycle: Sendable {
    public private(set) var state: RenderLifecycleState = .uninitialized
    /// 0 before the first context; +1 on entering `surfaceReady` or `reinitialized` (FR-F208).
    public private(set) var generation = 0
    public private(set) var history: [RenderLifecycleEvent] = []
    public private(set) var rejectedTransitions = 0
    public let historyLimit: Int

    public init(historyLimit: Int = 256) {
        self.historyLimit = max(1, historyLimit)
    }

    private static let table: [RenderLifecycleState: Set<RenderLifecycleState>] = [
        .uninitialized: [.surfaceReady],
        .surfaceReady: [.active, .surfaceInvalid, .reinitialized],
        .active: [.suspended, .surfaceInvalid, .reinitialized],
        .suspended: [.active, .surfaceInvalid, .reinitialized],
        .surfaceInvalid: [.active, .suspended, .reinitialized],
        .reinitialized: [.active, .surfaceInvalid, .suspended],
        .destroyed: [],
    ]

    /// Whether `from → to` is a documented transition. Every non-destroyed state may be destroyed.
    public static func isAllowed(from: RenderLifecycleState, to: RenderLifecycleState) -> Bool {
        if from == .destroyed { return false }
        if to == .destroyed { return true }
        return table[from, default: []].contains(to)
    }

    /// Attempts a transition. A rejected transition leaves the state unchanged, is counted and recorded.
    @discardableResult
    public mutating func transition(to next: RenderLifecycleState) -> Bool {
        let ok = Self.isAllowed(from: state, to: next)
        if ok, next == .surfaceReady || next == .reinitialized { generation += 1 }
        append(RenderLifecycleEvent(from: state, to: next, generation: generation, accepted: ok))
        if ok { state = next } else { rejectedTransitions += 1 }
        return ok
    }

    private mutating func append(_ event: RenderLifecycleEvent) {
        history.append(event)
        if history.count > historyLimit { history.removeFirst(history.count - historyLimit) }
    }

    /// True while frames may be drawn.
    public var canRender: Bool { state == .active }
}
