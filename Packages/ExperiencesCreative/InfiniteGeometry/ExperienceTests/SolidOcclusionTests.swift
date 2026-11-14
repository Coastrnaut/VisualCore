// SolidOcclusionTests — feature 042 (A05-P03) T-A05-304 (FR-A05-301–303; spec story 1, scenario 2). The 3D
// composition drawn through the presenter's `DepthMeshPass` inside the one app's session host on the simulator, short
// runs only, seen from yaw 0 and from yaw π (behind).
//
// The check: the petals are drawn in a fixed order (petal 0 first), so without depth testing the later petal wins
// wherever two petals overlap on screen — from one of the two sides that is the farther petal. For each view the CPU
// casts the ray of a pixel centre (`OrbitCamera.ray`) against the built mesh and keeps the front-facing hits (the
// faces the renderer does not cull). A probe is a pixel whose ray hits front faces of two petals (an on-screen
// overlap) where the shaded colours of the nearest front hit and of the farthest front hit on another petal differ
// clearly (≥ 0.12 in one
// channel; the light is fixed in world space and the two faces point differently) and whose four neighbours at
// ±1.5 pixels have their nearest hit on the same petal with nearly the same colour (no silhouette, no antialiased
// edge). The expected colour is the lit mesh shader evaluated on the CPU: palette colour · (ambient + (1 − ambient) ·
// max(n · light, 0)) with the interpolated vertex normal. A probe passes when the rendered pixel is closer to the
// nearest hit's colour than to the farthest hit's colour, so shading rounding cannot flip the verdict while a back
// petal painted over a front one always fails it. 12 probes per view (overlap pixels are rare at the default pitch), at least 95% (all 12) must pass, on screen and in the
// offscreen still (`RenderHost.renderOffscreen`, the export path); the still also equals the screen within 2/255 per
// channel on 95% of the probes. Pixels whose ray and neighbours miss the mesh read the dark background.
// Hosted by the VisualCore app.
import XCTest
import InfiniteGeometryCore
@testable import InfiniteGeometryExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

@MainActor
final class SolidOcclusionTests: XCTestCase {
    /// The overlap probes per view.
    static let probes = 12
    /// The background probes per view.
    static let backgroundProbes = 16
    /// The share of probes that must pass.
    static let requiredShare = 0.95
    /// The smallest per-channel difference between the nearest and the farthest hit's colours of a probe.
    static let separation = 0.12
    /// The largest per-channel difference of a neighbour's nearest colour from the probe's.
    static let smoothness = 0.04
    /// The neighbour offset in pixels.
    static let neighbourOffset = 1.5
    /// The equality tolerance of the still against the screen, in 1/255 steps.
    static let stillTolerance = 2
    /// The mesh shader's light direction and ambient fraction (`MeshRenderer` defaults).
    static let light = Vec3(0.3, 0.6, 1).normalized
    static let ambient = 0.15

    private var id: ExperienceID { InfiniteGeometryExperience.id ?? ExperienceID(rawValue: "a05.unknown")! }

    private func request(made: @escaping @MainActor (any Experience) -> Void) -> ExperienceOpenRequest {
        let id = self.id
        return ExperienceOpenRequest(id: id, seed: GeometryCore.manifestSeed, snapshot: nil, refusedSnapshotFails: false) {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("ig-solid-\(UUID().uuidString)")
            let storage = ExperienceStorage(id: id, root: root, defaults: UserDefaults(suiteName: "ig-solid-tests")!)
            let experience = InfiniteGeometryExperience.make(id: id, storage: storage, reduceMotion: false,
                                                             reduceFlashing: false)
            made(experience)
            return experience
        }
    }

    /// One drawn frame: screen and still pixels (both bottom-up rows), their size and the core drawn.
    private struct Frame {
        let screen: [UInt8]
        let still: [UInt8]
        let width: Int
        let height: Int
        let core: GeometryCore

        func rgb(_ pixels: [UInt8], column: Int, row: Int) -> Vec3 {
            let i = (row * width + column) * 4
            return Vec3(Double(pixels[i]) / 255, Double(pixels[i + 1]) / 255, Double(pixels[i + 2]) / 255)
        }
    }

    private func render(yaw: Double) async throws -> Frame {
        let session = ExperienceSession()
        var made: (any Experience)?
        let opened = await session.open(request { made = $0 })
        XCTAssertEqual(opened, .running)
        defer { session.close() }
        let view = try XCTUnwrap(session.renderHost?.view)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 320)
        view.layoutIfNeeded()
        let experience = try XCTUnwrap(made)
        let solid = try XCTUnwrap(GeometryPreset.curated.firstIndex { $0.kind == .solid })
        XCTAssertTrue(experience.handle(control: "preset.select", values: [Double(solid)]).isAccepted)
        if yaw != 0 { XCTAssertTrue(experience.handle(control: "camera.orbit", values: [yaw, 0]).isAccepted) }
        let host = try XCTUnwrap(session.renderHost)
        for _ in 0..<2 { XCTAssertTrue(host.renderOneFrame(present: false), "yaw \(yaw)") }
        let shell = try XCTUnwrap(experience as? ExperienceShell<GeometryPresenter>)
        XCTAssertGreaterThan(shell.presenter.drawnCount, 0)
        let core = try XCTUnwrap(shell.engine.core)
        XCTAssertEqual(core.orbit3D.yaw, yaw, accuracy: 1e-12)
        let size = host.pixelSize
        let screen = host.readPixels()
        XCTAssertEqual(screen.count, size.width * size.height * 4)
        let image = try host.renderOffscreen(width: size.width, height: size.height, time: 0)
        // The still is top-down; flip it to the screen's bottom-up rows.
        var still = [UInt8](repeating: 0, count: image.rgba.count)
        let rowBytes = size.width * 4
        for row in 0..<size.height {
            let source = (size.height - 1 - row) * rowBytes
            still.replaceSubrange(row * rowBytes..<(row + 1) * rowBytes, with: image.rgba[source..<source + rowBytes])
        }
        return Frame(screen: screen, still: still, width: size.width, height: size.height, core: core)
    }

    // MARK: CPU ray cast

    /// A front-facing hit: the ray parameter, the petal and the interpolated vertex normal.
    private struct Hit {
        let t: Double
        let petal: Int
        let normal: Vec3
    }

    /// The built solid as triangles grouped by petal, each group with a bounding sphere for early rejection.
    private struct Caster {
        let positions: [Vec3]
        let normals: [Vec3]
        let indices: [UInt32]
        let groups: [(range: Range<Int>, centre: Vec3, radius: Double)]

        init(mesh: Mesh, petals: Int) {
            positions = mesh.positions
            normals = mesh.normals
            indices = mesh.indices
            let perPetal = mesh.indices.count / max(petals, 1)
            groups = (0..<max(petals, 1)).map { k in
                let range = k * perPetal..<(k + 1) * perPetal
                let points = range.map { mesh.positions[Int(mesh.indices[$0])] }
                let centre = points.reduce(Vec3.zero, +) / Double(max(points.count, 1))
                let radius = points.map { ($0 - centre).length }.max() ?? 0
                return (range, centre, radius)
            }
        }

        /// The front-facing hits of the ray (`origin`, unit `direction`), nearest first.
        func frontHits(origin: Vec3, direction: Vec3) -> [Hit] {
            var hits: [Hit] = []
            for (petal, group) in groups.enumerated() {
                let oc = group.centre - origin
                let along = oc.dot(direction)
                guard (oc - direction * along).length <= group.radius + 1e-9 else { continue }
                for i in stride(from: group.range.lowerBound, to: group.range.upperBound - 2, by: 3) {
                    let ia = Int(indices[i]), ib = Int(indices[i + 1]), ic = Int(indices[i + 2])
                    let a = positions[ia], e1 = positions[ib] - a, e2 = positions[ic] - a
                    // Front-facing exactly as the renderer's back-face culling decides (counter-clockwise front).
                    guard e1.cross(e2).dot(direction) < 0 else { continue }
                    let p = direction.cross(e2)
                    let det = e1.dot(p)
                    guard abs(det) > 1e-12 else { continue }
                    let inv = 1 / det, s = origin - a
                    let u = s.dot(p) * inv
                    guard u >= 0, u <= 1 else { continue }
                    let q = s.cross(e1)
                    let v = direction.dot(q) * inv
                    guard v >= 0, u + v <= 1 else { continue }
                    let t = e2.dot(q) * inv
                    guard t > 1e-6 else { continue }
                    let n = (normals[ia] * (1 - u - v) + normals[ib] * u + normals[ic] * v).normalized
                    hits.append(Hit(t: t, petal: petal, normal: n))
                }
            }
            return hits.sorted { $0.t < $1.t }
        }
    }

    /// The mesh shader's colour for a surface of `normal` with the opaque palette colour `base`.
    private static func shade(_ base: Vec4, normal: Vec3) -> Vec3 {
        let lambert = max(normal.dot(light), 0)
        let k = ambient + (1 - ambient) * lambert
        return Vec3(base.x * k, base.y * k, base.z * k)
    }

    private static func maxDifference(_ a: Vec3, _ b: Vec3) -> Double {
        max(abs(a.x - b.x), abs(a.y - b.y), abs(a.z - b.z))
    }

    // MARK: Check

    private func check(yaw: Double) async throws {
        let frame = try await render(yaw: yaw)
        guard case .solid(let mesh) = try XCTUnwrap(frame.core.composition()) else {
            return XCTFail("the 3D composition is a solid")
        }
        let caster = Caster(mesh: mesh, petals: frame.core.preset.order)
        let camera = frame.core.orbit3D.camera
        let width = Double(frame.width), height = Double(frame.height), aspect = width / height
        let base = GeometryPresenter.color(palette: frame.core.preset.palette, index: 4)
        func hits(_ x: Double, _ y: Double) -> [Hit] {
            let ray = camera.ray(ndc: Vec2(x / width * 2 - 1, y / height * 2 - 1), aspect: aspect)
            return caster.frontHits(origin: ray.origin, direction: ray.direction)
        }
        let offsets = [(Self.neighbourOffset, 0.0), (-Self.neighbourOffset, 0.0),
                       (0.0, Self.neighbourOffset), (0.0, -Self.neighbourOffset)]
        var rng = SeededRandom(seed: 0xA05_0304 &+ UInt64(yaw > 1 ? 1 : 0))
        var screenPasses = 0, stillPasses = 0, stillEqual = 0, probes = 0, background = 0, tries = 0
        while (probes < Self.probes || background < Self.backgroundProbes), tries < 20_000 {
            tries += 1
            let column = rng.int(2...(frame.width - 3)), row = rng.int(2...(frame.height - 3))
            let x = Double(column) + 0.5, y = Double(row) + 0.5
            let centre = hits(x, y)
            if centre.isEmpty {
                guard background < Self.backgroundProbes,
                      offsets.allSatisfy({ hits(x + $0.0, y + $0.1).isEmpty }) else { continue }
                background += 1
                let c = frame.rgb(frame.screen, column: column, row: row)
                XCTAssertLessThanOrEqual(max(c.x, c.y, c.z), Double(Self.stillTolerance) / 255,
                                         "yaw \(yaw): background pixel (\(column), \(row)) is dark")
                continue
            }
            guard probes < Self.probes, let near = centre.first,
                  let far = centre.last(where: { $0.petal != near.petal }) else { continue }
            let nearColour = Self.shade(base, normal: near.normal), farColour = Self.shade(base, normal: far.normal)
            guard Self.maxDifference(nearColour, farColour) >= Self.separation else { continue }
            let smooth = offsets.allSatisfy { offset in
                guard let n = hits(x + offset.0, y + offset.1).first, n.petal == near.petal else { return false }
                return Self.maxDifference(Self.shade(base, normal: n.normal), nearColour) <= Self.smoothness
            }
            guard smooth else { continue }
            probes += 1
            let onScreen = frame.rgb(frame.screen, column: column, row: row)
            let inStill = frame.rgb(frame.still, column: column, row: row)
            if Self.maxDifference(onScreen, nearColour) < Self.maxDifference(onScreen, farColour) { screenPasses += 1 }
            if Self.maxDifference(inStill, nearColour) < Self.maxDifference(inStill, farColour) { stillPasses += 1 }
            if Self.maxDifference(onScreen, inStill) <= Double(Self.stillTolerance) / 255 + 1e-9 { stillEqual += 1 }
        }
        XCTAssertEqual(probes, Self.probes, "yaw \(yaw): enough overlap probes (\(tries) tries)")
        XCTAssertEqual(background, Self.backgroundProbes, "yaw \(yaw): enough background probes")
        let required = Int((Double(max(probes, 1)) * Self.requiredShare).rounded(.up))
        XCTAssertGreaterThanOrEqual(screenPasses, required, "yaw \(yaw): nearer petal on screen \(screenPasses)/\(probes)")
        XCTAssertGreaterThanOrEqual(stillPasses, required, "yaw \(yaw): nearer petal in the still \(stillPasses)/\(probes)")
        XCTAssertGreaterThanOrEqual(stillEqual, required, "yaw \(yaw): still equals screen \(stillEqual)/\(probes)")
    }

    func testTheNearerPetalWinsFromTheFront() async throws { try await check(yaw: 0) }

    func testTheNearerPetalWinsFromBehind() async throws { try await check(yaw: Double.pi) }
}
