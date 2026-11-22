// AmethystEscapeSceneGeometryTests — feature 363 (R02-G07-03) T-R02G0703-004 (FR-R02G0703-001, 002, 006;
// SC-R02G0703-001; clarifications Q1–Q3). The crystal geometry of Amethyst Escape built from real plays: every mesh is
// finite and bounded with one colour per vertex for the extreme settings (2 shells × 6 sectors and 5 × 12); the pearl,
// the exit arrow and every wedge top project inside the view with a 5 % margin at seven aspects 0.4 … 2.5; positions,
// tops and the camera are the same at every tier; the world sector follows the offset after a rotation; the move bar
// measures 0, half and the full length; an escaped pearl sits on the exit; a wedge failure is amber; wedges are emitted
// back to front; the 5 × 12 level-0 meshes stay under 10,000 triangles. Hand-made levels, plain loops; well under 1 s.
//
// Feature 364 (R02-G07-04) T-R02G0704-003: at the authored orbit, both yaw limits, both pitch limits and the four
// corners of the orbit bounds the pearl, the exit arrow and every wedge top project inside the view with a 5 % margin at
// the seven aspects; the authored camera is the authored orbit's camera and the camera of R02-G07-03, bit for bit;
// `AmethystEscapeOrbit.clamped()` keeps the bounds; isolating a shell keeps every position and scales exactly the other
// shells' wedge, rim, fin and cross shades (and fallback colours) by 0.25; nil isolation is the plain mesh.
//
// Feature 366 (R02-G07-06) T-R02G0706-005: the eased lights. Nil lights give the plain meshes byte for byte; lights
// settled on a snapshot give the plain crystal, and the plain glow scaled by the snapshot's targets (exactly the plain
// glow while playing); mid-fade, the failed wedge's amber shade is the wedge level (no amber at level 0, where the wedge
// keeps its blocked material), the pearl weights are the plain ones times the pearl level and the exit weights the plain
// ones times the exit level / 0.5.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
@testable import AmethystEscapeCore

@Suite struct AmethystEscapeSceneGeometryTests {
    typealias Geometry = AmethystEscapeSceneGeometry
    typealias Snapshot = AmethystEscapeSceneSnapshot

    static let aspects: [Double] = [0.4, 0.5, 0.75, 1, 1.5, 2, 2.5]

    /// The smallest setting: 2 shells × 6 sectors with an aperture pair, a wall and a blocked wedge.
    static func small(budget: Int = 10) throws -> AmethystEscapeLevel {
        try AmethystEscapeLevel(id: "geometry-2x6", seed: 1, difficulty: 1, sectors: 6,
                                shells: [AmethystEscapeShell(apertures: [0, 2], walls: [3], blocked: [4]),
                                         AmethystEscapeShell(apertures: [1], walls: [5], blocked: [2])],
                                start: 0, budget: budget)
    }

    /// The largest setting: 5 shells × 12 sectors, every shell with apertures, a wall and two blocked wedges.
    static func large() throws -> AmethystEscapeLevel {
        var shells: [AmethystEscapeShell] = []
        for k in 0..<5 {
            let apertures: [Int] = k < 4 ? [k, k + 6] : [3]
            let walls: [Int] = [(k + 2) % 12]
            let blocked: [Int] = [(k + 8) % 12, (k + 9) % 12].sorted()
            shells.append(AmethystEscapeShell(apertures: apertures, walls: walls, blocked: blocked))
        }
        return try AmethystEscapeLevel(id: "geometry-5x12", seed: 2, difficulty: 5, sectors: 12, shells: shells,
                                       start: 0, budget: 60)
    }

    /// A play of `level` begun, with `actions` applied.
    static func play(_ level: AmethystEscapeLevel, _ actions: [AmethystEscapeAction] = []) throws -> AmethystEscapePlay {
        var play = AmethystEscapePlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        for action in actions { try play.apply(action, expecting: play.fingerprint) }
        return play
    }

    /// Snapshots of both extreme settings, opening and rotated, plus an escaped and a failed play.
    static func snapshots() throws -> [Snapshot] {
        var result: [Snapshot] = []
        let s: AmethystEscapeLevel = try small()
        let l: AmethystEscapeLevel = try large()
        result.append(Snapshot(play: try play(s), levelNumber: 1, time: 0))
        result.append(Snapshot(play: try play(s, [.rotate(1, 1), .rotate(0, -1)]), levelNumber: 1, time: .infinity))
        result.append(Snapshot(play: try play(l), levelNumber: 2, time: 3))
        result.append(Snapshot(play: try play(l, [.rotate(4, 1), .rotate(2, -1), .rotate(0, 1), .advance]),
                               levelNumber: 2, time: 7))
        result.append(try escaped())
        result.append(try failed())
        return result
    }

    /// A 2 × 6 play whose pearl left through the exit gap.
    static func escaped() throws -> Snapshot {
        let level = try AmethystEscapeLevel(id: "escape", seed: 3, difficulty: 1, sectors: 6,
                                            shells: [AmethystEscapeShell(apertures: [0]),
                                                     AmethystEscapeShell(apertures: [0])],
                                            start: 0, budget: 5)
        return Snapshot(play: try play(level, [.advance, .advance]), levelNumber: 3, time: 0)
    }

    /// A 2 × 6 play whose pearl fell into the blocked wedge of shell 1, sector 0.
    static func failed() throws -> Snapshot {
        let level = try AmethystEscapeLevel(id: "wedge", seed: 4, difficulty: 1, sectors: 6,
                                            shells: [AmethystEscapeShell(apertures: [0]),
                                                     AmethystEscapeShell(apertures: [3], blocked: [0])],
                                            start: 0, budget: 5)
        return Snapshot(play: try play(level, [.advance]), levelNumber: 4, time: 0)
    }

    /// The distance between `p` and `q`.
    static func distance(_ p: Vec3, _ q: SIMD3<Double>) -> Double {
        ((p.x - q.x) * (p.x - q.x) + (p.y - q.y) * (p.y - q.y) + (p.z - q.z) * (p.z - q.z)).squareRoot()
    }

    static func parts(_ s: Snapshot, _ tier: AmethystEscapeTier) throws -> [AmethystEscapeColouredMesh] {
        [try Geometry.crystalPart(s, tier: tier), try Geometry.glowPart(s, tier: tier)]
    }

    @Test func finiteAndBoundedForExtremeSettings() throws {
        for s in try Self.snapshots() {
            let w: Double = Geometry.shellWidth(s)
            #expect(abs(w - 0.8 / Double(s.shells.count)) < 1e-12)
            for tier in AmethystEscapeTier.all {
                for (index, part) in try Self.parts(s, tier).enumerated() {
                    let m: Mesh = part.mesh
                    #expect(part.colours.count == m.positions.count)
                    #expect(m.normals.count == m.positions.count && m.uvs.count == m.positions.count)
                    #expect(m.indices.count % 3 == 0 && !m.indices.isEmpty)
                    for i in m.indices { #expect(Int(i) < m.positions.count) }
                    for k in m.positions.indices {
                        let p: Vec3 = m.positions[k]
                        let ok: Bool = p.x.isFinite && p.y.isFinite && p.z.isFinite && m.normals[k].x.isFinite
                            && m.normals[k].y.isFinite && m.normals[k].z.isFinite && m.uvs[k].x.isFinite
                            && m.uvs[k].y.isFinite
                        #expect(ok)
                        if index == 0 {
                            // The crystal lies on the backdrop square, below the tallest element.
                            #expect(abs(p.x) <= Geometry.backdropHalf + 1e-9
                                && abs(p.z) <= Geometry.backdropHalf + 1e-9)
                            #expect(p.y >= 0 && p.y <= Geometry.tallest(s) + 1e-9)
                        } else {
                            // The glow lies within its widest shell of the pearl or the exit.
                            let pearl: Double = Self.distance(p, Geometry.pearlCentre(s))
                            let exit: Double = Self.distance(p, Geometry.exitCentre(s))
                            let shells: Double = Double(tier.glowShells)
                            #expect(pearl <= Geometry.pearlRadius * w * (1 + Geometry.pearlShellGrowth * shells) + 1e-9
                                || exit <= Geometry.exitGlowRadius * (1 + shells) + 0.01)
                            #expect(p.y <= Geometry.tallest(s) + 1e-9)
                        }
                        let c: Vec4 = part.colours[k]
                        #expect(c.x >= 0 && c.x <= 1 && c.y >= 0 && c.y <= 1 && c.z >= 0 && c.z <= 1 && c.w == 1)
                    }
                }
            }
            for aspect in [0.0, -1, .nan, .infinity, 1e-9, 1e9] {
                let cam: AmethystEscapeCamera = Geometry.camera(s, aspect: aspect)
                #expect(cam.eye.x.isFinite && cam.eye.y.isFinite && cam.eye.z.isFinite && cam.near > 0)
                #expect(Geometry.project(SIMD3(0, 0, 0), camera: cam) != nil)
                #expect(cam.viewProjection.floats.count == 16)
            }
            #expect(Geometry.camera(s, aspect: .nan) == Geometry.camera(s, aspect: 1))
            #expect(Geometry.project(SIMD3(.nan, 0, 0), camera: Geometry.camera(s, aspect: 1)) == nil)
        }
    }

    @Test func pearlExitAndWedgeTopsInsideTheViewAtSevenAspects() throws {
        for s in try Self.snapshots() {
            var points: [SIMD3<Double>] = [Geometry.pearlCentre(s), Geometry.exitCentre(s)]
            for shell in s.shells.indices {
                for sector in 0..<s.sectors {
                    points.append(Geometry.wedgeTopCentre(shell: shell, sector: sector, s))
                }
            }
            for aspect in Self.aspects {
                let cam: AmethystEscapeCamera = Geometry.camera(s, aspect: aspect)
                for p in points {
                    let v: SIMD2<Double>? = Geometry.project(p, camera: cam)
                    #expect(v != nil)
                    guard let v else { continue }
                    #expect(v.x >= 0.05 && v.x <= 0.95 && v.y >= 0.05 && v.y <= 0.95)
                }
                // The move bar's ends stay in view too.
                for x in [Geometry.moveBarStart, Geometry.moveBarStart + Geometry.moveBarFull] {
                    let v: SIMD2<Double>? = Geometry.project(SIMD3(x, Geometry.moveBarLift, Geometry.moveBarZ),
                                                             camera: cam)
                    #expect(v.map { $0.x >= 0 && $0.x <= 1 && $0.y >= 0 && $0.y <= 1 } == true)
                }
            }
        }
    }

    @Test func samePositionsAtEveryTier() throws {
        for s in try Self.snapshots() {
            var tops: [[Vec3]] = []
            for tier in AmethystEscapeTier.all {
                let crystal: Mesh = try Geometry.crystalMesh(s, tier: tier)
                // The flat wedge tops (up normals on wedge materials) are the same vertices at every tier.
                var top: [Vec3] = []
                for k in crystal.positions.indices where abs(crystal.normals[k].y - 1) < 1e-9
                    && [Geometry.amethystCode, Geometry.blockedCode, Geometry.amberCode].contains(crystal.uvs[k].x) {
                    top.append(crystal.positions[k])
                }
                tops.append(top)
                // The pearl core is the last sphere of the glow mesh at every tier.
                let glow: Mesh = try Geometry.glowMesh(s, tier: tier)
                let core: [Vec3] = Array(glow.positions.suffix(4))
                let centre: SIMD3<Double> = Geometry.pearlCentre(s)
                for p in core {
                    let d: Double = ((p.x - centre.x) * (p.x - centre.x) + (p.y - centre.y) * (p.y - centre.y)
                        + (p.z - centre.z) * (p.z - centre.z)).squareRoot()
                    #expect(abs(d - Geometry.pearlRadius * Geometry.shellWidth(s)) < 1e-9)
                }
            }
            #expect(!tops[0].isEmpty)
            #expect(tops[0] == tops[1] && tops[1] == tops[2])
            for aspect in Self.aspects {
                #expect(Geometry.camera(s, aspect: aspect).viewProjection.floats
                    == Geometry.camera(s, aspect: aspect).viewProjection.floats)
            }
            // Richer tiers have more bevel bands and glow shells, never fewer triangles.
            let counts: [Int] = try AmethystEscapeTier.all.map { try Geometry.crystalMesh(s, tier: $0).indices.count }
            #expect(counts[0] > counts[1] && counts[1] > counts[2])
            let glow: [Int] = try AmethystEscapeTier.all.map { try Geometry.glowMesh(s, tier: $0).indices.count }
            #expect(glow[0] > glow[1] && glow[1] > glow[2])
        }
    }

    @Test func worldSectorFollowsTheOffsetAfterARotation() throws {
        let level: AmethystEscapeLevel = try Self.small()
        let before = Snapshot(play: try Self.play(level), levelNumber: 1, time: 0)
        let after = Snapshot(play: try Self.play(level, [.rotate(1, 1)]), levelNumber: 1, time: 0)
        let back = Snapshot(play: try Self.play(level, [.rotate(0, -1)]), levelNumber: 1, time: 0)
        for sector in 0..<6 {
            #expect(Geometry.worldSector(shell: 1, sector: sector, before) == sector)
            #expect(Geometry.worldSector(shell: 1, sector: sector, after) == (sector + 1) % 6)
            #expect(Geometry.worldSector(shell: 0, sector: sector, after) == sector)
            #expect(Geometry.worldSector(shell: 0, sector: sector, back) == (sector + 5) % 6)
            // The wedge top turns with it: after the rotation own sector s sits where s + 1 sat before.
            let moved: SIMD3<Double> = Geometry.wedgeTopCentre(shell: 1, sector: sector, after)
            let target: SIMD3<Double> = Geometry.wedgeTopCentre(shell: 1, sector: (sector + 1) % 6, before)
            #expect(abs(moved.x - target.x) < 1e-12 && abs(moved.y - target.y) < 1e-12 && abs(moved.z - target.z) < 1e-12)
        }
        // Angles run from +x towards +z: world sector 0's middle has positive x and z.
        let top: SIMD3<Double> = Geometry.wedgeTopCentre(shell: 0, sector: 0, before)
        #expect(top.x > 0 && top.z > 0)
        #expect(abs(top.y - Geometry.shellHeight(0, before)) < 1e-12)
        #expect(abs(Geometry.shellHeight(0, before) - 0.14) < 1e-12 && abs(Geometry.shellHeight(1, before) - 0.08) < 1e-12)
        // The exit follows the outer offset.
        #expect(after.exitGap == 2 && before.exitGap == 1)
        let exit: SIMD3<Double> = Geometry.exitCentre(after)
        let angle: Double = 2 * Double.pi * 2.5 / 6
        #expect(abs(exit.x - 1.06 * cos(angle)) < 1e-12 && abs(exit.z - 1.06 * sin(angle)) < 1e-12)
    }

    @Test func moveBarLengthAtZeroHalfAndTheBudget() throws {
        let level: AmethystEscapeLevel = try Self.small(budget: 4)
        let spin: AmethystEscapeAction = .rotate(1, 1)
        let zero = Snapshot(play: try Self.play(level), levelNumber: 1, time: 0)
        let half = Snapshot(play: try Self.play(level, [spin, spin]), levelNumber: 1, time: 0)
        let full = Snapshot(play: try Self.play(level, [spin, spin, spin, spin]), levelNumber: 1, time: 0)
        #expect(Geometry.moveBarLength(zero) == 0)
        #expect(abs(Geometry.moveBarLength(half) - 0.8) < 1e-12)
        #expect(abs(Geometry.moveBarLength(full) - 1.6) < 1e-12)
        #expect(full.failure == .budget)
        // The bar's vertices reach x = −0.8 + length at z = 1.02 ± 0.015.
        for (s, length) in [(half, 0.8), (full, 1.6)] {
            let m: Mesh = try Geometry.crystalMesh(s, tier: .of(2))
            let bar: [Vec3] = m.positions.filter { abs($0.y - Geometry.moveBarLift) < 1e-12 }
            #expect(bar.count == 4)
            #expect(abs((bar.map(\.x).max() ?? 0) - (-0.8 + length)) < 1e-12)
            #expect(abs((bar.map(\.x).min() ?? 0) + 0.8) < 1e-12)
            #expect(bar.allSatisfy { abs($0.z - 1.02) <= 0.015 + 1e-12 })
        }
        let none: Mesh = try Geometry.crystalMesh(zero, tier: .of(2))
        #expect(none.positions.allSatisfy { abs($0.y - Geometry.moveBarLift) > 1e-12 })
    }

    @Test func escapedPearlSitsOnTheExitAndAFailedWedgeIsAmber() throws {
        let won: Snapshot = try Self.escaped()
        #expect(won.escaped)
        #expect(Geometry.pearlCentre(won) == Geometry.exitCentre(won))
        let lost: Snapshot = try Self.failed()
        #expect(lost.failure == .wedge(1, 0))
        let w: Double = Geometry.shellWidth(lost)
        let pearl: SIMD3<Double> = Geometry.pearlCentre(lost)
        let pocket: SIMD3<Double> = Geometry.wedgeTopCentre(shell: 1, sector: 0, lost)
        #expect(abs(pearl.x - pocket.x) < 1e-12 && abs(pearl.z - pocket.z) < 1e-12)
        #expect(abs(pearl.y - (Geometry.shellHeight(1, lost) + 0.3 * w)) < 1e-12)
        let m: Mesh = try Geometry.crystalMesh(lost, tier: .of(0))
        let amber: [Vec3] = m.positions.indices.filter { m.uvs[$0].x == Geometry.amberCode }.map { m.positions[$0] }
        #expect(!amber.isEmpty)
        let span: Double = 2 * Double.pi / 6
        for p in amber {
            var angle: Double = atan2(p.z, p.x)
            if angle < 0 { angle += 2 * Double.pi }
            #expect(angle >= 0 && angle <= span)
            let r: Double = (p.x * p.x + p.z * p.z).squareRoot()
            #expect(r >= 0.6 - 1e-9 && r <= 1.0 + 1e-9)
        }
        let open: Mesh = try Geometry.crystalMesh(Snapshot(play: try Self.play(try Self.small()), levelNumber: 1,
                                                           time: 0), tier: .of(0))
        #expect(!open.uvs.contains { $0.x == Geometry.amberCode })
    }

    @Test func wedgesAreEmittedBackToFront() throws {
        for s in try Self.snapshots() {
            let order: [AmethystEscapeWedge] = Geometry.wedgeOrder(s)
            #expect(order.count == s.shells.count * s.sectors)
            for i in 1..<order.count {
                let a: SIMD3<Double> = Geometry.wedgeTopCentre(shell: order[i - 1].shell, sector: order[i - 1].sector, s)
                let b: SIMD3<Double> = Geometry.wedgeTopCentre(shell: order[i].shell, sector: order[i].sector, s)
                #expect(a.z < b.z - 1e-12 || (abs(a.z - b.z) <= 1e-12 && a.y <= b.y + 1e-12))
            }
            // In the mesh, each wedge's first top-cap triangle follows the previous wedge's.
            let m: Mesh = try Geometry.crystalMesh(s, tier: .of(0))
            let span: Double = 2 * Double.pi / Double(s.sectors)
            var first: [AmethystEscapeWedge: Int] = [:]
            var t: Int = 0
            while t < m.indices.count {
                let ids: [Int] = [Int(m.indices[t]), Int(m.indices[t + 1]), Int(m.indices[t + 2])]
                defer { t += 3 }
                guard ids.allSatisfy({ abs(m.normals[$0].y - 1) < 1e-9 && m.uvs[$0].x >= 1 && m.uvs[$0].x != 2 })
                else { continue }
                let y: Double = m.positions[ids[0]].y
                guard let shell = s.shells.indices.first(where: { abs(Geometry.shellHeight($0, s) - y) < 1e-9 }),
                      ids.allSatisfy({ abs(m.positions[$0].y - y) < 1e-12 }) else { continue }
                let cx: Double = ids.map { m.positions[$0].x }.reduce(0, +) / 3
                let cz: Double = ids.map { m.positions[$0].z }.reduce(0, +) / 3
                var angle: Double = atan2(cz, cx)
                if angle < 0 { angle += 2 * Double.pi }
                let world: Int = Int(angle / span) % s.sectors
                guard let wedge = order.first(where: { $0.shell == shell && $0.world == world }) else { continue }
                if first[wedge] == nil { first[wedge] = t }
            }
            #expect(first.count == order.count)
            let positions: [Int] = order.compactMap { first[$0] }
            #expect(positions == positions.sorted())
        }
    }

    @Test func largestSettingStaysWithinTheTriangleBudget() throws {
        let s = Snapshot(play: try Self.play(try Self.large()), levelNumber: 2, time: 0)
        let crystal: Mesh = try Geometry.crystalMesh(s, tier: .of(0))
        let glow: Mesh = try Geometry.glowMesh(s, tier: .of(0))
        #expect((crystal.indices.count + glow.indices.count) / 3 < 10_000)
    }

    // MARK: Orbit (feature 364)

    typealias Orbit = AmethystEscapeOrbit

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

    @Test func pearlExitAndWedgeTopsInsideTheViewAtEveryOrbitBound() throws {
        for s in try Self.snapshots() {
            var points: [SIMD3<Double>] = [Geometry.pearlCentre(s), Geometry.exitCentre(s)]
            for shell in s.shells.indices {
                for sector in 0..<s.sectors {
                    points.append(Geometry.wedgeTopCentre(shell: shell, sector: sector, s))
                }
            }
            for orbit in Self.orbits {
                for aspect in Self.aspects {
                    let cam: AmethystEscapeCamera = Geometry.camera(s, aspect: aspect, orbit: orbit)
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
            let cam: AmethystEscapeCamera = Geometry.camera(s, aspect: 1, orbit: orbit)
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
                let cam: AmethystEscapeCamera = Geometry.camera(s, aspect: aspect)
                #expect(cam == Geometry.camera(s, aspect: aspect, orbit: .authored))
                // The fixed camera of R02-G07-03, rebuilt from its formula.
                let a: Double = Geometry.usableAspect(aspect)
                let d: Double = Geometry.distance(radius: Geometry.boundingRadius, aspect: a)
                let eye: SIMD3<Double> = Geometry.eyeDirection * d
                let near: Double = max((d - Geometry.boundingRadius) * 0.5, 1e-3)
                let far: Double = d + 2 * Geometry.boundingRadius + 1
                let view: Mat4 = Mat4.lookAt(eye: Vec3(eye.x, eye.y, eye.z), target: Vec3(0, 0, 0), up: Vec3(0, 1, 0))
                let projection: Mat4 = Mat4.perspective(fovY: Geometry.fieldOfView, aspect: a, near: near, far: far)
                #expect(cam.eye == eye && cam.near == near && cam.far == far && cam.aspect == a)
                #expect(cam.view == view && cam.projection == projection)
                #expect(cam.viewProjection.floats == (projection * view).floats)
            }
        }
    }

    @Test func clampedKeepsTheOrbitBounds() {
        let degree: Double = Double.pi / 180
        #expect(abs(Orbit.yawLimit - 40 * degree) < 1e-15)
        #expect(abs(Orbit.pitchRange.lowerBound - 30 * degree) < 1e-15)
        #expect(abs(Orbit.pitchRange.upperBound - 75 * degree) < 1e-15)
        #expect(abs(Orbit.authored.pitch - 50 * degree) < 1e-15)
        #expect(Orbit.authored.clamped() == .authored)
        let inside: Orbit = Orbit(yaw: 10 * degree, pitch: 35 * degree)
        #expect(inside.clamped() == inside)
        let low: Orbit = Orbit(yaw: -3, pitch: -1).clamped()
        #expect(low.yaw == -Orbit.yawLimit && low.pitch == Orbit.pitchRange.lowerBound)
        let high: Orbit = Orbit(yaw: 3, pitch: 2).clamped()
        #expect(high.yaw == Orbit.yawLimit && high.pitch == Orbit.pitchRange.upperBound)
        let odd: [Double] = [.nan, .infinity, -.infinity]
        for value in odd {
            #expect(Orbit(yaw: value, pitch: value).clamped() == .authored)
            let yawOnly: Orbit = Orbit(yaw: value, pitch: 35 * degree).clamped()
            #expect(yawOnly.yaw == 0 && yawOnly.pitch == 35 * degree)
        }
        for orbit in Self.orbits {
            let e: SIMD3<Double> = orbit.eyeDirection
            #expect(abs(Geometry.length(e) - 1) < 1e-12)
            #expect(e.y > 0 && e.z > 0)
        }
        #expect(Orbit(yaw: 3, pitch: 2).eyeDirection == high.eyeDirection)
    }

    // MARK: Isolation (feature 364)

    /// The mesh as a triangle soup: for every index, its vertex's position, uv and colour.
    static func soup(_ part: AmethystEscapeColouredMesh) -> [(position: Vec3, uv: Vec2, colour: Vec4)] {
        var result: [(position: Vec3, uv: Vec2, colour: Vec4)] = []
        for i in part.mesh.indices {
            let k: Int = Int(i)
            result.append((part.mesh.positions[k], part.mesh.uvs[k], part.colours[k]))
        }
        return result
    }

    @Test func nilIsolationIsThePlainMesh() throws {
        for s in try Self.snapshots() {
            for tier in AmethystEscapeTier.all {
                let plain: AmethystEscapeColouredMesh = try Geometry.crystalPart(s, tier: tier)
                #expect(try Geometry.crystalPart(s, tier: tier, isolated: nil) == plain)
                #expect(try Geometry.crystalPart(s, tier: tier, isolated: -1) == plain)
                #expect(try Geometry.crystalPart(s, tier: tier, isolated: s.shells.count) == plain)
                #expect(try Geometry.crystalMesh(s, tier: tier, isolated: nil) == plain.mesh)
                #expect(try Geometry.crystalMesh(s, tier: tier) == plain.mesh)
            }
        }
    }

    @Test func isolationDimsOnlyTheOtherShells() throws {
        for s in try Self.snapshots() {
            let n: Int = s.shells.count
            let w: Double = 0.8 / Double(n)
            let tier: AmethystEscapeTier = .of(1)
            let plain: [(position: Vec3, uv: Vec2, colour: Vec4)] = Self.soup(try Geometry.crystalPart(s, tier: tier))
            for isolated in 0..<n {
                let part: AmethystEscapeColouredMesh = try Geometry.crystalPart(s, tier: tier, isolated: isolated)
                #expect(try Geometry.crystalMesh(s, tier: tier, isolated: isolated) == part.mesh)
                let dimmed: [(position: Vec3, uv: Vec2, colour: Vec4)] = Self.soup(part)
                #expect(dimmed.count == plain.count)
                guard dimmed.count == plain.count else { continue }
                var dark: Int = 0, kept: Int = 0
                for t in stride(from: 0, to: plain.count, by: 3) {
                    // The triangle's shell: every vertex within 0.001 of the shell's annulus (the backdrop is code 0;
                    // the exit arrow and the move bar lie beyond every shell). A fin's end cap on the boundary of
                    // shells k and k + 1 belongs to k when it rises above shell k + 1's fins (h_(k+1) + 0.02).
                    var low: Double = .infinity, high: Double = 0, top: Double = 0
                    for j in 0..<3 {
                        let p: Vec3 = plain[t + j].position
                        let radial: Double = (p.x * p.x + p.z * p.z).squareRoot()
                        low = min(low, radial)
                        high = max(high, radial)
                        top = max(top, p.y)
                    }
                    var candidates: [Int] = []
                    if plain[t].uv.x != Geometry.backdropCode {
                        for k in 0..<n {
                            let r0: Double = 0.2 + Double(k) * w
                            if low >= r0 - 1e-3 && high <= r0 + w + 1e-3 { candidates.append(k) }
                        }
                    }
                    var owner: Int = candidates.first ?? -1
                    if candidates.count == 2 {
                        let k: Int = candidates[0]
                        let outerFin: Double = 0.08 + 0.06 * Double(n - 2 - k) + 0.02
                        owner = top > outerFin + 1e-9 ? k : k + 1
                    }
                    #expect(candidates.count <= 2)
                    let factor: Double = owner >= 0 && owner != isolated ? 0.25 : 1
                    if factor < 1 { dark += 1 } else { kept += 1 }
                    for j in 0..<3 {
                        let a: (position: Vec3, uv: Vec2, colour: Vec4) = plain[t + j]
                        let b: (position: Vec3, uv: Vec2, colour: Vec4) = dimmed[t + j]
                        // Equal up to the builder's 1e-9 weld grid (a vertex shared across shells may weld only
                        // without isolation).
                        #expect(abs(a.position.x - b.position.x) < 1e-8 && abs(a.position.y - b.position.y) < 1e-8
                            && abs(a.position.z - b.position.z) < 1e-8)
                        #expect(a.uv.x == b.uv.x)
                        #expect(b.uv.y == a.uv.y * factor)
                        #expect(abs(b.colour.x - a.colour.x * factor) < 1e-12
                            && abs(b.colour.y - a.colour.y * factor) < 1e-12
                            && abs(b.colour.z - a.colour.z * factor) < 1e-12 && b.colour.w == 1)
                    }
                }
                #expect(dark > 0 && kept > 0)
            }
            // The glow (pearl and exit) never changes with isolation: it has no isolation parameter.
        }
    }

    // MARK: Eased lights (feature 366)

    /// The glow vertices of `part` whose colour slot is `colour` (pearl or exit), as (position, weight) pairs.
    static func glowWeights(_ part: AmethystEscapeColouredMesh,
                            colour: SIMD3<Double>) -> [(position: Vec3, weight: Double)] {
        var result: [(position: Vec3, weight: Double)] = []
        for k in part.mesh.positions.indices {
            let n: Vec3 = part.mesh.normals[k]
            if abs(n.x - colour.x) < 1e-12 && abs(n.y - colour.y) < 1e-12 && abs(n.z - colour.z) < 1e-12 {
                result.append((part.mesh.positions[k], part.mesh.uvs[k].x))
            }
        }
        return result
    }

    /// Checks that `lit`'s `colour` glow weights are `plain`'s times `factor` (clamped to 0 … 1), at the same places.
    static func expectScaled(_ lit: AmethystEscapeColouredMesh, _ plain: AmethystEscapeColouredMesh,
                             colour: SIMD3<Double>, factor: Double) {
        let a: [(position: Vec3, weight: Double)] = glowWeights(plain, colour: colour)
        let b: [(position: Vec3, weight: Double)] = glowWeights(lit, colour: colour)
        #expect(a.count == b.count && !a.isEmpty)
        for i in 0..<min(a.count, b.count) {
            #expect(a[i].position == b[i].position)
            #expect(abs(b[i].weight - min(max(a[i].weight * factor, 0), 1)) < 1e-12)
        }
    }

    @Test func nilLightsAreThePlainMeshes() throws {
        for s in try Self.snapshots() {
            for tier in AmethystEscapeTier.all {
                let crystal: AmethystEscapeColouredMesh = try Geometry.crystalPart(s, tier: tier)
                #expect(try Geometry.crystalPart(s, tier: tier, lights: nil) == crystal)
                #expect(try Geometry.crystalPart(s, tier: tier, isolated: 0, lights: nil)
                    == Geometry.crystalPart(s, tier: tier, isolated: 0))
                #expect(try Geometry.crystalMesh(s, tier: tier, lights: nil) == crystal.mesh)
                let glow: AmethystEscapeColouredMesh = try Geometry.glowPart(s, tier: tier)
                #expect(try Geometry.glowPart(s, tier: tier, lights: nil) == glow)
                #expect(try Geometry.glowMesh(s, tier: tier, lights: nil) == glow.mesh)
            }
        }
    }

    @Test func settledLightsDrawTheSnapshotsTargets() throws {
        for s in try Self.snapshots() {
            var lights = AmethystEscapeLights(reducedFlash: false)
            lights.settle(to: s)
            #expect(lights.isSettled)
            for tier in AmethystEscapeTier.all {
                // The crystal: the failed wedge rests at full amber, exactly the plain mesh.
                #expect(try Geometry.crystalPart(s, tier: tier, lights: lights) == Geometry.crystalPart(s, tier: tier))
                let plain: AmethystEscapeColouredMesh = try Geometry.glowPart(s, tier: tier)
                let lit: AmethystEscapeColouredMesh = try Geometry.glowPart(s, tier: tier, lights: lights)
                if s.failure == nil && !s.escaped {
                    #expect(lit == plain)
                } else {
                    #expect(lit.mesh.positions == plain.mesh.positions && lit.mesh.indices == plain.mesh.indices)
                    Self.expectScaled(lit, plain, colour: AmethystEscapePalette.pearl,
                                      factor: s.failure == nil ? 1 : AmethystEscapeLights.pearlFailed)
                    if tier.glowShells > 0 {
                        Self.expectScaled(lit, plain, colour: AmethystEscapePalette.exit,
                                          factor: s.escaped ? AmethystEscapeLights.exitEscaped / 0.5 : 1)
                    }
                }
            }
        }
    }

    @Test func midFadeLevelsScaleTheWedgeThePearlAndTheExit() throws {
        // The wedge failure, a third of the way through its 0.15 s fade.
        let failed: Snapshot = try Self.failed()
        let level = try AmethystEscapeLevel(id: "wedge", seed: 4, difficulty: 1, sectors: 6,
                                            shells: [AmethystEscapeShell(apertures: [0]),
                                                     AmethystEscapeShell(apertures: [3], blocked: [0])],
                                            start: 0, budget: 5)
        let before: Snapshot = Snapshot(play: try Self.play(level), levelNumber: 4, time: 0)
        var lights = AmethystEscapeLights(reducedFlash: false)
        lights.settle(to: before)
        lights.step(toward: failed, elapsed: 0.05)
        #expect(lights.wedge > 0 && lights.wedge < 1 && lights.pearl < 1 && lights.pearl > 0.6)
        let tier: AmethystEscapeTier = .of(0)
        let plain: [(position: Vec3, uv: Vec2, colour: Vec4)] = Self.soup(try Geometry.crystalPart(failed, tier: tier))
        let lit: [(position: Vec3, uv: Vec2, colour: Vec4)] =
            Self.soup(try Geometry.crystalPart(failed, tier: tier, lights: lights))
        #expect(plain.count == lit.count)
        var amber: Int = 0
        for i in 0..<min(plain.count, lit.count) {
            #expect(plain[i].position == lit[i].position && plain[i].uv.x == lit[i].uv.x)
            if plain[i].uv.x == Geometry.amberCode {
                amber += 1
                #expect(abs(lit[i].uv.y - plain[i].uv.y * lights.wedge) < 1e-12)
            } else {
                #expect(lit[i].uv.y == plain[i].uv.y && lit[i].colour == plain[i].colour)
            }
        }
        #expect(amber > 0)
        let glowPlain: AmethystEscapeColouredMesh = try Geometry.glowPart(failed, tier: tier)
        let glowLit: AmethystEscapeColouredMesh = try Geometry.glowPart(failed, tier: tier, lights: lights)
        Self.expectScaled(glowLit, glowPlain, colour: AmethystEscapePalette.pearl, factor: lights.pearl)
        Self.expectScaled(glowLit, glowPlain, colour: AmethystEscapePalette.exit, factor: 1)
        // At wedge level 0 (the fade not yet begun) the failed wedge keeps its blocked material.
        var dark = AmethystEscapeLights(reducedFlash: true)
        dark.settle(to: before)
        dark.step(toward: failed, elapsed: 0)
        #expect(dark.wedge == 0)
        let unlit: [(position: Vec3, uv: Vec2, colour: Vec4)] =
            Self.soup(try Geometry.crystalPart(failed, tier: tier, lights: dark))
        #expect(!unlit.contains { $0.uv.x == Geometry.amberCode })
        let blockedPlain: Int = plain.filter { $0.uv.x == Geometry.blockedCode }.count
        #expect(unlit.filter { $0.uv.x == Geometry.blockedCode }.count == blockedPlain + amber)
        // The escape, a third of the way through the exit's fade from 0.5 to 1.
        let escaped: Snapshot = try Self.escaped()
        let open = try AmethystEscapeLevel(id: "escape", seed: 3, difficulty: 1, sectors: 6,
                                           shells: [AmethystEscapeShell(apertures: [0]),
                                                    AmethystEscapeShell(apertures: [0])],
                                           start: 0, budget: 5)
        var exitLights = AmethystEscapeLights(reducedFlash: false)
        exitLights.settle(to: Snapshot(play: try Self.play(open, [.advance]), levelNumber: 3, time: 0))
        exitLights.step(toward: escaped, elapsed: 0.05)
        #expect(exitLights.exit > 0.5 && exitLights.exit < 1)
        let exitPlain: AmethystEscapeColouredMesh = try Geometry.glowPart(escaped, tier: tier)
        let exitLit: AmethystEscapeColouredMesh = try Geometry.glowPart(escaped, tier: tier, lights: exitLights)
        Self.expectScaled(exitLit, exitPlain, colour: AmethystEscapePalette.exit, factor: exitLights.exit / 0.5)
        Self.expectScaled(exitLit, exitPlain, colour: AmethystEscapePalette.pearl, factor: 1)
    }
}
