// SceneMeshesTests — feature 105 (A14-P03) T-A14-308 (FR-A14-301, FR-A14-302, FR-A14-303, FR-A14-311; clarifications
// Q1–Q3; contracts/bodies.md). The CPU meshes of the 3D view, no GPU, short: the unit 48 × 24 body spheres carry their
// recipe colours; Saturn's ring is two-sided (every triangle has a twin with reversed winding, each wound with its
// normals), its radii keep the ring record's ratio and the Cassini division is darker; the 400 star directions are
// deterministic unit vectors spread over the sphere and each star's tetrahedron is small and wound outward; the star
// sphere lies at 0.9 × far, inside the depth range in both modes (StarDepthTests proves it lies beyond every body in
// both modes); the orbit
// paths have 128 points per planet in both modes (true-relative Neptune about 60 units out); the marker is a unit circle.
import Foundation
import XCTest
@testable import SolarSystemExplorerExperience
import SolarSystemExplorerCore
import VisualCoreMath
import VisualCoreScenes

final class SceneMeshesTests: XCTestCase {
    /// A text key of `p` rounded to 1e-9.
    private func key(_ p: Vec3) -> String {
        String(format: "%.9f,%.9f,%.9f", p.x, p.y, p.z)
    }

    /// The key of the triangle `a`, `b`, `c` rotated so the smallest vertex key comes first (winding kept).
    private func triangleKey(_ a: String, _ b: String, _ c: String) -> String {
        let keys: [String] = [a, b, c]
        var best = 0
        for i in 1..<3 where keys[i] < keys[best] { best = i }
        return "\(keys[best])|\(keys[(best + 1) % 3])|\(keys[(best + 2) % 3])"
    }

    func testTheBodySpheresCarryTheirRecipeColours() {
        let bodies = SceneMeshes.bodies()
        XCTAssertEqual(bodies.count, 9)
        XCTAssertEqual(SceneMeshes.unitSphere, Mesh.uvSphere(segments: 48, rings: 24, radius: 1))
        for (index, part) in bodies.enumerated() {
            XCTAssertEqual(part.mesh, SceneMeshes.unitSphere, "body \(index)")
            let recipe = SurfaceRecipe.recipe(bodyID: BodyCatalog.bundled.bodies[index].id)
            XCTAssertNotNil(recipe, "body \(index)")
            XCTAssertEqual(part.colors.count, part.mesh.positions.count)
            XCTAssertEqual(part.colors.first, recipe.map { SceneMeshes.vector($0.color(at: part.mesh.positions[0])) })
            XCTAssertEqual(SceneMeshes.markerColor(index: index), recipe.map { SceneMeshes.vector($0.primary) })
        }
        XCTAssertNotEqual(bodies[3].colors, bodies[5].colors, "Earth and Jupiter differ")
        // The tilt: Saturn's pole leans 26.73° from the scene's +y about the x axis.
        let pole = SceneMeshes.bodyTilt(index: SceneMeshes.saturnIndex).applyVector(Vec3(0, 1, 0))
        XCTAssertEqual(acos(pole.dot(Vec3(0, 1, 0))) * 180 / Double.pi, 26.73, accuracy: 1e-9)
        XCTAssertEqual(pole.x, 0, accuracy: 1e-12, "about the x axis")
    }

    func testSaturnsRingIsTwoSidedWithTheRecordsRatios() throws {
        let ring = try SceneMeshes.saturnRing()
        let mesh = ring.mesh
        XCTAssertEqual(ring.colors.count, mesh.positions.count)
        XCTAssertEqual(mesh.indices.count % 6, 0, "two equal halves of triangles")
        var keys: Set<String> = []
        var triangles: [(String, String, String)] = []
        var k = 0
        while k + 2 < mesh.indices.count {
            let ia = Int(mesh.indices[k]), ib = Int(mesh.indices[k + 1]), ic = Int(mesh.indices[k + 2])
            let a = mesh.positions[ia], b = mesh.positions[ib], c = mesh.positions[ic]
            // Each face is wound with its normals (so the face the renderer keeps is the one the normals light).
            let faceNormal = (b - a).cross(c - a)
            XCTAssertGreaterThan(faceNormal.dot(mesh.normals[ia]), 0, "triangle \(k / 3) wound with its normal")
            XCTAssertEqual(abs(mesh.normals[ia].y), 1, accuracy: 1e-9, "a flat annulus")
            let triangle = (key(a), key(b), key(c))
            triangles.append(triangle)
            keys.insert(triangleKey(triangle.0, triangle.1, triangle.2))
            k += 3
        }
        for triangle in triangles {
            XCTAssertTrue(keys.contains(triangleKey(triangle.0, triangle.2, triangle.1)),
                          "a reversed twin of \(triangle)")
        }
        // Radii in Saturn radii: the inner and outer edges keep the record's ratio, all in the x–z plane.
        var smallest = Double.infinity, largest = 0.0
        for p in mesh.positions {
            XCTAssertEqual(p.y, 0, accuracy: 1e-12)
            let r = (p.x * p.x + p.z * p.z).squareRoot()
            smallest = min(smallest, r)
            largest = max(largest, r)
        }
        let record = RingRecord.saturn
        XCTAssertEqual(smallest, record.innerKm / 58_232, accuracy: 1e-9)
        XCTAssertEqual(largest, record.outerKm / 58_232, accuracy: 1e-9)
        XCTAssertEqual(largest / smallest, record.outerKm / record.innerKm, accuracy: 1e-9)
        XCTAssertEqual(SceneMeshes.ringOuterRadius, largest, accuracy: 1e-9)
        // The Cassini division is darker than every other part of the ring.
        var darkest = Double.infinity, division = 0.0, divisionCount = 0
        for (index, p) in mesh.positions.enumerated() {
            let c = ring.colors[index]
            let luminance = 0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z
            let km = (p.x * p.x + p.z * p.z).squareRoot() * 58_232
            if record.inCassiniDivision(km) {
                division = max(division, luminance)
                divisionCount += 1
            } else {
                darkest = min(darkest, luminance)
            }
        }
        XCTAssertGreaterThan(divisionCount, 0, "vertices on the division's edges")
        XCTAssertLessThan(division, 0.5 * darkest, "the division is a darker band")
    }

    func testThe400StarDirectionsAreDeterministicUnitVectors() {
        let directions = SceneMeshes.starDirections()
        XCTAssertEqual(directions.count, 400)
        XCTAssertEqual(directions, SceneMeshes.starDirections(), "the same on every run")
        XCTAssertEqual(directions, SceneMeshes.starField)
        XCTAssertEqual(SceneMeshes.starSeed, 0xA14_57A5)
        XCTAssertNotEqual(directions, SceneMeshes.starDirections(seed: 1), "the seed fixes them")
        var mean = Vec3.zero
        var upper = 0
        for direction in directions {
            XCTAssertEqual(direction.length, 1, accuracy: 1e-12)
            mean = mean + direction / 400
            if direction.y > 0 { upper += 1 }
        }
        XCTAssertLessThan(mean.length, 0.15, "spread over the sphere")
        XCTAssertTrue(upper > 150 && upper < 250, "about half above the ecliptic: \(upper)")
        XCTAssertEqual(Set(directions.map(key)).count, 400, "no star twice")

        let mesh = SceneMeshes.starMesh()
        XCTAssertEqual(mesh.positions.count, 400 * 12)
        XCTAssertEqual(mesh.indices.count, 400 * 12)
        for star in 0..<400 {
            let center = directions[star]
            for corner in 0..<12 {
                let p = mesh.positions[star * 12 + corner]
                XCTAssertEqual((p - center).length, SceneMeshes.starSize, accuracy: 1e-12, "star \(star)")
            }
            for face in 0..<4 {
                let base = star * 12 + face * 3
                let a = mesh.positions[base], b = mesh.positions[base + 1], c = mesh.positions[base + 2]
                let centroid = (a + b + c) / 3
                XCTAssertGreaterThan((b - a).cross(c - a).dot(centroid - center), 0, "star \(star) face \(face) outward")
            }
        }
    }

    func testTheStarSphereLiesAt09FarInsideTheDepthRange() throws {
        let zooms: [Int] = [-1, 0, 12]
        for mode in ScaleMode.allCases {
            for zoom in zooms {
                let clip = mode.clipRange(distance: mode.cameraDistance(zoomSteps: zoom))
                let radius = SceneMeshes.starRadius(far: clip.far)
                XCTAssertEqual(radius, 0.9 * clip.far, accuracy: 1e-12)
                XCTAssertLessThan(radius * (1 + SceneMeshes.starSize), clip.far, "\(mode) zoom \(zoom): inside far")
                XCTAssertGreaterThan(radius, clip.near, "\(mode) zoom \(zoom): beyond near")
            }
        }
        // Enhanced: every body (and the ring around Saturn) lies nearer than the stars from every focus and zoom.
        for selection in 0..<SolarCore.bodyCount {
            for zoom in zooms {
                let state = try XCTUnwrap(SolarState(selection: selection, dayOffset: 0, yawSteps: 0, pitchDegrees: 35,
                                                     zoomSteps: zoom))
                let camera = OrbitLayout.camera(state: state)
                let radius = SceneMeshes.starRadius(far: camera.far)
                for index in 0..<SolarCore.bodyCount {
                    let center = OrbitLayout.scenePosition(index: index, day: 0)
                    let extent = max(OrbitLayout.displayRadius(index: index),
                                     index == SceneMeshes.saturnIndex ? OrbitLayout.saturnRingRadius(mode: .enhanced)
                                                                      : 0)
                    XCTAssertLessThan((center - camera.eye).length + extent, radius,
                                      "focus \(selection) zoom \(zoom) body \(index)")
                }
            }
        }
    }

    func testOrbitPathsHave128PointsPerPlanetInBothModes() throws {
        for mode in ScaleMode.allCases {
            let paths = SceneMeshes.orbitPaths(mode: mode)
            XCTAssertEqual(paths.count, 8, "\(mode)")
            for (offset, path) in paths.enumerated() {
                XCTAssertEqual(path.count, 128, "\(mode) planet \(offset + 1)")
                for point in path { XCTAssertTrue(point.isFinite) }
            }
            for id in OrbitLayout.orbitBodyIDs {
                XCTAssertGreaterThan(try SceneMeshes.orbitMesh(bodyID: id, mode: mode).triangleCount, 0, id)
            }
        }
        XCTAssertEqual(SceneMeshes.orbitPaths(mode: .enhanced)[2], OrbitLayout.orbitPath(bodyID: "earth"))
        var neptune = 0.0
        for point in SceneMeshes.orbitPaths(mode: .trueRelative)[7] { neptune = max(neptune, point.length) }
        XCTAssertEqual(neptune, 60, accuracy: 1.5, "true-relative Neptune about 60 units out")
        var earth = 0.0
        for point in SceneMeshes.orbitPaths(mode: .trueRelative)[2] { earth = max(earth, point.length) }
        XCTAssertEqual(earth, 2 * 1.0167, accuracy: 0.01, "Earth's aphelion at 2 units per AU")
    }

    func testTheMarkerIsAUnitCircleInTheXYPlane() throws {
        let marker = try SceneMeshes.markerMesh()
        XCTAssertGreaterThan(marker.triangleCount, 0)
        for p in marker.positions {
            let r = (p.x * p.x + p.y * p.y).squareRoot()
            XCTAssertEqual(r, 1, accuracy: SceneMeshes.markerTubeRadius + 1e-9)
            XCTAssertEqual(p.z, 0, accuracy: SceneMeshes.markerTubeRadius + 1e-9)
        }
    }
}
