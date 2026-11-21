// LissajousLabyrinthTestSupport — feature 313 (R02-G02-03) T-R02G0203-006 (FR-R02G0203-001 … 004, 006, 007;
// SC-R02G0203-001, 002; clarifications Q1–Q4). Shared helpers of the Lissajous Labyrinth experience tests, mirroring the
// Aurora Loom harness (feature 303): opening the experience through the one app's session host (seed `s` prepares level
// `s % 100 + 1`, a session without a quality pin is pinned to level 0), drawing live frames, drawing an off-screen still
// (RGBA8, rows top-down: the host's `renderOffscreen` flips the GL read-back, so the still has the orientation of the
// Core's CPU projection, origin top left, y down), the engine digest, and the frame checks of clarification Q3:
//   - each projected path sample (every 32nd lap tick, i.e. the tier's stride subsampled to 128 samples per lap, the
//     same ticks at every tier; samples inside an obstacle's projected disc + 1 px are skipped) lies within 2 px of a
//     pixel whose luminance exceeds night's by at least 0.15;
//   - each checkpoint ring's band point (`ringBandPoint`) shows `LissajousLabyrinthShaders.solidColour(copper, lit:)` for
//     its state within 0.12 per channel (visited: u_lit 1; next: u_lit 0.5, the mean of dim and lit; otherwise dim); the
//     best pixel within 1.5 px of the band point counts, since the thread or the head may cross the band point itself;
//   - each obstacle not overlapped by another obstacle or a ring band shows, near its projected centre, its two
//     translucent layers (front and back hemisphere, opacity 0.45, no depth test) of violet dim, or copper lit when the
//     lap touches it, over night, within 0.12 per channel (FR-R02G0203-002 contact colour);
//   - the corner pixels at least 6 px from every scene element are within 0.05 per channel of night.
// Adapted bound (documented): clarification Q3 names a 96 × 64 still. At that size the thread (0.035 world units)
// projects to 0.17 … 0.25 px on the five checked levels, so pixel-centre rasterization (no multisampling) leaves 30 … 45 %
// of the path samples without a lit pixel within 2 px, and ring bands are 0.2 … 0.6 px wide (a host CPU raster of the
// Core meshes, 2026-11-20). The checks therefore ran at 8 × that frame, 768 × 512 (the same aspect 1.5 and framing),
// where the CPU raster finds every sample and every ring band. Feature 314 (R02-G02-04) frames the dial rings beside the
// figure, which shrinks the figure on screen by about a third, so the checks now run at 12 × (1,152 × 768) and the
// colour search radius grows by the same 1.5 (1.5 → 2.25 px): the same world distances as before. `width`/`height`
// below are the single place to change.
// Luminance is the Rec. 709 weighting of the stored 0 … 1 channel values. Short runs only (no sleep, no wall-clock
// assertion).
#if os(iOS)
import CoreGraphics
import Foundation
import Testing
import UIKit
import LissajousLabyrinthCore
@testable import LissajousLabyrinthExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

/// Building, opening, drawing and measuring Lissajous Labyrinth.
@MainActor
enum LissajousLabyrinthTest {
    typealias Geometry = LissajousLabyrinthSceneGeometry
    typealias Palette = LissajousLabyrinthPalette

    /// The experience id `r02-g02.lissajous-labyrinth`.
    static var id: ExperienceID {
        LissajousLabyrinthExperience.id ?? ExperienceID(rawValue: "r02-g02.unknown")!
    }

    /// The frame-check size: 8 × clarification Q3's 96 × 64 (see the file header), aspect 1.5.
    static let width = 1_152, height = 768
    /// The seeds of the checked levels 1, 21, 41, 61 and 81.
    static let seeds: [UInt64] = [0, 20, 40, 60, 80]
    /// The path samples checked: every `tickStep`-th lap tick (128 per lap at every tier).
    static let tickStep = 32
    /// The path samples' search radius in pixels and their luminance margin over the background.
    static let sampleRadius = 2.0
    static let litMargin = 0.15
    /// The per-channel bounds of the ring and obstacle colours and of the background.
    static let colourTolerance = 0.12
    static let backgroundTolerance = 0.05
    /// How far (pixels) from the band point / obstacle centre a matching pixel may be.
    static let colourSearch = 2.25
    /// How far (pixels) a background pixel must be from every scene element.
    static let backgroundClearance = 6.0
    /// The obstacles' opacity in the scene (`drawSpheres`).
    static let obstacleOpacity = 0.45

    /// Opens Lissajous Labyrinth with `seed` in `session` through the factory, lays the view out at `size` points and
    /// draws one frame. A session without a quality pin is pinned to level 0. `configure` runs on the presenter before
    /// its first `setup` (the fallback seam).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false, size: CGSize = CGSize(width: 48, height: 32),
                     configure: ((LissajousLabyrinthPresenter) -> Void)? = nil) async throws
        -> ExperienceShell<LissajousLabyrinthPresenter> {
        let id = self.id
        var made: ExperienceShell<LissajousLabyrinthPresenter>?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: seed) {
            let shell = LissajousLabyrinthExperience.make(id: id, reduceMotion: reduceMotion,
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
    static func digest(_ shell: ExperienceShell<LissajousLabyrinthPresenter>) throws -> String {
        try shell.engine.digest().hex
    }

    /// Pins `session` to quality level `tier` and checks that the engine took it.
    static func pin(_ session: ExperienceSession, _ shell: ExperienceShell<LissajousLabyrinthPresenter>, tier: Int,
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
    static var nightLuminance: Double { luminance(Palette.night) }

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

    /// The number of pixels farther than `tolerance` per channel from night.
    static func nonNightPixels(_ rgba: [UInt8], tolerance: Double = 0.05) -> Int {
        var count = 0
        var i = 0
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

    /// The pixel within `radius` of (`px`, `py`) whose colour is nearest `want` (per channel), and that distance;
    /// nil when no pixel centre lies within `radius` inside the picture.
    static func bestMatch(_ rgba: [UInt8], near px: Double, _ py: Double, radius: Double, want: SIMD3<Double>,
                          width: Int, height: Int) -> (x: Int, y: Int, colour: SIMD3<Double>, distance: Double)? {
        let reach = Int(radius.rounded(.up)) + 1
        let cx = Int(px.rounded(.down))
        let cy = Int(py.rounded(.down))
        var best: (x: Int, y: Int, colour: SIMD3<Double>, distance: Double)?
        for y in (cy - reach)...(cy + reach) {
            guard y >= 0, y < height else { continue }
            for x in (cx - reach)...(cx + reach) {
                guard x >= 0, x < width else { continue }
                let dx = Double(x) + 0.5 - px
                let dy = Double(y) + 0.5 - py
                guard dx * dx + dy * dy <= radius * radius else { continue }
                let c = colour(rgba, x: x, y: y, width: width)
                let d = channelDistance(c, want)
                if best == nil || d < best!.distance { best = (x, y, c, d) }
            }
        }
        return best
    }

    // MARK: CPU reference (clarification Q3)

    /// The view-projection the scene uses for a `width` × `height` target.
    static func viewProjection(_ snapshot: LissajousLabyrinthSceneSnapshot, width: Int, height: Int) -> Mat4 {
        Geometry.viewProjection(aspect: Double(width) / Double(height), snapshot: snapshot)
    }

    /// The camera's world up axis: +y made perpendicular to the view direction (as `ringBandPoint` uses it).
    static var cameraUp: Vec3 {
        let v = Geometry.viewDirection
        return (Vec3(0, 1, 0) - v * v.y).normalized
    }

    /// The projected centre and pixel radius of a ball (checkpoint or obstacle), nil behind the camera.
    static func disc(_ ball: LissajousLabyrinthBall, viewProjection: Mat4, width: Int,
                     height: Int) -> (centre: Vec2, radius: Double)? {
        let centre = Geometry.world(ball)
        guard let c = Geometry.project(centre, viewProjection: viewProjection, width: width, height: height),
              let e = Geometry.project(centre + cameraUp * Geometry.radius(ball), viewProjection: viewProjection,
                                       width: width, height: height) else { return nil }
        let dx = e.x - c.x, dy = e.y - c.y
        return (c, (dx * dx + dy * dy).squareRoot())
    }

    /// The projected discs of every obstacle of `snapshot`.
    static func obstacleDiscs(_ snapshot: LissajousLabyrinthSceneSnapshot, viewProjection: Mat4, width: Int,
                              height: Int) -> [(centre: Vec2, radius: Double)] {
        var discs: [(centre: Vec2, radius: Double)] = []
        for ball in snapshot.level.obstacles {
            if let d = disc(ball, viewProjection: viewProjection, width: width, height: height) { discs.append(d) }
        }
        return discs
    }

    /// The checked path samples of `tier`: the drawn samples (`Geometry.path`) at lap ticks 0, 32, 64, …, projected;
    /// nil entries are samples behind the camera. Every tier yields the same 128 ticks.
    static func checkedSamples(_ snapshot: LissajousLabyrinthSceneSnapshot, tier: LissajousLabyrinthTier,
                               viewProjection: Mat4, width: Int, height: Int) -> [(tick: Int, pixel: Vec2?)] {
        let path = Geometry.path(snapshot, tier: tier)
        let step = Swift.max(tickStep / Swift.max(tier.stride, 1), 1)
        var result: [(tick: Int, pixel: Vec2?)] = []
        var j = 0
        while j < path.count {
            let p = Geometry.project(path[j], viewProjection: viewProjection, width: width, height: height)
            result.append((j * tier.stride, p))
            j += step
        }
        return result
    }

    /// The path check: every checked sample of `tier` not inside an obstacle's projected disc (+ 1 px) has, within
    /// 2 px, a pixel whose luminance exceeds night's by at least `margin`. Returns the samples, the skipped and the
    /// misses.
    static func pathMisses(_ rgba: [UInt8], snapshot: LissajousLabyrinthSceneSnapshot, tier: LissajousLabyrinthTier,
                           width: Int = width, height: Int = height,
                           margin: Double = litMargin) -> (samples: Int, skipped: Int, misses: [String]) {
        let vp = viewProjection(snapshot, width: width, height: height)
        let discs = obstacleDiscs(snapshot, viewProjection: vp, width: width, height: height)
        let threshold = nightLuminance + margin
        var samples = 0
        var skipped = 0
        var misses: [String] = []
        for sample in checkedSamples(snapshot, tier: tier, viewProjection: vp, width: width, height: height) {
            samples += 1
            guard let p = sample.pixel else {
                misses.append("tick \(sample.tick): no projection")
                continue
            }
            var hidden = false
            for d in discs {
                let dx = p.x - d.centre.x, dy = p.y - d.centre.y
                if (dx * dx + dy * dy).squareRoot() <= d.radius + 1 { hidden = true }
            }
            if hidden {
                skipped += 1
                continue
            }
            let found = anyPixel(rgba, near: p.x, p.y, radius: sampleRadius, width: width, height: height) { c in
                luminance(c) >= threshold
            }
            if !found { misses.append(String(format: "tick %ld at (%.1f, %.1f)", sample.tick, p.x, p.y)) }
        }
        return (samples, skipped, misses)
    }

    /// The colour a checkpoint ring of `snapshot` shows where it faces the camera: lit when visited in order, half lit
    /// (u_lit 0.5: the mean of dim and lit) when it is the next one, dim otherwise.
    static func ringColour(_ snapshot: LissajousLabyrinthSceneSnapshot, index: Int) -> SIMD3<Double> {
        let dim = LissajousLabyrinthShaders.solidColour(Palette.copper, lit: false)
        let lit = LissajousLabyrinthShaders.solidColour(Palette.copper, lit: true)
        if snapshot.visited(index) { return lit }
        if snapshot.nextCheckpoint == index { return dim + (lit - dim) * 0.5 }
        return dim
    }

    /// A ring's state name for messages.
    static func ringState(_ snapshot: LissajousLabyrinthSceneSnapshot, index: Int) -> String {
        if snapshot.visited(index) { return "visited" }
        return snapshot.nextCheckpoint == index ? "next" : "unvisited"
    }

    /// The ring check: for each checkpoint the best pixel within 1.5 px of its projected band point is within 0.12 per
    /// channel of `ringColour`. Returns the number checked, the states seen and the misses.
    static func ringMisses(_ rgba: [UInt8], snapshot: LissajousLabyrinthSceneSnapshot, width: Int = width,
                           height: Int = height) -> (checked: Int, states: Set<String>, misses: [String]) {
        let vp = viewProjection(snapshot, width: width, height: height)
        var checked = 0
        var states: Set<String> = []
        var misses: [String] = []
        for (index, ball) in snapshot.level.checkpoints.enumerated() {
            let state = ringState(snapshot, index: index)
            guard let b = Geometry.project(Geometry.ringBandPoint(ball), viewProjection: vp, width: width,
                                           height: height) else {
                misses.append("ring \(index): no projection")
                continue
            }
            let want = ringColour(snapshot, index: index)
            guard let best = bestMatch(rgba, near: b.x, b.y, radius: colourSearch, want: want, width: width,
                                       height: height) else {
                misses.append(String(format: "ring %ld: band point outside at (%.1f, %.1f)", index, b.x, b.y))
                continue
            }
            checked += 1
            states.insert(state)
            if best.distance > colourTolerance {
                misses.append(String(format: "ring %ld (%@) at (%ld, %ld): got (%.3f, %.3f, %.3f) want (%.3f, %.3f, %.3f)",
                                     index, state, best.x, best.y, best.colour.x, best.colour.y, best.colour.z,
                                     want.x, want.y, want.z))
            }
        }
        return (checked, states, misses)
    }

    /// The colour at the centre of an obstacle over night: its two translucent hemispheres (front and back, no depth
    /// test), each premultiplied `solidColour(violet, lit: false)` or, when the lap touches it, `solidColour(copper,
    /// lit: true)`, at opacity 0.45.
    static func obstacleColour(touched: Bool) -> SIMD3<Double> {
        let body = touched ? LissajousLabyrinthShaders.solidColour(Palette.copper, lit: true)
            : LissajousLabyrinthShaders.solidColour(Palette.violet, lit: false)
        var c = Palette.night
        for _ in 0..<2 { c = body * obstacleOpacity + c * (1 - obstacleOpacity) }
        return c
    }

    /// The obstacle check: each obstacle whose centre is not covered by another obstacle's disc (+ 1 px) nor near a
    /// ring band has, within 1.5 px of its projected centre, a pixel within 0.12 per channel of `obstacleColour`.
    /// Returns the number checked, whether the touched obstacle was among them, and the misses.
    static func obstacleMisses(_ rgba: [UInt8], snapshot: LissajousLabyrinthSceneSnapshot, width: Int = width,
                               height: Int = height) -> (checked: Int, touchedChecked: Bool, misses: [String]) {
        let vp = viewProjection(snapshot, width: width, height: height)
        let discs = obstacleDiscs(snapshot, viewProjection: vp, width: width, height: height)
        var rings: [(centre: Vec2, radius: Double)] = []
        for ball in snapshot.level.checkpoints {
            if let d = disc(ball, viewProjection: vp, width: width, height: height) { rings.append(d) }
        }
        var checked = 0
        var touchedChecked = false
        var misses: [String] = []
        guard discs.count == snapshot.level.obstacles.count else {
            return (0, false, ["an obstacle has no projection"])
        }
        for (index, d) in discs.enumerated() {
            var covered = false
            for (other, e) in discs.enumerated() where other != index {
                let dx = d.centre.x - e.centre.x, dy = d.centre.y - e.centre.y
                if (dx * dx + dy * dy).squareRoot() <= e.radius + colourSearch + 1 { covered = true }
            }
            for r in rings {
                let dx = d.centre.x - r.centre.x, dy = d.centre.y - r.centre.y
                let distance = (dx * dx + dy * dy).squareRoot()
                let inner = Geometry.ringInner * r.radius
                if distance >= inner - colourSearch - 1 && distance <= r.radius + colourSearch + 1 { covered = true }
            }
            if covered { continue }
            let touched = snapshot.contactObstacle == index
            let want = obstacleColour(touched: touched)
            guard let best = bestMatch(rgba, near: d.centre.x, d.centre.y, radius: colourSearch, want: want,
                                       width: width, height: height) else {
                misses.append(String(format: "obstacle %ld: outside at (%.1f, %.1f)", index, d.centre.x, d.centre.y))
                continue
            }
            checked += 1
            if touched { touchedChecked = true }
            if best.distance > colourTolerance {
                misses.append(String(format: "obstacle %ld (touched %@) at (%ld, %ld): got (%.3f, %.3f, %.3f) want (%.3f, %.3f, %.3f)",
                                     index, touched ? "yes" : "no", best.x, best.y, best.colour.x, best.colour.y,
                                     best.colour.z, want.x, want.y, want.z))
            }
        }
        return (checked, touchedChecked, misses)
    }

    /// The distance (pixels) from (`px`, `py`) to the nearest scene element: path samples (level-2's every 4th tick,
    /// grown by 2 px), checkpoint and obstacle discs and the head.
    static func sceneDistance(_ snapshot: LissajousLabyrinthSceneSnapshot, px: Double, py: Double, width: Int,
                              height: Int) -> Double {
        let vp = viewProjection(snapshot, width: width, height: height)
        var nearest = Double.infinity
        let path = Geometry.path(snapshot, tier: LissajousLabyrinthTier.of(2))
        for q in path {
            guard let p = Geometry.project(q, viewProjection: vp, width: width, height: height) else { continue }
            let dx = p.x - px, dy = p.y - py
            nearest = Swift.min(nearest, (dx * dx + dy * dy).squareRoot() - 2)
        }
        var balls: [LissajousLabyrinthBall] = snapshot.level.checkpoints
        for ball in snapshot.level.obstacles { balls.append(ball) }
        for ball in balls {
            guard let d = disc(ball, viewProjection: vp, width: width, height: height) else { continue }
            let dx = d.centre.x - px, dy = d.centre.y - py
            nearest = Swift.min(nearest, (dx * dx + dy * dy).squareRoot() - d.radius)
        }
        if let h = Geometry.project(Geometry.headPosition(snapshot), viewProjection: vp, width: width, height: height) {
            let dx = h.x - px, dy = h.y - py
            nearest = Swift.min(nearest, (dx * dx + dy * dy).squareRoot() - 8)
        }
        return nearest
    }

    /// The background check: of the pixels 2 px in from each corner, those at least 6 px from every scene element are
    /// within 0.05 per channel of night. Returns the number checked and the misses.
    static func backgroundMisses(_ rgba: [UInt8], snapshot: LissajousLabyrinthSceneSnapshot, width: Int = width,
                                 height: Int = height) -> (checked: Int, misses: [String]) {
        let candidates: [(x: Int, y: Int)] = [(2, 2), (width - 3, 2), (2, height - 3), (width - 3, height - 3)]
        var checked = 0
        var misses: [String] = []
        for candidate in candidates {
            let distance = sceneDistance(snapshot, px: Double(candidate.x) + 0.5, py: Double(candidate.y) + 0.5,
                                         width: width, height: height)
            guard distance >= backgroundClearance else { continue }
            checked += 1
            let got = colour(rgba, x: candidate.x, y: candidate.y, width: width)
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
        let bandX = Int((Double(width) * fraction).rounded(.down))
        let bandY = Int((Double(height) * fraction).rounded(.down))
        var checked = 0
        var misses: [String] = []
        var y = 0
        while y < height {
            var x = 0
            while x < width {
                let inBand = x < bandX || x >= width - bandX || y < bandY || y >= height - bandY
                if inBand {
                    checked += 1
                    let got = colour(rgba, x: x, y: y, width: width)
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

    /// Runs the checks of clarification Q3 on `rgba` (drawn at `tier`) against `snapshot`, recording an issue per
    /// failure.
    static func checkFrame(_ rgba: [UInt8], snapshot: LissajousLabyrinthSceneSnapshot, tier: Int,
                           width: Int = width, height: Int = height, _ what: String,
                           sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(rgba.count == width * height * 4, "\(what): picture size", sourceLocation: sourceLocation)
        guard rgba.count == width * height * 4 else { return }
        let path = pathMisses(rgba, snapshot: snapshot, tier: LissajousLabyrinthTier.of(tier), width: width,
                              height: height)
        #expect(path.samples == LissajousLabyrinthLap.ticks / tickStep, "\(what): path samples \(path.samples)",
                sourceLocation: sourceLocation)
        #expect(path.skipped * 2 < path.samples, "\(what): \(path.skipped) of \(path.samples) samples skipped",
                sourceLocation: sourceLocation)
        #expect(path.misses.isEmpty,
                "\(what): \(path.misses.count) path samples without a lit pixel: \(path.misses.prefix(6))",
                sourceLocation: sourceLocation)
        let rings = ringMisses(rgba, snapshot: snapshot, width: width, height: height)
        #expect(rings.checked == snapshot.level.checkpoints.count, "\(what): rings checked \(rings.checked)",
                sourceLocation: sourceLocation)
        #expect(rings.misses.isEmpty, "\(what): \(rings.misses)", sourceLocation: sourceLocation)
        let obstacles = obstacleMisses(rgba, snapshot: snapshot, width: width, height: height)
        #expect(obstacles.misses.isEmpty, "\(what): \(obstacles.misses)", sourceLocation: sourceLocation)
        let background = backgroundMisses(rgba, snapshot: snapshot, width: width, height: height)
        #expect(background.checked >= 1, "\(what): no background pixel clear of the scene",
                sourceLocation: sourceLocation)
        #expect(background.misses.isEmpty, "\(what): \(background.misses)", sourceLocation: sourceLocation)
    }
}
#endif
