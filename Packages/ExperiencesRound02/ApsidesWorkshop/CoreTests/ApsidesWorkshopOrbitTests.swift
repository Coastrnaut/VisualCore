// ApsidesWorkshopOrbitTests — feature 471 (R02-G18-01) T-R02G1801-003 (FR-R02G1801-002 … 005, 014; SC-R02G1801-003,
// 004; clarifications Q1 … Q3). Apsides Workshop's sky against an independent recomputation: on 500 seeded valid orbits
// (SeededRandom(seed: 2_471), periods 16 … 96 even) every position agrees with a `Double` Kepler solution (E − e·sin E
// = M solved with Foundation's sin and cos to 1e−12, x = a(cos E − e), y = a·√(1 − e²)·sin E, turned by 15d°, a = size
// · 256) within 2 sky units; every tick's Kepler residual is within `ApsidesWorkshopFixed.residualBound`; and every
// sector (atan2, or the exact rule on a boundary ray), swept share (direct cross-product enumeration), apsis reading,
// contact decision (an exact rational closest-point distance in `Int128`), event tick and the judge's outcome (contact
// first by tick then planet; then the targets in order: order, share, apsis-sector, apsis-distance) equal a
// recomputation here on the kernel's integer positions; the recomputation never calls `ApsidesWorkshopSky` except to
// obtain those positions. Each case of seven carries a known outcome (win, contact, order, share, apsis-sector,
// apsis-distance or a random mix), so every outcome is met in each group of 100. Hand cases: a point on each of the 8
// boundary rays and just before it; the fixed-point sine and cosine against Foundation within 2^−26 and the exact 15°
// turns; a circular orbit; the extreme valid orbits and one step beyond; a share and an apsis distance one unit either
// side of a bound; a planet one sky unit inside and outside contact and grazing (no contact); contact named by tick,
// then planet; a sector never entered (share 0, event tick T); and the bisection fallback, which valid orbits reach.
// Explicit types and plain loops keep the type checker fast on CI.
import Foundation
import Testing
import VisualCoreSimulation
@testable import ApsidesWorkshopCore

@Suite struct ApsidesWorkshopOrbitTests {
    /// One seeded orbit with the planets and targets judged and further planets whose contact decisions are compared.
    private struct Case: Sendable {
        let orbit: ApsidesWorkshopOrbit
        let period: Int
        let planets: [ApsidesWorkshopPlanet]
        let targets: [ApsidesWorkshopTarget]
        let probes: [ApsidesWorkshopPlanet]
    }

    /// The reference judge's verdict.
    private struct Verdict: Equatable {
        let failure: ApsidesWorkshopFailure?
        let met: Int
        let deviations: [Int]
        let ticks: [Int]
    }

    /// The independent reference computations of this file (they never call `ApsidesWorkshopSky`'s rules).
    private enum Reference {
        /// The seed of the orbits.
        static let seed: UInt64 = 2_471
        /// The number of seeded orbits.
        static let caseCount: Int = 500
        /// The orbits per test.
        static let groupSize: Int = 100
        /// Sky units per lattice unit.
        static let unit: Int = 256
        /// The fixed-point one as a `Double`.
        static let one: Double = 1_073_741_824
        /// The seeded cases, built once.
        static let cases: [Case] = makeCases()

        /// The eccentric anomaly solving E − e·sin E = M to 1e−12, by Newton's method kept inside [M − e, M + e].
        static func anomaly(mean m: Double, eccentricity e: Double) -> Double {
            var low: Double = m - e
            var high: Double = m + e
            var x: Double = m
            for _ in 0..<200 {
                let f: Double = x - e * sin(x) - m
                if abs(f) <= 1e-12 { break }
                if f < 0 { low = x } else { high = x }
                var next: Double = x - f / (1 - e * cos(x))
                if next <= low || next >= high { next = (low + high) / 2 }
                x = next
            }
            return x
        }

        /// The orbiter's position at `tick` in sky units, in `Double`.
        static func position(_ orbit: ApsidesWorkshopOrbit, tick: Int, period: Int) -> (x: Double, y: Double) {
            let a: Double = Double(orbit.size * unit)
            let e: Double = Double(orbit.eccentricity) / 20
            let m: Double = 2 * Double.pi * Double(tick) / Double(period)
            let big: Double = anomaly(mean: m, eccentricity: e)
            let px: Double = a * (cos(big) - e)
            let py: Double = a * (1 - e * e).squareRoot() * sin(big)
            let theta: Double = Double(15 * orbit.direction) * Double.pi / 180
            return (px * cos(theta) - py * sin(theta), px * sin(theta) + py * cos(theta))
        }

        /// The sector of a point other than the star: the exact rule on the 8 boundary rays (a ray belongs to the
        /// sector it begins), atan2 elsewhere.
        static func sector(_ p: ApsidesWorkshopPoint) -> Int {
            let x: Int = p.x
            let y: Int = p.y
            if y == 0 && x > 0 { return 0 }
            if x == y && x > 0 { return 1 }
            if x == 0 && y > 0 { return 2 }
            if y == -x && x < 0 { return 3 }
            if y == 0 && x < 0 { return 4 }
            if x == y && x < 0 { return 5 }
            if x == 0 && y < 0 { return 6 }
            if y == -x && x > 0 { return 7 }
            var angle: Double = atan2(Double(y), Double(x))
            if angle < 0 { angle += 2 * Double.pi }
            return min(7, Int(angle / (Double.pi / 4)))
        }

        /// The doubled area of the triangle star → P(t) → P(t + 1).
        static func doubledArea(_ points: [ApsidesWorkshopPoint], tick: Int) -> Int64 {
            let p: ApsidesWorkshopPoint = points[tick]
            let q: ApsidesWorkshopPoint = points[tick + 1 == points.count ? 0 : tick + 1]
            return Int64(p.x) * Int64(q.y) - Int64(p.y) * Int64(q.x)
        }

        /// The share of each sector in tenths of a percent, rounded down, by direct enumeration of the ticks.
        static func shares(_ points: [ApsidesWorkshopPoint]) -> [Int] {
            var areas: [Int64] = [0, 0, 0, 0, 0, 0, 0, 0]
            var total: Int64 = 0
            for tick in 0..<points.count {
                let doubled: Int64 = doubledArea(points, tick: tick)
                areas[sector(points[tick])] += doubled
                total += doubled
            }
            var result: [Int] = []
            for area in areas {
                result.append(total > 0 ? Int(max(0, area) * 1000 / total) : 0)
            }
            return result
        }

        /// Whether `planet` is struck by the segment a → b: the closest point a + (p/q)(b − a), p/q clamped to 0 … 1,
        /// lies strictly closer than the radius, decided exactly as |q·(c − a) − p·(b − a)|² < r²·q².
        static func strikes(_ planet: ApsidesWorkshopPlanet, _ a: ApsidesWorkshopPoint,
                            _ b: ApsidesWorkshopPoint) -> Bool {
            let cx: Int128 = Int128(planet.x * unit)
            let cy: Int128 = Int128(planet.y * unit)
            let r: Int128 = Int128(planet.radius * unit)
            let dx: Int128 = Int128(b.x) - Int128(a.x)
            let dy: Int128 = Int128(b.y) - Int128(a.y)
            let wx: Int128 = cx - Int128(a.x)
            let wy: Int128 = cy - Int128(a.y)
            let q: Int128 = dx * dx + dy * dy
            if q == 0 { return wx * wx + wy * wy < r * r }
            var p: Int128 = wx * dx + wy * dy
            if p < 0 { p = 0 }
            if p > q { p = q }
            let vx: Int128 = q * wx - p * dx
            let vy: Int128 = q * wy - p * dy
            return vx * vx + vy * vy < r * r * q * q
        }

        /// The sector of the direction 15d° + `extra`°.
        static func directionSector(_ direction: Int, extra: Int) -> Int {
            ((15 * direction + extra) % 360) / 45
        }

        /// The periapsis (`apoapsis` false) or apoapsis distance in twentieths of a lattice unit.
        static func distance(_ orbit: ApsidesWorkshopOrbit, apoapsis: Bool) -> Int {
            apoapsis ? orbit.size * 20 + orbit.size * orbit.eccentricity
                : orbit.size * 20 - orbit.size * orbit.eccentricity
        }

        /// The event tick of `target`.
        static func eventTick(_ target: ApsidesWorkshopTarget, points: [ApsidesWorkshopPoint], period: Int) -> Int {
            switch target.kind {
            case .periapsis: return 0
            case .apoapsis: return period / 2
            case .sweep:
                for tick in 0..<period where sector(points[tick]) == target.sector { return tick }
                return period
            }
        }

        /// The judge recomputed: contact first (lowest tick, then lowest planet), then the targets in order.
        static func judge(_ c: Case, points: [ApsidesWorkshopPoint]) -> Verdict {
            let shares: [Int] = Reference.shares(points)
            var ticks: [Int] = []
            var values: [Int] = []
            var deviations: [Int] = []
            for target in c.targets {
                ticks.append(eventTick(target, points: points, period: c.period))
                let value: Int = target.kind == .sweep ? shares[target.sector]
                    : distance(c.orbit, apoapsis: target.kind == .apoapsis)
                values.append(value)
                var deviation: Int = 0
                if value < target.low { deviation = value - target.low }
                if value > target.high { deviation = value - target.high }
                deviations.append(deviation)
            }
            var tick: Int = 0
            while tick < c.period {
                let next: Int = tick + 1 == c.period ? 0 : tick + 1
                var index: Int = 0
                while index < c.planets.count {
                    if strikes(c.planets[index], points[tick], points[next]) {
                        return Verdict(failure: .contact(planet: index, tick: tick), met: 0, deviations: deviations,
                                       ticks: ticks)
                    }
                    index += 1
                }
                tick += 1
            }
            var met: Int = 0
            var failure: ApsidesWorkshopFailure?
            for index in 0..<c.targets.count {
                let target: ApsidesWorkshopTarget = c.targets[index]
                if index > 0 && ticks[index] < ticks[index - 1] {
                    failure = .order(target: index, tick: ticks[index])
                } else if target.kind == .sweep {
                    if deviations[index] != 0 {
                        failure = .share(target: index, tick: ticks[index], share: values[index])
                    }
                } else {
                    let extra: Int = target.kind == .periapsis ? 0 : 180
                    let sector: Int = directionSector(c.orbit.direction, extra: extra)
                    if sector != target.sector {
                        failure = .apsisSector(target: index, sector: sector)
                    } else if deviations[index] != 0 {
                        failure = .apsisDistance(target: index, distance: values[index])
                    }
                }
                if failure != nil { break }
                met += 1
            }
            return Verdict(failure: failure, met: met, deviations: deviations, ticks: ticks)
        }

        /// A random valid orbit.
        static func orbit(_ random: inout SeededRandom) -> ApsidesWorkshopOrbit {
            while true {
                let size: Int = random.int(8...48)
                let k: Int = random.int(0...15)
                let d: Int = random.int(0...23)
                if size * (20 - k) >= 60 && size * (20 + k) <= 1280 {
                    return ApsidesWorkshopOrbit(size: size, eccentricity: k, direction: d)
                }
            }
        }

        /// Whether a planet lies within the level's ranges and clear of the star.
        static func isPlaceable(_ planet: ApsidesWorkshopPlanet) -> Bool {
            let reach: Int = planet.radius + 2
            return abs(planet.x) <= 64 && abs(planet.y) <= 64 && (1...8).contains(planet.radius)
                && planet.x * planet.x + planet.y * planet.y > reach * reach
        }

        /// A random placeable planet.
        static func planet(_ random: inout SeededRandom) -> ApsidesWorkshopPlanet {
            while true {
                let planet = ApsidesWorkshopPlanet(x: random.int(-64...64), y: random.int(-64...64),
                                                   radius: random.int(1...8))
                if isPlaceable(planet) { return planet }
            }
        }

        /// The lattice point nearest to `p`.
        static func lattice(_ p: ApsidesWorkshopPoint) -> (x: Int, y: Int) {
            (Int((Double(p.x) / Double(unit)).rounded()), Int((Double(p.y) / Double(unit)).rounded()))
        }

        /// A placeable planet near tick `tick`'s position (it may or may not touch the orbit).
        static func nearPlanet(_ random: inout SeededRandom, points: [ApsidesWorkshopPoint]) -> ApsidesWorkshopPlanet {
            while true {
                let centre: (x: Int, y: Int) = lattice(points[random.int(0...(points.count - 1))])
                let planet = ApsidesWorkshopPlanet(x: centre.x + random.int(-4...4), y: centre.y + random.int(-4...4),
                                                   radius: random.int(1...4))
                if isPlaceable(planet) { return planet }
            }
        }

        /// Whether any segment of the revolution strikes `planet`.
        static func strikesOrbit(_ planet: ApsidesWorkshopPlanet, points: [ApsidesWorkshopPoint]) -> Bool {
            for tick in 0..<points.count {
                let next: Int = tick + 1 == points.count ? 0 : tick + 1
                if strikes(planet, points[tick], points[next]) { return true }
            }
            return false
        }

        /// A band around `value` within `bounds`, `spread` drawn per side (a negative spread may exclude the value).
        static func band(_ random: inout SeededRandom, around value: Int, spread: ClosedRange<Int>,
                         bounds: ClosedRange<Int>) -> (low: Int, high: Int) {
            var low: Int = min(max(value - random.int(spread), bounds.lowerBound), bounds.upperBound)
            var high: Int = min(max(value + random.int(spread), bounds.lowerBound), bounds.upperBound)
            if low > high { swap(&low, &high) }
            return (low, high)
        }

        /// The 500 seeded cases.
        static func makeCases() -> [Case] {
            var random = SeededRandom(seed: seed)
            var result: [Case] = []
            for index in 0..<caseCount {
                result.append(makeCase(&random, scenario: index % 7))
            }
            return result
        }

        /// One case of `scenario`: 0 win, 1 contact, 2 order, 3 share, 4 apsis-sector, 5 apsis-distance, 6 random.
        static func makeCase(_ random: inout SeededRandom, scenario: Int) -> Case {
            let orbit: ApsidesWorkshopOrbit = Reference.orbit(&random)
            let period: Int = 2 * random.int(8...48)
            let points: [ApsidesWorkshopPoint] = ApsidesWorkshopSky.positions(orbit, period: period).points
            let shares: [Int] = Reference.shares(points)
            let first: Int = sector(points[0])
            let opposite: Int = sector(points[period / 2])
            let periapsis: Int = distance(orbit, apoapsis: false)
            let apoapsis: Int = distance(orbit, apoapsis: true)
            let periSector: Int = directionSector(orbit.direction, extra: 0)
            let apoSector: Int = directionSector(orbit.direction, extra: 180)
            var probes: [ApsidesWorkshopPlanet] = []
            for _ in 0..<3 { probes.append(planet(&random)) }
            for _ in 0..<3 { probes.append(nearPlanet(&random, points: points)) }
            var planets: [ApsidesWorkshopPlanet] = []
            var targets: [ApsidesWorkshopTarget] = []
            switch scenario {
            case 0:
                for _ in 0..<20 {
                    let candidate: ApsidesWorkshopPlanet = nearPlanet(&random, points: points)
                    if !strikesOrbit(candidate, points: points) { planets.append(candidate); break }
                }
                let share: (low: Int, high: Int) = band(&random, around: shares[first], spread: 0...20,
                                                       bounds: 0...1000)
                let near: (low: Int, high: Int) = band(&random, around: periapsis, spread: 0...30, bounds: 0...1280)
                let far: (low: Int, high: Int) = band(&random, around: apoapsis, spread: 0...30, bounds: 0...1280)
                targets = [ApsidesWorkshopTarget(kind: .periapsis, sector: periSector, low: near.low, high: near.high),
                           .sweep(sector: first, low: share.low, high: share.high),
                           ApsidesWorkshopTarget(kind: .apoapsis, sector: apoSector, low: far.low, high: far.high)]
            case 1:
                let centre: (x: Int, y: Int) = lattice(points[period / 2])
                for _ in 0..<random.int(0...2) { planets.append(planet(&random)) }
                planets.append(ApsidesWorkshopPlanet(x: centre.x, y: centre.y, radius: 1))
                targets = [.sweep(sector: first, low: 0, high: 1000)]
            case 2:
                targets = [.sweep(sector: opposite, low: 0, high: 1000), .sweep(sector: first, low: 0, high: 1000)]
            case 3:
                let share: Int = shares[first]
                targets = [share >= 1 ? .sweep(sector: first, low: 0, high: share - 1)
                    : .sweep(sector: first, low: share + 1, high: 1000)]
            case 4:
                targets = [ApsidesWorkshopTarget(kind: .periapsis, sector: (periSector + 1) % 8, low: 0, high: 1280)]
            case 5:
                let low: Int = apoapsis < 1280 ? apoapsis + 1 : 0
                let high: Int = apoapsis < 1280 ? 1280 : apoapsis - 1
                targets = [ApsidesWorkshopTarget(kind: .apoapsis, sector: apoSector, low: low, high: high)]
            default:
                for _ in 0..<random.int(0...2) { planets.append(random.int(0...1) == 0 ? planet(&random)
                    : nearPlanet(&random, points: points)) }
                for _ in 0..<random.int(1...4) {
                    let kind: Int = random.int(0...2)
                    if kind == 0 {
                        let s: Int = random.int(0...7)
                        let b: (low: Int, high: Int) = band(&random, around: shares[s], spread: -10...60,
                                                           bounds: 0...1000)
                        targets.append(.sweep(sector: s, low: b.low, high: b.high))
                    } else {
                        let apo: Bool = kind == 2
                        let right: Int = apo ? apoSector : periSector
                        let s: Int = random.int(0...3) == 0 ? random.int(0...7) : right
                        let b: (low: Int, high: Int) = band(&random, around: apo ? apoapsis : periapsis,
                                                           spread: -5...30, bounds: 0...1280)
                        targets.append(ApsidesWorkshopTarget(kind: apo ? .apoapsis : .periapsis, sector: s,
                                                             low: b.low, high: b.high))
                    }
                }
            }
            return Case(orbit: orbit, period: period, planets: planets, targets: targets, probes: probes)
        }

        /// The outcome code of a verdict ("win" when there is no failure).
        static func code(_ failure: ApsidesWorkshopFailure?) -> String {
            failure?.code ?? "win"
        }
    }

    // MARK: - 500 seeded orbits

    @Test("500 seeded orbits equal the independent recomputation", arguments: 0..<5)
    func seededOrbits(group: Int) {
        typealias F = ApsidesWorkshopFixed
        var outcomes: Set<String> = []
        let start: Int = group * Reference.groupSize
        for index in start..<(start + Reference.groupSize) {
            let c: Case = Reference.cases[index]
            #expect(c.orbit.isValid)
            let solved = ApsidesWorkshopSky.positions(c.orbit, period: c.period)
            let points: [ApsidesWorkshopPoint] = solved.points
            #expect(points.count == c.period)
            let report: ApsidesWorkshopReport = ApsidesWorkshopSky.report(period: c.period, planets: c.planets,
                                                                          targets: c.targets, orbit: c.orbit)
            #expect(report.positions == points)
            // Positions against the Double Kepler solution; residuals within the bound.
            let e: Int64 = F.one * Int64(c.orbit.eccentricity) / 20
            var largest: Int64 = 0
            for tick in 0..<c.period {
                let exact: (x: Double, y: Double) = Reference.position(c.orbit, tick: tick, period: c.period)
                let dx: Double = abs(exact.x - Double(points[tick].x))
                let dy: Double = abs(exact.y - Double(points[tick].y))
                #expect(dx <= 2 && dy <= 2, "case \(index) tick \(tick): off by (\(dx), \(dy))")
                let mean: Int64 = F.meanAnomaly(tick: tick, period: c.period)
                let anomaly = F.eccentricAnomaly(mean: mean, eccentricity: e)
                #expect(anomaly.residual <= F.residualBound, "case \(index) tick \(tick)")
                largest = max(largest, anomaly.residual)
                let big: Double = Double(anomaly.anomaly) / Reference.one
                let real: Double = abs(Double(mean) / Reference.one - big + Double(e) / Reference.one * sin(big))
                #expect(real <= Double(F.residualBound) / Reference.one + 0x1.0p-26, "case \(index) tick \(tick)")
                #expect(Reference.doubledArea(points, tick: tick) > 0, "case \(index) tick \(tick): not prograde")
                #expect(ApsidesWorkshopSky.sector(of: points[tick]) == Reference.sector(points[tick]),
                        "case \(index) tick \(tick) at (\(points[tick].x), \(points[tick].y))")
            }
            #expect(solved.largestResidual == largest && report.largestResidual == largest)
            #expect(largest <= F.residualBound)
            // Shares.
            let shares: [Int] = Reference.shares(points)
            #expect(report.shares == shares, "case \(index)")
            #expect(ApsidesWorkshopSky.shares(points) == shares)
            var sum: Int = 0
            for share in shares { sum += share }
            #expect(sum >= 993 && sum <= 1000, "case \(index): shares sum to \(sum)")
            // Apsis readings: the sectors from the direction, and the kernel's apsis positions on them.
            let periSector: Int = Reference.directionSector(c.orbit.direction, extra: 0)
            let apoSector: Int = Reference.directionSector(c.orbit.direction, extra: 180)
            #expect(c.orbit.periapsisSector == periSector && c.orbit.apoapsisSector == apoSector)
            #expect(Reference.sector(points[0]) == periSector, "case \(index)")
            #expect(Reference.sector(points[c.period / 2]) == apoSector, "case \(index)")
            let near: Int = Reference.distance(c.orbit, apoapsis: false)
            let far: Int = Reference.distance(c.orbit, apoapsis: true)
            #expect(c.orbit.periapsisDistance == near && c.orbit.apoapsisDistance == far)
            let p0: ApsidesWorkshopPoint = points[0]
            let pHalf: ApsidesWorkshopPoint = points[c.period / 2]
            let r0: Double = (Double(p0.x) * Double(p0.x) + Double(p0.y) * Double(p0.y)).squareRoot() * 20 / 256
            let rHalf: Double = (Double(pHalf.x) * Double(pHalf.x) + Double(pHalf.y) * Double(pHalf.y))
                .squareRoot() * 20 / 256
            #expect(abs(r0 - Double(near)) <= 0.2 && abs(rHalf - Double(far)) <= 0.2, "case \(index)")
            // Contact decisions on every segment for the judged and the probe planets.
            let planets: [ApsidesWorkshopPlanet] = c.planets + c.probes
            for tick in 0..<c.period {
                let next: Int = tick + 1 == c.period ? 0 : tick + 1
                for planet in planets {
                    let kernel: Bool = ApsidesWorkshopSky.touches(planet, from: points[tick], to: points[next])
                    #expect(kernel == Reference.strikes(planet, points[tick], points[next]),
                            "case \(index) tick \(tick) planet \(planet)")
                }
            }
            // Event ticks, deviations, met prefix and outcome.
            let verdict: Verdict = Reference.judge(c, points: points)
            #expect(report.eventTicks == verdict.ticks, "case \(index)")
            #expect(report.deviations == verdict.deviations, "case \(index)")
            #expect(report.met == verdict.met, "case \(index)")
            #expect(report.failure == verdict.failure, "case \(index)")
            #expect(report.wins == (verdict.failure == nil))
            outcomes.insert(Reference.code(verdict.failure))
        }
        let expected: Set<String> = ["win", "contact", "order", "share", "apsis-sector", "apsis-distance"]
        #expect(expected.isSubset(of: outcomes), "outcomes met: \(outcomes.sorted())")
    }

    // MARK: - Hand cases

    @Test("a point on each boundary ray belongs to the sector it begins; just before it, to the previous one")
    func boundaryRays() {
        let rays: [(x: Int, y: Int)] = [(100, 0), (100, 100), (0, 100), (-100, 100), (-100, 0), (-100, -100),
                                        (0, -100), (100, -100)]
        // A point turned slightly clockwise from each ray.
        let before: [(x: Int, y: Int)] = [(100, -1), (100, 99), (1, 100), (-99, 100), (-100, 1), (-100, -99),
                                          (-1, -100), (99, -100)]
        let after: [(x: Int, y: Int)] = [(100, 1), (99, 100), (-1, 100), (-100, 99), (-100, -1), (-99, -100),
                                         (1, -100), (100, -99)]
        for s in 0..<8 {
            let on = ApsidesWorkshopPoint(x: rays[s].x, y: rays[s].y)
            #expect(ApsidesWorkshopSky.sector(of: on) == s, "ray \(s)")
            #expect(Reference.sector(on) == s)
            let early = ApsidesWorkshopPoint(x: before[s].x, y: before[s].y)
            #expect(ApsidesWorkshopSky.sector(of: early) == (s + 7) % 8, "before ray \(s)")
            let late = ApsidesWorkshopPoint(x: after[s].x, y: after[s].y)
            #expect(ApsidesWorkshopSky.sector(of: late) == s, "after ray \(s)")
            // A periapsis on the ray (direction 3s) lands exactly on it through the exact turn table.
            let orbit = ApsidesWorkshopOrbit(size: 20, eccentricity: 5, direction: 3 * s)
            let p0: ApsidesWorkshopPoint = ApsidesWorkshopSky.positions(orbit, period: 16).points[0]
            let onRay: Bool = (rays[s].x == 0 ? p0.x == 0 : p0.x * rays[s].y == p0.y * rays[s].x)
                && p0.x.signum() == rays[s].x.signum() && p0.y.signum() == rays[s].y.signum()
            #expect(onRay, "periapsis of direction \(3 * s) at (\(p0.x), \(p0.y))")
            #expect(ApsidesWorkshopSky.sector(of: p0) == s)
        }
    }

    @Test("fixed-point sine and cosine agree with Foundation within 2^-26; 15-degree turns are exact")
    func fixedTrigonometry() {
        typealias F = ApsidesWorkshopFixed
        let tolerance: Double = 0x1.0p-26
        for i in -3000...3000 {
            let angle: Int64 = Int64(i) * 4_500_000
            let x: Double = Double(angle) / Reference.one
            #expect(abs(Double(F.sin(angle)) / Reference.one - sin(x)) <= tolerance, "sin at \(angle)")
            #expect(abs(Double(F.cos(angle)) / Reference.one - cos(x)) <= tolerance, "cos at \(angle)")
        }
        for step in 0..<24 {
            let t: (cos: Int64, sin: Int64) = F.turn(step)
            let radians: Double = Double(15 * step) * Double.pi / 180
            #expect(abs(Double(t.cos) / Reference.one - cos(radians)) <= tolerance, "turn \(step)")
            #expect(abs(Double(t.sin) / Reference.one - sin(radians)) <= tolerance, "turn \(step)")
        }
        #expect(F.turn(0).cos == F.one && F.turn(0).sin == 0)
        #expect(F.turn(6).cos == 0 && F.turn(6).sin == F.one)
        #expect(F.turn(12).cos == -F.one && F.turn(12).sin == 0)
        #expect(F.turn(18).cos == 0 && F.turn(18).sin == -F.one)
        for step in [3, 9, 15, 21] {
            let t: (cos: Int64, sin: Int64) = F.turn(step)
            #expect(abs(t.cos) == abs(t.sin), "turn \(step): |cos 45°| = |sin 45°|")
        }
        #expect(F.sin(0) == 0 && F.cos(0) == F.one)
        #expect(F.sin(F.pi) == 0 && F.cos(F.pi) == -F.one)
    }

    @Test("a circular orbit: constant radius, equal shares, the anomaly equals the mean anomaly")
    func circularOrbit() {
        typealias F = ApsidesWorkshopFixed
        let orbit = ApsidesWorkshopOrbit(size: 24, eccentricity: 0, direction: 5)
        #expect(orbit.isValid)
        let points: [ApsidesWorkshopPoint] = ApsidesWorkshopSky.positions(orbit, period: 32).points
        for p in points {
            let r: Double = (Double(p.x) * Double(p.x) + Double(p.y) * Double(p.y)).squareRoot()
            #expect(abs(r - 24 * 256) <= 1, "radius \(r)")
        }
        for share in ApsidesWorkshopSky.shares(points) {
            #expect((124...125).contains(share), "share \(share)")
        }
        for tick in 0..<32 {
            let mean: Int64 = F.meanAnomaly(tick: tick, period: 32)
            let solved = F.eccentricAnomaly(mean: mean, eccentricity: 0)
            #expect(solved.anomaly == mean && solved.residual == 0 && solved.newtonSteps == 0 && !solved.bisected)
        }
        #expect(orbit.periapsisDistance == 480 && orbit.apoapsisDistance == 480)
        #expect(orbit.periapsisSector == 1 && orbit.apoapsisSector == 5)
        #expect(ApsidesWorkshopSky.sector(of: points[0]) == 1 && ApsidesWorkshopSky.sector(of: points[16]) == 5)
        let target = ApsidesWorkshopTarget(kind: .apoapsis, sector: 5, low: 480, high: 480)
        let report = ApsidesWorkshopSky.report(period: 32, planets: [], targets: [target], orbit: orbit)
        #expect(report.wins && report.eventTicks == [16])
    }

    @Test("the extreme valid orbits are valid and stay in the sky; one step beyond is invalid")
    func extremeOrbits() {
        let extremes: [ApsidesWorkshopOrbit] = [ApsidesWorkshopOrbit(size: 12, eccentricity: 15, direction: 7),
                                               ApsidesWorkshopOrbit(size: 10, eccentricity: 14, direction: 0),
                                               ApsidesWorkshopOrbit(size: 40, eccentricity: 12, direction: 23)]
        for orbit in extremes {
            #expect(orbit.isValid, "\(orbit)")
            for period in [16, 96] {
                let solved = ApsidesWorkshopSky.positions(orbit, period: period)
                #expect(solved.largestResidual <= ApsidesWorkshopFixed.residualBound)
                for tick in 0..<period {
                    let p: ApsidesWorkshopPoint = solved.points[tick]
                    let r: Double = (Double(p.x) * Double(p.x) + Double(p.y) * Double(p.y)).squareRoot()
                    #expect(r >= 3 * 256 - 1 && r <= 64 * 256 + 1, "\(orbit) tick \(tick) radius \(r)")
                    let exact: (x: Double, y: Double) = Reference.position(orbit, tick: tick, period: period)
                    #expect(abs(exact.x - Double(p.x)) <= 2 && abs(exact.y - Double(p.y)) <= 2)
                }
            }
        }
        #expect(extremes[0].periapsisDistance == 60 && extremes[1].periapsisDistance == 60)
        #expect(extremes[2].apoapsisDistance == 1280)
        let beyond: [ApsidesWorkshopOrbit] = [ApsidesWorkshopOrbit(size: 11, eccentricity: 15, direction: 7),
                                             ApsidesWorkshopOrbit(size: 9, eccentricity: 14, direction: 0),
                                             ApsidesWorkshopOrbit(size: 10, eccentricity: 15, direction: 0),
                                             ApsidesWorkshopOrbit(size: 41, eccentricity: 12, direction: 23),
                                             ApsidesWorkshopOrbit(size: 40, eccentricity: 13, direction: 23)]
        for orbit in beyond {
            #expect(orbit.isInRange && !orbit.isValid, "\(orbit)")
        }
        let outside: [ApsidesWorkshopOrbit] = [ApsidesWorkshopOrbit(size: 7, eccentricity: 0, direction: 0),
                                              ApsidesWorkshopOrbit(size: 49, eccentricity: 0, direction: 0),
                                              ApsidesWorkshopOrbit(size: 20, eccentricity: -1, direction: 0),
                                              ApsidesWorkshopOrbit(size: 20, eccentricity: 16, direction: 0),
                                              ApsidesWorkshopOrbit(size: 20, eccentricity: 0, direction: -1),
                                              ApsidesWorkshopOrbit(size: 20, eccentricity: 0, direction: 24)]
        for orbit in outside {
            #expect(!orbit.isInRange && !orbit.isValid, "\(orbit)")
        }
    }

    @Test("a share on a band bound is inside; one unit beyond it fails share")
    func shareBandBounds() throws {
        let orbit = ApsidesWorkshopOrbit(size: 24, eccentricity: 6, direction: 4)
        let points: [ApsidesWorkshopPoint] = ApsidesWorkshopSky.positions(orbit, period: 32).points
        let s: Int = Reference.sector(points[0])
        let v: Int = Reference.shares(points)[s]
        try #require(v >= 11 && v <= 989)
        let cases: [(low: Int, high: Int, deviation: Int)] = [(v, v + 10, 0), (v + 1, v + 11, -1), (v - 10, v, 0),
                                                              (v - 11, v - 1, 1)]
        for c in cases {
            let target: ApsidesWorkshopTarget = .sweep(sector: s, low: c.low, high: c.high)
            let report = ApsidesWorkshopSky.report(period: 32, planets: [], targets: [target], orbit: orbit)
            #expect(report.deviations == [c.deviation], "band \(c.low) … \(c.high)")
            if c.deviation == 0 {
                #expect(report.wins && report.met == 1)
            } else {
                #expect(report.failure == .share(target: 0, tick: 0, share: v) && report.met == 0)
            }
        }
    }

    @Test("an apsis distance on a range bound is inside; one unit beyond fails apsis-distance; wrong sector first")
    func apsisRangeBounds() {
        let orbit = ApsidesWorkshopOrbit(size: 24, eccentricity: 6, direction: 4)
        let kinds: [ApsidesWorkshopTargetKind] = [.periapsis, .apoapsis]
        for kind in kinds {
            let apo: Bool = kind == .apoapsis
            let d: Int = Reference.distance(orbit, apoapsis: apo)
            let s: Int = Reference.directionSector(orbit.direction, extra: apo ? 180 : 0)
            let cases: [(low: Int, high: Int, deviation: Int)] = [(d, d + 40, 0), (d + 1, d + 40, -1),
                                                                  (d - 40, d, 0), (d - 40, d - 1, 1)]
            for c in cases {
                let target = ApsidesWorkshopTarget(kind: kind, sector: s, low: c.low, high: c.high)
                let report = ApsidesWorkshopSky.report(period: 32, planets: [], targets: [target], orbit: orbit)
                #expect(report.deviations == [c.deviation], "\(kind) range \(c.low) … \(c.high)")
                #expect(report.eventTicks == [apo ? 16 : 0])
                if c.deviation == 0 {
                    #expect(report.wins)
                } else {
                    #expect(report.failure == .apsisDistance(target: 0, distance: d))
                }
            }
            let wrong = ApsidesWorkshopTarget(kind: kind, sector: (s + 1) % 8, low: d, high: d)
            let report = ApsidesWorkshopSky.report(period: 32, planets: [], targets: [wrong], orbit: orbit)
            #expect(report.failure == .apsisSector(target: 0, sector: s))
        }
    }

    @Test("a planet one sky unit inside contact is struck; grazing and one unit outside are not")
    func planetContactBounds() {
        // Planet at (10, 0) lattice units, radius 2: centre (2560, 0), radius 512 sky units.
        let planet = ApsidesWorkshopPlanet(x: 10, y: 0, radius: 2)
        let offsets: [(y: Int, struck: Bool)] = [(512, false), (511, true), (513, false), (-511, true), (-512, false)]
        for o in offsets {
            // The closest point inside the segment.
            let a = ApsidesWorkshopPoint(x: 2260, y: o.y)
            let b = ApsidesWorkshopPoint(x: 2860, y: o.y)
            #expect(ApsidesWorkshopSky.touches(planet, from: a, to: b) == o.struck, "interior at \(o.y)")
            #expect(Reference.strikes(planet, a, b) == o.struck)
            // The closest point at the first endpoint, then at the second.
            let near = ApsidesWorkshopPoint(x: 2560, y: o.y)
            let away = ApsidesWorkshopPoint(x: 2560, y: o.y > 0 ? 1500 : -1500)
            #expect(ApsidesWorkshopSky.touches(planet, from: near, to: away) == o.struck, "start at \(o.y)")
            #expect(ApsidesWorkshopSky.touches(planet, from: away, to: near) == o.struck, "end at \(o.y)")
        }
        // A slanted segment whose closest point lies at distance exactly 1280 = 5 · 256 (3-4-5), then 0.6 nearer or
        // farther after a one-unit shift.
        let slanted = ApsidesWorkshopPlanet(x: 0, y: 20, radius: 5)
        let shifts: [(dx: Int, struck: Bool)] = [(0, false), (-1, true), (1, false)]
        for s in shifts {
            let a = ApsidesWorkshopPoint(x: 1792 + s.dx, y: 5376)
            let b = ApsidesWorkshopPoint(x: -256 + s.dx, y: 6912)
            #expect(ApsidesWorkshopSky.touches(slanted, from: a, to: b) == s.struck, "slanted shift \(s.dx)")
            #expect(Reference.strikes(slanted, a, b) == s.struck)
        }
    }

    @Test("contact is named by its lowest tick, then its lowest planet, before any target")
    func contactOrder() {
        let orbit = ApsidesWorkshopOrbit(size: 40, eccentricity: 0, direction: 0)
        let points: [ApsidesWorkshopPoint] = ApsidesWorkshopSky.positions(orbit, period: 16).points
        let at5: (x: Int, y: Int) = Reference.lattice(points[5])
        let at3: (x: Int, y: Int) = Reference.lattice(points[3])
        let planets: [ApsidesWorkshopPlanet] = [ApsidesWorkshopPlanet(x: at5.x, y: at5.y, radius: 1),
                                                ApsidesWorkshopPlanet(x: at3.x, y: at3.y, radius: 1),
                                                ApsidesWorkshopPlanet(x: at3.x, y: at3.y, radius: 2)]
        let targets: [ApsidesWorkshopTarget] = [ApsidesWorkshopTarget(kind: .periapsis, sector: 7, low: 0, high: 1)]
        let report = ApsidesWorkshopSky.report(period: 16, planets: planets, targets: targets, orbit: orbit)
        #expect(report.failure == .contact(planet: 1, tick: 2))
        #expect(report.met == 0 && !report.wins)
        let c = Case(orbit: orbit, period: 16, planets: planets, targets: targets, probes: [])
        #expect(Reference.judge(c, points: points).failure == report.failure)
    }

    @Test("a sector never entered has share 0 and event tick T")
    func sectorNeverEntered() {
        let orbit = ApsidesWorkshopOrbit(size: 12, eccentricity: 15, direction: 0)
        let points: [ApsidesWorkshopPoint] = ApsidesWorkshopSky.positions(orbit, period: 16).points
        var missing: [Int] = []
        for s in 0..<8 {
            var entered: Bool = false
            for p in points where Reference.sector(p) == s { entered = true }
            if !entered { missing.append(s) }
        }
        #expect(missing == [1, 6, 7])
        let shares: [Int] = ApsidesWorkshopSky.shares(points)
        for s in missing {
            #expect(shares[s] == 0, "sector \(s)")
            let target: ApsidesWorkshopTarget = .sweep(sector: s, low: 0, high: 0)
            let report = ApsidesWorkshopSky.report(period: 16, planets: [], targets: [target], orbit: orbit)
            #expect(report.eventTicks == [16] && report.wins, "sector \(s)")
        }
    }

    @Test("the bisection fallback is reached by valid orbits and keeps the residual within the bound")
    func newtonFallback() {
        typealias F = ApsidesWorkshopFixed
        // e = 0.4, tick 3 of 16: Newton's first step leaves [M − e, M + e], so bisection decides E.
        let e: Int64 = F.one * 8 / 20
        let mean: Int64 = F.meanAnomaly(tick: 3, period: 16)
        let solved = F.eccentricAnomaly(mean: mean, eccentricity: e)
        #expect(solved.bisected && solved.residual <= F.residualBound)
        let exact: Double = Reference.anomaly(mean: Double(mean) / Reference.one,
                                              eccentricity: Double(e) / Reference.one)
        #expect(abs(Double(solved.anomaly) / Reference.one - exact) <= 1e-6)
        // Every eccentricity step and every period: the bound holds whether Newton or bisection decides.
        var bisected: Int = 0
        for k in 0...15 {
            let ek: Int64 = F.one * Int64(k) / 20
            for period in stride(from: 16, through: 96, by: 2) {
                for tick in 0..<period {
                    let m: Int64 = F.meanAnomaly(tick: tick, period: period)
                    let s = F.eccentricAnomaly(mean: m, eccentricity: ek)
                    #expect(s.residual <= F.residualBound, "k \(k) period \(period) tick \(tick)")
                    #expect(s.anomaly >= m - ek && s.anomaly <= m + ek)
                    #expect(s.newtonSteps <= F.newtonSteps)
                    if s.bisected { bisected += 1 }
                }
            }
        }
        #expect(bisected > 0)
    }
}
