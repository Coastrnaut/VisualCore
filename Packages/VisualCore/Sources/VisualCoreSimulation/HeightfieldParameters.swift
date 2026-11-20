// HeightfieldParameters — feature 217 (R02-F17) T-R02F17-002 (FR-R02F17-001, FR-R02F17-003, FR-R02F17-006;
// clarifications Q2–Q4; data-model.md). The edge kind, the constants of the pipe-flow and erosion laws with their
// ranges, the ledger that accounts for every quantum added, removed or drained, and the report of one frame step.

/// What happens at the grid's border.
public enum HeightfieldEdges: String, Sendable, Codable, CaseIterable {
    /// Nothing crosses the border.
    case walled
    /// Water (with its dye and sediment) flows out across the border and is counted as drained.
    case open
}

/// The constants of the flow and erosion laws (clarifications Q2–Q4).
public struct HeightfieldParameters: Sendable, Equatable, Codable {
    /// Gravity g, 0 < g ≤ 100.
    public var gravity = 9.81
    /// Pipe cross-section A, 0 < A ≤ 10.
    public var pipeArea = 1.0
    /// The factor kept of each flux per sub-step, 0 … 1.
    public var damping = 0.995
    /// The longest sub-step in seconds, 0 < h ≤ 0.1.
    public var maxSubstep = 1.0 / 120
    /// The most sub-steps in one frame step, 1 … 64.
    public var maxSubsteps = 64
    /// Whether water erodes and deposits rock.
    public var erosion = false
    /// Sediment capacity constant K_c, 0 … 10.
    public var capacity = 0.05
    /// Dissolving rate K_s, 0 … 10.
    public var dissolving = 0.3
    /// Settling rate K_d, 0 … 10.
    public var depositing = 0.3

    /// The defaults.
    public init() {}

    /// These parameters, or ``HeightfieldError/invalidParameter(_:)`` naming the first one that is not finite or outside
    /// its range.
    public func validated() throws(HeightfieldError) -> HeightfieldParameters {
        func check(_ value: Double, _ name: String, _ isValid: (Double) -> Bool) throws(HeightfieldError) {
            guard value.isFinite, isValid(value) else { throw .invalidParameter(name) }
        }
        try check(gravity, "gravity") { $0 > 0 && $0 <= 100 }
        try check(pipeArea, "pipeArea") { $0 > 0 && $0 <= 10 }
        try check(damping, "damping") { $0 >= 0 && $0 <= 1 }
        try check(maxSubstep, "maxSubstep") { $0 > 0 && $0 <= 0.1 }
        guard (1...64).contains(maxSubsteps) else { throw .invalidParameter("maxSubsteps") }
        try check(capacity, "capacity") { $0 >= 0 && $0 <= 10 }
        try check(dissolving, "dissolving") { $0 >= 0 && $0 <= 10 }
        try check(depositing, "depositing") { $0 >= 0 && $0 <= 10 }
        return self
    }
}

/// Every quantum added, removed or drained, per quantity; each total equals its account's ``Account/net`` exactly.
public struct HeightfieldLedger: Sendable, Equatable, Codable {
    /// One quantity's account, in quanta.
    public struct Account: Sendable, Equatable, Codable {
        /// Quanta added by explicit operations.
        public internal(set) var added: Int64 = 0
        /// Quanta removed by explicit operations.
        public internal(set) var removed: Int64 = 0
        /// Quanta that left across open edges.
        public internal(set) var drained: Int64 = 0

        /// added − removed − drained: what the grid must hold.
        public var net: Int64 { added - removed - drained }
    }

    /// Water.
    public internal(set) var water = Account()
    /// Rock: terrain plus suspended sediment.
    public internal(set) var rock = Account()
    /// One account per dye channel.
    public internal(set) var dye: [Account]

    init(dyeChannels: Int) { dye = Array(repeating: Account(), count: dyeChannels) }
}

/// What one frame step did.
public struct HeightfieldStepReport: Sendable, Equatable {
    /// The sub-steps run.
    public let substeps: Int
    /// The length of each sub-step in seconds.
    public let substepDuration: Double
    /// The frame time not simulated because the sub-step limit was reached (0 otherwise).
    public let droppedTime: Double
    /// Whether a flux was clamped to 0 … ``Heightfield/maxFlux`` or reset from a non-finite value.
    public let fluxClamped: Bool
}
