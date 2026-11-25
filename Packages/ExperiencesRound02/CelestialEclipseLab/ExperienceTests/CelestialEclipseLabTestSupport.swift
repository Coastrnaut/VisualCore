// CelestialEclipseLabTestSupport — feature 463 (R02-G17-03) T-R02G1703-006 (FR-R02G1703-001 … 007; clarifications
// Q1–Q4). Shared helpers of the Celestial Eclipse Lab experience tests, following Starlit Cartouche's harness (feature
// 453): opening the experience through the one app's session host (seed `s` prepares certified level `s % 100 + 1`; a
// session without a quality pin is pinned to level 0), issuing kernel actions through the shell, drawing live frames,
// drawing an off-screen still (RGBA8, rows top-down, the orientation of the Core's CPU projection
// `CelestialEclipseLabSceneGeometry.project`, origin top left, y down, scaled here to pixels), the engine digest, the
// frame checks of clarification Q3 at 1,152 × 768 at the shown tick 0, and a short search for a run that fails with a
// clear failing mark.
//
// There is no glide: the shown tick is the adapter's presentation state and is never advanced by time, and the only
// time-driven value is the halo pulse (`u_pulse`, 1 at frame time 0 and under Reduce Motion). Every still here is drawn
// at frame time 0 unless a test says otherwise.
//
// The CPU reference: the painter's order of `CelestialEclipseLabSceneGeometry.paintOrder` (farthest first; ties by
// kind, then index) with every element's projected footprint (world sizes of the geometry's constants): an orbital
// ring's ribbon through every orbit position (half `ringWidth`), its notch annulus around the body and a fixed body's
// square frame; the chosen ring's annulus; a body's disc of radius r · s (and the broken outline ring when the failure
// names it); a crescent shadow's lens (the hull of `shadowLens` at `shadowZ`); a halo's annulus; the timeline strip; a
// bracket's box (with the broken frame of a horizon failure); a mark's diamond or cross with its frame; the end mark;
// the playhead's line; an actions bar's rectangle. A point is checked only when it projects into the picture at least
// 6 px from every element drawn after it that could hide its cue:
//   - a body's centre (a body that is not the back body of any eclipse under way at the shown tick): hidden by a later
//     orbital ring (its ribbon passes through its own body), shadow, body (conservative) and gauge; the chosen ring and
//     the halos are gold and keep it bright. Within 3 px a pixel is brighter than the backdrop at its height by 0.25 in
//     luminance;
//   - the first actions bar, when lit: hidden by every later element but another bar. Within 3 px red above blue by
//     0.08 (corona gold);
//   - the timeline strip's centre: hidden by every later element that is not a gauge (no gauge drawn over the strip is
//     backdrop-coloured). Within 3 px a pixel 0.1 from the backdrop in luminance;
//   - a lit or failing timeline mark: hidden by every later element but the playhead, a matched diamond, the failing
//     cross and the end mark (all with red above blue). Within 3 px red above blue by 0.08 (and, for a lit mark, 0.25
//     brighter than the backdrop);
//   - the backdrop: 9 × 9 patches at 3 % from the picture's edges and halfway along them, 24 px from every footprint;
//     the per-channel median of each is within 0.06 of the gradient (ink at the bottom of the backdrop quad, ink top at
//     its top) at its height, or of the median of the shader's CPU reference
//     `CelestialEclipseLabShaders.backdropColour` over the patch (a speck the reference predicts).
// The backdrop quad faces the eye at one depth, so its projection is affine: its height h (0 bottom … 1 top) and
// horizontal coordinate s (−1 left … +1 right) at a pixel are read off the projections of its edge midpoints, taken
// from the sky mesh's vertices of material code 0 (the backdrop) and their a_uv.y. Luminance is the Rec. 709 weighting
// of the stored 0 … 1 channel values. Positions come from the presenter's `lastSnapshot`. Short runs only (no sleep, no
// wall-clock assertion).
//
// The checked levels are catalog levels 1, 21, 41, 61 and 81 (seeds 0, 20, 40, 60, 80).
#if os(iOS)
import CelestialEclipseLabCore
import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import CelestialEclipseLabExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the point checks of one frame found.
struct CelestialEclipseLabCheckReport {
    /// The body centres measured and those left out (covered at the shown tick or within 6 px of a later element).
    var bodiesChecked: Int = 0
    var bodiesExcluded: Int = 0
    /// Whether the first actions bar was measured.
    var barChecked: Bool = false
    /// Whether the timeline strip's centre was measured.
    var stripChecked: Bool = false
    /// The backdrop patches measured.
    var patchesChecked: Int = 0
    /// Every failed check, in words.
    var misses: [String] = []
}

/// A projected strip: the segment `a` … `b` grown by `half` pixels (a disc when `a == b`).
struct CelestialEclipseLabTestCapsule {
    var a: SIMD2<Double>
    var b: SIMD2<Double>
    var half: Double
}

/// A projected annulus: the circle of `radius` pixels around `centre` grown by `half` pixels on each side.
struct CelestialEclipseLabTestRing {
    var centre: SIMD2<Double>
    var radius: Double
    var half: Double
}

/// The projected footprint of one drawn element (pixels, y down).
struct CelestialEclipseLabTestFootprint {
    var hulls: [[SIMD2<Double>]] = []
    var capsules: [CelestialEclipseLabTestCapsule] = []
    var rings: [CelestialEclipseLabTestRing] = []

    /// The signed distance (pixels) of `p` from the footprint: negative inside, infinite for an empty footprint.
    func distance(_ p: SIMD2<Double>) -> Double {
        var best: Double = Double.infinity
        for hull in hulls { best = Swift.min(best, CelestialEclipseLabTest.hullDistance(hull, p)) }
        for capsule in capsules {
            best = Swift.min(best, CelestialEclipseLabTest.segmentDistance(p, capsule.a, capsule.b) - capsule.half)
        }
        for ring in rings {
            let d: SIMD2<Double> = p - ring.centre
            let r: Double = (d.x * d.x + d.y * d.y).squareRoot()
            best = Swift.min(best, Swift.abs(r - ring.radius) - ring.half)
        }
        return best
    }
}

/// The painter's order of one snapshot on one target with every element's footprint (same indices).
struct CelestialEclipseLabTestLayout {
    var order: [CelestialEclipseLabElement] = []
    var footprints: [CelestialEclipseLabTestFootprint] = []

    /// The place of the element drawing `part` for `item` in the painter's order, or nil.
    func rank(_ part: CelestialEclipseLabElement.Part, _ item: Int) -> Int? {
        for (place, element) in order.enumerated() where element.part == part && element.item == item {
            return place
        }
        return nil
    }

    /// Whether `p` lies at least `clearance` pixels from every element painted after place `rank` that `hides`.
    func isClear(_ p: SIMD2<Double>, after rank: Int, clearance: Double,
                 hides: (CelestialEclipseLabElement) -> Bool) -> Bool {
        var place: Int = rank + 1
        while place < order.count {
            if hides(order[place]), footprints[place].distance(p) < clearance { return false }
            place += 1
        }
        return true
    }

    /// The smallest distance (pixels) of `p` from any footprint.
    func minimumDistance(_ p: SIMD2<Double>) -> Double {
        var best: Double = Double.infinity
        for footprint in footprints { best = Swift.min(best, footprint.distance(p)) }
        return best
    }
}

/// The backdrop quad's projection on one target: its edge midpoints in pixels.
struct CelestialEclipseLabTestBackdrop {
    var bottom: SIMD2<Double>
    var top: SIMD2<Double>
    var left: SIMD2<Double>
    var right: SIMD2<Double>

    /// The backdrop's height h (0 at the quad's bottom, 1 at its top) at pixel row `y`.
    func height(_ y: Double) -> Double {
        let span: Double = top.y - bottom.y
        return span != 0 ? (y - bottom.y) / span : 0.5
    }

    /// The backdrop's horizontal coordinate s (−1 at the quad's left edge, +1 at its right) at pixel column `x`.
    func horizontal(_ x: Double) -> Double {
        let span: Double = right.x - left.x
        return span != 0 ? -1 + 2 * (x - left.x) / span : 0
    }

    /// The gradient colour (ink → ink top) at pixel (`x`, `y`).
    func gradient(x: Double, y: Double) -> SIMD3<Double> {
        let h: Double = Swift.min(Swift.max(height(y), 0), 1)
        let ink: SIMD3<Double> = CelestialEclipseLabPalette.ink
        return ink + (CelestialEclipseLabPalette.inkTop - ink) * h
    }

    /// The shader's CPU reference colour (gradient and specks) at pixel (`x`, `y`).
    func reference(x: Double, y: Double) -> SIMD3<Double> {
        CelestialEclipseLabShaders.backdropColour(height: height(y), horizontal: horizontal(x))
    }
}

/// A run that fails with its failing mark clear of every later element: the level, the set-up before the run and the
/// failing mark's pixel at the check size.
struct CelestialEclipseLabFailureCase {
    /// The catalog level number.
    var number: Int
    /// The phase changes made before the run.
    var setUp: [CelestialEclipseLabAction]
    /// The failing mark's projected centre (pixels at 1,152 × 768).
    var mark: SIMD2<Double>
    /// Whether the failure is the horizon's (the end mark) rather than an unwanted or window event's (a cross).
    var horizon: Bool
}

/// Building, opening, drawing and measuring Celestial Eclipse Lab.
@MainActor
enum CelestialEclipseLabTest {
    typealias Geometry = CelestialEclipseLabSceneGeometry
    typealias Palette = CelestialEclipseLabPalette
    typealias Snapshot = CelestialEclipseLabSceneSnapshot
    typealias Shell = ExperienceShell<CelestialEclipseLabPresenter>
    typealias Element = CelestialEclipseLabElement
    typealias Part = CelestialEclipseLabElement.Part

    /// The experience id `r02-g17.celestial-eclipse-lab`.
    static var id: ExperienceID {
        CelestialEclipseLabExperience.id ?? ExperienceID(rawValue: "r02-g17.unknown")!
    }

    /// The frame-check size of clarification Q3, aspect 1.5.
    static let width: Int = 1_152
    static let height: Int = 768
    /// The checked catalog levels and their seeds (seed = level − 1).
    static let levels: [Int] = [1, 21, 41, 61, 81]
    static let seeds: [UInt64] = [0, 20, 40, 60, 80]
    /// The search radius (pixels) of the point checks.
    static let pointRadius: Double = 3
    /// The clearance (pixels) of every checked point from every element drawn after it.
    static let clearance: Double = 6
    /// A body's centre (and a lit mark) is brighter than the backdrop by at least this luminance.
    static let bodyMargin: Double = 0.25
    /// The first actions bar's (and a mark's) red above blue.
    static let hueMargin: Double = 0.08
    /// The timeline strip's luminance difference from the backdrop.
    static let stripMargin: Double = 0.1
    /// The per-channel bound of a backdrop patch's median.
    static let backdropTolerance: Double = 0.06
    /// A backdrop patch's half side (pixels; 9 × 9) and its clearance from every footprint.
    static let patchHalf: Int = 4
    static let patchClearance: Double = 24
    /// The backdrop patch centres (fractions of the view, origin top left).
    static let patchFractions: [(x: Double, y: Double)] = [
        (0.03, 0.03), (0.5, 0.03), (0.97, 0.03), (0.03, 0.5), (0.97, 0.5), (0.03, 0.97), (0.5, 0.97), (0.97, 0.97),
    ]

    /// Opens Celestial Eclipse Lab with `seed` in `session` through the factory, lays the view out at `size` points and
    /// draws one frame. A session without a quality pin is pinned to level 0. `configure` runs on the presenter before
    /// its first `setup` (the fallback seam).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false, size: CGSize = CGSize(width: 48, height: 32),
                     configure: ((CelestialEclipseLabPresenter) -> Void)? = nil) async throws -> Shell {
        let id: ExperienceID = self.id
        var made: Shell?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: seed) {
            let shell: Shell = CelestialEclipseLabExperience.make(id: id, reduceMotion: reduceMotion,
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
    static func core(_ shell: Shell) throws -> CelestialEclipseLabExperienceCore {
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
    nonisolated static func control(_ action: CelestialEclipseLabAction) -> (control: String, values: [Double]) {
        switch action {
        case let .phase(body, offset):
            ("orbit.phase", [Double(body), Double(offset)])
        case .run:
            ("clock.run", [])
        }
    }

    /// The host action of `action` (step 0).
    nonisolated static func experienceAction(_ action: CelestialEclipseLabAction) -> ExperienceAction {
        let issued = control(action)
        return ExperienceAction(control: issued.control, values: issued.values, step: 0)
    }

    /// The certified plan of level `number`: its minimal phase changes (the run not included).
    nonisolated static func certifiedPlan(_ number: Int) throws -> [CelestialEclipseLabAction] {
        try CelestialEclipseLabExperienceCore.generated(number: number).plan.actions
    }

    /// Issues `actions` through the shell, each expected to be accepted; returns how many were.
    @discardableResult
    static func issue(_ shell: Shell, _ actions: [CelestialEclipseLabAction],
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
    static func coreAfter(_ number: Int,
                          _ actions: [CelestialEclipseLabAction]) throws -> CelestialEclipseLabExperienceCore {
        var core: CelestialEclipseLabExperienceCore = try CelestialEclipseLabExperienceCore.opening(number: number)
        for action in actions {
            let result: ActionResult = core.apply(experienceAction(action))
            #expect(result == .accepted, "level \(number) \(action): \(result.code)")
        }
        return core
    }

    /// The kernel's body positions of `play` at `tick` for its current phases.
    nonisolated static func kernelPositions(_ play: CelestialEclipseLabPlay,
                                            tick: Int) -> [CelestialEclipseLabVector] {
        var positions: [CelestialEclipseLabVector] = []
        let bodies: [CelestialEclipseLabBody] = play.level.bodies
        for index in bodies.indices {
            positions.append(bodies[index].position(at: tick, phase: play.phases[index]))
        }
        return positions
    }

    /// The set-ups tried before a run in ``failureCase(candidates:)``: none, every proper prefix of the certified plan,
    /// then single phase changes of each movable body (at most `limit` set-ups in all).
    static func setUps(_ number: Int, limit: Int = 24) throws -> [[CelestialEclipseLabAction]] {
        var result: [[CelestialEclipseLabAction]] = [[]]
        let plan: [CelestialEclipseLabAction] = try certifiedPlan(number)
        var length: Int = 1
        while length < plan.count {
            result.append(Array(plan.prefix(length)))
            length += 1
        }
        let level: CelestialEclipseLabLevel = try CelestialEclipseLabExperienceCore.level(number: number)
        let opening: CelestialEclipseLabExperienceCore = try CelestialEclipseLabExperienceCore.opening(number: number)
        for body in level.bodies.indices where !level.bodies[body].fixed {
            for offset in 0..<level.bodies[body].period where offset != opening.play.phases[body] {
                guard result.count < limit else { return result }
                result.append([.phase(body, offset)])
            }
        }
        return result
    }

    /// The first run over `candidates` (level numbers) after one of ``setUps(_:limit:)`` that fails and whose failing
    /// mark (the cross of an unwanted or window event, or the end mark of a horizon failure) projects into the picture
    /// clear of every later element that could hide its colour; nil when none does.
    static func failureCase(candidates: [Int]) throws -> CelestialEclipseLabFailureCase? {
        for number in candidates {
            for setUp in try setUps(number) {
                var core: CelestialEclipseLabExperienceCore = try CelestialEclipseLabExperienceCore.opening(
                    number: number)
                var accepted: Bool = true
                let actions: [CelestialEclipseLabAction] = setUp + [.run]
                for action in actions {
                    let result: ActionResult = core.apply(experienceAction(action))
                    if result != .accepted { accepted = false }
                }
                guard accepted, core.play.stage == .failed else { continue }
                let snapshot: Snapshot = core.snapshot(time: 0)
                guard let found = failingMark(snapshot) else { continue }
                return CelestialEclipseLabFailureCase(number: number, setUp: setUp, mark: found.pixel,
                                                      horizon: found.horizon)
            }
        }
        return nil
    }

    /// The failing mark of `snapshot` at the check size when it is clear of every later element that could hide its
    /// colour: its pixel and whether it is the horizon's end mark; nil otherwise.
    static func failingMark(_ snapshot: Snapshot, width: Int = width,
                            height: Int = height) -> (pixel: SIMD2<Double>, horizon: Bool)? {
        let o: CelestialEclipseLabTestLayout = layout(snapshot, width: width, height: height)
        let horizon: Bool = Geometry.isHorizonFailure(snapshot)
        let place: Int?
        if horizon {
            place = o.rank(.endMark, 0)
        } else if let interval = Geometry.failingInterval(snapshot) {
            place = o.rank(.mark, interval)
        } else {
            place = nil
        }
        guard let rank = place else { return nil }
        let element: Element = o.order[rank]
        guard let p = pixel(element.centre, snapshot, width: width, height: height),
              inside(p, width: width, height: height) else { return nil }
        let clear: Bool = o.isClear(p, after: rank, clearance: clearance) { markHides($0, snapshot) }
        return clear ? (p, horizon) : nil
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

    /// Whether `c` has red above blue by at least 0.08 (corona gold, ember, the broken colour).
    static func isReddish(_ c: SIMD3<Double>) -> Bool {
        c.x - c.z >= hueMargin
    }

    /// The number of pixels brighter than the backdrop's top colour by 0.1 in luminance (anything drawn on it).
    static func drawnPixels(_ rgba: [UInt8]) -> Int {
        let floor: Double = luminance(Palette.inkTop) + 0.1
        var count: Int = 0
        var i: Int = 0
        while i + 3 < rgba.count {
            let c = SIMD3<Double>(Double(rgba[i]) / 255, Double(rgba[i + 1]) / 255, Double(rgba[i + 2]) / 255)
            if luminance(c) > floor { count += 1 }
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

    /// The colour of the pixel that holds `p`, clamped to the picture.
    static func centre(_ rgba: [UInt8], _ p: SIMD2<Double>, width: Int = width, height: Int = height) -> SIMD3<Double> {
        let x: Int = Swift.min(Swift.max(Int(p.x.rounded(.down)), 0), width - 1)
        let y: Int = Swift.min(Swift.max(Int(p.y.rounded(.down)), 0), height - 1)
        return colour(rgba, x: x, y: y, width: width)
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

    /// The per-channel median of `colours` (black for none).
    nonisolated static func median(_ colours: [SIMD3<Double>]) -> SIMD3<Double> {
        guard !colours.isEmpty else { return SIMD3<Double>(0, 0, 0) }
        var reds: [Double] = []
        var greens: [Double] = []
        var blues: [Double] = []
        for c in colours {
            reds.append(c.x)
            greens.append(c.y)
            blues.append(c.z)
        }
        reds.sort()
        greens.sort()
        blues.sort()
        let m: Int = colours.count / 2
        return SIMD3<Double>(reds[m], greens[m], blues[m])
    }

    // MARK: Vectors

    /// The dot product of `a` and `b`.
    nonisolated static func dot3(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        a.x * b.x + a.y * b.y + a.z * b.z
    }

    /// The cross product a × b.
    nonisolated static func cross3(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3<Double>(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
    }

    /// `v` scaled to unit length (unchanged when zero).
    nonisolated static func unit3(_ v: SIMD3<Double>) -> SIMD3<Double> {
        let l: Double = dot3(v, v).squareRoot()
        return l > 0 ? v / l : v
    }

    /// `camera`'s right and up vectors (from its eye towards its target, +y up), as the geometry's camera-facing
    /// pieces use them.
    nonisolated static func viewBasis(_ camera: CelestialEclipseLabCamera)
        -> (right: SIMD3<Double>, up: SIMD3<Double>) {
        let forward: SIMD3<Double> = unit3(camera.target - camera.eye)
        let right: SIMD3<Double> = unit3(cross3(forward, SIMD3<Double>(0, 1, 0)))
        return (right, cross3(right, forward))
    }

    // MARK: CPU reference (clarification Q3)

    /// The camera the scene uses for `snapshot` on a `width` × `height` target.
    static func camera(_ snapshot: Snapshot, width: Int, height: Int) -> CelestialEclipseLabCamera {
        Geometry.camera(snapshot, aspect: Double(width) / Double(height))
    }

    /// The pixel of world point `point` through `camera` on a `width` × `height` target (nil without a projection).
    static func project(_ point: SIMD3<Double>, _ camera: CelestialEclipseLabCamera, width: Int,
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

    /// The pixels of the geometry's reference points (`referencePoints`: every body's centre, the timeline strip's
    /// centre, each target bracket, the playhead and the first actions bar) in their order (nil without a projection);
    /// empty for an empty target.
    static func referencePixels(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> [SIMD2<Double>?] {
        var result: [SIMD2<Double>?] = []
        guard width > 0, height > 0 else { return result }
        let cam: CelestialEclipseLabCamera = camera(snapshot, width: width, height: height)
        for element in Geometry.referencePoints(snapshot, camera: cam) {
            result.append(project(element.centre, cam, width: width, height: height))
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

    /// The signed distance (pixels) of `p` from the convex polygon `hull` (corners in the order `convexHull` gives
    /// them): negative inside (infinite for fewer than three corners).
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

    /// Whether `p` lies inside a `width` × `height` picture.
    static func inside(_ p: SIMD2<Double>, width: Int, height: Int) -> Bool {
        p.x >= 0 && p.y >= 0 && p.x < Double(width) && p.y < Double(height)
    }

    /// The pixel length of the camera-facing world length `length` at `centre` (along the view's right vector).
    static func pixelLength(_ length: Double, at centre: SIMD3<Double>, _ camera: CelestialEclipseLabCamera,
                            width: Int, height: Int) -> Double {
        let right: SIMD3<Double> = viewBasis(camera).right
        guard let a = project(centre, camera, width: width, height: height),
              let b = project(centre + right * length, camera, width: width, height: height) else {
            return 0
        }
        let d: SIMD2<Double> = b - a
        return (d.x * d.x + d.y * d.y).squareRoot()
    }

    /// The projected strip of half width `half` (world units) from `a` to `b`, or nil without a projection.
    static func strip(_ a: SIMD3<Double>, _ b: SIMD3<Double>, half: Double, _ camera: CelestialEclipseLabCamera,
                      width: Int, height: Int) -> CelestialEclipseLabTestCapsule? {
        guard let pa = project(a, camera, width: width, height: height),
              let pb = project(b, camera, width: width, height: height) else { return nil }
        let w: Double = pixelLength(half, at: (a + b) / 2, camera, width: width, height: height)
        return CelestialEclipseLabTestCapsule(a: pa, b: pb, half: w)
    }

    /// The projected camera-facing disc of `radius` (world units) around `centre`, or nil without a projection.
    static func disc(_ centre: SIMD3<Double>, radius: Double, _ camera: CelestialEclipseLabCamera, width: Int,
                     height: Int) -> CelestialEclipseLabTestCapsule? {
        strip(centre, centre, half: radius, camera, width: width, height: height)
    }

    /// The projected camera-facing annulus of `radius` and half width `half` (world units) around `centre`.
    static func ring(_ centre: SIMD3<Double>, radius: Double, half: Double, _ camera: CelestialEclipseLabCamera,
                     width: Int, height: Int) -> CelestialEclipseLabTestRing? {
        guard let p = project(centre, camera, width: width, height: height) else { return nil }
        return CelestialEclipseLabTestRing(centre: p, radius: pixelLength(radius, at: centre, camera, width: width,
                                                                          height: height),
                                           half: pixelLength(half, at: centre, camera, width: width, height: height))
    }

    /// The hull of the camera-facing rectangle of half sizes `half` (world units) around `centre`.
    static func billboardHull(_ centre: SIMD3<Double>, half: SIMD2<Double>, _ camera: CelestialEclipseLabCamera,
                              width: Int, height: Int) -> [SIMD2<Double>] {
        let basis = viewBasis(camera)
        let r: SIMD3<Double> = basis.right * half.x
        let u: SIMD3<Double> = basis.up * half.y
        var projected: [SIMD2<Double>] = []
        for corner in [centre - r - u, centre + r - u, centre + r + u, centre - r + u] {
            if let p = project(corner, camera, width: width, height: height) { projected.append(p) }
        }
        return convexHull(projected)
    }

    /// The four edges of the camera-facing square outline of half side `half` around `centre`, each a strip of half
    /// width `line` (world units).
    static func squareOutline(_ centre: SIMD3<Double>, half: Double, line: Double,
                              _ camera: CelestialEclipseLabCamera, width: Int,
                              height: Int) -> [CelestialEclipseLabTestCapsule] {
        let basis = viewBasis(camera)
        let r: SIMD3<Double> = basis.right * half
        let u: SIMD3<Double> = basis.up * half
        let corners: [SIMD3<Double>] = [centre - r - u, centre + r - u, centre + r + u, centre - r + u]
        var result: [CelestialEclipseLabTestCapsule] = []
        for k in 0..<4 {
            if let s = strip(corners[k], corners[(k + 1) % 4], half: line, camera, width: width, height: height) {
                result.append(s)
            }
        }
        return result
    }

    /// The projected footprint of `element` of `snapshot` (see the file header).
    static func footprint(_ element: Element, _ snapshot: Snapshot, _ cam: CelestialEclipseLabCamera,
                          width: Int, height: Int) -> CelestialEclipseLabTestFootprint {
        var f = CelestialEclipseLabTestFootprint()
        let i: Int = element.item
        let c: SIMD3<Double> = element.centre
        switch element.part {
        case .orbit:
            guard i >= 0, i < snapshot.bodies.count else { return f }
            let body: CelestialEclipseLabBody = snapshot.bodies[i]
            let n: Int = body.orbit.count
            for k in 0..<n {
                let a: SIMD3<Double> = Geometry.world(body.orbit[k], snapshot)
                let b: SIMD3<Double> = Geometry.world(body.orbit[(k + 1) % n], snapshot)
                if let s = strip(a, b, half: Geometry.ringWidth / 2, cam, width: width, height: height) {
                    f.capsules.append(s)
                }
            }
            let centre: SIMD3<Double> = Geometry.bodyCentre(i, snapshot)
            let r: Double = Geometry.bodyRadius(i, snapshot)
            let notchMiddle: Double = r + (Geometry.notchInner + Geometry.notchOuter) / 2
            let notchHalf: Double = (Geometry.notchOuter - Geometry.notchInner) / 2 + Geometry.notchWidth
            if let notches = ring(centre, radius: notchMiddle, half: notchHalf, cam, width: width, height: height) {
                f.rings.append(notches)
            }
            if body.fixed {
                f.capsules += squareOutline(centre, half: r + Geometry.frameOffset, line: Geometry.frameWidth / 2,
                                            cam, width: width, height: height)
            }
        case .chosen:
            let radius: Double = Geometry.bodyRadius(i, snapshot) + Geometry.chosenOffset
            if let r = ring(c, radius: radius, half: Geometry.chosenWidth / 2, cam, width: width, height: height) {
                f.rings.append(r)
            }
        case .body:
            let r: Double = Geometry.bodyRadius(i, snapshot)
            if let d = disc(c, radius: r, cam, width: width, height: height) { f.capsules.append(d) }
            if let pair = Geometry.failureBodies(snapshot), pair.front == i || pair.back == i,
               let outline = ring(c, radius: r + Geometry.outlineOffset, half: Geometry.outlineWidth / 2, cam,
                                  width: width, height: height) {
                f.rings.append(outline)
            }
        case .shadow:
            guard i >= 0, i < snapshot.eclipses.count else { return f }
            let eclipse: CelestialEclipseLabEclipse = snapshot.eclipses[i]
            let z: Double = Geometry.shadowZ(eclipse, snapshot)
            var projected: [SIMD2<Double>] = []
            for q in Geometry.shadowLens(eclipse, snapshot) {
                let lifted = SIMD3<Double>(q.x, q.y, z)
                if let p = project(lifted, cam, width: width, height: height) { projected.append(p) }
            }
            f.hulls.append(convexHull(projected))
        case .halo:
            guard i >= 0, i < snapshot.eclipses.count else { return f }
            let r: Double = Geometry.bodyRadius(snapshot.eclipses[i].front, snapshot)
            if let h = ring(c, radius: r + Geometry.haloWidth / 2, half: Geometry.haloWidth / 2, cam, width: width,
                            height: height) { f.rings.append(h) }
        case .strip:
            if let s = strip(Geometry.tickPosition(0, snapshot), Geometry.tickPosition(snapshot.horizon - 1, snapshot),
                             half: Geometry.stripHeight / 2, cam, width: width, height: height) {
                f.capsules.append(s)
            }
        case .bracket:
            let ends: (Double, Double) = Geometry.bracketEnds(i, snapshot)
            let notches: Double = Double(Geometry.bracketNotches(i)) * Geometry.bracketNotchSpacing / 2
            var halfWidth: Double = Swift.max((ends.1 - ends.0) / 2, notches) + Geometry.bracketLine
            var top: Double = Geometry.bracketNotchY + Geometry.bracketNotchSide / 2 + Geometry.bracketLine
            var bottom: Double = Geometry.bracketY - Geometry.bracketLeg - Geometry.bracketLine
            if Geometry.framedBracket(snapshot) == i {
                halfWidth += Geometry.outlineWidth
                top += Geometry.outlineWidth
                bottom -= Geometry.outlineWidth
            }
            let middle = SIMD3<Double>((ends.0 + ends.1) / 2, (top + bottom) / 2, Geometry.gaugeZ)
            f.hulls.append(billboardHull(middle, half: SIMD2<Double>(halfWidth, (top - bottom) / 2), cam,
                                         width: width, height: height))
        case .mark:
            let half: Double = Geometry.markMaterial(i, snapshot) == Geometry.materialCross
                ? Geometry.markFrame + Geometry.outlineWidth : Geometry.markSize
            f.hulls.append(billboardHull(c, half: SIMD2<Double>(half, half), cam, width: width, height: height))
        case .endMark:
            let half: Double = Geometry.markSize / 2.0.squareRoot() + Geometry.crossWidth
            f.hulls.append(billboardHull(c, half: SIMD2<Double>(half, half), cam, width: width, height: height))
        case .playhead:
            let reach = SIMD3<Double>(0, Geometry.playheadHalf, 0)
            if let s = strip(c - reach, c + reach, half: Geometry.playheadWidth / 2, cam, width: width,
                             height: height) { f.capsules.append(s) }
        case .bar:
            let half = SIMD2<Double>(Geometry.barFill * Geometry.actionsSlot(snapshot) / 2, Geometry.barHeight / 2)
            f.hulls.append(billboardHull(c, half: half, cam, width: width, height: height))
        }
        return f
    }

    /// The painter's order of `snapshot` on a `width` × `height` target with every element's footprint; empty for an
    /// empty target.
    static func layout(_ snapshot: Snapshot, width: Int = width,
                       height: Int = height) -> CelestialEclipseLabTestLayout {
        var result = CelestialEclipseLabTestLayout()
        guard width > 0, height > 0 else { return result }
        let cam: CelestialEclipseLabCamera = camera(snapshot, width: width, height: height)
        result.order = Geometry.paintOrder(snapshot, camera: cam)
        for element in result.order {
            result.footprints.append(footprint(element, snapshot, cam, width: width, height: height))
        }
        return result
    }

    /// The backdrop quad's projection for `snapshot` on a `width` × `height` target, read from the sky mesh's backdrop
    /// vertices (material code 0; a_uv.y 0 at the bottom, 1 at the top); nil for an empty target or a mesh without the
    /// four backdrop corners.
    static func backdrop(_ snapshot: Snapshot, width: Int = width,
                         height: Int = height) -> CelestialEclipseLabTestBackdrop? {
        guard width > 0, height > 0 else { return nil }
        let cheapest: CelestialEclipseLabTier = CelestialEclipseLabTier.all[CelestialEclipseLabTier.all.count - 1]
        guard let mesh = try? Geometry.skyMesh(snapshot, tier: cheapest) else { return nil }
        var corners: [(p: SIMD3<Double>, h: Double)] = []
        for index in mesh.positions.indices where index < mesh.uvs.count && Swift.abs(mesh.uvs[index].x) < 0.5 {
            let v: Vec3 = mesh.positions[index]
            corners.append((SIMD3<Double>(v.x, v.y, v.z), mesh.uvs[index].y))
        }
        guard corners.count == 4 else { return nil }
        let cam: CelestialEclipseLabCamera = camera(snapshot, width: width, height: height)
        let right: SIMD3<Double> = viewBasis(cam).right
        var bottom = SIMD3<Double>(0, 0, 0)
        var top = SIMD3<Double>(0, 0, 0)
        for corner in corners {
            if corner.h < 0.5 { bottom += corner.p / 2 } else { top += corner.p / 2 }
        }
        let sorted = corners.sorted { a, b in dot3(a.p, right) < dot3(b.p, right) }
        let left: SIMD3<Double> = (sorted[0].p + sorted[1].p) / 2
        let rightEdge: SIMD3<Double> = (sorted[2].p + sorted[3].p) / 2
        guard let pb = project(bottom, cam, width: width, height: height),
              let pt = project(top, cam, width: width, height: height),
              let pl = project(left, cam, width: width, height: height),
              let pr = project(rightEdge, cam, width: width, height: height) else { return nil }
        return CelestialEclipseLabTestBackdrop(bottom: pb, top: pt, left: pl, right: pr)
    }

    // MARK: Hiders (see the file header)

    /// Whether a later `element` can hide a body's brightness.
    nonisolated static func bodyHides(_ element: CelestialEclipseLabElement) -> Bool {
        switch element.part {
        case .chosen, .halo: false
        case .orbit, .body, .shadow, .strip, .bracket, .mark, .endMark, .playhead, .bar: true
        }
    }

    /// Whether a later `element` can hide the first actions bar's gold.
    nonisolated static func barHides(_ element: CelestialEclipseLabElement) -> Bool {
        element.part != .bar
    }

    /// Whether a later `element` can make the timeline strip's centre look like the backdrop.
    nonisolated static func stripHides(_ element: CelestialEclipseLabElement) -> Bool {
        element.kind != .gauge
    }

    /// Whether a later `element` can hide the red of a lit or failing mark (the playhead, matched diamonds, the
    /// failing cross and the end mark are all red above blue).
    nonisolated static func markHides(_ element: CelestialEclipseLabElement, _ snapshot: Snapshot) -> Bool {
        switch element.part {
        case .playhead, .endMark: return false
        case .mark: return Geometry.markMaterial(element.item, snapshot) == Geometry.materialFaint
        default: return true
        }
    }

    // MARK: Checks

    /// The lit timeline marks of `snapshot` (matched diamonds) that project into the picture clear of every later
    /// element that could hide their gold, with their interval index.
    static func clearLitMarks(_ snapshot: Snapshot, width: Int = width,
                              height: Int = height) -> [(interval: Int, pixel: SIMD2<Double>)] {
        let o: CelestialEclipseLabTestLayout = layout(snapshot, width: width, height: height)
        var result: [(interval: Int, pixel: SIMD2<Double>)] = []
        let lit: Int = Swift.min(Swift.max(snapshot.matched, 0), snapshot.intervals.count)
        for j in 0..<lit {
            guard let rank = o.rank(.mark, j),
                  let p = pixel(o.order[rank].centre, snapshot, width: width, height: height),
                  inside(p, width: width, height: height) else { continue }
            let clear: Bool = o.isClear(p, after: rank, clearance: clearance) { markHides($0, snapshot) }
            if clear { result.append((j, p)) }
        }
        return result
    }

    /// The backdrop patch check at view fraction (`fx`, `fy`): nil when the patch is not measured (outside the
    /// picture or near a footprint), else the miss in words or "" when it passed.
    static func patchResult(_ rgba: [UInt8], fx: Double, fy: Double, sky: CelestialEclipseLabTestBackdrop,
                            _ o: CelestialEclipseLabTestLayout, width: Int, height: Int) -> String? {
        let cx: Int = Swift.min(width - 1, Int(fx * Double(width)))
        let cy: Int = Swift.min(height - 1, Int(fy * Double(height)))
        guard cx - patchHalf >= 0, cy - patchHalf >= 0, cx + patchHalf < width, cy + patchHalf < height else {
            return nil
        }
        let p = SIMD2<Double>(Double(cx) + 0.5, Double(cy) + 0.5)
        guard o.minimumDistance(p) >= patchClearance else { return nil }
        var seen: [SIMD3<Double>] = []
        var predicted: [SIMD3<Double>] = []
        for y in (cy - patchHalf)...(cy + patchHalf) {
            for x in (cx - patchHalf)...(cx + patchHalf) {
                seen.append(colour(rgba, x: x, y: y, width: width))
                predicted.append(sky.reference(x: Double(x) + 0.5, y: Double(y) + 0.5))
            }
        }
        let got: SIMD3<Double> = median(seen)
        let gradient: SIMD3<Double> = sky.gradient(x: p.x, y: p.y)
        if channelDistance(got, gradient) <= backdropTolerance { return "" }
        if channelDistance(got, median(predicted)) <= backdropTolerance { return "" }
        let format: String = "backdrop patch (%ld, %ld) h %.3f: median (%.3f, %.3f, %.3f), gradient (%.3f, %.3f, "
            + "%.3f)"
        return String(format: format, cx, cy, sky.height(p.y), got.x, got.y, got.z, gradient.x, gradient.y,
                      gradient.z)
    }

    /// The body checks of clarification Q3 on `rgba` against `snapshot`, added to `report`.
    static func checkBodies(_ rgba: [UInt8], _ snapshot: Snapshot, _ o: CelestialEclipseLabTestLayout,
                            _ sky: CelestialEclipseLabTestBackdrop, width: Int, height: Int,
                            into report: inout CelestialEclipseLabCheckReport) {
        for index in snapshot.bodies.indices {
            // The back body of an eclipse under way is covered at the shown tick: not a bright centre.
            let covered: Bool = snapshot.eclipses.contains { eclipse in eclipse.back == index }
            guard !covered else {
                report.bodiesExcluded += 1
                continue
            }
            guard let p = pixel(Geometry.bodyCentre(index, snapshot), snapshot, width: width, height: height),
                  inside(p, width: width, height: height), let rank = o.rank(.body, index) else {
                report.misses.append("body \(index): it does not project into the picture")
                continue
            }
            let clear: Bool = o.isClear(p, after: rank, clearance: clearance, hides: bodyHides)
            if !clear {
                report.bodiesExcluded += 1
                continue
            }
            report.bodiesChecked += 1
            let floor: Double = luminance(sky.gradient(x: p.x, y: p.y)) + bodyMargin
            let bright: Bool = anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height,
                                        where: { luminance($0) >= floor })
            if !bright {
                let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
                report.misses.append(String(format: "body %ld (%.1f, %.1f) is (%.3f, %.3f, %.3f)", index, p.x, p.y,
                                            c.x, c.y, c.z))
            }
        }
    }

    /// The gauge checks of clarification Q3 (the first actions bar when lit, the timeline strip's centre) on `rgba`
    /// against `snapshot`, added to `report`.
    static func checkGauges(_ rgba: [UInt8], _ snapshot: Snapshot, _ o: CelestialEclipseLabTestLayout,
                            _ sky: CelestialEclipseLabTestBackdrop, width: Int, height: Int,
                            into report: inout CelestialEclipseLabCheckReport) {
        if Geometry.litActions(snapshot) > 0,
           let p = pixel(Geometry.actionsBar(0, snapshot), snapshot, width: width, height: height),
           inside(p, width: width, height: height), let rank = o.rank(.bar, 0) {
            let clear: Bool = o.isClear(p, after: rank, clearance: clearance, hides: barHides)
            if clear {
                report.barChecked = true
                if !anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height, where: isReddish) {
                    let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
                    report.misses.append(String(format: "actions bar 0 (%.1f, %.1f) is (%.3f, %.3f, %.3f)", p.x, p.y,
                                                c.x, c.y, c.z))
                }
            }
        }
        if let p = pixel(Geometry.timelineCentre(), snapshot, width: width, height: height),
           inside(p, width: width, height: height), let rank = o.rank(.strip, 0) {
            let clear: Bool = o.isClear(p, after: rank, clearance: clearance, hides: stripHides)
            if clear {
                report.stripChecked = true
                let back: Double = luminance(sky.gradient(x: p.x, y: p.y))
                let off: Bool = anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height,
                                         where: { Swift.abs(luminance($0) - back) >= stripMargin })
                if !off {
                    report.misses.append(String(format: "timeline strip centre (%.1f, %.1f) is backdrop-coloured",
                                                p.x, p.y))
                }
            }
        }
    }

    /// The point checks of clarification Q3 (see the file header) on `rgba` against `snapshot`.
    static func pointReport(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width,
                            height: Int = height) -> CelestialEclipseLabCheckReport {
        var report = CelestialEclipseLabCheckReport()
        let o: CelestialEclipseLabTestLayout = layout(snapshot, width: width, height: height)
        guard let sky = backdrop(snapshot, width: width, height: height) else {
            report.misses.append("no backdrop quad in the sky mesh")
            return report
        }
        checkBodies(rgba, snapshot, o, sky, width: width, height: height, into: &report)
        checkGauges(rgba, snapshot, o, sky, width: width, height: height, into: &report)
        for fraction in patchFractions {
            guard let result = patchResult(rgba, fx: fraction.x, fy: fraction.y, sky: sky, o, width: width,
                                           height: height) else { continue }
            report.patchesChecked += 1
            if !result.isEmpty { report.misses.append(result) }
        }
        return report
    }

    /// Runs the checks of clarification Q3 on `rgba` against `snapshot`, recording an issue per failure, and returns
    /// the report. `requireBody` also requires at least one body centre to be measured; a picture of at least 64 × 64
    /// must measure at least four backdrop patches.
    @discardableResult
    static func checkFrame(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width, height: Int = height,
                           requireBody: Bool = false, _ what: String,
                           sourceLocation: SourceLocation = #_sourceLocation) -> CelestialEclipseLabCheckReport {
        #expect(rgba.count == width * height * 4, "\(what): picture size", sourceLocation: sourceLocation)
        guard rgba.count == width * height * 4 else { return CelestialEclipseLabCheckReport() }
        let report: CelestialEclipseLabCheckReport = pointReport(rgba, snapshot: snapshot, width: width,
                                                                 height: height)
        if requireBody {
            #expect(report.bodiesChecked > 0, "\(what): no body centre clear of the later elements",
                    sourceLocation: sourceLocation)
        }
        if width >= 64 && height >= 64 {
            #expect(report.patchesChecked >= 4, "\(what): backdrop patches \(report.patchesChecked)",
                    sourceLocation: sourceLocation)
        }
        let shown: [String] = Array(report.misses.prefix(8))
        #expect(report.misses.isEmpty, "\(what): \(shown)", sourceLocation: sourceLocation)
        let bodies: String = String(format: "bodies checked %ld, excluded %ld", report.bodiesChecked,
                                    report.bodiesExcluded)
        print("celestial-eclipse-lab \(what): \(bodies); bar \(report.barChecked); strip \(report.stripChecked); "
              + "patches \(report.patchesChecked)")
        return report
    }
}
#endif
