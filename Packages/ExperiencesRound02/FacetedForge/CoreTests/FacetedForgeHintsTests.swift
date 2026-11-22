// FacetedForgeHintsTests — feature 375 (R02-G08-05) T-R02G0805-002 (FR-R02G0805-002, 003; SC-R02G0805-002, 003;
// clarifications Q1, Q5). Hints and failure explanations on the 100 certified levels (generated once per process
// through the adapter's cache, prewarmed concurrently): on every level the opening hint is the certified solution's
// first cut and following exact hints (re-asked after every cut) wins with exactly the certified smallest cut count, in
// 20 groups of 5 levels; the certifying solve equals the new entry point from the crystal and the opening plan is the
// certified solution on one level in ten; 200 seeded reachable states (seed 2_375: certified cuts, random crossing
// cuts, undos and pauses from certified openings) get a hint that is a legal cut, from every state with a plan
// following hints wins, and a state without a plan is confirmed unwinnable independently where feasible (no cut left
// for a needed one, fewer pieces needed than present, or an exhaustive search written here over every crossing cut for
// one or two cuts, on the pieces themselves and without the solver); a hint never changes the play; the three hint
// levels agree on the cut and read as clarification Q1 says; loading, tutorial, won and result-after-win plays get no
// hint, failed ones `stuck`; 500 seeded failures (seed 3_375, 10 groups: cuts that leave a sliver and cuts that exhaust
// the budget) are explained with the reason, cut, piece, share or cuts and pieces tracked independently here (own piece
// list, own shares, own canonical order). Every group prints its slowest hint (no wall-clock assertion). Explicit
// types, plain loops.
@testable import FacetedForgeCore
import Foundation
import Testing

/// The 100 certified levels and their solutions in manifest order, generated concurrently once per test process.
private let hintCatalogResult: Result<[FacetedForgeGenerated], any Error> = Result {
    DispatchQueue.concurrentPerform(iterations: 100) { (index: Int) in
        _ = try? FacetedForgeExperienceCore.generated(number: index + 1)
    }
    var catalog: [FacetedForgeGenerated] = []
    for number in 1...100 { catalog.append(try FacetedForgeExperienceCore.generated(number: number)) }
    return catalog
}

/// The certified catalog.
private func hintCatalog() throws -> [FacetedForgeGenerated] { try hintCatalogResult.get() }

/// Seconds of a duration.
private func seconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) + Double(duration.components.attoseconds) * 1e-18
}

/// Timing of hint calls: the slowest, the total and the count.
private struct HintTimer {
    var slowest: Double = 0
    var total: Double = 0
    var count: Int = 0

    /// The hint of `level` for `play`, timed.
    mutating func hint(_ level: Int, _ play: FacetedForgePlay) -> FacetedForgeHint? {
        let start: ContinuousClock.Instant = ContinuousClock.now
        let hint: FacetedForgeHint? = FacetedForgeHints.hint(level: level, play: play)
        let elapsed: Double = seconds(ContinuousClock.now - start)
        if elapsed > slowest { slowest = elapsed }
        total += elapsed
        count += 1
        return hint
    }

    /// A one-line summary in milliseconds.
    var summary: String {
        let mean: Double = count == 0 ? 0 : total / Double(count)
        return String(format: "%d hints, mean %.3f ms, slowest %.3f ms", count, mean * 1_000, slowest * 1_000)
    }
}

/// Every crossing cut of `pieces`: every piece, directions 0 … 12, every depth whose plane crosses the piece.
private func crossingCuts(_ pieces: [FacetedForgePiece]) -> [(piece: Int, direction: Int, depth: Int)] {
    var cuts: [(piece: Int, direction: Int, depth: Int)] = []
    for index in pieces.indices {
        for direction in 0..<FacetedForgeDirection.all.count {
            for depth in FacetedForgeHalfSpace.depths
            where pieces[index].isCrossed(direction: direction, depth: depth) {
                cuts.append((index, direction, depth))
            }
        }
    }
    return cuts
}

/// The (share, faces) entries of `pieces` in a crystal of volume `volume`, or nil on an arithmetic overflow.
private func entries(_ pieces: [FacetedForgePiece], volume: FacetedForgeFraction) -> [FacetedForgeTargetPiece]? {
    var made: [FacetedForgeTargetPiece] = []
    for piece in pieces {
        guard let share = try? piece.volume.dividing(by: volume) else { return nil }
        made.append(FacetedForgeTargetPiece(share: share, faces: piece.faceCount))
    }
    return made
}

/// Whether `part` is a sub-multiset of `whole`.
private func isSubMultiset(_ part: [FacetedForgeTargetPiece], of whole: [FacetedForgeTargetPiece]) -> Bool {
    var left: [FacetedForgeTargetPiece] = whole
    for entry in part {
        guard let found = left.firstIndex(of: entry) else { return false }
        left.remove(at: found)
    }
    return true
}

/// The pieces after cutting `pieces[index]`, in canonical order, and its two halves; nil when the cut overflows or
/// leaves a half below `sliver` (a sliver fails the play, so it can never be part of a win).
private func cutting(_ pieces: [FacetedForgePiece], _ index: Int, _ direction: Int, _ depth: Int,
                     volume: FacetedForgeFraction, sliver: FacetedForgeFraction) -> [FacetedForgePiece]? {
    guard let halves = try? pieces[index].cut(direction: direction, depth: depth),
          let below = try? halves.below.volume.dividing(by: volume),
          let above = try? halves.above.volume.dividing(by: volume),
          !(below < sliver), !(above < sliver) else { return nil }
    var rest: [FacetedForgePiece] = pieces
    rest.remove(at: index)
    return FacetedForgePiece.canonical(rest + [halves.below, halves.above])
}

/// Independent: whether one cut of `pieces` (no sliver) makes exactly the target of `level`.
private func winsInOne(_ pieces: [FacetedForgePiece], level: FacetedForgeLevel) -> Bool {
    let volume: FacetedForgeFraction = level.crystal.volume
    let target: [FacetedForgeTargetPiece] = level.target.sorted()
    for cut in crossingCuts(pieces) {
        guard let next = cutting(pieces, cut.piece, cut.direction, cut.depth, volume: volume, sliver: level.sliver),
              let made = entries(next, volume: volume) else { continue }
        if made.sorted() == target { return true }
    }
    return false
}

/// Independent: whether two cuts of `pieces` (no sliver) make exactly the target of `level`. A second cut splits one
/// piece and keeps the rest, so the rest must already be target entries: only those pieces are tried.
private func winsInTwo(_ pieces: [FacetedForgePiece], level: FacetedForgeLevel) -> Bool {
    let volume: FacetedForgeFraction = level.crystal.volume
    for cut in crossingCuts(pieces) {
        guard let next = cutting(pieces, cut.piece, cut.direction, cut.depth, volume: volume, sliver: level.sliver),
              let made = entries(next, volume: volume) else { continue }
        for index in next.indices {
            var rest: [FacetedForgeTargetPiece] = made
            rest.remove(at: index)
            guard isSubMultiset(rest, of: level.target) else { continue }
            let target: [FacetedForgeTargetPiece] = level.target.sorted()
            for direction in 0..<FacetedForgeDirection.all.count {
                for depth in FacetedForgeHalfSpace.depths
                where next[index].isCrossed(direction: direction, depth: depth) {
                    guard let last = cutting(next, index, direction, depth, volume: volume, sliver: level.sliver),
                          let final = entries(last, volume: volume) else { continue }
                    if final.sorted() == target { return true }
                }
            }
        }
    }
    return false
}

/// Follows exact hints from `start` (resumed when paused; `first`, when given, is the hint already asked for `start`)
/// until the play ends; the problems found (empty: won, every
/// hinted cut a crossing cut and accepted) and the cuts spent following them.
private func followHints(_ start: FacetedForgePlay, label: String, first: FacetedForgeHint? = nil,
                         timer: inout HintTimer) -> (problems: [String], spent: Int) {
    var play: FacetedForgePlay = start
    if play.stage == .paused { try? play.handle(.resume) }
    var spent: Int = 0
    var given: FacetedForgeHint? = first
    for _ in 0..<32 {
        if play.stage == .won { return ([], spent) }
        let asked: FacetedForgeHint? = given ?? timer.hint(3, play)
        given = nil
        guard let hint = asked else { return (["\(label): no hint in \(play.stage)"], spent) }
        guard let action = hint.action else { return (["\(label): stuck at cut \(play.cuts)"], spent) }
        guard case .cut(let piece, let direction, let depth) = action, play.pieces.indices.contains(piece),
              play.pieces[piece].isCrossed(direction: direction, depth: depth) else {
            return (["\(label): hinted \(action) is not a crossing cut"], spent)
        }
        do {
            try play.apply(action, expecting: play.fingerprint)
        } catch {
            return (["\(label): hinted \(action) refused: \(error)"], spent)
        }
        spent += 1
    }
    return (play.stage == .won ? [] : ["\(label): not won, stage \(play.stage)"], spent)
}

/// A seeded reachable state of the hint sample.
private struct HintSample {
    let number: Int
    let play: FacetedForgePlay
}

/// The 200 seeded reachable states, drawn once per test process.
private let hintSamplesResult: Result<[HintSample], any Error> = Result { try drawHintSamples() }

/// The 200 seeded reachable states.
private func hintSamples() throws -> [HintSample] { try hintSamplesResult.get() }

/// 200 seeded reachable states (seed 2_375): from a certified opening, 0 … smallest − 1 certified cuts (so many states
/// stay on a winning path), then 0 … 3 random steps — a random crossing cut (most often) or an undo — where a cut that
/// fails the play is undone and a won play is drawn again; about one in four samples ends paused.
private func drawHintSamples() throws -> [HintSample] {
    let catalog: [FacetedForgeGenerated] = try hintCatalog()
    var random = FacetedForgeRandom(seed: 2_375)
    var samples: [HintSample] = []
    while samples.count < 200 {
        let number: Int = random.int(1...100)
        let generated: FacetedForgeGenerated = catalog[number - 1]
        var play: FacetedForgePlay = try FacetedForgeExperienceCore.freshPlay(of: generated.level)
        let certified: Int = random.int(0...(generated.solution.actions.count - 1))
        for index in 0..<certified { try play.apply(generated.solution.actions[index], expecting: play.fingerprint) }
        let steps: Int = random.int(0...3)
        for _ in 0..<steps {
            if play.stage != .playing { break }
            if random.int(0...4) == 0 {
                if play.canUndo { try play.undo() }
                continue
            }
            let cut: (piece: Int, direction: Int, depth: Int) = FacetedForgeFixtures.randomCut(play.pieces, &random)
            do {
                try play.apply(.cut(cut.piece, cut.direction, cut.depth), expecting: play.fingerprint)
            } catch {
                continue
            }
            if play.stage == .failed { try play.undo() }
        }
        guard play.stage == .playing else { continue }
        if random.int(0...3) == 0 { try play.handle(.pause) }
        samples.append(HintSample(number: number, play: play))
    }
    return samples
}

/// A seeded failure and what this test tracked about it independently.
private struct TrackedFailure {
    let number: Int
    let play: FacetedForgePlay
    /// "sliver" or "budget".
    let reason: String
    /// The failing cut, 1-based.
    let cut: Int
    /// The sliver piece's canonical index after the failing cut (sliver only).
    let piece: Int?
    /// The sliver piece's share (sliver only).
    let share: FacetedForgeFraction?
    /// The pieces at the failure.
    let pieces: Int
}

@Suite struct FacetedForgeHintsTests {
    // MARK: Following hints from every opening

    /// SC-R02G0805-002: on every certified level the opening hint is the certified solution's first cut, and
    /// following exact hints (re-asked after every cut) wins with exactly the certified smallest cut count (group
    /// `group` of 5 levels; 20 groups keep each case short, as the opening search repeats the certification's work).
    @Test(arguments: 0..<20) func testFollowingHintsWinsEveryCertifiedLevel(group: Int) throws {
        let catalog: [FacetedForgeGenerated] = try hintCatalog()
        var timer = HintTimer()
        for number in (group * 5 + 1)...(group * 5 + 5) {
            let generated: FacetedForgeGenerated = catalog[number - 1]
            let level: FacetedForgeLevel = generated.level
            let play: FacetedForgePlay = try FacetedForgeExperienceCore.freshPlay(of: level)
            let opening: FacetedForgeHint? = timer.hint(3, play)
            #expect(opening?.action == generated.solution.actions.first, "level \(number): not the certified cut")
            let result: (problems: [String], spent: Int) = followHints(play, label: "level \(number)", first: opening,
                                                                       timer: &timer)
            #expect(result.problems.isEmpty, "\(result.problems)")
            #expect(result.spent == generated.solution.smallest, "level \(number): \(result.spent) cuts")
        }
        print("hints group \(group): \(timer.summary)")
    }

    /// The certifying solve is the new entry point from the crystal with the lower bound of cuts left (same
    /// smallest, cuts and work) and the opening plan is the certified solution, on one level in ten (the whole catalog
    /// is certified through the new entry point by the catalog tests' pinned digest and witnesses).
    @Test func testCertifyingSolveEqualsSolveFromCrystal() throws {
        let catalog: [FacetedForgeGenerated] = try hintCatalog()
        for index in stride(from: 0, to: catalog.count, by: 10) {
            let opening: FacetedForgePlay = try FacetedForgeExperienceCore.freshPlay(of: catalog[index].level)
            #expect(FacetedForgeHints.plan(opening)?.actions == catalog[index].solution.actions, "level \(index + 1)")
            let level: FacetedForgeLevel = catalog[index].level
            let fromCrystal: FacetedForgeSolution? = FacetedForgeSolver.solve(
                level, from: [level.crystal], cutsLeft: FacetedForgeSolver.lowerBound(level))
            #expect(fromCrystal == catalog[index].solution, "level \(index + 1)")
            #expect(fromCrystal?.smallest == FacetedForgeSolver.lowerBound(level))
        }
        let level: FacetedForgeLevel = catalog[0].level
        #expect(FacetedForgeSolver.solve(level, from: [level.crystal], cutsLeft: 0) == nil)
        #expect(FacetedForgeSolver.solve(level, from: [level.crystal], cutsLeft: -1) == nil)
    }

    // MARK: Seeded reachable states

    /// SC-R02G0805-002: 200 seeded reachable states (group `group` of 20): the hint is a legal cut at every level and
    /// does not change the play; from a state with a plan following hints wins within the cuts left; a state without a
    /// plan is confirmed unwinnable independently where feasible.
    @Test(arguments: 0..<10) func testSeededReachableStates(group: Int) throws {
        let samples: [HintSample] = try hintSamples()
        var timer = HintTimer()
        var planned: Int = 0
        var confirmed: Int = 0
        var unconfirmed: Int = 0
        for index in (group * 20)..<(group * 20 + 20) {
            let sample: HintSample = samples[index]
            let play: FacetedForgePlay = sample.play
            let label: String = "sample \(index) (level \(sample.number), \(play.cuts) cuts, \(play.stage))"
            let fingerprint: String = play.fingerprint
            let hint: FacetedForgeHint? = timer.hint(3, play)
            #expect(play.fingerprint == fingerprint && play == sample.play, "\(label): the hint changed the play")
            guard let hint else {
                Issue.record("\(label): no hint")
                continue
            }
            for level in 1...2 {
                let lower: FacetedForgeHint? = FacetedForgeHints.hint(level: level, play: play)
                #expect(lower?.kind == hint.kind && lower?.action == hint.action, "\(label): level \(level) differs")
            }
            let plan: FacetedForgePlan? = FacetedForgeHints.plan(play)
            if let plan {
                planned += 1
                #expect(hint.kind == .cut && hint.action == plan.actions.first, "\(label): hint is not the plan")
                #expect(plan.actions.count == play.level.target.count - play.pieces.count)
                #expect(plan.actions.count <= play.remaining, "\(label): plan longer than the cuts left")
                var copy: FacetedForgePlay = play
                if copy.stage == .paused { try copy.handle(.resume) }
                if let action = hint.action {
                    let error: FacetedForgeError? = FacetedForgeInvariantTests.refusal { () throws(FacetedForgeError) in
                        try copy.apply(action, expecting: copy.fingerprint)
                    }
                    #expect(error == nil, "\(label): hinted \(action) refused")
                }
                let result: (problems: [String], spent: Int) = followHints(play, label: label, timer: &timer)
                #expect(result.problems.isEmpty, "\(result.problems)")
                #expect(result.spent <= play.remaining, "\(label): \(result.spent) cuts")
            } else {
                #expect(hint.kind == .stuck && hint.text == FacetedForgeHint.stuckText, "\(label): not stuck")
                let need: Int = play.level.target.count - play.pieces.count
                if need < 1 || need > play.remaining {
                    confirmed += 1
                } else if need == 1 {
                    #expect(!winsInOne(play.pieces, level: play.level), "\(label): one cut wins without a plan")
                    confirmed += 1
                } else if need == 2 {
                    #expect(!winsInTwo(play.pieces, level: play.level), "\(label): two cuts win without a plan")
                    confirmed += 1
                } else {
                    unconfirmed += 1
                }
            }
        }
        print("states group \(group): \(planned) planned, \(confirmed) unplanned confirmed, "
              + "\(unconfirmed) unplanned beyond two cuts; \(timer.summary)")
    }

    /// The sample covers paused states, many levels and states on and off a certified winning path (the states with
    /// and without a plan are counted by each group of ``testSeededReachableStates(group:)``).
    @Test func testSeededSampleCoverage() throws {
        let catalog: [FacetedForgeGenerated] = try hintCatalog()
        let samples: [HintSample] = try hintSamples()
        var paused: Int = 0
        var levels: Set<Int> = []
        var opening: Int = 0
        for sample in samples {
            if sample.play.stage == .paused { paused += 1 }
            if sample.play.cuts == 0 { opening += 1 }
            levels.insert(sample.number)
            #expect(sample.play.cuts < catalog[sample.number - 1].solution.smallest + 4)
        }
        print("sample: \(samples.count) states, \(paused) paused, \(opening) at no cut, \(levels.count) levels")
        #expect(samples.count == 200)
        #expect(paused >= 20 && levels.count >= 50)
    }

    // MARK: Hint levels, stages and texts

    /// Clarification Q1: the three levels on level 1 read "Cut (piece)", "… in direction x" and "… at depth d"; the
    /// whole crystal is named as such, later pieces by number, share and faces.
    @Test func testHintTextsPerLevel() throws {
        let catalog: [FacetedForgeGenerated] = try hintCatalog()
        let level: FacetedForgeLevel = catalog[0].level
        var play: FacetedForgePlay = try FacetedForgeExperienceCore.freshPlay(of: level)
        guard case .cut(let p0, let d0, let z0) = catalog[0].solution.actions[0] else { return }
        let name0: String = FacetedForgeDirection.all[d0].name
        #expect(p0 == 0)
        #expect(FacetedForgeHints.hint(level: 1, play: play)?.text == "Cut the whole crystal")
        #expect(FacetedForgeHints.hint(level: 2, play: play)?.text == "Cut the whole crystal in direction " + name0)
        #expect(FacetedForgeHints.hint(level: 3, play: play)?.text
                == "Cut the whole crystal in direction " + name0 + " at depth " + String(z0))
        #expect(FacetedForgeHints.hint(level: 0, play: play)?.level == 1)
        #expect(FacetedForgeHints.hint(level: 9, play: play)?.level == 3)
        let first: FacetedForgeHint? = FacetedForgeHints.hint(level: 3, play: play)
        #expect(first?.kind == .cut && first?.piece == 0 && first?.direction == d0 && first?.depth == z0)
        try play.apply(catalog[0].solution.actions[0], expecting: play.fingerprint)
        guard play.stage == .playing, let second = FacetedForgeHints.hint(level: 3, play: play),
              let piece = second.piece, let direction = second.direction, let depth = second.depth else {
            Issue.record("level 1 has no second cut")
            return
        }
        let words: String = "piece " + String(piece + 1) + ": "
            + FacetedForgeLevel.shareText(play.shares[piece]) + " of the crystal, "
            + String(play.pieces[piece].faceCount) + " faces"
        let name: String = FacetedForgeDirection.all[direction].name
        #expect(FacetedForgeHints.hint(level: 1, play: play)?.text == "Cut " + words)
        #expect(FacetedForgeHints.hint(level: 2, play: play)?.text == "Cut " + words + " in direction " + name)
        #expect(second.text == "Cut " + words + " in direction " + name + " at depth " + String(depth))
        print("level 1 hints: \(first?.text ?? "-") / \(second.text)")
    }

    /// Loading, tutorial, won and result-after-win plays get no hint; failed and result-after-failure plays get the
    /// failed `stuck` hint; a state that cannot match the target gets the stuck text.
    @Test func testHintStages() throws {
        let catalog: [FacetedForgeGenerated] = try hintCatalog()
        let level: FacetedForgeLevel = catalog[0].level
        #expect(level.tutorial)
        var loading = FacetedForgePlay(level: level)
        #expect(FacetedForgeHints.hint(level: 1, play: loading) == nil && FacetedForgeHints.plan(loading) == nil)
        try loading.handle(.begin)
        #expect(loading.stage == .tutorial && FacetedForgeHints.hint(level: 1, play: loading) == nil)
        var won: FacetedForgePlay = try FacetedForgeExperienceCore.freshPlay(of: level)
        for action in catalog[0].solution.actions { try won.apply(action, expecting: won.fingerprint) }
        #expect(won.stage == .won && FacetedForgeHints.hint(level: 3, play: won) == nil)
        #expect(FacetedForgeFailureExplanation(play: won) == nil)
        try won.handle(.showResult)
        #expect(FacetedForgeHints.hint(level: 3, play: won) == nil && FacetedForgeFailureExplanation(play: won) == nil)
        let tracked: [TrackedFailure] = try Self.failures(count: 4, seed: 4_375)
        for failure in tracked {
            var play: FacetedForgePlay = failure.play
            for level in 1...3 {
                let hint: FacetedForgeHint? = FacetedForgeHints.hint(level: level, play: play)
                #expect(hint?.kind == .stuck && hint?.text == "Undo the last cut or retry the level.")
                #expect(hint?.action == nil && hint?.piece == nil)
            }
            try play.handle(.showResult)
            #expect(FacetedForgeHints.hint(level: 2, play: play)?.text == FacetedForgeHint.failedText)
            #expect(FacetedForgeFailureExplanation(play: play)?.failure == failure.play.failure)
        }
        // A play whose pieces can no longer be partitioned into the target is stuck at every level.
        var random = FacetedForgeRandom(seed: 5_375)
        var stuck: Int = 0
        for _ in 0..<40 {
            var play: FacetedForgePlay = try FacetedForgeExperienceCore.freshPlay(of: catalog[random.int(0...99)].level)
            let cut: (piece: Int, direction: Int, depth: Int) = random.pick(crossingCuts(play.pieces))
            guard (try? play.apply(.cut(cut.piece, cut.direction, cut.depth), expecting: play.fingerprint)) != nil,
                  play.stage == .playing,
                  !FacetedForgeSolver.canPartition(play.pieces, into: play.level.target,
                                                   crystal: play.level.crystal.volume) else { continue }
            stuck += 1
            for level in 1...3 {
                let text: String? = FacetedForgeHints.hint(level: level, play: play)?.text
                #expect(text == "No way to match the target was found in the cuts left: "
                        + "undo the last cut or retry the level.")
            }
            #expect(FacetedForgeFailureExplanation(play: play) == nil)
        }
        #expect(stuck >= 5, "\(stuck) stuck plays")
    }

    // MARK: Failure explanations

    /// `count` seeded failures (seed `seed`): from a certified opening, cuts chosen by this test until the play fails —
    /// in about half the plays a sliver cut is taken as soon as one exists, otherwise only cuts without a sliver, so the
    /// budget runs out. The cut number, the reason, the sliver piece (its index in this test's own canonical order) and
    /// share, and the pieces made are tracked here.
    private static func failures(count: Int, seed: UInt64) throws -> [TrackedFailure] {
        let catalog: [FacetedForgeGenerated] = try hintCatalog()
        var random = FacetedForgeRandom(seed: seed)
        var tracked: [TrackedFailure] = []
        while tracked.count < count {
            let number: Int = random.int(1...100)
            let level: FacetedForgeLevel = catalog[number - 1].level
            let volume: FacetedForgeFraction = level.crystal.volume
            let wantSliver: Bool = random.int(0...1) == 0
            var play: FacetedForgePlay = try FacetedForgeExperienceCore.freshPlay(of: level)
            var pieces: [FacetedForgePiece] = [level.crystal]
            var spent: Int = 0
            var result: TrackedFailure?
            var attempts: Int = 0
            while play.stage == .playing && attempts < 400 {
                attempts += 1
                var chosen: (piece: Int, direction: Int, depth: Int) = FacetedForgeFixtures.randomCut(pieces, &random)
                var sliverHalf: FacetedForgePiece?
                var sliverShare: FacetedForgeFraction?
                // Look at up to 24 random cuts for the wanted kind (a sliver, or none).
                for _ in 0..<24 {
                    let candidate: (piece: Int, direction: Int, depth: Int) =
                        FacetedForgeFixtures.randomCut(pieces, &random)
                    guard let halves = try? pieces[candidate.piece].cut(direction: candidate.direction,
                                                                         depth: candidate.depth),
                          let below = try? halves.below.volume.dividing(by: volume),
                          let above = try? halves.above.volume.dividing(by: volume) else { continue }
                    let thin: Bool = below < level.sliver || above < level.sliver
                    if thin == wantSliver {
                        chosen = candidate
                        break
                    }
                }
                guard let halves = try? pieces[chosen.piece].cut(direction: chosen.direction, depth: chosen.depth),
                      let below = try? halves.below.volume.dividing(by: volume),
                      let above = try? halves.above.volume.dividing(by: volume) else { continue }
                if below < level.sliver {
                    sliverHalf = halves.below
                    sliverShare = below
                } else if above < level.sliver {
                    sliverHalf = halves.above
                    sliverShare = above
                }
                let previous: FacetedForgePlay = play
                do {
                    try play.apply(.cut(chosen.piece, chosen.direction, chosen.depth), expecting: play.fingerprint)
                } catch {
                    play = previous
                    continue
                }
                var rest: [FacetedForgePiece] = pieces
                rest.remove(at: chosen.piece)
                pieces = FacetedForgePiece.canonical(rest + [halves.below, halves.above])
                spent += 1
                if let sliverHalf, let sliverShare {
                    let index: Int? = pieces.firstIndex(of: sliverHalf)
                    result = TrackedFailure(number: number, play: play, reason: "sliver", cut: spent, piece: index,
                                            share: sliverShare, pieces: pieces.count)
                } else if spent == level.budget {
                    result = TrackedFailure(number: number, play: play, reason: "budget", cut: spent, piece: nil,
                                            share: nil, pieces: pieces.count)
                }
            }
            if let result, result.play.stage == .failed { tracked.append(result) }
        }
        return tracked
    }

    /// SC-R02G0805-003: 500 seeded failures (seed 3_375; group g of 10 draws 50 with seed 3_375 × 100 + g) explained
    /// with the true reason, cut, piece and share, or cuts spent, pieces and target, in the texts of clarification
    /// Q5; the explanation never changes the play.
    @Test(arguments: 0..<10) func testSeededFailuresExplained(group: Int) throws {
        let tracked: [TrackedFailure] = try Self.failures(count: 50, seed: 3_375 * 100 + UInt64(group))
        var slivers: Int = 0
        var budgets: Int = 0
        for (index, failure) in tracked.enumerated() {
            let play: FacetedForgePlay = failure.play
            let label: String = "failure \(index) (level \(failure.number), \(failure.reason))"
            let fingerprint: String = play.fingerprint
            guard let explanation = FacetedForgeFailureExplanation(play: play) else {
                Issue.record("\(label): no explanation")
                continue
            }
            #expect(play.fingerprint == fingerprint, "\(label): the explanation changed the play")
            #expect(explanation.failure.code == failure.reason, "\(label): \(explanation.failure.code)")
            #expect(explanation.cut == failure.cut && explanation.pieces == failure.pieces, "\(label)")
            #expect(explanation.target == play.level.target.count, "\(label)")
            let advice: String = " Undo the last cut or retry the level."
            if failure.reason == "sliver" {
                slivers += 1
                guard let piece = failure.piece, let share = failure.share else {
                    Issue.record("\(label): untracked sliver")
                    continue
                }
                #expect(explanation.piece == piece && explanation.share == share, "\(label)")
                let expected: String = "Cut " + String(failure.cut) + " left piece " + String(piece + 1) + " at "
                    + FacetedForgeLevel.shareText(share) + " of the crystal, thinner than the sliver limit of "
                    + play.level.sliver.text + "." + advice
                #expect(explanation.text == expected, "\(label): \(explanation.text)")
            } else {
                budgets += 1
                #expect(explanation.piece == nil && explanation.share == nil, "\(label)")
                let budget: String = String(play.level.budget)
                let expected: String = "The cuts ran out: " + budget + " of " + budget + " spent with "
                    + String(failure.pieces) + " pieces; the target has " + String(play.level.target.count) + "."
                    + advice
                #expect(explanation.text == expected, "\(label): \(explanation.text)")
            }
        }
        print("failures group \(group): \(tracked.count) explained, \(slivers) slivers, \(budgets) budgets; e.g. "
              + (tracked.first.flatMap { FacetedForgeFailureExplanation(play: $0.play)?.text } ?? "-"))
        #expect(tracked.count == 50 && slivers >= 10 && budgets >= 10, "\(slivers) slivers, \(budgets) budgets")
    }
}
