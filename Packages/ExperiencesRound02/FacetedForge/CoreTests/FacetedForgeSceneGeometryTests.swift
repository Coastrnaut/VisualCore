// FacetedForgeSceneGeometryTests — feature 373 (R02-G08-03) T-R02G0803-004 (FR-R02G0803-001, 002, 004, 006;
// SC-R02G0803-001; clarifications Q1–Q4). The crystal geometry of Faceted Forge built from real plays: every mesh is
// finite and bounded with unit normals and one colour per vertex for the uncut crystal, one known cut, a play cut into
// 21 pieces, a sliver failure and a win; every opened piece centre, cut-face centre, the preview centre and every cut
// mark bar project inside the view with a 5 % margin at seven aspects 0.4 … 2.5; positions are the same at every tier
// and level-2 has no glow; the cut flags of a known cut are exact; the uncut crystal does not move; the mark has 0,
// half and all bars spent; the opening eases over 0.4 s and is full at once under Reduce Motion; pieces are emitted
// back to front. Hand-made levels, plain loops; well under 10 s.
// Feature 374 (R02-G08-04) T-R02G0804-002 (FR-R02G0804-006; SC-R02G0804-004): the cameras fit the framing sphere of
// radius 1.65 (was 1.45); at the authored orbit, both yaw limits, both pitch limits and the four corners of the orbit
// bounds every opened piece centre, cut-face centre, preview centre and both ends of every cut-mark bar project inside
// the view with a 5 % margin at the seven aspects; the authored camera is the authored orbit's camera, bit for bit;
// `FacetedForgeOrbit.clamped()` keeps the bounds and a non-finite angle becomes the authored one. At the four corners
// of the orbit bounds the pieces and each piece's faces come out back to front for that orbit's eye, and the sliver
// cross and cut-mark bars face that eye; the default (authored) meshes equal the explicit `.authored` ones.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
@testable import FacetedForgeCore

@Suite struct FacetedForgeSceneGeometryTests {
    typealias Geometry = FacetedForgeSceneGeometry
    typealias Snapshot = FacetedForgeSceneSnapshot

    static let aspects: [Double] = [0.4, 0.5, 0.75, 1, 1.5, 2, 2.5]

    /// The cube −6 … 6 with `budget` cuts, sliver limit `sliver` and a target of two pieces of `shares`.
    static func cube(budget: Int, sliver: FacetedForgeFraction,
                     shares: [FacetedForgeFraction]) throws -> FacetedForgeLevel {
        var planes: [FacetedForgeHalfSpace] = []
        for direction in 0..<3 {
            planes.append(FacetedForgeHalfSpace(direction: direction, sign: 1, depth: 6))
            planes.append(FacetedForgeHalfSpace(direction: direction, sign: -1, depth: -6))
        }
        var target: [FacetedForgeTargetPiece] = []
        for share in shares { target.append(FacetedForgeTargetPiece(share: share, faces: 6)) }
        return try FacetedForgeLevel(id: "geometry-cube", seed: 1, difficulty: 1, planes: planes.sorted(),
                                     budget: budget, sliver: sliver, target: target.sorted())
    }

    /// A cube level no cut of the tests wins: target shares 1/7 and 6/7, sliver limit 1/100000.
    static func openCube(budget: Int) throws -> FacetedForgeLevel {
        try cube(budget: budget, sliver: try FacetedForgeFraction(1, 100_000),
                 shares: [try FacetedForgeFraction(1, 7), try FacetedForgeFraction(6, 7)])
    }

    /// A play of `level` begun, with `actions` applied.
    static func play(_ level: FacetedForgeLevel, _ actions: [FacetedForgeAction] = []) throws -> FacetedForgePlay {
        var play = FacetedForgePlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        for action in actions { try play.apply(action, expecting: play.fingerprint) }
        return play
    }

    /// The open cube cut 20 times (budget 20): each time the largest piece at its middle crossing depth, the
    /// direction cycling through the axes and diagonals.
    static func manyPieces() throws -> FacetedForgePlay {
        var p: FacetedForgePlay = try play(try openCube(budget: 20))
        var turn: Int = 0
        while p.stage == .playing {
            var applied: Bool = false
            for attempt in 0..<13 {
                let direction: Int = (turn + attempt) % 13
                let depths: [Int] = FacetedForgeSolver.crossingDepths(p.pieces[0], direction: direction)
                if depths.isEmpty { continue }
                try p.apply(.cut(0, direction, depths[depths.count / 2]), expecting: p.fingerprint)
                applied = true
                break
            }
            if !applied { break }
            turn += 1
        }
        return p
    }

    /// A snapshot of `play` with a valid preview choice at `time`.
    static func snapshot(_ play: FacetedForgePlay, time: Double, piece: Int = 0, direction: Int = 0) -> Snapshot {
        let choice = FacetedForgePreviewChoice(piece: piece, direction: direction, depth: 0).clamped(to: play)
        return Snapshot(play: play, levelNumber: 1, choice: choice, time: time)
    }

    /// The uncut crystal, a known cut, 21 pieces, a sliver failure and a win (opened, time 1 s).
    static func snapshots() throws -> [Snapshot] {
        var result: [Snapshot] = []
        result.append(snapshot(try play(try openCube(budget: 4)), time: 1))
        result.append(snapshot(try play(try openCube(budget: 4), [.cut(0, 0, -2)]), time: 1, piece: 1, direction: 9))
        result.append(snapshot(try manyPieces(), time: 1, piece: 3, direction: 5))
        result.append(try sliver())
        result.append(try won())
        return result
    }

    /// A cube whose sliver limit is 1/5, cut at x = −5 (a 1/12 slice): a sliver failure.
    static func sliver() throws -> Snapshot {
        let half: FacetedForgeFraction = try FacetedForgeFraction(1, 2)
        let level = try cube(budget: 3, sliver: try FacetedForgeFraction(1, 5), shares: [half, half])
        return snapshot(try play(level, [.cut(0, 0, -5)]), time: 1)
    }

    /// A cube whose target is two halves, cut at x = 0: won.
    static func won(time: Double = 1) throws -> Snapshot {
        let half: FacetedForgeFraction = try FacetedForgeFraction(1, 2)
        let level = try cube(budget: 3, sliver: try FacetedForgeFraction(1, 100), shares: [half, half])
        return snapshot(try play(level, [.cut(0, 0, 0)]), time: time)
    }

    static func parts(_ s: Snapshot, _ tier: FacetedForgeTier) throws -> [FacetedForgeColouredMesh] {
        [try Geometry.crystalPart(s, tier: tier), try Geometry.glowPart(s, tier: tier)]
    }

    @Test func manyPiecePlayHasTwentyOneFiniteOpenedPieces() throws {
        let p: FacetedForgePlay = try Self.manyPieces()
        #expect(p.cuts == 20 && p.pieces.count == 21)
        #expect(p.failure == .budget)
        let s: Snapshot = Self.snapshot(p, time: 1)
        #expect(s.pieces.count == 21 && Geometry.cutFaceCentres(s).count >= 20)
        #expect(Geometry.previewCentre(s) != nil)
    }

    @Test func finiteAndBoundedForEverySnapshot() throws {
        for s in try Self.snapshots() {
            for tier in FacetedForgeTier.all {
                for (index, part) in try Self.parts(s, tier).enumerated() {
                    let m: Mesh = part.mesh
                    #expect(part.colours.count == m.positions.count)
                    #expect(m.normals.count == m.positions.count && m.uvs.count == m.positions.count)
                    #expect(m.indices.count % 3 == 0)
                    let glows: Bool = tier.glowShells > 0 && !Geometry.cutFaceCentres(s).isEmpty
                    #expect(m.indices.isEmpty == (index == 1 && !glows))
                    for i in m.indices { #expect(Int(i) < m.positions.count) }
                    for k in m.positions.indices {
                        let p: Vec3 = m.positions[k]
                        let n: Vec3 = m.normals[k]
                        let ok: Bool = p.x.isFinite && p.y.isFinite && p.z.isFinite && n.x.isFinite && n.y.isFinite
                            && n.z.isFinite && m.uvs[k].x.isFinite && m.uvs[k].y.isFinite
                        #expect(ok)
                        let r: Double = (p.x * p.x + p.y * p.y + p.z * p.z).squareRoot()
                        if index == 0 {
                            let unitNormal: Double = (n.x * n.x + n.y * n.y + n.z * n.z).squareRoot()
                            #expect(abs(unitNormal - 1) < 1e-9)
                            #expect(abs(p.x) <= Geometry.groundHalf + 1e-9 && abs(p.z) <= Geometry.groundHalf + 1e-9)
                            #expect(p.y >= Geometry.groundY - 1e-9 && p.y <= 1.3)
                            let code: Int = Int(m.uvs[k].x.rounded())
                            #expect(code >= 0 && code <= 7)
                            if code >= 1 && code <= 5 { #expect(r <= 1.25) }
                        } else {
                            #expect(r <= 1.3)
                        }
                        let c: Vec4 = part.colours[k]
                        #expect(c.x >= 0 && c.x <= 1 && c.y >= 0 && c.y <= 1 && c.z >= 0 && c.z <= 1 && c.w == 1)
                    }
                }
            }
            for aspect in [0.0, -1, .nan, .infinity, 1e-9, 1e9] {
                let cam: FacetedForgeCamera = Geometry.camera(s, aspect: aspect)
                #expect(cam.eye.x.isFinite && cam.eye.y.isFinite && cam.eye.z.isFinite && cam.near > 0)
                #expect(Geometry.project(SIMD3(0, 0, 0), camera: cam) != nil)
            }
            #expect(Geometry.camera(s, aspect: .nan) == Geometry.camera(s, aspect: 1))
            #expect(Geometry.project(SIMD3(.nan, 0, 0), camera: Geometry.camera(s, aspect: 1)) == nil)
        }
    }

    @Test func centresAndMarkInsideTheViewAtSevenAspects() throws {
        for s in try Self.snapshots() {
            var points: [SIMD3<Double>] = Geometry.cutFaceCentres(s)
            for piece in s.pieces.indices { points.append(Geometry.pieceCentre(piece, s)) }
            if let preview = Geometry.previewCentre(s) { points.append(preview) }
            for bar in 0..<s.budget {
                let c: SIMD3<Double> = Geometry.markBarCentre(bar, budget: s.budget)
                points.append(c + SIMD3(0.06, 0, 0))
                points.append(c - SIMD3(0.06, 0, 0))
            }
            // The opened crystal's extreme reach (radius 1.2) in six directions.
            let reach: [SIMD3<Double>] = [SIMD3(1.2, 0, 0), SIMD3(-1.2, 0, 0), SIMD3(0, 1.2, 0), SIMD3(0, -1.2, 0),
                                          SIMD3(0, 0, 1.2), SIMD3(0, 0, -1.2)]
            for p in reach { points.append(p) }
            for aspect in Self.aspects {
                let cam: FacetedForgeCamera = Geometry.camera(s, aspect: aspect)
                for p in points {
                    let v: SIMD2<Double>? = Geometry.project(p, camera: cam)
                    #expect(v != nil)
                    if let v {
                        #expect(v.x >= 0.05 && v.x <= 0.95 && v.y >= 0.05 && v.y <= 0.95, "\(p) at \(aspect): \(v)")
                    }
                }
            }
        }
    }

    @Test func positionsAreTheSameAtEveryTierAndLevelTwoHasNoGlow() throws {
        for s in try Self.snapshots() {
            var reference: [Vec3]?
            for tier in FacetedForgeTier.all {
                let m: Mesh = try Geometry.crystalMesh(s, tier: tier)
                var kept: [Vec3] = []
                for k in m.positions.indices where Int(m.uvs[k].x.rounded()) != 3 { kept.append(m.positions[k]) }
                if let reference { #expect(kept == reference) } else { reference = kept }
                let glow: Mesh = try Geometry.glowMesh(s, tier: tier)
                if tier.glowShells == 0 { #expect(glow.indices.isEmpty) }
            }
            for piece in s.pieces.indices {
                let c: SIMD3<Double> = Geometry.pieceCentre(piece, s)
                #expect(c.x.isFinite && c.y.isFinite && c.z.isFinite)
            }
        }
    }

    @Test func cutFlagsAreExactOnAKnownCut() throws {
        let s: Snapshot = Self.snapshot(try Self.play(try Self.openCube(budget: 4), [.cut(0, 0, -2)]), time: 1)
        #expect(s.pieces.count == 2)
        let plane: Double = -2 / s.scale
        for piece in s.pieces {
            #expect(piece.faces.count == 6 && piece.cutFaces.count == 6)
            var cut: Int = 0
            for (f, face) in piece.faces.enumerated() {
                var onPlane: Bool = true
                for i in face where abs(piece.corners[i].x - plane) > 1e-12 { onPlane = false }
                #expect(piece.cutFaces[f] == onPlane)
                if piece.cutFaces[f] { cut += 1 }
            }
            #expect(cut == 1)
        }
        let centres: [SIMD3<Double>] = Geometry.cutFaceCentres(s)
        #expect(centres.count == 2)
        // Each piece moved away along its centroid direction: the two cut faces separate along x.
        if centres.count == 2 { #expect(abs(centres[0].x - centres[1].x) > 0.1) }
    }

    @Test func uncutCrystalDoesNotMove() throws {
        let s: Snapshot = Self.snapshot(try Self.play(try Self.openCube(budget: 4)), time: 5)
        #expect(s.pieces.count == 1)
        #expect(Geometry.offset(piece: 0, s) == SIMD3<Double>(0, 0, 0))
        #expect(Geometry.offset(piece: 0, s, reduceMotion: true) == SIMD3<Double>(0, 0, 0))
        #expect(Geometry.pieceCentre(0, s) == s.pieces[0].centroid)
        #expect(Geometry.cutFaceCentres(s).isEmpty)
        #expect(Geometry.offset(piece: 7, s) == SIMD3<Double>(0, 0, 0))
    }

    @Test func markBarsAtZeroHalfAndFullBudget() throws {
        let level: FacetedForgeLevel = try Self.openCube(budget: 4)
        let plays: [FacetedForgePlay] = [try Self.play(level),
                                         try Self.play(level, [.cut(0, 0, -2), .cut(0, 1, 1)]),
                                         try Self.play(level, [.cut(0, 0, -2), .cut(0, 1, 1), .cut(0, 2, 0),
                                                               .cut(0, 0, -4)])]
        let expected: [Int] = [0, 2, 4]
        for (index, p) in plays.enumerated() {
            let s: Snapshot = Self.snapshot(p, time: 1)
            let codes: [Double] = Geometry.markCodes(s)
            #expect(codes.count == 4)
            var spent: Int = 0
            for code in codes where code == FacetedForgeMaterial.spentBar { spent += 1 }
            #expect(spent == expected[index])
            for bar in 0..<codes.count {
                #expect((codes[bar] == FacetedForgeMaterial.spentBar) == (bar < expected[index]))
            }
            let m: Mesh = try Geometry.crystalMesh(s, tier: FacetedForgeTier.of(2))
            var spentVertices: Int = 0
            var unspentVertices: Int = 0
            for uv in m.uvs {
                if uv.x == FacetedForgeMaterial.spentBar { spentVertices += 1 }
                if uv.x == FacetedForgeMaterial.unspentBar { unspentVertices += 1 }
            }
            #expect(spentVertices == 4 * expected[index] && unspentVertices == 4 * (4 - expected[index]))
        }
        #expect(abs(Geometry.markBarCentre(0, budget: 4).x - (-0.9 + 0.225)) < 1e-12)
        #expect(abs(Geometry.markBarCentre(3, budget: 4).x - (0.9 - 0.225)) < 1e-12)
    }

    @Test func openingEasesAndIsFullUnderReduceMotion() throws {
        let level: FacetedForgeLevel = try Self.openCube(budget: 4)
        let p: FacetedForgePlay = try Self.play(level, [.cut(0, 0, -2)])
        let times: [Double] = [-1, 0, 0.1, 0.2, 0.3, 0.4, 2]
        let expected: [Double] = [0, 0, 0.12 * 0.15625, 0.06, 0.12 * 0.84375, 0.12, 0.12]
        for (index, time) in times.enumerated() {
            let s: Snapshot = Self.snapshot(p, time: time)
            #expect(abs(Geometry.opening(s) - expected[index]) < 1e-12)
            #expect(Geometry.opening(s, reduceMotion: true) == 0.12)
            let shift: SIMD3<Double> = Geometry.offset(piece: 0, s)
            let length: Double = (shift * shift).sum().squareRoot()
            #expect(abs(length - expected[index]) < 1e-12)
        }
        #expect(Geometry.opening(try Self.won(time: 0)) == 0)
        #expect(abs(Geometry.opening(try Self.won(time: 0.2)) - 0.1) < 1e-12)
        #expect(Geometry.opening(try Self.won(time: 1)) == 0.2)
        #expect(Geometry.opening(try Self.won(time: 0), reduceMotion: true) == 0.2)
    }

    @Test func piecesAreEmittedBackToFrontAndSliverIsMarked() throws {
        let s: Snapshot = Self.snapshot(try Self.manyPieces(), time: 1)
        let order: [Int] = Geometry.pieceOrder(s)
        #expect(order.sorted() == Array(s.pieces.indices))
        for k in 1..<order.count {
            let a: Double = (Geometry.pieceCentre(order[k - 1], s) * Geometry.eyeDirection).sum()
            let b: Double = (Geometry.pieceCentre(order[k], s) * Geometry.eyeDirection).sum()
            #expect(a <= b + 1e-12)
        }
        let failed: Snapshot = try Self.sliver()
        #expect(failed.failurePiece != nil)
        var crossVertices: Int = 0
        for uv in try Geometry.crystalMesh(failed, tier: FacetedForgeTier.of(0)).uvs
        where uv.x == FacetedForgeMaterial.sliverCross {
            crossVertices += 1
        }
        #expect(crossVertices == 8)
        var none: Int = 0
        for uv in try Geometry.crystalMesh(try Self.won(), tier: FacetedForgeTier.of(0)).uvs
        where uv.x == FacetedForgeMaterial.sliverCross {
            none += 1
        }
        #expect(none == 0)
    }

    // MARK: Orbit (feature 374)

    typealias Orbit = FacetedForgeOrbit

    /// The authored orbit, both yaw limits, both pitch limits and the four corners of the orbit bounds.
    static let orbits: [Orbit] = [
        .authored,
        Orbit(yaw: -Orbit.yawLimit, pitch: Orbit.authored.pitch),
        Orbit(yaw: Orbit.yawLimit, pitch: Orbit.authored.pitch),
        Orbit(yaw: 0, pitch: Orbit.pitchRange.lowerBound),
        Orbit(yaw: 0, pitch: Orbit.pitchRange.upperBound),
        Orbit(yaw: -Orbit.yawLimit, pitch: Orbit.pitchRange.lowerBound),
        Orbit(yaw: -Orbit.yawLimit, pitch: Orbit.pitchRange.upperBound),
        Orbit(yaw: Orbit.yawLimit, pitch: Orbit.pitchRange.lowerBound),
        Orbit(yaw: Orbit.yawLimit, pitch: Orbit.pitchRange.upperBound),
    ]

    /// Every opened piece centre, cut-face centre, the preview centre and both ends of every cut-mark bar of `s`.
    static func framedPoints(_ s: Snapshot) -> [SIMD3<Double>] {
        var points: [SIMD3<Double>] = Geometry.cutFaceCentres(s)
        for piece in s.pieces.indices { points.append(Geometry.pieceCentre(piece, s)) }
        if let preview = Geometry.previewCentre(s) { points.append(preview) }
        let budget: Int = max(s.budget, 0)
        let slot: Double = (Geometry.markEnd - Geometry.markStart) / Double(max(budget, 1))
        let halfWidth: Double = min(Geometry.markFill * slot, Geometry.markMaxWidth) / 2
        for bar in 0..<budget {
            let c: SIMD3<Double> = Geometry.markBarCentre(bar, budget: budget)
            points.append(c + SIMD3(halfWidth, 0, 0))
            points.append(c - SIMD3(halfWidth, 0, 0))
        }
        return points
    }

    @Test func theFramingSphereHoldsTheMarkRow() throws {
        #expect(Geometry.boundingRadius == 1.65)
        for s in try Self.snapshots() {
            for p in Self.framedPoints(s) { #expect(Geometry.length(p) <= Geometry.boundingRadius, "\(p)") }
            #expect(Geometry.camera(s, aspect: 1).radius == 1.65)
        }
    }

    @Test func centresAndMarkInsideTheViewAtEveryOrbitBound() throws {
        for s in try Self.snapshots() {
            let points: [SIMD3<Double>] = Self.framedPoints(s)
            for orbit in Self.orbits {
                for aspect in Self.aspects {
                    let cam: FacetedForgeCamera = Geometry.camera(s, aspect: aspect, orbit: orbit)
                    #expect(Geometry.length(cam.eye) - cam.radius > cam.near)
                    var outside: Int = 0
                    for p in points {
                        guard let v = Geometry.project(p, camera: cam) else {
                            outside += 1
                            continue
                        }
                        if !(v.x >= 0.05 && v.x <= 0.95 && v.y >= 0.05 && v.y <= 0.95) { outside += 1 }
                    }
                    #expect(outside == 0, "orbit \(orbit) aspect \(aspect)")
                }
            }
        }
    }

    @Test func theOrbitCameraLooksFromTheOrbitDirection() throws {
        let s: Snapshot = try Self.snapshots()[0]
        for orbit in Self.orbits {
            let cam: FacetedForgeCamera = Geometry.camera(s, aspect: 1, orbit: orbit)
            let eye: SIMD3<Double> = cam.eye
            let horizontal: Double = (eye.x * eye.x + eye.z * eye.z).squareRoot()
            #expect(abs(atan2(eye.y, horizontal) - orbit.pitch) < 1e-12)
            #expect(abs(atan2(eye.x, eye.z) - orbit.yaw) < 1e-12)
            #expect(abs(Geometry.length(eye) - Geometry.length(Geometry.camera(s, aspect: 1).eye)) < 1e-12)
            #expect(cam.radius == Geometry.boundingRadius)
            let centre: SIMD2<Double>? = Geometry.project(.zero, camera: cam)
            #expect(centre != nil)
            if let centre { #expect(abs(centre.x - 0.5) < 1e-9 && abs(centre.y - 0.5) < 1e-9) }
        }
    }

    @Test func theAuthoredCameraIsTheAuthoredOrbitBitForBit() throws {
        #expect(Orbit.authored.yaw == 0)
        #expect(Orbit.authored.pitch == Geometry.pitch)
        #expect(Orbit.authored.eyeDirection == Geometry.eyeDirection)
        let aspects: [Double] = [0.4, 0.5, 0.75, 1, 1.5, 2, 2.5, 0, -1, .nan, .infinity, 20]
        for s in try Self.snapshots() {
            for aspect in aspects {
                let cam: FacetedForgeCamera = Geometry.camera(s, aspect: aspect)
                #expect(cam == Geometry.camera(s, aspect: aspect, orbit: .authored))
                // The fixed camera of R02-G08-03, rebuilt from its formula with the framing radius 1.65.
                let a: Double = Geometry.usableAspect(aspect)
                let r: Double = Geometry.boundingRadius
                let d: Double = Geometry.distance(radius: r, aspect: a)
                let eye: SIMD3<Double> = Geometry.eyeDirection * d
                let near: Double = max((d - r) * 0.5, 1e-3)
                let far: Double = d + 2 * r - Geometry.groundY + 1
                let view: Mat4 = Mat4.lookAt(eye: Vec3(eye.x, eye.y, eye.z), target: Vec3(0, 0, 0), up: Vec3(0, 1, 0))
                let projection: Mat4 = Mat4.perspective(fovY: Geometry.fieldOfView, aspect: a, near: near, far: far)
                #expect(cam.eye == eye && cam.near == near && cam.far == far && cam.aspect == a)
                #expect(cam.view == view && cam.projection == projection && cam.radius == r)
            }
        }
    }

    @Test func clampedKeepsTheOrbitBounds() {
        let limit: Double = Orbit.yawLimit
        let low: Double = Orbit.pitchRange.lowerBound
        let high: Double = Orbit.pitchRange.upperBound
        #expect(abs(limit - 40 * Double.pi / 180) < 1e-15)
        #expect(abs(low - 10 * Double.pi / 180) < 1e-15 && abs(high - 60 * Double.pi / 180) < 1e-15)
        #expect(Orbit(yaw: 2, pitch: 2).clamped() == Orbit(yaw: limit, pitch: high))
        #expect(Orbit(yaw: -2, pitch: -1).clamped() == Orbit(yaw: -limit, pitch: low))
        #expect(Orbit(yaw: 0.1, pitch: 0.5).clamped() == Orbit(yaw: 0.1, pitch: 0.5))
        #expect(Orbit(yaw: .nan, pitch: .infinity).clamped() == .authored)
        #expect(Orbit(yaw: .nan, pitch: .infinity).eyeDirection == Orbit.authored.eyeDirection)
        let far: Orbit = Orbit(yaw: 3, pitch: 1.5)
        #expect(far.eyeDirection == far.clamped().eyeDirection)
        for orbit in Self.orbits {
            let e: SIMD3<Double> = orbit.eyeDirection
            #expect(abs(Geometry.length(e) - 1) < 1e-12)
            #expect(e.y > 0 && e.z > 0)
        }
    }

    /// The four corners of the orbit bounds.
    static let corners: [Orbit] = [
        Orbit(yaw: -Orbit.yawLimit, pitch: Orbit.pitchRange.lowerBound),
        Orbit(yaw: -Orbit.yawLimit, pitch: Orbit.pitchRange.upperBound),
        Orbit(yaw: Orbit.yawLimit, pitch: Orbit.pitchRange.lowerBound),
        Orbit(yaw: Orbit.yawLimit, pitch: Orbit.pitchRange.upperBound),
    ]

    @Test func piecesAndFacesAreBackToFrontForEveryOrbitCorner() throws {
        var reordered: Int = 0
        for s in try Self.snapshots() {
            for orbit in Self.corners {
                let eye: SIMD3<Double> = orbit.eyeDirection
                let order: [Int] = Geometry.pieceOrder(s, orbit: orbit)
                #expect(order.sorted() == Array(s.pieces.indices))
                if order != Geometry.pieceOrder(s) { reordered += 1 }
                for k in 1..<max(order.count, 1) {
                    let a: Double = Geometry.dot(Geometry.pieceCentre(order[k - 1], s), eye)
                    let b: Double = Geometry.dot(Geometry.pieceCentre(order[k], s), eye)
                    #expect(a <= b + 1e-12, "orbit \(orbit)")
                }
                for piece in s.pieces {
                    let faces: [Int] = Geometry.faceOrder(piece, eye: Geometry.frame(orbit).eye)
                    #expect(faces.sorted() == Array(piece.faces.indices))
                    for k in 1..<max(faces.count, 1) {
                        let a: SIMD3<Double> = Geometry.faceCentre(piece.faces[faces[k - 1]], piece.corners) ?? .zero
                        let b: SIMD3<Double> = Geometry.faceCentre(piece.faces[faces[k]], piece.corners) ?? .zero
                        #expect(Geometry.dot(a, eye) <= Geometry.dot(b, eye) + 1e-12)
                    }
                }
            }
        }
        // The 21-piece play is drawn in another order from at least one corner than from the authored view.
        #expect(reordered > 0)
    }

    @Test func crossAndMarkFaceTheOrbitEye() throws {
        let snapshots: [Snapshot] = [try Self.sliver(), Self.snapshot(try Self.manyPieces(), time: 1)]
        for s in snapshots {
            for orbit in Self.corners {
                let frame: (eye: SIMD3<Double>, up: SIMD3<Double>, right: SIMD3<Double>) = Geometry.frame(orbit)
                #expect(frame.eye == orbit.eyeDirection)
                #expect(abs(Geometry.dot(frame.eye, frame.up)) < 1e-12)
                #expect(abs(Geometry.dot(frame.eye, frame.right)) < 1e-12)
                #expect(abs(Geometry.dot(frame.up, frame.right)) < 1e-12 && frame.up.y > 0)
                #expect(abs(Geometry.length(frame.up) - 1) < 1e-12 && abs(Geometry.length(frame.right) - 1) < 1e-12)
                // Right-handed: right × up is the direction towards the eye.
                #expect(Geometry.length(Geometry.cross(frame.right, frame.up) - frame.eye) < 1e-12)
                let m: Mesh = try Geometry.crystalMesh(s, tier: FacetedForgeTier.of(0), orbit: orbit)
                var faced: Int = 0
                for k in m.positions.indices {
                    let code: Double = m.uvs[k].x
                    guard code == FacetedForgeMaterial.sliverCross || code == FacetedForgeMaterial.spentBar
                        || code == FacetedForgeMaterial.unspentBar else { continue }
                    let n: SIMD3<Double> = SIMD3(m.normals[k].x, m.normals[k].y, m.normals[k].z)
                    #expect(Geometry.length(n - frame.eye) < 1e-12)
                    faced += 1
                }
                #expect(faced > 0)
                // Each mark bar lies in the plane through its centre facing the eye.
                let codes: [Double] = Geometry.markCodes(s)
                for k in m.positions.indices where m.uvs[k].x == FacetedForgeMaterial.spentBar
                    || m.uvs[k].x == FacetedForgeMaterial.unspentBar {
                    let p: SIMD3<Double> = SIMD3(m.positions[k].x, m.positions[k].y, m.positions[k].z)
                    var nearest: Double = .infinity
                    var height: Double = .infinity
                    for bar in 0..<codes.count {
                        let c: SIMD3<Double> = Geometry.markBarCentre(bar, budget: codes.count)
                        if Geometry.length(p - c) < nearest {
                            nearest = Geometry.length(p - c)
                            height = abs(Geometry.dot(p - c, frame.eye))
                        }
                    }
                    #expect(nearest < 0.1 && height < 1e-9)
                }
            }
        }
    }

    @Test func theAuthoredDefaultEqualsTheExplicitAuthoredOrbit() throws {
        let frame: (eye: SIMD3<Double>, up: SIMD3<Double>, right: SIMD3<Double>) = Geometry.frame(.authored)
        #expect(frame.eye == Geometry.eyeDirection && frame.up == Geometry.screenUp && frame.right == SIMD3(1, 0, 0))
        #expect(Geometry.frame(Orbit(yaw: .nan, pitch: .nan)).up == Geometry.screenUp)
        var snapshots: [Snapshot] = try Self.snapshots()
        snapshots.append(try Self.won(time: 0.2))
        for s in snapshots {
            #expect(Geometry.pieceOrder(s) == Geometry.pieceOrder(s, orbit: .authored))
            for tier in FacetedForgeTier.all {
                for reduceMotion in [false, true] {
                    let crystal: FacetedForgeColouredMesh = try Geometry.crystalPart(s, tier: tier,
                                                                                     reduceMotion: reduceMotion)
                    #expect(crystal == (try Geometry.crystalPart(s, tier: tier, reduceMotion: reduceMotion,
                                                                 orbit: .authored)))
                    #expect(crystal.mesh == (try Geometry.crystalMesh(s, tier: tier, reduceMotion: reduceMotion,
                                                                      orbit: .authored)))
                    let glow: FacetedForgeColouredMesh = try Geometry.glowPart(s, tier: tier,
                                                                               reduceMotion: reduceMotion)
                    #expect(glow == (try Geometry.glowPart(s, tier: tier, reduceMotion: reduceMotion,
                                                           orbit: .authored)))
                    #expect(glow.mesh == (try Geometry.glowMesh(s, tier: tier, reduceMotion: reduceMotion,
                                                                orbit: Self.corners[0])))
                }
            }
        }
    }
}
