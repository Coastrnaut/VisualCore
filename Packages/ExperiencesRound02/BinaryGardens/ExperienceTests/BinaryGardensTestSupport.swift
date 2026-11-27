// BinaryGardensTestSupport — feature 503 (R02-G21-03) T-R02G2103-006 (FR-R02G2103-001 … 007, 010; clarifications
// Q1–Q5). Shared helpers of the Binary Gardens experience tests, following Mushroom Weather's harness (feature 493):
// opening the experience through the one app's session host (seed `s` prepares certified level `s % 100 + 1`; a
// session without a quality pin is pinned to level 0), making set-up actions (each level's certified plan, the
// generator's plan `BinaryGardensExperienceCore.generated(number:).plan`, so the predicted run is the winning one) and
// showing tick 24 (`clock.show [24]`), issuing kernel actions through the shell, drawing live frames, drawing an
// off-screen still (RGBA8, rows top-down, the orientation of the Core's CPU projection
// `BinaryGardensSceneGeometry.project`, origin top left, y down, scaled here to pixels), the engine digest, the frame
// checks of clarification Q3 at 1,152 × 768, and a short search for a failing run whose broken element is clear of
// every later element.
//
// Only the corona rays and the pollen motes move by time (their shaders read `u_time` times `u_motion`); they are
// never reference points, and their footprints below cover their whole reach (a ray at its full length, a mote's whole
// loop), so every check here holds at every frame time. Every still here is drawn at frame time 0 unless a test says
// otherwise.
//
// The CPU reference: the painter's order of `BinaryGardensSceneGeometry.paintOrder` (by kind, the worlds and stars
// back to front by eye distance; the scene draws with depth testing off, so a later element covers an earlier one)
// with every element's projected footprint, the convex hull of points that bound it, conservative where the drawn
// shape is smaller (every quad at its full extent ``BinaryGardensShaders/quadExtent`` times its shape half, which is
// also what the unlit fallback draws): the backdrop none (it lies under everything); the tilt dial its pip quads; a
// ring or an orbit each of its 48 segment quads; the trails each dot's quad; a world the box of its cube-sphere, its
// pip quads, its broken-ring quad and its motes' whole loops; a star its disc quad, its corona ray quads and its pip
// quads; a gauge row the box of its plate and its tick marker; an actions bar its quad. Trails, coronas and motes are
// those of the tier drawn (of every tier when no tier is named). The glow elements of the order have no footprint
// there: the additive glow (drawn last) only brightens and hides no cue, but its extent at the tier drawn (each star's
// and each world's outermost shell) keeps the backdrop patches away.
// A point is checked only when it projects into the picture at least 6 px from every element drawn after it:
//   - each world's centre: within 3 px a pixel brighter than the backdrop there by 0.15 in luminance (at least one is
//     checked in every frame);
//   - each star's centre: within 3 px a pixel brighter than the backdrop there by 0.4 (at least one is checked in
//     every frame);
//   - the first actions bar, when lit: within 3 px red above blue by 0.08 (the vermilion of an action left);
//   - the first gauge plate's left margin (−0.925, −1.2, 0): within 3 px a pixel 0.05 from the backdrop in luminance;
//   - the backdrop: 9 × 9 patches at 3 % from the picture's corners, 24 px from every footprint; the per-channel
//     median of each is within 0.06 of the gradient (space at the bottom of the backdrop quad, space top at its top)
//     at its height (`BinaryGardensSceneGeometry.backdropHeight(view:camera:)`; the sparse starfield cannot move a
//     median); both lower corners are measured on a picture of at least 256 × 256.
// "The backdrop there" is the gradient's colour at the pixel's height. Luminance is the Rec. 709 weighting of the
// stored 0 … 1 channel values. Positions come from the presenter's `lastSnapshot`. Short runs only (no sleep, no
// wall-clock assertion).
//
// The checked levels are catalog levels 1, 21, 41, 61 and 81 (seeds 0, 20, 40, 60, 80).
#if os(iOS)
import BinaryGardensCore
import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import BinaryGardensExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the point checks of one frame found.
struct BinaryGardensCheckReport {
    /// The worlds whose centre was measured.
    var worldsChecked: Int = 0
    /// The stars whose centre was measured.
    var starsChecked: Int = 0
    /// Whether the first actions bar was measured.
    var barChecked: Bool = false
    /// Whether the first gauge plate's left margin was measured.
    var marginChecked: Bool = false
    /// The backdrop patches measured.
    var patchesChecked: Int = 0
    /// The lower-corner backdrop patches measured.
    var lowerPatchesChecked: Int = 0
    /// Every failed check, in words.
    var misses: [String] = []
}

/// The projected footprint of one drawn element (pixels, y down): convex polygons.
struct BinaryGardensTestFootprint {
    /// Convex polygons (corners in the order `convexHull` gives them).
    var hulls: [[SIMD2<Double>]] = []

    /// The signed distance (pixels) of `p` from the footprint: negative inside, infinite for an empty footprint.
    func distance(_ p: SIMD2<Double>) -> Double {
        var best: Double = Double.infinity
        for hull in hulls { best = Swift.min(best, BinaryGardensTest.hullDistance(hull, p)) }
        return best
    }
}

/// The painter's order of one snapshot on one target with every element's footprint (same indices) and the glow's.
struct BinaryGardensTestLayout {
    /// The elements in painter's order.
    var order: [BinaryGardensElement] = []
    /// The footprint of each element of `order` (empty for the glow elements).
    var footprints: [BinaryGardensTestFootprint] = []
    /// The glow's footprint at the tier drawn (drawn last, additive).
    var glow = BinaryGardensTestFootprint()

    /// The place of the element of `kind` drawing `item` in the painter's order, or nil.
    func rank(_ kind: BinaryGardensElement.Kind, _ item: Int) -> Int? {
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
struct BinaryGardensTestBackdrop {
    /// The camera of the target.
    var camera: BinaryGardensCamera
    /// The target's width in pixels.
    var width: Int
    /// The target's height in pixels.
    var height: Int

    /// The backdrop's height h (0 at the quad's bottom, 1 at its top) at pixel (`x`, `y`).
    func heightAt(x: Double, y: Double) -> Double {
        let view = SIMD2<Double>(x / Double(width), y / Double(height))
        return BinaryGardensSceneGeometry.backdropHeight(view: view, camera: camera)
    }

    /// The gradient colour (space → space top) at pixel (`x`, `y`): the shader's CPU reference without the starfield.
    func gradient(x: Double, y: Double) -> SIMD3<Double> {
        BinaryGardensShaders.backdropColour(height: heightAt(x: x, y: y))
    }
}

/// A run that fails with a broken element clear of every later element: the level, the set-up before the run, the
/// failure's code and the checked points of the broken element at the check size (level-2).
struct BinaryGardensFailureCase {
    /// The catalog level number.
    var number: Int
    /// The actions made before the run.
    var setUp: [BinaryGardensAction]
    /// The failure's code (`frozen`, `scorched`, `unstable`, `wilted` or `bleached`).
    var code: String
    /// The checked points of the broken element (pixels at 1,152 × 768).
    var points: [SIMD2<Double>]
}

/// Building, opening, drawing and measuring Binary Gardens.
@MainActor
enum BinaryGardensTest {
    typealias Geometry = BinaryGardensSceneGeometry
    typealias Palette = BinaryGardensPalette
    typealias Snapshot = BinaryGardensSceneSnapshot
    typealias Shell = ExperienceShell<BinaryGardensPresenter>
    typealias Element = BinaryGardensElement
    typealias Kind = BinaryGardensElement.Kind

    /// The experience id `r02-g21.binary-gardens`.
    static var id: ExperienceID {
        BinaryGardensExperience.id ?? ExperienceID(rawValue: "r02-g21.unknown")!
    }

    /// The frame-check size of clarification Q3, aspect 1.5.
    nonisolated static let width: Int = 1_152
    nonisolated static let height: Int = 768
    /// The checked catalog levels and their seeds (seed = level − 1).
    nonisolated static let levels: [Int] = [1, 21, 41, 61, 81]
    nonisolated static let seeds: [UInt64] = [0, 20, 40, 60, 80]
    /// The feature's own seed (level 2_503 % 100 + 1 = 4).
    nonisolated static let featureSeed: UInt64 = 2_503
    /// The tick shown by the frame checks of clarification Q3.
    nonisolated static let checkTick: Int = 24
    /// The search radius (pixels) of the point checks.
    nonisolated static let pointRadius: Double = 3
    /// The search radius (pixels) at a broken mark.
    nonisolated static let markRadius: Double = 1.5
    /// The clearance (pixels) of every checked point from every element drawn after it.
    nonisolated static let clearance: Double = 6
    /// Each world's centre is brighter than the backdrop there by at least this.
    nonisolated static let worldMargin: Double = 0.15
    /// Each star's centre is brighter than the backdrop there by at least this.
    nonisolated static let starMargin: Double = 0.4
    /// The first actions bar's red above blue.
    nonisolated static let hueMargin: Double = 0.08
    /// The first gauge plate's left margin differs from the backdrop by at least this in luminance.
    nonisolated static let marginDifference: Double = 0.05
    /// The per-channel bound of a backdrop patch's median.
    nonisolated static let backdropTolerance: Double = 0.06
    /// The per-channel bound of a flat level-2 colour (the broken colour).
    nonisolated static let colourTolerance: Double = 0.1
    /// A backdrop patch's half side (pixels; 9 × 9) and its clearance from every footprint.
    nonisolated static let patchHalf: Int = 4
    nonisolated static let patchClearance: Double = 24
    /// The backdrop patch centres (fractions of the view, origin top left): the four corners at 3 %, the lower two
    /// last.
    nonisolated static let patchFractions: [(x: Double, y: Double)] = [(0.03, 0.03), (0.97, 0.03), (0.03, 0.97),
                                                                       (0.97, 0.97)]
    /// The samples of a circle bound (its polygon is scaled out so it holds the circle).
    nonisolated static let circleSamples: Int = 16
    /// Where a window bracket's end bars are sampled: at ±0.93 of its half length (the ends cover |u| ≥ 0.85).
    nonisolated static let bracketEndSample: Double = 0.93

    /// Opens Binary Gardens with `seed` in `session` through the factory, lays the view out at `size` points, draws one
    /// frame, makes the actions `setUp` through the shell and, with `atCheckTick`, shows tick 24 and draws again. A
    /// session without a quality pin is pinned to level 0. `configure` runs on the presenter before its first `setup`
    /// (the fallback seam).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, setUp: [BinaryGardensAction] = [],
                     reduceMotion: Bool = false, reduceFlashing: Bool = false,
                     size: CGSize = CGSize(width: 48, height: 32), atCheckTick: Bool = true,
                     configure: ((BinaryGardensPresenter) -> Void)? = nil) async throws -> Shell {
        let id: ExperienceID = self.id
        var made: Shell?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: seed) {
            let shell: Shell = BinaryGardensExperience.make(id: id, reduceMotion: reduceMotion,
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
        if atCheckTick {
            try showCheckTick(shell)
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
    static func core(_ shell: Shell) throws -> BinaryGardensExperienceCore {
        try #require(shell.engine.core)
    }

    /// Pins `session` to quality level `tier` and checks that the engine took it.
    static func pin(_ session: ExperienceSession, _ shell: Shell, tier: Int,
                    sourceLocation: SourceLocation = #_sourceLocation) {
        session.qualityPin = tier
        #expect(shell.engine.qualityTier == tier, "pinned tier \(tier)", sourceLocation: sourceLocation)
    }

    /// Shows tick 24 of `shell`'s play through the shell (`clock.show [24]`); returns the tick.
    @discardableResult
    static func showCheckTick(_ shell: Shell, sourceLocation: SourceLocation = #_sourceLocation) throws -> Int {
        let result: ActionResult = shell.handle(control: "clock.show", values: [Double(checkTick)])
        #expect(result == .accepted, "clock.show [\(checkTick)]: \(result.code)", sourceLocation: sourceLocation)
        return checkTick
    }

    // MARK: Actions

    /// The control and values that issue the kernel action `action` through the shell.
    nonisolated static func control(_ action: BinaryGardensAction) -> (control: String, values: [Double]) {
        switch action {
        case let .ring(star, index):
            return ("star.ring", [Double(star), Double(index)])
        case let .phase(star, step):
            return ("star.phase", [Double(star), Double(step)])
        case let .luminosity(star, index):
            return ("star.luminosity", [Double(star), Double(index)])
        case let .tilt(step):
            return ("orbit.tilt", [Double(step)])
        case .run:
            return ("light.run", [])
        }
    }

    /// The host action of `action` (step 0).
    nonisolated static func experienceAction(_ action: BinaryGardensAction) -> ExperienceAction {
        let issued = control(action)
        return ExperienceAction(control: issued.control, values: issued.values, step: 0)
    }

    /// The host action showing tick `tick` (step 0).
    nonisolated static func showAction(_ tick: Int) -> ExperienceAction {
        ExperienceAction(control: "clock.show", values: [Double(tick)], step: 0)
    }

    /// The certified plan of level `number` (the generator's plan): its actions (the run not included).
    nonisolated static func certifiedPlan(_ number: Int) throws -> [BinaryGardensAction] {
        try BinaryGardensExperienceCore.generated(number: number).plan.actions
    }

    /// Issues `actions` through the shell, each expected to be accepted; returns how many were.
    @discardableResult
    static func issue(_ shell: Shell, _ actions: [BinaryGardensAction],
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

    /// The opening core of level `number` with `actions` applied and, with `showCheckTick`, tick 24 shown (no host):
    /// the CPU reference of that state.
    static func coreAfter(_ number: Int, _ actions: [BinaryGardensAction],
                          showCheckTick: Bool = true) throws -> BinaryGardensExperienceCore {
        var core: BinaryGardensExperienceCore = try BinaryGardensExperienceCore.opening(number: number)
        for action in actions {
            let result: ActionResult = core.apply(experienceAction(action))
            #expect(result == .accepted, "level \(number) \(action): \(result.code)")
        }
        if showCheckTick {
            let result: ActionResult = core.apply(showAction(checkTick))
            #expect(result == .accepted, "level \(number) clock.show [\(checkTick)]: \(result.code)")
        }
        return core
    }

    /// The set-ups tried before the run in ``failureCase(candidates:)``: none (the opening: an immediate run, which
    /// never wins, since a level refuses a winning start), then every proper prefix of the certified plan (the search
    /// skips those the kernel refuses).
    static func setUps(_ number: Int) throws -> [[BinaryGardensAction]] {
        var result: [[BinaryGardensAction]] = [[]]
        let plan: [BinaryGardensAction] = try certifiedPlan(number)
        var length: Int = 1
        while length < plan.count {
            result.append(Array(plan.prefix(length)))
            length += 1
        }
        return result
    }

    /// The first run over `candidates` (level numbers) after one of ``setUps(_:)`` that fails and whose broken
    /// element has a point that projects into the level-2 picture clear of every later element; nil when none does.
    static func failureCase(candidates: [Int]) throws -> BinaryGardensFailureCase? {
        for number in candidates {
            for setUp in try setUps(number) {
                var core: BinaryGardensExperienceCore = try BinaryGardensExperienceCore.opening(number: number)
                var accepted: Bool = true
                let actions: [BinaryGardensAction] = setUp + [.run]
                for action in actions where accepted {
                    let result: ActionResult = core.apply(experienceAction(action))
                    if result != .accepted { accepted = false }
                }
                guard accepted, core.play.stage == .failed, let failure = core.play.failure else { continue }
                _ = core.apply(showAction(checkTick))
                let snapshot: Snapshot = core.snapshot(time: 0)
                let points: [SIMD2<Double>] = brokenPoints(snapshot)
                guard !points.isEmpty else { continue }
                return BinaryGardensFailureCase(number: number, setUp: setUp, code: failure.code, points: points)
            }
        }
        return nil
    }

    /// The pixels of `candidates` (world) that project into the picture clear of every element after place `rank`.
    static func clearPixels(_ candidates: [SIMD3<Double>], after rank: Int, _ o: BinaryGardensTestLayout,
                            width: Int, height: Int) -> [SIMD2<Double>] {
        var result: [SIMD2<Double>] = []
        for point in candidates {
            guard let p = pixel(point, width: width, height: height), inside(p, width: width, height: height),
                  o.isClear(p, after: rank, clearance: clearance) else { continue }
            result.append(p)
        }
        return result
    }

    /// The world points of the broken ring of a frozen or scorched world `world`: its centre line (radius
    /// 0.1 · (1 − ``BinaryGardensShaders/ringHalf``)) at eight angles in the eye-facing plane.
    static func brokenRingPoints(_ world: Int, _ snapshot: Snapshot) -> [SIMD3<Double>] {
        let centre: SIMD3<Double> = Geometry.worldCentre(world, snapshot)
        let axes: (right: SIMD3<Double>, up: SIMD3<Double>) = facing(centre)
        let radius: Double = Geometry.brokenRingRadius * (1 - BinaryGardensShaders.ringHalf)
        var points: [SIMD3<Double>] = []
        for k in 0..<8 {
            let a: Double = 2 * Double.pi * Double(k) / 8
            points.append(centre + (axes.right * cos(a) + axes.up * sin(a)) * radius)
        }
        return points
    }

    /// The centre of tick `tick`'s gauge cell of world `world` (its column centre, half its height above the
    /// baseline).
    static func cellPoint(_ world: Int, tick: Int, _ snapshot: Snapshot) -> SIMD3<Double> {
        let entry: BinaryGardensSceneWorld = snapshot.worlds[world]
        let index: Int = Snapshot.tickIndex(tick)
        let flux: Int = index < entry.flux.count ? entry.flux[index] : 0
        let h: Double = Geometry.cellHeight(flux: flux, lethalHigh: entry.lethalHigh)
        return SIMD3<Double>(Geometry.cellX(tick), Geometry.baseline(world) + h / 2, 0)
    }

    /// The world points of world `world`'s window bracket end bars (each piece's two ends, at mid height), or, when no
    /// tick is comfortable, of its required tick's middle.
    static func windowPoints(_ world: Int, _ snapshot: Snapshot) -> [SIMD3<Double>] {
        let entry: BinaryGardensSceneWorld = snapshot.worlds[world]
        let y: Double = Geometry.gaugeY(world)
        let pieces = Geometry.windowPieces(entry)
        guard !pieces.isEmpty else {
            let middle: Double = y - (Geometry.requiredLow + Geometry.requiredHigh) / 2
            return [SIMD3<Double>(Geometry.requiredX(entry), middle, 0)]
        }
        let middle: Double = y - (Geometry.bracketLow + Geometry.bracketHigh) / 2
        var points: [SIMD3<Double>] = []
        for piece in pieces {
            let left: Double = Geometry.cellsStart + Double(piece.first - 1) * Geometry.cellPitch
            let right: Double = Geometry.cellsStart + Double(piece.last) * Geometry.cellPitch
            let centre: Double = (left + right) / 2
            let half: Double = (right - left) / 2
            points.append(SIMD3<Double>(centre - bracketEndSample * half, middle, 0))
            points.append(SIMD3<Double>(centre + bracketEndSample * half, middle, 0))
        }
        return points
    }

    /// The world point of world `world`'s bloom marker centre.
    static func bloomMarkerPoint(_ world: Int, _ snapshot: Snapshot) -> SIMD3<Double> {
        let entry: BinaryGardensSceneWorld = snapshot.worlds[world]
        let marker: Int = Swift.min(entry.integral, 2 * entry.bloomHigh)
        return SIMD3<Double>(Geometry.bloomX(marker, bloomHigh: entry.bloomHigh), Geometry.gaugeY(world), 0)
    }

    /// Up to `limit` points of the broken element of the failed `snapshot` at the check size and level-2 (where the
    /// broken colour is drawn flat), each clear of every later element (clarification Q4): on a frozen or scorched
    /// failure the named world's gauge cell at the failure's column and points of its broken ring; on an unstable
    /// failure its window bracket's end bars, or its required tick alone when no tick is comfortable; on a wilted or
    /// bleached failure its bloom marker. Empty without a failure on a failed play or without a clear point.
    static func brokenPoints(_ snapshot: Snapshot, width: Int = width, height: Int = height,
                             limit: Int = 6) -> [SIMD2<Double>] {
        let o: BinaryGardensTestLayout = layout(snapshot, tier: 2, width: width, height: height)
        var result: [SIMD2<Double>] = []
        guard snapshot.stage == .failed else { return result }
        if let mark = Geometry.lethalMark(snapshot), snapshot.worlds.indices.contains(mark.world) {
            if let rank = o.rank(.gauge, mark.world) {
                result += clearPixels([cellPoint(mark.world, tick: mark.column, snapshot)], after: rank, o,
                                      width: width, height: height)
            }
            if let rank = o.rank(.world, mark.world) {
                result += clearPixels(brokenRingPoints(mark.world, snapshot), after: rank, o, width: width,
                                      height: height)
            }
        }
        if let world = Geometry.unstableWorld(snapshot), snapshot.worlds.indices.contains(world),
           let rank = o.rank(.gauge, world) {
            result += clearPixels(windowPoints(world, snapshot), after: rank, o, width: width, height: height)
        }
        if let world = Geometry.bloomWorld(snapshot), snapshot.worlds.indices.contains(world),
           let rank = o.rank(.gauge, world) {
            result += clearPixels([bloomMarkerPoint(world, snapshot)], after: rank, o, width: width, height: height)
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

    /// Whether `c` is the broken colour within 0.1 per channel (`BinaryGardensPalette.broken`; the lethal-high cells
    /// and star 1 are 0.13 or more away in green or blue).
    static func isBroken(_ c: SIMD3<Double>) -> Bool {
        channelDistance(c, Palette.broken) <= colourTolerance
    }

    /// Whether `c` has red above blue by at least 0.08 (the vermilion of a lit actions bar; the unlit bar is bluer).
    static func isVermilion(_ c: SIMD3<Double>) -> Bool {
        c.x - c.z >= hueMargin
    }

    /// The number of pixels brighter than the backdrop's top colour by 0.1 in luminance (anything drawn on it).
    static func drawnPixels(_ rgba: [UInt8]) -> Int {
        let floor: Double = luminance(Palette.spaceTop) + 0.1
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

    /// The number of pixels within `radius` of `p` where `a` and `b` (same size, `width` × `height`) differ.
    static func differingPixels(_ a: [UInt8], _ b: [UInt8], near p: SIMD2<Double>, radius: Double, width: Int = width,
                                height: Int = height) -> Int {
        guard a.count == b.count, a.count == width * height * 4 else { return 0 }
        var count: Int = 0
        for spot in pixelsNear(p, radius: radius, width: width, height: height) {
            let i: Int = (spot.y * width + spot.x) * 4
            if a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2] { count += 1 }
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
    static func camera(width: Int, height: Int) -> BinaryGardensCamera {
        Geometry.camera(aspect: Double(width) / Double(Swift.max(height, 1)))
    }

    /// The pixel of world point `point` through `camera` on a `width` × `height` target (nil without a projection).
    static func project(_ point: SIMD3<Double>, _ camera: BinaryGardensCamera, width: Int,
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

    /// The pixels of the geometry's reference points (`referencePoints`: the barycentre, every world centre, both star
    /// centres, the first gauge plate's left margin and the first actions bar; never a trail dot, a ray or a mote) in
    /// their order (nil without a projection); empty for an empty target.
    static func referencePixels(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> [SIMD2<Double>?] {
        var result: [SIMD2<Double>?] = []
        guard width > 0, height > 0 else { return result }
        let cam: BinaryGardensCamera = camera(width: width, height: height)
        for point in Geometry.referencePoints(snapshot) {
            result.append(project(point.centre, cam, width: width, height: height))
        }
        return result
    }

    /// The number of reference points `snapshot` has: the barycentre, its worlds, both stars, the first gauge plate's
    /// margin (with worlds) and the first actions bar (with a budget).
    nonisolated static func referenceCount(_ snapshot: BinaryGardensSceneSnapshot) -> Int {
        3 + snapshot.worlds.count + (snapshot.worlds.isEmpty ? 0 : 1) + (snapshot.budget > 0 ? 1 : 0)
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

    /// The dot product a · b.
    nonisolated static func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        a.x * b.x + a.y * b.y + a.z * b.z
    }

    /// `v` scaled to unit length (`fallback` for a zero vector).
    nonisolated static func unit(_ v: SIMD3<Double>, fallback: SIMD3<Double>) -> SIMD3<Double> {
        let length: Double = dot(v, v).squareRoot()
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

    /// The corners of a base-plane (z = 0 parallel) rectangle of half sizes `half` around `centre`.
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

    /// A polygon holding the base-plane circle of `radius` around `centre`.
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

    /// The four corners of the segment strip of `width` from `a` to `b` at its full quad extent (as the geometry
    /// builds it: across lying radially in the segment's plane about the origin); empty for a segment of length 0.
    nonisolated static func segmentCorners(_ a: SIMD3<Double>, _ b: SIMD3<Double>,
                                           width: Double) -> [SIMD3<Double>] {
        let d: SIMD3<Double> = b - a
        let size: Double = dot(d, d).squareRoot()
        guard size > 0 else { return [] }
        let along: SIMD3<Double> = d / size
        let middle: SIMD3<Double> = (a + b) / 2
        var radial: SIMD3<Double> = middle - along * dot(middle, along)
        if dot(radial, radial).squareRoot() < 1e-12 { radial = cross(SIMD3<Double>(0, 0, 1), along) }
        let across: SIMD3<Double> = unit(radial, fallback: SIMD3<Double>(0, 0, 1))
        let e: Double = BinaryGardensShaders.quadExtent
        return rectangle(middle, u: along, v: across, half: SIMD2<Double>(e * size / 2, e * width / 2))
    }

    /// The convex hull of the pixels of `points` (world) through `camera` on a `width` × `height` target.
    static func hull(_ points: [SIMD3<Double>], _ camera: BinaryGardensCamera, width: Int,
                     height: Int) -> [SIMD2<Double>] {
        var projected: [SIMD2<Double>] = []
        for point in points {
            if let p = project(point, camera, width: width, height: height) { projected.append(p) }
        }
        return convexHull(projected)
    }

    // MARK: Footprints

    /// The projected footprint of `element` of `snapshot` drawn at any of `tiers` (see the file header).
    static func footprint(_ element: Element, _ snapshot: Snapshot, tiers: [BinaryGardensTier],
                          _ cam: BinaryGardensCamera, width: Int, height: Int) -> BinaryGardensTestFootprint {
        var f = BinaryGardensTestFootprint()
        let e: Double = BinaryGardensShaders.quadExtent
        let c: SIMD3<Double> = element.centre
        let i: Int = element.item
        let k: Double = snapshot.fitScale
        var groups: [[SIMD3<Double>]] = []
        switch element.kind {
        case .backdrop, .glow:
            break
        case .tiltDial:
            for step in 0...Swift.max(snapshot.maxTilt, 0) {
                groups.append(facingSquare(Geometry.tiltPipCentre(step), half: e * Geometry.tiltPipRadius))
            }
        case .ring:
            guard snapshot.ringRadii.indices.contains(i) else { break }
            let radius: Int = snapshot.ringRadii[i]
            let tilt: Int = snapshot.arrangement.tilt
            let width: Double = Geometry.ringMaterial(i, snapshot).dashed ? Geometry.ringWidth : Geometry.starRingWidth
            for step in 0..<BinaryGardensSky.cycle {
                let corners = segmentCorners(Geometry.ringVertex(radius: radius, step: step, tilt: tilt, scale: k),
                                             Geometry.ringVertex(radius: radius, step: step + 1, tilt: tilt,
                                                                 scale: k), width: width)
                if !corners.isEmpty { groups.append(corners) }
            }
        case .orbit:
            guard snapshot.worlds.indices.contains(i) else { break }
            let radius: Int = snapshot.worlds[i].radius
            for step in 0..<BinaryGardensSky.cycle {
                let corners = segmentCorners(Geometry.orbitVertex(radius: radius, step: step, scale: k),
                                             Geometry.orbitVertex(radius: radius, step: step + 1, scale: k),
                                             width: Geometry.orbitWidth)
                if !corners.isEmpty { groups.append(corners) }
            }
        case .trail:
            for tier in tiers {
                for dot in Geometry.trailDots(snapshot, tier: tier) {
                    groups.append(facingSquare(dot.centre, half: e * Geometry.trailRadius))
                }
            }
        case .world:
            guard snapshot.worlds.indices.contains(i) else { break }
            let centre: SIMD3<Double> = Geometry.worldCentre(i, snapshot)
            let r: Double = Geometry.worldRadius
            groups.append(box(centre - SIMD3<Double>(r, r, r), centre + SIMD3<Double>(r, r, r)))
            for pip in Geometry.worldPips(i, snapshot) {
                groups.append(facingSquare(pip, half: e * Geometry.pipRadius))
            }
            if Geometry.lethalMark(snapshot)?.world == i {
                groups.append(facingSquare(centre, half: e * Geometry.brokenRingRadius))
            }
            var loops: Bool = false
            for tier in tiers where !Geometry.motes(i, snapshot, tier: tier, won: snapshot.isWon).isEmpty {
                loops = true
            }
            if loops {
                let reach: Double = BinaryGardensShaders.moteLoopRadius + e * Geometry.moteRadius
                groups.append(facingCircle(centre, radius: reach) + horizontalCircle(centre, radius: reach))
            }
        case .star:
            let centre: SIMD3<Double> = Geometry.starCentre(i, snapshot)
            let lums: [Int] = snapshot.arrangement.luminosities
            let r: Double = Geometry.starRadius(luminosityIndex: lums.indices.contains(i) ? lums[i] : 0)
            groups.append(facingSquare(centre, half: e * r))
            for tier in tiers {
                for ray in Geometry.coronaRays(i, snapshot, tier: tier) {
                    groups.append(rectangle(ray.centre, u: ray.across, v: ray.along,
                                            half: SIMD2<Double>(e * ray.half.x, e * ray.half.y)))
                }
            }
            for pip in Geometry.luminosityPips(i, snapshot) {
                groups.append(facingSquare(pip.centre, half: e * Geometry.pipRadius))
            }
        case .gauge:
            groups.append(gaugeBox(i, snapshot))
        case .actions:
            let half = SIMD2<Double>(e * Geometry.barFill * Geometry.actionsSlot(snapshot) / 2,
                                     e * Geometry.actionsHeight / 2)
            groups.append(horizontalRectangle(c, half: half))
        }
        for group in groups {
            let polygon: [SIMD2<Double>] = hull(group, cam, width: width, height: height)
            if polygon.count >= 3 { f.hulls.append(polygon) }
        }
        return f
    }

    /// The corners of the box of world `world`'s gauge row: its plate (x −0.95 … 1.22, its quad at its full extent
    /// across) and its tick marker quad, which bound every cell, guide, bracket, tick and meter of the row.
    static func gaugeBox(_ world: Int, _ snapshot: Snapshot) -> [SIMD3<Double>] {
        let e: Double = BinaryGardensShaders.quadExtent
        let y: Double = Geometry.gaugeY(world)
        let lowX: Double = Geometry.plateLeft
        let highX: Double = Geometry.plateRight
        let lowY: Double = y - e * Geometry.plateHalf
        let markerTop: Double = y + Geometry.markerRise + e * Geometry.markerRadius
        let highY: Double = Swift.max(y + e * Geometry.plateHalf, markerTop)
        return box(SIMD3<Double>(lowX, lowY, 0), SIMD3<Double>(highX, highY, 0))
    }

    /// The glow's footprint at the richest of `tiers` (the most shells): each star's and each world's outermost
    /// shell.
    static func glowFootprint(_ snapshot: Snapshot, tiers: [BinaryGardensTier], _ cam: BinaryGardensCamera,
                              width: Int, height: Int) -> BinaryGardensTestFootprint {
        var f = BinaryGardensTestFootprint()
        var shells: Int = 0
        for tier in tiers { shells = Swift.max(shells, tier.glowShells) }
        guard shells > 0 else { return f }
        let lums: [Int] = snapshot.arrangement.luminosities
        for star in 0..<2 {
            let r: Double = Geometry.starRadius(luminosityIndex: lums.indices.contains(star) ? lums[star] : 0)
            let radius: Double = r + Geometry.starGlowGrowth * Double(shells)
            let polygon = hull(facingCircle(Geometry.starCentre(star, snapshot), radius: radius), cam, width: width,
                               height: height)
            if polygon.count >= 3 { f.hulls.append(polygon) }
        }
        for world in snapshot.worlds.indices {
            let radius: Double = Geometry.worldRadius + Geometry.worldGlowGrowth * Double(shells)
            let polygon = hull(facingCircle(Geometry.worldCentre(world, snapshot), radius: radius), cam, width: width,
                               height: height)
            if polygon.count >= 3 { f.hulls.append(polygon) }
        }
        return f
    }

    /// The tiers a layout covers: tier `tier` (clamped), or every tier when nil.
    static func tiers(_ tier: Int?) -> [BinaryGardensTier] {
        guard let tier else { return BinaryGardensTier.all }
        return [BinaryGardensTier.of(tier)]
    }

    /// The painter's order of `snapshot` drawn at `tier` (every tier when nil) on a `width` × `height` target with
    /// every element's footprint and the glow's; empty for an empty target.
    static func layout(_ snapshot: Snapshot, tier: Int? = nil, width: Int = width,
                       height: Int = height) -> BinaryGardensTestLayout {
        var result = BinaryGardensTestLayout()
        guard width > 0, height > 0 else { return result }
        let cam: BinaryGardensCamera = camera(width: width, height: height)
        let drawn: [BinaryGardensTier] = tiers(tier)
        result.order = Geometry.paintOrder(snapshot)
        for element in result.order {
            result.footprints.append(footprint(element, snapshot, tiers: drawn, cam, width: width, height: height))
        }
        result.glow = glowFootprint(snapshot, tiers: drawn, cam, width: width, height: height)
        return result
    }

    /// The backdrop's colour coordinates on a `width` × `height` target; nil for an empty target.
    static func backdrop(width: Int = width, height: Int = height) -> BinaryGardensTestBackdrop? {
        guard width > 0, height > 0 else { return nil }
        return BinaryGardensTestBackdrop(camera: camera(width: width, height: height), width: width, height: height)
    }

    // MARK: Checks

    /// The backdrop patch check at view fraction (`fx`, `fy`): nil when the patch is not measured (outside the
    /// picture or near a footprint), else the miss in words or "" when it passed.
    static func patchResult(_ rgba: [UInt8], fx: Double, fy: Double, sky: BinaryGardensTestBackdrop,
                            _ o: BinaryGardensTestLayout, width: Int, height: Int) -> String? {
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

    /// The body checks of clarification Q3 for elements of `kind` (worlds or stars) at `centres`: every body whose
    /// centre is clear of every later element is brighter than the backdrop there by `margin` within 3 px; returns
    /// how many were measured.
    static func checkBodies(_ rgba: [UInt8], kind: Kind, centres: [SIMD3<Double>], margin: Double,
                            _ o: BinaryGardensTestLayout, _ sky: BinaryGardensTestBackdrop, width: Int, height: Int,
                            misses: inout [String]) -> Int {
        var measured: Int = 0
        for (k, point) in centres.enumerated() {
            guard let p = pixel(point, width: width, height: height),
                  inside(p, width: width, height: height), let rank = o.rank(kind, k),
                  o.isClear(p, after: rank, clearance: clearance) else { continue }
            measured += 1
            let floor: Double = luminance(sky.gradient(x: p.x, y: p.y)) + margin
            let bright: Bool = anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height,
                                        where: { luminance($0) >= floor })
            if !bright {
                let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
                let name: String = kind == .world ? "world" : "star"
                misses.append(name + String(format: " %ld centre (%.1f, %.1f) is (%.3f, %.3f, %.3f), floor %.3f", k,
                                            p.x, p.y, c.x, c.y, c.z, floor))
            }
        }
        return measured
    }

    /// The actions bar and gauge margin checks of clarification Q3 on `rgba` against `snapshot`, added to `report`.
    static func checkCues(_ rgba: [UInt8], _ snapshot: Snapshot, _ o: BinaryGardensTestLayout,
                          _ sky: BinaryGardensTestBackdrop, width: Int, height: Int,
                          into report: inout BinaryGardensCheckReport) {
        if Geometry.litActions(snapshot) > 0,
           let p = pixel(Geometry.actionsBar(0, snapshot), width: width, height: height),
           inside(p, width: width, height: height), let rank = o.rank(.actions, 0),
           o.isClear(p, after: rank, clearance: clearance) {
            report.barChecked = true
            if !anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height, where: isVermilion) {
                let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
                report.misses.append(String(format: "actions bar 0 (%.1f, %.1f) is (%.3f, %.3f, %.3f)", p.x, p.y,
                                            c.x, c.y, c.z))
            }
        }
        if !snapshot.worlds.isEmpty,
           let p = pixel(Geometry.gaugeMargin(0), width: width, height: height),
           inside(p, width: width, height: height), let rank = o.rank(.gauge, 0),
           o.isClear(p, after: rank, clearance: clearance) {
            report.marginChecked = true
            let back: Double = luminance(sky.gradient(x: p.x, y: p.y))
            let off: Bool = anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height,
                                     where: { Swift.abs(luminance($0) - back) >= marginDifference })
            if !off {
                report.misses.append(String(format: "gauge plate 0 margin (%.1f, %.1f) is backdrop-coloured", p.x,
                                            p.y))
            }
        }
    }

    /// The point checks of clarification Q3 (see the file header) on `rgba` against `snapshot` drawn at `tier`.
    static func pointReport(_ rgba: [UInt8], snapshot: Snapshot, tier: Int?, width: Int = width,
                            height: Int = height) -> BinaryGardensCheckReport {
        var report = BinaryGardensCheckReport()
        let o: BinaryGardensTestLayout = layout(snapshot, tier: tier, width: width, height: height)
        guard let sky = backdrop(width: width, height: height) else {
            report.misses.append("an empty target")
            return report
        }
        var misses: [String] = []
        var worlds: [SIMD3<Double>] = []
        for world in snapshot.worlds.indices { worlds.append(Geometry.worldCentre(world, snapshot)) }
        report.worldsChecked = checkBodies(rgba, kind: .world, centres: worlds, margin: worldMargin, o, sky,
                                           width: width, height: height, misses: &misses)
        let stars: [SIMD3<Double>] = [Geometry.starCentre(0, snapshot), Geometry.starCentre(1, snapshot)]
        report.starsChecked = checkBodies(rgba, kind: .star, centres: stars, margin: starMargin, o, sky, width: width,
                                          height: height, misses: &misses)
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
    /// tier), recording an issue per failure, and returns the report. At least one world and one star must be
    /// measured, as must the first gauge plate's margin and (when lit) the first actions bar; a picture of at least
    /// 256 × 256 must measure both lower corner patches.
    @discardableResult
    static func checkFrame(_ rgba: [UInt8], snapshot: Snapshot, tier: Int?, width: Int = width,
                           height: Int = height, _ what: String,
                           sourceLocation: SourceLocation = #_sourceLocation) -> BinaryGardensCheckReport {
        #expect(rgba.count == width * height * 4, "\(what): picture size", sourceLocation: sourceLocation)
        guard rgba.count == width * height * 4 else { return BinaryGardensCheckReport() }
        let report: BinaryGardensCheckReport = pointReport(rgba, snapshot: snapshot, tier: tier, width: width,
                                                           height: height)
        if !snapshot.worlds.isEmpty {
            #expect(report.worldsChecked >= 1, "\(what): no world centre was clear", sourceLocation: sourceLocation)
            #expect(report.marginChecked, "\(what): the first gauge plate's margin was not clear",
                    sourceLocation: sourceLocation)
        }
        #expect(report.starsChecked >= 1, "\(what): no star centre was clear", sourceLocation: sourceLocation)
        if Geometry.litActions(snapshot) > 0 {
            #expect(report.barChecked, "\(what): the first actions bar was not clear", sourceLocation: sourceLocation)
        }
        if width >= 256 && height >= 256 {
            #expect(report.lowerPatchesChecked == 2, "\(what): lower corner patches \(report.lowerPatchesChecked)",
                    sourceLocation: sourceLocation)
        }
        let shown: [String] = Array(report.misses.prefix(8))
        #expect(report.misses.isEmpty, "\(what): \(shown)", sourceLocation: sourceLocation)
        print("binary-gardens \(what): worlds \(report.worldsChecked) of \(snapshot.worlds.count); stars "
              + "\(report.starsChecked) of 2; bar \(report.barChecked); margin \(report.marginChecked); patches "
              + "\(report.patchesChecked) (lower \(report.lowerPatchesChecked))")
        return report
    }
}
#endif
