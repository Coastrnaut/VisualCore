// PuzzleCatalogTests — feature 224 (R02-F24) T-R02F24-003 (FR-R02F24-001, 002, 005, 006; clarifications Q1, Q2, Q5;
// SC-R02F24-001, 004). A 3-stage, 30-level lights-out plan builds twice identically with a pinned digest; every level
// certifies; each stage is ordered by difficulty, then identity; the progression rule holds; unfillable plans fail with
// their stage and calls; a progression breach fails with its position; the stored form round-trips byte for byte and
// newer, damaged and edited forms are refused; the initialiser's refusals and its acceptance of duplicates.
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreSimulation

/// Lights-out candidate for a stage: a walk of k distinct moves from the solved state, k drawn from the stage budget's
/// minLength … maxLength (clamped to 1 … 9). Lights-out moves commute and are self-inverse, so the k moves solve the
/// start and k distinct moves are its shortest solution.
private func stageLightsOutMaker(_ rng: inout SeededRandom,
                                 _ stage: PuzzleCatalogStage) -> (start: UInt16, solution: [Int])? {
    let rules: LightsOutRules = LightsOutRules()
    let low: Int = max(1, min(9, stage.budget.minLength))
    let high: Int = max(low, min(9, stage.budget.maxLength))
    let count: Int = rng.int(low...high)
    let order: [Int] = rng.shuffled(Array(0..<9))
    var moves: [Int] = []
    var state: UInt16 = 0
    for k in 0..<count {
        let move: Int = order[k]
        moves.append(move)
        guard let next = rules.apply(move, to: state) else { return nil }
        state = next
    }
    return (start: state, solution: moves)
}

@Suite("PuzzleCatalog")
struct PuzzleCatalogTests {
    private let rules: LightsOutRules = LightsOutRules()

    /// The regression anchor: the digest of ``plan()`` built from seed 2,024. Any change to the rules, the generator,
    /// the seed derivation, the builder or the plan changes it; computed once on 2026-11-20 and pinned here.
    private static let pinnedDigest: String = "678aafc04dd15e5fb2b6025693e65698ecc47f8cd4f1f5a8fcc1c1f44701c90a"

    private func stage(count: Int, min minLength: Int, max maxLength: Int) throws -> PuzzleCatalogStage {
        let budget: FairnessBudget = try FairnessBudget(minLength: minLength, maxLength: maxLength, maxBranching: 9,
                                                        nodeBudget: 1_000)
        return try PuzzleCatalogStage(count: count, budget: budget, uniqueness: .goal, attempts: 20)
    }

    /// Three stages of 10 levels with walk lengths 1 … 3, 3 … 5 and 5 … 7. The standard rule (drop 1, jump 3) fits by
    /// construction: each stage is sorted ascending (no drops inside), shortest lengths inside a stage differ by at
    /// most 2 between neighbours, and a stage starts at or above the previous stage's ceiling and at most 2 above it.
    private func plan() throws -> PuzzleCatalogPlan {
        let stages: [PuzzleCatalogStage] = [
            try stage(count: 10, min: 1, max: 3),
            try stage(count: 10, min: 3, max: 5),
            try stage(count: 10, min: 5, max: 7),
        ]
        return try PuzzleCatalogPlan(id: "lights-out-catalog", seed: 2_024, stages: stages, rule: .standard)
    }

    private func build() throws -> PuzzleCatalog<LightsOutRules> {
        try PuzzleCatalogBuilder.build(try plan(), rules: rules, make: stageLightsOutMaker)
    }

    private func identities(_ catalog: PuzzleCatalog<LightsOutRules>) -> [String] {
        var result: [String] = []
        for entry in catalog.entries { result.append(entry.level.identity) }
        return result
    }

    /// The stored form as a mutable JSON object.
    private func object(_ catalog: PuzzleCatalog<LightsOutRules>) throws -> [String: Any] {
        let any: Any = try JSONSerialization.jsonObject(with: catalog.encoded())
        return try #require(any as? [String: Any])
    }

    private func data(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    @Test("a 3-stage, 30-level plan builds twice identically with the pinned digest")
    func deterministicWithPinnedDigest() throws {
        let first: PuzzleCatalog<LightsOutRules> = try build()
        let second: PuzzleCatalog<LightsOutRules> = try build()
        #expect(first == second)
        #expect(first.digest == second.digest)
        #expect(first.entries.count == 30)
        #expect(first.id == "lights-out-catalog")
        #expect(first.digest == PuzzleCatalog<LightsOutRules>.digest(id: first.id, identities: identities(first)))
        #expect(first.digest == Self.pinnedDigest)
    }

    @Test("every level re-certifies with its stored difficulty and identities are distinct")
    func everyLevelCertifies() throws {
        let catalog: PuzzleCatalog<LightsOutRules> = try build()
        var seen: Set<String> = []
        for entry in catalog.entries {
            let certificate: PuzzleCertificate = PuzzleValidator.certify(entry.level, rules: rules)
            #expect(certificate.isValid)
            #expect(PuzzleDifficulty(certificate: certificate) == entry.difficulty)
            #expect(entry.level.uniqueness == .goal)
            #expect(seen.insert(entry.level.identity).inserted)
        }
    }

    @Test("each stage is ordered by difficulty, then identity, and the progression rule holds")
    func stagesOrderedAndRuleHolds() throws {
        let catalog: PuzzleCatalog<LightsOutRules> = try build()
        let bounds: [(Int, Int)] = [(1, 3), (3, 5), (5, 7)]
        for s in 0..<3 {
            let base: Int = s * 10
            for i in base..<(base + 10) {
                let shortest: Int = catalog.entries[i].difficulty.shortest
                #expect(shortest >= bounds[s].0 && shortest <= bounds[s].1)
                if i == base { continue }
                let a: PuzzleCatalogEntry<LightsOutRules> = catalog.entries[i - 1]
                let b: PuzzleCatalogEntry<LightsOutRules> = catalog.entries[i]
                let ordered: Bool = a.difficulty < b.difficulty
                    || (a.difficulty == b.difficulty && a.level.identity < b.level.identity)
                #expect(ordered)
            }
        }
        var difficulties: [PuzzleDifficulty] = []
        for entry in catalog.entries { difficulties.append(entry.difficulty) }
        #expect(ProgressionRule.standard.breach(difficulties) == nil)
    }

    @Test("a maker that never makes a candidate fails the first stage on its first call")
    func failingCall() throws {
        let plan: PuzzleCatalogPlan = try PuzzleCatalogPlan(id: "empty", seed: 2_024,
                                                            stages: [try stage(count: 3, min: 1, max: 3)])
        #expect(throws: ContentError.planFailed(stage: 0, calls: 1)) {
            _ = try PuzzleCatalogBuilder.build(
                plan, rules: rules,
                make: { (_: inout SeededRandom, _: PuzzleCatalogStage) -> (start: UInt16, solution: [Int])? in nil })
        }
    }

    @Test("a stage asking more distinct levels than exist fails after 4 × count calls")
    func tooManyDuplicates() throws {
        // Walks of exactly one move give only 9 distinct lights-out starts; the stage asks for 10.
        let plan: PuzzleCatalogPlan = try PuzzleCatalogPlan(id: "too-small", seed: 2_024,
                                                            stages: [try stage(count: 10, min: 1, max: 1)])
        // Duplicates are judged on content without the seed (the identity includes it), so only 9 distinct
        // one-move boards exist and the stage cannot reach 10 within 4 × 10 calls.
        #expect(throws: ContentError.planFailed(stage: 0, calls: 40)) {
            _ = try PuzzleCatalogBuilder.build(plan, rules: rules, make: stageLightsOutMaker)
        }
    }

    @Test("a progression breach fails at the first level of the harder stage")
    func progressionBreach() throws {
        let stages: [PuzzleCatalogStage] = [
            try stage(count: 4, min: 1, max: 1),
            try stage(count: 4, min: 5, max: 5),
        ]
        let rule: ProgressionRule = try ProgressionRule(maxDrop: 1, maxJump: 0)
        let plan: PuzzleCatalogPlan = try PuzzleCatalogPlan(id: "steep", seed: 2_024, stages: stages, rule: rule)
        #expect(throws: ContentError.progression(4)) {
            _ = try PuzzleCatalogBuilder.build(plan, rules: rules, make: stageLightsOutMaker)
        }
    }

    @Test("the stored form round-trips byte for byte, also through Codable")
    func roundTrip() throws {
        let catalog: PuzzleCatalog<LightsOutRules> = try build()
        let bytes: Data = catalog.encoded()
        let decoded: PuzzleCatalog<LightsOutRules> = try PuzzleCatalog<LightsOutRules>.decode(bytes)
        #expect(decoded == catalog)
        #expect(decoded.encoded() == bytes)
        let viaCodable: PuzzleCatalog<LightsOutRules> = try JSONDecoder().decode(PuzzleCatalog<LightsOutRules>.self,
                                                                                from: bytes)
        #expect(viaCodable == catalog)
        let object: [String: Any] = try object(catalog)
        #expect(object["schema"] as? Int == 1)
        let entries: [Any] = try #require(object["entries"] as? [Any])
        let first: [String: Any] = try #require(entries.first as? [String: Any])
        let level: [String: Any] = try #require(first["level"] as? [String: Any])
        #expect(level["identity"] as? String == catalog.entries[0].level.identity)
    }

    @Test("a newer schema is refused as newer")
    func newerSchema() throws {
        var object: [String: Any] = try object(try build())
        object["schema"] = 2
        let bytes: Data = try data(object)
        #expect(throws: ContentError.newerSchema(2)) {
            _ = try PuzzleCatalog<LightsOutRules>.decode(bytes)
        }
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(PuzzleCatalog<LightsOutRules>.self, from: bytes)
        }
    }

    /// Whether decoding `bytes` throws `.malformed`.
    private func isMalformed(_ bytes: Data) -> Bool {
        do {
            _ = try PuzzleCatalog<LightsOutRules>.decode(bytes)
            return false
        } catch {
            if case .malformed = error { return true }
            return false
        }
    }

    @Test("damaged forms are refused as malformed: not JSON, missing keys, a schema below 1, an edited level")
    func damaged() throws {
        let catalog: PuzzleCatalog<LightsOutRules> = try build()
        #expect(isMalformed(Data("not json".utf8)))

        let keys: [String] = ["schema", "id", "digest", "entries"]
        for key in keys {
            var object: [String: Any] = try object(catalog)
            object.removeValue(forKey: key)
            #expect(isMalformed(try data(object)), "missing \(key)")
        }

        var zero: [String: Any] = try object(catalog)
        zero["schema"] = 0
        #expect(isMalformed(try data(zero)))

        var edited: [String: Any] = try object(catalog)
        var entries: [Any] = try #require(edited["entries"] as? [Any])
        var entry: [String: Any] = try #require(entries[3] as? [String: Any])
        var level: [String: Any] = try #require(entry["level"] as? [String: Any])
        let start: Int = try #require(level["start"] as? Int)
        level["start"] = start ^ 1
        entry["level"] = level
        entries[3] = entry
        edited["entries"] = entries
        #expect(isMalformed(try data(edited)))

        var badID: [String: Any] = try object(catalog)
        badID["id"] = "Not A Slug"
        #expect(isMalformed(try data(badID)))

        var empty: [String: Any] = try object(catalog)
        empty["entries"] = [Any]()
        #expect(isMalformed(try data(empty)))
    }

    @Test("an edited digest is refused as edited")
    func editedDigest() throws {
        let catalog: PuzzleCatalog<LightsOutRules> = try build()
        var object: [String: Any] = try object(catalog)
        object["digest"] = String(repeating: "0", count: 64)
        let bytes: Data = try data(object)
        #expect(throws: ContentError.edited) {
            _ = try PuzzleCatalog<LightsOutRules>.decode(bytes)
        }
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(PuzzleCatalog<LightsOutRules>.self, from: bytes)
        }
        // Reordered entries keep valid levels but change the digest.
        var reordered: [String: Any] = try self.object(catalog)
        var entries: [Any] = try #require(reordered["entries"] as? [Any])
        entries.swapAt(0, 1)
        reordered["entries"] = entries
        let reorderedBytes: Data = try data(reordered)
        #expect(throws: ContentError.edited) {
            _ = try PuzzleCatalog<LightsOutRules>.decode(reorderedBytes)
        }
    }

    @Test("the initialiser refuses a bad id and 0 or more than 1,000 entries, and accepts duplicates")
    func initialiserRules() throws {
        let catalog: PuzzleCatalog<LightsOutRules> = try build()
        let entry: PuzzleCatalogEntry<LightsOutRules> = catalog.entries[0]
        #expect(throws: ContentError.plan("id")) {
            _ = try PuzzleCatalog<LightsOutRules>(id: "Bad Id", entries: [entry])
        }
        #expect(throws: ContentError.plan("id")) {
            _ = try PuzzleCatalog<LightsOutRules>(id: "", entries: [entry])
        }
        #expect(throws: ContentError.plan("entries")) {
            _ = try PuzzleCatalog<LightsOutRules>(id: "ok", entries: [])
        }
        let tooMany: [PuzzleCatalogEntry<LightsOutRules>] = Array(repeating: entry, count: 1_001)
        #expect(throws: ContentError.plan("entries")) {
            _ = try PuzzleCatalog<LightsOutRules>(id: "ok", entries: tooMany)
        }
        let most: [PuzzleCatalogEntry<LightsOutRules>] = Array(repeating: entry, count: 1_000)
        let full: PuzzleCatalog<LightsOutRules> = try PuzzleCatalog<LightsOutRules>(id: "ok", entries: most)
        #expect(full.entries.count == 1_000)

        let duplicates: PuzzleCatalog<LightsOutRules> = try PuzzleCatalog<LightsOutRules>(id: "dup",
                                                                                         entries: [entry, entry])
        let identity: String = entry.level.identity
        #expect(duplicates.digest == PuzzleCatalog<LightsOutRules>.digest(id: "dup", identities: [identity, identity]))
        let decoded: PuzzleCatalog<LightsOutRules> = try PuzzleCatalog<LightsOutRules>.decode(duplicates.encoded())
        #expect(decoded == duplicates)
    }

    @Test("the digest is SHA-256 of the id and identities, each followed by a newline")
    func digestDefinition() throws {
        let expected: String = StableHashProbe.sha256("abc\nx\ny\n")
        #expect(PuzzleCatalog<LightsOutRules>.digest(id: "abc", identities: ["x", "y"]) == expected)
        #expect(PuzzleCatalog<LightsOutRules>.digest(id: "abc", identities: []) == StableHashProbe.sha256("abc\n"))
        // Known SHA-256 of "abc\n".
        #expect(StableHashProbe.sha256("abc\n")
            == "edeaaff3f1774ad2888673770c6d64097e391bc362d7d6fb34982ddf0efd18cb")
    }

    @Test("an unchecked value with a stated digest keeps it; reason codes are stable")
    func uncheckedAndCodes() throws {
        let catalog: PuzzleCatalog<LightsOutRules> = try build()
        let wrong: PuzzleCatalog<LightsOutRules> = PuzzleCatalog<LightsOutRules>(id: catalog.id,
                                                                                entries: catalog.entries,
                                                                                digest: "x")
        #expect(wrong.digest == "x")
        #expect(throws: ContentError.edited) {
            _ = try PuzzleCatalog<LightsOutRules>.decode(wrong.encoded())
        }
        #expect(ContentError.planFailed(stage: 0, calls: 1).reasonCode == "r2-f24.plan-failed")
        #expect(ContentError.progression(4).reasonCode == "r2-f24.progression")
        #expect(ContentError.edited.reasonCode == "r2-f24.edited")
    }
}

/// SHA-256 of a string's UTF-8, through the same hash the catalog uses.
private enum StableHashProbe {
    static func sha256(_ text: String) -> String {
        StableHash.sha256Hex(Array(text.utf8))
    }
}
