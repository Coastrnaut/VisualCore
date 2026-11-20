// PuzzleRules — feature 223 (R02-F23) T-R02F23-002 (FR-R02F23-002…004, 006; clarifications Q1…Q4). The contract a
// puzzle experience implements (pure rules: the same state always gives the same moves and results), the uniqueness a
// level promises, its fairness budget, and the verdict and statistics of a certification.

/// The pure rules of one puzzle family.
public protocol PuzzleRules: Sendable {
    /// A position of the puzzle.
    associatedtype State: Hashable & Codable & Sendable
    /// A player action.
    associatedtype Move: Hashable & Codable & Sendable
    /// The family's id, a lowercase slug of at most 64 characters, stored in every level.
    var rulesID: String { get }
    /// The legal moves in `state`, always in the same order.
    func moves(in state: State) -> [Move]
    /// The state after `move`, or nil when `move` is not legal in `state`.
    func apply(_ move: Move, to state: State) -> State?
    /// Whether `state` is solved.
    func isSolved(_ state: State) -> Bool
}

/// What a level promises about its solutions.
public enum PuzzleUniqueness: String, Sendable, Codable, CaseIterable {
    /// No promise.
    case none
    /// Exactly one solved state is reachable within the maximum length.
    case goal
    /// The level's solution is the only shortest solution.
    case solution
}

/// The bounds a fair level stays within.
public struct FairnessBudget: Sendable, Equatable, Codable {
    /// The longest allowed solution.
    public static let maxLength = 4_096
    /// The largest allowed branching bound.
    public static let maxBranching = 1_024
    /// The largest allowed node budget.
    public static let maxNodes = 1_000_000

    /// The shortest solution allowed (the level's own and the shortest one found).
    public let minLength: Int
    /// The longest solution allowed, and the depth of the certification search.
    public let maxLength: Int
    /// The most moves any reachable state may offer.
    public let maxBranching: Int
    /// The most states the certification search may discover, the start included.
    public let nodeBudget: Int

    /// A budget; refuses values outside their ranges.
    ///
    /// - Throws: `.budget("minLength")` unless 0 ≤ minLength ≤ maxLength; `.budget("maxLength")` unless
    ///   maxLength ≤ 4,096; `.budget("maxBranching")` unless 1 … 1,024; `.budget("nodeBudget")` unless 1 … 1,000,000.
    public init(minLength: Int = 1, maxLength: Int, maxBranching: Int = 64,
                nodeBudget: Int = 100_000) throws(PuzzleError) {
        guard maxLength >= 0, maxLength <= Self.maxLength else { throw .budget("maxLength") }
        guard minLength >= 0, minLength <= maxLength else { throw .budget("minLength") }
        guard maxBranching >= 1, maxBranching <= Self.maxBranching else { throw .budget("maxBranching") }
        guard nodeBudget >= 1, nodeBudget <= Self.maxNodes else { throw .budget("nodeBudget") }
        self.minLength = minLength
        self.maxLength = maxLength
        self.maxBranching = maxBranching
        self.nodeBudget = nodeBudget
    }

    private enum CodingKeys: String, CodingKey { case minLength, maxLength, maxBranching, nodeBudget }

    /// Decodes a budget and checks it with the same rules as the initialiser.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(minLength: c.decode(Int.self, forKey: .minLength), maxLength: c.decode(Int.self, forKey: .maxLength),
                          maxBranching: c.decode(Int.self, forKey: .maxBranching),
                          nodeBudget: c.decode(Int.self, forKey: .nodeBudget))
        } catch let error as PuzzleError {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: error.reasonCode))
        }
    }
}

/// The answer of a certification: valid, or the first check that failed.
public enum PuzzleVerdict: Sendable, Equatable, Hashable, Codable {
    /// Every check passed.
    case valid
    /// The level names other rules than the ones it was checked against.
    case wrongRules
    /// The solution move at this index is not legal.
    case illegalMove(Int)
    /// The solution does not end in a solved state.
    case notSolved
    /// A solution of this length is below the minimum (the level's own, or the shortest one found).
    case tooShort(Int)
    /// The level's solution has this many moves, above the maximum.
    case tooLong(Int)
    /// A reachable state offers this many moves, above the branching bound.
    case tooBranching(Int)
    /// The uniqueness promise does not hold.
    case notUnique
    /// The search reached its node budget before it could prove the level.
    case unproven

    /// The verdict's name without its payload, for counts and logs.
    public var name: String {
        switch self {
        case .valid: "valid"
        case .wrongRules: "wrongRules"
        case .illegalMove: "illegalMove"
        case .notSolved: "notSolved"
        case .tooShort: "tooShort"
        case .tooLong: "tooLong"
        case .tooBranching: "tooBranching"
        case .notUnique: "notUnique"
        case .unproven: "unproven"
        }
    }
}

/// The result of certifying a level: the verdict and what the search saw.
public struct PuzzleCertificate: Sendable, Equatable, Codable {
    /// The verdict.
    public let verdict: PuzzleVerdict
    /// The states the search discovered, the start included (0 when it did not run).
    public let explored: Int
    /// The length of the shortest solution found, if the search found one.
    public let shortest: Int?
    /// The solved states found, capped at 2.
    public let solvedStates: Int
    /// The number of shortest solutions, capped at 2.
    public let shortestPaths: Int
    /// The most moves any discovered state offered.
    public let maxBranching: Int

    /// A certificate of the given values.
    public init(verdict: PuzzleVerdict, explored: Int = 0, shortest: Int? = nil, solvedStates: Int = 0,
                shortestPaths: Int = 0, maxBranching: Int = 0) {
        self.verdict = verdict
        self.explored = explored
        self.shortest = shortest
        self.solvedStates = solvedStates
        self.shortestPaths = shortestPaths
        self.maxBranching = maxBranching
    }

    /// Whether the verdict is `.valid`.
    public var isValid: Bool { verdict == .valid }
}
