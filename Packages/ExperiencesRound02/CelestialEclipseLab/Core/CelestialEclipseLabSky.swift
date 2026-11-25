// CelestialEclipseLabSky — feature 461 (R02-G17-01) T-R02G1701-002 (FR-R02G1701-001, 002, 004, 005, 014;
// SC-R02G1701-003, 004; clarifications Q1, Q3, Q5). The exact sky of Celestial Eclipse Lab: bodies on periodic orbits
// of lattice positions, each with a disc radius and a phase (the starting offset along its orbit), seen along the z
// axis (the projection drops z; a greater z is nearer the viewer). Two bodies eclipse at a tick when the squared
// distance between their projected centres is strictly smaller than the square of the sum of their radii; touching
// discs do not eclipse. Every pair of bodies keeps one front-to-back order at every tick (the level checks it), so
// every eclipse names its front and back body. An eclipse interval is a run of eclipse ticks of one pair; its first
// tick is an eclipse event; its visibility class is the deepest over its ticks (total when the front radius is at least
// the back radius and the squared distance is at most (rf − rb)², annular when the front radius is smaller and the
// squared distance is at most (rb − rf)², partial otherwise; total and annular rank above partial). The timeline orders
// the intervals by first tick, then front body, then back body, and the judge walks their events against the target: a
// match advances; the next target outside its window fails `window`; any other event fails `unwanted`; no events left
// fails `horizon`; events after the last match are ignored. Integers only; no clock, no random source.
import Foundation

/// A lattice position of a body, each coordinate −32 … 32.
public struct CelestialEclipseLabVector: Sendable, Hashable, Codable {
    /// The x coordinate (projected).
    public let x: Int
    /// The y coordinate (projected).
    public let y: Int
    /// The depth; a greater z is nearer the viewer.
    public let z: Int

    /// A position of the given coordinates.
    public init(_ x: Int, _ y: Int, _ z: Int) {
        self.x = x
        self.y = y
        self.z = z
    }

    /// The squared distance between the projections (x, y) of this position and `other`.
    public func projectedSquaredDistance(to other: Self) -> Int {
        let dx: Int = x - other.x
        let dy: Int = y - other.y
        return dx * dx + dy * dy
    }
}

/// A body: a periodic orbit of lattice positions, a disc radius and whether its phase is fixed.
public struct CelestialEclipseLabBody: Sendable, Hashable, Codable {
    /// The positions along the orbit, one per tick of the period.
    public let orbit: [CelestialEclipseLabVector]
    /// The disc radius, 1 … 8.
    public let radius: Int
    /// Whether the player cannot change this body's phase.
    public let fixed: Bool

    /// A body of the given values (checked by the level).
    public init(orbit: [CelestialEclipseLabVector], radius: Int, fixed: Bool = false) {
        self.orbit = orbit
        self.radius = radius
        self.fixed = fixed
    }

    /// The period: the number of orbit positions.
    public var period: Int { orbit.count }

    /// The position at `tick` with phase `phase`: orbit[(tick + phase) mod period].
    public func position(at tick: Int, phase: Int) -> CelestialEclipseLabVector {
        let count: Int = max(orbit.count, 1)
        let index: Int = ((tick + phase) % count + count) % count
        return orbit[index]
    }

    /// The smallest depth along the orbit.
    public var nearestBack: Int { orbit.map(\.z).min() ?? 0 }

    /// The largest depth along the orbit.
    public var farthestFront: Int { orbit.map(\.z).max() ?? 0 }
}

/// One eclipse of the target sequence: a front body, a back body and a window of ticks.
public struct CelestialEclipseLabTarget: Sendable, Hashable, Codable {
    /// The body in front.
    public let front: Int
    /// The body behind.
    public let back: Int
    /// The first tick of the window.
    public let open: Int
    /// The last tick of the window.
    public let close: Int

    /// A target eclipse of the given values (checked by the level).
    public init(front: Int, back: Int, open: Int, close: Int) {
        self.front = front
        self.back = back
        self.open = open
        self.close = close
    }

    /// Whether `tick` lies in the window (both ends included).
    public func admits(_ tick: Int) -> Bool { tick >= open && tick <= close }
}

/// The visibility class of an eclipse.
public enum CelestialEclipseLabVisibility: String, Sendable, Codable, CaseIterable {
    /// The discs overlap partly.
    case partial
    /// The front disc covers the back disc entirely.
    case total
    /// The front disc lies entirely inside the back disc, which shows around it as a ring.
    case annular

    /// The depth rank: total and annular above partial.
    var rank: Int { self == .partial ? 0 : 1 }
}

/// One eclipse interval: a pair of bodies, the first and last tick of a run of eclipse ticks and its class.
public struct CelestialEclipseLabInterval: Sendable, Hashable {
    /// The body in front.
    public let front: Int
    /// The body behind.
    public let back: Int
    /// The first eclipse tick (the event).
    public let first: Int
    /// The last eclipse tick of the run.
    public let last: Int
    /// The deepest class over the run's ticks.
    public let visibility: CelestialEclipseLabVisibility

    /// An interval of the given values.
    public init(front: Int, back: Int, first: Int, last: Int, visibility: CelestialEclipseLabVisibility) {
        self.front = front
        self.back = back
        self.first = first
        self.last = last
        self.visibility = visibility
    }
}

/// Why a run fails.
public enum CelestialEclipseLabFailure: Sendable, Hashable, Codable {
    /// An eclipse that is not the next target came first.
    case unwanted(front: Int, back: Int, tick: Int)
    /// The next target eclipse came outside its window.
    case window(front: Int, back: Int, tick: Int, open: Int, close: Int)
    /// The clock reached its horizon with this target eclipse (and any after it) still to come.
    case horizon(front: Int, back: Int, open: Int, close: Int)

    /// The failure code: `unwanted`, `window` or `horizon`.
    public var code: String {
        switch self {
        case .unwanted: "unwanted"
        case .window: "window"
        case .horizon: "horizon"
        }
    }
}

/// The predicted timeline of a phase setting: the intervals in order, the matched prefix of the target and the
/// failure a run would end with (nil when it would win).
public struct CelestialEclipseLabTimeline: Sendable, Equatable {
    /// The eclipse intervals, ordered by first tick, then front body, then back body.
    public let intervals: [CelestialEclipseLabInterval]
    /// How many target eclipses the events match, in order.
    public let matched: Int
    /// The failure a run would end with; nil when a run would win.
    public let failure: CelestialEclipseLabFailure?

    /// A timeline of the given values.
    public init(intervals: [CelestialEclipseLabInterval], matched: Int, failure: CelestialEclipseLabFailure?) {
        self.intervals = intervals
        self.matched = matched
        self.failure = failure
    }

    /// Whether a run would win.
    public var wins: Bool { failure == nil }
}

/// The exact sky rules (see the file header).
public enum CelestialEclipseLabSky {
    /// Whether the discs of `a` (phase `phases.0`) and `b` (phase `phases.1`) overlap at `tick`: the squared projected
    /// distance is strictly below (ra + rb)².
    public static func eclipses(_ a: CelestialEclipseLabBody, _ b: CelestialEclipseLabBody, at tick: Int,
                                phases: (Int, Int)) -> Bool {
        let pa: CelestialEclipseLabVector = a.position(at: tick, phase: phases.0)
        let pb: CelestialEclipseLabVector = b.position(at: tick, phase: phases.1)
        let reach: Int = a.radius + b.radius
        return pa.projectedSquaredDistance(to: pb) < reach * reach
    }

    /// The front and back body of the pair (i, j) in the level's depth order: the body whose smallest depth is above
    /// the other's largest depth is in front.
    public static func order(_ level: CelestialEclipseLabLevel, _ i: Int, _ j: Int) -> (front: Int, back: Int) {
        level.bodies[i].nearestBack > level.bodies[j].farthestFront ? (i, j) : (j, i)
    }

    /// The visibility class of one eclipse tick of `front` over `back` at squared projected distance `d2`.
    public static func visibility(front: CelestialEclipseLabBody, back: CelestialEclipseLabBody,
                                  squaredDistance d2: Int) -> CelestialEclipseLabVisibility {
        if front.radius >= back.radius {
            let gap: Int = front.radius - back.radius
            return d2 <= gap * gap ? .total : .partial
        }
        let gap: Int = back.radius - front.radius
        return d2 <= gap * gap ? .annular : .partial
    }

    /// Every eclipse interval of `level` with `phases` over ticks 0 … horizon − 1, ordered by first tick, then front
    /// body, then back body.
    public static func intervals(_ level: CelestialEclipseLabLevel, phases: [Int]) -> [CelestialEclipseLabInterval] {
        var result: [CelestialEclipseLabInterval] = []
        let count: Int = level.bodies.count
        for i in 0..<count {
            for j in (i + 1)..<max(count, i + 1) {
                let pair: (front: Int, back: Int) = order(level, i, j)
                let front: CelestialEclipseLabBody = level.bodies[pair.front]
                let back: CelestialEclipseLabBody = level.bodies[pair.back]
                var start: Int? = nil
                var deepest: CelestialEclipseLabVisibility = .partial
                for tick in 0..<level.horizon {
                    let pf: CelestialEclipseLabVector = front.position(at: tick, phase: phases[pair.front])
                    let pb: CelestialEclipseLabVector = back.position(at: tick, phase: phases[pair.back])
                    let d2: Int = pf.projectedSquaredDistance(to: pb)
                    let reach: Int = front.radius + back.radius
                    if d2 < reach * reach {
                        let now: CelestialEclipseLabVisibility = visibility(front: front, back: back,
                                                                            squaredDistance: d2)
                        if start == nil {
                            start = tick
                            deepest = now
                        } else if now.rank > deepest.rank {
                            deepest = now
                        }
                    } else if let first = start {
                        result.append(CelestialEclipseLabInterval(front: pair.front, back: pair.back, first: first,
                                                                  last: tick - 1, visibility: deepest))
                        start = nil
                    }
                }
                if let first = start {
                    result.append(CelestialEclipseLabInterval(front: pair.front, back: pair.back, first: first,
                                                              last: level.horizon - 1, visibility: deepest))
                }
            }
        }
        result.sort { lhs, rhs in
            if lhs.first != rhs.first { return lhs.first < rhs.first }
            if lhs.front != rhs.front { return lhs.front < rhs.front }
            return lhs.back < rhs.back
        }
        return result
    }

    /// The predicted timeline of `level` with `phases`: the intervals, the matched prefix of the target and the
    /// judge's failure (see the file header).
    public static func timeline(_ level: CelestialEclipseLabLevel, phases: [Int]) -> CelestialEclipseLabTimeline {
        let all: [CelestialEclipseLabInterval] = intervals(level, phases: phases)
        var matched: Int = 0
        for interval in all {
            if matched == level.target.count { break }
            let next: CelestialEclipseLabTarget = level.target[matched]
            if interval.front == next.front && interval.back == next.back {
                if next.admits(interval.first) {
                    matched += 1
                    continue
                }
                return CelestialEclipseLabTimeline(
                    intervals: all, matched: matched,
                    failure: .window(front: next.front, back: next.back, tick: interval.first, open: next.open,
                                     close: next.close))
            }
            return CelestialEclipseLabTimeline(
                intervals: all, matched: matched,
                failure: .unwanted(front: interval.front, back: interval.back, tick: interval.first))
        }
        if matched < level.target.count {
            let next: CelestialEclipseLabTarget = level.target[matched]
            return CelestialEclipseLabTimeline(
                intervals: all, matched: matched,
                failure: .horizon(front: next.front, back: next.back, open: next.open, close: next.close))
        }
        return CelestialEclipseLabTimeline(intervals: all, matched: matched, failure: nil)
    }
}

/// A player action of Celestial Eclipse Lab (clarification Q2): a phase change of a movable body (one action) or the
/// run that ends the level (no action). Encoded as `{"phase": {"_0": body, "_1": offset}}` or `{"run": {}}`.
public enum CelestialEclipseLabAction: Sendable, Hashable, Codable {
    /// Set body `0`'s phase to offset `1` (0 … period − 1, different from the current one).
    case phase(Int, Int)
    /// Run the clock and end the level.
    case run
}
