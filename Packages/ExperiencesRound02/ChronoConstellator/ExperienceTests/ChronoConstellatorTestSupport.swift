// ChronoConstellatorTestSupport — feature 353 (R02-G06-03) T-R02G0603-006 (FR-R02G0603-001 … 007; SC-R02G0603-001, 002;
// clarifications Q1–Q4). Shared helpers of the Chrono Constellator experience tests, following the Colorfall Canyons
// harness (feature 343): opening the experience through the one app's session host (seed `s` prepares level
// `s % 100 + 1`; a session without a quality pin is pinned to level 0), advancing the play (a short hold on star 1,
// then a few ticks, so ribbons, a hold bar and moved stars exist), drawing live frames, drawing an off-screen
// still (RGBA8, rows top-down: the host's `renderOffscreen` flips the GL read-back, so the still has the orientation
// of the Core's CPU projection `ChronoConstellatorSceneGeometry.pixel`, origin top left, y down), the engine digest,
// and the frame checks of clarification Q3 at 1,152 × 768:
//   - each star node centre lies within 3 px of a pixel whose luminance exceeds the field's by at least 0.15;
//   - each target ring differs from the field: the ring band is 0.34 … 0.42·u about the target centre, so it is sampled
//     at eight points on its middle circle (0.38·u) and within 3 px of each projected sample some pixel differs from
//     the field by at least 0.1 in luminance (3 px reach the band's outer edge at 0.42·u for every grid of the
//     catalog);
//   - the field background at the two probe corners (0.02, 0.02) and (0.98, 0.98) of the view is within 0.05 per
//     channel of `ChronoConstellatorPalette.field` (the camera fits the bounding sphere inside ±0.88 NDC, so both
//     corners lie outside every element).
// Luminance is the Rec. 709 weighting of the stored 0 … 1 channel values. Short runs only (no sleep, no wall-clock
// assertion).
#if os(iOS)
import ChronoConstellatorCore
import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import ChronoConstellatorExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// Building, opening, drawing and measuring Chrono Constellator.
@MainActor
enum ChronoConstellatorTest {
    typealias Geometry = ChronoConstellatorSceneGeometry
    typealias Palette = ChronoConstellatorPalette
    typealias Snapshot = ChronoConstellatorSceneSnapshot
    typealias Shell = ExperienceShell<ChronoConstellatorPresenter>

    /// The experience id `r02-g06.chrono-constellator`.
    static var id: ExperienceID {
        ChronoConstellatorExperience.id ?? ExperienceID(rawValue: "r02-g06.unknown")!
    }

    /// The frame-check size of clarification Q3, aspect 1.5.
    static let width: Int = 1_152
    static let height: Int = 768
    /// The seeds of the checked levels 1, 21, 41, 61 and 81.
    static let seeds: [UInt64] = [0, 20, 40, 60, 80]
    /// The ticks run by `advance`.
    static let advanceTicks: Int = 4
    /// The hold `advance` adds: star 1 (index 0) from tick 1 for 2 ticks.
    static let holdValues: [Double] = [0, 1, 2]
    /// The search radius (pixels) of the star and ring checks.
    static let pointRadius: Double = 3
    /// The luminance margin of a star centre over the field.
    static let litMargin: Double = 0.15
    /// The luminance difference from the field of a target ring.
    static let ringMargin: Double = 0.1
    /// The radius (in cells) of the ring samples: the middle of the band 0.34 … 0.42·u.
    static let ringSampleRadius: Double = 0.38
    /// The ring samples per target.
    static let ringSamples: Int = 8
    /// The per-channel bound of the background.
    static let backgroundTolerance: Double = 0.05
    /// The background probe points (fractions of the view, origin top left).
    static let backgroundPoints: [(x: Double, y: Double)] = [(0.02, 0.02), (0.98, 0.98)]

    /// Opens Chrono Constellator with `seed` in `session` through the factory, lays the view out at `size` points and
    /// draws one frame. A session without a quality pin is pinned to level 0. `configure` runs on the presenter before
    /// its first `setup` (the fallback seam).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false, size: CGSize = CGSize(width: 48, height: 32),
                     configure: ((ChronoConstellatorPresenter) -> Void)? = nil) async throws -> Shell {
        let id: ExperienceID = self.id
        var made: Shell?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: seed) {
            let shell: Shell = ChronoConstellatorExperience.make(id: id, reduceMotion: reduceMotion,
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
    static func core(_ shell: Shell) throws -> ChronoConstellatorExperienceCore {
        try #require(shell.engine.core)
    }

    /// Pins `session` to quality level `tier` and checks that the engine took it.
    static func pin(_ session: ExperienceSession, _ shell: Shell, tier: Int,
                    sourceLocation: SourceLocation = #_sourceLocation) {
        session.qualityPin = tier
        #expect(shell.engine.qualityTier == tier, "pinned tier \(tier)", sourceLocation: sourceLocation)
    }

    /// Advances the play through the shell: adds the hold of `holdValues`, then steps `ticks` ticks. Returns the number
    /// of accepted actions (the step is always accepted on a fresh level).
    @discardableResult
    static func advance(_ shell: Shell, ticks: Int = advanceTicks) -> Int {
        var accepted: Int = 0
        if shell.handle(control: "star.hold", values: holdValues) == .accepted { accepted += 1 }
        if shell.handle(control: "time.step", values: [Double(ticks)]) == .accepted { accepted += 1 }
        return accepted
    }

    /// The same as `advance` on a bare core (no host): the CPU reference of an advanced state.
    static func advanced(_ number: Int, ticks: Int = advanceTicks) throws -> ChronoConstellatorExperienceCore {
        var core: ChronoConstellatorExperienceCore = try ChronoConstellatorExperienceCore.opening(number: number)
        _ = core.apply(ExperienceAction(control: "star.hold", values: holdValues, step: 0))
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

    /// The luminance of the field.
    static var fieldLuminance: Double { luminance(Palette.field) }

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

    /// The number of pixels farther than `tolerance` per channel from the field.
    static func nonFieldPixels(_ rgba: [UInt8], tolerance: Double = 0.05) -> Int {
        var count: Int = 0
        var i: Int = 0
        while i + 3 < rgba.count {
            let c = SIMD3<Double>(Double(rgba[i]) / 255, Double(rgba[i + 1]) / 255, Double(rgba[i + 2]) / 255)
            if channelDistance(c, Palette.field) > tolerance { count += 1 }
            i += 4
        }
        return count
    }

    /// Whether some pixel whose centre lies within `radius` of (`px`, `py`) has a luminance of at least `minimum`
    /// (`above` true) or differs from `reference` by at least `minimum` in luminance (`above` false).
    static func anyPixel(_ rgba: [UInt8], near px: Double, _ py: Double, radius: Double, width: Int, height: Int,
                         minimum: Double, above: Bool, reference: Double) -> Bool {
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
                let lit: Double = luminance(colour(rgba, x: x, y: y, width: width))
                if above {
                    if lit >= minimum { return true }
                } else {
                    if Swift.abs(lit - reference) >= minimum { return true }
                }
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
    static func camera(_ snapshot: Snapshot, width: Int, height: Int) -> ChronoConstellatorCamera {
        Geometry.camera(snapshot, aspect: Double(width) / Double(height))
    }

    /// The projected star node centres of `snapshot` as a flat list x0, y0, x1, y1, … (NaN for a missing projection).
    static func starPixels(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> [Double] {
        let cam: ChronoConstellatorCamera = camera(snapshot, width: width, height: height)
        var result: [Double] = []
        for s in 0..<snapshot.stars.count {
            if let p = Geometry.pixel(Geometry.starCentre(s, snapshot), camera: cam, width: width, height: height) {
                result.append(p.x)
                result.append(p.y)
            } else {
                result.append(Double.nan)
                result.append(Double.nan)
            }
        }
        return result
    }

    /// The star check: every star node centre has, within 3 px, a pixel whose luminance exceeds the field's by at
    /// least `margin`. Returns the stars checked and the misses.
    static func starMisses(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width, height: Int = height,
                           margin: Double = litMargin) -> (checked: Int, misses: [String]) {
        let cam: ChronoConstellatorCamera = camera(snapshot, width: width, height: height)
        let threshold: Double = fieldLuminance + margin
        var checked: Int = 0
        var misses: [String] = []
        for s in 0..<snapshot.stars.count {
            guard let p = Geometry.pixel(Geometry.starCentre(s, snapshot), camera: cam, width: width,
                                         height: height) else {
                misses.append("star \(s): no projection")
                continue
            }
            checked += 1
            let found: Bool = anyPixel(rgba, near: p.x, p.y, radius: pointRadius, width: width, height: height,
                                       minimum: threshold, above: true, reference: 0)
            if !found { misses.append(String(format: "star %ld at (%.1f, %.1f) without a lit pixel", s, p.x, p.y)) }
        }
        return (checked, misses)
    }

    /// The ring check: for every target, each of `ringSamples` points on the middle circle of its ring band has, within
    /// 3 px of its projection, a pixel that differs from the field by at least `margin` in luminance. Returns the
    /// samples checked and the misses.
    static func ringMisses(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width, height: Int = height,
                           margin: Double = ringMargin) -> (checked: Int, misses: [String]) {
        let cam: ChronoConstellatorCamera = camera(snapshot, width: width, height: height)
        let u: Double = Geometry.cellSize(snapshot)
        var checked: Int = 0
        var misses: [String] = []
        for s in 0..<snapshot.stars.count {
            let centre: SIMD3<Double> = Geometry.targetCentre(s, snapshot)
            for k in 0..<ringSamples {
                let angle: Double = 2 * Double.pi * Double(k) / Double(ringSamples)
                let offset: SIMD3<Double> = SIMD3<Double>(cos(angle), 0, sin(angle)) * (ringSampleRadius * u)
                guard let p = Geometry.pixel(centre + offset, camera: cam, width: width, height: height) else {
                    misses.append("target \(s) sample \(k): no projection")
                    continue
                }
                checked += 1
                let found: Bool = anyPixel(rgba, near: p.x, p.y, radius: pointRadius, width: width, height: height,
                                           minimum: margin, above: false, reference: fieldLuminance)
                if !found {
                    misses.append(String(format: "target %ld sample %ld at (%.1f, %.1f) is field", s, k, p.x, p.y))
                }
            }
        }
        return (checked, misses)
    }

    /// The background check: the pixels of the two probe corners are within 0.05 per channel of the field. Returns
    /// the number checked and the misses.
    static func backgroundMisses(_ rgba: [UInt8], width: Int = width,
                                 height: Int = height) -> (checked: Int, misses: [String]) {
        var checked: Int = 0
        var misses: [String] = []
        for point in backgroundPoints {
            let got = pixelAtFraction(rgba, point.x, point.y, width: width, height: height)
            checked += 1
            if channelDistance(got.colour, Palette.field) > backgroundTolerance {
                misses.append(String(format: "background (%ld, %ld): (%.3f, %.3f, %.3f)", got.x, got.y,
                                     got.colour.x, got.colour.y, got.colour.z))
            }
        }
        return (checked, misses)
    }

    /// The pixel positions of every star node centre, every target centre and every loop cell centre of `snapshot`
    /// (nil behind the camera), in that order.
    static func referencePixels(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> [Vec2?] {
        let cam: ChronoConstellatorCamera = camera(snapshot, width: width, height: height)
        var result: [Vec2?] = []
        for s in 0..<snapshot.stars.count {
            result.append(Geometry.pixel(Geometry.starCentre(s, snapshot), camera: cam, width: width, height: height))
        }
        for s in 0..<snapshot.stars.count {
            result.append(Geometry.pixel(Geometry.targetCentre(s, snapshot), camera: cam, width: width,
                                         height: height))
        }
        for s in 0..<snapshot.stars.count {
            for cell in snapshot.stars[s].loop {
                result.append(Geometry.pixel(Geometry.cellCentre(cell, snapshot), camera: cam, width: width,
                                             height: height))
            }
        }
        return result
    }

    /// Runs the checks of clarification Q3 on `rgba` against `snapshot`, recording an issue per failure.
    static func checkFrame(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width, height: Int = height,
                           _ what: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(rgba.count == width * height * 4, "\(what): picture size", sourceLocation: sourceLocation)
        guard rgba.count == width * height * 4 else { return }
        let stars = starMisses(rgba, snapshot: snapshot, width: width, height: height)
        #expect(stars.checked == snapshot.stars.count, "\(what): stars checked \(stars.checked)",
                sourceLocation: sourceLocation)
        #expect(stars.misses.isEmpty, "\(what): \(stars.misses)", sourceLocation: sourceLocation)
        let rings = ringMisses(rgba, snapshot: snapshot, width: width, height: height)
        #expect(rings.checked == snapshot.stars.count * ringSamples, "\(what): ring samples \(rings.checked)",
                sourceLocation: sourceLocation)
        #expect(rings.misses.isEmpty, "\(what): \(rings.misses.prefix(8))", sourceLocation: sourceLocation)
        let background = backgroundMisses(rgba, width: width, height: height)
        #expect(background.checked == backgroundPoints.count, "\(what): background", sourceLocation: sourceLocation)
        #expect(background.misses.isEmpty, "\(what): \(background.misses)", sourceLocation: sourceLocation)
    }
}
#endif
