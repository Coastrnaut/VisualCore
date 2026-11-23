// BackwardsAuroraTestSupport — feature 393 (R02-G10-03) T-R02G1003-006 (FR-R02G1003-001 … 007; SC-R02G1003-001, 002;
// clarifications Q1–Q5). Shared helpers of the Backwards Aurora experience tests, following the Nocturne Garden harness
// (feature 383): opening the experience through the one app's session host (seed `s` prepares level `s % 100 + 1`; a
// session without a quality pin is pinned to level 0), advancing the play by the first action of the level's certified
// solution (one `wave.reverse`), drawing live frames, drawing an off-screen still (RGBA8, rows top-down: the host's
// `renderOffscreen` flips the GL read-back, so the still has the orientation of the Core's CPU projection
// `BackwardsAuroraSceneGeometry.project`, origin top left, y down, scaled here to pixels), the engine digest, and the
// frame checks of clarification Q3 at 1,152 × 768:
//   - every wave sample point (z = 0) that projects into the picture at least 6 px clear of every checkpoint ring (the
//     ring's outer radius in pixels plus 6), of every checkpoint tick's x (the tick's half width in pixels plus 6), of
//     every kink cross and of the tear cross (half the cross's span in pixels plus 6) has, within 3 px of the point, a
//     ribbon pixel: blue − red at least 0.15 and luminance at least 0.15 away from the ground's;
//   - every target point (the ghost plane z = −0.05) whose sample differs from the wave's by at least 12 units, under the
//     same exclusions, has within 3 px a ghost pixel: luminance at least 0.1 away from the ground's and red − green at
//     least 0.05 (lilac);
//   - the gauge's first bar has, within 3 px of its centre, a pixel at least 0.1 away from the ground in luminance;
//   - the two probe corners (0.02, 0.02) and (0.98, 0.98) of the view are within 0.05 per channel of the ground.
// The ghost points are at least 12 · 0.6 / 64 = 0.1125 world units from the ribbon's centre line, beyond the ribbon
// (0.03) and the richest glow shell (0.03 + 2 · 0.02 = 0.07) with room for the ghost's half height and the 3-pixel
// search (8 units, 0.075, let the additive glow tint a ghost pixel on level 81 at tier 0: corrected 2026-11-22).
// Positions come from the presenter's `lastSnapshot` (the snapshot it drew). Luminance is the Rec. 709 weighting of the stored 0 … 1 channel
// values. Short runs only (no sleep, no wall-clock assertion).
#if os(iOS)
import CoreGraphics
import Foundation
import BackwardsAuroraCore
import Testing
import UIKit
@testable import BackwardsAuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the point checks of one frame found.
struct BackwardsAuroraFrameReport {
    /// The sample points measured, and those left out by a ring, tick, kink or tear exclusion.
    var ribbonChecked: Int = 0
    var ribbonExcluded: Int = 0
    /// The target points measured (|s − t| ≥ 8, outside every exclusion).
    var ghostChecked: Int = 0
    /// Every failed check, in words.
    var misses: [String] = []
}

/// Building, opening, drawing and measuring Backwards Aurora.
@MainActor
enum BackwardsAuroraTest {
    typealias Geometry = BackwardsAuroraSceneGeometry
    typealias Palette = BackwardsAuroraPalette
    typealias Snapshot = BackwardsAuroraSceneSnapshot
    typealias Shell = ExperienceShell<BackwardsAuroraPresenter>

    /// The experience id `r02-g10.backwards-aurora`.
    static var id: ExperienceID {
        BackwardsAuroraExperience.id ?? ExperienceID(rawValue: "r02-g10.unknown")!
    }

    /// The frame-check size of clarification Q3, aspect 1.5.
    static let width: Int = 1_152
    static let height: Int = 768
    /// The seeds of the checked levels 1, 21, 41, 61 and 81 (seed = level − 1).
    static let seeds: [UInt64] = [0, 20, 40, 60, 80]
    /// The search radius (pixels) of every point check.
    static let pointRadius: Double = 3
    /// The clearance (pixels) of every checked point from a ring, a tick, a kink or the tear.
    static let clearance: Double = 6
    /// The ribbon's coolness (blue − red).
    static let ribbonCoolness: Double = 0.15
    /// The ribbon's luminance difference from the ground.
    static let ribbonMargin: Double = 0.15
    /// The smallest |s − t| at which a target point is checked.
    static let ghostGap: Int = 12
    /// The ghost's luminance difference from the ground.
    static let ghostMargin: Double = 0.1
    /// The ghost's lilac (red − green).
    static let ghostLilac: Double = 0.05
    /// The luminance difference from the ground near the gauge's first bar.
    static let gaugeMargin: Double = 0.1
    /// The warmth (red − blue) of the tear cross.
    static let tearWarmth: Double = 0.2
    /// The per-channel bound of the ground.
    static let backgroundTolerance: Double = 0.05
    /// The ground probe points (fractions of the view, origin top left).
    static let backgroundPoints: [(x: Double, y: Double)] = [(0.02, 0.02), (0.98, 0.98)]

    /// Opens Backwards Aurora with `seed` in `session` through the factory, lays the view out at `size` points and
    /// draws one frame. A session without a quality pin is pinned to level 0. `configure` runs on the presenter before
    /// its first `setup` (the fallback seam).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false, size: CGSize = CGSize(width: 48, height: 32),
                     configure: ((BackwardsAuroraPresenter) -> Void)? = nil) async throws -> Shell {
        let id: ExperienceID = self.id
        var made: Shell?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: seed) {
            let shell: Shell = BackwardsAuroraExperience.make(id: id, reduceMotion: reduceMotion,
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
    static func core(_ shell: Shell) throws -> BackwardsAuroraExperienceCore {
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
    static func control(_ action: BackwardsAuroraAction) -> (control: String, values: [Double]) {
        switch action {
        case let .reverse(start, end):
            ("wave.reverse", [Double(start), Double(end)])
        }
    }

    /// The host action of `action` (step 0).
    static func experienceAction(_ action: BackwardsAuroraAction) -> ExperienceAction {
        let issued = control(action)
        return ExperienceAction(control: issued.control, values: issued.values, step: 0)
    }

    /// The certified solution of level `number`.
    static func certifiedActions(_ number: Int) throws -> [BackwardsAuroraAction] {
        try BackwardsAuroraExperienceCore.generated(number: number).solution.actions
    }

    /// The first action of level `number`'s certified solution.
    static func firstAction(_ number: Int) throws -> BackwardsAuroraAction {
        let actions: [BackwardsAuroraAction] = try certifiedActions(number)
        return try #require(actions.first, "level \(number) has a certified solution")
    }

    /// Advances the play through the shell by the first action of its level's certified solution. Returns whether
    /// the action was accepted.
    @discardableResult
    static func advance(_ shell: Shell) throws -> Bool {
        let number: Int = try core(shell).levelNumber
        let issued = control(try firstAction(number))
        let result: ActionResult = shell.handle(control: issued.control, values: issued.values)
        #expect(result == .accepted, "level \(number) \(issued.control) \(issued.values): \(result.code)")
        return result == .accepted
    }

    /// The same as `advance` on a bare core (no host): the CPU reference of an advanced state.
    static func advanced(_ number: Int) throws -> BackwardsAuroraExperienceCore {
        var core: BackwardsAuroraExperienceCore = try BackwardsAuroraExperienceCore.opening(number: number)
        let result: ActionResult = core.apply(experienceAction(try firstAction(number)))
        #expect(result == .accepted, "level \(number): \(result.code)")
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
    static func camera(_ snapshot: Snapshot, width: Int, height: Int) -> BackwardsAuroraCamera {
        Geometry.camera(snapshot, aspect: Double(width) / Double(height))
    }

    /// The pixel of world point `point` for `snapshot` on a `width` × `height` target (origin top left, y down; nil
    /// without a projection or for an empty target).
    static func pixel(_ point: SIMD3<Double>, _ snapshot: Snapshot, width: Int = width,
                      height: Int = height) -> SIMD2<Double>? {
        guard width > 0, height > 0,
              let v = Geometry.project(point, camera: camera(snapshot, width: width, height: height)) else { return nil }
        return SIMD2<Double>(v.x * Double(width), v.y * Double(height))
    }

    /// The pixel length of `radius` world units laid along x from `centre` (nil without a projection).
    static func pixelRadius(_ centre: SIMD3<Double>, _ radius: Double, _ snapshot: Snapshot, width: Int = width,
                            height: Int = height) -> Double? {
        guard let a = pixel(centre, snapshot, width: width, height: height),
              let b = pixel(centre + SIMD3<Double>(radius, 0, 0), snapshot, width: width, height: height) else {
            return nil
        }
        let d: SIMD2<Double> = b - a
        return (d.x * d.x + d.y * d.y).squareRoot()
    }

    /// The pixels of every sample point (position order), every ring centre (checkpoint order) and the gauge's first
    /// bar, in that order (nil without a projection). None of them depends on the tier.
    static func referencePixels(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> [SIMD2<Double>?] {
        var result: [SIMD2<Double>?] = []
        for k in 0..<snapshot.count {
            result.append(pixel(Geometry.samplePoint(k, snapshot), snapshot, width: width, height: height))
        }
        for index in snapshot.checkpoints.indices {
            result.append(pixel(Geometry.ringCentre(index, snapshot), snapshot, width: width, height: height))
        }
        result.append(pixel(Geometry.gaugeBar(0, snapshot), snapshot, width: width, height: height))
        return result
    }

    /// A round exclusion zone in pixels.
    struct Zone {
        let centre: SIMD2<Double>
        let radius: Double
    }

    /// The exclusions of `snapshot`: round zones around every ring (outer radius + clearance), kink cross and the tear
    /// cross (half span + clearance), and the x of every checkpoint tick (half width + clearance on either side).
    static func exclusions(_ snapshot: Snapshot, width: Int = width,
                           height: Int = height) -> (zones: [Zone], ticks: [(x: Double, half: Double)]) {
        var zones: [Zone] = []
        var ticks: [(x: Double, half: Double)] = []
        let outer: Double = Geometry.ringRadius + Geometry.ringLine / 2
        for index in snapshot.checkpoints.indices {
            let c: SIMD3<Double> = Geometry.ringCentre(index, snapshot)
            if let p = pixel(c, snapshot, width: width, height: height),
               let r = pixelRadius(c, outer, snapshot, width: width, height: height) {
                zones.append(Zone(centre: p, radius: r + clearance))
            }
            let position: Int = snapshot.checkpoints[index]
            let foot: SIMD3<Double> = SIMD3<Double>(Geometry.samplePoint(position, snapshot).x, 0, Geometry.tickZ)
            if let p = pixel(foot, snapshot, width: width, height: height),
               let r = pixelRadius(foot, Geometry.tickHalfWidth, snapshot, width: width, height: height) {
                ticks.append((x: p.x, half: r + clearance))
            }
        }
        var crosses: [(k: Int, span: Double)] = []
        for k in snapshot.kinks { crosses.append((k: k, span: Geometry.kinkSpan)) }
        if let seam = snapshot.tear { crosses.append((k: seam, span: Geometry.tearSpan)) }
        for cross in crosses {
            let s: SIMD3<Double> = Geometry.samplePoint(cross.k, snapshot)
            let c: SIMD3<Double> = SIMD3<Double>(s.x, s.y, Geometry.crossZ)
            if let p = pixel(c, snapshot, width: width, height: height),
               let r = pixelRadius(c, cross.span / 2, snapshot, width: width, height: height) {
                zones.append(Zone(centre: p, radius: r + clearance))
            }
        }
        return (zones, ticks)
    }

    /// Whether `p` lies in one of `exclusions`.
    static func excluded(_ p: SIMD2<Double>,
                         _ exclusions: (zones: [Zone], ticks: [(x: Double, half: Double)])) -> Bool {
        for zone in exclusions.zones {
            let d: SIMD2<Double> = p - zone.centre
            if d.x * d.x + d.y * d.y < zone.radius * zone.radius { return true }
        }
        for tick in exclusions.ticks where Swift.abs(p.x - tick.x) < tick.half {
            return true
        }
        return false
    }

    /// Whether `p` lies inside a `width` × `height` picture.
    static func inside(_ p: SIMD2<Double>, width: Int, height: Int) -> Bool {
        p.x >= 0 && p.y >= 0 && p.x < Double(width) && p.y < Double(height)
    }

    /// Whether `c` is a ribbon pixel: cyan (blue − red ≥ 0.15) and 0.15 from the ground in luminance.
    static func isRibbon(_ c: SIMD3<Double>) -> Bool {
        c.z - c.x >= ribbonCoolness && Swift.abs(luminance(c) - groundLuminance) >= ribbonMargin
    }

    /// Whether `c` is a ghost pixel: 0.1 from the ground in luminance and lilac (red − green ≥ 0.05).
    static func isGhost(_ c: SIMD3<Double>) -> Bool {
        Swift.abs(luminance(c) - groundLuminance) >= ghostMargin && c.x - c.y >= ghostLilac
    }

    /// The first sample point of `snapshot` outside every exclusion and inside the picture (its position and pixel).
    static func firstClearSample(_ snapshot: Snapshot, width: Int = width,
                                 height: Int = height) -> (k: Int, p: SIMD2<Double>)? {
        let zones = exclusions(snapshot, width: width, height: height)
        for k in 0..<snapshot.count {
            guard let p = pixel(Geometry.samplePoint(k, snapshot), snapshot, width: width, height: height),
                  inside(p, width: width, height: height), !excluded(p, zones) else { continue }
            return (k, p)
        }
        return nil
    }

    /// The ribbon and ghost checks of clarification Q3 (see the file header) on `rgba` against `snapshot`.
    static func pointReport(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width,
                            height: Int = height) -> BackwardsAuroraFrameReport {
        var report = BackwardsAuroraFrameReport()
        let zones = exclusions(snapshot, width: width, height: height)
        for k in 0..<snapshot.count {
            guard let p = pixel(Geometry.samplePoint(k, snapshot), snapshot, width: width, height: height),
                  inside(p, width: width, height: height) else {
                report.misses.append("sample \(k): it does not project into the picture")
                continue
            }
            if excluded(p, zones) {
                report.ribbonExcluded += 1
                continue
            }
            report.ribbonChecked += 1
            if !anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height, where: isRibbon) {
                let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
                report.misses.append(String(format: "ribbon at sample %ld (%.1f, %.1f) is (%.3f, %.3f, %.3f)", k, p.x,
                                            p.y, c.x, c.y, c.z))
            }
        }
        let n: Int = Swift.min(snapshot.count, snapshot.target.count)
        for k in 0..<n where Swift.abs(snapshot.samples[k] - snapshot.target[k]) >= ghostGap {
            guard let p = pixel(Geometry.targetPoint(k, snapshot), snapshot, width: width, height: height),
                  inside(p, width: width, height: height) else {
                report.misses.append("target \(k): it does not project into the picture")
                continue
            }
            if excluded(p, zones) { continue }
            report.ghostChecked += 1
            if !anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height, where: isGhost) {
                let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
                report.misses.append(String(format: "ghost at target %ld (%.1f, %.1f) is (%.3f, %.3f, %.3f)", k, p.x,
                                            p.y, c.x, c.y, c.z))
            }
        }
        return report
    }

    /// The gauge check: within 3 px of the first bar's centre, a pixel 0.1 away from the ground in luminance.
    static func gaugeMisses(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width,
                            height: Int = height) -> [String] {
        guard snapshot.budget > 0 else { return ["gauge: no budget"] }
        guard let p = pixel(Geometry.gaugeBar(0, snapshot), snapshot, width: width, height: height) else {
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

    /// Runs the checks of clarification Q3 on `rgba` against `snapshot`, recording an issue per failure, and returns
    /// the report. `ghost` false leaves out the ghost check (the unlit fallback keeps the ribbon, gauge and background).
    @discardableResult
    static func checkFrame(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width, height: Int = height,
                           ghost: Bool = true, _ what: String,
                           sourceLocation: SourceLocation = #_sourceLocation) -> BackwardsAuroraFrameReport {
        #expect(rgba.count == width * height * 4, "\(what): picture size", sourceLocation: sourceLocation)
        guard rgba.count == width * height * 4 else { return BackwardsAuroraFrameReport() }
        var report: BackwardsAuroraFrameReport = pointReport(rgba, snapshot: snapshot, width: width, height: height)
        if !ghost {
            var kept: [String] = []
            for miss in report.misses where !miss.hasPrefix("ghost") { kept.append(miss) }
            report.misses = kept
        }
        #expect(report.ribbonChecked > 0, "\(what): no sample point clear of the markers",
                sourceLocation: sourceLocation)
        #expect(report.misses.isEmpty, "\(what): \(report.misses.prefix(8))", sourceLocation: sourceLocation)
        let gauge: [String] = gaugeMisses(rgba, snapshot: snapshot, width: width, height: height)
        #expect(gauge.isEmpty, "\(what): \(gauge)", sourceLocation: sourceLocation)
        let background: [String] = backgroundMisses(rgba, width: width, height: height)
        #expect(background.isEmpty, "\(what): \(background)", sourceLocation: sourceLocation)
        let note: String = String(format: "backwards-aurora %@: ribbon checked %ld, excluded %ld; ghost checked %ld",
                                  what, report.ribbonChecked, report.ribbonExcluded, report.ghostChecked)
        print(note)
        return report
    }

    // MARK: Tear search

    /// The levels searched for a tearing reversal, in order: the bands with a breaking limit below 128 first (the
    /// checked levels 81, 61 and 41, already certified by the render tests), then the rest of 41 … 100.
    static var tearSearchOrder: [Int] {
        var order: [Int] = [81, 61, 41]
        for level in 82...100 { order.append(level) }
        for level in 62...80 { order.append(level) }
        for level in 42...60 { order.append(level) }
        return order
    }

    /// A deterministic search for a reversal from a level's opening that tears with the torn seam's sample point
    /// inside the check-size picture: every section the level allows, starts ascending then lengths ascending. Returns
    /// the level, the reversal and the seam; nil when none is found.
    static func tearFailure() throws -> (level: Int, action: BackwardsAuroraAction, seam: Int)? {
        for level in tearSearchOrder {
            let core: BackwardsAuroraExperienceCore = try BackwardsAuroraExperienceCore.opening(number: level)
            let n: Int = core.play.wave.count
            let lengths: ClosedRange<Int> = core.play.level.sectionLengths
            for start in 0..<n {
                for length in lengths {
                    let end: Int = start + length - 1
                    guard end < n else { continue }
                    let action: BackwardsAuroraAction = .reverse(start, end)
                    var copy: BackwardsAuroraExperienceCore = core
                    guard copy.apply(experienceAction(action)) == .accepted else { continue }
                    guard case let .tear(_, seam)? = copy.play.failure else { continue }
                    let snapshot: Snapshot = copy.snapshot(sectionStart: 0, sectionEnd: 1, time: 0)
                    guard let p = pixel(Geometry.samplePoint(seam, snapshot), snapshot),
                          inside(p, width: width, height: height) else { continue }
                    return (level, action, seam)
                }
            }
        }
        return nil
    }
}
#endif
