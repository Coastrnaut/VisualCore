// ColorfallCanyonsHintsTests — feature 345 (R02-G05-05) T-R02G0505-002 (FR-R02G0505-002, 003; SC-R02G0505-002, 003;
// clarifications Q1, Q5; research R1 … R3, R6). Hints and failure explanations on the 100 certified levels (read from
// the stored witness files, which ColorfallCanyonsCatalogTests proves equal to the generator's levels): following exact
// hints from every level's start wins; 200 seeded reachable states (seed 2_345: random legal carves, valves and steps
// from certified starts, a failing step undone) get a legal exact hint, and from every state with a plan following hints
// wins, while a state without one gets `stuck`; the three hint levels agree on the action and read as clarification Q1
// says; won, loading and tutorial plays get no hint and failed ones `stuck`; 500 seeded failures (seed 3_345) are
// explained with the reason, basin, colour, amounts and tick recomputed independently here; the plan from a level's
// start equals the solver's certified solution. Every group measures and prints its slowest hint. Groups are sized so
// each test stays well under 10 s on the host. Explicit types, plain loops (CI type-check rule).
@testable import ColorfallCanyonsCore
import Foundation
import Testing
import VisualCoreSimulation

/// The stored part of a witness file this suite reads: its number, level and certified actions.
private struct HintStoredLevel: Decodable {
    let number: Int
    let level: ColorfallCanyonsLevel
    let actions: [ColorfallCanyonsAction]
}

/// The repository's witness directory, found from this file.
private let hintWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/colorfall-canyons/levels", isDirectory: true)

/// The 100 certified levels and their witness actions in manifest order, decoded once per test process.
private let hintStoredResult: Result<[HintStoredLevel], any Error> = Result {
    var levels: [HintStoredLevel] = []
    for number in 1...100 {
        let name: String = String(ColorfallCanyonsGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: hintWitnessDirectory.appendingPathComponent(name))
        let stored: HintStoredLevel = try JSONDecoder().decode(HintStoredLevel.self, from: data)
        guard stored.number == number else { throw ColorfallCanyonsError.generation(number) }
        levels.append(stored)
    }
    return levels
}

/// The certified levels.
private func hintLevels() throws -> [ColorfallCanyonsLevel] { try hintStoredResult.get().map(\.level) }

/// The play of certified level `number` after the first `count` of its witness actions (all of them when nil).
private func witnessPlay(_ number: Int, actions count: Int? = nil) throws -> ColorfallCanyonsPlay {
    let stored: HintStoredLevel = try hintStoredResult.get()[number - 1]
    var play: ColorfallCanyonsPlay = try ColorfallCanyonsExperienceCore.freshPlay(of: stored.level)
    for index in 0..<(count ?? stored.actions.count) {
        try play.apply(stored.actions[index], expecting: play.fingerprint)
    }
    return play
}

/// The plays the agreement test checks besides seeded states: every certified level 1 … 10 with all its witness edits
/// applied (a `run` hint), and level 98 with its two witness carves applied (its certified set ends with a valve).
private func edgePlays() throws -> [ColorfallCanyonsPlay] {
    var plays: [ColorfallCanyonsPlay] = []
    let stored: [HintStoredLevel] = try hintStoredResult.get()
    for number in 1...10 { plays.append(try witnessPlay(number, actions: stored[number - 1].actions.count - 1)) }
    plays.append(try witnessPlay(98, actions: 2))
    return plays
}

/// Seconds of a duration.
private func seconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) + Double(duration.components.attoseconds) * 1e-18
}

/// The hint of `level` for `play`, timed; the slowest time so far is kept in `slowest`.
private func timedHint(_ level: Int, _ play: ColorfallCanyonsPlay, slowest: inout Double) -> ColorfallCanyonsHint? {
    let start: ContinuousClock.Instant = ContinuousClock.now
    let hint: ColorfallCanyonsHint? = ColorfallCanyonsHints.hint(level: level, play: play)
    let elapsed: Double = seconds(ContinuousClock.now - start)
    if elapsed > slowest { slowest = elapsed }
    return hint
}

/// The kernel action an exact hint names (a run is one step of the ticks left, 1 … 600); nil for `stuck`.
private func hintAction(_ hint: ColorfallCanyonsHint) -> ColorfallCanyonsAction? {
    switch hint.kind {
    case .carve: return hint.cell.map { ColorfallCanyonsAction.carve($0) }
    case .valve: return hint.spring.map { ColorfallCanyonsAction.valve($0) }
    case .run: return .step(max(1, min(600, hint.ticks)))
    case .stuck: return nil
    }
}

/// Follows exact hints from `start` (resumed when paused) until the play ends; the problems found (empty: won, every
/// hinted action accepted).
private func followHints(_ start: ColorfallCanyonsPlay, label: String, slowest: inout Double) -> [String] {
    var play: ColorfallCanyonsPlay = start
    if play.stage == .paused { try? play.handle(.resume) }
    for _ in 0..<64 {
        if play.stage == .won { return [] }
        guard let hint = timedHint(3, play, slowest: &slowest) else { return ["\(label): no hint in \(play.stage)"] }
        guard let action = hintAction(hint) else { return ["\(label): stuck at tick \(play.fluid.tick)"] }
        do {
            try play.apply(action, expecting: play.fingerprint)
        } catch {
            return ["\(label): hinted \(action) refused: \(error)"]
        }
    }
    return play.stage == .won ? [] : ["\(label): not won, stage \(play.stage)"]
}

/// A seeded reachable state of the hint sample: the play and whether it ended won while being built.
private struct HintSample {
    let number: Int
    let play: ColorfallCanyonsPlay
}

/// The 200 seeded reachable states (seed 2_345) and the won plays met while building them. From a random certified
/// level's start, 0 … 5 random legal actions: a carve of a cell carvable now, a valve toggle (both only with actions
/// left) or a step of 1 … 40 ticks; a step that fails the play is undone, a play that is won is set aside; about one
/// state in ten is paused.
private let hintSamplesResult: Result<(states: [HintSample], won: [HintSample]), any Error> = Result {
    let levels: [ColorfallCanyonsLevel] = try hintLevels()
    var random: SeededRandom = SeededRandom(seed: 2_345)
    var states: [HintSample] = []
    var won: [HintSample] = []
    while states.count < 200 {
        let number: Int = random.int(1...100)
        let level: ColorfallCanyonsLevel = levels[number - 1]
        var play: ColorfallCanyonsPlay = try ColorfallCanyonsExperienceCore.freshPlay(of: level)
        let count: Int = random.int(0...5)
        var ended: Bool = false
        for _ in 0..<count {
            let choice: Int = random.int(0...2)
            var action: ColorfallCanyonsAction = .step(random.int(1...40))
            if choice == 0 && play.remaining > 0 {
                var cells: [Int] = []
                for cell in 0..<level.cellCount where level.isCarvable(cell, heights: play.fluid.heights) {
                    cells.append(cell)
                }
                if !cells.isEmpty { action = .carve(cells[random.int(0...(cells.count - 1))]) }
            } else if choice == 1 && play.remaining > 0 && !level.springs.isEmpty {
                action = .valve(random.int(0...(level.springs.count - 1)))
            }
            try play.apply(action, expecting: play.fingerprint)
            if play.stage == .failed { try play.undo() }
            if play.stage == .won {
                won.append(HintSample(number: number, play: play))
                ended = true
                break
            }
        }
        if ended { continue }
        if random.int(0...9) == 0 { try play.handle(.pause) }
        states.append(HintSample(number: number, play: play))
    }
    return (states, won)
}

/// The seeded reachable states.
private func hintSamples() throws -> [HintSample] { try hintSamplesResult.get().states }

/// One seeded failure of the explanation sample.
private struct FailureSample {
    let number: Int
    let play: ColorfallCanyonsPlay
}

/// The 500 seeded failures (seed 3_345): from a random certified level's start, 0 … min(3, budget) random edits (a carve
/// of a cell carvable now or a valve toggle), then steps of 600 ticks until the play ends; won plays are skipped.
private let failureSamplesResult: Result<[FailureSample], any Error> = Result {
    let levels: [ColorfallCanyonsLevel] = try hintLevels()
    var random: SeededRandom = SeededRandom(seed: 3_345)
    var samples: [FailureSample] = []
    while samples.count < 500 {
        let number: Int = random.int(1...100)
        let level: ColorfallCanyonsLevel = levels[number - 1]
        var play: ColorfallCanyonsPlay = try ColorfallCanyonsExperienceCore.freshPlay(of: level)
        let edits: Int = random.int(0...min(3, level.budget))
        for _ in 0..<edits {
            var cells: [Int] = []
            for cell in 0..<level.cellCount where level.isCarvable(cell, heights: play.fluid.heights) { cells.append(cell) }
            if cells.isEmpty && level.springs.isEmpty { break }
            let pick: Int = random.int(0...(cells.count + level.springs.count - 1))
            let action: ColorfallCanyonsAction = pick < cells.count ? .carve(cells[pick]) : .valve(pick - cells.count)
            try play.apply(action, expecting: play.fingerprint)
        }
        while play.stage == .playing { try play.apply(.step(600), expecting: play.fingerprint) }
        if play.stage == .failed { samples.append(FailureSample(number: number, play: play)) }
    }
    return samples
}

/// The expected explanation of a failed play, recomputed here from its fluid without the explanation's code: the
/// reason, basin (1-based), colour, amount, limit and text; nil when the fluid shows no cause.
private func expectedExplanation(_ play: ColorfallCanyonsPlay)
    -> (failure: ColorfallCanyonsFailure, basin: Int, color: ColorfallCanyonsColor?, amount: Int, limit: Int,
        text: String)? {
    let level: ColorfallCanyonsLevel = play.level
    let masses: [[Int]] = play.fluid.masses
    let names: [String] = ["cyan", "coral", "yellow"]
    let advice: String = " Undo the last change or retry the level."
    for index in 0..<level.basins.count {
        let basin: ColorfallCanyonsBasin = level.basins[index]
        if !basin.isProtected { continue }
        var wrong: Int = 0
        var present: [String] = []
        var top: Int = -1
        var topMass: Int = -1
        for c in 0..<3 where basin.shares[c] == 0 {
            wrong += masses[basin.cell][c]
            if masses[basin.cell][c] > 0 { present.append(names[c]) }
            if masses[basin.cell][c] > topMass {
                top = c
                topMass = masses[basin.cell][c]
            }
        }
        if wrong > basin.toleratedWrong {
            let row: Int = basin.cell / level.columns + 1
            let column: Int = basin.cell % level.columns + 1
            let text: String = "Basin \(index + 1) (row \(row), column \(column)) took \(wrong) units of "
                + present.joined(separator: " and ") + "; it allows at most \(basin.toleratedWrong)." + advice
            return (.contamination, index + 1, ColorfallCanyonsColor(rawValue: top), wrong, basin.toleratedWrong, text)
        }
    }
    for index in 0..<level.basins.count {
        let basin: ColorfallCanyonsBasin = level.basins[index]
        let volume: Int = masses[basin.cell][0] + masses[basin.cell][1] + masses[basin.cell][2]
        if volume > basin.capacity {
            let text: String = "Basin \(index + 1) overflowed: \(volume) units, its capacity is \(basin.capacity)."
                + advice
            return (.overflow, index + 1, nil, volume, basin.capacity, text)
        }
    }
    for index in 0..<level.basins.count {
        let basin: ColorfallCanyonsBasin = level.basins[index]
        let cell: [Int] = masses[basin.cell]
        let volume: Int = cell[0] + cell[1] + cell[2]
        var met: Bool = basin.fill == 0 || volume >= basin.fill
        if basin.fill > 0 && met {
            for c in 0..<3 where abs(1_000 * cell[c] - basin.shares[c] * volume) > basin.tolerance * volume { met = false }
        }
        if !met {
            let text: String = "Time ran out at tick \(play.fluid.tick): basin \(index + 1) holds cyan \(cell[0]), "
                + "coral \(cell[1]), yellow \(cell[2]); it needs \(basin.description)." + advice
            return (.time, index + 1, nil, volume, basin.fill, text)
        }
    }
    return nil
}

@Suite struct ColorfallCanyonsHintsTests {
    /// Follows exact hints from the start of certified levels `numbers`; returns the problems.
    private func followFromStarts(_ numbers: ClosedRange<Int>) throws -> [String] {
        let levels: [ColorfallCanyonsLevel] = try hintLevels()
        var problems: [String] = []
        var slowest: Double = 0
        for number in numbers {
            let play: ColorfallCanyonsPlay = try ColorfallCanyonsExperienceCore.freshPlay(of: levels[number - 1])
            problems += followHints(play, label: "level \(number)", slowest: &slowest)
        }
        print("Colorfall hints: levels \(numbers) slowest hint \(Int(slowest * 1_000)) ms")
        return problems
    }

    /// SC-R02G0505-002: exact hints from the start win levels 1 … 25.
    @Test func exactHintsWinLevels1To25() throws { #expect(try followFromStarts(1...25) == []) }

    /// SC-R02G0505-002: exact hints from the start win levels 26 … 50.
    @Test func exactHintsWinLevels26To50() throws { #expect(try followFromStarts(26...50) == []) }

    /// SC-R02G0505-002: exact hints from the start win levels 51 … 75.
    @Test func exactHintsWinLevels51To75() throws { #expect(try followFromStarts(51...75) == []) }

    /// SC-R02G0505-002: exact hints from the start win levels 76 … 100.
    @Test func exactHintsWinLevels76To100() throws { #expect(try followFromStarts(76...100) == []) }

    /// Checks seeded states `range`: the exact hint is a legal action (accepted by the kernel), it is `stuck` exactly
    /// when there is no plan, it names the plan's first edit, and from every state with a plan following hints wins.
    private func checkSamples(_ range: Range<Int>) throws -> (problems: [String], planned: Int, stuck: Int) {
        let samples: [HintSample] = try hintSamples()
        var problems: [String] = []
        var slowest: Double = 0
        var planned: Int = 0
        var stuck: Int = 0
        for index in range {
            let sample: HintSample = samples[index]
            let label: String = "state \(index) (level \(sample.number))"
            let plan: ColorfallCanyonsSolution? = ColorfallCanyonsHints.plan(sample.play)
            guard let hint = timedHint(3, sample.play, slowest: &slowest) else {
                problems.append("\(label): no hint")
                continue
            }
            guard let plan else {
                stuck += 1
                if hint.kind != .stuck { problems.append("\(label): no plan but hint \(hint.kind)") }
                continue
            }
            planned += 1
            if plan.edits.count > min(sample.play.remaining, 3) { problems.append("\(label): plan over budget") }
            switch plan.edits.first {
            case .none: if hint.kind != .run { problems.append("\(label): empty plan, hint \(hint.kind)") }
            case .some(.carve(let cell)):
                if hint.kind != .carve || hint.cell != cell { problems.append("\(label): plan carve \(cell), hint \(hint)") }
            case .some(.valve(let spring)):
                if hint.kind != .valve || hint.spring != spring {
                    problems.append("\(label): plan valve \(spring), hint \(hint)")
                }
            }
            guard let action = hintAction(hint) else {
                problems.append("\(label): plan but stuck")
                continue
            }
            var legal: ColorfallCanyonsPlay = sample.play
            if legal.stage == .paused { try legal.handle(.resume) }
            do { try legal.apply(action, expecting: legal.fingerprint) } catch {
                problems.append("\(label): hinted \(action) refused: \(error)")
            }
            problems += followHints(sample.play, label: label, slowest: &slowest)
        }
        print("Colorfall hints: states \(range) planned \(planned) stuck \(stuck) slowest hint \(Int(slowest * 1_000)) ms")
        return (problems, planned, stuck)
    }

    /// SC-R02G0505-002: seeded states 0 … 49.
    @Test func seededStates0To49() throws { #expect(try checkSamples(0..<50).problems == []) }

    /// SC-R02G0505-002: seeded states 50 … 99.
    @Test func seededStates50To99() throws { #expect(try checkSamples(50..<100).problems == []) }

    /// SC-R02G0505-002: seeded states 100 … 149.
    @Test func seededStates100To149() throws { #expect(try checkSamples(100..<150).problems == []) }

    /// SC-R02G0505-002: seeded states 150 … 199.
    @Test func seededStates150To199() throws { #expect(try checkSamples(150..<200).problems == []) }

    /// The sample holds 200 states, some of them paused, so the paused branch is exercised too.
    @Test func seededSampleHoldsPausedStates() throws {
        let samples: [HintSample] = try hintSamples()
        var paused: Int = 0
        for index in 0..<samples.count where samples[index].play.stage == .paused { paused += 1 }
        print("Colorfall hints: sample \(samples.count) states, \(paused) paused")
        #expect(samples.count == 200)
        #expect(paused > 0)
    }

    /// Clarification Q1: the three levels name the same action, levels clamp to 1 … 3, and each text reads as specified.
    @Test func hintLevelsAgreeAndReadAsSpecified() throws {
        let samples: [HintSample] = try hintSamples()
        var problems: [String] = []
        var kinds: Set<ColorfallCanyonsHintKind> = []
        var plays: [ColorfallCanyonsPlay] = []
        for index in 0..<20 { plays.append(samples[index].play) }
        plays += try edgePlays()
        for index in 0..<plays.count {
            let play: ColorfallCanyonsPlay = plays[index]
            let level: ColorfallCanyonsLevel = play.level
            guard let one = ColorfallCanyonsHints.hint(level: 1, play: play),
                  let two = ColorfallCanyonsHints.hint(level: 2, play: play),
                  let three = ColorfallCanyonsHints.hint(level: 3, play: play),
                  let low = ColorfallCanyonsHints.hint(level: 0, play: play),
                  let high = ColorfallCanyonsHints.hint(level: 9, play: play) else {
                problems.append("state \(index): a hint is missing")
                continue
            }
            kinds.insert(three.kind)
            for other in [one, two] where other.kind != three.kind || other.cell != three.cell
                || other.spring != three.spring || other.ticks != three.ticks || other.planSize != three.planSize {
                problems.append("state \(index): level \(other.level) differs from level 3")
            }
            if low != one || high != three { problems.append("state \(index): clamping") }
            if one.level != 1 || two.level != 2 || three.level != 3 { problems.append("state \(index): levels") }
            let ticks: Int = level.tickLimit - play.fluid.tick
            var expected: [String] = []
            switch three.kind {
            case .carve:
                let cell: Int = three.cell ?? -1
                expected = ["Carve a channel", "Carve near row \(cell / level.columns + 1)",
                            "Carve row \(cell / level.columns + 1), column \(cell % level.columns + 1)"]
            case .valve:
                let spring: Int = three.spring ?? 0
                let name: String = level.springs[spring].color.name
                let verb: String = play.fluid.valves[spring] ? "Close" : "Open"
                expected = ["Switch a valve", "Switch the \(name) spring", "\(verb) the \(name) valve"]
            case .run:
                expected = ["Let the fluid run", "Run to the end", "Run: \(ticks) ticks"]
            case .stuck:
                let text: String = "No win is reachable from here: undo the last change or retry the level."
                expected = [text, text, text]
            }
            if [one.text, two.text, three.text] != expected {
                problems.append("state \(index): texts \([one.text, two.text, three.text]) expected \(expected)")
            }
            if three.ticks != ticks { problems.append("state \(index): ticks \(three.ticks) expected \(ticks)") }
        }
        print("Colorfall hints: kinds seen \(kinds.map(\.rawValue).sorted())")
        #expect(problems == [])
        #expect(kinds == [.carve, .valve, .run, .stuck])
    }

    /// Clarification Q1: no hint when won (seeded wins and every won certified play), loading or in the tutorial; a
    /// failed play gets `stuck` with the undo-or-retry text at every level; a hint never changes the play.
    @Test func hintStagesAndPurity() throws {
        let levels: [ColorfallCanyonsLevel] = try hintLevels()
        var won: [ColorfallCanyonsPlay] = []
        for sample in try hintSamplesResult.get().won { won.append(sample.play) }
        for number in 1...10 { won.append(try witnessPlay(number)) }
        for play in won {
            #expect(play.stage == .won)
            #expect(ColorfallCanyonsHints.hint(level: 3, play: play) == nil)
        }
        var loading: ColorfallCanyonsPlay = ColorfallCanyonsPlay(level: levels[0])
        #expect(ColorfallCanyonsHints.hint(level: 1, play: loading) == nil)
        try loading.handle(.begin)
        #expect(loading.stage == .tutorial)
        #expect(ColorfallCanyonsHints.hint(level: 1, play: loading) == nil)
        let failures: [FailureSample] = try failureSamplesResult.get()
        for index in 0..<20 {
            let play: ColorfallCanyonsPlay = failures[index].play
            let before: String = play.fingerprint
            for level in 1...3 {
                let hint: ColorfallCanyonsHint? = ColorfallCanyonsHints.hint(level: level, play: play)
                #expect(hint?.kind == .stuck)
                #expect(hint?.text == "No win is reachable from here: undo the last change or retry the level.")
            }
            #expect(play.fingerprint == before)
            var result: ColorfallCanyonsPlay = play
            try result.handle(.showResult)
            #expect(ColorfallCanyonsHints.hint(level: 3, play: result) == nil)
        }
        let samples: [HintSample] = try hintSamples()
        for index in 0..<10 {
            let play: ColorfallCanyonsPlay = samples[index].play
            let before: ColorfallCanyonsPlay = play
            _ = ColorfallCanyonsHints.hint(level: 3, play: play)
            #expect(play == before)
        }
    }

    /// Checks seeded failures `range` against the independent recomputation; returns the problems and the reasons seen.
    private func checkFailures(_ range: Range<Int>) throws -> (problems: [String], reasons: [String: Int]) {
        let samples: [FailureSample] = try failureSamplesResult.get()
        var problems: [String] = []
        var reasons: [String: Int] = [:]
        for index in range {
            let play: ColorfallCanyonsPlay = samples[index].play
            let label: String = "failure \(index) (level \(samples[index].number))"
            guard let failure = play.failure else {
                problems.append("\(label): no failure")
                continue
            }
            reasons[failure.rawValue, default: 0] += 1
            if play.fluid.verdict(level: play.level) != .failed(failure) { problems.append("\(label): verdict") }
            guard let expected = expectedExplanation(play), let explanation = ColorfallCanyonsFailureExplanation(play: play)
            else {
                problems.append("\(label): no explanation")
                continue
            }
            if expected.failure != failure || explanation.failure != failure { problems.append("\(label): reason") }
            if explanation.basin != expected.basin { problems.append("\(label): basin \(explanation.basin)") }
            if explanation.color != expected.color { problems.append("\(label): colour") }
            if explanation.amount != expected.amount || explanation.limit != expected.limit {
                problems.append("\(label): amounts")
            }
            if explanation.tick != play.fluid.tick { problems.append("\(label): tick") }
            if explanation.text != expected.text { problems.append("\(label): text \(explanation.text)") }
            var shown: ColorfallCanyonsPlay = play
            try shown.handle(.showResult)
            if ColorfallCanyonsFailureExplanation(play: shown) != explanation { problems.append("\(label): result") }
        }
        print("Colorfall failures \(range): \(reasons.sorted { $0.key < $1.key })")
        return (problems, reasons)
    }

    /// SC-R02G0505-003: seeded failures 0 … 249 explained truly.
    @Test func seededFailures0To249() throws { #expect(try checkFailures(0..<250).problems == []) }

    /// SC-R02G0505-003: seeded failures 250 … 499 explained truly; across the sample more than one reason occurs.
    @Test func seededFailures250To499() throws {
        let checked: (problems: [String], reasons: [String: Int]) = try checkFailures(250..<500)
        #expect(checked.problems == [])
        let all: [FailureSample] = try failureSamplesResult.get()
        var reasons: Set<ColorfallCanyonsFailure> = []
        for sample in all { if let failure = sample.play.failure { reasons.insert(failure) } }
        #expect(reasons.count >= 2)
    }

    /// No explanation for plays that did not fail; a sample explanation reads exactly.
    @Test func noExplanationWithoutAFailure() throws {
        let levels: [ColorfallCanyonsLevel] = try hintLevels()
        var play: ColorfallCanyonsPlay = try ColorfallCanyonsExperienceCore.freshPlay(of: levels[0])
        #expect(ColorfallCanyonsFailureExplanation(play: play) == nil)
        for number in 1...5 { #expect(ColorfallCanyonsFailureExplanation(play: try witnessPlay(number)) == nil) }
        while play.stage == .playing { try play.apply(.step(600), expecting: play.fingerprint) }
        #expect(play.failure == .time)
        let explanation: ColorfallCanyonsFailureExplanation? = ColorfallCanyonsFailureExplanation(play: play)
        #expect(explanation?.text.hasPrefix("Time ran out at tick \(play.level.tickLimit): basin 1 holds cyan ") == true)
        #expect(explanation?.text.hasSuffix("; it needs \(play.level.basins[0].description). Undo the last change or retry the level.") == true)
        try play.undo()
        #expect(ColorfallCanyonsFailureExplanation(play: play) == nil)
    }

    /// Research R1: from a certified level's start the plan is the solver's solution (edits and win tick), and with the
    /// same bound it equals `solve(_:depth:)` in full (work and smaller counts too).
    private func planMatchesSolve(_ numbers: ClosedRange<Int>) throws -> [String] {
        let levels: [ColorfallCanyonsLevel] = try hintLevels()
        var problems: [String] = []
        var slowest: Double = 0
        for number in numbers {
            let level: ColorfallCanyonsLevel = levels[number - 1]
            let start: ContinuousClock.Instant = ContinuousClock.now
            let plan: ColorfallCanyonsSolution? = ColorfallCanyonsSolver.plan(level, from: ColorfallCanyonsFluid(level: level),
                                                                              budget: level.budget)
            slowest = max(slowest, seconds(ContinuousClock.now - start))
            let bound: Int = min(level.budget, ColorfallCanyonsSolver.maximumDepth)
            let solved: ColorfallCanyonsSolution? = ColorfallCanyonsSolver.solve(level, depth: bound)
            guard let plan, let solved else {
                problems.append("level \(number): plan \(String(describing: plan)), solve \(String(describing: solved))")
                continue
            }
            if plan != solved { problems.append("level \(number): plan \(plan) solve \(solved)") }
            if bound < ColorfallCanyonsSolver.maximumDepth, let full = ColorfallCanyonsSolver.solve(level),
               full.edits != plan.edits || full.winTick != plan.winTick {
                problems.append("level \(number): plan differs from solve(level)")
            }
        }
        print("Colorfall plan from start: levels \(numbers) slowest plan \(Int(slowest * 1_000)) ms")
        return problems
    }

    /// Research R1: plan from the start equals solve for levels 1 … 50.
    @Test func planFromStartEqualsSolveLevels1To50() throws { #expect(try planMatchesSolve(1...50) == []) }

    /// Research R1: plan from the start equals solve for levels 51 … 75.
    @Test func planFromStartEqualsSolveLevels51To75() throws { #expect(try planMatchesSolve(51...75) == []) }

    /// Research R1: plan from the start equals solve for levels 76 … 100.
    @Test func planFromStartEqualsSolveLevels76To100() throws { #expect(try planMatchesSolve(76...100) == []) }

    /// The plan is nil for a fluid that does not belong to the level, and a plan's win tick is absolute.
    @Test func planRefusesAForeignFluidAndReportsAbsoluteTicks() throws {
        let levels: [ColorfallCanyonsLevel] = try hintLevels()
        let other: ColorfallCanyonsLevel? = levels.first { $0.cellCount != levels[0].cellCount }
        if let other {
            #expect(ColorfallCanyonsSolver.plan(levels[0], from: ColorfallCanyonsFluid(level: other), budget: 3) == nil)
        }
        let level: ColorfallCanyonsLevel = levels[0]
        guard let solution = ColorfallCanyonsSolver.solve(level) else {
            Issue.record("level 1 has no solution")
            return
        }
        var play: ColorfallCanyonsPlay = try ColorfallCanyonsExperienceCore.freshPlay(of: level)
        for edit in solution.edits { try play.apply(edit.action, expecting: play.fingerprint) }
        try play.apply(.step(5), expecting: play.fingerprint)
        let plan: ColorfallCanyonsSolution? = ColorfallCanyonsHints.plan(play)
        #expect(plan?.edits == [])
        #expect(plan?.winTick == solution.winTick)
    }
}
