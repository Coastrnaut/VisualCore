// ApsidesWorkshopOrbit — feature 471 (R02-G18-01) T-R02G1801-002 (FR-R02G1801-002 … 005, 014; SC-R02G1801-003, 004;
// clarifications Q1 … Q3, Q5). Apsides Workshop's sky: a star at the origin, 256 sky units per lattice unit; an orbit
// of size a 8 … 48 lattice units, eccentricity step k 0 … 15 (e = k/20) and periapsis direction step d 0 … 23 (15°
// each), valid when a(20 − k) ≥ 60 and a(20 + k) ≤ 1280; the orbiter's position at every tick of one revolution from
// Kepler's equation (``ApsidesWorkshopFixed``), (a(cos E − e), a·√(1 − e²)·sin E) turned by 15d° and rounded to whole
// sky units; 8 sectors of 45° (the boundary ray belonging to the sector it begins); the share of each sector by one
// cross-product triangle per tick, counted for P(t), in tenths of a percent rounded down; apsis readings; exclusion
// planets struck when a tick segment passes strictly closer than the radius; the targets' event ticks and the judge
// (contact first, then the targets in order: order, share, apsis-sector, apsis-distance). Everything after the anomaly
// is exact integer arithmetic on the rounded positions.

/// An orbit: size, eccentricity step and periapsis direction step.
public struct ApsidesWorkshopOrbit: Sendable, Hashable, Codable {
    /// The sizes (semi-major axis) in lattice units.
    public static let sizes: ClosedRange<Int> = 8...48
    /// The eccentricity steps (e = step / 20).
    public static let eccentricities: ClosedRange<Int> = 0...15
    /// The periapsis direction steps (15° each, counterclockwise from +x).
    public static let directions: ClosedRange<Int> = 0...23

    /// The semi-major axis in lattice units, 8 … 48.
    public let size: Int
    /// The eccentricity step, 0 … 15 (e = eccentricity / 20).
    public let eccentricity: Int
    /// The periapsis direction step, 0 … 23 (15° each).
    public let direction: Int

    /// An orbit of the given steps (not checked; see ``isInRange`` and ``isValid``).
    public init(size: Int, eccentricity: Int, direction: Int) {
        self.size = size
        self.eccentricity = eccentricity
        self.direction = direction
    }

    /// Whether every step is within its range.
    public var isInRange: Bool {
        Self.sizes.contains(size) && Self.eccentricities.contains(eccentricity) && Self.directions.contains(direction)
    }

    /// Whether the steps are in range, the periapsis stays at least 3 lattice units from the star (a(20 − k) ≥ 60) and
    /// the apoapsis within the sky (a(20 + k) ≤ 1280).
    public var isValid: Bool {
        isInRange && size * (20 - eccentricity) >= 60 && size * (20 + eccentricity) <= 1280
    }

    /// The periapsis sector, ⌊d/3⌋.
    public var periapsisSector: Int { direction / 3 }
    /// The apoapsis sector, ⌊(d + 12)/3⌋ mod 8.
    public var apoapsisSector: Int { ((direction + 12) / 3) % 8 }
    /// The periapsis distance in twentieths of a lattice unit, a(20 − k).
    public var periapsisDistance: Int { size * (20 - eccentricity) }
    /// The apoapsis distance in twentieths of a lattice unit, a(20 + k).
    public var apoapsisDistance: Int { size * (20 + eccentricity) }
}

/// A point of the sky in sky units (256 per lattice unit).
public struct ApsidesWorkshopPoint: Sendable, Hashable, Codable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

/// An exclusion planet: a centre in lattice units and a radius.
public struct ApsidesWorkshopPlanet: Sendable, Hashable, Codable {
    /// The centre in lattice units, each −64 … 64.
    public let x: Int
    public let y: Int
    /// The radius in lattice units, 1 … 8.
    public let radius: Int

    public init(x: Int, y: Int, radius: Int) {
        self.x = x
        self.y = y
        self.radius = radius
    }
}

/// The kind of a target.
public enum ApsidesWorkshopTargetKind: String, Sendable, Codable, CaseIterable {
    /// A sector sweep: the sector's share must lie in low … high (tenths of a percent).
    case sweep
    /// The periapsis must lie in the sector at a distance in low … high (twentieths of a lattice unit).
    case periapsis
    /// The apoapsis must lie in the sector at a distance in low … high (twentieths of a lattice unit).
    case apoapsis
}

/// A target: a sector sweep or an apsis target, with its band (both bounds included).
public struct ApsidesWorkshopTarget: Sendable, Hashable, Codable {
    public let kind: ApsidesWorkshopTargetKind
    /// The sector, 0 … 7.
    public let sector: Int
    /// The lowest share (sweep, tenths of a percent) or nearest distance (apsis, twentieths).
    public let low: Int
    /// The highest share (sweep) or farthest distance (apsis).
    public let high: Int

    public init(kind: ApsidesWorkshopTargetKind, sector: Int, low: Int, high: Int) {
        self.kind = kind
        self.sector = sector
        self.low = low
        self.high = high
    }

    /// A sector sweep target.
    public static func sweep(sector: Int, low: Int, high: Int) -> ApsidesWorkshopTarget {
        ApsidesWorkshopTarget(kind: .sweep, sector: sector, low: low, high: high)
    }
}

/// Why a play fails.
public enum ApsidesWorkshopFailure: Sendable, Hashable, Codable {
    /// The orbit struck planet `planet` on the segment from tick `tick`.
    case contact(planet: Int, tick: Int)
    /// Target `target` comes at tick `tick`, before the previous target.
    case order(target: Int, tick: Int)
    /// Sweep target `target` (event tick `tick`) has share `share`, outside its band.
    case share(target: Int, tick: Int, share: Int)
    /// Apsis target `target` lies in sector `sector`, not its sector.
    case apsisSector(target: Int, sector: Int)
    /// Apsis target `target` lies at distance `distance` (twentieths), outside its range.
    case apsisDistance(target: Int, distance: Int)

    /// The failure's code: `contact`, `order`, `share`, `apsis-sector` or `apsis-distance`.
    public var code: String {
        switch self {
        case .contact: "contact"
        case .order: "order"
        case .share: "share"
        case .apsisSector: "apsis-sector"
        case .apsisDistance: "apsis-distance"
        }
    }
}

/// The orbit report after an action: positions, shares, residual, event ticks, deviations and the predicted outcome.
public struct ApsidesWorkshopReport: Sendable, Equatable {
    /// The orbiter's position at ticks 0 … period − 1.
    public let positions: [ApsidesWorkshopPoint]
    /// The share of each sector 0 … 7 in tenths of a percent (rounded down).
    public let shares: [Int]
    /// The largest Kepler residual over the revolution (fixed point, 2^30 as one).
    public let largestResidual: Int64
    /// The event tick of each target.
    public let eventTicks: [Int]
    /// Each target's deviation: how far its share or distance lies outside its band (negative below, positive above,
    /// 0 inside).
    public let deviations: [Int]
    /// The number of targets met in order before the first unmet one (all of them when the orbit wins).
    public let met: Int
    /// The failure of a play now, or nil when it would win.
    public let failure: ApsidesWorkshopFailure?

    /// Whether a play now would win.
    public var wins: Bool { failure == nil }
}

/// The exact rules of the sky.
public enum ApsidesWorkshopSky {
    /// Sky units per lattice unit.
    public static let unit: Int = 256
    /// The star's radius in lattice units.
    public static let starRadius: Int = 2
    /// The number of sectors.
    public static let sectorCount: Int = 8
    /// The share of the whole orbit, in tenths of a percent.
    public static let wholeShare: Int = 1000

    /// The orbiter's position at every tick of one revolution of `period` ticks, and the largest Kepler residual.
    public static func positions(_ orbit: ApsidesWorkshopOrbit, period: Int) -> (points: [ApsidesWorkshopPoint],
                                                                             largestResidual: Int64) {
        typealias F = ApsidesWorkshopFixed
        let e: Int64 = F.one * Int64(orbit.eccentricity) / 20
        let b: Int64 = F.sqrt(F.one - F.mul(e, e))
        let a: Int64 = Int64(orbit.size * unit)
        let turn = F.turn(orbit.direction)
        var points: [ApsidesWorkshopPoint] = []
        points.reserveCapacity(period)
        var largest: Int64 = 0
        for tick in 0..<period {
            let solved = F.eccentricAnomaly(mean: F.meanAnomaly(tick: tick, period: period), eccentricity: e)
            largest = max(largest, solved.residual)
            let cosE: Int64 = F.cos(solved.anomaly)
            let sinE: Int64 = F.sin(solved.anomaly)
            // In sky units with 2^16 as one, so the turn's products stay below 2^62.
            let x16: Int64 = F.roundShift(a * (cosE - e), 14)
            let y16: Int64 = F.roundShift(a * F.mul(b, sinE), 14)
            let x: Int64 = F.roundShift(x16 * turn.cos - y16 * turn.sin, 46)
            let y: Int64 = F.roundShift(x16 * turn.sin + y16 * turn.cos, 46)
            points.append(ApsidesWorkshopPoint(x: Int(x), y: Int(y)))
        }
        return (points, largest)
    }

    /// The sector 0 … 7 of a point other than the star: sector s covers the directions from 45s° (included) to
    /// 45(s + 1)° (excluded), decided from the signs of x and y and |x| against |y|.
    public static func sector(of p: ApsidesWorkshopPoint) -> Int {
        let x: Int = p.x
        let y: Int = p.y
        if y >= 0 {
            if x > 0 && y < x { return 0 }
            if x > 0 { return 1 }          // y ≥ x > 0
            if y > -x { return 2 }         // x ≤ 0
            if y > 0 { return 3 }          // 0 < y ≤ −x
            return 4                       // y == 0, x < 0
        }
        if x < 0 && y > x { return 4 }
        if x < 0 { return 5 }              // y ≤ x < 0
        if y < -x { return 6 }             // x ≥ 0
        return 7                           // −x ≤ y < 0, x > 0
    }

    /// The share of each sector in tenths of a percent, rounded down: one triangle star → P(t) → P(t + 1) per tick
    /// (P(period) = P(0)), its doubled area the cross product, counted for the sector of P(t).
    public static func shares(_ points: [ApsidesWorkshopPoint]) -> [Int] {
        var areas: [Int64] = Array(repeating: 0, count: sectorCount)
        var total: Int64 = 0
        for (index, p) in points.enumerated() {
            let q: ApsidesWorkshopPoint = points[(index + 1) % points.count]
            let doubled: Int64 = Int64(p.x) * Int64(q.y) - Int64(p.y) * Int64(q.x)
            areas[sector(of: p)] += doubled
            total += doubled
        }
        guard total > 0 else { return Array(repeating: 0, count: sectorCount) }
        return areas.map { Int(max(0, $0) * Int64(wholeShare) / total) }
    }

    /// Whether `planet` is struck by the segment a → b: its centre's distance to the segment is strictly below its
    /// radius, decided exactly with integer dot and cross products.
    public static func touches(_ planet: ApsidesWorkshopPlanet, from a: ApsidesWorkshopPoint,
                               to b: ApsidesWorkshopPoint) -> Bool {
        let cx = Int64(planet.x * unit), cy = Int64(planet.y * unit)
        let r = Int64(planet.radius * unit)
        let r2: Int64 = r * r
        let dx = Int64(b.x - a.x), dy = Int64(b.y - a.y)
        let wx: Int64 = cx - Int64(a.x), wy: Int64 = cy - Int64(a.y)
        let dot: Int64 = wx * dx + wy * dy
        if dot <= 0 { return wx * wx + wy * wy < r2 }
        let length2: Int64 = dx * dx + dy * dy
        if dot >= length2 {
            let ux: Int64 = cx - Int64(b.x), uy: Int64 = cy - Int64(b.y)
            return ux * ux + uy * uy < r2
        }
        let cross: Int64 = wx * dy - wy * dx
        return cross * cross < r2 * length2
    }

    /// The event tick of `target`: a sweep, the first tick whose position lies in its sector (`period` if none);
    /// periapsis 0; apoapsis period / 2.
    public static func eventTick(_ target: ApsidesWorkshopTarget, points: [ApsidesWorkshopPoint], period: Int) -> Int {
        switch target.kind {
        case .periapsis: return 0
        case .apoapsis: return period / 2
        case .sweep: return points.firstIndex { sector(of: $0) == target.sector } ?? period
        }
    }

    /// The full report of `orbit` in `level`.
    public static func report(_ level: ApsidesWorkshopLevel, orbit: ApsidesWorkshopOrbit) -> ApsidesWorkshopReport {
        report(period: level.period, planets: level.planets, targets: level.targets, orbit: orbit)
    }

    /// The full report of `orbit` with the given period, planets and targets: contact first (lowest tick, then lowest
    /// planet), then the targets in order (order, share, apsis-sector, apsis-distance).
    public static func report(period: Int, planets: [ApsidesWorkshopPlanet], targets: [ApsidesWorkshopTarget],
                              orbit: ApsidesWorkshopOrbit) -> ApsidesWorkshopReport {
        let (points, largest) = positions(orbit, period: period)
        let shares: [Int] = shares(points)
        let ticks: [Int] = targets.map { eventTick($0, points: points, period: period) }
        var deviations: [Int] = []
        for target in targets {
            let value: Int = reading(target, orbit: orbit, shares: shares)
            deviations.append(value < target.low ? value - target.low : value > target.high ? value - target.high : 0)
        }
        var failure: ApsidesWorkshopFailure?
        contact: for tick in 0..<period {
            for (index, planet) in planets.enumerated()
            where touches(planet, from: points[tick], to: points[(tick + 1) % period]) {
                failure = .contact(planet: index, tick: tick)
                break contact
            }
        }
        var met: Int = 0
        if failure == nil {
            for (index, target) in targets.enumerated() {
                if index > 0 && ticks[index] < ticks[index - 1] {
                    failure = .order(target: index, tick: ticks[index]); break
                }
                switch target.kind {
                case .sweep:
                    if deviations[index] != 0 {
                        failure = .share(target: index, tick: ticks[index], share: shares[target.sector])
                    }
                case .periapsis, .apoapsis:
                    let sector: Int = target.kind == .periapsis ? orbit.periapsisSector : orbit.apoapsisSector
                    if sector != target.sector {
                        failure = .apsisSector(target: index, sector: sector)
                    } else if deviations[index] != 0 {
                        failure = .apsisDistance(target: index, distance: reading(target, orbit: orbit,
                                                                                    shares: shares))
                    }
                }
                if failure != nil { break }
                met += 1
            }
        }
        return ApsidesWorkshopReport(positions: points, shares: shares, largestResidual: largest, eventTicks: ticks,
                                     deviations: deviations, met: met, failure: failure)
    }

    /// The value a target's band is compared with: the sector's share for a sweep, the apsis distance for an apsis
    /// target.
    static func reading(_ target: ApsidesWorkshopTarget, orbit: ApsidesWorkshopOrbit, shares: [Int]) -> Int {
        switch target.kind {
        case .sweep: return shares[target.sector]
        case .periapsis: return orbit.periapsisDistance
        case .apoapsis: return orbit.apoapsisDistance
        }
    }
}
