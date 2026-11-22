// NocturneGardenGeneratorTests — feature 382 (R02-G09-02) T-R02G0902-004 (FR-R02G0902-001, 003, 005, 006;
// clarification Q1; analyze findings C1, C2). Host checks of the generator: the manifest's shape and level ids, the
// five band profiles, candidate determinism, the candidates' shape (bed, sizes, elevations, band, budget, tutorial,
// required, allowance, forbidden ring, supply with the decoy), generated levels certified at the lower bound within the
// band's range and budget with a winning witness, skipped candidates re-checked as unqualified, deterministic
// generation, difficulty metrics from a hand-built action list, the refusal reason codes and the catalog digest.
// Eight sampled entries (two per band 1 … 3, one each of bands 4 and 5), generated once per process and shared.
// Explicit types, plain loops, short runs.
import Testing
import VisualCoreSimulation
@testable import NocturneGardenCore

@Suite("NocturneGardenGenerator")
struct NocturneGardenGeneratorTests {
    /// The sampled entries: 1, 2 (tutorial, band 1), 21, 22 (band 2), 41, 42 (band 3), 61 (band 4), 81 (band 5).
    static let sampled: [NocturneGardenManifestEntry] =
        [1, 2, 21, 22, 41, 42, 61, 81].map { NocturneGardenManifest.entries[$0 - 1] }

    /// The sampled entries generated once and shared by the tests (nil where generation threw).
    static let sampledResults: [NocturneGardenGenerated?] = sampled.map { try? NocturneGardenGenerator.generate($0) }

    /// The shared certified levels of the sample; a sampled entry that did not generate is recorded as an issue.
    static func generatedSample() -> [NocturneGardenGenerated] {
        var results: [NocturneGardenGenerated] = []
        for (offset, result) in sampledResults.enumerated() {
            if let result {
                results.append(result)
            } else {
                Issue.record("level \(sampled[offset].number) did not generate")
            }
        }
        return results
    }

    /// Whether `level` fails one of the conditions `generate` requires of a candidate (clarification Q1).
    static func unqualified(_ level: NocturneGardenLevel?, profile: NocturneGardenBandProfile) -> Bool {
        guard let level else { return true }
        guard let bound: NocturneGardenBound = NocturneGardenSolver.lowerBound(level) else { return true }
        if !profile.smallest.contains(bound.smallest) || bound.smallest > level.budget { return true }
        guard let solution: NocturneGardenSolution = NocturneGardenSolver.solve(level) else { return true }
        return solution.smallest != bound.smallest
    }

    /// The manifest has 100 entries numbered 1 … 100, 20 per band in order, budgets in the band's range, and level
    /// ids are `nocturne-garden-NNN`.
    @Test func manifestShape() {
        let entries: [NocturneGardenManifestEntry] = NocturneGardenManifest.entries
        #expect(entries.count == 100)
        var perBand: [Int: Int] = [:]
        for (offset, entry) in entries.enumerated() {
            #expect(entry.number == offset + 1)
            #expect(entry.band == offset / 20 + 1)
            let low: Int = 2 * entry.band + 6
            #expect(entry.budget >= low && entry.budget <= low + 3, "level \(entry.number) budget \(entry.budget)")
            perBand[entry.band, default: 0] += 1
        }
        for band in 1...5 { #expect(perBand[band] == 20) }
        #expect(NocturneGardenManifest.source.contains("round2.md"))
        #expect(NocturneGardenGenerator.levelID(7) == "nocturne-garden-007")
        #expect(NocturneGardenGenerator.levelID(42) == "nocturne-garden-042")
        #expect(NocturneGardenGenerator.levelID(100) == "nocturne-garden-100")
    }

    /// The five band profiles are exactly those of data-model.md, and bands outside 1 … 5 clamp.
    @Test func bandProfiles() throws {
        let widths: [Int] = [16, 20, 24, 28, 32]
        let heights: [Int] = [12, 14, 16, 20, 24]
        let smallest: [ClosedRange<Int>] = [2...3, 3...4, 4...5, 5...6, 6...7]
        let sizes: [Set<Int>] = [[2], [1, 2], [1, 2, 3], [1, 2, 3], [1, 2, 3]]
        let elevations: [Set<Int>] = [[2, 3], [2, 3], [1, 2, 3, 4], [1, 2, 3, 4], [1, 2, 3, 4]]
        let blooms: [ClosedRange<Int>] = [1...2, 2...3, 3...4, 4...5, 5...6]
        let rings: [Int] = [1, 1, 2, 2, 2]
        let keeps: [Int] = [1, 1, 3, 3, 3]
        let keepDenominators: [Int] = [2, 2, 4, 4, 4]
        let required: [NocturneGardenRatio] = [try NocturneGardenRatio(4, 5), try NocturneGardenRatio(17, 20),
                                               try NocturneGardenRatio(9, 10), try NocturneGardenRatio(19, 20),
                                               try NocturneGardenRatio(1, 1)]
        let allowances: [Int] = [2, 2, 1, 1, 0]
        let decoys: [Bool] = [false, false, true, true, true]
        for band in 1...5 {
            let profile: NocturneGardenBandProfile = .of(band: band)
            let i: Int = band - 1
            #expect(profile.band == band)
            #expect(profile.width == widths[i] && profile.height == heights[i])
            #expect(profile.smallest == smallest[i])
            #expect(profile.sizes == sizes[i])
            #expect(profile.elevations == elevations[i])
            #expect(profile.blooms == blooms[i])
            #expect(profile.ring == rings[i])
            #expect(profile.keep.numerator == keeps[i] && profile.keep.denominator == keepDenominators[i])
            #expect(profile.required == required[i])
            #expect(profile.leakAllowance == allowances[i])
            #expect(profile.decoy == decoys[i])
        }
        #expect(NocturneGardenBandProfile.of(band: 0) == NocturneGardenBandProfile.of(band: 1))
        #expect(NocturneGardenBandProfile.of(band: 9) == NocturneGardenBandProfile.of(band: 5))
    }

    /// The same entry and index give the same candidate; different indices usually give different candidates.
    @Test func candidateDeterminism() {
        var distinct: Int = 0
        var compared: Int = 0
        for number in [1, 21, 41, 61, 81] {
            let entry: NocturneGardenManifestEntry = NocturneGardenManifest.entries[number - 1]
            var previous: String? = nil
            for index in 0..<6 {
                let first: NocturneGardenLevel? = NocturneGardenGenerator.candidate(entry, index: index)
                let second: NocturneGardenLevel? = NocturneGardenGenerator.candidate(entry, index: index)
                #expect(first?.fingerprint == second?.fingerprint, "level \(number) candidate \(index)")
                #expect(first == second)
                if let fingerprint = first?.fingerprint {
                    if let previous {
                        compared += 1
                        if previous != fingerprint { distinct += 1 }
                    }
                    previous = fingerprint
                }
            }
        }
        #expect(compared > 0)
        #expect(distinct * 10 >= compared * 9, "\(distinct) of \(compared) consecutive candidates differ")
    }

    /// The first ten candidates of one entry per band have the band's shape, the entry's budget and id, a forbidden
    /// ring around the target and a supply of the construction's blooms plus the decoy from band 3.
    @Test func candidateShape() {
        var checked: Int = 0
        for number in [2, 22, 42, 62, 82] {
            let entry: NocturneGardenManifestEntry = NocturneGardenManifest.entries[number - 1]
            let profile: NocturneGardenBandProfile = .of(band: entry.band)
            for index in 0..<10 {
                guard let level = NocturneGardenGenerator.candidate(entry, index: index) else { continue }
                checked += 1
                let label: String = "level \(number) candidate \(index)"
                #expect(level.id == NocturneGardenGenerator.levelID(number), "\(label)")
                #expect(level.seed == entry.seed)
                #expect(level.width == profile.width && level.height == profile.height, "\(label)")
                #expect(level.sizes == profile.sizes && level.elevations == profile.elevations, "\(label)")
                #expect(profile.elevations.contains(level.sun), "\(label)")
                #expect(level.difficulty == entry.band, "\(label)")
                #expect(level.budget == entry.budget, "\(label)")
                #expect(level.tutorial == (number <= 3), "\(label)")
                #expect(level.required == profile.required && level.leakAllowance == profile.leakAllowance)
                #expect(!level.target.isEmpty, "\(label)")
                #expect(level.forbidden.isDisjoint(with: level.target), "\(label)")
                let ringCells: Set<Int> = Set(NocturneGardenGenerator.ring(level.target, distance: profile.ring,
                                                                           width: level.width,
                                                                           height: level.height))
                #expect(level.forbidden.isSubset(of: ringCells), "\(label)")
                for cell in level.forbidden {
                    var near: Bool = false
                    for target in level.target {
                        let dc: Int = abs(cell % level.width - target % level.width)
                        let dr: Int = abs(cell / level.width - target / level.width)
                        if max(dc, dr) <= profile.ring {
                            near = true
                            break
                        }
                    }
                    #expect(near, "\(label) forbidden cell \(cell)")
                }
                let total: Int = level.supplyTotal
                let upper: Int = profile.blooms.upperBound + (profile.decoy ? 1 : 0)
                #expect(total >= profile.blooms.lowerBound && total <= upper, "\(label) supply \(total)")
                if profile.decoy {
                    var ones: Int = 0
                    for (_, count) in level.supply where count == 1 { ones += 1 }
                    #expect(ones >= 1, "\(label) has no single-count kind for the decoy")
                    if total == profile.blooms.lowerBound {
                        Issue.record("\(label): decoy band supply \(total) leaves no room for a decoy")
                    }
                } else {
                    #expect(profile.blooms.contains(total), "\(label) supply \(total)")
                }
            }
        }
        #expect(checked >= 10)
    }

    /// Each sampled level is certified: the solution meets the lower bound, lies in the band's range and budget, the
    /// witness wins, the difficulty records it, and every skipped candidate is genuinely unqualified.
    @Test func generatedLevelsAreCertified() {
        let results: [NocturneGardenGenerated] = Self.generatedSample()
        #expect(results.count == Self.sampled.count)
        for generated in results {
            let entry: NocturneGardenManifestEntry = generated.entry
            let profile: NocturneGardenBandProfile = .of(band: entry.band)
            let level: NocturneGardenLevel = generated.level
            let label: String = "level \(entry.number)"
            #expect(level.id == NocturneGardenGenerator.levelID(entry.number), "\(label)")
            #expect(generated.solution.actions.count == generated.solution.smallest, "\(label)")
            #expect(generated.solution.smallest == generated.bound.smallest, "\(label)")
            #expect(generated.difficulty.smallest == generated.solution.smallest, "\(label)")
            #expect(profile.smallest.contains(generated.solution.smallest), "\(label)")
            #expect(generated.solution.smallest <= level.budget, "\(label)")
            #expect(NocturneGardenSolver.wins(level, actions: generated.solution.actions), "\(label)")
            #expect(generated.difficulty.work == generated.solution.work, "\(label)")
            #expect(generated.difficulty.targetCells == level.target.count, "\(label)")
            #expect(generated.difficulty.forbiddenCells == level.forbidden.count, "\(label)")
            #expect(generated.skipped >= 0 && generated.skipped < NocturneGardenGenerator.maxCandidates, "\(label)")
            let chosen: NocturneGardenLevel? = NocturneGardenGenerator.candidate(entry, index: generated.skipped)
            #expect(chosen == level, "\(label)")
            for index in 0..<generated.skipped {
                let candidate: NocturneGardenLevel? = NocturneGardenGenerator.candidate(entry, index: index)
                #expect(Self.unqualified(candidate, profile: profile), "\(label) skipped candidate \(index) qualifies")
            }
        }
    }

    /// Generating the same entry twice gives equal results.
    @Test func generationIsDeterministic() throws {
        for number in [1, 41] {
            let entry: NocturneGardenManifestEntry = NocturneGardenManifest.entries[number - 1]
            let first: NocturneGardenGenerated = try NocturneGardenGenerator.generate(entry)
            let second: NocturneGardenGenerated = try NocturneGardenGenerator.generate(entry)
            #expect(first == second, "level \(number)")
            #expect(first.level.fingerprint == second.level.fingerprint)
        }
    }

    /// The difficulty of a hand-built action list counts the distinct kinds and sizes, the sun change and the
    /// level's target and forbidden cells; its R02-F24 difficulty uses the smallest move count.
    @Test func difficultyFromActions() throws {
        let level: NocturneGardenLevel = try NocturneGardenLevelTests.level()
        let actions: [NocturneGardenAction] = [.plant(.tulip, 3, 3, 1), .plant(.rose, 5, 5, 2),
                                               .plant(.tulip, 7, 7, 2), .move(0, 4, 4), .resize(1, 1), .remove(2)]
        let plain: NocturneGardenDifficulty = NocturneGardenDifficulty(level: level, actions: actions, work: 17)
        #expect(plain.smallest == 6)
        #expect(plain.kinds == 2)
        #expect(plain.sizes == 2)
        #expect(!plain.sunChange)
        #expect(plain.targetCells == 4 && plain.forbiddenCells == 2)
        #expect(plain.required == level.required)
        #expect(plain.work == 17)
        #expect(plain.puzzleDifficulty.shortest == plain.smallest)
        #expect(plain.puzzleDifficulty.explored == 17)
        let withSun: [NocturneGardenAction] = [.sun(3), .plant(.lily, 2, 2, 3)]
        let sunny: NocturneGardenDifficulty = NocturneGardenDifficulty(level: level, actions: withSun, work: 4)
        #expect(sunny.smallest == 2 && sunny.kinds == 1 && sunny.sizes == 1 && sunny.sunChange)
        #expect(sunny.puzzleDifficulty.shortest == 2)
    }

    /// The generator's refusals carry the stable reason codes.
    @Test func refusalReasonCodes() {
        let generation: NocturneGardenError = .generation(7)
        let witness: NocturneGardenError = .witness("x")
        #expect(generation.reasonCode == "r02-g09.generation")
        #expect(witness.reasonCode == "r02-g09.witness")
        #expect(generation == .generation(7) && generation != .generation(8))
        #expect(NocturneGardenGenerator.maxCandidates == 256)
    }

    /// The catalog digest is stable for the same levels and changes when their order changes.
    @Test func catalogDigestIsOrderSensitive() {
        let levels: [NocturneGardenLevel] = Self.generatedSample().map(\.level)
        #expect(levels.count >= 2)
        let digest: String = NocturneGardenGenerator.catalogDigest(levels)
        #expect(digest == NocturneGardenGenerator.catalogDigest(levels))
        #expect(!digest.isEmpty)
        let reversed: [NocturneGardenLevel] = Array(levels.reversed())
        #expect(digest != NocturneGardenGenerator.catalogDigest(reversed))
        #expect(NocturneGardenGenerator.catalogID == "nocturne-garden")
    }
}
