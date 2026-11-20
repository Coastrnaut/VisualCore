// LissajousLabyrinthWitnessTests — feature 312 (R02-G02-02) T-R02G0202-005 (FR-R02G0202-004; clarification Q4). Witnesses
// of seeded hand-built levels: a target setting is chosen, checkpoints are put on its samples and obstacles kept only
// where its lap does not touch them, the start changes one or two of its dials, and the solution sets those dials back by
// hand (the solver is not used). The stored form round-trips byte for byte with one trailing newline; edited actions,
// fingerprints, level, terminal, near miss, non-coprime counterexample and difficulty are refused; newer and damaged
// stored forms are refused; the near miss loses with a named verdict; the non-coprime counterexample is refused by the
// rules (also when a is 1 and when a and b are 1); a solution that does not win is refused.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
@testable import LissajousLabyrinthCore
import Testing
import VisualCoreSimulation

@Suite struct LissajousLabyrinthWitnessTests {
    /// A hand-built level and the setting that wins it.
    struct Built {
        let level: LissajousLabyrinthLevel
        let target: LissajousLabyrinthDials
    }

    /// Random valid dials.
    static func dials(_ random: inout SeededRandom) -> LissajousLabyrinthDials {
        while true {
            let d = LissajousLabyrinthDials(frequencyA: random.int(1...9), frequencyB: random.int(1...9),
                                            phaseA: random.int(0...15), phaseC: random.int(0...15))
            if d.isValid { return d }
        }
    }

    /// A level won by `target` (or random target dials) whose start changes one or two of its dials; nil when the
    /// draw does not suit (the start is invalid or wins).
    static func build(_ random: inout SeededRandom, target forced: LissajousLabyrinthDials? = nil) -> Built? {
        let target: LissajousLabyrinthDials = forced ?? dials(&random)
        let amplitudes: [Int] = [random.int(1...4), random.int(1...4), random.int(1...4)]
        let frequencyC: Int = random.int(1...9)
        guard let far = try? LissajousLabyrinthBall(x: 5_000, y: 5_000, z: 5_000, radius: 64),
              let probe = try? LissajousLabyrinthLevel(id: "probe", seed: 0, band: 1, amplitudes: amplitudes,
                                                       frequencyC: frequencyC, start: target, checkpoints: [far],
                                                       obstacles: [], allowance: 8) else { return nil }
        let points: [LissajousLabyrinthPoint] = LissajousLabyrinthLap.samples(target, level: probe)
        let count: Int = random.int(2...3)
        var ticks: [Int] = []
        while ticks.count < count {
            let t: Int = random.int(0...4_095)
            if !ticks.contains(t) { ticks.append(t) }
        }
        ticks.sort()
        var checkpoints: [LissajousLabyrinthBall] = []
        for t in ticks {
            let p: LissajousLabyrinthPoint = points[t]
            guard let ball = try? LissajousLabyrinthBall(x: p.x, y: p.y, z: p.z, radius: random.int(128...384)) else {
                return nil
            }
            checkpoints.append(ball)
        }
        var obstacles: [LissajousLabyrinthBall] = []
        let wanted: Int = random.int(1...2)
        var attempts: Int = 0
        while obstacles.count < wanted && attempts < 20 {
            attempts += 1
            guard let ball = try? LissajousLabyrinthBall(x: random.int(-4_000...4_000), y: random.int(-4_000...4_000),
                                                         z: random.int(-4_000...4_000),
                                                         radius: random.int(128...768)) else { continue }
            var touches: Bool = false
            for n in 0..<LissajousLabyrinthLap.ticks {
                let q: LissajousLabyrinthPoint = points[(n + 1) % LissajousLabyrinthLap.ticks]
                if LissajousLabyrinthLap.segmentTouches(points[n], q, ball: ball) {
                    touches = true
                    break
                }
            }
            if !touches { obstacles.append(ball) }
        }
        var start: LissajousLabyrinthDials = target
        let changed: Int = random.int(1...2)
        var picked: [LissajousLabyrinthDial] = []
        while picked.count < changed {
            let dial: LissajousLabyrinthDial = LissajousLabyrinthDial.allCases[random.int(0...3)]
            if !picked.contains(dial) { picked.append(dial) }
        }
        for dial in picked {
            var value: Int = random.int(dial.range)
            while value == target[dial] { value = random.int(dial.range) }
            start[dial] = value
        }
        guard start.isValid,
              let level = try? LissajousLabyrinthLevel(id: "witness-fixture", seed: random.next(),
                                                       band: random.int(1...5), amplitudes: amplitudes,
                                                       frequencyC: frequencyC, start: start, checkpoints: checkpoints,
                                                       obstacles: obstacles, allowance: random.int(3...12),
                                                       tutorial: random.int(0...2) == 0) else { return nil }
        return Built(level: level, target: target)
    }

    /// The actions that set every differing dial to the target's value, in dial order or else reversed, keeping every
    /// intermediate state legal and not winning; nil when neither order does.
    static func actions(_ built: Built) -> [LissajousLabyrinthAction]? {
        var forward: [LissajousLabyrinthAction] = []
        for dial in LissajousLabyrinthDial.allCases where built.level.start[dial] != built.target[dial] {
            forward.append(LissajousLabyrinthAction(dial: dial, value: built.target[dial]))
        }
        let orders: [[LissajousLabyrinthAction]] = [forward, Array(forward.reversed())]
        let rules = LissajousLabyrinthRules(level: built.level)
        for order in orders {
            var state: LissajousLabyrinthDials = built.level.start
            var legal: Bool = true
            for index in order.indices {
                guard let next = rules.apply(order[index], to: state) else {
                    legal = false
                    break
                }
                state = next
                if index < order.count - 1 && rules.isSolved(state) {
                    legal = false
                    break
                }
            }
            if legal && state == built.target { return order }
        }
        return nil
    }

    /// A generated level of `built` solved by `actions` (by hand, without the solver).
    static func generated(_ built: Built, actions: [LissajousLabyrinthAction],
                          _ random: inout SeededRandom) -> LissajousLabyrinthGenerated {
        let solution = LissajousLabyrinthSolution(shortest: actions.count, actions: actions, setting: built.target,
                                                  winningSettings: random.int(1...40), work: random.int(1...200))
        let difficulty = LissajousLabyrinthDifficulty(level: built.level, solution: solution)
        let entry = LissajousLabyrinthManifestEntry(number: random.int(1...100), seed: built.level.seed,
                                                    band: built.level.band, budget: built.level.allowance)
        return LissajousLabyrinthGenerated(entry: entry, level: built.level, solution: solution, difficulty: difficulty,
                                           skipped: random.int(0...5))
    }

    /// A witness of a level won by `target`, or nil when the draw does not suit.
    static func witness(_ random: inout SeededRandom,
                        target: LissajousLabyrinthDials? = nil) throws -> LissajousLabyrinthWitness? {
        guard let built = build(&random, target: target), let actions = actions(built) else { return nil }
        let generated: LissajousLabyrinthGenerated = generated(built, actions: actions, &random)
        do {
            return try LissajousLabyrinthWitness.make(generated)
        } catch LissajousLabyrinthError.witness("counterexample") {
            return nil
        }
    }

    /// `count` seeded witnesses.
    static func witnesses(_ count: Int) throws -> [LissajousLabyrinthWitness] {
        var random: SeededRandom = SeededRandom(seed: 2_312)
        var result: [LissajousLabyrinthWitness] = []
        var draws: Int = 0
        while result.count < count {
            draws += 1
            precondition(draws < 20 * count, "too few suitable fixtures")
            if let witness = try witness(&random) { result.append(witness) }
        }
        return result
    }

    /// The stored JSON of `witness` edited by `edit`.
    static func edited(_ witness: LissajousLabyrinthWitness, _ edit: (inout [String: Any]) -> Void) throws -> Data {
        var object: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: witness.encoded()) as? [String: Any])
        edit(&object)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// The refusal `decode` raises for `data`, or nil when it decodes.
    static func refusal(_ data: Data) -> LissajousLabyrinthError? {
        do {
            _ = try LissajousLabyrinthWitness.decode(data)
            return nil
        } catch {
            return error
        }
    }

    @Test func seededWitnessesRoundTripByteForByte() throws {
        let witnesses: [LissajousLabyrinthWitness] = try Self.witnesses(16)
        var tutorials: Int = 0
        for witness in witnesses {
            let data: Data = witness.encoded()
            #expect(data.last == 0x0A)
            #expect(data.dropLast().last != 0x0A)
            let decoded: LissajousLabyrinthWitness = try LissajousLabyrinthWitness.decode(data)
            #expect(decoded == witness)
            #expect(decoded.encoded() == data)
            #expect(witness.fingerprints.count == witness.actions.count + 1)
            #expect(witness.actions.count == witness.difficulty.shortest)
            #expect(witness.terminal.visits.count == witness.level.checkpoints.count)
            #expect(witness.terminal.clearance == witness.difficulty.clearance)
            #expect(witness.terminal.clearance > 0)
            if witness.level.tutorial { tutorials += 1 }
        }
        #expect(tutorials > 0 && tutorials < witnesses.count)
    }

    @Test func terminalVisitsAreInOrderInsideTheirCheckpoints() throws {
        for witness in try Self.witnesses(8) {
            let level: LissajousLabyrinthLevel = witness.level
            var winning: LissajousLabyrinthDials = level.start
            for action in witness.actions { winning[action.dial] = action.value }
            #expect(LissajousLabyrinthLap.verdict(winning, level: level) == .won)
            var previous: Int = -1
            for index in witness.terminal.visits.indices {
                let tick: Int = witness.terminal.visits[index]
                #expect(tick > previous)
                previous = tick
                let point: LissajousLabyrinthPoint = LissajousLabyrinthLap.position(tick: tick, dials: winning,
                                                                                    level: level)
                #expect(LissajousLabyrinthLap.contains(level.checkpoints[index], point))
            }
        }
    }

    @Test func nearMissLosesWithANamedVerdict() throws {
        for witness in try Self.witnesses(12) {
            let level: LissajousLabyrinthLevel = witness.level
            var winning: LissajousLabyrinthDials = level.start
            for action in witness.actions { winning[action.dial] = action.value }
            let nearMiss: LissajousLabyrinthNearMiss = witness.nearMiss
            let rules = LissajousLabyrinthRules(level: level)
            #expect(rules.apply(nearMiss.action, to: winning) == nearMiss.dials)
            let verdict: LissajousLabyrinthVerdict = LissajousLabyrinthLap.verdict(nearMiss.dials, level: level)
            #expect(verdict != .won)
            #expect(nearMiss.verdict.verdict == verdict)
            #expect(nearMiss.verdict.kind == "contact" || nearMiss.verdict.kind == "missed")
            if case let .contact(obstacle, tick) = verdict {
                #expect((0..<level.obstacles.count).contains(obstacle))
                #expect((0..<LissajousLabyrinthLap.ticks).contains(tick))
            }
            if case let .missed(checkpoint) = verdict {
                #expect((0..<level.checkpoints.count).contains(checkpoint))
            }
            // No legal change of a smaller distance, nor of the same distance earlier in dial order, loses.
            let distance: Int = abs(nearMiss.action.value - winning[nearMiss.action.dial])
            let order: [LissajousLabyrinthDial] = LissajousLabyrinthDial.allCases
            let nearIndex: Int = try #require(order.firstIndex(of: nearMiss.action.dial))
            for index in order.indices {
                let dial: LissajousLabyrinthDial = order[index]
                for value in dial.range {
                    let d: Int = abs(value - winning[dial])
                    let earlier: Bool = d < distance || (d == distance && (index < nearIndex
                        || (index == nearIndex && value < nearMiss.action.value)))
                    guard earlier, let next = rules.apply(LissajousLabyrinthAction(dial: dial, value: value),
                                                          to: winning) else { continue }
                    #expect(LissajousLabyrinthLap.verdict(next, level: level) == .won)
                }
            }
        }
    }

    @Test func nonCoprimeCounterexampleIsRefused() throws {
        for witness in try Self.witnesses(8) {
            var winning: LissajousLabyrinthDials = witness.level.start
            for action in witness.actions { winning[action.dial] = action.value }
            let counter: LissajousLabyrinthNonCoprime = witness.nonCoprime
            #expect(!counter.dials.isValid)
            #expect(counter.reason == "r02-g02.move")
            let last: LissajousLabyrinthAction = try #require(counter.actions.last)
            #expect(LissajousLabyrinthRules(level: witness.level).apply(last, to: winning) == nil)
            #expect(LissajousLabyrinthWitness.isRefused(counter, from: winning, level: witness.level))
        }
    }

    @Test func nonCoprimeRuleCoversEveryFrequencyPair() throws {
        for a in 1...9 {
            for b in 1...9 where LissajousLabyrinthDials.gcd(a, b) == 1 {
                let winning = LissajousLabyrinthDials(frequencyA: a, frequencyB: b, phaseA: 3, phaseC: 7)
                let counter: LissajousLabyrinthNonCoprime = LissajousLabyrinthWitness.nonCoprime(of: winning)
                #expect(!counter.dials.isValid)
                #expect(counter.dials.phaseA == 3 && counter.dials.phaseC == 7)
                if a == 1 && b == 1 {
                    let expected: [LissajousLabyrinthAction] = [
                        LissajousLabyrinthAction(dial: .frequencyA, value: 2),
                        LissajousLabyrinthAction(dial: .frequencyB, value: 2),
                    ]
                    #expect(counter.actions == expected)
                } else if a == 1 {
                    var smallest: Int = 0
                    for value in 2...9 where smallest == 0 && LissajousLabyrinthDials.gcd(value, b) > 1 {
                        smallest = value
                    }
                    #expect(counter.actions == [LissajousLabyrinthAction(dial: .frequencyA, value: smallest)])
                } else {
                    var smallest: Int = 0
                    for value in 1...9 where smallest == 0 && value != b && LissajousLabyrinthDials.gcd(a, value) > 1 {
                        smallest = value
                    }
                    #expect(counter.actions == [LissajousLabyrinthAction(dial: .frequencyB, value: smallest)])
                }
            }
        }
        let one = LissajousLabyrinthDials(frequencyA: 1, frequencyB: 6, phaseA: 0, phaseC: 0)
        #expect(LissajousLabyrinthWitness.nonCoprime(of: one).actions
            == [LissajousLabyrinthAction(dial: .frequencyA, value: 2)])
        let three = LissajousLabyrinthDials(frequencyA: 3, frequencyB: 7, phaseA: 0, phaseC: 0)
        #expect(LissajousLabyrinthWitness.nonCoprime(of: three).actions
            == [LissajousLabyrinthAction(dial: .frequencyB, value: 3)])
    }

    @Test func witnessesWithFrequencyAOneAndBothOneRoundTrip() throws {
        var random: SeededRandom = SeededRandom(seed: 2_312)
        let targets: [LissajousLabyrinthDials] = [
            LissajousLabyrinthDials(frequencyA: 1, frequencyB: 4, phaseA: 5, phaseC: 2),
            LissajousLabyrinthDials(frequencyA: 1, frequencyB: 1, phaseA: 9, phaseC: 12),
        ]
        for target in targets {
            var found: LissajousLabyrinthWitness? = nil
            var draws: Int = 0
            while found == nil && draws < 60 {
                draws += 1
                found = try Self.witness(&random, target: target)
            }
            let witness: LissajousLabyrinthWitness = try #require(found)
            let counter: LissajousLabyrinthNonCoprime = witness.nonCoprime
            #expect(counter.actions.first?.dial == .frequencyA)
            #expect(LissajousLabyrinthWitness.isRefused(counter, from: target, level: witness.level))
            if target.frequencyB == 1 {
                #expect(counter.dials.frequencyA == 2 && counter.dials.frequencyB == 2)
                #expect(counter.actions.count == 2)
            } else {
                #expect(counter.dials.frequencyA == 2 && counter.dials.frequencyB == 4)
            }
            let data: Data = witness.encoded()
            #expect(try LissajousLabyrinthWitness.decode(data).encoded() == data)
        }
    }

    @Test func schemaAndDamageRefusals() throws {
        let witness: LissajousLabyrinthWitness = try #require(try Self.witnesses(1).first)
        let newer: Data = try Self.edited(witness) { $0["schema"] = 2 }
        #expect(Self.refusal(newer) == .newerSchema(2))
        let older: Data = try Self.edited(witness) { $0["schema"] = 0 }
        #expect(Self.refusal(older) == .witness("damaged"))
        let damaged: Data = witness.encoded().prefix(40)
        #expect(Self.refusal(damaged) == .witness("damaged"))
        let missing: Data = try Self.edited(witness) { $0.removeValue(forKey: "terminal") }
        #expect(Self.refusal(missing) == .witness("damaged"))
        let garbage: Data = Data("not json".utf8)
        #expect(Self.refusal(garbage) == .witness("damaged"))
        #expect(LissajousLabyrinthError.witness("damaged").reasonCode == "r02-g02.witness")
    }

    @Test func editedPartsAreRefused() throws {
        let witness: LissajousLabyrinthWitness = try #require(try Self.witnesses(1).first)

        let action: Data = try Self.edited(witness) { object in
            var actions: [[String: Any]] = object["actions"] as! [[String: Any]]
            let dial: String = actions[0]["dial"] as! String
            let value: Int = actions[0]["value"] as! Int
            let top: Int = dial.hasPrefix("frequency") ? 9 : 15
            actions[0]["value"] = value == top ? value - 1 : value + 1
            object["actions"] = actions
        }
        let actionRefusal: LissajousLabyrinthError? = Self.refusal(action)
        let actionParts: [LissajousLabyrinthError] = [.witness("replay"), .witness("fingerprints")]
        #expect(actionRefusal.map { actionParts.contains($0) } == true)

        let fingerprint: Data = try Self.edited(witness) { object in
            var fingerprints: [String] = object["fingerprints"] as! [String]
            fingerprints[fingerprints.count - 1] = String(repeating: "0", count: 64)
            object["fingerprints"] = fingerprints
        }
        #expect(Self.refusal(fingerprint) == .witness("fingerprints"))

        let levelEdit: Data = try Self.edited(witness) { object in
            var value: [String: Any] = object["level"] as! [String: Any]
            value["allowance"] = (value["allowance"] as! Int) == 64 ? 63 : 64
            object["level"] = value
        }
        #expect(Self.refusal(levelEdit) == .witness("level"))

        let visits: Data = try Self.edited(witness) { object in
            var value: [String: Any] = object["terminal"] as! [String: Any]
            var ticks: [Int] = value["visits"] as! [Int]
            ticks[0] += 1
            value["visits"] = ticks
            object["terminal"] = value
        }
        #expect(Self.refusal(visits) == .witness("terminal"))

        let clearance: Data = try Self.edited(witness) { object in
            var value: [String: Any] = object["terminal"] as! [String: Any]
            value["clearance"] = (value["clearance"] as! Int) - 1
            object["terminal"] = value
        }
        #expect(Self.refusal(clearance) == .witness("terminal"))

        let nearTick: Data = try Self.edited(witness) { object in
            var value: [String: Any] = object["nearMiss"] as! [String: Any]
            var verdict: [String: Any] = value["verdict"] as! [String: Any]
            if verdict["kind"] as! String == "contact" {
                verdict["tick"] = (verdict["tick"] as! Int) + 1
            } else {
                verdict["checkpoint"] = (verdict["checkpoint"] as! Int) + 1
            }
            value["verdict"] = verdict
            object["nearMiss"] = value
        }
        #expect(Self.refusal(nearTick) == .witness("nearMiss"))

        let nearKind: Data = try Self.edited(witness) { object in
            var value: [String: Any] = object["nearMiss"] as! [String: Any]
            var verdict: [String: Any] = value["verdict"] as! [String: Any]
            verdict["kind"] = "won"
            value["verdict"] = verdict
            object["nearMiss"] = value
        }
        #expect(Self.refusal(nearKind) == .witness("nearMiss"))

        let coprime: Data = try Self.edited(witness) { object in
            var value: [String: Any] = object["nonCoprime"] as! [String: Any]
            value["reason"] = "r02-g02.stage"
            object["nonCoprime"] = value
        }
        #expect(Self.refusal(coprime) == .witness("nonCoprime"))

        let coprimeDials: Data = try Self.edited(witness) { object in
            var value: [String: Any] = object["nonCoprime"] as! [String: Any]
            var dials: [String: Any] = value["dials"] as! [String: Any]
            dials["phaseA"] = ((dials["phaseA"] as! Int) + 1) % 16
            value["dials"] = dials
            object["nonCoprime"] = value
        }
        #expect(Self.refusal(coprimeDials) == .witness("nonCoprime"))

        let shortest: Data = try Self.edited(witness) { object in
            var value: [String: Any] = object["difficulty"] as! [String: Any]
            value["shortest"] = (value["shortest"] as! Int) + 1
            object["difficulty"] = value
        }
        #expect(Self.refusal(shortest) == .witness("difficulty"))

        let difficultyClearance: Data = try Self.edited(witness) { object in
            var value: [String: Any] = object["difficulty"] as! [String: Any]
            value["clearance"] = (value["clearance"] as! Int) + 1
            object["difficulty"] = value
        }
        #expect(Self.refusal(difficultyClearance) == .witness("difficulty"))
    }

    @Test func aReFingerprintedLevelDoesNotReplay() throws {
        let witness: LissajousLabyrinthWitness = try #require(try Self.witnesses(1).first)
        let old: LissajousLabyrinthLevel = witness.level
        let other = try LissajousLabyrinthLevel(id: old.id, seed: old.seed, band: old.band, amplitudes: old.amplitudes,
                                                frequencyC: old.frequencyC, start: old.start,
                                                checkpoints: old.checkpoints, obstacles: old.obstacles,
                                                allowance: old.allowance == 64 ? 63 : old.allowance + 1,
                                                tutorial: old.tutorial)
        let replacement: Any = try JSONSerialization.jsonObject(with: other.encoded())
        let data: Data = try Self.edited(witness) { $0["level"] = replacement }
        #expect(Self.refusal(data) == .witness("fingerprints"))
    }

    @Test func aSolutionThatDoesNotWinIsRefused() throws {
        var random: SeededRandom = SeededRandom(seed: 2_312)
        var checked: Int = 0
        var draws: Int = 0
        while checked < 5 && draws < 200 {
            draws += 1
            guard let built = Self.build(&random), let full = Self.actions(built), full.count >= 2 else { continue }
            let short: [LissajousLabyrinthAction] = Array(full.dropLast())
            let generated: LissajousLabyrinthGenerated = Self.generated(built, actions: short, &random)
            #expect(throws: LissajousLabyrinthError.witness("replay")) { try LissajousLabyrinthWitness.make(generated) }
            checked += 1
        }
        #expect(checked == 5)
        // An illegal action (no change) is refused by the replay too.
        while true {
            guard let built = Self.build(&random), let full = Self.actions(built) else { continue }
            var actions: [LissajousLabyrinthAction] = full
            let first: LissajousLabyrinthAction = full[0]
            actions.insert(LissajousLabyrinthAction(dial: first.dial, value: built.level.start[first.dial]), at: 0)
            let generated: LissajousLabyrinthGenerated = Self.generated(built, actions: actions, &random)
            #expect(throws: LissajousLabyrinthError.witness("replay")) { try LissajousLabyrinthWitness.make(generated) }
            break
        }
    }

    @Test func reasonCodes() {
        #expect(LissajousLabyrinthError.witness("replay").reasonCode == "r02-g02.witness")
        #expect(LissajousLabyrinthError.witness("counterexample").reasonCode == "r02-g02.witness")
        #expect(LissajousLabyrinthError.move("not-coprime").reasonCode == "r02-g02.move")
    }
}
