// WorldPackTests — feature 092 (A12-P04) T-A12-402 (FR-A12-401, FR-A12-403–406; clarifications Q1–Q5; SC-A12-402–404).
// The environment packs, host-free and short: each pack applies without refusal with its preset, seed, prop counts per
// kind, light, default view and no selection; applying is deterministic (the same state and bytes from any start); the
// budgets (≤ 16 props, ≤ 30,000 vertices, ≤ 18 draws) hold; a broken pack (a prop under water) is refused with
// `a12.under-water` and the state is unchanged; a 24 yaw × 8 pitch × 4 distance sweep per pack stays within the pack's
// limits and keeps the clearance over terrain and props; the pack limits lie inside the global ones and are the
// presets' limits; a restored out-of-range view is clamped to them; a prop near the eye raises the pitch.
import Foundation
import Testing
import TinyWorldsCore
import VisualCoreMath
import VisualCoreScenes

@Suite struct WorldPackTests {
    private let degree = Double.pi / 180

    /// The expected props per kind (tree, rock, house, lantern) of each pack, in preset order.
    private let counts: [[PropKind: Int]] = [
        [.tree: 3, .rock: 2, .house: 1, .lantern: 1],
        [.tree: 0, .rock: 5, .house: 0, .lantern: 3],
        [.tree: 2, .rock: 0, .house: 6, .lantern: 4],
    ]

    private func opened(_ pack: WorldPack) throws -> WorldState {
        try pack.state().get()
    }

    @Test(arguments: WorldPack.all)
    func eachPackAppliesWithItsComposition(pack: WorldPack) throws {
        let state = try opened(pack)
        #expect(state.presetIndex == pack.presetIndex && state.seed == pack.seed)
        #expect(state.light == pack.light && state.view == pack.defaultView)
        #expect(state.selection == WorldState.noSelection)
        #expect(state.props.count == pack.props.count)
        for kind in PropKind.allCases {
            #expect(state.props.filter { $0.kind == kind }.count == counts[pack.presetIndex][kind], "\(pack.id) \(kind)")
            #expect(pack.count(kind) == counts[pack.presetIndex][kind])
        }
        for (placed, prop) in zip(state.props, pack.props) {
            #expect(placed.kind == prop.kind && placed.x == prop.x && placed.z == prop.z && placed.isValid)
            let turn = (prop.turn * WorldView.radiansPerDegree).remainder(dividingBy: 2 * Double.pi)
            #expect(abs(placed.rotation - turn) < 1e-12, "\(pack.id) turn \(prop.turn)")
            #expect(placed.y >= WorldEditing.minimumGround(pack.preset))
        }
        #expect(pack.author == "VisualCore project" && pack.license == "MIT")
        #expect(pack.id == pack.preset.id.contentId && pack.name == pack.preset.name)
        #expect(WorldPack.pack(index: pack.presetIndex) == pack && WorldPack.pack(id: pack.id) == pack)
        #expect(WorldPack.pack(for: pack.preset.id) == pack)
    }

    @Test func theBundledPackDataIsAsSpecified() {
        #expect(WorldPack.all.map(\.id) == ["island", "asteroid-garden", "miniature-city"])
        #expect(WorldPack.all.map(\.seed) == [11, 7, 5])
        #expect(WorldPack.all.map(\.presetIndex) == [0, 1, 2])
        #expect(WorldPack.all.map { [$0.light.azimuth, $0.light.elevation, $0.light.ambient] }
                == [[120, 45, 0.35], [300, 30, 0.25], [210, 60, 0.40]])
        #expect(WorldPack.all.map(\.limits.distance) == [12...28, 12...30, 10...24])
        #expect(WorldPack.all.map(\.limits) == [CameraLimits(pitchDegrees: 15...70, distance: 12...28),
                                               CameraLimits(pitchDegrees: 20...75, distance: 12...30),
                                               CameraLimits(pitchDegrees: 25...75, distance: 10...24)])
        let views = WorldPack.all.map(\.defaultView)
        for (view, expected) in zip(views, [(45.0, 35.0, 18.0), (135, 40, 20), (-45, 45, 16)]) {
            #expect(abs(view.yawDegrees - expected.0) < 1e-9 && abs(view.pitchDegrees - expected.1) < 1e-9)
            #expect(view.distance == expected.2)
        }
        #expect(WorldPack.pack(index: 3) == nil && WorldPack.pack(index: -1) == nil && WorldPack.pack(id: "x") == nil)
    }

    @Test(arguments: WorldPack.all)
    func applyingIsDeterministicFromAnyStart(pack: WorldPack) throws {
        let first = try opened(pack)
        let second = try opened(pack)
        #expect(first == second && first.encoded() == second.encoded())
        // Over an edited world (another preset, a new seed, a prop, another light and view): the same state.
        var edited = WorldState.initial
        edited.choosePreset((pack.presetIndex + 1) % 3)
        edited.newSeed()
        WorldEditing.place(kind: 1, x: 0, z: 0, in: &edited)
        edited.light = WorldLight(azimuth: 10, elevation: 20, ambient: 0.5)
        edited.view = WorldView(yaw: 1, pitch: 1, distance: 29)
        #expect(pack.apply(to: &edited) == nil)
        #expect(edited == first && edited.encoded() == first.encoded())
        let field = try #require(WorldEditing.groundField(of: first))
        var again = WorldState.initial
        #expect(pack.apply(to: &again, field: field) == nil && again == first)
        // The opened state survives the JSON round trip unchanged.
        #expect(try WorldState.decode(first.encoded()).get() == first)
    }

    @Test(arguments: WorldPack.all)
    func eachPackIsWithinItsBudgets(pack: WorldPack) throws {
        #expect(pack.props.count <= WorldPack.maxProps && WorldPack.maxProps == 16)
        let vertices = try #require(pack.vertexCount())
        let parts = try TerrainGenerator.parts(preset: pack.preset, seed: pack.seed)
        let props = pack.props.reduce(0) { $0 + PropCatalog.model($1.kind).mesh.positions.count }
        #expect(vertices == parts.reduce(0) { $0 + $1.mesh.positions.count } + props)
        #expect(vertices <= WorldPack.maxVertices && WorldPack.maxVertices == 30_000, "\(pack.id): \(vertices)")
        #expect(pack.drawCount == parts.count + pack.props.count)
        #expect(pack.drawCount <= WorldPack.maxDraws && WorldPack.maxDraws == 18 && pack.drawCount <= 2 + pack.props.count)
    }

    @Test func aBrokenPackIsRefusedAndTheWorldStays() throws {
        var props = WorldPack.island.props
        props[3] = PackProp(.rock, x: 5.0, z: 5.0, turn: 0)                // the island's corner lies under the sea
        let broken = WorldPack(id: "broken", name: "Broken", presetIndex: 0, seed: 11, props: props,
                               light: WorldPack.island.light, limits: WorldPack.island.limits,
                               defaultView: WorldPack.island.defaultView)
        var state = WorldState.initial
        WorldEditing.place(kind: 0, x: 0, z: 0, in: &state)
        let before = state
        #expect(broken.apply(to: &state) == .underWater)
        #expect(state == before && state.encoded() == before.encoded())
        #expect(WorldEditRefusal.underWater.rawValue == "a12.under-water")
        guard case .failure(let refusal) = broken.state() else { Issue.record("the broken pack opened"); return }
        #expect(refusal == .underWater && broken.vertexCount() == nil)
        // Other broken data is refused the same way: two props too close, a prop outside the world.
        var close = broken
        close.props = [PackProp(.tree, x: 0, z: 0), PackProp(.rock, x: 0.3, z: 0)]
        #expect(close.apply(to: &state) == .tooClose && state == before)
        close.props = [PackProp(.tree, x: 6, z: 0)]
        #expect(close.apply(to: &state) == .outside && state == before)
        close.props = Array(repeating: PackProp(.tree, x: 0, z: 0), count: 17)
        #expect(close.apply(to: &state) == .propCap && state == before)
    }

    @Test(arguments: WorldPack.all)
    func theSweepKeepsThePacksLimitsAndTheClearanceOverTerrainAndProps(pack: WorldPack) throws {
        let state = try opened(pack)
        let field = try #require(WorldEditing.groundField(of: state))
        let limits = pack.limits
        #expect(CameraPolicy.keepsClearance(state, field: field))
        var count = 0
        for y in 0..<24 {
            for p in 0..<8 {
                for d in 0..<4 {
                    // The sweep spans the global ranges, so the clamp also brings views into the pack's limits.
                    let pitch = (10 + 65 * Double(p) / 7) * degree
                    let distance = 10 + 20 * Double(d) / 3
                    let view = WorldView(yaw: (-180 + 15 * Double(y)) * degree, pitch: pitch, distance: distance)
                    let clamped = CameraPolicy.clamp(view, state: state, field: field)
                    count += 1
                    #expect(limits.contains(clamped), "\(pack.id) \(view) → \(clamped)")
                    #expect(CameraPolicy.keepsClearance(clamped, field: field, limits: limits, props: state.props))
                    #expect(CameraPolicy.headroom(of: clamped, field: field, props: state.props) >= 0.5)
                    #expect(clamped.yaw == view.yaw)
                    #expect(clamped.distance == min(max(distance, limits.distance.lowerBound),
                                                    limits.distance.upperBound))
                    #expect(clamped.pitch >= min(max(pitch, limits.pitch.lowerBound), limits.pitch.upperBound))
                    #expect(CameraPolicy.clamp(clamped, state: state, field: field) == clamped, "idempotent")
                }
            }
        }
        #expect(count == 24 * 8 * 4)
    }

    @Test func thePackLimitsLieInsideTheGlobalOnesAndAreThePresetsLimits() {
        for pack in WorldPack.all {
            #expect(pack.limits.isInsideGlobal, "\(pack.id)")
            #expect(CameraPolicy.limits(for: pack.preset) == pack.limits)
            #expect(pack.limits.contains(pack.defaultView))
            #expect(pack.limits.pitch.lowerBound >= WorldView.pitchRange.lowerBound
                    && pack.limits.pitch.upperBound <= WorldView.pitchRange.upperBound)
            #expect(pack.limits.distance.lowerBound >= WorldView.distanceRange.lowerBound
                    && pack.limits.distance.upperBound <= WorldView.distanceRange.upperBound)
        }
        #expect(abs(WorldPack.island.limits.pitchDegrees.lowerBound - 15) < 1e-9)
        #expect(abs(WorldPack.miniatureCity.limits.pitchDegrees.upperBound - 75) < 1e-9)
    }

    @Test func aRestoredOutOfRangeViewIsClampedToThePresetsLimits() throws {
        var state = try opened(.island)
        let props = state.props, light = state.light
        state.view = WorldView(yaw: 0.25, pitch: 10 * degree, distance: 30)   // valid globally, outside 15°…70°, 12…28
        let restored = try WorldState.decode(state.encoded()).get()
        #expect(restored.view == state.view, "the document keeps the view; the policy clamps it")
        let clamped = CameraPolicy.clamp(restored.view, state: restored)
        #expect(abs(clamped.pitchDegrees - 15) < 1e-9 && clamped.distance == 28 && clamped.yaw == 0.25)
        #expect(restored.props == props && restored.light == light, "the clamp never changes a prop or the light")
        var city = try opened(.miniatureCity)
        city.view = WorldView(yaw: -1, pitch: 80 * degree, distance: 10)       // pitch clamps to 75° globally first
        let top = CameraPolicy.clamp(city.view, state: city)
        #expect(abs(top.pitchDegrees - 75) < 1e-9 && top.distance == 10)
        city.view = WorldView(yaw: -1, pitch: 12 * degree, distance: 29)
        let low = CameraPolicy.clamp(city.view, state: city)
        #expect(abs(low.pitchDegrees - 25) < 1e-9 && low.distance == 24)
        #expect(CameraPolicy.clamp(city.view, preset: city.preset, seed: city.seed, props: city.props) == low)
    }

    @Test func aPropNearTheEyeRaisesThePitch() throws {
        let field = try HeightField(columns: 8, rows: 8, cellSize: 1.5, originX: -6, originZ: -6) { _, _ in 0 }
        let view = WorldView(yaw: 0, pitch: 30 * degree, distance: 10)
        let eye = CameraPolicy.eye(of: view)
        #expect(CameraPolicy.keepsClearance(view, field: field))
        // A (synthetic) prop standing 4 m high under the eye: its top is 4 + 1.18 m, above the eye's 5.3 m.
        let tall = PlacedProp(kind: .tree, x: eye.x + 1.5, y: 4, z: eye.z)
        let radius = CameraPolicy.pickingRadius(of: tall)
        #expect(abs(radius - (0.42 * 0.42 * 2).squareRoot()) < 1e-9)
        #expect(1.5 <= CameraPolicy.propReach + radius, "within 1 m plus the picking radius")
        #expect(abs(CameraPolicy.propMaximum(props: [tall], x: eye.x, z: eye.z) - 5.18) < 1e-9)
        #expect(!CameraPolicy.keepsClearance(view, field: field, props: [tall]))
        let clamped = CameraPolicy.clamp(view, field: field, props: [tall])
        #expect(CameraPolicy.keepsClearance(clamped, field: field, props: [tall]))
        let raised = clamped.pitchDegrees - 30
        #expect(raised >= 1 && abs(raised - raised.rounded()) < 1e-9 && clamped.distance == 10 && clamped.yaw == 0)
        // Beyond 1 m plus the radius the prop is ignored.
        let far = PlacedProp(kind: .tree, x: eye.x + 1.7, y: 4, z: eye.z)
        #expect(CameraPolicy.propMaximum(props: [far], x: eye.x, z: eye.z) == -.infinity)
        #expect(CameraPolicy.clamp(view, field: field, props: [far]) == view)
        // A clamp limited to a pack's upper pitch stops there.
        let wall = stride(from: 3.0, through: 9.0, by: 1.0).map { PlacedProp(kind: .tree, x: 0, y: 40, z: $0) }
        let limits = WorldPack.island.limits
        #expect(CameraPolicy.clamp(view, field: field, limits: limits, props: wall).pitch == limits.pitch.upperBound)
    }
}
