// StarlitCartoucheTestSupport — feature 453 (R02-G16-03) T-R02G1603-006 (FR-R02G1603-001 … 007; clarifications
// Q1–Q4). Shared helpers of the Starlit Cartouche experience tests, following Voxel Origami's harness (feature 443):
// opening the experience through the one app's session host (seed `s` prepares certified level `s % 100 + 1`; a
// session without a quality pin is pinned to level 0), issuing kernel actions through the shell, drawing live frames,
// drawing an off-screen still (RGBA8, rows top-down, the orientation of the Core's CPU projection
// `StarlitCartoucheSceneGeometry.project`, origin top left, y down, scaled here to pixels), the engine digest, the
// frame checks of clarification Q3 at 1,152 × 768, and a short search through the chart for a leg that fails a level.
//
// The glide: the presenter places the ship along its newest trail by the share of `glideSeconds` since the frame at
// which the play last changed. A still drawn right after a change therefore shows glide 0. `prime` draws a small still
// at frame time −`glideSeconds` first (the snapshot's time is clamped to 0, the glide clock starts there), so the next
// still at frame time 0 shows the ship at rest (glide 1) and presentation time 0.
//
// The CPU reference: the painter's order of `StarlitCartoucheSceneGeometry.paintOrder` (farthest first, the ship at
// rest) with every element's projected footprint (world sizes of the geometry's header, the widest tier for the
// trails' ghosts): a corridor's ribbon 0.02, a hazard's 0.06, a trail's 0.05 widened by its three ghosts, the failed
// leg's 0.05, a star's disc to its notch tips 0.098 (and a failure's ring 0.158), the ship's disc of radius 0.07, the
// beacon's and the chosen ring's annuli, the cartouche's square, the bars', track's and pips' rectangles. A point is
// checked only when it projects into the picture at least 6 px from every element drawn after it that could hide its
// cue:
//   - a star's centre: hidden by a later solid corridor (#3A4478, only 0.2 above the night in luminance), hazard and
//     gauge; a later dashed symbol corridor, trail, ring or the ship keep it bright. Within 3 px a pixel is brighter
//     than the backdrop at its height by 0.25 in luminance;
//   - the ship's centre (at its star, at rest): hidden by every later element but a solid corridor (#3A4478 has blue
//     above red by 0.24) and the chosen ring (the ship's own sapphire). Within 3 px a pixel has blue above red by 0.08;
//   - a trail's midpoint (or, when that is hidden, a point at 0.35, 0.65, 0.2 or 0.8 of it): hidden by every later
//     element but another trail and the failed leg (both red above blue). Within 3 px red above blue by 0.08;
//   - the first actions bar: 6 px from every later element; within 3 px a pixel 0.1 from the backdrop in luminance;
//   - the backdrop: 9 × 9 patches at 3 % from the picture's edges and halfway along them, 24 px from every footprint;
//     the per-channel median of each is within 0.06 of the firmament gradient (night at the bottom of the firmament
//     quad, night top at its top) at its height, or of the median of the shader's CPU reference
//     `StarlitCartoucheShaders.firmamentColour` over the patch (a speck the reference predicts).
// The firmament quad faces the eye at one depth, so its projection is affine: its height h (0 bottom … 1 top) and
// horizontal coordinate s (−1 left … +1 right) at a pixel are read off the projections of its edge midpoints, taken
// from the chart mesh's vertices of material code 0 (the firmament) and their a_uv.y. Luminance is the Rec. 709
// weighting of the stored 0 … 1 channel values. Positions come from the presenter's `lastSnapshot`. Short runs only (no
// sleep, no wall-clock assertion).
//
// The checked levels are catalog levels 1, 21, 41, 61 and 81 (seeds 0, 20, 40, 60, 80).
#if os(iOS)
import CoreGraphics
import Foundation
import StarlitCartoucheCore
import Testing
import UIKit
@testable import StarlitCartoucheExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the point checks of one frame found.
struct StarlitCartoucheCheckReport {
    /// The star centres measured and those left out by the 6-pixel clearance.
    var starsChecked: Int = 0
    var starsExcluded: Int = 0
    /// Whether the ship's centre was measured.
    var shipChecked: Bool = false
    /// The trails with a measured point.
    var trailsChecked: Int = 0
    /// Whether the first actions bar was measured.
    var actionsChecked: Bool = false
    /// The backdrop patches measured.
    var patchesChecked: Int = 0
    /// Every failed check, in words.
    var misses: [String] = []
}

/// A projected strip: the segment `a` … `b` grown by `half` pixels (a disc when `a == b`).
struct StarlitCartoucheCapsule {
    var a: SIMD2<Double>
    var b: SIMD2<Double>
    var half: Double
}

/// A projected annulus: the circle of `radius` pixels around `centre` grown by `half` pixels on each side.
struct StarlitCartoucheRing {
    var centre: SIMD2<Double>
    var radius: Double
    var half: Double
}

/// The projected footprint of one drawn element (pixels, y down).
struct StarlitCartoucheFootprint {
    var hulls: [[SIMD2<Double>]] = []
    var capsules: [StarlitCartoucheCapsule] = []
    var rings: [StarlitCartoucheRing] = []

    /// The signed distance (pixels) of `p` from the footprint: negative inside, infinite for an empty footprint.
    func distance(_ p: SIMD2<Double>) -> Double {
        var best: Double = Double.infinity
        for hull in hulls { best = Swift.min(best, StarlitCartoucheTest.hullDistance(hull, p)) }
        for capsule in capsules {
            best = Swift.min(best, StarlitCartoucheTest.segmentDistance(p, capsule.a, capsule.b) - capsule.half)
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
struct StarlitCartoucheLayout {
    var order: [StarlitCartoucheElement] = []
    var footprints: [StarlitCartoucheFootprint] = []

    /// The place of element (`kind`, `index`) in the painter's order, or nil.
    func rank(_ kind: StarlitCartoucheElement.Kind, _ index: Int) -> Int? {
        for (place, element) in order.enumerated() where element.kind == kind && element.index == index {
            return place
        }
        return nil
    }

    /// Whether `p` lies at least `clearance` pixels from every element painted after place `rank` that `hides`.
    func isClear(_ p: SIMD2<Double>, after rank: Int, clearance: Double,
                 hides: (StarlitCartoucheElement) -> Bool) -> Bool {
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

/// The firmament quad's projection on one target: its edge midpoints in pixels.
struct StarlitCartoucheBackdrop {
    var bottom: SIMD2<Double>
    var top: SIMD2<Double>
    var left: SIMD2<Double>
    var right: SIMD2<Double>

    /// The firmament's height h (0 at the quad's bottom, 1 at its top) at pixel row `y`.
    func height(_ y: Double) -> Double {
        let span: Double = top.y - bottom.y
        return span != 0 ? (y - bottom.y) / span : 0.5
    }

    /// The firmament's horizontal coordinate s (−1 at the quad's left edge, +1 at its right) at pixel column `x`.
    func horizontal(_ x: Double) -> Double {
        let span: Double = right.x - left.x
        return span != 0 ? -1 + 2 * (x - left.x) / span : 0
    }

    /// The gradient colour (night → night top) at pixel (`x`, `y`).
    func gradient(x: Double, y: Double) -> SIMD3<Double> {
        let h: Double = Swift.min(Swift.max(height(y), 0), 1)
        let night: SIMD3<Double> = StarlitCartouchePalette.night
        return night + (StarlitCartouchePalette.nightTop - night) * h
    }

    /// The shader's CPU reference colour (gradient and specks) at pixel (`x`, `y`) with firmament turn `angle`.
    func reference(x: Double, y: Double, angle: Double) -> SIMD3<Double> {
        StarlitCartoucheShaders.firmamentColour(height: height(y), horizontal: horizontal(x), angle: angle)
    }
}

/// Building, opening, drawing and measuring Starlit Cartouche.
@MainActor
enum StarlitCartoucheTest {
    typealias Geometry = StarlitCartoucheSceneGeometry
    typealias Palette = StarlitCartouchePalette
    typealias Snapshot = StarlitCartoucheSceneSnapshot
    typealias Shell = ExperienceShell<StarlitCartouchePresenter>
    typealias Kind = StarlitCartoucheElement.Kind

    /// The experience id `r02-g16.starlit-cartouche`.
    static var id: ExperienceID {
        StarlitCartoucheExperience.id ?? ExperienceID(rawValue: "r02-g16.unknown")!
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
    /// A star's centre is brighter than the backdrop by at least this luminance.
    static let starMargin: Double = 0.25
    /// The ship's blue above red, and a trail's red above blue.
    static let hueMargin: Double = 0.08
    /// The first actions bar's luminance difference from the backdrop.
    static let actionsMargin: Double = 0.1
    /// The per-channel bound of a backdrop patch's median.
    static let backdropTolerance: Double = 0.06
    /// A backdrop patch's half side (pixels; 9 × 9) and its clearance from every footprint.
    static let patchHalf: Int = 4
    static let patchClearance: Double = 24
    /// The backdrop patch centres (fractions of the view, origin top left).
    static let patchFractions: [(x: Double, y: Double)] = [
        (0.03, 0.03), (0.5, 0.03), (0.97, 0.03), (0.03, 0.5), (0.97, 0.5), (0.03, 0.97), (0.5, 0.97), (0.97, 0.97),
    ]
    /// The shares along a trail tried in turn, its midpoint first.
    static let trailShares: [Double] = [0.5, 0.35, 0.65, 0.2, 0.8]
    /// The shares along the failed leg sampled for its broken colour.
    static let failedShares: [Double] = [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]
    /// The per-channel distance from #FF6B4A that counts as the broken colour (an active hazard's #FF5A5F is 0.083
    /// away).
    static let brokenTolerance: Double = 0.05

    // World sizes of the footprints (the geometry's header; generous where it names none).
    static let corridorHalf: Double = 0.01
    static let hazardHalf: Double = 0.03
    static let trailHalf: Double = (0.05 + 3 * 0.02) / 2
    static let failedHalf: Double = 0.025
    static let starReach: Double = 0.098
    static let markReach: Double = 0.158
    static let shipReach: Double = 0.07
    static let beaconRadius: Double = 0.12
    static let chosenRadius: Double = 0.1
    static let ringHalf: Double = 0.006
    static let cartoucheHalf: Double = 0.26
    static let gaugeSpan: Double = 0.9
    static let barFill: Double = 0.8
    static let barHalfHeight: Double = 0.02
    static let markWidth: Double = 0.016
    static let trackHalfHeight: Double = 0.015
    static let pipHalf: Double = 0.02

    /// Opens Starlit Cartouche with `seed` in `session` through the factory, lays the view out at `size` points and
    /// draws one frame. A session without a quality pin is pinned to level 0. `configure` runs on the presenter before
    /// its first `setup` (the fallback seam).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false, size: CGSize = CGSize(width: 48, height: 32),
                     configure: ((StarlitCartouchePresenter) -> Void)? = nil) async throws -> Shell {
        let id: ExperienceID = self.id
        var made: Shell?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: seed) {
            let shell: Shell = StarlitCartoucheExperience.make(id: id, reduceMotion: reduceMotion,
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

    /// Starts the glide clock at frame time −`glideSeconds` with a small still of the view's aspect (1.5), so the next
    /// still at frame time 0 shows the ship at rest (see the file header).
    static func prime(_ session: ExperienceSession) throws {
        _ = try still(session, width: 96, height: 64, time: -StarlitCartouchePresenter.glideSeconds)
    }

    /// The engine digest of `shell`'s state (hex).
    static func digest(_ shell: Shell) throws -> String {
        try shell.engine.digest().hex
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> StarlitCartoucheExperienceCore {
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
    nonisolated static func control(_ action: StarlitCartoucheAction) -> (control: String, values: [Double]) {
        switch action {
        case let .leg(star, wait):
            ("route.fly", [Double(star), Double(wait)])
        }
    }

    /// The host action of `action` (step 0).
    nonisolated static func experienceAction(_ action: StarlitCartoucheAction) -> ExperienceAction {
        let issued = control(action)
        return ExperienceAction(control: issued.control, values: issued.values, step: 0)
    }

    /// The certified plan of level `number`: its minimal winning legs.
    nonisolated static func certifiedLegs(_ number: Int) throws -> [StarlitCartoucheAction] {
        try StarlitCartoucheExperienceCore.generated(number: number).plan.legs
    }

    /// Issues `actions` through the shell, each expected to be accepted; returns how many were.
    @discardableResult
    static func issue(_ shell: Shell, _ actions: [StarlitCartoucheAction],
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
                          _ actions: [StarlitCartoucheAction]) throws -> StarlitCartoucheExperienceCore {
        var core: StarlitCartoucheExperienceCore = try StarlitCartoucheExperienceCore.opening(number: number)
        for action in actions {
            let result: ActionResult = core.apply(experienceAction(action))
            #expect(result == .accepted, "level \(number) \(action): \(result.code)")
        }
        return core
    }

    /// The kernel's star positions of `play` at its beat.
    nonisolated static func kernelPositions(_ play: StarlitCartouchePlay) -> [StarlitCartoucheVector] {
        var positions: [StarlitCartoucheVector] = []
        for star in play.level.stars { positions.append(star.position(at: play.beat)) }
        return positions
    }

    /// The first set-up over `candidates` (level numbers) of at most `maxDepth` − 1 accepted legs followed by a leg
    /// the chart fails (not on the budget, so the snapshot carries the failed leg), found breadth first through the
    /// adapter, whose failed leg has at least three clear sample points: the level, the set-up, the failing leg and the
    /// samples.
    static func failureCase(candidates: [Int], maxDepth: Int) throws
        -> (number: Int, setUp: [StarlitCartoucheAction], failing: StarlitCartoucheAction,
            samples: [SIMD2<Double>])? {
        for number in candidates {
            let opening: StarlitCartoucheExperienceCore = try StarlitCartoucheExperienceCore.opening(number: number)
            var frontier: [(core: StarlitCartoucheExperienceCore, actions: [StarlitCartoucheAction])] = [(opening, [])]
            for _ in 0..<maxDepth {
                var next: [(core: StarlitCartoucheExperienceCore, actions: [StarlitCartoucheAction])] = []
                for item in frontier {
                    let starCount: Int = item.core.play.level.stars.count
                    for star in 0..<starCount where star != item.core.play.star {
                        for wait in StarlitCartoucheExperienceCore.waitRange {
                            var core: StarlitCartoucheExperienceCore = item.core
                            let action = StarlitCartoucheAction.leg(star, wait)
                            guard core.apply(experienceAction(action)) == .accepted else { continue }
                            if core.play.stage == .failed {
                                let snapshot: Snapshot = core.snapshot(time: 0)
                                guard snapshot.failedLeg != nil else { continue }
                                let samples: [SIMD2<Double>] = failedLegSamples(snapshot)
                                if samples.count >= 3 { return (number, item.actions, action, samples) }
                            } else if core.play.stage == .playing, next.count < 12 {
                                next.append((core, item.actions + [action]))
                            }
                        }
                    }
                }
                frontier = next
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

    /// Whether `c` has blue above red by at least 0.08 (the sapphire ship).
    static func isBlue(_ c: SIMD3<Double>) -> Bool {
        c.z - c.x >= hueMargin
    }

    /// Whether `c` has red above blue by at least 0.08 (a meteor-gold trail).
    static func isRed(_ c: SIMD3<Double>) -> Bool {
        c.x - c.z >= hueMargin
    }

    /// Whether `c` is the broken colour #FF6B4A within ``brokenTolerance`` per channel.
    static func isBroken(_ c: SIMD3<Double>) -> Bool {
        channelDistance(c, StarlitCartouchePalette.broken) <= brokenTolerance
    }

    /// The number of pixels brighter than the firmament's top colour by 0.1 in luminance (anything drawn on it).
    static func drawnPixels(_ rgba: [UInt8]) -> Int {
        let floor: Double = luminance(Palette.nightTop) + 0.1
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

    /// How many of `points` have, within 3 px, a pixel in the broken colour.
    static func brokenHits(_ rgba: [UInt8], _ points: [SIMD2<Double>], width: Int = width,
                           height: Int = height) -> Int {
        guard rgba.count == width * height * 4 else { return 0 }
        var hits: Int = 0
        for p in points where anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height,
                                       where: isBroken) {
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
    nonisolated static func viewBasis(_ camera: StarlitCartoucheCamera) -> (right: SIMD3<Double>, up: SIMD3<Double>) {
        let forward: SIMD3<Double> = unit3(camera.target - camera.eye)
        let right: SIMD3<Double> = unit3(cross3(forward, SIMD3<Double>(0, 1, 0)))
        return (right, cross3(right, forward))
    }

    // MARK: CPU reference (clarification Q3)

    /// The camera the scene uses for `snapshot` on a `width` × `height` target.
    static func camera(_ snapshot: Snapshot, width: Int, height: Int) -> StarlitCartoucheCamera {
        Geometry.camera(snapshot, aspect: Double(width) / Double(height))
    }

    /// The pixel of world point `point` through `camera` on a `width` × `height` target (nil without a projection).
    static func project(_ point: SIMD3<Double>, _ camera: StarlitCartoucheCamera, width: Int,
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

    /// The pixels of the geometry's reference points (`referencePoints`: every star's centre, the ship's centre, every
    /// trail's midpoint, the cartouche's centre, the first actions bar) in their order (nil without a projection);
    /// empty for an empty target.
    static func referencePixels(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> [SIMD2<Double>?] {
        var result: [SIMD2<Double>?] = []
        guard width > 0, height > 0 else { return result }
        let cam: StarlitCartoucheCamera = camera(snapshot, width: width, height: height)
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
    static func pixelLength(_ length: Double, at centre: SIMD3<Double>, _ camera: StarlitCartoucheCamera, width: Int,
                            height: Int) -> Double {
        let right: SIMD3<Double> = viewBasis(camera).right
        guard let a = project(centre, camera, width: width, height: height),
              let b = project(centre + right * length, camera, width: width, height: height) else {
            return 0
        }
        let d: SIMD2<Double> = b - a
        return (d.x * d.x + d.y * d.y).squareRoot()
    }

    /// The projected strip of half width `half` (world units) from `a` to `b`, or nil without a projection.
    static func strip(_ a: SIMD3<Double>, _ b: SIMD3<Double>, half: Double, _ camera: StarlitCartoucheCamera,
                      width: Int, height: Int) -> StarlitCartoucheCapsule? {
        guard let pa = project(a, camera, width: width, height: height),
              let pb = project(b, camera, width: width, height: height) else { return nil }
        let w: Double = pixelLength(half, at: (a + b) / 2, camera, width: width, height: height)
        return StarlitCartoucheCapsule(a: pa, b: pb, half: w)
    }

    /// The projected camera-facing disc of `radius` (world units) around `centre`, or nil without a projection.
    static func disc(_ centre: SIMD3<Double>, radius: Double, _ camera: StarlitCartoucheCamera, width: Int,
                     height: Int) -> StarlitCartoucheCapsule? {
        strip(centre, centre, half: radius, camera, width: width, height: height)
    }

    /// The projected camera-facing annulus of `radius` and half width `half` (world units) around `centre`.
    static func ring(_ centre: SIMD3<Double>, radius: Double, half: Double, _ camera: StarlitCartoucheCamera,
                     width: Int, height: Int) -> StarlitCartoucheRing? {
        guard let p = project(centre, camera, width: width, height: height) else { return nil }
        return StarlitCartoucheRing(centre: p, radius: pixelLength(radius, at: centre, camera, width: width,
                                                                   height: height),
                                    half: pixelLength(half, at: centre, camera, width: width, height: height))
    }

    /// The hull of the camera-facing rectangle of half sizes `half` (world units) around `centre`.
    static func billboardHull(_ centre: SIMD3<Double>, half: SIMD2<Double>, _ camera: StarlitCartoucheCamera,
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

    /// Whether corridor `index` of `snapshot` is drawn as pearl dashes (an undrawn symbol corridor).
    nonisolated static func isDashed(_ index: Int, _ snapshot: Snapshot) -> Bool {
        snapshot.symbol.contains(index) && !snapshot.drawn.contains(index)
    }

    /// The projected footprint of `element` of `snapshot` (see the file header).
    static func footprint(_ element: StarlitCartoucheElement, _ snapshot: Snapshot, _ cam: StarlitCartoucheCamera,
                          width: Int, height: Int) -> StarlitCartoucheFootprint {
        var f = StarlitCartoucheFootprint()
        let i: Int = element.index
        switch element.kind {
        case .corridor:
            if i >= 0, i < snapshot.corridors.count {
                let c: StarlitCartoucheCorridor = snapshot.corridors[i]
                if let s = strip(Geometry.starCentre(c.a, snapshot), Geometry.starCentre(c.b, snapshot),
                                 half: corridorHalf, cam, width: width, height: height) { f.capsules.append(s) }
            }
        case .hazard:
            if i >= 0, i < snapshot.hazards.count, snapshot.hazards[i].corridor < snapshot.corridors.count {
                let c: StarlitCartoucheCorridor = snapshot.corridors[snapshot.hazards[i].corridor]
                if let s = strip(Geometry.starCentre(c.a, snapshot), Geometry.starCentre(c.b, snapshot),
                                 half: hazardHalf, cam, width: width, height: height) { f.capsules.append(s) }
            }
        case .trail:
            let ends = Geometry.trailEnds(i, snapshot)
            if let s = strip(ends.start, ends.end, half: trailHalf, cam, width: width, height: height) {
                f.capsules.append(s)
            }
        case .failedLeg:
            if let ends = Geometry.failedLegEnds(snapshot),
               let s = strip(ends.start, ends.end, half: failedHalf, cam, width: width, height: height) {
                f.capsules.append(s)
            }
        case .star:
            let marked: Bool = Geometry.markedStar(snapshot) == i
            let reach: Double = marked ? markReach : starReach
            if let d = disc(element.centre, radius: reach, cam, width: width, height: height) { f.capsules.append(d) }
        case .ship:
            if let d = disc(element.centre, radius: shipReach, cam, width: width, height: height) {
                f.capsules.append(d)
            }
        case .beacon:
            if let r = ring(element.centre, radius: beaconRadius, half: ringHalf, cam, width: width,
                            height: height) { f.rings.append(r) }
        case .chosen:
            if let r = ring(element.centre, radius: chosenRadius, half: ringHalf, cam, width: width,
                            height: height) { f.rings.append(r) }
        case .cartouche:
            f.hulls.append(billboardHull(element.centre, half: SIMD2<Double>(cartoucheHalf, cartoucheHalf), cam,
                                         width: width, height: height))
        case .actionsBar:
            let slot: Double = gaugeSpan / Double(Swift.max(snapshot.budget, 1))
            let half = SIMD2<Double>(barFill * slot / 2 + markWidth, barHalfHeight + markWidth)
            f.hulls.append(billboardHull(element.centre, half: half, cam, width: width, height: height))
        case .beatTrack:
            let half = SIMD2<Double>(gaugeSpan / 2 + markWidth, trackHalfHeight + markWidth)
            f.hulls.append(billboardHull(element.centre, half: half, cam, width: width, height: height))
        case .waitPip:
            f.hulls.append(billboardHull(element.centre, half: SIMD2<Double>(pipHalf, pipHalf), cam, width: width,
                                         height: height))
        case .preview:
            // Feature 454 (R02-G16-04): the launch preview ribbon, 0.03 wide.
            if let ends = Geometry.previewEnds(snapshot),
               let s = strip(ends.start, ends.end, half: 0.015, cam, width: width, height: height) {
                f.capsules.append(s)
            }
        }
        return f
    }

    /// The painter's order of `snapshot` on a `width` × `height` target with every element's footprint; empty for an
    /// empty target.
    static func layout(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> StarlitCartoucheLayout {
        var result = StarlitCartoucheLayout()
        guard width > 0, height > 0 else { return result }
        let cam: StarlitCartoucheCamera = camera(snapshot, width: width, height: height)
        result.order = Geometry.paintOrder(snapshot, camera: cam)
        for element in result.order {
            result.footprints.append(footprint(element, snapshot, cam, width: width, height: height))
        }
        return result
    }

    /// The firmament quad's projection for `snapshot` on a `width` × `height` target, read from the chart mesh's
    /// firmament vertices (material code 0; a_uv.y 0 at the bottom, 1 at the top); nil for an empty target or a mesh
    /// without the four firmament corners.
    static func backdrop(_ snapshot: Snapshot, width: Int = width,
                         height: Int = height) -> StarlitCartoucheBackdrop? {
        guard width > 0, height > 0 else { return nil }
        let cheapest: StarlitCartoucheTier = StarlitCartoucheTier.all[StarlitCartoucheTier.all.count - 1]
        guard let mesh = try? Geometry.chartMesh(snapshot, tier: cheapest, glide: 1) else { return nil }
        var corners: [(p: SIMD3<Double>, h: Double)] = []
        for index in mesh.positions.indices where index < mesh.uvs.count && Swift.abs(mesh.uvs[index].x) < 0.5 {
            let v: Vec3 = mesh.positions[index]
            corners.append((SIMD3<Double>(v.x, v.y, v.z), mesh.uvs[index].y))
        }
        guard corners.count == 4 else { return nil }
        let cam: StarlitCartoucheCamera = camera(snapshot, width: width, height: height)
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
        return StarlitCartoucheBackdrop(bottom: pb, top: pt, left: pl, right: pr)
    }

    // MARK: Hiders (see the file header)

    /// Whether a later `element` can hide a star's brightness.
    nonisolated static func starHides(_ element: StarlitCartoucheElement, _ snapshot: Snapshot) -> Bool {
        switch element.kind {
        case .corridor: !isDashed(element.index, snapshot)
        case .hazard, .cartouche, .actionsBar, .beatTrack, .waitPip, .preview: true
        case .trail, .failedLeg, .star, .ship, .beacon, .chosen: false
        }
    }

    /// Whether a later `element` can hide the ship's blue.
    nonisolated static func shipHides(_ element: StarlitCartoucheElement, _ snapshot: Snapshot) -> Bool {
        switch element.kind {
        case .corridor: isDashed(element.index, snapshot)
        case .chosen, .ship, .preview: false
        case .hazard, .trail, .failedLeg, .star, .beacon, .cartouche, .actionsBar, .beatTrack, .waitPip: true
        }
    }

    /// Whether a later `element` can hide a trail's gold.
    nonisolated static func trailHides(_ element: StarlitCartoucheElement) -> Bool {
        element.kind != .trail && element.kind != .failedLeg
    }

    // MARK: Checks

    /// The clear sample points (pixels at the check size) along the failed leg of `snapshot`, each 6 px from every
    /// element painted after it; empty without a failed leg.
    static func failedLegSamples(_ snapshot: Snapshot, width: Int = width,
                                 height: Int = height) -> [SIMD2<Double>] {
        guard let ends = Geometry.failedLegEnds(snapshot) else { return [] }
        let o: StarlitCartoucheLayout = layout(snapshot, width: width, height: height)
        guard let rank = o.rank(.failedLeg, 0) else { return [] }
        var result: [SIMD2<Double>] = []
        for share in failedShares {
            let world: SIMD3<Double> = ends.start + (ends.end - ends.start) * share
            guard let p = pixel(world, snapshot, width: width, height: height),
                  inside(p, width: width, height: height) else { continue }
            let clear: Bool = o.isClear(p, after: rank, clearance: clearance) { _ in true }
            if clear { result.append(p) }
        }
        return result
    }

    /// The first clear point of trail `leg` (its midpoint, else another share), or nil.
    static func clearTrailPoint(_ leg: Int, _ snapshot: Snapshot, _ o: StarlitCartoucheLayout, width: Int,
                                height: Int) -> SIMD2<Double>? {
        guard let rank = o.rank(.trail, leg) else { return nil }
        let ends = Geometry.trailEnds(leg, snapshot)
        for share in trailShares {
            let world: SIMD3<Double> = share == 0.5 ? Geometry.trailMidpoint(leg, snapshot)
                : ends.start + (ends.end - ends.start) * share
            guard let p = pixel(world, snapshot, width: width, height: height),
                  inside(p, width: width, height: height) else { continue }
            let clear: Bool = o.isClear(p, after: rank, clearance: clearance, hides: trailHides)
            if clear { return p }
        }
        return nil
    }

    /// The backdrop patch check at view fraction (`fx`, `fy`): nil when the patch is not measured (outside the
    /// picture or near a footprint), else the miss in words or "" when it passed.
    static func patchResult(_ rgba: [UInt8], fx: Double, fy: Double, sky: StarlitCartoucheBackdrop,
                            _ o: StarlitCartoucheLayout, width: Int, height: Int, angle: Double) -> String? {
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
                predicted.append(sky.reference(x: Double(x) + 0.5, y: Double(y) + 0.5, angle: angle))
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

    /// The point checks of clarification Q3 (see the file header) on `rgba` against `snapshot`; `angle` is the
    /// firmament turn the frame was drawn with.
    static func pointReport(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width, height: Int = height,
                            angle: Double = 0) -> StarlitCartoucheCheckReport {
        var report = StarlitCartoucheCheckReport()
        let o: StarlitCartoucheLayout = layout(snapshot, width: width, height: height)
        guard let sky = backdrop(snapshot, width: width, height: height) else {
            report.misses.append("no firmament quad in the chart mesh")
            return report
        }
        for index in snapshot.stars.indices {
            guard let p = pixel(Geometry.starCentre(index, snapshot), snapshot, width: width, height: height),
                  inside(p, width: width, height: height), let rank = o.rank(.star, index) else {
                report.misses.append("star \(index): it does not project into the picture")
                continue
            }
            let clear: Bool = o.isClear(p, after: rank, clearance: clearance) { starHides($0, snapshot) }
            if !clear {
                report.starsExcluded += 1
                continue
            }
            report.starsChecked += 1
            let floor: Double = luminance(sky.gradient(x: p.x, y: p.y)) + starMargin
            let bright: Bool = anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height,
                                        where: { luminance($0) >= floor })
            if !bright {
                let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
                report.misses.append(String(format: "star %ld (%.1f, %.1f) is (%.3f, %.3f, %.3f)", index, p.x, p.y,
                                            c.x, c.y, c.z))
            }
        }
        if !snapshot.stars.isEmpty, let p = pixel(Geometry.shipCentre(snapshot), snapshot, width: width,
                                                  height: height),
           inside(p, width: width, height: height), let rank = o.rank(.ship, 0) {
            let clear: Bool = o.isClear(p, after: rank, clearance: clearance) { shipHides($0, snapshot) }
            if clear {
                report.shipChecked = true
                if !anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height, where: isBlue) {
                    let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
                    report.misses.append(String(format: "ship (%.1f, %.1f) is (%.3f, %.3f, %.3f)", p.x, p.y, c.x,
                                                c.y, c.z))
                }
            }
        }
        for leg in snapshot.legs.indices {
            guard let p = clearTrailPoint(leg, snapshot, o, width: width, height: height) else { continue }
            report.trailsChecked += 1
            if !anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height, where: isRed) {
                let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
                report.misses.append(String(format: "trail %ld (%.1f, %.1f) is (%.3f, %.3f, %.3f)", leg, p.x, p.y,
                                            c.x, c.y, c.z))
            }
        }
        if snapshot.budget > 0, let p = pixel(Geometry.actionsBar(0, snapshot), snapshot, width: width,
                                              height: height),
           inside(p, width: width, height: height), let rank = o.rank(.actionsBar, 0) {
            // The bars stand a few pixels apart and are all drawn in the actions colours, so a neighbouring bar painted
            // later cannot make bar 0's centre look like the backdrop; only other elements count as hiding it.
            let clear: Bool = o.isClear(p, after: rank, clearance: clearance) { $0.kind != .actionsBar }
            if clear {
                report.actionsChecked = true
                let back: Double = luminance(sky.gradient(x: p.x, y: p.y))
                let off: Bool = anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height,
                                         where: { Swift.abs(luminance($0) - back) >= actionsMargin })
                if !off {
                    report.misses.append(String(format: "actions bar 0 at (%.1f, %.1f) is backdrop-coloured", p.x,
                                                p.y))
                }
            }
        }
        for fraction in patchFractions {
            guard let result = patchResult(rgba, fx: fraction.x, fy: fraction.y, sky: sky, o, width: width,
                                           height: height, angle: angle) else { continue }
            report.patchesChecked += 1
            if !result.isEmpty { report.misses.append(result) }
        }
        return report
    }

    /// Runs the checks of clarification Q3 on `rgba` against `snapshot`, recording an issue per failure, and returns
    /// the report. `requireStar` also requires at least one star centre to be measured; a picture of at least 64 × 64
    /// must measure at least four backdrop patches.
    @discardableResult
    static func checkFrame(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width, height: Int = height,
                           requireStar: Bool = false, angle: Double = 0, _ what: String,
                           sourceLocation: SourceLocation = #_sourceLocation) -> StarlitCartoucheCheckReport {
        #expect(rgba.count == width * height * 4, "\(what): picture size", sourceLocation: sourceLocation)
        guard rgba.count == width * height * 4 else { return StarlitCartoucheCheckReport() }
        let report: StarlitCartoucheCheckReport = pointReport(rgba, snapshot: snapshot, width: width, height: height,
                                                              angle: angle)
        if requireStar {
            #expect(report.starsChecked > 0, "\(what): no star centre clear of the later elements",
                    sourceLocation: sourceLocation)
        }
        if width >= 64 && height >= 64 {
            #expect(report.patchesChecked >= 4, "\(what): backdrop patches \(report.patchesChecked)",
                    sourceLocation: sourceLocation)
        }
        let shown: [String] = Array(report.misses.prefix(8))
        #expect(report.misses.isEmpty, "\(what): \(shown)", sourceLocation: sourceLocation)
        let stars: String = String(format: "stars checked %ld, excluded %ld", report.starsChecked,
                                   report.starsExcluded)
        print("starlit-cartouche \(what): \(stars); ship \(report.shipChecked); trails \(report.trailsChecked); "
              + "actions \(report.actionsChecked); patches \(report.patchesChecked)")
        return report
    }
}
#endif
