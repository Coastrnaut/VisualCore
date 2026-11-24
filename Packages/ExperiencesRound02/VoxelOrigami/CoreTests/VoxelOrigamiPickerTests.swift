// VoxelOrigamiPickerTests — feature 444 (R02-G15-04) T-R02G1504-002 (FR-R02G1504-001, 003; SC-R02G1504-001;
// clarifications Q1, Q2). The picker against an independent pick written here (its own world mapping, cube corners,
// gift-wrapping hull, ray-crossing point-in-polygon, segment distance and front-most rule; only the camera and its
// projection are shared): 500 seeded points (seed 2_444) over six certified levels, three view sizes and three orbits;
// the 8-point allowance at 7 and 9 points beyond the outermost outline; the front-most of overlapping cubes; the root;
// unusable input. The turn prediction against an independent recomputation (own descendants, swinging test and
// right-hand quarter turn about the hinge axis), and the step chosen at the threshold ± 1 point.
// Explicit types, plain loops; each test well under 2 s.
import Foundation
import Testing
import VisualCoreSimulation
@testable import VoxelOrigamiCore

struct VoxelOrigamiPickerTests {
    typealias G = VoxelOrigamiSceneGeometry
    typealias Snapshot = VoxelOrigamiSceneSnapshot

    /// The seed of the seeded points.
    static let seed: UInt64 = 2_444
    /// The certified level numbers used.
    static let levelNumbers: [Int] = [1, 2, 5, 10, 20, 30]
    /// The view sizes in points: a phone in portrait, a tablet in landscape, a large tablet in landscape.
    static let sizes: [SIMD2<Double>] = [SIMD2(390, 844), SIMD2(1024, 768), SIMD2(1366, 1024)]
    /// The orbits: authored, the upper right corner and the lower left corner.
    static let orbits: [VoxelOrigamiOrbit] = [.authored,
                                              VoxelOrigamiOrbit(yaw: 60 * Double.pi / 180, pitch: 35 * Double.pi / 180),
                                              VoxelOrigamiOrbit(yaw: -60 * Double.pi / 180,
                                                                pitch: -20 * Double.pi / 180)]

    /// The opening snapshots of ``levelNumbers``.
    static func snapshots() throws -> [Snapshot] {
        var result: [Snapshot] = []
        for number in levelNumbers {
            result.append(try VoxelOrigamiExperienceCore.opening(number: number).snapshot(time: 0))
        }
        return result
    }

    // MARK: Independent reference

    /// The world point of cell `c` by the snapshot's mapping, recomputed: the box of the cells and the target cells,
    /// its centre m and s = 1.5 / (largest extent + 1).
    static func world(_ c: VoxelOrigamiVector, _ snap: Snapshot) -> SIMD3<Double> {
        var all: [VoxelOrigamiVector] = snap.cells
        all.append(contentsOf: snap.target)
        var low: SIMD3<Double> = SIMD3(1e9, 1e9, 1e9)
        var high: SIMD3<Double> = SIMD3(-1e9, -1e9, -1e9)
        for v in all {
            let p: SIMD3<Double> = SIMD3(Double(v.x), Double(v.y), Double(v.z))
            low = SIMD3(min(low.x, p.x), min(low.y, p.y), min(low.z, p.z))
            high = SIMD3(max(high.x, p.x), max(high.y, p.y), max(high.z, p.z))
        }
        let extent: SIMD3<Double> = high - low
        let s: Double = 1.5 / (max(extent.x, max(extent.y, extent.z)) + 1)
        let p: SIMD3<Double> = SIMD3(Double(c.x), Double(c.y), Double(c.z))
        return (p - (low + high) * 0.5) * s
    }

    /// The scale s, recomputed.
    static func scale(_ snap: Snapshot) -> Double {
        let a: SIMD3<Double> = world(VoxelOrigamiVector(0, 0, 0), snap)
        let b: SIMD3<Double> = world(VoxelOrigamiVector(1, 0, 0), snap)
        return b.x - a.x
    }

    /// View point of `p` (points, y down) or nil.
    static func screen(_ p: SIMD3<Double>, _ size: SIMD2<Double>, _ camera: VoxelOrigamiCamera) -> SIMD2<Double>? {
        guard let v = G.project(p, camera: camera) else { return nil }
        return SIMD2(v.x * size.x, v.y * size.y)
    }

    /// The projected corners of cube `i`: an axis-aligned cube of side 0.9 s (a quarter-turn rotation maps the corner
    /// set onto itself).
    static func cubeCorners(_ i: Int, _ snap: Snapshot, _ size: SIMD2<Double>,
                            _ camera: VoxelOrigamiCamera) -> [SIMD2<Double>] {
        let centre: SIMD3<Double> = world(snap.cells[i], snap)
        let h: Double = 0.45 * scale(snap)
        var result: [SIMD2<Double>] = []
        for sx in [-1.0, 1.0] {
            for sy in [-1.0, 1.0] {
                for sz in [-1.0, 1.0] {
                    if let q = screen(centre + SIMD3(sx * h, sy * h, sz * h), size, camera) { result.append(q) }
                }
            }
        }
        return result
    }

    /// The convex hull by gift wrapping (any winding).
    static func giftWrap(_ points: [SIMD2<Double>]) -> [SIMD2<Double>] {
        guard points.count >= 3 else { return points }
        var start: Int = 0
        for i in points.indices where points[i].x < points[start].x
            || (points[i].x == points[start].x && points[i].y < points[start].y) {
            start = i
        }
        var hull: [SIMD2<Double>] = []
        var current: Int = start
        var guardCount: Int = 0
        repeat {
            hull.append(points[current])
            var next: Int = (current + 1) % points.count
            for j in points.indices where j != current {
                let a: SIMD2<Double> = points[next] - points[current]
                let b: SIMD2<Double> = points[j] - points[current]
                let c: Double = a.x * b.y - a.y * b.x
                let farther: Bool = b.x * b.x + b.y * b.y > a.x * a.x + a.y * a.y
                if c < 0 || (c == 0 && farther) { next = j }
            }
            current = next
            guardCount += 1
        } while current != start && guardCount <= points.count
        return hull
    }

    /// Whether `p` lies inside `polygon` by ray crossing (boundary points count via the distance test instead).
    static func crossesInside(_ p: SIMD2<Double>, _ polygon: [SIMD2<Double>]) -> Bool {
        var inside: Bool = false
        var j: Int = polygon.count - 1
        for i in polygon.indices {
            let a: SIMD2<Double> = polygon[i]
            let b: SIMD2<Double> = polygon[j]
            if (a.y > p.y) != (b.y > p.y) {
                let x: Double = a.x + (p.y - a.y) * (b.x - a.x) / (b.y - a.y)
                if p.x < x { inside = !inside }
            }
            j = i
        }
        return inside
    }

    /// The distance from `p` to the boundary of `polygon`.
    static func edgeDistance(_ p: SIMD2<Double>, _ polygon: [SIMD2<Double>]) -> Double {
        var best: Double = Double.infinity
        for i in polygon.indices {
            let a: SIMD2<Double> = polygon[i]
            let b: SIMD2<Double> = polygon[(i + 1) % polygon.count]
            let d: SIMD2<Double> = b - a
            let l: Double = d.x * d.x + d.y * d.y
            var t: Double = l > 0 ? ((p.x - a.x) * d.x + (p.y - a.y) * d.y) / l : 0
            t = min(max(t, 0), 1)
            let q: SIMD2<Double> = a + d * t - p
            best = min(best, (q.x * q.x + q.y * q.y).squareRoot())
        }
        return best
    }

    /// The independent pick: of the cubes whose hull holds `p` or lies within `reach` points, the one nearest the eye
    /// (ties to the higher index); -1 for none.
    static func reference(_ p: SIMD2<Double>, _ snap: Snapshot, _ size: SIMD2<Double>, _ orbit: VoxelOrigamiOrbit,
                          reach: Double = 8) -> Int {
        let camera: VoxelOrigamiCamera = G.camera(snap, aspect: size.x / size.y, orbit: orbit)
        var best: Int = -1
        var bestDistance: Double = Double.infinity
        for i in snap.cells.indices {
            let hull: [SIMD2<Double>] = giftWrap(cubeCorners(i, snap, size, camera))
            guard crossesInside(p, hull) || edgeDistance(p, hull) <= reach else { continue }
            let d3: SIMD3<Double> = world(snap.cells[i], snap) - camera.eye
            let d: Double = (d3.x * d3.x + d3.y * d3.y + d3.z * d3.z).squareRoot()
            if d < bestDistance || (d == bestDistance && i > best) {
                best = i
                bestDistance = d
            }
        }
        return best
    }

    /// The picker's answer as an index (-1 for empty).
    static func index(_ pick: VoxelOrigamiPick) -> Int {
        if case .cube(let i) = pick { return i }
        return -1
    }

    // MARK: Picking

    @Test func fiveHundredSeededPointsMatchTheIndependentPick() throws {
        let snaps: [Snapshot] = try Self.snapshots()
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var hits: Int = 0
        var empties: Int = 0
        for n in 0..<500 {
            let snap: Snapshot = snaps[n % snaps.count]
            let size: SIMD2<Double> = Self.sizes[(n / snaps.count) % Self.sizes.count]
            let orbit: VoxelOrigamiOrbit = Self.orbits[(n / (snaps.count * Self.sizes.count)) % Self.orbits.count]
            var point: SIMD2<Double>
            if n % 2 == 0 {
                // Near a random cube's projected centre.
                let camera: VoxelOrigamiCamera = G.camera(snap, aspect: size.x / size.y, orbit: orbit)
                let cube: Int = random.int(0...(snap.cells.count - 1))
                let centre: SIMD2<Double> = Self.screen(Self.world(snap.cells[cube], snap), size, camera)
                    ?? SIMD2(0, 0)
                point = centre + SIMD2(random.double() * 120 - 60, random.double() * 120 - 60)
            } else {
                point = SIMD2(random.double() * size.x, random.double() * size.y)
            }
            let expected: Int = Self.reference(point, snap, size, orbit)
            let got: Int = Self.index(VoxelOrigamiPicker.pick(point, size: size, snapshot: snap, orbit: orbit))
            #expect(got == expected, "level \(snap.levelNumber) size \(size) orbit \(orbit) point \(point)")
            if expected >= 0 { hits += 1 } else { empties += 1 }
        }
        #expect(hits > 100 && empties > 50)
    }

    @Test func outlineIsTheCounterClockwiseHullOfTheCorners() throws {
        for snap in try Self.snapshots() {
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let camera: VoxelOrigamiCamera = G.camera(snap, aspect: size.x / size.y, orbit: orbit)
                    for i in snap.cells.indices {
                        let got: [SIMD2<Double>] = VoxelOrigamiPicker.outline(i, size: size, snapshot: snap,
                                                                              camera: camera)
                        let corners: [SIMD2<Double>] = Self.cubeCorners(i, snap, size, camera)
                        #expect(got.count >= 4 && got.count <= 6)
                        // Negative shoelace area in y-down points: counter-clockwise on the screen.
                        var area: Double = 0
                        for k in got.indices {
                            let a: SIMD2<Double> = got[k]
                            let b: SIMD2<Double> = got[(k + 1) % got.count]
                            area += a.x * b.y - b.x * a.y
                        }
                        #expect(area < 0)
                        // Every corner inside or on it, every vertex a corner.
                        for c in corners {
                            #expect(Self.crossesInside(c, got) || Self.edgeDistance(c, got) < 1e-6)
                        }
                        for v in got {
                            var nearest: Double = Double.infinity
                            for c in corners { nearest = min(nearest, ((v - c) * (v - c)).sum().squareRoot()) }
                            #expect(nearest < 1e-6)
                        }
                    }
                }
            }
        }
    }

    @Test func allowanceReachesSevenPointsButNotNine() throws {
        let directions: [SIMD2<Double>] = [SIMD2(1, 0), SIMD2(-1, 0), SIMD2(0, 1), SIMD2(0, -1)]
        var checked: Int = 0
        for snap in try Self.snapshots() {
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let camera: VoxelOrigamiCamera = G.camera(snap, aspect: size.x / size.y, orbit: orbit)
                    var all: [SIMD2<Double>] = []
                    for i in snap.cells.indices { all.append(contentsOf: Self.cubeCorners(i, snap, size, camera)) }
                    for direction in directions {
                        // The outermost corner along the direction: every outline lies behind it.
                        var extreme: SIMD2<Double> = all[0]
                        for p in all where (p * direction).sum() > (extreme * direction).sum() { extreme = p }
                        let near: SIMD2<Double> = extreme + direction * 7
                        let far: SIMD2<Double> = extreme + direction * 9
                        let nearPick: Int = Self.index(VoxelOrigamiPicker.pick(near, size: size, snapshot: snap,
                                                                               orbit: orbit))
                        #expect(nearPick >= 0)
                        #expect(nearPick == Self.reference(near, snap, size, orbit))
                        #expect(VoxelOrigamiPicker.pick(far, size: size, snapshot: snap, orbit: orbit) == .empty)
                        checked += 1
                    }
                }
            }
        }
        #expect(checked == Self.levelNumbers.count * 9 * 4)
    }

    @Test func frontMostOfOverlappingCubesWins() throws {
        var overlaps: Int = 0
        for snap in try Self.snapshots() {
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let camera: VoxelOrigamiCamera = G.camera(snap, aspect: size.x / size.y, orbit: orbit)
                    for i in snap.cells.indices {
                        guard let p = Self.screen(Self.world(snap.cells[i], snap), size, camera) else { continue }
                        // Cubes whose bare outline (no allowance) holds the point.
                        var holders: [Int] = []
                        for j in snap.cells.indices {
                            let hull: [SIMD2<Double>] = Self.giftWrap(Self.cubeCorners(j, snap, size, camera))
                            if Self.crossesInside(p, hull) { holders.append(j) }
                        }
                        let got: Int = Self.index(VoxelOrigamiPicker.pick(p, size: size, snapshot: snap,
                                                                          orbit: orbit))
                        #expect(got == Self.reference(p, snap, size, orbit))
                        if holders.count >= 2 && got >= 0 {
                            overlaps += 1
                            // The pick is nearer the eye than every other holder.
                            let e: SIMD3<Double> = camera.eye
                            let mine: SIMD3<Double> = Self.world(snap.cells[got], snap) - e
                            for j in holders where j != got {
                                let other: SIMD3<Double> = Self.world(snap.cells[j], snap) - e
                                #expect((mine * mine).sum() <= (other * other).sum())
                            }
                        }
                    }
                }
            }
        }
        #expect(overlaps > 0)
    }

    @Test func rootIsPickedWhereItIsFrontMost() throws {
        var roots: Int = 0
        for snap in try Self.snapshots() {
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let camera: VoxelOrigamiCamera = G.camera(snap, aspect: size.x / size.y, orbit: orbit)
                    guard let p = Self.screen(Self.world(snap.cells[0], snap), size, camera) else { continue }
                    let expected: Int = Self.reference(p, snap, size, orbit)
                    let got: VoxelOrigamiPick = VoxelOrigamiPicker.pick(p, size: size, snapshot: snap, orbit: orbit)
                    #expect(Self.index(got) == expected)
                    if expected == 0 {
                        #expect(got == .cube(0))
                        roots += 1
                    }
                }
            }
        }
        #expect(roots > 0)
    }

    @Test func unusableInputPicksNothing() throws {
        let snap: Snapshot = try Self.snapshots()[0]
        let size: SIMD2<Double> = Self.sizes[0]
        let camera: VoxelOrigamiCamera = G.camera(snap, aspect: size.x / size.y, orbit: .authored)
        let centre: SIMD2<Double> = Self.screen(Self.world(snap.cells[0], snap), size, camera) ?? SIMD2(0, 0)
        let badPoints: [SIMD2<Double>] = [SIMD2(.nan, 10), SIMD2(10, .infinity), SIMD2(-.infinity, .nan)]
        for p in badPoints {
            #expect(VoxelOrigamiPicker.pick(p, size: size, snapshot: snap, orbit: .authored) == .empty)
        }
        let badSizes: [SIMD2<Double>] = [SIMD2(0, 844), SIMD2(390, 0), SIMD2(-390, 844), SIMD2(.nan, 844),
                                         SIMD2(390, .infinity)]
        for s in badSizes {
            #expect(VoxelOrigamiPicker.pick(centre, size: s, snapshot: snap, orbit: .authored) == .empty)
            #expect(VoxelOrigamiPicker.viewPoint(SIMD3(0, 0, 0), size: s, camera: camera) == nil)
            #expect(VoxelOrigamiPicker.outline(0, size: s, snapshot: snap, camera: camera).isEmpty)
            #expect(VoxelOrigamiPicker.prediction(1, size: s, snapshot: snap, orbit: .authored) == nil)
        }
        #expect(VoxelOrigamiPicker.outline(-1, size: size, snapshot: snap, camera: camera).isEmpty)
        #expect(VoxelOrigamiPicker.outline(snap.cells.count, size: size, snapshot: snap, camera: camera).isEmpty)
        let behind: SIMD3<Double> = camera.eye + (camera.eye - camera.target)
        #expect(VoxelOrigamiPicker.viewPoint(behind, size: size, camera: camera) == nil)
        // A non-finite orbit is the authored one.
        let nanOrbit: VoxelOrigamiOrbit = VoxelOrigamiOrbit(yaw: .nan, pitch: .infinity)
        #expect(VoxelOrigamiPicker.pick(centre, size: size, snapshot: snap, orbit: nanOrbit)
            == VoxelOrigamiPicker.pick(centre, size: size, snapshot: snap, orbit: .authored))
    }

    // MARK: Prediction

    /// The independent prediction of hinge `h`: the descendants of h off its axis, turned a quarter by the right-hand
    /// rule (`step` · a × r for the offset r from cube h); the one farthest from the axis (lowest index on ties)
    /// projected after minus before. Nil when nothing swings.
    static func referencePrediction(_ h: Int, _ snap: Snapshot, _ size: SIMD2<Double>, _ orbit: VoxelOrigamiOrbit,
                                    step: Int) -> SIMD2<Double>? {
        guard let parent = snap.cubes[h].parent else { return nil }
        let camera: VoxelOrigamiCamera = G.camera(snap, aspect: size.x / size.y, orbit: orbit)
        let pivot: VoxelOrigamiVector = snap.cells[h]
        let a: VoxelOrigamiVector = pivot - snap.cells[parent]
        var before: SIMD3<Double> = SIMD3(0, 0, 0)
        var after: SIMD3<Double> = SIMD3(0, 0, 0)
        var count: Int = 0
        var farthest: Int = -1
        for i in snap.cubes.indices where i != h {
            // A descendant: walking up the parents reaches h.
            var walker: Int? = snap.cubes[i].parent
            var isBelow: Bool = false
            while let w = walker {
                if w == h {
                    isBelow = true
                    break
                }
                walker = snap.cubes[w].parent
            }
            guard isBelow else { continue }
            let r: VoxelOrigamiVector = snap.cells[i] - pivot
            let c: VoxelOrigamiVector = VoxelOrigamiVector(a.y * r.z - a.z * r.y, a.z * r.x - a.x * r.z,
                                                           a.x * r.y - a.y * r.x)
            guard c != .zero else { continue }
            let along: Int = a.x * r.x + a.y * r.y + a.z * r.z
            let moved: VoxelOrigamiVector = VoxelOrigamiVector(pivot.x + a.x * along + step * c.x,
                                                               pivot.y + a.y * along + step * c.y,
                                                               pivot.z + a.z * along + step * c.z)
            let off: Int = r.x * r.x + r.y * r.y + r.z * r.z - along * along
            count += 1
            if off > farthest {
                farthest = off
                before = world(snap.cells[i], snap)
                after = world(moved, snap)
            }
        }
        guard count > 0,
              let p0 = screen(before, size, camera),
              let p1 = screen(after, size, camera) else { return nil }
        return p1 - p0
    }

    @Test func predictionMatchesTheIndependentRecomputation() throws {
        var predicted: Int = 0
        var idle: Int = 0
        for snap in try Self.snapshots() {
            for size in Self.sizes {
                for orbit in Self.orbits {
                    #expect(VoxelOrigamiPicker.prediction(0, size: size, snapshot: snap, orbit: orbit) == nil)
                    #expect(VoxelOrigamiPicker.prediction(-1, size: size, snapshot: snap, orbit: orbit) == nil)
                    #expect(VoxelOrigamiPicker.prediction(snap.cubes.count, size: size, snapshot: snap,
                                                          orbit: orbit) == nil)
                    for h in 1..<snap.cubes.count {
                        let got: VoxelOrigamiTurnPrediction? = VoxelOrigamiPicker.prediction(h, size: size,
                                                                                            snapshot: snap,
                                                                                            orbit: orbit)
                        let plus: SIMD2<Double>? = Self.referencePrediction(h, snap, size, orbit, step: 1)
                        let minus: SIMD2<Double>? = Self.referencePrediction(h, snap, size, orbit, step: -1)
                        guard let p = plus, let m = minus else {
                            #expect(got == nil, "hinge \(h) swings nothing")
                            idle += 1
                            continue
                        }
                        guard let g = got else {
                            Issue.record("hinge \(h) has no prediction")
                            continue
                        }
                        #expect(g.hinge == h)
                        #expect(abs(g.plus.x - p.x) < 1e-6 && abs(g.plus.y - p.y) < 1e-6)
                        #expect(abs(g.minus.x - m.x) < 1e-6 && abs(g.minus.y - m.y) < 1e-6)
                        predicted += 1
                    }
                }
            }
        }
        #expect(predicted > 0)
        #expect(idle > 0, "a leaf hinge swings nothing")
    }

    /// The independent step: the larger projection of `travel` onto the unit motions (ties to +1), once it reaches
    /// `threshold`.
    static func referenceStep(_ travel: SIMD2<Double>, plus: SIMD2<Double>, minus: SIMD2<Double>,
                              threshold: Double) -> Int? {
        let lp: Double = (plus * plus).sum().squareRoot()
        let lm: Double = (minus * minus).sum().squareRoot()
        guard lp > 0, lm > 0 else { return nil }
        let ap: Double = (travel * plus).sum() / lp
        let am: Double = (travel * minus).sum() / lm
        let best: Double = max(ap, am)
        guard best >= threshold else { return nil }
        return ap >= am ? 1 : -1
    }

    @Test func stepPicksTheSignAtTheThreshold() throws {
        let threshold: Double = 24
        var checked: Int = 0
        for snap in try Self.snapshots() {
            for size in Self.sizes {
                for orbit in Self.orbits {
                    for h in 1..<snap.cubes.count {
                        guard let g = VoxelOrigamiPicker.prediction(h, size: size, snapshot: snap, orbit: orbit)
                        else { continue }
                        let lp: Double = (g.plus * g.plus).sum().squareRoot()
                        let lm: Double = (g.minus * g.minus).sum().squareRoot()
                        guard lp > 1e-9, lm > 1e-9 else { continue }
                        let unitPlus: SIMD2<Double> = g.plus / lp
                        let unitMinus: SIMD2<Double> = g.minus / lm
                        // Along +1's motion: +1 from threshold + 1, nothing at threshold − 1.
                        #expect(g.step(for: unitPlus * (threshold + 1), threshold: threshold) == 1)
                        #expect(g.step(for: unitPlus * (threshold - 1), threshold: threshold) == nil)
                        // Along −1's motion: the independent rule (−1 unless the motions point the same way).
                        let travelMinus: SIMD2<Double> = unitMinus * (threshold + 1)
                        let expectedMinus: Int? = Self.referenceStep(travelMinus, plus: g.plus, minus: g.minus,
                                                                     threshold: threshold)
                        #expect(g.step(for: travelMinus, threshold: threshold) == expectedMinus)
                        let along: Double = (unitPlus * unitMinus).sum()
                        if along < 0.999 { #expect(expectedMinus == -1) }
                        #expect(g.step(for: unitMinus * (threshold - 1), threshold: threshold) == nil)
                        checked += 1
                    }
                }
            }
        }
        #expect(checked > 0)
        // Hand values: opposite motions, a zero motion, unusable travel.
        let opposite: VoxelOrigamiTurnPrediction = VoxelOrigamiTurnPrediction(hinge: 1, plus: SIMD2(30, 0),
                                                                              minus: SIMD2(-30, 0))
        #expect(opposite.step(for: SIMD2(25, 3), threshold: 24) == 1)
        #expect(opposite.step(for: SIMD2(-25, 3), threshold: 24) == -1)
        #expect(opposite.step(for: SIMD2(23, 0), threshold: 24) == nil)
        #expect(opposite.step(for: SIMD2(0, 40), threshold: 24) == nil)
        #expect(opposite.step(for: SIMD2(.nan, 40), threshold: 24) == nil)
        let zero: VoxelOrigamiTurnPrediction = VoxelOrigamiTurnPrediction(hinge: 1, plus: SIMD2(0, 0),
                                                                          minus: SIMD2(-30, 0))
        #expect(zero.step(for: SIMD2(-40, 0), threshold: 24) == nil)
    }

    /// A subtree symmetric about its hinge line (cubes 2 and 3 on opposite sides of hinge 1's line) still predicts a
    /// motion: the tracked cube is the first of the two farthest from the line, so it is never on it.
    @Test func aSymmetricSubtreeStillPredictsAMotion() throws {
        let cubes: [VoxelOrigamiCube] = [
            .root,
            VoxelOrigamiCube(parent: 0, direction: VoxelOrigamiVector(1, 0, 0)),
            VoxelOrigamiCube(parent: 1, direction: VoxelOrigamiVector(0, 1, 0)),
            VoxelOrigamiCube(parent: 1, direction: VoxelOrigamiVector(0, -1, 0)),
        ]
        let line: [VoxelOrigamiVector] = [VoxelOrigamiVector(0, 0, 0), VoxelOrigamiVector(1, 0, 0),
                                          VoxelOrigamiVector(2, 0, 0), VoxelOrigamiVector(3, 0, 0)]
        let level: VoxelOrigamiLevel = try VoxelOrigamiLevel(id: "symmetric", seed: 1, difficulty: 1, cubes: cubes,
                                                             target: line, orientations: .any, budget: 4)
        let snap: VoxelOrigamiSceneSnapshot = VoxelOrigamiSceneSnapshot(play: VoxelOrigamiPlay(level: level),
                                                                        chosenHinge: 1, levelNumber: 1, time: 0)
        let pose: VoxelOrigamiPose = VoxelOrigamiLattice.pose(cubes, turns: snap.turns)
        let moving: [Int] = VoxelOrigamiLattice.swinging(cubes, pose: pose, hinge: 1)
        #expect(moving == [2, 3])
        #expect(VoxelOrigamiPicker.trackedCube(1, cubes: cubes, pose: pose, moving: moving) == 2)
        let size: SIMD2<Double> = SIMD2(1024, 768)
        let prediction: VoxelOrigamiTurnPrediction? = VoxelOrigamiPicker.prediction(1, size: size, snapshot: snap,
                                                                                    orbit: .authored)
        #expect(prediction != nil)
        if let prediction {
            let plus: Double = (prediction.plus.x * prediction.plus.x
                + prediction.plus.y * prediction.plus.y).squareRoot()
            let minus: Double = (prediction.minus.x * prediction.minus.x
                + prediction.minus.y * prediction.minus.y).squareRoot()
            #expect(plus > 1 && minus > 1, "a quarter turn moves the tracked cube on screen")
        }
    }

}
