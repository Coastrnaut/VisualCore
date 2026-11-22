// ChronoConstellatorRegressionGoldenFrameTests — feature 358 (R02-G06-08) T-R02G0608-005 (FR-R02G0608-004;
// SC-R02G0608-003; clarification Q3). Through the one app's session host, each of the 16 code-only golden frames of
// `ChronoConstellatorGolden.frames` (certified levels 1, 21, 41, 61 and 81 at tiers 0, 1 and 2 at presentation time 0,
// each after its witness's phase changes followed by `step(6)`, plus the hero frame: level 1 after the hero scenario's
// phase change and `step(6)`, tier 0) is drawn off screen at the frame-check size 1,152 × 768 of
// `ChronoConstellatorTest` with the authored camera. The snapshot the presenter shows equals
// `ChronoConstellatorGolden.snapshot(frame)`, so the rendered frame is the described one; the frame's description
// (`ChronoConstellatorGolden.description(frame)`, decoded here) names the drawn tier's detail, the play tick, the tick
// mark's length, every star node centre, target centre and distinct loop cell centre, and those agree with the CPU
// reference within one quantum; the picture passes the feature-353 frame checks of `ChronoConstellatorTest.checkFrame`
// (each star centre within 3 px of a pixel at least 0.15 brighter than the field; each target ring, sampled on its band
// 0.34 … 0.42·u with a 3 px reach, at least 0.1 from the field in luminance; every free loop cell's track differs from
// the field; the two probe corners within 0.05 per channel of the field). Seed s opens level s % 100 + 1, so a frame of
// level L opens at seed L − 1; actions go through the session's action port as `star.phase`, `star.hold`,
// `star.release`, `time.step` and `time.rewind`. One test per level plus the hero test. Modelled on
// `ColorfallCanyonsRegressionGoldenFrameTests` (feature 348). Synthetic data, explicit types, plain loops, no sleep, no
// wall-clock assertion.
#if os(iOS)
import ChronoConstellatorCore
import Foundation
import Testing
@testable import ChronoConstellatorExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct ChronoConstellatorRegressionGoldenFrameTests {
    /// A position of the description in 1/8 pixel.
    struct Position: Decodable, Equatable {
        let x: Int
        let y: Int
    }

    /// An 8-bit colour of the description.
    struct Colour: Decodable, Equatable {
        let r: Int
        let g: Int
        let b: Int
    }

    /// A projected point of the description: its star or cell index and its position.
    struct Point: Decodable, Equatable {
        let index: Int
        let position: Position?
    }

    /// The description of one golden frame, decoded from `ChronoConstellatorGolden.description(_:)` (the colours other
    /// than the field are left undecoded).
    struct Description: Decodable, Equatable {
        let name: String
        let level: Int
        let tier: Int
        let tick: Int
        let tickMark: Int
        let ribbonTicks: Int
        let segments: Int
        let glowShells: Int
        let width: Int
        let height: Int
        let quantum: Int
        let field: Colour
        let stars: [Point]
        let targets: [Point]
        let cells: [Point]
    }

    /// The golden frames of `level` other than the hero (its three tiers), in their fixed order.
    static func tierFrames(level: Int) -> [ChronoConstellatorGolden.Frame] {
        var list: [ChronoConstellatorGolden.Frame] = []
        for frame in ChronoConstellatorGolden.frames where frame.level == level && frame.name != "hero" {
            list.append(frame)
        }
        return list
    }

    /// Sends `actions` through the session's action port as `star.phase`, `star.hold`, `star.release`, `time.step`
    /// and `time.rewind`, expecting each to be accepted.
    static func apply(_ actions: [ChronoConstellatorAction], to shell: ChronoConstellatorTest.Shell, _ what: String) {
        for action in actions {
            let result: ActionResult
            switch action {
            case .phase(let star, let phase):
                result = shell.handle(control: "star.phase", values: [Double(star), Double(phase)])
            case .hold(let star, let start, let length):
                result = shell.handle(control: "star.hold", values: [Double(star), Double(start), Double(length)])
            case .release(let star, let start):
                result = shell.handle(control: "star.release", values: [Double(star), Double(start)])
            case .step(let ticks):
                result = shell.handle(control: "time.step", values: [Double(ticks)])
            case .rewind:
                result = shell.handle(control: "time.rewind", values: [])
            }
            #expect(result == .accepted, "\(what): \(action) gave \(result.code)")
        }
    }

    /// Opens `level` (seed level − 1) and checks that the engine shows it.
    static func open(_ session: ExperienceSession, level: Int) async throws -> ChronoConstellatorTest.Shell {
        let seed: UInt64 = UInt64(level - 1)
        #expect(ChronoConstellatorExperienceCore.levelNumber(forSeed: seed) == level)
        let shell: ChronoConstellatorTest.Shell = try await ChronoConstellatorTest.open(session, seed: seed)
        let opened: Int = try ChronoConstellatorTest.core(shell).levelNumber
        #expect(opened == level, "seed \(seed) opened level \(opened)")
        return shell
    }

    /// The decoded description of `frame`.
    static func description(_ frame: ChronoConstellatorGolden.Frame) throws -> Description {
        let data: Data = try ChronoConstellatorGolden.description(frame)
        return try JSONDecoder().decode(Description.self, from: data)
    }

    /// Whether the described position `q` lies within one quantum (per axis) of the pixel `p`; both nil also agree.
    static func agrees(_ q: Position?, _ p: Vec2?, quantum: Int) -> Bool {
        switch (q, p) {
        case (nil, nil):
            return true
        case let (q?, p?):
            let x: Double = p.x * Double(quantum)
            let y: Double = p.y * Double(quantum)
            return abs(Double(q.x) - x) <= 1 && abs(Double(q.y) - y) <= 1
        default:
            return false
        }
    }

    /// `c` in 8 bits per channel, each clamped to 0 … 1 and rounded.
    static func colour(_ c: SIMD3<Double>) -> Colour {
        let byte: (Double) -> Int = { v in Int((min(max(v, 0), 1) * 255).rounded()) }
        return Colour(r: byte(c.x), g: byte(c.y), b: byte(c.z))
    }

    /// The point check of one kind: `described` must list exactly `expected` (index and CPU pixel) in order, each
    /// position within one quantum. Appends the misses, named by `kind`.
    static func pointMisses(_ kind: String, described: [Point], expected: [(index: Int, pixel: Vec2?)], quantum: Int,
                            into misses: inout [String]) {
        guard described.count == expected.count else {
            misses.append("\(described.count) \(kind)s described, CPU reference \(expected.count)")
            return
        }
        for k in 0..<expected.count {
            let point: Point = described[k]
            if point.index != expected[k].index || !agrees(point.position, expected[k].pixel, quantum: quantum) {
                misses.append("\(kind) \(expected[k].index): described \(point)")
            }
        }
    }

    /// The description check: the frame's identity, size, tick, tick mark and tier detail, the field colour, and every
    /// star node centre, target centre and distinct loop cell centre against the CPU reference of `golden`. Returns
    /// the misses.
    static func descriptionMisses(_ described: Description, frame: ChronoConstellatorGolden.Frame,
                                  golden: ChronoConstellatorSceneSnapshot) -> [String] {
        typealias Geometry = ChronoConstellatorSceneGeometry
        var misses: [String] = []
        let width: Int = ChronoConstellatorTest.width
        let height: Int = ChronoConstellatorTest.height
        let tier: ChronoConstellatorTier = ChronoConstellatorTier.of(frame.tier)
        let quantum: Int = described.quantum
        if described.name != frame.name { misses.append("name \(described.name)") }
        if described.level != frame.level || described.tier != frame.tier {
            misses.append("level \(described.level) tier \(described.tier)")
        }
        if described.width != width || described.height != height {
            misses.append("size \(described.width) × \(described.height)")
        }
        if described.tick != golden.tick { misses.append("tick \(described.tick), snapshot \(golden.tick)") }
        if described.ribbonTicks != tier.ribbonTicks || described.segments != tier.segments
            || described.glowShells != tier.glowShells {
            misses.append("tier detail \(described.ribbonTicks)/\(described.segments)/\(described.glowShells)")
        }
        if described.field != colour(ChronoConstellatorPalette.field) { misses.append("field \(described.field)") }
        let u: Double = Geometry.cellSize(golden)
        let length: Double = u > 0 ? Geometry.tickBarLength(golden) / u : 0
        let mark: Double = length * Double(ChronoConstellatorGolden.lengthQuantum)
        if abs(Double(described.tickMark) - mark) > 1 {
            misses.append("tick mark \(described.tickMark), CPU reference \(mark)")
        }
        let cam: ChronoConstellatorCamera = ChronoConstellatorTest.camera(golden, width: width, height: height)
        var stars: [(index: Int, pixel: Vec2?)] = []
        var targets: [(index: Int, pixel: Vec2?)] = []
        var loopCells: Set<Int> = []
        for s in 0..<golden.stars.count {
            let star: Vec2? = Geometry.pixel(Geometry.starCentre(s, golden), camera: cam, width: width, height: height)
            stars.append((s, star))
            let target: Vec2? = Geometry.pixel(Geometry.targetCentre(s, golden), camera: cam, width: width,
                                               height: height)
            targets.append((s, target))
            for cell in golden.stars[s].loop { loopCells.insert(cell) }
        }
        var cells: [(index: Int, pixel: Vec2?)] = []
        for cell in loopCells.sorted() {
            let p: Vec2? = Geometry.pixel(Geometry.cellCentre(cell, golden), camera: cam, width: width, height: height)
            cells.append((cell, p))
        }
        pointMisses("star", described: described.stars, expected: stars, quantum: quantum, into: &misses)
        pointMisses("target", described: described.targets, expected: targets, quantum: quantum, into: &misses)
        pointMisses("loop cell", described: described.cells, expected: cells, quantum: quantum, into: &misses)
        return misses
    }

    /// Pins `frame`'s tier, renders the 1,152 × 768 still at the frame's time, compares the shown snapshot with the
    /// golden one and runs the description check and the feature-353 frame checks of clarification Q3; every issue
    /// names the frame, and the frame checks name the star, target, track cell or corner that failed.
    static func check(_ frame: ChronoConstellatorGolden.Frame, session: ExperienceSession,
                      shell: ChronoConstellatorTest.Shell) throws {
        let width: Int = ChronoConstellatorGolden.width
        let height: Int = ChronoConstellatorGolden.height
        ChronoConstellatorTest.pin(session, shell, tier: frame.tier)
        let rgba: [UInt8] = try ChronoConstellatorTest.still(session, width: width, height: height, time: frame.time)
        let shown: ChronoConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot,
                                                                  "\(frame.name): no snapshot")
        let golden: ChronoConstellatorSceneSnapshot = try ChronoConstellatorGolden.snapshot(frame)
        #expect(shown.time == 0, "\(frame.name): the still's frame time is \(shown.time), not 0")
        #expect(shown.levelNumber == golden.levelNumber, "\(frame.name): level \(shown.levelNumber)")
        #expect(shown.phases == golden.phases, "\(frame.name): the shown phases differ from the golden ones")
        #expect(shown.stars == golden.stars, "\(frame.name): the shown stars differ from the golden ones")
        #expect(shown.tick == golden.tick, "\(frame.name): tick \(shown.tick), golden \(golden.tick)")
        #expect(shown.stage == golden.stage, "\(frame.name): stage \(shown.stage), golden \(golden.stage)")
        #expect(shown == golden, "\(frame.name): the shown snapshot differs from the golden one")
        #expect(shell.presenter.fallbackReason == nil, "\(frame.name): \(shell.presenter.fallbackReason ?? "")")
        #expect(shell.presenter.tierLog.last?.tier == frame.tier, "\(frame.name): drawn tier")
        let described: Description = try Self.description(frame)
        let misses: [String] = Self.descriptionMisses(described, frame: frame, golden: golden)
        #expect(misses.isEmpty, "\(frame.name): description \(misses.prefix(6))")
        ChronoConstellatorTest.checkFrame(rgba, snapshot: golden, width: width, height: height, frame.name)
        let stars = ChronoConstellatorTest.starMisses(rgba, snapshot: golden, width: width, height: height)
        let rings = ChronoConstellatorTest.ringMisses(rgba, snapshot: golden, width: width, height: height)
        let tracks = ChronoConstellatorTest.trackMisses(rgba, snapshot: golden, width: width, height: height)
        print("chrono-constellator golden \(frame.name): tick \(golden.tick), stars checked \(stars.checked), "
              + "ring samples checked \(rings.checked), track cells checked \(tracks.checked), "
              + "\(described.cells.count) loop cells described")
    }

    @Test func theGoldenSetHasSixteenFrames() {
        let frames: [ChronoConstellatorGolden.Frame] = ChronoConstellatorGolden.frames
        #expect(frames.count == 16)
        #expect(ChronoConstellatorGolden.width == ChronoConstellatorTest.width)
        #expect(ChronoConstellatorGolden.height == ChronoConstellatorTest.height)
        var heroes: Int = 0
        for frame in frames where frame.name == "hero" {
            heroes += 1
            #expect(frame.level == 1 && frame.tier == 0 && frame.actions.count == 2)
            #expect(frame.actions.last == .step(ChronoConstellatorGolden.ticks), "hero: the frame ends with step(6)")
        }
        #expect(heroes == 1)
        for frame in frames { #expect(frame.time == 0, "\(frame.name): time \(frame.time)") }
        for level in ChronoConstellatorGolden.levels {
            let tiers: [ChronoConstellatorGolden.Frame] = Self.tierFrames(level: level)
            #expect(tiers.count == 3, "level \(level) has three tier frames")
            let actions: [ChronoConstellatorAction] = tiers.first?.actions ?? []
            #expect(actions.last == .step(ChronoConstellatorGolden.ticks),
                    "level \(level): the frame ends with step(6)")
            var steps: Int = 0
            for action in actions {
                if case .step = action { steps += 1 }
            }
            #expect(steps == 1, "level \(level): the witness's own steps are left out")
            #expect(actions.count > 1, "level \(level): the witness has phase changes")
        }
        var names: Set<String> = []
        for frame in frames { names.insert(frame.name) }
        #expect(names.count == 16, "frame names are unique")
    }

    @Test(arguments: [1, 21, 41, 61, 81])
    func everyTierFrameOfTheLevelMatchesItsDescription(level: Int) async throws {
        let frames: [ChronoConstellatorGolden.Frame] = Self.tierFrames(level: level)
        #expect(frames.count == 3, "level \(level): \(frames.count) tier frames")
        guard let first: ChronoConstellatorGolden.Frame = frames.first else { return }
        let session = ExperienceSession()
        defer { session.close() }
        let shell: ChronoConstellatorTest.Shell = try await Self.open(session, level: level)
        // The three tier frames share their actions: apply them once, then draw each tier.
        Self.apply(first.actions, to: shell, first.name)
        for frame in frames {
            #expect(frame.actions == first.actions, "\(frame.name): the tier frames share their actions")
            try Self.check(frame, session: session, shell: shell)
        }
        session.qualityPin = 0
    }

    @Test func theHeroFrameMatchesItsDescription() async throws {
        var heroes: [ChronoConstellatorGolden.Frame] = []
        for frame in ChronoConstellatorGolden.frames where frame.name == "hero" { heroes.append(frame) }
        let hero: ChronoConstellatorGolden.Frame = try #require(heroes.first, "no hero frame in the golden set")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: ChronoConstellatorTest.Shell = try await Self.open(session, level: hero.level)
        let before: String = try ChronoConstellatorTest.digest(shell)
        Self.apply(hero.actions, to: shell, hero.name)
        let after: String = try ChronoConstellatorTest.digest(shell)
        #expect(after != before, "the hero actions change the digest")
        try Self.check(hero, session: session, shell: shell)
        session.qualityPin = 0
    }
}
#endif
