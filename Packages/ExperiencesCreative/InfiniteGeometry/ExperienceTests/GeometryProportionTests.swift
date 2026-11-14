// GeometryProportionTests — feature 044 (A05-P05) T-A05-507 (FR-A05-520, FR-A05-540; SC-A05-504; spec Clarifications
// "How are proportions measured"). Regression fixture 5 on several screen shapes, through the one app's session host
// on the simulator, short runs only: views of 120 × 260, 200 × 200, 240 × 180 and 260 × 120 points (portrait
// 9:19.5, square, 4:3, landscape 19.5:9), each drawn at the default camera, then three checks within 1 pixel:
//   (a) the kaleidoscope (order 8, so its picture has the quarter turn) lies wholly inside the view and the bounding
//       box of its non-background pixels (the presenter clears to black) is square;
//   (b) each tiling: the presenter's world-to-pixel mapping (`GeometryPresenter.pixelPoint`, the one the root node,
//       the probe and the drawing use) maps a world unit in x and in y to the same number of pixels, and the drawn
//       frame's background probe, placed through the inverse mapping, reads dark on the drawn pixels;
//   (c) the 3D composition: the reference bounding sphere projected with the drawn camera at the drawn aspect has
//       equal horizontal and vertical pixel extents (measured along the camera's right and up axes through the
//       sphere centre, so both pairs lie at the centre's depth). Hosted by the VisualCore app.
import XCTest
import InfiniteGeometryCore
@testable import InfiniteGeometryExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

@MainActor
final class GeometryProportionTests: XCTestCase {
    /// The view shapes in points: portrait 9:19.5, square, 4:3 and landscape 19.5:9.
    static let views: [(width: Double, height: Double)] = [(120, 260), (200, 200), (240, 180), (260, 120)]
    /// The tolerance of every proportion check, in pixels.
    static let tolerance = 1.0
    /// A pixel counts as drawn when one channel exceeds this value (the background is black).
    static let drawnThreshold: UInt8 = 8

    private var id: ExperienceID { InfiniteGeometryExperience.id ?? ExperienceID(rawValue: "a05.unknown")! }

    private func request(made: @escaping @MainActor (any Experience) -> Void) -> ExperienceOpenRequest {
        let id = self.id
        return ExperienceOpenRequest(id: id, seed: GeometryCore.manifestSeed, snapshot: nil, refusedSnapshotFails: false) {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("ig-proportion-\(UUID().uuidString)")
            let storage = ExperienceStorage(id: id, root: root, defaults: UserDefaults(suiteName: "ig-proportion-tests")!)
            let experience = InfiniteGeometryExperience.make(id: id, storage: storage, reduceMotion: false,
                                                             reduceFlashing: false)
            made(experience)
            return experience
        }
    }

    /// A running session (full quality pinned) with the curated preset of `kind` selected.
    private func open(_ kind: GeometryPreset.Kind) async throws
        -> (ExperienceSession, any Experience, ExperienceShell<GeometryPresenter>) {
        let session = ExperienceSession()
        session.qualityPin = 0
        var made: (any Experience)?
        let opened = await session.open(request { made = $0 })
        XCTAssertEqual(opened, .running)
        let experience = try XCTUnwrap(made)
        let shell = try XCTUnwrap(experience as? ExperienceShell<GeometryPresenter>)
        let index = try XCTUnwrap(GeometryPreset.curated.firstIndex { $0.kind == kind })
        if try XCTUnwrap(shell.engine.core).presetIndex != index {
            XCTAssertTrue(experience.handle(control: "preset.select", values: [Double(index)]).isAccepted, "\(kind)")
        }
        return (session, experience, shell)
    }

    /// Lays the view out at `width` × `height` points, draws one frame and returns its pixels (bottom-up rows) and
    /// size; the presenter's mirror holds the same drawn size.
    private func draw(_ session: ExperienceSession, _ shell: ExperienceShell<GeometryPresenter>, width: Double,
                      height: Double) throws -> (pixels: [UInt8], width: Int, height: Int) {
        let host = try XCTUnwrap(session.renderHost)
        host.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
        host.view.layoutIfNeeded()
        XCTAssertTrue(host.renderOneFrame(present: false), "\(width) × \(height)")
        let size = host.pixelSize
        XCTAssertEqual(shell.presenter.mirror.canvasSize, Vec2(Double(size.width), Double(size.height)),
                       "\(width) × \(height): the drawn size")
        // The drawn size has the view's shape (the drawable is the view in pixels).
        XCTAssertEqual(Double(size.width) / Double(size.height), width / height, accuracy: 0.02, "\(width) × \(height)")
        let pixels = host.readPixels()
        XCTAssertEqual(pixels.count, size.width * size.height * 4)
        return (pixels, size.width, size.height)
    }

    // (a)
    func testTheKaleidoscopeIsSquareOnEveryViewShape() async throws {
        let (session, _, shell) = try await open(.kaleidoscope)
        defer { session.close() }
        XCTAssertEqual(try XCTUnwrap(shell.engine.core).preset.order % 4, 0, "the quarter turn is a symmetry")
        for view in Self.views {
            let frame = try draw(session, shell, width: view.width, height: view.height)
            var minX = Int.max, maxX = Int.min, minY = Int.max, maxY = Int.min
            for row in 0..<frame.height {
                for column in 0..<frame.width {
                    let i = (row * frame.width + column) * 4
                    guard max(frame.pixels[i], frame.pixels[i + 1], frame.pixels[i + 2]) > Self.drawnThreshold
                    else { continue }
                    minX = min(minX, column); maxX = max(maxX, column)
                    minY = min(minY, row); maxY = max(maxY, row)
                }
            }
            let label = "\(view.width) × \(view.height)"
            XCTAssertLessThanOrEqual(minX, maxX, "\(label): the kaleidoscope is drawn")
            guard minX <= maxX else { continue }
            // Wholly inside: a background margin on every side, so the box is not cut by the view.
            XCTAssertGreaterThan(minX, 0, label); XCTAssertLessThan(maxX, frame.width - 1, label)
            XCTAssertGreaterThan(minY, 0, label); XCTAssertLessThan(maxY, frame.height - 1, label)
            let boxWidth = Double(maxX - minX + 1), boxHeight = Double(maxY - minY + 1)
            XCTAssertEqual(boxWidth, boxHeight, accuracy: Self.tolerance, "\(label): the drawn extent is square")
            XCTAssertGreaterThan(boxWidth, Double(min(frame.width, frame.height)) / 4, "\(label): a real extent")
        }
    }

    // (b)
    func testTheTilingsScaleBothAxesEqually() async throws {
        for kind in [GeometryPreset.Kind.squareTiling, .hexTiling] {
            let (session, experience, shell) = try await open(kind)
            defer { session.close() }
            var probed = 0
            for view in Self.views {
                let label = "\(kind) \(view.width) × \(view.height)"
                let frame = try draw(session, shell, width: view.width, height: view.height)
                let core = try XCTUnwrap(shell.engine.core)
                let size = shell.presenter.mirror.canvasSize
                func pixel(_ x: Double, _ y: Double) -> Vec2 {
                    GeometryPresenter.pixelPoint(world: Vec2(x, y), size: size, view: core.view2D)
                }
                let origin = pixel(0, 0), unitX = pixel(1, 0), unitY = pixel(0, 1)
                XCTAssertEqual(abs(unitX.x - origin.x), abs(unitY.y - origin.y), accuracy: Self.tolerance,
                               "\(label): a world unit spans the same pixels in x and y")
                XCTAssertEqual(unitX.y, origin.y, accuracy: 1e-9, "\(label): x does not move y")
                XCTAssertEqual(unitY.x, origin.x, accuracy: 1e-9, "\(label): y does not move x")
                XCTAssertEqual(abs(unitX.x - origin.x), Double(min(frame.width, frame.height)) / 2,
                               accuracy: Self.tolerance, "\(label): the fit is half the shorter side")
                let back = GeometryPresenter.worldPoint(pixel: unitY, size: size, view: core.view2D)
                XCTAssertEqual(back.x, 0, accuracy: 1e-9, label)
                XCTAssertEqual(back.y, 1, accuracy: 1e-9, label)
                // The drawn frame agrees with the mapping: the probe placed through it reads the background (a view
                // the tiling covers everywhere has no probe).
                let probes = experience.frameProbes
                XCTAssertLessThanOrEqual(probes.count, 1, label)
                for probe in probes {
                    XCTAssertEqual(FrameChecks.probe(probe, rgba: frame.pixels, width: frame.width,
                                                     height: frame.height)?.rawValue, probe.expected, label)
                    probed += 1
                }
            }
            XCTAssertGreaterThanOrEqual(probed, 2, "\(kind): the non-square views have a background probe")
        }
    }

    // (c)
    func testTheSolidsBoundingSphereProjectsRound() async throws {
        let (session, _, shell) = try await open(.solid)
        defer { session.close() }
        for view in Self.views {
            let label = "\(view.width) × \(view.height)"
            let frame = try draw(session, shell, width: view.width, height: view.height)
            XCTAssertTrue(FrameChecks.isNonBlank(frame.pixels, width: frame.width, height: frame.height), label)
            let core = try XCTUnwrap(shell.engine.core)
            guard case .solid(let mesh) = try XCTUnwrap(core.composition()) else {
                return XCTFail("\(label): the 3D composition is a solid")
            }
            let size = shell.presenter.mirror.canvasSize
            let aspect = size.x / size.y
            let camera = core.orbit3D.camera
            let forward = (camera.target - camera.eye).normalized
            let right = forward.cross(Vec3(0, 1, 0)).normalized
            let up = right.cross(forward).normalized
            // The mesh's own sphere and the origin-centred sphere of the camera rule (`boundingRadius`).
            let spheres = [(try XCTUnwrap(mesh.bounds.center), try XCTUnwrap(mesh.bounds.radius)),
                           (Vec3.zero, core.boundingRadius)]
            for (centre, radius) in spheres {
                func pixel(_ p: Vec3) -> Vec2 {
                    let ndc = camera.project(p, aspect: aspect)
                    return Vec2((ndc.x + 1) / 2 * size.x, (ndc.y + 1) / 2 * size.y)
                }
                let horizontal = abs(pixel(centre + right * radius).x - pixel(centre - right * radius).x)
                let vertical = abs(pixel(centre + up * radius).y - pixel(centre - up * radius).y)
                XCTAssertEqual(horizontal, vertical, accuracy: Self.tolerance,
                               "\(label) radius \(radius): the projected sphere is round")
                XCTAssertGreaterThan(vertical, 10, "\(label): a real extent")
            }
        }
    }
}
