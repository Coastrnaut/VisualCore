// WorldEditingTests — feature 091 (A12-P03) T-A12-302 (FR-A12-302, FR-A12-303; clarification Q2; research D2;
// SC-A12-301). The editing actions, host-free and short: placed props rest within 1 mm of the drawn terrain triangles
// on every preset, inside |x|, |z| ≤ 5.5 m, on allowed ground and at least 0.6 m apart; each refusal (prop-cap,
// outside, under-water, too-close, no-selection, invalid-choice) is named and changes nothing; select, move, rotate
// (wrapped into −π…π) and delete; replaying an edit sequence twice gives equal states and bytes; a ray picks the nearest
// prop by its picking box.
import Foundation
import Testing
import TinyWorldsCore
import VisualCoreMath
import VisualCoreScenes

/// A state of `preset` (index) and `seed` with no props.
func editingState(preset: Int, seed: UInt32 = 1) -> WorldState {
    WorldState(presetIndex: preset, seed: seed, view: .default, random: WorldState.initial.random)
}

/// Up to `count` centres (on a 0.7 m grid shifted by an irregular offset) where a prop may stand in `state`, in
/// row-major order; they are at least 0.7 m apart, so all of them can be placed together.
func validSpots(_ state: WorldState, count: Int, offset: Double = 0.123456789012345) -> [(x: Double, z: Double)] {
    guard let field = WorldEditing.groundField(of: state) else { return [] }
    var spots: [(x: Double, z: Double)] = []
    for j in 0..<15 {
        for i in 0..<15 where spots.count < count {
            let x = -4.9 + 0.7 * Double(i) + offset, z = -4.9 + 0.7 * Double(j) + offset / 3
            if case .success = WorldEditing.validate(x: x, z: z, in: state, field: field) { spots.append((x, z)) }
        }
    }
    return spots
}

/// The height at (x, z) of the drawn terrain mesh's triangle over that point, from the mesh's own vertices
/// (barycentric in x–z), independent of `WorldEditing.groundHeight`.
private func drawnHeight(_ mesh: Mesh, _ field: HeightField, x: Double, z: Double) -> Double? {
    let i = Int(((x - field.originX) / field.cellSize).rounded(.down))
    let j = Int(((z - field.originZ) / field.cellSize).rounded(.down))
    let first = 6 * (j * field.columns + i)
    for t in 0..<2 {
        let corners = (0..<3).map { mesh.positions[Int(mesh.indices[first + 3 * t + $0])] }
        let (a, b, c) = (corners[0], corners[1], corners[2])
        let d = (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
        let wa = ((b.z - c.z) * (x - c.x) + (c.x - b.x) * (z - c.z)) / d
        let wb = ((c.z - a.z) * (x - c.x) + (a.x - c.x) * (z - c.z)) / d
        let wc = 1 - wa - wb
        if wa >= -1e-9, wb >= -1e-9, wc >= -1e-9 { return wa * a.y + wb * b.y + wc * c.y }
    }
    return nil
}

@Suite struct WorldEditingTests {
    @Test(arguments: [0, 1, 2])
    func placedPropsRestOnTheDrawnTerrainAndKeepTheRules(preset: Int) throws {
        var state = editingState(preset: preset)
        let field = try #require(WorldEditing.groundField(of: state))
        let mesh = try field.mesh()
        let spots = validSpots(state, count: WorldEditing.maxProps)
        #expect(spots.count == WorldEditing.maxProps, "preset \(preset) has room for 24 props")
        for (n, spot) in spots.enumerated() {
            #expect(WorldEditing.place(kind: n % 4, x: spot.x, z: spot.z, in: &state, field: field) == nil)
            #expect(state.selection == n, "the placed prop is selected")
        }
        #expect(state.props.count == WorldEditing.maxProps)
        let minimum = WorldEditing.minimumGround(state.preset)
        for (n, prop) in state.props.enumerated() {
            let drawn = try #require(drawnHeight(mesh, field, x: prop.x, z: prop.z))
            #expect(abs(prop.y - drawn) <= 0.001, "prop \(n) rests within 1 mm of the terrain")
            #expect(abs(prop.x) <= 5.5 && abs(prop.z) <= 5.5 && prop.y >= minimum)
            #expect(prop.rotation == 0 && prop.scale == 1 && prop.kind.rawValue == n % 4 && prop.isValid)
            for other in state.props[(n + 1)...] {
                let dx = other.x - prop.x, dz = other.z - prop.z
                #expect((dx * dx + dz * dz).squareRoot() >= WorldEditing.minSpacing)
            }
        }
        let full = state
        let free = try #require(validSpots(editingState(preset: preset), count: 1, offset: 0.4).first)
        #expect(WorldEditing.place(kind: 0, x: free.x, z: free.z, in: &state, field: field) == .propCap)
        #expect(state == full, "a refused placement changes nothing")
    }

    @Test func eachPlacementRefusalIsNamedAndChangesNothing() throws {
        var state = editingState(preset: 0)
        let spot = try #require(validSpots(state, count: 1).first)
        #expect(WorldEditing.place(kind: 1, x: spot.x, z: spot.z, in: &state) == nil)
        let before = state
        #expect(WorldEditing.place(kind: 0, x: 5.6, z: 0, in: &state) == .outside)
        #expect(WorldEditing.place(kind: 0, x: 0, z: -5.51, in: &state) == .outside)
        #expect(WorldEditing.place(kind: 0, x: 5.4, z: 5.4, in: &state) == .underWater, "the island's corner is sea")
        #expect(WorldEditing.place(kind: 0, x: spot.x + 0.3, z: spot.z + 0.3, in: &state) == .tooClose)
        #expect(WorldEditing.place(kind: 4, x: spot.x, z: spot.z, in: &state) == .invalidChoice)
        #expect(WorldEditing.place(kind: -1, x: spot.x, z: spot.z, in: &state) == .invalidChoice)
        #expect(WorldEditing.place(kind: 0, x: .nan, z: 0, in: &state) == .invalidChoice)
        #expect(WorldEditing.place(kind: 0, x: 0, z: .infinity, in: &state) == .invalidChoice)
        #expect(state == before)
        var garden = editingState(preset: 1)
        #expect(WorldEditing.place(kind: 0, x: 5.5, z: 5.5, in: &garden) == .underWater, "off the asteroid's disc")
        #expect(WorldEditing.minimumGround(.asteroidGarden) == -0.4 && WorldEditing.minimumGround(.island) == 0.05)
        #expect(WorldEditing.minimumGround(.miniatureCity) == 0.05)
        #expect(Set(WorldEditRefusal.allCases.map(\.rawValue)) == ["a12.prop-cap", "a12.outside", "a12.under-water",
                                                                   "a12.too-close", "a12.no-selection",
                                                                   "a12.invalid-choice"])
    }

    @Test func selectMoveRotateAndDeleteChangeOnlyTheSelectedProp() throws {
        var state = editingState(preset: 2)
        let field = try #require(WorldEditing.groundField(of: state))
        let spots = validSpots(state, count: 3)
        for (n, spot) in spots.enumerated() { WorldEditing.place(kind: n, x: spot.x, z: spot.z, in: &state) }
        #expect(WorldEditing.select(5, in: &state) == .invalidChoice && state.selection == 2)
        #expect(WorldEditing.select(-2, in: &state) == .invalidChoice)
        #expect(WorldEditing.select(-1, in: &state) == nil && state.selection == -1)
        let unselected = state
        #expect(WorldEditing.move(dx: 0.5, dz: 0, in: &state) == .noSelection)
        #expect(WorldEditing.rotate(degrees: 45, in: &state) == .noSelection)
        #expect(WorldEditing.delete(in: &state) == .noSelection)
        #expect(state == unselected)

        #expect(WorldEditing.select(0, in: &state) == nil)
        let original = state.props[0]
        #expect(WorldEditing.move(dx: 1.5, dz: 0, in: &state) == .invalidChoice)
        #expect(WorldEditing.move(dx: 0, dz: .nan, in: &state) == .invalidChoice)
        #expect(WorldEditing.rotate(degrees: 181, in: &state) == .invalidChoice)
        #expect(state.props[0] == original)
        // spots 0 and 1 are neighbours 0.7 m apart on one row: moving prop 1 by 0.2 m towards prop 0 is too close,
        // moving it 0.05 m away is accepted and changes only prop 1.
        #expect(abs(spots[1].x - spots[0].x - 0.7) < 1e-9 && spots[1].z == spots[0].z)
        WorldEditing.select(1, in: &state)
        let beforeClose = state
        #expect(WorldEditing.move(dx: -0.2, dz: 0, in: &state, field: field) == .tooClose)
        #expect(state == beforeClose, "a refused move changes nothing")
        #expect(WorldEditing.move(dx: 0.05, dz: 0, in: &state, field: field) == nil)
        let moved = state.props[1]
        #expect(moved.x == spots[1].x + 0.05 && moved.y == WorldEditing.groundHeight(field: field, x: moved.x, z: moved.z))
        #expect(state.props[0] == unselected.props[0] && state.props[2] == unselected.props[2])
        state = unselected
        WorldEditing.select(1, in: &state)
        #expect(WorldEditing.rotate(degrees: 170, in: &state) == nil)
        #expect(WorldEditing.rotate(degrees: 170, in: &state) == nil)
        #expect(abs(state.props[1].rotation - (-20 * Double.pi / 180)) < 1e-12, "340° wraps to −20°")
        #expect(WorldEditing.rotate(degrees: 180, in: &state) == nil)
        #expect(state.props[1].rotation >= -Double.pi && state.props[1].rotation <= Double.pi)
        #expect(state.props[1].x == unselected.props[1].x && state.props[1].y == unselected.props[1].y)

        #expect(WorldEditing.delete(in: &state) == nil)
        #expect(state.props.count == 2 && state.selection == -1)
        #expect(state.props[0] == unselected.props[0] && state.props[1] == unselected.props[2])
    }

    @Test func aMoveSnapsToTheTerrainAndKeepsTheRules() throws {
        var state = editingState(preset: 0)
        let field = try #require(WorldEditing.groundField(of: state))
        let spot = try #require(validSpots(state, count: 1).first)
        WorldEditing.place(kind: 3, x: spot.x, z: spot.z, in: &state)
        WorldEditing.rotate(degrees: 45, in: &state)
        var moves = 0
        for (dx, dz) in [(0.5, 0.0), (0.0, 0.5), (0.5, 0.5), (-0.5, 0.0), (0.0, -0.5)] {
            let before = state
            if let refusal = WorldEditing.move(dx: dx, dz: dz, in: &state, field: field) {
                #expect([.outside, .underWater].contains(refusal) && state == before)
            } else {
                moves += 1
                let prop = state.props[0]
                #expect(prop.x == before.props[0].x + dx && prop.z == before.props[0].z + dz)
                #expect(prop.y == WorldEditing.groundHeight(field: field, x: prop.x, z: prop.z))
                #expect(prop.rotation == before.props[0].rotation && prop.scale == 1)
            }
        }
        #expect(moves > 0)
        // Walk the prop off the island: every step is either accepted (still on land) or refused (sea or outside).
        for _ in 0..<12 {
            let before = state
            if let refusal = WorldEditing.move(dx: 1, dz: 0, in: &state, field: field) {
                #expect([.outside, .underWater].contains(refusal) && state == before)
                break
            }
        }
        #expect(state.props[0].x <= 5.5 && state.props[0].y >= 0.05)
    }

    /// The same action sequence replayed on the same start gives the same state and bytes.
    @Test func replayingAnEditSequenceGivesTheSameState() throws {
        let start = editingState(preset: 1, seed: 42)
        let spots = validSpots(start, count: 6)
        func replay() -> (WorldState, [WorldEditRefusal?]) {
            var state = start
            var results: [WorldEditRefusal?] = []
            for (n, spot) in spots.enumerated() {
                results.append(WorldEditing.place(kind: n % 4, x: spot.x, z: spot.z, in: &state))
            }
            results.append(WorldEditing.select(2, in: &state))
            results.append(WorldEditing.move(dx: 0.25, dz: -0.5, in: &state))
            results.append(WorldEditing.rotate(degrees: -135, in: &state))
            results.append(WorldEditing.select(4, in: &state))
            results.append(WorldEditing.rotate(degrees: 77.7, in: &state))
            results.append(WorldEditing.delete(in: &state))
            results.append(WorldEditing.place(kind: 9, x: 0, z: 0, in: &state))
            results.append(WorldEditing.select(0, in: &state))
            results.append(WorldEditing.move(dx: -0.75, dz: 0.75, in: &state))
            state.light.setAzimuth(200)
            return (state, results)
        }
        let (a, resultsA) = replay(), (b, resultsB) = replay()
        #expect(a == b && resultsA == resultsB)
        #expect(a.encoded() == b.encoded())
        #expect(a.props.count == 5 && resultsA.contains(.invalidChoice))
    }

    @Test func aRayPicksTheNearestPropByItsPickingBox() throws {
        var state = editingState(preset: 0)
        let spots = validSpots(state, count: 2)
        WorldEditing.place(kind: 0, x: spots[0].x, z: spots[0].z, in: &state)
        WorldEditing.place(kind: 2, x: spots[1].x, z: spots[1].z, in: &state)
        WorldEditing.rotate(degrees: 30, in: &state)
        let tree = state.props[0], house = state.props[1]
        let down = try #require(Ray3(origin: Vec3(tree.x, 10, tree.z), direction: Vec3(0, -1, 0)))
        let hit = try #require(WorldEditing.pick(ray: down, props: state.props))
        #expect(hit.index == 0)
        #expect(abs(hit.distance - (10 - tree.y - PropCatalog.model(.tree).height)) < 1e-9)
        let houseDown = try #require(Ray3(origin: Vec3(house.x, 10, house.z), direction: Vec3(0, -1, 0)))
        #expect(WorldEditing.pick(ray: houseDown, props: state.props)?.index == 1)
        // Along the line through both centres, from beyond the tree: the tree is met first.
        let from = Vec3(tree.x + (tree.x - house.x) * 3, tree.y + 0.2, tree.z + (tree.z - house.z) * 3)
        let through = try #require(Ray3(origin: from, direction: Vec3(house.x - from.x, 0, house.z - from.z)))
        #expect(WorldEditing.pick(ray: through, props: state.props)?.index == 0)
        let sky = try #require(Ray3(origin: Vec3(0, 10, 0), direction: Vec3(0, 1, 0)))
        #expect(WorldEditing.pick(ray: sky, props: state.props) == nil)
        #expect(WorldEditing.pick(ray: down, props: []) == nil)
        // The rotated house's box turns with it: a corner of the unrotated box is missed.
        let model = PropCatalog.model(.house)
        let corner = Vec3(house.x + model.boxMax.x - 0.01, 10, house.z + model.boxMax.z - 0.01)
        let cornerRay = try #require(Ray3(origin: corner, direction: Vec3(0, -1, 0)))
        #expect(WorldEditing.pick(ray: cornerRay, props: [house]) == nil)
        let local = house.localPoint(Vec3(house.x, house.y + 0.5, house.z))
        #expect(abs(local.x) < 1e-12 && abs(local.y - 0.5) < 1e-12 && abs(local.z) < 1e-12)
        let m = house.modelMatrix
        #expect(m.c3 == Vec4(house.x, house.y, house.z, 1) && abs(m.c0.x - cos(house.rotation)) < 1e-12)
    }
}
