// EchoCartographerPickerTests — feature 404 (R02-G11-04) T-R02G1104-002. The analytic picker of Echo Cartographer
// against an independent pick written here (its own camera basis, projection and unprojection from the camera's eye,
// target, field of view and aspect; its own cell centres and square containment): 500 seeded points (LCG seed 2_404) per
// view size and orbit over certified levels 1, 41 and 100 with markers placed, at 3 view sizes and 3 orbits; the
// 22-point marker target at 21 and 23 points; a marker beats the cell under it; equal distances go to the lower cell
// index; unusable input gives nil or empty. Explicit types, plain loops; well under 10 s each.
import Foundation
import Testing
import VisualCoreMath
@testable import EchoCartographerCore

@Suite struct EchoCartographerPickerTests {
    typealias Geometry = EchoCartographerSceneGeometry
    typealias Snapshot = EchoCartographerSceneSnapshot
    typealias Cell = EchoCartographerCell
    typealias Picker = EchoCartographerPicker

    static let sizes: [SIMD2<Double>] = [SIMD2(390, 844), SIMD2(1024, 768), SIMD2(2000, 800)]

    static let orbits: [EchoCartographerOrbit] = [EchoCartographerOrbit.authored,
                                                  EchoCartographerOrbit(yaw: EchoCartographerOrbit.yawLimit,
                                                                        pitch: EchoCartographerOrbit.pitchRange.upperBound),
                                                  EchoCartographerOrbit(yaw: -0.3, pitch: -0.1)]

    /// A 64-bit linear congruential generator (Knuth's MMIX constants).
    struct LCG {
        var state: UInt64
        mutating func next() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 11) / 9_007_199_254_740_992
        }
        mutating func int(_ upper: Int) -> Int { min(Int(next() * Double(upper)), upper - 1) }
    }

    /// A play of `level` begun (tutorial dismissed) with markers on `marks` (refused ones skipped).
    static func snapshot(_ level: EchoCartographerLevel, marks: [Cell], number: Int) throws -> Snapshot {
        var play: EchoCartographerPlay = EchoCartographerPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        for cell in marks {
            try? play.apply(.mark(cell.x, cell.y), expecting: play.fingerprint)
        }
        return Snapshot(play: play, levelNumber: number, time: 0)
    }

    /// Certified levels 1, 41 and 100 with seeded markers (up to 8, 4 and 1).
    static func certified() throws -> [Snapshot] {
        var random: LCG = LCG(state: 2_404)
        var result: [Snapshot] = []
        let numbers: [Int] = [1, 41, 100]
        let counts: [Int] = [8, 4, 1]
        for (position, number) in numbers.enumerated() {
            let level: EchoCartographerLevel = try EchoCartographerExperienceCore.opening(number: number).play.level
            var marks: [Cell] = []
            for _ in 0..<counts[position] {
                marks.append(Cell(x: random.int(level.chamber.width), y: random.int(level.chamber.height)))
            }
            result.append(try snapshot(level, marks: marks, number: number))
        }
        return result
    }

    /// An open chamber of `width` × `height` with markers `marks`.
    static func open(_ width: Int, _ height: Int, marks: [Cell]) throws -> Snapshot {
        let chamber: EchoCartographerChamber = try EchoCartographerChamber(width: width, height: height, walls: [])
        let level: EchoCartographerLevel = try EchoCartographerLevel(
            id: "picker-open", seed: 4, difficulty: 1, chamber: chamber, entry: Cell(x: 0, y: 0),
            beacons: [Cell(x: width - 1, y: height - 1)], tolerance: 0, energy: 5, missCost: 1)
        return try snapshot(level, marks: marks, number: 9)
    }

    // MARK: The independent pick

    /// The camera basis (right, up, forward) from the eye towards the target with +y up.
    static func basis(_ camera: EchoCartographerCamera) -> (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>) {
        let f0: SIMD3<Double> = camera.target - camera.eye
        let f: SIMD3<Double> = f0 / (f0 * f0).sum().squareRoot()
        let r0: SIMD3<Double> = SIMD3(f.y * 0 - f.z * 1, f.z * 0 - f.x * 0, f.x * 1 - f.y * 0)
        let r: SIMD3<Double> = r0 / (r0 * r0).sum().squareRoot()
        let u: SIMD3<Double> = SIMD3(r.y * f.z - r.z * f.y, r.z * f.x - r.x * f.z, r.x * f.y - r.y * f.x)
        return (r, u, f)
    }

    /// World `p` in view points of `size`, or nil behind the eye.
    static func project(_ p: SIMD3<Double>, _ camera: EchoCartographerCamera, _ size: SIMD2<Double>) -> SIMD2<Double>? {
        let (r, u, f): (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>) = basis(camera)
        let d: SIMD3<Double> = p - camera.eye
        let depth: Double = (d * f).sum()
        guard depth > 0 else { return nil }
        let t: Double = tan(camera.fovY / 2)
        let nx: Double = (d * r).sum() / (depth * t * camera.aspect)
        let ny: Double = (d * u).sum() / (depth * t)
        return SIMD2((nx + 1) / 2 * size.x, (1 - ny) / 2 * size.y)
    }

    /// The point where the eye ray through view point `q` meets y = 0 ahead, or nil.
    static func floorHit(_ q: SIMD2<Double>, _ camera: EchoCartographerCamera, _ size: SIMD2<Double>) -> SIMD3<Double>? {
        let (r, u, f): (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>) = basis(camera)
        let t: Double = tan(camera.fovY / 2)
        let nx: Double = 2 * q.x / size.x - 1
        let ny: Double = 1 - 2 * q.y / size.y
        let direction: SIMD3<Double> = f + r * (nx * t * camera.aspect) + u * (ny * t)
        guard direction.y < 0 else { return nil }
        let k: Double = -camera.eye.y / direction.y
        return camera.eye + direction * k
    }

    /// The independent pick, or nil when the point lies within 1e-7 of a decision boundary (a cell border or the
    /// 22-point circle), where rounding may decide either way.
    static func expected(_ q: SIMD2<Double>, _ s: Snapshot, _ size: SIMD2<Double>,
                         _ orbit: EchoCartographerOrbit) -> EchoCartographerPick? {
        let camera: EchoCartographerCamera = Geometry.camera(s, aspect: size.x / size.y, orbit: orbit)
        let pitch: Double = 1.8 / Double(max(s.width, s.height))
        var best: Cell? = nil
        var bestDistance: Double = Double.infinity
        for marker in s.markers {
            let centre: SIMD3<Double> = SIMD3((Double(marker.x) + 0.5 - Double(s.width) / 2) * pitch, 0.01,
                                              (Double(marker.y) + 0.5 - Double(s.height) / 2) * pitch)
            guard let p = project(centre, camera, size) else { continue }
            let d: Double = ((p - q) * (p - q)).sum().squareRoot()
            if abs(d - 22) < 1e-7 { return nil }
            if d > 22 { continue }
            if d < bestDistance || (d == bestDistance && marker.y * s.width + marker.x < best!.y * s.width + best!.x) {
                best = marker
                bestDistance = d
            }
        }
        if let marker = best { return .marker(marker) }
        guard let hit = floorHit(q, camera, size) else { return .empty }
        let half: Double = pitch / 2
        for y in 0..<s.height {
            for x in 0..<s.width {
                let cx: Double = (Double(x) + 0.5 - Double(s.width) / 2) * pitch
                let cz: Double = (Double(y) + 0.5 - Double(s.height) / 2) * pitch
                let dx: Double = abs(hit.x - cx)
                let dz: Double = abs(hit.z - cz)
                if (abs(dx - half) < 1e-7 && dz <= half + 1e-7) || (abs(dz - half) < 1e-7 && dx <= half + 1e-7) {
                    return nil
                }
                if dx < half && dz < half { return .cell(Cell(x: x, y: y)) }
            }
        }
        return .empty
    }

    // MARK: Tests

    @Test func fiveHundredSeededPointsAgreeWithAnIndependentPick() throws {
        let snapshots: [Snapshot] = try Self.certified()
        #expect(snapshots[0].markers.count >= 4)
        var random: LCG = LCG(state: 2_404)
        var markers: Int = 0
        var cells: Int = 0
        var empties: Int = 0
        var skipped: Int = 0
        for size in Self.sizes {
            for orbit in Self.orbits {
                for index in 0..<500 {
                    let s: Snapshot = snapshots[index % snapshots.count]
                    var q: SIMD2<Double> = SIMD2(random.next() * size.x, random.next() * size.y)
                    // Every third point near a marker, so the marker target is exercised.
                    if index % 3 == 0 && !s.markers.isEmpty {
                        let camera: EchoCartographerCamera = Geometry.camera(s, aspect: size.x / size.y, orbit: orbit)
                        let k: Int = random.int(s.markers.count)
                        if let p = Self.project(Geometry.markerCentre(k, s), camera, size) {
                            let jittered: SIMD2<Double> = p + SIMD2(random.next() * 60 - 30, random.next() * 60 - 30)
                            q = SIMD2(min(max(jittered.x, 0), size.x), min(max(jittered.y, 0), size.y))
                        }
                    }
                    let picked: EchoCartographerPick = Picker.pick(q, size: size, snapshot: s, orbit: orbit)
                    guard let want = Self.expected(q, s, size, orbit) else { skipped += 1; continue }
                    #expect(picked == want, "\(q) in \(size) at \(orbit), level \(s.levelNumber)")
                    switch want {
                    case .marker: markers += 1
                    case let .cell(c):
                        cells += 1
                        let floor: Cell? = Picker.floorCell(q, size: size, snapshot: s, orbit: orbit)
                        #expect(floor == c)
                    case .empty: empties += 1
                    }
                }
            }
        }
        #expect(skipped <= 5)
        #expect(markers > 300 && cells > 1_000 && empties > 100, "\(markers) \(cells) \(empties)")
    }

    @Test func theMarkerTargetIsTwentyTwoPoints() throws {
        let marker: Cell = Cell(x: 3, y: 3)
        let s: Snapshot = try Self.open(7, 7, marks: [marker])
        #expect(s.markers == [marker])
        let directions: [SIMD2<Double>] = [SIMD2(1, 0), SIMD2(-1, 0), SIMD2(0, 1), SIMD2(0.6, -0.8)]
        for size in Self.sizes {
            for orbit in Self.orbits {
                let camera: EchoCartographerCamera = Geometry.camera(s, aspect: size.x / size.y, orbit: orbit)
                guard let v = Geometry.project(Geometry.markerCentre(0, s), camera: camera) else {
                    Issue.record("marker behind the eye")
                    continue
                }
                let p: SIMD2<Double> = SIMD2(v.x * size.x, v.y * size.y)
                for direction in directions {
                    let near: EchoCartographerPick = Picker.pick(p + direction * 21, size: size, snapshot: s,
                                                                 orbit: orbit)
                    let far: EchoCartographerPick = Picker.pick(p + direction * 23, size: size, snapshot: s,
                                                                orbit: orbit)
                    #expect(near == .marker(marker))
                    #expect(far != .marker(marker))
                    if case .empty = far { Issue.record("23 points from a centre marker is still on the chamber") }
                }
            }
        }
    }

    @Test func aMarkerBeatsTheCellUnderItAndTiesGoToTheLowerIndex() throws {
        let marker: Cell = Cell(x: 2, y: 4)
        let s: Snapshot = try Self.open(6, 6, marks: [marker])
        for size in Self.sizes {
            for orbit in Self.orbits {
                let camera: EchoCartographerCamera = Geometry.camera(s, aspect: size.x / size.y, orbit: orbit)
                guard let v = Geometry.project(Geometry.cellCentre(marker, s), camera: camera) else { continue }
                let p: SIMD2<Double> = SIMD2(v.x * size.x, v.y * size.y)
                #expect(Picker.floorCell(p, size: size, snapshot: s, orbit: orbit) == marker)
                #expect(Picker.pick(p, size: size, snapshot: s, orbit: orbit) == .marker(marker))
            }
        }
        // Two markers mirrored about x = 0 at the authored orbit, placed in either order: a touch a point off the mirror
        // line picks the nearer one.
        let left: Cell = Cell(x: 7, y: 8)
        let right: Cell = Cell(x: 8, y: 8)
        let orders: [[Cell]] = [[right, left], [left, right]]
        let size: SIMD2<Double> = SIMD2(1000, 1000)
        for marks in orders {
            let t: Snapshot = try Self.open(16, 16, marks: marks)
            let camera: EchoCartographerCamera = Geometry.camera(t, aspect: 1, orbit: .authored)
            guard let a = Picker.projected(Geometry.cellCentre(left, t) + SIMD3(0, Geometry.markerY, 0),
                                           camera: camera, size: size),
                  let b = Picker.projected(Geometry.cellCentre(right, t) + SIMD3(0, Geometry.markerY, 0),
                                           camera: camera, size: size) else {
                Issue.record("markers behind the eye")
                continue
            }
            #expect(a.x < 500 && b.x > 500 && abs((a.x - 500) + (b.x - 500)) < 1e-9)
            #expect(Picker.pick(SIMD2(499, a.y), size: size, snapshot: t, orbit: .authored) == .marker(left))
            #expect(Picker.pick(SIMD2(501, a.y), size: size, snapshot: t, orbit: .authored) == .marker(right))
        }
        // Exactly equal distances (rounding never makes two projected rings exactly equidistant on demand, so the rule
        // is checked on the picker's own comparison): the lower cell index wins in either order.
        let t: Snapshot = try Self.open(16, 16, marks: [left, right])
        #expect(Picker.precedes(left, 10, right, 10, t))
        #expect(!Picker.precedes(right, 10, left, 10, t))
        #expect(Picker.precedes(right, 9.5, left, 10, t))
        #expect(!Picker.precedes(left, 10.5, right, 10, t))
        #expect(Picker.precedes(right, 21, nil, Double.infinity, t))
        #expect(Picker.precedes(Cell(x: 15, y: 7), 3, Cell(x: 0, y: 8), 3, t))
    }

    @Test func unusableInputPicksNothing() throws {
        let s: Snapshot = try Self.open(7, 7, marks: [Cell(x: 3, y: 3)])
        let camera: EchoCartographerCamera = Geometry.camera(s, aspect: 1, orbit: .authored)
        let good: SIMD2<Double> = SIMD2(195, 422)
        let size: SIMD2<Double> = SIMD2(390, 844)
        let badPoints: [SIMD2<Double>] = [SIMD2(.nan, 10), SIMD2(10, .infinity), SIMD2(-1, 10), SIMD2(10, 845),
                                          SIMD2(391, 10)]
        let badSizes: [SIMD2<Double>] = [SIMD2(0, 844), SIMD2(390, -1), SIMD2(.nan, 844), SIMD2(390, .infinity)]
        for point in badPoints {
            #expect(Picker.pick(point, size: size, snapshot: s, orbit: .authored) == .empty)
            #expect(Picker.floorCell(point, size: size, snapshot: s, orbit: .authored) == nil)
            #expect(Picker.ray(point, size: size, camera: camera) == nil)
        }
        for bad in badSizes {
            #expect(Picker.pick(good, size: bad, snapshot: s, orbit: .authored) == .empty)
            #expect(Picker.floorCell(good, size: bad, snapshot: s, orbit: .authored) == nil)
            #expect(Picker.ray(good, size: bad, camera: camera) == nil)
        }
        // The top edge looks past the chamber: empty, no cell; a unit ray otherwise.
        #expect(Picker.pick(SIMD2(195, 0), size: size, snapshot: s, orbit: .authored) == .empty)
        #expect(Picker.floorCell(SIMD2(195, 0), size: size, snapshot: s, orbit: .authored) == nil)
        if let r = Picker.ray(good, size: size, camera: camera) {
            #expect(abs((r.direction * r.direction).sum() - 1) < 1e-12)
        } else {
            Issue.record("no ray through the view's centre")
        }
    }
}
