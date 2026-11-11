// SimulationControl.swift — the pause/step state of the playground and its accessible strings (feature 023 T-A02-503;
// FR-A02-501; US1 AC1, AC5). GPU-free so the control rules are host-testable.

/// Running or paused, with the labels, hints and announcements the playground controls show.
public struct SimulationControl: Sendable, Equatable {
    /// What VoiceOver announces after a control acts.
    public enum Announcement: Sendable, Equatable {
        case paused, resumed, stepped, reset
        /// The spoken text.
        public var text: String {
            switch self {
            case .paused: "Paused"
            case .resumed: "Resumed"
            case .stepped: "Stepped one frame"
            case .reset: "Reset to the starting picture"
            }
        }
    }

    /// True while the simulation is paused.
    public private(set) var paused = false

    /// Starts running.
    public init(paused: Bool = false) { self.paused = paused }

    /// Step is available only while paused.
    public var stepEnabled: Bool { paused }
    /// The Pause/Resume control's label.
    public var pauseLabel: String { paused ? "Resume" : "Pause" }
    /// The Step control's accessibility hint.
    public var stepHint: String { paused ? "Advances the fluid by one frame" : "Pause first to step one frame" }

    /// Pauses or resumes; returns the announcement.
    public mutating func toggle() -> Announcement {
        paused.toggle()
        return paused ? .paused : .resumed
    }
}
