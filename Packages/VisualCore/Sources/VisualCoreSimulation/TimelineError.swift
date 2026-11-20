// TimelineError.swift — refusals of the event log, snapshot ring, reversible timeline and stored runs
// (feature 214 R02-F14 T-R02F14-002; FR-R02F14-007; clarification Q5).

/// Why a timeline request was refused; `reasonCode` is a stable `r2-f14.*` name for logs and tests.
public enum TimelineError: Error, Equatable, Sendable {
    /// A step below 0 was requested.
    case negativeStep
    /// A step above `EventLog.maxStep` (10,000,000) was requested; carries the step.
    case stepLimit(Int)
    /// The log would exceed `EventLog.maxEntries` (1,048,576) commands.
    case logLimit
    /// No command exists at `step` with position `index` within that step.
    case noSuchCommand(step: Int, index: Int)
    /// A snapshot ring capacity outside 1…1,024; carries the capacity.
    case ringSize(Int)
    /// A snapshot interval outside 1…65,536; carries the interval.
    case interval(Int)
    /// A replay produced a hash different from a kept one (the simulation is not deterministic).
    case hashMismatch
    /// A stored run has a schema newer than this build understands; carries the schema.
    case newerSchema(Int)
    /// A stored run could not be read; carries a short description.
    case malformed(String)

    /// The stable reason code of this refusal (`r2-f14.<name>`).
    public var reasonCode: String {
        switch self {
        case .negativeStep: return "r2-f14.negative-step"
        case .stepLimit: return "r2-f14.step-limit"
        case .logLimit: return "r2-f14.log-limit"
        case .noSuchCommand: return "r2-f14.no-such-command"
        case .ringSize: return "r2-f14.ring-size"
        case .interval: return "r2-f14.interval"
        case .hashMismatch: return "r2-f14.hash-mismatch"
        case .newerSchema: return "r2-f14.newer-schema"
        case .malformed: return "r2-f14.malformed"
        }
    }
}
