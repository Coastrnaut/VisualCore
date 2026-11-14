// KaleidoscopeRenderTests — feature 041 (A05-P02) T-A05-205 (FR-A05-201, FR-A05-202; SC-A05-201; spec Clarifications).
// The kaleidoscope drawn by its full-screen shader inside the one app's session host on the simulator, short runs
// only: for orders 1, 3, 6 and 12 the frame is read back and 64 sampled points are compared with their group images
// — the rotation by 2π/n and the mirror image about the fold axis (θ → −θ) — mapped to pixels with the presenter's
// fit (the square −1…1 on the shorter side, default camera). At least 95% of the pairs must match within 2/255 per
// channel. Excluded, as rounding cannot be avoided there: points within 1 pixel of a mirror line (spec), and points
// whose point or image lies within 1.5 pixels of a polygon edge (the image of a pixel centre is not a pixel centre, so
// an antialiased edge pixel differs by up to one pixel of coverage). Half of the points are drawn inside motif images
// so the comparison covers coloured pixels, not only the background. At order 1 there are mirror pairs only, and the
// half-turn is not a symmetry (no extra copies). Hosted by the VisualCore app.
import XCTest
import InfiniteGeometryCore
@testable import InfiniteGeometryExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreSimulation

@MainActor
final class KaleidoscopeRenderTests: XCTestCase {
    /// The sampled points per order (SC-A05-201).
    static let samples = 64
    /// The share of pairs that must match.
    static let requiredShare = 0.95
    /// The largest per-channel difference of a match, in 1/255 steps.
    static let tolerance = 2
    /// Points this close to a mirror line are skipped, in pixels (spec).
    static let mirrorMargin = 1.0
    /// Points or images this close to a polygon edge are skipped, in pixels.
    static let edgeMargin = 1.5

    private var id: ExperienceID { InfiniteGeometryExperience.id ?? ExperienceID(rawValue: "a05.unknown")! }

    private func request(made: @escaping @MainActor (any Experience) -> Void) -> ExperienceOpenRequest {
        let id = self.id
        return ExperienceOpenRequest(id: id, seed: GeometryCore.manifestSeed, snapshot: nil, refusedSnapshotFails: false) {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("ig-kaleido-\(UUID().uuidString)")
            let storage = ExperienceStorage(id: id, root: root, defaults: UserDefaults(suiteName: "ig-kaleido-tests")!)
            let experience = InfiniteGeometryExperience.make(id: id, storage: storage, reduceMotion: false,
                                                             reduceFlashing: false)
            made(experience)
            return experience
        }
    }

    /// One frame of the kaleidoscope at `order`: the pixels (bottom-up rows), their size and the core drawn.
    private struct Frame {
        let pixels: [UInt8]
        let width: Int
        let height: Int
        let core: GeometryCore

        /// The fit in pixels per world unit (default camera).
        var fit: Double { Double(min(width, height)) / 2 }

        /// The pixel position (x from the left, y from the bottom) of world point `p`.
        func pixel(_ p: Vec2) -> Vec2 { Vec2(Double(width) / 2 + p.x * fit, Double(height) / 2 + p.y * fit) }

        /// The world point of the centre of pixel (`column`, `row`), row 0 at the bottom.
        func world(column: Int, row: Int) -> Vec2 {
            Vec2((Double(column) + 0.5 - Double(width) / 2) / fit, (Double(row) + 0.5 - Double(height) / 2) / fit)
        }

        /// The RGB of the pixel containing world point `p`, or nil outside the frame.
        func rgb(_ p: Vec2) -> [Int]? {
            let q = pixel(p)
            let column = Int(q.x.rounded(.down)), row = Int(q.y.rounded(.down))
            guard (0..<width).contains(column), (0..<height).contains(row) else { return nil }
            let index = (row * width + column) * 4
            return [Int(pixels[index]), Int(pixels[index + 1]), Int(pixels[index + 2])]
        }
    }

    private func render(order: Int) async throws -> Frame {
        let session = ExperienceSession()
        var made: (any Experience)?
        let opened = await session.open(request { made = $0 })
        XCTAssertEqual(opened, .running)
        defer { session.close() }
        let view = try XCTUnwrap(session.renderHost?.view)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 320)
        view.layoutIfNeeded()
        let experience = try XCTUnwrap(made)
        let kaleidoscope = try XCTUnwrap(GeometryPreset.curated.firstIndex { $0.kind == .kaleidoscope })
        XCTAssertTrue(experience.handle(control: "preset.select", values: [Double(kaleidoscope)]).isAccepted)
        XCTAssertTrue(experience.handle(control: "symmetry.order", values: [Double(order)]).isAccepted, "order \(order)")
        let host = try XCTUnwrap(session.renderHost)
        for _ in 0..<2 { XCTAssertTrue(host.renderOneFrame(present: false), "order \(order)") }
        let shell = try XCTUnwrap(experience as? ExperienceShell<GeometryPresenter>)
        XCTAssertGreaterThan(shell.presenter.drawnCount, 0)
        let core = try XCTUnwrap(shell.engine.core)
        XCTAssertEqual(core.preset.order, order)
        XCTAssertLessThanOrEqual(core.preset.scale, 1, "every image is kept at scale ≤ 1")
        let size = host.pixelSize
        let pixels = host.readPixels()
        XCTAssertEqual(pixels.count, size.width * size.height * 4)
        return Frame(pixels: pixels, width: size.width, height: size.height, core: core)
    }

    /// The distance from `p` to the segment `a`–`b`.
    private static func distance(_ p: Vec2, _ a: Vec2, _ b: Vec2) -> Double {
        let ab = b - a
        let lengthSquared = ab.dot(ab)
        guard lengthSquared > 0 else { return p.distance(to: a) }
        let t = min(max((p - a).dot(ab) / lengthSquared, 0), 1)
        return p.distance(to: a + ab * t)
    }

    /// The distance from `p` to the nearest mirror line of the dihedral group of `order` (lines at angles kπ/n).
    private static func mirrorDistance(_ p: Vec2, order: Int) -> Double {
        (0..<order).map { k -> Double in
            let a = Double.pi * Double(k) / Double(order)
            return abs(-sin(a) * p.x + cos(a) * p.y)
        }.min() ?? .infinity
    }

    private static func rotate(_ p: Vec2, by angle: Double) -> Vec2 {
        let c = cos(angle), s = sin(angle)
        return Vec2(c * p.x - s * p.y, s * p.x + c * p.y)
    }

    private static func matches(_ a: [Int], _ b: [Int]) -> Bool {
        zip(a, b).allSatisfy { abs($0 - $1) <= tolerance }
    }

    private static func isDark(_ c: [Int]) -> Bool { c.allSatisfy { $0 <= tolerance } }

    /// Samples `samples` points that pass the exclusions and counts the matching rotation and mirror pairs, and at
    /// order 1 the half-turn mismatches among coloured points.
    private func check(order: Int) async throws {
        let frame = try await render(order: order)
        guard case .plane(let polygons) = try XCTUnwrap(frame.core.composition()) else {
            return XCTFail("the kaleidoscope is a plane")
        }
        let pixel = 1 / frame.fit
        func nearEdge(_ p: Vec2) -> Bool {
            polygons.contains { polygon in
                polygon.points.indices.contains { k in
                    Self.distance(p, polygon.points[k], polygon.points[(k + 1) % polygon.points.count])
                        < Self.edgeMargin * pixel
                }
            }
        }
        var rng = SeededRandom(seed: 0xA05_0201 &+ UInt64(order))
        var rotationMatches = 0, mirrorMatches = 0, coloured = 0, halfTurnMismatches = 0, accepted = 0
        var tries = 0
        while accepted < Self.samples, tries < 20_000 {
            tries += 1
            // Even tries: inside a random motif image; odd tries: anywhere in the disc of radius 0.95.
            var target: Vec2
            if tries % 2 == 0, let polygon = polygons.randomElement(using: &rng) {
                let weights = polygon.points.map { _ in rng.range(0.05...1) }
                let total = weights.reduce(0, +)
                target = zip(polygon.points, weights).reduce(Vec2.zero) { $0 + $1.0 * ($1.1 / total) }
            } else {
                let r = 0.95 * rng.range(0...1).squareRoot(), a = rng.range(0...(2 * Double.pi))
                target = Vec2(r * cos(a), r * sin(a))
            }
            // Snap the point to its pixel centre.
            let q = frame.pixel(target)
            let p = frame.world(column: Int(q.x.rounded(.down)), row: Int(q.y.rounded(.down)))
            guard p.length <= 0.95, Self.mirrorDistance(p, order: order) >= Self.mirrorMargin * pixel else { continue }
            let rotated = Self.rotate(p, by: 2 * Double.pi / Double(order))
            let mirrored = Vec2(p.x, -p.y)
            let halfTurn = Vec2(-p.x, -p.y)
            guard ![p, rotated, mirrored].contains(where: nearEdge) else { continue }
            guard let c = frame.rgb(p), let cr = frame.rgb(rotated), let cm = frame.rgb(mirrored) else { continue }
            accepted += 1
            if Self.matches(c, cr) { rotationMatches += 1 }
            if Self.matches(c, cm) { mirrorMatches += 1 }
            if !Self.isDark(c) {
                coloured += 1
                if order == 1, !nearEdge(halfTurn), let ch = frame.rgb(halfTurn), !Self.matches(c, ch) {
                    halfTurnMismatches += 1
                }
            }
        }
        XCTAssertEqual(accepted, Self.samples, "order \(order): enough points pass the exclusions")
        let required = Int((Double(Self.samples) * Self.requiredShare).rounded(.up))
        XCTAssertGreaterThanOrEqual(coloured, Self.samples / 4, "order \(order): coloured points are compared")
        XCTAssertGreaterThanOrEqual(mirrorMatches, required, "order \(order): mirror pairs \(mirrorMatches)/\(accepted)")
        if order > 1 {
            XCTAssertGreaterThanOrEqual(rotationMatches, required,
                                        "order \(order): rotation pairs \(rotationMatches)/\(accepted)")
        } else {
            // Order 1: the motif and its mirror only — the half-turn is not a symmetry.
            XCTAssertGreaterThan(halfTurnMismatches, 0, "order 1 draws no extra copies")
        }
    }

    func testOrderOneIsTheMotifAndItsMirror() async throws { try await check(order: 1) }

    func testOrderThreeIsSymmetric() async throws { try await check(order: 3) }

    func testOrderSixIsSymmetric() async throws { try await check(order: 6) }

    func testOrderTwelveIsSymmetric() async throws { try await check(order: 12) }

    /// The shader's uniform values come from the core: order, repetitions, scale, motif, centroid and 2D camera.
    func testShaderParametersFollowTheCore() throws {
        var core = try GeometryCore(seed: 7)
        let kaleidoscope = try XCTUnwrap(GeometryPreset.curated.firstIndex { $0.kind == .kaleidoscope })
        XCTAssertEqual(core.apply(ExperienceAction(control: "preset.select", values: [Double(kaleidoscope)], step: 0)),
                       .accepted)
        XCTAssertEqual(core.apply(ExperienceAction(control: "camera.pan", values: [0.25, -0.125], step: 0)), .accepted)
        XCTAssertEqual(core.apply(ExperienceAction(control: "camera.zoom", values: [2], step: 0)), .accepted)
        let values = KaleidoscopeShader.parameters(for: core)
        let motif = KaleidoscopeShader.motifPoints(core.preset)
        XCTAssertTrue((3...7).contains(motif.count))
        XCTAssertEqual(values["order"], Double(core.preset.order))
        XCTAssertEqual(values["repeats"], Double(core.preset.repeats))
        XCTAssertEqual(values["scale"], core.preset.scale)
        XCTAssertEqual(values["count"], Double(motif.count))
        XCTAssertEqual(values["p0x"], motif[0].x)
        XCTAssertEqual(values["p6y"], motif.count == 7 ? motif[6].y : 0)
        XCTAssertEqual(values["centerX"], 0.25)
        XCTAssertEqual(values["centerY"], -0.125)
        XCTAssertEqual(values["zoom"], 2)
        XCTAssertEqual(KaleidoscopeShader.palette(core.preset.palette).count, 6)
        XCTAssertTrue(KaleidoscopeShader.fragment.contains("#include \"vc/sdf.glsl\""))
    }
}
