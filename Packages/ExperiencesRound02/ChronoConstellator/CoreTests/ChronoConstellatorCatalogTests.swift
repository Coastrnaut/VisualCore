// ChronoConstellatorCatalogTests — feature 352 (R02-G06-02) T-R02G0602-006 (FR-R02G0602-001, 003, 004, 005;
// SC-R02G0602-001 … 005). The 100-level catalog: manifest shape, the pinned digest, the progression rule and band means,
// every stored witness replayed to a win through the play, an independent brute force on levels 1, 11, … 91 (every
// phase-only timeline of fewer edits than the solver's count, and on the band 1–2 samples every timeline adding one hold
// of starts 1 … 32 and lengths 1 … 32), and the witness files in docs/games/chrono-constellator/levels/ compared byte for
// byte with the regenerated witnesses, one test per band. The files are written only when
// CHRONO_CONSTELLATOR_WRITE_WITNESSES=1 is set. Test data uses explicit types and plain loops (CI type-check rule).
@testable import ChronoConstellatorCore
import Foundation
import Testing
import VisualCoreSimulation

/// The levels of manifest numbers `numbers`, generated in order.
private func generate(_ numbers: ClosedRange<Int>) -> Result<[ChronoConstellatorGenerated], any Error> {
    Result {
        var result: [ChronoConstellatorGenerated] = []
        for number in numbers {
            result.append(try ChronoConstellatorGenerator.generate(ChronoConstellatorManifest.entries[number - 1]))
        }
        return result
    }
}

// Each band is generated once per test process, on first use, so no single test waits for the whole catalog.
private let band1: Result<[ChronoConstellatorGenerated], any Error> = generate(1...20)
private let band2: Result<[ChronoConstellatorGenerated], any Error> = generate(21...40)
private let band3: Result<[ChronoConstellatorGenerated], any Error> = generate(41...60)
private let band4: Result<[ChronoConstellatorGenerated], any Error> = generate(61...80)
private let band5: Result<[ChronoConstellatorGenerated], any Error> = generate(81...100)

/// The generated levels of band `band` (1 … 5: levels 20·(band − 1) + 1 … 20·band).
private func generatedBand(_ band: Int) throws -> [ChronoConstellatorGenerated] {
    switch band {
    case 1: try band1.get()
    case 2: try band2.get()
    case 3: try band3.get()
    case 4: try band4.get()
    default: try band5.get()
    }
}

/// The repository's witness directory, found from this file.
private let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/chrono-constellator/levels", isDirectory: true)

/// The 100 stored witnesses, decoded (and so re-verified) once per test process, in manifest order.
private let stored: Result<[ChronoConstellatorWitness], any Error> = Result { try decodeStoredWitnesses() }

/// The 100 stored witnesses.
private func storedWitnesses() throws -> [ChronoConstellatorWitness] { try stored.get() }

/// The file name of level `number`'s witness.
private func witnessName(_ number: Int) -> String {
    String(ChronoConstellatorGenerator.levelID(number).suffix(3)) + ".witness.json"
}

/// Decodes the 100 stored witness files in manifest order.
private func decodeStoredWitnesses() throws -> [ChronoConstellatorWitness] {
    var result: [ChronoConstellatorWitness] = []
    for entry in ChronoConstellatorManifest.entries {
        let url: URL = witnessDirectory.appendingPathComponent(witnessName(entry.number))
        result.append(try ChronoConstellatorWitness.decode(Data(contentsOf: url)))
    }
    return result
}

/// Whether `timeline` wins `level` before the tick limit, judged by the kernel's evaluation tick by tick.
private func wins(_ level: ChronoConstellatorLevel, _ timeline: ChronoConstellatorTimeline) -> Bool {
    for tick in 1...level.tickLimit {
        let verdict: ChronoConstellatorVerdict = ChronoConstellatorEvaluation.verdict(
            positions: timeline.positions(at: tick, level: level), tick: tick, level: level)
        switch verdict {
        case .running: continue
        case .won: return true
        case .failed: return false
        }
    }
    return false
}

@Suite struct ChronoConstellatorCatalogTests {
    /// The pinned catalog digest; an intended rule or seed change re-pins it after review.
    static let pinnedDigest = "6483b20ee7d44efad49b5cc0607c8c62d38a177ace8a5390fceb9b637a986ffc"

    @Test func manifestHasOneHundredEntriesTwentyPerBand() {
        let entries: [ChronoConstellatorManifestEntry] = ChronoConstellatorManifest.entries
        #expect(entries.count == 100)
        var perBand: [Int] = [0, 0, 0, 0, 0]
        for (index, entry) in entries.enumerated() {
            #expect(entry.number == index + 1)
            #expect((1...5).contains(entry.band))
            #expect((8...19).contains(entry.budget))
            perBand[entry.band - 1] += 1
        }
        #expect(perBand == [20, 20, 20, 20, 20])
        #expect(Set(entries.map(\.seed)).count == 100)
        #expect(entries[0].seed == 0x99994f80a5c46202)
    }

    /// The digest over the stored levels' fingerprints (equal to the generated ones: see the band tests) is pinned; the
    /// ids follow the manifest.
    @Test func catalogMatchesThePinnedDigest() throws {
        let witnesses: [ChronoConstellatorWitness] = try storedWitnesses()
        #expect(witnesses.count == 100)
        var levels: [ChronoConstellatorLevel] = []
        for (index, witness) in witnesses.enumerated() {
            levels.append(witness.level)
            #expect(witness.number == index + 1)
            #expect(witness.level.id == ChronoConstellatorGenerator.levelID(index + 1))
        }
        let digest: String = ChronoConstellatorGenerator.catalogDigest(levels)
        #expect(digest == Self.pinnedDigest, "catalog digest \(digest)")
        #expect(Set(levels.map(\.fingerprint)).count == 100)
    }

    /// Solvable within the budget, inside each band's range; the progression rule and the band means of the smallest
    /// count (never falling) hold over the stored difficulties.
    @Test func everyLevelIsSolvableWithinItsBudgetAndKeepsTheProgression() throws {
        let witnesses: [ChronoConstellatorWitness] = try storedWitnesses()
        var difficulties: [PuzzleDifficulty] = []
        var sumSmallest: [Int] = [0, 0, 0, 0, 0]
        for witness in witnesses {
            let level: ChronoConstellatorLevel = witness.level
            var edits: Int = 0
            for action in witness.actions {
                if case .step = action { continue }
                edits += 1
            }
            #expect(edits == witness.difficulty.smallest)
            #expect(edits <= level.budget)
            let profile: ChronoConstellatorBandProfile = ChronoConstellatorBandProfile.of(band: level.difficulty)
            #expect(profile.smallest.contains(witness.difficulty.smallest))
            #expect(witness.difficulty.blocked >= profile.blocked)
            difficulties.append(witness.difficulty.puzzleDifficulty)
            sumSmallest[level.difficulty - 1] += witness.difficulty.smallest
        }
        #expect(ProgressionRule.standard.breach(difficulties) == nil)
        for band in 1..<5 {
            #expect(sumSmallest[band] >= sumSmallest[band - 1], "mean smallest falls at band \(band + 1): \(sumSmallest)")
        }
    }

    /// SC-R02G0602-001 and 005 for all 100 levels: the witness actions replayed on a play win within the budget and the
    /// tick limit at the recorded tick, and the level fails without edits.
    @Test func everyStoredWitnessWins() throws {
        for witness in try storedWitnesses() {
            let level: ChronoConstellatorLevel = witness.level
            var play = ChronoConstellatorPlay(level: level)
            try play.handle(.begin)
            if level.tutorial { try play.handle(.dismissTutorial) }
            for action in witness.actions { try play.apply(action, expecting: play.fingerprint) }
            #expect(play.stage == .won, "\(level.id) is not won by its witness")
            #expect(play.tick == witness.winTick)
            #expect(play.tick <= level.tickLimit)
            #expect(play.spent <= level.budget)
            #expect(!wins(level, ChronoConstellatorTimeline(level: level)), "\(level.id) is won without edits")
        }
    }

    /// SC-R02G0602-002 on levels 1, 11, … 91: an independent brute force over every phase-only timeline of fewer edits
    /// than the solver's count (every subset of stars and every offset), each judged tick by tick, finds no win; on the
    /// band 1–2 samples (counts ≤ 2) every such timeline plus one hold of starts 1 … 32 and lengths 1 … 32 finds none either.
    @Test(arguments: [1, 11, 21, 31, 41, 51, 61, 71, 81, 91])
    func theSolverAgreesWithABruteForce(number: Int) throws {
        let witness: ChronoConstellatorWitness = try storedWitnesses()[number - 1]
        let level: ChronoConstellatorLevel = witness.level
        let smallest: Int = witness.difficulty.smallest
        let withHolds: Bool = level.difficulty <= 2
        var found: Bool = false
        var timelines: Int = 0
        // Every phase-only timeline of `size` changed stars, `size` < smallest, by recursion over the stars.
        func visit(star: Int, changed: Int, size: Int, timeline: ChronoConstellatorTimeline) {
            if found { return }
            if star == level.stars.count {
                guard changed == size else { return }
                timelines += 1
                if wins(level, timeline) { found = true }
                if withHolds && size + 1 < smallest {
                    for s in 1...min(32, level.tickLimit) {
                        for k in 1...32 where s + k - 1 <= level.tickLimit {
                            for held in level.stars.indices {
                                let hold = ChronoConstellatorHold(star: held, start: s, length: k)
                                guard let next = try? timeline.adding(hold, level: level) else { continue }
                                timelines += 1
                                if wins(level, next) { found = true; return }
                            }
                        }
                    }
                }
                return
            }
            visit(star: star + 1, changed: changed, size: size, timeline: timeline)
            guard changed < size else { return }
            for offset in 0..<level.stars[star].length where offset != level.stars[star].phase {
                guard let next = try? timeline.settingPhase(star: star, to: offset, level: level) else { continue }
                visit(star: star + 1, changed: changed + 1, size: size, timeline: next)
            }
        }
        for size in 0..<smallest where !found {
            visit(star: 0, changed: 0, size: size, timeline: ChronoConstellatorTimeline(level: level))
        }
        #expect(!found, "level \(number) is won with fewer than the solver's \(smallest) edits")
        #expect(timelines > 0)
    }

    /// The witness files of band `band` equal the regenerated witnesses byte for byte (written only with
    /// CHRONO_CONSTELLATOR_WRITE_WITNESSES=1).
    @Test(arguments: [1, 2, 3, 4, 5])
    func witnessFilesMatchByteForByte(band: Int) throws {
        let catalog: [ChronoConstellatorGenerated] = try generatedBand(band)
        let write: Bool = ProcessInfo.processInfo.environment["CHRONO_CONSTELLATOR_WRITE_WITNESSES"] == "1"
        if write { try FileManager.default.createDirectory(at: witnessDirectory, withIntermediateDirectories: true) }
        for generated in catalog {
            let witness: ChronoConstellatorWitness = try ChronoConstellatorWitness.make(generated)
            let data: Data = witness.encoded()
            let url: URL = witnessDirectory.appendingPathComponent(witnessName(generated.entry.number))
            if write { try data.write(to: url) }
            let stored: Data = try Data(contentsOf: url)
            #expect(stored == data, "\(witnessName(generated.entry.number)) differs from the regenerated witness")
            #expect(try ChronoConstellatorWitness.decode(stored) == witness)
        }
    }

    @Test func thereAreOneHundredWitnessFiles() throws {
        let names: [String] = try FileManager.default.contentsOfDirectory(atPath: witnessDirectory.path)
            .filter { $0.hasSuffix(".witness.json") }
        #expect(names.count == 100)
    }
}
