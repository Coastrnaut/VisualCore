// ColorfallCanyonsPickerTests — feature 344 (R02-G05-04) T-R02G0504-002 (FR-R02G0504-003, 004; SC-R02G0504-001;
// clarification "How is a touch picked?"). The analytic picker against an independent pick written here: the same
// ray (only `ColorfallCanyonsPicker.ray` is shared), its own plane and face intersections for block tops and emitter
// boxes, and its own 22-point fallback, on 500 seeded points (seed 2_344) per certified level, view size and orbit
// (authored and the four bound corners); a touch beside the grid falls back to the nearest target within 22 points; a
// cell hidden behind a taller nearer block resolves to the nearer block; non-finite input picks nothing. Plain loops
// and explicit types (CI type-check rule).
import Foundation
import Testing
@testable import ColorfallCanyonsCore
import VisualCoreMath
import VisualCoreScenes

@Suite struct ColorfallCanyonsPickerTests {
    typealias Geometry = ColorfallCanyonsSceneGeometry
    typealias Snapshot = ColorfallCanyonsSceneSnapshot
    typealias Picker = ColorfallCanyonsPicker

    /// The view sizes in points: phone portrait and landscape, tablet portrait.
    static let sizes: [SIMD2<Double>] = [SIMD2(390, 844), SIMD2(844, 390), SIMD2(1_024, 1_366)]

    /// The authored orbit and the four corners of the orbit bounds.
    static let orbits: [ColorfallCanyonsOrbit] = [
        .authored,
        ColorfallCanyonsOrbit(yaw: -ColorfallCanyonsOrbit.yawLimit, pitch: ColorfallCanyonsOrbit.pitchRange.lowerBound),
        ColorfallCanyonsOrbit(yaw: -ColorfallCanyonsOrbit.yawLimit, pitch: ColorfallCanyonsOrbit.pitchRange.upperBound),
        ColorfallCanyonsOrbit(yaw: ColorfallCanyonsOrbit.yawLimit, pitch: ColorfallCanyonsOrbit.pitchRange.lowerBound),
        ColorfallCanyonsOrbit(yaw: ColorfallCanyonsOrbit.yawLimit, pitch: ColorfallCanyonsOrbit.pitchRange.upperBound),
    ]

    /// A snapshot of `level` begun (tutorial dismissed), every closed valve opened and `ticks` stepped.
    static func snapshot(_ level: ColorfallCanyonsLevel, ticks: Int) throws -> Snapshot {
        var play: ColorfallCanyonsPlay = ColorfallCanyonsPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        var actions: [ColorfallCanyonsAction] = []
        for (index, spring) in level.springs.enumerated() where !spring.open { actions.append(.valve(index)) }
        if ticks > 0 { actions.append(.step(ticks)) }
        for action in actions where play.stage == .playing {
            try? play.apply(action, expecting: play.fingerprint)
        }
        return Snapshot(play: play, levelNumber: 1, time: 0)
    }

    /// Snapshots of the first three certified catalog levels (generated from the manifest), valves opened, 20 ticks.
    static func certifiedSnapshots() throws -> [Snapshot] {
        var result: [Snapshot] = []
        for number in 0..<3 {
            let generated: ColorfallCanyonsGenerated =
                try ColorfallCanyonsGenerator.generate(ColorfallCanyonsManifest.entries[number])
            result.append(try snapshot(generated.level, ticks: 20))
        }
        return result
    }

    /// The entry distance (> 0) of the ray `origin` + t·`direction` into the horizontal square of half-size `half`
    /// about (`centre.x`, `y`, `centre.z`), by the plane equation; nil when it misses.
    static func square(origin: SIMD3<Double>, direction: SIMD3<Double>, centre: SIMD3<Double>, half: Double,
                       y: Double) -> Double? {
        guard abs(direction.y) > 1e-15 else { return nil }
        let t: Double = (y - origin.y) / direction.y
        guard t > 0 else { return nil }
        let p: SIMD3<Double> = origin + direction * t
        guard abs(p.x - centre.x) <= half + 1e-12, abs(p.z - centre.z) <= half + 1e-12 else { return nil }
        return t
    }

    /// The smallest distance (> 0) at which the ray meets a face of the box of half-width `half` about `centre`'s x and
    /// z from y `bottom` to `top`: its top, bottom and four vertical sides intersected one by one; nil when it misses.
    static func box(origin: SIMD3<Double>, direction: SIMD3<Double>, centre: SIMD3<Double>, half: Double,
                    bottom: Double, top: Double) -> Double? {
        var best: Double?
        for y in [bottom, top] {
            if let t = square(origin: origin, direction: direction, centre: centre, half: half, y: y) {
                if best == nil || t < best! { best = t }
            }
        }
        // Sides x = centre.x ± half (z and y inside) and z = centre.z ± half (x and y inside).
        for sign in [-1.0, 1.0] {
            if abs(direction.x) > 1e-15 {
                let t: Double = (centre.x + sign * half - origin.x) / direction.x
                let p: SIMD3<Double> = origin + direction * t
                if t > 0, abs(p.z - centre.z) <= half + 1e-12, p.y >= bottom - 1e-12, p.y <= top + 1e-12 {
                    if best == nil || t < best! { best = t }
                }
            }
            if abs(direction.z) > 1e-15 {
                let t: Double = (centre.z + sign * half - origin.z) / direction.z
                let p: SIMD3<Double> = origin + direction * t
                if t > 0, abs(p.x - centre.x) <= half + 1e-12, p.y >= bottom - 1e-12, p.y <= top + 1e-12 {
                    if best == nil || t < best! { best = t }
                }
            }
        }
        return best
    }

    /// The smallest spring index on `cell`, or nil.
    static func springOn(_ cell: Int, _ snapshot: Snapshot) -> Int? {
        for s in 0..<snapshot.springs.count where snapshot.springs[s].cell == cell { return s }
        return nil
    }

    /// The pick a hit on (or a target at) `cell`'s top means: its smallest spring, else the cell.
    static func pickOf(_ cell: Int, _ snapshot: Snapshot) -> ColorfallCanyonsPick {
        if let s = springOn(cell, snapshot) { return .spring(s) }
        return .cell(cell)
    }

    /// Every hit of the ray: (distance, pick) for each block top and emitter box it meets.
    static func hits(origin: SIMD3<Double>, direction: SIMD3<Double>,
                     _ snapshot: Snapshot) -> [(t: Double, pick: ColorfallCanyonsPick)] {
        let u: Double = Geometry.cellSize(snapshot)
        var result: [(t: Double, pick: ColorfallCanyonsPick)] = []
        for cell in 0..<snapshot.cellCount {
            let top: SIMD3<Double> = Geometry.cellTop(cell, snapshot)
            if let t = square(origin: origin, direction: direction, centre: top, half: u / 2, y: top.y) {
                let pick: ColorfallCanyonsPick = pickOf(cell, snapshot)
                result.append((t, pick))
            }
        }
        for s in 0..<snapshot.springs.count {
            let base: SIMD3<Double> = Geometry.cellTop(snapshot.springs[s].cell, snapshot)
            let topY: Double = base.y + 0.6 * u
            if let t = box(origin: origin, direction: direction, centre: base, half: 0.18 * u, bottom: base.y,
                           top: topY) {
                result.append((t, .spring(s)))
            }
        }
        return result
    }

    /// The independent pick of `point`: the nearest hit, else the nearest projected cell top centre or emitter top
    /// within 22 points, else empty.
    static func expected(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: Snapshot,
                         orbit: ColorfallCanyonsOrbit) -> ColorfallCanyonsPick {
        let camera: ColorfallCanyonsCamera = Geometry.camera(snapshot, aspect: size.x / size.y, orbit: orbit)
        guard let r = Picker.ray(point, size: size, camera: camera) else { return .empty }
        var bestT: Double = .infinity
        var best: ColorfallCanyonsPick = .empty
        for hit in hits(origin: r.origin, direction: r.direction, snapshot) where hit.t < bestT {
            bestT = hit.t
            best = hit.pick
        }
        if best != .empty { return best }
        var targets: [(world: SIMD3<Double>, pick: ColorfallCanyonsPick)] = []
        for cell in 0..<snapshot.cellCount {
            let pick: ColorfallCanyonsPick = pickOf(cell, snapshot)
            targets.append((Geometry.cellTop(cell, snapshot), pick))
        }
        for s in 0..<snapshot.springs.count {
            let base: SIMD3<Double> = Geometry.cellTop(snapshot.springs[s].cell, snapshot)
            targets.append((base + SIMD3(0, 0.6 * Geometry.cellSize(snapshot), 0), .spring(s)))
        }
        var bestD: Double = .infinity
        for target in targets {
            guard let v = Geometry.project(target.world, camera: camera) else { continue }
            let d: Double = ((v.x * size.x - point.x) * (v.x * size.x - point.x)
                + (v.y * size.y - point.y) * (v.y * size.y - point.y)).squareRoot()
            if d <= 22, d < bestD {
                bestD = d
                best = target.pick
            }
        }
        return best
    }

    /// The projection of `world` in view points of `size`.
    static func points(_ world: SIMD3<Double>, size: SIMD2<Double>, camera: ColorfallCanyonsCamera) -> SIMD2<Double>? {
        guard let v = Geometry.project(world, camera: camera) else { return nil }
        return SIMD2(v.x * size.x, v.y * size.y)
    }

    @Test func picksMatchAnIndependentPickOnSeededPoints() throws {
        let snapshots: [Snapshot] = try Self.certifiedSnapshots()
        var random: ColorfallCanyonsRandom = ColorfallCanyonsRandom(seed: 2_344)
        var cells: Int = 0, springs: Int = 0, empties: Int = 0, mismatches: Int = 0
        for snapshot in snapshots {
            for size in Self.sizes {
                for orbit in Self.orbits {
                    for _ in 0..<500 {
                        let x: Double = Double(random.next() % 100_000) / 100_000 * size.x
                        let y: Double = Double(random.next() % 100_000) / 100_000 * size.y
                        let point: SIMD2<Double> = SIMD2(x, y)
                        let pick: ColorfallCanyonsPick = Picker.pick(point, size: size, snapshot: snapshot,
                                                                     orbit: orbit)
                        let expected: ColorfallCanyonsPick = Self.expected(point, size: size, snapshot: snapshot,
                                                                           orbit: orbit)
                        if pick != expected { mismatches += 1 }
                        #expect(pick == expected, "point \(point) size \(size) orbit \(orbit)")
                        switch pick {
                        case .cell: cells += 1
                        case .spring: springs += 1
                        case .empty: empties += 1
                        }
                    }
                }
            }
        }
        #expect(mismatches == 0)
        #expect(cells > 1_000 && springs > 0 && empties > 0)
    }

    @Test func everyCellTopCentrePicksItsCellAtEveryOrbit() throws {
        let snapshots: [Snapshot] = try Self.certifiedSnapshots()
        for snapshot in snapshots {
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let camera: ColorfallCanyonsCamera = Geometry.camera(snapshot, aspect: size.x / size.y,
                                                                         orbit: orbit)
                    for cell in 0..<snapshot.cellCount {
                        guard let p = Self.points(Geometry.cellTop(cell, snapshot), size: size, camera: camera) else {
                            Issue.record("cell \(cell) behind the camera")
                            continue
                        }
                        let pick: ColorfallCanyonsPick = Picker.pick(p, size: size, snapshot: snapshot, orbit: orbit)
                        #expect(pick == Self.expected(p, size: size, snapshot: snapshot, orbit: orbit))
                    }
                }
            }
        }
    }

    @Test func aTouchBesideTheGridFallsBackToTheNearestTargetWithin22Points() throws {
        let snapshots: [Snapshot] = try Self.certifiedSnapshots()
        let size: SIMD2<Double> = SIMD2(390, 844)
        var fallbacks: Int = 0
        for snapshot in snapshots {
            for orbit in Self.orbits {
                let camera: ColorfallCanyonsCamera = Geometry.camera(snapshot, aspect: size.x / size.y, orbit: orbit)
                for cell in 0..<snapshot.cellCount {
                    guard let centre = Self.points(Geometry.cellTop(cell, snapshot), size: size, camera: camera) else {
                        continue
                    }
                    // Points 12 … 21 points from the projected top centre in 16 directions.
                    for k in 0..<16 {
                        let angle: Double = 2 * Double.pi * Double(k) / 16
                        for radius in [12.0, 16.0, 21.0] {
                            let p: SIMD2<Double> = centre + SIMD2(cos(angle), sin(angle)) * radius
                            guard let r = Picker.ray(p, size: size, camera: camera) else { continue }
                            let any: Int = Self.hits(origin: r.origin, direction: r.direction, snapshot).count
                            guard any == 0 else { continue }
                            let pick: ColorfallCanyonsPick = Picker.pick(p, size: size, snapshot: snapshot,
                                                                         orbit: orbit)
                            #expect(pick != .empty)
                            #expect(pick == Self.expected(p, size: size, snapshot: snapshot, orbit: orbit))
                            fallbacks += 1
                        }
                    }
                }
                // The view's top-left corner region is far from every target.
                let corner: SIMD2<Double> = SIMD2(1, 1)
                if let r = Picker.ray(corner, size: size, camera: camera),
                   Self.hits(origin: r.origin, direction: r.direction, snapshot).isEmpty {
                    #expect(Picker.pick(corner, size: size, snapshot: snapshot, orbit: orbit) == .empty)
                }
            }
        }
        #expect(fallbacks > 0)
        #expect(Picker.minimumTarget == 22)
    }

    /// A 4 × 4 level whose cell 11 (row 2) stands at height 15 in front of cell 7 (row 1) at height 0.
    static func wallLevel() throws -> ColorfallCanyonsLevel {
        let heights: [Int] = [15, 15, 15, 15,
                              9, 8, 9, 0,
                              12, 0, 12, 15,
                              12, 12, 12, 0]
        var grounds: [ColorfallCanyonsGround] = Array(repeating: .open, count: 16)
        grounds[15] = .drain
        var springs: [ColorfallCanyonsSpring] = []
        for c in 0..<3 {
            springs.append(ColorfallCanyonsSpring(cell: c, color: ColorfallCanyonsColor(rawValue: c)!, release: 2,
                                                  supply: 400, open: true))
        }
        let basin: ColorfallCanyonsBasin = ColorfallCanyonsBasin(cell: 9, capacity: 999, fill: 900,
                                                                 shares: [400, 0, 600], tolerance: 50,
                                                                 isProtected: false, toleratedWrong: 0)
        return try ColorfallCanyonsLevel(id: "wall", seed: 2_344, difficulty: 2, columns: 4, rows: 4, heights: heights,
                                         grounds: grounds, springs: springs, basins: [basin], flowRate: 3, budget: 10,
                                         tickLimit: 3_600)
    }

    @Test func aCellHiddenBehindATallerNearerBlockResolvesToTheNearerBlock() throws {
        let snapshot: Snapshot = try Self.snapshot(try Self.wallLevel(), ticks: 0)
        let size: SIMD2<Double> = SIMD2(390, 844)
        let camera: ColorfallCanyonsCamera = Geometry.camera(snapshot, aspect: size.x / size.y, orbit: .authored)
        let u: Double = Geometry.cellSize(snapshot)
        // A point on cell 11's top near its far edge (towards cell 7, −z).
        let world: SIMD3<Double> = Geometry.cellTop(11, snapshot) + SIMD3(0, 0, -0.45 * u)
        let p: SIMD2<Double>? = Self.points(world, size: size, camera: camera)
        #expect(p != nil)
        guard let p, let r = Picker.ray(p, size: size, camera: camera) else { return }
        let hits: [(t: Double, pick: ColorfallCanyonsPick)] = Self.hits(origin: r.origin, direction: r.direction,
                                                                         snapshot)
        var hitsHidden: Bool = false
        var hitsWall: Bool = false
        for hit in hits {
            if hit.pick == .cell(7) { hitsHidden = true }
            if hit.pick == .cell(11) { hitsWall = true }
        }
        #expect(hitsHidden && hitsWall)
        #expect(Picker.pick(p, size: size, snapshot: snapshot, orbit: .authored) == .cell(11))
    }

    @Test func nonFiniteOrUnusableInputPicksNothing() throws {
        let snapshot: Snapshot = try Self.snapshot(try Self.wallLevel(), ticks: 0)
        let size: SIMD2<Double> = SIMD2(390, 844)
        let camera: ColorfallCanyonsCamera = Geometry.camera(snapshot, aspect: size.x / size.y, orbit: .authored)
        let centre: SIMD2<Double> = SIMD2(195, 422)
        #expect(Picker.pick(centre, size: size, snapshot: snapshot, orbit: .authored) != .empty)
        let points: [SIMD2<Double>] = [SIMD2(.nan, 422), SIMD2(195, .infinity), SIMD2(-.infinity, .nan)]
        for point in points {
            #expect(Picker.pick(point, size: size, snapshot: snapshot, orbit: .authored) == .empty)
            #expect(Picker.ray(point, size: size, camera: camera) == nil)
        }
        let sizes: [SIMD2<Double>] = [SIMD2(0, 844), SIMD2(390, -1), SIMD2(.nan, 844), SIMD2(390, .infinity)]
        for bad in sizes {
            #expect(Picker.pick(centre, size: bad, snapshot: snapshot, orbit: .authored) == .empty)
            #expect(Picker.ray(centre, size: bad, camera: camera) == nil)
        }
        // A non-finite orbit is the authored one.
        let odd: ColorfallCanyonsOrbit = ColorfallCanyonsOrbit(yaw: .nan, pitch: .infinity)
        #expect(Picker.pick(centre, size: size, snapshot: snapshot, orbit: odd)
            == Picker.pick(centre, size: size, snapshot: snapshot, orbit: .authored))
        // The ray of the view centre is unit length and passes through the grid centre.
        if let r = Picker.ray(centre, size: size, camera: camera) {
            let length: Double = Geometry.length(r.direction)
            #expect(abs(length - 1) < 1e-12)
            let t: Double = Geometry.dot(-r.origin, r.direction)
            #expect(Geometry.length(r.origin + r.direction * t) < 1e-9)
        } else {
            Issue.record("no ray through the view centre")
        }
    }
}
