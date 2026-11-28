// MyceliumArchitectPreviewTests — feature 514 (R02-G22-04) T-R02G2204-002 (FR-R02G2204-002, 005, 006, 008, 013, 014;
// SC-R02G2204-003, 004, 006; clarifications Q3, Q5; research R4, R6, R7). The view orbit, the presentation state of the
// snapshot and the adapter, and the previews: the orbit clamped to yaw ±60° and pitch −20° … +35°, the authored orbit's
// camera equal to R02-G22-03's bit for bit, every orbit camera within bounds holding the authored box (board, gauges,
// pips, actions bars) inside the view with a margin of at least 5 % at every aspect 0.4 … 2.5 and its backdrop filling
// the view; 200 seeded previews equal to what the kernel's own play makes of the change (the report of the changed
// arrangement, or the refusal in the play's order) through `previewReport(_:)`, the adapter's preview and the
// snapshot's; the digest, `==` and the payload unchanged by previews, inspection, orbit and tool; the presentation
// state back to its defaults at an opening, `level.next`, reset and restore; the ghost veins dashed (three `limitTick`
// dashes per previewed vein), nothing ghostly for a refused preview, the inspection ring, and R02-G22-03's meshes
// unchanged without them. Host-run (`swift test`); explicit types, plain loops (CI type-check rule).
import Foundation
@testable import MyceliumArchitectCore
import Testing
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation

/// The id of the experience.
private let previewCoreID: ExperienceID = ExperienceID(rawValue: MyceliumArchitectExperienceCore.experienceID)!

/// The digest of `core` as the engine writes it.
private func previewDigest(of core: MyceliumArchitectExperienceCore) throws -> String {
    var builder: DigestBuilder = DigestBuilder(domain: previewCoreID.rawValue)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

@Suite struct MyceliumArchitectPreviewTests {
    typealias Core = MyceliumArchitectExperienceCore
    typealias Cell = MyceliumArchitectCell
    typealias Orbit = MyceliumArchitectViewOrbit
    typealias G = MyceliumArchitectSceneGeometry
    typealias Preview = MyceliumArchitectPreview

    /// The seed of the seeded tests of this file.
    static let seed: UInt64 = 2_514

    /// The aspects checked.
    static let aspects: [Double] = [0.4, 0.6, 0.8, 1.0, 1.5, 2.0, 2.5]

    /// Degrees in radians.
    static func radians(_ degrees: Double) -> Double { degrees * Double.pi / 180 }

    /// The orbits checked: yaw −60 … 60 by 30 × pitch −20, −10, 0, 17.5, 35 (degrees).
    static func orbits() -> [Orbit] {
        var list: [Orbit] = []
        let yaws: [Double] = [-60, -30, 0, 30, 60]
        let pitches: [Double] = [-20, -10, 0, 17.5, 35]
        for yaw in yaws {
            for pitch in pitches { list.append(Orbit(yaw: radians(yaw), pitch: radians(pitch))) }
        }
        return list
    }

    /// The control and values of an arrangement action or the run.
    static func control(_ action: MyceliumArchitectAction) -> (id: String, values: [Double]) {
        switch action {
        case .nutrient(let c): return ("cell.nutrient", [Double(c.column), Double(c.row)])
        case .blocker(let c): return ("cell.blocker", [Double(c.column), Double(c.row)])
        case .clear(let c): return ("cell.clear", [Double(c.column), Double(c.row)])
        case .seed(let d): return ("root.seed", [Double(d.rawValue)])
        case .unseed(let d): return ("root.unseed", [Double(d.rawValue)])
        case .run: return ("growth.run", [])
        }
    }

    /// `core` after `control` with `values` (accepted or not); whether it was accepted.
    static func applied(_ core: inout Core, _ id: String, _ values: [Double] = []) -> Bool {
        core.apply(ExperienceAction(control: id, values: values, step: 0)).isAccepted
    }

    /// What the kernel's own play makes of `action`: the report after applying it to a copy, or its refusal.
    static func kernel(_ play: MyceliumArchitectPlay,
                       _ action: MyceliumArchitectAction) -> Result<MyceliumArchitectReport, MyceliumArchitectError> {
        var copy: MyceliumArchitectPlay = play
        do throws(MyceliumArchitectError) {
            try copy.apply(action, expecting: copy.fingerprint)
        } catch {
            return .failure(error)
        }
        return .success(copy.report)
    }

    /// A random arrangement action on `level` (cells on and off the board, sites when the level has them, placed
    /// items for a clear, every direction).
    static func randomAction(_ random: inout SeededRandom, play: MyceliumArchitectPlay) -> MyceliumArchitectAction {
        let level: MyceliumArchitectLevel = play.level
        let sites: [Cell] = level.sites ?? []
        func someCell(_ random: inout SeededRandom) -> Cell {
            let roll: Int = random.int(0...9)
            if roll < 6, !sites.isEmpty { return sites[random.int(0...(sites.count - 1))] }
            if roll == 9 {
                return Cell(column: random.int(-2...(level.width + 1)), row: random.int(-2...(level.height + 1)))
            }
            return Cell(column: random.int(0...(level.width - 1)), row: random.int(0...(level.height - 1)))
        }
        let kind: Int = random.int(0...5)
        let direction: MyceliumArchitectDirection = MyceliumArchitectDirection(rawValue: random.int(0...7))!
        switch kind {
        case 0: return .nutrient(someCell(&random))
        case 1: return .blocker(someCell(&random))
        case 2:
            let placed: [Cell] = play.arrangement.nutrients + play.arrangement.blockers
            if !placed.isEmpty, random.int(0...3) > 0 { return .clear(placed[random.int(0...(placed.count - 1))]) }
            return .clear(someCell(&random))
        case 3: return .seed(direction)
        case 4: return .unseed(direction)
        default:
            return random.int(0...1) == 0 ? .nutrient(someCell(&random)) : .seed(direction)
        }
    }

    // MARK: Orbit

    @Test func theOrbitIsClampedToItsBounds() {
        #expect(Orbit.authored == Orbit(yaw: 0, pitch: 0) && Orbit.authored.isAuthored)
        #expect(abs(Orbit.yawRange.upperBound - Self.radians(60)) < 1e-12)
        #expect(abs(Orbit.pitchRange.lowerBound - Self.radians(-20)) < 1e-12)
        #expect(abs(Orbit.pitchRange.upperBound - Self.radians(35)) < 1e-12)
        let far: Orbit = Orbit(yaw: 5, pitch: -5).clamped()
        #expect(far == Orbit(yaw: Orbit.yawRange.upperBound, pitch: Orbit.pitchRange.lowerBound))
        let wild: Orbit = Orbit(yaw: Double.nan, pitch: Double.infinity).clamped()
        #expect(wild == Orbit.authored)
        #expect(!Orbit(yaw: Double.nan, pitch: 0).isWithinBounds && !Orbit(yaw: 2, pitch: 0).isWithinBounds)
        for corner in Orbit.corners { #expect(corner.isWithinBounds && corner.clamped() == corner) }
    }

    @Test func theAuthoredOrbitIsTheFixedCameraBitForBit() {
        for aspect in Self.aspects + [Double.nan, 0, -1, 9] {
            #expect(Orbit.authored.camera(aspect: aspect) == G.camera(aspect: aspect), "aspect \(aspect)")
        }
        #expect(G.drawnEye(.authored) == G.eye)
        #expect(G.backdropCentre(orbit: .authored) == G.backdropCentre())
    }

    @Test func everyOrbitKeepsTheBoardAndGaugesInsideWithFivePercent() throws {
        var points: [SIMD3<Double>] = []
        for index in 0..<8 { points.append(G.corner(index)) }
        let checked: [SIMD3<Double>] = [SIMD3(-0.95, -0.9, 0), SIMD3(0.95, 1.0, 0), SIMD3(-0.95, 1.0, 0),
                                        SIMD3(0.95, -0.9, 0), SIMD3(-0.95, -1.165, 0), SIMD3(0.95, -1.075, 0),
                                        SIMD3(-0.95, -1.3575, 0), SIMD3(0.95, -1.3225, 0), SIMD3(0, -1.24, 0)]
        points.append(contentsOf: checked)
        var cameras: Int = 0
        for orbit in Self.orbits() + Orbit.corners {
            for aspect in Self.aspects {
                let camera: MyceliumArchitectCamera = orbit.camera(aspect: aspect)
                cameras += 1
                #expect(camera.fovY.isFinite && camera.fovY > 0 && camera.near > 0 && camera.far > camera.near)
                #expect(camera.target == G.lookAt)
                for point in points {
                    let v: SIMD2<Double> = try #require(G.project(point, camera: camera))
                    #expect(v.x >= 0.05 && v.x <= 0.95 && v.y >= 0.05 && v.y <= 0.95,
                            "orbit \(orbit) aspect \(aspect) point \(point) at \(v)")
                }
                let d: SIMD3<Double> = camera.eye - camera.target
                #expect(G.dot(d, d).squareRoot() >= G.authoredDistance - 1e-9)
            }
        }
        #expect(cameras == 203)
        for aspect in [Double.nan, 0, -3, Double.infinity] {
            let camera: MyceliumArchitectCamera = Orbit.corners[3].camera(aspect: aspect)
            #expect(camera.aspect == 1 && camera.fovY.isFinite && camera.eye.x.isFinite)
        }
    }

    @Test func theOrbitPitchRaisesTheEyeAndTheYawTurnsIt() {
        let authored: SIMD3<Double> = G.camera(aspect: 1).eye
        let raised: SIMD3<Double> = Orbit(yaw: 0, pitch: Self.radians(20)).camera(aspect: 1).eye
        let lowered: SIMD3<Double> = Orbit(yaw: 0, pitch: Self.radians(-20)).camera(aspect: 1).eye
        let turned: SIMD3<Double> = Orbit(yaw: Self.radians(45), pitch: 0).camera(aspect: 1).eye
        func elevation(_ eye: SIMD3<Double>) -> Double {
            let d: SIMD3<Double> = eye - G.lookAt
            return atan2(d.z, (d.x * d.x + d.y * d.y).squareRoot())
        }
        #expect(elevation(raised) > elevation(authored) && elevation(lowered) < elevation(authored))
        #expect(turned.x > 0.5 && abs(elevation(turned) - elevation(authored)) < 1e-9)
    }

    @Test func theOrbitBackdropFillsTheViewAndTheMeshStaysFinite() throws {
        let core: Core = try Core.opening(number: 1)
        for orbit in Orbit.corners + [Orbit(yaw: Self.radians(30), pitch: Self.radians(10))] {
            let frame: (centre: SIMD3<Double>, forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>,
                        half: SIMD2<Double>) = G.backdropFrame(orbit)
            let w: SIMD3<Double> = frame.right * frame.half.x
            let h: SIMD3<Double> = frame.up * frame.half.y
            let quad: [SIMD3<Double>] = [frame.centre - w - h, frame.centre + w - h, frame.centre + w + h,
                                         frame.centre - w + h]
            for aspect in [0.25] + Self.aspects + [4.0] {
                let camera: MyceliumArchitectCamera = orbit.camera(aspect: aspect)
                var low: SIMD2<Double> = SIMD2(Double.infinity, Double.infinity)
                var high: SIMD2<Double> = SIMD2(-Double.infinity, -Double.infinity)
                for corner in quad {
                    let v: SIMD2<Double> = try #require(G.project(corner, camera: camera))
                    low = SIMD2(min(low.x, v.x), min(low.y, v.y))
                    high = SIMD2(max(high.x, v.x), max(high.y, v.y))
                }
                #expect(low.x <= 0 && low.y <= 0 && high.x >= 1 && high.y >= 1, "orbit \(orbit) aspect \(aspect)")
            }
            let snapshot: MyceliumArchitectSceneSnapshot = core.snapshotForRendering.orbiting(orbit)
            for index in 0..<MyceliumArchitectTier.all.count {
                let mesh: Mesh = G.board(snapshot, tier: MyceliumArchitectTier.of(index))
                for p in mesh.positions { #expect(p.x.isFinite && p.y.isFinite && p.z.isFinite) }
            }
        }
    }

    // MARK: Previews

    @Test func twoHundredPreviewsEqualTheKernel() throws {
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var cores: [Core] = []
        for number in [1, 2, 3, 4] { cores.append(try Core.opening(number: number)) }
        var accepted: Int = 0
        var refused: Set<String> = []
        for case_ in 0..<200 {
            let slot: Int = random.int(0...(cores.count - 1))
            var core: Core = cores[slot]
            if case_ % 40 == 39 {
                // A play that is not being played: the run ends it, so every change is refused with the stage.
                _ = Self.applied(&core, "growth.run")
            }
            let action: MyceliumArchitectAction = Self.randomAction(&random, play: core.play)
            let expected: Result<MyceliumArchitectReport, MyceliumArchitectError> = Self.kernel(core.play, action)
            let before: String = try previewDigest(of: core)
            let previewed: Result<MyceliumArchitectReport, MyceliumArchitectError> = core.previewReport(action)
            #expect(previewed == expected, "case \(case_) \(action)")
            var shown: Core = core
            shown.setPreview(action)
            let preview: Preview = try #require(shown.preview)
            #expect(preview == Preview.of(action, level: core.play.level, arrangement: core.play.arrangement,
                                          stage: core.play.stage, actionsLeft: core.play.actionsLeft))
            #expect(preview.change == action)
            switch expected {
            case .success(let report):
                accepted += 1
                #expect(preview.report == report && preview.wins == report.wins && preview.failure == report.failure)
                #expect(preview.refusal == nil)
            case .failure(let error):
                refused.insert(error.reasonCode)
                #expect(preview.refusal == error && preview.report == nil && preview.wins == nil)
            }
            let snapshot: MyceliumArchitectSceneSnapshot = shown.snapshot(time: 1)
            #expect(snapshot.preview == preview)
            #expect(core.snapshot(time: 1).previewing(action).preview == preview)
            let shownDigest: String = try previewDigest(of: shown)
            #expect(shown == core && shownDigest == before)
            #expect(try shown.snapshotPayload() == core.snapshotPayload())
            // Advance the explored state: apply the change when the kernel accepts it (sometimes), or undo/reset.
            if case_ % 40 == 39 {
                var back: Core = core
                if !Self.applied(&back, "play.undo") { back.reset() }
                cores[slot] = back
            } else if case .success = expected, random.int(0...2) > 0 {
                let c: (id: String, values: [Double]) = Self.control(action)
                #expect(Self.applied(&core, c.id, c.values))
                cores[slot] = core
            }
        }
        #expect(accepted >= 40)
        #expect(refused.contains("r02-g22.action") && refused.contains("r02-g22.stage"))
    }

    @Test func aRunIsRefusedByTheChangeRule() throws {
        let core: Core = try Core.opening(number: 1)
        #expect(core.previewReport(.run) == .failure(.action("run")))
    }

    // MARK: Presentation state

    @Test func presentationStateNeverChangesTheDigest() throws {
        let core: Core = try Core.opening(number: 2)
        let digest: String = try previewDigest(of: core)
        let payload: Data = try core.snapshotPayload()
        var shown: Core = core
        shown.setTool(.blocker)
        shown.inspect(core.play.level.root)
        shown.setOrbit(Orbit(yaw: 9, pitch: -9))
        shown.setPreview(.seed(.east))
        #expect(shown.tool == .blocker && shown.inspectedCell == core.play.level.root)
        #expect(shown.orbit == Orbit(yaw: Orbit.yawRange.upperBound, pitch: Orbit.pitchRange.lowerBound))
        #expect(shown.preview != nil)
        let shownDigest: String = try previewDigest(of: shown)
        let shownPayload: Data = try shown.snapshotPayload()
        #expect(shown == core && shownDigest == digest && shownPayload == payload)
        let snapshot: MyceliumArchitectSceneSnapshot = shown.snapshot(time: 0)
        #expect(snapshot.tool == .blocker && snapshot.inspectedCell == core.play.level.root)
        #expect(snapshot.orbit == shown.orbit && snapshot.preview == shown.preview)
        shown.inspect(Cell(column: -1, row: 0))
        #expect(shown.inspectedCell == nil)
        shown.resetView()
        #expect(shown.orbit == .authored)
        shown.clearPreview()
        #expect(shown.preview == nil)
        #expect(MyceliumArchitectTool.allCases == [.nutrient, .blocker])
        #expect(MyceliumArchitectTool.blocker.controlID == "cell.blocker")
        #expect(MyceliumArchitectTool.nutrient.placement(Cell(column: 1, row: 2)) == .nutrient(Cell(column: 1, row: 2)))
    }

    /// `core` with every presentation state away from its default.
    static func dressed(_ core: Core) -> Core {
        var shown: Core = core
        shown.setTool(.blocker)
        shown.inspect(core.play.level.root)
        shown.setOrbit(Orbit(yaw: 0.3, pitch: 0.2))
        shown.setPreview(.seed(.south))
        return shown
    }

    /// Whether every presentation state of `core` is at its default.
    static func isPlain(_ core: Core) -> Bool {
        core.tool == .nutrient && core.preview == nil && core.inspectedCell == nil && core.orbit == .authored
    }

    @Test func presentationStateReturnsToItsDefaults() throws {
        let opening: Core = try Core.opening(number: 3)
        #expect(Self.isPlain(opening))
        var next: Core = Self.dressed(opening)
        #expect(Self.applied(&next, "level.next"))
        #expect(Self.isPlain(next) && next.levelNumber == 4)
        var reset: Core = Self.dressed(next)
        reset.reset()
        #expect(Self.isPlain(reset) && reset.levelNumber == 3)
        let payload: Data = try Self.dressed(opening).snapshotPayload()
        let restored: Core = try Core.restore(payload: payload, seed: 2)
        #expect(Self.isPlain(restored))
        // An accepted action clears the preview only; growth.show and a refusal keep it.
        var kept: Core = Self.dressed(opening)
        #expect(Self.applied(&kept, "growth.show", [0]))
        #expect(kept.preview != nil)
        var moved: Core = Self.dressed(opening)
        var changed: Bool = false
        for direction in 0..<8 where !changed {
            changed = Self.applied(&moved, "root.seed", [Double(direction)])
        }
        let level: MyceliumArchitectLevel = opening.play.level
        for row in 0..<level.height where !changed {
            for column in 0..<level.width where !changed {
                changed = Self.applied(&moved, "cell.nutrient", [Double(column), Double(row)])
            }
        }
        #expect(changed)
        #expect(moved.preview == nil && moved.tool == .blocker && moved.inspectedCell != nil && moved.orbit != .authored)
        var refusedCore: Core = Self.dressed(opening)
        let previewBefore: Preview? = refusedCore.preview
        #expect(!Self.applied(&refusedCore, "play.redo"))
        #expect(refusedCore.preview == previewBefore)
    }

    // MARK: Ghosts and inspection

    /// The vertices of `mesh` whose a_uv.x decodes to `material`.
    static func count(_ mesh: Mesh, _ material: MyceliumArchitectMaterial) -> Int {
        var total: Int = 0
        for uv in mesh.uvs where MyceliumArchitectMaterial.decode(uv.x).material == material { total += 1 }
        return total
    }

    @Test func ghostVeinsAreDashedAndARefusedPreviewDrawsNothingGhostly() throws {
        let core: Core = try Core.opening(number: 1)
        let plain: MyceliumArchitectSceneSnapshot = core.snapshotForRendering
        let tier: MyceliumArchitectTier = MyceliumArchitectTier.of(0)
        let plainMesh: MyceliumArchitectColouredMesh = G.boardPart(plain, tier: tier)
        #expect(G.boardPart(plain.choosing(.blocker), tier: tier) == plainMesh)
        var found: Bool = false
        for direction in MyceliumArchitectDirection.allCases where !found {
            let snapshot: MyceliumArchitectSceneSnapshot = plain.previewing(.seed(direction))
            guard let report = snapshot.preview?.report, report.grown.count > 1 else { continue }
            found = true
            let veins: Int = G.ghostVeins(snapshot).count
            #expect(veins == report.grown.count - 1)
            let mesh: MyceliumArchitectColouredMesh = G.boardPart(snapshot, tier: tier)
            let added: Int = Self.count(mesh.mesh, .limitTick) - Self.count(plainMesh.mesh, .limitTick)
            #expect(added == veins * G.ghostDashes * 4, "\(added) for \(veins) veins")
            for vein in G.ghostVeins(snapshot) {
                #expect(abs(vein.from.z - G.ghostLift * plain.fitScale) < 1e-12)
                let dashes: [(from: SIMD3<Double>, to: SIMD3<Double>)] = G.ghostDashSegments(from: vein.from,
                                                                                               to: vein.to)
                #expect(dashes.count == 3 && dashes[0].from != vein.from && dashes[2].to != vein.to)
            }
        }
        #expect(found)
        let refusedSnapshot: MyceliumArchitectSceneSnapshot = plain.previewing(.clear(Cell(column: 0, row: 0)))
        #expect(refusedSnapshot.preview?.refusal != nil)
        #expect(G.boardPart(refusedSnapshot, tier: tier) == plainMesh)
        #expect(G.paintOrder(refusedSnapshot) == G.paintOrder(plain))
    }

    @Test func theInspectedCellIsRinged() throws {
        let core: Core = try Core.opening(number: 1)
        let plain: MyceliumArchitectSceneSnapshot = core.snapshotForRendering
        let tier: MyceliumArchitectTier = MyceliumArchitectTier.of(2)
        let plainMesh: Mesh = G.board(plain, tier: tier)
        let cell: Cell = core.play.level.terminals[0]
        let ringed: MyceliumArchitectSceneSnapshot = plain.inspecting(cell)
        #expect(ringed.inspectedCell == cell)
        let mesh: Mesh = G.board(ringed, tier: tier)
        #expect(Self.count(mesh, .pipHollow) == Self.count(plainMesh, .pipHollow) + 4)
        let centre: SIMD3<Double> = G.centre(cell, ringed)
        let half: Double = G.inspectRing * ringed.fitScale
        var corners: Int = 0
        for k in mesh.positions.indices where MyceliumArchitectMaterial.decode(mesh.uvs[k].x).material == .pipHollow {
            let p: Vec3 = mesh.positions[k]
            if abs(abs(p.x - centre.x) - half) < 1e-9 && abs(abs(p.y - centre.y) - half) < 1e-9 { corners += 1 }
        }
        #expect(corners == 4)
        #expect(plain.inspecting(Cell(column: 99, row: 0)).inspectedCell == nil)
        #expect(G.board(plain.inspecting(nil), tier: tier) == plainMesh)
    }
}
