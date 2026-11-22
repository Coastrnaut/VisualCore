// FacetedForgeTestSupport — feature 373 (R02-G08-03) T-R02G0803-006 (FR-R02G0803-001 … 007; SC-R02G0803-001, 002;
// clarifications Q1–Q5). Shared helpers of the Faceted Forge experience tests, following the Amethyst Escape harness
// (feature 363): opening the experience through the one app's session host (seed `s` prepares level `s % 100 + 1`; a
// session without a quality pin is pinned to level 0), advancing the play (the first cut of the level's certified
// solution, `piece.cut [piece, direction, depth]`, so there are at least two pieces and a cut face), drawing live
// frames, drawing an off-screen still (RGBA8, rows top-down: the host's `renderOffscreen` flips the GL read-back, so
// the still has the orientation of the Core's CPU projection `FacetedForgeSceneGeometry.pixel`, origin top left, y
// down), the engine digest, and the frame checks of clarification Q3 at 1,152 × 768:
//   - within 3 px of every piece's opened centre some pixel differs from the ground by at least 0.1 in luminance;
//   - within 3 px of every camera-facing cut face's centre some pixel is warm (red − blue at least 0.15);
//   - within 3 px of the preview plane's centre (when the preview crosses its piece) some pixel differs from the
//     ground by at least 0.05 in luminance;
//   - within 3 px of the cut mark's first bar some pixel differs from the ground by at least 0.1 in luminance;
//   - the ground at the two probe corners (0.02, 0.02) and (0.98, 0.98) of the view is within 0.05 per channel of
//     `FacetedForgePalette.ground` (the camera fits the bounding sphere inside a 5 % margin).
// The cut-face check is restricted to faces whose outward normal faces the eye (n · unit(eye − centre) > 0.05): every
// cut makes two coincident cut faces with opposite normals, and the one turned away is culled (back faces are culled on
// every draw), so it cannot be seen. A visible cut face may lie behind another piece's translucent ice glass (alpha
// 0.45, more at grazing angles); through one glass layer the amber interior keeps red − blue near 0.2, so it is still
// checked. A cut face whose centre lies under an opaque bar of the cut mark (drawn last) is skipped and counted.
// Positions come from the presenter's `lastSnapshot` (the snapshot it drew, with the time of the still) and the
// presenter's Reduce Motion setting, which the scene's geometry uses too. Luminance is the Rec. 709 weighting of the
// stored 0 … 1 channel values. Short runs only (no sleep, no wall-clock assertion).
#if os(iOS)
import CoreGraphics
import FacetedForgeCore
import Foundation
import Testing
import UIKit
@testable import FacetedForgeExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// Building, opening, drawing and measuring Faceted Forge.
@MainActor
enum FacetedForgeTest {
    typealias Geometry = FacetedForgeSceneGeometry
    typealias Palette = FacetedForgePalette
    typealias Snapshot = FacetedForgeSceneSnapshot
    typealias Shell = ExperienceShell<FacetedForgePresenter>

    /// The experience id `r02-g08.faceted-forge`.
    static var id: ExperienceID {
        FacetedForgeExperience.id ?? ExperienceID(rawValue: "r02-g08.unknown")!
    }

    /// The frame-check size of clarification Q3, aspect 1.5.
    static let width: Int = 1_152
    static let height: Int = 768
    /// The seeds of the checked levels 1, 21, 41, 61 and 81 (seed = level − 1).
    static let seeds: [UInt64] = [0, 20, 40, 60, 80]
    /// The search radius (pixels) of every point check.
    static let pointRadius: Double = 3
    /// The luminance difference from the ground near a piece centre.
    static let pieceMargin: Double = 0.1
    /// The warmth (red − blue) near a visible cut face's centre.
    static let cutWarmth: Double = 0.15
    /// The luminance difference from the ground near the preview plane's centre.
    static let previewMargin: Double = 0.05
    /// The luminance difference from the ground near the cut mark's first bar.
    static let markMargin: Double = 0.1
    /// The per-channel bound of the ground.
    static let backgroundTolerance: Double = 0.05
    /// The smallest n · unit(eye − centre) of a cut face counted as facing the camera.
    static let facingMinimum: Double = 0.05
    /// The ground probe points (fractions of the view, origin top left).
    static let backgroundPoints: [(x: Double, y: Double)] = [(0.02, 0.02), (0.98, 0.98)]

    /// Opens Faceted Forge with `seed` in `session` through the factory, lays the view out at `size` points and draws
    /// one frame. A session without a quality pin is pinned to level 0. `configure` runs on the presenter before its
    /// first `setup` (the fallback seam).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false, size: CGSize = CGSize(width: 48, height: 32),
                     configure: ((FacetedForgePresenter) -> Void)? = nil) async throws -> Shell {
        let id: ExperienceID = self.id
        var made: Shell?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: seed) {
            let shell: Shell = FacetedForgeExperience.make(id: id, reduceMotion: reduceMotion,
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
    static func core(_ shell: Shell) throws -> FacetedForgeExperienceCore {
        try #require(shell.engine.core)
    }

    /// Pins `session` to quality level `tier` and checks that the engine took it.
    static func pin(_ session: ExperienceSession, _ shell: Shell, tier: Int,
                    sourceLocation: SourceLocation = #_sourceLocation) {
        session.qualityPin = tier
        #expect(shell.engine.qualityTier == tier, "pinned tier \(tier)", sourceLocation: sourceLocation)
    }

    /// The control and values that issue the kernel action `action` through the shell.
    static func control(_ action: FacetedForgeAction) -> (control: String, values: [Double]) {
        switch action {
        case .cut(let piece, let direction, let depth):
            ("piece.cut", [Double(piece), Double(direction), Double(depth)])
        }
    }

    /// The first cut of the certified solution of level `number`; nil when the level has none.
    static func firstCut(_ number: Int) -> FacetedForgeAction? {
        FacetedForgeExperienceCore.certifiedActions(number).first
    }

    /// Advances the play through the shell: the first cut of the certified solution of the shell's level. Returns
    /// the number of accepted actions (1 on a fresh level).
    @discardableResult
    static func advance(_ shell: Shell) throws -> Int {
        let number: Int = try core(shell).levelNumber
        let action: FacetedForgeAction = try #require(firstCut(number), "level \(number) has a certified cut")
        let issued = control(action)
        return shell.handle(control: issued.control, values: issued.values) == .accepted ? 1 : 0
    }

    /// The same as `advance` on a bare core (no host): the CPU reference of an advanced state.
    static func advanced(_ number: Int) throws -> FacetedForgeExperienceCore {
        var core: FacetedForgeExperienceCore = try FacetedForgeExperienceCore.opening(number: number)
        let action: FacetedForgeAction = try #require(firstCut(number), "level \(number) has a certified cut")
        let issued = control(action)
        let result: ActionResult = core.apply(ExperienceAction(control: issued.control, values: issued.values,
                                                               step: 0))
        #expect(result == .accepted, "level \(number) first cut: \(result.code)")
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

    /// The luminance of the ground.
    static var groundLuminance: Double { luminance(Palette.ground) }

    /// The largest per-channel difference of `a` and `b`.
    nonisolated static func channelDistance(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
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

    /// Whether some pixel within `radius` of (`px`, `py`) differs from the ground by at least `margin` in luminance.
    static func differsFromGround(_ rgba: [UInt8], near px: Double, _ py: Double, margin: Double,
                                  radius: Double = pointRadius, width: Int, height: Int) -> Bool {
        let ground: Double = groundLuminance
        let test: (SIMD3<Double>) -> Bool = { (c: SIMD3<Double>) -> Bool in
            Swift.abs(Self.luminance(c) - ground) >= margin
        }
        return anyPixel(rgba, near: px, py, radius: radius, width: width, height: height, where: test)
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
    static func camera(_ snapshot: Snapshot, width: Int, height: Int) -> FacetedForgeCamera {
        Geometry.camera(snapshot, aspect: Double(width) / Double(height))
    }

    /// The pixel of world point `point` for `snapshot` on a `width` × `height` target (nil without a projection).
    static func pixel(_ point: SIMD3<Double>, _ snapshot: Snapshot, width: Int = width,
                      height: Int = height) -> Vec2? {
        Geometry.pixel(point, camera: camera(snapshot, width: width, height: height), width: width, height: height)
    }

    /// The outward unit normal of the polygon `p` (anticlockwise seen from outside) by Newell's method; zero when
    /// degenerate.
    static func newell(_ p: [SIMD3<Double>]) -> SIMD3<Double> {
        var n: SIMD3<Double> = SIMD3<Double>(0, 0, 0)
        for i in p.indices {
            let a: SIMD3<Double> = p[i]
            let b: SIMD3<Double> = p[(i + 1) % p.count]
            n += SIMD3<Double>((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y))
        }
        let length: Double = (n * n).sum().squareRoot()
        return length > 1e-15 ? n / length : SIMD3<Double>(0, 0, 0)
    }

    /// Every cut face of `snapshot`, in piece then face order (the order of `Geometry.cutFaceCentres`): its piece, its
    /// opened centre and its outward unit normal.
    static func cutFaces(_ snapshot: Snapshot,
                         reduceMotion: Bool) -> [(piece: Int, centre: SIMD3<Double>, normal: SIMD3<Double>)] {
        let centres: [SIMD3<Double>] = Geometry.cutFaceCentres(snapshot, reduceMotion: reduceMotion)
        var result: [(piece: Int, centre: SIMD3<Double>, normal: SIMD3<Double>)] = []
        for index in snapshot.pieces.indices {
            let piece: Snapshot.Piece = snapshot.pieces[index]
            for f in piece.faces.indices where f < piece.cutFaces.count && piece.cutFaces[f] {
                var corners: [SIMD3<Double>] = []
                for corner in piece.faces[f] where piece.corners.indices.contains(corner) {
                    corners.append(piece.corners[corner])
                }
                guard !corners.isEmpty, result.count < centres.count else { continue }
                result.append((index, centres[result.count], newell(corners)))
            }
        }
        return result
    }

    /// Whether `point` lies inside the convex polygon `polygon` (either winding; on the edge counts as inside).
    static func inside(_ point: Vec2, _ polygon: [Vec2]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var positive: Bool = false
        var negative: Bool = false
        for i in polygon.indices {
            let a: Vec2 = polygon[i]
            let b: Vec2 = polygon[(i + 1) % polygon.count]
            let side: Double = (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x)
            if side > 0 { positive = true }
            if side < 0 { negative = true }
        }
        return !(positive && negative)
    }

    /// The projected outlines of the cut mark's bars of `snapshot` (each four corners; bars without a projection are
    /// left out), as `Geometry.crystalPart` builds them.
    static func markOutlines(_ snapshot: Snapshot, width: Int = width, height: Int = height) -> [[Vec2]] {
        let budget: Int = Swift.max(snapshot.budget, 0)
        guard budget > 0 else { return [] }
        let slot: Double = (Geometry.markEnd - Geometry.markStart) / Double(budget)
        let halfLength: Double = Swift.min(Geometry.markFill * slot, Geometry.markMaxWidth) / 2
        let along: SIMD3<Double> = SIMD3<Double>(halfLength, 0, 0)
        let across: SIMD3<Double> = Geometry.screenUp * Geometry.markHalfHeight
        var outlines: [[Vec2]] = []
        for bar in 0..<budget {
            let c: SIMD3<Double> = Geometry.markBarCentre(bar, budget: budget)
            let corners: [SIMD3<Double>] = [c - along - across, c + along - across, c + along + across,
                                            c - along + across]
            var outline: [Vec2] = []
            for corner in corners {
                if let p = pixel(corner, snapshot, width: width, height: height) { outline.append(p) }
            }
            if outline.count == 4 { outlines.append(outline) }
        }
        return outlines
    }

    /// The pixel positions of every piece's opened centre, every cut face's opened centre, the preview plane's centre
    /// (when there is a preview) and every cut mark bar's centre of `snapshot` (nil behind the camera), in that order.
    static func referencePixels(_ snapshot: Snapshot, reduceMotion: Bool, width: Int = width,
                                height: Int = height) -> [Vec2?] {
        var result: [Vec2?] = []
        for index in snapshot.pieces.indices {
            result.append(pixel(Geometry.pieceCentre(index, snapshot, reduceMotion: reduceMotion), snapshot,
                                width: width, height: height))
        }
        for centre in Geometry.cutFaceCentres(snapshot, reduceMotion: reduceMotion) {
            result.append(pixel(centre, snapshot, width: width, height: height))
        }
        if let preview = Geometry.previewCentre(snapshot, reduceMotion: reduceMotion) {
            result.append(pixel(preview, snapshot, width: width, height: height))
        }
        for bar in 0..<Swift.max(snapshot.budget, 0) {
            result.append(pixel(Geometry.markBarCentre(bar, budget: snapshot.budget), snapshot, width: width,
                                height: height))
        }
        return result
    }

    /// The piece check: within 3 px of every piece's opened centre some pixel differs from the ground by at least 0.1
    /// in luminance. Returns the pieces checked and the misses.
    static func pieceMisses(_ rgba: [UInt8], snapshot: Snapshot, reduceMotion: Bool, width: Int = width,
                            height: Int = height) -> (checked: Int, misses: [String]) {
        var checked: Int = 0
        var misses: [String] = []
        for index in snapshot.pieces.indices {
            let centre: SIMD3<Double> = Geometry.pieceCentre(index, snapshot, reduceMotion: reduceMotion)
            guard let p = pixel(centre, snapshot, width: width, height: height) else {
                misses.append("piece \(index): no projection")
                continue
            }
            checked += 1
            if !differsFromGround(rgba, near: p.x, p.y, margin: pieceMargin, width: width, height: height) {
                misses.append(String(format: "piece %ld at (%.1f, %.1f) is ground", index, p.x, p.y))
            }
        }
        return (checked, misses)
    }

    /// The cut-face check: within 3 px of the centre of every cut face that faces the camera some pixel has red − blue
    /// of at least 0.15. Returns the faces checked, the faces turned away (culled), the faces under a cut mark bar
    /// (skipped) and the misses.
    static func cutFaceMisses(_ rgba: [UInt8], snapshot: Snapshot, reduceMotion: Bool, width: Int = width,
                              height: Int = height) -> (checked: Int, away: Int, underMark: Int, misses: [String]) {
        let cam: FacetedForgeCamera = camera(snapshot, width: width, height: height)
        let marks: [[Vec2]] = markOutlines(snapshot, width: width, height: height)
        var checked: Int = 0
        var away: Int = 0
        var underMark: Int = 0
        var misses: [String] = []
        for face in cutFaces(snapshot, reduceMotion: reduceMotion) {
            let toEye: SIMD3<Double> = cam.eye - face.centre
            let distance: Double = (toEye * toEye).sum().squareRoot()
            let facing: Double = distance > 0 ? (face.normal * toEye).sum() / distance : 0
            guard facing > facingMinimum else {
                away += 1
                continue
            }
            guard let p = Geometry.pixel(face.centre, camera: cam, width: width, height: height) else {
                misses.append("cut face of piece \(face.piece): no projection")
                continue
            }
            var covered: Bool = false
            for outline in marks where inside(p, outline) { covered = true }
            if covered {
                underMark += 1
                continue
            }
            checked += 1
            let warmth: Double = cutWarmth
            let test: (SIMD3<Double>) -> Bool = { (c: SIMD3<Double>) -> Bool in c.x - c.z >= warmth }
            let warm: Bool = anyPixel(rgba, near: p.x, p.y, radius: pointRadius, width: width, height: height,
                                      where: test)
            if !warm {
                misses.append(String(format: "cut face of piece %ld at (%.1f, %.1f) is not warm", face.piece, p.x,
                                     p.y))
            }
        }
        return (checked, away, underMark, misses)
    }

    /// The preview check: within 3 px of the preview plane's centre some pixel differs from the ground by at least
    /// 0.05 in luminance. Returns the misses (empty when it passes, and when there is no preview).
    static func previewMisses(_ rgba: [UInt8], snapshot: Snapshot, reduceMotion: Bool, width: Int = width,
                              height: Int = height) -> [String] {
        guard let centre = Geometry.previewCentre(snapshot, reduceMotion: reduceMotion) else { return [] }
        guard let p = pixel(centre, snapshot, width: width, height: height) else { return ["preview: no projection"] }
        let found: Bool = differsFromGround(rgba, near: p.x, p.y, margin: previewMargin, width: width,
                                            height: height)
        return found ? [] : [String(format: "preview at (%.1f, %.1f) is ground", p.x, p.y)]
    }

    /// The cut mark check: within 3 px of the first bar's centre some pixel differs from the ground by at least 0.1 in
    /// luminance. Returns the misses (empty when it passes).
    static func markMisses(_ rgba: [UInt8], snapshot: Snapshot, width: Int = width, height: Int = height) -> [String] {
        guard snapshot.budget > 0 else { return ["cut mark: no budget"] }
        let centre: SIMD3<Double> = Geometry.markBarCentre(0, budget: snapshot.budget)
        guard let p = pixel(centre, snapshot, width: width, height: height) else { return ["cut mark: no projection"] }
        let found: Bool = differsFromGround(rgba, near: p.x, p.y, margin: markMargin, width: width, height: height)
        return found ? [] : [String(format: "cut mark bar 0 at (%.1f, %.1f) is ground", p.x, p.y)]
    }

    /// The background check: the pixels of the two probe corners are within 0.05 per channel of the ground. Returns
    /// the number checked and the misses.
    static func backgroundMisses(_ rgba: [UInt8], width: Int = width,
                                 height: Int = height) -> (checked: Int, misses: [String]) {
        var checked: Int = 0
        var misses: [String] = []
        for point in backgroundPoints {
            let got = pixelAtFraction(rgba, point.x, point.y, width: width, height: height)
            checked += 1
            if channelDistance(got.colour, Palette.ground) > backgroundTolerance {
                misses.append(String(format: "background (%ld, %ld): (%.3f, %.3f, %.3f)", got.x, got.y,
                                     got.colour.x, got.colour.y, got.colour.z))
            }
        }
        return (checked, misses)
    }

    /// The expected colour of the sliver cross as the crystal program lights it: the sliver colour × (ambient + diffuse
    /// · max(n · l, 0)) with the cross's normal (the eye direction) and the scene's light.
    static var litSliver: SIMD3<Double> {
        let raw: SIMD3<Float> = FacetedForgeCrystalScene.lightDirection
        let light: SIMD3<Double> = SIMD3<Double>(Double(raw.x), Double(raw.y), Double(raw.z))
        let length: Double = (light * light).sum().squareRoot()
        let dot: Double = (light * Geometry.eyeDirection).sum() / Swift.max(length, 1e-9)
        return FacetedForgeShaders.crystalShade(base: Palette.sliver, normalDotLight: dot)
    }

    /// Whether some pixel within `radius` px of the failure piece's opened centre has the sliver-cross colour (within
    /// 0.1 per channel of the lit or the plain sliver colour).
    static func sliverNear(_ rgba: [UInt8], snapshot: Snapshot, reduceMotion: Bool, radius: Double = 6,
                           width: Int = width, height: Int = height) -> Bool {
        guard let piece = snapshot.failurePiece else { return false }
        let centre: SIMD3<Double> = Geometry.pieceCentre(piece, snapshot, reduceMotion: reduceMotion)
        guard let p = pixel(centre, snapshot, width: width, height: height) else { return false }
        let lit: SIMD3<Double> = litSliver
        let plain: SIMD3<Double> = Palette.sliver
        let test: (SIMD3<Double>) -> Bool = { (c: SIMD3<Double>) -> Bool in
            Self.channelDistance(c, lit) <= 0.1 || Self.channelDistance(c, plain) <= 0.1
        }
        return anyPixel(rgba, near: p.x, p.y, radius: radius, width: width, height: height, where: test)
    }

    /// Runs the checks of clarification Q3 on `rgba` against `snapshot`, recording an issue per failure. `cutFaces`
    /// false skips the cut-face check (the unlit fallback draws without culling); `expectCutFace` requires at least one
    /// checked cut face (after a cut).
    static func checkFrame(_ rgba: [UInt8], snapshot: Snapshot, reduceMotion: Bool, width: Int = width,
                           height: Int = height, cutFaces: Bool = true, expectCutFace: Bool = false, _ what: String,
                           sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(rgba.count == width * height * 4, "\(what): picture size", sourceLocation: sourceLocation)
        guard rgba.count == width * height * 4 else { return }
        let pieces = pieceMisses(rgba, snapshot: snapshot, reduceMotion: reduceMotion, width: width, height: height)
        #expect(pieces.checked == snapshot.pieces.count, "\(what): pieces checked \(pieces.checked)",
                sourceLocation: sourceLocation)
        #expect(pieces.misses.isEmpty, "\(what): \(pieces.misses.prefix(8))", sourceLocation: sourceLocation)
        if cutFaces {
            let faces = cutFaceMisses(rgba, snapshot: snapshot, reduceMotion: reduceMotion, width: width,
                                      height: height)
            if expectCutFace {
                let note: String = "\(what): a visible cut face (away \(faces.away), under the mark "
                    + "\(faces.underMark))"
                #expect(faces.checked > 0, Comment(rawValue: note), sourceLocation: sourceLocation)
            }
            #expect(faces.misses.isEmpty, "\(what): \(faces.misses.prefix(8))", sourceLocation: sourceLocation)
        }
        let preview: [String] = previewMisses(rgba, snapshot: snapshot, reduceMotion: reduceMotion, width: width,
                                              height: height)
        #expect(preview.isEmpty, "\(what): \(preview)", sourceLocation: sourceLocation)
        let mark: [String] = markMisses(rgba, snapshot: snapshot, width: width, height: height)
        #expect(mark.isEmpty, "\(what): \(mark)", sourceLocation: sourceLocation)
        let background = backgroundMisses(rgba, width: width, height: height)
        #expect(background.checked == backgroundPoints.count, "\(what): background", sourceLocation: sourceLocation)
        #expect(background.misses.isEmpty, "\(what): \(background.misses)", sourceLocation: sourceLocation)
    }

    // MARK: Sliver search

    /// The depths at which the plane of `direction` crosses `piece`, ascending.
    static func crossingDepths(_ piece: FacetedForgePiece, direction: Int) -> [Int] {
        var depths: [Int] = []
        for depth in FacetedForgeHalfSpace.depths where piece.isCrossed(direction: direction, depth: depth) {
            depths.append(depth)
        }
        return depths
    }

    /// A cut of `core`'s play that fails it with a sliver: the pieces smallest share first, every direction, the
    /// lowest and the highest crossing depth; nil when none does.
    static func sliverCut(_ core: FacetedForgeExperienceCore) -> (action: FacetedForgeAction, piece: Int, cut: Int)? {
        let play: FacetedForgePlay = core.play
        var order: [Int] = Array(play.pieces.indices)
        order.sort { (a: Int, b: Int) -> Bool in
            play.shares[a] == play.shares[b] ? a < b : play.shares[a] < play.shares[b]
        }
        for index in order {
            for direction in FacetedForgeDirection.all.indices {
                let depths: [Int] = crossingDepths(play.pieces[index], direction: direction)
                guard let low = depths.first, let high = depths.last else { continue }
                let extremes: [Int] = low == high ? [low] : [low, high]
                for depth in extremes {
                    let action: FacetedForgeAction = .cut(index, direction, depth)
                    let issued = control(action)
                    var copy: FacetedForgeExperienceCore = core
                    guard copy.apply(ExperienceAction(control: issued.control, values: issued.values, step: 0))
                            == .accepted else { continue }
                    if case .sliver(let piece, let cut) = copy.play.failure { return (action, piece, cut) }
                }
            }
        }
        return nil
    }

    /// A deterministic search over the certified levels 1 … 100 for a play that fails with a sliver: on each level,
    /// try a sliver cut (`sliverCut`) of the current play; when none, make the level's neutral cut and try again,
    /// within the budget. Returns the level, the actions (neutral cuts, then the sliver cut), the failure's piece and
    /// cut index; nil when none is found.
    static func sliverFailure() throws -> (level: Int, actions: [FacetedForgeAction], piece: Int, cut: Int)? {
        for level in 1...100 {
            var core: FacetedForgeExperienceCore = try FacetedForgeExperienceCore.opening(number: level)
            var actions: [FacetedForgeAction] = []
            for _ in 0..<core.play.level.budget {
                guard core.play.stage == .playing else { break }
                if let found = sliverCut(core) {
                    actions.append(found.action)
                    return (level, actions, found.piece, found.cut)
                }
                guard let neutral = FacetedForgeExperienceCore.neutralCut(core.play) else { break }
                let issued = control(neutral)
                guard core.apply(ExperienceAction(control: issued.control, values: issued.values, step: 0))
                        == .accepted else { break }
                actions.append(neutral)
            }
        }
        return nil
    }
}
#endif
