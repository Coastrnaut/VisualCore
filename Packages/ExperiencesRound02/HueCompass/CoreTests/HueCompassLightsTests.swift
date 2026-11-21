// HueCompassLightsTests — feature 336 (R02-G04-06) T-R02G0406-003 (FR-R02G0406-004; clarification Q3; research R3,
// R4; SC-R02G0406-003). The eased lights: the targets (probed bearings 1, the selection and the target ring at their
// bearings, glow 1 when won); a scripted win (three probes and a selection, one action per 0.2 s) sampled every 1/60 s
// under Reduce Flashing crosses half the range at most 3 times per second per element and every complete one-way fade
// of more than half the range takes at least 0.4 s; adversarial flicker (a probe mark appearing and vanishing, the
// selection and ring toggling, a turn and its undo, a retry that clears the probes and replays them, and a selection
// that jumps between two bearings, every 1, 2 and 5 frames and at random) stays within both limits under Reduce
// Flashing; normally a target is reached within 0.15 s and one frame; settle jumps; a new level settles; a vanished mark
// keeps its bearing while it fades out and is then dropped; a selection wanted elsewhere fades out where it was and then
// in at the new bearing; negative and non-finite elapsed times do nothing; the measure detects fast blinking. Seeded
// fixtures (no solver), explicit types, plain loops, short runs.
import Testing
@testable import HueCompassCore

@Suite struct HueCompassLightsTests {
    typealias Lights = HueCompassLights
    static let frameRate: Double = 60
    static let frame: Double = 1 / 60
    /// The seed of the pseudo-random flicker pattern.
    static let seed: UInt64 = 2_336
    /// The level number every test snapshot carries (another number settles the lights).
    static let levelNumber: Int = 7

    /// The practice copy (allowance 24) of fixture 3.
    static func level() throws -> HueCompassLevel {
        try HueCompassExperienceCore.practiceLevel(of: HueCompassFixtures.fixture(3).level)
    }

    /// A fresh play of `level` after `actions`.
    static func play(_ level: HueCompassLevel, _ actions: [HueCompassAction]) throws -> HueCompassPlay {
        var play: HueCompassPlay = try HueCompassExperienceCore.freshPlay(of: level)
        for action in actions { try play.apply(action, expecting: play.fingerprint) }
        return play
    }

    /// The snapshot of `play` with the test level number (or `number`).
    static func snap(_ play: HueCompassPlay, number: Int = levelNumber) -> HueCompassSceneSnapshot {
        HueCompassSceneSnapshot(play: play, levelNumber: number, time: 0)
    }

    /// Three probes 10 bearings apart, starting at the level's start.
    static let probes: [HueCompassAction] = [.probe, .turn(10), .probe, .turn(10), .probe]

    /// The probes, a turn to the target and a winning selection.
    static func winning(_ level: HueCompassLevel) -> [HueCompassAction] {
        let at: Int = HueCompassWheel.mod(level.start + 20, 96)
        let turn: Int = HueCompassFixtures.shortestTurn(from: at, to: level.target)
        var actions: [HueCompassAction] = probes
        if turn != 0 { actions.append(.turn(turn)) }
        actions.append(.select(bearing: level.target, band: level.targetBand))
        return actions
    }

    /// The probes and a missed selection at `away` bearings from the target.
    static func missing(_ level: HueCompassLevel, away: Int) -> [HueCompassAction] {
        probes + [.select(bearing: HueCompassWheel.mod(level.target + away, 96), band: level.targetBand)]
    }

    /// One vector per recorded frame: the probe level at each of the 96 bearings, the selection level at each bearing,
    /// the ring level at each bearing, then the selection, ring and glow levels (0 while absent).
    static func samples(_ frames: [Lights]) -> [[Double]] {
        var result: [[Double]] = []
        result.reserveCapacity(frames.count)
        for lights in frames {
            var row: [Double] = []
            row.reserveCapacity(96 * 3 + 3)
            for bearing in 0..<96 { row.append(lights.probes[bearing] ?? 0) }
            for bearing in 0..<96 { row.append(lights.selection?.bearing == bearing ? lights.selection?.level ?? 0 : 0) }
            for bearing in 0..<96 { row.append(lights.ring?.bearing == bearing ? lights.ring?.level ?? 0 : 0) }
            row.append(lights.selection?.level ?? 0)
            row.append(lights.ring?.level ?? 0)
            row.append(lights.glow)
            result.append(row)
        }
        return result
    }

    /// Whether `lights` show exactly the targets of `snapshot`.
    static func atTargets(_ lights: Lights, _ snapshot: HueCompassSceneSnapshot) -> Bool {
        let present: Set<Int> = Set(HueCompassSceneGeometry.probeBearings(snapshot))
        guard Set(lights.probes.keys) == present, lights.probes.values.allSatisfy({ $0 == 1 }) else { return false }
        let selection: Lights.Mark? = snapshot.selection.map { Lights.Mark(level: 1, bearing: $0.bearing) }
        let ring: Lights.Mark? = snapshot.target.map { Lights.Mark(level: 1, bearing: $0) }
        return lights.selection == selection && lights.ring == ring && lights.glow == (snapshot.stage == .won ? 1 : 0)
    }

    /// Checks both Reduce Flashing limits on `frames`.
    static func expectSlow(_ frames: [Lights], _ label: String) {
        let samples: [[Double]] = Self.samples(frames)
        let rate: Double = Lights.maxHalfRangeCrossingsPerSecond(samples, frameRate: frameRate)
        #expect(rate <= 3, "\(label): \(rate) crossings per second")
        let shortest: Double = Lights.shortestHalfRangeChange(samples, frameRate: frameRate)
        #expect(shortest >= 0.4, "\(label): \(shortest) s")
    }

    /// Steps lights settled to `snapshots(0)` toward `snapshots(frame)` for frames 1 … 180 (3 s at 60 Hz).
    static func run(reducedFlash: Bool, _ snapshots: (Int) -> HueCompassSceneSnapshot) -> [Lights] {
        var lights: Lights = Lights(reducedFlash: reducedFlash)
        lights.settle(to: snapshots(0))
        var frames: [Lights] = [lights]
        for frame in 1...180 {
            lights.step(toward: snapshots(frame), elapsed: HueCompassLightsTests.frame)
            frames.append(lights)
        }
        return frames
    }

    /// Plays the winning actions, one per 0.2 s, while stepping lights at 60 Hz for 3 s.
    static func scriptedWin(reducedFlash: Bool) throws -> [Lights] {
        let level: HueCompassLevel = try Self.level()
        let actions: [HueCompassAction] = winning(level)
        var plays: [HueCompassPlay] = [try play(level, [])]
        for count in 1...actions.count { plays.append(try play(level, Array(actions.prefix(count)))) }
        #expect(plays.last?.stage == .won)
        return run(reducedFlash: reducedFlash) { frame in
            let due: Int = min(Int(Double(frame) / frameRate / 0.2), actions.count)
            return snap(plays[due])
        }
    }

    @Test func targetsFollowTheSnapshot() throws {
        let level: HueCompassLevel = try Self.level()
        let start: HueCompassSceneSnapshot = Self.snap(try Self.play(level, []))
        let won: HueCompassSceneSnapshot = Self.snap(try Self.play(level, Self.winning(level)))
        let missed: HueCompassSceneSnapshot = Self.snap(try Self.play(level, Self.missing(level, away: 48)))
        #expect(Lights.glowTarget(start) == 0 && Lights.glowTarget(won) == 1 && Lights.glowTarget(missed) == 0)
        #expect(Lights.selectionTarget(start) == nil && Lights.ringTarget(start) == nil)
        #expect(Lights.selectionTarget(won) == level.target && Lights.ringTarget(won) == level.target)
        #expect(Lights.selectionTarget(missed) == HueCompassWheel.mod(level.target + 48, 96))
        #expect(Lights.probeTargets(won).count == 3)
        for snapshot in [start, won, missed] {
            var lights: Lights = Lights(reducedFlash: false)
            lights.settle(to: snapshot)
            #expect(Self.atTargets(lights, snapshot) && lights.isSettled)
        }
    }

    @Test func scriptedWinUnderReduceFlashing() throws {
        let frames: [Lights] = try Self.scriptedWin(reducedFlash: true)
        let last: Lights = try #require(frames.last)
        #expect(last.glow == 1 && last.probes.count == 3 && last.selection?.level == 1 && last.ring?.level == 1)
        #expect(last.isSettled)
        let rate: Double = Lights.maxHalfRangeCrossingsPerSecond(Self.samples(frames), frameRate: Self.frameRate)
        #expect(rate >= 1, "the win is measured")
        Self.expectSlow(frames, "scripted win")
        #expect(Lights.shortestHalfRangeChange(Self.samples(frames), frameRate: Self.frameRate).isFinite)
    }

    @Test func scriptedWinNormallyFadesFast() throws {
        let frames: [Lights] = try Self.scriptedWin(reducedFlash: false)
        #expect(frames.last?.isSettled == true && frames.last?.glow == 1)
        let shortest: Double = Lights.shortestHalfRangeChange(Self.samples(frames), frameRate: Self.frameRate)
        #expect(shortest > 0 && shortest <= 0.15 + Self.frame + 1e-9, "\(shortest) s")
    }

    @Test func targetsAreReachedWithinDurationAndOneFrame() throws {
        let level: HueCompassLevel = try Self.level()
        let start: HueCompassSceneSnapshot = Self.snap(try Self.play(level, []))
        let end: HueCompassSceneSnapshot = Self.snap(try Self.play(level, Self.winning(level)))
        for (from, to) in [(start, end), (end, start)] {
            for reduced in [false, true] {
                var lights: Lights = Lights(reducedFlash: reduced)
                lights.settle(to: from)
                let duration: Double = reduced ? Lights.reducedFlashDuration : Lights.normalDuration
                #expect(lights.duration == duration)
                let frames: Int = Int((duration * Self.frameRate).rounded()) + 1
                for index in 0..<frames {
                    lights.step(toward: to, elapsed: Self.frame)
                    if index < frames - 2 { #expect(!lights.isSettled, "not instantly, frame \(index)") }
                }
                #expect(lights.isSettled && Self.atTargets(lights, to), "reduced \(reduced)")
            }
        }
    }

    @Test func flickerStaysSlowUnderReduceFlashing() throws {
        let level: HueCompassLevel = try Self.level()
        let empty: HueCompassSceneSnapshot = Self.snap(try Self.play(level, []))
        let probed: HueCompassSceneSnapshot = Self.snap(try Self.play(level, [.probe]))
        let turned: HueCompassSceneSnapshot = Self.snap(try Self.play(level, [.probe, .turn(5)]))
        var undone: HueCompassPlay = try Self.play(level, [.probe, .turn(5)])
        try undone.undo()
        let undoneSnapshot: HueCompassSceneSnapshot = Self.snap(undone)
        let playing: HueCompassSceneSnapshot = Self.snap(try Self.play(level, Self.probes))
        let won: HueCompassSceneSnapshot = Self.snap(try Self.play(level, Self.winning(level)))
        let missA: HueCompassSceneSnapshot = Self.snap(try Self.play(level, Self.missing(level, away: 48)))
        let missB: HueCompassSceneSnapshot = Self.snap(try Self.play(level, Self.missing(level, away: 20)))
        // A retry and a replay: the fresh play and the play after 1 … 5 of the probing actions.
        var replay: [HueCompassSceneSnapshot] = [empty]
        for count in 1...Self.probes.count {
            replay.append(Self.snap(try Self.play(level, Array(Self.probes.prefix(count)))))
        }
        let pairs: [(String, HueCompassSceneSnapshot, HueCompassSceneSnapshot)] = [
            ("probe mark", empty, probed), ("turn and undo", turned, undoneSnapshot),
            ("selection and ring", playing, won), ("selection moves", missA, missB), ("win and miss", won, missA),
        ]
        var state: UInt64 = Self.seed
        for pattern in 0..<5 {
            for (name, low, high) in pairs {
                let frames: [Lights] = Self.run(reducedFlash: true) { frame in
                    let on: Bool
                    switch pattern {
                    case 0: on = frame % 2 == 0
                    case 1: on = (frame / 2) % 2 == 0
                    case 2: on = (frame / 5) % 2 == 0
                    case 3: on = frame < 14 || frame % 2 == 0
                    default:
                        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                        on = (state >> 33) & 1 == 1
                    }
                    return on ? high : low
                }
                Self.expectSlow(frames, "\(name), pattern \(pattern)")
            }
            // Retry and replay: every frame the play is cleared or replayed to another length.
            let frames: [Lights] = Self.run(reducedFlash: true) { frame in
                let step: Int = pattern < 3 ? frame / (pattern * 2 + 1) : frame &* 7 &+ pattern
                return step % 2 == 0 ? replay[0] : replay[1 + step % Self.probes.count]
            }
            Self.expectSlow(frames, "retry and replay, pattern \(pattern)")
        }
    }

    @Test func theMeasureDetectsNormalBlinking() throws {
        let level: HueCompassLevel = try Self.level()
        let empty: HueCompassSceneSnapshot = Self.snap(try Self.play(level, []))
        let probed: HueCompassSceneSnapshot = Self.snap(try Self.play(level, [.probe]))
        // Toggled every 5 frames from a lit probe: at 0.15 s (9 frames) a fade moves 5 / 9 of the range, between 1 and
        // 4 / 9, so it crosses half the range every 5 frames, 12 times a second.
        let frames: [Lights] = Self.run(reducedFlash: false) { frame in
            (frame / 5) % 2 == 0 ? probed : empty
        }
        #expect(Lights.maxHalfRangeCrossingsPerSecond(Self.samples(frames), frameRate: Self.frameRate) > 3)
    }

    @Test func aVanishedMarkKeepsItsBearingWhileFading() throws {
        let level: HueCompassLevel = try Self.level()
        let ended: HueCompassSceneSnapshot = Self.snap(try Self.play(level, Self.missing(level, away: 48)))
        let retried: HueCompassSceneSnapshot = Self.snap(try Self.play(level, []))
        let selected: Int = HueCompassWheel.mod(level.target + 48, 96)
        for reduced in [false, true] {
            var lights: Lights = Lights(reducedFlash: reduced)
            lights.settle(to: ended)
            let bearings: Set<Int> = Set(lights.probes.keys)
            #expect(bearings.count == 3)
            var previous: Double = 1
            var frames: Int = 0
            while (lights.selection != nil || lights.ring != nil || !lights.probes.isEmpty) && frames < 60 {
                lights.step(toward: retried, elapsed: Self.frame)
                frames += 1
                if let selection = lights.selection, let ring = lights.ring {
                    #expect(selection.bearing == selected && ring.bearing == level.target)
                    #expect(selection.level < previous && selection.level > 0 && ring.level == selection.level)
                    #expect(Set(lights.probes.keys) == bearings)
                    #expect(lights.probes.values.allSatisfy { $0 == selection.level })
                    previous = selection.level
                }
            }
            #expect(lights.selection == nil && lights.ring == nil && lights.probes.isEmpty, "dropped once at 0")
            let expected: Int = Int((lights.duration * Self.frameRate).rounded())
            #expect(abs(frames - expected) <= 1, "faded out in \(frames) frames")
            #expect(lights.isSettled && Self.atTargets(lights, retried))
        }
    }

    @Test func aMovedSelectionFadesOutThenIn() throws {
        let level: HueCompassLevel = try Self.level()
        let first: HueCompassSceneSnapshot = Self.snap(try Self.play(level, Self.missing(level, away: 48)))
        let second: HueCompassSceneSnapshot = Self.snap(try Self.play(level, Self.missing(level, away: 20)))
        let a: Int = HueCompassWheel.mod(level.target + 48, 96)
        let b: Int = HueCompassWheel.mod(level.target + 20, 96)
        for reduced in [false, true] {
            var lights: Lights = Lights(reducedFlash: reduced)
            lights.settle(to: first)
            var sawB: Bool = false
            var frames: Int = 0
            var previous: Double = 1
            repeat {
                lights.step(toward: second, elapsed: Self.frame)
                frames += 1
                let mark: Lights.Mark = try #require(lights.selection)
                if mark.bearing == a {
                    #expect(!sawB && mark.level < previous, "fading out at the old bearing")
                } else {
                    #expect(mark.bearing == b)
                    if !sawB { #expect(mark.level <= 1 / (lights.duration * Self.frameRate) + 1e-9) }
                    if sawB { #expect(mark.level > previous, "fading in at the new bearing") }
                    sawB = true
                }
                previous = mark.level
                #expect(lights.ring == Lights.Mark(level: 1, bearing: level.target), "the ring stays")
            } while !lights.isSettled && frames < 120
            #expect(sawB && lights.isSettled && Self.atTargets(lights, second))
            let expected: Int = 2 * Int((lights.duration * Self.frameRate).rounded())
            #expect(abs(frames - expected) <= 2, "out and in in \(frames) frames")
        }
    }

    @Test func settleJumpsAndANewLevelSettles() throws {
        let level: HueCompassLevel = try Self.level()
        let start: HueCompassSceneSnapshot = Self.snap(try Self.play(level, Self.probes))
        let won: HueCompassSceneSnapshot = Self.snap(try Self.play(level, Self.winning(level)))
        var lights: Lights = Lights(reducedFlash: true)
        #expect(lights.probes.isEmpty && lights.selection == nil && lights.ring == nil && lights.glow == 0)
        #expect(lights.isSettled)
        lights.step(toward: start, elapsed: Self.frame)
        #expect(Self.atTargets(lights, start) && lights.isSettled, "the first step settles")
        lights.settle(to: won)
        #expect(Self.atTargets(lights, won) && lights.glow == 1 && lights.isSettled)
        let other: HueCompassSceneSnapshot = Self.snap(try Self.play(level, []), number: Self.levelNumber + 1)
        lights.step(toward: other, elapsed: 0)
        #expect(Self.atTargets(lights, other) && lights.isSettled, "another level settles at once")
    }

    @Test func negativeAndNonFiniteElapsedDoNothing() throws {
        let level: HueCompassLevel = try Self.level()
        let start: HueCompassSceneSnapshot = Self.snap(try Self.play(level, []))
        let end: HueCompassSceneSnapshot = Self.snap(try Self.play(level, Self.winning(level)))
        for reduced in [false, true] {
            var lights: Lights = Lights(reducedFlash: reduced)
            lights.settle(to: start)
            for elapsed in [-1.0, -.infinity, .infinity, .nan, 0] {
                lights.step(toward: end, elapsed: elapsed)
                #expect(lights.glow == 0 && (lights.selection?.level ?? 0) == 0, "elapsed \(elapsed)")
                #expect(lights.probes.values.allSatisfy { $0 == 0 }, "elapsed \(elapsed)")
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
