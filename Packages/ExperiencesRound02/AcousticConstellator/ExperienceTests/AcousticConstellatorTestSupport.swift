// AcousticConstellatorTestSupport — feature 423 (R02-G13-03) T-R02G1303-006 (FR-R02G1303-001 … 007; SC-R02G1303-001,
// 002; clarifications Q1–Q5). Shared helpers of the Acoustic Constellator experience tests, following Harmonic Bridges's
// harness (feature 413): opening the experience through the one app's session host (seed `s` prepares level
// `s % 100 + 1`; a session without a quality pin is pinned to level 0), arranging the constellation through the shell
// to the level's certified plan (the witness actions without the final listen: every symbol pair linked and every star
// nudged, so the report of the current state holds teal links at tick 0), drawing live frames, drawing an off-screen
// still (RGBA8, rows top-down, the orientation of the Core's CPU projection `AcousticConstellatorSceneGeometry.project`,
// origin top left, y down, scaled here to pixels), the engine digest, and the frame checks of clarification Q3 at
// 1,152 × 768.
//
// The presenter hands the snapshot the seconds since the play last changed, so the first still after an action, drawn
// at frame time 0, restarts the tick clock at 0 (tick 0 shown); live frames are therefore not drawn between an action
// and the stills that need a known time.
//
// The CPU reference: every star's centre, every link's check point (`linkCheckPoint`, u = 0.25 along its spline,
// 0.015 to the side, clear of the 0.01-wide strip), the first coherence bar, the first hold pip and the first moves bar,
// projected through the camera at the target's aspect. A point is checked only when it projects into the picture at
// least 6 px from every other element:
//   - a star's centre is checked against every other star's body (the convex hull of its projected ellipsoid at the
//     largest pulse, 1.15 times the radii): stars are opaque and drawn after the gauges, guides, links and hands, so
//     only another star can cover a star's centre. Within 3 px of the centre a pixel differs from the sky by at least
//     0.15 in luminance with red, green and blue within 0.1 of each other (white). The additive glow and wave shells
//     drawn over a star at level-0 and level-1 saturate every channel of the lit star white (the star colour times at
//     least 0.8 light plus at least a quarter of the cyan glow), so the white hue is checked at every tier;
//   - a teal link's check point (a link whose kernel gap at the drawn tick is at most 1 and which is not snapped) is
//     checked against every star body, every other link's spline (17 points), every dashed guide's chord and every
//     phase hand at the drawn tick. The check point lies 0.015 beside the strip's axis (about 3 … 5 px at this size) and
//     the strip is 0.01 wide, so the search disc reaches from the check point to the axis point at u = 0.25
//     (`linkRadius`); within it a pixel differs from the sky by at least 0.08 with green above red by at least 0.05;
//   - the first moves bar has, within 3 px of its centre, a pixel at least 0.1 away from the sky in luminance (lit
//     #B8C0D0 or unlit #2A2433 both qualify; the gauges lie on y = 0 in front of every star);
//   - the two probe corners (0.02, 0.02) and (0.98, 0.98) of the view are within 0.05 per channel of the sky.
// Luminance is the Rec. 709 weighting of the stored 0 … 1 channel values. Positions come from the presenter's
// `lastSnapshot` (the snapshot it drew). Short runs only (no sleep, no wall-clock assertion).
//
// The checked levels (24, 44, 60, 72, 82; seeds 23, 43, 59, 71, 81) were chosen by projecting every certified level's
// arranged constellation (the witness files under docs/games/acoustic-constellator/levels with the kernel's tick rule)
// through this camera with a 2 px safety margin on the clearance: each has every star centre clear and at least two
// teal links whose check points are clear; the checks below require at least one of each again at every tier.
#if os(iOS)
import CoreGraphics
import Foundation
import AcousticConstellatorCore
import Testing
import UIKit
@testable import AcousticConstellatorExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the point checks of one frame found.
struct AcousticConstellatorFrameReport {
    /// The star centres measured and those left out by the 6-pixel clearance.
    var starChecked: Int = 0
    var starExcluded: Int = 0
    /// The teal link check points measured and those left out by the 6-pixel clearance.
    var tealChecked: Int = 0
    var tealExcluded: Int = 0
    /// Every failed check, in words.
    var misses: [String] = []
}

/// How a frame was drawn, as far as the reference needs it: whether stars pulse, whether glow is drawn and whether the
/// tick is held at 0 (Reduce Motion).
struct AcousticConstellatorDrawMode: Equatable {
    var pulse: Bool
    var glow: Bool
    var reduceMotion: Bool

    /// The mode of host tier `tier` (clamped) with or without Reduce Motion.
    static func tier(_ tier: Int, reduceMotion: Bool = false) -> AcousticConstellatorDrawMode {
        let drawn: AcousticConstellatorTier = AcousticConstellatorTier.of(tier)
        return AcousticConstellatorDrawMode(pulse: drawn.pulse && !reduceMotion, glow: drawn.glowShells > 0,
                                            reduceMotion: reduceMotion)
    }

    /// The unlit fallback: the level-2 geometry (no pulse, no glow).
    static let fallback = AcousticConstellatorDrawMode(pulse: false, glow: false, reduceMotion: false)
}

/// Building, opening, drawing and measuring Acoustic Constellator.
@MainActor
enum AcousticConstellatorTest {
    typealias Geometry = AcousticConstellatorSceneGeometry
    typealias Palette = AcousticConstellatorPalette
    typealias Snapshot = AcousticConstellatorSceneSnapshot
    typealias Shell = ExperienceShell<AcousticConstellatorPresenter>

    /// The experience id `r02-g13.acoustic-constellator`.
    static var id: ExperienceID {
        AcousticConstellatorExperience.id ?? ExperienceID(rawValue: "r02-g13.unknown")!
    }

    /// The frame-check size of clarification Q3, aspect 1.5.
    static let width: Int = 1_152
    static let height: Int = 768
    /// The seeds of the checked levels 24, 44, 60, 72 and 82 (seed = level − 1; see the file header).
    static let seeds: [UInt64] = [23, 43, 59, 71, 81]
    /// The search radius (pixels) of the star, gauge and outline-cross checks.
    static let pointRadius: Double = 3
    /// The clearance (pixels) of every checked point from every other element.
    static let clearance: Double = 6
    /// The star centre's luminance difference from the sky.
    static let starMargin: Double = 0.15
    /// The largest spread of a white star pixel's channels.
    static let whiteSpread: Double = 0.1
    /// The teal link's luminance difference from the sky.
    static let linkMargin: Double = 0.08
    /// The teal link's green above red.
    static let tealHue: Double = 0.05
    /// The luminance difference from the sky near the first moves bar.
    static let movesMargin: Double = 0.1
    /// The per-channel bound of the sky.
    static let backgroundTolerance: Double = 0.05
    /// The sky probe points (fractions of the view, origin top left).
    static let backgroundPoints: [(x: Double, y: Double)] = [(0.02, 0.02), (0.98, 0.98)]
    /// The largest star pulse (1 + 0.15), the size of a star's body in the clearance test at every tier.
    static let pulseBound: Double = 1 + AcousticConstellatorShaders.pulseAmplitude

    /// Opens Acoustic Constellator with `seed` in `session` through the factory, lays the view out at `size` points and
    /// draws one frame. A session without a quality pin is pinned to level 0. `configure` runs on the presenter before
    /// its first `setup` (the fallback seam).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false, size: CGSize = CGSize(width: 48, height: 32),
                     configure: ((AcousticConstellatorPresenter) -> Void)? = nil) async throws -> Shell {
        let id: ExperienceID = self.id
        var made: Shell?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: seed) {
            let shell: Shell = AcousticConstellatorExperience.make(id: id, reduceMotion: reduceMotion,
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
    static func core(_ shell: Shell) throws -> AcousticConstellatorExperienceCore {
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
    nonisolated static func control(_ action: AcousticConstellatorAction) -> (control: String, values: [Double]) {
        switch action {
        case let .link(a, b):
            ("link.add", [Double(a), Double(b)])
        case let .unlink(a, b):
            ("link.remove", [Double(a), Double(b)])
        case let .nudge(star, step):
            ("star.nudge", [Double(star), Double(step)])
        case .listen:
            ("constellation.listen", [])
        }
    }

    /// The host action of `action` (step 0).
    nonisolated static func experienceAction(_ action: AcousticConstellatorAction) -> ExperienceAction {
        let issued = control(action)
        return ExperienceAction(control: issued.control, values: issued.values, step: 0)
    }

    /// The certified solution of level `number`: the witness actions of its certified plan (links in pair order, nudges
    /// in star order, then one listen), as the witness file stores them.
    nonisolated static func certifiedActions(_ number: Int) throws -> [AcousticConstellatorAction] {
        AcousticConstellatorSolver.actions(try AcousticConstellatorExperienceCore.generated(number: number).plan)
    }

    /// The certified arrangement of level `number`: the solution without its final listen.
    nonisolated static func certifiedArrangement(_ number: Int) throws -> [AcousticConstellatorAction] {
        var result: [AcousticConstellatorAction] = []
        for action in try certifiedActions(number) where action != .listen { result.append(action) }
        return result
    }

    /// The certified plan's links of level `number` without its nudges (the arrangement left with the starting phases).
    nonisolated static func certifiedLinksOnly(_ number: Int) throws -> [AcousticConstellatorAction] {
        var result: [AcousticConstellatorAction] = []
        for action in try certifiedActions(number) {
            if case .link = action { result.append(action) }
        }
        return result
    }

    /// Issues `actions` through the shell, each expected to be accepted; returns how many were.
    @discardableResult
    static func issue(_ shell: Shell, _ actions: [AcousticConstellatorAction],
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

    /// Arranges the shell's level to its certified plan (no listen). Returns whether every action was accepted.
    @discardableResult
    static func arrange(_ shell: Shell) throws -> Bool {
        let number: Int = try core(shell).levelNumber
        let actions: [AcousticConstellatorAction] = try certifiedArrangement(number)
        #expect(!actions.isEmpty, "level \(number) has a certified arrangement")
        return issue(shell, actions) == actions.count
    }

    /// The same as `arrange` on a bare core (no host): the CPU reference of the arranged state.
    static func arranged(_ number: Int) throws -> AcousticConstellatorExperienceCore {
        var core: AcousticConstellatorExperienceCore = try AcousticConstellatorExperienceCore.opening(number: number)
        for action in try certifiedArrangement(number) {
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

    /// The luminance of the sky.
    static var skyLuminance: Double { luminance(Palette.sky) }

    /// The number of pixels farther than `tolerance` per channel from the sky.
    static func nonSkyPixels(_ rgba: [UInt8], tolerance: Double = 0.05) -> Int {
        var count: Int = 0
        var i: Int = 0
        while i + 3 < rgba.count {
            let c = SIMD3<Double>(Double(rgba[i]) / 255, Double(rgba[i + 1]) / 255, Double(rgba[i + 2]) / 255)
            if channelDistance(c, Palette.sky) > tolerance { count += 1 }
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
    static func camera(_ snapshot: Snapshot, width: Int, height: Int) -> AcousticConstellatorCamera {
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

    /// The tick drawn for `snapshot` in `mode`.
    static func drawnTick(_ snapshot: Snapshot, _ mode: AcousticConstellatorDrawMode) -> Int {
        Geometry.drawnTick(snapshot, reduceMotion: mode.reduceMotion)
    }

    /// The world reference points of `snapshot` in a fixed order, none depending on the tier or the tick: star centres
    /// (star order), link check points (link order), the first coherence bar, the first hold pip, the first moves bar.
    static func referenceWorldPoints(_ snapshot: Snapshot) -> [SIMD3<Double>] {
        var points: [SIMD3<Double>] = []
        for index in snapshot.stars.indices { points.append(Geometry.starCentre(index, snapshot)) }
        for index in snapshot.links.indices { points.append(Geometry.linkCheckPoint(index, snapshot)) }
        points.append(Geometry.coherenceBar(0, snapshot))
        points.append(Geometry.holdPip(0, snapshot))
        points.append(Geometry.movesBar(0, snapshot))
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

    /// The convex hull (pixels, y down) of star `index`'s projected ellipsoid at the largest pulse: 12 directions around
    /// on 9 latitudes (poles included) at 1.15 times the radii (0.045, 0.035, 0.045).
    static func starHull(_ index: Int, _ snapshot: Snapshot, width: Int = width,
                         height: Int = height) -> [SIMD2<Double>] {
        let c: SIMD3<Double> = Geometry.starCentre(index, snapshot)
        let radii: SIMD3<Double> = Geometry.starRadii * pulseBound
        var points: [SIMD2<Double>] = []
        for ring in 0...8 {
            let latitude: Double = -Double.pi / 2 + Double.pi * Double(ring) / 8
            for k in 0..<12 {
                let longitude: Double = 2 * Double.pi * Double(k) / 12
                let s = SIMD3<Double>(cos(latitude) * cos(longitude), sin(latitude), cos(latitude) * sin(longitude))
                if let p = pixel(c + radii * s, snapshot, width: width, height: height) { points.append(p) }
            }
        }
        return convexHull(points)
    }

    /// The hulls of every star of `snapshot`, in star order.
    static func starHulls(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> [[SIMD2<Double>]] {
        var result: [[SIMD2<Double>]] = []
        for index in snapshot.stars.indices { result.append(starHull(index, snapshot, width: width, height: height)) }
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

    /// The distance (pixels) of `p` from the polyline `line` (infinite for an empty line, the point distance for one
    /// point).
    nonisolated static func polylineDistance(_ p: SIMD2<Double>, _ line: [SIMD2<Double>]) -> Double {
        guard let first = line.first else { return Double.infinity }
        guard line.count > 1 else { return segmentDistance(p, first, first) }
        var best: Double = Double.infinity
        for i in 0..<(line.count - 1) { best = Swift.min(best, segmentDistance(p, line[i], line[i + 1])) }
        return best
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
            best = Swift.min(best, segmentDistance(p, a, b))
        }
        return inside ? -best : best
    }

    /// The projected axis of link `index` (17 points along its spline, u = 0 … 1; points without a projection left
    /// out).
    static func linkAxis(_ index: Int, _ snapshot: Snapshot, width: Int = width,
                         height: Int = height) -> [SIMD2<Double>] {
        var result: [SIMD2<Double>] = []
        for k in 0...Geometry.linkSegments {
            let u: Double = Double(k) / Double(Geometry.linkSegments)
            if let p = pixel(Geometry.linkPoint(index, u: u, snapshot), snapshot, width: width, height: height) {
                result.append(p)
            }
        }
        return result
    }

    /// The projected chords of the dashed guides (the unlinked symbol pairs), in guide order.
    static func guideAxes(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> [[SIMD2<Double>]] {
        var result: [[SIMD2<Double>]] = []
        for pair in snapshot.unlinkedSymbolPairs {
            var line: [SIMD2<Double>] = []
            for star in [pair.a, pair.b] {
                if let p = pixel(Geometry.starCentre(star, snapshot), snapshot, width: width, height: height) {
                    line.append(p)
                }
            }
            result.append(line)
        }
        return result
    }

    /// The projected phase hand of star `index` at `tick`: from 0.04 above the centre, 0.07 along its direction.
    static func handAxis(_ index: Int, tick: Int, _ snapshot: Snapshot, width: Int = width,
                         height: Int = height) -> [SIMD2<Double>] {
        let c: SIMD3<Double> = Geometry.starCentre(index, snapshot) + SIMD3<Double>(0, Geometry.handLift, 0)
        let e: SIMD3<Double> = c + Geometry.handDirection(index, tick: tick, snapshot) * Geometry.handLength
        var line: [SIMD2<Double>] = []
        for point in [c, e] {
            if let p = pixel(point, snapshot, width: width, height: height) { line.append(p) }
        }
        return line
    }

    /// Whether `p` lies inside a `width` × `height` picture.
    static func inside(_ p: SIMD2<Double>, width: Int, height: Int) -> Bool {
        p.x >= 0 && p.y >= 0 && p.x < Double(width) && p.y < Double(height)
    }

    /// Whether star `index`'s centre pixel `p` is at least 6 px outside every other star's body.
    static func isStarClear(_ index: Int, _ p: SIMD2<Double>, hulls: [[SIMD2<Double>]]) -> Bool {
        for other in hulls.indices where other != index {
            if hullDistance(hulls[other], p) < clearance { return false }
        }
        return true
    }

    /// Whether link `index`'s check point pixel `p` is at least 6 px from every star body, every other link's axis,
    /// every guide chord and every phase hand at `tick`.
    static func isLinkClear(_ index: Int, _ p: SIMD2<Double>, _ snapshot: Snapshot, tick: Int,
                            hulls: [[SIMD2<Double>]], width: Int = width, height: Int = height) -> Bool {
        for hull in hulls where hullDistance(hull, p) < clearance { return false }
        for other in snapshot.links.indices where other != index {
            if polylineDistance(p, linkAxis(other, snapshot, width: width, height: height)) < clearance { return false }
        }
        for guide in guideAxes(snapshot, width: width, height: height) where polylineDistance(p, guide) < clearance {
            return false
        }
        for star in snapshot.stars.indices {
            let hand: [SIMD2<Double>] = handAxis(star, tick: tick, snapshot, width: width, height: height)
            if polylineDistance(p, hand) < clearance { return false }
        }
        return true
    }

    /// The search radius (pixels) of link `index`'s check: from its check point to its axis point at u = 0.25, so the
    /// disc reaches across the 0.01 between the check point and the strip's edge to the strip's middle.
    static func linkRadius(_ index: Int, _ snapshot: Snapshot, width: Int = width, height: Int = height) -> Double {
        guard let check = pixel(Geometry.linkCheckPoint(index, snapshot), snapshot, width: width, height: height),
              let axis = pixel(Geometry.linkPoint(index, u: Geometry.checkU, snapshot), snapshot, width: width,
                               height: height) else { return pointRadius }
        let d: SIMD2<Double> = axis - check
        return Swift.max((d.x * d.x + d.y * d.y).squareRoot(), 1)
    }

    /// Whether link `index` is teal and whole at `tick`: the kernel's gap is at most 1 and it has not snapped.
    static func isTealWhole(_ index: Int, _ snapshot: Snapshot, tick: Int) -> Bool {
        snapshot.isTeal(index, at: tick) && !snapshot.isSnapped(index, at: tick)
    }

    /// Whether `c` is a white star pixel: 0.15 from the sky in luminance with red, green and blue within 0.1.
    static func isWhiteStar(_ c: SIMD3<Double>) -> Bool {
        let spread: Double = Swift.max(c.x, c.y, c.z) - Swift.min(c.x, c.y, c.z)
        return Swift.abs(luminance(c) - skyLuminance) >= starMargin && spread <= whiteSpread
    }

    /// Whether `c` is a teal link pixel: 0.08 from the sky in luminance and green − red ≥ 0.05.
    static func isTealLink(_ c: SIMD3<Double>) -> Bool {
        Swift.abs(luminance(c) - skyLuminance) >= linkMargin && c.y - c.x >= tealHue
    }

    /// Whether `c` shows the broken outline #FF6B4A (red well above green and blue; the plum guides, the silver and
    /// teal links, the white stars and hands and every gauge colour stay below these bounds).
    static func isBrokenOutline(_ c: SIMD3<Double>) -> Bool {
        c.x >= 0.45 && c.x - c.y >= 0.3 && c.x - c.z >= 0.3
    }

    /// The first star of `snapshot` whose centre lies inside the picture and clear of every other star (index and
    /// pixel).
    static func firstClearStar(_ snapshot: Snapshot, width: Int = width,
                               height: Int = height) -> (index: Int, p: SIMD2<Double>)? {
        let hulls: [[SIMD2<Double>]] = starHulls(snapshot, width: width, height: height)
        for index in snapshot.stars.indices {
            guard let p = pixel(Geometry.starCentre(index, snapshot), snapshot, width: width, height: height),
                  inside(p, width: width, height: height), isStarClear(index, p, hulls: hulls) else { continue }
            return (index, p)
        }
        return nil
    }

    /// The teal, whole links of `snapshot` at the drawn tick of `mode` whose check points are clear (link index and
    /// pixel).
    static func clearTealLinks(_ snapshot: Snapshot, _ mode: AcousticConstellatorDrawMode, width: Int = width,
                               height: Int = height) -> [(index: Int, p: SIMD2<Double>)] {
        let hulls: [[SIMD2<Double>]] = starHulls(snapshot, width: width, height: height)
        let tick: Int = drawnTick(snapshot, mode)
        var result: [(index: Int, p: SIMD2<Double>)] = []
        for index in snapshot.links.indices where isTealWhole(index, snapshot, tick: tick) {
            guard let p = pixel(Geometry.linkCheckPoint(index, snapshot), snapshot, width: width, height: height),
                  inside(p, width: width, height: height),
                  isLinkClear(index, p, snapshot, tick: tick, hulls: hulls, width: width, height: height) else {
                continue
            }
            result.append((index, p))
        }
        return result
    }

    /// The star and teal-link checks of clarification Q3 (see the file header) on `rgba` against `snapshot`.
    static func pointReport(_ rgba: [UInt8], snapshot: Snapshot, mode: AcousticConstellatorDrawMode,
                            width: Int = width, height: Int = height) -> AcousticConstellatorFrameReport {
        var report = AcousticConstellatorFrameReport()
        let hulls: [[SIMD2<Double>]] = starHulls(snapshot, width: width, height: height)
        for index in snapshot.stars.indices {
            guard let p = pixel(Geometry.starCentre(index, snapshot), snapshot, width: width, height: height),
                  inside(p, width: width, height: height) else {
                report.misses.append("star \(index): it does not project into the picture")
                continue
            }
            if !isStarClear(index, p, hulls: hulls) {
                report.starExcluded += 1
                continue
            }
            report.starChecked += 1
            if !anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height, where: isWhiteStar) {
                let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
                report.misses.append(String(format: "white star %ld (%.1f, %.1f) is (%.3f, %.3f, %.3f)", index, p.x,
                                            p.y, c.x, c.y, c.z))
            }
        }
        let tick: Int = drawnTick(snapshot, mode)
        for index in snapshot.links.indices where isTealWhole(index, snapshot, tick: tick) {
            guard let p = pixel(Geometry.linkCheckPoint(index, snapshot), snapshot, width: width, height: height),
                  inside(p, width: width, height: height) else {
                report.misses.append("link \(index): it does not project into the picture")
                continue
            }
            if !isLinkClear(index, p, snapshot, tick: tick, hulls: hulls, width: width, height: height) {
                report.tealExcluded += 1
                continue
            }
            report.tealChecked += 1
            let radius: Double = linkRadius(index, snapshot, width: width, height: height)
            if !anyPixel(rgba, near: p, radius: radius, width: width, height: height, where: isTealLink) {
                let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
                report.misses.append(String(format: "teal link %ld (%.1f, %.1f) r %.1f is (%.3f, %.3f, %.3f)", index,
                                            p.x, p.y, radius, c.x, c.y, c.z))
            }
        }
        return report
    }

    /// The pixel of the first moves bar's centre (nil without a projection).
    static func movesPixel(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> SIMD2<Double>? {
        pixel(Geometry.movesBar(0, snapshot), snapshot, width: width, height: height)
    }

    /// The moves check: within 3 px of the first moves bar's centre, a pixel 0.1 away from the sky in luminance.
    static func movesMisses(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width,
                            height: Int = height) -> [String] {
        guard snapshot.budget > 0 else { return ["moves: no budget"] }
        guard let p = movesPixel(snapshot, width: width, height: height) else {
            return ["moves bar 0: no projection"]
        }
        let sky: Double = skyLuminance
        let margin: Double = movesMargin
        let test: (SIMD3<Double>) -> Bool = { (c: SIMD3<Double>) -> Bool in
            Swift.abs(Self.luminance(c) - sky) >= margin
        }
        let found: Bool = anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height, where: test)
        return found ? [] : [String(format: "moves bar 0 at (%.1f, %.1f) is sky", p.x, p.y)]
    }

    /// The background check: the pixels of the two probe corners are within 0.05 per channel of the sky.
    static func backgroundMisses(_ rgba: [UInt8], width: Int = width, height: Int = height) -> [String] {
        var misses: [String] = []
        for point in backgroundPoints {
            let got = pixelAtFraction(rgba, point.x, point.y, width: width, height: height)
            if channelDistance(got.colour, Palette.sky) > backgroundTolerance {
                misses.append(String(format: "background (%ld, %ld): (%.3f, %.3f, %.3f)", got.x, got.y,
                                     got.colour.x, got.colour.y, got.colour.z))
            }
        }
        return misses
    }

    /// Runs the checks of clarification Q3 on `rgba` against `snapshot` drawn in `mode`, recording an issue per
    /// failure, and returns the report. `require` true (the arranged frames at the check size) also requires at least
    /// one star centre and one teal link check point to be measured.
    @discardableResult
    static func checkFrame(_ rgba: [UInt8], snapshot: Snapshot, mode: AcousticConstellatorDrawMode,
                           width: Int = width, height: Int = height, require: Bool = true, _ what: String,
                           sourceLocation: SourceLocation = #_sourceLocation) -> AcousticConstellatorFrameReport {
        #expect(rgba.count == width * height * 4, "\(what): picture size", sourceLocation: sourceLocation)
        guard rgba.count == width * height * 4 else { return AcousticConstellatorFrameReport() }
        let report: AcousticConstellatorFrameReport = pointReport(rgba, snapshot: snapshot, mode: mode, width: width,
                                                                  height: height)
        if require {
            #expect(report.starChecked > 0, "\(what): no star centre clear of the other stars",
                    sourceLocation: sourceLocation)
            #expect(report.tealChecked > 0, "\(what): no teal link check point clear of the other elements",
                    sourceLocation: sourceLocation)
        }
        let shown: [String] = Array(report.misses.prefix(8))
        #expect(report.misses.isEmpty, "\(what): \(shown)", sourceLocation: sourceLocation)
        let moves: [String] = movesMisses(rgba, snapshot: snapshot, width: width, height: height)
        #expect(moves.isEmpty, "\(what): \(moves)", sourceLocation: sourceLocation)
        let background: [String] = backgroundMisses(rgba, width: width, height: height)
        #expect(background.isEmpty, "\(what): \(background)", sourceLocation: sourceLocation)
        let stars: String = String(format: "star checked %ld, excluded %ld", report.starChecked, report.starExcluded)
        let links: String = String(format: "teal checked %ld, excluded %ld", report.tealChecked, report.tealExcluded)
        print("acoustic-constellator \(what): \(stars); \(links)")
        return report
    }

    // MARK: Failure outline

    /// The pixels along the chord from star `a` to star `b` (u = 0.05 … 0.95) at least 6 px outside every star body.
    static func chordSamples(_ a: Int, _ b: Int, _ snapshot: Snapshot, width: Int = width,
                             height: Int = height) -> [SIMD2<Double>] {
        let hulls: [[SIMD2<Double>]] = starHulls(snapshot, width: width, height: height)
        let pa: SIMD3<Double> = Geometry.starCentre(a, snapshot)
        let pb: SIMD3<Double> = Geometry.starCentre(b, snapshot)
        var result: [SIMD2<Double>] = []
        for j in 1...19 {
            let u: Double = Double(j) / 20
            guard let p = pixel(pa + (pb - pa) * u, snapshot, width: width, height: height),
                  inside(p, width: width, height: height) else { continue }
            var clear: Bool = true
            for hull in hulls where hullDistance(hull, p) < clearance { clear = false }
            if clear { result.append(p) }
        }
        return result
    }

    /// The pixels along link `index`'s spline (u = 0.05 … 0.95) at least 6 px outside every star body.
    static func linkSamples(_ index: Int, _ snapshot: Snapshot, width: Int = width,
                            height: Int = height) -> [SIMD2<Double>] {
        let hulls: [[SIMD2<Double>]] = starHulls(snapshot, width: width, height: height)
        var result: [SIMD2<Double>] = []
        for j in 1...19 {
            let u: Double = Double(j) / 20
            guard let p = pixel(Geometry.linkPoint(index, u: u, snapshot), snapshot, width: width, height: height),
                  inside(p, width: width, height: height) else { continue }
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
}
#endif
