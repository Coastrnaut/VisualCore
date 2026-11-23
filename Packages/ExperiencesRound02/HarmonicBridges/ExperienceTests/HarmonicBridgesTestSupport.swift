// HarmonicBridgesTestSupport — feature 413 (R02-G12-03) T-R02G1203-006 (FR-R02G1203-001 … 007; SC-R02G1203-001, 002;
// clarifications Q1–Q5). Shared helpers of the Harmonic Bridges experience tests, following Echo Cartographer's harness
// (feature 403): opening the experience through the one app's session host (seed `s` prepares level `s % 100 + 1`; a
// session without a quality pin is pinned to level 0), tuning the strings through the shell to the level's certified
// pegs (the plan's tunings, without the final test: every step then holds the crossing, so the shown step 0 has
// bridges), drawing live frames, drawing an off-screen still (RGBA8, rows top-down, the orientation of the Core's CPU
// projection `HarmonicBridgesSceneGeometry.project`, origin top left, y down, scaled here to pixels), the engine digest,
// and the frame checks of clarification Q3 at 1,152 × 768.
//
// The presenter hands the snapshot the seconds since the play last changed, so the first still after an action, drawn
// at frame time 0, restarts the step clock at 0 (step 0 shown); live frames are therefore not drawn between an action
// and the stills that need a known time.
//
// The CPU reference: every island's top centre, every string's midpoint, every string's membrane check point
// (`membraneMidpoint`, u = 0.25, 0.018 to the side), the gauge's first bar and the first step pip, projected through the
// camera at the target's aspect. The "other elements" a checked point keeps clear of (6 px) are: every island top
// centre, every string midpoint (at rest and, where strings swing, displaced by the wave at the frame time), where a
// string swings the displaced string point at u = 0.25 (the string passing near its membrane check point), every sample
// mark centre (displaced with its string), every drawn membrane check point, every gauge bar and every step pip, and
// every other island's prism (the convex hull of its 12 projected corners; islands are opaque and drawn over the
// strings and membranes). The wave is the Core's CPU reference `HarmonicBridgesShaders.waveDisplacement` of the
// geometry's packed modes. A point is checked only when it projects into the picture at least 6 px from every other
// element:
//   - an island's top centre has, within 3 px, a pixel whose luminance differs from the ground's by at least 0.1 with
//     red above blue by at least 0.05 (copper). Where the tier draws glow (level-0, level-1) the glow shells of reached
//     islands and of bridge membranes lie additively over the top centres of the islands they touch and tint them cyan,
//     so on those islands only the luminance is checked; the copper hue is checked on every other island, and on every
//     island at level-2 and in the fallback;
//   - a drawn membrane's check point has, within 3 px, a pixel 0.08 from the ground in luminance with blue above red by
//     at least 0.05 (cyan);
//   - the gauge's first bar has, within 3 px of its centre, a pixel at least 0.1 away from the ground in luminance;
//   - the two probe corners (0.02, 0.02) and (0.98, 0.98) of the view are within 0.05 per channel of the ground.
// Luminance is the Rec. 709 weighting of the stored 0 … 1 channel values. Positions come from the presenter's
// `lastSnapshot` (the snapshot it drew). Short runs only (no sleep, no wall-clock assertion).
#if os(iOS)
import CoreGraphics
import Foundation
import HarmonicBridgesCore
import Testing
import UIKit
@testable import HarmonicBridgesExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the point checks of one frame found.
struct HarmonicBridgesFrameReport {
    /// The island top centres measured, those whose copper hue was measured, and those left out by the clearance.
    var topChecked: Int = 0
    var copperChecked: Int = 0
    var topExcluded: Int = 0
    /// The membrane check points measured, and those left out by the 6-pixel clearance.
    var membraneChecked: Int = 0
    var membraneExcluded: Int = 0
    /// Every failed check, in words.
    var misses: [String] = []
}

/// How a frame was drawn, as far as the reference needs it: whether strings swing, whether glow shells are drawn and
/// whether the step is held (Reduce Motion).
struct HarmonicBridgesDrawMode: Equatable {
    var motion: Bool
    var glow: Bool
    var reduceMotion: Bool

    /// The mode of host tier `tier` (clamped) with or without Reduce Motion.
    static func tier(_ tier: Int, reduceMotion: Bool = false) -> HarmonicBridgesDrawMode {
        let drawn: HarmonicBridgesTier = HarmonicBridgesTier.of(tier)
        return HarmonicBridgesDrawMode(motion: drawn.motion && !reduceMotion, glow: drawn.glowShells > 0,
                                       reduceMotion: reduceMotion)
    }

    /// The unlit fallback: the level-2 geometry (strings at rest, no glow).
    static let fallback = HarmonicBridgesDrawMode(motion: false, glow: false, reduceMotion: false)
}

/// Building, opening, drawing and measuring Harmonic Bridges.
@MainActor
enum HarmonicBridgesTest {
    typealias Geometry = HarmonicBridgesSceneGeometry
    typealias Palette = HarmonicBridgesPalette
    typealias Snapshot = HarmonicBridgesSceneSnapshot
    typealias Shell = ExperienceShell<HarmonicBridgesPresenter>

    /// The experience id `r02-g12.harmonic-bridges`.
    static var id: ExperienceID {
        HarmonicBridgesExperience.id ?? ExperienceID(rawValue: "r02-g12.unknown")!
    }

    /// The frame-check size of clarification Q3, aspect 1.5.
    static let width: Int = 1_152
    static let height: Int = 768
    /// The seeds of the checked levels 2, 11, 31, 41 and 61 (seed = level − 1): levels whose tuned frame at time 0 has,
    /// at every tier, at least one island top with a measurable copper hue and at least one drawn membrane check point
    /// clear of every other element (chosen with the same projection; the checks require it again).
    static let seeds: [UInt64] = [1, 10, 30, 40, 60]
    /// The search radius (pixels) of every point check.
    static let pointRadius: Double = 3
    /// The clearance (pixels) of every checked point from every other element.
    static let clearance: Double = 6
    /// The island top's luminance difference from the ground.
    static let topMargin: Double = 0.1
    /// The island top's copper (red − blue).
    static let copper: Double = 0.05
    /// The membrane's luminance difference from the ground.
    static let membraneMargin: Double = 0.08
    /// The membrane's cyan (blue − red).
    static let cyan: Double = 0.05
    /// The luminance difference from the ground near the gauge's first bar.
    static let gaugeMargin: Double = 0.1
    /// The per-channel bound of the ground.
    static let backgroundTolerance: Double = 0.05
    /// The ground probe points (fractions of the view, origin top left).
    static let backgroundPoints: [(x: Double, y: Double)] = [(0.02, 0.02), (0.98, 0.98)]

    /// Opens Harmonic Bridges with `seed` in `session` through the factory, lays the view out at `size` points and
    /// draws one frame. A session without a quality pin is pinned to level 0. `configure` runs on the presenter before
    /// its first `setup` (the fallback seam).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false, size: CGSize = CGSize(width: 48, height: 32),
                     configure: ((HarmonicBridgesPresenter) -> Void)? = nil) async throws -> Shell {
        let id: ExperienceID = self.id
        var made: Shell?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: seed) {
            let shell: Shell = HarmonicBridgesExperience.make(id: id, reduceMotion: reduceMotion,
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
    static func core(_ shell: Shell) throws -> HarmonicBridgesExperienceCore {
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
    static func control(_ action: HarmonicBridgesAction) -> (control: String, values: [Double]) {
        switch action {
        case let .tune(string, peg):
            ("string.tune", [Double(string), Double(peg)])
        case .test:
            ("crossing.test", [])
        }
    }

    /// The host action of `action` (step 0).
    static func experienceAction(_ action: HarmonicBridgesAction) -> ExperienceAction {
        let issued = control(action)
        return ExperienceAction(control: issued.control, values: issued.values, step: 0)
    }

    /// The certified solution (witness actions: the tunings, then one test) of level `number`.
    static func certifiedActions(_ number: Int) throws -> [HarmonicBridgesAction] {
        try HarmonicBridgesExperienceCore.generated(number: number).actions
    }

    /// The certified tunings of level `number` (the solution without its final test).
    static func certifiedTunings(_ number: Int) throws -> [HarmonicBridgesAction] {
        var result: [HarmonicBridgesAction] = []
        for action in try certifiedActions(number) where action != .test { result.append(action) }
        return result
    }

    /// Issues `actions` through the shell, each expected to be accepted; returns how many were.
    @discardableResult
    static func issue(_ shell: Shell, _ actions: [HarmonicBridgesAction],
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

    /// Tunes the shell's level to its certified pegs (no test). Returns whether every tuning was accepted.
    @discardableResult
    static func tune(_ shell: Shell) throws -> Bool {
        let number: Int = try core(shell).levelNumber
        let tunings: [HarmonicBridgesAction] = try certifiedTunings(number)
        #expect(!tunings.isEmpty, "level \(number) has certified tunings")
        return issue(shell, tunings) == tunings.count
    }

    /// The same as `tune` on a bare core (no host): the CPU reference of the tuned state.
    static func tuned(_ number: Int) throws -> HarmonicBridgesExperienceCore {
        var core: HarmonicBridgesExperienceCore = try HarmonicBridgesExperienceCore.opening(number: number)
        for action in try certifiedTunings(number) {
            let result: ActionResult = core.apply(experienceAction(action))
            #expect(result == .accepted, "level \(number): \(result.code)")
        }
        return core
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

    /// The luminance of the ground.
    static var groundLuminance: Double { luminance(Palette.ground) }

    /// The number of pixels farther than `tolerance` per channel from the ground.
    static func nonGroundPixels(_ rgba: [UInt8], tolerance: Double = 0.05) -> Int {
        var count: Int = 0
        var i: Int = 0
        while i + 3 < rgba.count {
            let c = SIMD3<Double>(Double(rgba[i]) / 255, Double(rgba[i + 1]) / 255, Double(rgba[i + 2]) / 255)
            if channelDistance(c, Palette.ground) > tolerance { count += 1 }
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

    /// The largest luminance of the pixels whose centres lie within `radius` of `p` (0 when none).
    static func brightest(_ rgba: [UInt8], near p: SIMD2<Double>, radius: Double, width: Int = width,
                          height: Int = height) -> Double {
        let reach: Int = Int(radius.rounded(.up)) + 1
        let cx: Int = Int(p.x.rounded(.down))
        let cy: Int = Int(p.y.rounded(.down))
        var best: Double = 0
        for y in (cy - reach)...(cy + reach) {
            guard y >= 0, y < height else { continue }
            for x in (cx - reach)...(cx + reach) {
                guard x >= 0, x < width else { continue }
                let dx: Double = Double(x) + 0.5 - p.x
                let dy: Double = Double(y) + 0.5 - p.y
                guard dx * dx + dy * dy <= radius * radius else { continue }
                best = Swift.max(best, luminance(colour(rgba, x: x, y: y, width: width)))
            }
        }
        return best
    }

    /// The colour of the pixel that holds `p`, clamped to the picture.
    static func centre(_ rgba: [UInt8], _ p: SIMD2<Double>, width: Int, height: Int) -> SIMD3<Double> {
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
    static func camera(_ snapshot: Snapshot, width: Int, height: Int) -> HarmonicBridgesCamera {
        Geometry.camera(snapshot, aspect: Double(width) / Double(height))
    }

    /// The pixel of world point `point` for `snapshot` on a `width` × `height` target (origin top left, y down; nil
    /// without a projection or for an empty target).
    static func pixel(_ point: SIMD3<Double>, _ snapshot: Snapshot, width: Int = width,
                      height: Int = height) -> SIMD2<Double>? {
        guard width > 0, height > 0 else { return nil }
        guard let v = Geometry.project(point, camera: camera(snapshot, width: width, height: height)) else {
            return nil
        }
        return SIMD2<Double>(v.x * Double(width), v.y * Double(height))
    }

    /// The step drawn for `snapshot` in `mode`.
    static func drawnStep(_ snapshot: Snapshot, _ mode: HarmonicBridgesDrawMode) -> Int {
        Geometry.drawnStep(snapshot, reduceMotion: mode.reduceMotion)
    }

    /// The world reference points of `snapshot` in a fixed order, none depending on the tier or the step: island tops
    /// (island order), string midpoints and membrane check points (string order), the gauge's first bar, the first
    /// step pip.
    static func referenceWorldPoints(_ snapshot: Snapshot) -> [SIMD3<Double>] {
        var points: [SIMD3<Double>] = []
        for index in snapshot.islands.indices { points.append(Geometry.islandTop(index, snapshot)) }
        for index in snapshot.strings.indices { points.append(Geometry.stringMidpoint(index, snapshot)) }
        for index in snapshot.strings.indices { points.append(Geometry.membraneMidpoint(index, snapshot)) }
        points.append(Geometry.gaugeBar(0, snapshot))
        points.append(Geometry.stepPip(0, snapshot))
        return points
    }

    /// The pixels of `referenceWorldPoints(snapshot)`, in that order (nil without a projection).
    static func referencePixels(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> [SIMD2<Double>?] {
        var result: [SIMD2<Double>?] = []
        for point in referenceWorldPoints(snapshot) {
            result.append(pixel(point, snapshot, width: width, height: height))
        }
        return result
    }

    /// The sideways wave displacement of string `index` at `u` in the drawn step of `mode` (0 at rest).
    static func wave(_ index: Int, u: Double, _ snapshot: Snapshot, _ mode: HarmonicBridgesDrawMode) -> Double {
        guard mode.motion else { return 0 }
        let packed: Double = Geometry.packModes(index, step: drawnStep(snapshot, mode), snapshot)
        return HarmonicBridgesShaders.waveDisplacement(u: u, time: HarmonicBridgesShaders.wrappedTime(snapshot.time),
                                                       packed: packed, motion: 1)
    }

    /// The point at `u` along string `index` on plane `y`, displaced sideways by the wave of `mode`.
    static func swungPoint(_ index: Int, u: Double, y: Double, _ snapshot: Snapshot,
                           _ mode: HarmonicBridgesDrawMode) -> SIMD3<Double> {
        let rest: SIMD3<Double> = Geometry.stringPoint(index, u: u, y: y, snapshot)
        return rest + Geometry.stringSide(index, snapshot) * wave(index, u: u, snapshot, mode)
    }

    /// The pixels of every point element a checked point keeps clear of (see the file header; points without a
    /// projection are left out).
    static func elementPixels(_ snapshot: Snapshot, _ mode: HarmonicBridgesDrawMode, width: Int = width,
                              height: Int = height) -> [SIMD2<Double>] {
        var world: [SIMD3<Double>] = []
        let step: Int = drawnStep(snapshot, mode)
        for index in snapshot.islands.indices { world.append(Geometry.islandTop(index, snapshot)) }
        for index in snapshot.strings.indices {
            world.append(Geometry.stringMidpoint(index, snapshot))
            if mode.motion {
                world.append(swungPoint(index, u: 0.5, y: Geometry.stringY, snapshot, mode))
                if Swift.abs(wave(index, u: Geometry.membraneSampleU, snapshot, mode)) > 1e-9 {
                    world.append(swungPoint(index, u: Geometry.membraneSampleU, y: Geometry.stringY, snapshot, mode))
                }
            }
            for k in 1...HarmonicBridgesSwing.samples {
                world.append(swungPoint(index, u: Double(k) / 6, y: Geometry.markY, snapshot, mode))
            }
            if snapshot.isBridge(index, step: step) { world.append(Geometry.membraneMidpoint(index, snapshot)) }
        }
        for index in 0..<Swift.max(snapshot.budget, 0) { world.append(Geometry.gaugeBar(index, snapshot)) }
        for index in 0..<snapshot.steps { world.append(Geometry.stepPip(index, snapshot)) }
        var result: [SIMD2<Double>] = []
        for point in world {
            if let p = pixel(point, snapshot, width: width, height: height) { result.append(p) }
        }
        return result
    }

    /// The convex hull (counter-clockwise in pixels, y down) of island `index`'s projected prism corners.
    static func islandHull(_ index: Int, _ snapshot: Snapshot, width: Int = width,
                           height: Int = height) -> [SIMD2<Double>] {
        let c: SIMD3<Double> = Geometry.islandCentre(index, snapshot)
        var points: [SIMD2<Double>] = []
        for k in 0..<6 {
            let angle: Double = Double(k) * Double.pi / 3
            for y in [0, Geometry.islandHeight] {
                let corner = SIMD3<Double>(c.x + Geometry.islandRadius * cos(angle), y,
                                           c.z + Geometry.islandRadius * sin(angle))
                if let p = pixel(corner, snapshot, width: width, height: height) { points.append(p) }
            }
        }
        return convexHull(points)
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

    /// The signed distance (pixels) of `p` from the convex polygon `hull`: negative inside.
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
            let length: Double = ab.x * ab.x + ab.y * ab.y
            let t: Double = length > 0 ? Swift.min(Swift.max((ap.x * ab.x + ap.y * ab.y) / length, 0), 1) : 0
            let q: SIMD2<Double> = a + ab * t
            let d: SIMD2<Double> = p - q
            best = Swift.min(best, (d.x * d.x + d.y * d.y).squareRoot())
        }
        return inside ? -best : best
    }

    /// The hulls of every island of `snapshot`, in island order.
    static func islandHulls(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> [[SIMD2<Double>]] {
        var result: [[SIMD2<Double>]] = []
        for index in snapshot.islands.indices {
            result.append(islandHull(index, snapshot, width: width, height: height))
        }
        return result
    }

    /// Whether `p` is at least `clearance` pixels from every element of `elements` (except one at `p` itself counted
    /// once: the point being checked) and from every island hull other than `ownIsland`'s.
    static func isClear(_ p: SIMD2<Double>, among elements: [SIMD2<Double>], hulls: [[SIMD2<Double>]],
                        ownIsland: Int? = nil) -> Bool {
        var selfSkipped: Bool = false
        for e in elements {
            let d: SIMD2<Double> = e - p
            let distance: Double = (d.x * d.x + d.y * d.y).squareRoot()
            if distance == 0, !selfSkipped {
                selfSkipped = true
                continue
            }
            if distance < clearance { return false }
        }
        for index in hulls.indices where index != ownIsland {
            if hullDistance(hulls[index], p) < clearance { return false }
        }
        return true
    }

    /// Whether `p` lies inside a `width` × `height` picture.
    static func inside(_ p: SIMD2<Double>, width: Int, height: Int) -> Bool {
        p.x >= 0 && p.y >= 0 && p.x < Double(width) && p.y < Double(height)
    }

    /// Whether `c` is an island-top pixel by luminance: 0.1 from the ground.
    static func isTop(_ c: SIMD3<Double>) -> Bool {
        Swift.abs(luminance(c) - groundLuminance) >= topMargin
    }

    /// Whether `c` is a copper island-top pixel: 0.1 from the ground in luminance and red − blue ≥ 0.05.
    static func isCopperTop(_ c: SIMD3<Double>) -> Bool {
        isTop(c) && c.x - c.z >= copper
    }

    /// Whether `c` is a membrane pixel: 0.08 from the ground in luminance and blue − red ≥ 0.05.
    static func isMembrane(_ c: SIMD3<Double>) -> Bool {
        Swift.abs(luminance(c) - groundLuminance) >= membraneMargin && c.z - c.x >= cyan
    }

    /// Whether `c` shows the broken outline #FF6B4A (red well above green and blue; the copper string, the island
    /// edges and the lit gauge stay below these bounds).
    static func isBrokenOutline(_ c: SIMD3<Double>) -> Bool {
        c.x >= 0.45 && c.x - c.y >= 0.3 && c.x - c.z >= 0.3
    }

    /// Whether island `index`'s top lies under a glow shell in `mode`: the tier draws glow and the island is reached in
    /// the drawn step or joined by a bridge of that step.
    static func isGlowing(_ index: Int, _ snapshot: Snapshot, _ mode: HarmonicBridgesDrawMode) -> Bool {
        guard mode.glow else { return false }
        let step: Int = drawnStep(snapshot, mode)
        if snapshot.isReached(index, step: step) { return true }
        for (s, string) in snapshot.strings.enumerated() where snapshot.isBridge(s, step: step) {
            if string.a == index || string.b == index { return true }
        }
        return false
    }

    /// The first island top of `snapshot` inside the picture and clear of every other element (its index and pixel).
    static func firstClearTop(_ snapshot: Snapshot, _ mode: HarmonicBridgesDrawMode, width: Int = width,
                              height: Int = height) -> (index: Int, p: SIMD2<Double>)? {
        let elements: [SIMD2<Double>] = elementPixels(snapshot, mode, width: width, height: height)
        let hulls: [[SIMD2<Double>]] = islandHulls(snapshot, width: width, height: height)
        for index in snapshot.islands.indices {
            guard let p = pixel(Geometry.islandTop(index, snapshot), snapshot, width: width, height: height),
                  inside(p, width: width, height: height),
                  isClear(p, among: elements, hulls: hulls, ownIsland: index) else { continue }
            return (index, p)
        }
        return nil
    }

    /// The drawn membranes' check points of `snapshot` clear of every other element (string index and pixel).
    static func clearMembranes(_ snapshot: Snapshot, _ mode: HarmonicBridgesDrawMode, width: Int = width,
                               height: Int = height) -> [(index: Int, p: SIMD2<Double>)] {
        let elements: [SIMD2<Double>] = elementPixels(snapshot, mode, width: width, height: height)
        let hulls: [[SIMD2<Double>]] = islandHulls(snapshot, width: width, height: height)
        let step: Int = drawnStep(snapshot, mode)
        var result: [(index: Int, p: SIMD2<Double>)] = []
        for index in snapshot.strings.indices where snapshot.isBridge(index, step: step) {
            guard let p = pixel(Geometry.membraneMidpoint(index, snapshot), snapshot, width: width, height: height),
                  inside(p, width: width, height: height), isClear(p, among: elements, hulls: hulls) else { continue }
            result.append((index, p))
        }
        return result
    }

    /// The island-top and membrane checks of clarification Q3 (see the file header) on `rgba` against `snapshot`.
    static func pointReport(_ rgba: [UInt8], snapshot: Snapshot, mode: HarmonicBridgesDrawMode, width: Int = width,
                            height: Int = height) -> HarmonicBridgesFrameReport {
        var report = HarmonicBridgesFrameReport()
        let elements: [SIMD2<Double>] = elementPixels(snapshot, mode, width: width, height: height)
        let hulls: [[SIMD2<Double>]] = islandHulls(snapshot, width: width, height: height)
        for index in snapshot.islands.indices {
            guard let p = pixel(Geometry.islandTop(index, snapshot), snapshot, width: width, height: height),
                  inside(p, width: width, height: height) else {
                report.misses.append("island \(index): it does not project into the picture")
                continue
            }
            if !isClear(p, among: elements, hulls: hulls, ownIsland: index) {
                report.topExcluded += 1
                continue
            }
            report.topChecked += 1
            let hue: Bool = !isGlowing(index, snapshot, mode)
            if hue { report.copperChecked += 1 }
            let found: Bool = hue
                ? anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height, where: isCopperTop)
                : anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height, where: isTop)
            if !found {
                let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
                let kind: String = hue ? "copper island" : "island"
                report.misses.append(kind + String(format: " %ld (%.1f, %.1f) is (%.3f, %.3f, %.3f)", index, p.x,
                                                   p.y, c.x, c.y, c.z))
            }
        }
        let step: Int = drawnStep(snapshot, mode)
        for index in snapshot.strings.indices where snapshot.isBridge(index, step: step) {
            guard let p = pixel(Geometry.membraneMidpoint(index, snapshot), snapshot, width: width, height: height),
                  inside(p, width: width, height: height) else {
                report.misses.append("membrane \(index): it does not project into the picture")
                continue
            }
            if !isClear(p, among: elements, hulls: hulls) {
                report.membraneExcluded += 1
                continue
            }
            report.membraneChecked += 1
            if !anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height, where: isMembrane) {
                let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
                report.misses.append(String(format: "membrane %ld (%.1f, %.1f) is (%.3f, %.3f, %.3f)", index, p.x,
                                            p.y, c.x, c.y, c.z))
            }
        }
        return report
    }

    /// The pixel of the gauge's first bar's centre (nil without a projection).
    static func gaugePixel(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> SIMD2<Double>? {
        pixel(Geometry.gaugeBar(0, snapshot), snapshot, width: width, height: height)
    }

    /// The gauge check: within 3 px of the first bar's centre, a pixel 0.1 away from the ground in luminance.
    static func gaugeMisses(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width,
                            height: Int = height) -> [String] {
        guard snapshot.budget > 0 else { return ["gauge: no budget"] }
        guard let p = gaugePixel(snapshot, width: width, height: height) else {
            return ["gauge bar 0: no projection"]
        }
        let ground: Double = groundLuminance
        let margin: Double = gaugeMargin
        let test: (SIMD3<Double>) -> Bool = { (c: SIMD3<Double>) -> Bool in
            Swift.abs(Self.luminance(c) - ground) >= margin
        }
        let found: Bool = anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height, where: test)
        return found ? [] : [String(format: "gauge bar 0 at (%.1f, %.1f) is ground", p.x, p.y)]
    }

    /// The background check: the pixels of the two probe corners are within 0.05 per channel of the ground.
    static func backgroundMisses(_ rgba: [UInt8], width: Int = width, height: Int = height) -> [String] {
        var misses: [String] = []
        for point in backgroundPoints {
            let got = pixelAtFraction(rgba, point.x, point.y, width: width, height: height)
            if channelDistance(got.colour, Palette.ground) > backgroundTolerance {
                misses.append(String(format: "background (%ld, %ld): (%.3f, %.3f, %.3f)", got.x, got.y,
                                     got.colour.x, got.colour.y, got.colour.z))
            }
        }
        return misses
    }

    /// Runs the checks of clarification Q3 on `rgba` against `snapshot` drawn in `mode`, recording an issue per
    /// failure, and returns the report. `require` true (the tuned frames at the check size) also requires at least one
    /// island top, one copper-hued island top and one membrane check point to be measured.
    @discardableResult
    static func checkFrame(_ rgba: [UInt8], snapshot: Snapshot, mode: HarmonicBridgesDrawMode, width: Int = width,
                           height: Int = height, require: Bool = true, _ what: String,
                           sourceLocation: SourceLocation = #_sourceLocation) -> HarmonicBridgesFrameReport {
        #expect(rgba.count == width * height * 4, "\(what): picture size", sourceLocation: sourceLocation)
        guard rgba.count == width * height * 4 else { return HarmonicBridgesFrameReport() }
        let report: HarmonicBridgesFrameReport = pointReport(rgba, snapshot: snapshot, mode: mode, width: width,
                                                             height: height)
        if require {
            #expect(report.topChecked > 0, "\(what): no island top clear of the other elements",
                    sourceLocation: sourceLocation)
            #expect(report.copperChecked > 0, "\(what): no copper-checked island top", sourceLocation: sourceLocation)
            #expect(report.membraneChecked > 0, "\(what): no membrane check point clear of the other elements",
                    sourceLocation: sourceLocation)
        }
        let shown: [String] = Array(report.misses.prefix(8))
        #expect(report.misses.isEmpty, "\(what): \(shown)", sourceLocation: sourceLocation)
        let gauge: [String] = gaugeMisses(rgba, snapshot: snapshot, width: width, height: height)
        #expect(gauge.isEmpty, "\(what): \(gauge)", sourceLocation: sourceLocation)
        let background: [String] = backgroundMisses(rgba, width: width, height: height)
        #expect(background.isEmpty, "\(what): \(background)", sourceLocation: sourceLocation)
        let tops: String = String(format: "top checked %ld (copper %ld), excluded %ld", report.topChecked,
                                  report.copperChecked, report.topExcluded)
        let membranes: String = String(format: "membrane checked %ld, excluded %ld", report.membraneChecked,
                                       report.membraneExcluded)
        print("harmonic-bridges \(what): \(tops); \(membranes)")
        return report
    }

    // MARK: Failure outline

    /// The pixels along string `index` at rest (u = 0.05 … 0.95) at least 6 px outside every island hull.
    static func stringSamples(_ index: Int, _ snapshot: Snapshot, width: Int = width,
                              height: Int = height) -> [SIMD2<Double>] {
        let hulls: [[SIMD2<Double>]] = islandHulls(snapshot, width: width, height: height)
        var result: [SIMD2<Double>] = []
        for j in 1...19 {
            let u: Double = Double(j) / 20
            guard let p = pixel(Geometry.stringPoint(index, u: u, y: Geometry.stringY, snapshot), snapshot,
                                width: width, height: height), inside(p, width: width, height: height) else { continue }
            var clear: Bool = true
            for hull in hulls where hullDistance(hull, p) < clearance { clear = false }
            if clear { result.append(p) }
        }
        return result
    }

    /// How many of `points` have, within `radius`, a pixel of the broken outline colour.
    static func outlineHits(_ rgba: [UInt8], _ points: [SIMD2<Double>], radius: Double = 5, width: Int = width,
                            height: Int = height) -> Int {
        var hits: Int = 0
        for p in points where anyPixel(rgba, near: p, radius: radius, width: width, height: height,
                                       where: isBrokenOutline) {
            hits += 1
        }
        return hits
    }

    // MARK: Tier geometry

    /// The positions of `mesh` without the wave shells' vertices (material code 10, drawn only at level-0).
    static func positionsWithoutWaveShells(_ mesh: Mesh) -> [Vec3] {
        var result: [Vec3] = []
        let shell: Int = HarmonicBridgesMaterial.waveShell.rawValue
        for index in mesh.positions.indices {
            let code: Int = index < mesh.uvs.count ? Int(mesh.uvs[index].x.rounded()) : -1
            if code != shell { result.append(mesh.positions[index]) }
        }
        return result
    }
}
#endif
