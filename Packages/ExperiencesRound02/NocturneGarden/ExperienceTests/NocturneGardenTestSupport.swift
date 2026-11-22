// NocturneGardenTestSupport — feature 383 (R02-G09-03) T-R02G0903-006 (FR-R02G0903-001 … 007; SC-R02G0903-001, 002;
// clarifications Q1–Q5). Shared helpers of the Nocturne Garden experience tests, following the Faceted Forge harness
// (feature 373): opening the experience through the one app's session host (seed `s` prepares level `s % 100 + 1`; a
// session without a quality pin is pinned to level 0), advancing the play to the witness's first plant (the certified
// solution's actions up to and including its first `bloom.plant`, so a solution that opens with a sun move makes that
// move first), drawing live frames, drawing an off-screen still (RGBA8, rows top-down: the host's `renderOffscreen` flips
// the GL read-back, so the still has the orientation of the Core's CPU projection `NocturneGardenSceneGeometry.pixel`,
// origin top left, y down), the engine digest, and the frame checks of clarification Q3 at 1,152 × 768, made at the
// projected centre of every bed cell that lies outside every bloom's exclusion box:
//   - every shadow cell (the kernel's mask; after a leak failure the crossed leaking cells are left to the leak check)
//     has, within 3 px of its centre, a pixel at least 0.15 darker in luminance than the mist reference;
//   - every forbidden cell outside the shadow has, within 3 px, a pixel with red − blue at least 0.15 (the coral hatch:
//     both its lines and its coral-tinted gaps pass);
//   - every target cell outside the shadow has, within 3 px, a pixel at least 0.15 brighter in luminance than the
//     shadow reference;
//   - the gauge's first bar not under a bloom's box (bar 0 unless a stem crosses it) has, within 3 px, a pixel that
//     differs from the ground by at least 0.1 in luminance;
//   - the two probe corners (0.02, 0.02) and (0.98, 0.98) of the view are within 0.05 per channel of the ground.
// References, chosen to be robust: the mist reference is the mean luminance of the centre pixels of the plain mist cells
// that were checked (not shadow, not forbidden, not target, outside every box) — measured, so the drifting mist bands
// and the light are taken as drawn — and it must itself be at least the palette mist lit by the ambient term alone
// (`luminance(mist) × NocturneGardenShaders.ambient`, the darkest the lit mist can be) less 0.05, which proves the mist
// is drawn; when no plain mist cell is visible that palette floor is used. The shadow reference is the mean centre
// luminance of the checked shadow cells, or the palette shadow's luminance when none is visible.
// The exclusion box of a bloom is the union of the Core's `bloomPixelBox` (head and stem, the same at every tier) and
// the projected bounds of its richest glow shells (the head outline scaled by 1 + 0.08 × 2 about its vertex mean, from
// the shells' depth to the head's front face): the additive glow of level-0 can reach past the head's outline, and it
// would brighten a shadow cell. Every box is widened by 6 px: the 3 px of the sampling disc plus 3 px for the sway
// (at most 0.008 world units, about 2 px here) and edge antialiasing. Positions come from the presenter's
// `lastSnapshot` (the snapshot it drew). Luminance is the Rec. 709 weighting of the stored 0 … 1 channel values. Short
// runs only (no sleep, no wall-clock assertion).
#if os(iOS)
import CoreGraphics
import Foundation
import NocturneGardenCore
import Testing
import UIKit
@testable import NocturneGardenExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the cell checks of one frame found.
struct NocturneGardenCellReport {
    /// The bed cells measured (outside every exclusion box).
    var checked: Int = 0
    /// The bed cells left out because a bloom's box covers them.
    var excluded: Int = 0
    /// The shadow, forbidden, target and plain mist cells measured.
    var shadow: Int = 0
    var forbidden: Int = 0
    var target: Int = 0
    var mist: Int = 0
    /// The mist and shadow references (luminance).
    var mistReference: Double = 0
    var shadowReference: Double = 0
    /// Every failed check, in words.
    var misses: [String] = []
}

/// Building, opening, drawing and measuring Nocturne Garden.
@MainActor
enum NocturneGardenTest {
    typealias Geometry = NocturneGardenSceneGeometry
    typealias Palette = NocturneGardenPalette
    typealias Snapshot = NocturneGardenSceneSnapshot
    typealias Shell = ExperienceShell<NocturneGardenPresenter>
    typealias Box = (min: Vec2, max: Vec2)

    /// The experience id `r02-g09.nocturne-garden`.
    static var id: ExperienceID {
        NocturneGardenExperience.id ?? ExperienceID(rawValue: "r02-g09.unknown")!
    }

    /// The frame-check size of clarification Q3, aspect 1.5.
    static let width: Int = 1_152
    static let height: Int = 768
    /// The seeds of the checked levels 1, 21, 41, 61 and 81 (seed = level − 1).
    static let seeds: [UInt64] = [0, 20, 40, 60, 80]
    /// The search radius (pixels) of every point check.
    static let pointRadius: Double = 3
    /// How far (pixels) every bloom's exclusion box is widened: the sampling disc plus sway and antialiasing.
    static let boxPad: Double = 6
    /// How much darker than the mist reference a shadow cell is.
    static let shadowMargin: Double = 0.15
    /// The warmth (red − blue) of a forbidden cell outside the shadow.
    static let forbiddenWarmth: Double = 0.15
    /// How much brighter than the shadow reference a target cell outside the shadow is.
    static let targetMargin: Double = 0.15
    /// The luminance difference from the ground near the gauge's first visible bar.
    static let gaugeMargin: Double = 0.1
    /// The warmth (red − blue) of a crossed leaking cell.
    static let leakWarmth: Double = 0.15
    /// The per-channel bound of the ground.
    static let backgroundTolerance: Double = 0.05
    /// The ground probe points (fractions of the view, origin top left).
    static let backgroundPoints: [(x: Double, y: Double)] = [(0.02, 0.02), (0.98, 0.98)]

    /// Opens Nocturne Garden with `seed` in `session` through the factory, lays the view out at `size` points and
    /// draws one frame. A session without a quality pin is pinned to level 0. `configure` runs on the presenter before
    /// its first `setup` (the fallback seam).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false, size: CGSize = CGSize(width: 48, height: 32),
                     configure: ((NocturneGardenPresenter) -> Void)? = nil) async throws -> Shell {
        let id: ExperienceID = self.id
        var made: Shell?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: seed) {
            let shell: Shell = NocturneGardenExperience.make(id: id, reduceMotion: reduceMotion,
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
    static func core(_ shell: Shell) throws -> NocturneGardenExperienceCore {
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
    static func control(_ action: NocturneGardenAction) -> (control: String, values: [Double]) {
        switch action {
        case let .plant(kind, column, row, size):
            ("bloom.plant", [Double(kind.order), Double(column), Double(row), Double(size)])
        case let .move(bloom, column, row):
            ("bloom.move", [Double(bloom), Double(column), Double(row)])
        case let .resize(bloom, size):
            ("bloom.resize", [Double(bloom), Double(size)])
        case let .remove(bloom):
            ("bloom.remove", [Double(bloom)])
        case let .sun(elevation):
            ("sun.set", [Double(elevation)])
        }
    }

    /// The host action of `action` (step 0).
    static func experienceAction(_ action: NocturneGardenAction) -> ExperienceAction {
        let issued = control(action)
        return ExperienceAction(control: issued.control, values: issued.values, step: 0)
    }

    /// The certified solution of level `number`.
    static func certifiedActions(_ number: Int) throws -> [NocturneGardenAction] {
        try NocturneGardenExperienceCore.generated(number: number).solution.actions
    }

    /// The certified solution of level `number` up to and including its first plant (a leading sun move is made
    /// first); the whole solution when it has no plant.
    static func firstPlant(_ number: Int) throws -> [NocturneGardenAction] {
        let actions: [NocturneGardenAction] = try certifiedActions(number)
        var prefix: [NocturneGardenAction] = []
        for action in actions {
            prefix.append(action)
            if case .plant = action { break }
        }
        return prefix
    }

    /// Advances the play through the shell to the witness's first plant of the shell's level. Returns the number of
    /// accepted actions (the prefix's length on a fresh level).
    @discardableResult
    static func advance(_ shell: Shell) throws -> Int {
        let number: Int = try core(shell).levelNumber
        let actions: [NocturneGardenAction] = try firstPlant(number)
        #expect(!actions.isEmpty, "level \(number) has a certified solution")
        var accepted: Int = 0
        for action in actions {
            let issued = control(action)
            let result: ActionResult = shell.handle(control: issued.control, values: issued.values)
            #expect(result == .accepted, "level \(number) \(issued.control) \(issued.values): \(result.code)")
            if result == .accepted { accepted += 1 }
        }
        return accepted
    }

    /// The same as `advance` on a bare core (no host): the CPU reference of an advanced state.
    static func advanced(_ number: Int) throws -> NocturneGardenExperienceCore {
        var core: NocturneGardenExperienceCore = try NocturneGardenExperienceCore.opening(number: number)
        for action in try firstPlant(number) {
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

    /// The luminance of the ground.
    static var groundLuminance: Double { luminance(Palette.ground) }

    /// The darkest the lit mist can be: the palette mist lit by the ambient term alone.
    static var mistFloor: Double { luminance(Palette.mist) * NocturneGardenShaders.ambient }

    /// The mean luminance of a picture.
    static func meanLuminance(_ rgba: [UInt8]) -> Double {
        var sum: Double = 0
        var count: Int = 0
        var i: Int = 0
        while i + 3 < rgba.count {
            let c = SIMD3<Double>(Double(rgba[i]) / 255, Double(rgba[i + 1]) / 255, Double(rgba[i + 2]) / 255)
            sum += luminance(c)
            count += 1
            i += 4
        }
        return count > 0 ? sum / Double(count) : 0
    }

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

    /// Whether some pixel whose centre lies within `radius` of (`px`, `py`) passes `test`.
    static func anyPixel(_ rgba: [UInt8], near px: Double, _ py: Double, radius: Double, width: Int, height: Int,
                         where test: (SIMD3<Double>) -> Bool) -> Bool {
        let reach: Int = Int(radius.rounded(.up)) + 1
        let cx: Int = Int(px.rounded(.down))
        let cy: Int = Int(py.rounded(.down))
        for y in (cy - reach)...(cy + reach) {
            guard y >= 0, y < height else { continue }
            for x in (cx - reach)...(cx + reach) {
                guard x >= 0, x < width else { continue }
                let dx: Double = Double(x) + 0.5 - px
                let dy: Double = Double(y) + 0.5 - py
                guard dx * dx + dy * dy <= radius * radius else { continue }
                if test(colour(rgba, x: x, y: y, width: width)) { return true }
            }
        }
        return false
    }

    /// The colour of the pixel that holds (`px`, `py`), clamped to the picture.
    static func centre(_ rgba: [UInt8], _ px: Double, _ py: Double, width: Int, height: Int) -> SIMD3<Double> {
        let x: Int = Swift.min(Swift.max(Int(px.rounded(.down)), 0), width - 1)
        let y: Int = Swift.min(Swift.max(Int(py.rounded(.down)), 0), height - 1)
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
    static func camera(_ snapshot: Snapshot, width: Int, height: Int) -> NocturneGardenCamera {
        Geometry.camera(snapshot, aspect: Double(width) / Double(height))
    }

    /// The pixel of world point `point` for `snapshot` on a `width` × `height` target (nil without a projection).
    static func pixel(_ point: SIMD3<Double>, _ snapshot: Snapshot, width: Int = width,
                      height: Int = height) -> Vec2? {
        Geometry.pixel(point, camera: camera(snapshot, width: width, height: height), width: width, height: height)
    }

    /// The pixels of every bed cell's centre (cell order), every gauge bar's centre and the lantern, in that order
    /// (nil without a projection). None of them depends on the tier.
    static func referencePixels(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> [Vec2?] {
        var result: [Vec2?] = []
        for cell in 0..<(snapshot.width * snapshot.height) {
            result.append(pixel(Geometry.cellCentre(cell, snapshot), snapshot, width: width, height: height))
        }
        for bar in 0..<Swift.max(snapshot.budget, 0) {
            result.append(pixel(Geometry.gaugeBar(bar, snapshot), snapshot, width: width, height: height))
        }
        result.append(pixel(Geometry.lantern(snapshot), snapshot, width: width, height: height))
        return result
    }

    /// The exclusion box of every bloom of `snapshot` (see the file header), not yet widened. A bloom whose box does
    /// not project gets the whole picture (nothing near it is checked).
    static func bloomBoxes(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> [Box] {
        let cam: NocturneGardenCamera = camera(snapshot, width: width, height: height)
        let richest: NocturneGardenTier = NocturneGardenTier.all[0]
        let whole: Box = (Vec2(0, 0), Vec2(Double(width), Double(height)))
        let u: Double = Geometry.cellSize(snapshot)
        let growth: Double = 1 + Geometry.glowGrowth * Double(richest.glowShells)
        let depths: [Double] = [Geometry.bloomZ - Geometry.glowLift * Double(richest.glowShells),
                                Geometry.bloomZ + Geometry.headDepth]
        var boxes: [Box] = []
        for index in snapshot.blooms.indices {
            guard let box = Geometry.bloomPixelBox(index, snapshot, tier: richest, camera: cam, width: width,
                                                   height: height) else {
                boxes.append(whole)
                continue
            }
            var low: Vec2 = box.min
            var high: Vec2 = box.max
            let bloom: NocturneGardenBloom = snapshot.blooms[index]
            // The head is drawn at headScale·size·u (spec clarification Q1, corrected on 2026-11-22).
            let scale: Double = Double(Swift.min(Swift.max(bloom.size, 1), 3)) * u * Geometry.headScale
            let foot = SIMD2<Double>(-Geometry.bedHalfWidth + Double(bloom.column) * u, Double(bloom.row) * u)
            var outline: [SIMD2<Double>] = []
            for p in bloom.kind.outline {
                outline.append(foot + SIMD2<Double>(Double(p.x), Double(p.y)) * scale)
            }
            var mean = SIMD2<Double>(0, 0)
            for p in outline { mean += p }
            if !outline.isEmpty { mean /= Double(outline.count) }
            var projected: Bool = true
            for p in outline {
                let q: SIMD2<Double> = mean + (p - mean) * growth
                for z in depths {
                    guard let s = Geometry.pixel(SIMD3<Double>(q.x, q.y, z), camera: cam, width: width,
                                                 height: height) else {
                        projected = false
                        continue
                    }
                    low = Vec2(Swift.min(low.x, s.x), Swift.min(low.y, s.y))
                    high = Vec2(Swift.max(high.x, s.x), Swift.max(high.y, s.y))
                }
            }
            let grown: Box = (low, high)
            boxes.append(projected ? grown : whole)
        }
        return boxes
    }

    /// Whether `p` lies within `boxPad` of any of `boxes`.
    static func excluded(_ p: Vec2, _ boxes: [Box]) -> Bool {
        for box in boxes {
            if p.x >= box.min.x - boxPad, p.x <= box.max.x + boxPad, p.y >= box.min.y - boxPad,
               p.y <= box.max.y + boxPad {
                return true
            }
        }
        return false
    }

    /// Whether `p` lies inside a `width` × `height` picture.
    static func inside(_ p: Vec2, width: Int, height: Int) -> Bool {
        p.x >= 0 && p.y >= 0 && p.x < Double(width) && p.y < Double(height)
    }

    /// The cell checks of clarification Q3 (see the file header) on `rgba` against `snapshot`.
    static func cellReport(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width,
                           height: Int = height) -> NocturneGardenCellReport {
        var report = NocturneGardenCellReport()
        let boxes: [Box] = bloomBoxes(snapshot, width: width, height: height)
        let shadow: Set<Int> = Set(snapshot.shadow)
        let forbidden: Set<Int> = Set(snapshot.forbidden)
        let target: Set<Int> = Set(snapshot.target)
        let leaking: Set<Int> = snapshot.leakFailure ? Set(snapshot.leaking) : []
        var shadowPoints: [(cell: Int, p: Vec2)] = []
        var forbiddenPoints: [(cell: Int, p: Vec2)] = []
        var targetPoints: [(cell: Int, p: Vec2)] = []
        var mistSum: Double = 0
        var shadowSum: Double = 0
        for cell in 0..<(snapshot.width * snapshot.height) {
            guard let p = pixel(Geometry.cellCentre(cell, snapshot), snapshot, width: width, height: height),
                  inside(p, width: width, height: height) else {
                report.misses.append("cell \(cell): its centre does not project into the picture")
                continue
            }
            if excluded(p, boxes) {
                report.excluded += 1
                continue
            }
            report.checked += 1
            let lum: Double = luminance(centre(rgba, p.x, p.y, width: width, height: height))
            if shadow.contains(cell) {
                if leaking.contains(cell) { continue }
                shadowPoints.append((cell, p))
                shadowSum += lum
            } else if forbidden.contains(cell) {
                forbiddenPoints.append((cell, p))
            } else if target.contains(cell) {
                targetPoints.append((cell, p))
            } else {
                report.mist += 1
                mistSum += lum
            }
        }
        report.mistReference = report.mist > 0 ? mistSum / Double(report.mist) : mistFloor
        if report.mist > 0 && report.mistReference < mistFloor - 0.05 {
            report.misses.append(String(format: "the mist is too dark: %.3f (floor %.3f)", report.mistReference,
                                        mistFloor))
        }
        report.shadowReference = shadowPoints.isEmpty ? luminance(Palette.shadow)
            : shadowSum / Double(shadowPoints.count)
        let darkest: Double = report.mistReference - shadowMargin
        let dark: (SIMD3<Double>) -> Bool = { (c: SIMD3<Double>) -> Bool in Self.luminance(c) <= darkest }
        for point in shadowPoints {
            report.shadow += 1
            if !anyPixel(rgba, near: point.p.x, point.p.y, radius: pointRadius, width: width, height: height,
                         where: dark) {
                report.misses.append(String(format: "shadow cell %ld at (%.1f, %.1f) is not %.2f darker than the mist "
                                            + "%.3f", point.cell, point.p.x, point.p.y, shadowMargin,
                                            report.mistReference))
            }
        }
        let warmth: Double = forbiddenWarmth
        let warm: (SIMD3<Double>) -> Bool = { (c: SIMD3<Double>) -> Bool in c.x - c.z >= warmth }
        for point in forbiddenPoints {
            report.forbidden += 1
            if !anyPixel(rgba, near: point.p.x, point.p.y, radius: pointRadius, width: width, height: height,
                         where: warm) {
                report.misses.append(String(format: "forbidden cell %ld at (%.1f, %.1f) is not warm", point.cell,
                                            point.p.x, point.p.y))
            }
        }
        let brightest: Double = report.shadowReference + targetMargin
        let bright: (SIMD3<Double>) -> Bool = { (c: SIMD3<Double>) -> Bool in Self.luminance(c) >= brightest }
        for point in targetPoints {
            report.target += 1
            if !anyPixel(rgba, near: point.p.x, point.p.y, radius: pointRadius, width: width, height: height,
                         where: bright) {
                report.misses.append(String(format: "target cell %ld at (%.1f, %.1f) is not %.2f brighter than the "
                                            + "shadow %.3f", point.cell, point.p.x, point.p.y, targetMargin,
                                            report.shadowReference))
            }
        }
        return report
    }

    /// The gauge check: the first bar outside every exclusion box has, within 3 px of its centre, a pixel 0.1 away
    /// from the ground in luminance. Returns the bar checked (nil when none) and the misses.
    static func gaugeMisses(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width,
                            height: Int = height) -> (bar: Int?, misses: [String]) {
        guard snapshot.budget > 0 else { return (nil, ["gauge: no budget"]) }
        let boxes: [Box] = bloomBoxes(snapshot, width: width, height: height)
        let ground: Double = groundLuminance
        let margin: Double = gaugeMargin
        let test: (SIMD3<Double>) -> Bool = { (c: SIMD3<Double>) -> Bool in
            Swift.abs(Self.luminance(c) - ground) >= margin
        }
        for bar in 0..<snapshot.budget {
            guard let p = pixel(Geometry.gaugeBar(bar, snapshot), snapshot, width: width, height: height) else {
                return (bar, ["gauge bar \(bar): no projection"])
            }
            if excluded(p, boxes) { continue }
            let found: Bool = anyPixel(rgba, near: p.x, p.y, radius: pointRadius, width: width, height: height,
                                       where: test)
            return (bar, found ? [] : [String(format: "gauge bar %ld at (%.1f, %.1f) is ground", bar, p.x, p.y)])
        }
        return (nil, ["gauge: every bar lies under a bloom"])
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

    /// The leak check after a leak failure: within 3 px of every leaking cell's centre outside every exclusion box some
    /// pixel has red − blue at least 0.15 (the leak cross). Returns the cells checked and the misses.
    static func leakMisses(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width,
                           height: Int = height) -> (checked: Int, misses: [String]) {
        let boxes: [Box] = bloomBoxes(snapshot, width: width, height: height)
        let warmth: Double = leakWarmth
        let warm: (SIMD3<Double>) -> Bool = { (c: SIMD3<Double>) -> Bool in c.x - c.z >= warmth }
        var checked: Int = 0
        var misses: [String] = []
        for cell in snapshot.leaking {
            guard let p = pixel(Geometry.cellCentre(cell, snapshot), snapshot, width: width, height: height),
                  inside(p, width: width, height: height), !excluded(p, boxes) else { continue }
            checked += 1
            if !anyPixel(rgba, near: p.x, p.y, radius: pointRadius, width: width, height: height, where: warm) {
                misses.append(String(format: "leaking cell %ld at (%.1f, %.1f) is not crossed", cell, p.x, p.y))
            }
        }
        return (checked, misses)
    }

    /// Runs the checks of clarification Q3 on `rgba` against `snapshot`, recording an issue per failure, and returns
    /// the cell report. `cells` false leaves out the forbidden and target checks (the unlit fallback keeps only the
    /// shadow check, the gauge and the background).
    @discardableResult
    static func checkFrame(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width, height: Int = height,
                           cells: Bool = true, _ what: String,
                           sourceLocation: SourceLocation = #_sourceLocation) -> NocturneGardenCellReport {
        #expect(rgba.count == width * height * 4, "\(what): picture size", sourceLocation: sourceLocation)
        guard rgba.count == width * height * 4 else { return NocturneGardenCellReport() }
        var report: NocturneGardenCellReport = cellReport(rgba, snapshot: snapshot, width: width, height: height)
        if !cells {
            var kept: [String] = []
            for miss in report.misses where !miss.hasPrefix("forbidden") && !miss.hasPrefix("target") {
                kept.append(miss)
            }
            report.misses = kept
        }
        #expect(report.checked > 0, "\(what): no bed cell outside the blooms' boxes", sourceLocation: sourceLocation)
        #expect(report.misses.isEmpty, "\(what): \(report.misses.prefix(8))", sourceLocation: sourceLocation)
        let gauge = gaugeMisses(rgba, snapshot: snapshot, width: width, height: height)
        #expect(gauge.misses.isEmpty, "\(what): \(gauge.misses)", sourceLocation: sourceLocation)
        let background: [String] = backgroundMisses(rgba, width: width, height: height)
        #expect(background.isEmpty, "\(what): \(background)", sourceLocation: sourceLocation)
        let note: String = String(format: "nocturne-garden %@: cells checked %ld, excluded %ld; shadow %ld, forbidden "
                                  + "%ld, target %ld, mist %ld; mist %.3f, shadow %.3f; gauge bar %@", what,
                                  report.checked, report.excluded, report.shadow, report.forbidden, report.target,
                                  report.mist, report.mistReference, report.shadowReference,
                                  gauge.bar.map { String($0) } ?? "none")
        print(note)
        return report
    }

    // MARK: Leak search

    /// Every plant `play` could make, in a fixed order: rows, then columns ascending, then the supplied kinds in case
    /// order, then the allowed sizes descending (the larger shadows leak first).
    static func plants(_ play: NocturneGardenPlay) -> [NocturneGardenAction] {
        let level: NocturneGardenLevel = play.level
        let sizes: [Int] = level.sizes.sorted(by: >)
        var result: [NocturneGardenAction] = []
        for row in 0..<level.height {
            for column in 0..<level.width {
                for kind in NocturneGardenKind.allCases where play.available(kind) > 0 {
                    for size in sizes { result.append(.plant(kind, column, row, size)) }
                }
            }
        }
        return result
    }

    /// Whether some leaking cell of `snapshot` projects into the check-size picture outside every exclusion box.
    static func visibleLeak(_ snapshot: Snapshot) -> Bool {
        let boxes: [Box] = bloomBoxes(snapshot)
        for cell in snapshot.leaking {
            guard let p = pixel(Geometry.cellCentre(cell, snapshot), snapshot),
                  inside(p, width: width, height: height) else { continue }
            if !excluded(p, boxes) { return true }
        }
        return false
    }

    /// A deterministic search over the certified levels 1 … 100 for a play that fails by a leak with a visible leaking
    /// cell. A shadow is its head's outline stretched upward by e / 2 (e the sun elevation), so it shows above the head
    /// only for a low sun: on each level, first lower the sun to the lowest allowed (an empty bed never leaks or wins),
    /// then try every plant (`plants`) of the current play; when none leaks visibly, make the first plant that keeps
    /// the play in `playing` and try again, within the budget. Returns the level and the actions (the sun move, the
    /// keeping plants, then the leaking plant); nil when none is found.
    static func leakFailure() throws -> (level: Int, actions: [NocturneGardenAction])? {
        for level in 1...100 {
            var core: NocturneGardenExperienceCore = try NocturneGardenExperienceCore.opening(number: level)
            var actions: [NocturneGardenAction] = []
            let budget: Int = core.play.level.budget
            if let lowest = core.play.level.elevations.max(), lowest != core.play.elevation, budget > 1 {
                let sun: NocturneGardenAction = .sun(lowest)
                guard core.apply(experienceAction(sun)) == .accepted, core.play.stage == .playing else { continue }
                actions.append(sun)
            }
            for _ in 0..<budget {
                guard core.play.stage == .playing else { break }
                var keeper: NocturneGardenAction?
                for plant in plants(core.play) {
                    var copy: NocturneGardenExperienceCore = core
                    guard copy.apply(experienceAction(plant)) == .accepted else { continue }
                    if case .leak = copy.play.failure {
                        if visibleLeak(copy.snapshot(time: 0)) {
                            actions.append(plant)
                            return (level, actions)
                        }
                        continue
                    }
                    if keeper == nil && copy.play.stage == .playing { keeper = plant }
                }
                guard let next = keeper, core.apply(experienceAction(next)) == .accepted else { break }
                actions.append(next)
            }
        }
        return nil
    }
}
#endif
