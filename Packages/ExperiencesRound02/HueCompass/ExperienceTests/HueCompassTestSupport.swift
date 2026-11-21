// HueCompassTestSupport — feature 333 (R02-G04-03) T-R02G0403-006 (FR-R02G0403-001 … 004, 006, 007; SC-R02G0403-001,
// 002; clarifications Q1–Q4). Shared helpers of the Hue Compass experience tests, mirroring the Wave Knot Keeper harness
// (feature 323): opening the experience through the one app's session host (seed `s` prepares level `s % 100 + 1`, a
// session without a quality pin is pinned to level 0), drawing live frames, drawing an off-screen still (RGBA8, rows
// top-down: the host's `renderOffscreen` flips the GL read-back, so the still has the orientation of the Core's CPU
// projection `HueCompassSceneGeometry.pixel`, origin top left, y down), the engine digest, and the frame checks of
// clarification Q3 at 1,152 × 768:
//   - the needle tip and each probe mark centre lie within 3 px of a pixel whose luminance exceeds night's by at least
//     0.15;
//   - each band segment's colour sample (`bandSamplePoint`, radius 0.85 on its middle angle, clear of the glyphs; the
//     best pixel within 1 px for pixel-centre rounding) is within 0.15 per channel of `bandSegmentColour`; segments
//     within 2 segments of the needle's own segment are skipped (the needle and its glow shells can cover them);
//   - the four pixels 2 px in from the corners, clear of the projected bounding sphere by at least 6 px, are within
//     0.05 per channel of night.
// Luminance is the Rec. 709 weighting of the stored 0 … 1 channel values. Short runs only (no sleep, no wall-clock
// assertion).
#if os(iOS)
import CoreGraphics
import Foundation
import HueCompassCore
import Testing
import UIKit
@testable import HueCompassExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// Building, opening, drawing and measuring Hue Compass.
@MainActor
enum HueCompassTest {
    typealias Geometry = HueCompassSceneGeometry
    typealias Palette = HueCompassPalette
    typealias Shell = ExperienceShell<HueCompassPresenter>

    /// The experience id `r02-g04.hue-compass`.
    static var id: ExperienceID {
        HueCompassExperience.id ?? ExperienceID(rawValue: "r02-g04.unknown")!
    }

    /// The frame-check size of clarification Q3, aspect 1.5.
    static let width: Int = 1_152
    static let height: Int = 768
    /// The seeds of the checked levels 1, 21, 41, 61 and 81.
    static let seeds: [UInt64] = [0, 20, 40, 60, 80]
    /// The search radius (pixels) of the tip and mark check and its luminance margin over night.
    static let pointRadius: Double = 3
    static let litMargin: Double = 0.15
    /// The per-channel bound of the band colours and of the background.
    static let bandTolerance: Double = 0.15
    static let backgroundTolerance: Double = 0.05
    /// How far (pixels) from the projected band sample the sampled pixel may be (pixel-centre rounding).
    static let centreSearch: Double = 1
    /// Band segments within this many segments of the needle's segment are not colour-checked.
    static let needleSkip: Int = 2
    /// How far (pixels) a background pixel must be from the projected bounding sphere.
    static let backgroundClearance: Double = 6

    /// Opens Hue Compass with `seed` in `session` through the factory, lays the view out at `size` points and draws one
    /// frame. A session without a quality pin is pinned to level 0. `configure` runs on the presenter before its first
    /// `setup` (the fallback seam).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false, size: CGSize = CGSize(width: 48, height: 32),
                     configure: ((HueCompassPresenter) -> Void)? = nil) async throws -> Shell {
        let id: ExperienceID = self.id
        var made: Shell?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: seed) {
            let shell: Shell = HueCompassExperience.make(id: id, reduceMotion: reduceMotion,
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
    static func core(_ shell: Shell) throws -> HueCompassExperienceCore {
        try #require(shell.engine.core)
    }

    /// Pins `session` to quality level `tier` and checks that the engine took it.
    static func pin(_ session: ExperienceSession, _ shell: Shell, tier: Int,
                    sourceLocation: SourceLocation = #_sourceLocation) {
        session.qualityPin = tier
        #expect(shell.engine.qualityTier == tier, "pinned tier \(tier)", sourceLocation: sourceLocation)
    }

    /// Probes at the current bearing, then (while at least two units are left) turns 17 bearings and probes again, so
    /// the play keeps stage `playing` with one or two clues. Returns the number of probes accepted.
    static func probeTwice(_ shell: Shell) throws -> Int {
        var accepted: Int = 0
        if shell.handle(control: "compass.probe") == .accepted { accepted += 1 }
        let core: HueCompassExperienceCore = try self.core(shell)
        if core.play.stage == .playing, core.play.remaining >= 2 {
            #expect(shell.handle(control: "compass.turn", values: [17]) == .accepted)
            if shell.handle(control: "compass.probe") == .accepted { accepted += 1 }
        }
        return accepted
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
    static func camera(width: Int, height: Int) -> HueCompassCamera {
        Geometry.camera(aspect: Double(width) / Double(height))
    }

    /// The camera's world up axis: +y made perpendicular to the view direction.
    static var cameraUp: SIMD3<Double> {
        let v: SIMD3<Double> = Geometry.eyeDirection
        let up: SIMD3<Double> = SIMD3<Double>(0, 1, 0) - v * v.y
        let length: Double = (up * up).sum().squareRoot()
        return up / length
    }

    /// The projected centre and pixel radius of a sphere of `radius` world units at `centre`; nil behind the camera.
    static func disc(_ centre: SIMD3<Double>, radius: Double, camera: HueCompassCamera, width: Int,
                     height: Int) -> (centre: Vec2, radius: Double)? {
        guard let c = Geometry.pixel(centre, camera: camera, width: width, height: height),
              let e = Geometry.pixel(centre + cameraUp * radius, camera: camera, width: width,
                                     height: height) else { return nil }
        let dx: Double = e.x - c.x
        let dy: Double = e.y - c.y
        return (c, (dx * dx + dy * dy).squareRoot())
    }

    /// The circular distance of band segments `a` and `b` (0 … 12).
    static func segmentDistance(_ a: Int, _ b: Int) -> Int {
        let n: Int = HueCompassWheel.bands
        let d: Int = ((a - b) % n + n) % n
        return Swift.min(d, n - d)
    }

    /// The band segment the needle of `snapshot` lies over: bearing / 4.
    static func needleSegment(_ snapshot: HueCompassSceneSnapshot) -> Int {
        snapshot.bearing / HueCompassWheel.bearingsPerBand
    }

    /// The segments whose colour sample is checked: all but those within `needleSkip` of the needle's segment.
    static func checkableSegments(_ snapshot: HueCompassSceneSnapshot) -> [Int] {
        var result: [Int] = []
        let needle: Int = needleSegment(snapshot)
        for k in 0..<HueCompassWheel.bands where segmentDistance(k, needle) > needleSkip { result.append(k) }
        return result
    }

    /// The tip check: the needle tip has, within 3 px, a pixel whose luminance exceeds night's by at least `margin`.
    /// Returns the miss, if any.
    static func tipMiss(_ rgba: [UInt8], snapshot: HueCompassSceneSnapshot, width: Int = width,
                        height: Int = height, margin: Double = litMargin) -> String? {
        let cam: HueCompassCamera = camera(width: width, height: height)
        guard let p = Geometry.pixel(Geometry.needleTip(snapshot), camera: cam, width: width, height: height) else {
            return "needle tip: no projection"
        }
        let threshold: Double = nightLuminance + margin
        let found: Bool = anyPixel(rgba, near: p.x, p.y, radius: pointRadius, width: width, height: height) { c in
            luminance(c) >= threshold
        }
        return found ? nil : String(format: "needle tip at (%.1f, %.1f) without a lit pixel", p.x, p.y)
    }

    /// The mark check: every probe mark centre has, within 3 px, a pixel whose luminance exceeds night's by at least
    /// `margin`. Returns the marks checked and the misses.
    static func markMisses(_ rgba: [UInt8], snapshot: HueCompassSceneSnapshot, width: Int = width,
                           height: Int = height, margin: Double = litMargin) -> (checked: Int, misses: [String]) {
        let cam: HueCompassCamera = camera(width: width, height: height)
        let threshold: Double = nightLuminance + margin
        var checked: Int = 0
        var misses: [String] = []
        for b in Geometry.probeBearings(snapshot) {
            guard let p = Geometry.pixel(Geometry.probeMarkCentre(b), camera: cam, width: width, height: height) else {
                misses.append("probe mark \(b): no projection")
                continue
            }
            checked += 1
            let found: Bool = anyPixel(rgba, near: p.x, p.y, radius: pointRadius, width: width, height: height) { c in
                luminance(c) >= threshold
            }
            if !found { misses.append(String(format: "probe mark %ld at (%.1f, %.1f)", b, p.x, p.y)) }
        }
        return (checked, misses)
    }

    /// The band check: for each checkable segment the best pixel within 1 px of its projected colour sample is within
    /// 0.15 per channel of `bandSegmentColour`. Returns the segments checked and the misses.
    static func bandMisses(_ rgba: [UInt8], snapshot: HueCompassSceneSnapshot, width: Int = width,
                           height: Int = height) -> (checked: Int, misses: [String]) {
        let cam: HueCompassCamera = camera(width: width, height: height)
        var checked: Int = 0
        var misses: [String] = []
        for k in checkableSegments(snapshot) {
            guard let p = Geometry.pixel(Geometry.bandSamplePoint(k), camera: cam, width: width, height: height) else {
                misses.append("segment \(k): no projection")
                continue
            }
            let want: SIMD3<Double> = Geometry.bandSegmentColour(k, in: snapshot)
            guard let best = bestMatch(rgba, near: p.x, p.y, radius: centreSearch, want: want, width: width,
                                       height: height) else {
                misses.append(String(format: "segment %ld: outside at (%.1f, %.1f)", k, p.x, p.y))
                continue
            }
            checked += 1
            if best.distance > bandTolerance {
                misses.append(String(format: "segment %ld at (%ld, %ld): got (%.3f, %.3f, %.3f) want (%.3f, %.3f, %.3f)",
                                     k, best.x, best.y, best.colour.x, best.colour.y, best.colour.z, want.x, want.y,
                                     want.z))
            }
        }
        return (checked, misses)
    }

    /// The background check: of the pixels 2 px in from each corner, those at least 6 px outside the projected
    /// bounding sphere (radius grown by 15 % for the perspective silhouette) are within 0.05 per channel of night.
    /// Returns the number checked and the misses.
    static func backgroundMisses(_ rgba: [UInt8], width: Int = width, height: Int = height)
        -> (checked: Int, misses: [String]) {
        let cam: HueCompassCamera = camera(width: width, height: height)
        let sphere = disc(SIMD3<Double>(0, 0, 0), radius: Geometry.boundingRadius, camera: cam, width: width,
                          height: height)
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

    /// The pixel positions of the needle tip, every band sample, every fog prism top and every probe mark of
    /// `snapshot` (nil behind the camera), in that order.
    static func referencePixels(_ snapshot: HueCompassSceneSnapshot, width: Int = width,
                                height: Int = height) -> [Vec2?] {
        let cam: HueCompassCamera = camera(width: width, height: height)
        var result: [Vec2?] = [Geometry.pixel(Geometry.needleTip(snapshot), camera: cam, width: width, height: height)]
        for k in 0..<HueCompassWheel.bands {
            result.append(Geometry.pixel(Geometry.bandSamplePoint(k), camera: cam, width: width, height: height))
        }
        for b in 0..<HueCompassWheel.bearings {
            result.append(Geometry.pixel(Geometry.fogTop(b, in: snapshot), camera: cam, width: width, height: height))
        }
        for b in Geometry.probeBearings(snapshot) {
            result.append(Geometry.pixel(Geometry.probeMarkCentre(b), camera: cam, width: width, height: height))
        }
        return result
    }

    /// Runs the checks of clarification Q3 on `rgba` against `snapshot`, recording an issue per failure.
    static func checkFrame(_ rgba: [UInt8], snapshot: HueCompassSceneSnapshot, width: Int = width,
                           height: Int = height, _ what: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(rgba.count == width * height * 4, "\(what): picture size", sourceLocation: sourceLocation)
        guard rgba.count == width * height * 4 else { return }
        let tip: String? = tipMiss(rgba, snapshot: snapshot, width: width, height: height)
        #expect(tip == nil, "\(what): \(tip ?? "")", sourceLocation: sourceLocation)
        let marks = markMisses(rgba, snapshot: snapshot, width: width, height: height)
        #expect(marks.checked == Geometry.probeBearings(snapshot).count, "\(what): marks checked \(marks.checked)",
                sourceLocation: sourceLocation)
        #expect(marks.misses.isEmpty, "\(what): \(marks.misses)", sourceLocation: sourceLocation)
        let bands = bandMisses(rgba, snapshot: snapshot, width: width, height: height)
        #expect(bands.checked == checkableSegments(snapshot).count, "\(what): band segments checked \(bands.checked)",
                sourceLocation: sourceLocation)
        #expect(bands.misses.isEmpty, "\(what): \(bands.misses.count) band misses: \(bands.misses.prefix(6))",
                sourceLocation: sourceLocation)
        let background = backgroundMisses(rgba, width: width, height: height)
        #expect(background.checked >= 1, "\(what): no background pixel clear of the scene",
                sourceLocation: sourceLocation)
        #expect(background.misses.isEmpty, "\(what): \(background.misses)", sourceLocation: sourceLocation)
    }
}
#endif
