// WaveKnotKeeperLightsTests — feature 326 (R02-G03-06) T-R02G0306-003 (FR-R02G0306-004; clarification Q3; research R3,
// R4; SC-R02G0306-003). The eased lights: the targets (present marks 1, match 1 while the summary equals the target, glow
// 1 when won); a scripted win of certified level 1 (its solution applied one move per 0.2 s) sampled every 1/60 s under
// Reduce Flashing crosses half the range at most 3 times per second per element and every complete one-way fade of more
// than half the range takes at least 0.4 s; adversarial flicker (a move and its undo every frame for 3 s on the level of
// seed 2_326, and the start and won ropes toggled every 1, 2 and 5 frames and at random) stays within both limits under
// Reduce Flashing; normally a target is reached within 0.15 s and one frame; settle jumps; a new level settles; a
// vanished mark keeps its over segment and fraction while it fades out and is then dropped; negative and non-finite
// elapsed times do nothing; the measure detects fast blinking. Explicit types, plain loops, short runs.
import Testing
@testable import WaveKnotKeeperCore
import VisualCoreExperience

@Suite struct WaveKnotKeeperLightsTests {
    typealias Core = WaveKnotKeeperExperienceCore
    typealias Lights = WaveKnotKeeperLights
    static let frameRate: Double = 60
    static let frame: Double = 1 / 60
    /// The seed of the adversarial flicker (level 2_326 % 100 + 1 = 27) and its pseudo-random pattern.
    static let seed: UInt64 = 2_326

    /// The `point.move` action for a kernel move.
    static func action(_ move: WaveKnotKeeperMove) -> ExperienceAction {
        let index: Int = Core.directionOrder.firstIndex(of: move.direction) ?? 0
        return ExperienceAction(control: "point.move", values: [Double(move.point), Double(index)], step: 0)
    }

    static let undo: ExperienceAction = ExperienceAction(control: "play.undo", values: [], step: 0)

    /// The mark keys of `snapshot`.
    static func keys(_ snapshot: WaveKnotKeeperSceneSnapshot) -> Set<Lights.Key> {
        Set(snapshot.crossings.map { Lights.Key(first: $0.first, second: $0.second) })
    }

    /// One vector per recorded frame: the level of each key in `keys` order (0 while absent), then match and glow.
    static func samples(_ frames: [Lights]) -> [[Double]] {
        var all: Set<Lights.Key> = []
        for lights in frames { all.formUnion(lights.crossings.keys) }
        let order: [Lights.Key] = all.sorted { ($0.first, $0.second) < ($1.first, $1.second) }
        var result: [[Double]] = []
        result.reserveCapacity(frames.count)
        for lights in frames {
            var row: [Double] = []
            for key in order { row.append(lights.crossings[key]?.level ?? 0) }
            row.append(lights.match)
            row.append(lights.glow)
            result.append(row)
        }
        return result
    }

    /// Whether `lights` show exactly the targets of `snapshot` (present marks at 1 and nothing else, match, glow).
    static func atTargets(_ lights: Lights, _ snapshot: WaveKnotKeeperSceneSnapshot) -> Bool {
        let present: Set<Lights.Key> = keys(snapshot)
        guard Set(lights.crossings.keys) == present else { return false }
        guard lights.crossings.values.allSatisfy({ $0.level == 1 }) else { return false }
        return lights.match == (snapshot.matchesTarget ? 1 : 0) && lights.glow == (snapshot.stage == .won ? 1 : 0)
    }

    /// Level 1's opening and the same play after its certified solution.
    static func levelOne() throws -> (start: Core, won: Core) {
        let start: Core = try Core.opening(number: 1)
        var won: Core = start
        for move in try Core.generated(number: 1).solution.moves { #expect(won.apply(action(move)) == .accepted) }
        #expect(won.play.stage == .won)
        return (start, won)
    }

    /// Plays level 1's certified solution, one move per 0.2 s, while stepping lights at 60 Hz for 3 s.
    static func scriptedWin(reducedFlash: Bool) throws -> (frames: [Lights], won: Bool) {
        var core: Core = try Core.opening(number: 1)
        let moves: [WaveKnotKeeperMove] = try Core.generated(number: 1).solution.moves
        var lights: Lights = Lights(reducedFlash: reducedFlash)
        lights.settle(to: core.snapshot(time: 0))
        var frames: [Lights] = [lights]
        var applied: Int = 0
        for frame in 1...180 {
            let seconds: Double = Double(frame) / frameRate
            let due: Int = min(Int(seconds / 0.2), moves.count)
            while applied < due {
                #expect(core.apply(action(moves[applied])) == .accepted)
                applied += 1
            }
            lights.step(toward: core.snapshot(time: seconds), elapsed: Self.frame)
            frames.append(lights)
        }
        return (frames, core.play.stage == .won)
    }

    /// A legal move of `core`'s play that keeps it playing and changes its set of crossing marks.
    static func markChangingMove(_ core: Core) -> WaveKnotKeeperMove? {
        let before: Set<Lights.Key> = keys(core.snapshot(time: 0))
        for move in WaveKnotKeeperRules(level: core.play.level).moves(in: core.play.points) {
            var copy: Core = core
            guard copy.apply(action(move)) == .accepted, copy.play.stage == .playing else { continue }
            if keys(copy.snapshot(time: 0)) != before { return move }
        }
        return nil
    }

    @Test func targetsFollowTheSnapshot() throws {
        let level: (start: Core, won: Core) = try Self.levelOne()
        let start: WaveKnotKeeperSceneSnapshot = level.start.snapshot(time: 0)
        let won: WaveKnotKeeperSceneSnapshot = level.won.snapshot(time: 0)
        #expect(Lights.glowTarget(start) == 0 && Lights.matchTarget(start) == 0)
        #expect(Lights.glowTarget(won) == 1 && Lights.matchTarget(won) == 1)
        var lights: Lights = Lights(reducedFlash: false)
        lights.settle(to: start)
        #expect(Self.atTargets(lights, start) && lights.isSettled)
        for mark in start.crossings {
            let light: Lights.Crossing? = lights.crossings[Lights.Key(first: mark.first, second: mark.second)]
            #expect(light?.over == mark.over)
            let expected: Double? = WaveKnotKeeperSceneGeometry.crossingParameter(mark, points: start.points)
            #expect(light?.fraction == (expected ?? 0.5))
            #expect((light?.fraction ?? -1) >= 0 && (light?.fraction ?? 2) <= 1)
        }
    }

    @Test func scriptedWinUnderReduceFlashing() throws {
        let run: (frames: [Lights], won: Bool) = try Self.scriptedWin(reducedFlash: true)
        #expect(run.won)
        #expect(run.frames.last?.glow == 1 && run.frames.last?.match == 1, "the glow and the match reach 1")
        #expect(run.frames.last?.isSettled == true)
        let samples: [[Double]] = Self.samples(run.frames)
        let rate: Double = Lights.maxHalfRangeCrossingsPerSecond(samples, frameRate: Self.frameRate)
        #expect(rate >= 1 && rate <= 3, "\(rate) crossings per second")
        let shortest: Double = Lights.shortestHalfRangeChange(samples, frameRate: Self.frameRate)
        #expect(shortest >= 0.4 && shortest.isFinite, "\(shortest) s")
    }

    @Test func scriptedWinNormallyFadesFast() throws {
        let run: (frames: [Lights], won: Bool) = try Self.scriptedWin(reducedFlash: false)
        #expect(run.won)
        let shortest: Double = Lights.shortestHalfRangeChange(Self.samples(run.frames), frameRate: Self.frameRate)
        #expect(shortest > 0 && shortest <= 0.15 + Self.frame + 1e-9, "\(shortest) s")
    }

    @Test func targetsAreReachedWithinDurationAndOneFrame() throws {
        let level: (start: Core, won: Core) = try Self.levelOne()
        let start: WaveKnotKeeperSceneSnapshot = level.start.snapshot(time: 0)
        let end: WaveKnotKeeperSceneSnapshot = level.won.snapshot(time: 0)
        for reduced in [false, true] {
            var lights: Lights = Lights(reducedFlash: reduced)
            lights.settle(to: start)
            let duration: Double = reduced ? Lights.reducedFlashDuration : Lights.normalDuration
            #expect(lights.duration == duration)
            let frames: Int = Int((duration * Self.frameRate).rounded()) + 1
            for index in 0..<frames {
                lights.step(toward: end, elapsed: Self.frame)
                if index < frames - 2 { #expect(!lights.isSettled, "not instantly, frame \(index)") }
            }
            #expect(lights.isSettled && Self.atTargets(lights, end), "reduced \(reduced)")
        }
    }

    @Test func moveAndUndoEveryFrameStaysSlowUnderReduceFlashing() throws {
        let core: Core = try Core.opening(number: Core.levelNumber(forSeed: Self.seed))
        let move: WaveKnotKeeperMove = try #require(Self.markChangingMove(core))
        var flicker: Core = core
        var lights: Lights = Lights(reducedFlash: true)
        lights.settle(to: flicker.snapshot(time: 0))
        var frames: [Lights] = [lights]
        for frame in 0..<180 {
            let result: ActionResult = frame % 2 == 0 ? flicker.apply(Self.action(move)) : flicker.apply(Self.undo)
            #expect(result == .accepted, "frame \(frame)")
            lights.step(toward: flicker.snapshot(time: Double(frame) * Self.frame), elapsed: Self.frame)
            frames.append(lights)
        }
        let samples: [[Double]] = Self.samples(frames)
        #expect(samples.first.map { $0.count > 2 } == true, "crossing series are measured")
        let rate: Double = Lights.maxHalfRangeCrossingsPerSecond(samples, frameRate: Self.frameRate)
        #expect(rate <= 3, "\(rate)")
        #expect(Lights.shortestHalfRangeChange(samples, frameRate: Self.frameRate) >= 0.4)
        // Held 4 frames (a mark near 0.44 at the normal speed), then the same flicker blinks the mark across half its
        // range every frame: the measure detects it, so the bound above is meaningful.
        var normal: Lights = Lights(reducedFlash: false)
        var fast: Core = core
        normal.settle(to: fast.snapshot(time: 0))
        var normalFrames: [Lights] = [normal]
        for frame in 0..<120 {
            let toggle: Bool = frame < 4 || frame % 2 == 0
            let moved: Bool = fast.play.points != core.play.points
            if toggle != moved {
                #expect((moved ? fast.apply(Self.undo) : fast.apply(Self.action(move))) == .accepted)
            }
            normal.step(toward: fast.snapshot(time: 0), elapsed: Self.frame)
            normalFrames.append(normal)
        }
        #expect(Lights.maxHalfRangeCrossingsPerSecond(Self.samples(normalFrames), frameRate: Self.frameRate) > 3)
    }

    @Test func toggledTargetsStaySlowUnderReduceFlashing() throws {
        let level: (start: Core, won: Core) = try Self.levelOne()
        let playing: WaveKnotKeeperSceneSnapshot = level.start.snapshot(time: 0)
        let won: WaveKnotKeeperSceneSnapshot = level.won.snapshot(time: 0)
        var state: UInt64 = Self.seed
        for pattern in 0..<5 {
            var lights: Lights = Lights(reducedFlash: true)
            lights.settle(to: playing)
            var frames: [Lights] = [lights]
            for frame in 0..<180 {
                let high: Bool
                switch pattern {
                case 0: high = frame % 2 == 0
                case 1: high = (frame / 2) % 2 == 0
                case 2: high = (frame / 5) % 2 == 0
                case 3: high = frame < 14 || frame % 2 == 0
                default:
                    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                    high = (state >> 33) & 1 == 1
                }
                lights.step(toward: high ? won : playing, elapsed: Self.frame)
                frames.append(lights)
            }
            let samples: [[Double]] = Self.samples(frames)
            #expect(Lights.maxHalfRangeCrossingsPerSecond(samples, frameRate: Self.frameRate) <= 3, "pattern \(pattern)")
            #expect(Lights.shortestHalfRangeChange(samples, frameRate: Self.frameRate) >= 0.4, "pattern \(pattern)")
        }
    }

    @Test func aVanishedMarkKeepsItsPlaceWhileFading() throws {
        let core: Core = try Core.opening(number: Core.levelNumber(forSeed: Self.seed))
        var found: (move: WaveKnotKeeperMove, key: Lights.Key)?
        let before: WaveKnotKeeperSceneSnapshot = core.snapshot(time: 0)
        for move in WaveKnotKeeperRules(level: core.play.level).moves(in: core.play.points) {
            var copy: Core = core
            guard copy.apply(Self.action(move)) == .accepted else { continue }
            if let gone = Self.keys(before).subtracting(Self.keys(copy.snapshot(time: 0))).first {
                found = (move, gone)
                break
            }
        }
        let (move, key): (WaveKnotKeeperMove, Lights.Key) = try #require(found)
        for reduced in [false, true] {
            var lights: Lights = Lights(reducedFlash: reduced)
            lights.settle(to: before)
            let remembered: Lights.Crossing = try #require(lights.crossings[key])
            var moved: Core = core
            #expect(moved.apply(Self.action(move)) == .accepted)
            let after: WaveKnotKeeperSceneSnapshot = moved.snapshot(time: 0)
            var previous: Double = 1
            var frames: Int = 0
            while lights.crossings[key] != nil && frames < 60 {
                lights.step(toward: after, elapsed: Self.frame)
                frames += 1
                if let now = lights.crossings[key] {
                    #expect(now.over == remembered.over && now.fraction == remembered.fraction)
                    #expect(now.level < previous && now.level > 0)
                    previous = now.level
                }
            }
            #expect(lights.crossings[key] == nil, "dropped once at 0")
            let expected: Int = Int((lights.duration * Self.frameRate).rounded())
            #expect(abs(frames - expected) <= 1, "faded out in \(frames) frames")
            #expect(lights.isSettled && Self.atTargets(lights, after))
            // Marks that appeared fade in at their drawn crossing point.
            for mark in after.crossings where !Self.keys(before).contains(Lights.Key(first: mark.first,
                                                                                    second: mark.second)) {
                let light: Lights.Crossing? = lights.crossings[Lights.Key(first: mark.first, second: mark.second)]
                #expect(light?.over == mark.over)
                #expect(light?.fraction == WaveKnotKeeperSceneGeometry.crossingParameter(mark, points: after.points))
            }
        }
    }

    @Test func settleJumpsAndANewLevelSettles() throws {
        let level: (start: Core, won: Core) = try Self.levelOne()
        let start: WaveKnotKeeperSceneSnapshot = level.start.snapshot(time: 0)
        let won: WaveKnotKeeperSceneSnapshot = level.won.snapshot(time: 0)
        var lights: Lights = Lights(reducedFlash: true)
        #expect(lights.crossings.isEmpty && lights.match == 0 && lights.glow == 0 && lights.isSettled)
        lights.step(toward: start, elapsed: Self.frame)
        #expect(Self.atTargets(lights, start) && lights.isSettled, "the first step settles")
        lights.settle(to: won)
        #expect(Self.atTargets(lights, won) && lights.glow == 1 && lights.match == 1 && lights.isSettled)
        let other: WaveKnotKeeperSceneSnapshot = try Core.opening(number: 2).snapshot(time: 0)
        lights.step(toward: other, elapsed: 0)
        #expect(Self.atTargets(lights, other) && lights.isSettled, "another level settles at once")
    }

    @Test func negativeAndNonFiniteElapsedDoNothing() throws {
        let level: (start: Core, won: Core) = try Self.levelOne()
        let start: WaveKnotKeeperSceneSnapshot = level.start.snapshot(time: 0)
        let end: WaveKnotKeeperSceneSnapshot = level.won.snapshot(time: 0)
        for reduced in [false, true] {
            var lights: Lights = Lights(reducedFlash: reduced)
            lights.settle(to: start)
            for elapsed in [-1.0, -.infinity, .infinity, .nan, 0] {
                lights.step(toward: end, elapsed: elapsed)
                #expect(lights.match == 0 && lights.glow == 0, "elapsed \(elapsed)")
                for (key, light) in lights.crossings where Self.keys(start).contains(key) {
                    #expect(light.level == 1, "elapsed \(elapsed)")
                }
            }
            lights.step(toward: end, elapsed: 10)
            #expect(Self.atTargets(lights, end) && lights.isSettled)
        }
    }

    @Test func measuresOnHandMadeSamples() {
        #expect(Lights.maxHalfRangeCrossingsPerSecond([], frameRate: 60) == 0)
        #expect(Lights.shortestHalfRangeChange([[0]], frameRate: 60) == .infinity)
        // 0 → 1 in 6 frames and back: two crossings, each fade 0.1 s at 60 Hz.
        var samples: [[Double]] = []
        for index in 0...6 { samples.append([Double(index) / 6]) }
        for index in 0...6 { samples.append([1 - Double(index) / 6]) }
        samples.append([0])
        #expect(Lights.maxHalfRangeCrossingsPerSecond(samples, frameRate: 60) == 2)
        #expect(abs(Lights.shortestHalfRangeChange(samples, frameRate: 60) - 0.1) < 1e-9)
        // A blink between 0 and 1 every frame for one second: 60 crossings.
        var blink: [[Double]] = []
        for index in 0...60 { blink.append([Double(index % 2)]) }
        #expect(Lights.maxHalfRangeCrossingsPerSecond(blink, frameRate: 60) == 60)
        #expect(Lights.shortestHalfRangeChange(samples, frameRate: .nan) == .infinity)
    }
}
