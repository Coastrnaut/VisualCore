// ExperienceOpenRequest — feature 189 T-U03-007 (FR-U03-003, FR-U03-012, FR-U03-022; research R2; contract
// specs/189-ua-f03-experience-host/contracts/session-api.md). What an opener hands to the session: a factory for
// the experience, the seed, an optional stored snapshot, the resource budget of the render host, the
// memory-pressure limit and the time limit of the preparation.
import VisualCoreDiagnostics
import VisualCoreExperience

/// A request to open one experience in an `ExperienceSession`.
///
/// The session calls `make` on the main actor only after it closed what was open before, so that two experiences
/// never exist side by side.
public struct ExperienceOpenRequest {
    /// The experience to open.
    public let id: ExperienceID
    /// Builds the experience. Called once per open, on the main actor.
    public let make: @MainActor () -> any Experience
    /// The seed of the preparation.
    public var seed: UInt64
    /// A stored snapshot to restore after the preparation; a refused snapshot is recorded and the open goes on.
    public var snapshot: ExperienceSnapshot?
    /// The resource budget of the render host the session creates.
    public var budget: ResourceBudget
    /// Live bytes above which a memory warning closes the experience; nil means half of the budget's total.
    public var memoryPressureLimit: Int?
    /// The time limit of the preparation.
    public var timeLimit: Duration

    /// Creates a request. Defaults: no snapshot, the default budget, half of the budget's total as the
    /// memory-pressure limit and 10 seconds for the preparation.
    public init(id: ExperienceID, seed: UInt64, snapshot: ExperienceSnapshot? = nil,
                budget: ResourceBudget = ResourceBudget(), memoryPressureLimit: Int? = nil,
                timeLimit: Duration = .seconds(10), make: @escaping @MainActor () -> any Experience) {
        self.id = id
        self.make = make
        self.seed = seed
        self.snapshot = snapshot
        self.budget = budget
        self.memoryPressureLimit = memoryPressureLimit
        self.timeLimit = timeLimit
    }
}
