// AmethystEscapeTestSupport — feature 363 (R02-G07-03) T-R02G0703-006 (FR-R02G0703-001 … 007; SC-R02G0703-001, 002;
// clarifications Q1–Q4). Shared helpers of the Amethyst Escape experience tests, following the Chrono Constellator
// harness (feature 353): opening the experience through the one app's session host (seed `s` prepares level
// `s % 100 + 1`; a session without a quality pin is pinned to level 0), advancing the play (one turn of the innermost
// shell, so an offset is non-zero and the move bar shows), drawing live frames, drawing an off-screen still (RGBA8, rows
// top-down: the host's `renderOffscreen` flips the GL read-back, so the still has the orientation of the Core's CPU
// projection `AmethystEscapeSceneGeometry.pixel`, origin top left, y down), the engine digest, and the frame checks of
// clarification Q3 at 1,152 × 768:
//   - the pearl centre lies within 3 px of a pixel whose luminance exceeds the backdrop's by at least 0.15;
//   - within 3 px of the exit arrow centre some pixel differs from the backdrop by at least 0.1 in luminance;
//   - within 3 px of every open (not blocked) wedge's top centre some pixel differs from the backdrop by at least 0.05
//     in luminance;
//   - the backdrop at the two probe corners (0.02, 0.02) and (0.98, 0.98) of the view is within 0.05 per channel of
//     `AmethystEscapePalette.backdrop` (the camera fits the bounding sphere inside a 5 % margin, so both corners lie
//     outside every element).
// Luminance is the Rec. 709 weighting of the stored 0 … 1 channel values. Short runs only (no sleep, no wall-clock
// assertion).
#if os(iOS)
import AmethystEscapeCore
import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import AmethystEscapeExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// Building, opening, drawing and measuring Amethyst Escape.
@MainActor
enum AmethystEscapeTest {
    typealias Geometry = AmethystEscapeSceneGeometry
    typealias Palette = AmethystEscapePalette
    typealias Snapshot = AmethystEscapeSceneSnapshot
    typealias Shell = ExperienceShell<AmethystEscapePresenter>

    /// The experience id `r02-g07.amethyst-escape`.
    static var id: ExperienceID {
        AmethystEscapeExperience.id ?? ExperienceID(rawValue: "r02-g07.unknown")!
    }

    /// The frame-check size of clarification Q3, aspect 1.5.
    static let width: Int = 1_152
    static let height: Int = 768
    /// The seeds of the checked levels 1, 21, 41, 61 and 81 (seed = level − 1).
    static let seeds: [UInt64] = [0, 20, 40, 60, 80]
    /// The search radius (pixels) of every point check.
    static let pointRadius: Double = 3
    /// The luminance margin of the pearl centre over the backdrop.
    static let pearlMargin: Double = 0.15
    /// The luminance difference from the backdrop near the exit arrow centre.
    static let exitMargin: Double = 0.1
    /// The luminance difference from the backdrop near an open wedge's top centre.
    static let wedgeMargin: Double = 0.05
    /// The per-channel bound of the backdrop.
    static let backgroundTolerance: Double = 0.05
    /// The backdrop probe points (fractions of the view, origin top left).
    static let backgroundPoints: [(x: Double, y: Double)] = [(0.02, 0.02), (0.98, 0.98)]

    /// Opens Amethyst Escape with `seed` in `session` through the factory, lays the view out at `size` points and draws
    /// one frame. A session without a quality pin is pinned to level 0. `configure` runs on the presenter before its
    /// first `setup` (the fallback seam).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false, size: CGSize = CGSize(width: 48, height: 32),
                     configure: ((AmethystEscapePresenter) -> Void)? = nil) async throws -> Shell {
        let id: ExperienceID = self.id
        var made: Shell?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: seed) {
            let shell: Shell = AmethystEscapeExperience.make(id: id, reduceMotion: reduceMotion,
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
    static func core(_ shell: Shell) throws -> AmethystEscapeExperienceCore {
        try #require(shell.engine.core)
    }

    /// Pins `session` to quality level `tier` and checks that the engine took it.
    static func pin(_ session: ExperienceSession, _ shell: Shell, tier: Int,
                    sourceLocation: SourceLocation = #_sourceLocation) {
        session.qualityPin = tier
        #expect(shell.engine.qualityTier == tier, "pinned tier \(tier)", sourceLocation: sourceLocation)
    }

    /// Advances the play through the shell: turns the innermost shell one sector clockwise. Returns the number of
    /// accepted actions (1 on a fresh level).
    @discardableResult
    static func advance(_ shell: Shell) -> Int {
        shell.handle(control: "shell.rotate", values: [0, 1]) == .accepted ? 1 : 0
    }

    /// The same as `advance` on a bare core (no host): the CPU reference of an advanced state.
    static func advanced(_ number: Int) throws -> AmethystEscapeExperienceCore {
        var core: AmethystEscapeExperienceCore = try AmethystEscapeExperienceCore.opening(number: number)
        _ = core.apply(ExperienceAction(control: "shell.rotate", values: [0, 1], step: 0))
        return core
    }

    /// The control and values that issue the kernel action `action` through the shell.
    static func control(_ action: AmethystEscapeAction) -> (control: String, values: [Double]) {
        switch action {
        case .rotate(let shell, let step): ("shell.rotate", [Double(shell), Double(step)])
        case .advance: ("pearl.advance", [])
        }
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

    /// The luminance of the backdrop.
    static var backdropLuminance: Double { luminance(Palette.backdrop) }

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

    /// The number of pixels farther than `tolerance` per channel from the backdrop.
    static func nonBackdropPixels(_ rgba: [UInt8], tolerance: Double = 0.05) -> Int {
        var count: Int = 0
        var i: Int = 0
        while i + 3 < rgba.count {
            let c = SIMD3<Double>(Double(rgba[i]) / 255, Double(rgba[i + 1]) / 255, Double(rgba[i + 2]) / 255)
            if channelDistance(c, Palette.backdrop) > tolerance { count += 1 }
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
    static func camera(_ snapshot: Snapshot, width: Int, height: Int) -> AmethystEscapeCamera {
        Geometry.camera(snapshot, aspect: Double(width) / Double(height))
    }

    /// The open (not blocked) wedges of `snapshot` as (shell, own sector), innermost shell first.
    static func openWedges(_ snapshot: Snapshot) -> [(shell: Int, sector: Int)] {
        var result: [(shell: Int, sector: Int)] = []
        for shell in snapshot.shells.indices {
            for sector in 0..<snapshot.sectors where !snapshot.shells[shell].blocked.contains(sector) {
                result.append((shell, sector))
            }
        }
        return result
    }

    /// The projected pearl centre of `snapshot` (nil without a projection).
    static func pearlPixel(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> Vec2? {
        Geometry.pixel(Geometry.pearlCentre(snapshot), camera: camera(snapshot, width: width, height: height),
                       width: width, height: height)
    }

    /// The projected exit arrow centre of `snapshot` (nil without a projection).
    static func exitPixel(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> Vec2? {
        Geometry.pixel(Geometry.exitCentre(snapshot), camera: camera(snapshot, width: width, height: height),
                       width: width, height: height)
    }

    /// The pixel positions of the pearl centre, the exit arrow centre and every wedge's top centre (open or blocked,
    /// innermost shell first) of `snapshot` (nil behind the camera), in that order.
    static func referencePixels(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> [Vec2?] {
        let cam: AmethystEscapeCamera = camera(snapshot, width: width, height: height)
        var result: [Vec2?] = [pearlPixel(snapshot, width: width, height: height),
                               exitPixel(snapshot, width: width, height: height)]
        for shell in snapshot.shells.indices {
            for sector in 0..<snapshot.sectors {
                result.append(Geometry.pixel(Geometry.wedgeTopCentre(shell: shell, sector: sector, snapshot),
                                             camera: cam, width: width, height: height))
            }
        }
        return result
    }

    /// The pearl check: within 3 px of the pearl centre some pixel's luminance exceeds the backdrop's by at least
    /// `margin`. Returns the misses (empty when it passes).
    static func pearlMisses(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width, height: Int = height,
                            margin: Double = pearlMargin) -> [String] {
        guard let p = pearlPixel(snapshot, width: width, height: height) else { return ["pearl: no projection"] }
        let found: Bool = anyPixel(rgba, near: p.x, p.y, radius: pointRadius, width: width, height: height,
                                   minimum: backdropLuminance + margin, above: true, reference: 0)
        return found ? [] : [String(format: "pearl at (%.1f, %.1f) without a lit pixel", p.x, p.y)]
    }

    /// The exit check: within 3 px of the exit arrow centre some pixel differs from the backdrop by at least `margin`
    /// in luminance. Returns the misses (empty when it passes).
    static func exitMisses(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width, height: Int = height,
                           margin: Double = exitMargin) -> [String] {
        guard let p = exitPixel(snapshot, width: width, height: height) else { return ["exit: no projection"] }
        let found: Bool = anyPixel(rgba, near: p.x, p.y, radius: pointRadius, width: width, height: height,
                                   minimum: margin, above: false, reference: backdropLuminance)
        return found ? [] : [String(format: "exit arrow at (%.1f, %.1f) is backdrop", p.x, p.y)]
    }

    /// The wedge check: within 3 px of every open wedge's top centre some pixel differs from the backdrop by at least
    /// `margin` in luminance. Returns the wedges checked and the misses.
    static func wedgeMisses(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width, height: Int = height,
                            margin: Double = wedgeMargin) -> (checked: Int, misses: [String]) {
        let cam: AmethystEscapeCamera = camera(snapshot, width: width, height: height)
        var checked: Int = 0
        var misses: [String] = []
        for wedge in openWedges(snapshot) {
            let top: SIMD3<Double> = Geometry.wedgeTopCentre(shell: wedge.shell, sector: wedge.sector, snapshot)
            guard let p = Geometry.pixel(top, camera: cam, width: width, height: height) else {
                misses.append("wedge \(wedge.shell)/\(wedge.sector): no projection")
                continue
            }
            checked += 1
            let found: Bool = anyPixel(rgba, near: p.x, p.y, radius: pointRadius, width: width, height: height,
                                       minimum: margin, above: false, reference: backdropLuminance)
            if !found {
                misses.append(String(format: "wedge %ld/%ld at (%.1f, %.1f) is backdrop", wedge.shell, wedge.sector,
                                     p.x, p.y))
            }
        }
        return (checked, misses)
    }

    /// The move bar check (T-R02G0703-015): after at least one move, within 3 px of the bar's midpoint some pixel
    /// differs from the backdrop by at least `margin` in luminance. Returns the misses (empty when it passes, and when
    /// no move was spent, since the bar then has no length).
    static func moveBarMisses(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width, height: Int = height,
                              margin: Double = exitMargin) -> [String] {
        let length: Double = Geometry.moveBarLength(snapshot)
        guard snapshot.moves > 0, length > 0 else { return [] }
        let cam: AmethystEscapeCamera = camera(snapshot, width: width, height: height)
        let middle = SIMD3<Double>(Geometry.moveBarStart + length / 2, Geometry.moveBarLift, Geometry.moveBarZ)
        guard let p = Geometry.pixel(middle, camera: cam, width: width, height: height) else {
            return ["move bar: no projection"]
        }
        let found: Bool = anyPixel(rgba, near: p.x, p.y, radius: pointRadius, width: width, height: height,
                                   minimum: margin, above: false, reference: backdropLuminance)
        return found ? [] : [String(format: "move bar at (%.1f, %.1f) is backdrop", p.x, p.y)]
    }

    /// Whether some pixel within `radius` px of the top centre of `shell`/`sector` is amber-like (red above blue by at
    /// least 0.2; the amethyst facets have more blue than red and the pearl is near white). The default reach is 60 px
    /// because the failed pocket's pearl (radius 0.3·w, about 38 px on a two-shell level) covers the top centre itself.
    static func amberNear(_ rgba: [UInt8], snapshot: Snapshot, shell: Int, sector: Int, radius: Double = 60,
                          width: Int = width, height: Int = height) -> Bool {
        let cam: AmethystEscapeCamera = camera(snapshot, width: width, height: height)
        let top: SIMD3<Double> = Geometry.wedgeTopCentre(shell: shell, sector: sector, snapshot)
        guard let p = Geometry.pixel(top, camera: cam, width: width, height: height) else { return false }
        let reach: Int = Int(radius.rounded(.up))
        for y in (Int(p.y) - reach)...(Int(p.y) + reach) where y >= 0 && y < height {
            for x in (Int(p.x) - reach)...(Int(p.x) + reach) where x >= 0 && x < width {
                let c: SIMD3<Double> = colour(rgba, x: x, y: y, width: width)
                if c.x - c.z >= 0.2 { return true }
            }
        }
        return false
    }

    /// The background check: the pixels of the two probe corners are within 0.05 per channel of the backdrop. Returns
    /// the number checked and the misses.
    static func backgroundMisses(_ rgba: [UInt8], width: Int = width,
                                 height: Int = height) -> (checked: Int, misses: [String]) {
        var checked: Int = 0
        var misses: [String] = []
        for point in backgroundPoints {
            let got = pixelAtFraction(rgba, point.x, point.y, width: width, height: height)
            checked += 1
            if channelDistance(got.colour, Palette.backdrop) > backgroundTolerance {
                misses.append(String(format: "background (%ld, %ld): (%.3f, %.3f, %.3f)", got.x, got.y,
                                     got.colour.x, got.colour.y, got.colour.z))
            }
        }
        return (checked, misses)
    }

    /// Runs the checks of clarification Q3 (and the move bar's, T-R02G0703-015) on `rgba` against `snapshot`, recording an
    /// issue per failure. `wedges`
    /// false skips the open-wedge check (the fallback frame checks only the pearl and the corners).
    static func checkFrame(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width, height: Int = height,
                           wedges: Bool = true, exit: Bool = true, _ what: String,
                           sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(rgba.count == width * height * 4, "\(what): picture size", sourceLocation: sourceLocation)
        guard rgba.count == width * height * 4 else { return }
        let pearl: [String] = pearlMisses(rgba, snapshot: snapshot, width: width, height: height)
        #expect(pearl.isEmpty, "\(what): \(pearl)", sourceLocation: sourceLocation)
        if exit {
            let arrow: [String] = exitMisses(rgba, snapshot: snapshot, width: width, height: height)
            #expect(arrow.isEmpty, "\(what): \(arrow)", sourceLocation: sourceLocation)
        }
        if wedges {
            let open = wedgeMisses(rgba, snapshot: snapshot, width: width, height: height)
            #expect(open.checked == openWedges(snapshot).count, "\(what): wedges checked \(open.checked)",
                    sourceLocation: sourceLocation)
            #expect(open.checked > 0, "\(what): some wedge is open", sourceLocation: sourceLocation)
            #expect(open.misses.isEmpty, "\(what): \(open.misses.prefix(8))", sourceLocation: sourceLocation)
        }
        let bar: [String] = moveBarMisses(rgba, snapshot: snapshot, width: width, height: height)
        #expect(bar.isEmpty, "\(what): \(bar)", sourceLocation: sourceLocation)
        let background = backgroundMisses(rgba, width: width, height: height)
        #expect(background.checked == backgroundPoints.count, "\(what): background", sourceLocation: sourceLocation)
        #expect(background.misses.isEmpty, "\(what): \(background.misses)", sourceLocation: sourceLocation)
    }
}
#endif
