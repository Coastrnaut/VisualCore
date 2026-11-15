// SceneMeshes — feature 105 (A14-P03) T-A14-308 (FR-A14-301, FR-A14-302, FR-A14-303, FR-A14-311; clarifications
// Q1–Q3; research D1–D3; data-model "Starfield"; contracts/bodies.md). The CPU geometry of Solar System Explorer's 3D
// view, made once per presenter and kept across context recreations (no GPU, no state of its own):
//   - Bodies: one `Mesh.uvSphere(segments: 48, rings: 24)` of unit radius per body, coloured per vertex by the body's
//     `SurfaceRecipe` (the recipe evaluates each vertex's unit direction, so the seam and pole vertices match). The
//     presenter scales each sphere to the scale mode's drawn radius and tilts it by the body's catalog axial tilt about
//     the scene x axis with the model matrix (``bodyTilt(index:)``), so Saturn's bands share the plane of its rings.
//   - Saturn's ring: a flat annulus from `Mesh.revolution` (64 segments) in the x–z plane (Saturn's equatorial plane
//     before the tilt) from the C ring's inner edge to the A ring's outer edge (`RingRecord.saturn`), in units of
//     Saturn's mean radius (km ÷ the catalog's 58,232 km), so the presenter scales it with Saturn's drawn radius in
//     both scale modes. Per-vertex colours by radius: pale tan brightening from 0.75 at the inner edge to 1 at the
//     Cassini division, the division itself dark (``cassiniColor``), the A ring at 0.9. Extra profile points just
//     outside the division's edges (``ringEdgeInset``) keep the band crisp. Because the mesh renderer always culls back
//     faces, a copy with reversed winding and flipped normals is appended, so both faces draw. The ring is tilted with
//     Saturn by its catalog axial tilt (26.73°) about the scene x axis; the pole's azimuth is not modelled (stated
//     approximation, clarification Q2).
//   - Orbit paths: 128 samples per planet for each scale mode (``OrbitLayout/orbitPath(bodyID:mode:)``), drawn as
//     closed tubes of ``OrbitLayout/orbitTubeRadius(mode:)``.
//   - Starfield: 400 directions seeded 0xA14_57A5 (SplitMix64, two 53-bit uniforms each, z = 2u − 1 and
//     φ = 2πv, so the directions are uniform on the sphere), each a small regular tetrahedron whose vertices lie
//     ``starSize`` (0.004) from its point on the unit sphere (flat normals, outward winding). The presenter centres
//     the mesh on the eye and scales it to ``starRadius(far:)`` = 0.9 × the active far plane.
//   - Marker ring: a closed `Mesh.tube` circle of radius 1 in the x–y plane (normal +z); the presenter turns it to
//     face the camera and scales it to the marker's pixel radius.
//   - Detail levels (feature 107, A14-P05, T-A14-504; FR-A14-510; clarification Q5): ``DetailLevel/levels`` lists two,
//     `level-0` (spheres 48 × 24, 400 stars, orbits of 128 samples, all of the above) and `level-1` (spheres 24 × 12
//     with the same recipe colours per vertex, the first 200 of the 400 star directions, orbits of 64 samples, every
//     second point of level 0's). Saturn's ring, the selection rings and the marker ring are shared by both levels. A
//     level changes only the meshes, never a position.
import Foundation
import SolarSystemExplorerCore
import VisualCoreMath
import VisualCoreScenes

/// The CPU meshes of the 3D view: bodies, Saturn's ring, orbit tubes, the starfield and the marker ring.
enum SceneMeshes {
    // MARK: Bodies

    /// Longitude segments of each body sphere (48).
    static let sphereSegments = 48
    /// Latitude rings of each body sphere (24).
    static let sphereRings = 24

    /// The unit sphere every body is drawn from at detail level 0 (48 × 24, radius 1).
    static let unitSphere: Mesh = Mesh.uvSphere(segments: sphereSegments, rings: sphereRings, radius: 1)
    /// Longitude segments of each body sphere at detail level 1 (24).
    static let lowSphereSegments = 24
    /// Latitude rings of each body sphere at detail level 1 (12).
    static let lowSphereRings = 12
    /// The unit sphere every body is drawn from at detail level 1 (24 × 12, radius 1).
    static let lowUnitSphere: Mesh = Mesh.uvSphere(segments: lowSphereSegments, rings: lowSphereRings, radius: 1)

    /// The surface recipe of the catalog body at `index` (nil outside the catalog or without a recipe).
    static func recipe(index: Int) -> SurfaceRecipe? {
        guard let body = SolarCore.catalog.body(at: index) else { return nil }
        return SurfaceRecipe.recipe(bodyID: body.id)
    }

    /// `color` as an RGBA vector.
    static func vector(_ color: SurfaceColor) -> Vec4 { Vec4(color.r, color.g, color.b, color.a) }

    /// The per-vertex colours of `mesh` for the body at `index` from its surface recipe (mid grey without one).
    static func bodyColors(index: Int, mesh: Mesh) -> [Vec4] {
        guard let recipe = recipe(index: index) else {
            return [Vec4](repeating: Vec4(0.5, 0.5, 0.5, 1), count: mesh.positions.count)
        }
        return recipe.colors(for: mesh.positions).map(vector)
    }

    /// The nine unit body spheres (`sphere`, by default level 0's 48 × 24) in catalog order with their recipe
    /// colours per vertex.
    static func bodies(sphere: Mesh = unitSphere) -> [(mesh: Mesh, colors: [Vec4])] {
        var parts: [(mesh: Mesh, colors: [Vec4])] = []
        for index in 0..<SolarCore.bodyCount {
            parts.append((sphere, bodyColors(index: index, mesh: sphere)))
        }
        return parts
    }

    /// The body's colour for markers: its recipe's primary colour (grey without a recipe).
    static func markerColor(index: Int) -> Vec4 {
        guard let recipe = recipe(index: index) else { return Vec4(0.6, 0.6, 0.6, 1) }
        return vector(recipe.primary)
    }

    /// The catalog axial tilt of the body at `index`, radians (0 outside the catalog).
    static func axialTilt(index: Int) -> Double {
        (SolarCore.catalog.body(at: index)?.axialTiltDegrees ?? 0) * Double.pi / 180
    }

    /// The rotation by the body's axial tilt about the scene x axis (its pole leans toward −z from +y).
    static func bodyTilt(index: Int) -> Mat4 {
        Mat4.rotation(Quat(axis: Vec3(1, 0, 0), angle: axialTilt(index: index)))
    }

    // MARK: Saturn's ring

    /// The catalog index of Saturn.
    static let saturnIndex: Int = SolarCore.catalog.bodies.firstIndex { $0.id == RingRecord.saturn.bodyID } ?? 6
    /// Saturn's mean radius, km (the catalog's), the ring mesh's unit.
    static let saturnRadiusKm: Double = SolarCore.catalog.body(at: saturnIndex)?.meanRadiusKm ?? 58_232
    /// The angular segments of the ring annulus (64).
    static let ringSegments = 64
    /// The ring's light colour (pale tan).
    static let ringLight = Vec4(0.86, 0.78, 0.62, 1)
    /// The Cassini division's colour (dark).
    static let cassiniColor = Vec4(0.16, 0.14, 0.12, 1)
    /// The ring's ambient light fraction (0.7, clarification Q2).
    static let ringAmbient = 0.7
    /// The distance, km, of the extra profile points outside the Cassini division's edges (keeps the band crisp).
    static let ringEdgeInset = 100.0

    /// The profile radii of the annulus in km, inner to outer: the inner edge, the midpoint to the division, the
    /// division's edges with a point ``ringEdgeInset`` outside each, and the outer edge.
    static func ringProfileKm(_ record: RingRecord = .saturn) -> [Double] {
        [record.innerKm, (record.innerKm + record.cassiniInnerKm) / 2, record.cassiniInnerKm - ringEdgeInset,
         record.cassiniInnerKm, record.cassiniOuterKm, record.cassiniOuterKm + ringEdgeInset, record.outerKm]
    }

    /// The ring colour at `radiusKm` from Saturn's centre: dark in the Cassini division; pale tan × (0.75 … 1) from
    /// the inner edge to the division; × 0.9 beyond it (the A ring).
    static func ringColor(radiusKm: Double, record: RingRecord = .saturn) -> Vec4 {
        if record.inCassiniDivision(radiusKm) { return cassiniColor }
        let factor: Double
        if radiusKm < record.cassiniInnerKm {
            let t = min(max((radiusKm - record.innerKm) / (record.cassiniInnerKm - record.innerKm), 0), 1)
            factor = 0.75 + 0.25 * t
        } else {
            factor = 0.9
        }
        return Vec4(ringLight.x * factor, ringLight.y * factor, ringLight.z * factor, 1)
    }

    /// Saturn's two-sided ring in Saturn radii (x–z plane, centred on the origin) with its per-vertex colours: the
    /// annulus from `Mesh.revolution` and a copy with reversed winding and flipped normals.
    static func saturnRing(_ record: RingRecord = .saturn) throws -> (mesh: Mesh, colors: [Vec4]) {
        let profile = ringProfileKm(record).map { Vec2($0 / saturnRadiusKm, 0) }
        let face = try Mesh.revolution(profile: profile, segments: ringSegments)
        var mesh = face
        let count = UInt32(face.positions.count)
        mesh.positions += face.positions
        mesh.normals += face.normals.map { Vec3(-$0.x, -$0.y, -$0.z) }
        mesh.uvs += face.uvs
        var k = 0
        while k + 2 < face.indices.count {
            mesh.indices += [face.indices[k] + count, face.indices[k + 2] + count, face.indices[k + 1] + count]
            k += 3
        }
        var colors: [Vec4] = []
        colors.reserveCapacity(mesh.positions.count)
        for p in mesh.positions {
            let radiusKm = (p.x * p.x + p.z * p.z).squareRoot() * saturnRadiusKm
            colors.append(ringColor(radiusKm: radiusKm, record: record))
        }
        return (mesh, colors)
    }

    /// The ring's outer radius in Saturn radii (A ring outer edge ÷ Saturn's radius, about 2.35).
    static var ringOuterRadius: Double { RingRecord.saturn.outerKm / saturnRadiusKm }

    // MARK: Orbits

    /// The orbit paths of ``OrbitLayout/orbitBodyIDs`` in `mode` (`samples` scene points each, 128 by default).
    static func orbitPaths(mode: ScaleMode, samples: Int = OrbitLayout.orbitSamples) -> [[Vec3]] {
        OrbitLayout.orbitBodyIDs.map { OrbitLayout.orbitPath(bodyID: $0, mode: mode, samples: samples) }
    }

    /// The orbit tube of `bodyID` in `mode`: a closed `Mesh.tube` of ``OrbitLayout/orbitTubeRadius(mode:)`` and
    /// ``SolarPresenter/orbitSides`` sides along its path of `samples` points (128 by default).
    static func orbitMesh(bodyID: String, mode: ScaleMode, samples: Int = OrbitLayout.orbitSamples) throws -> Mesh {
        try Mesh.tube(path: OrbitLayout.orbitPath(bodyID: bodyID, mode: mode, samples: samples),
                      radius: OrbitLayout.orbitTubeRadius(mode: mode), sides: SolarPresenter.orbitSides, caps: false,
                      closed: true)
    }

    // MARK: Starfield

    /// The number of stars at detail level 0 (400).
    static let starCount = 400
    /// The number of stars at detail level 1 (200, the first 200 of level 0's directions).
    static let lowStarCount = 200
    /// The starfield seed (0xA14_57A5).
    static let starSeed: UInt64 = 0xA14_57A5
    /// The distance of each star's tetrahedron vertices from its point on the unit sphere (0.004).
    static let starSize = 0.004
    /// The star sphere's radius as a fraction of the far plane (0.9).
    static let starRadiusFactor = 0.9
    /// The stars' colour (white).
    static let starColor = Vec4(1, 1, 1, 1)

    /// The star sphere's radius for the far plane `far`: 0.9 × far.
    static func starRadius(far: Double) -> Double { starRadiusFactor * far }

    /// The SplitMix64 sequence from `seed`: each call advances the state by the golden gamma and mixes it.
    struct SplitMix64 {
        /// The generator state.
        var state: UInt64

        /// The next 64-bit output.
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }

        /// The next uniform number in 0 ..< 1 (53 bits).
        mutating func unit() -> Double { Double(next() >> 11) / Double(UInt64(1) << 53) }
    }

    /// The 400 star directions (unit vectors, uniform on the sphere), identical on every run.
    static func starDirections(seed: UInt64 = starSeed, count: Int = starCount) -> [Vec3] {
        var generator = SplitMix64(state: seed)
        var result: [Vec3] = []
        result.reserveCapacity(count)
        for _ in 0..<count {
            let z = 2 * generator.unit() - 1
            let phi = 2 * Double.pi * generator.unit()
            let ring = max(0, 1 - z * z).squareRoot()
            result.append(Vec3(ring * cos(phi), z, ring * sin(phi)))
        }
        return result
    }

    /// The 400 star directions of ``starSeed``, made once.
    static let starField: [Vec3] = starDirections()
    /// The star directions of detail level 1: the first ``lowStarCount`` (200) of ``starField``, so its sky is a
    /// subset of level 0's.
    static let lowStarField: [Vec3] = Array(starField.prefix(lowStarCount))

    /// The starfield on the unit sphere: one regular tetrahedron per direction (4 faces, 3 vertices each with the
    /// face's normal, wound outward).
    static func starMesh(directions: [Vec3] = starField) -> Mesh {
        let corners: [Vec3] = [Vec3(1, 1, 1).normalized, Vec3(1, -1, -1).normalized, Vec3(-1, 1, -1).normalized,
                               Vec3(-1, -1, 1).normalized]
        let faces: [(Int, Int, Int, Int)] = [(0, 1, 2, 3), (0, 1, 3, 2), (0, 2, 3, 1), (1, 2, 3, 0)]
        var mesh = Mesh.plane()
        mesh.positions = []; mesh.normals = []; mesh.uvs = []; mesh.indices = []
        mesh.positions.reserveCapacity(directions.count * 12)
        for direction in directions {
            let vertices = corners.map { direction + $0 * starSize }
            for (i, j, k, opposite) in faces {
                let a = vertices[i]
                var b = vertices[j], c = vertices[k]
                var normal = (b - a).cross(c - a)
                if normal.dot(a - vertices[opposite]) < 0 {
                    swap(&b, &c)
                    normal = (b - a).cross(c - a)
                }
                let n = normal.length > 0 ? normal.normalized : direction
                let base = UInt32(mesh.positions.count)
                mesh.positions += [a, b, c]
                mesh.normals += [n, n, n]
                mesh.uvs += [Vec2(0, 0), Vec2(1, 0), Vec2(0, 1)]
                mesh.indices += [base, base + 1, base + 2]
            }
        }
        return mesh
    }

    // MARK: Detail levels

    /// One detail level of the 3D view (feature 107, clarification Q5): the body sphere's segments and rings, the
    /// number of stars and the samples of each orbit path.
    struct DetailLevel: Equatable, Sendable {
        /// The level's name in the registration and the quality profile (`level-0`, `level-1`).
        let name: String
        /// Longitude segments of each body sphere.
        let sphereSegments: Int
        /// Latitude rings of each body sphere.
        let sphereRings: Int
        /// The number of stars drawn (a prefix of ``SceneMeshes/starField``).
        let starCount: Int
        /// The samples of each orbit path.
        let orbitSamples: Int

        /// The two levels, the full one first: `level-0` (48 × 24, 400 stars, 128 samples) and `level-1` (24 × 12,
        /// 200 stars, 64 samples).
        static let levels: [DetailLevel] = [
            DetailLevel(name: "level-0", sphereSegments: SceneMeshes.sphereSegments,
                        sphereRings: SceneMeshes.sphereRings, starCount: SceneMeshes.starCount,
                        orbitSamples: OrbitLayout.orbitSamples),
            DetailLevel(name: "level-1", sphereSegments: SceneMeshes.lowSphereSegments,
                        sphereRings: SceneMeshes.lowSphereRings, starCount: SceneMeshes.lowStarCount,
                        orbitSamples: OrbitLayout.lowOrbitSamples)
        ]

        /// The index of the level drawn for the host's `tier`: clamped to 0 … levels − 1 (above 1 draws level 1,
        /// below 0 draws level 0).
        static func index(tier: Int) -> Int { min(max(tier, 0), levels.count - 1) }
    }

    // MARK: Markers

    /// The points of the marker circle (48).
    static let markerPoints = 48
    /// The marker tube's radius relative to the circle's radius (0.12).
    static let markerTubeRadius = 0.12
    /// The sides of the marker tube (6).
    static let markerSides = 6

    /// The marker ring: a closed tube along the unit circle in the x–y plane (normal +z), centred on the origin.
    static func markerMesh() throws -> Mesh {
        var path: [Vec3] = []
        for i in 0..<markerPoints {
            let angle = 2 * Double.pi * Double(i) / Double(markerPoints)
            path.append(Vec3(cos(angle), sin(angle), 0))
        }
        return try Mesh.tube(path: path, radius: markerTubeRadius, sides: markerSides, caps: false, closed: true)
    }
}
