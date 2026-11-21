// WaveKnotKeeperRegressionGoldenFrameTests — feature 328 (R02-G03-08) T-R02G0308-005 (FR-R02G0308-004;
// SC-R02G0308-003). Through the one app's session host, each of the 16 code-only golden frames of
// `WaveKnotKeeperGolden.frames` (certified levels 1, 21, 41, 61 and 81 at tiers 0, 1 and 2 at presentation time 0, plus
// the hero frame: level 1 after the hero scenario's one move, tier 0) is drawn off screen at the frame-check size
// 1,152 × 768 of `WaveKnotKeeperTest` (clarification Q3). The snapshot the presenter shows equals
// `WaveKnotKeeperGolden.snapshot(frame)` (level, points, gates, target, crossings, stage, no selection, time 0), so the
// rendered frame is the described one; the frame's description (`WaveKnotKeeperGolden.description(frame)`, decoded
// here) names the drawn tier's detail and every projected control point, segment midpoint, gate centre and drawn
// crossing, and those positions agree with the CPU reference within one 1/8-pixel quantum; the picture passes the
// feature-323 frame checks (control points and segment midpoints within 3 px of a pixel 0.15 brighter than night,
// handle centres pearl within 0.15, gate centres tinted towards sapphire, background within 0.05 of night), and every
// described crossing outside a gate lies within 3 px of a lit pixel. Seed s opens level s % 100 + 1, so a frame of
// level L opens at seed L − 1; moves go through the session's action port as `point.move [point, direction index]`.
// One test per level plus the hero test, each well under 10 s. Modelled on `LissajousLabyrinthRegressionGoldenFrameTests`
// (feature 318). Synthetic data, explicit types, plain loops, no sleep, no wall-clock assertion.
#if os(iOS)
import Foundation
import Testing
import WaveKnotKeeperCore
@testable import WaveKnotKeeperExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct WaveKnotKeeperRegressionGoldenFrameTests {
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

    /// A drawn crossing of the description.
    struct Crossing: Decodable, Equatable {
        let first: Int
        let second: Int
        let over: Int
        let position: Position?
    }

    /// The description of one golden frame, decoded from `WaveKnotKeeperGolden.description(_:)`.
    struct Description: Decodable, Equatable {
        let name: String
        let level: Int
        let tier: Int
        let sides: Int
        let cornerSamples: Int
        let glowShells: Int
        let width: Int
        let height: Int
        let quantum: Int
        let night: Colour
        let pearl: Colour
        let sapphire: Colour
        let ember: Colour
        let points: [Position?]
        let midpoints: [Position?]
        let gates: [Position?]
        let crossings: [Crossing]
    }

    /// The golden frames of `level` without moves (its three tiers), in their fixed order.
    static func tierFrames(level: Int) -> [WaveKnotKeeperGolden.Frame] {
        var list: [WaveKnotKeeperGolden.Frame] = []
        for frame in WaveKnotKeeperGolden.frames where frame.level == level && frame.moves.isEmpty {
            list.append(frame)
        }
        return list
    }

    /// Sends `moves` through the session's action port as `point.move [point, direction index]`.
    static func apply(_ moves: [WaveKnotKeeperMove], to shell: WaveKnotKeeperTest.Shell, _ what: String) {
        for move in moves {
            let direction: Int = WaveKnotKeeperExperienceCore.directionOrder.firstIndex(of: move.direction) ?? -1
            #expect(direction >= 0, "\(what): direction \(move.direction) is not in the direction order")
            let values: [Double] = [Double(move.point), Double(direction)]
            let result: ActionResult = shell.handle(control: "point.move", values: values)
            #expect(result == .accepted, "\(what): point.move \(values) gave \(result.code)")
        }
    }

    /// Opens `level` (seed level − 1) and checks that the engine shows it.
    static func open(_ session: ExperienceSession, level: Int) async throws -> WaveKnotKeeperTest.Shell {
        let seed: UInt64 = UInt64(level - 1)
        #expect(WaveKnotKeeperExperienceCore.levelNumber(forSeed: seed) == level)
        let shell: WaveKnotKeeperTest.Shell = try await WaveKnotKeeperTest.open(session, seed: seed)
        #expect(try WaveKnotKeeperTest.core(shell).levelNumber == level)
        return shell
    }

    /// The decoded description of `frame`.
    static func description(_ frame: WaveKnotKeeperGolden.Frame) throws -> Description {
        try JSONDecoder().decode(Description.self, from: try WaveKnotKeeperGolden.description(frame))
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

    /// The description check: the frame's identity, size and tier detail, the colours, and every described position
    /// against the CPU reference of `golden` (points, midpoints, gate centres in `referencePixels` order). Returns the
    /// misses.
    static func descriptionMisses(_ described: Description, frame: WaveKnotKeeperGolden.Frame,
                                  golden: WaveKnotKeeperSceneSnapshot) -> [String] {
        var misses: [String] = []
        let tier: WaveKnotKeeperTier = WaveKnotKeeperTier.of(frame.tier)
        if described.name != frame.name { misses.append("name \(described.name)") }
        if described.level != frame.level || described.tier != frame.tier {
            misses.append("level \(described.level) tier \(described.tier)")
        }
        if described.width != WaveKnotKeeperTest.width || described.height != WaveKnotKeeperTest.height {
            misses.append("size \(described.width) × \(described.height)")
        }
        if described.sides != tier.sides || described.cornerSamples != tier.cornerSamples
            || described.glowShells != tier.glowShells {
            misses.append("tier detail \(described.sides)/\(described.cornerSamples)/\(described.glowShells)")
        }
        let night: SIMD3<Double> = WaveKnotKeeperPalette.night
        let byte: (Double) -> Int = { v in Int((min(max(v, 0), 1) * 255).rounded()) }
        if described.night != Colour(r: byte(night.x), g: byte(night.y), b: byte(night.z)) {
            misses.append("night \(described.night)")
        }
        let reference: [Vec2?] = WaveKnotKeeperTest.referencePixels(golden)
        let positions: [Position?] = described.points + described.midpoints + described.gates
        if described.points.count != golden.points.count || described.gates.count != golden.gates.count
            || positions.count != reference.count {
            misses.append("counts: \(described.points.count) points, \(described.midpoints.count) midpoints, "
                          + "\(described.gates.count) gates; reference \(reference.count)")
            return misses
        }
        for index in 0..<positions.count where !agrees(positions[index], reference[index], quantum: described.quantum) {
            misses.append("position \(index): described \(String(describing: positions[index])), reference "
                          + "\(String(describing: reference[index]))")
        }
        if described.crossings.count != golden.crossings.count {
            misses.append("\(described.crossings.count) crossings, snapshot \(golden.crossings.count)")
        }
        return misses
    }

    /// The crossing check: every described crossing with a position outside the gates' projected boxes has, within
    /// 3 px, a pixel whose luminance exceeds night's by at least 0.15. Returns the crossings checked and the misses.
    static func crossingMisses(_ rgba: [UInt8], described: Description, golden: WaveKnotKeeperSceneSnapshot)
        -> (checked: Int, misses: [String]) {
        let width: Int = described.width
        let height: Int = described.height
        let cam: WaveKnotKeeperCamera = WaveKnotKeeperTest.camera(golden, width: width, height: height)
        let rects = WaveKnotKeeperTest.gateRects(golden, camera: cam, width: width, height: height)
        let threshold: Double = WaveKnotKeeperTest.nightLuminance + WaveKnotKeeperTest.litMargin
        var checked: Int = 0
        var misses: [String] = []
        for crossing in described.crossings {
            guard let q = crossing.position else { continue }
            let p = Vec2(Double(q.x) / Double(described.quantum), Double(q.y) / Double(described.quantum))
            if WaveKnotKeeperTest.insideAny(p, rects) { continue }
            checked += 1
            let found: Bool = WaveKnotKeeperTest.anyPixel(rgba, near: p.x, p.y, radius: WaveKnotKeeperTest.pointRadius,
                                                          width: width, height: height) { c in
                WaveKnotKeeperTest.luminance(c) >= threshold
            }
            if !found {
                misses.append(String(format: "crossing %ld×%ld at (%.1f, %.1f)", crossing.first, crossing.second,
                                     p.x, p.y))
            }
        }
        return (checked, misses)
    }

    /// Pins `frame`'s tier, renders the 1,152 × 768 still at the frame's time, compares the shown snapshot with the
    /// golden one and runs the description check, the frame checks of clarification Q3 and the crossing check.
    static func check(_ frame: WaveKnotKeeperGolden.Frame, session: ExperienceSession,
                      shell: WaveKnotKeeperTest.Shell) throws {
        let width: Int = WaveKnotKeeperGolden.width
        let height: Int = WaveKnotKeeperGolden.height
        WaveKnotKeeperTest.pin(session, shell, tier: frame.tier)
        let rgba: [UInt8] = try WaveKnotKeeperTest.still(session, width: width, height: height, time: frame.time)
        let shown: WaveKnotKeeperSceneSnapshot = try #require(shell.presenter.lastSnapshot, "\(frame.name): no snapshot")
        let golden: WaveKnotKeeperSceneSnapshot = try WaveKnotKeeperGolden.snapshot(frame)
        #expect(shown.time == 0, "\(frame.name): the still's frame time is \(shown.time), not 0")
        #expect(shown.levelNumber == golden.levelNumber, "\(frame.name): level \(shown.levelNumber)")
        #expect(shown.points == golden.points, "\(frame.name): the shown points differ from the golden ones")
        #expect(shown.gates == golden.gates, "\(frame.name): the shown gates differ from the golden ones")
        #expect(shown.target == golden.target, "\(frame.name): the shown target differs from the golden one")
        #expect(shown.crossings == golden.crossings, "\(frame.name): the shown crossings differ from the golden ones")
        #expect(shown.stage == golden.stage, "\(frame.name): stage \(shown.stage), golden \(golden.stage)")
        #expect(shown.selected == nil, "\(frame.name): selection \(String(describing: shown.selected))")
        #expect(shown == golden, "\(frame.name): the shown snapshot differs from the golden one")
        #expect(shell.presenter.fallbackReason == nil, "\(frame.name): \(shell.presenter.fallbackReason ?? "")")
        #expect(shell.presenter.tierLog.last?.tier == frame.tier, "\(frame.name): drawn tier")
        let described: Description = try Self.description(frame)
        let misses: [String] = Self.descriptionMisses(described, frame: frame, golden: golden)
        #expect(misses.isEmpty, "\(frame.name): description \(misses.prefix(6))")
        WaveKnotKeeperTest.checkFrame(rgba, snapshot: golden, width: width, height: height, frame.name)
        let crossings = Self.crossingMisses(rgba, described: described, golden: golden)
        #expect(crossings.misses.isEmpty, "\(frame.name): \(crossings.misses.prefix(6))")
        print("wave-knot-keeper golden \(frame.name): \(golden.points.count) points, \(golden.gates.count) gates, "
              + "crossings checked \(crossings.checked) of \(described.crossings.count)")
    }

    @Test func theGoldenSetHasSixteenFrames() throws {
        let frames: [WaveKnotKeeperGolden.Frame] = WaveKnotKeeperGolden.frames
        #expect(frames.count == 16)
        #expect(WaveKnotKeeperGolden.width == WaveKnotKeeperTest.width)
        #expect(WaveKnotKeeperGolden.height == WaveKnotKeeperTest.height)
        var heroes: Int = 0
        for frame in frames where frame.name == "hero" {
            heroes += 1
            #expect(frame.level == 1 && frame.tier == 0 && !frame.moves.isEmpty)
        }
        #expect(heroes == 1)
        for frame in frames { #expect(frame.time == 0, "\(frame.name): time \(frame.time)") }
        for level in WaveKnotKeeperGolden.levels {
            #expect(Self.tierFrames(level: level).count == 3, "level \(level) has three tier frames")
        }
        var names: Set<String> = []
        for frame in frames { names.insert(frame.name) }
        #expect(names.count == 16, "frame names are unique")
    }

    @Test(arguments: [1, 21, 41, 61, 81])
    func everyTierFrameOfTheLevelMatchesItsDescription(level: Int) async throws {
        let frames: [WaveKnotKeeperGolden.Frame] = Self.tierFrames(level: level)
        #expect(frames.count == 3, "level \(level): \(frames.count) tier frames")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: WaveKnotKeeperTest.Shell = try await Self.open(session, level: level)
        for frame in frames {
            Self.apply(frame.moves, to: shell, frame.name)
            try Self.check(frame, session: session, shell: shell)
        }
        session.qualityPin = 0
    }

    @Test func theHeroFrameMatchesItsDescription() async throws {
        var heroes: [WaveKnotKeeperGolden.Frame] = []
        for frame in WaveKnotKeeperGolden.frames where frame.name == "hero" { heroes.append(frame) }
        let hero: WaveKnotKeeperGolden.Frame = try #require(heroes.first, "no hero frame in the golden set")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: WaveKnotKeeperTest.Shell = try await Self.open(session, level: hero.level)
        let before: String = try WaveKnotKeeperTest.digest(shell)
        Self.apply(hero.moves, to: shell, hero.name)
        #expect(try WaveKnotKeeperTest.digest(shell) != before, "the hero move changes the digest")
        #expect(try WaveKnotKeeperTest.core(shell).play.spent == hero.moves.count, "the hero move is spent")
        try Self.check(hero, session: session, shell: shell)
        session.qualityPin = 0
    }
}
#endif
