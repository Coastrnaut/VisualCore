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
