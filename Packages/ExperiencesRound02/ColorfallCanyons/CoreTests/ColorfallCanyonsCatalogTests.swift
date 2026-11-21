// ColorfallCanyonsCatalogTests — feature 342 (R02-G05-02) T-R02G0502-006 (FR-R02G0502-001, 003, 004, 005;
// SC-R02G0502-001 … 005). The 100-level catalog: manifest shape, the pinned digest, regeneration, the progression rule
// and band means, every stored witness replayed to a win with zero drift, an independent brute force on levels 1, 11,
// … 91, and the witness files in docs/games/colorfall-canyons/levels/ compared byte for byte, one test per half band (so
// each test regenerates at most 10 levels). The files are written only when COLORFALL_CANYONS_WRITE_WITNESSES=1 is set.
// Test data uses explicit types and plain loops (CI type-check rule).
@testable import ColorfallCanyonsCore
import Foundation
import Testing
import VisualCoreSimulation

/// The levels of manifest numbers `numbers`, generated in order.
private func generate(_ numbers: ClosedRange<Int>) -> Result<[ColorfallCanyonsGenerated], any Error> {
    Result {
        var result: [ColorfallCanyonsGenerated] = []
        for number in numbers { result.append(try ColorfallCanyonsGenerator.generate(ColorfallCanyonsManifest.entries[number - 1])) }
        return result
    }
}

// Each half band is generated once per test process, on first use, so no single test waits for the whole catalog.
private let half01: Result<[ColorfallCanyonsGenerated], any Error> = generate(1...10)
private let half02: Result<[ColorfallCanyonsGenerated], any Error> = generate(11...20)
private let half03: Result<[ColorfallCanyonsGenerated], any Error> = generate(21...30)
private let half04: Result<[ColorfallCanyonsGenerated], any Error> = generate(31...40)
private let half05: Result<[ColorfallCanyonsGenerated], any Error> = generate(41...50)
private let half06: Result<[ColorfallCanyonsGenerated], any Error> = generate(51...60)
private let half07: Result<[ColorfallCanyonsGenerated], any Error> = generate(61...70)
private let half08: Result<[ColorfallCanyonsGenerated], any Error> = generate(71...80)
private let half09: Result<[ColorfallCanyonsGenerated], any Error> = generate(81...90)
private let half10: Result<[ColorfallCanyonsGenerated], any Error> = generate(91...100)

/// The generated levels of half band `half` (1 … 10: levels 10·(half − 1) + 1 … 10·half).
private func generatedHalf(_ half: Int) throws -> [ColorfallCanyonsGenerated] {
    switch half {
    case 1: try half01.get()
    case 2: try half02.get()
    case 3: try half03.get()
    case 4: try half04.get()
    case 5: try half05.get()
    case 6: try half06.get()
    case 7: try half07.get()
    case 8: try half08.get()
    case 9: try half09.get()
    default: try half10.get()
    }
}

/// The generated level of manifest number `number`.
private func generatedLevel(_ number: Int) throws -> ColorfallCanyonsGenerated {
    for generated in try generatedHalf((number - 1) / 10 + 1) where generated.entry.number == number { return generated }
    throw ColorfallCanyonsError.generation(number)
}

/// The repository's witness directory, found from this file.
private let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/colorfall-canyons/levels", isDirectory: true)

/// The 100 stored witnesses, decoded (and so re-verified) once per test process, in manifest order.
private let stored: Result<[ColorfallCanyonsWitness], any Error> = Result { try decodeStoredWitnesses() }

/// The 100 stored witnesses.
private func storedWitnesses() throws -> [ColorfallCanyonsWitness] { try stored.get() }

/// The file name of level `number`'s witness.
private func witnessName(_ number: Int) -> String {
    String(ColorfallCanyonsGenerator.levelID(number).suffix(3)) + ".witness.json"
}

/// Decodes the 100 stored witness files in manifest order.
private func decodeStoredWitnesses() throws -> [ColorfallCanyonsWitness] {
    var result: [ColorfallCanyonsWitness] = []
    for entry in ColorfallCanyonsManifest.entries {
        let url: URL = witnessDirectory.appendingPathComponent(witnessName(entry.number))
        result.append(try ColorfallCanyonsWitness.decode(Data(contentsOf: url)))
    }
    return result
}

@Suite struct ColorfallCanyonsCatalogTests {
    /// The pinned catalog digest; an intended rule or seed change re-pins it after review.
    static let pinnedDigest = "68eec7b5df5790cd52979d6f01fdcad576fefe02436c2c0b655813fc8f55f019"

    @Test func manifestHasOneHundredEntriesTwentyPerBand() {
        let entries: [ColorfallCanyonsManifestEntry] = ColorfallCanyonsManifest.entries
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
        #expect(entries[0].seed == 0xc65bc117d84efa83)
    }

    /// The digest over the stored levels' fingerprints (equal to the generated ones: see the half-band tests) is
    /// pinned; the ids follow the manifest.
    @Test func catalogMatchesThePinnedDigest() throws {
        let witnesses: [ColorfallCanyonsWitness] = try storedWitnesses()
        #expect(witnesses.count == 100)
        var levels: [ColorfallCanyonsLevel] = []
        for (index, witness) in witnesses.enumerated() {
            levels.append(witness.level)
            #expect(witness.number == index + 1)
            #expect(witness.level.id == ColorfallCanyonsGenerator.levelID(index + 1))
        }
        let digest: String = ColorfallCanyonsGenerator.catalogDigest(levels)
        #expect(digest == Self.pinnedDigest, "catalog digest \(digest)")
        #expect(Set(levels.map(\.fingerprint)).count == 100)
    }

    /// Solvable within the budget, inside each band's range; the progression rule and the band means of the smallest
    /// count (never falling) hold over the stored difficulties.
    @Test func everyLevelIsSolvableWithinItsBudgetAndKeepsTheProgression() throws {
        let witnesses: [ColorfallCanyonsWitness] = try storedWitnesses()
        var difficulties: [PuzzleDifficulty] = []
        var sumSmallest: [Int] = [0, 0, 0, 0, 0]
        for witness in witnesses {
            let level: ColorfallCanyonsLevel = witness.level
            var spent: Int = 0
            for action in witness.actions {
                if case .step = action { continue }
                spent += 1
            }
            #expect(spent == witness.difficulty.smallest)
            #expect(spent <= level.budget)
            let profile: ColorfallCanyonsBandProfile = ColorfallCanyonsBandProfile.of(band: level.difficulty)
            #expect(profile.smallest.contains(witness.difficulty.smallest))
            difficulties.append(witness.difficulty.puzzleDifficulty)
            sumSmallest[level.difficulty - 1] += witness.difficulty.smallest
        }
        #expect(ProgressionRule.standard.breach(difficulties) == nil)
        for band in 1..<5 {
            #expect(sumSmallest[band] >= sumSmallest[band - 1], "mean smallest falls at band \(band + 1): \(sumSmallest)")
        }
    }

    /// SC-R02G0502-001 and 005 for all 100 levels: the witness actions replayed on a play win within the budget and the
    /// tick limit with exact conservation on every tick, and the level fails without edits.
    @Test func everyStoredWitnessWinsWithZeroDrift() throws {
        for witness in try storedWitnesses() {
            let level: ColorfallCanyonsLevel = witness.level
            var play = ColorfallCanyonsPlay(level: level)
            try play.handle(.begin)
            if level.tutorial { try play.handle(.dismissTutorial) }
            for action in witness.actions {
                if case .step(let ticks) = action {
                    for _ in 0..<ticks where play.stage == .playing {
                        try play.apply(.step(1), expecting: play.fingerprint)
                        #expect(play.fluid.isConserved(), "\(level.id) drift at tick \(play.fluid.tick)")
                    }
                } else {
                    try play.apply(action, expecting: play.fingerprint)
                }
            }
            #expect(play.stage == .won, "\(level.id) is not won by its witness")
            #expect(play.fluid.tick == witness.winTick)
            #expect(play.fluid.tick <= level.tickLimit)
            let unedited = ColorfallCanyonsSolver.run(level, edits: [])
            #expect(unedited?.verdict != .won, "\(level.id) is won without edits")
        }
    }

    /// SC-R02G0502-002 on levels 1, 11, … 91: an independent brute force over every edit set up to the solver's depth
    /// (no pruning, no cache; each set run through the kernel) finds the solver's smallest count.
    @Test(arguments: [1, 11, 21, 31, 41, 51, 61, 71, 81, 91])
    func theSolverAgreesWithABruteForce(number: Int) throws {
        let level: ColorfallCanyonsLevel = try storedWitnesses()[number - 1].level
        let smallest: Int = try storedWitnesses()[number - 1].difficulty.smallest
        let moves: [ColorfallCanyonsEdit] = ColorfallCanyonsSolver.moves(level)
        var found: Int?
        for size in 0..<smallest where found == nil {
            var indices: [Int] = []
            var wins: Bool = false
            func visit(from start: Int) {
                if wins { return }
                if indices.count == size {
                    let edits: [ColorfallCanyonsEdit] = indices.map { moves[$0] }
                    if ColorfallCanyonsSolver.run(level, edits: edits)?.verdict == .won { wins = true }
                    return
                }
                guard start < moves.count else { return }
                for index in start..<moves.count {
                    indices.append(index)
                    visit(from: index)
                    indices.removeLast()
                }
            }
            visit(from: 0)
            if wins { found = size }
        }
        #expect(found == nil, "level \(number) is won with \(found ?? -1) edits, fewer than the solver's \(smallest)")
    }

    /// The witness files of half band `half` equal the regenerated witnesses byte for byte (written only with
    /// COLORFALL_CANYONS_WRITE_WITNESSES=1).
    @Test(arguments: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
    func witnessFilesMatchByteForByte(half: Int) throws {
        let catalog: [ColorfallCanyonsGenerated] = try generatedHalf(half)
        let write: Bool = ProcessInfo.processInfo.environment["COLORFALL_CANYONS_WRITE_WITNESSES"] == "1"
        if write { try FileManager.default.createDirectory(at: witnessDirectory, withIntermediateDirectories: true) }
        for generated in catalog {
            let witness: ColorfallCanyonsWitness = try ColorfallCanyonsWitness.make(generated)
            let data: Data = witness.encoded()
            let url: URL = witnessDirectory.appendingPathComponent(witnessName(generated.entry.number))
            if write { try data.write(to: url) }
            let stored: Data = try Data(contentsOf: url)
            #expect(stored == data, "\(witnessName(generated.entry.number)) differs from the regenerated witness")
            #expect(try ColorfallCanyonsWitness.decode(stored) == witness)
        }
    }

    @Test func thereAreOneHundredWitnessFiles() throws {
        let names: [String] = try FileManager.default.contentsOfDirectory(atPath: witnessDirectory.path)
            .filter { $0.hasSuffix(".witness.json") }
        #expect(names.count == 100)
    }
}
