// ColorfallCanyonsLightsTests — feature 346 (R02-G05-06) T-R02G0506-003 (FR-R02G0506-004; SC-R02G0506-003;
// clarification Q3; research R3, R4). The eased lights of certified level 1: the targets (sheet brightness per cell
// holding fluid, emitters 1 flowing and 0.3 not, glow 1 when won); a scripted win (the certified actions, every step
// split into steps of 1 tick, one action per frame) and adversarial flicker (a valve toggled and undone every frame with
// steps of 1 tick between, a tick and its undo, and retries that restart the play), sampled every 1/60 s under Reduce
// Flashing: no element crosses half its range more than 3 times per second and every complete one-way fade of more than
// half the range takes at least 0.4 s; normally a target is reached within 0.15 s; settle jumps; a new level settles; an
// emptied sheet keeps its weights while it fades out and is then dropped; negative and non-finite elapsed times do
// nothing; the measure detects fast blinking. Explicit types, plain loops, short runs, no wall-clock asserts.
import Testing
@testable import ColorfallCanyonsCore

@Suite struct ColorfallCanyonsLightsTests {
    typealias Lights = ColorfallCanyonsLights
    static let frameRate: Double = 60
    static let frame: Double = 1 / 60
    /// The certified level every test plays.
    static let levelNumber: Int = 1

    /// Certified level 1.
    static func level() throws -> ColorfallCanyonsLevel {
        try ColorfallCanyonsExperienceCore.level(number: levelNumber)
    }

    /// A fresh play of certified level 1 in stage `playing`.
    static func freshPlay() throws -> ColorfallCanyonsPlay {
        try ColorfallCanyonsExperienceCore.freshPlay(of: try level())
    }

    /// The snapshot of `play` with the test level number (or `number`).
    static func snap(_ play: ColorfallCanyonsPlay, number: Int = levelNumber) -> ColorfallCanyonsSceneSnapshot {
        ColorfallCanyonsSceneSnapshot(play: play, levelNumber: number, time: 0)
    }

    /// The certified actions of level 1 with every step split into steps of 1 tick.
    static func scriptedWin() -> [ColorfallCanyonsAction] {
        var result: [ColorfallCanyonsAction] = []
        for action in ColorfallCanyonsExperienceCore.certifiedActions(levelNumber) {
            switch action {
            case .step(let ticks):
                for _ in 0..<ticks { result.append(.step(1)) }
            default:
                result.append(action)
            }
        }
        return result
    }

    /// One sample of every light: a level per grid cell (0 without a sheet), every emitter, the glow.
    static func sample(_ lights: Lights, cells: Int) -> [Double] {
        var values: [Double] = []
        values.reserveCapacity(cells + lights.emitters.count + 1)
        for cell in 0..<cells { values.append(lights.sheets[cell]?.level ?? 0) }
        values.append(contentsOf: lights.emitters)
        values.append(lights.glow)
        return values
    }

    /// Checks the two flash limits on `samples` under Reduce Flashing.
    static func expectWithinLimits(_ samples: [[Double]], _ label: String) {
        let crossings: Double = Lights.maxHalfRangeCrossingsPerSecond(samples, frameRate: frameRate)
        #expect(crossings <= 3, "\(label): \(crossings) crossings per second")
        let shortest: Double = Lights.shortestHalfRangeChange(samples, frameRate: frameRate)
        #expect(shortest >= 0.4, "\(label): a half-range fade took \(shortest) s")
    }

    /// Whether `play` accepts `action` now (it is applied when it does).
    static func tryApply(_ play: inout ColorfallCanyonsPlay, _ action: ColorfallCanyonsAction) -> Bool {
        do {
            try play.apply(action, expecting: play.fingerprint)
            return true
        } catch {
            return false
        }
    }

    @Test func settleJumpsToTheTargets() throws {
        var play: ColorfallCanyonsPlay = try Self.freshPlay()
        let actions: [ColorfallCanyonsAction] = Self.scriptedWin()
        for action in actions where play.stage == .playing { _ = Self.tryApply(&play, action) }
        #expect(play.stage == .won)
        let snapshot: ColorfallCanyonsSceneSnapshot = Self.snap(play)
        var lights: Lights = Lights(reducedFlash: true)
        #expect(lights.sheets.isEmpty && lights.emitters.isEmpty && lights.glow == 0)
        lights.settle(to: snapshot)
        #expect(lights.isSettled && lights.glow == 1)
        var lit: Int = 0
        for cell in 0..<snapshot.cellCount {
            let volume: Int = snapshot.volume(cell)
            if volume > 0 {
                lit += 1
                #expect(lights.sheets[cell]?.level == ColorfallCanyonsPalette.brightness(volume: volume))
                #expect(lights.sheets[cell]?.weights == ColorfallCanyonsShaders.weights(masses: snapshot.masses[cell]))
            } else {
                #expect(lights.sheets[cell] == nil)
            }
        }
        #expect(lit > 0 && lights.sheets.count == lit)
        #expect(lights.emitters.count == snapshot.springs.count)
        for index in snapshot.springs.indices {
            let expected: Double = snapshot.springs[index].flowing ? 1 : ColorfallCanyonsSceneGeometry.dimming
            #expect(lights.emitters[index] == expected)
        }
        // The first step also settles; a new level number settles again (no fade from the old level).
        var first: Lights = Lights(reducedFlash: false)
        first.step(toward: snapshot, elapsed: Self.frame)
        #expect(first.isSettled && first.glow == 1)
        let fresh: ColorfallCanyonsPlay = try Self.freshPlay()
        first.step(toward: Self.snap(fresh, number: 2), elapsed: Self.frame)
        #expect(first.isSettled && first.glow == 0)
    }

    @Test func normalModeReachesTargetsWithinTheDuration() throws {
        let start: ColorfallCanyonsPlay = try Self.freshPlay()
        var won: ColorfallCanyonsPlay = start
        for action in Self.scriptedWin() where won.stage == .playing { _ = Self.tryApply(&won, action) }
        let frames: Int = Int((Lights.normalDuration * Self.frameRate).rounded())
        #expect(frames == 9)
        // From the start to the won state and back (a retry), both ways within 0.15 s, not one frame sooner for the glow.
        let pairs: [(ColorfallCanyonsPlay, ColorfallCanyonsPlay)] = [(start, won), (won, start)]
        for (from, to) in pairs {
            var lights: Lights = Lights(reducedFlash: false)
            lights.settle(to: Self.snap(from))
            let target: ColorfallCanyonsSceneSnapshot = Self.snap(to)
            for _ in 0..<(frames - 1) { lights.step(toward: target, elapsed: Self.frame) }
            #expect(!lights.isSettled && lights.glow > 0 && lights.glow < 1)
            lights.step(toward: target, elapsed: Self.frame)
            #expect(lights.isSettled)
            #expect(lights.glow == (to.stage == .won ? 1 : 0))
        }
    }

    @Test func badElapsedTimesDoNothing() throws {
        let start: ColorfallCanyonsPlay = try Self.freshPlay()
        var won: ColorfallCanyonsPlay = start
        for action in Self.scriptedWin() where won.stage == .playing { _ = Self.tryApply(&won, action) }
        var lights: Lights = Lights(reducedFlash: true)
        lights.settle(to: Self.snap(start))
        let before: Lights = lights
        let bad: [Double] = [-1, -.infinity, .infinity, .nan, 0]
        for elapsed in bad {
            lights.step(toward: Self.snap(won), elapsed: elapsed)
            #expect(lights.glow == 0 && lights.emitters == before.emitters, "\(elapsed)")
            for (cell, sheet) in lights.sheets {
                #expect(sheet.level == (before.sheets[cell]?.level ?? 0), "\(elapsed) cell \(cell)")
            }
        }
        #expect(!lights.isSettled)
        // A real frame then moves the glow.
        lights.step(toward: Self.snap(won), elapsed: Self.frame)
        #expect(lights.glow > 0)
    }

    @Test func anEmptiedSheetKeepsItsWeightsWhileFading() throws {
        var play: ColorfallCanyonsPlay = try Self.freshPlay()
        let empty: ColorfallCanyonsSceneSnapshot = Self.snap(play)
        var filled: ColorfallCanyonsSceneSnapshot = empty
        for action in Self.scriptedWin() where play.stage == .playing {
            _ = Self.tryApply(&play, action)
            filled = Self.snap(play)
            var newlyLit: Bool = false
            for cell in 0..<filled.cellCount where filled.volume(cell) > 0 && empty.volume(cell) == 0 { newlyLit = true }
            if newlyLit { break }
        }
        var cell: Int = -1
        for index in 0..<filled.cellCount where filled.volume(index) > 0 && empty.volume(index) == 0 { cell = index }
        try #require(cell >= 0)
        let weights: SIMD3<Double> = ColorfallCanyonsShaders.weights(masses: filled.masses[cell])
        #expect(weights != SIMD3<Double>(0, 0, 0))
        for reduced in [false, true] {
            var lights: Lights = Lights(reducedFlash: reduced)
            lights.settle(to: filled)
            let full: Double = ColorfallCanyonsPalette.brightness(volume: filled.volume(cell))
            #expect(lights.sheets[cell] == Lights.Sheet(level: full, weights: weights))
            let duration: Double = reduced ? Lights.reducedFlashDuration : Lights.normalDuration
            let frames: Int = Int((duration * Self.frameRate).rounded())
            var previous: Double = full
            for _ in 0..<(frames - 1) {
                lights.step(toward: empty, elapsed: Self.frame)
                let sheet: Lights.Sheet? = lights.sheets[cell]
                try #require(sheet != nil)
                #expect(sheet?.weights == weights)
                let level: Double = sheet?.level ?? 0
                #expect(level < previous && level > 0)
                previous = level
            }
            lights.step(toward: empty, elapsed: Self.frame)
            #expect(lights.sheets[cell] == nil && lights.isSettled)
        }
    }

    @Test func aScriptedWinStaysWithinTheLimits() throws {
        var play: ColorfallCanyonsPlay = try Self.freshPlay()
        let cells: Int = play.level.cellCount
        var lights: Lights = Lights(reducedFlash: true)
        lights.settle(to: Self.snap(play))
        var samples: [[Double]] = [Self.sample(lights, cells: cells)]
        let actions: [ColorfallCanyonsAction] = Self.scriptedWin()
        for action in actions where play.stage == .playing {
            #expect(Self.tryApply(&play, action))
            lights.step(toward: Self.snap(play), elapsed: Self.frame)
            samples.append(Self.sample(lights, cells: cells))
        }
        #expect(play.stage == .won)
        for _ in 0..<60 {
            lights.step(toward: Self.snap(play), elapsed: Self.frame)
            samples.append(Self.sample(lights, cells: cells))
        }
        #expect(lights.isSettled && lights.glow == 1)
        // The win glow faded in over exactly 0.45 s, a complete one-way fade of the whole range.
        Self.expectWithinLimits(samples, "scripted win")
        let shortest: Double = Lights.shortestHalfRangeChange(samples, frameRate: Self.frameRate)
        #expect(shortest.isFinite)
    }

    /// Runs `frames` frames of a flicker `pattern` (one action per frame; nil = undo) on level 1 under Reduce Flashing,
    /// restarting the play every `retryEvery` frames and whenever it ends; returns the samples and accepted changes.
    static func flicker(pattern: [ColorfallCanyonsAction?], frames: Int, retryEvery: Int) throws -> ([[Double]], Int) {
        var play: ColorfallCanyonsPlay = try freshPlay()
        let cells: Int = play.level.cellCount
        var lights: Lights = Lights(reducedFlash: true)
        lights.settle(to: snap(play))
        var samples: [[Double]] = [sample(lights, cells: cells)]
        var accepted: Int = 0
        for index in 0..<frames {
            if play.stage != .playing || (index > 0 && index % retryEvery == 0) {
                play = try freshPlay()
                accepted += 1
            } else if let action = pattern[index % pattern.count] {
                if tryApply(&play, action) { accepted += 1 }
            } else {
                do {
                    try play.undo()
                    accepted += 1
                } catch {}
            }
            lights.step(toward: snap(play), elapsed: frame)
            samples.append(sample(lights, cells: cells))
        }
        return (samples, accepted)
    }

    @Test func adversarialFlickerStaysWithinTheLimits() throws {
        let level: ColorfallCanyonsLevel = try Self.level()
        try #require(!level.springs.isEmpty)
        var patterns: [(String, [ColorfallCanyonsAction?])] = []
        for spring in level.springs.indices {
            // A valve toggled and undone every frame, a tick between.
            patterns.append(("valve \(spring) and undo", [.valve(spring), nil, .step(1)]))
            // A valve toggled, a tick, both undone: the fluid and the emitter flicker together.
            patterns.append(("valve \(spring), tick, undo twice", [.valve(spring), .step(1), nil, nil, .step(1)]))
        }
        // Ticks and their undos, every frame.
        patterns.append(("tick and undo", [.step(1), .step(1), nil]))
        for (label, pattern) in patterns {
            let runs: [Int] = [17, 45, 300]
            for retry in runs {
                let (samples, accepted): ([[Double]], Int) = try Self.flicker(pattern: pattern, frames: 300,
                                                                              retryEvery: retry)
                #expect(accepted > 100, "\(label) retry \(retry)")
                Self.expectWithinLimits(samples, "\(label) retry \(retry)")
            }
        }
    }

    @Test func theMeasureDetectsFastBlinking() {
        // A level blinking 0 ↔ 1 every frame crosses half its range 60 times a second in one-frame fades.
        var samples: [[Double]] = []
        for index in 0..<120 { samples.append([index % 2 == 0 ? 0 : 1, 0.3]) }
        #expect(Lights.maxHalfRangeCrossingsPerSecond(samples, frameRate: 60) == 60)
        #expect(Lights.shortestHalfRangeChange(samples, frameRate: 60) == 1.0 / 60)
        #expect(Lights.maxHalfRangeCrossingsPerSecond([[0.2]], frameRate: 60) == 0)
        // Small steps near 0.5 cross without a big fade.
        var near: [[Double]] = []
        for index in 0..<60 { near.append([index % 2 == 0 ? 0.49 : 0.51]) }
        #expect(Lights.maxHalfRangeCrossingsPerSecond(near, frameRate: 60) == 59)
        #expect(Lights.shortestHalfRangeChange(near, frameRate: 60) == .infinity)
    }
}
