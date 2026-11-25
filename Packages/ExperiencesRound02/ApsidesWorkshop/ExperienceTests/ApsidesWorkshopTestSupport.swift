// ApsidesWorkshopTestSupport — feature 473 (R02-G18-03) T-R02G1803-006 (FR-R02G1803-001 … 007; clarifications
// Q1–Q4). Shared helpers of the Apsides Workshop experience tests, following Celestial Eclipse Lab's harness (feature
// 463): opening the experience through the one app's session host (seed `s` prepares certified level `s % 100 + 1`; a
// session without a quality pin is pinned to level 0) and showing the tick T/2 (`clock.show [period / 2]`, the
// apoapsis, at least 8 lattice units from the star, so the orbiter never covers the star's check point), issuing kernel
// actions through the shell, drawing live frames, drawing an off-screen still (RGBA8, rows top-down, the orientation
// of the Core's CPU projection `ApsidesWorkshopSceneGeometry.project`, origin top left, y down, scaled here to pixels),
// the engine digest, the frame checks of clarification Q3 at 1,152 × 768, and a short search for a failing play whose
// broken element is clear of every later element.
//
// The shown tick is the adapter's presentation state and is never advanced by time; the only time-driven value is the
// star's pulse (`u_pulse`, 1 at frame time 0 and under Reduce Motion). Every still here is drawn at frame time 0 unless
// a test says otherwise.
//
// The CPU reference: the painter's order of `ApsidesWorkshopSceneGeometry.paintOrder` (by kind, then index) with every
// element's projected footprint, conservative where the drawn shape is thinner (world sizes of the geometry's
// constants): the backdrop none (it lies under everything); a wedge's triangle star → P(t) → P(t + 1); the compass the
// disc out to the apsis bracket's outer edge; the ghost loop's ribbon; the orbit loop's ribbon through the kernel's
// chords and through the level-0 refinement (the union of every tier's loop), with a contact's broken segment; an apsis
// marker's disc around its mark quad; a planet's disc out to its hazard ring; the star's and the orbiter's discs; a
// gauge row's box (track, band bracket and reading mark); an actions bar's rectangle. The additive glow (drawn last)
// only brightens and hides no cue, but its level-0 extent (star, orbit loop, orbiter) keeps the backdrop patches away.
// A point is checked only when it projects into the picture at least 6 px from every element drawn after it:
//   - the star's centre and the orbiter's centre: within 3 px a pixel brighter than the backdrop at its height by 0.25
//     in luminance;
//   - the first actions bar, when lit: within 3 px red above blue by 0.08 (deep rose);
//   - the first gauge track's centre: within 3 px a pixel 0.1 from the backdrop in luminance (the track's own band
//     bracket and reading mark are not backdrop-coloured either);
//   - the backdrop: 9 × 9 patches at 3 % from the picture's edges and halfway along them, 24 px from every footprint;
//     the per-channel median of each is within 0.06 of the gradient (midnight at the bottom of the backdrop quad,
//     midnight top at its top) at its height (`ApsidesWorkshopSceneGeometry.backdropHeight(view:camera:)`), or of the
//     median of the shader's CPU reference `ApsidesWorkshopShaders.backdropColour` over the patch (a speck the
//     reference predicts).
// The camera looks straight down the z axis, so the backdrop's horizontal coordinate at a pixel is its world x at the
// backdrop's plane over the quad's half width. Luminance is the Rec. 709 weighting of the stored 0 … 1 channel values.
// Positions come from the presenter's `lastSnapshot`. Short runs only (no sleep, no wall-clock assertion).
//
// The checked levels are catalog levels 1, 21, 41, 61 and 81 (seeds 0, 20, 40, 60, 80).
#if os(iOS)
import ApsidesWorkshopCore
import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import ApsidesWorkshopExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the point checks of one frame found.
struct ApsidesWorkshopCheckReport {
    /// Whether the star's centre was measured.
    var starChecked: Bool = false
    /// Whether the orbiter's centre was measured.
    var orbiterChecked: Bool = false
    /// Whether the first actions bar was measured.
    var barChecked: Bool = false
    /// Whether the first gauge track's centre was measured.
    var trackChecked: Bool = false
    /// The backdrop patches measured.
    var patchesChecked: Int = 0
    /// Every failed check, in words.
    var misses: [String] = []
}

/// A projected strip: the segment `a` … `b` grown by `half` pixels (a disc when `a == b`).
struct ApsidesWorkshopTestCapsule {
    /// One end (pixels).
    var a: SIMD2<Double>
    /// The other end (pixels).
    var b: SIMD2<Double>
    /// The half width (pixels).
    var half: Double
}

/// The projected footprint of one drawn element (pixels, y down).
struct ApsidesWorkshopTestFootprint {
    /// Convex polygons (corners in the order `convexHull` gives them).
    var hulls: [[SIMD2<Double>]] = []
    /// Strips and discs.
    var capsules: [ApsidesWorkshopTestCapsule] = []

    /// The signed distance (pixels) of `p` from the footprint: negative inside, infinite for an empty footprint.
    func distance(_ p: SIMD2<Double>) -> Double {
        var best: Double = Double.infinity
        for hull in hulls { best = Swift.min(best, ApsidesWorkshopTest.hullDistance(hull, p)) }
        for capsule in capsules {
            best = Swift.min(best, ApsidesWorkshopTest.segmentDistance(p, capsule.a, capsule.b) - capsule.half)
        }
        return best
    }
}

/// The painter's order of one snapshot on one target with every element's footprint (same indices) and the glow's.
struct ApsidesWorkshopTestLayout {
    /// The elements in painter's order.
    var order: [ApsidesWorkshopElement] = []
    /// The footprint of each element of `order`.
    var footprints: [ApsidesWorkshopTestFootprint] = []
    /// The level-0 glow's footprint (drawn last, additive).
    var glow = ApsidesWorkshopTestFootprint()

    /// The place of the element drawing `part` for `item` in the painter's order, or nil.
    func rank(_ part: ApsidesWorkshopElement.Part, _ item: Int) -> Int? {
        for (place, element) in order.enumerated() where element.part == part && element.item == item {
            return place
        }
        return nil
    }

    /// Whether `p` lies at least `clearance` pixels from every element painted after place `rank`.
    func isClear(_ p: SIMD2<Double>, after rank: Int, clearance: Double) -> Bool {
        var place: Int = rank + 1
        while place < order.count {
            if footprints[place].distance(p) < clearance { return false }
            place += 1
        }
        return true
    }

    /// The smallest distance (pixels) of `p` from any footprint, the glow's included.
    func minimumDistance(_ p: SIMD2<Double>) -> Double {
        var best: Double = glow.distance(p)
        for footprint in footprints { best = Swift.min(best, footprint.distance(p)) }
        return best
    }
}

/// The backdrop's colour coordinates on one target.
struct ApsidesWorkshopTestBackdrop {
    /// The camera of the target.
    var camera: ApsidesWorkshopCamera
    /// The target's size in pixels.
    var width: Int
    var height: Int

    /// The backdrop's height h (0 at the quad's bottom, 1 at its top) at pixel (`x`, `y`).
    func heightAt(x: Double, y: Double) -> Double {
        let view = SIMD2<Double>(x / Double(width), y / Double(height))
        return ApsidesWorkshopSceneGeometry.backdropHeight(view: view, camera: camera)
    }

    /// The backdrop's horizontal coordinate s (−1 at the quad's left edge, +1 at its right) at pixel column `x`.
    func horizontal(_ x: Double) -> Double {
        let distance: Double = camera.eye.z - ApsidesWorkshopSceneGeometry.backdropDepth
        let halfWidth: Double = distance * tan(camera.fovY / 2) * camera.aspect
        let worldX: Double = camera.target.x + (2 * x / Double(width) - 1) * halfWidth
        let quadHalf: Double = ApsidesWorkshopSceneGeometry.backdropHalf().x
        return quadHalf > 0 ? worldX / quadHalf : 0
    }

    /// The gradient colour (midnight → midnight top) at pixel (`x`, `y`).
    func gradient(x: Double, y: Double) -> SIMD3<Double> {
        let h: Double = heightAt(x: x, y: y)
        let low: SIMD3<Double> = ApsidesWorkshopPalette.midnight
        return low + (ApsidesWorkshopPalette.midnightTop - low) * h
    }

    /// The shader's CPU reference colour (gradient and specks) at pixel (`x`, `y`).
    func reference(x: Double, y: Double) -> SIMD3<Double> {
        ApsidesWorkshopShaders.backdropColour(height: heightAt(x: x, y: y), horizontal: horizontal(x))
    }
}

/// A play that fails with its broken element clear of every later element: the level, the set-up before the play and
/// the checked point of the broken element at the check size.
struct ApsidesWorkshopFailureCase {
    /// The catalog level number.
    var number: Int
    /// The tunings made before the play.
    var setUp: [ApsidesWorkshopAction]
    /// The checked point of the broken element (pixels at 1,152 × 768).
    var point: SIMD2<Double>
    /// Whether the failure is a contact (the broken segment) rather than a target's (the broken gauge track).
    var contact: Bool
}

/// Building, opening, drawing and measuring Apsides Workshop.
@MainActor
enum ApsidesWorkshopTest {
    typealias Geometry = ApsidesWorkshopSceneGeometry
    typealias Palette = ApsidesWorkshopPalette
    typealias Snapshot = ApsidesWorkshopSceneSnapshot
    typealias Shell = ExperienceShell<ApsidesWorkshopPresenter>
    typealias Element = ApsidesWorkshopElement
    typealias Part = ApsidesWorkshopElement.Part

    /// The experience id `r02-g18.apsides-workshop`.
    static var id: ExperienceID {
        ApsidesWorkshopExperience.id ?? ExperienceID(rawValue: "r02-g18.unknown")!
    }

    /// The frame-check size of clarification Q3, aspect 1.5.
    static let width: Int = 1_152
    static let height: Int = 768
    /// The checked catalog levels and their seeds (seed = level − 1).
    static let levels: [Int] = [1, 21, 41, 61, 81]
    static let seeds: [UInt64] = [0, 20, 40, 60, 80]
    /// The search radius (pixels) of the point checks.
    static let pointRadius: Double = 3
    /// The search radius (pixels) at a broken element or a lit gauge mark (thin shapes beside other reddish ones).
    static let markRadius: Double = 1.5
    /// The clearance (pixels) of every checked point from every element drawn after it.
    static let clearance: Double = 6
    /// The star's and the orbiter's centre (and a lit mark) are brighter than the backdrop by at least this.
    static let brightMargin: Double = 0.25
    /// The first actions bar's (and a broken element's and a lit mark's) red above blue.
    static let hueMargin: Double = 0.08
    /// The first gauge track's luminance difference from the backdrop.
    static let trackMargin: Double = 0.1
    /// The per-channel bound of a backdrop patch's median.
    static let backdropTolerance: Double = 0.06
    /// A backdrop patch's half side (pixels; 9 × 9) and its clearance from every footprint.
    static let patchHalf: Int = 4
    static let patchClearance: Double = 24
    /// The backdrop patch centres (fractions of the view, origin top left).
    static let patchFractions: [(x: Double, y: Double)] = [
        (0.03, 0.03), (0.5, 0.03), (0.97, 0.03), (0.03, 0.5), (0.97, 0.5), (0.03, 0.97), (0.5, 0.97), (0.97, 0.97),
    ]
    /// A gauge row's half height in world units (band bracket reach and line, the mark quad), with a margin.
    static let gaugeRowHalf: Double = 0.03

    /// Opens Apsides Workshop with `seed` in `session` through the factory, lays the view out at `size` points, draws
    /// one frame and, with `atHalf`, shows the tick T/2 and draws again. A session without a quality pin is pinned
    /// to level 0. `configure` runs on the presenter before its first `setup` (the fallback seam).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false, size: CGSize = CGSize(width: 48, height: 32),
                     atHalf: Bool = true,
                     configure: ((ApsidesWorkshopPresenter) -> Void)? = nil) async throws -> Shell {
        let id: ExperienceID = self.id
        var made: Shell?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: seed) {
            let shell: Shell = ApsidesWorkshopExperience.make(id: id, reduceMotion: reduceMotion,
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
        if atHalf {
            try showHalf(shell)
            try draw(session)
        }
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
    static func core(_ shell: Shell) throws -> ApsidesWorkshopExperienceCore {
        try #require(shell.engine.core)
    }

    /// Pins `session` to quality level `tier` and checks that the engine took it.
    static func pin(_ session: ExperienceSession, _ shell: Shell, tier: Int,
                    sourceLocation: SourceLocation = #_sourceLocation) {
        session.qualityPin = tier
        #expect(shell.engine.qualityTier == tier, "pinned tier \(tier)", sourceLocation: sourceLocation)
    }

    /// The tick T/2 of a level of `period` ticks (the apoapsis).
    nonisolated static func halfTick(_ period: Int) -> Int {
        period / 2
    }

    /// Shows the tick T/2 of `shell`'s level through the shell (`clock.show [period / 2]`); returns the tick.
    @discardableResult
    static func showHalf(_ shell: Shell, sourceLocation: SourceLocation = #_sourceLocation) throws -> Int {
        let tick: Int = halfTick(try core(shell).play.level.period)
        let result: ActionResult = shell.handle(control: "clock.show", values: [Double(tick)])
        #expect(result == .accepted, "clock.show [\(tick)]: \(result.code)", sourceLocation: sourceLocation)
        return tick
    }

    // MARK: Actions

    /// The control and values that issue the kernel action `action` through the shell.
    nonisolated static func control(_ action: ApsidesWorkshopAction) -> (control: String, values: [Double]) {
        switch action {
        case let .periapsis(eccentricity, direction):
            ("orbit.periapsis", [Double(eccentricity), Double(direction)])
        case let .size(size):
            ("orbit.size", [Double(size)])
        case .play:
            ("orbit.play", [])
        }
    }

    /// The host action of `action` (step 0).
    nonisolated static func experienceAction(_ action: ApsidesWorkshopAction) -> ExperienceAction {
        let issued = control(action)
        return ExperienceAction(control: issued.control, values: issued.values, step: 0)
    }

    /// The host action showing tick `tick` (step 0).
    nonisolated static func showAction(_ tick: Int) -> ExperienceAction {
        ExperienceAction(control: "clock.show", values: [Double(tick)], step: 0)
    }

    /// The certified plan of level `number`: its minimal tunings (the play not included).
    nonisolated static func certifiedPlan(_ number: Int) throws -> [ApsidesWorkshopAction] {
        try ApsidesWorkshopExperienceCore.generated(number: number).plan.actions
    }

    /// Issues `actions` through the shell, each expected to be accepted; returns how many were.
    @discardableResult
    static func issue(_ shell: Shell, _ actions: [ApsidesWorkshopAction],
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

    /// The opening core of level `number` with `actions` applied and, with `showHalf`, the tick T/2 shown (no host):
    /// the CPU reference of that state.
    static func coreAfter(_ number: Int, _ actions: [ApsidesWorkshopAction],
                          showHalf: Bool = true) throws -> ApsidesWorkshopExperienceCore {
        var core: ApsidesWorkshopExperienceCore = try ApsidesWorkshopExperienceCore.opening(number: number)
        for action in actions {
            let result: ActionResult = core.apply(experienceAction(action))
            #expect(result == .accepted, "level \(number) \(action): \(result.code)")
        }
        if showHalf {
            let tick: Int = halfTick(core.play.level.period)
            let result: ActionResult = core.apply(showAction(tick))
            #expect(result == .accepted, "level \(number) clock.show [\(tick)]: \(result.code)")
        }
        return core
    }

    /// The set-ups tried before the play in ``failureCase(candidates:)``: none, every proper prefix of the certified
    /// plan, then single tunings of the opening orbit (size ± 1 … 3, direction ± 1 … 3, eccentricity ± 1; at most
    /// `limit` set-ups in all; the search skips those the kernel refuses).
    static func setUps(_ number: Int, limit: Int = 24) throws -> [[ApsidesWorkshopAction]] {
        var result: [[ApsidesWorkshopAction]] = [[]]
        let plan: [ApsidesWorkshopAction] = try certifiedPlan(number)
        var length: Int = 1
        while length < plan.count {
            result.append(Array(plan.prefix(length)))
            length += 1
        }
        let start: ApsidesWorkshopOrbit = try ApsidesWorkshopExperienceCore.level(number: number).orbit
        let steps: [Int] = [1, -1, 2, -2, 3, -3]
        for step in steps {
            guard result.count < limit else { return result }
            result.append([.size(start.size + step)])
            guard result.count < limit else { return result }
            let direction: Int = (start.direction + step + 24) % 24
            result.append([.periapsis(start.eccentricity, direction)])
        }
        for step in [1, -1] where result.count < limit {
            result.append([.periapsis(start.eccentricity + step, start.direction)])
        }
        return result
    }

    /// The first play over `candidates` (level numbers) after one of ``setUps(_:limit:)`` that fails and whose broken
    /// element (the contact's broken segment or the failing target's gauge track) has a point that projects into the
    /// picture clear of every later element; nil when none does.
    static func failureCase(candidates: [Int]) throws -> ApsidesWorkshopFailureCase? {
        for number in candidates {
            for setUp in try setUps(number) {
                var core: ApsidesWorkshopExperienceCore = try ApsidesWorkshopExperienceCore.opening(number: number)
                var accepted: Bool = true
                let actions: [ApsidesWorkshopAction] = setUp + [.play]
                for action in actions where accepted {
                    let result: ActionResult = core.apply(experienceAction(action))
                    if result != .accepted { accepted = false }
                }
                guard accepted, core.play.stage == .failed else { continue }
                _ = core.apply(showAction(halfTick(core.play.level.period)))
                let snapshot: Snapshot = core.snapshot(time: 0)
                guard let found = brokenPoint(snapshot) else { continue }
                return ApsidesWorkshopFailureCase(number: number, setUp: setUp, point: found.pixel,
                                                  contact: found.contact)
            }
        }
        return nil
    }

    /// A point of the broken element of `snapshot` at the check size that is clear of every later element (and of
    /// the failing gauge's own reddish band bracket and reading mark): on a contact a point of the broken segment
    /// P(tick) → P(tick + 1), on a target failure a point of that target's gauge track; nil otherwise.
    static func brokenPoint(_ snapshot: Snapshot, width: Int = width,
                            height: Int = height) -> (pixel: SIMD2<Double>, contact: Bool)? {
        let o: ApsidesWorkshopTestLayout = layout(snapshot, width: width, height: height)
        let cam: ApsidesWorkshopCamera = camera(width: width, height: height)
        if let hit = Geometry.contact(snapshot), !snapshot.positions.isEmpty {
            guard let rank = o.rank(.orbit, 0) else { return nil }
            let n: Int = snapshot.positions.count
            let t: Int = Swift.min(Swift.max(hit.tick, 0), n - 1)
            let a: SIMD3<Double> = Geometry.world(snapshot.positions[t], depth: Geometry.planeZ)
            let b: SIMD3<Double> = Geometry.world(snapshot.positions[(t + 1) % n], depth: Geometry.planeZ)
            var step: Int = 1
            while step < 10 {
                let f: Double = Double(step) / 10
                step += 1
                guard let p = project(a + (b - a) * f, cam, width: width, height: height),
                      inside(p, width: width, height: height),
                      o.isClear(p, after: rank, clearance: clearance) else { continue }
                return (p, true)
            }
            return nil
        }
        guard let target = Geometry.failingGauge(snapshot), target >= 0, target < snapshot.gauges.count,
              let rank = o.rank(.track, target) else { return nil }
        let gauge: ApsidesWorkshopGauge = snapshot.gauges[target]
        let y: Double = Geometry.gaugeCentre(target).y
        let z: Double = Geometry.planeZ
        guard let markPixel = project(Geometry.markCentre(target, snapshot), cam, width: width, height: height),
              let lowPixel = project(SIMD3<Double>(Geometry.gaugeX(gauge.target.low, top: gauge.scaleTop), y, z), cam,
                                     width: width, height: height),
              let highPixel = project(SIMD3<Double>(Geometry.gaugeX(gauge.target.high, top: gauge.scaleTop), y, z),
                                      cam, width: width, height: height) else { return nil }
        let at = SIMD3<Double>(0, y, z)
        let markHalf: Double = pixelLength(ApsidesWorkshopShaders.markQuadExtent * Geometry.markRadius, at: at, cam,
                                           width: width, height: height)
        let lineHalf: Double = pixelLength(Geometry.bandLine / 2, at: at, cam, width: width, height: height)
        var x: Double = Geometry.gaugeStart + 0.025
        while x <= Geometry.gaugeEnd - 0.025 {
            let candidate = SIMD3<Double>(x, y, z)
            x += 0.025
            guard let p = project(candidate, cam, width: width, height: height),
                  inside(p, width: width, height: height) else { continue }
            guard Swift.abs(p.x - markPixel.x) >= markHalf + clearance else { continue }
            let bandLeft: Double = lowPixel.x - lineHalf - clearance
            let bandRight: Double = highPixel.x + lineHalf + clearance
            guard p.x < bandLeft || p.x > bandRight else { continue }
            guard o.isClear(p, after: rank, clearance: clearance) else { continue }
            return (p, false)
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

    /// Whether `c` has red above blue by at least 0.08 (deep rose, the broken colour).
    static func isReddish(_ c: SIMD3<Double>) -> Bool {
        c.x - c.z >= hueMargin
    }

    /// The number of pixels brighter than the backdrop's top colour by 0.1 in luminance (anything drawn on it).
    static func drawnPixels(_ rgba: [UInt8]) -> Int {
        let floor: Double = luminance(Palette.midnightTop) + 0.1
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

    // MARK: CPU reference (clarification Q3)

    /// The camera the scene uses on a `width` × `height` target (independent of the snapshot, the tier and the time).
    static func camera(width: Int, height: Int) -> ApsidesWorkshopCamera {
        Geometry.camera(aspect: Double(width) / Double(Swift.max(height, 1)))
    }

    /// The pixel of world point `point` through `camera` on a `width` × `height` target (nil without a projection).
    static func project(_ point: SIMD3<Double>, _ camera: ApsidesWorkshopCamera, width: Int,
                        height: Int) -> SIMD2<Double>? {
        guard let v = Geometry.project(point, camera: camera) else { return nil }
        return SIMD2<Double>(v.x * Double(width), v.y * Double(height))
    }

    /// The pixel of world point `point` on a `width` × `height` target (origin top left, y down; nil without a
    /// projection or for an empty target).
    static func pixel(_ point: SIMD3<Double>, width: Int = width, height: Int = height) -> SIMD2<Double>? {
        guard width > 0, height > 0 else { return nil }
        return project(point, camera(width: width, height: height), width: width, height: height)
    }

    /// The pixels of the geometry's reference points (`referencePoints`: every planet's centre, the star's centre,
    /// the orbiter's centre, the first gauge track's centre and the first actions bar) in their order (nil without a
    /// projection); empty for an empty target.
    static func referencePixels(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> [SIMD2<Double>?] {
        var result: [SIMD2<Double>?] = []
        guard width > 0, height > 0 else { return result }
        let cam: ApsidesWorkshopCamera = camera(width: width, height: height)
        for element in Geometry.referencePoints(snapshot) {
            result.append(project(element.centre, cam, width: width, height: height))
        }
        return result
    }

    /// The number of reference points `snapshot` has: its planets, the star, the orbiter, the first gauge track (with
    /// a target) and the first actions bar (with a budget).
    nonisolated static func referenceCount(_ snapshot: ApsidesWorkshopSceneSnapshot) -> Int {
        snapshot.planets.count + 2 + (snapshot.gauges.isEmpty ? 0 : 1) + (snapshot.budget > 0 ? 1 : 0)
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

    /// The pixel length of the world length `length` at `centre` (along x; the camera looks straight down the z axis).
    static func pixelLength(_ length: Double, at centre: SIMD3<Double>, _ camera: ApsidesWorkshopCamera,
                            width: Int, height: Int) -> Double {
        guard let a = project(centre, camera, width: width, height: height),
              let b = project(centre + SIMD3<Double>(length, 0, 0), camera, width: width, height: height) else {
            return 0
        }
        let d: SIMD2<Double> = b - a
        return (d.x * d.x + d.y * d.y).squareRoot()
    }

    /// The projected strip of half width `half` (world units) from `a` to `b`, or nil without a projection.
    static func strip(_ a: SIMD3<Double>, _ b: SIMD3<Double>, half: Double, _ camera: ApsidesWorkshopCamera,
                      width: Int, height: Int) -> ApsidesWorkshopTestCapsule? {
        guard let pa = project(a, camera, width: width, height: height),
              let pb = project(b, camera, width: width, height: height) else { return nil }
        let w: Double = pixelLength(half, at: (a + b) / 2, camera, width: width, height: height)
        return ApsidesWorkshopTestCapsule(a: pa, b: pb, half: w)
    }

    /// The projected disc of `radius` (world units) around `centre`, or nil without a projection.
    static func disc(_ centre: SIMD3<Double>, radius: Double, _ camera: ApsidesWorkshopCamera, width: Int,
                     height: Int) -> ApsidesWorkshopTestCapsule? {
        strip(centre, centre, half: radius, camera, width: width, height: height)
    }

    /// The hull of the rectangle of half sizes `half` (world units) around `centre` in its plane.
    static func rectangleHull(_ centre: SIMD3<Double>, half: SIMD2<Double>, _ camera: ApsidesWorkshopCamera,
                              width: Int, height: Int) -> [SIMD2<Double>] {
        let corners: [SIMD3<Double>] = [
            centre + SIMD3<Double>(-half.x, -half.y, 0), centre + SIMD3<Double>(half.x, -half.y, 0),
            centre + SIMD3<Double>(half.x, half.y, 0), centre + SIMD3<Double>(-half.x, half.y, 0),
        ]
        var projected: [SIMD2<Double>] = []
        for corner in corners {
            if let p = project(corner, camera, width: width, height: height) { projected.append(p) }
        }
        return convexHull(projected)
    }

    /// The strips of the closed loop through `points`, each of half width `half` (world units).
    static func loopStrips(_ points: [SIMD3<Double>], half: Double, _ camera: ApsidesWorkshopCamera, width: Int,
                           height: Int) -> [ApsidesWorkshopTestCapsule] {
        var result: [ApsidesWorkshopTestCapsule] = []
        let n: Int = points.count
        guard n >= 2 else { return result }
        for k in 0..<n {
            if let s = strip(points[k], points[(k + 1) % n], half: half, camera, width: width, height: height) {
                result.append(s)
            }
        }
        return result
    }

    /// The orbit loop's points of every tier at once: the kernel's chords (level-2) and the level-0 refinement.
    static func orbitPoints(_ snapshot: Snapshot) -> (chords: [SIMD3<Double>], refined: [SIMD3<Double>]) {
        let cheapest: ApsidesWorkshopTier = ApsidesWorkshopTier.all[ApsidesWorkshopTier.all.count - 1]
        let richest: ApsidesWorkshopTier = ApsidesWorkshopTier.all[0]
        return (Geometry.refinement(snapshot, tier: cheapest), Geometry.refinement(snapshot, tier: richest))
    }

    /// The projected footprint of `element` of `snapshot` (see the file header).
    static func footprint(_ element: Element, _ snapshot: Snapshot, _ cam: ApsidesWorkshopCamera,
                          width: Int, height: Int) -> ApsidesWorkshopTestFootprint {
        var f = ApsidesWorkshopTestFootprint()
        let i: Int = element.item
        let c: SIMD3<Double> = element.centre
        switch element.part {
        case .backdrop:
            break
        case .wedge:
            let n: Int = snapshot.positions.count
            guard i >= 0, i < n else { return f }
            let corners: [SIMD3<Double>] = [
                SIMD3<Double>(0, 0, Geometry.wedgeDepth),
                Geometry.world(snapshot.positions[i], depth: Geometry.wedgeDepth),
                Geometry.world(snapshot.positions[(i + 1) % n], depth: Geometry.wedgeDepth),
            ]
            var projected: [SIMD2<Double>] = []
            for corner in corners {
                if let p = project(corner, cam, width: width, height: height) { projected.append(p) }
            }
            let hull: [SIMD2<Double>] = convexHull(projected)
            if hull.count >= 3 {
                f.hulls.append(hull)
            } else if projected.count >= 2 {
                // A degenerate wedge (collinear corners) is a segment.
                f.capsules.append(ApsidesWorkshopTestCapsule(a: projected[0], b: projected[projected.count - 1],
                                                             half: 0.5))
            }
        case .compass:
            let outer: Double = Geometry.apsisBracketRadius + Geometry.apsisBracketWidth / 2
            if let d = disc(Geometry.starCentre(), radius: outer, cam, width: width, height: height) {
                f.capsules.append(d)
            }
        case .ghost:
            var loop: [SIMD3<Double>] = []
            for p in snapshot.ghost { loop.append(Geometry.world(p, depth: Geometry.ghostDepth)) }
            f.capsules += loopStrips(loop, half: Geometry.ghostWidth / 2, cam, width: width, height: height)
        case .orbit:
            let points = orbitPoints(snapshot)
            let half: Double = Geometry.orbitWidth / 2
            f.capsules += loopStrips(points.chords, half: half, cam, width: width, height: height)
            f.capsules += loopStrips(points.refined, half: half, cam, width: width, height: height)
            if let hit = Geometry.contact(snapshot), !snapshot.positions.isEmpty {
                let n: Int = snapshot.positions.count
                let t: Int = Swift.min(Swift.max(hit.tick, 0), n - 1)
                let a: SIMD3<Double> = Geometry.world(snapshot.positions[t], depth: Geometry.planeZ)
                let b: SIMD3<Double> = Geometry.world(snapshot.positions[(t + 1) % n], depth: Geometry.planeZ)
                if let s = strip(a, b, half: Geometry.brokenSegmentWidth / 2, cam, width: width, height: height) {
                    f.capsules.append(s)
                }
            }
        case .periapsis, .apoapsis:
            let size: Double = element.part == .periapsis ? Geometry.periapsisSize : Geometry.apoapsisSize
            let radius: Double = ApsidesWorkshopShaders.markQuadExtent * size / 2 * 2.0.squareRoot()
            if let d = disc(c, radius: radius, cam, width: width, height: height) { f.capsules.append(d) }
        case .planet:
            let radius: Double = Geometry.planetRadius(i, snapshot) + Geometry.hazardWidth
            if let d = disc(c, radius: radius, cam, width: width, height: height) { f.capsules.append(d) }
        case .star:
            if let d = disc(c, radius: Geometry.starRadius, cam, width: width, height: height) { f.capsules.append(d) }
        case .orbiter:
            if let d = disc(c, radius: Geometry.orbiterRadius, cam, width: width, height: height) {
                f.capsules.append(d)
            }
        case .track:
            let markHalf: Double = ApsidesWorkshopShaders.markQuadExtent * Geometry.markRadius
            let halfWidth: Double = (Geometry.gaugeEnd - Geometry.gaugeStart) / 2 + markHalf
            f.hulls.append(rectangleHull(c, half: SIMD2<Double>(halfWidth, gaugeRowHalf), cam, width: width,
                                         height: height))
        case .bar:
            let half = SIMD2<Double>(Geometry.barFill * Geometry.actionsSlot(snapshot) / 2, Geometry.barHeight / 2)
            f.hulls.append(rectangleHull(c, half: half, cam, width: width, height: height))
        }
        return f
    }

    /// The level-0 glow's footprint (the widest glow of any tier): the star's and the orbiter's bands and the orbit
    /// loop's ribbon at their outermost shell.
    static func glowFootprint(_ snapshot: Snapshot, _ cam: ApsidesWorkshopCamera, width: Int,
                              height: Int) -> ApsidesWorkshopTestFootprint {
        var f = ApsidesWorkshopTestFootprint()
        let shells: Double = Double(ApsidesWorkshopTier.all[0].glowShells)
        let star: Double = Geometry.starRadius + Geometry.starGlowGrowth * shells
        if let d = disc(Geometry.starCentre(), radius: star, cam, width: width, height: height) { f.capsules.append(d) }
        let orbiter: Double = Geometry.orbiterRadius + Geometry.orbiterGlowGrowth * shells
        if let d = disc(Geometry.orbiterCentre(snapshot), radius: orbiter, cam, width: width, height: height) {
            f.capsules.append(d)
        }
        let half: Double = Geometry.orbitWidth / 2 + Geometry.orbitGlowGrowth * shells
        f.capsules += loopStrips(orbitPoints(snapshot).refined, half: half, cam, width: width, height: height)
        return f
    }

    /// The painter's order of `snapshot` on a `width` × `height` target with every element's footprint and the
    /// glow's; empty for an empty target.
    static func layout(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> ApsidesWorkshopTestLayout {
        var result = ApsidesWorkshopTestLayout()
        guard width > 0, height > 0 else { return result }
        let cam: ApsidesWorkshopCamera = camera(width: width, height: height)
        result.order = Geometry.paintOrder(snapshot)
        for element in result.order {
            result.footprints.append(footprint(element, snapshot, cam, width: width, height: height))
        }
        result.glow = glowFootprint(snapshot, cam, width: width, height: height)
        return result
    }

    /// The backdrop's colour coordinates on a `width` × `height` target; nil for an empty target.
    static func backdrop(width: Int = width, height: Int = height) -> ApsidesWorkshopTestBackdrop? {
        guard width > 0, height > 0 else { return nil }
        return ApsidesWorkshopTestBackdrop(camera: camera(width: width, height: height), width: width, height: height)
    }

    // MARK: Checks

    /// The gauge marks of `snapshot` that project into the picture clear of every later element, with their target.
    static func clearMarks(_ snapshot: Snapshot, width: Int = width,
                           height: Int = height) -> [(target: Int, pixel: SIMD2<Double>)] {
        let o: ApsidesWorkshopTestLayout = layout(snapshot, width: width, height: height)
        var result: [(target: Int, pixel: SIMD2<Double>)] = []
        for i in snapshot.gauges.indices {
            guard let rank = o.rank(.track, i),
                  let p = pixel(Geometry.markCentre(i, snapshot), width: width, height: height),
                  inside(p, width: width, height: height),
                  o.isClear(p, after: rank, clearance: clearance) else { continue }
            result.append((i, p))
        }
        return result
    }

    /// The backdrop patch check at view fraction (`fx`, `fy`): nil when the patch is not measured (outside the
    /// picture or near a footprint), else the miss in words or "" when it passed.
    static func patchResult(_ rgba: [UInt8], fx: Double, fy: Double, sky: ApsidesWorkshopTestBackdrop,
                            _ o: ApsidesWorkshopTestLayout, width: Int, height: Int) -> String? {
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
        return String(format: format, cx, cy, sky.heightAt(x: p.x, y: p.y), got.x, got.y, got.z, gradient.x,
                      gradient.y, gradient.z)
    }

    /// The bright-centre check of clarification Q3 at the element `part` (the star or the orbiter) centred at
    /// `point`: true when measured; a miss is added to `misses`.
    static func checkBright(_ rgba: [UInt8], _ part: Part, at point: SIMD3<Double>, _ o: ApsidesWorkshopTestLayout,
                            _ sky: ApsidesWorkshopTestBackdrop, width: Int, height: Int,
                            misses: inout [String]) -> Bool {
        let name: String = part == .star ? "star" : "orbiter"
        guard let p = pixel(point, width: width, height: height), inside(p, width: width, height: height),
              let rank = o.rank(part, 0) else {
            misses.append("\(name): it does not project into the picture")
            return false
        }
        guard o.isClear(p, after: rank, clearance: clearance) else { return false }
        let floor: Double = luminance(sky.gradient(x: p.x, y: p.y)) + brightMargin
        let bright: Bool = anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height,
                                    where: { luminance($0) >= floor })
        if !bright {
            let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
            misses.append(name + String(format: " centre (%.1f, %.1f) is (%.3f, %.3f, %.3f)", p.x, p.y, c.x, c.y,
                                        c.z))
        }
        return true
    }

    /// The gauge checks of clarification Q3 (the first actions bar when lit, the first gauge track's centre) on
    /// `rgba` against `snapshot`, added to `report`.
    static func checkGauges(_ rgba: [UInt8], _ snapshot: Snapshot, _ o: ApsidesWorkshopTestLayout,
                            _ sky: ApsidesWorkshopTestBackdrop, width: Int, height: Int,
                            into report: inout ApsidesWorkshopCheckReport) {
        if Geometry.litActions(snapshot) > 0,
           let p = pixel(Geometry.actionsBar(0, snapshot), width: width, height: height),
           inside(p, width: width, height: height), let rank = o.rank(.bar, 0),
           o.isClear(p, after: rank, clearance: clearance) {
            report.barChecked = true
            if !anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height, where: isReddish) {
                let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
                report.misses.append(String(format: "actions bar 0 (%.1f, %.1f) is (%.3f, %.3f, %.3f)", p.x, p.y,
                                            c.x, c.y, c.z))
            }
        }
        if !snapshot.gauges.isEmpty, let p = pixel(Geometry.gaugeCentre(0), width: width, height: height),
           inside(p, width: width, height: height), let rank = o.rank(.track, 0),
           o.isClear(p, after: rank, clearance: clearance) {
            report.trackChecked = true
            let back: Double = luminance(sky.gradient(x: p.x, y: p.y))
            let off: Bool = anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height,
                                     where: { Swift.abs(luminance($0) - back) >= trackMargin })
            if !off {
                report.misses.append(String(format: "gauge track 0 centre (%.1f, %.1f) is backdrop-coloured", p.x,
                                            p.y))
            }
        }
    }

    /// The point checks of clarification Q3 (see the file header) on `rgba` against `snapshot`.
    static func pointReport(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width,
                            height: Int = height) -> ApsidesWorkshopCheckReport {
        var report = ApsidesWorkshopCheckReport()
        let o: ApsidesWorkshopTestLayout = layout(snapshot, width: width, height: height)
        guard let sky = backdrop(width: width, height: height) else {
            report.misses.append("an empty target")
            return report
        }
        var misses: [String] = []
        let star: Bool = checkBright(rgba, .star, at: Geometry.starCentre(), o, sky, width: width, height: height,
                                     misses: &misses)
        let orbiter: Bool = checkBright(rgba, .orbiter, at: Geometry.orbiterCentre(snapshot), o, sky, width: width,
                                        height: height, misses: &misses)
        report.starChecked = star
        report.orbiterChecked = orbiter
        report.misses += misses
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
    /// the report. With the shown tick T/2 the star and the orbiter are always clear, so both must be measured, as
    /// must the first gauge track and (when lit) the first actions bar; a picture of at least 64 × 64 must measure at
    /// least four backdrop patches.
    @discardableResult
    static func checkFrame(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width, height: Int = height,
                           _ what: String,
                           sourceLocation: SourceLocation = #_sourceLocation) -> ApsidesWorkshopCheckReport {
        #expect(rgba.count == width * height * 4, "\(what): picture size", sourceLocation: sourceLocation)
        guard rgba.count == width * height * 4 else { return ApsidesWorkshopCheckReport() }
        let report: ApsidesWorkshopCheckReport = pointReport(rgba, snapshot: snapshot, width: width, height: height)
        if snapshot.shownTick == halfTick(snapshot.period) {
            #expect(report.starChecked, "\(what): the star's centre was not clear", sourceLocation: sourceLocation)
            #expect(report.orbiterChecked, "\(what): the orbiter's centre was not clear",
                    sourceLocation: sourceLocation)
        }
        if !snapshot.gauges.isEmpty {
            #expect(report.trackChecked, "\(what): the first gauge track was not clear", sourceLocation: sourceLocation)
        }
        if Geometry.litActions(snapshot) > 0 {
            #expect(report.barChecked, "\(what): the first actions bar was not clear", sourceLocation: sourceLocation)
        }
        if width >= 64 && height >= 64 {
            #expect(report.patchesChecked >= 4, "\(what): backdrop patches \(report.patchesChecked)",
                    sourceLocation: sourceLocation)
        }
        let shown: [String] = Array(report.misses.prefix(8))
        #expect(report.misses.isEmpty, "\(what): \(shown)", sourceLocation: sourceLocation)
        print("apsides-workshop \(what): star \(report.starChecked); orbiter \(report.orbiterChecked); bar "
              + "\(report.barChecked); track \(report.trackChecked); patches \(report.patchesChecked)")
        return report
    }
}
#endif
