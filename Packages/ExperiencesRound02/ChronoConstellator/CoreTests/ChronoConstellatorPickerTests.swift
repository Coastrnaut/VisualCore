// ChronoConstellatorPickerTests — feature 354 (R02-G06-04) T-R02G0604-002 (FR-R02G0604-001, 002, 004; SC-R02G0604-001,
// 003; research R4). The analytic picker against an independent pick written here: the same ray (only
// `ChronoConstellatorPicker.ray` and the drawn camera are shared), its own closest-approach sphere test for the star
// nodes, its own plane intersection, cell lookup and timeline band, and its own 22-point fallback, on 500 seeded points
// (seed 2_354) per certified level and tick, view size and orbit (authored, both yaw limits, both pitch limits); every
// projected star centre picks its star; a touch beside the grid falls back to the nearest star within 22 points; the
// loop index and the scrub tick follow their formulas, clamping included; non-finite input picks nothing. Plain loops
// and explicit types (CI type-check rule).
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
@testable import ChronoConstellatorCore

@Suite struct ChronoConstellatorPickerTests {
    typealias Geometry = ChronoConstellatorSceneGeometry
    typealias Snapshot = ChronoConstellatorSceneSnapshot
    typealias Picker = ChronoConstellatorPicker
    typealias Orbit = ChronoConstellatorOrbit

    /// The view sizes in points: phone portrait, tablet landscape, tablet portrait.
    static let sizes: [SIMD2<Double>] = [SIMD2(390, 844), SIMD2(1_180, 820), SIMD2(1_024, 1_366)]

    /// The authored orbit, both yaw limits and both pitch limits.
    static let orbits: [Orbit] = [
        .authored,
        Orbit(yaw: -Orbit.yawLimit, pitch: Orbit.authored.pitch),
        Orbit(yaw: Orbit.yawLimit, pitch: Orbit.authored.pitch),
        Orbit(yaw: 0, pitch: Orbit.pitchRange.lowerBound),
        Orbit(yaw: 0, pitch: Orbit.pitchRange.upperBound),
    ]

    /// Snapshots of the certified levels 1, 21, 41, 61 and 81, fresh (tick 0) and stepped 5 ticks (or as far as the
    /// play goes).
    static func certifiedSnapshots() throws -> [Snapshot] {
        var result: [Snapshot] = []
        for number in [1, 21, 41, 61, 81] {
            let level: ChronoConstellatorLevel = try ChronoConstellatorExperienceCore.level(number: number)
            var play: ChronoConstellatorPlay = try ChronoConstellatorExperienceCore.freshPlay(of: level)
            result.append(Snapshot(play: play, levelNumber: number, time: 0))
            try? play.apply(.step(5), expecting: play.fingerprint)
            result.append(Snapshot(play: play, levelNumber: number, time: 0))
        }
        return result
    }

    /// The camera the picker draws with for `size` and `orbit`.
    static func camera(_ snapshot: Snapshot, size: SIMD2<Double>, orbit: Orbit) -> ChronoConstellatorCamera {
        Geometry.camera(snapshot, aspect: size.x / size.y, orbit: orbit)
    }

    /// The distance along the ray at which it enters the sphere, by the closest approach: the foot of the
    /// perpendicular from `centre` lies at s = (centre − origin)·direction, the squared miss distance is
    /// |centre − origin|² − s², and the entry lies √(radius² − miss²) before the foot; nil when it misses or the entry
    /// lies behind the origin.
    static func sphereEntry(origin: SIMD3<Double>, direction: SIMD3<Double>, centre: SIMD3<Double>,
                            radius: Double) -> Double? {
        let toCentre: SIMD3<Double> = centre - origin
        let s: Double = (toCentre * direction).sum()
        let miss: Double = (toCentre * toCentre).sum() - s * s
        guard miss <= radius * radius else { return nil }
        let entry: Double = s - (radius * radius - miss).squareRoot()
        return entry > 0 ? entry : nil
    }

    /// The point where the ray meets y = 0 ahead of the origin, by the plane equation; nil otherwise.
    static func plane(origin: SIMD3<Double>, direction: SIMD3<Double>) -> SIMD3<Double>? {
        guard direction.y != 0 else { return nil }
        let t: Double = (0 - origin.y) / direction.y
        guard t > 0 else { return nil }
        return origin + direction * t
    }

    /// The row-major cell whose square contains the field point `p` (scanning every cell), or nil off the grid.
    static func cellContaining(_ p: SIMD3<Double>, _ snapshot: Snapshot) -> Int? {
        let u: Double = Geometry.cellSize(snapshot)
        let half: Double = u / 2
        let count: Int = snapshot.columns * snapshot.rows
        for cell in 0..<count {
            let c: SIMD3<Double> = Geometry.cellCentre(cell, snapshot)
            if p.x >= c.x - half && p.x <= c.x + half && p.z >= c.z - half && p.z <= c.z + half { return cell }
        }
        return nil
    }

    /// The projection of `world` in view points of `size`.
    static func points(_ world: SIMD3<Double>, size: SIMD2<Double>,
                       camera: ChronoConstellatorCamera) -> SIMD2<Double>? {
        guard let v = Geometry.project(world, camera: camera) else { return nil }
        return SIMD2(v.x * size.x, v.y * size.y)
    }

    /// The distance in points between `a` and `b`.
    static func gap(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let d: SIMD2<Double> = a - b
        return (d.x * d.x + d.y * d.y).squareRoot()
    }

    /// Whether the ray of `point` hits any star node sphere (independently computed).
    static func hitsAnyStar(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: Snapshot,
                            camera: ChronoConstellatorCamera) -> Bool {
        guard let r = Picker.ray(point, size: size, camera: camera) else { return false }
        let radius: Double = 0.3 * Geometry.cellSize(snapshot)
        for star in 0..<snapshot.stars.count {
            let centre: SIMD3<Double> = Geometry.cellCentre(snapshot.stars[star].cell, snapshot)
                + SIMD3(0, 0.25 * Geometry.cellSize(snapshot), 0)
            if sphereEntry(origin: r.origin, direction: r.direction, centre: centre, radius: radius) != nil {
                return true
            }
        }
        return false
    }

    /// The independent pick of `point`.
    static func expected(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: Snapshot,
                         orbit: Orbit) -> ChronoConstellatorPick {
        let camera: ChronoConstellatorCamera = Self.camera(snapshot, size: size, orbit: orbit)
        guard let r = Picker.ray(point, size: size, camera: camera) else { return .empty }
        let u: Double = Geometry.cellSize(snapshot)
        var bestT: Double = .infinity
        var bestStar: Int = -1
        for star in 0..<snapshot.stars.count {
            let centre: SIMD3<Double> = Geometry.cellCentre(snapshot.stars[star].cell, snapshot) + SIMD3(0, 0.25 * u, 0)
            if let t = sphereEntry(origin: r.origin, direction: r.direction, centre: centre, radius: 0.3 * u),
               t < bestT {
                bestT = t
                bestStar = star
            }
        }
        if bestStar >= 0 { return .star(bestStar) }
        if let p = plane(origin: r.origin, direction: r.direction), let cell = cellContaining(p, snapshot) {
            let width: Double = Double(snapshot.columns) * u
            let depth: Double = Double(snapshot.rows) * u
            if p.z >= depth / 2 - 0.25 * u { return .timeline((p.x + width / 2) / width) }
            return .cell(cell)
        }
        var bestD: Double = .infinity
        var result: ChronoConstellatorPick = .empty
        for star in 0..<snapshot.stars.count {
            let centre: SIMD3<Double> = Geometry.cellCentre(snapshot.stars[star].cell, snapshot) + SIMD3(0, 0.25 * u, 0)
            guard let q = points(centre, size: size, camera: camera) else { continue }
            let d: Double = gap(q, point)
            if d <= 22 && d < bestD {
                bestD = d
                result = .star(star)
            }
        }
        return result
    }

    /// The independent loop index of a drag of `star` at `point`.
    static func expectedLoopIndex(star: Int, _ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: Snapshot,
                                  orbit: Orbit) -> Int? {
        let camera: ChronoConstellatorCamera = Self.camera(snapshot, size: size, orbit: orbit)
        guard let r = Picker.ray(point, size: size, camera: camera) else { return nil }
        let loop: [Int] = snapshot.stars[star].loop
        if let p = plane(origin: r.origin, direction: r.direction), let cell = cellContaining(p, snapshot) {
            for index in 0..<loop.count where loop[index] == cell { return index }
        }
        var bestD: Double = .infinity
        var result: Int?
        for index in 0..<loop.count {
            guard let q = points(Geometry.cellCentre(loop[index], snapshot), size: size, camera: camera) else {
                continue
            }
            let d: Double = gap(q, point)
            if d <= 22 && d < bestD {
                bestD = d
                result = index
            }
        }
        return result
    }

    /// Whether two picks agree (timeline fractions to 1e-9).
    static func same(_ a: ChronoConstellatorPick, _ b: ChronoConstellatorPick) -> Bool {
        if case .timeline(let x) = a, case .timeline(let y) = b { return abs(x - y) < 1e-9 }
        return a == b
    }

    @Test func picksMatchAnIndependentPickOnSeededPoints() throws {
        // One snapshot per level, ticks alternating 0 and 5 (levels 1, 41, 81 fresh; 21, 61 stepped).
        let all: [Snapshot] = try Self.certifiedSnapshots()
        var snapshots: [Snapshot] = []
        for k in 0..<5 { snapshots.append(all[2 * k + k % 2]) }
        var random: SeededRandom = SeededRandom(seed: 2_354)
        var stars: Int = 0, cells: Int = 0, timelines: Int = 0, empties: Int = 0, mismatches: Int = 0
        var loopChecks: Int = 0
        for snapshot in snapshots {
            for size in Self.sizes {
                for orbit in Self.orbits {
                    for _ in 0..<500 {
                        let point: SIMD2<Double> = SIMD2(random.double() * size.x, random.double() * size.y)
                        let pick: ChronoConstellatorPick = Picker.pick(point, size: size, snapshot: snapshot,
                                                                       orbit: orbit)
                        let expected: ChronoConstellatorPick = Self.expected(point, size: size, snapshot: snapshot,
                                                                             orbit: orbit)
                        if !Self.same(pick, expected) {
                            mismatches += 1
                            Issue.record("point \(point) size \(size) orbit \(orbit): \(pick) vs \(expected)")
                        }
                        switch pick {
                        case .star: stars += 1
                        case .cell: cells += 1
                        case .timeline: timelines += 1
                        case .empty: empties += 1
                        }
                        let star: Int = Int(random.next() % UInt64(snapshot.stars.count))
                        let index: Int? = Picker.loopIndex(star: star, at: point, size: size, snapshot: snapshot,
                                                           orbit: orbit)
                        #expect(index == Self.expectedLoopIndex(star: star, point, size: size, snapshot: snapshot,
                                                                orbit: orbit))
                        if index != nil { loopChecks += 1 }
                    }
                }
            }
        }
        #expect(mismatches == 0)
        #expect(stars > 0 && cells > 1_000 && timelines > 0 && empties > 0,
                "stars \(stars) cells \(cells) timelines \(timelines) empties \(empties)")
        #expect(loopChecks > 1_000)
    }

    @Test func everyStarCentrePicksAStarAtEveryOrbit() throws {
        let snapshots: [Snapshot] = try Self.certifiedSnapshots()
        for snapshot in snapshots {
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let camera: ChronoConstellatorCamera = Self.camera(snapshot, size: size, orbit: orbit)
                    for star in 0..<snapshot.stars.count {
                        guard let p = Self.points(Geometry.starCentre(star, snapshot), size: size,
                                                  camera: camera) else {
                            Issue.record("star \(star) behind the camera")
                            continue
                        }
                        let pick: ChronoConstellatorPick = Picker.pick(p, size: size, snapshot: snapshot,
                                                                       orbit: orbit)
                        #expect(pick == Self.expected(p, size: size, snapshot: snapshot, orbit: orbit))
                        if case .star = pick {} else { Issue.record("star \(star) centre picked \(pick)") }
                    }
                }
            }
        }
    }

    @Test func aTouchBesideTheGridFallsBackToTheNearestStarWithin22Points() throws {
        let snapshots: [Snapshot] = try Self.certifiedSnapshots()
        var fallbacks: Int = 0
        for snapshot in snapshots {
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let camera: ChronoConstellatorCamera = Self.camera(snapshot, size: size, orbit: orbit)
                    for star in 0..<snapshot.stars.count {
                        guard let centre = Self.points(Geometry.starCentre(star, snapshot), size: size,
                                                       camera: camera) else { continue }
                        for k in 0..<16 {
                            let angle: Double = 2 * Double.pi * Double(k) / 16
                            for radius in [14.0, 18.0, 21.5] {
                                let p: SIMD2<Double> = centre + SIMD2(cos(angle), sin(angle)) * radius
                                guard let r = Picker.ray(p, size: size, camera: camera) else { continue }
                                if Self.hitsAnyStar(p, size: size, snapshot: snapshot, camera: camera) { continue }
                                if let hit = Self.plane(origin: r.origin, direction: r.direction),
                                   Self.cellContaining(hit, snapshot) != nil { continue }
                                let pick: ChronoConstellatorPick = Picker.pick(p, size: size, snapshot: snapshot,
                                                                               orbit: orbit)
                                #expect(pick != .empty)
                                #expect(pick == Self.expected(p, size: size, snapshot: snapshot, orbit: orbit))
                                fallbacks += 1
                            }
                        }
                    }
                    // Just beyond 22 points of every star and off the grid is empty space.
                    let corner: SIMD2<Double> = SIMD2(1, 1)
                    if Self.expected(corner, size: size, snapshot: snapshot, orbit: orbit) == .empty {
                        #expect(Picker.pick(corner, size: size, snapshot: snapshot, orbit: orbit) == .empty)
                    }
                }
            }
        }
        #expect(fallbacks > 0)
        #expect(Picker.minimumTarget == 22 && Picker.timelineBand == 0.25)
    }

    @Test func theTimelineBandPicksItsFractionAndTheCellsLieBehindIt() throws {
        let snapshot: Snapshot = try Self.certifiedSnapshots()[0]
        let u: Double = Geometry.cellSize(snapshot)
        let halfWidth: Double = Double(snapshot.columns) * u / 2
        let halfDepth: Double = Double(snapshot.rows) * u / 2
        for size in Self.sizes {
            for orbit in Self.orbits {
                let camera: ChronoConstellatorCamera = Self.camera(snapshot, size: size, orbit: orbit)
                for fraction in [0.02, 0.27, 0.51, 0.77, 0.98] {
                    let x: Double = -halfWidth + 2 * halfWidth * fraction
                    let band: SIMD3<Double> = SIMD3(x, 0, halfDepth - 0.12 * u)
                    if let p = Self.points(band, size: size, camera: camera) {
                        let pick: ChronoConstellatorPick = Picker.pick(p, size: size, snapshot: snapshot,
                                                                       orbit: orbit)
                        if case .timeline(let f) = pick {
                            #expect(abs(f - fraction) < 1e-6)
                        } else {
                            Issue.record("band point \(fraction) picked \(pick)")
                        }
                    }
                    // Half a band further in is the last row's cell (unless a node covers it).
                    let inside: SIMD3<Double> = SIMD3(x, 0, halfDepth - 0.4 * u)
                    if let p = Self.points(inside, size: size, camera: camera),
                       !Self.hitsAnyStar(p, size: size, snapshot: snapshot, camera: camera) {
                        let column: Int = min(Int(fraction * Double(snapshot.columns)), snapshot.columns - 1)
                        let cell: Int = (snapshot.rows - 1) * snapshot.columns + column
                        #expect(Picker.pick(p, size: size, snapshot: snapshot, orbit: orbit) == .cell(cell))
                    }
                }
            }
        }
    }

    @Test func loopIndexFindsTheLoopCellUnderOrNearTheFinger() throws {
        let snapshots: [Snapshot] = try Self.certifiedSnapshots()
        let size: SIMD2<Double> = SIMD2(390, 844)
        var nearby: Int = 0
        for snapshot in snapshots {
            for orbit in Self.orbits {
                let camera: ChronoConstellatorCamera = Self.camera(snapshot, size: size, orbit: orbit)
                for star in 0..<snapshot.stars.count {
                    let loop: [Int] = snapshot.stars[star].loop
                    for index in 0..<loop.count {
                        guard let p = Self.points(Geometry.cellCentre(loop[index], snapshot), size: size,
                                                  camera: camera) else { continue }
                        let first: Int = loop.firstIndex(of: loop[index]) ?? index
                        #expect(Picker.loopIndex(star: star, at: p, size: size, snapshot: snapshot,
                                                 orbit: orbit) == first)
                        // A point 15 points away that is off the loop still finds a loop cell within 22 points.
                        let off: SIMD2<Double> = p + SIMD2(p.x + 15 <= size.x ? 15 : -15, 0)
                        let got: Int? = Picker.loopIndex(star: star, at: off, size: size, snapshot: snapshot,
                                                         orbit: orbit)
                        #expect(got == Self.expectedLoopIndex(star: star, off, size: size, snapshot: snapshot,
                                                              orbit: orbit))
                        #expect(got != nil)
                        nearby += 1
                    }
                }
                // The top-left corner is far from every loop cell of the 5 × 5 … grids at these orbits.
                let corner: SIMD2<Double> = SIMD2(1, 1)
                #expect(Picker.loopIndex(star: 0, at: corner, size: size, snapshot: snapshot, orbit: orbit)
                    == Self.expectedLoopIndex(star: 0, corner, size: size, snapshot: snapshot, orbit: orbit))
                #expect(Picker.loopIndex(star: -1, at: corner, size: size, snapshot: snapshot, orbit: orbit) == nil)
                #expect(Picker.loopIndex(star: snapshot.stars.count, at: corner, size: size, snapshot: snapshot,
                                         orbit: orbit) == nil)
            }
        }
        #expect(nearby > 0)
    }

    @Test func tickFollowsTheFieldPlaneXFractionClamped() throws {
        let snapshots: [Snapshot] = try Self.certifiedSnapshots()
        for snapshot in snapshots {
            let u: Double = Geometry.cellSize(snapshot)
            let halfWidth: Double = Double(snapshot.columns) * u / 2
            let halfDepth: Double = Double(snapshot.rows) * u / 2
            let limit: Double = Double(snapshot.tickLimit)
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let camera: ChronoConstellatorCamera = Self.camera(snapshot, size: size, orbit: orbit)
                    // Inside the band, in the middle of the grid and beyond either side edge.
                    for fraction in [-0.2, 0, 0.1, 0.333, 0.5, 0.9, 1, 1.2] {
                        for z in [halfDepth - 0.1 * u, 0.0] {
                            let world: SIMD3<Double> = SIMD3(-halfWidth + 2 * halfWidth * fraction, 0, z)
                            guard let p = Self.points(world, size: size, camera: camera),
                                  p.x >= 0, p.x <= size.x, p.y >= 0, p.y <= size.y,
                                  let r = Picker.ray(p, size: size, camera: camera),
                                  let hit = Self.plane(origin: r.origin, direction: r.direction) else { continue }
                            let f: Double = min(max((hit.x + halfWidth) / (2 * halfWidth), 0), 1)
                            let expected: Int = Int((limit * f).rounded())
                            #expect(Picker.tick(at: p, size: size, snapshot: snapshot, orbit: orbit) == expected)
                            if fraction <= 0 { #expect(expected == 0) }
                            if fraction >= 1 { #expect(expected == snapshot.tickLimit) }
                        }
                    }
                }
            }
        }
    }

    @Test func nonFiniteOrUnusableInputPicksNothing() throws {
        let snapshot: Snapshot = try Self.certifiedSnapshots()[0]
        let size: SIMD2<Double> = SIMD2(390, 844)
        let camera: ChronoConstellatorCamera = Self.camera(snapshot, size: size, orbit: .authored)
        let centre: SIMD2<Double> = SIMD2(195, 422)
        #expect(Picker.pick(centre, size: size, snapshot: snapshot, orbit: .authored) != .empty)
        let points: [SIMD2<Double>] = [SIMD2(.nan, 422), SIMD2(195, .infinity), SIMD2(-.infinity, .nan),
                                       SIMD2(-5, 422), SIMD2(195, 900)]
        for point in points {
            #expect(Picker.pick(point, size: size, snapshot: snapshot, orbit: .authored) == .empty)
            #expect(Picker.ray(point, size: size, camera: camera) == nil)
            #expect(Picker.tick(at: point, size: size, snapshot: snapshot, orbit: .authored) == nil)
            #expect(Picker.loopIndex(star: 0, at: point, size: size, snapshot: snapshot, orbit: .authored) == nil)
        }
        let sizes: [SIMD2<Double>] = [SIMD2(0, 844), SIMD2(390, -1), SIMD2(.nan, 844), SIMD2(390, .infinity)]
        for bad in sizes {
            #expect(Picker.pick(centre, size: bad, snapshot: snapshot, orbit: .authored) == .empty)
            #expect(Picker.ray(centre, size: bad, camera: camera) == nil)
            #expect(Picker.tick(at: centre, size: bad, snapshot: snapshot, orbit: .authored) == nil)
        }
        // A non-finite orbit is the authored one.
        let odd: Orbit = Orbit(yaw: .nan, pitch: .infinity)
        #expect(Picker.pick(centre, size: size, snapshot: snapshot, orbit: odd)
            == Picker.pick(centre, size: size, snapshot: snapshot, orbit: .authored))
        // The ray of the view centre is unit length and passes through the grid centre.
        if let r = Picker.ray(centre, size: size, camera: camera) {
            #expect(abs(Geometry.length(r.direction) - 1) < 1e-12)
            let t: Double = Geometry.dot(-r.origin, r.direction)
            #expect(Geometry.length(r.origin + r.direction * t) < 1e-9)
        } else {
            Issue.record("no ray through the view centre")
        }
    }
}
