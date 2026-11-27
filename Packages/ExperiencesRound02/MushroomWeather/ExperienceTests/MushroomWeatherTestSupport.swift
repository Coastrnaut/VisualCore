// MushroomWeatherTestSupport — feature 493 (R02-G20-03) T-R02G2003-006 (FR-R02G2003-001 … 007; clarifications
// Q1–Q5). Shared helpers of the Mushroom Weather experience tests, following Microscopic Aurora's harness (feature
// 483): opening the experience through the one app's session host (seed `s` prepares certified level `s % 100 + 1`;
// a session without a quality pin is pinned to level 0), making set-up actions (each level's certified plan, the
// generator's plan `MushroomWeatherExperienceCore.generated(number:).plan`, so the predicted run is the winning one)
// and showing the cycle half the cycles run (`clock.show [cyclesRun / 2]`), issuing kernel actions through the shell,
// drawing live frames, drawing an off-screen still (RGBA8, rows top-down, the orientation of the Core's CPU projection
// `MushroomWeatherSceneGeometry.project`, origin top left, y down, scaled here to pixels), the engine digest, the frame
// checks of clarification Q3 at 1,152 × 768, and a short search for a failing run whose broken element is clear of
// every later element.
//
// Only the droplets and the spore motes move by time (their vertex shader reads `u_time` times `u_motion`); they are
// never reference points, and their footprints below cover their whole paths, so every check here holds at every
// frame time. Every still here is drawn at frame time 0 unless a test says otherwise.
//
// The CPU reference: the painter's order of `MushroomWeatherSceneGeometry.paintOrder` (by kind, then index; the scene
// draws with depth testing off, so a later element covers an earlier one) with every element's projected footprint,
// the convex hull of points that bound it, conservative where the drawn shape is smaller (world sizes of the
// geometry's constants; every quad at its full extent ``MushroomWeatherShaders/quadExtent`` times its shape half,
// which is also what the unlit fallback draws): the backdrop none (it lies under everything); the moon its quad and
// its four tick quads; a floor cell, a mist square, the mold patch, a site ring and a band ring their horizontal
// quads; a log or stone its box; each frond stem its strip; a stalk its cylinder; a cap the cylinder from the wilted
// rim to the apex with the eye-facing disc of the flat cap; a pod the cylinder from the floor to its top, its
// eye-facing disc and a grown pod's ring quad; each droplet its quad along its whole rise; each mote its quad around
// its whole loop; a vent its box; a gauge row the box of its track, its band bracket quad and its marker quad; a run
// bar its segments' box; an actions bar its quad. Droplets, motes and fronds are those of the tier drawn (of every
// tier when no tier is named). The additive glow (drawn last) only brightens and hides no cue, but its extent at the
// tier drawn (the cap and pod shells) keeps the backdrop patches away.
// A point is checked only when it projects into the picture at least 6 px from every element drawn after it:
//   - each cap's centre: within 3 px a pixel brighter than moss (`MushroomWeatherPalette.moss`) by 0.2 in luminance
//     (caps are drawn in colony order, so the last one is never excluded by another cap; at least one is checked in
//     every frame);
//   - the moon's centre: within 3 px a pixel 0.1 from the backdrop at its height in luminance;
//   - the first actions bar, when lit: within 3 px red above blue by 0.08 (the amber of an action left);
//   - the first gauge track's centre: within 3 px a pixel 0.1 from the backdrop in luminance;
//   - the backdrop: 9 × 9 patches at 3 % from the picture's corners, 24 px from every footprint; the per-channel
//     median of each is within 0.06 of the gradient (midnight at the bottom of the backdrop quad, midnight top at its
//     top) at its height (`MushroomWeatherSceneGeometry.backdropHeight(view:camera:)`); both lower corners are
//     measured on a picture of at least 256 × 256.
// Luminance is the Rec. 709 weighting of the stored 0 … 1 channel values. Positions come from the presenter's
// `lastSnapshot`. Short runs only (no sleep, no wall-clock assertion).
//
// The checked levels are catalog levels 1, 21, 41, 61 and 81 (seeds 0, 20, 40, 60, 80).
#if os(iOS)
import CoreGraphics
import Foundation
import MushroomWeatherCore
import Testing
import UIKit
@testable import MushroomWeatherExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the point checks of one frame found.
struct MushroomWeatherCheckReport {
    /// The caps whose centre was measured.
    var capsChecked: Int = 0
    /// Whether the moon's centre was measured.
    var moonChecked: Bool = false
    /// Whether the first actions bar was measured.
    var barChecked: Bool = false
    /// Whether the first gauge track's centre was measured.
    var trackChecked: Bool = false
    /// The backdrop patches measured.
    var patchesChecked: Int = 0
    /// The lower-corner backdrop patches measured.
    var lowerPatchesChecked: Int = 0
    /// Every failed check, in words.
    var misses: [String] = []
}

/// The projected footprint of one drawn element (pixels, y down): convex polygons.
struct MushroomWeatherTestFootprint {
    /// Convex polygons (corners in the order `convexHull` gives them).
    var hulls: [[SIMD2<Double>]] = []

    /// The signed distance (pixels) of `p` from the footprint: negative inside, infinite for an empty footprint.
    func distance(_ p: SIMD2<Double>) -> Double {
        var best: Double = Double.infinity
        for hull in hulls { best = Swift.min(best, MushroomWeatherTest.hullDistance(hull, p)) }
        return best
    }
}

/// The painter's order of one snapshot on one target with every element's footprint (same indices) and the glow's.
struct MushroomWeatherTestLayout {
    /// The elements in painter's order.
    var order: [MushroomWeatherElement] = []
    /// The footprint of each element of `order`.
    var footprints: [MushroomWeatherTestFootprint] = []
    /// The glow's footprint at the tier drawn (drawn last, additive).
    var glow = MushroomWeatherTestFootprint()

    /// The place of the element of `kind` drawing `item` in the painter's order, or nil.
    func rank(_ kind: MushroomWeatherElement.Kind, _ item: Int) -> Int? {
        for (place, element) in order.enumerated() where element.kind == kind && element.item == item {
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
struct MushroomWeatherTestBackdrop {
    /// The camera of the target.
    var camera: MushroomWeatherCamera
    /// The target's width in pixels.
    var width: Int
    /// The target's height in pixels.
    var height: Int

    /// The backdrop's height h (0 at the quad's bottom, 1 at its top) at pixel (`x`, `y`).
    func heightAt(x: Double, y: Double) -> Double {
        let view = SIMD2<Double>(x / Double(width), y / Double(height))
        return MushroomWeatherSceneGeometry.backdropHeight(view: view, camera: camera)
    }

    /// The gradient colour (midnight → midnight top) at pixel (`x`, `y`): the shader's CPU reference.
    func gradient(x: Double, y: Double) -> SIMD3<Double> {
        MushroomWeatherShaders.backdropColour(height: heightAt(x: x, y: y))
    }
}

/// A run that fails with a broken element clear of every later element: the level, the set-up before the run, the
/// failure's code and the checked points of the broken element at the check size (level-2).
struct MushroomWeatherFailureCase {
    /// The catalog level number.
    var number: Int
    /// The actions made before the run.
    var setUp: [MushroomWeatherAction]
    /// The failure's code (`dried`, `mold` or `unstable`).
    var code: String
    /// The checked points of the broken element (pixels at 1,152 × 768).
    var points: [SIMD2<Double>]
}

/// Building, opening, drawing and measuring Mushroom Weather.
@MainActor
enum MushroomWeatherTest {
    typealias Geometry = MushroomWeatherSceneGeometry
    typealias Palette = MushroomWeatherPalette
    typealias Snapshot = MushroomWeatherSceneSnapshot
    typealias Shell = ExperienceShell<MushroomWeatherPresenter>
    typealias Element = MushroomWeatherElement
    typealias Kind = MushroomWeatherElement.Kind

    /// The experience id `r02-g20.mushroom-weather`.
    static var id: ExperienceID {
        MushroomWeatherExperience.id ?? ExperienceID(rawValue: "r02-g20.unknown")!
    }

    /// The frame-check size of clarification Q3, aspect 1.5.
    nonisolated static let width: Int = 1_152
    nonisolated static let height: Int = 768
    /// The checked catalog levels and their seeds (seed = level − 1).
    nonisolated static let levels: [Int] = [1, 21, 41, 61, 81]
    nonisolated static let seeds: [UInt64] = [0, 20, 40, 60, 80]
    /// The search radius (pixels) of the point checks.
    nonisolated static let pointRadius: Double = 3
    /// The search radius (pixels) at a broken or lit mark.
    nonisolated static let markRadius: Double = 1.5
    /// The clearance (pixels) of every checked point from every element drawn after it.
    nonisolated static let clearance: Double = 6
    /// Each cap's centre is brighter than moss by at least this.
    nonisolated static let brightMargin: Double = 0.2
    /// The first actions bar's red above blue.
    nonisolated static let hueMargin: Double = 0.08
    /// The moon's and the gauge track's luminance difference from the backdrop.
    nonisolated static let backdropMargin: Double = 0.1
    /// The per-channel bound of a backdrop patch's median.
    nonisolated static let backdropTolerance: Double = 0.06
    /// The per-channel bound of a flat level-2 colour (the broken colour, the lit cap colour).
    nonisolated static let colourTolerance: Double = 0.1
    /// A backdrop patch's half side (pixels; 9 × 9) and its clearance from every footprint.
    nonisolated static let patchHalf: Int = 4
    nonisolated static let patchClearance: Double = 24
    /// The backdrop patch centres (fractions of the view, origin top left): the four corners at 3 %, the lower two
    /// last.
    nonisolated static let patchFractions: [(x: Double, y: Double)] = [(0.03, 0.03), (0.97, 0.03), (0.03, 0.97), (0.97, 0.97)]
    /// The samples of a circle bound (its polygon is scaled out so it holds the circle).
    nonisolated static let circleSamples: Int = 16

    /// Opens Mushroom Weather with `seed` in `session` through the factory, lays the view out at `size` points, draws
    /// one frame, makes the actions `setUp` through the shell and, with `atHalf`, shows the cycle half the cycles run
    /// and draws again. A session without a quality pin is pinned to level 0. `configure` runs on the presenter before
    /// its first `setup` (the fallback seam).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, setUp: [MushroomWeatherAction] = [],
                     reduceMotion: Bool = false, reduceFlashing: Bool = false,
                     size: CGSize = CGSize(width: 48, height: 32), atHalf: Bool = true,
                     configure: ((MushroomWeatherPresenter) -> Void)? = nil) async throws -> Shell {
        let id: ExperienceID = self.id
        var made: Shell?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: seed) {
            let shell: Shell = MushroomWeatherExperience.make(id: id, reduceMotion: reduceMotion,
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
        if !setUp.isEmpty {
            #expect(issue(shell, setUp) == setUp.count)
        }
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
    static func core(_ shell: Shell) throws -> MushroomWeatherExperienceCore {
        try #require(shell.engine.core)
    }

    /// Pins `session` to quality level `tier` and checks that the engine took it.
    static func pin(_ session: ExperienceSession, _ shell: Shell, tier: Int,
                    sourceLocation: SourceLocation = #_sourceLocation) {
        session.qualityPin = tier
        #expect(shell.engine.qualityTier == tier, "pinned tier \(tier)", sourceLocation: sourceLocation)
    }

    /// The shown cycle of clarification Q3: half the cycles run.
    nonisolated static func halfCycle(_ cyclesRun: Int) -> Int {
        cyclesRun / 2
    }

    /// Shows the cycle half the cycles run of `shell`'s play through the shell (`clock.show [cycles / 2]`); returns
    /// the cycle.
    @discardableResult
    static func showHalf(_ shell: Shell, sourceLocation: SourceLocation = #_sourceLocation) throws -> Int {
        let cycle: Int = halfCycle(try core(shell).play.report.cycles)
        let result: ActionResult = shell.handle(control: "clock.show", values: [Double(cycle)])
        #expect(result == .accepted, "clock.show [\(cycle)]: \(result.code)", sourceLocation: sourceLocation)
        return cycle
    }

    // MARK: Actions

    /// The control and values that issue the kernel action `action` through the shell.
    nonisolated static func control(_ action: MushroomWeatherAction) -> (control: String, values: [Double]) {
        switch action {
        case let .place(slot, cell):
            return ("pod.place", [Double(slot), Double(cell.row), Double(cell.column)])
        case let .remove(slot):
            return ("pod.remove", [Double(slot)])
        case let .vent(index, open):
            return ("vent.set", [Double(index), open ? 1 : 0])
        case let .moonlight(level):
            return ("moon.set", [Double(level)])
        case .run:
            return ("weather.run", [])
        }
    }

    /// The host action of `action` (step 0).
    nonisolated static func experienceAction(_ action: MushroomWeatherAction) -> ExperienceAction {
        let issued = control(action)
        return ExperienceAction(control: issued.control, values: issued.values, step: 0)
    }

    /// The host action showing cycle `cycle` (step 0).
    nonisolated static func showAction(_ cycle: Int) -> ExperienceAction {
        ExperienceAction(control: "clock.show", values: [Double(cycle)], step: 0)
    }

    /// The certified plan of level `number` (the generator's plan): its actions (the run not included).
    nonisolated static func certifiedPlan(_ number: Int) throws -> [MushroomWeatherAction] {
        try MushroomWeatherExperienceCore.generated(number: number).plan.actions
    }

    /// Issues `actions` through the shell, each expected to be accepted; returns how many were.
    @discardableResult
    static func issue(_ shell: Shell, _ actions: [MushroomWeatherAction],
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

    /// The opening core of level `number` with `actions` applied and, with `showHalf`, the cycle half the cycles run
    /// shown (no host): the CPU reference of that state.
    static func coreAfter(_ number: Int, _ actions: [MushroomWeatherAction],
                          showHalf: Bool = true) throws -> MushroomWeatherExperienceCore {
        var core: MushroomWeatherExperienceCore = try MushroomWeatherExperienceCore.opening(number: number)
        for action in actions {
            let result: ActionResult = core.apply(experienceAction(action))
            #expect(result == .accepted, "level \(number) \(action): \(result.code)")
        }
        if showHalf {
            let cycle: Int = halfCycle(core.play.report.cycles)
            let result: ActionResult = core.apply(showAction(cycle))
            #expect(result == .accepted, "level \(number) clock.show [\(cycle)]: \(result.code)")
        }
        return core
    }

    /// The set-ups tried before the run in ``failureCase(candidates:)``: none (the opening: an immediate run), then
    /// every proper prefix of the certified plan (the search skips those the kernel refuses).
    static func setUps(_ number: Int) throws -> [[MushroomWeatherAction]] {
        var result: [[MushroomWeatherAction]] = [[]]
        let plan: [MushroomWeatherAction] = try certifiedPlan(number)
        var length: Int = 1
        while length < plan.count {
            result.append(Array(plan.prefix(length)))
            length += 1
        }
        return result
    }

    /// The first run over `candidates` (level numbers) after one of ``setUps(_:)`` that fails and whose broken
    /// element has a point that projects into the level-2 picture clear of every later element; nil when none does.
    static func failureCase(candidates: [Int]) throws -> MushroomWeatherFailureCase? {
        for number in candidates {
            for setUp in try setUps(number) {
                var core: MushroomWeatherExperienceCore = try MushroomWeatherExperienceCore.opening(number: number)
                var accepted: Bool = true
                let actions: [MushroomWeatherAction] = setUp + [.run]
                for action in actions where accepted {
                    let result: ActionResult = core.apply(experienceAction(action))
                    if result != .accepted { accepted = false }
                }
                guard accepted, core.play.stage == .failed, let failure = core.play.failure else { continue }
                _ = core.apply(showAction(halfCycle(core.play.report.cycles)))
                let snapshot: Snapshot = core.snapshot(time: 0)
                let points: [SIMD2<Double>] = brokenPoints(snapshot)
                guard !points.isEmpty else { continue }
                return MushroomWeatherFailureCase(number: number, setUp: setUp, code: failure.code, points: points)
            }
        }
        return nil
    }

    /// The pixels of `candidates` (world) that project into the picture clear of every element after place `rank`.
    static func clearPixels(_ candidates: [SIMD3<Double>], after rank: Int, _ o: MushroomWeatherTestLayout,
                            width: Int, height: Int) -> [SIMD2<Double>] {
        var result: [SIMD2<Double>] = []
        for point in candidates {
            guard let p = pixel(point, width: width, height: height), inside(p, width: width, height: height),
                  o.isClear(p, after: rank, clearance: clearance) else { continue }
            result.append(p)
        }
        return result
    }

    /// Up to `limit` points of the broken element of the failed `snapshot` at the check size and level-2 (where the
    /// broken colour is drawn flat), each clear of every later element: on a dried failure the named colony's cap
    /// centre; on a mold failure points of the mold patch; on an unstable failure the named colony's marker centre and
    /// its run bar's segment centres. Empty without a failure on a failed play or without a clear point.
    static func brokenPoints(_ snapshot: Snapshot, width: Int = width, height: Int = height,
                             limit: Int = 6) -> [SIMD2<Double>] {
        let o: MushroomWeatherTestLayout = layout(snapshot, tier: 2, width: width, height: height)
        var result: [SIMD2<Double>] = []
        guard snapshot.stage == .failed else { return result }
        let s: Double = Geometry.scale(rows: snapshot.rows, columns: snapshot.columns)
        if let colony = Geometry.driedColony(snapshot), let rank = o.rank(.cap, colony) {
            result += clearPixels([Geometry.capCentre(colony, snapshot)], after: rank, o, width: width,
                                  height: height)
        }
        if let cell = Geometry.moldCell(snapshot), let rank = o.rank(.mark, cell.row * snapshot.columns + cell.column) {
            var centre: SIMD3<Double> = Geometry.cellCentre(cell, snapshot, height: 0)
            centre.z = Geometry.markZ
            let d: Double = 0.15 * s
            let candidates: [SIMD3<Double>] = [
                centre, centre + SIMD3<Double>(d, 0, 0), centre + SIMD3<Double>(-d, 0, 0),
                centre + SIMD3<Double>(0, d, 0), centre + SIMD3<Double>(0, -d, 0),
            ]
            result += clearPixels(candidates, after: rank, o, width: width, height: height).prefix(limit)
        }
        if let colony = Geometry.unstableColony(snapshot) {
            if let rank = o.rank(.gauge, colony) {
                result += clearPixels([Geometry.markerCentre(colony, snapshot)], after: rank, o, width: width,
                                      height: height)
            }
            if let rank = o.rank(.runBar, colony) {
                var segments: [SIMD3<Double>] = []
                for segment in 0..<Swift.max(snapshot.requiredCycles, 1) {
                    segments.append(Geometry.runSegmentCentre(segment, colony: colony, snapshot))
                }
                result += clearPixels(segments, after: rank, o, width: width, height: height)
            }
        }
        return Array(result.prefix(limit))
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

    /// Whether `c` is the broken colour within 0.1 per channel (`MushroomWeatherPalette.broken`; the amber pods,
    /// markers and bars are 0.24 or more away in green).
    static func isBroken(_ c: SIMD3<Double>) -> Bool {
        channelDistance(c, Palette.broken) <= colourTolerance
    }

    /// Whether `c` is the lit cap colour within 0.1 per channel (`MushroomWeatherPalette.cap`).
    static func isLitCap(_ c: SIMD3<Double>) -> Bool {
        channelDistance(c, Palette.cap) <= colourTolerance
    }

    /// Whether `c` has red above blue by at least 0.08 (the amber of a lit actions bar; the unlit bar is bluer).
    static func isAmber(_ c: SIMD3<Double>) -> Bool {
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

    /// The number of pixels where `a` and `b` (same size) differ.
    static func differingPixels(_ a: [UInt8], _ b: [UInt8]) -> Int {
        guard a.count == b.count else { return Swift.max(a.count, b.count) / 4 }
        var count: Int = 0
        var i: Int = 0
        while i + 3 < a.count {
            if a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2] || a[i + 3] != b[i + 3] { count += 1 }
            i += 4
        }
        return count
    }

    /// The pixels (x, y) whose centres lie within `radius` of `p`, inside the picture.
    static func pixelsNear(_ p: SIMD2<Double>, radius: Double, width: Int, height: Int) -> [(x: Int, y: Int)] {
        var result: [(x: Int, y: Int)] = []
        let reach: Int = Int(radius.rounded(.up)) + 1
        let cx: Int = Int(p.x.rounded(.down))
        let cy: Int = Int(p.y.rounded(.down))
        for y in (cy - reach)...(cy + reach) {
            guard y >= 0, y < height else { continue }
            for x in (cx - reach)...(cx + reach) {
                guard x >= 0, x < width else { continue }
                let dx: Double = Double(x) + 0.5 - p.x
                let dy: Double = Double(y) + 0.5 - p.y
                if dx * dx + dy * dy <= radius * radius { result.append((x, y)) }
            }
        }
        return result
    }

    /// Whether some pixel whose centre lies within `radius` of `p` passes `test`.
    static func anyPixel(_ rgba: [UInt8], near p: SIMD2<Double>, radius: Double, width: Int, height: Int,
                         where test: (SIMD3<Double>) -> Bool) -> Bool {
        for spot in pixelsNear(p, radius: radius, width: width, height: height) {
            if test(colour(rgba, x: spot.x, y: spot.y, width: width)) { return true }
        }
        return false
    }

    /// The colour of the pixel that holds `p`, clamped to the picture.
    static func centre(_ rgba: [UInt8], _ p: SIMD2<Double>, width: Int = width,
                       height: Int = height) -> SIMD3<Double> {
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
    static func camera(width: Int, height: Int) -> MushroomWeatherCamera {
        Geometry.camera(aspect: Double(width) / Double(Swift.max(height, 1)))
    }

    /// The pixel of world point `point` through `camera` on a `width` × `height` target (nil without a projection).
    static func project(_ point: SIMD3<Double>, _ camera: MushroomWeatherCamera, width: Int,
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

    /// The pixels of the geometry's reference points (`referencePoints`: the floor centre, every cap centre, the moon
    /// centre, the first gauge track's centre and the first actions bar; never a droplet or a mote) in their order
    /// (nil without a projection); empty for an empty target.
    static func referencePixels(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> [SIMD2<Double>?] {
        var result: [SIMD2<Double>?] = []
        guard width > 0, height > 0 else { return result }
        let cam: MushroomWeatherCamera = camera(width: width, height: height)
        for point in Geometry.referencePoints(snapshot) {
            result.append(project(point.centre, cam, width: width, height: height))
        }
        return result
    }

    /// The number of reference points `snapshot` has: the floor centre, its caps, the moon, the first gauge track
    /// (with colonies) and the first actions bar (with a budget).
    nonisolated static func referenceCount(_ snapshot: MushroomWeatherSceneSnapshot) -> Int {
        2 + snapshot.colonies.count + (snapshot.colonies.isEmpty ? 0 : 1) + (snapshot.budget > 0 ? 1 : 0)
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

    // MARK: Bounding points (world)

    /// The cross product a × b.
    nonisolated static func cross(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3<Double>(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
    }

    /// `v` scaled to unit length (`fallback` for a zero vector).
    nonisolated static func unit(_ v: SIMD3<Double>, fallback: SIMD3<Double>) -> SIMD3<Double> {
        let length: Double = (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot()
        return length > 1e-9 ? v / length : fallback
    }

    /// The right and up axes of a part facing the eye at `centre` (as the geometry's eye-facing basis).
    nonisolated static func facing(_ centre: SIMD3<Double>) -> (right: SIMD3<Double>, up: SIMD3<Double>) {
        let w: SIMD3<Double> = unit(Geometry.eye - centre, fallback: SIMD3<Double>(0, 0, 1))
        let right: SIMD3<Double> = unit(cross(SIMD3<Double>(0, 0, 1), w), fallback: SIMD3<Double>(1, 0, 0))
        return (right: right, up: cross(w, right))
    }

    /// The four corners of the rectangle of half sizes `half` around `centre` in the plane of the unit axes `u`, `v`.
    nonisolated static func rectangle(_ centre: SIMD3<Double>, u: SIMD3<Double>, v: SIMD3<Double>,
                                      half: SIMD2<Double>) -> [SIMD3<Double>] {
        let a: SIMD3<Double> = u * half.x
        let b: SIMD3<Double> = v * half.y
        return [centre - a - b, centre + a - b, centre + a + b, centre - a + b]
    }

    /// The corners of a horizontal (floor-parallel) rectangle of half sizes `half` around `centre`.
    nonisolated static func horizontalRectangle(_ centre: SIMD3<Double>, half: SIMD2<Double>) -> [SIMD3<Double>] {
        rectangle(centre, u: SIMD3<Double>(1, 0, 0), v: SIMD3<Double>(0, 1, 0), half: half)
    }

    /// The corners of an eye-facing square of half side `half` around `centre`.
    nonisolated static func facingSquare(_ centre: SIMD3<Double>, half: Double) -> [SIMD3<Double>] {
        let axes: (right: SIMD3<Double>, up: SIMD3<Double>) = facing(centre)
        return rectangle(centre, u: axes.right, v: axes.up, half: SIMD2<Double>(half, half))
    }

    /// A polygon holding the circle of `radius` around `centre` in the plane of the unit axes `u`, `v`.
    nonisolated static func circle(_ centre: SIMD3<Double>, u: SIMD3<Double>, v: SIMD3<Double>,
                                   radius: Double) -> [SIMD3<Double>] {
        let n: Int = circleSamples
        let reach: Double = radius / cos(Double.pi / Double(n))
        var points: [SIMD3<Double>] = []
        for k in 0..<n {
            let a: Double = 2 * Double.pi * Double(k) / Double(n)
            points.append(centre + (u * cos(a) + v * sin(a)) * reach)
        }
        return points
    }

    /// A polygon holding the horizontal circle of `radius` around `centre`.
    nonisolated static func horizontalCircle(_ centre: SIMD3<Double>, radius: Double) -> [SIMD3<Double>] {
        circle(centre, u: SIMD3<Double>(1, 0, 0), v: SIMD3<Double>(0, 1, 0), radius: radius)
    }

    /// A polygon holding the eye-facing circle of `radius` around `centre`.
    nonisolated static func facingCircle(_ centre: SIMD3<Double>, radius: Double) -> [SIMD3<Double>] {
        let axes: (right: SIMD3<Double>, up: SIMD3<Double>) = facing(centre)
        return circle(centre, u: axes.right, v: axes.up, radius: radius)
    }

    /// The eight corners of the box `low` … `high`.
    nonisolated static func box(_ low: SIMD3<Double>, _ high: SIMD3<Double>) -> [SIMD3<Double>] {
        var corners: [SIMD3<Double>] = []
        for index in 0..<8 {
            corners.append(SIMD3<Double>(index & 1 == 0 ? low.x : high.x, index & 2 == 0 ? low.y : high.y,
                                         index & 4 == 0 ? low.z : high.z))
        }
        return corners
    }

    /// The convex hull of the pixels of `points` (world) through `camera` on a `width` × `height` target.
    static func hull(_ points: [SIMD3<Double>], _ camera: MushroomWeatherCamera, width: Int,
                     height: Int) -> [SIMD2<Double>] {
        var projected: [SIMD2<Double>] = []
        for point in points {
            if let p = project(point, camera, width: width, height: height) { projected.append(p) }
        }
        return convexHull(projected)
    }

    // MARK: Footprints

    /// The projected footprint of `element` of `snapshot` drawn at any of `tiers` (see the file header); `mistSides`
    /// are the mist squares' sides in drawing order.
    static func footprint(_ element: Element, _ snapshot: Snapshot, tiers: [MushroomWeatherTier],
                          mistSides: [Double], _ cam: MushroomWeatherCamera, width: Int,
                          height: Int) -> MushroomWeatherTestFootprint {
        var f = MushroomWeatherTestFootprint()
        let e: Double = MushroomWeatherShaders.quadExtent
        let s: Double = Geometry.scale(rows: snapshot.rows, columns: snapshot.columns)
        let c: SIMD3<Double> = element.centre
        let i: Int = element.item
        var groups: [[SIMD3<Double>]] = []
        switch element.kind {
        case .backdrop:
            break
        case .moon:
            var points: [SIMD3<Double>] = facingSquare(Geometry.moonCentre(), half: e * Geometry.moonRadius)
            for k in 0..<Geometry.tickCount {
                points += facingSquare(Geometry.tickCentre(k), half: e * Geometry.tickRadius)
            }
            groups.append(points)
        case .floor:
            let h: Double = e * Geometry.floorSquare * s / 2
            groups.append(horizontalRectangle(c, half: SIMD2<Double>(h, h)))
        case .blocked:
            let hx: Double = Swift.max(Geometry.logLength / 2, Geometry.stoneRadius) * s
            let hy: Double = Swift.max(Geometry.logRadius, Geometry.stoneRadius) * s
            let top: Double = Swift.max(2 * Geometry.logRadius, Geometry.stoneHeight) * s
            groups.append(box(SIMD3<Double>(c.x - hx, c.y - hy, 0), SIMD3<Double>(c.x + hx, c.y + hy, top)))
        case .fronds:
            var drawsFronds: Bool = false
            for tier in tiers where tier.fronds { drawsFronds = true }
            if drawsFronds {
                for stem in Geometry.frondStems(snapshot) {
                    let w: Double = Geometry.frondWidths[stem.generation] * s / 2
                    var points: [SIMD3<Double>] = []
                    for end in [stem.from, stem.to] {
                        points.append(end + SIMD3<Double>(w, 0, 0))
                        points.append(end - SIMD3<Double>(w, 0, 0))
                        points.append(end + SIMD3<Double>(0, 0, w))
                        points.append(end - SIMD3<Double>(0, 0, w))
                    }
                    groups.append(points)
                }
            }
        case .mist:
            let side: Double = element.index < mistSides.count ? mistSides[element.index] : Geometry.floorSquare * s
            let h: Double = e * side / 2
            groups.append(horizontalRectangle(c, half: SIMD2<Double>(h, h)))
        case .mark:
            let h: Double = e * Geometry.markSide * s / 2
            groups.append(horizontalRectangle(c, half: SIMD2<Double>(h, h)))
        case .site:
            let h: Double = e * Geometry.siteRadius * s
            groups.append(horizontalRectangle(c, half: SIMD2<Double>(h, h)))
        case .bandRing:
            let h: Double = e * Geometry.bandRadius * s
            groups.append(horizontalRectangle(c, half: SIMD2<Double>(h, h)))
        case .stalk:
            let radius: Double = Swift.max(Geometry.stalkFoot, Geometry.flatStalkWidth / 2) * s
            let base = SIMD3<Double>(c.x, c.y, 0)
            groups.append(horizontalCircle(base, radius: radius)
                + horizontalCircle(base + SIMD3<Double>(0, 0, Geometry.stalkHeight * s), radius: radius))
        case .cap:
            let radius: Double = Geometry.capRadius * s
            let base = SIMD3<Double>(c.x, c.y, 0)
            var points: [SIMD3<Double>] = horizontalCircle(base + SIMD3<Double>(0, 0, Geometry.wiltedRim * s),
                                                           radius: radius)
            points += horizontalCircle(base + SIMD3<Double>(0, 0, Geometry.capApex * s), radius: radius)
            points += facingCircle(c, radius: radius)
            groups.append(points)
        case .pod:
            let r: Double = Geometry.podRadius(i, snapshot)
            let base = SIMD3<Double>(c.x, c.y, 0)
            var points: [SIMD3<Double>] = horizontalCircle(base, radius: r)
            points += horizontalCircle(SIMD3<Double>(c.x, c.y, c.z + r), radius: r)
            points += facingCircle(c, radius: r)
            if snapshot.isGrown(i) {
                let h: Double = e * (r + (Geometry.podRingGap + Geometry.podRingWidth) * s)
                points += horizontalRectangle(c, half: SIMD2<Double>(h, h))
            }
            groups.append(points)
        case .droplets:
            let rise: Double = MushroomWeatherShaders.dropletRise(scale: s)
            let half: Double = e * Geometry.dropletHalf * s
            for tier in tiers {
                for point in Geometry.droplets(i, snapshot, tier: tier) {
                    groups.append(facingSquare(point.centre, half: half)
                        + facingSquare(point.centre + SIMD3<Double>(0, 0, rise), half: half))
                }
            }
        case .motes:
            let radius: Double = MushroomWeatherShaders.moteLoopRadius
            let half: Double = e * Geometry.moteHalf
            for tier in tiers {
                for point in Geometry.motes(tier: tier) {
                    let loop: SIMD3<Double> = point.centre - SIMD3<Double>(radius, 0, 0)
                    var points: [SIMD3<Double>] = []
                    for spot in horizontalCircle(loop, radius: radius) {
                        points += facingSquare(spot, half: half)
                    }
                    groups.append(points)
                }
            }
        case .vent:
            let h: Double = Geometry.ventSide * s / 2
            let z: Double = 0.15 * s
            groups.append(box(c - SIMD3<Double>(h, h, z), c + SIMD3<Double>(h, h, z)))
        case .gauge:
            groups.append(gaugeBox(i, snapshot))
        case .runBar:
            let y: Double = Geometry.gaugeY(i)
            let h: Double = e * Geometry.runHeight / 2
            groups.append(box(SIMD3<Double>(Geometry.runStart, y - h, 0), SIMD3<Double>(Geometry.runEnd, y + h, 0)))
        case .bar:
            let half = SIMD2<Double>(e * Geometry.barFill * Geometry.actionsSlot(snapshot) / 2,
                                     e * Geometry.barHeight / 2)
            groups.append(horizontalRectangle(c, half: half))
        }
        for group in groups {
            let polygon: [SIMD2<Double>] = hull(group, cam, width: width, height: height)
            if polygon.count >= 3 { f.hulls.append(polygon) }
        }
        return f
    }

    /// The corners of the box of colony `colony`'s gauge row: its track, its band bracket quad and its marker quad at
    /// their full quad extents.
    static func gaugeBox(_ colony: Int, _ snapshot: Snapshot) -> [SIMD3<Double>] {
        let e: Double = MushroomWeatherShaders.quadExtent
        let y: Double = Geometry.gaugeY(colony)
        var lowX: Double = Geometry.gaugeStart
        var highX: Double = Geometry.gaugeEnd
        var lowY: Double = y - Geometry.trackHeight / 2
        var highY: Double = y + Geometry.trackHeight / 2
        if colony < snapshot.colonies.count {
            let entry: MushroomWeatherSceneColony = snapshot.colonies[colony]
            let low: Double = Geometry.gaugeX(entry.low, top: snapshot.moldBound)
            let high: Double = Geometry.gaugeX(Swift.max(entry.high, entry.low), top: snapshot.moldBound)
            let halfHeight: Double = (Geometry.bracketOffset + Geometry.bracketHeight / 2) / 2
            let halfWidth: Double = Swift.max((high - low) / 2, Geometry.bracketMinimum)
            lowX = Swift.min(lowX, (low + high) / 2 - e * halfWidth)
            highX = Swift.max(highX, (low + high) / 2 + e * halfWidth)
            lowY = Swift.min(lowY, y + halfHeight - e * halfHeight)
            highY = Swift.max(highY, y + halfHeight + e * halfHeight)
            let marker: SIMD3<Double> = Geometry.markerCentre(colony, snapshot)
            let m: Double = e * Geometry.markerHalf
            lowX = Swift.min(lowX, marker.x - m)
            highX = Swift.max(highX, marker.x + m)
            lowY = Swift.min(lowY, marker.y - m)
            highY = Swift.max(highY, marker.y + m)
        }
        return box(SIMD3<Double>(lowX, lowY, 0), SIMD3<Double>(highX, highY, 0))
    }

    /// The glow's footprint at the richest of `tiers` (the most shells): each cap's and each pod's outermost shell.
    static func glowFootprint(_ snapshot: Snapshot, tiers: [MushroomWeatherTier], _ cam: MushroomWeatherCamera,
                              width: Int, height: Int) -> MushroomWeatherTestFootprint {
        var f = MushroomWeatherTestFootprint()
        var shells: Int = 0
        for tier in tiers { shells = Swift.max(shells, tier.glowShells) }
        guard shells > 0 else { return f }
        let s: Double = Geometry.scale(rows: snapshot.rows, columns: snapshot.columns)
        for colony in snapshot.colonies.indices {
            let radius: Double = (Geometry.capRadius + Geometry.capGlowGrowth * Double(shells)) * s
            let polygon = hull(facingCircle(Geometry.capCentre(colony, snapshot), radius: radius), cam, width: width,
                               height: height)
            if polygon.count >= 3 { f.hulls.append(polygon) }
        }
        for slot in snapshot.pods.indices {
            guard let centre = Geometry.podCentre(slot, snapshot) else { continue }
            let radius: Double = Geometry.podRadius(slot, snapshot) + Geometry.podGlowGrowth * s * Double(shells)
            let polygon = hull(facingCircle(centre, radius: radius), cam, width: width, height: height)
            if polygon.count >= 3 { f.hulls.append(polygon) }
        }
        return f
    }

    /// The tiers a layout covers: tier `tier` (clamped), or every tier when nil.
    static func tiers(_ tier: Int?) -> [MushroomWeatherTier] {
        guard let tier else { return MushroomWeatherTier.all }
        return [MushroomWeatherTier.of(tier)]
    }

    /// The painter's order of `snapshot` drawn at `tier` (every tier when nil) on a `width` × `height` target with
    /// every element's footprint and the glow's; empty for an empty target.
    static func layout(_ snapshot: Snapshot, tier: Int? = nil, width: Int = width,
                       height: Int = height) -> MushroomWeatherTestLayout {
        var result = MushroomWeatherTestLayout()
        guard width > 0, height > 0 else { return result }
        let cam: MushroomWeatherCamera = camera(width: width, height: height)
        let drawn: [MushroomWeatherTier] = tiers(tier)
        var mistSides: [Double] = []
        for square in Geometry.mistSquares(snapshot) { mistSides.append(square.side) }
        result.order = Geometry.paintOrder(snapshot)
        for element in result.order {
            result.footprints.append(footprint(element, snapshot, tiers: drawn, mistSides: mistSides, cam,
                                               width: width, height: height))
        }
        result.glow = glowFootprint(snapshot, tiers: drawn, cam, width: width, height: height)
        return result
    }

    /// The backdrop's colour coordinates on a `width` × `height` target; nil for an empty target.
    static func backdrop(width: Int = width, height: Int = height) -> MushroomWeatherTestBackdrop? {
        guard width > 0, height > 0 else { return nil }
        return MushroomWeatherTestBackdrop(camera: camera(width: width, height: height), width: width, height: height)
    }

    // MARK: Checks

    /// The backdrop patch check at view fraction (`fx`, `fy`): nil when the patch is not measured (outside the
    /// picture or near a footprint), else the miss in words or "" when it passed.
    static func patchResult(_ rgba: [UInt8], fx: Double, fy: Double, sky: MushroomWeatherTestBackdrop,
                            _ o: MushroomWeatherTestLayout, width: Int, height: Int) -> String? {
        let cx: Int = Swift.min(width - 1, Int(fx * Double(width)))
        let cy: Int = Swift.min(height - 1, Int(fy * Double(height)))
        guard cx - patchHalf >= 0, cy - patchHalf >= 0, cx + patchHalf < width, cy + patchHalf < height else {
            return nil
        }
        let p = SIMD2<Double>(Double(cx) + 0.5, Double(cy) + 0.5)
        guard o.minimumDistance(p) >= patchClearance else { return nil }
        var seen: [SIMD3<Double>] = []
        for y in (cy - patchHalf)...(cy + patchHalf) {
            for x in (cx - patchHalf)...(cx + patchHalf) {
                seen.append(colour(rgba, x: x, y: y, width: width))
            }
        }
        let got: SIMD3<Double> = median(seen)
        let gradient: SIMD3<Double> = sky.gradient(x: p.x, y: p.y)
        if channelDistance(got, gradient) <= backdropTolerance { return "" }
        let format: String = "backdrop patch (%ld, %ld) h %.3f: median (%.3f, %.3f, %.3f), gradient (%.3f, %.3f, "
            + "%.3f)"
        return String(format: format, cx, cy, sky.heightAt(x: p.x, y: p.y), got.x, got.y, got.z, gradient.x,
                      gradient.y, gradient.z)
    }

    /// The cap checks of clarification Q3: every cap whose centre is clear of every later element is brighter than
    /// moss by 0.2 within 3 px; returns how many were measured.
    static func checkCaps(_ rgba: [UInt8], _ snapshot: Snapshot, _ o: MushroomWeatherTestLayout, width: Int,
                          height: Int, misses: inout [String]) -> Int {
        let floor: Double = luminance(Palette.moss) + brightMargin
        var measured: Int = 0
        for k in snapshot.colonies.indices {
            guard let p = pixel(Geometry.capCentre(k, snapshot), width: width, height: height),
                  inside(p, width: width, height: height), let rank = o.rank(.cap, k),
                  o.isClear(p, after: rank, clearance: clearance) else { continue }
            measured += 1
            let bright: Bool = anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height,
                                        where: { luminance($0) >= floor })
            if !bright {
                let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
                misses.append(String(format: "cap %ld centre (%.1f, %.1f) is (%.3f, %.3f, %.3f)", k, p.x, p.y, c.x,
                                     c.y, c.z))
            }
        }
        return measured
    }

    /// The moon, actions bar and gauge track checks of clarification Q3 on `rgba` against `snapshot`, added to
    /// `report`.
    static func checkCues(_ rgba: [UInt8], _ snapshot: Snapshot, _ o: MushroomWeatherTestLayout,
                          _ sky: MushroomWeatherTestBackdrop, width: Int, height: Int,
                          into report: inout MushroomWeatherCheckReport) {
        if let p = pixel(Geometry.moonCentre(), width: width, height: height),
           inside(p, width: width, height: height), let rank = o.rank(.moon, 0),
           o.isClear(p, after: rank, clearance: clearance) {
            report.moonChecked = true
            let back: Double = luminance(sky.gradient(x: p.x, y: p.y))
            let off: Bool = anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height,
                                     where: { Swift.abs(luminance($0) - back) >= backdropMargin })
            if !off {
                report.misses.append(String(format: "moon centre (%.1f, %.1f) is backdrop-coloured", p.x, p.y))
            }
        }
        if Geometry.litActions(snapshot) > 0,
           let p = pixel(Geometry.actionsBar(0, snapshot), width: width, height: height),
           inside(p, width: width, height: height), let rank = o.rank(.bar, 0),
           o.isClear(p, after: rank, clearance: clearance) {
            report.barChecked = true
            if !anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height, where: isAmber) {
                let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
                report.misses.append(String(format: "actions bar 0 (%.1f, %.1f) is (%.3f, %.3f, %.3f)", p.x, p.y,
                                            c.x, c.y, c.z))
            }
        }
        if !snapshot.colonies.isEmpty,
           let p = pixel(Geometry.gaugeTrackCentre(0), width: width, height: height),
           inside(p, width: width, height: height), let rank = o.rank(.gauge, 0),
           o.isClear(p, after: rank, clearance: clearance) {
            report.trackChecked = true
            let back: Double = luminance(sky.gradient(x: p.x, y: p.y))
            let off: Bool = anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height,
                                     where: { Swift.abs(luminance($0) - back) >= backdropMargin })
            if !off {
                report.misses.append(String(format: "gauge track 0 centre (%.1f, %.1f) is backdrop-coloured", p.x,
                                            p.y))
            }
        }
    }

    /// The point checks of clarification Q3 (see the file header) on `rgba` against `snapshot` drawn at `tier`.
    static func pointReport(_ rgba: [UInt8], snapshot: Snapshot, tier: Int?, width: Int = width,
                            height: Int = height) -> MushroomWeatherCheckReport {
        var report = MushroomWeatherCheckReport()
        let o: MushroomWeatherTestLayout = layout(snapshot, tier: tier, width: width, height: height)
        guard let sky = backdrop(width: width, height: height) else {
            report.misses.append("an empty target")
            return report
        }
        var misses: [String] = []
        report.capsChecked = checkCaps(rgba, snapshot, o, width: width, height: height, misses: &misses)
        report.misses += misses
        checkCues(rgba, snapshot, o, sky, width: width, height: height, into: &report)
        for (index, fraction) in patchFractions.enumerated() {
            guard let result = patchResult(rgba, fx: fraction.x, fy: fraction.y, sky: sky, o, width: width,
                                           height: height) else { continue }
            report.patchesChecked += 1
            if index >= 2 { report.lowerPatchesChecked += 1 }
            if !result.isEmpty { report.misses.append(result) }
        }
        return report
    }

    /// Runs the checks of clarification Q3 on `rgba` against `snapshot` drawn at `tier` (nil: footprints of every
    /// tier), recording an issue per failure, and returns the report. At least one cap must be measured (the last one
    /// is never excluded by another cap), as must the first gauge track and (when lit) the first actions bar; a
    /// picture of at least 256 × 256 must measure both lower corner patches. The moon is measured when clear and
    /// reported.
    @discardableResult
    static func checkFrame(_ rgba: [UInt8], snapshot: Snapshot, tier: Int?, width: Int = width,
                           height: Int = height, _ what: String,
                           sourceLocation: SourceLocation = #_sourceLocation) -> MushroomWeatherCheckReport {
        #expect(rgba.count == width * height * 4, "\(what): picture size", sourceLocation: sourceLocation)
        guard rgba.count == width * height * 4 else { return MushroomWeatherCheckReport() }
        let report: MushroomWeatherCheckReport = pointReport(rgba, snapshot: snapshot, tier: tier, width: width,
                                                             height: height)
        if !snapshot.colonies.isEmpty {
            #expect(report.capsChecked >= 1, "\(what): no cap centre was clear", sourceLocation: sourceLocation)
            #expect(report.trackChecked, "\(what): the first gauge track was not clear",
                    sourceLocation: sourceLocation)
        }
        if Geometry.litActions(snapshot) > 0 {
            #expect(report.barChecked, "\(what): the first actions bar was not clear", sourceLocation: sourceLocation)
        }
        if width >= 256 && height >= 256 {
            #expect(report.lowerPatchesChecked == 2, "\(what): lower corner patches \(report.lowerPatchesChecked)",
                    sourceLocation: sourceLocation)
        }
        let shown: [String] = Array(report.misses.prefix(8))
        #expect(report.misses.isEmpty, "\(what): \(shown)", sourceLocation: sourceLocation)
        print("mushroom-weather \(what): caps \(report.capsChecked) of \(snapshot.colonies.count); moon "
              + "\(report.moonChecked); bar \(report.barChecked); track \(report.trackChecked); patches "
              + "\(report.patchesChecked) (lower \(report.lowerPatchesChecked))")
        return report
    }
}
#endif
