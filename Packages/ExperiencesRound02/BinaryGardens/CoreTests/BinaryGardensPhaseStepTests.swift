// BinaryGardensPhaseStepTests — feature 502 (R02-G21-02) T-R02G2102-002 (FR-R02G2102-006, 009; SC-R02G2102-006, 007;
// clarification Q1; research R1, R2). The kernel extension: an optional phase step g ∈ {1, 2, 3, 4, 6, 8, 12, 16, 24}.
// A level without a phase step keeps feature 501's stored form and fingerprint byte for byte (values pinned from the
// unchanged feature-501 kernel on 2026-11-27, before the extension was written); a level with one round-trips with
// `phaseStep` in its stored form and a different fingerprint; "phase step" (not a listed divisor) and "phase off grid"
// (a starting phase off the grid) are refused in that order, after "nothing adjustable" and before "separation" and
// "already won"; the play and the puzzle contract refuse a phase action off the grid with "off the phase grid" (after
// "phase out of range", before "locked"); the puzzle's move list holds the grid phases only; `allowsPhase(_:)` and
// `isWellFormed` follow the grid; the two new refusals carry their reason codes. Explicit types, plain loops.
import Foundation
import Testing
import VisualCoreMath
@testable import BinaryGardensCore

@Suite struct BinaryGardensPhaseStepTests {
    typealias Level = BinaryGardensLevel

    /// The fingerprint of ``hand(phaseStep:phases:)`` without a phase step, pinned from the feature-501 kernel.
    static let pinnedFingerprint: String = "f2cfb23cce82d3305eefeb81a7069267bcf988e33a64eb50927e739d01d74e2e"

    /// The stored form of ``hand(phaseStep:phases:)`` without a phase step, pinned from the feature-501 kernel.
    static let pinnedStoredForm: String = "{\"budget\":10,\"clampRadius\":2,\"difficulty\":1,\"fingerprint\":"
        + "\"f2cfb23cce82d3305eefeb81a7069267bcf988e33a64eb50927e739d01d74e2e\",\"id\":\"phase-step-hand\","
        + "\"lethalTolerance\":2,\"luminosityLevels\":[8,24],\"maxTilt\":2,\"minimumSeparation\":0,"
        + "\"ringRadii\":[3,6,9],\"schema\":1,\"seed\":0,\"starSpeed\":1,\"stars\":[{\"luminosity\":0,"
        + "\"luminosityAdjustable\":true,\"phase\":0,\"phaseAdjustable\":true,\"ring\":0,\"ringAdjustable\":true},"
        + "{\"luminosity\":1,\"luminosityAdjustable\":false,\"phase\":24,\"phaseAdjustable\":true,\"ring\":2,"
        + "\"ringAdjustable\":false}],\"startTilt\":0,\"tutorial\":false,\"worlds\":[{\"bloomHigh\":0,"
        + "\"bloomLow\":0,\"comfortHigh\":199999,\"comfortLow\":1,\"lethalHigh\":200000,\"lethalLow\":0,"
        + "\"phase\":0,\"radius\":20,\"speed\":1,\"window\":1}]}"

    /// The play fingerprint of a new play of the hand level without a phase step, pinned from the feature-501 kernel.
    static let pinnedPlayFingerprint: String = "b8ae2a42ab844a99de53a9c973af08778d09aff578bbd7cc17c55788ff26e6c9"

    /// One world whose bloom band is 0 … 0, so no arrangement wins (every integral is positive).
    static let world: BinaryGardensWorld = BinaryGardensWorld(radius: 20, phase: 0, speed: 1, lethalLow: 0,
                                                              comfortLow: 1, comfortHigh: 199_999,
                                                              lethalHigh: 200_000, window: 1, bloomLow: 0,
                                                              bloomHigh: 0)

    /// The hand level: rings 3, 6, 9; ω 1; luminosities 8, 24; star 1 on ring 1 (phase `phases[0]`, everything
    /// adjustable), star 2 on ring 3 (phase `phases[1]`, only its phase adjustable); T_max 2; σ `separation`.
    static func hand(phaseStep: Int = 1, phases: [Int] = [0, 24], separation: Int = 0,
                     anything: Bool = true, world: BinaryGardensWorld = world) throws(BinaryGardensError) -> Level {
        let stars: [BinaryGardensStar] = [
            BinaryGardensStar(ring: 0, phase: phases[0], luminosity: 0, ringAdjustable: anything,
                              phaseAdjustable: anything, luminosityAdjustable: anything),
            BinaryGardensStar(ring: 2, phase: phases[1], luminosity: 1, ringAdjustable: false,
                              phaseAdjustable: anything, luminosityAdjustable: false),
        ]
        return try Level(id: "phase-step-hand", seed: 0, difficulty: 1, ringRadii: [3, 6, 9], starSpeed: 1,
                         luminosityLevels: [8, 24], stars: stars, maxTilt: anything ? 2 : 0, startTilt: 0,
                         minimumSeparation: separation, clampRadius: 2, worlds: [world], lethalTolerance: 2,
                         budget: 10, tutorial: false, phaseStep: phaseStep)
    }

    /// The reason payload of a level refusal, "none" when accepted, or "other".
    static func refusal(_ build: () throws(BinaryGardensError) -> Level) -> String {
        do {
            _ = try build()
            return "none"
        } catch {
            if case .level(let name) = error { return name }
            return "other"
        }
    }

    /// The phase moves of the puzzle's initial position, as (star, step).
    static func phaseMoves(_ level: Level) -> [[Int]] {
        let rules: BinaryGardensPuzzle = BinaryGardensPuzzle(level: level)
        var result: [[Int]] = []
        for move in rules.moves(in: rules.initialState) {
            if case .phase(let star, let step) = move { result.append([star, step]) }
        }
        return result
    }

    @Test func aLevelWithoutAPhaseStepKeepsItsFeature501BytesAndFingerprint() throws {
        let level: Level = try Self.hand()
        #expect(level.phaseStep == 1)
        #expect(level.fingerprint == Self.pinnedFingerprint)
        #expect(String(decoding: level.encoded(), as: UTF8.self) == Self.pinnedStoredForm)
        #expect(BinaryGardensPlay(level: level).fingerprint == Self.pinnedPlayFingerprint)
        let decoded: Level = try Level.decode(level.encoded())
        #expect(decoded == level)
        #expect(decoded.phaseStep == 1)
        // An explicit phase step of 1 is the same level.
        #expect(try Self.hand(phaseStep: 1) == level)
        // Every phase 0 … 47 is a move of a phase-adjustable star.
        let moves: [[Int]] = Self.phaseMoves(level)
        #expect(moves.count == 47 + 47)
    }

    @Test func aLevelWithAPhaseStepRoundTripsWithItsFingerprint() throws {
        let level: Level = try Self.hand(phaseStep: 8, phases: [16, 24])
        #expect(level.phaseStep == 8)
        let text: String = String(decoding: level.encoded(), as: UTF8.self)
        #expect(text.contains("\"phaseStep\":8"))
        #expect(level.fingerprint != Self.pinnedFingerprint)
        let decoded: Level = try Level.decode(level.encoded())
        #expect(decoded == level)
        #expect(decoded.phaseStep == 8)
        #expect(decoded.fingerprint == level.fingerprint)
        let coded: Level = try JSONDecoder().decode(Level.self, from: JSONEncoder().encode(level))
        #expect(coded == level)
        // The fingerprint is the SHA-256 of the stored form without the fingerprint.
        let without: Level = try Self.hand(phaseStep: 8, phases: [16, 24])
        #expect(without.fingerprint == level.fingerprint)
        // Every listed step round-trips; the fingerprints differ from step to step.
        var fingerprints: Set<String> = []
        for step in Level.phaseSteps {
            let stepped: Level = try Self.hand(phaseStep: step, phases: [0, 0])
            #expect(try Level.decode(stepped.encoded()) == stepped, "step \(step)")
            #expect(String(decoding: stepped.encoded(), as: UTF8.self).contains("\"phaseStep\"") == (step > 1))
            fingerprints.insert(stepped.fingerprint)
        }
        #expect(fingerprints.count == Level.phaseSteps.count)
        #expect(Level.phaseSteps == [1, 2, 3, 4, 6, 8, 12, 16, 24])
    }

    @Test func phaseStepAndPhaseOffGridAreRefusedInOrder() {
        for step in [0, 5, 7, 9, 10, 32, 48, -8] {
            #expect(Self.refusal { () throws(BinaryGardensError) in try Self.hand(phaseStep: step) } == "phase step",
                    "step \(step)")
        }
        #expect(Self.refusal { () throws(BinaryGardensError) in try Self.hand(phaseStep: 8, phases: [4, 24]) }
                    == "phase off grid")
        #expect(Self.refusal { () throws(BinaryGardensError) in try Self.hand(phaseStep: 8, phases: [0, 20]) }
                    == "phase off grid")
        // "phase step" before "phase off grid".
        #expect(Self.refusal { () throws(BinaryGardensError) in try Self.hand(phaseStep: 5, phases: [4, 24]) }
                    == "phase step")
        // "nothing adjustable" before both.
        #expect(Self.refusal { () throws(BinaryGardensError) in
            try Self.hand(phaseStep: 5, phases: [4, 20], anything: false)
        } == "nothing adjustable")
        // Both before "separation": stars on rings 3 and 9 are at most 12 units apart, so σ 13 breaks.
        #expect(Self.refusal { () throws(BinaryGardensError) in try Self.hand(separation: 13) } == "separation")
        #expect(Self.refusal { () throws(BinaryGardensError) in
            try Self.hand(phaseStep: 8, phases: [4, 24], separation: 13)
        } == "phase off grid")
        #expect(Self.refusal { () throws(BinaryGardensError) in
            try Self.hand(phaseStep: 7, phases: [0, 24], separation: 13)
        } == "phase step")
        // Both before "already won": a world whose every band is wide wins at once.
        let easy = BinaryGardensWorld(radius: 20, phase: 0, speed: 1, lethalLow: 0, comfortLow: 1,
                                      comfortHigh: 199_999, lethalHigh: 200_000, window: 1, bloomLow: 0,
                                      bloomHigh: BinaryGardensLevel.maximumBloom)
        #expect(Self.refusal { () throws(BinaryGardensError) in try Self.hand(world: easy) } == "already won")
        #expect(Self.refusal { () throws(BinaryGardensError) in
            try Self.hand(phaseStep: 8, phases: [4, 24], world: easy)
        } == "phase off grid")
        #expect(Self.refusal { () throws(BinaryGardensError) in try Self.hand(phaseStep: 6, phases: [0, 24]) }
                    == "none")
    }

    @Test func theProbeChecksThePhaseStepToo() throws {
        let stars: [BinaryGardensStar] = [
            BinaryGardensStar(ring: 0, phase: 12, luminosity: 0, ringAdjustable: true, phaseAdjustable: true,
                              luminosityAdjustable: false),
            BinaryGardensStar(ring: 1, phase: 30, luminosity: 0, ringAdjustable: false, phaseAdjustable: true,
                              luminosityAdjustable: false),
        ]
        let probe: Level = try Level.probe(ringRadii: [3, 9], starSpeed: 2, luminosityLevels: [10], stars: stars,
                                           maxTilt: 0, startTilt: 0, minimumSeparation: 0, clampRadius: 2,
                                           worlds: [Self.world], lethalTolerance: 0, phaseStep: 6)
        #expect(probe.phaseStep == 6)
        #expect(Self.refusal { () throws(BinaryGardensError) in
            try Level.probe(ringRadii: [3, 9], starSpeed: 2, luminosityLevels: [10], stars: stars, maxTilt: 0,
                            startTilt: 0, minimumSeparation: 0, clampRadius: 2, worlds: [Self.world],
                            lethalTolerance: 0, phaseStep: 8)
        } == "phase off grid")
    }

    @Test func thePlayRefusesAPhaseOffTheGrid() throws {
        let level: Level = try Self.hand(phaseStep: 8, phases: [16, 24])
        var play: BinaryGardensPlay = BinaryGardensPlay(level: level)
        try play.handle(.begin)
        let before: String = play.fingerprint
        #expect(throws: BinaryGardensError.action("off the phase grid")) {
            try play.apply(.phase(star: 0, step: 20), expecting: before)
        }
        #expect(play.fingerprint == before)
        #expect(play.actionsSpent == 0)
        #expect(play.records.count == 1)
        // "phase out of range" before "off the phase grid"; "off the phase grid" before "locked" and "unchanged".
        #expect(throws: BinaryGardensError.action("phase out of range")) {
            try play.apply(.phase(star: 0, step: 50), expecting: before)
        }
        // A grid phase is accepted.
        try play.apply(.phase(star: 0, step: 40), expecting: before)
        #expect(play.arrangement.phases == [40, 24])
        #expect(play.actionsSpent == 1)
        // The kernel's check names the grid for a locked control too (grid before locked).
        let frozen: Level = try Self.hand(phaseStep: 8, phases: [16, 24])
        let lockedStar: Level = try Level(id: "phase-step-locked", seed: 0, difficulty: 1, ringRadii: [3, 6, 9],
                                          starSpeed: 1, luminosityLevels: [8, 24],
                                          stars: [frozen.stars[0],
                                                  BinaryGardensStar(ring: 2, phase: 24, luminosity: 1,
                                                                    ringAdjustable: false, phaseAdjustable: false,
                                                                    luminosityAdjustable: false)],
                                          maxTilt: 2, startTilt: 0, minimumSeparation: 0, clampRadius: 2,
                                          worlds: [Self.world], lethalTolerance: 2, budget: 10, tutorial: false,
                                          phaseStep: 8)
        #expect(throws: BinaryGardensError.action("off the phase grid")) {
            try BinaryGardensSky.changed(lockedStar, lockedStar.start, by: .phase(star: 1, step: 3))
        }
        #expect(throws: BinaryGardensError.action("locked")) {
            try BinaryGardensSky.changed(lockedStar, lockedStar.start, by: .phase(star: 1, step: 8))
        }
    }

    @Test func thePuzzleListsGridPhasesOnlyAndRefusesTheRest() throws {
        let level: Level = try Self.hand(phaseStep: 8, phases: [16, 24])
        let moves: [[Int]] = Self.phaseMoves(level)
        #expect(moves == [[0, 0], [0, 8], [0, 24], [0, 32], [0, 40], [1, 0], [1, 8], [1, 16], [1, 32], [1, 40]])
        let rules: BinaryGardensPuzzle = BinaryGardensPuzzle(level: level)
        #expect(rules.apply(.phase(star: 0, step: 4), to: rules.initialState) == nil)
        #expect(rules.apply(.phase(star: 0, step: 8), to: rules.initialState) != nil)
        let six: Level = try Self.hand(phaseStep: 6, phases: [0, 24])
        var steps: [Int] = []
        for move in Self.phaseMoves(six) where move[0] == 0 { steps.append(move[1]) }
        #expect(steps == [6, 12, 18, 24, 30, 36, 42])
        // Every move of the puzzle is accepted by the play, and the play accepts no other phase.
        for move in rules.moves(in: rules.initialState) {
            var play: BinaryGardensPlay = BinaryGardensPlay(level: level)
            try play.handle(.begin)
            try play.apply(move, expecting: play.fingerprint)
        }
        for step in 0..<48 where step % 8 != 0 {
            #expect(throws: BinaryGardensError.action("off the phase grid")) {
                try BinaryGardensSky.changed(level, level.start, by: .phase(star: 0, step: step))
            }
        }
    }

    @Test func allowsPhaseAndWellFormedFollowTheGrid() throws {
        let level: Level = try Self.hand(phaseStep: 12, phases: [0, 24])
        var allowed: [Int] = []
        for step in -1...48 where level.allowsPhase(step) { allowed.append(step) }
        #expect(allowed == [0, 12, 24, 36])
        let plain: Level = try Self.hand()
        var all: Int = 0
        for step in -1...48 where plain.allowsPhase(step) { all += 1 }
        #expect(all == 48)
        let on = BinaryGardensArrangement(rings: [0, 2], phases: [12, 36], luminosities: [0, 1], tilt: 0)
        let off = BinaryGardensArrangement(rings: [0, 2], phases: [13, 36], luminosities: [0, 1], tilt: 0)
        #expect(BinaryGardensSky.isWellFormed(level, on))
        #expect(!BinaryGardensSky.isWellFormed(level, off))
        #expect(BinaryGardensSky.isWellFormed(plain, off))
        #expect(!BinaryGardensSky.keepsSeparation(level, arrangement: off))
        let rules: BinaryGardensPuzzle = BinaryGardensPuzzle(level: level)
        #expect(rules.moves(in: BinaryGardensPuzzle.Position(arrangement: off, actionsSpent: 0)).isEmpty)
        #expect(!rules.isSolved(BinaryGardensPuzzle.Position(arrangement: off, actionsSpent: 0)))
    }

    @Test func theNewRefusalsCarryTheirReasonCodes() {
        #expect(BinaryGardensError.generation(7).reasonCode == "r02-g21.generation")
        #expect(BinaryGardensError.witness("digests").reasonCode == "r02-g21.witness")
        #expect(BinaryGardensError.generation(7) != BinaryGardensError.generation(8))
        #expect(BinaryGardensError.witness("a") != BinaryGardensError.witness("b"))
    }
}
