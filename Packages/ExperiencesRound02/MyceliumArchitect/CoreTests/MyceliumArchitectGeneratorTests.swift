// MyceliumArchitectGeneratorTests — feature 512 (R02-G22-02) T-R02G2202-005 (FR-R02G2202-001, 007; clarification Q2).
// Host checks of the level generator: the manifest (100 entries, numbers 1 … 100, 20 per band, budgets 8 … 11,
// 10 … 13, 12 … 15, 14 … 17, 16 … 19 by band, five emphases × 20, five concepts × 20); generation determinism (the
// same entry generated twice gives equal levels and fingerprints, a candidate drawn twice is equal); the generated
// levels against their band profile (board sides, terminal count, site count, seed limit, pulses, strength, reach,
// curvature and obstacle penalties, fixed nutrients, budget = manifest budget, tutorial on levels 1 … 3, the id
// `mycelium-architect-NNN`, difficulty = band, sites declared, weight limit ≤ nutrient budget); the emphasised kind in
// the generator's plan, seen through the limits it leaves on the level; terminals never on sites or fixed nutrients;
// the neighbour rule (FR-R02G2202-007): `sameBoard` directly, consecutive generated levels never share a board, and the
// accepted candidate is skipped when the previous level is the accepted level itself; the refusal `.generation(n)` for
// an entry whose band the level rules refuse; `replayWins` for every generated plan; and the content pipeline's sources
// (Core/Content) hold no clock, floating point or run-time trigonometry. Only a few entries per band are generated
// (cached in a `static let`), never the whole catalog. Explicit types and plain loops keep the type checker fast on CI.
import Foundation
import Testing
import VisualCoreSimulation
@testable import MyceliumArchitectCore

@Suite struct MyceliumArchitectGeneratorTests {
    typealias Generator = MyceliumArchitectGenerator
    typealias Generated = MyceliumArchitectGeneratedLevel
    typealias Profile = MyceliumArchitectBandProfile

    /// The sampled manifest numbers, chained in runs of consecutive numbers (each previous is the one before it).
    /// Every band has entries whose emphasis names a kind (place nutrient, seed filament, block toxin).
    static let sampleRuns: [[Int]] = [[1, 2, 3, 4, 5], [23, 24, 25], [43, 44, 45], [63, 64, 65], [83, 84, 85]]

    /// The budget range of each band, 1 … 5.
    static let bandBudgets: [ClosedRange<Int>] = [8...11, 10...13, 12...15, 14...17, 16...19]

    /// The five control emphases.
    static let emphases: [String] = ["steer growth", "commit graph", "place nutrient", "seed filament", "block toxin"]

    /// The five required concepts.
    static let concepts: [String] = ["bounded branching graph", "shortest-path nutrients", "root terminal connectivity",
                                     "toxic-zone avoidance", "growth budget"]

    /// The manifest entry of `number`.
    static func entry(_ number: Int) -> MyceliumArchitectManifestEntry {
        MyceliumArchitectManifest.entries[number - 1]
    }

    /// The generated levels of `sampleRuns`, keyed by number; a refused entry is left out (and fails `sampled`).
    static let generated: [Int: Generated] = {
        var result: [Int: Generated] = [:]
        for run in sampleRuns {
            var previous: MyceliumArchitectLevel? = nil
            for number in run {
                let level: Generated? = try? Generator.generate(entry(number), previous: previous)
                if let level { result[number] = level }
                previous = level?.level
            }
        }
        return result
    }()

    /// Every sampled number in manifest order.
    static var sampledNumbers: [Int] {
        var numbers: [Int] = []
        for run in sampleRuns { numbers.append(contentsOf: run) }
        return numbers
    }

    // MARK: - Manifest

    /// The manifest has 100 entries numbered 1 … 100, 20 per band, budgets in the band's range.
    @Test func manifestShape() {
        let entries: [MyceliumArchitectManifestEntry] = MyceliumArchitectManifest.entries
        #expect(entries.count == 100)
        var perBand: [Int] = [0, 0, 0, 0, 0]
        var seeds: Set<UInt64> = []
        for (offset, entry) in entries.enumerated() {
            #expect(entry.number == offset + 1)
            let expectedBand: Int = offset / 20 + 1
            #expect(entry.band == expectedBand, "entry \(entry.number) band")
            if (1...5).contains(entry.band) {
                perBand[entry.band - 1] += 1
                #expect(Self.bandBudgets[entry.band - 1].contains(entry.budget), "entry \(entry.number) budget")
            }
            seeds.insert(entry.plannedSeed)
        }
        #expect(perBand == [20, 20, 20, 20, 20])
        #expect(seeds.count == 100)
    }

    /// Five emphases and five concepts, 20 entries each.
    @Test func manifestEmphasesAndConcepts() {
        var emphasisCounts: [String: Int] = [:]
        var conceptCounts: [String: Int] = [:]
        for entry in MyceliumArchitectManifest.entries {
            emphasisCounts[entry.emphasis, default: 0] += 1
            conceptCounts[entry.concept, default: 0] += 1
        }
        #expect(emphasisCounts.count == 5)
        #expect(conceptCounts.count == 5)
        for emphasis in Self.emphases { #expect(emphasisCounts[emphasis] == 20, "\(emphasis)") }
        for concept in Self.concepts { #expect(conceptCounts[concept] == 20, "\(concept)") }
    }

    // MARK: - Generation

    /// Every sampled entry generates.
    @Test func sampled() {
        for number in Self.sampledNumbers {
            #expect(Self.generated[number] != nil, "entry \(number) refused")
        }
    }

    /// Generating the same entry twice gives equal levels and fingerprints; a candidate drawn twice is equal.
    @Test func deterministic() throws {
        let numbers: [Int] = [1, 23, 43, 63, 83]
        for number in numbers {
            let first: Generated = try Generator.generate(Self.entry(number), previous: nil)
            let second: Generated = try Generator.generate(Self.entry(number), previous: nil)
            #expect(first == second, "entry \(number)")
            #expect(first.level.fingerprint == second.level.fingerprint)
            #expect(first.level == Self.generated[number]?.level)
            let again: Generated? = Generator.candidate(Self.entry(number), index: first.skipped, previous: nil)
            #expect(again == first)
        }
    }

    /// The generated levels respect their band profile and their manifest entry.
    @Test func bandProfiles() throws {
        for number in Self.sampledNumbers {
            let generated: Generated = try #require(Self.generated[number])
            let entry: MyceliumArchitectManifestEntry = Self.entry(number)
            let level: MyceliumArchitectLevel = generated.level
            let profile: Profile = Profile.band(entry.band)
            #expect(generated.entry == entry)
            #expect(profile.sides.contains(level.width), "entry \(number) width")
            #expect(profile.sides.contains(level.height), "entry \(number) height")
            #expect(profile.terminals.contains(level.terminals.count), "entry \(number) terminals")
            #expect(level.sites?.count == profile.sites, "entry \(number) sites")
            #expect(profile.fixedNutrients.contains(level.fixedNutrients.count), "entry \(number) fixed")
            #expect(level.maxSeeds == profile.seedLimit, "entry \(number) seed limit")
            #expect(level.startSeeds.count <= profile.seedLimit)
            #expect(level.pulses == profile.pulses, "entry \(number) pulses")
            #expect(profile.strength.contains(level.strength), "entry \(number) strength")
            #expect(profile.reach.contains(level.reach), "entry \(number) reach")
            #expect(profile.curvature.contains(level.curvature), "entry \(number) curvature")
            #expect(profile.obstacle.contains(level.obstacle), "entry \(number) obstacle")
            #expect(level.budget == entry.budget, "entry \(number) budget")
            #expect(level.tutorial == (number <= 3), "entry \(number) tutorial")
            #expect(level.id == String(format: "mycelium-architect-%03d", number))
            #expect(level.difficulty == entry.band)
            #expect(level.seed == entry.plannedSeed)
            #expect(level.sites != nil)
            #expect(level.weightLimit <= level.nutrientBudget, "entry \(number) weight limit")
            #expect(generated.solution.length == profile.plan, "entry \(number) plan length")
            #expect(generated.skipped >= 0 && generated.skipped < Generator.candidateBound)
            #expect(generated.difficulty == MyceliumArchitectDifficulty(level: level, solution: generated.solution))
        }
    }

    /// The emphasised kind is the generator plan's first action when the emphasis names one (it always can at step
    /// 0: no seed is planned yet and every site is free). The plan is not stored, so it shows through the limits it
    /// leaves: a planned nutrient (blocker) lifts the nutrient (blocker) limit to at least 2, a planned seed leaves a
    /// seed free beyond the starting seeds.
    @Test func emphasisedKindInPlan() throws {
        var checked: Int = 0
        for number in Self.sampledNumbers {
            let generated: Generated = try #require(Self.generated[number])
            let level: MyceliumArchitectLevel = generated.level
            switch Self.entry(number).emphasis {
            case "place nutrient":
                #expect(level.maxNutrients >= 2, "entry \(number)")
                checked += 1
            case "block toxin":
                #expect(level.maxBlockers >= 2, "entry \(number)")
                checked += 1
            case "seed filament":
                #expect(level.startSeeds.count < level.maxSeeds, "entry \(number)")
                checked += 1
            default:
                break
            }
        }
        #expect(checked >= 10)
    }

    /// Terminals are never sites or fixed nutrients, nor the root, rocks or toxins.
    @Test func terminalsAreFree() throws {
        for number in Self.sampledNumbers {
            let level: MyceliumArchitectLevel = try #require(Self.generated[number]).level
            let sites: Set<MyceliumArchitectCell> = Set(level.sites ?? [])
            let fixed: Set<MyceliumArchitectCell> = Set(level.fixedNutrients)
            let blocked: Set<MyceliumArchitectCell> = Set(level.rocks + level.toxins + [level.root])
            for terminal in level.terminals {
                #expect(!sites.contains(terminal), "entry \(number) terminal on a site")
                #expect(!fixed.contains(terminal), "entry \(number) terminal on a fixed nutrient")
                #expect(!blocked.contains(terminal), "entry \(number) terminal on a feature")
            }
        }
    }

    /// Every generated plan wins through the play; a truncated plan does not.
    @Test func replayWinsEveryPlan() throws {
        for number in Self.sampledNumbers {
            let generated: Generated = try #require(Self.generated[number])
            #expect(Generator.replayWins(generated.level, generated.solution.actions), "entry \(number)")
            #expect(generated.solution.actions.last == .run)
            #expect(!Generator.replayWins(generated.level, [.run]), "entry \(number) won without a plan")
        }
    }

    // MARK: - Neighbour rule (FR-R02G2202-007)

    /// `sameBoard` compares size, root, rocks and toxins only.
    @Test func sameBoardDirect() throws {
        let a: MyceliumArchitectLevel = try #require(Self.generated[1]).level
        let b: MyceliumArchitectLevel = try #require(Self.generated[2]).level
        #expect(Generator.sameBoard(a, a))
        #expect(Generator.sameBoard(b, b))
        #expect(!Generator.sameBoard(a, b))
        #expect(!Generator.sameBoard(b, a))
        // The same board with other terminals and budget is still the same board.
        let retuned: MyceliumArchitectLevel = try MyceliumArchitectLevel(
            id: "retuned", seed: 1, difficulty: a.difficulty, width: a.width, height: a.height, root: a.root,
            terminals: a.terminals, rocks: a.rocks, toxins: a.toxins, fixedNutrients: a.fixedNutrients,
            strength: a.strength, reach: a.reach, curvature: a.curvature, obstacle: a.obstacle,
            maxNutrients: a.maxNutrients, maxBlockers: a.maxBlockers, maxSeeds: a.maxSeeds, startSeeds: a.startSeeds,
            pulses: a.pulses, nutrientBudget: a.nutrientBudget, weightLimit: a.weightLimit,
            budget: a.budget == 8 ? 9 : 8, tutorial: !a.tutorial, refusingAWin: false, sites: a.sites)
        #expect(Generator.sameBoard(a, retuned))
        #expect(a.fingerprint != retuned.fingerprint)
    }

    /// Consecutive generated levels never share a board.
    @Test func consecutiveBoardsDiffer() throws {
        for run in Self.sampleRuns {
            var index: Int = 1
            while index < run.count {
                let before: MyceliumArchitectLevel = try #require(Self.generated[run[index - 1]]).level
                let after: MyceliumArchitectLevel = try #require(Self.generated[run[index]]).level
                #expect(!Generator.sameBoard(before, after), "entries \(run[index - 1]) and \(run[index])")
                index += 1
            }
        }
    }

    /// With the accepted level itself as the previous one, the accepted candidate is skipped deterministically: it
    /// is nil against its own board, the candidates before it stay nil, and `generate` moves past it.
    @Test func ownBoardIsSkipped() throws {
        let numbers: [Int] = [1, 43]
        for number in numbers {
            let entry: MyceliumArchitectManifestEntry = Self.entry(number)
            let accepted: Generated = try #require(Self.generated[number])
            #expect(Generator.candidate(entry, index: accepted.skipped, previous: accepted.level) == nil)
            var index: Int = 0
            while index < accepted.skipped {
                #expect(Generator.candidate(entry, index: index, previous: nil) == nil, "entry \(number) \(index)")
                index += 1
            }
            let next: Generated = try Generator.generate(entry, previous: accepted.level)
            #expect(next.skipped > accepted.skipped, "entry \(number)")
            #expect(!Generator.sameBoard(next.level, accepted.level))
            let again: Generated = try Generator.generate(entry, previous: accepted.level)
            #expect(again == next)
        }
    }

    /// An entry whose band the level rules refuse yields no candidate; `generate` throws `.generation(number)`.
    @Test func impossibleBandRefused() {
        let impossible: MyceliumArchitectManifestEntry = MyceliumArchitectManifestEntry(
            number: 77, plannedSeed: 0x0123_4567_89ab_cdef, band: 6, budget: 12, emphasis: "steer growth",
            concept: "growth budget")
        #expect(Generator.candidate(impossible, index: 0, previous: nil) == nil)
        var refused: MyceliumArchitectError? = nil
        do {
            _ = try Generator.generate(impossible, previous: nil)
        } catch {
            refused = error
        }
        #expect(refused == .generation(77))
    }

    // MARK: - Digest and sources

    /// The digest is deterministic and depends on the order of the levels.
    @Test func digestDeterministic() throws {
        let a: MyceliumArchitectLevel = try #require(Self.generated[1]).level
        let b: MyceliumArchitectLevel = try #require(Self.generated[2]).level
        #expect(Generator.digest([a, b]) == Generator.digest([a, b]))
        #expect(Generator.digest([a, b]) != Generator.digest([b, a]))
    }

    /// The content sources hold no clock, floating point, run-time trigonometry or system randomness.
    @Test func contentSourcesHaveNoClockOrFloat() throws {
        let tests: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let content: URL = tests.deletingLastPathComponent().appendingPathComponent("Core/Content")
        let names: [String] = try FileManager.default.contentsOfDirectory(atPath: content.path)
            .filter { $0.hasSuffix(".swift") }.sorted()
        #expect(names.count >= 4)
        let forbidden: [String] = ["Date(", "Double", "Float", "sin(", "cos(", "random()", "CFAbsoluteTime"]
        for name in names {
            let text: String = try String(contentsOf: content.appendingPathComponent(name), encoding: .utf8)
            let cleaned: String = text.replacingOccurrences(of: "SeededRandom", with: "")
            for token in forbidden {
                #expect(!cleaned.contains(token), "\(name) contains \(token)")
            }
        }
    }
}
