// AmethystEscapePickerTests — feature 364 (R02-G07-04) T-R02G0704-003 (FR-R02G0704-001, 002, 004; SC-R02G0704-001;
// clarifications Q1, Q2). The analytic picker against an independent pick written here: the same ray (only
// `AmethystEscapePicker.ray` and the drawn camera are shared), its own closest-approach sphere test for the pearl, its
// own plane intersection and annulus test for the shells, and its own projector and distance to a shell's projected
// top-ring midline (a 90-sample scan refined by a golden-section search on the angle) for the 22-point fallback, on 500
// seeded points (seed 2_364) per certified level (openings of levels 1, 21, 41, 61 and 81), the three view sizes and
// the five orbits (the authored orbit and the four orbit limits) cycling with the point; the drag angle against its own
// plane hit; the minimum target around the pearl and beside the outer shell; the angle's sign (+x towards +z
// positive); and non-finite input. Plain loops and explicit types (CI type-check rule).
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
@testable import AmethystEscapeCore

@Suite struct AmethystEscapePickerTests {
    typealias Geometry = AmethystEscapeSceneGeometry
    typealias Snapshot = AmethystEscapeSceneSnapshot
    typealias Picker = AmethystEscapePicker
    typealias Orbit = AmethystEscapeOrbit

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

    /// How close to a decision boundary (points) the independent midline fallback counts as ambiguous: the picker's
    /// 128-chord polyline lies within a fraction of a point of the true projected circle.
    static let boundary: Double = 0.25

    /// The opening snapshots of the certified levels 1, 21, 41, 61 and 81.
    static func certifiedSnapshots() throws -> [Snapshot] {
        var result: [Snapshot] = []
        for number in [1, 21, 41, 61, 81] {
            result.append(try AmethystEscapeExperienceCore.opening(number: number).snapshot(time: 0))
        }
        return result
    }

    /// The camera the picker draws with for `size` and `orbit`.
    static func camera(_ snapshot: Snapshot, size: SIMD2<Double>, orbit: Orbit) -> AmethystEscapeCamera {
        Geometry.camera(snapshot, aspect: size.x / size.y, orbit: orbit)
    }

    /// Whether the ray meets the sphere ahead, by the closest approach: the foot of the perpendicular from `centre`
    /// lies at s = (centre − origin)·direction and the squared miss distance is |centre − origin|² − s²; the far
    /// intersection s + √(radius² − miss²) must lie ahead of the origin.
    static func meetsSphere(origin: SIMD3<Double>, direction: SIMD3<Double>, centre: SIMD3<Double>,
                            radius: Double) -> Bool {
        let toCentre: SIMD3<Double> = centre - origin
        let s: Double = (toCentre * direction).sum()
        let miss: Double = (toCentre * toCentre).sum() - s * s
        guard miss <= radius * radius else { return false }
        return s + (radius * radius - miss).squareRoot() > 0
    }

    /// The point where the ray meets y = `height` ahead of the origin, by the plane equation; nil otherwise.
    static func plane(origin: SIMD3<Double>, direction: SIMD3<Double>, height: Double) -> SIMD3<Double>? {
        guard direction.y != 0 else { return nil }
        let t: Double = (height - origin.y) / direction.y
        guard t > 0 else { return nil }
        return origin + direction * t
    }

    /// The projection of `world` in view points of `size`.
    static func points(_ world: SIMD3<Double>, size: SIMD2<Double>, camera: AmethystEscapeCamera) -> SIMD2<Double>? {
        guard let v = Geometry.project(world, camera: camera) else { return nil }
        return SIMD2(v.x * size.x, v.y * size.y)
    }

    /// The distance in points between `a` and `b`.
    static func gap(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let d: SIMD2<Double> = a - b
        return (d.x * d.x + d.y * d.y).squareRoot()
    }

    /// The inner radius r_k = 0.2 + k·w of shell `k`, written out.
    static func inner(_ k: Int, _ snapshot: Snapshot) -> Double { 0.2 + Double(k) * 0.8 / Double(snapshot.shells.count) }

    /// The top height h_k = 0.08 + 0.06·(n − 1 − k) of shell `k`, written out.
    static func height(_ k: Int, _ snapshot: Snapshot) -> Double {
        0.08 + 0.06 * Double(snapshot.shells.count - 1 - k)
    }

    /// A plain projector written here: the rows of the camera's view-projection, clip = M·(p, 1), NDC = clip / w and
    /// view points ((x + 1)/2 · width, (1 − y)/2 · height); +infinity behind the camera.
    struct Projector {
        let row0: SIMD4<Double>
        let row1: SIMD4<Double>
        let row3: SIMD4<Double>
        let size: SIMD2<Double>

        init(_ camera: AmethystEscapeCamera, size: SIMD2<Double>) {
            let m: Mat4 = camera.viewProjection
            let a: Vec4 = m.row(0), b: Vec4 = m.row(1), d: Vec4 = m.row(3)
            row0 = SIMD4(a.x, a.y, a.z, a.w)
            row1 = SIMD4(b.x, b.y, b.z, b.w)
            row3 = SIMD4(d.x, d.y, d.z, d.w)
            self.size = size
        }

        /// The distance in points from `point` to the projection of `world`.
        func distance(_ point: SIMD2<Double>, _ world: SIMD3<Double>) -> Double {
            let p: SIMD4<Double> = SIMD4(world.x, world.y, world.z, 1)
            let w: Double = (row3 * p).sum()
            guard w > 0 else { return .infinity }
            let x: Double = ((row0 * p).sum() / w + 1) / 2 * size.x - point.x
            let y: Double = (1 - (row1 * p).sum() / w) / 2 * size.y - point.y
            return (x * x + y * y).squareRoot()
        }
    }

    /// The distance in points from `point` to the projection of the midline point of shell `k` at `angle`.
    static func midlinePoint(_ point: SIMD2<Double>, _ k: Int, angle: Double, snapshot: Snapshot,
                             projector: Projector) -> Double {
        let r: Double = inner(k, snapshot) + 0.4 / Double(snapshot.shells.count)
        return projector.distance(point, SIMD3(r * cos(angle), height(k, snapshot), r * sin(angle)))
    }

    /// The distance in points from `point` to shell `k`'s projected midline circle: the best of 90 samples, refined
    /// by a golden-section search over the neighbouring samples.
    static func midline(_ point: SIMD2<Double>, _ k: Int, size: SIMD2<Double>, snapshot: Snapshot,
                        camera: AmethystEscapeCamera) -> Double {
        midline(point, k, snapshot: snapshot, projector: Projector(camera, size: size))
    }

    /// ``midline(_:_:size:snapshot:camera:)`` with a projector made once.
    static func midline(_ point: SIMD2<Double>, _ k: Int, snapshot: Snapshot, projector: Projector) -> Double {
        let samples: Int = 90
        let step: Double = 2 * Double.pi / Double(samples)
        var bestAngle: Double = 0
        var best: Double = .infinity
        for i in 0..<samples {
            let a: Double = Double(i) * step
            let d: Double = midlinePoint(point, k, angle: a, snapshot: snapshot, projector: projector)
            if d < best {
                best = d
                bestAngle = a
            }
        }
        var lo: Double = bestAngle - step
        var hi: Double = bestAngle + step
        let ratio: Double = (5.0.squareRoot() - 1) / 2
        for _ in 0..<26 {
            let a: Double = hi - ratio * (hi - lo)
            let b: Double = lo + ratio * (hi - lo)
            if midlinePoint(point, k, angle: a, snapshot: snapshot, projector: projector)
                < midlinePoint(point, k, angle: b, snapshot: snapshot, projector: projector) {
                hi = b
            } else {
                lo = a
            }
        }
        let refined: Double = midlinePoint(point, k, angle: (lo + hi) / 2, snapshot: snapshot, projector: projector)
        return min(best, refined)
    }

    /// The independent pick of `point` and whether it rests on a decision within ``boundary`` points of the midline
    /// fallback's limits (22 points, or a near tie between two shells).
    static func expected(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: Snapshot,
                         orbit: Orbit) -> (pick: AmethystEscapePick, ambiguous: Bool) {
        let camera: AmethystEscapeCamera = Self.camera(snapshot, size: size, orbit: orbit)
        guard let r = Picker.ray(point, size: size, camera: camera) else { return (.empty, false) }
        let n: Int = snapshot.shells.count
        let w: Double = 0.8 / Double(n)
        let pearl: SIMD3<Double> = Geometry.pearlCentre(snapshot)
        if meetsSphere(origin: r.origin, direction: r.direction, centre: pearl, radius: 0.3 * w) {
            return (.pearl, false)
        }
        if let q = points(pearl, size: size, camera: camera), gap(q, point) <= 22 { return (.pearl, false) }
        for k in 0..<n {
            if let p = plane(origin: r.origin, direction: r.direction, height: height(k, snapshot)) {
                let radial: Double = (p.x * p.x + p.z * p.z).squareRoot()
                if radial >= inner(k, snapshot) && radial <= inner(k, snapshot) + w { return (.shell(k), false) }
            }
        }
        let projector: Projector = Projector(camera, size: size)
        var distances: [Double] = []
        for k in 0..<n {
            distances.append(midline(point, k, snapshot: snapshot, projector: projector))
        }
        var bestK: Int = -1
        var bestD: Double = .infinity
        for k in 0..<n where distances[k] <= 22 && distances[k] < bestD {
            bestD = distances[k]
            bestK = k
        }
        var ambiguous: Bool = false
        for k in 0..<n where abs(distances[k] - 22) < boundary { ambiguous = true }
        if bestK >= 0 {
            for k in 0..<n where k != bestK && abs(distances[k] - bestD) < boundary { ambiguous = true }
        }
        return (bestK >= 0 ? .shell(bestK) : .empty, ambiguous)
    }

    /// The independent drag angle of `point` on shell `k`'s plane: atan2(z, x) of the plane hit, or nil.
    static func expectedAngle(_ k: Int, _ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: Snapshot,
                              orbit: Orbit) -> Double? {
        let camera: AmethystEscapeCamera = Self.camera(snapshot, size: size, orbit: orbit)
        guard let r = Picker.ray(point, size: size, camera: camera),
              let p = plane(origin: r.origin, direction: r.direction, height: height(k, snapshot)) else { return nil }
        return atan2(p.z, p.x)
    }

    @Test func picksMatchAnIndependentPickOnSeededPoints() throws {
        let snapshots: [Snapshot] = try Self.certifiedSnapshots()
        var random: SeededRandom = SeededRandom(seed: 2_364)
        var pearls: Int = 0, tops: Int = 0, fallbacks: Int = 0, empties: Int = 0
        var mismatches: Int = 0, ambiguous: Int = 0, total: Int = 0, angles: Int = 0
        for snapshot in snapshots {
            for i in 0..<500 {
                // The view size and the orbit cycle with the point (3 and 5 are coprime: all 15 pairs).
                let size: SIMD2<Double> = Self.sizes[i % Self.sizes.count]
                let orbit: Orbit = Self.orbits[i % Self.orbits.count]
                let point: SIMD2<Double> = SIMD2(random.double() * size.x, random.double() * size.y)
                let pick: AmethystEscapePick = Picker.pick(point, size: size, snapshot: snapshot, orbit: orbit)
                let expected: (pick: AmethystEscapePick, ambiguous: Bool) =
                    Self.expected(point, size: size, snapshot: snapshot, orbit: orbit)
                total += 1
                if expected.ambiguous {
                    ambiguous += 1
                } else if pick != expected.pick {
                    mismatches += 1
                    Issue.record("point \(point) size \(size) orbit \(orbit): \(pick) vs \(expected.pick)")
                }
                switch pick {
                case .pearl: pearls += 1
                case .shell(let k):
                    let camera: AmethystEscapeCamera = Self.camera(snapshot, size: size, orbit: orbit)
                    var onTop: Bool = false
                    if let r = Picker.ray(point, size: size, camera: camera),
                       let p = Self.plane(origin: r.origin, direction: r.direction,
                                          height: Self.height(k, snapshot)) {
                        let radial: Double = (p.x * p.x + p.z * p.z).squareRoot()
                        let w: Double = 0.8 / Double(snapshot.shells.count)
                        onTop = radial >= Self.inner(k, snapshot) && radial <= Self.inner(k, snapshot) + w
                    }
                    if onTop { tops += 1 } else { fallbacks += 1 }
                case .empty: empties += 1
                }
                let shell: Int = Int(random.next() % UInt64(snapshot.shells.count))
                let angle: Double? = Picker.angle(shell: shell, at: point, size: size, snapshot: snapshot,
                                                  orbit: orbit)
                let want: Double? = Self.expectedAngle(shell, point, size: size, snapshot: snapshot, orbit: orbit)
                #expect((angle == nil) == (want == nil))
                if let angle, let want {
                    #expect(abs(angle - want) < 1e-9)
                    angles += 1
                }
            }
        }
        #expect(total == 2_500)
        #expect(mismatches == 0)
        #expect(ambiguous < total / 100, "ambiguous \(ambiguous)")
        #expect(pearls > 0 && tops > 150 && fallbacks > 0 && empties > 150,
                "pearls \(pearls) tops \(tops) fallbacks \(fallbacks) empties \(empties)")
        #expect(angles > 1_500)
    }

    @Test func thePearlHasAMinimumTargetOf22Points() throws {
        #expect(Picker.minimumTarget == 22)
        let snapshots: [Snapshot] = try Self.certifiedSnapshots()
        var checked: Int = 0
        for snapshot in snapshots {
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let camera: AmethystEscapeCamera = Self.camera(snapshot, size: size, orbit: orbit)
                    guard let centre = Self.points(Geometry.pearlCentre(snapshot), size: size, camera: camera) else {
                        Issue.record("pearl behind the camera")
                        continue
                    }
                    #expect(Picker.pick(centre, size: size, snapshot: snapshot, orbit: orbit) == .pearl)
                    for k in 0..<12 {
                        let angle: Double = 2 * Double.pi * Double(k) / 12
                        for radius in [8.0, 14.0, 21.5] {
                            let p: SIMD2<Double> = centre + SIMD2(cos(angle), sin(angle)) * radius
                            #expect(Picker.pick(p, size: size, snapshot: snapshot, orbit: orbit) == .pearl)
                            checked += 1
                        }
                        // Beyond 22 points and off the pearl sphere, the pearl is not picked.
                        let far: SIMD2<Double> = centre + SIMD2(cos(angle), sin(angle)) * 40
                        let expected: (pick: AmethystEscapePick, ambiguous: Bool) =
                            Self.expected(far, size: size, snapshot: snapshot, orbit: orbit)
                        if expected.pick != .pearl && !expected.ambiguous {
                            #expect(Picker.pick(far, size: size, snapshot: snapshot, orbit: orbit) == expected.pick)
                        }
                    }
                }
            }
        }
        #expect(checked > 0)
    }

    @Test func aTouchJustBesideTheOuterShellFallsBackToItsMidline() throws {
        let snapshots: [Snapshot] = try Self.certifiedSnapshots()
        var fallbacks: Int = 0
        for snapshot in snapshots {
            let n: Int = snapshot.shells.count
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let camera: AmethystEscapeCamera = Self.camera(snapshot, size: size, orbit: orbit)
                    for k in 0..<8 {
                        // Just outside the outer shell's rim on its own plane: its midline is w/2 + 0.01 away.
                        let angle: Double = 2 * Double.pi * (Double(k) + 0.25) / 8
                        let world: SIMD3<Double> = SIMD3(cos(angle), 0, sin(angle)) * (1 + 0.01)
                            + SIMD3(0, Self.height(n - 1, snapshot), 0)
                        guard let p = Self.points(world, size: size, camera: camera),
                              p.x >= 0, p.x <= size.x, p.y >= 0, p.y <= size.y else { continue }
                        let expected: (pick: AmethystEscapePick, ambiguous: Bool) =
                            Self.expected(p, size: size, snapshot: snapshot, orbit: orbit)
                        guard !expected.ambiguous else { continue }
                        let pick: AmethystEscapePick = Picker.pick(p, size: size, snapshot: snapshot, orbit: orbit)
                        #expect(pick == expected.pick)
                        if pick == .shell(n - 1) {
                            let d: Double = Self.midline(p, n - 1, size: size, snapshot: snapshot, camera: camera)
                            #expect(d <= 22 && d > 0)
                            fallbacks += 1
                        }
                    }
                    // The top-left corner is far from the crystal: empty space.
                    let corner: SIMD2<Double> = SIMD2(1, 1)
                    #expect(Self.expected(corner, size: size, snapshot: snapshot, orbit: orbit).pick == .empty)
                    #expect(Picker.pick(corner, size: size, snapshot: snapshot, orbit: orbit) == .empty)
                }
            }
        }
        #expect(fallbacks > 0)
    }

    @Test func everyWedgeTopCentrePicksItsShellAtEveryOrbit() throws {
        let snapshots: [Snapshot] = try Self.certifiedSnapshots()
        for snapshot in snapshots {
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let camera: AmethystEscapeCamera = Self.camera(snapshot, size: size, orbit: orbit)
                    for shell in 0..<snapshot.shells.count {
                        for sector in 0..<snapshot.sectors {
                            let top: SIMD3<Double> = Geometry.wedgeTopCentre(shell: shell, sector: sector, snapshot)
                            guard let p = Self.points(top, size: size, camera: camera) else { continue }
                            let pick: AmethystEscapePick = Picker.pick(p, size: size, snapshot: snapshot,
                                                                       orbit: orbit)
                            let expected: (pick: AmethystEscapePick, ambiguous: Bool) =
                                Self.expected(p, size: size, snapshot: snapshot, orbit: orbit)
                            #expect(pick == expected.pick)
                            // An inner (taller) shell's top can hide it, and the pearl wins; otherwise it is this shell.
                            if case .shell(let k) = pick { #expect(k <= shell) }
                        }
                    }
                }
            }
        }
    }

    @Test func theAngleRunsFromPlusXTowardsPlusZ() throws {
        let snapshot: Snapshot = try Self.certifiedSnapshots()[0]
        let size: SIMD2<Double> = SIMD2(1_180, 820)
        for orbit in Self.orbits {
            let camera: AmethystEscapeCamera = Self.camera(snapshot, size: size, orbit: orbit)
            for shell in 0..<snapshot.shells.count {
                let r: Double = Self.inner(shell, snapshot) + 0.4 / Double(snapshot.shells.count)
                let h: Double = Self.height(shell, snapshot)
                for degrees in [-150.0, -90, -30, 0, 15, 45, 90, 135, 170] {
                    let a: Double = degrees * Double.pi / 180
                    guard let p = Self.points(SIMD3(r * cos(a), h, r * sin(a)), size: size, camera: camera) else {
                        continue
                    }
                    let angle: Double? = Picker.angle(shell: shell, at: p, size: size, snapshot: snapshot,
                                                      orbit: orbit)
                    #expect(angle != nil)
                    if let angle { #expect(abs(angle - a) < 1e-6, "shell \(shell) \(degrees)° got \(angle)") }
                }
                // A point on +x turned slightly towards +z has a small positive angle; towards −z a negative one.
                if let plus = Self.points(SIMD3(r * cos(0.2), h, r * sin(0.2)), size: size, camera: camera),
                   let minus = Self.points(SIMD3(r * cos(-0.2), h, r * sin(-0.2)), size: size, camera: camera) {
                    #expect((Picker.angle(shell: shell, at: plus, size: size, snapshot: snapshot,
                                          orbit: orbit) ?? 0) > 0)
                    #expect((Picker.angle(shell: shell, at: minus, size: size, snapshot: snapshot,
                                          orbit: orbit) ?? 0) < 0)
                }
            }
            let centre: SIMD2<Double> = size / 2
            #expect(Picker.angle(shell: -1, at: centre, size: size, snapshot: snapshot, orbit: orbit) == nil)
            #expect(Picker.angle(shell: snapshot.shells.count, at: centre, size: size, snapshot: snapshot,
                                 orbit: orbit) == nil)
        }
    }

    @Test func nonFiniteOrUnusableInputPicksNothing() throws {
        let snapshot: Snapshot = try Self.certifiedSnapshots()[0]
        let size: SIMD2<Double> = SIMD2(390, 844)
        let camera: AmethystEscapeCamera = Self.camera(snapshot, size: size, orbit: .authored)
        let centre: SIMD2<Double> = SIMD2(195, 422)
        let wedge: SIMD2<Double>? = Self.points(Geometry.wedgeTopCentre(shell: 0, sector: 0, snapshot), size: size,
                                                camera: camera)
        #expect(wedge.map { Picker.pick($0, size: size, snapshot: snapshot, orbit: .authored) } == .shell(0))
        let bad: [SIMD2<Double>] = [SIMD2(.nan, 422), SIMD2(195, .infinity), SIMD2(-.infinity, .nan),
                                    SIMD2(-5, 422), SIMD2(195, 900)]
        for point in bad {
            #expect(Picker.pick(point, size: size, snapshot: snapshot, orbit: .authored) == .empty)
            #expect(Picker.ray(point, size: size, camera: camera) == nil)
            #expect(Picker.angle(shell: 0, at: point, size: size, snapshot: snapshot, orbit: .authored) == nil)
        }
        let sizes: [SIMD2<Double>] = [SIMD2(0, 844), SIMD2(390, -1), SIMD2(.nan, 844), SIMD2(390, .infinity)]
        for badSize in sizes {
            #expect(Picker.pick(centre, size: badSize, snapshot: snapshot, orbit: .authored) == .empty)
            #expect(Picker.ray(centre, size: badSize, camera: camera) == nil)
            #expect(Picker.angle(shell: 0, at: centre, size: badSize, snapshot: snapshot, orbit: .authored) == nil)
        }
        // A non-finite orbit is the authored one.
        let odd: Orbit = Orbit(yaw: .nan, pitch: .infinity)
        if let wedge {
            #expect(Picker.pick(wedge, size: size, snapshot: snapshot, orbit: odd)
                == Picker.pick(wedge, size: size, snapshot: snapshot, orbit: .authored))
        }
        // The ray of the view centre is unit length and passes through the crystal centre.
        if let r = Picker.ray(centre, size: size, camera: camera) {
            #expect(abs(Geometry.length(r.direction) - 1) < 1e-12)
            let t: Double = Geometry.dot(-r.origin, r.direction)
            #expect(Geometry.length(r.origin + r.direction * t) < 1e-9)
        } else {
            Issue.record("no ray through the view centre")
        }
    }
}
