// LissajousLabyrinthWitness — feature 312 (R02-G02-02) T-R02G0202-005 (FR-R02G0202-004; clarification Q4). The solver
// witness of one generated level: the actions of its shortest solution, the play fingerprint after the start (and the
// tutorial) and after every action, the terminal measure of the winning setting (the tick at which each checkpoint is
// first visited in order, and the minimum clearance), the near miss (from the winning setting, the single legal dial
// change of the smallest value distance that loses, ties in dial order then lower value, with its verdict) and the
// non-coprime counterexample (frequency b set to the smallest other value sharing a factor with a; when a is 1, frequency
// a set to the smallest other value sharing a factor with b; when both are 1, both set to 2), which the rules refuse with
// `r02-g02.move`. The stored form is JSON with sorted keys, pretty-printed, with one trailing newline; decoding rebuilds
// the witness by replay and refuses any stored value that the replay does not reproduce.
import Foundation

/// A losing lap verdict in stored form: `kind` is `"contact"` (with `obstacle` and `tick`) or `"missed"` (with
/// `checkpoint`).
public struct LissajousLabyrinthLoss: Sendable, Equatable, Codable {
    /// `"contact"` or `"missed"`.
    public let kind: String
    /// The touched obstacle's index for a contact, otherwise nil.
    public let obstacle: Int?
    /// The tick of the contact segment's start for a contact, otherwise nil.
    public let tick: Int?
    /// The index of the first checkpoint not reached in order for a miss, otherwise nil.
    public let checkpoint: Int?

    /// The stored form of a losing verdict; nil for `.won`.
    public init?(_ verdict: LissajousLabyrinthVerdict) {
        switch verdict {
        case .won:
            return nil
        case let .contact(obstacle, tick):
            kind = "contact"
            self.obstacle = obstacle
            self.tick = tick
            checkpoint = nil
        case let .missed(checkpoint):
            kind = "missed"
            obstacle = nil
            tick = nil
            self.checkpoint = checkpoint
        }
    }

    /// The verdict this stored form names, or nil when its fields do not describe one.
    public var verdict: LissajousLabyrinthVerdict? {
        switch (kind, obstacle, tick, checkpoint) {
        case let ("contact", obstacle?, tick?, nil): .contact(obstacle: obstacle, tick: tick)
        case let ("missed", nil, nil, checkpoint?): .missed(checkpoint: checkpoint)
        default: nil
        }
    }
}

/// The near miss of a winning setting: one legal dial change that loses, and the verdict that proves it.
public struct LissajousLabyrinthNearMiss: Sendable, Equatable, Codable {
    /// The single dial change from the winning setting.
    public let action: LissajousLabyrinthAction
    /// The losing dials it reaches.
    public let dials: LissajousLabyrinthDials
    /// The losing verdict of those dials.
    public let verdict: LissajousLabyrinthLoss

    /// A near miss of the given values (not checked; ``LissajousLabyrinthWitness`` checks it).
    public init(action: LissajousLabyrinthAction, dials: LissajousLabyrinthDials, verdict: LissajousLabyrinthLoss) {
        self.action = action
        self.dials = dials
        self.verdict = verdict
    }
}

/// The non-coprime counterexample of a winning setting: dial changes whose last one the rules refuse because the two
/// frequencies would share a factor.
public struct LissajousLabyrinthNonCoprime: Sendable, Equatable, Codable {
    /// The frequency changes in order; every one but the last is accepted by the rules, the last is refused.
    public let actions: [LissajousLabyrinthAction]
    /// The dials with every change applied; their frequencies share a factor, so they are invalid.
    public let dials: LissajousLabyrinthDials
    /// The refusal's reason code, `r02-g02.move`.
    public let reason: String

    /// A counterexample of the given values (not checked; ``LissajousLabyrinthWitness`` checks it).
    public init(actions: [LissajousLabyrinthAction], dials: LissajousLabyrinthDials, reason: String) {
        self.actions = actions
        self.dials = dials
        self.reason = reason
    }
}

/// The terminal measure of a winning setting.
public struct LissajousLabyrinthTerminal: Sendable, Equatable, Codable {
    /// The tick at which each checkpoint is first visited, in checkpoint order (the in-order scan of the lap verdict).
    public let visits: [Int]
    /// The minimum clearance (``LissajousLabyrinthDifficulty/clearance(_:level:)``).
    public let clearance: Int

    /// A terminal measure of the given values.
    public init(visits: [Int], clearance: Int) {
        self.visits = visits
        self.clearance = clearance
    }

    /// The terminal measure of `dials` on `level`.
    public init(_ dials: LissajousLabyrinthDials, level: LissajousLabyrinthLevel) {
        let points: [LissajousLabyrinthPoint] = LissajousLabyrinthLap.samples(dials, level: level)
        var visits: [Int] = []
        var next: Int = 0
        for n in 0..<LissajousLabyrinthLap.ticks where next < level.checkpoints.count {
            if LissajousLabyrinthLap.contains(level.checkpoints[next], points[n]) {
                visits.append(n)
                next += 1
            }
        }
        self.init(visits: visits, clearance: LissajousLabyrinthDifficulty.clearance(dials, level: level))
    }
}

/// A generated level: its manifest entry, the level, its proven shortest solution, its difficulty and the candidates
/// skipped before it.
public struct LissajousLabyrinthGenerated: Sendable, Equatable {
    /// The manifest entry the level was generated from.
    public let entry: LissajousLabyrinthManifestEntry
    /// The level.
    public let level: LissajousLabyrinthLevel
    /// Its shortest solution.
    public let solution: LissajousLabyrinthSolution
    /// Its difficulty.
    public let difficulty: LissajousLabyrinthDifficulty
    /// The candidates skipped before this one, 0 … 63.
    public let skipped: Int

    /// A generated level of the given values.
    public init(entry: LissajousLabyrinthManifestEntry, level: LissajousLabyrinthLevel,
                solution: LissajousLabyrinthSolution, difficulty: LissajousLabyrinthDifficulty, skipped: Int) {
        self.entry = entry
        self.level = level
        self.solution = solution
        self.difficulty = difficulty
        self.skipped = skipped
    }
}

/// The replayable proof that a generated Lissajous Labyrinth level is won by its shortest solution, lost by a near miss
/// and guarded by the coprime rule.
public struct LissajousLabyrinthWitness: Sendable, Equatable, Codable {
    /// The stored-form schema.
    public static var schema: Int { 1 }

    /// The manifest number of the level, 1 … 100.
    public let number: Int
    /// The level.
    public let level: LissajousLabyrinthLevel
    /// The actions of the shortest solution, in order.
    public let actions: [LissajousLabyrinthAction]
    /// The play fingerprint after `begin` (and `dismissTutorial` when the level has a tutorial), then after each action.
    public let fingerprints: [String]
    /// The visit ticks and minimum clearance of the winning setting.
    public let terminal: LissajousLabyrinthTerminal
    /// The nearest losing single dial change from the winning setting.
    public let nearMiss: LissajousLabyrinthNearMiss
    /// The frequency change the rules refuse because the frequencies would share a factor.
    public let nonCoprime: LissajousLabyrinthNonCoprime
    /// The level's difficulty.
    public let difficulty: LissajousLabyrinthDifficulty
    /// The candidates the generator skipped before accepting this level.
    public let skipped: Int

    /// A witness of the given values (not checked).
    private init(number: Int, level: LissajousLabyrinthLevel, actions: [LissajousLabyrinthAction],
                 fingerprints: [String], terminal: LissajousLabyrinthTerminal, nearMiss: LissajousLabyrinthNearMiss,
                 nonCoprime: LissajousLabyrinthNonCoprime, difficulty: LissajousLabyrinthDifficulty, skipped: Int) {
        self.number = number
        self.level = level
        self.actions = actions
        self.fingerprints = fingerprints
        self.terminal = terminal
        self.nearMiss = nearMiss
        self.nonCoprime = nonCoprime
        self.difficulty = difficulty
        self.skipped = skipped
    }

    /// The witness of a generated level, built by replaying its solution on a new play.
    ///
    /// - Throws: `.witness("replay")` when an event or action is refused, the actions do not end in a win or the play's
    ///   final dials are not the solution's setting; `.witness("counterexample")` when no single legal dial change from
    ///   the winning setting loses.
    public static func make(_ generated: LissajousLabyrinthGenerated) throws(LissajousLabyrinthError) -> Self {
        let level: LissajousLabyrinthLevel = generated.level
        let actions: [LissajousLabyrinthAction] = generated.solution.actions
        let replayed: Replay = try replay(level: level, actions: actions)
        guard replayed.play.stage == .won, replayed.play.dials == generated.solution.setting else {
            throw .witness("replay")
        }
        let winning: LissajousLabyrinthDials = replayed.play.dials
        guard let nearMiss = nearMiss(of: winning, level: level) else { throw .witness("counterexample") }
        return Self(number: generated.entry.number, level: level, actions: actions,
                    fingerprints: replayed.fingerprints, terminal: LissajousLabyrinthTerminal(winning, level: level),
                    nearMiss: nearMiss, nonCoprime: nonCoprime(of: winning), difficulty: generated.difficulty,
                    skipped: generated.skipped)
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
            preconditionFailure("a Lissajous Labyrinth witness of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored witness and re-verifies it: the actions are replayed on a new play of the stored level and every
    /// stored value must be reproduced.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.witness("damaged")` for unreadable JSON, missing keys or a schema
    ///   below 1; `.witness("level")` for a level the level rules refuse (an edited field breaks its fingerprint);
    ///   `.witness(part)` with `"replay"` (a refused action, no win), `"fingerprints"`, `"terminal"`, `"nearMiss"`,
    ///   `"nonCoprime"` or `"difficulty"` for a value the replay does not reproduce.
    public static func decode(_ data: Data) throws(LissajousLabyrinthError) -> Self {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .witness("damaged") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .witness("damaged") }
        let stored: Self
        do {
            stored = try JSONDecoder().decode(Self.self, from: data)
        } catch is LevelRefusal {
            throw .witness("level")
        } catch {
            throw .witness("damaged")
        }
        try stored.verify()
        return stored
    }

    /// Re-verifies every stored value by replay.
    private func verify() throws(LissajousLabyrinthError) {
        let replayed: Replay = try Self.replay(level: level, actions: actions)
        guard replayed.fingerprints == fingerprints else { throw .witness("fingerprints") }
        guard replayed.play.stage == .won else { throw .witness("replay") }
        let winning: LissajousLabyrinthDials = replayed.play.dials
        guard LissajousLabyrinthTerminal(winning, level: level) == terminal else { throw .witness("terminal") }
        guard let recomputed = Self.nearMiss(of: winning, level: level), recomputed == nearMiss,
              let verdict = nearMiss.verdict.verdict,
              LissajousLabyrinthLap.verdict(nearMiss.dials, level: level) == verdict else {
            throw .witness("nearMiss")
        }
        guard Self.nonCoprime(of: winning) == nonCoprime, Self.isRefused(nonCoprime, from: winning, level: level) else {
            throw .witness("nonCoprime")
        }
        guard difficulty.shortest == actions.count,
              difficulty.clearance == LissajousLabyrinthDifficulty.clearance(winning, level: level) else {
            throw .witness("difficulty")
        }
    }

    /// A finished replay: the play and the fingerprints after the start and after each action.
    private struct Replay {
        let play: LissajousLabyrinthPlay
        let fingerprints: [String]
    }

    /// Replays `actions` on a new play of `level` after `begin` (and `dismissTutorial` when the level has a tutorial).
    ///
    /// - Throws: `.witness("replay")` when an event or an action is refused.
    private static func replay(level: LissajousLabyrinthLevel,
                               actions: [LissajousLabyrinthAction]) throws(LissajousLabyrinthError) -> Replay {
        var play = LissajousLabyrinthPlay(level: level)
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
        return Replay(play: play, fingerprints: fingerprints)
    }

    /// The near miss of `winning` on `level`: among the single dial changes the rules accept, the one of the smallest
    /// |value − current| that loses, ties in dial order (frequencyA, frequencyB, phaseA, phaseC) then lower value; nil
    /// when every legal change wins.
    static func nearMiss(of winning: LissajousLabyrinthDials,
                         level: LissajousLabyrinthLevel) -> LissajousLabyrinthNearMiss? {
        struct Candidate {
            let distance: Int
            let order: Int
            let action: LissajousLabyrinthAction
            let dials: LissajousLabyrinthDials
        }
        let rules = LissajousLabyrinthRules(level: level)
        var candidates: [Candidate] = []
        let dials: [LissajousLabyrinthDial] = LissajousLabyrinthDial.allCases
        for order in dials.indices {
            let dial: LissajousLabyrinthDial = dials[order]
            for value in dial.range {
                let action = LissajousLabyrinthAction(dial: dial, value: value)
                guard let next = rules.apply(action, to: winning) else { continue }
                candidates.append(Candidate(distance: abs(value - winning[dial]), order: order, action: action,
                                            dials: next))
            }
        }
        candidates.sort { lhs, rhs in
            if lhs.distance != rhs.distance { return lhs.distance < rhs.distance }
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.action.value < rhs.action.value
        }
        for candidate in candidates {
            if let loss = LissajousLabyrinthLoss(LissajousLabyrinthLap.verdict(candidate.dials, level: level)) {
                return LissajousLabyrinthNearMiss(action: candidate.action, dials: candidate.dials, verdict: loss)
            }
        }
        return nil
    }

    /// The non-coprime counterexample of `winning`: frequency b set to the smallest other value 1 … 9 sharing a factor
    /// with a; when a is 1, frequency a set to the smallest other value sharing a factor with b; when both are 1, a then
    /// b set to 2.
    static func nonCoprime(of winning: LissajousLabyrinthDials) -> LissajousLabyrinthNonCoprime {
        let a: Int = winning.frequencyA
        let b: Int = winning.frequencyB
        var actions: [LissajousLabyrinthAction] = []
        if a == 1 && b == 1 {
            actions = [LissajousLabyrinthAction(dial: .frequencyA, value: 2),
                       LissajousLabyrinthAction(dial: .frequencyB, value: 2)]
        } else if a == 1 {
            for value in LissajousLabyrinthDial.frequencyA.range where value != a {
                if LissajousLabyrinthDials.gcd(value, b) > 1 {
                    actions = [LissajousLabyrinthAction(dial: .frequencyA, value: value)]
                    break
                }
            }
        } else {
            for value in LissajousLabyrinthDial.frequencyB.range where value != b {
                if LissajousLabyrinthDials.gcd(a, value) > 1 {
                    actions = [LissajousLabyrinthAction(dial: .frequencyB, value: value)]
                    break
                }
            }
        }
        var dials: LissajousLabyrinthDials = winning
        for action in actions { dials[action.dial] = action.value }
        return LissajousLabyrinthNonCoprime(actions: actions, dials: dials,
                                            reason: LissajousLabyrinthError.move("not-coprime").reasonCode)
    }

    /// Whether the rules of `level` accept every change of `counterexample` but the last from `winning` and refuse the
    /// last, its dials are invalid and its reason is `r02-g02.move`.
    static func isRefused(_ counterexample: LissajousLabyrinthNonCoprime, from winning: LissajousLabyrinthDials,
                          level: LissajousLabyrinthLevel) -> Bool {
        guard let last = counterexample.actions.last, !counterexample.dials.isValid,
              counterexample.reason == LissajousLabyrinthError.move("not-coprime").reasonCode else { return false }
        let rules = LissajousLabyrinthRules(level: level)
        var state: LissajousLabyrinthDials = winning
        for action in counterexample.actions.dropLast() {
            guard let next = rules.apply(action, to: state) else { return false }
            state = next
        }
        guard rules.apply(last, to: state) == nil else { return false }
        state[last.dial] = last.value
        return state == counterexample.dials
    }

    /// The error a stored level that the level rules refuse raises while decoding.
    private struct LevelRefusal: Error {}

    private enum CodingKeys: String, CodingKey {
        case schema, number, level, actions, fingerprints, terminal, nearMiss, nonCoprime, difficulty, skipped
    }

    /// Decodes the stored fields without re-verifying them; ``decode(_:)`` decodes and re-verifies.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let schema: Int = try c.decode(Int.self, forKey: .schema)
        guard (1...Self.schema).contains(schema) else {
            throw DecodingError.dataCorruptedError(forKey: .schema, in: c, debugDescription: "schema \(schema)")
        }
        number = try c.decode(Int.self, forKey: .number)
        do { level = try c.decode(LissajousLabyrinthLevel.self, forKey: .level) } catch { throw LevelRefusal() }
        actions = try c.decode([LissajousLabyrinthAction].self, forKey: .actions)
        fingerprints = try c.decode([String].self, forKey: .fingerprints)
        terminal = try c.decode(LissajousLabyrinthTerminal.self, forKey: .terminal)
        nearMiss = try c.decode(LissajousLabyrinthNearMiss.self, forKey: .nearMiss)
        nonCoprime = try c.decode(LissajousLabyrinthNonCoprime.self, forKey: .nonCoprime)
        difficulty = try c.decode(LissajousLabyrinthDifficulty.self, forKey: .difficulty)
        skipped = try c.decode(Int.self, forKey: .skipped)
    }

    /// Encodes the stored form with ``schema``.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.schema, forKey: .schema)
        try c.encode(number, forKey: .number)
        try c.encode(level, forKey: .level)
        try c.encode(actions, forKey: .actions)
        try c.encode(fingerprints, forKey: .fingerprints)
        try c.encode(terminal, forKey: .terminal)
        try c.encode(nearMiss, forKey: .nearMiss)
        try c.encode(nonCoprime, forKey: .nonCoprime)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(skipped, forKey: .skipped)
    }
}
