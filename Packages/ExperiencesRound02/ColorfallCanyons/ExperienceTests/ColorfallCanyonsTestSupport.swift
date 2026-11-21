// ColorfallCanyonsTestSupport — feature 343 (R02-G05-03) T-R02G0503-006 (FR-R02G0503-001 … 007; SC-R02G0503-001, 002;
// clarifications Q1–Q4). Shared helpers of the Colorfall Canyons experience tests, following the Hue Compass harness
// (feature 333): opening the experience through the one app's session host (seed `s` prepares level `s % 100 + 1`, a
// session without a quality pin is pinned to level 0), letting the fluid run (open every closed valve, then a few
// ticks, so emitters flow and sheets exist), drawing live frames, drawing an off-screen still (RGBA8, rows top-down:
// the host's `renderOffscreen` flips the GL read-back, so the still has the orientation of the Core's CPU projection
// `ColorfallCanyonsSceneGeometry.pixel`, origin top left, y down), the engine digest, and the frame checks of
// clarification Q3 at 1,152 × 768:
//   - each spring emitter top lies within 3 px of a pixel whose luminance exceeds night's by at least 0.15 (checked for
//     every flowing spring; a closed or dry emitter is dimmed to 0.3 by design and is reported, not checked);
//   - each open cell top centre's pixel differs from night by at least 0.1 in luminance. The renderer draws without a
//     depth test (painter's order: terrain, features, fluid), so a cell top can be covered by a nearer, taller block's
//     side or by another cell's fluid; those covers are also non-night but a dim rock side or a thin coral sheet can
//     sit just under the 0.1 margin. The robust rule: every dry, spring-free open cell of the FRONT row (nearest the
//     camera, nothing can stand in front of it, nothing but its own top covers its centre) must pass, and at least 80 %
//     of all open cells must pass;
//   - the four pixels 2 px in from the corners, clear of the projected bounding sphere (the camera's `radius`, grown by
//     15 % for the perspective silhouette) by at least 6 px, are within 0.05 per channel of night.
// Luminance is the Rec. 709 weighting of the stored 0 … 1 channel values. Short runs only (no sleep, no wall-clock
// assertion).
#if os(iOS)
import ColorfallCanyonsCore
import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import ColorfallCanyonsExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// Building, opening, drawing and measuring Colorfall Canyons.
@MainActor
enum ColorfallCanyonsTest {
    typealias Geometry = ColorfallCanyonsSceneGeometry
    typealias Palette = ColorfallCanyonsPalette
    typealias Snapshot = ColorfallCanyonsSceneSnapshot
    typealias Shell = ExperienceShell<ColorfallCanyonsPresenter>

    /// The experience id `r02-g05.colorfall-canyons`.
    static var id: ExperienceID {
        ColorfallCanyonsExperience.id ?? ExperienceID(rawValue: "r02-g05.unknown")!
    }

    /// The frame-check size of clarification Q3, aspect 1.5.
    static let width: Int = 1_152
    static let height: Int = 768
    /// The seeds of the checked levels 1, 21, 41, 61 and 81.
    static let seeds: [UInt64] = [0, 20, 40, 60, 80]
    /// The ticks run by `flow` so the springs release and the sheets exist.
    static let flowTicks: Int = 2
    /// The search radius (pixels) of the emitter check and its luminance margin over night.
    static let pointRadius: Double = 3
    static let litMargin: Double = 0.15
    /// The luminance difference from night of an open cell top centre.
    static let cellMargin: Double = 0.1
    /// The share of all open cells that must pass the cell check.
    static let cellShare: Double = 0.8
    /// The per-channel bound of the background.
    static let backgroundTolerance: Double = 0.05
    /// How far (pixels) a background pixel must be from the projected bounding sphere.
    static let backgroundClearance: Double = 6

    /// Opens Colorfall Canyons with `seed` in `session` through the factory, lays the view out at `size` points and
    /// draws one frame. A session without a quality pin is pinned to level 0. `configure` runs on the presenter before
    /// its first `setup` (the fallback seam).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false, size: CGSize = CGSize(width: 48, height: 32),
                     configure: ((ColorfallCanyonsPresenter) -> Void)? = nil) async throws -> Shell {
        let id: ExperienceID = self.id
        var made: Shell?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: seed) {
            let shell: Shell = ColorfallCanyonsExperience.make(id: id, reduceMotion: reduceMotion,
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
    static func core(_ shell: Shell) throws -> ColorfallCanyonsExperienceCore {
        try #require(shell.engine.core)
    }

    /// Pins `session` to quality level `tier` and checks that the engine took it.
    static func pin(_ session: ExperienceSession, _ shell: Shell, tier: Int,
                    sourceLocation: SourceLocation = #_sourceLocation) {
        session.qualityPin = tier
        #expect(shell.engine.qualityTier == tier, "pinned tier \(tier)", sourceLocation: sourceLocation)
    }

    /// Lets the fluid run through the shell: opens every closed valve that still has supply (while actions are left),
    /// then steps `ticks` ticks. Returns the number of accepted actions.
    @discardableResult
    static func flow(_ shell: Shell, ticks: Int = flowTicks) throws -> Int {
        var accepted: Int = 0
        let start: Snapshot = try core(shell).snapshot(time: 0)
        for index in 0..<start.springs.count {
            let spring: Snapshot.Spring = start.springs[index]
            guard !spring.open, spring.supplyLeft > 0 else { continue }
            if shell.handle(control: "canyon.valve", values: [Double(index)]) == .accepted { accepted += 1 }
        }
        if shell.handle(control: "time.step", values: [Double(ticks)]) == .accepted { accepted += 1 }
        return accepted
    }

    /// The same as `flow` on a bare core (no host): the CPU reference of a flowing state.
    static func flowing(_ number: Int, ticks: Int = flowTicks) throws -> ColorfallCanyonsExperienceCore {
        var core: ColorfallCanyonsExperienceCore = try ColorfallCanyonsExperienceCore.opening(number: number)
        let start: Snapshot = core.snapshot(time: 0)
        for index in 0..<start.springs.count {
            let spring: Snapshot.Spring = start.springs[index]
            guard !spring.open, spring.supplyLeft > 0 else { continue }
            _ = core.apply(ExperienceAction(control: "canyon.valve", values: [Double(index)], step: 0))
        }
        _ = core.apply(ExperienceAction(control: "time.step", values: [Double(ticks)], step: 0))
        return core
    }

    // MARK: Pixels

    /// The colour (0 … 1 per channel) of pixel (`x`, `y`) of a top-down RGBA8 picture `width` pixels wide.
    static func colour(_ rgba: [UInt8], x: Int, y: Int, width: Int) -> SIMD3<Double> {
        let i: Int = (y * width + x) * 4
        return SIMD3<Double>(Double(rgba[i]) / 255, Double(rgba[i + 1]) / 255, Double(rgba[i + 2]) / 255)
    }

    /// The Rec. 709 luminance of the 0 … 1 channel values of `c`.
    static func luminance(_ c: SIMD3<Double>) -> Double {
        0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z
    }

    /// The luminance of the night background.
    static var nightLuminance: Double { luminance(Palette.night) }

    /// The largest per-channel difference of `a` and `b`.
    static func channelDistance(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        Swift.max(Swift.abs(a.x - b.x), Swift.abs(a.y - b.y), Swift.abs(a.z - b.z))
    }

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

    /// The number of pixels farther than `tolerance` per channel from night.
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

    /// Whether some pixel whose centre lies within `radius` of (`px`, `py`) satisfies `accept`.
    static func anyPixel(_ rgba: [UInt8], near px: Double, _ py: Double, radius: Double, width: Int, height: Int,
                         accept: (SIMD3<Double>) -> Bool) -> Bool {
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
                if accept(colour(rgba, x: x, y: y, width: width)) { return true }
            }
        }
        return false
    }

    /// The pixel containing the projected point (`px`, `py`), clamped into the picture.
    static func pixelAt(_ rgba: [UInt8], _ px: Double, _ py: Double, width: Int, height: Int) -> SIMD3<Double> {
        let x: Int = Swift.min(Swift.max(Int(px.rounded(.down)), 0), width - 1)
        let y: Int = Swift.min(Swift.max(Int(py.rounded(.down)), 0), height - 1)
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

    // MARK: CPU reference (clarification Q3)

    /// The camera the scene uses for `snapshot` on a `width` × `height` target.
    static func camera(_ snapshot: Snapshot, width: Int, height: Int) -> ColorfallCanyonsCamera {
        Geometry.camera(snapshot, aspect: Double(width) / Double(height))
    }

    /// The camera's world up axis: +y made perpendicular to the view direction.
    static var cameraUp: SIMD3<Double> {
        let v: SIMD3<Double> = Geometry.eyeDirection
        let up: SIMD3<Double> = SIMD3<Double>(0, 1, 0) - v * v.y
        let length: Double = (up * up).sum().squareRoot()
        return up / length
    }

    /// The projected centre and pixel radius of a sphere of `radius` world units at `centre`; nil behind the camera.
    static func disc(_ centre: SIMD3<Double>, radius: Double, camera: ColorfallCanyonsCamera, width: Int,
                     height: Int) -> (centre: Vec2, radius: Double)? {
        guard let c = Geometry.pixel(centre, camera: camera, width: width, height: height),
              let e = Geometry.pixel(centre + cameraUp * radius, camera: camera, width: width,
                                     height: height) else { return nil }
        let dx: Double = e.x - c.x
        let dy: Double = e.y - c.y
        return (c, (dx * dx + dy * dy).squareRoot())
    }

    /// The open cells of `snapshot` (ground `.open`; springs and basins sit on open ground).
    static func openCells(_ snapshot: Snapshot) -> [Int] {
        var cells: [Int] = []
        for cell in 0..<snapshot.cellCount where snapshot.grounds[cell] == .open { cells.append(cell) }
        return cells
    }

    /// The open cells of the front row (the last row, nearest the camera) that hold no fluid and no spring: nothing
    /// but their own sandstone top covers their top centre.
    static func strictCells(_ snapshot: Snapshot) -> [Int] {
        var cells: [Int] = []
        let front: Int = snapshot.rows - 1
        for cell in openCells(snapshot) where cell / snapshot.columns == front {
            if snapshot.volume(cell) == 0 && !snapshot.isSpring(cell) { cells.append(cell) }
        }
        return cells
    }

    /// The emitter check: every flowing spring's emitter top has, within 3 px, a pixel whose luminance exceeds night's
    /// by at least `margin`. Returns the emitters checked, those skipped (dimmed) and the misses.
    static func emitterMisses(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width, height: Int = height,
                              margin: Double = litMargin) -> (checked: Int, dimmed: Int, misses: [String]) {
        let cam: ColorfallCanyonsCamera = camera(snapshot, width: width, height: height)
        let threshold: Double = nightLuminance + margin
        var checked: Int = 0
        var dimmed: Int = 0
        var misses: [String] = []
        for s in 0..<snapshot.springs.count {
            guard snapshot.springs[s].flowing else {
                dimmed += 1
                continue
            }
            guard let p = Geometry.pixel(Geometry.emitterTop(s, snapshot), camera: cam, width: width,
                                         height: height) else {
                misses.append("emitter \(s): no projection")
                continue
            }
            checked += 1
            let found: Bool = anyPixel(rgba, near: p.x, p.y, radius: pointRadius, width: width, height: height) { c in
                luminance(c) >= threshold
            }
            if !found { misses.append(String(format: "emitter %ld at (%.1f, %.1f) without a lit pixel", s, p.x, p.y)) }
        }
        return (checked, dimmed, misses)
    }

    /// The cell check: the pixel of each open cell's top centre differs from night by at least `margin` in luminance.
    /// Returns the open cells checked, those that pass, and the misses among the strict (front-row) cells and among
    /// all.
    static func cellResults(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width, height: Int = height,
                            margin: Double = cellMargin)
        -> (checked: Int, passed: Int, strictChecked: Int, strictMisses: [String], misses: [String]) {
        let cam: ColorfallCanyonsCamera = camera(snapshot, width: width, height: height)
        let strict: [Int] = strictCells(snapshot)
        var checked: Int = 0
        var passed: Int = 0
        var strictChecked: Int = 0
        var strictMisses: [String] = []
        var misses: [String] = []
        for cell in openCells(snapshot) {
            let isStrict: Bool = strict.contains(cell)
            guard let p = Geometry.pixel(Geometry.cellTop(cell, snapshot), camera: cam, width: width,
                                         height: height) else {
                misses.append("cell \(cell): no projection")
                if isStrict { strictMisses.append("cell \(cell): no projection") }
                continue
            }
            checked += 1
            if isStrict { strictChecked += 1 }
            let got: SIMD3<Double> = pixelAt(rgba, p.x, p.y, width: width, height: height)
            let difference: Double = Swift.abs(luminance(got) - nightLuminance)
            if difference >= margin {
                passed += 1
            } else {
                let text: String = String(format: "cell %ld at (%.1f, %.1f): (%.3f, %.3f, %.3f) differs by %.3f",
                                          cell, p.x, p.y, got.x, got.y, got.z, difference)
                misses.append(text)
                if isStrict { strictMisses.append(text) }
            }
        }
        return (checked, passed, strictChecked, strictMisses, misses)
    }

    /// The background check: of the pixels 2 px in from each corner, those at least 6 px outside the projected
    /// bounding sphere (radius grown by 15 % for the perspective silhouette) are within 0.05 per channel of night.
    /// Returns the number checked and the misses.
    static func backgroundMisses(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width, height: Int = height)
        -> (checked: Int, misses: [String]) {
        let cam: ColorfallCanyonsCamera = camera(snapshot, width: width, height: height)
        let sphere = disc(SIMD3<Double>(0, 0, 0), radius: cam.radius, camera: cam, width: width, height: height)
        let candidates: [(x: Int, y: Int)] = [(2, 2), (width - 3, 2), (2, height - 3), (width - 3, height - 3)]
        var checked: Int = 0
        var misses: [String] = []
        for candidate in candidates {
            if let sphere {
                let dx: Double = Double(candidate.x) + 0.5 - sphere.centre.x
                let dy: Double = Double(candidate.y) + 0.5 - sphere.centre.y
                let clearance: Double = (dx * dx + dy * dy).squareRoot() - sphere.radius * 1.15
                if clearance < backgroundClearance { continue }
            }
            checked += 1
            let got: SIMD3<Double> = colour(rgba, x: candidate.x, y: candidate.y, width: width)
            if channelDistance(got, Palette.night) > backgroundTolerance {
                misses.append(String(format: "background (%ld, %ld): (%.3f, %.3f, %.3f)", candidate.x, candidate.y,
                                     got.x, got.y, got.z))
            }
        }
        return (checked, misses)
    }

    /// The pixel positions of every cell top centre, every emitter top and every basin centre of `snapshot` (nil
    /// behind the camera), in that order.
    static func referencePixels(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> [Vec2?] {
        let cam: ColorfallCanyonsCamera = camera(snapshot, width: width, height: height)
        var result: [Vec2?] = []
        for cell in 0..<snapshot.cellCount {
            result.append(Geometry.pixel(Geometry.cellTop(cell, snapshot), camera: cam, width: width, height: height))
        }
        for s in 0..<snapshot.springs.count {
            result.append(Geometry.pixel(Geometry.emitterTop(s, snapshot), camera: cam, width: width, height: height))
        }
        for b in 0..<snapshot.basins.count {
            result.append(Geometry.pixel(Geometry.basinCentre(b, snapshot), camera: cam, width: width, height: height))
        }
        return result
    }

    /// Runs the checks of clarification Q3 on `rgba` against `snapshot`, recording an issue per failure.
    static func checkFrame(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width, height: Int = height,
                           _ what: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(rgba.count == width * height * 4, "\(what): picture size", sourceLocation: sourceLocation)
        guard rgba.count == width * height * 4 else { return }
        let emitters = emitterMisses(rgba, snapshot: snapshot, width: width, height: height)
        #expect(emitters.checked + emitters.dimmed == snapshot.springs.count, "\(what): emitters",
                sourceLocation: sourceLocation)
        #expect(emitters.misses.isEmpty, "\(what): \(emitters.misses)", sourceLocation: sourceLocation)
        let cells = cellResults(rgba, snapshot: snapshot, width: width, height: height)
        #expect(cells.checked == openCells(snapshot).count, "\(what): open cells checked \(cells.checked)",
                sourceLocation: sourceLocation)
        #expect(cells.strictMisses.isEmpty, "\(what): front-row cells \(cells.strictMisses)",
                sourceLocation: sourceLocation)
        let share: Double = cells.checked > 0 ? Double(cells.passed) / Double(cells.checked) : 0
        #expect(share >= cellShare,
                "\(what): \(cells.passed) of \(cells.checked) open cells: \(cells.misses.prefix(6))",
                sourceLocation: sourceLocation)
        let background = backgroundMisses(rgba, snapshot: snapshot, width: width, height: height)
        #expect(background.checked >= 1, "\(what): no background pixel clear of the scene",
                sourceLocation: sourceLocation)
        #expect(background.misses.isEmpty, "\(what): \(background.misses)", sourceLocation: sourceLocation)
    }
}
#endif
