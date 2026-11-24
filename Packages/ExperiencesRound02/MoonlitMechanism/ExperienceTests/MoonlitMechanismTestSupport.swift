// MoonlitMechanismTestSupport — feature 433 (R02-G14-03) T-R02G1403-006 (FR-R02G1403-001 … 007; SC-R02G1403-001, 002;
// clarifications Q1–Q5). Shared helpers of the Moonlit Mechanism experience tests, following Acoustic Constellator's
// harness (feature 423): opening the experience through the one app's session host (seed `s` prepares certified level
// `s % 100 + 1`; a session without a quality pin is pinned to level 0), issuing kernel actions through the shell,
// drawing live frames, drawing an off-screen still (RGBA8, rows top-down, the orientation of the Core's CPU projection
// `MoonlitMechanismSceneGeometry.project`, origin top left, y down, scaled here to pixels), the engine digest, the
// frame checks of clarification Q3 at 1,152 × 768, and a short search of the kernel's rules for set-ups that fail a run
// in a chosen way (a jam, a forbidden shadow, a failing key frame).
//
// The presenter hands the snapshot the seconds since the play last changed, and neither program has a time input, so a
// still drawn at frame time 0 shows presentation time 0.
//
// The CPU reference: the centre of every cast cell of the shown key frame, every gear's rim check point
// (`gearRimCheckPoint`: the tooth-zero notch's angle plus half a tooth, 0.2 s inside R), the first key-frame card, the
// first alignment pip and the first moves bar, projected through the camera at the target's aspect. A point is checked
// only when it projects into the picture at least 6 px from every element drawn over it that could hide the cue
// (elements drawn before it lie under it):
//   - a cast cell's centre: at least 6 px inside its own ink square (0.92 s); outside or inside every target border
//     (the band from 0.42 s to 0.5 s of a target cell), every dotted missing band (0.28 s … 0.38 s) and a forbidden
//     failure's outline (0.04 s … 0.14 s outside its cell) by 6 px; 6 px outside every forbidden cell (a forbidden
//     cast cell is left out: its cross lies on the centre); 6 px clear of every gear's opaque ring, from the body's
//     edge R − 0.3 s to the tooth tips R + 0.35 s (plus the jam outline's 0.1 s for a jammed pair), so the notch, the
//     rim and a jam outline are clear; 6 px outside the lamp, its two glow shells and its ladder. The translucent
//     layers drawn over the ink — every gear body holding the centre, at its fresnel shade at the farthest pixel within
//     6 px, and every blade spoke within 6 px at its brightest sheen, in painter's order (opaque pre-mixed colours in
//     the unlit fallback) — are composed on the CPU (`coveredLuminance`, blending is linear in the stored channels),
//     and the centre is measured only when that bound stays 0.27 below the paper. Within 3 px of the centre a pixel
//     is darker than the paper by at least 0.25 in luminance. A stray cell's hatching (#7A3A5A, 0.29) is a cast cell's
//     own pattern and darker than the bound needs, so stray cells are measured too;
//   - a gear's rim: the check point (half a tooth past the tooth-zero notch, 0.2 s inside R) or, when that is not
//     clear, the same radius 1.5, 2.5, … teeth past the notch: 6 px from every gear's notch strip (ink) and the lamp
//     with its glow and ladder (lunar blue). Everything else drawn over a rim — later gears' bodies, rims and blades,
//     a jam outline, the card glow — is red above blue by more than 0.08 itself. Within 3 px a pixel has red above
//     blue by at least 0.08 (the rim #E2C277 has 0.42, bevelled at most by a quarter);
//   - the first moves bar: 6 px outside the lamp (every other layer that can lie over it is 0.1 from the paper too);
//     within 3 px of its centre a pixel at least 0.1 from the paper in luminance (lit #E2C277 or unlit #2A2A38);
//   - the two probe corners (0.02, 0.02) and (0.98, 0.98) of the view are within 0.05 per channel of the night.
// Luminance is the Rec. 709 weighting of the stored 0 … 1 channel values. The gauges lie below the wall (y ≤ −0.14
// against the wall's lowest edge 0.05), so they are no obstacle for a cell. Positions come from the presenter's
// `lastSnapshot` (the snapshot it drew). Short runs only (no sleep, no wall-clock assertion).
//
// The checked levels are the plan's catalog levels 1, 21, 41, 61 and 81 (seeds 0, 20, 40, 60, 80).
#if os(iOS)
import CoreGraphics
import Foundation
import MoonlitMechanismCore
import Testing
import UIKit
@testable import MoonlitMechanismExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the point checks of one frame found.
struct MoonlitMechanismCheckReport {
    /// The cast-cell centres measured and those left out by the 6-pixel clearance.
    var cellChecked: Int = 0
    var cellExcluded: Int = 0
    /// The rim check points measured and those left out by the 6-pixel clearance.
    var rimChecked: Int = 0
    var rimExcluded: Int = 0
    /// Every failed check, in words.
    var misses: [String] = []
}

/// How a frame was drawn, as far as the reference needs it: lit by the clockwork program, or the unlit fallback whose
/// gear bodies are opaque.
struct MoonlitMechanismDrawMode: Equatable {
    var fallback: Bool

    /// The real scene (every tier: the tiers move nothing the checks read).
    static let lit = MoonlitMechanismDrawMode(fallback: false)
    /// The unlit fallback (the level-2 geometry with opaque, pre-mixed gear bodies).
    static let fallback = MoonlitMechanismDrawMode(fallback: true)

    /// The most gear bodies a measured cast cell may lie under.
    var maxBodies: Int { fallback ? 0 : 1 }
}

/// A kind of failed run whose outline the tests look for.
enum MoonlitMechanismFailureKind: String {
    /// A mesh out of alignment: the pair's meshing teeth are outlined.
    case jammed
    /// A key frame shadows a forbidden cell: the cell is outlined.
    case forbidden
    /// A required key frame misses target cells or strays beyond the allowance: its card is outlined.
    case card

    /// Whether the run outcome `outcome` is of this kind.
    func matches(_ outcome: MoonlitMechanismOutcome) -> Bool {
        switch outcome {
        case .jammed: self == .jammed
        case .forbidden: self == .forbidden
        case .missing, .stray: self == .card
        case .won: false
        }
    }

    /// Whether the play's failure `failure` is of this kind.
    func matches(_ failure: MoonlitMechanismFailure) -> Bool {
        switch failure {
        case .jammed: self == .jammed
        case .forbidden: self == .forbidden
        case .missing, .stray: self == .card
        case .budget: false
        }
    }
}

/// The projected obstacles of one snapshot on one target (pixels, y down).
struct MoonlitMechanismObstacles {
    /// Per gear: the hull of the disc out to the tooth tips (plus the jam outline's reach for a jammed pair).
    var gearOuter: [[SIMD2<Double>]] = []
    /// Per gear: the projected centre and the body's radius in pixels.
    var gearCentres: [SIMD2<Double>] = []
    var innerRadii: [Double] = []
    /// Per gear: the hulls of its solid blade spokes at the drawn phases.
    var blades: [[[SIMD2<Double>]]] = []
    /// The gears in painter's order.
    var gearOrder: [Int] = []
    /// Per gear: the hull of the translucent body (inside the rim band).
    var gearInner: [[SIMD2<Double>]] = []
    /// Per gear: the notch's axis and half width.
    var notchAxes: [[SIMD2<Double>]] = []
    var notchHalves: [Double] = []
    /// The lamp with its glow shells and the ladder.
    var lamp: [SIMD2<Double>] = []
    /// Per target cell: the outer and inner squares of its border.
    var targetOuter: [[SIMD2<Double>]] = []
    var targetInner: [[SIMD2<Double>]] = []
    /// Per missing cell: the outer and inner squares of its dotted band.
    var missingOuter: [[SIMD2<Double>]] = []
    var missingInner: [[SIMD2<Double>]] = []
    /// The forbidden cells and their squares.
    var forbiddenCells: [Int] = []
    var forbiddenSquares: [[SIMD2<Double>]] = []
    /// A forbidden failure's outline (empty without one).
    var brokenOuter: [SIMD2<Double>] = []
    var brokenInner: [SIMD2<Double>] = []
    /// Per key-frame card: its rectangle grown by two glow shells and the failure outline.
    var cards: [[SIMD2<Double>]] = []
    /// The paper wall.
    var paper: [SIMD2<Double>] = []
}

/// Building, opening, drawing and measuring Moonlit Mechanism.
@MainActor
enum MoonlitMechanismTest {
    typealias Geometry = MoonlitMechanismSceneGeometry
    typealias Palette = MoonlitMechanismPalette
    typealias Snapshot = MoonlitMechanismSceneSnapshot
    typealias Shell = ExperienceShell<MoonlitMechanismPresenter>

    /// The experience id `r02-g14.moonlit-mechanism`.
    static var id: ExperienceID {
        MoonlitMechanismExperience.id ?? ExperienceID(rawValue: "r02-g14.unknown")!
    }

    /// The frame-check size of clarification Q3, aspect 1.5.
    static let width: Int = 1_152
    static let height: Int = 768
    /// The seeds of the checked levels 1, 21, 41, 61 and 81 (seed = level − 1).
    static let seeds: [UInt64] = [0, 20, 40, 60, 80]
    /// The search radius (pixels) of the point checks.
    static let pointRadius: Double = 3
    /// The clearance (pixels) of every checked point from every other element.
    static let clearance: Double = 6
    /// A cast cell's centre is darker than the paper by at least this luminance.
    static let castMargin: Double = 0.25
    /// A rim point's red above blue.
    static let rimHue: Double = 0.08
    /// The first moves bar's luminance difference from the paper.
    static let movesMargin: Double = 0.1
    /// The per-channel bound of the night backdrop.
    static let backgroundTolerance: Double = 0.05
    /// The night probe points (fractions of the view, origin top left).
    static let backgroundPoints: [(x: Double, y: Double)] = [(0.02, 0.02), (0.98, 0.98)]
    /// The sides of the polygons standing for circles.
    static let circleSides: Int = 64
    /// The red-minus-green rise of an outline pixel over the frame before the failure.
    static let outlineRise: Double = 0.05

    /// Opens Moonlit Mechanism with `seed` in `session` through the factory, lays the view out at `size` points and
    /// draws one frame. A session without a quality pin is pinned to level 0. `configure` runs on the presenter before
    /// its first `setup` (the fallback seam).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false, size: CGSize = CGSize(width: 48, height: 32),
                     configure: ((MoonlitMechanismPresenter) -> Void)? = nil) async throws -> Shell {
        let id: ExperienceID = self.id
        var made: Shell?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: seed) {
            let shell: Shell = MoonlitMechanismExperience.make(id: id, reduceMotion: reduceMotion,
                                                               reduceFlashing: reduceFlashing)
            configure?(shell.presenter)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        #expect(opened == .running)
        let view = try #require(session.renderHost?.view)
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutIfNeeded()
        let shell: Shell = try #require(made)
        try draw(session)
        return shell
    }

    /// Draws `count` live frames of `session`.
    static func draw(_ session: ExperienceSession, frames count: Int = 1) throws {
        let host = try #require(session.renderHost)
        var drawn: Int = 0
        for _ in 0..<count where host.renderOneFrame(present: false) { drawn += 1 }
        #expect(drawn == count)
    }

    /// An off-screen still of `session` at `width` × `height` and frame time `time` seconds, RGBA8 rows top-down.
    static func still(_ session: ExperienceSession, width: Int = width, height: Int = height,
                      time: Double = 0) throws -> [UInt8] {
        let host = try #require(session.renderHost)
        return try host.renderOffscreen(width: width, height: height, time: time).rgba
    }

    /// The engine digest of `shell`'s state (hex).
    static func digest(_ shell: Shell) throws -> String {
        try shell.engine.digest().hex
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> MoonlitMechanismExperienceCore {
        try #require(shell.engine.core)
    }

    /// Pins `session` to quality level `tier` and checks that the engine took it.
    static func pin(_ session: ExperienceSession, _ shell: Shell, tier: Int,
                    sourceLocation: SourceLocation = #_sourceLocation) {
        session.qualityPin = tier
        #expect(shell.engine.qualityTier == tier, "pinned tier \(tier)", sourceLocation: sourceLocation)
    }

    // MARK: Actions

    /// The control and values that issue the kernel action `action` through the shell.
    nonisolated static func control(_ action: MoonlitMechanismAction) -> (control: String, values: [Double]) {
        switch action {
        case let .turn(step):
            ("handle.turn", [Double(step)])
        case let .reseat(gear, step):
            ("gear.reseat", [Double(gear), Double(step)])
        case let .lamp(step):
            ("lamp.step", [Double(step)])
        case .run:
            ("machine.run", [])
        }
    }

    /// The host action of `action` (step 0).
    nonisolated static func experienceAction(_ action: MoonlitMechanismAction) -> ExperienceAction {
        let issued = control(action)
        return ExperienceAction(control: issued.control, values: issued.values, step: 0)
    }

    /// The certified solution of level `number`: its plan's turns, re-seats in gear order, lamp steps, then one run.
    nonisolated static func certifiedActions(_ number: Int) throws -> [MoonlitMechanismAction] {
        MoonlitMechanismSolver.actions(try MoonlitMechanismExperienceCore.generated(number: number).plan)
    }

    /// The certified moves of level `number`: the solution without its run.
    nonisolated static func certifiedMoves(_ number: Int) throws -> [MoonlitMechanismAction] {
        var result: [MoonlitMechanismAction] = []
        for action in try certifiedActions(number) where action != .run { result.append(action) }
        return result
    }

    /// Issues `actions` through the shell, each expected to be accepted; returns how many were.
    @discardableResult
    static func issue(_ shell: Shell, _ actions: [MoonlitMechanismAction],
                      sourceLocation: SourceLocation = #_sourceLocation) -> Int {
        var accepted: Int = 0
        for (index, action) in actions.enumerated() {
            let issued = control(action)
            let result: ActionResult = shell.handle(control: issued.control, values: issued.values)
            #expect(result == .accepted, "action \(index) \(issued.control) \(issued.values): \(result.code)",
                    sourceLocation: sourceLocation)
            if result == .accepted { accepted += 1 }
        }
        return accepted
    }

    /// The opening core of level `number` with `actions` applied (no host): the CPU reference of that state.
    static func coreAfter(_ number: Int, _ actions: [MoonlitMechanismAction]) throws -> MoonlitMechanismExperienceCore {
        var core: MoonlitMechanismExperienceCore = try MoonlitMechanismExperienceCore.opening(number: number)
        for action in actions {
            let result: ActionResult = core.apply(experienceAction(action))
            #expect(result == .accepted, "level \(number) \(action): \(result.code)")
        }
        return core
    }

    /// Up to `limit` shortest scripts on level `number` (at most `maxDepth` turns, re-seats or lamp steps, then a run)
    /// whose run fails as `kind` says, found breadth first with the kernel's rules (the play judges a run exactly as
    /// `MoonlitMechanismLevel.run` does).
    nonisolated static func failingScripts(_ kind: MoonlitMechanismFailureKind, number: Int, maxDepth: Int,
                                           limit: Int) throws -> [[MoonlitMechanismAction]] {
        typealias Position = MoonlitMechanismRules.Position
        let level: MoonlitMechanismLevel = try MoonlitMechanismExperienceCore.level(number: number)
        let rules = MoonlitMechanismRules(level: level)
        var frontier: [(state: Position, actions: [MoonlitMechanismAction])] = [(rules.initialState, [])]
        var seen: Set<Position> = []
        seen.insert(Position(phases: rules.initialState.phases, height: rules.initialState.height, actionsSpent: 0,
                             outcome: .playing))
        var found: [[MoonlitMechanismAction]] = []
        for depth in 0...maxDepth {
            var next: [(state: Position, actions: [MoonlitMechanismAction])] = []
            for item in frontier {
                guard item.state.outcome == .playing, item.state.actionsSpent < level.budget else { continue }
                let outcome: MoonlitMechanismOutcome = level.run(phases: item.state.phases,
                                                                 height: item.state.height).outcome
                if kind.matches(outcome) {
                    found.append(item.actions + [.run])
                    if found.count >= limit { return found }
                }
                guard depth < maxDepth else { continue }
                for move in rules.moves(in: item.state) where move != .run {
                    guard let moved = rules.apply(move, to: item.state), moved.outcome == .playing,
                          moved.actionsSpent < level.budget else { continue }
                    let key = Position(phases: moved.phases, height: moved.height, actionsSpent: 0,
                                       outcome: .playing)
                    if seen.insert(key).inserted { next.append((moved, item.actions + [move])) }
                }
            }
            frontier = next
        }
        return found
    }

    /// The first script over `candidates` (level numbers) failing as `kind` whose outline has at least three clear
    /// sample points on the check target: the level, the actions (ending with the run) and the samples.
    static func failureCase(_ kind: MoonlitMechanismFailureKind, candidates: [Int], maxDepth: Int)
        throws -> (number: Int, actions: [MoonlitMechanismAction], samples: [SIMD2<Double>])? {
        for number in candidates {
            for script in try failingScripts(kind, number: number, maxDepth: maxDepth, limit: 8) {
                let core: MoonlitMechanismExperienceCore = try coreAfter(number, script)
                guard let failure = core.play.failure, kind.matches(failure) else { continue }
                let samples: [SIMD2<Double>] = failureSamples(kind, core.snapshot(time: 0))
                if samples.count >= 3 { return (number, script, samples) }
            }
        }
        return nil
    }

    // MARK: Pixels

    /// The colour (0 … 1 per channel) of pixel (`x`, `y`) of a top-down RGBA8 picture `width` pixels wide.
    nonisolated static func colour(_ rgba: [UInt8], x: Int, y: Int, width: Int) -> SIMD3<Double> {
        let i: Int = (y * width + x) * 4
        return SIMD3<Double>(Double(rgba[i]) / 255, Double(rgba[i + 1]) / 255, Double(rgba[i + 2]) / 255)
    }

    /// The Rec. 709 luminance of the 0 … 1 channel values of `c`.
    nonisolated static func luminance(_ c: SIMD3<Double>) -> Double {
        0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z
    }

    /// The largest per-channel difference of `a` and `b`.
    nonisolated static func channelDistance(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        Swift.max(Swift.abs(a.x - b.x), Swift.abs(a.y - b.y), Swift.abs(a.z - b.z))
    }

    /// The luminance of the paper.
    static var paperLuminance: Double { luminance(Palette.paper) }

    /// Whether `c` is a shadow pixel: darker than the paper by at least 0.25 in luminance.
    static func isShadow(_ c: SIMD3<Double>) -> Bool {
        paperLuminance - luminance(c) >= castMargin
    }

    /// Whether `c` is a gold rim pixel: red above blue by at least 0.08.
    static func isGold(_ c: SIMD3<Double>) -> Bool {
        c.x - c.z >= rimHue
    }

    /// Whether `c` is at least 0.1 from the paper in luminance.
    static func isOffPaper(_ c: SIMD3<Double>) -> Bool {
        Swift.abs(luminance(c) - paperLuminance) >= movesMargin
    }

    /// The number of pixels farther than `tolerance` per channel from the night.
    static func nonNightPixels(_ rgba: [UInt8], tolerance: Double = 0.05) -> Int {
        var count: Int = 0
        var i: Int = 0
        while i + 3 < rgba.count {
            let c = SIMD3<Double>(Double(rgba[i]) / 255, Double(rgba[i + 1]) / 255, Double(rgba[i + 2]) / 255)
            if channelDistance(c, Palette.night) > tolerance { count += 1 }
            i += 4
        }
        return count
    }

    /// The number of pixels whose blue fell by at least `drop` from `before` to `after` (same size).
    static func bluerDrops(_ after: [UInt8], _ before: [UInt8], drop: Int = 2) -> Int {
        guard after.count == before.count else { return 0 }
        var count: Int = 0
        var i: Int = 2
        while i < after.count {
            if Int(before[i]) - Int(after[i]) >= drop { count += 1 }
            i += 4
        }
        return count
    }

    /// Whether some pixel whose centre lies within `radius` of `p` passes `test`.
    static func anyPixel(_ rgba: [UInt8], near p: SIMD2<Double>, radius: Double, width: Int, height: Int,
                         where test: (SIMD3<Double>) -> Bool) -> Bool {
        let reach: Int = Int(radius.rounded(.up)) + 1
        let cx: Int = Int(p.x.rounded(.down))
        let cy: Int = Int(p.y.rounded(.down))
        for y in (cy - reach)...(cy + reach) {
            guard y >= 0, y < height else { continue }
            for x in (cx - reach)...(cx + reach) {
                guard x >= 0, x < width else { continue }
                let dx: Double = Double(x) + 0.5 - p.x
                let dy: Double = Double(y) + 0.5 - p.y
                guard dx * dx + dy * dy <= radius * radius else { continue }
                if test(colour(rgba, x: x, y: y, width: width)) { return true }
            }
        }
        return false
    }

    /// Whether some pixel within `radius` of `p` rose in red minus green by at least `rise` from `before` to `after`.
    static func anyRise(_ after: [UInt8], _ before: [UInt8], near p: SIMD2<Double>, radius: Double, rise: Double,
                        width: Int, height: Int) -> Bool {
        let reach: Int = Int(radius.rounded(.up)) + 1
        let cx: Int = Int(p.x.rounded(.down))
        let cy: Int = Int(p.y.rounded(.down))
        for y in (cy - reach)...(cy + reach) {
            guard y >= 0, y < height else { continue }
            for x in (cx - reach)...(cx + reach) {
                guard x >= 0, x < width else { continue }
                let dx: Double = Double(x) + 0.5 - p.x
                let dy: Double = Double(y) + 0.5 - p.y
                guard dx * dx + dy * dy <= radius * radius else { continue }
                let a: SIMD3<Double> = colour(after, x: x, y: y, width: width)
                let b: SIMD3<Double> = colour(before, x: x, y: y, width: width)
                if (a.x - a.y) - (b.x - b.y) >= rise { return true }
            }
        }
        return false
    }

    /// How many of `points` have, within 3 px, a pixel that rose in red minus green by ``outlineRise`` from `before`
    /// to `after` (the broken outline #FF6B4A, red minus green 0.58, drawn over what was there).
    static func outlineHits(_ after: [UInt8], _ before: [UInt8], _ points: [SIMD2<Double>], width: Int = width,
                            height: Int = height) -> Int {
        guard after.count == width * height * 4, before.count == after.count else { return 0 }
        var hits: Int = 0
        for p in points where anyRise(after, before, near: p, radius: pointRadius, rise: outlineRise, width: width,
                                      height: height) {
            hits += 1
        }
        return hits
    }

    /// The colour of the pixel that holds `p`, clamped to the picture.
    static func centre(_ rgba: [UInt8], _ p: SIMD2<Double>, width: Int = width, height: Int = height) -> SIMD3<Double> {
        let x: Int = Swift.min(Swift.max(Int(p.x.rounded(.down)), 0), width - 1)
        let y: Int = Swift.min(Swift.max(Int(p.y.rounded(.down)), 0), height - 1)
        return colour(rgba, x: x, y: y, width: width)
    }

    /// The pixel of the view fraction (`fx`, `fy`) (origin top left), as `FrameChecks` picks it.
    static func pixelAtFraction(_ rgba: [UInt8], _ fx: Double, _ fy: Double, width: Int,
                                height: Int) -> (x: Int, y: Int, colour: SIMD3<Double>) {
        let x: Int = Swift.min(width - 1, Int(fx * Double(width)))
        let y: Int = Swift.min(height - 1, Int(fy * Double(height)))
        return (x, y, colour(rgba, x: x, y: y, width: width))
    }

    /// A top-down still turned into the bottom-up rows `FrameChecks` reads (as `RenderHost.readPixels` gives them).
    static func bottomUp(_ still: [UInt8], width: Int, height: Int) -> [UInt8] {
        let row: Int = width * 4
        var rgba: [UInt8] = []
        rgba.reserveCapacity(still.count)
        for y in stride(from: height - 1, through: 0, by: -1) {
            rgba.append(contentsOf: still[(y * row)..<((y + 1) * row)])
        }
        return rgba
    }

    // MARK: CPU reference (clarification Q3)

    /// The camera the scene uses for `snapshot` on a `width` × `height` target.
    static func camera(_ snapshot: Snapshot, width: Int, height: Int) -> MoonlitMechanismCamera {
        Geometry.camera(snapshot, aspect: Double(width) / Double(height))
    }

    /// The pixel of world point `point` through `camera` on a `width` × `height` target (nil without a projection).
    static func project(_ point: SIMD3<Double>, _ camera: MoonlitMechanismCamera, width: Int,
                        height: Int) -> SIMD2<Double>? {
        guard let v = Geometry.project(point, camera: camera) else { return nil }
        return SIMD2<Double>(v.x * Double(width), v.y * Double(height))
    }

    /// The pixel of world point `point` for `snapshot` on a `width` × `height` target (origin top left, y down; nil
    /// without a projection or for an empty target).
    static func pixel(_ point: SIMD3<Double>, _ snapshot: Snapshot, width: Int = width,
                      height: Int = height) -> SIMD2<Double>? {
        guard width > 0, height > 0 else { return nil }
        return project(point, camera(snapshot, width: width, height: height), width: width, height: height)
    }

    /// The world reference points of `snapshot` in a fixed order, none depending on the tier or the time: cast-cell
    /// centres (cast order), rim check points (gear order), the first card, the first alignment pip, the first moves
    /// bar.
    static func referenceWorldPoints(_ snapshot: Snapshot) -> [SIMD3<Double>] {
        var points: [SIMD3<Double>] = []
        for cell in snapshot.cast { points.append(Geometry.cellCentre(cell, snapshot)) }
        for index in snapshot.gears.indices { points.append(Geometry.gearRimCheckPoint(index, snapshot)) }
        points.append(Geometry.card(0, snapshot))
        points.append(Geometry.alignmentPip(0, snapshot))
        points.append(Geometry.movesBar(0, snapshot))
        return points
    }

    /// The pixels of `referenceWorldPoints(snapshot)`, in that order (nil without a projection).
    static func referencePixels(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> [SIMD2<Double>?] {
        var result: [SIMD2<Double>?] = []
        guard width > 0, height > 0 else { return result }
        let cam: MoonlitMechanismCamera = camera(snapshot, width: width, height: height)
        for point in referenceWorldPoints(snapshot) {
            result.append(project(point, cam, width: width, height: height))
        }
        return result
    }

    /// The convex hull of `points` (Andrew's monotone chain).
    nonisolated static func convexHull(_ points: [SIMD2<Double>]) -> [SIMD2<Double>] {
        let sorted: [SIMD2<Double>] = points.sorted { a, b in a.x != b.x ? a.x < b.x : a.y < b.y }
        guard sorted.count > 2 else { return sorted }
        func turn(_ o: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }
        var lower: [SIMD2<Double>] = []
        for p in sorted {
            while lower.count >= 2, turn(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 { lower.removeLast() }
            lower.append(p)
        }
        var upper: [SIMD2<Double>] = []
        for p in sorted.reversed() {
            while upper.count >= 2, turn(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 { upper.removeLast() }
            upper.append(p)
        }
        return Array(lower.dropLast()) + Array(upper.dropLast())
    }

    /// The distance (pixels) of `p` from the segment `a` … `b`.
    nonisolated static func segmentDistance(_ p: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let ab: SIMD2<Double> = b - a
        let ap: SIMD2<Double> = p - a
        let length: Double = ab.x * ab.x + ab.y * ab.y
        let t: Double = length > 0 ? Swift.min(Swift.max((ap.x * ab.x + ap.y * ab.y) / length, 0), 1) : 0
        let d: SIMD2<Double> = p - (a + ab * t)
        return (d.x * d.x + d.y * d.y).squareRoot()
    }

    /// The distance (pixels) of `p` from the polyline `line` (infinite for an empty line).
    nonisolated static func polylineDistance(_ p: SIMD2<Double>, _ line: [SIMD2<Double>]) -> Double {
        guard let first = line.first else { return Double.infinity }
        guard line.count > 1 else { return segmentDistance(p, first, first) }
        var best: Double = Double.infinity
        for i in 0..<(line.count - 1) { best = Swift.min(best, segmentDistance(p, line[i], line[i + 1])) }
        return best
    }

    /// The signed distance (pixels) of `p` from the convex polygon `hull`: negative inside (infinite for fewer than
    /// three corners).
    nonisolated static func hullDistance(_ hull: [SIMD2<Double>], _ p: SIMD2<Double>) -> Double {
        guard hull.count >= 3 else { return Double.infinity }
        var inside: Bool = true
        var best: Double = Double.infinity
        for i in hull.indices {
            let a: SIMD2<Double> = hull[i]
            let b: SIMD2<Double> = hull[(i + 1) % hull.count]
            let ab: SIMD2<Double> = b - a
            let ap: SIMD2<Double> = p - a
            if ab.x * ap.y - ab.y * ap.x < 0 { inside = false }
            best = Swift.min(best, segmentDistance(p, a, b))
        }
        return inside ? -best : best
    }

    /// Whether `p` lies at least 6 px outside `outer` or at least 6 px inside `inner` (clear of the band between).
    static func ringClear(_ p: SIMD2<Double>, inner: [SIMD2<Double>], outer: [SIMD2<Double>]) -> Bool {
        hullDistance(outer, p) >= clearance || hullDistance(inner, p) <= -clearance
    }

    /// Whether `p` lies inside a `width` × `height` picture.
    static func inside(_ p: SIMD2<Double>, width: Int, height: Int) -> Bool {
        p.x >= 0 && p.y >= 0 && p.x < Double(width) && p.y < Double(height)
    }

    /// The hull of the circle of `radius` around `centre` in the plane z = centre.z: the circumscribed polygon when
    /// `outside`, else the inscribed one.
    static func circleHull(_ centre: SIMD3<Double>, radius: Double, outside: Bool, _ camera: MoonlitMechanismCamera,
                           width: Int, height: Int) -> [SIMD2<Double>] {
        let sides: Int = circleSides
        let r: Double = outside ? radius / cos(Double.pi / Double(sides)) : radius
        var points: [SIMD2<Double>] = []
        for k in 0..<sides {
            let a: Double = 2 * Double.pi * Double(k) / Double(sides)
            if let p = project(centre + SIMD3<Double>(cos(a) * r, sin(a) * r, 0), camera, width: width,
                               height: height) {
                points.append(p)
            }
        }
        return convexHull(points)
    }

    /// The hull of the axis-aligned rectangle of half sizes `half` around `centre` in the plane z = centre.z.
    static func rectangleHull(_ centre: SIMD3<Double>, half: SIMD2<Double>, _ camera: MoonlitMechanismCamera,
                              width: Int, height: Int) -> [SIMD2<Double>] {
        var points: [SIMD2<Double>] = []
        let signs: [(Double, Double)] = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
        for sign in signs {
            let corner = SIMD3<Double>(centre.x + sign.0 * half.x, centre.y + sign.1 * half.y, centre.z)
            if let p = project(corner, camera, width: width, height: height) { points.append(p) }
        }
        return convexHull(points)
    }

    /// The pixel length of the world length `length` along x at `centre`.
    static func pixelLength(_ length: Double, at centre: SIMD3<Double>, _ camera: MoonlitMechanismCamera, width: Int,
                            height: Int) -> Double {
        guard let a = project(centre, camera, width: width, height: height),
              let b = project(centre + SIMD3<Double>(length, 0, 0), camera, width: width, height: height) else {
            return 0
        }
        let d: SIMD2<Double> = b - a
        return (d.x * d.x + d.y * d.y).squareRoot()
    }

    /// The obstacles of `snapshot` on a `width` × `height` target (see the file header).
    static func obstacles(_ snapshot: Snapshot, width: Int = width,
                          height: Int = height) -> MoonlitMechanismObstacles {
        var o = MoonlitMechanismObstacles()
        guard width > 0, height > 0 else { return o }
        let cam: MoonlitMechanismCamera = camera(snapshot, width: width, height: height)
        let s: Double = Geometry.cellSize(snapshot)
        let radius: Double = Geometry.rimRadius(snapshot)
        let tooth: Double = Geometry.toothHeight * s
        let innerRadius: Double = radius - Geometry.rimBand * s
        let jammed = Geometry.jammedPair(snapshot)
        o.gearOrder = Geometry.gearOrder(snapshot)
        for index in snapshot.gears.indices {
            let c: SIMD3<Double> = Geometry.gearCentre(index, snapshot)
            let inPair: Bool = jammed.map { $0.child == index || $0.parent == index } ?? false
            let outerRadius: Double = radius + tooth + (inPair ? Geometry.jamBand.upperBound * s : 0)
            o.gearOuter.append(circleHull(c, radius: outerRadius, outside: true, cam, width: width, height: height))
            o.gearInner.append(circleHull(c, radius: innerRadius, outside: false, cam, width: width, height: height))
            o.gearCentres.append(project(c, cam, width: width, height: height) ?? SIMD2<Double>(-1e9, -1e9))
            o.innerRadii.append(pixelLength(innerRadius, at: c, cam, width: width, height: height))
            o.blades.append(bladeHulls(index, snapshot, cam, width: width, height: height))
            let a: Double = Geometry.toothAngle(index, tooth: 0, snapshot)
            let d = SIMD3<Double>(cos(a), sin(a), 0)
            var axis: [SIMD2<Double>] = []
            let ends: [SIMD3<Double>] = [c + d * innerRadius, c + d * (radius + Geometry.notchReach * tooth)]
            for end in ends {
                if let p = project(end, cam, width: width, height: height) { axis.append(p) }
            }
            o.notchAxes.append(axis)
            o.notchHalves.append(pixelLength(Geometry.notchWidth * s / 2, at: c, cam, width: width, height: height))
        }
        // The lamp with two glow shells, and the ladder with its rails.
        var lampPoints: [SIMD2<Double>] = circleHull(Geometry.lampCentre(snapshot),
                                                     radius: Geometry.lampRadius + 2 * Geometry.lampGlowGrowth,
                                                     outside: true, cam, width: width, height: height)
        let rungs: Int = Swift.max(snapshot.lampHeights, 1)
        let top: Double = Geometry.lampBaseY + Geometry.lampStep * Double(rungs - 1)
        let ladderCentre = SIMD3<Double>(Geometry.ladderX, (Geometry.lampBaseY + top) / 2, Geometry.lampZ)
        let ladderHalf = SIMD2<Double>(Geometry.rungWidth / 2 + Geometry.railWidth,
                                       (top - Geometry.lampBaseY) / 2 + 2 * Geometry.rungLine)
        lampPoints.append(contentsOf: rectangleHull(ladderCentre, half: ladderHalf, cam, width: width, height: height))
        o.lamp = convexHull(lampPoints)
        // The wall's cells.
        let half: Double = s / 2
        for cell in snapshot.target {
            let c: SIMD3<Double> = Geometry.cellCentre(cell, snapshot)
            o.targetOuter.append(rectangleHull(c, half: SIMD2<Double>(half, half), cam, width: width, height: height))
            let inner: Double = half - Geometry.targetLine * s
            o.targetInner.append(rectangleHull(c, half: SIMD2<Double>(inner, inner), cam, width: width,
                                               height: height))
        }
        for cell in snapshot.missingCells {
            let c: SIMD3<Double> = Geometry.cellCentre(cell, snapshot)
            let outer: Double = Geometry.missingBand.upperBound * s
            let inner: Double = Geometry.missingBand.lowerBound * s
            o.missingOuter.append(rectangleHull(c, half: SIMD2<Double>(outer, outer), cam, width: width,
                                                height: height))
            o.missingInner.append(rectangleHull(c, half: SIMD2<Double>(inner, inner), cam, width: width,
                                                height: height))
        }
        for cell in snapshot.forbidden {
            o.forbiddenCells.append(cell)
            let c: SIMD3<Double> = Geometry.cellCentre(cell, snapshot)
            o.forbiddenSquares.append(rectangleHull(c, half: SIMD2<Double>(half, half), cam, width: width,
                                                    height: height))
        }
        if let cell = Geometry.brokenCell(snapshot) {
            let c: SIMD3<Double> = Geometry.cellCentre(cell, snapshot)
            let outer: Double = half + Geometry.cellOutline.upperBound * s
            let inner: Double = half + Geometry.cellOutline.lowerBound * s
            o.brokenOuter = rectangleHull(c, half: SIMD2<Double>(outer, outer), cam, width: width, height: height)
            o.brokenInner = rectangleHull(c, half: SIMD2<Double>(inner, inner), cam, width: width, height: height)
        }
        // The gauges' cards with two glow shells and the failure outline.
        let grow: Double = 2 * Geometry.cardGlowGrowth + Geometry.cardOutline.upperBound
        let cardHalf = SIMD2<Double>(Geometry.cardWidth(snapshot) / 2 + grow, Geometry.cardHeight / 2 + grow)
        for index in snapshot.keyFrames.indices {
            o.cards.append(rectangleHull(Geometry.card(index, snapshot), half: cardHalf, cam, width: width,
                                         height: height))
        }
        let wallHalf = SIMD2<Double>(Double(snapshot.width) * s / 2, Double(snapshot.rows) * s / 2)
        o.paper = rectangleHull(SIMD3<Double>(0, Geometry.wallCentreY, Geometry.wallZ), half: wallHalf, cam,
                                width: width, height: height)
        return o
    }

    /// The hulls of gear `index`'s solid blade spokes at the drawn phases: strips 0.3 s wide from 0.35 s to 0.7 R
    /// along their slot's direction, as the geometry builds them.
    static func bladeHulls(_ index: Int, _ snapshot: Snapshot, _ camera: MoonlitMechanismCamera, width: Int,
                           height: Int) -> [[SIMD2<Double>]] {
        let gear: MoonlitMechanismGear = snapshot.gears[index]
        let teeth: Int = Swift.max(gear.teeth, 1)
        let s: Double = Geometry.cellSize(snapshot)
        let c: SIMD3<Double> = Geometry.gearCentre(index, snapshot)
        let phase: Int = index < snapshot.phases.count ? snapshot.phases[index] : 0
        let half: Double = Geometry.spokeWidth * s / 2
        var result: [[SIMD2<Double>]] = []
        for bit in 0..<Swift.min(teeth, gear.blades.count) where gear.blades[bit] {
            let slot: Int = ((bit + phase) % teeth + teeth) % teeth
            let d2: SIMD2<Double> = Geometry.spokeDirection(index, slot: slot, snapshot)
            let d = SIMD3<Double>(d2.x, d2.y, 0)
            let n = SIMD3<Double>(-d2.y, d2.x, 0)
            let a: SIMD3<Double> = c + d * (Geometry.hubRadius * s)
            let b: SIMD3<Double> = c + d * (Geometry.bodyInner * Geometry.rimRadius(snapshot))
            let corners: [SIMD3<Double>] = [a - n * half, a + n * half, b + n * half, b - n * half]
            var points: [SIMD2<Double>] = []
            for corner in corners {
                if let p = project(corner, camera, width: width, height: height) { points.append(p) }
            }
            result.append(convexHull(points))
        }
        return result
    }

    /// The largest luminance the translucent gear layers drawn over cast cell `cell` can give at its centre pixel
    /// `p` (which is clear of every opaque ring): the ink (or a stray cell's hatching, luminance 0.29), then in
    /// painter's order every gear whose body holds `p` (the body's fresnel shade at the body coordinate of the farthest
    /// pixel within 6 px, ``MoonlitMechanismShaders/gearBodyShade(local:)``) and each of its blade spokes within 6 px
    /// of `p` (alpha 0.5 at its brightest sheen). In the unlit fallback a body or a blade is opaque at its pre-mixed
    /// colour. Blending is linear in the stored channels, so the luminance composes exactly.
    static func coveredLuminance(_ cell: Int, _ p: SIMD2<Double>, _ snapshot: Snapshot, _ o: MoonlitMechanismObstacles,
                                 mode: MoonlitMechanismDrawMode) -> Double {
        var l: Double = luminance(Palette.ink)
        if snapshot.strayCells.contains(cell) { l = Swift.max(l, luminance(Palette.stray)) }
        let sheen: SIMD3<Double> = Palette.blade + (Palette.rim - Palette.blade) * MoonlitMechanismShaders.bladeSheen
        for index in o.gearOrder where index < o.gearInner.count {
            if hullDistance(o.gearInner[index], p) <= -clearance {
                if mode.fallback {
                    l = luminance(Geometry.colour(.gearBody))
                } else {
                    let delta: SIMD2<Double> = p - o.gearCentres[index]
                    let distance: Double = (delta.x * delta.x + delta.y * delta.y).squareRoot()
                    let radius: Double = Swift.max(o.innerRadii[index], 1)
                    let local: Double = Swift.min((distance + clearance) / radius, 1)
                    let shade = MoonlitMechanismShaders.gearBodyShade(local: local)
                    l = (1 - shade.alpha) * l + shade.alpha * luminance(shade.colour)
                }
            }
            for blade in o.blades[index] where hullDistance(blade, p) < clearance {
                if mode.fallback {
                    l = luminance(Geometry.colour(.blade))
                } else {
                    let a: Double = Palette.bladeAlpha
                    l = (1 - a) * l + a * luminance(sheen)
                }
            }
        }
        return l
    }

    /// The number of gear bodies whose inside holds `p` by at least 6 px.
    static func bodiesCovering(_ p: SIMD2<Double>, _ o: MoonlitMechanismObstacles) -> Int {
        var count: Int = 0
        for inner in o.gearInner where hullDistance(inner, p) <= -clearance { count += 1 }
        return count
    }

    /// Whether `p` is clear of every gear's opaque ring and lies under at most `maxBodies` gear bodies.
    static func isClearOfGears(_ p: SIMD2<Double>, _ o: MoonlitMechanismObstacles, maxBodies: Int) -> Bool {
        for index in o.gearOuter.indices where !ringClear(p, inner: o.gearInner[index], outer: o.gearOuter[index]) {
            return false
        }
        return bodiesCovering(p, o) <= maxBodies
    }

    /// Whether cast cell `cell`'s centre pixel `p` is at least 6 px from every other element (see the file header).
    static func isCellClear(_ cell: Int, _ p: SIMD2<Double>, _ snapshot: Snapshot, _ o: MoonlitMechanismObstacles,
                            mode: MoonlitMechanismDrawMode, width: Int, height: Int) -> Bool {
        if o.forbiddenCells.contains(cell) { return false }
        let cam: MoonlitMechanismCamera = camera(snapshot, width: width, height: height)
        let inkHalf: Double = Geometry.inkSide * Geometry.cellSize(snapshot) / 2
        let own: [SIMD2<Double>] = rectangleHull(Geometry.cellCentre(cell, snapshot),
                                                 half: SIMD2<Double>(inkHalf, inkHalf), cam, width: width,
                                                 height: height)
        guard hullDistance(own, p) <= -clearance else { return false }
        for index in o.targetOuter.indices where !ringClear(p, inner: o.targetInner[index],
                                                             outer: o.targetOuter[index]) {
            return false
        }
        for index in o.missingOuter.indices where !ringClear(p, inner: o.missingInner[index],
                                                              outer: o.missingOuter[index]) {
            return false
        }
        for square in o.forbiddenSquares where hullDistance(square, p) < clearance { return false }
        if !ringClear(p, inner: o.brokenInner, outer: o.brokenOuter) { return false }
        for index in o.gearOuter.indices where !ringClear(p, inner: o.gearInner[index], outer: o.gearOuter[index]) {
            return false
        }
        if hullDistance(o.lamp, p) < clearance { return false }
        // The translucent layers drawn over the ink must leave room for the 0.25 bound (with 0.02 to spare).
        return paperLuminance - coveredLuminance(cell, p, snapshot, o, mode: mode) >= castMargin + 0.02
    }

    /// Whether a rim point pixel `p` of gear `index` is at least 6 px from everything drawn over it that is not gold:
    /// every gear's notch strip (ink) and the lamp with its glow and ladder (lunar blue). Later gears' bodies, rims and
    /// blades, the jam outline and the card glow are all red above blue by more than 0.08 (gold #C9A24A, #E2C277,
    /// #B08A3C, #FF6B4A, #F2E2B0), so they keep the cue; everything drawn before the rim lies under its opaque band.
    static func isRimClear(_ index: Int, _ p: SIMD2<Double>, _ o: MoonlitMechanismObstacles) -> Bool {
        for gear in o.notchAxes.indices where polylineDistance(p, o.notchAxes[gear]) - o.notchHalves[gear] < clearance {
            return false
        }
        return hullDistance(o.lamp, p) >= clearance
    }

    /// The rim sample of gear `index` at `tooth` teeth past its tooth-zero notch (0.5 is ``gearRimCheckPoint``), 0.2 s
    /// inside R on the rim band.
    static func rimPoint(_ index: Int, tooth: Double, _ snapshot: Snapshot) -> SIMD3<Double> {
        let a: Double = Geometry.toothAngle(index, tooth: tooth, snapshot)
        let r: Double = Geometry.rimRadius(snapshot) - Geometry.checkInset * Geometry.cellSize(snapshot)
        return Geometry.gearCentre(index, snapshot) + SIMD3<Double>(cos(a) * r, sin(a) * r, 0)
    }

    /// The first clear rim sample of gear `index`: the check point (half a tooth past the notch), else 1.5, 2.5, …
    /// teeth past it (pixel and the tooth offset), or nil.
    static func clearRimPoint(_ index: Int, _ snapshot: Snapshot, _ o: MoonlitMechanismObstacles, width: Int,
                              height: Int) -> (p: SIMD2<Double>, tooth: Double)? {
        let teeth: Int = Swift.max(snapshot.gears[index].teeth, 1)
        for k in 0..<teeth {
            let tooth: Double = Double(k) + Geometry.checkTooth
            guard let p = pixel(rimPoint(index, tooth: tooth, snapshot), snapshot, width: width, height: height),
                  inside(p, width: width, height: height), isRimClear(index, p, o) else { continue }
            return (p, tooth)
        }
        return nil
    }

    /// Whether the first moves bar's centre pixel `p` is at least 6 px outside the lamp: every other layer drawn
    /// over the bar (gold bodies, rims and blades, ink notches) is at least 0.1 from the paper in luminance too.
    static func isMovesClear(_ p: SIMD2<Double>, _ o: MoonlitMechanismObstacles) -> Bool {
        hullDistance(o.lamp, p) >= clearance
    }

    /// Whether the first moves bar's centre pixel `p` is at least 6 px outside every gear and the lamp (its own
    /// colour shows).
    static func isMovesUncovered(_ p: SIMD2<Double>, _ o: MoonlitMechanismObstacles) -> Bool {
        for outer in o.gearOuter where hullDistance(outer, p) < clearance { return false }
        return hullDistance(o.lamp, p) >= clearance
    }

    /// The cast cells of `snapshot` whose centres are clear (cell and pixel), in cast order.
    static func clearCells(_ snapshot: Snapshot, mode: MoonlitMechanismDrawMode = .lit, width: Int = width,
                           height: Int = height) -> [(cell: Int, p: SIMD2<Double>)] {
        let o: MoonlitMechanismObstacles = obstacles(snapshot, width: width, height: height)
        var result: [(cell: Int, p: SIMD2<Double>)] = []
        for cell in snapshot.cast {
            guard let p = pixel(Geometry.cellCentre(cell, snapshot), snapshot, width: width, height: height),
                  inside(p, width: width, height: height),
                  isCellClear(cell, p, snapshot, o, mode: mode, width: width, height: height) else { continue }
            result.append((cell, p))
        }
        return result
    }

    /// The cast-cell and rim checks of clarification Q3 (see the file header) on `rgba` against `snapshot`.
    static func pointReport(_ rgba: [UInt8], snapshot: Snapshot, mode: MoonlitMechanismDrawMode, width: Int = width,
                            height: Int = height) -> MoonlitMechanismCheckReport {
        var report = MoonlitMechanismCheckReport()
        let o: MoonlitMechanismObstacles = obstacles(snapshot, width: width, height: height)
        for cell in snapshot.cast {
            guard let p = pixel(Geometry.cellCentre(cell, snapshot), snapshot, width: width, height: height),
                  inside(p, width: width, height: height) else {
                report.misses.append("cell \(cell): it does not project into the picture")
                continue
            }
            if !isCellClear(cell, p, snapshot, o, mode: mode, width: width, height: height) {
                report.cellExcluded += 1
                continue
            }
            report.cellChecked += 1
            if !anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height, where: isShadow) {
                let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
                report.misses.append(String(format: "cast cell %ld (%.1f, %.1f) is (%.3f, %.3f, %.3f)", cell, p.x, p.y,
                                            c.x, c.y, c.z))
            }
        }
        for index in snapshot.gears.indices {
            guard let check = pixel(Geometry.gearRimCheckPoint(index, snapshot), snapshot, width: width,
                                    height: height), inside(check, width: width, height: height) else {
                report.misses.append("gear \(index): its rim point does not project into the picture")
                continue
            }
            guard let rim = clearRimPoint(index, snapshot, o, width: width, height: height) else {
                report.rimExcluded += 1
                continue
            }
            let p: SIMD2<Double> = rim.p
            report.rimChecked += 1
            if !anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height, where: isGold) {
                let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
                report.misses.append(String(format: "rim of gear %ld (%.1f, %.1f) is (%.3f, %.3f, %.3f)", index, p.x,
                                            p.y, c.x, c.y, c.z))
            }
        }
        return report
    }

    /// The pixel of the first moves bar's centre (nil without a projection).
    static func movesPixel(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> SIMD2<Double>? {
        pixel(Geometry.movesBar(0, snapshot), snapshot, width: width, height: height)
    }

    /// The moves check: when the first moves bar is clear, within 3 px of its centre a pixel 0.1 away from the paper
    /// in luminance. Returns whether it was measured and the misses.
    static func movesCheck(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width,
                           height: Int = height) -> (checked: Bool, misses: [String]) {
        guard snapshot.budget > 0 else { return (false, ["moves: no budget"]) }
        guard let p = movesPixel(snapshot, width: width, height: height), inside(p, width: width, height: height) else {
            return (false, ["moves bar 0: no projection"])
        }
        guard isMovesClear(p, obstacles(snapshot, width: width, height: height)) else { return (false, []) }
        let found: Bool = anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height,
                                   where: isOffPaper)
        return (true, found ? [] : [String(format: "moves bar 0 at (%.1f, %.1f) is paper-coloured", p.x, p.y)])
    }

    /// The background check: the pixels of the two probe corners are within 0.05 per channel of the night.
    static func backgroundMisses(_ rgba: [UInt8], width: Int = width, height: Int = height) -> [String] {
        var misses: [String] = []
        for point in backgroundPoints {
            let got = pixelAtFraction(rgba, point.x, point.y, width: width, height: height)
            if channelDistance(got.colour, Palette.night) > backgroundTolerance {
                misses.append(String(format: "background (%ld, %ld): (%.3f, %.3f, %.3f)", got.x, got.y,
                                     got.colour.x, got.colour.y, got.colour.z))
            }
        }
        return misses
    }

    /// Runs the checks of clarification Q3 on `rgba` against `snapshot` drawn in `mode`, recording an issue per
    /// failure, and returns the report. `require` true also requires at least one cast-cell centre and one rim check
    /// point to be measured.
    @discardableResult
    static func checkFrame(_ rgba: [UInt8], snapshot: Snapshot, mode: MoonlitMechanismDrawMode = .lit,
                           width: Int = width, height: Int = height, require: Bool = true, _ what: String,
                           sourceLocation: SourceLocation = #_sourceLocation) -> MoonlitMechanismCheckReport {
        #expect(rgba.count == width * height * 4, "\(what): picture size", sourceLocation: sourceLocation)
        guard rgba.count == width * height * 4 else { return MoonlitMechanismCheckReport() }
        let report: MoonlitMechanismCheckReport = pointReport(rgba, snapshot: snapshot, mode: mode, width: width,
                                                              height: height)
        if require {
            #expect(report.cellChecked > 0, "\(what): no cast-cell centre clear of the other elements",
                    sourceLocation: sourceLocation)
            #expect(report.rimChecked > 0, "\(what): no rim check point clear of the other elements",
                    sourceLocation: sourceLocation)
        }
        let shown: [String] = Array(report.misses.prefix(8))
        #expect(report.misses.isEmpty, "\(what): \(shown)", sourceLocation: sourceLocation)
        let moves = movesCheck(rgba, snapshot: snapshot, width: width, height: height)
        #expect(moves.misses.isEmpty, "\(what): \(moves.misses)", sourceLocation: sourceLocation)
        let background: [String] = backgroundMisses(rgba, width: width, height: height)
        #expect(background.isEmpty, "\(what): \(background)", sourceLocation: sourceLocation)
        let cells: String = String(format: "cells checked %ld, excluded %ld", report.cellChecked, report.cellExcluded)
        let rims: String = String(format: "rims checked %ld, excluded %ld", report.rimChecked, report.rimExcluded)
        print("moonlit-mechanism \(what): \(cells); \(rims); moves checked \(moves.checked)")
        return report
    }

    // MARK: Failure outlines

    /// The sample points (pixels at the check size) on the outline a failure of `kind` draws in `snapshot`, each at
    /// least 6 px clear of the other elements that could hide it: the jam arcs' middle line (0.06 s beyond the tooth
    /// tips, ±0.75 of their half span, on both gears; drawn after every gear) clear of the lamp; the forbidden cell's
    /// outline middle (0.09 s outside the cell) clear of every gear ring, under at most one gear body, clear of the
    /// lamp and the other forbidden cells; the failing card's outline middle (0.01 outside the card) clear of every
    /// gear ring, under at most one gear body, and clear of the other cards.
    static func failureSamples(_ kind: MoonlitMechanismFailureKind, _ snapshot: Snapshot, width: Int = width,
                               height: Int = height) -> [SIMD2<Double>] {
        let o: MoonlitMechanismObstacles = obstacles(snapshot, width: width, height: height)
        let s: Double = Geometry.cellSize(snapshot)
        var world: [SIMD3<Double>] = []
        switch kind {
        case .jammed:
            guard let pair = Geometry.jammedPair(snapshot) else { return [] }
            let radius: Double = Geometry.rimRadius(snapshot) + Geometry.toothHeight * s
                + (Geometry.jamBand.lowerBound + Geometry.jamBand.upperBound) / 2 * s
            let pairs: [(Int, Int)] = [(pair.child, pair.parent), (pair.parent, pair.child)]
            for (a, b) in pairs {
                let ca: SIMD3<Double> = Geometry.gearCentre(a, snapshot)
                let cb: SIMD3<Double> = Geometry.gearCentre(b, snapshot)
                let towards: Double = atan2(cb.y - ca.y, cb.x - ca.x)
                let half: Double = Geometry.jamSpan * 2 * Double.pi / Double(Swift.max(snapshot.gears[a].teeth, 1))
                let shares: [Double] = [-0.75, -0.375, 0, 0.375, 0.75]
                for share in shares {
                    let angle: Double = towards + share * half
                    world.append(ca + SIMD3<Double>(cos(angle) * radius, sin(angle) * radius, 0))
                }
            }
        case .forbidden:
            guard let cell = Geometry.brokenCell(snapshot) else { return [] }
            let c: SIMD3<Double> = Geometry.cellCentre(cell, snapshot)
            let d: Double = s / 2 + (Geometry.cellOutline.lowerBound + Geometry.cellOutline.upperBound) / 2 * s
            world = squareRing(c, half: SIMD2<Double>(d, d))
        case .card:
            guard let index = Geometry.failingCard(snapshot) else { return [] }
            let mid: Double = (Geometry.cardOutline.lowerBound + Geometry.cardOutline.upperBound) / 2
            let half = SIMD2<Double>(Geometry.cardWidth(snapshot) / 2 + mid, Geometry.cardHeight / 2 + mid)
            world = squareRing(Geometry.card(index, snapshot), half: half)
        }
        let cam: MoonlitMechanismCamera = camera(snapshot, width: width, height: height)
        let unoutlined: [Int] = cardIndicesExcept(Geometry.failingCard(snapshot), snapshot)
        let broken: Int = Geometry.brokenCell(snapshot) ?? -1
        var result: [SIMD2<Double>] = []
        for point in world {
            guard let p = project(point, cam, width: width, height: height), inside(p, width: width, height: height),
                  hullDistance(o.lamp, p) >= clearance else { continue }
            switch kind {
            case .jammed:
                break
            case .forbidden:
                guard isClearOfGears(p, o, maxBodies: 1) else { continue }
                var near: Bool = false
                for (index, cell) in o.forbiddenCells.enumerated() where cell != broken {
                    if hullDistance(o.forbiddenSquares[index], p) < clearance { near = true }
                }
                if near { continue }
            case .card:
                guard isClearOfGears(p, o, maxBodies: 1) else { continue }
                var near: Bool = false
                for index in unoutlined {
                    let rect: [SIMD2<Double>] = rectangleHull(
                        Geometry.card(index, snapshot),
                        half: SIMD2<Double>(Geometry.cardWidth(snapshot) / 2, Geometry.cardHeight / 2), cam,
                        width: width, height: height)
                    if hullDistance(rect, p) < clearance { near = true }
                }
                if near { continue }
            }
            result.append(p)
        }
        return result
    }

    /// The card indices of `snapshot` other than `except`.
    static func cardIndicesExcept(_ except: Int?, _ snapshot: Snapshot) -> [Int] {
        var result: [Int] = []
        for index in snapshot.keyFrames.indices where index != except { result.append(index) }
        return result
    }

    /// Points on the axis-aligned square ring of half sizes `half` around `centre`: the four corners and four points
    /// along each side.
    static func squareRing(_ centre: SIMD3<Double>, half: SIMD2<Double>) -> [SIMD3<Double>] {
        var points: [SIMD3<Double>] = []
        let signs: [Double] = [-1, 1]
        let shares: [Double] = [-0.75, -0.25, 0.25, 0.75]
        for sx in signs {
            for sy in signs { points.append(centre + SIMD3<Double>(sx * half.x, sy * half.y, 0)) }
        }
        for sign in signs {
            for share in shares {
                points.append(centre + SIMD3<Double>(sign * half.x, share * half.y, 0))
                points.append(centre + SIMD3<Double>(share * half.x, sign * half.y, 0))
            }
        }
        return points
    }

    // MARK: Won wall

    /// Points 0.03 outside the paper wall's edge (five per side, in the wall glow's band, on the wall plane lifted by
    /// 0.002) whose pixels are at least 6 px from the paper and the lamp. The glow is additive and drawn last, so a
    /// gear's translucent gold over such a point does not hide it (nothing there comes near saturating).
    static func wallGlowSamples(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> [SIMD2<Double>] {
        let o: MoonlitMechanismObstacles = obstacles(snapshot, width: width, height: height)
        let cam: MoonlitMechanismCamera = camera(snapshot, width: width, height: height)
        let s: Double = Geometry.cellSize(snapshot)
        let hx: Double = Double(snapshot.width) * s / 2 + 0.03
        let hy: Double = Double(snapshot.rows) * s / 2 + 0.03
        let centre = SIMD3<Double>(0, Geometry.wallCentreY, Geometry.wallZ + 0.002)
        let shares: [Double] = [-0.8, -0.4, 0, 0.4, 0.8]
        let signs: [Double] = [-1, 1]
        var world: [SIMD3<Double>] = []
        for sign in signs {
            for share in shares {
                world.append(centre + SIMD3<Double>(sign * hx, share * hy, 0))
                world.append(centre + SIMD3<Double>(share * hx, sign * hy, 0))
            }
        }
        var result: [SIMD2<Double>] = []
        for point in world {
            guard let p = project(point, cam, width: width, height: height), inside(p, width: width, height: height),
                  hullDistance(o.paper, p) >= clearance, hullDistance(o.lamp, p) >= clearance else { continue }
            result.append(p)
        }
        return result
    }
}
#endif
