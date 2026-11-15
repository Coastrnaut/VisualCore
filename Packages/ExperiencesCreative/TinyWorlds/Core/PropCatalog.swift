// PropCatalog — feature 091 (A12-P03) T-A12-302 (FR-A12-301; clarification Q1; research D1; data-model "PlacedProp";
// G-PROPS). The four procedural props of Tiny Worlds, each one mesh in its own local space (metres, y up, its base
// centred on the origin at y = 0) built from VisualCore's mesh shapes and drawn with a per-vertex colour stream from
// the prop's three-colour palette (`ContentCatalog.propPalettes`, indices 0 base, 1 main, 2 accent):
//
// - tree (kind 0): a revolved trunk (radius 0.08 → 0.07 m, 0…0.45 m, base colour) and two revolved cones, the lower
//   crown (radius 0.42 m, 0.35…0.85 m, main colour) and the upper crown (radius 0.32 m, 0.68…1.18 m, accent colour);
// - rock (kind 1): a bevelled box 0.70 × 0.42 × 0.56 m with 0.16 m bevels (3 segments); vertices whose normal points
//   up (y > 0.6) take the accent (moss), down (y < −0.6) the base, the rest the main colour;
// - house (kind 2): walls as a bevelled box 0.60 × 0.45 × 0.50 m (0.02 m bevels, base colour), a gabled roof as the
//   triangle (−0.38, 0.45), (0.38, 0.45), (0, 0.80) extruded 0.62 m along z with caps (main colour), and a door
//   0.14 × 0.24 × 0.02 m on the +z wall (accent colour);
// - lantern (kind 3): a revolved post with a foot (radius 0.10 → 0.035 m, 0…0.90 m, base colour), a lamp sphere of
//   radius 0.12 m centred at 1.00 m (12 segments, 8 rings, accent colour) and a revolved cap cone (radius 0.14 m,
//   1.10…1.19 m, main colour).
//
// The parts are merged into one mesh (vertex arrays concatenated in the order above, indices offset); no two parts
// share a position, so the merged mesh validates like its parts. Every prop stays within 2,000 vertices and 1.2 m of
// height. Its picking box is its mesh bounds in local space. Generation is pure and deterministic; the bundled models
// are built once (`PropCatalog.model(_:)`).
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The four prop kinds, by index (the `prop.place` action's kind).
public enum PropKind: Int, CaseIterable, Codable, Sendable {
    /// A tree: trunk and two crown cones.
    case tree = 0
    /// A rounded rock.
    case rock = 1
    /// A little house with a gabled roof and a door.
    case house = 2
    /// A lantern: post, lamp and cap.
    case lantern = 3

    /// The content id (kebab-case), equal to the prop record's and the prop palette's id.
    public var contentId: String {
        switch self {
        case .tree: "tree"
        case .rock: "rock"
        case .house: "house"
        case .lantern: "lantern"
        }
    }

    /// The display name.
    public var name: String {
        switch self {
        case .tree: "Tree"
        case .rock: "Rock"
        case .house: "House"
        case .lantern: "Lantern"
        }
    }
}

/// One prop's drawable model in local space: the mesh, one colour per vertex and the picking box.
public struct PropModel: Equatable, Sendable {
    /// The kind.
    public var kind: PropKind
    /// The merged mesh, base centred on the origin at y = 0.
    public var mesh: Mesh
    /// One RGBA colour per vertex of ``mesh``.
    public var colors: [Vec4]
    /// The picking box's lower corner (the mesh bounds) in local space.
    public var boxMin: Vec3
    /// The picking box's upper corner (the mesh bounds) in local space.
    public var boxMax: Vec3

    /// The model's height above its base in metres.
    public var height: Double { boxMax.y }
}

/// Builds the props' models.
public enum PropCatalog {
    /// The most vertices a prop may have.
    public static let maxVertices = 2_000
    /// The greatest height of a prop in metres.
    public static let maxHeight = 1.2
    /// The index of the base colour in a prop palette.
    public static let baseIndex = 0
    /// The index of the main colour in a prop palette.
    public static let mainIndex = 1
    /// The index of the accent colour in a prop palette.
    public static let accentIndex = 2

    /// The bundled models in kind order, built once from `ContentCatalog.bundled`.
    private static let bundledModels: [PropModel] = PropKind.allCases.map { build($0, catalog: .bundled) }

    /// The bundled model of `kind`.
    public static func model(_ kind: PropKind) -> PropModel { bundledModels[kind.rawValue] }

    /// The model of `kind` with colours from `catalog`'s prop palette of the same id (mid grey when it is missing).
    public static func build(_ kind: PropKind, catalog: ContentCatalog) -> PropModel {
        let palette = catalog.propPalette(id: kind.contentId)
        func color(_ index: Int) -> Vec4 {
            guard let palette, palette.colors.indices.contains(index) else { return Vec4(0.5, 0.5, 0.5, 1) }
            let c = palette.colors[index]
            return Vec4(c.r, c.g, c.b, c.a)
        }
        var mesh = MeshBuilder().build()
        var colors: [Vec4] = []
        // Appends `part` moved by `offset`, each vertex coloured by `paint(position, normal)` (a palette index).
        func add(_ part: Mesh?, offset: Vec3 = Vec3(0, 0, 0), paint: (Vec3, Vec3) -> Int) {
            guard let part else { return }
            let base = UInt32(mesh.positions.count)
            for (p, n) in zip(part.positions, part.normals) {
                mesh.positions.append(p + offset)
                colors.append(color(paint(p + offset, n)))
            }
            mesh.normals += part.normals
            mesh.uvs += part.uvs
            mesh.indices += part.indices.map { $0 + base }
        }
        func uniform(_ index: Int) -> (Vec3, Vec3) -> Int { { _, _ in index } }
        switch kind {
        case .tree:
            add(try? Mesh.revolution(profile: [Vec2(0, 0), Vec2(0.08, 0), Vec2(0.07, 0.45), Vec2(0, 0.45)],
                                     segments: 12), paint: uniform(baseIndex))
            add(try? Mesh.revolution(profile: [Vec2(0, 0.35), Vec2(0.42, 0.35), Vec2(0, 0.85)], segments: 16),
                paint: uniform(mainIndex))
            add(try? Mesh.revolution(profile: [Vec2(0, 0.68), Vec2(0.32, 0.68), Vec2(0, 1.18)], segments: 16),
                paint: uniform(accentIndex))
        case .rock:
            add(try? Mesh.bevelledBox(size: Vec3(0.70, 0.42, 0.56), radius: 0.16, segments: 3),
                offset: Vec3(0, 0.21, 0)) { _, n in
                n.y > 0.6 ? accentIndex : (n.y < -0.6 ? baseIndex : mainIndex)
            }
        case .house:
            add(try? Mesh.bevelledBox(size: Vec3(0.60, 0.45, 0.50), radius: 0.02, segments: 1),
                offset: Vec3(0, 0.225, 0), paint: uniform(baseIndex))
            add(try? Mesh.extrusion(outline: [Vec2(-0.38, 0.45), Vec2(0.38, 0.45), Vec2(0, 0.80)], depth: 0.62,
                                    caps: true), paint: uniform(mainIndex))
            add(try? Mesh.bevelledBox(size: Vec3(0.14, 0.24, 0.02), radius: 0, segments: 1),
                offset: Vec3(0, 0.12, 0.26), paint: uniform(accentIndex))
        case .lantern:
            add(try? Mesh.revolution(profile: [Vec2(0, 0), Vec2(0.10, 0), Vec2(0.10, 0.06), Vec2(0.035, 0.09),
                                               Vec2(0.035, 0.90), Vec2(0, 0.90)], segments: 12),
                paint: uniform(baseIndex))
            add(Mesh.uvSphere(segments: 12, rings: 8, radius: 0.12), offset: Vec3(0, 1.0, 0),
                paint: uniform(accentIndex))
            add(try? Mesh.revolution(profile: [Vec2(0, 1.10), Vec2(0.14, 1.10), Vec2(0, 1.19)], segments: 12),
                paint: uniform(mainIndex))
        }
        let box: (Vec3, Vec3)
        if case let .box(lo, hi) = mesh.bounds { box = (lo, hi) } else { box = (Vec3(0, 0, 0), Vec3(0, 0, 0)) }
        return PropModel(kind: kind, mesh: mesh, colors: colors, boxMin: box.0, boxMax: box.1)
    }
}
