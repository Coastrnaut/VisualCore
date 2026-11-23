// EchoCartographerTestSupport — feature 403 (R02-G11-03) T-R02G1103-006 (FR-R02G1103-001 … 007; SC-R02G1103-001,
// 002; clarifications Q1–Q5). Shared helpers of the Echo Cartographer experience tests, following the Backwards Aurora
// harness (feature 393): opening the experience through the one app's session host (seed `s` prepares level
// `s % 100 + 1`; a session without a quality pin is pinned to level 0), advancing the play by one pulse from the
// level's entry (`cell.pulse` with the entry's column and row: the entry is the one cell known open at the opening, so
// the pulse is always accepted and reveals the walls its rays strike), drawing live frames, drawing an off-screen still
// (RGBA8, rows top-down: the host's `renderOffscreen` flips the GL read-back, so the still has the orientation of the
// Core's CPU projection `EchoCartographerSceneGeometry.project`, origin top left, y down, scaled here to pixels), the
// engine digest, and the frame checks of clarification Q3 at 1,152 × 768. The reference points are the Core's
// `EchoCartographerSceneGeometry.referencePoints(_:)` (every known-open cell's floor-tile centre, every known wall's
// top-face centre, the entry, every marker's centre, the gauge's first bar), projected through the camera at the
// target's aspect; the "other elements" a checked point keeps clear of are all those points plus the top of every
// located beacon's pillar. A point is checked only when it projects into the picture at least 6 px from every other
// element (so the entry's own floor tile, under the entry diamond, is left out):
//   - a floor-tile centre has, within 3 px, a pixel whose luminance differs from the ground's by at least 0.1;
//   - a wall's top-face centre has, within 3 px, a pixel whose luminance differs from the ground's by at least 0.08
//     with green above red by at least 0.05 (the dark mint face);
//   - the gauge's first bar has, within 3 px of its centre, a pixel at least 0.1 away from the ground in luminance;
//   - the two probe corners (0.02, 0.02) and (0.98, 0.98) of the view are within 0.05 per channel of the ground.
// Luminance is the Rec. 709 weighting of the stored 0 … 1 channel values. Positions come from the presenter's
// `lastSnapshot` (the snapshot it drew). Short runs only (no sleep, no wall-clock assertion).
#if os(iOS)
import CoreGraphics
import EchoCartographerCore
import Foundation
import Testing
import UIKit
@testable import EchoCartographerExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the point checks of one frame found.
struct EchoCartographerFrameReport {
    /// The floor-tile centres measured, and those left out by the 6-pixel clearance.
    var floorChecked: Int = 0
    var floorExcluded: Int = 0
    /// The wall top-face centres measured, and those left out by the 6-pixel clearance.
    var wallChecked: Int = 0
    var wallExcluded: Int = 0
    /// Every failed check, in words.
    var misses: [String] = []
}

/// Building, opening, drawing and measuring Echo Cartographer.
@MainActor
enum EchoCartographerTest {
    typealias Geometry = EchoCartographerSceneGeometry
    typealias Palette = EchoCartographerPalette
    typealias Snapshot = EchoCartographerSceneSnapshot
    typealias Shell = ExperienceShell<EchoCartographerPresenter>

    /// The experience id `r02-g11.echo-cartographer`.
    static var id: ExperienceID {
        EchoCartographerExperience.id ?? ExperienceID(rawValue: "r02-g11.unknown")!
    }

    /// The frame-check size of clarification Q3, aspect 1.5.
    static let width: Int = 1_152
    static let height: Int = 768
    /// The seeds of the checked levels 1, 21, 41, 61 and 81 (seed = level − 1).
    static let seeds: [UInt64] = [0, 20, 40, 60, 80]
    /// The search radius (pixels) of every point check.
    static let pointRadius: Double = 3
    /// The clearance (pixels) of every checked point from every other element.
    static let clearance: Double = 6
    /// The floor tile's luminance difference from the ground.
    static let floorMargin: Double = 0.1
    /// The wall top's luminance difference from the ground.
    static let wallMargin: Double = 0.08
    /// The wall top's mint (green − red).
    static let wallMint: Double = 0.05
    /// The luminance difference from the ground near the gauge's first bar.
    static let gaugeMargin: Double = 0.1
    /// How close (luminance) an unlit gauge bar's centre is to the unlit colour (the gauge is emissive: no lighting).
    static let gaugeUnlitTolerance: Double = 0.03
    /// The per-channel bound of the ground.
    static let backgroundTolerance: Double = 0.05
    /// The ground probe points (fractions of the view, origin top left).
    static let backgroundPoints: [(x: Double, y: Double)] = [(0.02, 0.02), (0.98, 0.98)]

    /// Opens Echo Cartographer with `seed` in `session` through the factory, lays the view out at `size` points and
    /// draws one frame. A session without a quality pin is pinned to level 0. `configure` runs on the presenter before
    /// its first `setup` (the fallback seam).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false, size: CGSize = CGSize(width: 48, height: 32),
                     configure: ((EchoCartographerPresenter) -> Void)? = nil) async throws -> Shell {
        let id: ExperienceID = self.id
        var made: Shell?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: seed) {
            let shell: Shell = EchoCartographerExperience.make(id: id, reduceMotion: reduceMotion,
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
    static func core(_ shell: Shell) throws -> EchoCartographerExperienceCore {
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
    static func control(_ action: EchoCartographerAction) -> (control: String, values: [Double]) {
        switch action {
        case let .pulse(x, y):
            ("cell.pulse", [Double(x), Double(y)])
        case let .claim(x, y):
            ("cell.claim", [Double(x), Double(y)])
        case let .mark(x, y):
            ("cell.mark", [Double(x), Double(y)])
        }
    }

    /// The host action of `action` (step 0).
    static func experienceAction(_ action: EchoCartographerAction) -> ExperienceAction {
        let issued = control(action)
        return ExperienceAction(control: issued.control, values: issued.values, step: 0)
    }

    /// The certified solution (witness actions) of level `number`.
    static func certifiedActions(_ number: Int) throws -> [EchoCartographerAction] {
        try EchoCartographerExperienceCore.generated(number: number).actions
    }

    /// The pulse from level `number`'s entry.
    static func entryPulse(_ number: Int) throws -> EchoCartographerAction {
        let entry: EchoCartographerCell = try EchoCartographerExperienceCore.level(number: number).entry
        return .pulse(entry.x, entry.y)
    }

    /// Advances the play through the shell by one pulse from its level's entry. Returns whether the pulse was
    /// accepted.
    @discardableResult
    static func advance(_ shell: Shell) throws -> Bool {
        let number: Int = try core(shell).levelNumber
        let issued = control(try entryPulse(number))
        let result: ActionResult = shell.handle(control: issued.control, values: issued.values)
        #expect(result == .accepted, "level \(number) \(issued.control) \(issued.values): \(result.code)")
        return result == .accepted
    }

    /// The same as `advance` on a bare core (no host): the CPU reference of an advanced state.
    static func advanced(_ number: Int) throws -> EchoCartographerExperienceCore {
        var core: EchoCartographerExperienceCore = try EchoCartographerExperienceCore.opening(number: number)
        let result: ActionResult = core.apply(experienceAction(try entryPulse(number)))
        #expect(result == .accepted, "level \(number): \(result.code)")
        return core
    }

    /// Pulses from the entry through the shell until the play leaves stage `playing` (the energy runs out: the
    /// `fixture-budget-out` path), at most the level's budget; returns the pulses accepted.
    @discardableResult
    static func pulseUntilEmpty(_ shell: Shell) throws -> Int {
        let start: EchoCartographerExperienceCore = try core(shell)
        let budget: Int = start.play.level.energy
        let issued = control(try entryPulse(start.levelNumber))
        var accepted: Int = 0
        for _ in 0..<budget {
            guard try core(shell).play.stage == .playing else { break }
            let result: ActionResult = shell.handle(control: issued.control, values: issued.values)
            #expect(result == .accepted, "pulse \(accepted + 1): \(result.code)")
            guard result == .accepted else { break }
            accepted += 1
        }
        return accepted
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
    static func camera(_ snapshot: Snapshot, width: Int, height: Int) -> EchoCartographerCamera {
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

    /// The world reference points of `snapshot` in a fixed order: floors (cell order), walls (cell order), the entry,
    /// markers (marker order), the gauge's first bar. None of them depends on the tier.
    static func referenceWorldPoints(_ snapshot: Snapshot) -> [SIMD3<Double>] {
        let reference: EchoCartographerReferencePoints = Geometry.referencePoints(snapshot)
        var points: [SIMD3<Double>] = []
        for p in reference.floors { points.append(p) }
        for p in reference.walls { points.append(p) }
        points.append(reference.entry)
        for p in reference.markers { points.append(p) }
        points.append(reference.firstGaugeBar)
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

    /// The pixels of every element a checked point keeps clear of: every reference point and the top of every located
    /// beacon's pillar (points without a projection are left out).
    static func elementPixels(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> [SIMD2<Double>] {
        var result: [SIMD2<Double>] = []
        for p in referencePixels(snapshot, width: width, height: height) {
            if let p { result.append(p) }
        }
        for cell in snapshot.located {
            if let p = pixel(Geometry.pillarTop(cell, snapshot), snapshot, width: width, height: height) {
                result.append(p)
            }
        }
        return result
    }

    /// Whether `p` is at least `clearance` pixels from every element of `elements` except one at `p` itself counted
    /// once (the point being checked).
    static func isClear(_ p: SIMD2<Double>, among elements: [SIMD2<Double>]) -> Bool {
        var selfSkipped: Bool = false
        for e in elements {
            let d: SIMD2<Double> = e - p
            let distance: Double = (d.x * d.x + d.y * d.y).squareRoot()
            if distance == 0, !selfSkipped {
                selfSkipped = true
                continue
            }
            if distance < clearance { return false }
        }
        return true
    }

    /// Whether `p` lies inside a `width` × `height` picture.
    static func inside(_ p: SIMD2<Double>, width: Int, height: Int) -> Bool {
        p.x >= 0 && p.y >= 0 && p.x < Double(width) && p.y < Double(height)
    }

    /// Whether `c` is a floor-tile pixel: 0.1 from the ground in luminance.
    static func isFloor(_ c: SIMD3<Double>) -> Bool {
        Swift.abs(luminance(c) - groundLuminance) >= floorMargin
    }

    /// Whether `c` is a wall-top pixel: 0.08 from the ground in luminance and mint (green − red ≥ 0.05).
    static func isWallTop(_ c: SIMD3<Double>) -> Bool {
        Swift.abs(luminance(c) - groundLuminance) >= wallMargin && c.y - c.x >= wallMint
    }

    /// The first floor-tile centre of `snapshot` inside the picture and clear of every other element (its index in
    /// the floors and its pixel).
    static func firstClearFloor(_ snapshot: Snapshot, width: Int = width,
                                height: Int = height) -> (index: Int, p: SIMD2<Double>)? {
        let elements: [SIMD2<Double>] = elementPixels(snapshot, width: width, height: height)
        let floors: [SIMD3<Double>] = Geometry.referencePoints(snapshot).floors
        for index in floors.indices {
            guard let p = pixel(floors[index], snapshot, width: width, height: height),
                  inside(p, width: width, height: height), isClear(p, among: elements) else { continue }
            return (index, p)
        }
        return nil
    }

    /// The floor and wall checks of clarification Q3 (see the file header) on `rgba` against `snapshot`.
    static func pointReport(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width,
                            height: Int = height) -> EchoCartographerFrameReport {
        var report = EchoCartographerFrameReport()
        let elements: [SIMD2<Double>] = elementPixels(snapshot, width: width, height: height)
        let reference: EchoCartographerReferencePoints = Geometry.referencePoints(snapshot)
        for index in reference.floors.indices {
            guard let p = pixel(reference.floors[index], snapshot, width: width, height: height),
                  inside(p, width: width, height: height) else {
                report.misses.append("floor \(index): it does not project into the picture")
                continue
            }
            if !isClear(p, among: elements) {
                report.floorExcluded += 1
                continue
            }
            report.floorChecked += 1
            if !anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height, where: isFloor) {
                let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
                report.misses.append(String(format: "floor %ld (%.1f, %.1f) is (%.3f, %.3f, %.3f)", index, p.x, p.y,
                                            c.x, c.y, c.z))
            }
        }
        for index in reference.walls.indices {
            guard let p = pixel(reference.walls[index], snapshot, width: width, height: height),
                  inside(p, width: width, height: height) else {
                report.misses.append("wall \(index): it does not project into the picture")
                continue
            }
            if !isClear(p, among: elements) {
                report.wallExcluded += 1
                continue
            }
            report.wallChecked += 1
            if !anyPixel(rgba, near: p, radius: pointRadius, width: width, height: height, where: isWallTop) {
                let c: SIMD3<Double> = centre(rgba, p, width: width, height: height)
                report.misses.append(String(format: "wall %ld (%.1f, %.1f) is (%.3f, %.3f, %.3f)", index, p.x, p.y,
                                            c.x, c.y, c.z))
            }
        }
        return report
    }

    /// The pixel of the gauge's first bar's centre (nil without a projection).
    static func gaugePixel(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> SIMD2<Double>? {
        pixel(Geometry.referencePoints(snapshot).firstGaugeBar, snapshot, width: width, height: height)
    }

    /// The gauge check: within 3 px of the first bar's centre, a pixel 0.1 away from the ground in luminance.
    static func gaugeMisses(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width,
                            height: Int = height) -> [String] {
        guard snapshot.budget > 0 else { return ["gauge: no budget"] }
        guard let p = gaugePixel(snapshot, width: width, height: height) else {
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
    /// the report. `known` true (a state after a pulse) also requires at least one floor-tile centre and one wall top
    /// to be checked; at the opening only the entry is known open and its tile lies under the entry diamond (closer
    /// than 6 px), so an opening frame passes `known: false` and is checked at the gauge and the background.
    @discardableResult
    static func checkFrame(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width, height: Int = height,
                           known: Bool = true, _ what: String,
                           sourceLocation: SourceLocation = #_sourceLocation) -> EchoCartographerFrameReport {
        #expect(rgba.count == width * height * 4, "\(what): picture size", sourceLocation: sourceLocation)
        guard rgba.count == width * height * 4 else { return EchoCartographerFrameReport() }
        let report: EchoCartographerFrameReport = pointReport(rgba, snapshot: snapshot, width: width, height: height)
        if known {
            #expect(report.floorChecked > 0, "\(what): no floor-tile centre clear of the other elements",
                    sourceLocation: sourceLocation)
            #expect(report.wallChecked > 0, "\(what): no wall top clear of the other elements",
                    sourceLocation: sourceLocation)
        }
        let shown: [String] = Array(report.misses.prefix(8))
        #expect(report.misses.isEmpty, "\(what): \(shown)", sourceLocation: sourceLocation)
        let gauge: [String] = gaugeMisses(rgba, snapshot: snapshot, width: width, height: height)
        #expect(gauge.isEmpty, "\(what): \(gauge)", sourceLocation: sourceLocation)
        let background: [String] = backgroundMisses(rgba, width: width, height: height)
        #expect(background.isEmpty, "\(what): \(background)", sourceLocation: sourceLocation)
        let floors: String = String(format: "floor checked %ld, excluded %ld", report.floorChecked,
                                    report.floorExcluded)
        let wallNote: String = String(format: "wall checked %ld, excluded %ld", report.wallChecked,
                                      report.wallExcluded)
        print("echo-cartographer \(what): \(floors); \(wallNote)")
        return report
    }

    // MARK: Tier geometry

    /// The positions of `mesh` without the ring field's vertices (material code 5, drawn only at a tier with rings).
    static func positionsWithoutRingField(_ mesh: Mesh) -> [Vec3] {
        var result: [Vec3] = []
        let ring: Int = EchoCartographerShaders.ringMaterial
        for index in mesh.positions.indices {
            let code: Int = index < mesh.uvs.count ? Int(mesh.uvs[index].x.rounded()) : -1
            if code != ring { result.append(mesh.positions[index]) }
        }
        return result
    }
}
#endif
