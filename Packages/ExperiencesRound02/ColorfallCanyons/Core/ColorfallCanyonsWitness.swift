// ColorfallCanyonsWitness — feature 342 (R02-G05-02) T-R02G0502-005 (FR-R02G0502-004; SC-R02G0502-003, 005;
// clarification Q4). The solver witness of one generated level: the actions (the smallest edit set as carve and valve
// actions in solver order, then `step(tick limit)`), the win tick, the 16-hex fluid digest after every tick up to the
// win, the released, held and spilled totals per colour at the win, the play fingerprints after `begin` (and
// `dismissTutorial`) and after each action, the unedited counterexample and the near miss (the edits without the last
// one), each with its failure reason and tick, the number of smaller edit sets simulated (all failing), the difficulty
// and the candidates skipped. The stored form is JSON with sorted keys, pretty-printed, with one trailing newline.
// Making and decoding both rebuild the witness from its level and actions — the replay on a `ColorfallCanyonsPlay`, the
// per-tick digests of a `ColorfallCanyonsFluid` stepped tick by tick after the edits, the totals and the
// counterexamples through `ColorfallCanyonsSolver.run` — and refuse any value the rebuild does not reproduce. Decoding
// also re-runs `ColorfallCanyonsSolver.solve` to the band's search depth (as the generator does), so a stored edit set
// that is not the first smallest one, a wrong `smaller` count or a wrong work count is refused.
import Foundation
import VisualCoreMath

/// A failing edit set of a witness: the edits, why the run to the tick limit fails and at which tick.
public struct ColorfallCanyonsCounterexample: Sendable, Equatable, Codable {
    /// The edits applied before the first tick, in solver order.
    public let edits: [ColorfallCanyonsEdit]
    /// Why the run fails.
    public let reason: ColorfallCanyonsFailure
    /// The tick at which the failure is decided.
    public let tick: Int

    /// A counterexample of the given values.
    public init(edits: [ColorfallCanyonsEdit], reason: ColorfallCanyonsFailure, tick: Int) {
        self.edits = edits
        self.reason = reason
        self.tick = tick
    }
}

/// The replayable proof that a generated Colorfall Canyons level is won by its smallest edit set, lost without edits
/// and lost by the near miss (clarification Q4).
public struct ColorfallCanyonsWitness: Sendable, Equatable, Codable {
    /// The stored-form schema.
    public static let schema: Int = 1

    /// The units of each colour (cyan, coral, yellow) at the win.
    public struct Totals: Sendable, Equatable, Codable {
        /// The units each colour's springs have released.
        public let released: [Int]
        /// The units of each colour held in cells, basins included.
        public let held: [Int]
        /// The units of each colour that reached a drain.
        public let spilled: [Int]

        /// Totals of the given values.
        public init(released: [Int], held: [Int], spilled: [Int]) {
            self.released = released
            self.held = held
            self.spilled = spilled
        }

        /// The totals of `fluid`.
        public init(_ fluid: ColorfallCanyonsFluid) {
            var held: [Int] = [0, 0, 0]
            for cell in fluid.masses {
                for c in 0..<3 { held[c] += cell[c] }
            }
            self.init(released: fluid.released, held: held, spilled: fluid.spilled)
        }
    }

    /// The manifest number of the level, 1 … 100.
    public let number: Int
    /// The level, stored in its own fingerprinted form.
    public let level: ColorfallCanyonsLevel
    /// The actions: the smallest edit set as carve and valve actions in solver order, then `step(tick limit)` (split
    /// into steps of at most 600 ticks, ending with the one that reaches the win, when the tick limit exceeds 600).
    public let actions: [ColorfallCanyonsAction]
    /// The tick at which the actions win.
    public let winTick: Int
    /// The fluid digest (``digest(_:)``) after every tick 1 … ``winTick``.
    public let digests: [String]
    /// The totals per colour at the win.
    public let totals: Totals
    /// The play fingerprints after `begin` (and `dismissTutorial` when the level has a tutorial) and after each action.
    public let fingerprints: [String]
    /// The run without edits, which fails.
    public let unedited: ColorfallCanyonsCounterexample
    /// The run of the edits without the last one, which fails (equal to ``unedited`` when one edit wins).
    public let nearMiss: ColorfallCanyonsCounterexample
    /// The distinct routings of fewer edits that the solver simulated, every one failing.
    public let smaller: Int
    /// The level's difficulty.
    public let difficulty: ColorfallCanyonsDifficulty
    /// The candidates the generator skipped before this level.
    public let skipped: Int

    /// A witness of the given values, unchecked (``make(_:)`` and ``decode(_:)`` check).
    init(number: Int, level: ColorfallCanyonsLevel, actions: [ColorfallCanyonsAction], winTick: Int, digests: [String],
         totals: Totals, fingerprints: [String], unedited: ColorfallCanyonsCounterexample,
         nearMiss: ColorfallCanyonsCounterexample, smaller: Int, difficulty: ColorfallCanyonsDifficulty, skipped: Int) {
        self.number = number
        self.level = level
        self.actions = actions
        self.winTick = winTick
        self.digests = digests
        self.totals = totals
        self.fingerprints = fingerprints
        self.unedited = unedited
        self.nearMiss = nearMiss
        self.smaller = smaller
        self.difficulty = difficulty
        self.skipped = skipped
    }

    /// The actions of `solution` on `level`: each edit as its carve or valve action in solver order, then
    /// `step(level.tickLimit)`. A tick limit above 600 (never generated) is split into steps of at most 600 ticks,
    /// ending with the step that reaches the solution's win tick.
    public static func actions(for solution: ColorfallCanyonsSolution,
                               level: ColorfallCanyonsLevel) -> [ColorfallCanyonsAction] {
        actions(edits: solution.edits, winTick: solution.winTick, tickLimit: level.tickLimit)
    }

    /// The fluid digest of `fluid`: the first 16 lowercase hex characters of `StableHash.sha256Hex` over every cell's
    /// masses, cells in index order, colours in the order cyan, coral, yellow, each mass as two bytes big-endian (a
    /// level's total supply is at most 3 × 999 units, so every mass fits).
    public static func digest(_ fluid: ColorfallCanyonsFluid) -> String {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(fluid.masses.count * 6)
        for cell in fluid.masses {
            for mass in cell {
                bytes.append(UInt8(truncatingIfNeeded: mass >> 8))
                bytes.append(UInt8(truncatingIfNeeded: mass))
            }
        }
        return String(StableHash.sha256Hex(bytes).prefix(16))
    }

    /// The witness of a generated level, built by replaying its solution.
    ///
    /// - Throws: `.witness(part)` for any part the rebuild refuses: `"actions"`, `"replay"` (a refused action, no win
    ///   or a win at another tick than the solution's), `"digests"`, `"unedited"` or `"near-miss"` (a counterexample
    ///   that wins or is not allowed), `"difficulty"` (not the difficulty of the solution and level), `"number"` or
    ///   `"skipped"`.
    public static func make(_ generated: ColorfallCanyonsGenerated) throws(ColorfallCanyonsError) -> Self {
        let solution: ColorfallCanyonsSolution = generated.solution
        let witness: Self = try build(number: generated.entry.number, level: generated.level,
                                      actions: actions(for: solution, level: generated.level), solution: solution,
                                      skipped: generated.skipped)
        guard witness.winTick == solution.winTick else { throw .witness("replay") }
        guard witness.difficulty == generated.difficulty else { throw .witness("difficulty") }
        return witness
    }

    /// The stored form: JSON with sorted keys, pretty-printed, without escaped slashes, followed by one newline.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        do {
            var data: Data = try encoder.encode(self)
            data.append(0x0A)
            return data
        } catch {
            preconditionFailure("a Colorfall Canyons witness of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored witness and re-verifies it by rebuilding it from its level and actions, re-running the solver
    /// to the band's search depth (the level's difficulty is its band) as the generator does.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.malformed(description)` for unreadable JSON, missing keys or a
    ///   schema below 1; `.witness("level")` for a level the level rules refuse (an edited field breaks its
    ///   fingerprint); `.witness(part)` with `"actions"` (not the canonical actions of their edits), `"replay"` (a
    ///   refused action or no win), `"difficulty"` (the edits are not the solver's first smallest set, or a metric
    ///   differs), `"number"`, `"skipped"`, `"win-tick"`, `"digests"`, `"totals"`, `"fingerprints"`, `"unedited"`,
    ///   `"near-miss"` or `"smaller"` for a value the rebuild does not reproduce.
    public static func decode(_ data: Data) throws(ColorfallCanyonsError) -> Self {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let stored: Self
        do {
            stored = try JSONDecoder().decode(Self.self, from: data)
        } catch is LevelRefusal {
            throw .witness("level")
        } catch {
            throw .malformed("unreadable")
        }
        let rebuilt: Self = try build(number: stored.number, level: stored.level, actions: stored.actions,
                                      solution: nil, skipped: stored.skipped)
        guard rebuilt.winTick == stored.winTick else { throw .witness("win-tick") }
        guard rebuilt.digests == stored.digests else { throw .witness("digests") }
        guard rebuilt.totals == stored.totals else { throw .witness("totals") }
        guard rebuilt.fingerprints == stored.fingerprints else { throw .witness("fingerprints") }
        guard rebuilt.unedited == stored.unedited else { throw .witness("unedited") }
        guard rebuilt.nearMiss == stored.nearMiss else { throw .witness("near-miss") }
        guard rebuilt.smaller == stored.smaller else { throw .witness("smaller") }
        guard rebuilt.difficulty == stored.difficulty else { throw .witness("difficulty") }
        return stored
    }

    /// The edit actions of `edits` in order, then steps of at most 600 ticks covering the tick limit, ending with the
    /// step that reaches `winTick`.
    static func actions(edits: [ColorfallCanyonsEdit], winTick: Int, tickLimit: Int) -> [ColorfallCanyonsAction] {
        var result: [ColorfallCanyonsAction] = edits.map(\.action)
        let largest: Int = ColorfallCanyonsPlay.steps.upperBound
        let end: Int = min(max(winTick, 1), tickLimit)
        var covered: Int = 0
        repeat {
            let ticks: Int = min(largest, tickLimit - covered)
            result.append(.step(ticks))
            covered += ticks
        } while covered < end
        return result
    }

    /// The leading carve and valve actions of `actions` as edits; nil when a carve or valve follows a step.
    static func edits(of actions: [ColorfallCanyonsAction]) -> [ColorfallCanyonsEdit]? {
        var edits: [ColorfallCanyonsEdit] = []
        var stepping: Bool = false
        for action in actions {
            switch action {
            case .carve(let cell):
                guard !stepping else { return nil }
                edits.append(.carve(cell))
            case .valve(let spring):
                guard !stepping else { return nil }
                edits.append(.valve(spring))
            case .step: stepping = true
            }
        }
        return edits
    }

    /// The failing run of `edits` on `level` as a counterexample, or nil when the set is not allowed or wins.
    static func counterexample(_ level: ColorfallCanyonsLevel,
                               edits: [ColorfallCanyonsEdit]) -> ColorfallCanyonsCounterexample? {
        guard let run = ColorfallCanyonsSolver.run(level, edits: edits),
              case .failed(let reason) = run.verdict else { return nil }
        return ColorfallCanyonsCounterexample(edits: edits, reason: reason, tick: run.tick)
    }

    /// Rebuilds a witness from its level and actions, checking every part. With `solution` nil the solver is re-run to
    /// the band's search depth and its first smallest set must be the witness's edits.
    private static func build(number: Int, level: ColorfallCanyonsLevel, actions: [ColorfallCanyonsAction],
                              solution: ColorfallCanyonsSolution?,
                              skipped: Int) throws(ColorfallCanyonsError) -> Self {
        // The edits, their win and the canonical action shape.
        guard let edits = edits(of: actions), edits == edits.sorted(),
              let run = ColorfallCanyonsSolver.run(level, edits: edits) else { throw .witness("actions") }
        guard run.verdict == .won else { throw .witness("replay") }
        let winTick: Int = run.tick
        guard actions == Self.actions(edits: edits, winTick: winTick, tickLimit: level.tickLimit) else {
            throw .witness("actions")
        }
        // Replay on a new play.
        var play = ColorfallCanyonsPlay(level: level)
        var fingerprints: [String] = []
        do {
            try play.handle(.begin)
            if level.tutorial { try play.handle(.dismissTutorial) }
            fingerprints.append(play.fingerprint)
            for action in actions {
                try play.apply(action, expecting: play.fingerprint)
                fingerprints.append(play.fingerprint)
            }
        } catch {
            throw .witness("replay")
        }
        guard play.stage == .won, play.fluid.tick == winTick else { throw .witness("replay") }
        // Per-tick digests of the edited fluid, stepped tick by tick to the win.
        guard var fluid = ColorfallCanyonsSolver.edited(level, edits: edits) else { throw .witness("actions") }
        var digests: [String] = []
        while fluid.tick < winTick {
            fluid.tick(level: level)
            guard fluid.isConserved() else { throw .witness("digests") }
            digests.append(digest(fluid))
        }
        guard fluid == play.fluid else { throw .witness("digests") }
        // Counterexamples: no edits, and the edits without the last one.
        guard let unedited = counterexample(level, edits: []) else { throw .witness("unedited") }
        guard let nearMiss = counterexample(level, edits: Array(edits.dropLast())) else {
            throw .witness("near-miss")
        }
        // The solver's first smallest set, its smaller count and the difficulty.
        let checked: ColorfallCanyonsSolution
        if let solution {
            guard solution.edits == edits else { throw .witness("actions") }
            checked = solution
        } else {
            // The generator's depth: the solver's move set (and so its work) depends on the depth searched.
            let depth: Int = ColorfallCanyonsBandProfile.of(band: level.difficulty).smallest.upperBound
            guard edits.count <= depth, let solved = ColorfallCanyonsSolver.solve(level, depth: depth),
                  solved.edits == edits else { throw .witness("difficulty") }
            checked = solved
        }
        let difficulty = ColorfallCanyonsDifficulty(
            smallest: edits.count, work: checked.work, winTick: winTick, springs: level.springs.count,
            basins: level.basins.count, protectedBasins: level.basins.filter(\.isProtected).count,
            carvableCells: (0..<level.cellCount).filter { level.isCarvable($0, heights: level.heights) }.count)
        guard (1...100).contains(number) else { throw .witness("number") }
        guard (0..<ColorfallCanyonsGenerator.maximumCandidates).contains(skipped) else { throw .witness("skipped") }
        return Self(number: number, level: level, actions: actions, winTick: winTick, digests: digests,
                    totals: Totals(play.fluid), fingerprints: fingerprints, unedited: unedited, nearMiss: nearMiss,
                    smaller: checked.smaller, difficulty: difficulty, skipped: skipped)
    }

    /// The error a stored level that the level rules refuse raises while decoding.
    private struct LevelRefusal: Error {}

    private enum CodingKeys: String, CodingKey {
        case schema, number, level, actions, winTick, digests, totals, fingerprints, unedited, nearMiss, smaller
        case difficulty, skipped
    }

    /// Decodes the stored fields without re-verifying them; ``decode(_:)`` decodes and re-verifies.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let schema: Int = try c.decode(Int.self, forKey: .schema)
        guard (1...Self.schema).contains(schema) else {
            throw DecodingError.dataCorruptedError(forKey: .schema, in: c, debugDescription: "schema \(schema)")
        }
        number = try c.decode(Int.self, forKey: .number)
        do { level = try c.decode(ColorfallCanyonsLevel.self, forKey: .level) } catch { throw LevelRefusal() }
        actions = try c.decode([ColorfallCanyonsAction].self, forKey: .actions)
        winTick = try c.decode(Int.self, forKey: .winTick)
        digests = try c.decode([String].self, forKey: .digests)
        totals = try c.decode(Totals.self, forKey: .totals)
        fingerprints = try c.decode([String].self, forKey: .fingerprints)
        unedited = try c.decode(ColorfallCanyonsCounterexample.self, forKey: .unedited)
        nearMiss = try c.decode(ColorfallCanyonsCounterexample.self, forKey: .nearMiss)
        smaller = try c.decode(Int.self, forKey: .smaller)
        difficulty = try c.decode(ColorfallCanyonsDifficulty.self, forKey: .difficulty)
        skipped = try c.decode(Int.self, forKey: .skipped)
    }

    /// Encodes the stored form with ``schema``.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.schema, forKey: .schema)
        try c.encode(number, forKey: .number)
        try c.encode(level, forKey: .level)
        try c.encode(actions, forKey: .actions)
        try c.encode(winTick, forKey: .winTick)
        try c.encode(digests, forKey: .digests)
        try c.encode(totals, forKey: .totals)
        try c.encode(fingerprints, forKey: .fingerprints)
        try c.encode(unedited, forKey: .unedited)
        try c.encode(nearMiss, forKey: .nearMiss)
        try c.encode(smaller, forKey: .smaller)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(skipped, forKey: .skipped)
    }
}
