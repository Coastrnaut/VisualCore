// WaveKnotKeeperTestSupport — feature 323 (R02-G03-03) T-R02G0303-006 (FR-R02G0303-001 … 004, 006, 007;
// SC-R02G0303-001, 002; clarifications Q1–Q4). Shared helpers of the Wave Knot Keeper experience tests, mirroring the
// Lissajous Labyrinth harness (feature 313): opening the experience through the one app's session host (seed `s`
// prepares level `s % 100 + 1`, a session without a quality pin is pinned to level 0), drawing live frames, drawing an
// off-screen still (RGBA8, rows top-down: the host's `renderOffscreen` flips the GL read-back, so the still has the
// orientation of the Core's CPU projection `WaveKnotKeeperSceneGeometry.pixel`, origin top left, y down), the engine
// digest, and the frame checks of clarification Q3 at 1,152 × 768 (the size Lissajous settled on for thin geometry):
//   - each projected control point and segment midpoint not inside a gate's projected box (+ 1 px) lies within 3 px of
//     a pixel whose luminance exceeds night's by at least 0.15;
//   - each handle's centre pixel (the best pixel within 1 px of the projected centre, for pixel-centre rounding) is
//     within 0.15 per channel of `WaveKnotKeeperShaders.solidColour(pearl)`, or of ember when the handle is the
//     selected one; handles inside a gate's projected box (the translucent gate is drawn over them) and handles whose
//     centre a later-drawn handle of another colour covers are skipped;
//   - each gate's centre pixel is tinted towards sapphire compared with night: its blue-minus-red exceeds night's by
//     at least 0.05 and its blue channel exceeds night's by at least 0.1 (gates whose centre the selected ember handle
//     covers are skipped);
//   - the four pixels 2 px in from the corners, clear of the projected bounding sphere by at least 6 px, are within
//     0.05 per channel of night.
// Luminance is the Rec. 709 weighting of the stored 0 … 1 channel values. Short runs only (no sleep, no wall-clock
// assertion).
#if os(iOS)
import CoreGraphics
import Foundation
import Testing
import UIKit
import WaveKnotKeeperCore
@testable import WaveKnotKeeperExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// Building, opening, drawing and measuring Wave Knot Keeper.
@MainActor
enum WaveKnotKeeperTest {
    typealias Geometry = WaveKnotKeeperSceneGeometry
    typealias Palette = WaveKnotKeeperPalette
    typealias Shell = ExperienceShell<WaveKnotKeeperPresenter>

    /// The experience id `r02-g03.wave-knot-keeper`.
    static var id: ExperienceID {
        WaveKnotKeeperExperience.id ?? ExperienceID(rawValue: "r02-g03.unknown")!
    }

    /// The frame-check size of clarification Q3, aspect 1.5.
    static let width: Int = 1_152
    static let height: Int = 768
    /// The seeds of the checked levels 1, 21, 41, 61 and 81.
    static let seeds: [UInt64] = [0, 20, 40, 60, 80]
    /// The search radius (pixels) of the point and midpoint check and its luminance margin over night.
    static let pointRadius: Double = 3
    static let litMargin: Double = 0.15
    /// The per-channel bound of the handle colours and of the background.
    static let handleTolerance: Double = 0.15
    static let backgroundTolerance: Double = 0.05
    /// How far (pixels) from the projected handle centre the centre pixel may be (pixel-centre rounding).
    static let centreSearch: Double = 1
    /// The gate tint: blue-minus-red above night's by this much, blue above night's by `gateBlue`.
    static let gateTint: Double = 0.05
    static let gateBlue: Double = 0.1
    /// How far (pixels) a background pixel must be from the projected bounding sphere.
    static let backgroundClearance: Double = 6

    /// Opens Wave Knot Keeper with `seed` in `session` through the factory, lays the view out at `size` points and draws
    /// one frame. A session without a quality pin is pinned to level 0. `configure` runs on the presenter before its
    /// first `setup` (the fallback seam).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false, size: CGSize = CGSize(width: 48, height: 32),
                     configure: ((WaveKnotKeeperPresenter) -> Void)? = nil) async throws -> Shell {
        let id: ExperienceID = self.id
        var made: Shell?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: seed) {
            let shell: Shell = WaveKnotKeeperExperience.make(id: id, reduceMotion: reduceMotion,
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
    static func core(_ shell: Shell) throws -> WaveKnotKeeperExperienceCore {
        try #require(shell.engine.core)
    }

    /// Pins `session` to quality level `tier` and checks that the engine took it.
    static func pin(_ session: ExperienceSession, _ shell: Shell, tier: Int,
                    sourceLocation: SourceLocation = #_sourceLocation) {
        session.qualityPin = tier
        #expect(shell.engine.qualityTier == tier, "pinned tier \(tier)", sourceLocation: sourceLocation)
    }

    /// The first legal `point.move` of `core` (point, direction index), found with the kernel's
    /// `WaveKnotKeeperPlay.refusal(of:points:level:)`; nil when every move is refused.
    static func legalMove(_ core: WaveKnotKeeperExperienceCore) -> (point: Int, direction: Int)? {
        let play: WaveKnotKeeperPlay = core.play
        guard play.spent < play.level.allowance else { return nil }
        let directions: [WaveKnotKeeperDirection] = WaveKnotKeeperExperienceCore.directionOrder
        for point in 0..<play.points.count {
            for index in 0..<directions.count {
                let move = WaveKnotKeeperMove(point: point, direction: directions[index])
                if WaveKnotKeeperPlay.refusal(of: move, points: play.points, level: play.level) == nil {
                    return (point, index)
                }
            }
        }
        return nil
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

    /// The pixel within `radius` of (`px`, `py`) whose colour is nearest `want` (per channel), and that distance;
    /// nil when no pixel centre lies within `radius` inside the picture.
    static func bestMatch(_ rgba: [UInt8], near px: Double, _ py: Double, radius: Double, want: SIMD3<Double>,
                          width: Int, height: Int) -> (x: Int, y: Int, colour: SIMD3<Double>, distance: Double)? {
        let reach: Int = Int(radius.rounded(.up)) + 1
        let cx: Int = Int(px.rounded(.down))
        let cy: Int = Int(py.rounded(.down))
        var best: (x: Int, y: Int, colour: SIMD3<Double>, distance: Double)?
        for y in (cy - reach)...(cy + reach) {
            guard y >= 0, y < height else { continue }
            for x in (cx - reach)...(cx + reach) {
                guard x >= 0, x < width else { continue }
                let dx: Double = Double(x) + 0.5 - px
                let dy: Double = Double(y) + 0.5 - py
                guard dx * dx + dy * dy <= radius * radius else { continue }
                let c: SIMD3<Double> = colour(rgba, x: x, y: y, width: width)
                let d: Double = channelDistance(c, want)
                if best == nil || d < best!.distance { best = (x, y, c, d) }
            }
        }
        return best
    }

    // MARK: CPU reference (clarification Q3)

    /// The camera the scene uses for a `width` × `height` target.
    static func camera(_ snapshot: WaveKnotKeeperSceneSnapshot, width: Int, height: Int) -> WaveKnotKeeperCamera {
        Geometry.camera(for: snapshot, aspect: Double(width) / Double(height))
    }

    /// The camera's world up axis: +y made perpendicular to the view direction.
    static var cameraUp: SIMD3<Double> {
        let v: SIMD3<Double> = Geometry.eyeDirection
        let up: SIMD3<Double> = SIMD3<Double>(0, 1, 0) - v * v.y
        let length: Double = (up * up).sum().squareRoot()
        return up / length
    }

    /// The projected centre and pixel radius of a sphere of `radius` world units at `centre`; nil behind the camera.
    static func disc(_ centre: SIMD3<Double>, radius: Double, camera: WaveKnotKeeperCamera, width: Int,
                     height: Int) -> (centre: Vec2, radius: Double)? {
        guard let c = Geometry.pixel(centre, camera: camera, width: width, height: height),
              let e = Geometry.pixel(centre + cameraUp * radius, camera: camera, width: width,
                                     height: height) else { return nil }
        let dx: Double = e.x - c.x
        let dy: Double = e.y - c.y
        return (c, (dx * dx + dy * dy).squareRoot())
    }

    /// The pixel rectangle around the eight projected corners of `gate`'s box, grown by 1 px; nil when a corner is
    /// behind the camera.
    static func gateRect(_ gate: WaveKnotKeeperGate, camera: WaveKnotKeeperCamera, width: Int,
                         height: Int) -> (low: Vec2, high: Vec2)? {
        let box = Geometry.gateBox(gate)
        var lowX: Double = .infinity, lowY: Double = .infinity
        var highX: Double = -.infinity, highY: Double = -.infinity
        for corner in 0..<8 {
            let p = SIMD3<Double>(corner & 1 == 0 ? box.low.x : box.high.x,
                                  corner & 2 == 0 ? box.low.y : box.high.y,
                                  corner & 4 == 0 ? box.low.z : box.high.z)
            guard let q = Geometry.pixel(p, camera: camera, width: width, height: height) else { return nil }
            lowX = Swift.min(lowX, q.x)
            lowY = Swift.min(lowY, q.y)
            highX = Swift.max(highX, q.x)
            highY = Swift.max(highY, q.y)
        }
        return (Vec2(lowX - 1, lowY - 1), Vec2(highX + 1, highY + 1))
    }

    /// The projected rectangles of every gate of `snapshot` (gates behind the camera are left out).
    static func gateRects(_ snapshot: WaveKnotKeeperSceneSnapshot, camera: WaveKnotKeeperCamera, width: Int,
                          height: Int) -> [(low: Vec2, high: Vec2)] {
        var rects: [(low: Vec2, high: Vec2)] = []
        for gate in snapshot.gates {
            if let r = gateRect(gate, camera: camera, width: width, height: height) { rects.append(r) }
        }
        return rects
    }

    /// Whether pixel point `p` lies inside any of `rects`.
    static func insideAny(_ p: Vec2, _ rects: [(low: Vec2, high: Vec2)]) -> Bool {
        for r in rects where p.x >= r.low.x && p.x <= r.high.x && p.y >= r.low.y && p.y <= r.high.y { return true }
        return false
    }

    /// The colour handle `index` of `snapshot` shows where it faces the eye: pearl, or ember when selected.
    static func handleColour(_ snapshot: WaveKnotKeeperSceneSnapshot, index: Int) -> SIMD3<Double> {
        WaveKnotKeeperShaders.solidColour(snapshot.selected == index ? Palette.ember : Palette.pearl)
    }

    /// The handles whose centre check applies: not inside a gate's projected box, and not covered (disc + 1 px) by a
    /// later-drawn handle of another colour.
    static func checkableHandles(_ snapshot: WaveKnotKeeperSceneSnapshot, width: Int = width,
                                 height: Int = height) -> [Int] {
        let cam: WaveKnotKeeperCamera = camera(snapshot, width: width, height: height)
        let rects = gateRects(snapshot, camera: cam, width: width, height: height)
        let world: [SIMD3<Double>] = Geometry.worldPoints(snapshot)
        var discs: [(centre: Vec2, radius: Double)?] = []
        for centre in world {
            discs.append(disc(centre, radius: Geometry.handleRadius, camera: cam, width: width, height: height))
        }
        var result: [Int] = []
        for index in 0..<world.count {
            guard let own = discs[index] else { continue }
            if insideAny(own.centre, rects) { continue }
            var covered: Bool = false
            for later in (index + 1)..<Swift.max(world.count, index + 1) {
                guard let other = discs[later] else { continue }
                if handleColour(snapshot, index: later) == handleColour(snapshot, index: index) { continue }
                let dx: Double = own.centre.x - other.centre.x
                let dy: Double = own.centre.y - other.centre.y
                if (dx * dx + dy * dy).squareRoot() <= other.radius + 1 { covered = true }
            }
            if !covered { result.append(index) }
        }
        return result
    }

    /// The point check: every projected control point and segment midpoint not inside a gate's projected box has,
    /// within 3 px, a pixel whose luminance exceeds night's by at least `margin`. Returns the points checked, the
    /// skipped and the misses.
    static func pointMisses(_ rgba: [UInt8], snapshot: WaveKnotKeeperSceneSnapshot, width: Int = width,
                            height: Int = height, margin: Double = litMargin)
        -> (checked: Int, skipped: Int, misses: [String]) {
        let cam: WaveKnotKeeperCamera = camera(snapshot, width: width, height: height)
        let rects = gateRects(snapshot, camera: cam, width: width, height: height)
        let threshold: Double = nightLuminance + margin
        var named: [(name: String, point: SIMD3<Double>)] = []
        let world: [SIMD3<Double>] = Geometry.worldPoints(snapshot)
        for index in 0..<world.count { named.append(("point \(index)", world[index])) }
        let middles: [SIMD3<Double>] = Geometry.segmentMidpoints(snapshot)
        for index in 0..<middles.count { named.append(("midpoint \(index)", middles[index])) }
        var checked: Int = 0
        var skipped: Int = 0
        var misses: [String] = []
        for entry in named {
            guard let p = Geometry.pixel(entry.point, camera: cam, width: width, height: height) else {
                misses.append("\(entry.name): no projection")
                continue
            }
            if insideAny(p, rects) {
                skipped += 1
                continue
            }
            checked += 1
            let found: Bool = anyPixel(rgba, near: p.x, p.y, radius: pointRadius, width: width, height: height) { c in
                luminance(c) >= threshold
            }
            if !found { misses.append(String(format: "%@ at (%.1f, %.1f)", entry.name, p.x, p.y)) }
        }
        return (checked, skipped, misses)
    }

    /// The handle check: for each checkable handle the best pixel within 1 px of its projected centre is within 0.15
    /// per channel of `handleColour`. Returns the handles checked, whether the selected one was among them, and the
    /// misses.
    static func handleMisses(_ rgba: [UInt8], snapshot: WaveKnotKeeperSceneSnapshot, width: Int = width,
                             height: Int = height) -> (checked: Int, selectedChecked: Bool, misses: [String]) {
        let cam: WaveKnotKeeperCamera = camera(snapshot, width: width, height: height)
        let world: [SIMD3<Double>] = Geometry.worldPoints(snapshot)
        var checked: Int = 0
        var selectedChecked: Bool = false
        var misses: [String] = []
        for index in checkableHandles(snapshot, width: width, height: height) {
            guard let c = Geometry.pixel(world[index], camera: cam, width: width, height: height) else { continue }
            let want: SIMD3<Double> = handleColour(snapshot, index: index)
            guard let best = bestMatch(rgba, near: c.x, c.y, radius: centreSearch, want: want, width: width,
                                       height: height) else {
                misses.append(String(format: "handle %ld: outside at (%.1f, %.1f)", index, c.x, c.y))
                continue
            }
            checked += 1
            let selected: Bool = snapshot.selected == index
            if selected { selectedChecked = true }
            if best.distance > handleTolerance {
                misses.append(String(format: "handle %ld (%@) at (%ld, %ld): got (%.3f, %.3f, %.3f) want (%.3f, %.3f, %.3f)",
                                     index, selected ? "selected" : "normal", best.x, best.y, best.colour.x,
                                     best.colour.y, best.colour.z, want.x, want.y, want.z))
            }
        }
        return (checked, selectedChecked, misses)
    }

    /// Whether `c` is tinted towards sapphire compared with night (see the file header).
    static func isSapphireTinted(_ c: SIMD3<Double>) -> Bool {
        let night: SIMD3<Double> = Palette.night
        return (c.z - c.x) >= (night.z - night.x) + gateTint && c.z >= night.z + gateBlue
    }

    /// The gate check: each gate's centre pixel (skipped when the selected handle's disc covers it) is tinted towards
    /// sapphire. Returns the gates checked and the misses.
    static func gateMisses(_ rgba: [UInt8], snapshot: WaveKnotKeeperSceneSnapshot, width: Int = width,
                           height: Int = height) -> (checked: Int, misses: [String]) {
        let cam: WaveKnotKeeperCamera = camera(snapshot, width: width, height: height)
        var ember: (centre: Vec2, radius: Double)?
        if let selected = snapshot.selected, snapshot.points.indices.contains(selected) {
            ember = disc(Geometry.worldPoints(snapshot)[selected], radius: Geometry.handleRadius, camera: cam,
                         width: width, height: height)
        }
        var checked: Int = 0
        var misses: [String] = []
        for (index, gate) in snapshot.gates.enumerated() {
            guard let c = Geometry.pixel(Geometry.gateCentre(gate), camera: cam, width: width, height: height) else {
                misses.append("gate \(index): no projection")
                continue
            }
            if let ember {
                let dx: Double = c.x - ember.centre.x
                let dy: Double = c.y - ember.centre.y
                if (dx * dx + dy * dy).squareRoot() <= ember.radius + 1 { continue }
            }
            let x: Int = Int(c.x.rounded(.down))
            let y: Int = Int(c.y.rounded(.down))
            guard x >= 0, x < width, y >= 0, y < height else {
                misses.append(String(format: "gate %ld: centre outside at (%.1f, %.1f)", index, c.x, c.y))
                continue
            }
            checked += 1
            let got: SIMD3<Double> = colour(rgba, x: x, y: y, width: width)
            if !isSapphireTinted(got) {
                misses.append(String(format: "gate %ld at (%ld, %ld): (%.3f, %.3f, %.3f) not tinted towards sapphire",
                                     index, x, y, got.x, got.y, got.z))
            }
        }
        return (checked, misses)
    }

    /// The background check: of the pixels 2 px in from each corner, those at least 6 px outside the projected
    /// bounding sphere (radius grown by 15 % for the perspective silhouette) are within 0.05 per channel of night.
    /// Returns the number checked and the misses.
    static func backgroundMisses(_ rgba: [UInt8], snapshot: WaveKnotKeeperSceneSnapshot, width: Int = width,
                                 height: Int = height) -> (checked: Int, misses: [String]) {
        let cam: WaveKnotKeeperCamera = camera(snapshot, width: width, height: height)
        let bounds = Geometry.bounds(snapshot)
        let sphere = disc(bounds.centre, radius: bounds.radius, camera: cam, width: width, height: height)
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

    /// The margin check: every pixel (every 2nd row and column) of the outer band `fraction` of the width / height on
    /// each side is within 0.05 per channel of night. Returns the number checked and the first misses.
    static func borderMisses(_ rgba: [UInt8], width: Int, height: Int,
                             fraction: Double = 0.04) -> (checked: Int, misses: [String]) {
        let bandX: Int = Int((Double(width) * fraction).rounded(.down))
        let bandY: Int = Int((Double(height) * fraction).rounded(.down))
        var checked: Int = 0
        var misses: [String] = []
        var y: Int = 0
        while y < height {
            var x: Int = 0
            while x < width {
                let inBand: Bool = x < bandX || x >= width - bandX || y < bandY || y >= height - bandY
                if inBand {
                    checked += 1
                    let got: SIMD3<Double> = colour(rgba, x: x, y: y, width: width)
                    if channelDistance(got, Palette.night) > backgroundTolerance && misses.count < 8 {
                        misses.append(String(format: "(%ld, %ld): (%.3f, %.3f, %.3f)", x, y, got.x, got.y, got.z))
                    }
                }
                x += 2
            }
            y += 2
        }
        return (checked, misses)
    }

    /// The pixel positions of every control point, segment midpoint and gate centre of `snapshot` (nil behind the
    /// camera), in that order.
    static func referencePixels(_ snapshot: WaveKnotKeeperSceneSnapshot, width: Int = width,
                                height: Int = height) -> [Vec2?] {
        let cam: WaveKnotKeeperCamera = camera(snapshot, width: width, height: height)
        var result: [Vec2?] = []
        for p in Geometry.worldPoints(snapshot) {
            result.append(Geometry.pixel(p, camera: cam, width: width, height: height))
        }
        for p in Geometry.segmentMidpoints(snapshot) {
            result.append(Geometry.pixel(p, camera: cam, width: width, height: height))
        }
        for gate in snapshot.gates {
            result.append(Geometry.pixel(Geometry.gateCentre(gate), camera: cam, width: width, height: height))
        }
        return result
    }

    /// Runs the checks of clarification Q3 on `rgba` against `snapshot`, recording an issue per failure.
    static func checkFrame(_ rgba: [UInt8], snapshot: WaveKnotKeeperSceneSnapshot, width: Int = width,
                           height: Int = height, _ what: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(rgba.count == width * height * 4, "\(what): picture size", sourceLocation: sourceLocation)
        guard rgba.count == width * height * 4 else { return }
        let points = pointMisses(rgba, snapshot: snapshot, width: width, height: height)
        #expect(points.checked + points.skipped == 2 * snapshot.points.count,
                "\(what): points \(points.checked) checked, \(points.skipped) skipped", sourceLocation: sourceLocation)
        // Gates (side 3 + padding around a control point of the solved rope) hide a few points; most stay checked.
        #expect(points.checked * 4 >= points.checked + points.skipped,
                "\(what): \(points.skipped) points inside gates", sourceLocation: sourceLocation)
        #expect(points.misses.isEmpty, "\(what): \(points.misses.count) points without a lit pixel: \(points.misses.prefix(6))",
                sourceLocation: sourceLocation)
        let handles = handleMisses(rgba, snapshot: snapshot, width: width, height: height)
        #expect(handles.checked >= 1, "\(what): no handle checked", sourceLocation: sourceLocation)
        #expect(handles.misses.isEmpty, "\(what): \(handles.misses.prefix(6))", sourceLocation: sourceLocation)
        if let selected = snapshot.selected,
           checkableHandles(snapshot, width: width, height: height).contains(selected) {
            #expect(handles.selectedChecked, "\(what): the selected handle \(selected) was not checked",
                    sourceLocation: sourceLocation)
        }
        let gates = gateMisses(rgba, snapshot: snapshot, width: width, height: height)
        #expect(gates.misses.isEmpty, "\(what): \(gates.misses)", sourceLocation: sourceLocation)
        let background = backgroundMisses(rgba, snapshot: snapshot, width: width, height: height)
        #expect(background.checked >= 1, "\(what): no background pixel clear of the scene",
                sourceLocation: sourceLocation)
        #expect(background.misses.isEmpty, "\(what): \(background.misses)", sourceLocation: sourceLocation)
    }
}
#endif
