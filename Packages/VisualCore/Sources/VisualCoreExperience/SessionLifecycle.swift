// SessionLifecycle — feature 189 T-U03-003 (FR-U03-001, FR-U03-080, FR-U03-081, FR-U03-100; contract
// specs/189-ua-f03-experience-host/contracts/session-api.md, pure part; data-model sections 1, 2, 4, 5 and 6).
// The pure values of an experience session: its states and transition table, the order of a close, the
// memory-pressure rule, the failure with its stage and the diagnostics. The session itself lives on the main actor
// in VisualCoreExperienceHost and makes every state change through `SessionLifecycle`, so the whole table is tested
// on the Mac host.
import Foundation

/// The states of an experience session.
public enum SessionState: String, Sendable, Codable, CaseIterable {
    /// Nothing is open.
    case idle
    /// An experience is being built and prepared; no render host exists yet.
    case preparing
    /// The experience is active and frames are drawn.
    case running
    /// The experience is kept while the app is not active; its clocks are stopped.
    case suspended
    /// An error ended the open or the run; the failure view is shown.
    case failed
    /// The session closed the experience itself and shows a text that says why.
    case message
    /// The steps of a full close are being taken.
    case closing
}

/// The scene phase of the app as the session takes it in.
public enum ScenePhaseInput: String, Sendable, Codable, CaseIterable {
    /// The scene is in the foreground and takes input.
    case active
    /// The scene is in the foreground and takes no input.
    case inactive
    /// The scene is not visible.
    case background
}

/// One step of a close. The session appends each step it takes to a record.
public enum SessionCloseStep: String, Sendable, Codable, CaseIterable {
    /// The frame clock of the render host is stopped.
    case stopClock
    /// A snapshot of the experience is handed to the sink.
    case handOutSnapshot
    /// The experience begins its deactivation.
    case beginDeactivation
    /// The render host and its GPU objects are destroyed.
    case destroyHost
    /// The GPU counts after the destruction are read.
    case readCounts
    /// The experience finishes its deactivation with the counts.
    case finishDeactivation
    /// The session becomes idle.
    case becomeIdle
    /// A running preparation is cancelled.
    case cancelPreparation

    /// The seven steps of a full close, in order.
    public static let order: [SessionCloseStep] = [
        .stopClock, .handOutSnapshot, .beginDeactivation, .destroyHost, .readCounts, .finishDeactivation, .becomeIdle,
    ]
    /// The two steps of a close while the experience is still preparing, in order.
    public static let cancelOrder: [SessionCloseStep] = [.cancelPreparation, .becomeIdle]
}

/// The stage of a session at which a failure happened.
public enum SessionStage: String, Sendable, Codable, CaseIterable {
    /// The preparation of the domain state.
    case prepare
    /// The restoring of a snapshot.
    case restore
    /// The creation of the render host.
    case createHost
    /// The setup of the presenter's GPU objects.
    case setup
    /// The drawing of a frame.
    case draw
    /// The recreation of the graphics context.
    case context
    /// The close.
    case close
}

/// A failure of a session: the storable failure and the stage at which it happened. Codes of the experience
/// contract are passed through unchanged.
public struct SessionFailure: Error, Sendable, Equatable, Codable {
    /// The code of a render host that could not be created.
    public static let hostFailedCode = "session.host-failed"
    /// The code of a graphics context that could not be recreated.
    public static let contextLostCode = "session.context-lost"
    /// The code of a snapshot sink that threw; it is recorded and not shown as a failure view.
    public static let sinkFailedCode = "session.sink-failed"

    /// The failure: a stable code and a text for people.
    public let failure: ExperienceFailure
    /// The stage at which it happened.
    public let stage: SessionStage

    /// Creates a session failure.
    public init(_ failure: ExperienceFailure, stage: SessionStage) {
        self.failure = failure
        self.stage = stage
    }

    /// The stable code of the failure.
    public var code: String { failure.code }
    /// The text for people.
    public var message: String { failure.message }
}

/// The durations of the stages of an open, in seconds. A stage that did not happen has no duration.
public struct SessionStageTimings: Sendable, Equatable, Codable {
    /// The preparation of the domain state.
    public var prepare: Double?
    /// The creation of the render host.
    public var createHost: Double?
    /// The activation of the experience.
    public var activate: Double?
    /// The first frame.
    public var firstFrame: Double?

    /// Creates timings without any duration.
    public init() {}
}

/// The answer to an open.
public enum SessionOpenResult: Sendable, Equatable {
    /// The experience runs.
    case running
    /// The experience is prepared and waits for the app to become active.
    case suspended
    /// The open failed; the session is in the failed state.
    case failed(SessionFailure)
    /// The session was closed while the experience prepared.
    case cancelled
    /// A newer open took the place of this one.
    case superseded
}

/// The rule that decides, after caches were shed, whether a memory warning closes the experience.
public enum MemoryPressureRule {
    /// The limit in bytes: the requested value when one is given, else half of the budget's total; never below 1.
    public static func limit(requested: Int?, budgetTotal: Int) -> Int {
        max(1, requested ?? budgetTotal / 2)
    }

    /// Whether the experience is closed: only when the live bytes are above the limit.
    public static func shouldClose(liveBytes: Int, limit: Int) -> Bool {
        liveBytes > limit
    }
}

/// The lifecycle of a session as a pure value: the state, the transition table and a counter of refusals.
public struct SessionLifecycle: Sendable, Equatable {
    /// The current state; a new lifecycle is idle.
    public private(set) var state: SessionState
    /// Transitions that were refused.
    public private(set) var rejectedTransitions: Int

    /// Creates an idle lifecycle.
    public init() {
        state = .idle
        rejectedTransitions = 0
    }

    /// Whether the transition is one of the 17 legal pairs; a state with itself is never legal.
    public static func isAllowed(from: SessionState, to: SessionState) -> Bool {
        switch from {
        case .idle: to == .preparing
        case .preparing: to == .running || to == .suspended || to == .failed || to == .closing
        case .running: to == .suspended || to == .failed || to == .closing
        case .suspended: to == .running || to == .failed || to == .closing
        case .failed: to == .preparing || to == .idle
        case .message: to == .idle || to == .preparing
        case .closing: to == .idle || to == .message
        }
    }

    /// Moves to `next` when the transition is legal and returns true; a refusal keeps the state, is counted and
    /// returns false.
    @discardableResult
    public mutating func transition(to next: SessionState) -> Bool {
        guard Self.isAllowed(from: state, to: next) else {
            rejectedTransitions += 1
            return false
        }
        state = next
        return true
    }
}

/// The readable state of a session at one moment: what a tester, the verification runner and a failure report
/// read. An item that does not exist is nil and is left out of the encoded form; nothing is made up.
public struct SessionDiagnostics: Sendable, Equatable, Codable {
    /// The state of the session.
    public var state: SessionState
    /// The open experience; nil when the session is idle.
    public var experience: ExperienceID?
    /// The diagnostics of the open experience; nil without one.
    public var experienceDiagnostics: ExperienceDiagnostics?
    /// The durations of the stages of the last open.
    public var timings: SessionStageTimings
    /// The GPU counts read after the last close; nil before the first close.
    public var lastCloseCounts: GPUResourceCounts?
    /// Opens that were started.
    public var opens: Int
    /// Full closes that were carried out.
    public var closes: Int
    /// Failures that were recorded.
    public var failures: Int
    /// Preparations that were cancelled by a close.
    public var cancelledPreparations: Int
    /// Opens whose place a newer open took.
    public var supersededOpens: Int
    /// Closes caused by memory pressure.
    public var memoryClosures: Int
    /// Recreations of the graphics context.
    public var contextRecreations: Int
    /// Snapshots the sink refused by throwing.
    public var sinkFailures: Int
    /// State transitions that were refused.
    public var rejectedTransitions: Int
    /// The last failure; it stays after the failure view was left.
    public var lastFailure: SessionFailure?
    /// The steps the last close took, in order.
    public var lastCloseSteps: [SessionCloseStep]

    /// Creates a diagnostics value.
    public init(state: SessionState, experience: ExperienceID?, experienceDiagnostics: ExperienceDiagnostics?,
                timings: SessionStageTimings, lastCloseCounts: GPUResourceCounts?, opens: Int, closes: Int,
                failures: Int, cancelledPreparations: Int, supersededOpens: Int, memoryClosures: Int,
                contextRecreations: Int, sinkFailures: Int, rejectedTransitions: Int, lastFailure: SessionFailure?,
                lastCloseSteps: [SessionCloseStep]) {
        self.state = state
        self.experience = experience
        self.experienceDiagnostics = experienceDiagnostics
        self.timings = timings
        self.lastCloseCounts = lastCloseCounts
        self.opens = opens
        self.closes = closes
        self.failures = failures
        self.cancelledPreparations = cancelledPreparations
        self.supersededOpens = supersededOpens
        self.memoryClosures = memoryClosures
        self.contextRecreations = contextRecreations
        self.sinkFailures = sinkFailures
        self.rejectedTransitions = rejectedTransitions
        self.lastFailure = lastFailure
        self.lastCloseSteps = lastCloseSteps
    }

    /// The value as JSON with keys in sorted order, for evidence files.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}
