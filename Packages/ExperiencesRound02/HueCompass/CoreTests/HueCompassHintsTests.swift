// HueCompassHintsTests — feature 335 (R02-G04-05) T-R02G0405-002 (FR-R02G0405-002, 003; SC-R02G0405-002, 003;
// clarifications Q1, Q5; research R1, R2). Following exact (level-3) hints from the start — the shortest turn to a probe
// hint's bearing and the probe, or the hinted selection — wins all 100 certified levels within the allowance (one test
// per band); on 2,000 seeded reachable states (random legal turns and probes from the certified starts, never ending the
// play) the consistent set contains the true target and equals an independent brute force, every exact hint is legal
// (a probe only with two or more units left, a selection in range), levels 1 … 3 agree on the action and hints never
// change the play; no hint outside `playing`; octant names and every hint text; 500 seeded failures (wrong selections
// and probe exhaustion) explained with the exact distances and texts. The certified levels are read from the witness
// files in docs/games/hue-compass/levels/, which HueCompassCatalogTests proves equal to the regenerated catalog. Seed
// 2_335 (`SeededRandom`). Explicit types and plain loops (CI type-check rule); no clock.
@testable import HueCompassCore
import Foundation
import Testing
import VisualCoreSimulation

/// The repository's witness directory, found from this file.
private let hintsWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/hue-compass/levels", isDirectory: true)

/// The 100 certified witnesses, decoded once per test process, in manifest order.
private let hintsWitnesses: Result<[HueCompassWitness], any Error> = Result {
    var result: [HueCompassWitness] = []
    for entry in HueCompassManifest.entries {
        let name: String = String(HueCompassGenerator.levelID(entry.number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: hintsWitnessDirectory.appendingPathComponent(name))
        result.append(try HueCompassWitness.decode(data))
    }
    return result
}

@Suite("Hue Compass hints and failure explanations")
struct HueCompassHintsTests {
    /// The suite's seed.
    static let seed: UInt64 = 2_335

    /// A new play of `level` in stage `playing`.
    static func started(_ level: HueCompassLevel) throws -> HueCompassPlay {
        var play: HueCompassPlay = HueCompassPlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The certified witnesses of levels `numbers`.
    static func witnesses(_ numbers: ClosedRange<Int>) throws -> [HueCompassWitness] {
        let all: [HueCompassWitness] = try hintsWitnesses.get()
        #expect(all.count == 100)
        var result: [HueCompassWitness] = []
        for witness in all where numbers.contains(witness.number) { result.append(witness) }
        return result
    }

    /// The signed shortest turn from `from` to `to`, −47 … 48.
    static func shortestTurn(from: Int, to: Int) -> Int {
        let d: Int = ((to - from) % 96 + 96) % 96
        return d <= 48 ? d : d - 96
    }

    /// Applies the action of `hint` to `play`: the shortest turn to a probe hint's bearing (none when already there)
    /// and the probe, or the hinted selection.
    static func follow(_ hint: HueCompassHint, play: inout HueCompassPlay) throws {
        switch hint.kind {
        case .probe:
            let turn: Int = shortestTurn(from: play.bearing, to: hint.bearing)
            if turn != 0 { try play.apply(.turn(turn), expecting: play.fingerprint) }
            try play.apply(.probe, expecting: play.fingerprint)
        case .select, .guess:
            let band: Int = try #require(hint.band)
            try play.apply(.select(bearing: hint.bearing, band: band), expecting: play.fingerprint)
        }
    }

    /// The consistent set by brute force: every bearing farther from the start than the bearing tolerance whose clue
    /// table (computed directly from the wheel, independent of `HueCompassHints`) matches every clue seen.
    static func bruteConsistent(_ play: HueCompassPlay) -> [Int] {
        let level: HueCompassLevel = play.level
        var result: [Int] = []
        for t in 0..<96 where HueCompassWheel.bearingDistance(t, level.start) > level.bearingTolerance {
            var ok: Bool = true
            for clue in play.clues {
                var depth: Int = 0
                let d: Int = ((t - clue.bearing) % 96 + 96) % 96
                if d > 1 && d < 95 {
                    if d <= 48 {
                        for k in 1..<d { depth += level.fog[(clue.bearing + k) % 96] }
                    } else {
                        for k in 1..<(96 - d) { depth += level.fog[((clue.bearing - k) % 96 + 96) % 96] }
                    }
                }
                let a: Int = (clue.bearing / 4 + level.offset) % 24
                let b: Int = (t / 4 + level.offset) % 24
                let gapRaw: Int = ((a - b) % 24 + 24) % 24
                let gap: Int = min(gapRaw, 24 - gapRaw)
                if gap != clue.hueGap || depth != clue.depth { ok = false }
            }
            if ok { result.append(t) }
        }
        return result
    }

    /// The expected failure text, computed independently of the explanation.
    static func expectedText(_ play: HueCompassPlay) -> String {
        let level: HueCompassLevel = play.level
        if play.failure == .probes {
            return "The last unit went to a probe; keep one for the selection. Retry the level."
        }
        let selection: HueCompassSelection = play.selection ?? HueCompassSelection(bearing: -1, band: -1)
        let bRaw: Int = ((selection.bearing - level.target) % 96 + 96) % 96
        let nRaw: Int = ((selection.band - level.targetBand) % 24 + 24) % 24
        return "The target was bearing " + String(level.target) + " (band " + String(level.targetBand)
            + "). Your selection was " + String(min(bRaw, 96 - bRaw)) + " bearings and " + String(min(nRaw, 24 - nRaw))
            + " bands away; the tolerances are " + String(level.bearingTolerance) + " and "
            + String(level.bandTolerance) + ". Retry the level."
    }

    // MARK: Following exact hints wins

    @Test("Following exact hints from the start wins every certified level within the allowance (5 × 20 levels)",
          arguments: [1, 2, 3, 4, 5])
    func exactHintsWin(band: Int) throws {
        let witnesses: [HueCompassWitness] = try Self.witnesses((band * 20 - 19)...(band * 20))
        #expect(witnesses.count == 20)
        var totalSteps: Int = 0
        var maximumSteps: Int = 0
        var probesAboveSmallest: Int = 0
        for witness in witnesses {
            let level: HueCompassLevel = witness.level
            var play: HueCompassPlay = try Self.started(level)
            #expect(HueCompassHints.consistent(play) == HueCompassSolver.candidates(level))
            var steps: Int = 0
            var probes: Int = 0
            while play.stage == .playing && steps < 30 {
                let hint: HueCompassHint = try #require(HueCompassHints.hint(level: 3, play: play))
                if hint.kind == .probe {
                    #expect(play.remaining >= 2, "level \(witness.number)")
                    probes += 1
                }
                try Self.follow(hint, play: &play)
                steps += 1
            }
            #expect(play.stage == .won, "level \(witness.number)")
            #expect(play.spent <= level.allowance, "level \(witness.number)")
            #expect(HueCompassHints.hint(level: 1, play: play) == nil)
            if probes > witness.difficulty.smallest { probesAboveSmallest += 1 }
            totalSteps += steps
            maximumSteps = max(maximumSteps, steps)
        }
        print("HueCompassHints band \(band): \(totalSteps) hint steps over 20 levels, at most \(maximumSteps) per level,"
              + " \(probesAboveSmallest) levels probed more than the certified smallest")
    }

    // MARK: Hints on reachable states

    /// The 2,000 reachable states run as twenty chunks of 100 (5 levels × 20 states; seed 2,335 + chunk). A state is
    /// 0 … 6 random actions from the level's start: a turn of a random non-zero step, or a probe when at least two units
    /// are left (so the play never ends).
    @Test("2,000 seeded reachable states (20 × 100): exact hints are legal and the consistent set holds the target",
          arguments: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19])
    func hintsOnReachableStates(chunk: Int) throws {
        let witnesses: [HueCompassWitness] = try Self.witnesses((chunk * 5 + 1)...(chunk * 5 + 5))
        #expect(witnesses.count == 5)
        var random: SeededRandom = SeededRandom(seed: Self.seed + UInt64(chunk))
        var states: Int = 0
        var kinds: [HueCompassHintKind: Int] = [:]
        for witness in witnesses {
            let level: HueCompassLevel = witness.level
            for _ in 0..<20 {
                var play: HueCompassPlay = try Self.started(level)
                let length: Int = random.int(0...6)
                for _ in 0..<length {
                    if random.int(0...1) == 0 && play.remaining >= 2 {
                        try play.apply(.probe, expecting: play.fingerprint)
                    } else {
                        var step: Int = random.int(-48...47)
                        if step >= 0 { step += 1 }
                        try play.apply(.turn(step), expecting: play.fingerprint)
                    }
                }
                #expect(play.stage == .playing, "level \(witness.number)")
                states += 1
                let before: String = play.fingerprint
                let members: [Int] = HueCompassHints.consistent(play)
                #expect(members.contains(level.target), "level \(witness.number)")
                #expect(members == Self.bruteConsistent(play), "level \(witness.number)")
                let hint1: HueCompassHint = try #require(HueCompassHints.hint(level: 1, play: play))
                let hint2: HueCompassHint = try #require(HueCompassHints.hint(level: 2, play: play))
                let hint: HueCompassHint = try #require(HueCompassHints.hint(level: 3, play: play))
                #expect(play.fingerprint == before)
                #expect(hint1.level == 1 && hint2.level == 2 && hint.level == 3)
                #expect(hint1.kind == hint.kind && hint2.kind == hint.kind, "level \(witness.number)")
                #expect(hint1.bearing == hint.bearing && hint2.bearing == hint.bearing, "level \(witness.number)")
                #expect(hint1.band == hint.band && hint2.band == hint.band, "level \(witness.number)")
                #expect(hint.consistent == members.count && hint1.consistent == members.count)
                #expect((0..<96).contains(hint.bearing))
                kinds[hint.kind, default: 0] += 1
                switch hint.kind {
                case .probe:
                    #expect(hint.band == nil)
                    #expect(play.remaining >= 2, "level \(witness.number)")
                    #expect(HueCompassSolver.selection(for: members, in: level) == nil)
                case .select:
                    let band: Int = try #require(hint.band)
                    #expect((0..<24).contains(band))
                    #expect(play.remaining >= 1)
                    // A settled selection accepts every consistent target, the true one included.
                    for t in members {
                        #expect(HueCompassWheel.bearingDistance(hint.bearing, t) <= level.bearingTolerance)
                        #expect(HueCompassWheel.bandDistance(band, level.band(of: t)) <= level.bandTolerance)
                    }
                    #expect(level.accepts(bearing: hint.bearing, band: band), "level \(witness.number)")
                case .guess:
                    let band: Int = try #require(hint.band)
                    #expect((0..<24).contains(band))
                    #expect(play.remaining == 1, "level \(witness.number)")
                }
                // Following the exact hint is a legal action.
                var next: HueCompassPlay = play
                try Self.follow(hint, play: &next)
                if hint.kind == .probe { #expect(next.stage == .playing, "level \(witness.number)") }
                if hint.kind == .select { #expect(next.stage == .won, "level \(witness.number)") }
            }
        }
        #expect(states == 100)
        #expect((kinds[.probe] ?? 0) > 0)
    }

    // MARK: Best guess on the last unit

    @Test("With one unit left the hint is the best guess: most members accepted, lowest bearing then band")
    func bestGuessOnLastUnit() throws {
        let witnesses: [HueCompassWitness] = try Self.witnesses(1...100)
        var guesses: Int = 0
        for number in [1, 21, 41, 61, 81, 100] {
            let level: HueCompassLevel = witnesses[number - 1].level
            var play: HueCompassPlay = try Self.started(level)
            while play.remaining > 1 { try play.apply(.probe, expecting: play.fingerprint) }
            #expect(play.stage == .playing)
            let members: [Int] = HueCompassHints.consistent(play)
            let hint: HueCompassHint = try #require(HueCompassHints.hint(level: 3, play: play))
            if HueCompassSolver.selection(for: members, in: level) != nil {
                #expect(hint.kind == .select)
                continue
            }
            guesses += 1
            #expect(hint.kind == .guess)
            // Brute force: count members accepted by every bearing and band; keep the first maximum.
            var bestCount: Int = -1
            var bestBearing: Int = -1
            var bestBand: Int = -1
            for b in 0..<96 {
                for n in 0..<24 {
                    var count: Int = 0
                    for t in members where HueCompassWheel.bearingDistance(b, t) <= level.bearingTolerance
                        && HueCompassWheel.bandDistance(n, level.band(of: t)) <= level.bandTolerance {
                        count += 1
                    }
                    if count > bestCount {
                        bestCount = count
                        bestBearing = b
                        bestBand = n
                    }
                }
            }
            #expect(hint.bearing == bestBearing && hint.band == bestBand, "level \(number)")
        }
        #expect(guesses >= 1)
    }

    // MARK: No hint outside playing

    @Test("No hint while loading, in the tutorial, paused, won or after the result")
    func noHintOutsidePlaying() throws {
        let witnesses: [HueCompassWitness] = try Self.witnesses(1...100)
        for number in [1, 2, 3, 21, 50, 99] {
            let witness: HueCompassWitness = witnesses[number - 1]
            let level: HueCompassLevel = witness.level
            var play: HueCompassPlay = HueCompassPlay(level: level)
            #expect(HueCompassHints.hint(level: 1, play: play) == nil)
            try play.handle(.begin)
            if level.tutorial {
                #expect(play.stage == .tutorial)
                #expect(HueCompassHints.hint(level: 1, play: play) == nil)
                try play.handle(.dismissTutorial)
            }
            #expect(HueCompassHints.hint(level: 3, play: play) != nil)
            #expect(HueCompassHints.hint(level: 0, play: play)?.level == 1)
            #expect(HueCompassHints.hint(level: 9, play: play)?.level == 3)
            try play.handle(.pause)
            #expect(HueCompassHints.hint(level: 3, play: play) == nil)
            try play.handle(.resume)
            for action in witness.actions where play.stage == .playing {
                try play.apply(action, expecting: play.fingerprint)
            }
            #expect(play.stage == .won)
            #expect(HueCompassHints.hint(level: 3, play: play) == nil)
            #expect(HueCompassFailureExplanation(play: play) == nil)
            try play.handle(.showResult)
            #expect(HueCompassHints.hint(level: 3, play: play) == nil)
            #expect(HueCompassFailureExplanation(play: play) == nil)
        }
    }

    // MARK: Texts

    @Test("Octants: north is bearing 24, each octant is 12k − 6 … 12k + 5")
    func octants() {
        let names: [String] = ["east", "north-east", "north", "north-west", "west", "south-west", "south",
                               "south-east"]
        for b in 0..<96 {
            var expected: Int = 0
            for k in 0..<8 {
                let low: Int = ((12 * k - 6) % 96 + 96) % 96
                let offset: Int = ((b - low) % 96 + 96) % 96
                if offset < 12 { expected = k }
            }
            #expect(HueCompassHint.octant(of: b) == expected, "bearing \(b)")
            #expect(HueCompassHint.octantName(of: b) == names[expected])
        }
        #expect(HueCompassHint.octantName(of: 24) == "north")
        #expect(HueCompassHint.octantName(of: 0) == "east")
        #expect(HueCompassHint.octantName(of: 90) == "east")
        #expect(HueCompassHint.octantName(of: 89) == "south-east")
        #expect(HueCompassHint.octantName(of: 5) == "east")
        #expect(HueCompassHint.octantName(of: 6) == "north-east")
        #expect(HueCompassHint.octantName(of: 48) == "west")
        #expect(HueCompassHint.octantName(of: 72) == "south")
        #expect(HueCompassHint.octantName(of: -24) == "south")
    }

    @Test("Hint texts at each level for probes, selections and best guesses")
    func hintTexts() {
        let texts: [String] = [
            HueCompassHint(level: 1, kind: .select, bearing: 24, band: 7, consistent: 2).text,
            HueCompassHint(level: 2, kind: .select, bearing: 24, band: 7, consistent: 2).text,
            HueCompassHint(level: 3, kind: .select, bearing: 24, band: 7, consistent: 2).text,
            HueCompassHint(level: 1, kind: .probe, bearing: 50, band: nil, consistent: 9).text,
            HueCompassHint(level: 2, kind: .probe, bearing: 50, band: nil, consistent: 9).text,
            HueCompassHint(level: 3, kind: .probe, bearing: 50, band: nil, consistent: 9).text,
            HueCompassHint(level: 1, kind: .guess, bearing: 13, band: 0, consistent: 4).text,
            HueCompassHint(level: 2, kind: .guess, bearing: 13, band: 0, consistent: 4).text,
            HueCompassHint(level: 3, kind: .guess, bearing: 13, band: 0, consistent: 4).text,
        ]
        let expected: [String] = [
            "Every clue now points to one place: select", "Select near north", "Select bearing 24 with band 7",
            "Probe once more", "Probe toward west", "Turn to bearing 50 and probe",
            "Best guess: select", "Best guess: select near north-east", "Best guess: select bearing 13 with band 0",
        ]
        for index in 0..<texts.count { #expect(texts[index] == expected[index]) }
    }

    // MARK: Failures

    /// The 500 failures run as five chunks of 100 (20 levels × 5 each; seed 2,335 + 100 + chunk): each failure first
    /// takes 0 … 3 random turns and probes (keeping two units), then either selects a random bearing and band the level
    /// refuses, or probes until the allowance is exhausted.
    @Test("500 seeded failures (5 × 100) are explained with the exact distances and texts", arguments: [0, 1, 2, 3, 4])
    func failuresExplained(chunk: Int) throws {
        let witnesses: [HueCompassWitness] = try Self.witnesses((chunk * 20 + 1)...(chunk * 20 + 20))
        #expect(witnesses.count == 20)
        var random: SeededRandom = SeededRandom(seed: Self.seed + 100 + UInt64(chunk))
        var explained: Int = 0
        var selections: Int = 0
        for witness in witnesses {
            let level: HueCompassLevel = witness.level
            for _ in 0..<5 {
                var play: HueCompassPlay = try Self.started(level)
                let length: Int = random.int(0...3)
                for _ in 0..<length {
                    if random.int(0...1) == 0 && play.remaining > 2 {
                        try play.apply(.probe, expecting: play.fingerprint)
                    } else {
                        try play.apply(.turn(random.int(1...48)), expecting: play.fingerprint)
                    }
                }
                #expect(HueCompassFailureExplanation(play: play) == nil)
                if random.int(0...1) == 0 {
                    var bearing: Int = random.int(0...95)
                    var band: Int = random.int(0...23)
                    while level.accepts(bearing: bearing, band: band) {
                        bearing = random.int(0...95)
                        band = random.int(0...23)
                    }
                    try play.apply(.select(bearing: bearing, band: band), expecting: play.fingerprint)
                    selections += 1
                } else {
                    while play.stage == .playing { try play.apply(.probe, expecting: play.fingerprint) }
                }
                #expect(play.stage == .failed, "level \(witness.number)")
                #expect(HueCompassHints.hint(level: 3, play: play) == nil)
                let explanation: HueCompassFailureExplanation = try #require(HueCompassFailureExplanation(play: play))
                #expect(explanation.failure == play.failure)
                #expect(explanation.target == level.target && explanation.targetBand == level.targetBand)
                #expect(explanation.bearingTolerance == level.bearingTolerance)
                #expect(explanation.bandTolerance == level.bandTolerance)
                if play.failure == .selection {
                    let selection: HueCompassSelection = try #require(play.selection)
                    let bearingDistance: Int = HueCompassWheel.bearingDistance(selection.bearing, level.target)
                    let bandDistance: Int = HueCompassWheel.bandDistance(selection.band, level.targetBand)
                    #expect(explanation.bearingDistance == bearingDistance)
                    #expect(explanation.bandDistance == bandDistance)
                    #expect(bearingDistance > level.bearingTolerance || bandDistance > level.bandTolerance)
                } else {
                    #expect(play.failure == .probes)
                    #expect(play.spent == level.allowance)
                    #expect(explanation.bearingDistance == nil && explanation.bandDistance == nil)
                }
                #expect(explanation.text == Self.expectedText(play), "level \(witness.number)")
                try play.handle(.showResult)
                #expect(HueCompassFailureExplanation(play: play) == explanation)
                #expect(HueCompassHints.hint(level: 3, play: play) == nil)
                explained += 1
            }
        }
        #expect(explained == 100)
        #expect(selections > 0 && selections < 100)
    }

    @Test("Failure texts for a miss and an exhausted allowance")
    func failureTextFormat() throws {
        let witness: HueCompassWitness = try Self.witnesses(1...1)[0]
        let level: HueCompassLevel = witness.level
        var miss: HueCompassPlay = try Self.started(level)
        let selection: HueCompassSelection = witness.nearMiss
        try miss.apply(.select(bearing: selection.bearing, band: selection.band), expecting: miss.fingerprint)
        let explanation: HueCompassFailureExplanation = try #require(HueCompassFailureExplanation(play: miss))
        #expect(explanation.bearingDistance == level.bearingTolerance + 1 && explanation.bandDistance == 0)
        #expect(explanation.text == "The target was bearing \(level.target) (band \(level.targetBand)). Your selection "
            + "was \(level.bearingTolerance + 1) bearings and 0 bands away; the tolerances are "
            + "\(level.bearingTolerance) and \(level.bandTolerance). Retry the level.")
        var spent: HueCompassPlay = try Self.started(level)
        while spent.stage == .playing { try spent.apply(.probe, expecting: spent.fingerprint) }
        #expect(HueCompassFailureExplanation(play: spent)?.text
            == "The last unit went to a probe; keep one for the selection. Retry the level.")
    }
}
