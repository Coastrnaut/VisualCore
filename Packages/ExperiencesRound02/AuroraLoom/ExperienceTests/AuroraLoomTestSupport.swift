// AuroraLoomTestSupport — feature 303 (R02-G01-03) T-R02G0103-008 (FR-R02G0103-003, 004, 006, 007; SC-R02G0103-001,
// 002; clarifications Q2–Q4). Shared helpers of the Aurora Loom experience tests, mirroring the A21 Aurora harness:
// opening the experience through the one app's session host (seed `s` prepares level `s % 100 + 1`, a session without a
// quality pin is pinned to level 0), drawing live frames, drawing an off-screen still (RGBA8, rows top-down: the host's
// `renderOffscreen` flips the GL read-back, so the still has the same orientation as the Core's CPU reference, origin top
// left, y down), the engine digest, and the frame checks of clarification Q3 at 96 × 64: each projected ribbon centre-line
// sample (32 segments) within 2 px of a pixel whose luminance exceeds the night background's by at least 0.15, each gate
// marker's pixel within 0.12 per channel of its gold (dim or lit), and background pixels at least 6 px from every
// ribbon, ring and marker within 0.05 per channel of night. Luminance is the Rec. 709 weighting of the stored 0 … 1
// channel values (the same per-channel scale as the colour bounds). Short runs only (no sleep, no wall-clock assertion).
#if os(iOS)
import CoreGraphics
import Foundation
import Testing
import UIKit
import AuroraLoomCore
@testable import AuroraLoomExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

/// Building, opening, drawing and measuring Aurora Loom.
@MainActor
enum AuroraLoomTest {
    /// The experience id `r02-g01.aurora-loom`.
    static var id: ExperienceID {
        AuroraLoomExperience.id ?? ExperienceID(rawValue: "r02-g01.unknown")!
    }

    /// The frame-check size of clarification Q3: 96 × 64 pixels.
    static let width = 96, height = 64
    /// The seeds of the checked levels 1, 21, 41, 61 and 81.
    static let seeds: [UInt64] = [0, 20, 40, 60, 80]
    /// The ribbon samples' search radius in pixels and their luminance margin over the background.
    static let sampleRadius = 2.0
    static let litMargin = 0.15
    /// The per-channel bounds of the marker colour and the background.
    static let markerTolerance = 0.12
    static let backgroundTolerance = 0.05
    /// How far (pixels) a background pixel must be from every ribbon, ring and marker point.
    static let backgroundClearance = 6.0

    /// Opens Aurora Loom with `seed` in `session` through the factory, lays the view out at `size` points and draws one
    /// frame. A session without a quality pin is pinned to level 0. `configure` runs on the presenter before its first
    /// `setup` (the fallback seam).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false, size: CGSize = CGSize(width: 48, height: 32),
                     configure: ((AuroraLoomPresenter) -> Void)? = nil) async throws
        -> ExperienceShell<AuroraLoomPresenter> {
        let id = self.id
        var made: ExperienceShell<AuroraLoomPresenter>?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: seed) {
            let shell = AuroraLoomExperience.make(id: id, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
            configure?(shell.presenter)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        #expect(opened == .running)
        let view = try #require(session.renderHost?.view)
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutIfNeeded()
        let shell = try #require(made)
        try draw(session)
        return shell
    }

    /// Draws `count` live frames of `session` (each 1/60 s of frame time).
    static func draw(_ session: ExperienceSession, frames count: Int = 1) throws {
        let host = try #require(session.renderHost)
        var drawn = 0
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
    static func digest(_ shell: ExperienceShell<AuroraLoomPresenter>) throws -> String {
        try shell.engine.digest().hex
    }

    /// Pins `session` to quality level `tier` and checks that the engine took it.
    static func pin(_ session: ExperienceSession, _ shell: ExperienceShell<AuroraLoomPresenter>, tier: Int,
                    sourceLocation: SourceLocation = #_sourceLocation) {
        session.qualityPin = tier
        #expect(shell.engine.qualityTier == tier, "pinned tier \(tier)", sourceLocation: sourceLocation)
    }

    // MARK: Pixels

    /// The colour (0 … 1 per channel) of pixel (`x`, `y`) of a top-down RGBA8 picture `width` pixels wide.
    static func colour(_ rgba: [UInt8], x: Int, y: Int, width: Int) -> SIMD3<Double> {
        let i = (y * width + x) * 4
        return SIMD3<Double>(Double(rgba[i]) / 255, Double(rgba[i + 1]) / 255, Double(rgba[i + 2]) / 255)
    }

    /// The Rec. 709 luminance of the 0 … 1 channel values of `c`.
    static func luminance(_ c: SIMD3<Double>) -> Double {
        0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z
    }

    /// The luminance of the night background.
    static var nightLuminance: Double { luminance(AuroraLoomPalette.night) }

    /// The largest per-channel difference of `a` and `b`.
    static func channelDistance(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        Swift.max(Swift.abs(a.x - b.x), Swift.abs(a.y - b.y), Swift.abs(a.z - b.z))
    }

    /// The mean luminance of a picture.
    static func meanLuminance(_ rgba: [UInt8]) -> Double {
        var sum = 0.0
        var count = 0
        var i = 0
        while i + 3 < rgba.count {
            let c = SIMD3<Double>(Double(rgba[i]) / 255, Double(rgba[i + 1]) / 255, Double(rgba[i + 2]) / 255)
            sum += luminance(c)
            count += 1
            i += 4
        }
        return count > 0 ? sum / Double(count) : 0
    }

    /// Whether some pixel whose centre lies within `radius` of (`px`, `py`) satisfies `accept`.
    static func anyPixel(_ rgba: [UInt8], near px: Double, _ py: Double, radius: Double, width: Int, height: Int,
                         accept: (SIMD3<Double>) -> Bool) -> Bool {
        let reach = Int(radius.rounded(.up)) + 1
        let cx = Int(px.rounded(.down))
        let cy = Int(py.rounded(.down))
        for y in (cy - reach)...(cy + reach) {
            guard y >= 0, y < height else { continue }
            for x in (cx - reach)...(cx + reach) {
                guard x >= 0, x < width else { continue }
                let dx = Double(x) + 0.5 - px
                let dy = Double(y) + 0.5 - py
                guard dx * dx + dy * dy <= radius * radius else { continue }
                if accept(colour(rgba, x: x, y: y, width: width)) { return true }
            }
        }
        return false
    }

    // MARK: Frame checks (clarification Q3)

    /// The ribbon check: every reference sample (32 segments) of `snapshot` at `width` × `height` has, within 2 px, a
    /// pixel whose luminance exceeds night's by at least `margin`. Returns the number of samples and the misses.
    static func ribbonMisses(_ rgba: [UInt8], snapshot: AuroraLoomSceneSnapshot, width: Int = width,
                             height: Int = height, margin: Double = litMargin) -> (samples: Int, misses: [String]) {
        let aspect = Double(width) / Double(height)
        let reference = AuroraLoomSceneGeometry.referenceSamples(snapshot: snapshot, aspect: aspect, width: width,
                                                                 height: height, segments: 32)
        let threshold = nightLuminance + margin
        var samples = 0
        var misses: [String] = []
        for ribbon in 0..<reference.count {
            for (index, p) in reference[ribbon].enumerated() {
                samples += 1
                let found = anyPixel(rgba, near: p.x, p.y, radius: sampleRadius, width: width, height: height) { c in
                    luminance(c) >= threshold
                }
                if !found {
                    misses.append(String(format: "ribbon %ld sample %ld at (%.1f, %.1f)", ribbon, index, p.x, p.y))
                }
            }
        }
        return (samples, misses)
    }

    /// Whether all three ribbons meet `gate` at `snapshot`'s tick (the marker is lit).
    static func gateLit(_ snapshot: AuroraLoomSceneSnapshot, gate: Int) -> Bool {
        var lit = true
        for ribbon in 0..<3 where !snapshot.lit(ribbon: ribbon, gate: gate) { lit = false }
        return lit
    }

    /// The marker check: the pixel holding each gate marker's projected centre is within 0.12 per channel of
    /// `AuroraLoomShaders.gateColour(gold, lit:)`. A marker that a later-drawn marker of the other lit state may cover
    /// (centres within 3 px) is skipped. Returns the number checked and the misses.
    static func markerMisses(_ rgba: [UInt8], snapshot: AuroraLoomSceneSnapshot, width: Int = width,
                             height: Int = height) -> (checked: Int, misses: [String]) {
        let aspect = Double(width) / Double(height)
        var centres: [(x: Double, y: Double)?] = []
        var lits: [Bool] = []
        for gate in 0..<4 {
            centres.append(AuroraLoomSceneGeometry.markerPixel(gate: gate, snapshot: snapshot, aspect: aspect,
                                                               width: width, height: height))
            lits.append(gateLit(snapshot, gate: gate))
        }
        var checked = 0
        var misses: [String] = []
        for gate in 0..<4 {
            guard let c = centres[gate] else {
                misses.append("gate \(gate): no projection")
                continue
            }
            var covered = false
            for later in (gate + 1)..<4 {
                guard let d = centres[later], lits[later] != lits[gate] else { continue }
                let dx = d.x - c.x, dy = d.y - c.y
                if dx * dx + dy * dy < 9 { covered = true }
            }
            if covered { continue }
            let x = Int(c.x.rounded(.down)), y = Int(c.y.rounded(.down))
            guard x >= 0, x < width, y >= 0, y < height else {
                misses.append("gate \(gate): outside at (\(x), \(y))")
                continue
            }
            let want = AuroraLoomShaders.gateColour(AuroraLoomPalette.gold, lit: lits[gate])
            let got = colour(rgba, x: x, y: y, width: width)
            checked += 1
            let off = channelDistance(got, want)
            if off > markerTolerance {
                misses.append(String(format: "gate %ld (lit %@) at (%ld, %ld): got (%.3f, %.3f, %.3f) want (%.3f, %.3f, %.3f)",
                                     gate, lits[gate] ? "yes" : "no", x, y, got.x, got.y, got.z, want.x, want.y, want.z))
            }
        }
        return (checked, misses)
    }

    /// Every projected point of the scene's ribbons (128 segments), rings and markers at `width` × `height`.
    static func scenePoints(_ snapshot: AuroraLoomSceneSnapshot, width: Int, height: Int) -> [(x: Double, y: Double)] {
        let aspect = Double(width) / Double(height)
        var points: [(x: Double, y: Double)] = []
        let ribbons = AuroraLoomSceneGeometry.referenceSamples(snapshot: snapshot, aspect: aspect, width: width,
                                                               height: height, segments: 128)
        for line in ribbons { for p in line { points.append(p) } }
        for gate in 0..<4 {
            for q in AuroraLoomSceneGeometry.gateRing(gate: gate, snapshot: snapshot) {
                if let p = AuroraLoomSceneGeometry.project(q, aspect: aspect, width: width, height: height) {
                    points.append(p)
                }
            }
            if let m = AuroraLoomSceneGeometry.markerPixel(gate: gate, snapshot: snapshot, aspect: aspect, width: width,
                                                           height: height) {
                points.append(m)
            }
        }
        return points
    }

    /// The background check: of the pixels 2 px in from each corner, those at least 6 px from every scene point are
    /// within 0.05 per channel of night. Returns the number checked and the misses.
    static func backgroundMisses(_ rgba: [UInt8], snapshot: AuroraLoomSceneSnapshot, width: Int = width,
                                 height: Int = height) -> (checked: Int, misses: [String]) {
        let points = scenePoints(snapshot, width: width, height: height)
        let candidates: [(x: Int, y: Int)] = [(2, 2), (width - 3, 2), (2, height - 3), (width - 3, height - 3)]
        var checked = 0
        var misses: [String] = []
        for candidate in candidates {
            let cx = Double(candidate.x) + 0.5, cy = Double(candidate.y) + 0.5
            var nearest = Double.infinity
            for p in points {
                let dx = p.x - cx, dy = p.y - cy
                nearest = Swift.min(nearest, (dx * dx + dy * dy).squareRoot())
            }
            guard nearest >= backgroundClearance else { continue }
            checked += 1
            let got = colour(rgba, x: candidate.x, y: candidate.y, width: width)
            if channelDistance(got, AuroraLoomPalette.night) > backgroundTolerance {
                misses.append(String(format: "background (%ld, %ld): (%.3f, %.3f, %.3f)", candidate.x, candidate.y,
                                     got.x, got.y, got.z))
            }
        }
        return (checked, misses)
    }

    /// Runs the three checks of clarification Q3 on `rgba` against `snapshot`, recording an issue per failure.
    static func checkFrame(_ rgba: [UInt8], snapshot: AuroraLoomSceneSnapshot, width: Int = width,
                           height: Int = height, _ what: String,
                           sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(rgba.count == width * height * 4, "\(what): picture size", sourceLocation: sourceLocation)
        guard rgba.count == width * height * 4 else { return }
        let ribbons = ribbonMisses(rgba, snapshot: snapshot, width: width, height: height)
        #expect(ribbons.samples == 3 * 33, "\(what): ribbon samples \(ribbons.samples)", sourceLocation: sourceLocation)
        #expect(ribbons.misses.isEmpty,
                "\(what): \(ribbons.misses.count) ribbon samples without a lit pixel: \(ribbons.misses.prefix(6))",
                sourceLocation: sourceLocation)
        let markers = markerMisses(rgba, snapshot: snapshot, width: width, height: height)
        #expect(markers.checked >= 1, "\(what): no marker checked", sourceLocation: sourceLocation)
        #expect(markers.misses.isEmpty, "\(what): \(markers.misses)", sourceLocation: sourceLocation)
        let background = backgroundMisses(rgba, snapshot: snapshot, width: width, height: height)
        #expect(background.checked >= 1, "\(what): no background pixel clear of the scene",
                sourceLocation: sourceLocation)
        #expect(background.misses.isEmpty, "\(what): \(background.misses)", sourceLocation: sourceLocation)
    }
}
#endif
