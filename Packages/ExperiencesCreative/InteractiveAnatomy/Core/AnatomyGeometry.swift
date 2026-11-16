// AnatomyGeometry — feature 125 (A17-P02) T-A17-202 (FR-A17-201; clarification Q2; data-model "MeshPlacement";
// contracts/scene.md). The fixed schematic geometry of the right knee: one placement per declared mesh id, each built
// from its kind with VisualCore's procedural generators and placed by its own model matrix. No asset of any kind.
//
// Convention (the region's): centimetres; +Y superior, +Z anterior, +X lateral (right knee); the joint line at y ≈ 0;
// every mesh inside the region bounds (−7…7, −15…15, −7…7). Model matrices hold only rotations and translations, so
// the renderer's `mat3(model) · normal` keeps normals true; flattened spheres (the patella) are baked as ellipsoids
// with true normals instead of being scaled by the matrix.
//
// Shapes, by kind (every one closed):
// - revolution (femoral condyles): a two-lobed profile about the local Y axis with a pole at each end, turned so the
//   axis lies along X at y = 2.2; the lobes (radius 2.0 at x = ±1.6) are the condyles, the waist (1.5) the notch;
// - tube (shafts, ligaments, tendons): a capped circle swept along a fixed path;
// - extrusion (plateau, cartilage, menisci): a capped outline; the flat pads are outlines in the (x, z) plane turned
//   +90° about X, so the extrusion depth runs vertically (outline (x, a) at depth d → world (x, −d, a));
// - sphere (tuberosity, fibular head, patella): a UV sphere, the patella baked into an ellipsoid.
// Stacking at the joint line, bottom to top: tibial plateau top −0.6; tibial cartilage −0.6…−0.3; menisci
// −0.35…0.0 on the cartilage rims; femoral cartilage pad 0.0…0.25 (two lobes joined at the front, the cruciate
// ligaments passing between them); condyles from 0.2. The trochlear groove cartilage is a plate in front of the
// condyles (z 1.825…2.075), wider than the patella in front of it.
//
// Triangles per level (level 0 / level 1): tubes 2n(m − 1) + 2n for n sides and m path points; spheres
// 2 · segments · (rings − 1); the revolution 2 · segments · (points − 2); extrusions 2n + 2(n − 2) for n outline
// points. The whole knee is 6,444 / 2,716 triangles, far inside 60,000 / 20,000.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The fixed procedural shape of one mesh, before its model matrix.
public enum AnatomyShape: Equatable, Sendable {
    /// A profile (x = radius ≥ 0, y = height) revolved about the Y axis; the segments come from the quality level.
    case revolution(profile: [Vec2])
    /// A capped tube of `radius` along `path`; the sides come from the quality level.
    case tube(path: [Vec3], radius: Double)
    /// A capped extrusion of an XY `outline` along z over `depth`.
    case extrusion(outline: [Vec2], depth: Double)
    /// A UV sphere with semi-axes `radii` (an ellipsoid with true normals when they differ); segments and rings come
    /// from the quality level.
    case sphere(radii: Vec3)
}

/// Where and how one declared mesh is built: its id, kind, shape and model matrix.
public struct MeshPlacement: Equatable, Sendable {
    /// The declared mesh id, `mesh.<structure>.<part>`.
    public let meshID: String
    /// The declared procedural kind.
    public let kind: ProceduralMeshDeclaration.Kind
    /// The fixed shape parameters.
    public let shape: AnatomyShape
    /// The model matrix (rotation and translation only) from mesh space to region space.
    public let model: Mat4

    /// Creates a placement.
    public init(meshID: String, kind: ProceduralMeshDeclaration.Kind, shape: AnatomyShape, model: Mat4) {
        self.meshID = meshID
        self.kind = kind
        self.shape = shape
        self.model = model
    }
}

/// The schematic geometry of the bundled right knee (see the file header).
public enum AnatomyGeometry {
    /// The placement of `meshID`, or nil when the id has none.
    public static func placement(for meshID: String) -> MeshPlacement? {
        placementsByID[meshID]
    }

    /// Every placement, in the order of the bundled region's mesh declarations.
    public static let placements: [MeshPlacement] = makePlacements()

    /// Builds the mesh of `placement` at `quality`, within the level's mesh budget.
    ///
    /// - Throws: the generator's `MeshError` (`.budget` or `.invalidInput`).
    public static func build(_ placement: MeshPlacement, quality: AnatomyQuality) throws(MeshError) -> Mesh {
        let budget = quality.meshBudget
        switch placement.shape {
        case let .revolution(profile):
            return try Mesh.revolution(profile: profile, segments: quality.segments, budget: budget)
        case let .tube(path, radius):
            return try Mesh.tube(path: path, radius: radius, sides: quality.tubeSides, caps: true, closed: false,
                                 budget: budget)
        case let .extrusion(outline, depth):
            return try Mesh.extrusion(outline: outline, depth: depth, caps: true, budget: budget)
        case let .sphere(radii):
            let mesh = ellipsoid(radii: radii, segments: quality.sphereSegments, rings: quality.sphereRings)
            if mesh.positions.count > budget.maxVertices || mesh.indices.count > budget.maxIndices {
                throw .budget(vertices: mesh.positions.count, indices: mesh.indices.count, budget: budget)
            }
            return mesh
        }
    }

    // MARK: - Shapes

    /// A UV sphere of radius 1 with its positions scaled by `radii` and its normals by their inverse, renormalised.
    static func ellipsoid(radii: Vec3, segments: Int, rings: Int) -> Mesh {
        var mesh = Mesh.uvSphere(segments: segments, rings: rings, radius: 1)
        mesh.positions = mesh.positions.map { Vec3($0.x * radii.x, $0.y * radii.y, $0.z * radii.z) }
        mesh.normals = mesh.normals.map { Vec3($0.x / radii.x, $0.y / radii.y, $0.z / radii.z).normalized }
        return mesh
    }

    /// The two-lobed condyle profile from pole (0, −3) to pole (0, 3): radius 2.0 at the lobes (±1.6), 1.5 at the
    /// waist (0), falling as a quarter ellipse to each pole.
    static func condyleProfile() -> [Vec2] {
        let half = 3.0, lobe = 1.6, lobeRadius = 2.0, waist = 1.5
        var points: [Vec2] = []
        let count = 24
        for k in 0...count {
            let h = -half + 2 * half * Double(k) / Double(count)
            let a = abs(h)
            let r: Double
            if k == 0 || k == count {
                r = 0
            } else if a >= lobe {
                let u = (a - lobe) / (half - lobe)
                r = lobeRadius * (max(0, 1 - u * u)).squareRoot()
            } else {
                r = waist + (lobeRadius - waist) * (1 - cos(.pi * a / lobe)) / 2
            }
            points.append(Vec2(r, h))
        }
        return points
    }

    /// `count` points of the ellipse with semi-axes `rx`, `ry` about `center`, counter-clockwise.
    static func ellipse(center: Vec2, rx: Double, ry: Double, count: Int) -> [Vec2] {
        (0..<count).map { k in
            let t = 2 * Double.pi * Double(k) / Double(count)
            return Vec2(center.x + rx * cos(t), center.y + ry * sin(t))
        }
    }

    /// A crescent about `center`: the outer elliptic arc from `from` to `to` (radians, counter-clockwise) and the inner
    /// arc back, `count` points on each arc.
    static func crescent(center: Vec2, outer: Vec2, inner: Vec2, from: Double, to: Double, count: Int) -> [Vec2] {
        var points: [Vec2] = []
        for k in 0..<count {
            let t = from + (to - from) * Double(k) / Double(count - 1)
            points.append(Vec2(center.x + outer.x * cos(t), center.y + outer.y * sin(t)))
        }
        for k in 0..<count {
            let t = to - (to - from) * Double(k) / Double(count - 1)
            points.append(Vec2(center.x + inner.x * cos(t), center.y + inner.y * sin(t)))
        }
        return points
    }

    // MARK: - Placements

    /// Degrees to radians.
    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }

    /// A pad lying flat: +90° about X (outline (x, a) at depth d → (x, −d, a)), then moved by `offset`.
    private static func flat(_ offset: Vec3) -> Mat4 {
        Mat4.translation(offset) * Mat4.rotation(Quat(axis: Vec3(1, 0, 0), angle: radians(90)))
    }

    /// The placements by mesh id.
    private static let placementsByID: [String: MeshPlacement] =
        Dictionary(placements.map { ($0.meshID, $0) }, uniquingKeysWith: { first, _ in first })

    /// The 20 placements of the right knee.
    private static func makePlacements() -> [MeshPlacement] {
        let identity = Mat4.identity
        func tube(_ id: String, _ path: [Vec3], _ radius: Double) -> MeshPlacement {
            MeshPlacement(meshID: id, kind: .tube, shape: .tube(path: path, radius: radius), model: identity)
        }
        func sphere(_ id: String, _ radii: Vec3, at center: Vec3) -> MeshPlacement {
            MeshPlacement(meshID: id, kind: .sphere, shape: .sphere(radii: radii), model: .translation(center))
        }
        func pad(_ id: String, _ outline: [Vec2], depth: Double, at offset: Vec3) -> MeshPlacement {
            MeshPlacement(meshID: id, kind: .extrusion, shape: .extrusion(outline: outline, depth: depth),
                          model: flat(offset))
        }
        // The condyles: the profile's axis (local +Y) turned onto world +X (−90° about Z), centred at y 2.2, z −0.2.
        let condyles = MeshPlacement(
            meshID: "mesh.femur.condyles", kind: .revolution, shape: .revolution(profile: condyleProfile()),
            model: Mat4.translation(Vec3(0, 2.2, -0.2)) * Mat4.rotation(Quat(axis: Vec3(0, 0, 1), angle: radians(-90))))
        // The femoral cartilage pad: two lobes (medial x −2.6…−0.8, lateral 0.8…2.6, z −1.8…1.4) joined at the front.
        let femoralPad: [Vec2] = [
            Vec2(-2.6, -1.8), Vec2(-0.8, -1.8), Vec2(-0.8, 0.9), Vec2(0.8, 0.9), Vec2(0.8, -1.8), Vec2(2.6, -1.8),
            Vec2(2.6, 1.4), Vec2(-2.6, 1.4),
        ]
        // The trochlear groove cartilage: a plate in the (x, y) plane, extruded along z in front of the condyles.
        let groove: [Vec2] = [
            Vec2(-2.4, 1.6), Vec2(-1.2, 1.1), Vec2(1.2, 1.1), Vec2(2.4, 1.6), Vec2(2.2, 3.8), Vec2(-2.2, 3.8),
        ]
        return [
            tube("mesh.femur.shaft", [Vec3(0, 14.5, -0.2), Vec3(0, 9, -0.2), Vec3(0, 3.4, -0.2)], 1.4),
            condyles,
            pad("mesh.tibia.plateau", ellipse(center: .zero, rx: 3.5, ry: 2.5, count: 28), depth: 1.2,
                at: Vec3(0, -1.2, 0)),
            tube("mesh.tibia.shaft", [Vec3(0, -1.4, -0.2), Vec3(0, -8, -0.2), Vec3(0, -14.5, -0.2)], 1.5),
            sphere("mesh.tibia.tuberosity", Vec3(0.8, 0.8, 0.8), at: Vec3(0, -3.0, 1.9)),
            sphere("mesh.fibula.head", Vec3(0.9, 0.9, 0.9), at: Vec3(3.4, -2.7, -1.2)),
            tube("mesh.fibula.shaft", [Vec3(3.4, -3.2, -1.2), Vec3(3.5, -9, -1.3), Vec3(3.6, -14.5, -1.4)], 0.55),
            sphere("mesh.patella.body", Vec3(1.6, 1.9, 0.8), at: Vec3(0, 2.6, 3.0)),
            pad("mesh.femoral-cartilage.condyles", femoralPad, depth: 0.25, at: Vec3(0, 0.125, 0)),
            MeshPlacement(meshID: "mesh.femoral-cartilage.groove", kind: .extrusion,
                          shape: .extrusion(outline: groove, depth: 0.25), model: .translation(Vec3(0, 0, 1.95))),
            pad("mesh.tibial-cartilage.medial", ellipse(center: Vec2(-1.6, 0), rx: 1.15, ry: 1.45, count: 20),
                depth: 0.3, at: Vec3(0, -0.45, 0)),
            pad("mesh.tibial-cartilage.lateral", ellipse(center: Vec2(1.6, 0), rx: 1.05, ry: 1.25, count: 20),
                depth: 0.3, at: Vec3(0, -0.45, 0)),
            pad("mesh.medial-meniscus.body",
                crescent(center: Vec2(-1.6, 0), outer: Vec2(1.55, 1.85), inner: Vec2(1.0, 1.25),
                         from: radians(50), to: radians(310), count: 14),
                depth: 0.35, at: Vec3(0, -0.175, 0)),
            pad("mesh.lateral-meniscus.body",
                crescent(center: Vec2(1.6, 0), outer: Vec2(1.4, 1.6), inner: Vec2(0.85, 1.05),
                         from: radians(-155), to: radians(155), count: 14),
                depth: 0.35, at: Vec3(0, -0.175, 0)),
            tube("mesh.acl.band", [Vec3(-0.3, -0.55, 0.7), Vec3(0.9, 1.6, -0.8)], 0.35),
            tube("mesh.pcl.band", [Vec3(0, -0.7, -1.9), Vec3(-0.7, 1.6, 0.3)], 0.4),
            tube("mesh.mcl.band",
                 [Vec3(-3.2, 3.6, -0.4), Vec3(-3.75, -0.2, -0.6), Vec3(-3.5, -2.0, -0.5), Vec3(-2.0, -5.0, -0.3)], 0.3),
            tube("mesh.lcl.band", [Vec3(3.3, 3.0, -0.6), Vec3(3.75, 0.5, -0.9), Vec3(3.6, -1.9, -1.2)], 0.3),
            tube("mesh.patellar-ligament.band", [Vec3(0, 1.0, 3.2), Vec3(0, -1.0, 2.9), Vec3(0, -3.0, 2.5)], 0.45),
            tube("mesh.quadriceps-tendon.band", [Vec3(0, 4.2, 3.0), Vec3(0, 7, 2.4), Vec3(0, 9.5, 1.9)], 0.55),
        ]
    }
}
