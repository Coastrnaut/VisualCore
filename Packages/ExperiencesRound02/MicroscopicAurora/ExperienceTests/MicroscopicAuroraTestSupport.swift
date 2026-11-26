// MicroscopicAuroraTestSupport — feature 483 (R02-G19-03) T-R02G1903-006 (FR-R02G1903-001 … 007; clarifications
// Q1–Q4). Shared helpers of the Microscopic Aurora experience tests, following Apsides Workshop's harness (feature
// 473): opening the experience through the one app's session host (seed `s` prepares certified level `s % 100 + 1`;
// a session without a quality pin is pinned to level 0), making set-up placements (each level's certified plan, so
// the swim is the winning one and every swimmer moves) and showing the tick half the ticks swum
// (`clock.show [ticksSwum / 2]`), issuing kernel actions through the shell, drawing live frames, drawing an
// off-screen still (RGBA8, rows top-down, the orientation of the Core's CPU projection
// `MicroscopicAuroraSceneGeometry.project`, origin top left, y down, scaled here to pixels), the engine digest, the
// frame checks of clarification Q3 at 1,152 × 768, and a short search for a failing play whose broken element is
// clear of every later element.
//
// Nothing moves by time in this game: the shown tick is the adapter's presentation state and the snapshot's time is
// read by no shader, so every still is the same at every frame time. Every still here is drawn at frame time 0
// unless a test says otherwise.
//
// The CPU reference: the painter's order of `MicroscopicAuroraSceneGeometry.paintOrder` (by kind, then index) with
// every element's projected footprint, conservative where the drawn shape is thinner (world sizes of the geometry's
// constants): the backdrop none (it lies under everything); the field the dish disc; the fronds the disc out to their
// reach; the rim the disc out to its outer edge; the exit mark its strip; a stencil outline and the named cell's
// outline their four strips; a lit cell its square out to 0.45 cell; a site its disc; a well the disc out to its
// arrowhead; a ribbon the strips through its level-0 points (the longest ribbon, holding every tier's); a swimmer the
// disc of half its length; a gauge row its box (track, requirement tick and reading mark); an actions bar its
// rectangle. The additive glow (drawn last) only brightens and hides no cue, but its level-0 extent (the swimmer
// bands and the ribbon bands) keeps the backdrop patches away.
// A point is checked only when it projects into the picture at least 6 px from every element drawn after it:
//   - each swimmer's centre: within 3 px a pixel brighter than the dish field by 0.25 in luminance (swimmers are
//     drawn in index order, so the last one is never excluded by another; at least one is checked in every frame);
//   - the rim's rightmost point: within 3 px a pixel 0.1 from the backdrop at its height in luminance;
//   - the first actions bar, when lit: within 3 px blue above green by 0.08 (heliotrope);
//   - the coverage track's centre: within 3 px a pixel 0.1 from the backdrop in luminance;
//   - the backdrop: 9 × 9 patches at 3 % from the picture's corners, 24 px from every footprint; the per-channel
//     median of each is within 0.06 of the gradient (abyss at the bottom of the backdrop quad, abyss top at its top)
//     at its height (`MicroscopicAuroraSceneGeometry.backdropHeight(view:camera:)`).
// Luminance is the Rec. 709 weighting of the stored 0 … 1 channel values. Positions come from the presenter's
// `lastSnapshot`. Short runs only (no sleep, no wall-clock assertion).
//
// The checked levels are catalog levels 1, 21, 41, 61 and 81 (seeds 0, 20, 40, 60, 80).
#if os(iOS)
import CoreGraphics
import Foundation
import MicroscopicAuroraCore
import Testing
import UIKit
@testable import MicroscopicAuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the point checks of one frame found.
struct MicroscopicAuroraCheckReport {
    /// The swimmers whose centre was measured.
    var swimmersChecked: Int = 0
    /// Whether the rim's rightmost point was measured.
    var rimChecked: Bool = false
    /// Whether the first actions bar was measured.
    var barChecked: Bool = false
    /// Whether the coverage track's centre was measured.
    var trackChecked: Bool = false
    /// The backdrop patches measured.
    var patchesChecked: Int = 0
    /// Every failed check, in words.
    var misses: [String] = []
}

/// A projected strip: the segment `a` … `b` grown by `half` pixels (a disc when `a == b`).
struct MicroscopicAuroraTestCapsule {
    /// One end (pixels).
    var a: SIMD2<Double>
    /// The other end (pixels).
    var b: SIMD2<Double>
    /// The half width (pixels).
    var half: Double
}

/// The projected footprint of one drawn element (pixels, y down).
struct MicroscopicAuroraTestFootprint {
    /// Convex polygons (corners in the order `convexHull` gives them).
    var hulls: [[SIMD2<Double>]] = []
    /// Strips and discs.
    var capsules: [MicroscopicAuroraTestCapsule] = []

    /// The signed distance (pixels) of `p` from the footprint: negative inside, infinite for an empty footprint.
    func distance(_ p: SIMD2<Double>) -> Double {
        var best: Double = Double.infinity
        for hull in hulls { best = Swift.min(best, MicroscopicAuroraTest.hullDistance(hull, p)) }
        for capsule in capsules {
            best = Swift.min(best, MicroscopicAuroraTest.segmentDistance(p, capsule.a, capsule.b) - capsule.half)
        }
        return best
    }
}

/// The painter's order of one snapshot on one target with every element's footprint (same indices) and the glow's.
struct MicroscopicAuroraTestLayout {
    /// The elements in painter's order.
    var order: [MicroscopicAuroraElement] = []
    /// The footprint of each element of `order`.
    var footprints: [MicroscopicAuroraTestFootprint] = []
    /// The level-0 glow's footprint (drawn last, additive).
    var glow = MicroscopicAuroraTestFootprint()

    /// The place of the element drawing `part` for `item` in the painter's order, or nil.
    func rank(_ part: MicroscopicAuroraElement.Part, _ item: Int) -> Int? {
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
struct MicroscopicAuroraTestBackdrop {
    /// The camera of the target.
    var camera: MicroscopicAuroraCamera
    /// The target's width in pixels.
    var width: Int
    /// The target's height in pixels.
    var height: Int

    /// The backdrop's height h (0 at the quad's bottom, 1 at its top) at pixel (`x`, `y`).
    func heightAt(x: Double, y: Double) -> Double {
        let view = SIMD2<Double>(x / Double(width), y / Double(height))
        return MicroscopicAuroraSceneGeometry.backdropHeight(view: view, camera: camera)
    }

    /// The gradient colour (abyss → abyss top) at pixel (`x`, `y`): the shader's CPU reference.
    func gradient(x: Double, y: Double) -> SIMD3<Double> {
        MicroscopicAuroraShaders.backdropColour(height: heightAt(x: x, y: y))
    }
}

/// A play that fails with a broken element clear of every later element: the level, the set-up before the play,
/// the failure's code and the checked points of the broken element at the check size.
struct MicroscopicAuroraFailureCase {
    /// The catalog level number.
    var number: Int
    /// The placements made before the play.
    var setUp: [MicroscopicAuroraAction]
    /// The failure's code (`exit`, `coherence`, `coverage` or `connectedness`).
    var code: String
    /// The checked points of the broken element (pixels at 1,152 × 768).
    var points: [SIMD2<Double>]
}

/// Building, opening, drawing and measuring Microscopic Aurora.
@MainActor
enum MicroscopicAuroraTest {
    typealias Geometry = MicroscopicAuroraSceneGeometry
    typealias Palette = MicroscopicAuroraPalette
    typealias Snapshot = MicroscopicAuroraSceneSnapshot
    typealias Shell = ExperienceShell<MicroscopicAuroraPresenter>
    typealias Element = MicroscopicAuroraElement
    typealias Part = MicroscopicAuroraElement.Part

    /// The experience id `r02-g19.microscopic-aurora`.
    static var id: ExperienceID {
        MicroscopicAuroraExperience.id ?? ExperienceID(rawValue: "r02-g19.unknown")!
    }

    /// The frame-check size of clarification Q3, aspect 1.5.
    static let width: Int = 1_152
    static let height: Int = 768
    /// The checked catalog levels and their seeds (seed = level − 1).
    static let levels: [Int] = [1, 21, 41, 61, 81]
    static let seeds: [UInt64] = [0, 20, 40, 60, 80]
    /// The search radius (pixels) of the point checks.
    static let pointRadius: Double = 3
    /// The search radius (pixels) at a broken or lit outline (strips about one pixel wide).
    static let markRadius: Double = 1.5
    /// The clearance (pixels) of every checked point from every element drawn after it.
    static let clearance: Double = 6
    /// Each swimmer's centre is brighter than the dish field by at least this.
    static let brightMargin: Double = 0.25
    /// The first actions bar's blue above green, and the broken colour's red above green and above blue.
    static let hueMargin: Double = 0.08
    /// The rim point's and the coverage track's luminance difference from the backdrop.
    static let backdropMargin: Double = 0.1
    /// The per-channel bound of a backdrop patch's median.
    static let backdropTolerance: Double = 0.06
    /// A backdrop patch's half side (pixels; 9 × 9) and its clearance from every footprint.
    static let patchHalf: Int = 4
    static let patchClearance: Double = 24
    /// The backdrop patch centres (fractions of the view, origin top left): the four corners at 3 %.
    static let patchFractions: [(x: Double, y: Double)] = [(0.03, 0.03), (0.97, 0.03), (0.03, 0.97), (0.97, 0.97)]
    /// A gauge row's half height in world units (requirement tick reach and width, the mark quad), with a margin.
    static let gaugeRowHalf: Double = 0.03
    /// A lit cell's conservative half side as a share of the cell (the square spans ±0.4 cell, feathered).
    static let litCellHalfShare: Double = 0.45

    /// Opens Microscopic Aurora with `seed` in `session` through the factory, lays the view out at `size` points,
    /// draws one frame, makes the placements `setUp` through the shell and, with `atHalf`, shows the tick half the
    /// ticks swum and draws again. A session without a quality pin is pinned to level 0. `configure` runs on the
    /// presenter before its first `setup` (the fallback seam).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, setUp: [MicroscopicAuroraAction] = [],
                     reduceMotion: Bool = false, reduceFlashing: Bool = false,
                     size: CGSize = CGSize(width: 48, height: 32), atHalf: Bool = true,
                     configure: ((MicroscopicAuroraPresenter) -> Void)? = nil) async throws -> Shell {
        let id: ExperienceID = self.id
        var made: Shell?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: seed) {
            let shell: Shell = MicroscopicAuroraExperience.make(id: id, reduceMotion: reduceMotion,
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
    static func core(_ shell: Shell) throws -> MicroscopicAuroraExperienceCore {
        try #require(shell.engine.core)
    }

    /// Pins `session` to quality level `tier` and checks that the engine took it.
    static func pin(_ session: ExperienceSession, _ shell: Shell, tier: Int,
                    sourceLocation: SourceLocation = #_sourceLocation) {
        session.qualityPin = tier
        #expect(shell.engine.qualityTier == tier, "pinned tier \(tier)", sourceLocation: sourceLocation)
    }

    /// The shown tick of clarification Q3: half the ticks swum.
    nonisolated static func halfTick(_ ticksSwum: Int) -> Int {
        ticksSwum / 2
    }

    /// Shows the tick half the ticks swum of `shell`'s play through the shell (`clock.show [ticks / 2]`); returns
    /// the tick.
    @discardableResult
    static func showHalf(_ shell: Shell, sourceLocation: SourceLocation = #_sourceLocation) throws -> Int {
        let tick: Int = halfTick(try core(shell).play.report.ticks)
        let result: ActionResult = shell.handle(control: "clock.show", values: [Double(tick)])
        #expect(result == .accepted, "clock.show [\(tick)]: \(result.code)", sourceLocation: sourceLocation)
        return tick
    }

    // MARK: Actions

    /// The control and values that issue the kernel action `action` through the shell.
    nonisolated static func control(_ action: MicroscopicAuroraAction) -> (control: String, values: [Double]) {
        switch action {
        case let .place(slot, well):
            let sense: Double = well.sense == .counterclockwise ? 1 : 0
            return ("well.place", [Double(slot), Double(well.cell.row), Double(well.cell.column),
                                   Double(well.strength), sense])
        case let .remove(slot):
            return ("well.remove", [Double(slot)])
        case .play:
            return ("swim.play", [])
        }
    }

    /// The host action of `action` (step 0).
    nonisolated static func experienceAction(_ action: MicroscopicAuroraAction) -> ExperienceAction {
        let issued = control(action)
        return ExperienceAction(control: issued.control, values: issued.values, step: 0)
    }

    /// The host action showing tick `tick` (step 0).
    nonisolated static func showAction(_ tick: Int) -> ExperienceAction {
        ExperienceAction(control: "clock.show", values: [Double(tick)], step: 0)
    }

    /// The certified plan of level `number`: its placements (the play not included).
    nonisolated static func certifiedPlan(_ number: Int) throws -> [MicroscopicAuroraAction] {
        try MicroscopicAuroraExperienceCore.generated(number: number).plan.actions
    }

    /// Issues `actions` through the shell, each expected to be accepted; returns how many were.
    @discardableResult
    static func issue(_ shell: Shell, _ actions: [MicroscopicAuroraAction],
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

    /// The opening core of level `number` with `actions` applied and, with `showHalf`, the tick half the ticks swum
    /// shown (no host): the CPU reference of that state.
    static func coreAfter(_ number: Int, _ actions: [MicroscopicAuroraAction],
                          showHalf: Bool = true) throws -> MicroscopicAuroraExperienceCore {
        var core: MicroscopicAuroraExperienceCore = try MicroscopicAuroraExperienceCore.opening(number: number)
        for action in actions {
            let result: ActionResult = core.apply(experienceAction(action))
            #expect(result == .accepted, "level \(number) \(action): \(result.code)")
        }
        if showHalf {
            let tick: Int = halfTick(core.play.report.ticks)
            let result: ActionResult = core.apply(showAction(tick))
            #expect(result == .accepted, "level \(number) clock.show [\(tick)]: \(result.code)")
        }
        return core
    }

    /// The set-ups tried before the play in ``failureCase(candidates:)``: none (the opening, no wells), then every
    /// proper prefix of the certified plan, then the plan with its last well's sense turned and with its strength
    /// changed by one (the search skips those the kernel refuses).
    static func setUps(_ number: Int) throws -> [[MicroscopicAuroraAction]] {
        var result: [[MicroscopicAuroraAction]] = [[]]
        let plan: [MicroscopicAuroraAction] = try certifiedPlan(number)
        var length: Int = 1
        while length < plan.count {
            result.append(Array(plan.prefix(length)))
            length += 1
        }
        guard let last = plan.last, case let .place(slot, well) = last else { return result }
        let head: [MicroscopicAuroraAction] = Array(plan.dropLast())
        let turned: MicroscopicAuroraSense = well.sense == .clockwise ? .counterclockwise : .clockwise
        result.append(head + [.place(slot: slot, well: MicroscopicAuroraWell(cell: well.cell, strength: well.strength,
                                                                            sense: turned))])
        for step in [1, -1] {
            let strength: Int = well.strength + step
            guard MicroscopicAuroraWell.strengths.contains(strength) else { continue }
            result.append(head + [.place(slot: slot, well: MicroscopicAuroraWell(cell: well.cell, strength: strength,
                                                                                sense: well.sense))])
        }
        return result
    }

    /// The first play over `candidates` (level numbers) after one of ``setUps(_:)`` that fails and whose broken
    /// element has a point that projects into the picture clear of every later element; nil when none does.
    static func failureCase(candidates: [Int]) throws -> MicroscopicAuroraFailureCase? {
        for number in candidates {
            for setUp in try setUps(number) {
                var core: MicroscopicAuroraExperienceCore = try MicroscopicAuroraExperienceCore.opening(number: number)
                var accepted: Bool = true
                let actions: [MicroscopicAuroraAction] = setUp + [.play]
                for action in actions where accepted {
                    let result: ActionResult = core.apply(experienceAction(action))
                    if result != .accepted { accepted = false }
                }
                guard accepted, core.play.stage == .failed, let failure = core.play.failure else { continue }
                _ = core.apply(showAction(halfTick(core.play.report.ticks)))
                let snapshot: Snapshot = core.snapshot(time: 0)
                let points: [SIMD2<Double>] = brokenPoints(snapshot)
                guard !points.isEmpty else { continue }
                return MicroscopicAuroraFailureCase(number: number, setUp: setUp, code: failure.code, points: points)
            }
        }
        return nil
    }

    /// The world points along the four edges of the outline of the cell centred at `centre` (on each edge's centre
    /// line, at fifths of its length, away from the corners).
    static func outlinePoints(_ centre: SIMD3<Double>) -> [SIMD3<Double>] {
        let h: Double = Geometry.cellSide / 2
        let corners: [SIMD3<Double>] = [
            SIMD3<Double>(-h, -h, 0), SIMD3<Double>(h, -h, 0), SIMD3<Double>(h, h, 0), SIMD3<Double>(-h, h, 0),
        ]
        let fractions: [Double] = [0.2, 0.35, 0.5, 0.65, 0.8]
        var points: [SIMD3<Double>] = []
        for k in 0..<4 {
            let a: SIMD3<Double> = centre + corners[k]
            let b: SIMD3<Double> = centre + corners[(k + 1) % 4]
            for f in fractions { points.append(a + (b - a) * f) }
        }
        return points
    }

    /// The pixels of `candidates` (world) that project into the picture clear of every element after place `rank`.
    static func clearPixels(_ candidates: [SIMD3<Double>], after rank: Int, _ o: MicroscopicAuroraTestLayout,
                            width: Int, height: Int) -> [SIMD2<Double>] {
        var result: [SIMD2<Double>] = []
        for point in candidates {
            guard let p = pixel(point, width: width, height: height), inside(p, width: width, height: height),
                  o.isClear(p, after: rank, clearance: clearance) else { continue }
            result.append(p)
        }
        return result
    }

    /// Up to `limit` points of the broken element of `snapshot` at the check size, each clear of every later
    /// element: on a coverage failure points of the unlit stencil outlines; on a connectedness failure points of the
    /// named cell's outline; on an exit the escaping swimmer's centre or points of the rim mark; on a coherence
    /// failure the centres of the swimmers outside the largest group. Empty without a failure or a clear point.
    static func brokenPoints(_ snapshot: Snapshot, width: Int = width, height: Int = height,
                             limit: Int = 6) -> [SIMD2<Double>] {
        let o: MicroscopicAuroraTestLayout = layout(snapshot, width: width, height: height)
        var result: [SIMD2<Double>] = []
        switch snapshot.failure {
        case .coverage?:
            let broken: [Int] = Geometry.brokenOutlines(snapshot).sorted()
            for index in broken where result.count < limit {
                guard let rank = o.rank(.outline, index) else { continue }
                let cell = MicroscopicAuroraCell(row: index / MicroscopicAuroraDish.cells,
                                                 column: index % MicroscopicAuroraDish.cells)
                let found: [SIMD2<Double>] = clearPixels(outlinePoints(Geometry.cellCentre(cell)), after: rank, o,
                                                         width: width, height: height)
                // One point per cell, so the points spread over several outlines.
                if let first = found.first { result.append(first) }
            }
        case let .connectedness(cell)?:
            if let rank = o.rank(.namedCell, cell.index) {
                let found: [SIMD2<Double>] = clearPixels(outlinePoints(Geometry.cellCentre(cell)), after: rank, o,
                                                         width: width, height: height)
                result += found.prefix(limit)
            }
        case let .exit(swimmer, _)?:
            if let rank = o.rank(.swimmer, swimmer) {
                result += clearPixels([Geometry.swimmerCentre(swimmer, snapshot)], after: rank, o, width: width,
                                      height: height)
            }
            if result.isEmpty, let rank = o.rank(.rimMark, 0), let d = Geometry.exitDirection(snapshot) {
                let r: Double = Geometry.rimRadius(snapshot)
                var candidates: [SIMD3<Double>] = []
                for k in -2...2 { candidates.append(d * (r + Geometry.exitMarkReach * Double(k) / 3)) }
                result += clearPixels(candidates, after: rank, o, width: width, height: height).prefix(limit)
            }
        case .coherence?:
            let broken: [Int] = Geometry.brokenSwimmers(snapshot).sorted()
            for index in broken where result.count < limit {
                guard let rank = o.rank(.swimmer, index) else { continue }
                result += clearPixels([Geometry.swimmerCentre(index, snapshot)], after: rank, o, width: width,
                                      height: height)
            }
        case nil:
            break
        }
        return result
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

    /// Whether `c` has red above green and above blue by at least 0.08 (the broken colour's red dominance; no other
    /// colour of the palette has it).
    static func isBroken(_ c: SIMD3<Double>) -> Bool {
        c.x - c.y >= hueMargin && c.x - c.z >= hueMargin
    }

    /// Whether `c` has blue above green by at least 0.08 (heliotrope, a lit actions bar).
    static func isHeliotrope(_ c: SIMD3<Double>) -> Bool {
        c.z - c.y >= hueMargin
    }

    /// The number of pixels brighter than the backdrop's top colour by 0.1 in luminance (anything drawn on it).
    static func drawnPixels(_ rgba: [UInt8]) -> Int {
        let floor: Double = luminance(Palette.abyssTop) + 0.1
        var count: Int = 0
        var i: Int = 0
        while i + 3 < rgba.count {
            let c = SIMD3<Double>(Double(rgba[i]) / 255, Double(rgba[i + 1]) / 255, Double(rgba[i + 2]) / 255)
            if luminance(c) > floor { count += 1 }
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
    static func camera(width: Int, height: Int) -> MicroscopicAuroraCamera {
        Geometry.camera(aspect: Double(width) / Double(Swift.max(height, 1)))
    }

    /// The pixel of world point `point` through `camera` on a `width` × `height` target (nil without a projection).
    static func project(_ point: SIMD3<Double>, _ camera: MicroscopicAuroraCamera, width: Int,
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

    /// The pixels of the geometry's reference points (`referencePoints`: the dish centre, the rim's rightmost point,
    /// every swimmer at the shown tick, the first site, the coverage track's centre and the first actions bar) in
    /// their order (nil without a projection); empty for an empty target.
    static func referencePixels(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> [SIMD2<Double>?] {
        var result: [SIMD2<Double>?] = []
        guard width > 0, height > 0 else { return result }
        let cam: MicroscopicAuroraCamera = camera(width: width, height: height)
        for point in Geometry.referencePoints(snapshot) {
            result.append(project(point.centre, cam, width: width, height: height))
        }
        return result
    }

    /// The number of reference points `snapshot` has: the dish centre, the rim point, its swimmers, the first site
    /// (with sites), the coverage track and the first actions bar (with a budget).
    nonisolated static func referenceCount(_ snapshot: MicroscopicAuroraSceneSnapshot) -> Int {
        2 + snapshot.positions.count + (snapshot.sites.isEmpty ? 0 : 1) + 1 + (snapshot.budget > 0 ? 1 : 0)
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
    static func pixelLength(_ length: Double, at centre: SIMD3<Double>, _ camera: MicroscopicAuroraCamera,
                            width: Int, height: Int) -> Double {
        guard let a = project(centre, camera, width: width, height: height),
              let b = project(centre + SIMD3<Double>(length, 0, 0), camera, width: width, height: height) else {
            return 0
        }
        let d: SIMD2<Double> = b - a
        return (d.x * d.x + d.y * d.y).squareRoot()
    }

    /// The projected strip of half width `half` (world units) from `a` to `b`, or nil without a projection.
    static func strip(_ a: SIMD3<Double>, _ b: SIMD3<Double>, half: Double, _ camera: MicroscopicAuroraCamera,
                      width: Int, height: Int) -> MicroscopicAuroraTestCapsule? {
        guard let pa = project(a, camera, width: width, height: height),
              let pb = project(b, camera, width: width, height: height) else { return nil }
        let w: Double = pixelLength(half, at: (a + b) / 2, camera, width: width, height: height)
        return MicroscopicAuroraTestCapsule(a: pa, b: pb, half: w)
    }

    /// The projected disc of `radius` (world units) around `centre`, or nil without a projection.
    static func disc(_ centre: SIMD3<Double>, radius: Double, _ camera: MicroscopicAuroraCamera, width: Int,
                     height: Int) -> MicroscopicAuroraTestCapsule? {
        strip(centre, centre, half: radius, camera, width: width, height: height)
    }

    /// The hull of the rectangle of half sizes `half` (world units) around `centre` in its plane.
    static func rectangleHull(_ centre: SIMD3<Double>, half: SIMD2<Double>, _ camera: MicroscopicAuroraCamera,
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

    /// The strips of the open polyline through `points`, each of half width `half` (world units).
    static func polylineStrips(_ points: [SIMD3<Double>], half: Double, _ camera: MicroscopicAuroraCamera,
                               width: Int, height: Int) -> [MicroscopicAuroraTestCapsule] {
        var result: [MicroscopicAuroraTestCapsule] = []
        guard points.count >= 2 else { return result }
        for k in 0..<(points.count - 1) {
            if let s = strip(points[k], points[k + 1], half: half, camera, width: width, height: height) {
                result.append(s)
            }
        }
        return result
    }

    /// The four strips of the outline of the cell centred at `centre`, `stripWidth` wide (world units), each extended
    /// by half the width at both ends.
    static func outlineStrips(_ centre: SIMD3<Double>, stripWidth: Double, _ camera: MicroscopicAuroraCamera,
                              width: Int, height: Int) -> [MicroscopicAuroraTestCapsule] {
        let h: Double = Geometry.cellSide / 2
        let corners: [SIMD3<Double>] = [
            SIMD3<Double>(-h, -h, 0), SIMD3<Double>(h, -h, 0), SIMD3<Double>(h, h, 0), SIMD3<Double>(-h, h, 0),
        ]
        var result: [MicroscopicAuroraTestCapsule] = []
        for k in 0..<4 {
            // A capsule's round caps reach half the width beyond each end, as the extended strip does.
            if let s = strip(centre + corners[k], centre + corners[(k + 1) % 4], half: stripWidth / 2, camera,
                             width: width, height: height) {
                result.append(s)
            }
        }
        return result
    }

    /// The level-0 ribbon of swimmer `index` (the longest; every tier's ribbon is its tail-trimmed part).
    static func longestRibbon(_ index: Int, _ snapshot: Snapshot) -> [SIMD3<Double>] {
        Geometry.ribbon(index, snapshot, tier: MicroscopicAuroraTier.all[0])
    }

    /// The projected footprint of `element` of `snapshot` (see the file header).
    static func footprint(_ element: Element, _ snapshot: Snapshot, _ cam: MicroscopicAuroraCamera,
                          width: Int, height: Int) -> MicroscopicAuroraTestFootprint {
        var f = MicroscopicAuroraTestFootprint()
        let i: Int = element.item
        let c: SIMD3<Double> = element.centre
        let rim: Double = Geometry.rimRadius(snapshot)
        var discs: [(centre: SIMD3<Double>, radius: Double)] = []
        switch element.part {
        case .backdrop:
            break
        case .field:
            discs.append((Geometry.dishCentre(), rim))
        case .fronds:
            discs.append((Geometry.dishCentre(), rim + Geometry.frondRoot + Geometry.frondReach))
        case .rim:
            discs.append((Geometry.dishCentre(), rim + Geometry.rimWidth / 2))
        case .rimMark:
            let d: SIMD3<Double> = Geometry.exitDirection(snapshot) ?? SIMD3<Double>(1, 0, 0)
            if let s = strip(d * (rim - Geometry.exitMarkReach), d * (rim + Geometry.exitMarkReach),
                             half: Geometry.exitMarkWidth / 2, cam, width: width, height: height) {
                f.capsules.append(s)
            }
        case .outline:
            f.capsules += outlineStrips(c, stripWidth: Geometry.outlineWidth, cam, width: width, height: height)
        case .litCell:
            let half: Double = Geometry.cellSide * litCellHalfShare
            f.hulls.append(rectangleHull(c, half: SIMD2<Double>(half, half), cam, width: width, height: height))
        case .namedCell:
            f.capsules += outlineStrips(c, stripWidth: Geometry.namedOutlineWidth, cam, width: width, height: height)
        case .site:
            discs.append((c, Geometry.siteRadiusShare * Geometry.cellSide + Geometry.siteWidth / 2))
        case .well:
            let reach: Double = Geometry.wellRadiusShare * Geometry.cellSide + Geometry.arrowLength
                + Geometry.arrowWidth / 2 + Geometry.wellWidth / 2
            discs.append((c, reach))
        case .ribbon:
            f.capsules += polylineStrips(longestRibbon(i, snapshot), half: Geometry.ribbonWidth / 2, cam,
                                         width: width, height: height)
        case .swimmer:
            discs.append((c, Geometry.capsuleLength / 2))
        case .coverageTrack, .coherenceTrack:
            let halfWidth: Double = (Geometry.gaugeEnd - Geometry.gaugeStart) / 2
                + MicroscopicAuroraShaders.markQuadExtent * Geometry.markRadius
            f.hulls.append(rectangleHull(c, half: SIMD2<Double>(halfWidth, gaugeRowHalf), cam, width: width,
                                         height: height))
        case .bar:
            let half = SIMD2<Double>(Geometry.barFill * Geometry.actionsSlot(snapshot) / 2, Geometry.barHeight / 2)
            f.hulls.append(rectangleHull(c, half: half, cam, width: width, height: height))
        }
        for entry in discs {
            if let d = disc(entry.centre, radius: entry.radius, cam, width: width, height: height) {
                f.capsules.append(d)
            }
        }
        return f
    }

    /// The level-0 glow's footprint (the widest glow of any tier): each swimmer's band and each ribbon's band at
    /// their outermost shell.
    static func glowFootprint(_ snapshot: Snapshot, _ cam: MicroscopicAuroraCamera, width: Int,
                              height: Int) -> MicroscopicAuroraTestFootprint {
        var f = MicroscopicAuroraTestFootprint()
        let shells: Double = Double(MicroscopicAuroraTier.all[0].glowShells)
        let swimmer: Double = Geometry.swimmerGlowInner + Geometry.swimmerGlowGrowth * shells
        let ribbon: Double = Geometry.ribbonWidth / 2 + Geometry.ribbonGlowGrowth * shells
        for i in snapshot.positions.indices {
            if let d = disc(Geometry.swimmerCentre(i, snapshot), radius: swimmer, cam, width: width, height: height) {
                f.capsules.append(d)
            }
            f.capsules += polylineStrips(longestRibbon(i, snapshot), half: ribbon, cam, width: width, height: height)
        }
        return f
    }

    /// The painter's order of `snapshot` on a `width` × `height` target with every element's footprint and the
    /// glow's; empty for an empty target.
    static func layout(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> MicroscopicAuroraTestLayout {
        var result = MicroscopicAuroraTestLayout()
        guard width > 0, height > 0 else { return result }
        let cam: MicroscopicAuroraCamera = camera(width: width, height: height)
        result.order = Geometry.paintOrder(snapshot)
        for element in result.order {
            result.footprints.append(footprint(element, snapshot, cam, width: width, height: height))
        }
        result.glow = glowFootprint(snapshot, cam, width: width, height: height)
        return result
    }

    /// The backdrop's colour coordinates on a `width` × `height` target; nil for an empty target.
    static func backdrop(width: Int = width, height: Int = height) -> MicroscopicAuroraTestBackdrop? {
        guard width > 0, height > 0 else { return nil }
        return MicroscopicAuroraTestBackdrop(camera: camera(width: width, height: height), width: width,
                                             height: height)
    }

    // MARK: Checks

    /// The backdrop patch check at view fraction (`fx`, `fy`): nil when the patch is not measured (outside the
    /// picture or near a footprint), else the miss in words or "" when it passed.
    static func patchResult(_ rgba: [UInt8], fx: Double, fy: Double, sky: MicroscopicAuroraTestBackdrop,
                            _ o: MicroscopicAuroraTestLayout, width: Int, height: Int) -> String? {
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

    /// The swimmer checks of clarification Q3: every swimmer whose centre is clear of every later element is
    /// brighter than the dish field by 0.25 within 3 px; returns how many were measured.
    static func checkSwimmers(_ rgba: [UInt8], _ snapshot: Snapshot, _ o: MicroscopicAuroraTestLayout,
                              width: Int, height: Int, misses: inout [String]) -> Int {
        let floor: Double = luminance(Palette.field) + brightMargin
        var measured: Int = 0
        for i in snapshot.positions.indices {
            guard let p = pixel(Geometry.swimmerCentre(i, snapshot), width: width, height: height),
                  inside(p, width: width, height: height), let rank = o.rank(.swimmer, i),
                  o.isClear(p, after: rank, clearance: clearance) else { continue }
            measured += 1
            let bright: Bool = anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height,
                                        where: { luminance($0) >= floor })
            if !bright {
                let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
                misses.append(String(format: "swimmer %ld centre (%.1f, %.1f) is (%.3f, %.3f, %.3f)", i, p.x, p.y,
                                     c.x, c.y, c.z))
            }
        }
        return measured
    }

    /// The rim, actions bar and coverage track checks of clarification Q3 on `rgba` against `snapshot`, added to
    /// `report`.
    static func checkCues(_ rgba: [UInt8], _ snapshot: Snapshot, _ o: MicroscopicAuroraTestLayout,
                          _ sky: MicroscopicAuroraTestBackdrop, width: Int, height: Int,
                          into report: inout MicroscopicAuroraCheckReport) {
        if let p = pixel(Geometry.rimPoint(snapshot), width: width, height: height),
           inside(p, width: width, height: height), let rank = o.rank(.rim, 0),
           o.isClear(p, after: rank, clearance: clearance) {
            report.rimChecked = true
            let back: Double = luminance(sky.gradient(x: p.x, y: p.y))
            let off: Bool = anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height,
                                     where: { Swift.abs(luminance($0) - back) >= backdropMargin })
            if !off {
                report.misses.append(String(format: "rim point (%.1f, %.1f) is backdrop-coloured", p.x, p.y))
            }
        }
        if Geometry.litActions(snapshot) > 0,
           let p = pixel(Geometry.actionsBar(0, snapshot), width: width, height: height),
           inside(p, width: width, height: height), let rank = o.rank(.bar, 0),
           o.isClear(p, after: rank, clearance: clearance) {
            report.barChecked = true
            if !anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height, where: isHeliotrope) {
                let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
                report.misses.append(String(format: "actions bar 0 (%.1f, %.1f) is (%.3f, %.3f, %.3f)", p.x, p.y,
                                            c.x, c.y, c.z))
            }
        }
        if let p = pixel(Geometry.coverageTrackCentre(), width: width, height: height),
           inside(p, width: width, height: height), let rank = o.rank(.coverageTrack, 0),
           o.isClear(p, after: rank, clearance: clearance) {
            report.trackChecked = true
            let back: Double = luminance(sky.gradient(x: p.x, y: p.y))
            let off: Bool = anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height,
                                     where: { Swift.abs(luminance($0) - back) >= backdropMargin })
            if !off {
                report.misses.append(String(format: "coverage track centre (%.1f, %.1f) is backdrop-coloured", p.x,
                                            p.y))
            }
        }
    }

    /// The point checks of clarification Q3 (see the file header) on `rgba` against `snapshot`.
    static func pointReport(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width,
                            height: Int = height) -> MicroscopicAuroraCheckReport {
        var report = MicroscopicAuroraCheckReport()
        let o: MicroscopicAuroraTestLayout = layout(snapshot, width: width, height: height)
        guard let sky = backdrop(width: width, height: height) else {
            report.misses.append("an empty target")
            return report
        }
        var misses: [String] = []
        report.swimmersChecked = checkSwimmers(rgba, snapshot, o, width: width, height: height, misses: &misses)
        report.misses += misses
        checkCues(rgba, snapshot, o, sky, width: width, height: height, into: &report)
        for fraction in patchFractions {
            guard let result = patchResult(rgba, fx: fraction.x, fy: fraction.y, sky: sky, o, width: width,
                                           height: height) else { continue }
            report.patchesChecked += 1
            if !result.isEmpty { report.misses.append(result) }
        }
        return report
    }

    /// Runs the checks of clarification Q3 on `rgba` against `snapshot`, recording an issue per failure, and returns
    /// the report. At least one swimmer must be measured (the last one is never excluded by another), as must the
    /// coverage track and (when lit) the first actions bar; a picture of at least 256 × 256 must measure all four
    /// corner patches. The rim point is measured when clear and reported.
    @discardableResult
    static func checkFrame(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width, height: Int = height,
                           _ what: String,
                           sourceLocation: SourceLocation = #_sourceLocation) -> MicroscopicAuroraCheckReport {
        #expect(rgba.count == width * height * 4, "\(what): picture size", sourceLocation: sourceLocation)
        guard rgba.count == width * height * 4 else { return MicroscopicAuroraCheckReport() }
        let report: MicroscopicAuroraCheckReport = pointReport(rgba, snapshot: snapshot, width: width,
                                                               height: height)
        if !snapshot.positions.isEmpty {
            #expect(report.swimmersChecked >= 1, "\(what): no swimmer centre was clear",
                    sourceLocation: sourceLocation)
        }
        #expect(report.trackChecked, "\(what): the coverage track was not clear", sourceLocation: sourceLocation)
        if Geometry.litActions(snapshot) > 0 {
            #expect(report.barChecked, "\(what): the first actions bar was not clear", sourceLocation: sourceLocation)
        }
        if width >= 256 && height >= 256 {
            #expect(report.patchesChecked == patchFractions.count, "\(what): corner patches \(report.patchesChecked)",
                    sourceLocation: sourceLocation)
        }
        let shown: [String] = Array(report.misses.prefix(8))
        #expect(report.misses.isEmpty, "\(what): \(shown)", sourceLocation: sourceLocation)
        print("microscopic-aurora \(what): swimmers \(report.swimmersChecked) of \(snapshot.positions.count); rim "
              + "\(report.rimChecked); bar \(report.barChecked); track \(report.trackChecked); patches "
              + "\(report.patchesChecked)")
        return report
    }
}
#endif
