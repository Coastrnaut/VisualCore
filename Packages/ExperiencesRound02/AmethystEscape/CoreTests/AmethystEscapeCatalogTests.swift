// AmethystEscapeCatalogTests — feature 362 (R02-G07-02) T-R02G0702-006 (FR-R02G0702-001, 003, 004, 005;
// SC-R02G0702-001 … 005). The 100-level catalog: manifest shape, the pinned digest, the progression rule and band means,
// every stored witness replayed to a win through the play and advances alone never escaping, an independent depth-limited
// search on levels 1, 11, … 91 (no sequence shorter than the solver's count escapes; one of that length does), and the
// witness files in docs/games/amethyst-escape/levels/ compared byte for byte with the regenerated witnesses, one test per
// band. The files are written only when AMETHYST_ESCAPE_WRITE_WITNESSES=1 is set. Test data uses explicit types and plain
// loops (CI type-check rule).
@testable import AmethystEscapeCore
import Foundation
import Testing
import VisualCoreSimulation

/// The levels of manifest numbers `numbers`, generated in order.
private func generate(_ numbers: ClosedRange<Int>) -> Result<[AmethystEscapeGenerated], any Error> {
    Result {
        var result: [AmethystEscapeGenerated] = []
        for number in numbers {
            result.append(try AmethystEscapeGenerator.generate(AmethystEscapeManifest.entries[number - 1]))
        }
        return result
    }
}

// Each band is generated once per test process, on first use, so no single test waits for the whole catalog.
private let band1: Result<[AmethystEscapeGenerated], any Error> = generate(1...20)
private let band2: Result<[AmethystEscapeGenerated], any Error> = generate(21...40)
private let band3: Result<[AmethystEscapeGenerated], any Error> = generate(41...60)
private let band4: Result<[AmethystEscapeGenerated], any Error> = generate(61...80)
private let band5: Result<[AmethystEscapeGenerated], any Error> = generate(81...100)

/// The generated levels of band `band` (1 … 5: levels 20·(band − 1) + 1 … 20·band).
private func generatedBand(_ band: Int) throws -> [AmethystEscapeGenerated] {
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
    .appendingPathComponent("docs/games/amethyst-escape/levels", isDirectory: true)

/// The 100 stored witnesses, decoded (and so re-verified) once per test process, in manifest order.
private let stored: Result<[AmethystEscapeWitness], any Error> = Result { try decodeStoredWitnesses() }

/// The 100 stored witnesses.
private func storedWitnesses() throws -> [AmethystEscapeWitness] { try stored.get() }

/// The file name of level `number`'s witness.
private func witnessName(_ number: Int) -> String {
    String(AmethystEscapeGenerator.levelID(number).suffix(3)) + ".witness.json"
}

/// Decodes the 100 stored witness files in manifest order.
private func decodeStoredWitnesses() throws -> [AmethystEscapeWitness] {
    var result: [AmethystEscapeWitness] = []
    for entry in AmethystEscapeManifest.entries {
        let url: URL = witnessDirectory.appendingPathComponent(witnessName(entry.number))
        result.append(try AmethystEscapeWitness.decode(Data(contentsOf: url)))
    }
    return result
}

/// An independent depth-limited search: whether some sequence of at most `depth` moves from `crystal` escapes, trying
/// every rotation of every shell in both directions and the advance, memoised on (state, depth left).
private struct EscapeSearch {
    let level: AmethystEscapeLevel
    var seen: Set<Int> = []

    init(level: AmethystEscapeLevel) { self.level = level }

    /// Whether an escape exists within `depth` moves.
    mutating func escapes(_ crystal: AmethystEscapeCrystal, within depth: Int) -> Bool {
        if depth == 0 { return false }
        let key: Int = AmethystEscapeSolver.encode(crystal, level: level) * 64 + depth
        if seen.contains(key) { return false }
        seen.insert(key)
        switch crystal.transition(level: level) {
        case .exited: return true
        case let .moved(pocket):
            if escapes(crystal.placing(pearl: pocket), within: depth - 1) { return true }
        case .stuck, .wedge:
            break
        }
        for shell in level.shells.indices {
            for step in [1, -1] {
                if escapes(crystal.rotating(shell: shell, step: step, level: level), within: depth - 1) { return true }
            }
        }
        return false
    }
}

@Suite struct AmethystEscapeCatalogTests {
    /// The pinned catalog digest; an intended rule or seed change re-pins it after review.
    static let pinnedDigest = "e65c452967b32b37446b6bff95faa9e7c728931d9af0457b3ddd5bc0772394e6"

    @Test func manifestHasOneHundredEntriesTwentyPerBand() {
        let entries: [AmethystEscapeManifestEntry] = AmethystEscapeManifest.entries
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
        #expect(entries[0].seed == 0x3a12398d70a2912d)
    }

    /// The digest over the stored levels' fingerprints (equal to the generated ones: see the band tests) is pinned; the
    /// ids follow the manifest.
    @Test func catalogMatchesThePinnedDigest() throws {
        let witnesses: [AmethystEscapeWitness] = try storedWitnesses()
        #expect(witnesses.count == 100)
        var levels: [AmethystEscapeLevel] = []
        for (index, witness) in witnesses.enumerated() {
            levels.append(witness.level)
            #expect(witness.number == index + 1)
            #expect(witness.level.id == AmethystEscapeGenerator.levelID(index + 1))
        }
        let digest: String = AmethystEscapeGenerator.catalogDigest(levels)
        #expect(digest == Self.pinnedDigest, "catalog digest \(digest)")
        #expect(Set(levels.map(\.fingerprint)).count == 100)
    }

    /// Solvable within the budget, inside each band's range; the progression rule and the band means of the smallest
    /// count (never falling) hold over the stored difficulties.
    @Test func everyLevelIsSolvableWithinItsBudgetAndKeepsTheProgression() throws {
        let witnesses: [AmethystEscapeWitness] = try storedWitnesses()
        var difficulties: [PuzzleDifficulty] = []
        var sumSmallest: [Int] = [0, 0, 0, 0, 0]
        for witness in witnesses {
            let level: AmethystEscapeLevel = witness.level
            #expect(witness.actions.count == witness.difficulty.smallest)
            #expect(witness.actions.count <= level.budget)
            let profile: AmethystEscapeBandProfile = AmethystEscapeBandProfile.of(band: level.difficulty)
            #expect(profile.smallest.contains(witness.difficulty.smallest))
            #expect(level.sectors == profile.sectors && level.shells.count == profile.shells)
            difficulties.append(witness.difficulty.puzzleDifficulty)
            sumSmallest[level.difficulty - 1] += witness.difficulty.smallest
        }
        #expect(ProgressionRule.standard.breach(difficulties) == nil)
        for band in 1..<5 {
            #expect(sumSmallest[band] >= sumSmallest[band - 1], "mean smallest falls at band \(band + 1): \(sumSmallest)")
        }
    }

    /// SC-R02G0702-001 and 005 for all 100 levels: the witness actions replayed on a play win within the budget, and
    /// advances alone never escape.
    @Test func everyStoredWitnessWins() throws {
        for witness in try storedWitnesses() {
            let level: AmethystEscapeLevel = witness.level
            var play = AmethystEscapePlay(level: level)
            try play.handle(.begin)
            if level.tutorial { try play.handle(.dismissTutorial) }
            for action in witness.actions { try play.apply(action, expecting: play.fingerprint) }
            #expect(play.stage == .won, "\(level.id) is not won by its witness")
            #expect(play.moves <= level.budget)
            #expect(!AmethystEscapeSolver.escapesByAdvancing(level), "\(level.id) escapes by advances alone")
        }
    }

    /// SC-R02G0702-002 on levels 1, 11, … 91: an independent depth-limited search over every move finds no escape in
    /// fewer moves than the solver's count and one in exactly that many.
    @Test(arguments: [1, 11, 21, 31, 41, 51, 61, 71, 81, 91])
    func theSolverAgreesWithAnIndependentSearch(number: Int) throws {
        let witness: AmethystEscapeWitness = try storedWitnesses()[number - 1]
        let level: AmethystEscapeLevel = witness.level
        let smallest: Int = witness.difficulty.smallest
        var shorter = EscapeSearch(level: level)
        let escapesSooner: Bool = shorter.escapes(AmethystEscapeCrystal(level: level), within: smallest - 1)
        #expect(!escapesSooner, "level \(number) escapes in fewer than \(smallest) moves")
        var exact = EscapeSearch(level: level)
        let escapesThen: Bool = exact.escapes(AmethystEscapeCrystal(level: level), within: smallest)
        #expect(escapesThen, "level \(number) does not escape in \(smallest) moves")
    }

    /// The witness files of band `band` equal the regenerated witnesses byte for byte (written only with
    /// AMETHYST_ESCAPE_WRITE_WITNESSES=1).
    @Test(arguments: [1, 2, 3, 4, 5])
    func witnessFilesMatchByteForByte(band: Int) throws {
        let catalog: [AmethystEscapeGenerated] = try generatedBand(band)
        let write: Bool = ProcessInfo.processInfo.environment["AMETHYST_ESCAPE_WRITE_WITNESSES"] == "1"
        if write { try FileManager.default.createDirectory(at: witnessDirectory, withIntermediateDirectories: true) }
        for generated in catalog {
            let witness: AmethystEscapeWitness = try AmethystEscapeWitness.make(generated)
            let data: Data = witness.encoded()
            let url: URL = witnessDirectory.appendingPathComponent(witnessName(generated.entry.number))
            if write { try data.write(to: url) }
            let stored: Data = try Data(contentsOf: url)
            #expect(stored == data, "\(witnessName(generated.entry.number)) differs from the regenerated witness")
            #expect(try AmethystEscapeWitness.decode(stored) == witness)
        }
    }

    @Test func thereAreOneHundredWitnessFiles() throws {
        let names: [String] = try FileManager.default.contentsOfDirectory(atPath: witnessDirectory.path)
            .filter { $0.hasSuffix(".witness.json") }
        #expect(names.count == 100)
    }
}
