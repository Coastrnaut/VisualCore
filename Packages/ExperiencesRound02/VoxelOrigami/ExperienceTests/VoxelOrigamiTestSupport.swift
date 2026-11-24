// VoxelOrigamiTestSupport — feature 443 (R02-G15-03) T-R02G1503-006 (FR-R02G1503-001 … 007; SC-R02G1503-001, 002;
// clarifications Q1–Q5). Shared helpers of the Voxel Origami experience tests, following Moonlit Mechanism's harness
// (feature 433): opening the experience through the one app's session host (seed `s` prepares certified level
// `s % 100 + 1`; a session without a quality pin is pinned to level 0), issuing kernel actions through the shell,
// drawing live frames, drawing an off-screen still (RGBA8, rows top-down, the orientation of the Core's CPU projection
// `VoxelOrigamiSceneGeometry.project`, origin top left, y down, scaled here to pixels), the engine digest, the frame
// checks of clarification Q3 at 1,152 × 768, and a short search of the kernel's rules for a turn that fails a level
// with a collision or a sweep.
//
// The presenter hands the snapshot the seconds since the play last changed, and neither program has a time input, so a
// still drawn at frame time 0 shows presentation time 0.
//
// The CPU reference: every cube's centre, every hinge mark's centre, the first covered pip and the first moves bar,
// projected through the camera at the target's aspect, with the painter's order of `VoxelOrigamiSceneGeometry
// .paintOrder` (farthest first). Every element's footprint is projected exactly as the geometry builds it, the same at
// every tier (a target wireframe's edges at the widest tier width 0.06 s): a cube's box of side 0.9 s (a lattice
// rotation keeps the box), plus a failure's wireframe of side 1.0 s and the cross over the still cube's cell; a target
// wireframe's 12 edges of side 0.96 s; a hinge bar 0.6 s × 0.12 s facing the eye; a pip's and a bar's camera-facing
// rectangle. A point is checked only when it projects into the picture at least 6 px from every element drawn after it
// that could hide its cue:
//   - a cube's centre: 6 px from every later cube (whose dots and hollow glyphs are dark), pip and bar, and 6 px from
//     its own dots (on its own +z face, when that face looks at the eye) and its own glyph diamonds (on its faces that
//     look at the eye). Later target wireframes (turquoise, luminance 0.74), hinge bars (grey 0.48, hot pink 0.42) and
//     failure outlines (0.53) are brighter than the night (0.05) by more than the bound, so they keep the cue. Within
//     3 px a pixel is brighter than the night by at least 0.25 in luminance (the frosted ivory is lit at least 0.55);
//   - the chosen hinge: its centre or, when that is hidden (the nearer of its two cubes is painted after it), the
//     centre of one of its other hot-pink stripes (local −0.4, 0.4, −0.8, 0.8 along the bar, the stripes of
//     `VoxelOrigamiShaders.stripeCoverage`), 6 px from every later element, and where the additive glow drawn last
//     can add at most 0.35 of blue at level-0 (`glowBlueBound`: every lit cube's and target cell's shell band within
//     6 px at its full alpha; the pink's red is already 1). Within 3 px a pixel has red above blue by at least 0.08
//     (#FF3C8C has 0.45);
//   - the first moves bar: 6 px from every later element; within 3 px a pixel at least 0.1 from the night in
//     luminance (lit #2EE6D6 or unlit #2A2D3A, 0.12 above the night; the additive glow only brightens);
//   - the two probe corners (0.02, 0.02) and (0.98, 0.98) of the view are within 0.05 per channel of the night.
// Luminance is the Rec. 709 weighting of the stored 0 … 1 channel values. Positions come from the presenter's
// `lastSnapshot` (the snapshot it drew). Short runs only (no sleep, no wall-clock assertion).
//
// The checked levels are catalog levels 1, 21, 41, 61 and 100 (seeds 0, 20, 40, 60, 99).
#if os(iOS)
import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import VoxelOrigamiExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VoxelOrigamiCore

/// What the point checks of one frame found.
struct VoxelOrigamiCheckReport {
    /// The cube centres measured and those left out by the 6-pixel clearance.
    var cubeChecked: Int = 0
    var cubeExcluded: Int = 0
    /// Whether a point of the chosen hinge was measured.
    var hingeChecked: Bool = false
    /// Whether the first moves bar was measured.
    var movesChecked: Bool = false
    /// Every failed check, in words.
    var misses: [String] = []
}

/// A projected strip: the segment `a` … `b` grown by `half` pixels.
struct VoxelOrigamiCapsule {
    var a: SIMD2<Double>
    var b: SIMD2<Double>
    var half: Double
}

/// The projected footprint of one drawn element (pixels, y down): convex hulls and capsules.
struct VoxelOrigamiFootprint {
    var hulls: [[SIMD2<Double>]] = []
    var capsules: [VoxelOrigamiCapsule] = []

    /// The signed distance (pixels) of `p` from the footprint: negative inside, infinite for an empty footprint.
    func distance(_ p: SIMD2<Double>) -> Double {
        var best: Double = Double.infinity
        for hull in hulls { best = Swift.min(best, VoxelOrigamiTest.hullDistance(hull, p)) }
        for capsule in capsules {
            best = Swift.min(best, VoxelOrigamiTest.segmentDistance(p, capsule.a, capsule.b) - capsule.half)
        }
        return best
    }
}

/// The painter's order of one snapshot on one target with every element's footprint (same indices).
struct VoxelOrigamiLayout {
    var order: [VoxelOrigamiElement] = []
    var footprints: [VoxelOrigamiFootprint] = []

    /// The place of element (`kind`, `index`) in the painter's order, or nil.
    func rank(_ kind: VoxelOrigamiElement.Kind, _ index: Int) -> Int? {
        for (place, element) in order.enumerated() where element.kind == kind && element.index == index {
            return place
        }
        return nil
    }

    /// Whether `p` lies at least `clearance` pixels from every element painted after place `rank` whose kind is in
    /// `kinds`.
    func isClear(_ p: SIMD2<Double>, after rank: Int, kinds: Set<VoxelOrigamiElement.Kind>,
                 clearance: Double) -> Bool {
        var place: Int = rank + 1
        while place < order.count {
            if kinds.contains(order[place].kind), footprints[place].distance(p) < clearance { return false }
            place += 1
        }
        return true
    }
}

/// Building, opening, drawing and measuring Voxel Origami.
@MainActor
enum VoxelOrigamiTest {
    typealias Geometry = VoxelOrigamiSceneGeometry
    typealias Palette = VoxelOrigamiPalette
    typealias Snapshot = VoxelOrigamiSceneSnapshot
    typealias Shell = ExperienceShell<VoxelOrigamiPresenter>
    typealias Kind = VoxelOrigamiElement.Kind

    /// The experience id `r02-g15.voxel-origami`.
    static var id: ExperienceID {
        VoxelOrigamiExperience.id ?? ExperienceID(rawValue: "r02-g15.unknown")!
    }

    /// The frame-check size of clarification Q3, aspect 1.5.
    static let width: Int = 1_152
    static let height: Int = 768
    /// The seeds of the checked levels 1, 21, 41, 61 and 100 (seed = level − 1).
    static let seeds: [UInt64] = [0, 20, 40, 60, 99]
    /// The search radius (pixels) of the point checks.
    static let pointRadius: Double = 3
    /// The clearance (pixels) of every checked point from every element drawn after it.
    static let clearance: Double = 6
    /// A cube's centre is brighter than the night by at least this luminance.
    static let cubeMargin: Double = 0.25
    /// The chosen hinge's red above blue.
    static let hingeHue: Double = 0.08
    /// The first moves bar's luminance difference from the night.
    static let movesMargin: Double = 0.1
    /// The per-channel bound of the night backdrop.
    static let backgroundTolerance: Double = 0.05
    /// The night probe points (fractions of the view, origin top left).
    static let backgroundPoints: [(x: Double, y: Double)] = [(0.02, 0.02), (0.98, 0.98)]
    /// The red-minus-green rise of an outline pixel over the frame before the failure.
    static let outlineRise: Double = 0.05
    /// The local coordinates along the chosen hinge's bar of its hot-pink stripe centres, the bar's centre first.
    static let stripeCentres: [Double] = [0, -0.4, 0.4, -0.8, 0.8]
    /// The kinds of later element that can hide a cube's centre (see the file header).
    static let cubeHiders: Set<Kind> = [.cube, .pip, .bar]
    /// Every kind (the hinge and moves checks and the failure outline).
    static let allKinds: Set<Kind> = Set(Kind.allCases)

    /// Opens Voxel Origami with `seed` in `session` through the factory, lays the view out at `size` points and draws
    /// one frame. A session without a quality pin is pinned to level 0. `configure` runs on the presenter before its
    /// first `setup` (the fallback seam).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false, size: CGSize = CGSize(width: 48, height: 32),
                     configure: ((VoxelOrigamiPresenter) -> Void)? = nil) async throws -> Shell {
        let id: ExperienceID = self.id
        var made: Shell?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: seed) {
            let shell: Shell = VoxelOrigamiExperience.make(id: id, reduceMotion: reduceMotion,
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
    static func core(_ shell: Shell) throws -> VoxelOrigamiExperienceCore {
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
    nonisolated static func control(_ action: VoxelOrigamiAction) -> (control: String, values: [Double]) {
        switch action {
        case let .turn(hinge, step):
            ("hinge.turn", [Double(hinge), Double(step)])
        }
    }

    /// The host action of `action` (step 0).
    nonisolated static func experienceAction(_ action: VoxelOrigamiAction) -> ExperienceAction {
        let issued = control(action)
        return ExperienceAction(control: issued.control, values: issued.values, step: 0)
    }

    /// The certified plan of level `number`: its minimal winning turns.
    nonisolated static func certifiedTurns(_ number: Int) throws -> [VoxelOrigamiAction] {
        try VoxelOrigamiExperienceCore.generated(number: number).plan.turns
    }

    /// Issues `actions` through the shell, each expected to be accepted; returns how many were.
    @discardableResult
    static func issue(_ shell: Shell, _ actions: [VoxelOrigamiAction],
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
    static func coreAfter(_ number: Int, _ actions: [VoxelOrigamiAction]) throws -> VoxelOrigamiExperienceCore {
        var core: VoxelOrigamiExperienceCore = try VoxelOrigamiExperienceCore.opening(number: number)
        for action in actions {
            let result: ActionResult = core.apply(experienceAction(action))
            #expect(result == .accepted, "level \(number) \(action): \(result.code)")
        }
        return core
    }

    /// Whether `failure` is a turn the lattice check refused (a collision or a sweep).
    nonisolated static func isTurnFailure(_ failure: VoxelOrigamiFailure?) -> Bool {
        switch failure {
        case .collision?, .sweep?: true
        default: false
        }
    }

    /// The first set-up over `candidates` (level numbers) of at most `maxDepth` − 1 clear turns followed by a turn
    /// the kernel refuses with a collision or a sweep, found breadth first through the adapter, whose outlines have at
    /// least two clear sample points on each of the moving and the still cube: the level, the set-up, the failing turn
    /// and the samples.
    static func failureCase(candidates: [Int], maxDepth: Int) throws
        -> (number: Int, setUp: [VoxelOrigamiAction], failing: VoxelOrigamiAction,
            moving: [SIMD2<Double>], still: [SIMD2<Double>])? {
        let steps: [Int] = [1, -1]
        for number in candidates {
            let opening: VoxelOrigamiExperienceCore = try VoxelOrigamiExperienceCore.opening(number: number)
            var frontier: [(core: VoxelOrigamiExperienceCore, actions: [VoxelOrigamiAction])] = [(opening, [])]
            for _ in 0..<maxDepth {
                var next: [(core: VoxelOrigamiExperienceCore, actions: [VoxelOrigamiAction])] = []
                for item in frontier {
                    let turnable: [Int] = item.core.snapshot(time: 0).turnable
                    for hinge in turnable {
                        for step in steps {
                            var core: VoxelOrigamiExperienceCore = item.core
                            let action = VoxelOrigamiAction.turn(hinge, step)
                            guard core.apply(experienceAction(action)) == .accepted else { continue }
                            if core.play.stage == .failed, isTurnFailure(core.play.failure) {
                                let samples = failureSamples(core.snapshot(time: 0))
                                if samples.moving.count >= 2, samples.still.count >= 2 {
                                    return (number, item.actions, action, samples.moving, samples.still)
                                }
                            } else if core.play.stage == .playing, next.count < 64 {
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

    /// The luminance of the night.
    static var nightLuminance: Double { luminance(Palette.night) }

    /// Whether `c` is brighter than the night by at least 0.25 in luminance (a cube).
    static func isCubeBright(_ c: SIMD3<Double>) -> Bool {
        luminance(c) - nightLuminance >= cubeMargin
    }

    /// Whether `c` is hot pink enough: red above blue by at least 0.08.
    static func isPink(_ c: SIMD3<Double>) -> Bool {
        c.x - c.z >= hingeHue
    }

    /// Whether `c` is at least 0.1 from the night in luminance.
    static func isOffNight(_ c: SIMD3<Double>) -> Bool {
        Swift.abs(luminance(c) - nightLuminance) >= movesMargin
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

    /// The authored view's right and up vectors (from the geometry's eye towards its look-at point, +y up), as the
    /// geometry's camera-facing rectangles use them.
    nonisolated static func viewBasis() -> (right: SIMD3<Double>, up: SIMD3<Double>) {
        let forward: SIMD3<Double> = unit3(VoxelOrigamiSceneGeometry.lookAt - VoxelOrigamiSceneGeometry.eye)
        let right: SIMD3<Double> = unit3(cross3(forward, SIMD3<Double>(0, 1, 0)))
        return (right, cross3(right, forward))
    }

    /// The world axis vector of the lattice vector `v`.
    nonisolated static func vector(_ v: VoxelOrigamiVector) -> SIMD3<Double> {
        SIMD3<Double>(Double(v.x), Double(v.y), Double(v.z))
    }

    // MARK: CPU reference (clarification Q3)

    /// The camera the scene uses for `snapshot` on a `width` × `height` target.
    static func camera(_ snapshot: Snapshot, width: Int, height: Int) -> VoxelOrigamiCamera {
        Geometry.camera(snapshot, aspect: Double(width) / Double(height))
    }

    /// The pixel of world point `point` through `camera` on a `width` × `height` target (nil without a projection).
    static func project(_ point: SIMD3<Double>, _ camera: VoxelOrigamiCamera, width: Int,
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

    /// The world reference points of `snapshot` in a fixed order, none depending on the tier or the time: cube centres
    /// (cube order), hinge centres (hinge 1 … n − 1), the first covered pip, the first moves bar.
    static func referenceWorldPoints(_ snapshot: Snapshot) -> [SIMD3<Double>] {
        var points: [SIMD3<Double>] = []
        for index in snapshot.cells.indices { points.append(Geometry.cubeCentre(index, snapshot)) }
        if snapshot.cubes.count > 1 {
            for hinge in 1..<snapshot.cubes.count { points.append(Geometry.hingeCentre(hinge, snapshot)) }
        }
        points.append(Geometry.coveredPip(0, snapshot))
        points.append(Geometry.movesBar(0, snapshot))
        return points
    }

    /// The pixels of `referenceWorldPoints(snapshot)`, in that order (nil without a projection).
    static func referencePixels(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> [SIMD2<Double>?] {
        var result: [SIMD2<Double>?] = []
        guard width > 0, height > 0 else { return result }
        let cam: VoxelOrigamiCamera = camera(snapshot, width: width, height: height)
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
    static func pixelLength(_ length: Double, at centre: SIMD3<Double>, _ camera: VoxelOrigamiCamera, width: Int,
                            height: Int) -> Double {
        let right: SIMD3<Double> = viewBasis().right
        guard let a = project(centre, camera, width: width, height: height),
              let b = project(centre + right * length, camera, width: width, height: height) else {
            return 0
        }
        let d: SIMD2<Double> = b - a
        return (d.x * d.x + d.y * d.y).squareRoot()
    }

    /// The hull of the projected world points `points`.
    static func hull(_ points: [SIMD3<Double>], _ camera: VoxelOrigamiCamera, width: Int,
                     height: Int) -> [SIMD2<Double>] {
        var projected: [SIMD2<Double>] = []
        for point in points {
            if let p = project(point, camera, width: width, height: height) { projected.append(p) }
        }
        return convexHull(projected)
    }

    /// The 8 corners of the axis-aligned box of half side `half` around `centre`.
    nonisolated static func boxCorners(_ centre: SIMD3<Double>, half: Double) -> [SIMD3<Double>] {
        var corners: [SIMD3<Double>] = []
        for index in 0..<8 {
            let x: Double = index & 1 == 0 ? -half : half
            let y: Double = index & 2 == 0 ? -half : half
            let z: Double = index & 4 == 0 ? -half : half
            corners.append(centre + SIMD3<Double>(x, y, z))
        }
        return corners
    }

    /// The 12 edges of the axis-aligned box of half side `half` around `centre`, as projected capsules of half width
    /// `halfWidth` (world units).
    static func wireCapsules(_ centre: SIMD3<Double>, half: Double, halfWidth: Double, _ camera: VoxelOrigamiCamera,
                             width: Int, height: Int) -> [VoxelOrigamiCapsule] {
        let corners: [SIMD3<Double>] = boxCorners(centre, half: half)
        let bits: [Int] = [1, 2, 4]
        var result: [VoxelOrigamiCapsule] = []
        for a in 0..<8 {
            for bit in bits where a & bit == 0 {
                let b: Int = a | bit
                guard let pa = project(corners[a], camera, width: width, height: height),
                      let pb = project(corners[b], camera, width: width, height: height) else { continue }
                let middle: SIMD3<Double> = (corners[a] + corners[b]) / 2
                let w: Double = pixelLength(halfWidth, at: middle, camera, width: width, height: height)
                result.append(VoxelOrigamiCapsule(a: pa, b: pb, half: w))
            }
        }
        return result
    }

    /// The hull of the camera-facing strip of `width` world units from `a` to `b`, as the geometry's `facingStrip`
    /// builds it (empty for a degenerate strip).
    static func stripHull(_ a: SIMD3<Double>, _ b: SIMD3<Double>, stripWidth: Double, _ camera: VoxelOrigamiCamera,
                          width: Int, height: Int) -> [SIMD2<Double>] {
        let direction: SIMD3<Double> = b - a
        guard dot3(direction, direction) > 0 else { return [] }
        var towards: SIMD3<Double> = unit3(VoxelOrigamiSceneGeometry.eye - (a + b) / 2)
        if dot3(towards, towards) == 0 { towards = SIMD3<Double>(0, 0, 1) }
        var side: SIMD3<Double> = unit3(cross3(direction, towards))
        if dot3(side, side) == 0 { side = viewBasis().right }
        let w: SIMD3<Double> = side * (stripWidth / 2)
        return hull([a + w, b + w, b - w, a - w], camera, width: width, height: height)
    }

    /// The hull of the camera-facing rectangle of half sizes `half` around `centre`.
    static func billboardHull(_ centre: SIMD3<Double>, half: SIMD2<Double>, _ camera: VoxelOrigamiCamera, width: Int,
                              height: Int) -> [SIMD2<Double>] {
        let basis = viewBasis()
        let r: SIMD3<Double> = basis.right * half.x
        let u: SIMD3<Double> = basis.up * half.y
        return hull([centre - r - u, centre + r - u, centre + r + u, centre - r + u], camera, width: width,
                    height: height)
    }

    /// The widest target edge of every tier, in s (the footprints are the same at every tier).
    static var widestEdge: Double {
        var widest: Double = 0
        for tier in VoxelOrigamiTier.all { widest = Swift.max(widest, tier.edgeWidth) }
        return widest
    }

    /// The painter's order of `snapshot` on a `width` × `height` target with every element's footprint (see the file
    /// header); empty for an empty target.
    static func layout(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> VoxelOrigamiLayout {
        var result = VoxelOrigamiLayout()
        guard width > 0, height > 0 else { return result }
        let cam: VoxelOrigamiCamera = camera(snapshot, width: width, height: height)
        let s: Double = Geometry.scale(snapshot)
        let basis = viewBasis()
        let broken = snapshot.brokenTurn
        result.order = Geometry.paintOrder(snapshot, camera: cam)
        for element in result.order {
            var footprint = VoxelOrigamiFootprint()
            switch element.kind {
            case .targetOutline:
                footprint.capsules = wireCapsules(element.centre, half: Geometry.targetSide * s / 2,
                                                  halfWidth: widestEdge * s / 2, cam, width: width, height: height)
            case .cube:
                let i: Int = element.index
                footprint.hulls.append(hull(boxCorners(element.centre, half: Geometry.cubeSide * s / 2), cam,
                                            width: width, height: height))
                if let b = broken, b.moving == i || b.still == i {
                    footprint.capsules = wireCapsules(element.centre, half: Geometry.brokenSide * s / 2,
                                                      halfWidth: Geometry.brokenWidth * s / 2, cam, width: width,
                                                      height: height)
                }
                if let b = broken, b.still == i {
                    let mark: SIMD3<Double> = Geometry.world(b.cell, snapshot)
                    let r: Double = Geometry.markLength * s / 2 / 2.0.squareRoot()
                    let up: SIMD3<Double> = basis.up
                    let right: SIMD3<Double> = basis.right
                    footprint.hulls.append(stripHull(mark + (up * -1 - right) * r, mark + (up + right) * r,
                                                     stripWidth: Geometry.markWidth * s, cam, width: width,
                                                     height: height))
                    footprint.hulls.append(stripHull(mark + (up - right) * r, mark + (right - up) * r,
                                                     stripWidth: Geometry.markWidth * s, cam, width: width,
                                                     height: height))
                }
            case .hinge:
                let axis: SIMD3<Double> = Geometry.hingeAxis(element.index, snapshot)
                let reach: SIMD3<Double> = axis * (Geometry.hingeLength * s / 2)
                footprint.hulls.append(stripHull(element.centre - reach, element.centre + reach,
                                                 stripWidth: Geometry.hingeWidth * s, cam, width: width,
                                                 height: height))
            case .pip:
                let side: Double = Geometry.pipSide(snapshot) / 2
                footprint.hulls.append(billboardHull(element.centre, half: SIMD2<Double>(side, side), cam,
                                                     width: width, height: height))
            case .bar:
                let half = SIMD2<Double>(Geometry.barFill * Geometry.movesSlot(snapshot) / 2, Geometry.barHeight / 2)
                footprint.hulls.append(billboardHull(element.centre, half: half, cam, width: width, height: height))
            }
            result.footprints.append(footprint)
        }
        return result
    }

    /// The footprints of cube `index`'s own decorations drawn over its faces: its dice dots (the square they fill on
    /// its own +z face, when that face looks at the eye) and its glyph diamonds (on every face that looks at the eye).
    static func ownDecorations(_ index: Int, _ snapshot: Snapshot, width: Int = width,
                               height: Int = height) -> [[SIMD2<Double>]] {
        let cam: VoxelOrigamiCamera = camera(snapshot, width: width, height: height)
        let s: Double = Geometry.scale(snapshot)
        let half: Double = Geometry.cubeSide * s / 2
        let c: SIMD3<Double> = Geometry.cubeCentre(index, snapshot)
        let axes: [SIMD3<Double>] = [SIMD3<Double>(1, 0, 0), SIMD3<Double>(0, 1, 0), SIMD3<Double>(0, 0, 1)]
        var result: [[SIMD2<Double>]] = []
        // Glyph diamonds: a lattice rotation keeps the faces on the world axes, with the diamond's corners on the two
        // world axes of the face.
        for axis in 0..<3 {
            for sign in [-1.0, 1.0] {
                let n: SIMD3<Double> = axes[axis] * sign
                let face: SIMD3<Double> = c + n * half
                guard dot3(n, VoxelOrigamiSceneGeometry.eye - face) > 0 else { continue }
                let u: SIMD3<Double> = axes[(axis + 1) % 3] * (Geometry.glyphRadius * s)
                let v: SIMD3<Double> = axes[(axis + 2) % 3] * (Geometry.glyphRadius * s)
                result.append(hull([face + u, face + v, face - u, face - v], cam, width: width, height: height))
            }
        }
        // Dots: on the cube's own +z face, turned by its orientation.
        guard index >= 0, index < snapshot.orientations.count else { return result }
        let turned: VoxelOrigamiVector = snapshot.orientations[index].applied(to: VoxelOrigamiVector(0, 0, 1))
        let n: SIMD3<Double> = vector(turned)
        let face: SIMD3<Double> = c + n * half
        guard dot3(n, VoxelOrigamiSceneGeometry.eye - face) > 0 else { return result }
        var others: [SIMD3<Double>] = []
        for axis in axes where Swift.abs(dot3(axis, n)) < 0.5 { others.append(axis) }
        guard others.count == 2 else { return result }
        let reach: Double = (Geometry.dotSpacing + Geometry.dotRadius) * s
        let e1: SIMD3<Double> = others[0] * reach
        let e2: SIMD3<Double> = others[1] * reach
        result.append(hull([face - e1 - e2, face + e1 - e2, face + e1 + e2, face - e1 + e2], cam, width: width,
                           height: height))
        return result
    }

    /// Whether cube `index`'s centre pixel `p` is clear (see the file header).
    static func isCubeClear(_ index: Int, _ p: SIMD2<Double>, _ snapshot: Snapshot, _ layout: VoxelOrigamiLayout,
                            width: Int, height: Int) -> Bool {
        guard let rank = layout.rank(.cube, index) else { return false }
        guard layout.isClear(p, after: rank, kinds: cubeHiders, clearance: clearance) else { return false }
        for decoration in ownDecorations(index, snapshot, width: width, height: height)
        where hullDistance(decoration, p) < clearance {
            return false
        }
        return true
    }

    /// The cubes of `snapshot` whose centres are clear (cube and pixel), in cube order.
    static func clearCubes(_ snapshot: Snapshot, width: Int = width,
                           height: Int = height) -> [(cube: Int, p: SIMD2<Double>)] {
        let o: VoxelOrigamiLayout = layout(snapshot, width: width, height: height)
        var result: [(cube: Int, p: SIMD2<Double>)] = []
        for index in snapshot.cells.indices {
            guard let p = pixel(Geometry.cubeCentre(index, snapshot), snapshot, width: width, height: height),
                  inside(p, width: width, height: height),
                  isCubeClear(index, p, snapshot, o, width: width, height: height) else { continue }
            result.append((index, p))
        }
        return result
    }

    /// The world point at local coordinate `local` (−1 parent end … +1 cube end) along hinge `hinge`'s bar.
    static func hingePoint(_ hinge: Int, local: Double, _ snapshot: Snapshot) -> SIMD3<Double> {
        let s: Double = Geometry.scale(snapshot)
        return Geometry.hingeCentre(hinge, snapshot)
            + Geometry.hingeAxis(hinge, snapshot) * (local * Geometry.hingeLength * s / 2)
    }

    /// The first clear point of the chosen hinge: its centre, else another hot-pink stripe centre (pixel and local
    /// coordinate), or nil.
    static func clearHingePoint(_ snapshot: Snapshot, _ layout: VoxelOrigamiLayout, width: Int = width,
                                height: Int = height) -> (p: SIMD2<Double>, local: Double)? {
        guard snapshot.cubes.count > 1, let rank = layout.rank(.hinge, snapshot.chosenHinge) else { return nil }
        for local in stripeCentres {
            guard let p = pixel(hingePoint(snapshot.chosenHinge, local: local, snapshot), snapshot, width: width,
                                height: height),
                  inside(p, width: width, height: height),
                  layout.isClear(p, after: rank, kinds: allKinds, clearance: clearance),
                  glowBlueBound(p, snapshot, width: width, height: height) <= hingeGlowAllowance else { continue }
            return (p, local)
        }
        return nil
    }

    /// The most blue the additive glow may add over a hot-pink hinge pixel and keep red above blue by 0.08 with 0.02
    /// to spare: the pink's red is already 1, its blue 0x8C / 255.
    static var hingeGlowAllowance: Double { 1 - Palette.hingeChosen.z - hingeHue - 0.02 }

    /// An upper bound of the blue the glow adds at pixel `p` at the richest tier (level-0: gain 1.5, two shells, the
    /// target shells at 0.4 of their factor unless the level is won): every shell band (between the camera-facing
    /// squares of the object's inner half size and that grown by k growths) of every lit cube and every target cell
    /// that comes within 6 px of `p` adds its full alpha 0.5 · gain · 0.5^k (the fade taken as 1) times its colour's
    /// blue. The same bound serves every tier, so the same hinge points are measured at every tier.
    static func glowBlueBound(_ p: SIMD2<Double>, _ snapshot: Snapshot, width: Int = width,
                              height: Int = height) -> Double {
        let cam: VoxelOrigamiCamera = camera(snapshot, width: width, height: height)
        let s: Double = Geometry.scale(snapshot)
        let best: VoxelOrigamiTier = VoxelOrigamiTier.all[0]
        let gain: Double = VoxelOrigamiShaders.glowGain(for: best)
        let targetShare: Double = Geometry.wonFlag(snapshot) == 1 ? 1 : VoxelOrigamiShaders.targetRest
        var objects: [(centre: SIMD3<Double>, inner: Double, growth: Double, blue: Double)] = []
        for cell in snapshot.target {
            objects.append((Geometry.world(cell, snapshot), Geometry.targetGlowInner * s, Geometry.targetGlowGrowth * s,
                            Palette.targetGlow.z * targetShare))
        }
        for index in snapshot.cells.indices where Geometry.isLit(index, snapshot) {
            objects.append((Geometry.cubeCentre(index, snapshot), Geometry.cubeGlowInner * s,
                            Geometry.cubeGlowGrowth * s, Palette.glow.z))
        }
        var total: Double = 0
        for object in objects {
            let inner: [SIMD2<Double>] = billboardHull(object.centre, half: SIMD2<Double>(object.inner, object.inner),
                                                       cam, width: width, height: height)
            guard hullDistance(inner, p) > -clearance else { continue }
            for k in 1...Swift.max(best.glowShells, 1) {
                let h: Double = object.inner + object.growth * Double(k)
                let outer: [SIMD2<Double>] = billboardHull(object.centre, half: SIMD2<Double>(h, h), cam,
                                                           width: width, height: height)
                guard hullDistance(outer, p) < clearance else { continue }
                total += VoxelOrigamiShaders.glowWeight * gain * pow(Geometry.glowWeight, Double(k)) * object.blue
            }
        }
        return total
    }

    /// The first hinge of `core`'s play (the chosen one first, then 1 … n − 1) whose chosen bar has a clear point at
    /// the check size, or nil.
    static func measurableHinge(_ core: VoxelOrigamiExperienceCore) -> Int? {
        let count: Int = core.play.level.cubes.count
        guard count > 1 else { return nil }
        var hinges: [Int] = [core.chosenHinge]
        for hinge in 1..<count where hinge != core.chosenHinge { hinges.append(hinge) }
        for hinge in hinges {
            let snapshot = VoxelOrigamiSceneSnapshot(play: core.play, chosenHinge: hinge, levelNumber: core.levelNumber,
                                                     time: 0)
            if clearHingePoint(snapshot, layout(snapshot)) != nil { return hinge }
        }
        return nil
    }

    /// The point checks of clarification Q3 (see the file header) on `rgba` against `snapshot`.
    static func pointReport(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width,
                            height: Int = height) -> VoxelOrigamiCheckReport {
        var report = VoxelOrigamiCheckReport()
        let o: VoxelOrigamiLayout = layout(snapshot, width: width, height: height)
        for index in snapshot.cells.indices {
            guard let p = pixel(Geometry.cubeCentre(index, snapshot), snapshot, width: width, height: height),
                  inside(p, width: width, height: height) else {
                report.misses.append("cube \(index): it does not project into the picture")
                continue
            }
            if !isCubeClear(index, p, snapshot, o, width: width, height: height) {
                report.cubeExcluded += 1
                continue
            }
            report.cubeChecked += 1
            if !anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height, where: isCubeBright) {
                let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
                report.misses.append(String(format: "cube %ld (%.1f, %.1f) is (%.3f, %.3f, %.3f)", index, p.x, p.y,
                                            c.x, c.y, c.z))
            }
        }
        if let hinge = clearHingePoint(snapshot, o, width: width, height: height) {
            report.hingeChecked = true
            if !anyPixel(rgba, near: hinge.p, radius: pointRadius, width: width, height: height, where: isPink) {
                let c: SIMD3<Double> = centre(rgba, hinge.p, width: width, height: height)
                report.misses.append(String(format: "hinge %ld at local %.1f (%.1f, %.1f) is (%.3f, %.3f, %.3f)",
                                            snapshot.chosenHinge, hinge.local, hinge.p.x, hinge.p.y, c.x, c.y, c.z))
            }
        }
        if snapshot.budget > 0, let p = movesPixel(snapshot, width: width, height: height),
           inside(p, width: width, height: height), let rank = o.rank(.bar, 0),
           o.isClear(p, after: rank, kinds: allKinds, clearance: clearance) {
            report.movesChecked = true
            if !anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height, where: isOffNight) {
                report.misses.append(String(format: "moves bar 0 at (%.1f, %.1f) is night-coloured", p.x, p.y))
            }
        }
        return report
    }

    /// The pixel of the first moves bar's centre (nil without a projection).
    static func movesPixel(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> SIMD2<Double>? {
        pixel(Geometry.movesBar(0, snapshot), snapshot, width: width, height: height)
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

    /// Runs the checks of clarification Q3 on `rgba` against `snapshot`, recording an issue per failure, and returns
    /// the report. `require` true also requires at least one cube centre to be measured.
    @discardableResult
    static func checkFrame(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width, height: Int = height,
                           require: Bool = true, _ what: String,
                           sourceLocation: SourceLocation = #_sourceLocation) -> VoxelOrigamiCheckReport {
        #expect(rgba.count == width * height * 4, "\(what): picture size", sourceLocation: sourceLocation)
        guard rgba.count == width * height * 4 else { return VoxelOrigamiCheckReport() }
        let report: VoxelOrigamiCheckReport = pointReport(rgba, snapshot: snapshot, width: width, height: height)
        if require {
            #expect(report.cubeChecked > 0, "\(what): no cube centre clear of the later elements",
                    sourceLocation: sourceLocation)
        }
        let shown: [String] = Array(report.misses.prefix(8))
        #expect(report.misses.isEmpty, "\(what): \(shown)", sourceLocation: sourceLocation)
        let background: [String] = backgroundMisses(rgba, width: width, height: height)
        #expect(background.isEmpty, "\(what): \(background)", sourceLocation: sourceLocation)
        let cubes: String = String(format: "cubes checked %ld, excluded %ld", report.cubeChecked, report.cubeExcluded)
        print("voxel-origami \(what): \(cubes); hinge checked \(report.hingeChecked); moves checked "
              + "\(report.movesChecked)")
        return report
    }

    // MARK: Failure outlines

    /// The sample points (pixels at the check size) on the outlines a collision or sweep draws in `snapshot`: three
    /// points along each of the 12 edges of the moving and the still cube's wireframe (side 1.0 s), each 6 px from
    /// every element painted after that cube.
    static func failureSamples(_ snapshot: Snapshot, width: Int = width,
                               height: Int = height) -> (moving: [SIMD2<Double>], still: [SIMD2<Double>]) {
        guard let broken = snapshot.brokenTurn else { return ([], []) }
        let o: VoxelOrigamiLayout = layout(snapshot, width: width, height: height)
        let s: Double = Geometry.scale(snapshot)
        func samples(_ cube: Int) -> [SIMD2<Double>] {
            guard let rank = o.rank(.cube, cube) else { return [] }
            let corners: [SIMD3<Double>] = boxCorners(Geometry.cubeCentre(cube, snapshot),
                                                      half: Geometry.brokenSide * s / 2)
            let bits: [Int] = [1, 2, 4]
            let shares: [Double] = [0.25, 0.5, 0.75]
            var result: [SIMD2<Double>] = []
            for a in 0..<8 {
                for bit in bits where a & bit == 0 {
                    for share in shares {
                        let world: SIMD3<Double> = corners[a] + (corners[a | bit] - corners[a]) * share
                        guard let p = pixel(world, snapshot, width: width, height: height),
                              inside(p, width: width, height: height),
                              o.isClear(p, after: rank, kinds: allKinds, clearance: clearance) else { continue }
                        result.append(p)
                    }
                }
            }
            return result
        }
        return (samples(broken.moving), samples(broken.still))
    }

    // MARK: Won level

    /// Points of cube `index`'s inner glow band (a camera-facing square of half size 0.52 s around its centre, inside
    /// the target shells' inner half size 0.55 s, where the cube's two shells are strongest): its corners, its edge
    /// middles and the quarter points of its edges.
    static func glowBandSamples(_ index: Int, _ snapshot: Snapshot, width: Int = width,
                                height: Int = height) -> [SIMD2<Double>] {
        let cam: VoxelOrigamiCamera = camera(snapshot, width: width, height: height)
        let s: Double = Geometry.scale(snapshot)
        let half: Double = 0.52 * s
        let basis = viewBasis()
        let c: SIMD3<Double> = Geometry.cubeCentre(index, snapshot)
        let shares: [Double] = [-1, -0.5, 0, 0.5, 1]
        let signs: [Double] = [-1, 1]
        var result: [SIMD2<Double>] = []
        for sign in signs {
            for share in shares {
                let points: [SIMD3<Double>] = [
                    c + basis.right * (sign * half) + basis.up * (share * half),
                    c + basis.right * (share * half) + basis.up * (sign * half),
                ]
                for point in points {
                    if let p = project(point, cam, width: width, height: height),
                       inside(p, width: width, height: height) {
                        result.append(p)
                    }
                }
            }
        }
        return result
    }
}
#endif
