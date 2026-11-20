// PuzzleLevelTests — feature 223 (R02-F23) T-R02F23-003 (FR-R02F23-001, 007; SC-R02F23-001). 200 seeded levels of
// both fixture rules round-trip with identical identities and bytes; any one changed value changes the identity;
// edited, newer and damaged stored forms are refused; the initialiser refuses bad rules ids and long solutions; one
// known level's identity is pinned as the regression anchor of the canonical JSON.
import Foundation
import Testing
@testable import VisualCoreSimulation

/// Tests of ``PuzzleLevel``.
struct PuzzleLevelTests {
    /// A seeded budget within every range.
    private static func budget(_ rng: inout SeededRandom) throws -> FairnessBudget {
        let maxLength: Int = rng.int(0...FairnessBudget.maxLength)
        let minLength: Int = rng.int(0...maxLength)
        let branching: Int = rng.int(1...FairnessBudget.maxBranching)
        let nodes: Int = rng.int(1...FairnessBudget.maxNodes)
        return try FairnessBudget(minLength: minLength, maxLength: maxLength, maxBranching: branching, nodeBudget: nodes)
    }

    /// A seeded optional seed: nil, a small value, or a full 64-bit value.
    private static func seed(_ rng: inout SeededRandom) -> UInt64? {
        let pick: Int = rng.int(0...2)
        if pick == 0 { return nil }
        if pick == 1 { return UInt64(rng.int(0...1_000)) }
        return rng.next()
    }

    /// A seeded promise.
    private static func uniqueness(_ rng: inout SeededRandom) -> PuzzleUniqueness {
        let all: [PuzzleUniqueness] = PuzzleUniqueness.allCases
        return all[rng.int(0...(all.count - 1))]
    }

    /// The error `decode` throws for `data`, or nil when it succeeds.
    private static func refusal<R: PuzzleRules>(_ data: Data, _ type: R.Type) -> PuzzleError? {
        do {
            _ = try PuzzleLevel<R>.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// Whether `error` is `.malformed`.
    private static func isMalformed(_ error: PuzzleError?) -> Bool {
        if case .malformed = error { return true }
        return false
    }

    /// A small known lights-out level.
    private static func knownLevel() throws -> PuzzleLevel<LightsOutRules> {
        try PuzzleLevel<LightsOutRules>(rulesID: "lights-out-3", start: 0b000_010_000, solution: [4],
                                        uniqueness: .solution, budget: FairnessBudget(minLength: 1, maxLength: 8),
                                        seed: 2_023)
    }

    private static func text(_ data: Data) -> String { String(decoding: data, as: UTF8.self) }
    private static func data(_ text: String) -> Data { Data(text.utf8) }

    @Test("200 seeded levels round-trip with identical identities and bytes")
    func seededRoundTrip() throws {
        var rng = SeededRandom(seed: 2_023)
        for i in 0..<200 {
            let uniqueness: PuzzleUniqueness = Self.uniqueness(&rng)
            let budget: FairnessBudget = try Self.budget(&rng)
            let seed: UInt64? = Self.seed(&rng)
            let length: Int = rng.int(0...24)
            var solution: [Int] = []
            for _ in 0..<length { solution.append(rng.int(0...8)) }
            if i % 2 == 0 {
                let start = UInt16(rng.int(0...511))
                let level = try PuzzleLevel<LightsOutRules>(rulesID: "lights-out-3", start: start, solution: solution,
                                                            uniqueness: uniqueness, budget: budget, seed: seed)
                let bytes: Data = level.encoded()
                let back: PuzzleLevel<LightsOutRules> = try PuzzleLevel<LightsOutRules>.decode(bytes)
                #expect(back == level)
                #expect(back.identity == level.identity)
                #expect(back.encoded() == bytes)
                #expect(back.seed == seed)
                let viaCodable = try JSONDecoder().decode(PuzzleLevel<LightsOutRules>.self, from: bytes)
                #expect(viaCodable == level)
            } else {
                var start: [Int] = [0, 1, 2, 3]
                for k in stride(from: 3, to: 0, by: -1) { start.swapAt(k, rng.int(0...k)) }
                var moves: [Int] = []
                for move in solution { moves.append(move % 3) }
                let level = try PuzzleLevel<SlidingRowRules>(rulesID: "sliding-row-4", start: start, solution: moves,
                                                             uniqueness: uniqueness, budget: budget, seed: seed)
                let bytes: Data = level.encoded()
                let back: PuzzleLevel<SlidingRowRules> = try PuzzleLevel<SlidingRowRules>.decode(bytes)
                #expect(back == level)
                #expect(back.identity == level.identity)
                #expect(back.encoded() == bytes)
            }
        }
    }

    @Test("the identity is 64 lower-case hex digits and a nil seed is written as null")
    func identityShape() throws {
        let level: PuzzleLevel<LightsOutRules> = try Self.knownLevel()
        #expect(level.identity.count == 64)
        let hex: Set<Character> = Set("0123456789abcdef")
        for ch in level.identity { #expect(hex.contains(ch)) }
        let unseeded = try PuzzleLevel<LightsOutRules>(rulesID: "lights-out-3", start: 16, solution: [4],
                                                       budget: FairnessBudget(maxLength: 8))
        #expect(Self.text(unseeded.encoded()).contains("\"seed\":null"))
        #expect(PuzzleLevel<LightsOutRules>.schema == 1)
    }

    @Test("a known level's identity is pinned (regression anchor of the canonical JSON)")
    func goldenIdentity() throws {
        let level: PuzzleLevel<LightsOutRules> = try Self.knownLevel()
        // Regression anchor, computed once on 2026-11-20 and cross-checked with `shasum -a 256` of the canonical JSON
        // {"budget":{"maxBranching":64,"maxLength":8,"minLength":1,"nodeBudget":100000},"rulesID":"lights-out-3",
        // "schema":1,"seed":2023,"solution":[4],"start":16,"uniqueness":"solution"}; a change means the canonical form
        // (and every stored level identity) changed.
        #expect(level.identity == "9072e611c291ec27d354205d85ae368ac766beac9b46c6332d870fc16fc5f38f")
    }

    @Test("changing any one value changes the identity")
    func everyValueCounts() throws {
        let base: PuzzleLevel<LightsOutRules> = try Self.knownLevel()
        let b: FairnessBudget = base.budget
        var variants: [PuzzleLevel<LightsOutRules>] = []
        variants.append(try PuzzleLevel(rulesID: "lights-out-4", start: base.start, solution: base.solution,
                                        uniqueness: base.uniqueness, budget: b, seed: base.seed))
        variants.append(try PuzzleLevel(rulesID: base.rulesID, start: 17, solution: base.solution,
                                        uniqueness: base.uniqueness, budget: b, seed: base.seed))
        variants.append(try PuzzleLevel(rulesID: base.rulesID, start: base.start, solution: [3],
                                        uniqueness: base.uniqueness, budget: b, seed: base.seed))
        variants.append(try PuzzleLevel(rulesID: base.rulesID, start: base.start, solution: [4, 4, 4],
                                        uniqueness: base.uniqueness, budget: b, seed: base.seed))
        variants.append(try PuzzleLevel(rulesID: base.rulesID, start: base.start, solution: base.solution,
                                        uniqueness: .goal, budget: b, seed: base.seed))
        variants.append(try PuzzleLevel(rulesID: base.rulesID, start: base.start, solution: base.solution,
                                        uniqueness: .none, budget: b, seed: base.seed))
        let budgets: [FairnessBudget] = [
            try FairnessBudget(minLength: 0, maxLength: b.maxLength, maxBranching: b.maxBranching, nodeBudget: b.nodeBudget),
            try FairnessBudget(minLength: b.minLength, maxLength: 9, maxBranching: b.maxBranching, nodeBudget: b.nodeBudget),
            try FairnessBudget(minLength: b.minLength, maxLength: b.maxLength, maxBranching: 9, nodeBudget: b.nodeBudget),
            try FairnessBudget(minLength: b.minLength, maxLength: b.maxLength, maxBranching: b.maxBranching, nodeBudget: 99)
        ]
        for other in budgets {
            variants.append(try PuzzleLevel(rulesID: base.rulesID, start: base.start, solution: base.solution,
                                            uniqueness: base.uniqueness, budget: other, seed: base.seed))
        }
        let seeds: [UInt64?] = [nil, 2_024, 0]
        for other in seeds {
            variants.append(try PuzzleLevel(rulesID: base.rulesID, start: base.start, solution: base.solution,
                                            uniqueness: base.uniqueness, budget: b, seed: other))
        }
        var seen: Set<String> = [base.identity]
        for variant in variants {
            #expect(variant.identity != base.identity)
            seen.insert(variant.identity)
        }
        #expect(seen.count == variants.count + 1)
        let same = try PuzzleLevel<LightsOutRules>(rulesID: base.rulesID, start: base.start, solution: base.solution,
                                                   uniqueness: base.uniqueness, budget: b, seed: base.seed)
        #expect(same.identity == base.identity)
    }

    @Test("a stored value edited without its identity is refused as edited")
    func editedRefused() throws {
        let stored: String = Self.text(try Self.knownLevel().encoded())
        let edits: [(String, String)] = [
            ("\"uniqueness\":\"solution\"", "\"uniqueness\":\"goal\""),
            ("\"start\":16", "\"start\":17"),
            ("\"solution\":[4]", "\"solution\":[3]"),
            ("\"seed\":2023", "\"seed\":2024"),
            ("\"seed\":2023", "\"seed\":null"),
            ("\"nodeBudget\":100000", "\"nodeBudget\":99999"),
            ("\"rulesID\":\"lights-out-3\"", "\"rulesID\":\"lights-out-9\"")
        ]
        for (from, to) in edits {
            #expect(stored.contains(from))
            let edited: String = stored.replacingOccurrences(of: from, with: to)
            #expect(Self.refusal(Self.data(edited), LightsOutRules.self) == .edited)
        }
        let identity: String = try Self.knownLevel().identity
        var flipped: String = identity
        flipped.removeLast()
        flipped.append(identity.hasSuffix("0") ? "1" : "0")
        let wrongID: String = stored.replacingOccurrences(of: identity, with: flipped)
        #expect(Self.refusal(Self.data(wrongID), LightsOutRules.self) == .edited)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(PuzzleLevel<LightsOutRules>.self, from: Self.data(wrongID))
        }
    }

    @Test("a newer schema is refused as newer")
    func newerSchema() throws {
        let stored: String = Self.text(try Self.knownLevel().encoded())
        #expect(stored.contains("\"schema\":1"))
        let newer: String = stored.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2")
        #expect(Self.refusal(Self.data(newer), LightsOutRules.self) == .newerSchema(2))
        #expect(Self.refusal(Self.data("{\"schema\":7}"), LightsOutRules.self) == .newerSchema(7))
    }

    @Test("damaged stored forms are refused as malformed")
    func damagedRefused() throws {
        let stored: String = Self.text(try Self.knownLevel().encoded())
        #expect(Self.isMalformed(Self.refusal(Self.data("not json"), LightsOutRules.self)))
        #expect(Self.isMalformed(Self.refusal(Data(), LightsOutRules.self)))
        #expect(Self.isMalformed(Self.refusal(Self.data("{\"schema\":\"one\"}"), LightsOutRules.self)))
        let schema0: String = stored.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":0")
        #expect(Self.refusal(Self.data(schema0), LightsOutRules.self) == .malformed("schema 0"))
        let keys: [String] = ["schema", "rulesID", "start", "solution", "uniqueness", "budget", "seed", "identity"]
        for key in keys {
            let object = try #require(JSONSerialization.jsonObject(with: Self.data(stored)) as? [String: Any])
            var trimmed: [String: Any] = object
            trimmed.removeValue(forKey: key)
            let bytes: Data = try JSONSerialization.data(withJSONObject: trimmed, options: [.sortedKeys])
            #expect(Self.isMalformed(Self.refusal(bytes, LightsOutRules.self)), "missing \(key)")
        }
        let badBudget: String = stored.replacingOccurrences(of: "\"maxBranching\":64", with: "\"maxBranching\":0")
        #expect(badBudget != stored)
        #expect(Self.isMalformed(Self.refusal(Self.data(badBudget), LightsOutRules.self)))
        let badPromise: String = stored.replacingOccurrences(of: "\"solution\"", with: "\"sometimes\"")
        #expect(Self.isMalformed(Self.refusal(Self.data(badPromise), LightsOutRules.self)))
        var long: String = "["
        for i in 0..<4_097 { long += i == 0 ? "4" : ",4" }
        long += "]"
        let tooLong: String = stored.replacingOccurrences(of: "\"solution\":[4]", with: "\"solution\":" + long)
        #expect(Self.refusal(Self.data(tooLong), LightsOutRules.self) == .malformed("r2-f23.solution-length"))
        let badSlug: String = stored.replacingOccurrences(of: "\"lights-out-3\"", with: "\"Lights-Out\"")
        #expect(Self.refusal(Self.data(badSlug), LightsOutRules.self) == .malformed("r2-f23.rules-id"))
        let badStart: String = stored.replacingOccurrences(of: "\"start\":16", with: "\"start\":-1")
        #expect(Self.isMalformed(Self.refusal(Self.data(badStart), LightsOutRules.self)))
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(PuzzleLevel<LightsOutRules>.self, from: Self.data(tooLong))
        }
    }

    @Test("the initialiser refuses bad rules ids and solutions above 4,096 moves")
    func initRefusals() throws {
        let budget = try FairnessBudget(maxLength: 8)
        let badIDs: [String] = ["", "Lights", "lights_out", "-lights", "lights-", "lights--out", "lights out",
                                String(repeating: "a", count: 65)]
        for id in badIDs {
            #expect(throws: PuzzleError.rulesID) {
                _ = try PuzzleLevel<LightsOutRules>(rulesID: id, start: 0, solution: [], budget: budget)
            }
        }
        let longest: [Int] = Array(repeating: 4, count: FairnessBudget.maxLength)
        let ok = try PuzzleLevel<LightsOutRules>(rulesID: String(repeating: "a", count: 64), start: 0,
                                                 solution: longest, budget: budget)
        #expect(ok.solution.count == 4_096)
        #expect(try PuzzleLevel<LightsOutRules>.decode(ok.encoded()) == ok)
        let tooLong: [Int] = Array(repeating: 4, count: FairnessBudget.maxLength + 1)
        #expect(throws: PuzzleError.solutionLength) {
            _ = try PuzzleLevel<LightsOutRules>(rulesID: "lights-out-3", start: 0, solution: tooLong, budget: budget)
        }
    }
}
