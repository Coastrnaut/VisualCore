// MoonlitMechanismPickerTests — feature 434 (R02-G14-04) T-R02G1404-002 (FR-R02G1404-005, 006; SC-R02G1404-001, 004;
// clarifications Q1, Q5). The analytic picker of Moonlit Mechanism against an independent pick written here (its own
// camera basis and projection from the camera's eye, target, field of view and aspect; its own lamp, ladder, card and
// gear places from the wall formulas; its own point-in-quadrilateral, segment distance and painter's order): 500
// seeded points (SeededRandom seed 2_434) per view size and orbit over certified levels 1, 50 and 100 (their openings,
// key frame 0 shown), at 3 view sizes and 3 orbits; the 22-point target of the lamp, the ladder and a card at 21 and 23
// points; the lamp beats the cards and the cards beat the gears; the front-most gear wins over a gear behind it and
// equal depths go to the higher index; equally near cards go to the lower index; the drag angle runs clockwise on
// screen; unusable input picks nothing. Explicit types, plain loops; well under 10 s each.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
@testable import MoonlitMechanismCore

/// The certified openings of this test process, built once.
private let certifiedOpenings: Result<[MoonlitMechanismSceneSnapshot], any Error> = Result {
    var result: [MoonlitMechanismSceneSnapshot] = []
    for number in [1, 50, 100] {
        result.append(try MoonlitMechanismExperienceCore.opening(number: number).snapshot(time: 0))
    }
    return result
}

@Suite struct MoonlitMechanismPickerTests {
    typealias Geometry = MoonlitMechanismSceneGeometry
    typealias Snapshot = MoonlitMechanismSceneSnapshot
    typealias Picker = MoonlitMechanismPicker
    typealias Orbit = MoonlitMechanismOrbit
    typealias Pick = MoonlitMechanismPick

    static let sizes: [SIMD2<Double>] = [SIMD2(390, 844), SIMD2(1024, 768), SIMD2(1366, 1024)]

    static let orbits: [Orbit] = [Orbit.authored,
                                  Orbit(yaw: 25 * Double.pi / 180, pitch: 15 * Double.pi / 180),
                                  Orbit(yaw: -25 * Double.pi / 180, pitch: -10 * Double.pi / 180)]

    static func certified() throws -> [Snapshot] { try certifiedOpenings.get() }

    static func camera(_ s: Snapshot, _ size: SIMD2<Double>, _ orbit: Orbit) -> MoonlitMechanismCamera {
        Geometry.camera(s, aspect: size.x / size.y, orbit: orbit)
    }

    // MARK: The independent pick

    /// The camera basis (right, up, forward) from the eye towards the target with +y up.
    static func basis(_ camera: MoonlitMechanismCamera) -> (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>) {
        let f0: SIMD3<Double> = camera.target - camera.eye
        let f: SIMD3<Double> = f0 / (f0 * f0).sum().squareRoot()
        let r0: SIMD3<Double> = SIMD3(-f.z, 0, f.x)
        let r: SIMD3<Double> = r0 / (r0 * r0).sum().squareRoot()
        let u: SIMD3<Double> = SIMD3(r.y * f.z - r.z * f.y, r.z * f.x - r.x * f.z, r.x * f.y - r.y * f.x)
        return (r, u, f)
    }

    /// World `p` in view points of `size`, or nil behind the eye.
    static func project(_ p: SIMD3<Double>, _ camera: MoonlitMechanismCamera, _ size: SIMD2<Double>) -> SIMD2<Double>? {
        let (r, u, f): (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>) = basis(camera)
        let d: SIMD3<Double> = p - camera.eye
        let depth: Double = (d * f).sum()
        guard depth > 0 else { return nil }
        let t: Double = tan(camera.fovY / 2)
        let nx: Double = (d * r).sum() / (depth * t * camera.aspect)
        let ny: Double = (d * u).sum() / (depth * t)
        return SIMD2((nx + 1) / 2 * size.x, (1 - ny) / 2 * size.y)
    }

    /// The cell size s = min(1.8 / W, 1.2 / H).
    static func cell(_ s: Snapshot) -> Double { min(1.8 / Double(s.width), 1.2 / Double(s.rows)) }

    /// The lamp's centre (0, 1.30 + 0.03 · height, 0.35).
    static func lamp(_ s: Snapshot) -> SIMD3<Double> { SIMD3(0, 1.30 + 0.03 * Double(s.height), 0.35) }

    /// The ladder's bottom and top rung centres at x 0.12, z 0.35.
    static func ladder(_ s: Snapshot) -> (SIMD3<Double>, SIMD3<Double>) {
        (SIMD3(0.12, 1.30, 0.35), SIMD3(0.12, 1.30 + 0.03 * Double(max(s.lampHeights, 1) - 1), 0.35))
    }

    /// Card `k`'s centre (−0.6 + (k + 0.5) · 1.2 / K, −0.18, raised 0.02 when shown, −0.6) and half sizes.
    static func card(_ k: Int, _ s: Snapshot) -> (SIMD3<Double>, SIMD2<Double>) {
        let slot: Double = 1.2 / Double(s.keyFrames.count)
        let y: Double = -0.18 + (k == s.shownFrame ? 0.02 : 0)
        return (SIMD3(-0.6 + (Double(k) + 0.5) * slot, y, -0.6), SIMD2(min(0.16, 0.8 * slot) / 2, 0.035))
    }

    /// Gear `g`'s centre: its centre cell on the wall mapping at z = −0.6 + 0.12 · depth.
    static func gear(_ g: Int, _ s: Snapshot) -> SIMD3<Double> {
        let c: MoonlitMechanismCell = s.gears[g].centre
        let size: Double = cell(s)
        return SIMD3((Double(c.column) - Double(s.width - 1) / 2) * size,
                     0.65 - (Double(c.row) - Double(s.rows - 1) / 2) * size, -0.6 + 0.12 * Double(s.gears[g].depth))
    }

    /// The distance from `q` to the segment a–b, by the closest point (the end itself beyond either end).
    static func toSegment(_ q: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let ab: SIMD2<Double> = b - a
        let len2: Double = (ab * ab).sum()
        let t: Double = len2 > 0 ? ((q - a) * ab).sum() / len2 : 0
        let c: SIMD2<Double> = t <= 0 ? a : (t >= 1 ? b : a + ab * t)
        return ((q - c) * (q - c)).sum().squareRoot()
    }

    /// The distance between view points.
    static func length(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double { ((a - b) * (a - b)).sum().squareRoot() }

    /// Whether `q` lies in the projected card rectangle (by crossing signs around its four corners).
    static func inCard(_ q: SIMD2<Double>, _ k: Int, _ s: Snapshot, _ camera: MoonlitMechanismCamera,
                       _ size: SIMD2<Double>) -> Bool {
        let (c, h): (SIMD3<Double>, SIMD2<Double>) = card(k, s)
        let corners: [SIMD3<Double>] = [c + SIMD3(-h.x, -h.y, 0), c + SIMD3(h.x, -h.y, 0), c + SIMD3(h.x, h.y, 0),
                                        c + SIMD3(-h.x, h.y, 0)]
        var points: [SIMD2<Double>] = []
        for p in corners {
            guard let v = project(p, camera, size) else { return false }
            points.append(v)
        }
        var signs: Set<Int> = []
        for i in 0..<4 {
            let a: SIMD2<Double> = points[i]
            let b: SIMD2<Double> = points[(i + 1) % 4]
            let cross: Double = (b.x - a.x) * (q.y - a.y) - (b.y - a.y) * (q.x - a.x)
            if cross != 0 { signs.insert(cross > 0 ? 1 : -1) }
        }
        return signs.count < 2
    }

    /// Gear `g`'s projected centre and target radius: the largest projected distance of eight outline points (radius
    /// 3.75 s, every 45°) plus 8 points.
    static func gearTarget(_ g: Int, _ s: Snapshot, _ camera: MoonlitMechanismCamera,
                           _ size: SIMD2<Double>) -> (SIMD2<Double>, Double)? {
        let centre3: SIMD3<Double> = gear(g, s)
        guard let centre = project(centre3, camera, size) else { return nil }
        let r: Double = 3.75 * cell(s)
        var radius: Double = 0
        for k in 0..<8 {
            let a: Double = Double(k) * Double.pi / 4
            guard let p = project(centre3 + SIMD3(r * cos(a), r * sin(a), 0), camera, size) else { return nil }
            radius = max(radius, length(p, centre))
        }
        return (centre, radius + 8)
    }

    /// The gears front-most first: descending depth, then descending index.
    static func frontFirst(_ s: Snapshot) -> [Int] {
        var order: [Int] = Array(s.gears.indices)
        order.sort { a, b in
            s.gears[a].depth != s.gears[b].depth ? s.gears[a].depth > s.gears[b].depth : a > b
        }
        return order
    }

    /// The gears whose target holds `q`, front-most first.
    static func gearHits(_ q: SIMD2<Double>, _ s: Snapshot, _ camera: MoonlitMechanismCamera,
                         _ size: SIMD2<Double>) -> [Int] {
        var hits: [Int] = []
        for g in frontFirst(s) {
            guard let (c, r) = gearTarget(g, s, camera, size) else { continue }
            if length(q, c) <= r { hits.append(g) }
        }
        return hits
    }

    /// The card a touch at `q` picks, or nil: inside the rectangle or centre within 22, the nearest centre.
    static func cardHit(_ q: SIMD2<Double>, _ s: Snapshot, _ camera: MoonlitMechanismCamera,
                        _ size: SIMD2<Double>) -> Int? {
        var best: Int? = nil
        var bestDistance: Double = Double.infinity
        for k in s.keyFrames.indices {
            guard let c = project(card(k, s).0, camera, size) else { continue }
            let d: Double = length(q, c)
            if (d <= 22 || inCard(q, k, s, camera, size)) && d < bestDistance - 1e-6 {
                best = k
                bestDistance = d
            }
        }
        return best
    }

    /// Whether `q` is on the lamp (centre within 22) and on the ladder (segment within 22).
    static func lampLadder(_ q: SIMD2<Double>, _ s: Snapshot, _ camera: MoonlitMechanismCamera,
                           _ size: SIMD2<Double>) -> (Bool, Bool) {
        var onLamp: Bool = false
        if let l = project(lamp(s), camera, size) { onLamp = length(q, l) <= 22 }
        var onLadder: Bool = false
        let (a3, b3): (SIMD3<Double>, SIMD3<Double>) = ladder(s)
        if let a = project(a3, camera, size), let b = project(b3, camera, size) { onLadder = toSegment(q, a, b) <= 22 }
        return (onLamp, onLadder)
    }

    /// The independent pick of clarification Q1.
    static func expected(_ q: SIMD2<Double>, _ s: Snapshot, _ size: SIMD2<Double>, _ orbit: Orbit) -> Pick {
        let camera: MoonlitMechanismCamera = Self.camera(s, size, orbit)
        let (onLamp, onLadder): (Bool, Bool) = lampLadder(q, s, camera, size)
        if onLamp { return .lamp }
        if onLadder { return .ladder }
        if let k = cardHit(q, s, camera, size) { return .card(k) }
        if let g = gearHits(q, s, camera, size).first { return .gear(g) }
        return .empty
    }

    // MARK: Tests

    @Test func agreesWithTheIndependentPickOnSeededPoints() throws {
        var random: SeededRandom = SeededRandom(seed: 2_434)
        var counts: [String: Int] = [:]
        var mismatches: Int = 0
        for s in try Self.certified() {
            for size in Self.sizes {
                for orbit in Self.orbits {
                    for _ in 0..<500 {
                        let q: SIMD2<Double> = SIMD2(random.double() * size.x, random.double() * size.y)
                        let got: Pick = Picker.pick(q, size: size, snapshot: s, orbit: orbit)
                        let want: Pick = Self.expected(q, s, size, orbit)
                        if got != want {
                            mismatches += 1
                            Issue.record("\(q) in \(size) at \(orbit): picked \(got), expected \(want)")
                        }
                        switch want {
                        case .lamp: counts["lamp", default: 0] += 1
                        case .ladder: counts["ladder", default: 0] += 1
                        case .card: counts["card", default: 0] += 1
                        case .gear: counts["gear", default: 0] += 1
                        case .empty: counts["empty", default: 0] += 1
                        }
                    }
                }
            }
        }
        #expect(mismatches == 0)
        #expect((counts["gear"] ?? 0) > 100 && (counts["empty"] ?? 0) > 100, "gears and empty space sampled: \(counts)")
    }

    @Test func targetedPointsAgreeOnEveryKind() throws {
        // A point on every lamp, ladder end, card centre and gear centre agrees with the independent pick (random
        // points rarely land on the small targets).
        var checked: Int = 0
        for s in try Self.certified() {
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let camera: MoonlitMechanismCamera = Self.camera(s, size, orbit)
                    var targets: [SIMD3<Double>] = [Self.lamp(s), Self.ladder(s).0, Self.ladder(s).1]
                    for k in s.keyFrames.indices { targets.append(Self.card(k, s).0) }
                    for g in s.gears.indices { targets.append(Self.gear(g, s)) }
                    for p in targets {
                        guard let q = Self.project(p, camera, size) else { continue }
                        let want: Pick = Self.expected(q, s, size, orbit)
                        #expect(Picker.pick(q, size: size, snapshot: s, orbit: orbit) == want)
                        checked += 1
                    }
                }
            }
        }
        #expect(checked > 100)
    }

    @Test func twentyTwoPointTargetsAt21And23Points() throws {
        for s in try Self.certified() {
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let camera: MoonlitMechanismCamera = Self.camera(s, size, orbit)
                    // The lamp: 21 and 23 points to its left (away from the ladder at x 0.12).
                    let l: SIMD2<Double> = try #require(Self.project(Self.lamp(s), camera, size))
                    #expect(Picker.pick(l + SIMD2(-21, 0), size: size, snapshot: s, orbit: orbit) == .lamp)
                    let lampFar: Pick = Picker.pick(l + SIMD2(-23, 0), size: size, snapshot: s, orbit: orbit)
                    #expect(lampFar != .lamp && lampFar != .ladder)
                    #expect(lampFar == Self.expected(l + SIMD2(-23, 0), s, size, orbit))
                    // The ladder: 21 and 23 points from its midpoint, perpendicular, on the side away from the lamp.
                    let (a3, b3): (SIMD3<Double>, SIMD3<Double>) = Self.ladder(s)
                    let a: SIMD2<Double> = try #require(Self.project(a3, camera, size))
                    let b: SIMD2<Double> = try #require(Self.project(b3, camera, size))
                    let mid: SIMD2<Double> = (a + b) / 2
                    let along: SIMD2<Double> = (b - a) / max(Self.length(b, a), 1e-12)
                    var normal: SIMD2<Double> = SIMD2(-along.y, along.x)
                    if Self.length(b, a) < 1e-9 { normal = SIMD2(1, 0) }
                    if ((mid - l) * normal).sum() < 0 { normal = -normal }
                    #expect(Picker.pick(mid + normal * 21, size: size, snapshot: s, orbit: orbit) == .ladder)
                    let ladderFar: Pick = Picker.pick(mid + normal * 23, size: size, snapshot: s, orbit: orbit)
                    #expect(ladderFar != .ladder && ladderFar != .lamp)
                    // A card: 21 and 23 points straight below its centre (outside its rectangle at 23).
                    for k in s.keyFrames.indices {
                        let c: SIMD2<Double> = try #require(Self.project(Self.card(k, s).0, camera, size))
                        let near: SIMD2<Double> = c + SIMD2(0, 21)
                        let far: SIMD2<Double> = c + SIMD2(0, 23)
                        #expect(Picker.pick(near, size: size, snapshot: s, orbit: orbit) == .card(k))
                        guard !Self.inCard(far, k, s, camera, size) else { continue }
                        let farPick: Pick = Picker.pick(far, size: size, snapshot: s, orbit: orbit)
                        #expect(farPick != .card(k), "card \(k) not picked 23 points below its centre")
                        #expect(farPick == Self.expected(far, s, size, orbit))
                    }
                }
            }
        }
    }

    /// The points of a square grid of step `step` and half side `half` around `centre`.
    static func grid(_ centre: SIMD2<Double>, half: Double, step: Double) -> [SIMD2<Double>] {
        var points: [SIMD2<Double>] = []
        var dy: Double = -half
        while dy <= half {
            var dx: Double = -half
            while dx <= half {
                points.append(centre + SIMD2(dx, dy))
                dx += step
            }
            dy += step
        }
        return points
    }

    @Test func lampBeatsCardsAndCardsBeatGears() throws {
        // Grids around the lamp, the ladder and every card; wherever the lamp or ladder and a gear both reach, or a
        // card and a gear both reach, the first wins. The opening levels place gears under the cards; a hand-made level
        // with a gear under the lamp covers the other case.
        var lampOverGear: Int = 0
        var cardOverGear: Int = 0
        var snapshots: [Snapshot] = try Self.certified()
        snapshots.append(try Self.gearUnderLamp())
        for s in snapshots {
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let camera: MoonlitMechanismCamera = Self.camera(s, size, orbit)
                    var points: [SIMD2<Double>] = []
                    var centres: [SIMD3<Double>] = [Self.lamp(s), Self.ladder(s).0, Self.ladder(s).1]
                    for k in s.keyFrames.indices { centres.append(Self.card(k, s).0) }
                    for c in centres {
                        guard let v = Self.project(c, camera, size) else { continue }
                        points.append(contentsOf: Self.grid(v, half: 30, step: 4))
                    }
                    for q in points {
                        let gears: [Int] = Self.gearHits(q, s, camera, size)
                        guard !gears.isEmpty else { continue }
                        let (onLamp, onLadder): (Bool, Bool) = Self.lampLadder(q, s, camera, size)
                        let got: Pick = Picker.pick(q, size: size, snapshot: s, orbit: orbit)
                        if onLamp || onLadder {
                            lampOverGear += 1
                            #expect(got == (onLamp ? .lamp : .ladder))
                        } else if let k = Self.cardHit(q, s, camera, size) {
                            cardOverGear += 1
                            #expect(got == .card(k))
                        }
                    }
                }
            }
        }
        #expect(lampOverGear > 0, "a lamp or ladder point over a gear was checked")
        #expect(cardOverGear > 0, "a card point over a gear was checked")
    }

    @Test func frontMostGearWins() throws {
        // Where two gears' targets overlap (17 points on the segment between their projected centres), the one drawn
        // last wins: higher depth, then (equal depths) higher index.
        var deeper: Int = 0
        var sameDepth: Int = 0
        var snapshots: [Snapshot] = try Self.certified()
        snapshots.append(try Self.equalDepths())
        for s in snapshots {
            for size in Self.sizes {
                for orbit in Self.orbits {
                    let camera: MoonlitMechanismCamera = Self.camera(s, size, orbit)
                    for i in s.gears.indices {
                        for j in s.gears.indices where j > i {
                            guard let a = Self.project(Self.gear(i, s), camera, size),
                                  let b = Self.project(Self.gear(j, s), camera, size) else { continue }
                            for step in 0...16 {
                                let q: SIMD2<Double> = a + (b - a) * (Double(step) / 16)
                                let hits: [Int] = Self.gearHits(q, s, camera, size)
                                guard hits.count >= 2, Self.cardHit(q, s, camera, size) == nil else { continue }
                                let (onLamp, onLadder): (Bool, Bool) = Self.lampLadder(q, s, camera, size)
                                guard !onLamp, !onLadder else { continue }
                                let front: Int = hits[0]
                                let behind: Int = hits[1]
                                if s.gears[front].depth == s.gears[behind].depth {
                                    sameDepth += 1
                                    #expect(front > behind)
                                } else {
                                    deeper += 1
                                    #expect(s.gears[front].depth > s.gears[behind].depth)
                                }
                                #expect(Picker.pick(q, size: size, snapshot: s, orbit: orbit) == .gear(front))
                            }
                        }
                    }
                }
            }
        }
        #expect(deeper > 0, "an overlap of gears at different depths was checked")
        #expect(sameDepth > 0, "an overlap of gears at equal depths was checked")
    }

    @Test func equallyNearCardsGoToTheLowerIndex() throws {
        // Six key frames: adjacent unshown cards are 0.2 apart; at the projected midpoint both centres are equally
        // near, and on a phone both within 22 points.
        let s: Snapshot = try Self.sixCards()
        var ties: Int = 0
        for size in Self.sizes {
            for orbit in Self.orbits {
                let camera: MoonlitMechanismCamera = Self.camera(s, size, orbit)
                for k in 1..<(s.keyFrames.count - 1) {
                    let a: SIMD2<Double> = try #require(Self.project(Self.card(k, s).0, camera, size))
                    let b: SIMD2<Double> = try #require(Self.project(Self.card(k + 1, s).0, camera, size))
                    let mid: SIMD2<Double> = (a + b) / 2
                    guard Self.length(mid, a) <= 22 else { continue }
                    ties += 1
                    #expect(Picker.pick(mid, size: size, snapshot: s, orbit: orbit) == .card(k))
                    // Just past the midpoint the nearer card wins.
                    let shift: SIMD2<Double> = (b - a) / Self.length(b, a)
                    #expect(Picker.pick(mid + shift * 0.5, size: size, snapshot: s, orbit: orbit) == .card(k + 1))
                }
            }
        }
        #expect(ties > 0, "an equally near pair of cards was checked")
    }

    @Test func gearCentreAndAngleRunClockwiseOnScreen() throws {
        let s: Snapshot = try Self.certified()[0]
        let size: SIMD2<Double> = SIMD2(390, 844)
        for orbit in Self.orbits {
            let camera: MoonlitMechanismCamera = Self.camera(s, size, orbit)
            for g in s.gears.indices {
                let got: SIMD2<Double> = try #require(Picker.gearCentre(g, size: size, snapshot: s, orbit: orbit))
                let want: SIMD2<Double> = try #require(Self.project(Self.gear(g, s), camera, size))
                #expect(Self.length(got, want) < 1e-6)
            }
        }
        #expect(Picker.gearCentre(-1, size: size, snapshot: s, orbit: .authored) == nil)
        #expect(Picker.gearCentre(s.gears.count, size: size, snapshot: s, orbit: .authored) == nil)
        #expect(Picker.gearCentre(0, size: SIMD2(0, 844), snapshot: s, orbit: .authored) == nil)
        let c: SIMD2<Double> = SIMD2(100, 100)
        #expect(Picker.angle(of: SIMD2(110, 100), about: c) == 0)
        #expect(abs(Picker.angle(of: SIMD2(100, 110), about: c) - Double.pi / 2) < 1e-12, "down is +π/2 (clockwise)")
        #expect(abs(Picker.angle(of: SIMD2(100, 90), about: c) + Double.pi / 2) < 1e-12, "up is −π/2")
        #expect(abs(Picker.angle(of: SIMD2(90, 100), about: c) - Double.pi) < 1e-12, "left is π")
        #expect(Picker.angle(of: c, about: c) == 0)
        #expect(Picker.angle(of: SIMD2(Double.nan, 0), about: c) == 0)
        // A finger going right → down → left (clockwise on screen) increases the angle.
        let right: Double = Picker.angle(of: SIMD2(110, 100), about: c)
        let downRight: Double = Picker.angle(of: SIMD2(107, 107), about: c)
        let down: Double = Picker.angle(of: SIMD2(100, 110), about: c)
        #expect(right < downRight && downRight < down)
        #expect(Picker.segmentDistance(SIMD2(5, 3), SIMD2(0, 0), SIMD2(10, 0)) == 3)
        #expect(Picker.segmentDistance(SIMD2(-3, 4), SIMD2(0, 0), SIMD2(10, 0)) == 5)
        #expect(Picker.segmentDistance(SIMD2(3, 4), SIMD2(0, 0), SIMD2(0, 0)) == 5)
    }

    @Test func unusableInputPicksNothing() throws {
        let s: Snapshot = try Self.certified()[0]
        let size: SIMD2<Double> = SIMD2(390, 844)
        let camera: MoonlitMechanismCamera = Self.camera(s, size, .authored)
        let onGear: SIMD2<Double> = try #require(Self.project(Self.gear(0, s), camera, size))
        #expect(Picker.pick(onGear, size: size, snapshot: s, orbit: .authored) != .empty)
        let points: [SIMD2<Double>] = [SIMD2(Double.nan, onGear.y), SIMD2(onGear.x, Double.infinity),
                                       SIMD2(-Double.infinity, 0)]
        for q in points { #expect(Picker.pick(q, size: size, snapshot: s, orbit: .authored) == .empty) }
        let sizes: [SIMD2<Double>] = [SIMD2(0, 844), SIMD2(390, 0), SIMD2(-390, 844), SIMD2(Double.nan, 844),
                                      SIMD2(390, Double.infinity)]
        for bad in sizes {
            #expect(Picker.pick(onGear, size: bad, snapshot: s, orbit: .authored) == .empty)
            #expect(Picker.viewPoint(Self.gear(0, s), size: bad, camera: camera) == nil)
        }
        // A non-finite orbit angle becomes 0: the authored view.
        let wild: Orbit = Orbit(yaw: Double.nan, pitch: Double.infinity)
        #expect(Picker.pick(onGear, size: size, snapshot: s, orbit: wild)
                == Picker.pick(onGear, size: size, snapshot: s, orbit: .authored))
        #expect(Picker.gearCentre(0, size: size, snapshot: s, orbit: wild)
                == Picker.gearCentre(0, size: size, snapshot: s, orbit: .authored))
        #expect(Picker.pick(SIMD2(1, 1), size: size, snapshot: s, orbit: .authored) == .empty, "the corner is empty")
    }

    // MARK: Hand-made levels

    /// A two-gear level on a wall of 8 × 6 cells whose gears sit on the top row, gear 0 under the lamp (top height).
    static func gearUnderLamp() throws -> Snapshot {
        let level: MoonlitMechanismLevel = try MoonlitMechanismSceneGeometryTests.level(
            gears: 2, teeth: 12, width: 8, rows: 6, lampHeights: 5, startingHeight: 4, frames: 2, budget: 10)
        return try Self.moved(level, cells: [(3, 0), (6, 0)], depths: [1, 2])
    }

    /// A three-gear level whose first two gears share a depth and overlap.
    static func equalDepths() throws -> Snapshot {
        let level: MoonlitMechanismLevel = try MoonlitMechanismSceneGeometryTests.level(
            gears: 3, teeth: 12, width: 16, rows: 12, lampHeights: 4, startingHeight: 0, frames: 3, budget: 40)
        return try Self.moved(level, cells: [(4, 5), (8, 5), (12, 5)], depths: [2, 2, 1])
    }

    /// A small level with six key frames.
    static func sixCards() throws -> Snapshot {
        let level: MoonlitMechanismLevel = try MoonlitMechanismSceneGeometryTests.level(
            gears: 3, teeth: 12, width: 16, rows: 12, lampHeights: 4, startingHeight: 0, frames: 6, budget: 40)
        return try MoonlitMechanismSceneGeometryTests.snapshot(level)
    }

    /// `level`'s snapshot with gear i re-centred on cell (column, row) `cells[i]` at depth `depths[i]`; picking reads
    /// only places, so the key frames stay as they were.
    static func moved(_ level: MoonlitMechanismLevel, cells: [(Int, Int)], depths: [Int]) throws -> Snapshot {
        var gears: [MoonlitMechanismGear] = []
        for index in level.gears.indices {
            let g: MoonlitMechanismGear = level.gears[index]
            let centre: MoonlitMechanismCell = MoonlitMechanismCell(column: cells[index].0, row: cells[index].1)
            gears.append(MoonlitMechanismGear(teeth: g.teeth, phase: g.phase, blades: g.blades, depth: depths[index],
                                              centre: centre, parent: g.parent, alignment: g.alignment,
                                              slots: g.slots))
        }
        let rebuilt: MoonlitMechanismLevel = try MoonlitMechanismLevel(
            id: "picker-moved", seed: 1, difficulty: 1, gears: gears, width: level.width, rows: level.rows,
            lampHeights: level.lampHeights, startingHeight: level.startingHeight, keyFrames: level.keyFrames,
            forbidden: level.forbidden, allowance: 0, budget: level.budget)
        return try MoonlitMechanismSceneGeometryTests.snapshot(rebuilt)
    }
}
