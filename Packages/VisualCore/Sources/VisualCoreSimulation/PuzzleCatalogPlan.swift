// PuzzleCatalogPlan — feature 224 (R02-F24) T-R02F24-002 (FR-R02F24-001, 002; clarifications Q1, Q2; research R2–R4).
// What a catalog is built from (an id, a seed and ordered stages), how a level's difficulty is measured from its
// certificate (shortest solution, then states explored) and the neighbour rule a catalog's order must keep.

/// The difficulty of a level, from its certificate: the shortest solution length, then the states explored.
public struct PuzzleDifficulty: Sendable, Equatable, Hashable, Codable, Comparable {
    /// The length of the shortest solution.
    public let shortest: Int
    /// The states the certification search discovered.
    public let explored: Int

    /// A difficulty of the given values.
    public init(shortest: Int, explored: Int) {
        self.shortest = shortest
        self.explored = explored
    }

    /// The difficulty of a certificate; nil when it has no shortest length.
    public init?(certificate: PuzzleCertificate) {
        guard let shortest = certificate.shortest else { return nil }
        self.init(shortest: shortest, explored: certificate.explored)
    }

    /// Ordered by shortest length, then by states explored.
    public static func < (a: PuzzleDifficulty, b: PuzzleDifficulty) -> Bool {
        (a.shortest, a.explored) < (b.shortest, b.explored)
    }
}

/// The largest drop and jump allowed between neighbouring levels' shortest lengths.
public struct ProgressionRule: Sendable, Equatable, Codable {
    /// The largest allowed drop or jump.
    public static let maxStep = 64
    /// A drop of at most 1 and a jump of at most 3.
    public static let standard = ProgressionRule(checkedDrop: 1, jump: 3)

    /// How much shorter the next level's shortest solution may be.
    public let maxDrop: Int
    /// How much longer the next level's shortest solution may be.
    public let maxJump: Int

    /// A rule; refuses values outside 0 … 64.
    ///
    /// - Throws: `.plan("maxDrop")` or `.plan("maxJump")` outside 0 … 64.
    public init(maxDrop: Int = 1, maxJump: Int = 3) throws(ContentError) {
        guard maxDrop >= 0, maxDrop <= Self.maxStep else { throw .plan("maxDrop") }
        guard maxJump >= 0, maxJump <= Self.maxStep else { throw .plan("maxJump") }
        self.init(checkedDrop: maxDrop, jump: maxJump)
    }

    private init(checkedDrop: Int, jump: Int) {
        self.maxDrop = checkedDrop
        self.maxJump = jump
    }

    private enum CodingKeys: String, CodingKey { case maxDrop, maxJump }

    /// Decodes a rule and checks it with the same rules as the initialiser.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(maxDrop: c.decode(Int.self, forKey: .maxDrop), maxJump: c.decode(Int.self, forKey: .maxJump))
        } catch let error as ContentError {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: error.reasonCode))
        }
    }

    /// The first position i ≥ 1 whose shortest length breaks the rule against position i − 1, and whether it is a
    /// drop; nil when the order keeps the rule.
    public func breach(_ difficulties: [PuzzleDifficulty]) -> (index: Int, isDrop: Bool)? {
        guard difficulties.count > 1 else { return nil }
        for i in 1..<difficulties.count {
            let previous = difficulties[i - 1].shortest, next = difficulties[i].shortest
            if next < previous - maxDrop { return (i, true) }
            if next > previous + maxJump { return (i, false) }
        }
        return nil
    }
}

/// One stage of a catalog plan: how many levels, under which budget and promise.
public struct PuzzleCatalogStage: Sendable, Equatable, Codable {
    /// The most levels in one stage.
    public static let maxCount = 500

    /// The number of levels in the stage.
    public let count: Int
    /// The fairness budget its levels are certified against.
    public let budget: FairnessBudget
    /// The uniqueness its levels promise.
    public let uniqueness: PuzzleUniqueness
    /// The generator attempts per level.
    public let attempts: Int

    /// A stage; refuses values outside their ranges.
    ///
    /// - Throws: `.plan("count")` outside 1 … 500; `.plan("attempts")` outside 1 … 10,000.
    public init(count: Int, budget: FairnessBudget, uniqueness: PuzzleUniqueness = .none,
                attempts: Int = 100) throws(ContentError) {
        guard count >= 1, count <= Self.maxCount else { throw .plan("count") }
        guard attempts >= 1, attempts <= PuzzleGenerator.maxAttempts else { throw .plan("attempts") }
        self.count = count
        self.budget = budget
        self.uniqueness = uniqueness
        self.attempts = attempts
    }

    private enum CodingKeys: String, CodingKey { case count, budget, uniqueness, attempts }

    /// Decodes a stage and checks it with the same rules as the initialiser.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(count: c.decode(Int.self, forKey: .count), budget: c.decode(FairnessBudget.self, forKey: .budget),
                          uniqueness: c.decode(PuzzleUniqueness.self, forKey: .uniqueness),
                          attempts: c.decode(Int.self, forKey: .attempts))
        } catch let error as ContentError {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: error.reasonCode))
        }
    }
}

/// What a catalog is built from: an id, a seed, ordered stages and the progression rule.
public struct PuzzleCatalogPlan: Sendable, Equatable, Codable {
    /// The most stages.
    public static let maxStages = 16
    /// The most levels in all stages together.
    public static let maxLevels = 1_000

    /// The catalog id, a lowercase slug.
    public let id: String
    /// The seed every level candidate is derived from.
    public let seed: UInt64
    /// The stages, easiest first.
    public let stages: [PuzzleCatalogStage]
    /// The rule the finished catalog's order must keep.
    public let rule: ProgressionRule

    /// A plan; refuses a bad id, no or too many stages and too many levels.
    ///
    /// - Throws: `.plan("id")` unless a lowercase slug; `.plan("stages")` outside 1 … 16 stages; `.plan("levels")`
    ///   above 1,000 levels in all.
    public init(id: String, seed: UInt64, stages: [PuzzleCatalogStage],
                rule: ProgressionRule = .standard) throws(ContentError) {
        guard PuzzleError.isSlug(id) else { throw .plan("id") }
        guard !stages.isEmpty, stages.count <= Self.maxStages else { throw .plan("stages") }
        var total = 0
        for stage in stages { total += stage.count }
        guard total <= Self.maxLevels else { throw .plan("levels") }
        self.id = id
        self.seed = seed
        self.stages = stages
        self.rule = rule
    }

    private enum CodingKeys: String, CodingKey { case id, seed, stages, rule }

    /// Decodes a plan and checks it with the same rules as the initialiser.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(id: c.decode(String.self, forKey: .id), seed: c.decode(UInt64.self, forKey: .seed),
                          stages: c.decode([PuzzleCatalogStage].self, forKey: .stages),
                          rule: c.decode(ProgressionRule.self, forKey: .rule))
        } catch let error as ContentError {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: error.reasonCode))
        }
    }
}
