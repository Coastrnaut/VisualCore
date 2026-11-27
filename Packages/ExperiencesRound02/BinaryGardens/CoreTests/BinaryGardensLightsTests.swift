// BinaryGardensLightsTests — feature 506 (R02-G21-06) T-R02G2106-004 (FR-R02G2106-004; SC-R02G2106-003;
// clarification Q3; research R2, R3). The eased lights over real adapter cores (`BinaryGardensExperienceCore.opening`,
// `apply`, `snapshot(time: 0)`) of the certified level the feature seed 2_506 chooses (`levelNumber(forSeed:)`, level
// 7) and the level after it (8, `level.next`): the targets (glow 0.7 playing / 1 won / 0.35 failed, the result after a
// win staying won and after a failure staying failed, the predicted failure while playing never dimming the glow; won 1
// once won, else 0; each world's bloom 1 when comfortable at the drawn shown tick or won, else 0, an accepted preview
// drawn); settle jumps and the first step settles; normally a fade takes 0.15 s (9 frames at 60 Hz) and turns at once;
// under Reduce Flashing it takes 0.45 s and a started fade finishes before it turns back; bad elapsed times do nothing;
// the presentation time never changes the lights, only the elapsed frame time does; another world count carries the
// blooms by index and starts new worlds at 0. A scripted win (the certified plan, its first action undone and redone,
// the run and the next level) and adversarial flicker — a ring change undone and redone every frame, a failed run undone
// and redone every frame, the shown tick stepped back and forth every frame, level changes every frame, a failure and a
// level change, a win and its retry, a win and the next level — each with retries every 17, 45 or 300 frames, sampled
// every 1/60 s for 5 s under Reduce Flashing with every element over its own range 0 … 1: no element crosses half its
// range more than 3 times per second and every complete one-way fade of more than half the range takes at least 0.4 s.
// The measure itself catches a nine-frame flicker without Reduce Flashing. No randomness, no clocks; explicit types,
// plain loops, short runs. Modelled on MushroomWeatherLightsTests (feature 496).
import Foundation
import Testing
import VisualCoreExperience
@testable import BinaryGardensCore

@Suite struct BinaryGardensLightsTests {
    typealias Lights = BinaryGardensLights
    typealias Core = BinaryGardensExperienceCore
    typealias Snapshot = BinaryGardensSceneSnapshot
    typealias G = BinaryGardensSceneGeometry
    /// The sampling rate, in frames per second.
    static let frameRate: Double = 60
    /// One frame, in seconds.
    static let frame: Double = 1 / 60
    /// The feature's fixture seed.
    static let seed: UInt64 = 2_506
    /// The primary level: the one the feature seed opens (7).
    static let primaryNumber: Int = Core.levelNumber(forSeed: seed)

    /// An adapter action of `control` with `values`.
    static func act(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The adapter action of a kernel action.
    static func act(_ action: BinaryGardensAction) -> ExperienceAction {
        switch action {
        case let .ring(star, index): act("star.ring", [Double(star), Double(index)])
        case let .phase(star, step): act("star.phase", [Double(star), Double(step)])
        case let .luminosity(star, index): act("star.luminosity", [Double(star), Double(index)])
        case let .tilt(step): act("orbit.tilt", [Double(step)])
        case .run: act("light.run")
        }
    }

    /// One frame of a script: an adapter action, a retry (back to the script's start core), or nothing.
    enum Step {
        /// An adapter action.
        case action(ExperienceAction)
        /// Back to the start core of the script.
        case retry
        /// Nothing.
        case idle
    }

    /// An undo.
    static let undo: Step = .action(act("play.undo"))
    /// A redo.
    static let redo: Step = .action(act("play.redo"))
    /// The run (from the opening it fails: a certified level's start never wins).
    static let run: Step = .action(act("light.run"))
    /// A change to the next level: accepted after a win (the win opens it); since feature 505 refused `r02-g21.locked`
    /// before one, as the next level is not open yet.
    static let next: Step = .action(act("level.next"))
    /// A change to the level before the primary one (always accepted: an opening opens levels 1 … its own, feature
    /// 505's `level.select`).
    static let previous: Step = .action(act("level.select", [Double(primaryNumber - 1)]))

    /// The opening core of the primary level (stage `playing`, tick 48 shown).
    static func start() throws -> Core { try Core.opening(number: primaryNumber) }

    /// The certified actions of the primary level (the run not included).
    static func planActions() throws -> [BinaryGardensAction] {
        try Core.generated(number: primaryNumber).plan.actions
    }

    /// The certified winning actions followed by the run, as adapter steps.
    static func winning() throws -> [Step] {
        var steps: [Step] = []
        for action in try planActions() where action != .run { steps.append(.action(act(action))) }
        steps.append(run)
        return steps
    }

    /// The bloom targets of `snapshot`, decided here independently: 1 for every world when won, else 1 for a world
    /// whose band at the shown tick of the drawn snapshot is comfortable.
    static func bloomTargets(_ snapshot: Snapshot) -> [Double] {
        let won: Bool = snapshot.stage == .won || (snapshot.stage == .result && snapshot.failure == nil)
        let drawn: Snapshot = G.drawnSnapshot(snapshot)
        var result: [Double] = []
        for world in drawn.worlds.indices {
            let index: Int = (drawn.shownTick - 1) % Snapshot.cycle
            result.append(won || drawn.worlds[world].bands[index] == .comfortable ? 1 : 0)
        }
        return result
    }

    /// The ring change of the opening that flips the most bloom targets, with the shown tick it is seen at: the
    /// opening with that tick shown (ticks tried 48, 1 … 47, the first with the most flips kept) and the change.
    static func ringChange(_ opening: Core) -> (start: Core, step: Step, flips: Int) {
        let level: BinaryGardensLevel = opening.play.level
        let puzzle: BinaryGardensPuzzle = BinaryGardensPuzzle(level: level)
        let position: BinaryGardensPuzzle.Position = BinaryGardensPuzzle.Position(
            arrangement: opening.play.arrangement, actionsSpent: opening.play.actionsSpent)
        var best: (start: Core, step: Step, flips: Int) = (opening, .idle, 0)
        var rings: [(BinaryGardensAction, Core)] = []
        for move in puzzle.moves(in: position) {
            guard case .ring = move else { continue }
            var core: Core = opening
            if core.apply(act(move)) == .accepted { rings.append((move, core)) }
        }
        if let first = rings.first { best = (opening, .action(act(first.0)), 0) }
        for tick in [48] + Array(1...47) {
            var shown: Core = opening
            guard shown.apply(act("clock.show", [Double(tick)])) == .accepted else { continue }
            let before: [Double] = bloomTargets(snap(shown))
            for (move, changed) in rings {
                var seen: Core = changed
                _ = seen.apply(act("clock.show", [Double(tick)]))
                let after: [Double] = bloomTargets(snap(seen))
                var flips: Int = 0
                for world in before.indices where world < after.count && before[world] != after[world] { flips += 1 }
                if flips > best.flips { best = (shown, .action(act(move)), flips) }
            }
        }
        return best
    }

    /// A shown tick t of the opening at which some world's bloom target differs from tick t + 1 (cyclic), with the
    /// steps showing t and t + 1; nil when every world's band keeps its comfort all cycle.
    static func tickFlip(_ opening: Core) -> (Step, Step)? {
        let snapshot: Snapshot = snap(opening)
        for tick in 1...Snapshot.cycle {
            let following: Int = tick % Snapshot.cycle + 1
            for world in snapshot.worlds {
                let a: Bool = world.bands[tick - 1] == .comfortable
                let b: Bool = world.bands[following - 1] == .comfortable
                if a != b {
                    return (.action(act("clock.show", [Double(tick)])),
                            .action(act("clock.show", [Double(following)])))
                }
            }
        }
        return nil
    }

    /// The snapshot of `core` at presentation time 0.
    static func snap(_ core: Core) -> Snapshot { core.snapshot(time: 0) }

    /// One sample of every light, each over its own range 0 … 1: the glow (a gain, 0 dark … 1), the won look and
    /// every world's bloom.
    static func sample(_ lights: Lights) -> [Double] { [lights.glow, lights.won] + lights.bloom }

    /// Checks the two flash limits on `samples` under Reduce Flashing.
    static func expectWithinLimits(_ samples: [[Double]], _ label: String) {
        let crossings: Double = Lights.maxHalfRangeCrossingsPerSecond(samples, frameRate: frameRate)
        #expect(crossings <= 3, "\(label): \(crossings) crossings per second")
        let shortest: Double = Lights.shortestHalfRangeChange(samples, frameRate: frameRate)
        #expect(shortest >= 0.4, "\(label): a half-range fade took \(shortest) s")
    }

    /// Checks that `lights` rest exactly at the targets of `snapshot`, decided here independently.
    static func expectAtTargets(_ lights: Lights, _ snapshot: Snapshot) {
        #expect(lights.isSettled)
        let won: Bool = snapshot.stage == .won || (snapshot.stage == .result && snapshot.failure == nil)
        let failed: Bool = snapshot.stage == .failed || (snapshot.stage == .result && snapshot.failure != nil)
        let glow: Double = won ? 1 : (failed ? 0.35 : 0.7)
        #expect(lights.glow == glow)
        #expect(lights.won == (won ? 1 : 0))
        #expect(lights.bloom == bloomTargets(snapshot))
    }

    /// The opening, won and failed snapshots of the primary level.
    static func stages() throws -> (start: Snapshot, won: Snapshot, failed: Snapshot) {
        let opening: Core = try start()
        var winner: Core = opening
        for step in try winning() {
            guard case .action(let action) = step else { continue }
            #expect(winner.apply(action) == .accepted)
        }
        var loser: Core = opening
        #expect(loser.apply(act(.run)) == .accepted)
        let result: (Snapshot, Snapshot, Snapshot) = (snap(opening), snap(winner), snap(loser))
        #expect(result.0.stage == .playing && result.1.stage == .won && result.2.stage == .failed)
        // The opening already carries the predicted failure, yet it glows as playing.
        #expect(result.0.failure != nil && result.2.failure != nil)
        return result
    }

    /// `snapshot` with its first `count` worlds (the last repeated when `count` exceeds them), as another level with
    /// another world count would show (unchecked initialiser; presentation only).
    static func withWorlds(_ snapshot: Snapshot, count: Int) -> Snapshot {
        var worlds: [BinaryGardensSceneWorld] = []
        for index in 0..<count { worlds.append(snapshot.worlds[min(index, snapshot.worlds.count - 1)]) }
        return Snapshot(ringRadii: snapshot.ringRadii, luminosityLevels: snapshot.luminosityLevels,
                        maxTilt: snapshot.maxTilt, phaseStep: snapshot.phaseStep,
                        lethalTolerance: snapshot.lethalTolerance, worlds: worlds,
                        arrangement: snapshot.arrangement, starPositions: snapshot.starPositions,
                        shownTick: snapshot.shownTick, failure: snapshot.failure, stage: snapshot.stage,
                        actionsLeft: snapshot.actionsLeft, budget: snapshot.budget,
                        levelNumber: snapshot.levelNumber, time: 0)
    }

    @Test func settleJumpsToTheTargetsOfEveryStage() throws {
        #expect(Self.primaryNumber == 7)
        let (start, won, failed): (Snapshot, Snapshot, Snapshot) = try Self.stages()
        var lights: Lights = Lights(reducedFlash: true)
        #expect(lights.glow == 0 && lights.won == 0 && lights.bloom.isEmpty)
        #expect(Lights.normalDuration == 0.15 && Lights.reducedFlashDuration == 0.45)
        lights.settle(to: won)
        Self.expectAtTargets(lights, won)
        #expect(lights.glow == 1 && lights.won == 1)
        #expect(lights.bloom == Array(repeating: 1.0, count: won.worlds.count))
        lights.settle(to: failed)
        Self.expectAtTargets(lights, failed)
        #expect(lights.glow == 0.35 && lights.won == 0)
        lights.settle(to: start)
        Self.expectAtTargets(lights, start)
        #expect(lights.glow == 0.7 && lights.won == 0)
        // The first step also settles.
        var first: Lights = Lights(reducedFlash: false)
        first.step(toward: won, elapsed: Self.frame)
        Self.expectAtTargets(first, won)
        // The result after a win stays won; after a failure it stays failed.
        let level: BinaryGardensLevel = try Core.level(number: Self.primaryNumber)
        var losing: BinaryGardensPlay = try Core.freshPlay(of: level)
        try losing.apply(.run, expecting: losing.fingerprint)
        try losing.handle(.showResult)
        let failedResult: Snapshot = Snapshot(play: losing, shownTick: 48, levelNumber: Self.primaryNumber, time: 0)
        #expect(failedResult.stage == .result && Lights.isFailed(failedResult) && !Lights.isWon(failedResult))
        lights.settle(to: failedResult)
        #expect(lights.glow == 0.35 && lights.won == 0)
        var winning: BinaryGardensPlay = try Core.freshPlay(of: level)
        for action in try Self.planActions() where action != .run {
            try winning.apply(action, expecting: winning.fingerprint)
        }
        try winning.apply(.run, expecting: winning.fingerprint)
        try winning.handle(.showResult)
        let wonResult: Snapshot = Snapshot(play: winning, shownTick: 48, levelNumber: Self.primaryNumber, time: 0)
        #expect(wonResult.stage == .result && Lights.isWon(wonResult) && !Lights.isFailed(wonResult))
        lights.settle(to: wonResult)
        #expect(lights.glow == 1 && lights.won == 1)
        // Every action of the plan keeps the playing glow, whatever the predicted report says.
        var changing: BinaryGardensPlay = try Core.freshPlay(of: level)
        for action in try Self.planActions() where action != .run {
            try changing.apply(action, expecting: changing.fingerprint)
            lights.settle(to: Snapshot(play: changing, shownTick: 48, levelNumber: Self.primaryNumber, time: 0))
            #expect(changing.stage == .playing && lights.glow == 0.7 && lights.won == 0)
        }
    }

    @Test func bloomsFollowTheShownTickAndTheDrawnPreview() throws {
        let opening: Core = try Self.start()
        let level: BinaryGardensLevel = opening.play.level
        // Every shown tick: the blooms are the comfort of each world's band at that tick.
        var shown: Core = opening
        var differs: Bool = false
        let reference: [Double] = Self.bloomTargets(Self.snap(opening))
        for tick in 1...Snapshot.cycle {
            #expect(shown.apply(Self.act("clock.show", [Double(tick)])) == .accepted)
            var lights: Lights = Lights(reducedFlash: false)
            lights.settle(to: Self.snap(shown))
            var expected: [Double] = []
            for world in shown.play.report.worlds {
                expected.append(world.bands[tick - 1] == .comfortable ? 1 : 0)
            }
            #expect(lights.bloom == expected, "tick \(tick)")
            if lights.bloom != reference { differs = true }
            // The glow and the won look never follow the shown tick.
            #expect(lights.glow == 0.7 && lights.won == 0)
        }
        #expect(differs, "some shown tick changes a bloom")
        // An accepted preview is drawn: the blooms follow the previewed report, the snapshot or its drawn copy alike.
        let puzzle: BinaryGardensPuzzle = BinaryGardensPuzzle(level: level)
        let moves: [BinaryGardensAction] = puzzle.moves(in: puzzle.initialState)
        var previewedOne: Bool = false
        for move in moves {
            let previewed: Snapshot = Self.snap(opening).previewing(move, level: level)
            guard let report = previewed.preview?.report else { continue }
            var lights: Lights = Lights(reducedFlash: true)
            lights.settle(to: previewed)
            var expected: [Double] = []
            for world in report.worlds { expected.append(world.bands[47] == .comfortable ? 1 : 0) }
            #expect(lights.bloom == expected)
            var drawn: Lights = Lights(reducedFlash: true)
            drawn.settle(to: G.drawnSnapshot(previewed))
            #expect(drawn == lights)
            if expected != reference { previewedOne = true }
        }
        #expect(previewedOne, "some preview changes a bloom")
    }

    @Test func onlyTheElapsedFrameTimeMovesTheLightsNotThePresentationTime() throws {
        let (start, won, _): (Snapshot, Snapshot, Snapshot) = try Self.stages()
        let opening: Core = try Self.start()
        var winner: Core = opening
        for step in try Self.winning() {
            guard case .action(let action) = step else { continue }
            #expect(winner.apply(action) == .accepted)
        }
        for reduced in [false, true] {
            var still: Lights = Lights(reducedFlash: reduced)
            var moving: Lights = Lights(reducedFlash: reduced)
            still.settle(to: start)
            moving.settle(to: opening.snapshot(time: 3.25))
            #expect(still == moving)
            for index in 0..<40 {
                still.step(toward: won, elapsed: Self.frame)
                moving.step(toward: winner.snapshot(time: 3.25 + Double(index) * 0.7), elapsed: Self.frame)
                #expect(still == moving, "frame \(index), reduced flash \(reduced)")
            }
            Self.expectAtTargets(still, won)
            var frozen: Lights = Lights(reducedFlash: reduced)
            frozen.settle(to: start)
            for index in 0..<10 { frozen.step(toward: winner.snapshot(time: Double(index) * 10), elapsed: 0) }
            #expect(frozen.glow == 0.7 && frozen.won == 0 && frozen.bloom == Self.bloomTargets(start))
            #expect(!frozen.isSettled)
        }
    }

    @Test func badElapsedTimesDoNothing() throws {
        let (start, won, _): (Snapshot, Snapshot, Snapshot) = try Self.stages()
        var lights: Lights = Lights(reducedFlash: true)
        lights.settle(to: start)
        let bad: [Double] = [-1, -.infinity, .infinity, .nan, 0]
        for elapsed in bad {
            lights.step(toward: won, elapsed: elapsed)
            #expect(lights.glow == 0.7 && lights.won == 0, "\(elapsed)")
        }
        #expect(!lights.isSettled)
        lights.step(toward: won, elapsed: Self.frame)
        #expect(lights.glow > 0.7 && lights.won > 0)
    }

    @Test func normalFadesTakeTheNormalDurationAndTurnAtOnce() throws {
        let (start, won, failed): (Snapshot, Snapshot, Snapshot) = try Self.stages()
        let frames: Int = Int((Lights.normalDuration * Self.frameRate).rounded())
        #expect(frames == 9)
        let froms: [Snapshot] = [start, won, start, failed, won, failed]
        let tos: [Snapshot] = [won, start, failed, start, failed, won]
        for index in froms.indices {
            var lights: Lights = Lights(reducedFlash: false)
            lights.settle(to: froms[index])
            for _ in 0..<(frames - 1) { lights.step(toward: tos[index], elapsed: Self.frame) }
            #expect(!lights.isSettled, "pair \(index)")
            lights.step(toward: tos[index], elapsed: Self.frame)
            Self.expectAtTargets(lights, tos[index])
        }
        // Normally a changed target turns a fade at once: partway into failing, the undo heads back.
        var turning: Lights = Lights(reducedFlash: false)
        turning.settle(to: start)
        for _ in 0..<4 { turning.step(toward: failed, elapsed: Self.frame) }
        let mid: Double = turning.glow
        #expect(mid < 0.7 && mid > 0.35)
        turning.step(toward: start, elapsed: Self.frame)
        #expect(turning.glow > mid)
        // Under Reduce Flashing the same change takes 0.45 s (27 frames) and a started fade finishes first.
        #expect(Int((Lights.reducedFlashDuration * Self.frameRate).rounded()) == 27)
        var slow: Lights = Lights(reducedFlash: true)
        slow.settle(to: start)
        for _ in 0..<26 { slow.step(toward: won, elapsed: Self.frame) }
        #expect(!slow.isSettled && slow.won > 0.9 && slow.won < 1)
        slow.step(toward: won, elapsed: Self.frame)
        Self.expectAtTargets(slow, won)
        var firm: Lights = Lights(reducedFlash: true)
        firm.settle(to: start)
        for _ in 0..<4 { firm.step(toward: won, elapsed: Self.frame) }
        let started: Double = firm.won
        firm.step(toward: start, elapsed: Self.frame)
        #expect(firm.won > started)
        for _ in 0..<22 { firm.step(toward: start, elapsed: Self.frame) }
        #expect(firm.won == 1 && firm.glow == 1 && !firm.isSettled)
        for _ in 0..<27 { firm.step(toward: start, elapsed: Self.frame) }
        Self.expectAtTargets(firm, start)
    }

    @Test func anotherWorldCountCarriesBloomsByIndexAndStartsNewWorldsAtZero() throws {
        let (_, won, _): (Snapshot, Snapshot, Snapshot) = try Self.stages()
        let five: Snapshot = Self.withWorlds(won, count: 5)
        let one: Snapshot = Self.withWorlds(won, count: 1)
        for reduced in [false, true] {
            let frames: Int = reduced ? 27 : 9
            var lights: Lights = Lights(reducedFlash: reduced)
            lights.settle(to: one)
            #expect(lights.bloom == [1])
            // Four new worlds start at 0 and fade in; world 0 keeps its level.
            lights.step(toward: five, elapsed: Self.frame)
            #expect(lights.bloom.count == 5 && lights.bloom[0] == 1)
            for world in 1..<5 {
                #expect(abs(lights.bloom[world] - 1 / Double(frames)) < 1e-9, "world \(world)")
            }
            for _ in 0..<(frames - 1) { lights.step(toward: five, elapsed: Self.frame) }
            Self.expectAtTargets(lights, five)
            // Dropping worlds keeps the first by index.
            lights.step(toward: one, elapsed: Self.frame)
            #expect(lights.bloom == [1] && lights.isSettled)
        }
        // A world mid-fade keeps its fade across a level with more worlds.
        let (start, _, _): (Snapshot, Snapshot, Snapshot) = try Self.stages()
        let targets: [Double] = Self.bloomTargets(start)
        if let dark = targets.firstIndex(of: 0) {
            var lights: Lights = Lights(reducedFlash: true)
            lights.settle(to: start)
            for _ in 0..<3 { lights.step(toward: won, elapsed: Self.frame) }
            let level: Double = lights.bloom[dark]
            #expect(abs(level - 3.0 / 27) < 1e-9)
            lights.step(toward: Self.withWorlds(won, count: start.worlds.count + 1), elapsed: Self.frame)
            #expect(abs(lights.bloom[dark] - 4.0 / 27) < 1e-9)
        }
    }

    /// Applies `step` to `core` (a retry restores `start`); true when accepted.
    static func perform(_ step: Step, _ core: inout Core, start: Core) -> Bool {
        switch step {
        case .action(let action):
            return core.apply(action) == .accepted
        case .retry:
            core = start
            return true
        case .idle:
            return false
        }
    }

    /// Runs `frames` frames of `steps` (one per frame, refusals allowed) from `start` under `reducedFlash`, retrying
    /// every `retryEvery` frames; returns the samples and the number of accepted steps. `cache` keeps each distinct
    /// state's snapshot (equal states give equal snapshots; a speed-up only).
    static func flicker(_ steps: [Step], start: Core, frames: Int, retryEvery: Int, reducedFlash: Bool = true,
                        cache: inout [String: Snapshot]) -> ([[Double]], Int) {
        var core: Core = start
        var lights: Lights = Lights(reducedFlash: reducedFlash)
        lights.settle(to: snap(core))
        var samples: [[Double]] = [sample(lights)]
        var accepted: Int = 0
        for index in 0..<frames {
            let step: Step = index > 0 && index % retryEvery == 0 ? .retry : steps[index % steps.count]
            if perform(step, &core, start: start) { accepted += 1 }
            let key: String = "\(core.levelNumber) \(core.shownTick) \(core.play.fingerprint)"
            let snapshot: Snapshot = cache[key] ?? snap(core)
            cache[key] = snapshot
            lights.step(toward: snapshot, elapsed: frame)
            samples.append(sample(lights))
        }
        return (samples, accepted)
    }

    @Test func aScriptedWinStaysWithinTheLimits() throws {
        var core: Core = try Self.start()
        var lights: Lights = Lights(reducedFlash: true)
        lights.settle(to: Self.snap(core))
        var samples: [[Double]] = [Self.sample(lights)]
        let wins: [Step] = try Self.winning()
        var script: [Step] = [wins[0], Self.undo, Self.redo]
        for index in 1..<wins.count { script.append(wins[index]) }
        let opening: Core = core
        for step in script {
            #expect(Self.perform(step, &core, start: opening))
            lights.step(toward: Self.snap(core), elapsed: Self.frame)
            samples.append(Self.sample(lights))
        }
        #expect(core.play.stage == .won)
        let wonSnapshot: Snapshot = Self.snap(core)
        for _ in 0..<60 {
            lights.step(toward: wonSnapshot, elapsed: Self.frame)
            samples.append(Self.sample(lights))
        }
        Self.expectAtTargets(lights, wonSnapshot)
        #expect(lights.glow == 1 && lights.won == 1)
        #expect(core.apply(Self.act("level.next")) == .accepted)
        #expect(core.levelNumber == Self.primaryNumber + 1 && core.play.stage == .playing)
        let nextSnapshot: Snapshot = Self.snap(core)
        for _ in 0..<60 {
            lights.step(toward: nextSnapshot, elapsed: Self.frame)
            samples.append(Self.sample(lights))
        }
        Self.expectAtTargets(lights, nextSnapshot)
        #expect(lights.glow == 0.7 && lights.won == 0)
        Self.expectWithinLimits(samples, "scripted win")
    }

    /// The flicker patterns, each with its steps and the fewest accepted steps it must make in 300 frames (the bounds
    /// leave room below what the patterns reach, so they only show that the patterns keep changing the state).
    static func patterns(_ opening: Core) throws -> [(name: String, start: Core, steps: [Step], least: Int)] {
        let (ringStart, ring, flips): (Core, Step, Int) = ringChange(opening)
        #expect(flips > 0, "a ring change flips a bloom")
        let wins: [Step] = try winning()
        var ringRedone: [Step] = [ring]
        for _ in 0..<5 { ringRedone += [undo, redo] }
        ringRedone.append(undo)
        var runRedone: [Step] = [run]
        for _ in 0..<5 { runRedone += [undo, redo] }
        runRedone.append(undo)
        var result: [(name: String, start: Core, steps: [Step], least: Int)] = [
            ("ring change undone and redone", ringStart, ringRedone, 150),
            ("failed run undone and redone", opening, runRedone, 150),
            ("change level every frame", opening, [previous, Step.retry], 200),
            ("failure and change level", opening, [run, previous, Step.retry], 200),
            ("win and retry", opening, wins + [Step.retry], 150),
            ("win and next level", opening, wins + [next, Step.retry], 150),
        ]
        if let (a, b) = tickFlip(opening) {
            result.append(("shown tick back and forth", opening, [a, b], 250))
        } else {
            Issue.record("no shown tick flips a bloom on level \(primaryNumber)")
        }
        return result
    }

    @Test func adversarialFlickerWithRetriesStaysWithinTheLimits() throws {
        let opening: Core = try Self.start()
        var cache: [String: Snapshot] = [:]
        let patterns: [(name: String, start: Core, steps: [Step], least: Int)] = try Self.patterns(opening)
        #expect(patterns.count == 7)
        for retry in [17, 45, 300] {
            for pattern in patterns {
                let (samples, accepted): ([[Double]], Int) = Self.flicker(pattern.steps, start: pattern.start,
                                                                          frames: 300,
                                                                          retryEvery: retry, cache: &cache)
                let name: String = "\(pattern.name), retry \(retry)"
                #expect(accepted >= pattern.least, "\(name): \(accepted) accepted")
                #expect(samples.count == 301)
                Self.expectWithinLimits(samples, name)
            }
        }
    }

    @Test func theMeasureDetectsFastBlinking() throws {
        var samples: [[Double]] = []
        for index in 0..<120 { samples.append([index % 2 == 0 ? 0 : 1, 0.3]) }
        #expect(Lights.maxHalfRangeCrossingsPerSecond(samples, frameRate: 60) == 60)
        #expect(Lights.shortestHalfRangeChange(samples, frameRate: 60) == 1.0 / 60)
        #expect(Lights.maxHalfRangeCrossingsPerSecond([[0.2]], frameRate: 60) == 0)
        var near: [[Double]] = []
        for index in 0..<60 { near.append([index % 2 == 0 ? 0.49 : 0.51]) }
        #expect(Lights.maxHalfRangeCrossingsPerSecond(near, frameRate: 60) == 59)
        #expect(Lights.shortestHalfRangeChange(near, frameRate: 60) == .infinity)
        // Without Reduce Flashing a failed run undone every 9 frames would blink; the slower fade holds the limit.
        var steps: [Step] = [Self.run]
        for _ in 0..<8 { steps.append(.idle) }
        steps.append(Self.undo)
        for _ in 0..<8 { steps.append(.idle) }
        let opening: Core = try Self.start()
        var cache: [String: Snapshot] = [:]
        let (fast, _): ([[Double]], Int) = Self.flicker(steps, start: opening, frames: 243, retryEvery: 1_000,
                                                         reducedFlash: false, cache: &cache)
        let (slow, _): ([[Double]], Int) = Self.flicker(steps, start: opening, frames: 240, retryEvery: 1_000,
                                                         cache: &cache)
        #expect(Lights.maxHalfRangeCrossingsPerSecond(fast, frameRate: 60) > 3)
        Self.expectWithinLimits(slow, "nine-frame failure flicker")
        let last: [Double] = fast[fast.count - 1]
        #expect(last[0] == 0.35 && last[1] == 0)
        // The same for the shown tick stepped every 9 frames: the blooms blink normally, not under Reduce Flashing.
        if let (a, b) = Self.tickFlip(opening) {
            var ticks: [Step] = [a]
            for _ in 0..<8 { ticks.append(.idle) }
            ticks.append(b)
            for _ in 0..<8 { ticks.append(.idle) }
            let (blink, _): ([[Double]], Int) = Self.flicker(ticks, start: opening, frames: 240, retryEvery: 1_000,
                                                              reducedFlash: false, cache: &cache)
            let (calm, _): ([[Double]], Int) = Self.flicker(ticks, start: opening, frames: 240, retryEvery: 1_000,
                                                             cache: &cache)
            #expect(Lights.maxHalfRangeCrossingsPerSecond(blink, frameRate: 60) > 3)
            Self.expectWithinLimits(calm, "nine-frame tick flicker")
        }
    }
}
