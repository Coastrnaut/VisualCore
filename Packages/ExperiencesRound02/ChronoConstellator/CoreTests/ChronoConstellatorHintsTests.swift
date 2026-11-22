// ChronoConstellatorHintsTests — feature 355 (R02-G06-05) T-R02G0605-002 (FR-R02G0605-002, 003; SC-R02G0605-002, 003;
// clarifications Q1, Q5). Hints and failure explanations on the 100 certified levels (generated once per process
// through the adapter's cache, prewarmed concurrently): following exact hints from every level's start wins, and the
// start's plan is the certified solution's phase changes; 200 seeded reachable states (seed 2_355: random phase
// changes, holds, releases, steps, rewinds and undos from certified openings, a failing step undone) get a legal exact
// hint, and from every state with a plan following hints wins, while a state without one gets `stuck`; the three hint
// levels agree on the action and read as clarification Q1 says; won, loading and tutorial plays get no hint and failed
// ones `stuck`; 500 seeded failures (seed 3_355) are explained with the stars, cell and tick recomputed independently
// here by an own replay. Every group measures and prints its slowest hint (no wall-clock assertion). Explicit types,
// plain loops.
@testable import ChronoConstellatorCore
import Foundation
import Testing
import VisualCoreSimulation

/// The 100 certified levels in manifest order, generated concurrently once per test process.
private let hintLevelsResult: Result<[ChronoConstellatorLevel], any Error> = Result {
    DispatchQueue.concurrentPerform(iterations: 100) { (index: Int) in
        _ = try? ChronoConstellatorExperienceCore.generated(number: index + 1)
    }
    var levels: [ChronoConstellatorLevel] = []
    for number in 1...100 { levels.append(try ChronoConstellatorExperienceCore.level(number: number)) }
    return levels
}

/// The certified levels.
private func hintLevels() throws -> [ChronoConstellatorLevel] { try hintLevelsResult.get() }

/// Seconds of a duration.
private func seconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) + Double(duration.components.attoseconds) * 1e-18
}

/// The hint of `level` for `play`, timed; the slowest time so far is kept in `slowest`.
private func timedHint(_ level: Int, _ play: ChronoConstellatorPlay, slowest: inout Double) -> ChronoConstellatorHint? {
    let start: ContinuousClock.Instant = ContinuousClock.now
    let hint: ChronoConstellatorHint? = ChronoConstellatorHints.hint(level: level, play: play)
    let elapsed: Double = seconds(ContinuousClock.now - start)
    if elapsed > slowest { slowest = elapsed }
    return hint
}

/// The kernel action an exact hint names (a run is one step of its ticks, at most 1,200); nil for `stuck`.
private func hintAction(_ hint: ChronoConstellatorHint) -> ChronoConstellatorAction? {
    switch hint.kind {
    case .phase:
        guard let star = hint.star, let phase = hint.phase else { return nil }
        return .phase(star, phase)
    case .release:
        guard let star = hint.star, let start = hint.start else { return nil }
        return .release(star, start)
    case .rewind: return .rewind
    case .run: return .step(max(1, min(1_200, hint.ticks)))
    case .stuck: return nil
    }
}

/// Follows exact hints from `start` (resumed when paused) until the play ends; the problems found (empty: won, every
/// hinted action accepted).
private func followHints(_ start: ChronoConstellatorPlay, label: String, slowest: inout Double) -> [String] {
    var play: ChronoConstellatorPlay = start
    if play.stage == .paused { try? play.handle(.resume) }
    for _ in 0..<32 {
        if play.stage == .won { return [] }
        guard let hint = timedHint(3, play, slowest: &slowest) else { return ["\(label): no hint in \(play.stage)"] }
        guard let action = hintAction(hint) else { return ["\(label): stuck at tick \(play.tick)"] }
        do {
            try play.apply(action, expecting: play.fingerprint)
        } catch {
            return ["\(label): hinted \(action) refused: \(error)"]
        }
    }
    return play.stage == .won ? [] : ["\(label): not won, stage \(play.stage)"]
}

/// A seeded reachable state of the hint sample.
private struct HintSample {
    let number: Int
    let play: ChronoConstellatorPlay
}

/// One random action for `play`: a phase change or a hold (at tick 0), a release of an existing hold, a step of 1 … 60
/// ticks, a rewind; `nil` stands for an undo.
private func randomAction(_ play: ChronoConstellatorPlay,
                          random: inout SeededRandom) -> ChronoConstellatorAction? {
    let level: ChronoConstellatorLevel = play.level
    let choice: Int = random.int(0...9)
    let star: Int = random.int(0...(level.stars.count - 1))
    switch choice {
    case 0, 1, 2:
        return .phase(star, random.int(0...(level.stars[star].length - 1)))
    case 3:
        let length: Int = random.int(1...10)
        return .hold(star, random.int(1...(level.tickLimit - length + 1)), length)
    case 4:
        if let hold = play.timeline.holds.first { return .release(hold.star, hold.start) }
        return .rewind
    case 5, 6, 7:
        return .step(random.int(1...60))
    case 8:
        return .rewind
    default:
        return nil
    }
}

/// The 200 seeded reachable states (seed 2_355) and the won plays met while building them. From a random certified
/// level's opening, 0 … 6 random actions (refused ones are skipped); a step that fails the play is undone, a won play
/// is set aside; about one state in ten is paused.
private let hintSamplesResult: Result<(states: [HintSample], won: [HintSample]), any Error> = Result {
    let levels: [ChronoConstellatorLevel] = try hintLevels()
    var random: SeededRandom = SeededRandom(seed: 2_355)
    var states: [HintSample] = []
    var won: [HintSample] = []
    while states.count < 200 {
        let number: Int = random.int(1...100)
        var play: ChronoConstellatorPlay = try ChronoConstellatorExperienceCore.freshPlay(of: levels[number - 1])
        let count: Int = random.int(0...6)
        var ended: Bool = false
        for _ in 0..<count {
            if let action = randomAction(play, random: &random) {
                try? play.apply(action, expecting: play.fingerprint)
            } else {
                try? play.undo()
            }
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

/// The 500 seeded failures (seed 3_355): from a random certified level's opening, 0 … min(3, budget) random phase
/// changes or holds (refused ones skipped), then steps of 1,200 ticks until the play ends; won plays are skipped.
private let failureSamplesResult: Result<[HintSample], any Error> = Result {
    let levels: [ChronoConstellatorLevel] = try hintLevels()
    var random: SeededRandom = SeededRandom(seed: 3_355)
    var samples: [HintSample] = []
    while samples.count < 500 {
        let number: Int = random.int(1...100)
        let level: ChronoConstellatorLevel = levels[number - 1]
        var play: ChronoConstellatorPlay = try ChronoConstellatorExperienceCore.freshPlay(of: level)
        let edits: Int = random.int(0...min(3, level.budget))
        for _ in 0..<edits {
            let star: Int = random.int(0...(level.stars.count - 1))
            if random.int(0...3) == 0 {
                let length: Int = random.int(1...10)
                let start: Int = random.int(1...(level.tickLimit - length + 1))
                try? play.apply(.hold(star, start, length), expecting: play.fingerprint)
            } else {
                let phase: Int = random.int(0...(level.stars[star].length - 1))
                try? play.apply(.phase(star, phase), expecting: play.fingerprint)
            }
        }
        while play.stage == .playing { try play.apply(.step(1_200), expecting: play.fingerprint) }
        if play.stage == .failed { samples.append(HintSample(number: number, play: play)) }
    }
    return samples
}

/// The cell of star `star` at tick `tick` recomputed here: loop[(phase + tick − held ticks among 1 … tick) mod L].
private func ownCell(_ level: ChronoConstellatorLevel, _ timeline: ChronoConstellatorTimeline, star: Int,
                     tick: Int) -> Int {
    var held: Int = 0
    for hold in timeline.holds where hold.star == star {
        var t: Int = hold.start
        while t <= hold.start + hold.length - 1 && t <= tick {
            held += 1
            t += 1
        }
    }
    let loop: [Int] = level.stars[star].loop
    let step: Int = timeline.phases[star] + tick - held
    return loop[((step % loop.count) + loop.count) % loop.count]
}

/// The expected explanation of a failed play, recomputed by an own replay of its timeline from tick 1: the failing
/// tick, the stars named, the cell and the text; nil when the replay wins or never fails.
private func expectedExplanation(_ play: ChronoConstellatorPlay)
    -> (tick: Int, stars: [Int], cell: Int?, text: String)? {
    let level: ChronoConstellatorLevel = play.level
    let names: [String] = ["ring", "cross", "diamond", "triangle", "square"]
    let advice: String = " Undo the last change, rewind or retry the level."
    func place(_ cell: Int) -> String { "row \(cell / level.columns + 1), column \(cell % level.columns + 1)" }
    for tick in 1...level.tickLimit {
        var cells: [Int] = []
        for star in 0..<level.stars.count { cells.append(ownCell(level, play.timeline, star: star, tick: tick)) }
        for a in 0..<cells.count {
            for b in (a + 1)..<max(a + 1, cells.count) where cells[a] == cells[b] {
                let text: String = "Star \(a + 1) (\(names[a])) and star \(b + 1) (\(names[b])) met at "
                    + "\(place(cells[a])) on tick \(tick)." + advice
                return (tick, [a, b], cells[a], text)
            }
        }
        var off: [Int] = []
        var parts: [String] = []
        for star in 0..<cells.count where cells[star] != level.stars[star].target {
            off.append(star)
            parts.append("star \(star + 1) (\(names[star])) is at \(place(cells[star])), its target is "
                + place(level.stars[star].target))
        }
        if off.isEmpty { return nil }
        if tick == level.tickLimit {
            return (tick, off, nil, "Time ran out at tick \(tick): " + parts.joined(separator: "; ") + "." + advice)
        }
    }
    return nil
}

@Suite struct ChronoConstellatorHintsTests {
    /// Follows exact hints from the openings of certified levels `numbers`; returns the problems.
    private func followFromStarts(_ numbers: ClosedRange<Int>) throws -> [String] {
        let levels: [ChronoConstellatorLevel] = try hintLevels()
        var problems: [String] = []
        var slowest: Double = 0
        for number in numbers {
            let play: ChronoConstellatorPlay = try ChronoConstellatorExperienceCore.freshPlay(of: levels[number - 1])
            problems += followHints(play, label: "level \(number)", slowest: &slowest)
        }
        print("Chrono hints: levels \(numbers) slowest hint \(String(format: "%.3f", slowest * 1_000)) ms")
        return problems
    }

    /// SC-R02G0605-002: exact hints from the opening win levels 1 … 50.
    @Test func exactHintsWinLevels1To50() throws {
        let problems: [String] = try followFromStarts(1...50)
        #expect(problems == [])
    }

    /// SC-R02G0605-002: exact hints from the opening win levels 51 … 100.
    @Test func exactHintsWinLevels51To100() throws {
        let problems: [String] = try followFromStarts(51...100)
        #expect(problems == [])
    }

    /// The plan from every certified opening is the certified solution's phase changes in star order.
    @Test func openingPlanIsTheCertifiedSolution() throws {
        let levels: [ChronoConstellatorLevel] = try hintLevels()
        var problems: [String] = []
        for number in 1...100 {
            let generated: ChronoConstellatorGenerated = try ChronoConstellatorExperienceCore.generated(number: number)
            let play: ChronoConstellatorPlay = try ChronoConstellatorExperienceCore.freshPlay(of: levels[number - 1])
            var changes: [ChronoConstellatorPhaseChange] = []
            for star in 0..<generated.level.stars.count
            where generated.solution.phases[star] != generated.level.stars[star].phase {
                changes.append(ChronoConstellatorPhaseChange(star: star, phase: generated.solution.phases[star]))
            }
            let plan: ChronoConstellatorPlan? = ChronoConstellatorHints.plan(play)
            if plan != .phases(changes) { problems.append("level \(number): plan \(String(describing: plan))") }
            if changes.count != generated.solution.lowerBound { problems.append("level \(number): change count") }
        }
        #expect(problems == [])
    }

    /// Checks seeded states `range`: the exact hint is `stuck` exactly when there is no plan, names the plan's action,
    /// is a legal action (accepted by the kernel), and from every state with a plan following hints wins.
    private func checkSamples(_ range: Range<Int>) throws -> (problems: [String], planned: Int, stuck: Int) {
        let samples: [HintSample] = try hintSamples()
        var problems: [String] = []
        var slowest: Double = 0
        var planned: Int = 0
        var stuck: Int = 0
        for index in range {
            let sample: HintSample = samples[index]
            let label: String = "state \(index) (level \(sample.number))"
            let plan: ChronoConstellatorPlan? = ChronoConstellatorHints.plan(sample.play)
            guard let hint = timedHint(3, sample.play, slowest: &slowest) else {
                problems.append("\(label): no hint")
                continue
            }
            guard let plan else {
                stuck += 1
                if hint.kind != .stuck || hint.text != ChronoConstellatorHint.stuckText {
                    problems.append("\(label): no plan but hint \(hint.kind)")
                }
                continue
            }
            planned += 1
            switch plan {
            case .run(let ticks):
                if hint.kind != .run || hint.ticks != ticks { problems.append("\(label): plan run, hint \(hint)") }
            case .rewind:
                if hint.kind != .rewind { problems.append("\(label): plan rewind, hint \(hint)") }
            case .release(let star, let start):
                if hint.kind != .release || hint.star != star || hint.start != start {
                    problems.append("\(label): plan release, hint \(hint)")
                }
            case .phases(let changes):
                if changes.isEmpty || hint.kind != .phase || hint.star != changes[0].star
                    || hint.phase != changes[0].phase {
                    problems.append("\(label): plan phases, hint \(hint)")
                }
            }
            guard let action = hintAction(hint) else {
                problems.append("\(label): plan but stuck")
                continue
            }
            var legal: ChronoConstellatorPlay = sample.play
            if legal.stage == .paused { try legal.handle(.resume) }
            do { try legal.apply(action, expecting: legal.fingerprint) } catch {
                problems.append("\(label): hinted \(action) refused: \(error)")
            }
            problems += followHints(sample.play, label: label, slowest: &slowest)
        }
        print("Chrono hints: states \(range) planned \(planned) stuck \(stuck) slowest hint "
            + "\(String(format: "%.3f", slowest * 1_000)) ms")
        for problem in problems { print("Chrono hints problem: \(problem)") }
        return (problems, planned, stuck)
    }

    /// SC-R02G0605-002: seeded states 0 … 99.
    @Test func seededStates0To99() throws {
        let problems: [String] = try checkSamples(0..<100).problems
        #expect(problems == [])
    }

    /// SC-R02G0605-002: seeded states 100 … 199.
    @Test func seededStates100To199() throws {
        let problems: [String] = try checkSamples(100..<200).problems
        #expect(problems == [])
    }

    /// The sample holds 200 states, some paused, some after tick 0 and some with holds, so every plan branch is met.
    @Test func seededSampleCoversEveryBranch() throws {
        let samples: [HintSample] = try hintSamples()
        var paused: Int = 0
        var kinds: Set<ChronoConstellatorHintKind> = []
        for index in 0..<samples.count {
            if samples[index].play.stage == .paused { paused += 1 }
            if let hint = ChronoConstellatorHints.hint(level: 3, play: samples[index].play) { kinds.insert(hint.kind) }
        }
        print("Chrono hints: sample \(samples.count) states, \(paused) paused, kinds \(kinds.map(\.rawValue).sorted())")
        #expect(samples.count == 200)
        #expect(paused > 0)
        #expect(kinds.isSuperset(of: [.phase, .release, .rewind, .run]))
    }

    /// Clarification Q1 on seeded states 0 … 99: the three levels agree, clamp and read as specified.
    @Test func hintLevelsAgreeStates0To99() throws {
        let problems: [String] = try checkLevels(0..<100)
        #expect(problems == [])
    }

    /// Clarification Q1 on seeded states 100 … 199: the three levels agree, clamp and read as specified.
    @Test func hintLevelsAgreeStates100To199() throws {
        let problems: [String] = try checkLevels(100..<200)
        #expect(problems == [])
    }

    /// Checks seeded states `range`: the three levels name the same action, levels clamp to 1 … 3, and each text reads
    /// as specified; returns the problems.
    private func checkLevels(_ range: Range<Int>) throws -> [String] {
        let samples: [HintSample] = try hintSamples()
        let names: [String] = ["ring", "cross", "diamond", "triangle", "square"]
        var problems: [String] = []
        for index in range {
            let play: ChronoConstellatorPlay = samples[index].play
            let level: ChronoConstellatorLevel = play.level
            guard let one = ChronoConstellatorHints.hint(level: 1, play: play),
                  let two = ChronoConstellatorHints.hint(level: 2, play: play),
                  let three = ChronoConstellatorHints.hint(level: 3, play: play),
                  let low = ChronoConstellatorHints.hint(level: 0, play: play),
                  let high = ChronoConstellatorHints.hint(level: 9, play: play) else {
                problems.append("state \(index): a hint is missing")
                continue
            }
            for other in [one, two] where other.kind != three.kind || other.star != three.star
                || other.cell != three.cell || other.phase != three.phase || other.start != three.start
                || other.ticks != three.ticks {
                problems.append("state \(index): level \(other.level) differs from level 3")
            }
            if low != one || high != three { problems.append("state \(index): clamping") }
            if one.level != 1 || two.level != 2 || three.level != 3 { problems.append("state \(index): levels") }
            let k: Int = (three.star ?? 0) + 1
            let shape: String = names[three.star ?? 0]
            var expected: [String] = []
            switch three.kind {
            case .run:
                expected = ["Replay the timeline", "Run to the end", "Run: \(three.ticks) ticks"]
            case .rewind:
                let text: String = "Rewind to tick 0 to change the timeline"
                expected = [text, text, text]
            case .release:
                expected = ["Remove a hold", "Remove star \(k)'s hold",
                            "Remove star \(k)'s hold from tick \(three.start ?? -1)"]
            case .phase:
                let star: Int = three.star ?? 0
                let phase: Int = three.phase ?? 0
                let cell: Int = level.stars[star].loop[phase]
                if three.cell != cell { problems.append("state \(index): cell \(String(describing: three.cell))") }
                expected = ["Change a star's start", "Change the start of star \(k) (\(shape))",
                            "Start star \(k) (\(shape)) at row \(cell / level.columns + 1), column "
                                + "\(cell % level.columns + 1) (phase \(phase))"]
            case .stuck:
                let text: String = "No win is reachable from here: undo the last change, rewind or retry the level."
                expected = [text, text, text]
            }
            if [one.text, two.text, three.text] != expected {
                problems.append("state \(index): texts \([one.text, two.text, three.text]) expected \(expected)")
            }
        }
        return problems
    }

    /// Won, loading and tutorial plays get no hint and no plan; failed plays get `stuck` with the failed text.
    @Test func stagesWithoutHints() throws {
        let won: [HintSample] = try hintSamplesResult.get().won
        let failures: [HintSample] = try failureSamplesResult.get()
        var problems: [String] = []
        var slowest: Double = 0
        for index in 0..<won.count where ChronoConstellatorHints.hint(level: 3, play: won[index].play) != nil
            || ChronoConstellatorHints.plan(won[index].play) != nil {
            problems.append("won \(index): hint or plan")
        }
        let tutorial: ChronoConstellatorLevel = try ChronoConstellatorExperienceCore.level(number: 1)
        var loading: ChronoConstellatorPlay = ChronoConstellatorPlay(level: tutorial)
        if ChronoConstellatorHints.hint(level: 1, play: loading) != nil { problems.append("loading: hint") }
        try loading.handle(.begin)
        if loading.stage != .tutorial || ChronoConstellatorHints.hint(level: 1, play: loading) != nil {
            problems.append("tutorial: hint")
        }
        for index in 0..<50 {
            for level in 1...3 {
                let hint: ChronoConstellatorHint? = timedHint(level, failures[index].play, slowest: &slowest)
                if hint?.kind != .stuck || hint?.text != "Undo the last change, rewind or retry the level." {
                    problems.append("failure \(index): hint \(String(describing: hint))")
                }
            }
            if ChronoConstellatorHints.plan(failures[index].play) != nil { problems.append("failure \(index): plan") }
        }
        print("Chrono hints: won plays \(won.count), failed-play slowest hint "
            + "\(String(format: "%.3f", slowest * 1_000)) ms")
        #expect(problems == [])
    }

    /// Checks seeded failures `range` against the independent recomputation.
    private func checkFailures(_ range: Range<Int>) throws -> [String] {
        let samples: [HintSample] = try failureSamplesResult.get()
        var problems: [String] = []
        var collisions: Int = 0
        for index in range {
            let play: ChronoConstellatorPlay = samples[index].play
            let label: String = "failure \(index) (level \(samples[index].number))"
            guard let explanation = ChronoConstellatorFailureExplanation(play: play) else {
                problems.append("\(label): no explanation")
                continue
            }
            guard let expected = expectedExplanation(play) else {
                problems.append("\(label): own replay does not fail")
                continue
            }
            if case .collision = explanation.failure { collisions += 1 }
            if explanation.failure != play.failure || explanation.tick != expected.tick || explanation.tick != play.tick
                || explanation.stars != expected.stars || explanation.cell != expected.cell
                || explanation.text != expected.text {
                problems.append("\(label): \(explanation.text) expected \(expected.text)")
            }
        }
        print("Chrono failures: \(range) collisions \(collisions) time \(range.count - collisions)")
        return problems
    }

    /// SC-R02G0605-003: seeded failures 0 … 249 explained with the true stars, cell and tick.
    @Test func failuresExplained0To249() throws {
        let problems: [String] = try checkFailures(0..<250)
        #expect(problems == [])
    }

    /// SC-R02G0605-003: seeded failures 250 … 499 explained with the true stars, cell and tick.
    @Test func failuresExplained250To499() throws {
        let problems: [String] = try checkFailures(250..<500)
        #expect(problems == [])
    }

    /// The sample holds both failure kinds, and plays that did not fail (or are not over) have no explanation.
    @Test func failureSampleCoversBothKinds() throws {
        let samples: [HintSample] = try failureSamplesResult.get()
        var collisions: Int = 0
        var times: Int = 0
        for index in 0..<samples.count {
            if case .collision = samples[index].play.failure { collisions += 1 } else { times += 1 }
        }
        print("Chrono failures: sample \(samples.count), collisions \(collisions), time \(times)")
        #expect(samples.count == 500)
        #expect(collisions > 0)
        #expect(times > 0)
        let opening: ChronoConstellatorPlay = try ChronoConstellatorExperienceCore.freshPlay(of: try hintLevels()[0])
        #expect(ChronoConstellatorFailureExplanation(play: opening) == nil)
        var result: ChronoConstellatorPlay = samples[0].play
        try result.handle(.showResult)
        let after: ChronoConstellatorFailureExplanation? = ChronoConstellatorFailureExplanation(play: result)
        #expect(after != nil)
        #expect(after == ChronoConstellatorFailureExplanation(play: samples[0].play))
    }
}
