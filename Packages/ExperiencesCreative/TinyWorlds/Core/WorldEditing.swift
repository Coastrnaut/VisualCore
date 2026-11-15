// WorldEditing — feature 091 (A12-P03) T-A12-302 (FR-A12-302, FR-A12-303; clarification Q2; research D2; data-model
// "PlacedProp"; contracts/actions.md; G-PROPS). Placing, selecting, moving, rotating and deleting props as pure
// functions over a `WorldState` (the `prop.*` actions), and picking a prop with a ray.
//
// Rules for a prop's centre (x, z), checked in this order by `validate`, each refusal with its code:
// - `a12.outside`: |x| or |z| above 5.5 m;
// - `a12.under-water`: the ground there below 0.05 m (island, miniature city: at least 0.05 m above sea level 0) or
//   below −0.4 m (asteroid garden: on the disc);
// - `a12.too-close`: closer than 0.6 m (in x–z) to the centre of another prop (the moved prop itself is ignored).
// The ground height is the height of the drawn terrain (the level-0 `HeightField` of the state's preset and seed,
// `TerrainGenerator.heightField(preset:seed:)`, triangulated as `HeightField.mesh` does: each cell split along its
// diagonal from (i, j) to (i + 1, j + 1)), so a placed prop's base rests on the triangles that are drawn; y is set to
// it. Values are stored with −0 normalised to 0, so the JSON round trip is bit-identical.
//
// Actions (each returns nil on success, else the refusal; a refusal changes nothing):
// - `place(kind:x:z:)`: `a12.invalid-choice` for a kind outside 0…3 or a non-finite coordinate, then `a12.prop-cap`
//   with 24 props already placed, then the rules; adds the prop (rotation 0, scale 1) at the end and selects it;
// - `select(_:)`: −1 clears the selection, a prop index selects it; anything else is `a12.invalid-choice`;
// - `move(dx:dz:)`: `a12.no-selection`, then `a12.invalid-choice` for a step outside −1…1 m, then the rules at the
//   moved centre; keeps the rotation and scale;
// - `rotate(degrees:)`: `a12.no-selection`, then `a12.invalid-choice` for a step outside −180…180; the rotation (in
//   radians) is wrapped into −π…π;
// - `delete()`: `a12.no-selection`; removes the selected prop and clears the selection.
// Every function takes an optional height field; pass the state's own (from `groundField(of:)`) to avoid rebuilding
// it. Replaying the same actions on the same state gives the same state.
//
// `pick(ray:props:)` returns the nearest prop whose picking box (`PropCatalog` bounds, moved by the prop's transform)
// the ray meets, with the distance along the ray; the caller compares it with the ground hit (`GroundPick`).
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// Why an editing action was refused; the raw values are the spoken refusal codes.
public enum WorldEditRefusal: String, CaseIterable, Codable, Error, Sendable {
    /// 24 props are already placed.
    case propCap = "a12.prop-cap"
    /// The centre lies outside |x|, |z| ≤ 5.5 m.
    case outside = "a12.outside"
    /// The ground under the centre is below the preset's lowest allowed height.
    case underWater = "a12.under-water"
    /// The centre is closer than 0.6 m to another prop's centre.
    case tooClose = "a12.too-close"
    /// No prop is selected.
    case noSelection = "a12.no-selection"
    /// A kind, index, step or coordinate outside its range, or non-finite.
    case invalidChoice = "a12.invalid-choice"
}

/// A placed prop: its kind and transform (position of its base centre, rotation about y, scale).
public struct PlacedProp: Codable, Equatable, Sendable {
    /// The kind.
    public var kind: PropKind
    /// Base centre x in metres.
    public var x: Double
    /// Base centre y in metres (the terrain height under the centre).
    public var y: Double
    /// Base centre z in metres.
    public var z: Double
    /// Rotation about +y in radians, −π…π.
    public var rotation: Double
    /// Uniform scale (1 in this phase).
    public var scale: Double

    /// Creates a placed prop (no validation; `WorldEditing` places props by its rules).
    public init(kind: PropKind, x: Double, y: Double, z: Double, rotation: Double = 0, scale: Double = 1) {
        self.kind = kind; self.x = x; self.y = y; self.z = z; self.rotation = rotation; self.scale = scale
    }

    /// True when every value is finite, |x| and |z| ≤ 5.5 m, y within `WorldPreset.heightRange`, the rotation in
    /// −π…π and the scale 1.
    public var isValid: Bool {
        [x, y, z, rotation, scale].allSatisfy(\.isFinite) && abs(x) <= WorldEditing.halfExtent
            && abs(z) <= WorldEditing.halfExtent && WorldPreset.heightRange.contains(y)
            && rotation >= -Double.pi && rotation <= Double.pi && scale == 1
    }

    /// The model matrix (column-major): scale, then rotation about +y, then translation to (x, y, z). A local point
    /// (lx, ly, lz) goes to (x + s(lx cos r + lz sin r), y + s · ly, z + s(−lx sin r + lz cos r)).
    public var modelMatrix: Mat4 {
        let c = cos(rotation) * scale, s = sin(rotation) * scale
        return Mat4(Vec4(c, 0, -s, 0), Vec4(0, scale, 0, 0), Vec4(s, 0, c, 0), Vec4(x, y, z, 1))
    }

    /// `point` in world space moved into the prop's local space (the inverse of ``modelMatrix``).
    public func localPoint(_ point: Vec3) -> Vec3 {
        localDirection(Vec3(point.x - x, point.y - y, point.z - z))
    }

    /// `direction` in world space turned (and scaled) into the prop's local space.
    public func localDirection(_ d: Vec3) -> Vec3 {
        let c = cos(rotation), s = sin(rotation)
        return Vec3((d.x * c - d.z * s) / scale, d.y / scale, (d.x * s + d.z * c) / scale)
    }

    private enum CodingKeys: String, CodingKey { case kind, rotation, scale, x, y, z }
}

/// The editing actions of Tiny Worlds (see the file header).
public enum WorldEditing {
    /// The most props a world holds.
    public static let maxProps = 24
    /// The largest |x| and |z| of a prop's centre in metres.
    public static let halfExtent = 5.5
    /// The least distance between two props' centres in metres (x–z).
    public static let minSpacing = 0.6
    /// The allowed move step in metres, for x and for z.
    public static let moveStepRange: ClosedRange<Double> = -1...1
    /// The allowed rotation step in degrees.
    public static let rotateStepRange: ClosedRange<Double> = -180...180

    /// The lowest ground a prop may stand on for `preset`: 0.05 m (island, miniature city) or −0.4 m (asteroid
    /// garden).
    public static func minimumGround(_ preset: WorldPreset) -> Double {
        preset.id == .asteroidGarden ? -0.4 : 0.05
    }

    /// The level-0 height field of `state`'s preset and seed, or nil when it is refused (never for the presets).
    public static func groundField(of state: WorldState) -> HeightField? {
        try? TerrainGenerator.heightField(preset: state.preset, seed: state.seed)
    }

    /// The height of the drawn terrain of `field` at (x, z): the triangle of `HeightField.mesh` over that point
    /// (cells split along the diagonal from (i, j) to (i + 1, j + 1)), interpolated linearly. Points outside the grid
    /// are clamped to its edge.
    public static func groundHeight(field: HeightField, x: Double, z: Double) -> Double {
        func cell(_ value: Double, _ origin: Double, _ count: Int) -> (Int, Double) {
            var u = (value - origin) / field.cellSize
            if u.isNaN { u = 0 }
            u = min(max(u, 0), Double(count))
            let index = min(Int(u.rounded(.down)), count - 1)
            return (index, u - Double(index))
        }
        let (i, s) = cell(x, field.originX, field.columns), (j, t) = cell(z, field.originZ, field.rows)
        let h00 = field.height(column: i, row: j), h10 = field.height(column: i + 1, row: j)
        let h01 = field.height(column: i, row: j + 1), h11 = field.height(column: i + 1, row: j + 1)
        if s >= t { return h00 + s * (h10 - h00) + t * (h11 - h10) }
        return h00 + t * (h01 - h00) + s * (h11 - h01)
    }

    /// The ground height at (x, z) if a prop may stand there in `state` (the rules of the file header, ignoring the
    /// prop at index `ignoring`), else the refusal.
    public static func validate(x: Double, z: Double, in state: WorldState, ignoring: Int? = nil,
                                field: HeightField? = nil) -> Result<Double, WorldEditRefusal> {
        guard x.isFinite, z.isFinite else { return .failure(.invalidChoice) }
        guard abs(x) <= halfExtent, abs(z) <= halfExtent else { return .failure(.outside) }
        guard let field = field ?? groundField(of: state) else { return .failure(.underWater) }
        let ground = groundHeight(field: field, x: x, z: z)
        guard ground >= minimumGround(state.preset) else { return .failure(.underWater) }
        for (index, other) in state.props.enumerated() where index != ignoring {
            let dx = other.x - x, dz = other.z - z
            if dx * dx + dz * dz < minSpacing * minSpacing { return .failure(.tooClose) }
        }
        return .success(ground + 0)
    }

    /// Places a prop of `kind` (0…3) at (x, z) and selects it; nil on success, else the refusal (see the file header).
    @discardableResult
    public static func place(kind: Int, x: Double, z: Double, in state: inout WorldState,
                             field: HeightField? = nil) -> WorldEditRefusal? {
        guard let kind = PropKind(rawValue: kind), x.isFinite, z.isFinite else { return .invalidChoice }
        guard state.props.count < maxProps else { return .propCap }
        switch validate(x: x, z: z, in: state, field: field) {
        case .failure(let refusal): return refusal
        case .success(let ground):
            state.props.append(PlacedProp(kind: kind, x: x + 0, y: ground, z: z + 0))
            state.selection = state.props.count - 1
            return nil
        }
    }

    /// Selects prop `index`, or clears the selection for −1; nil on success, else `a12.invalid-choice`.
    @discardableResult
    public static func select(_ index: Int, in state: inout WorldState) -> WorldEditRefusal? {
        guard index == WorldState.noSelection || state.props.indices.contains(index) else { return .invalidChoice }
        state.selection = index
        return nil
    }

    /// Moves the selected prop by (dx, dz) metres (each −1…1); nil on success, else the refusal.
    @discardableResult
    public static func move(dx: Double, dz: Double, in state: inout WorldState,
                            field: HeightField? = nil) -> WorldEditRefusal? {
        guard let prop = state.selectedProp else { return .noSelection }
        guard moveStepRange.contains(dx), moveStepRange.contains(dz) else { return .invalidChoice }
        let x = prop.x + dx, z = prop.z + dz
        switch validate(x: x, z: z, in: state, ignoring: state.selection, field: field) {
        case .failure(let refusal): return refusal
        case .success(let ground):
            state.props[state.selection].x = x + 0
            state.props[state.selection].z = z + 0
            state.props[state.selection].y = ground
            return nil
        }
    }

    /// Turns the selected prop by `degrees` (−180…180) about +y, wrapping into −π…π; nil on success, else the
    /// refusal.
    @discardableResult
    public static func rotate(degrees: Double, in state: inout WorldState) -> WorldEditRefusal? {
        guard let prop = state.selectedProp else { return .noSelection }
        guard rotateStepRange.contains(degrees) else { return .invalidChoice }
        state.props[state.selection].rotation = WorldView.wrap(prop.rotation + degrees * WorldView.radiansPerDegree) + 0
        return nil
    }

    /// Deletes the selected prop and clears the selection; nil on success, else `a12.no-selection`.
    @discardableResult
    public static func delete(in state: inout WorldState) -> WorldEditRefusal? {
        guard state.selectedProp != nil else { return .noSelection }
        state.props.remove(at: state.selection)
        state.selection = WorldState.noSelection
        return nil
    }

    /// The nearest of `props` whose picking box `ray` meets, with the distance along the ray (0 when the ray starts
    /// inside a box); nil when it meets none. Ties keep the lower index.
    public static func pick(ray: Ray3, props: [PlacedProp]) -> (index: Int, distance: Double)? {
        var best: (index: Int, distance: Double)?
        for (index, prop) in props.enumerated() {
            let model = PropCatalog.model(prop.kind)
            guard let local = Ray3(origin: prop.localPoint(ray.origin), direction: prop.localDirection(ray.direction)),
                  let hit = local.intersect(boxMin: model.boxMin, boxMax: model.boxMax) else { continue }
            let distance = hit.distance * prop.scale
            if best == nil || distance < best!.distance { best = (index, distance) }
        }
        return best
    }
}
