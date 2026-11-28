// MyceliumArchitectTestSupport — feature 513 (R02-G22-03) T-R02G2203-005 (FR-R02G2203-001 … 007, 010; clarifications
// Q1–Q5). Shared helpers of the Mycelium Architect experience tests, following Binary Gardens' harness (feature 503):
// opening the experience through the one app's session host (seed `s` prepares certified level `s % 100 + 1`; a
// session without a quality pin is pinned to level 0), making set-up actions (each level's certified plan, the
// generator's minimal plan `MyceliumArchitectExperienceCore.generated(number:).solution.actions` without its closing
// `run`, so the predicted run is the winning one), issuing kernel actions through the shell, drawing live frames,
// drawing an off-screen still (RGBA8, rows top-down, the orientation of the Core's CPU projection
// `MyceliumArchitectSceneGeometry.project`, origin top left, y down, scaled here to pixels), the engine digest, the
// frame checks of clarification Q3 at 1,152 × 768 at the full shown pulse (the pulses run, which every opening and
// every accepted action shows), and a short search for a failing run whose broken element is clear of every later
// element.
//
// Only the light pulses along the veins, the toxin ripples, the hyphae fuzz and the spores move by time (their shaders
// read `u_time` times `u_motion`); the pulses and ripples change colours inside their own shapes only, the fuzz sways
// by at most `MyceliumArchitectShaders.fuzzSway` and the spores drift by at most twice
// `MyceliumArchitectShaders.sporeDrift`, and the footprints below cover that reach, so every check here holds at every
// frame time. Every still here is drawn at frame time 0 unless a test says otherwise.
//
// The CPU reference: the painter's order of `MyceliumArchitectSceneGeometry.paintOrder` (by kind and index; the scene
// draws with depth testing off, so a later element covers an earlier one) with every element's projected footprint,
// the convex hull of points that bound it (every flat at its full quad, which is also what the unlit fallback draws):
// the backdrop none (it lies under everything); the floor its plate; a site, toxin (with a toxic failure's ring),
// blocker, nutrient or bloom its quad; a rock its box; a vein or sprout the box of its tube at the root radius; the
// fuzz each strand's quad widened by the sway; the root the box of its dome; a terminal the box of its dome, its pips
// and its broken ring; the spores each dot's quad widened by the drift; the gauge its plate; a pip or an actions bar
// its quad. Fuzz and spores are those of the tier drawn (of every tier when no tier is named). The glow elements of
// the order have no footprint there: the additive glow (drawn last) only brightens and hides no cue, but its extent
// at the tier drawn (each glowing element's outermost shell) keeps the backdrop patches away.
// A point is checked only when it projects into the picture at least 6 px from every element drawn after it:
//   - the root cap's centre: within 3 px a pixel brighter than the backdrop there by 0.15 in luminance;
//   - each terminal's centre: when reached, within 3 px a pixel brighter by 0.3; when not, a pixel 0.05 from the
//     backdrop in luminance; in the unlit fallback, a pixel within 0.1 per channel of the flat colour (cap open when
//     reached, cap closed otherwise); the root or at least one terminal is measured in every frame;
//   - the first actions bar, when lit: within 3 px red above blue by 0.08 (the copper of an action left);
//   - the weight plate's left margin (−0.925, −1.12, 0): within 3 px a pixel 0.05 from the backdrop in luminance;
//   - the backdrop: 9 × 9 patches at 3 % from the picture's corners, 24 px from every footprint; the per-channel
//     median of each is within 0.06 of the gradient (cave at the bottom of the backdrop quad, cave top at its top) at
//     its height (`MyceliumArchitectSceneGeometry.backdropHeight(view:camera:)`; the sparse spore points cannot move a
//     median); both lower corners are measured on a picture of at least 256 × 256.
// "The backdrop there" is the gradient's colour at the pixel's height. Luminance is the Rec. 709 weighting of the
// stored 0 … 1 channel values. Positions come from the presenter's `lastSnapshot`. Short runs only (no sleep, no
// wall-clock assertion). The geometry's sizes are read through `@testable import MyceliumArchitectCore`.
//
// The checked levels are catalog levels 1, 21, 41, 61 and 81 (seeds 0, 20, 40, 60, 80).
#if os(iOS)
import CoreGraphics
import Foundation
@testable import MyceliumArchitectCore
import Testing
import UIKit
@testable import MyceliumArchitectExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the point checks of one frame found.
struct MyceliumArchitectCheckReport {
    /// Whether the root cap's centre was measured.
    var rootChecked: Bool = false
    /// The terminals whose centre was measured.
    var terminalsChecked: Int = 0
    /// Whether the first actions bar was measured.
    var barChecked: Bool = false
    /// Whether the weight plate's left margin was measured.
    var marginChecked: Bool = false
    /// The backdrop patches measured.
    var patchesChecked: Int = 0
    /// The lower-corner backdrop patches measured.
    var lowerPatchesChecked: Int = 0
    /// Every failed check, in words.
    var misses: [String] = []

    /// Whether the root or at least one terminal was measured.
    var capChecked: Bool { rootChecked || terminalsChecked >= 1 }
}

/// The projected footprint of one drawn element (pixels, y down): convex polygons.
struct MyceliumArchitectTestFootprint {
    /// Convex polygons (corners in the order `convexHull` gives them).
    var hulls: [[SIMD2<Double>]] = []

    /// The signed distance (pixels) of `p` from the footprint: negative inside, infinite for an empty footprint.
    func distance(_ p: SIMD2<Double>) -> Double {
        var best: Double = Double.infinity
        for hull in hulls { best = Swift.min(best, MyceliumArchitectTest.hullDistance(hull, p)) }
        return best
    }
}

/// The painter's order of one snapshot on one target with every element's footprint (same indices) and the glow's.
struct MyceliumArchitectTestLayout {
    /// The elements in painter's order.
    var order: [MyceliumArchitectElement] = []
    /// The footprint of each element of `order` (empty for the glow elements).
    var footprints: [MyceliumArchitectTestFootprint] = []
    /// The glow's footprint at the tier drawn (drawn last, additive).
    var glow: MyceliumArchitectTestFootprint = MyceliumArchitectTestFootprint()

    /// The place of the element of `kind` drawing `item` in the painter's order, or nil.
    func rank(_ kind: MyceliumArchitectElement.Kind, _ item: Int) -> Int? {
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
struct MyceliumArchitectTestBackdrop {
    /// The camera of the target.
    var camera: MyceliumArchitectCamera
    /// The target's width in pixels.
    var width: Int
    /// The target's height in pixels.
    var height: Int

    /// The backdrop's height h (0 at the quad's bottom, 1 at its top) at pixel (`x`, `y`).
    func heightAt(x: Double, y: Double) -> Double {
        let view: SIMD2<Double> = SIMD2<Double>(x / Double(width), y / Double(height))
        return MyceliumArchitectSceneGeometry.backdropHeight(view: view, camera: camera)
    }

    /// The gradient colour (cave → cave top) at pixel (`x`, `y`): the shader's CPU reference without the spore points.
    func gradient(x: Double, y: Double) -> SIMD3<Double> {
        let c: Vec4 = MyceliumArchitectSceneGeometry.backdropColour(height: heightAt(x: x, y: y))
        return SIMD3<Double>(c.x, c.y, c.z)
    }
}

/// A run that fails with a broken element clear of every later element: the level, the set-up before the run, the
/// failure's code and the checked points of the broken element at the check size (level-2).
struct MyceliumArchitectFailureCase {
    /// The catalog level number.
    var number: Int
    /// The actions made before the run.
    var setUp: [MyceliumArchitectAction]
    /// The failure's code (`toxic`, `starved`, `unreached` or `overweight`).
    var code: String
    /// The checked points of the broken element (pixels at 1,152 × 768).
    var points: [SIMD2<Double>]
}

/// Building, opening, drawing and measuring Mycelium Architect.
@MainActor
enum MyceliumArchitectTest {
    typealias Geometry = MyceliumArchitectSceneGeometry
    typealias Palette = MyceliumArchitectPalette
    typealias Snapshot = MyceliumArchitectSceneSnapshot
    typealias Shell = ExperienceShell<MyceliumArchitectPresenter>
    typealias Element = MyceliumArchitectElement
    typealias Kind = MyceliumArchitectElement.Kind

    /// The experience id `r02-g22.mycelium-architect`.
    static var id: ExperienceID {
        MyceliumArchitectExperience.id ?? ExperienceID(rawValue: "r02-g22.unknown")!
    }

    /// The frame-check size of clarification Q3, aspect 1.5.
    nonisolated static let width: Int = 1_152
    nonisolated static let height: Int = 768
    /// The checked catalog levels and their seeds (seed = level − 1).
    nonisolated static let levels: [Int] = [1, 21, 41, 61, 81]
    nonisolated static let seeds: [UInt64] = [0, 20, 40, 60, 80]
    /// The feature's own seed (level 2_513 % 100 + 1 = 14).
    nonisolated static let featureSeed: UInt64 = 2_513
    /// The search radius (pixels) of the point checks.
    nonisolated static let pointRadius: Double = 3
    /// The search radius (pixels) at a broken mark.
    nonisolated static let markRadius: Double = 1.5
    /// The clearance (pixels) of every checked point from every element drawn after it.
    nonisolated static let clearance: Double = 6
    /// The root cap's centre is brighter than the backdrop there by at least this.
    nonisolated static let rootMargin: Double = 0.15
    /// A reached terminal's centre is brighter than the backdrop there by at least this.
    nonisolated static let reachedMargin: Double = 0.3
    /// An unreached terminal's centre differs from the backdrop there by at least this.
    nonisolated static let unreachedMargin: Double = 0.05
    /// The first actions bar's red above blue.
    nonisolated static let hueMargin: Double = 0.08
    /// The weight plate's left margin differs from the backdrop by at least this in luminance.
    nonisolated static let marginDifference: Double = 0.05
    /// The per-channel bound of a backdrop patch's median.
    nonisolated static let backdropTolerance: Double = 0.06
    /// The per-channel bound of a flat colour (the fallback's caps, the broken colour).
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

    /// Opens Mycelium Architect with `seed` in `session` through the factory, lays the view out at `size` points,
    /// draws one frame, makes the actions `setUp` through the shell and draws again (each accepted action shows the
    /// full growth). A session without a quality pin is pinned to level 0. `configure` runs on the presenter before
    /// its first `setup` (the fallback seam).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, setUp: [MyceliumArchitectAction] = [],
                     reduceMotion: Bool = false, reduceFlashing: Bool = false,
                     size: CGSize = CGSize(width: 48, height: 32),
                     configure: ((MyceliumArchitectPresenter) -> Void)? = nil) async throws -> Shell {
        let id: ExperienceID = self.id
        var made: Shell?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: seed) {
            let shell: Shell = MyceliumArchitectExperience.make(id: id, reduceMotion: reduceMotion,
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
    static func core(_ shell: Shell) throws -> MyceliumArchitectExperienceCore {
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
    nonisolated static func control(_ action: MyceliumArchitectAction) -> (control: String, values: [Double]) {
        switch action {
        case let .nutrient(cell):
            return ("cell.nutrient", [Double(cell.column), Double(cell.row)])
        case let .blocker(cell):
            return ("cell.blocker", [Double(cell.column), Double(cell.row)])
        case let .clear(cell):
            return ("cell.clear", [Double(cell.column), Double(cell.row)])
        case let .seed(direction):
            return ("root.seed", [Double(direction.rawValue)])
        case let .unseed(direction):
            return ("root.unseed", [Double(direction.rawValue)])
        case .run:
            return ("growth.run", [])
        }
    }

    /// The host action of `action` (step 0).
    nonisolated static func experienceAction(_ action: MyceliumArchitectAction) -> ExperienceAction {
        let issued: (control: String, values: [Double]) = control(action)
        return ExperienceAction(control: issued.control, values: issued.values, step: 0)
    }

    /// The host action showing pulse `pulse` (step 0).
    nonisolated static func showAction(_ pulse: Int) -> ExperienceAction {
        ExperienceAction(control: "growth.show", values: [Double(pulse)], step: 0)
    }

    /// The certified plan of level `number` (the generator's minimal plan): its arrangement actions, the closing run
    /// not included.
    nonisolated static func certifiedPlan(_ number: Int) throws -> [MyceliumArchitectAction] {
        let actions: [MyceliumArchitectAction] = try MyceliumArchitectExperienceCore.generated(number: number)
            .solution.actions
        var plan: [MyceliumArchitectAction] = []
        for action in actions where action != .run { plan.append(action) }
        return plan
    }

    /// Issues `actions` through the shell, each expected to be accepted; returns how many were.
    @discardableResult
    static func issue(_ shell: Shell, _ actions: [MyceliumArchitectAction],
                      sourceLocation: SourceLocation = #_sourceLocation) -> Int {
        var accepted: Int = 0
        for (index, action) in actions.enumerated() {
            let issued: (control: String, values: [Double]) = control(action)
            let result: ActionResult = shell.handle(control: issued.control, values: issued.values)
            #expect(result == .accepted, "action \(index) \(issued.control) \(issued.values): \(result.code)",
                    sourceLocation: sourceLocation)
            if result == .accepted { accepted += 1 }
        }
        return accepted
    }

    /// The opening core of level `number` with `actions` applied (no host): the CPU reference of that state.
    static func coreAfter(_ number: Int, _ actions: [MyceliumArchitectAction]) throws -> MyceliumArchitectExperienceCore {
        var core: MyceliumArchitectExperienceCore = try MyceliumArchitectExperienceCore.opening(number: number)
        for action in actions {
            let result: ActionResult = core.apply(experienceAction(action))
            #expect(result == .accepted, "level \(number) \(action): \(result.code)")
        }
        return core
    }

    /// The set-ups tried before the run in ``failureCase(candidates:)``: none (the opening: an immediate run, which
    /// never wins, since a level refuses a winning start), then every proper prefix of the certified plan.
    static func setUps(_ number: Int) throws -> [[MyceliumArchitectAction]] {
        var result: [[MyceliumArchitectAction]] = [[]]
        let plan: [MyceliumArchitectAction] = try certifiedPlan(number)
        var length: Int = 1
        while length < plan.count {
            result.append(Array(plan.prefix(length)))
            length += 1
        }
        return result
    }

    /// The first run over `candidates` (level numbers) after one of ``setUps(_:)`` that fails and whose broken
    /// element has a point that projects into the level-2 picture clear of every later element; nil when none does.
    static func failureCase(candidates: [Int]) throws -> MyceliumArchitectFailureCase? {
        for number in candidates {
            for setUp in try setUps(number) {
                var core: MyceliumArchitectExperienceCore = try MyceliumArchitectExperienceCore.opening(number: number)
                var accepted: Bool = true
                let actions: [MyceliumArchitectAction] = setUp + [.run]
                for action in actions where accepted {
                    let result: ActionResult = core.apply(experienceAction(action))
                    if result != .accepted { accepted = false }
                }
                guard accepted, core.play.stage == .failed, let failure = core.play.failure else { continue }
                let snapshot: Snapshot = core.snapshot(time: 0)
                let points: [SIMD2<Double>] = brokenPoints(snapshot)
                guard !points.isEmpty else { continue }
                return MyceliumArchitectFailureCase(number: number, setUp: setUp, code: failure.code, points: points)
            }
        }
        return nil
    }

    /// The pixels of `candidates` (world) that project into the picture clear of every element after place `rank`.
    static func clearPixels(_ candidates: [SIMD3<Double>], after rank: Int, _ o: MyceliumArchitectTestLayout,
                            width: Int, height: Int) -> [SIMD2<Double>] {
        var result: [SIMD2<Double>] = []
        for point in candidates {
            guard let p = pixel(point, width: width, height: height), inside(p, width: width, height: height),
                  o.isClear(p, after: rank, clearance: clearance) else { continue }
            result.append(p)
        }
        return result
    }

    /// The world points of a broken ring around `centre` (half 0.5·s): its centre line (radius
    /// 0.5·s · (1 − ``MyceliumArchitectShaders/ringHalf``)) at eight angles in the board plane.
    static func brokenRingPoints(_ centre: SIMD3<Double>, _ snapshot: Snapshot) -> [SIMD3<Double>] {
        let radius: Double = Geometry.markRing * snapshot.fitScale * (1 - MyceliumArchitectShaders.ringHalf)
        var points: [SIMD3<Double>] = []
        for k in 0..<8 {
            let a: Double = 2 * Double.pi * (Double(k) + 0.5) / 8
            points.append(centre + SIMD3<Double>(cos(a), sin(a), 0) * radius)
        }
        return points
    }

    /// Up to `limit` points of the broken element of the failed `snapshot` at the check size and level-2 (where the
    /// broken colour is drawn flat), each clear of every later element (clarification Q4): on a toxic failure points of
    /// the broken ring around the entered toxin; on an unreached failure points of the broken ring around the named
    /// terminal; on an overweight failure the middle of the weight fill past the limit tick. A starved failure's marks
    /// (a dashed outline and a hairline tick) give no point. Empty without a failure on a failed play or without a
    /// clear point.
    static func brokenPoints(_ snapshot: Snapshot, width: Int = width, height: Int = height,
                             limit: Int = 6) -> [SIMD2<Double>] {
        let o: MyceliumArchitectTestLayout = layout(snapshot, tier: 2, width: width, height: height)
        var result: [SIMD2<Double>] = []
        guard snapshot.stage == .failed else { return result }
        if let cell = Geometry.toxicCell(snapshot), let toxin = snapshot.level.toxins.firstIndex(of: cell),
           let rank = o.rank(.toxin, toxin) {
            let centre: SIMD3<Double> = Geometry.centre(cell, snapshot)
            result += clearPixels(brokenRingPoints(centre, snapshot), after: rank, o, width: width, height: height)
        }
        if let terminal = Geometry.unreachedTerminal(snapshot), snapshot.level.terminals.indices.contains(terminal),
           let rank = o.rank(.terminal, terminal) {
            let centre: SIMD3<Double> = Geometry.centre(snapshot.level.terminals[terminal], snapshot)
            result += clearPixels(brokenRingPoints(centre, snapshot), after: rank, o, width: width, height: height)
        }
        if Geometry.isOverweight(snapshot), let rank = o.rank(.gauge, 0) {
            let budget: Int = Swift.max(snapshot.nutrientBudget, 1)
            let end: Double = Geometry.weightX(snapshot.totalWeight, budget: budget)
            let limitX: Double = Geometry.weightX(snapshot.weightLimit, budget: budget)
            let a: SIMD2<Double>? = pixel(SIMD3<Double>(limitX, Geometry.gaugeY, 0), width: width, height: height)
            let b: SIMD2<Double>? = pixel(SIMD3<Double>(end, Geometry.gaugeY, 0), width: width, height: height)
            if let a, let b, b.x - a.x >= 8 {
                let middle: SIMD3<Double> = SIMD3<Double>((limitX + end) / 2, Geometry.gaugeY, 0)
                result += clearPixels([middle], after: rank, o, width: width, height: height)
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

    /// The red, green and blue of a palette colour.
    nonisolated static func rgb(_ c: Vec4) -> SIMD3<Double> {
        SIMD3<Double>(c.x, c.y, c.z)
    }

    /// Whether `c` is the broken colour within 0.1 per channel (`MyceliumArchitectPalette.broken`).
    static func isBroken(_ c: SIMD3<Double>) -> Bool {
        channelDistance(c, rgb(Palette.broken)) <= colourTolerance
    }

    /// Whether `c` has red above blue by at least 0.08 (the copper of a lit actions bar; the unlit bar is bluer).
    static func isCopper(_ c: SIMD3<Double>) -> Bool {
        c.x - c.z >= hueMargin
    }

    /// The number of pixels brighter than the backdrop's top colour by 0.1 in luminance (anything drawn on it).
    static func drawnPixels(_ rgba: [UInt8]) -> Int {
        let floor: Double = luminance(rgb(Palette.caveTop)) + 0.1
        var count: Int = 0
        var i: Int = 0
        while i + 3 < rgba.count {
            let c: SIMD3<Double> = SIMD3<Double>(Double(rgba[i]) / 255, Double(rgba[i + 1]) / 255,
                                                 Double(rgba[i + 2]) / 255)
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
    static func camera(width: Int, height: Int) -> MyceliumArchitectCamera {
        Geometry.camera(aspect: Double(width) / Double(Swift.max(height, 1)))
    }

    /// The pixel of world point `point` through `camera` on a `width` × `height` target (nil without a projection).
    static func project(_ point: SIMD3<Double>, _ camera: MyceliumArchitectCamera, width: Int,
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

    /// The pixels of the geometry's reference points (`referencePoints`: the board centre, the root, every terminal,
    /// the weight plate's left margin and the first actions bar; never a fuzz strand or a spore) in their order (nil
    /// without a projection); empty for an empty target.
    static func referencePixels(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> [SIMD2<Double>?] {
        var result: [SIMD2<Double>?] = []
        guard width > 0, height > 0 else { return result }
        let cam: MyceliumArchitectCamera = camera(width: width, height: height)
        for point in Geometry.referencePoints(snapshot) {
            result.append(project(point.centre, cam, width: width, height: height))
        }
        return result
    }

    /// The number of reference points `snapshot` has: the board centre, the root, its terminals, the weight plate's
    /// margin and the first actions bar (with a budget).
    nonisolated static func referenceCount(_ snapshot: MyceliumArchitectSceneSnapshot) -> Int {
        3 + snapshot.level.terminals.count + (snapshot.budget > 0 ? 1 : 0)
    }

    /// The convex hull of `points` (Andrew's monotone chain).
    nonisolated static func convexHull(_ points: [SIMD2<Double>]) -> [SIMD2<Double>] {
        let sorted: [SIMD2<Double>] = points.sorted { (a: SIMD2<Double>, b: SIMD2<Double>) -> Bool in
            a.x != b.x ? a.x < b.x : a.y < b.y
        }
        guard sorted.count > 2 else { return sorted }
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

    /// The turn (cross product) of `o` → `a` → `b`.
    nonisolated static func turn(_ o: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
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

    /// The corners of a board-plane rectangle of half sizes `half` around `centre` (at `centre.z`).
    nonisolated static func horizontalRectangle(_ centre: SIMD3<Double>, half: SIMD2<Double>) -> [SIMD3<Double>] {
        let a: SIMD3<Double> = SIMD3<Double>(half.x, 0, 0)
        let b: SIMD3<Double> = SIMD3<Double>(0, half.y, 0)
        return [centre - a - b, centre + a - b, centre + a + b, centre - a + b]
    }

    /// The corners of a board-plane square of half side `half` around `centre`.
    nonisolated static func square(_ centre: SIMD3<Double>, half: Double) -> [SIMD3<Double>] {
        horizontalRectangle(centre, half: SIMD2<Double>(half, half))
    }

    /// A polygon holding the board-plane circle of `radius` around `centre`.
    nonisolated static func horizontalCircle(_ centre: SIMD3<Double>, radius: Double) -> [SIMD3<Double>] {
        let n: Int = circleSamples
        let reach: Double = radius / cos(Double.pi / Double(n))
        var points: [SIMD3<Double>] = []
        for k in 0..<n {
            let a: Double = 2 * Double.pi * Double(k) / Double(n)
            points.append(centre + SIMD3<Double>(cos(a), sin(a), 0) * reach)
        }
        return points
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

    /// The corners of the box of a tube of radius `radius` resting on the floor from `a` to `b` (z 0 … 2·radius): each
    /// end widened sideways and lengthwise by the radius.
    nonisolated static func tubeBox(_ a: SIMD3<Double>, _ b: SIMD3<Double>, radius: Double) -> [SIMD3<Double>] {
        let d: SIMD3<Double> = SIMD3<Double>(b.x - a.x, b.y - a.y, 0)
        let size: Double = (d.x * d.x + d.y * d.y).squareRoot()
        guard size > 0 else {
            return box(a - SIMD3<Double>(radius, radius, 0), a + SIMD3<Double>(radius, radius, 2 * radius))
        }
        let along: SIMD3<Double> = d / size * radius
        let side: SIMD3<Double> = SIMD3<Double>(-d.y, d.x, 0) / size * radius
        var corners: [SIMD3<Double>] = []
        let lift: SIMD3<Double> = SIMD3<Double>(0, 0, 2 * radius)
        let ends: [SIMD3<Double>] = [a - along, b + along]
        for end in ends {
            let flat: SIMD3<Double> = SIMD3<Double>(end.x, end.y, 0)
            corners.append(flat + side)
            corners.append(flat - side)
            corners.append(flat + side + lift)
            corners.append(flat - side + lift)
        }
        return corners
    }

    /// The corners of a strip of half width `half` from `a` to `b` in the plane z = a.z, lengthened by `half` at both
    /// ends.
    nonisolated static func stripCorners(_ a: SIMD3<Double>, _ b: SIMD3<Double>, half: Double) -> [SIMD3<Double>] {
        let d: SIMD3<Double> = SIMD3<Double>(b.x - a.x, b.y - a.y, 0)
        let size: Double = (d.x * d.x + d.y * d.y).squareRoot()
        guard size > 0 else { return square(a, half: half) }
        let along: SIMD3<Double> = d / size * half
        let across: SIMD3<Double> = SIMD3<Double>(-d.y, d.x, 0) / size * half
        return [a - along - across, a - along + across, b + along + across, b + along - across]
    }

    /// The convex hull of the pixels of `points` (world) through `camera` on a `width` × `height` target.
    static func hull(_ points: [SIMD3<Double>], _ camera: MyceliumArchitectCamera, width: Int,
                     height: Int) -> [SIMD2<Double>] {
        var projected: [SIMD2<Double>] = []
        for point in points {
            if let p = project(point, camera, width: width, height: height) { projected.append(p) }
        }
        return convexHull(projected)
    }

    // MARK: Footprints

    /// The bounding point groups of a terminal cap `terminal` at `c`: the box of its dome, its pips and its broken
    /// ring (a square of half 0.56·s, from the floor to the dome's top).
    static func terminalBox(_ c: SIMD3<Double>, _ s: Double) -> [SIMD3<Double>] {
        let reach: Double = Swift.max(Geometry.capPipRing + Geometry.capPipHalf, Geometry.markRing,
                                      Geometry.terminalCapRadius) * s
        let top: Double = Geometry.capHeight * Geometry.terminalCapRadius * s
        return box(c - SIMD3<Double>(reach, reach, 0), c + SIMD3<Double>(reach, reach, top))
    }

    /// The projected footprint of `element` of `snapshot` drawn at any of `tiers` (see the file header).
    static func footprint(_ element: Element, _ snapshot: Snapshot, tiers: [MyceliumArchitectTier],
                          _ cam: MyceliumArchitectCamera, width: Int, height: Int) -> MyceliumArchitectTestFootprint {
        var f: MyceliumArchitectTestFootprint = MyceliumArchitectTestFootprint()
        let c: SIMD3<Double> = element.centre
        let i: Int = element.item
        let s: Double = snapshot.fitScale
        let level: MyceliumArchitectLevel = snapshot.level
        var groups: [[SIMD3<Double>]] = []
        switch element.kind {
        case .backdrop, .glow:
            break
        case .floor:
            groups.append(horizontalRectangle(SIMD3<Double>((Geometry.floorLow.x + Geometry.floorHigh.x) / 2,
                                                            (Geometry.floorLow.y + Geometry.floorHigh.y) / 2, 0),
                                              half: (Geometry.floorHigh - Geometry.floorLow) / 2))
        case .site:
            groups.append(square(c, half: Geometry.siteHalf * s))
        case .toxin:
            groups.append(square(c, half: Swift.max(Geometry.toxinRadius, Geometry.markRing) * s))
        case .rock:
            let a: Double = Geometry.rockSide * s / 2
            groups.append(box(c - SIMD3<Double>(a, a, 0), c + SIMD3<Double>(a, a, Geometry.rockHeight * s)))
        case .blocker:
            groups.append(square(c, half: Geometry.blockerRadius * s))
        case .nutrient:
            groups.append(square(c, half: Geometry.nutrientRadius * s))
        case .vein:
            guard snapshot.grown.indices.contains(i), i < snapshot.parents.count,
                  let parent = snapshot.parents[i], snapshot.grown.indices.contains(parent) else { break }
            let a: SIMD3<Double> = Geometry.centre(snapshot.grown[parent], snapshot)
            let b: SIMD3<Double> = Geometry.centre(snapshot.grown[i], snapshot)
            groups.append(tubeBox(a, b, radius: Geometry.veinRootRadius * s))
        case .bloom:
            groups.append(square(c, half: Geometry.bloomRadius * s))
        case .fuzz:
            let half: Double = Swift.max(Geometry.fuzzWidth * s, 0.003) / 2 + MyceliumArchitectShaders.fuzzSway
            for tier in tiers {
                for strand in Geometry.fuzzStrands(snapshot, tier: tier) {
                    groups.append(stripCorners(strand.from, strand.to, half: half))
                }
            }
        case .sprout:
            guard snapshot.arrangement.seeds.indices.contains(i) else { break }
            let root: SIMD3<Double> = Geometry.centre(level.root, snapshot)
            let tip: SIMD3<Double> = root + Geometry.planeDirection(snapshot.arrangement.seeds[i])
                * (Geometry.sproutLength * s)
            groups.append(tubeBox(root, tip, radius: Geometry.sproutRootRadius * s))
        case .root:
            let r: Double = Geometry.rootCapRadius * s
            groups.append(box(c - SIMD3<Double>(r, r, 0), c + SIMD3<Double>(r, r, Geometry.capHeight * r)))
        case .terminal:
            groups.append(terminalBox(c, s))
        case .spore:
            let drift: Double = 2 * Swift.max(MyceliumArchitectShaders.sporeDrift, Geometry.sporeDrift)
            for tier in tiers {
                for spore in Geometry.spores(tier) {
                    groups.append(square(spore.centre, half: Geometry.sporeHalf + drift))
                }
            }
        case .gauge:
            let half: Double = Swift.max(Geometry.plateHalf, Geometry.tickHalfHeight)
            groups.append(box(SIMD3<Double>(Geometry.plateLeft, Geometry.gaugeY - half, 0),
                              SIMD3<Double>(Geometry.plateRight, Geometry.gaugeY + half, 0)))
        case .pip:
            groups.append(square(c, half: Geometry.pipHalf))
        case .actions:
            let half: SIMD2<Double> = SIMD2<Double>(Geometry.barFill * Geometry.actionsSlot(snapshot) / 2,
                                                    Geometry.actionsHeight / 2)
            groups.append(horizontalRectangle(c, half: half))
        }
        for group in groups {
            let polygon: [SIMD2<Double>] = hull(group, cam, width: width, height: height)
            if polygon.count >= 3 { f.hulls.append(polygon) }
        }
        return f
    }

    /// The glow's footprint at the richest of `tiers` (the most shells): the outermost shell around the root, every
    /// reached terminal and every shown bloom.
    static func glowFootprint(_ snapshot: Snapshot, tiers: [MyceliumArchitectTier], _ cam: MyceliumArchitectCamera,
                              width: Int, height: Int) -> MyceliumArchitectTestFootprint {
        var f: MyceliumArchitectTestFootprint = MyceliumArchitectTestFootprint()
        var shells: Int = 0
        for tier in tiers { shells = Swift.max(shells, tier.glowShells) }
        guard shells > 0 else { return f }
        let s: Double = snapshot.fitScale
        let grow: Double = Geometry.glowGrowth * s * Double(shells)
        var circles: [(centre: SIMD3<Double>, radius: Double)] = []
        circles.append((Geometry.centre(snapshot.level.root, snapshot), Geometry.rootCapRadius * s + grow))
        for (terminal, cell) in snapshot.level.terminals.enumerated() where snapshot.isReached(terminal) {
            circles.append((Geometry.centre(cell, snapshot), Geometry.terminalCapRadius * s + grow))
        }
        for bloom in Geometry.shownBlooms(snapshot) {
            circles.append((Geometry.centre(bloom.cell, snapshot), Geometry.bloomRadius * s + grow))
        }
        for circle in circles {
            let polygon: [SIMD2<Double>] = hull(horizontalCircle(circle.centre, radius: circle.radius), cam,
                                                width: width, height: height)
            if polygon.count >= 3 { f.hulls.append(polygon) }
        }
        return f
    }

    /// The tiers a layout covers: tier `tier` (clamped), or every tier when nil.
    static func tiers(_ tier: Int?) -> [MyceliumArchitectTier] {
        guard let tier else { return MyceliumArchitectTier.all }
        return [MyceliumArchitectTier.of(tier)]
    }

    /// The painter's order of `snapshot` drawn at `tier` (every tier when nil) on a `width` × `height` target with
    /// every element's footprint and the glow's; empty for an empty target.
    static func layout(_ snapshot: Snapshot, tier: Int? = nil, width: Int = width,
                       height: Int = height) -> MyceliumArchitectTestLayout {
        var result: MyceliumArchitectTestLayout = MyceliumArchitectTestLayout()
        guard width > 0, height > 0 else { return result }
        let cam: MyceliumArchitectCamera = camera(width: width, height: height)
        let drawn: [MyceliumArchitectTier] = tiers(tier)
        result.order = Geometry.paintOrder(snapshot)
        for element in result.order {
            result.footprints.append(footprint(element, snapshot, tiers: drawn, cam, width: width, height: height))
        }
        result.glow = glowFootprint(snapshot, tiers: drawn, cam, width: width, height: height)
        return result
    }

    /// The backdrop's colour coordinates on a `width` × `height` target; nil for an empty target.
    static func backdrop(width: Int = width, height: Int = height) -> MyceliumArchitectTestBackdrop? {
        guard width > 0, height > 0 else { return nil }
        return MyceliumArchitectTestBackdrop(camera: camera(width: width, height: height), width: width,
                                             height: height)
    }

    // MARK: Checks

    /// The backdrop patch check at view fraction (`fx`, `fy`): nil when the patch is not measured (outside the
    /// picture or near a footprint), else the miss in words or "" when it passed.
    static func patchResult(_ rgba: [UInt8], fx: Double, fy: Double, sky: MyceliumArchitectTestBackdrop,
                            _ o: MyceliumArchitectTestLayout, width: Int, height: Int) -> String? {
        let cx: Int = Swift.min(width - 1, Int(fx * Double(width)))
        let cy: Int = Swift.min(height - 1, Int(fy * Double(height)))
        guard cx - patchHalf >= 0, cy - patchHalf >= 0, cx + patchHalf < width, cy + patchHalf < height else {
            return nil
        }
        let p: SIMD2<Double> = SIMD2<Double>(Double(cx) + 0.5, Double(cy) + 0.5)
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

    /// The root cap check of clarification Q3: when the root's centre is clear of every later element, a pixel within
    /// 3 px is brighter than the backdrop there by 0.15; returns whether it was measured.
    static func checkRoot(_ rgba: [UInt8], _ snapshot: Snapshot, _ o: MyceliumArchitectTestLayout,
                          _ sky: MyceliumArchitectTestBackdrop, width: Int, height: Int,
                          misses: inout [String]) -> Bool {
        let point: SIMD3<Double> = Geometry.centre(snapshot.level.root, snapshot)
        guard let p = pixel(point, width: width, height: height), inside(p, width: width, height: height),
              let rank = o.rank(.root, 0), o.isClear(p, after: rank, clearance: clearance) else { return false }
        let floor: Double = luminance(sky.gradient(x: p.x, y: p.y)) + rootMargin
        let bright: Bool = anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height,
                                    where: { (c: SIMD3<Double>) -> Bool in luminance(c) >= floor })
        if !bright {
            let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
            misses.append(String(format: "root centre (%.1f, %.1f) is (%.3f, %.3f, %.3f), floor %.3f", p.x, p.y, c.x,
                                 c.y, c.z, floor))
        }
        return true
    }

    /// The terminal checks of clarification Q3: every terminal whose centre is clear of every later element is, when
    /// reached, brighter than the backdrop there by 0.3, and when not, 0.05 from it in luminance; in the `fallback`,
    /// within 0.1 per channel of its flat colour. Returns how many were measured.
    static func checkTerminals(_ rgba: [UInt8], _ snapshot: Snapshot, _ o: MyceliumArchitectTestLayout,
                               _ sky: MyceliumArchitectTestBackdrop, fallback: Bool, width: Int, height: Int,
                               misses: inout [String]) -> Int {
        var measured: Int = 0
        for (index, cell) in snapshot.level.terminals.enumerated() {
            let point: SIMD3<Double> = Geometry.centre(cell, snapshot)
            guard let p = pixel(point, width: width, height: height), inside(p, width: width, height: height),
                  let rank = o.rank(.terminal, index), o.isClear(p, after: rank, clearance: clearance) else { continue }
            measured += 1
            let reached: Bool = snapshot.isReached(index)
            let back: Double = luminance(sky.gradient(x: p.x, y: p.y))
            var passed: Bool = false
            var rule: String = ""
            if fallback {
                let flat: SIMD3<Double> = rgb(reached ? Palette.capOpen : Palette.capClosed)
                rule = reached ? "flat cap open" : "flat cap closed"
                passed = anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height,
                                  where: { (c: SIMD3<Double>) -> Bool in channelDistance(c, flat) <= colourTolerance })
            } else if reached {
                rule = String(format: "brighter than %.3f", back + reachedMargin)
                passed = anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height,
                                  where: { (c: SIMD3<Double>) -> Bool in luminance(c) >= back + reachedMargin })
            } else {
                rule = String(format: "%.2f from %.3f", unreachedMargin, back)
                passed = anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height,
                                  where: { (c: SIMD3<Double>) -> Bool in
                                      Swift.abs(luminance(c) - back) >= unreachedMargin
                                  })
            }
            if !passed {
                let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
                misses.append(String(format: "terminal %ld centre (%.1f, %.1f) is (%.3f, %.3f, %.3f), want ", index,
                                     p.x, p.y, c.x, c.y, c.z) + rule)
            }
        }
        return measured
    }

    /// The actions bar and gauge margin checks of clarification Q3 on `rgba` against `snapshot`, added to `report`.
    static func checkCues(_ rgba: [UInt8], _ snapshot: Snapshot, _ o: MyceliumArchitectTestLayout,
                          _ sky: MyceliumArchitectTestBackdrop, width: Int, height: Int,
                          into report: inout MyceliumArchitectCheckReport) {
        if Geometry.litActions(snapshot) > 0,
           let p = pixel(Geometry.actionsBar(0, snapshot), width: width, height: height),
           inside(p, width: width, height: height), let rank = o.rank(.actions, 0),
           o.isClear(p, after: rank, clearance: clearance) {
            report.barChecked = true
            if !anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height, where: isCopper) {
                let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
                report.misses.append(String(format: "actions bar 0 (%.1f, %.1f) is (%.3f, %.3f, %.3f)", p.x, p.y,
                                            c.x, c.y, c.z))
            }
        }
        if let p = pixel(Geometry.gaugeMargin, width: width, height: height),
           inside(p, width: width, height: height), let rank = o.rank(.gauge, 0),
           o.isClear(p, after: rank, clearance: clearance) {
            report.marginChecked = true
            let back: Double = luminance(sky.gradient(x: p.x, y: p.y))
            let off: Bool = anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height,
                                     where: { (c: SIMD3<Double>) -> Bool in
                                         Swift.abs(luminance(c) - back) >= marginDifference
                                     })
            if !off {
                report.misses.append(String(format: "weight plate margin (%.1f, %.1f) is backdrop-coloured", p.x,
                                            p.y))
            }
        }
    }

    /// The point checks of clarification Q3 (see the file header) on `rgba` against `snapshot` drawn at `tier`
    /// (`fallback`: the unlit flat colours).
    static func pointReport(_ rgba: [UInt8], snapshot: Snapshot, tier: Int?, fallback: Bool = false,
                            width: Int = width, height: Int = height) -> MyceliumArchitectCheckReport {
        var report: MyceliumArchitectCheckReport = MyceliumArchitectCheckReport()
        let o: MyceliumArchitectTestLayout = layout(snapshot, tier: tier, width: width, height: height)
        guard let sky = backdrop(width: width, height: height) else {
            report.misses.append("an empty target")
            return report
        }
        var misses: [String] = []
        report.rootChecked = checkRoot(rgba, snapshot, o, sky, width: width, height: height, misses: &misses)
        report.terminalsChecked = checkTerminals(rgba, snapshot, o, sky, fallback: fallback, width: width,
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
    /// tier; `fallback`: the unlit flat colours), recording an issue per failure, and returns the report. The root or
    /// a terminal must be measured, as must the weight plate's margin and (when lit) the first actions bar; a picture
    /// of at least 256 × 256 must measure both lower corner patches.
    @discardableResult
    static func checkFrame(_ rgba: [UInt8], snapshot: Snapshot, tier: Int?, fallback: Bool = false,
                           width: Int = width, height: Int = height, _ what: String,
                           sourceLocation: SourceLocation = #_sourceLocation) -> MyceliumArchitectCheckReport {
        #expect(rgba.count == width * height * 4, "\(what): picture size", sourceLocation: sourceLocation)
        guard rgba.count == width * height * 4 else { return MyceliumArchitectCheckReport() }
        let report: MyceliumArchitectCheckReport = pointReport(rgba, snapshot: snapshot, tier: tier,
                                                               fallback: fallback, width: width, height: height)
        #expect(report.capChecked, "\(what): neither the root nor a terminal centre was clear",
                sourceLocation: sourceLocation)
        #expect(report.marginChecked, "\(what): the weight plate's margin was not clear",
                sourceLocation: sourceLocation)
        if Geometry.litActions(snapshot) > 0 {
            #expect(report.barChecked, "\(what): the first actions bar was not clear", sourceLocation: sourceLocation)
        }
        if width >= 256 && height >= 256 {
            #expect(report.lowerPatchesChecked == 2, "\(what): lower corner patches \(report.lowerPatchesChecked)",
                    sourceLocation: sourceLocation)
        }
        let shown: [String] = Array(report.misses.prefix(8))
        #expect(report.misses.isEmpty, "\(what): \(shown)", sourceLocation: sourceLocation)
        print("mycelium-architect \(what): root \(report.rootChecked); terminals \(report.terminalsChecked) of "
              + "\(snapshot.level.terminals.count); bar \(report.barChecked); margin \(report.marginChecked); patches "
              + "\(report.patchesChecked) (lower \(report.lowerPatchesChecked))")
        return report
    }
}
#endif
