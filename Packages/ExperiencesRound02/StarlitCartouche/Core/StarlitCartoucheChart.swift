// StarlitCartoucheChart — feature 451 (R02-G16-01) T-R02G1601-002 (FR-R02G1601-002, 003, 014; SC-R02G1601-003, 004;
// clarifications Q1 … Q4). The exact geometry and timing of Starlit Cartouche, in integers only:
//
// - A star sits at `orbit[b mod length]` at beat b (beats are whole numbers from 0; an orbit has 1 … 4 lattice
//   positions, each coordinate −8 … 8). Its glyph point is a cell of the 5 × 5 cartouche grid.
// - A corridor joins two stars (undirected) and takes 1 … 3 beats to fly. It is flyable at beat b when the squared
//   distance between its stars' positions at b is at most r², r the level's range.
// - `leg(level, from: i, at: t, to: j, wait: w)` departs at t₀ = t + w along the corridor between i and j and arrives at
//   t₁ = t₀ + travel. It is refused (`r02-g16.action`) for an unknown star, j equal to i, no corridor between them, a
//   wait outside 0 … 8, and stars out of range at t₀.
// - `check` fails a leg, in this order: `departure` (t₀ after the close of i's window), `hazard` (the lowest hazard on
//   the leg's corridor whose closed interval meets [t₀, t₁]), `arrival` (t₁ outside j's window), `deadline` (t₁ after
//   the level's deadline) and `stroke` (the corridor is not one of the symbol's strokes).
// - The truth metric: strokes drawn, missing and stray, their sum (the glyph mismatch) and the hazard clearance (over
//   every flown leg and every hazard on its corridor, the fewest beats between the two closed intervals; nil when no
//   hazard shares a flown corridor). It never decides by itself.
import Foundation

/// A lattice position of the star chart.
public struct StarlitCartoucheVector: Sendable, Hashable, Codable, Comparable {
    /// The x coordinate.
    public let x: Int
    /// The y coordinate.
    public let y: Int
    /// The z coordinate.
    public let z: Int

    /// A position of the given coordinates.
    public init(_ x: Int, _ y: Int, _ z: Int) {
        self.x = x
        self.y = y
        self.z = z
    }

    /// The squared distance to `other`.
    public func squaredDistance(to other: StarlitCartoucheVector) -> Int {
        let dx: Int = x - other.x
        let dy: Int = y - other.y
        let dz: Int = z - other.z
        return dx * dx + dy * dy + dz * dz
    }

    /// Lexicographic order by x, y, z.
    public static func < (a: StarlitCartoucheVector, b: StarlitCartoucheVector) -> Bool {
        (a.x, a.y, a.z) < (b.x, b.y, b.z)
    }
}

/// A cell of the 5 × 5 cartouche grid: a star's glyph point.
public struct StarlitCartoucheGlyphPoint: Sendable, Hashable, Codable {
    /// The column, 0 … 4.
    public let x: Int
    /// The row, 0 … 4.
    public let y: Int

    /// A glyph point of the given cell.
    public init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }
}

/// A star: its orbit, its glyph point and its time window.
public struct StarlitCartoucheStar: Sendable, Hashable, Codable {
    /// The lattice positions it cycles through, one per beat.
    public let orbit: [StarlitCartoucheVector]
    /// Its point on the cartouche grid.
    public let glyph: StarlitCartoucheGlyphPoint
    /// The first beat the ship may arrive.
    public let open: Int
    /// The last beat the ship may arrive or depart.
    public let close: Int

    /// A star of the given values (checked by the level).
    public init(orbit: [StarlitCartoucheVector], glyph: StarlitCartoucheGlyphPoint, open: Int, close: Int) {
        self.orbit = orbit
        self.glyph = glyph
        self.open = open
        self.close = close
    }

    /// The position at beat `beat` (≥ 0): `orbit[beat mod length]`.
    public func position(at beat: Int) -> StarlitCartoucheVector {
        let length: Int = orbit.count
        return orbit[((beat % length) + length) % length]
    }

    /// Whether `beat` is inside the window.
    public func admits(_ beat: Int) -> Bool { beat >= open && beat <= close }
}

/// A corridor between two stars (undirected; stored with a < b) and its travel time in beats.
public struct StarlitCartoucheCorridor: Sendable, Hashable, Codable {
    /// The lower star index.
    public let a: Int
    /// The higher star index.
    public let b: Int
    /// The beats a leg takes, 1 … 3.
    public let travel: Int

    /// A corridor between `a` and `b` (stored with the lower index first).
    public init(_ a: Int, _ b: Int, travel: Int) {
        self.a = min(a, b)
        self.b = max(a, b)
        self.travel = travel
    }

    /// Whether it joins stars `i` and `j` (either way).
    public func joins(_ i: Int, _ j: Int) -> Bool { (a == i && b == j) || (a == j && b == i) }
}

/// A hazard tube: a corridor blocked during the closed beat interval [from, to].
public struct StarlitCartoucheHazard: Sendable, Hashable, Codable {
    /// The corridor index.
    public let corridor: Int
    /// The first blocked beat.
    public let from: Int
    /// The last blocked beat.
    public let to: Int

    /// A hazard of the given values (checked by the level).
    public init(corridor: Int, from: Int, to: Int) {
        self.corridor = corridor
        self.from = from
        self.to = to
    }
}

/// One flown leg: from, to, the corridor, the wait, the departure and arrival beats.
public struct StarlitCartoucheLeg: Sendable, Hashable, Codable {
    /// The star left.
    public let from: Int
    /// The star reached.
    public let to: Int
    /// The corridor index.
    public let corridor: Int
    /// The beats waited before departure, 0 … 8.
    public let wait: Int
    /// The departure beat t₀.
    public let depart: Int
    /// The arrival beat t₁.
    public let arrive: Int
}

/// Why a leg or the play failed (clarifications Q3, Q5).
public enum StarlitCartoucheFailure: Sendable, Hashable, Codable {
    /// The ship left `star` at `beat`, after its window closed at `close`.
    case departure(star: Int, beat: Int, close: Int)
    /// The leg met hazard `hazard` (blocking [from, to]) on corridor `corridor`.
    case hazard(corridor: Int, hazard: Int, from: Int, to: Int)
    /// The ship reached `star` at `beat`, outside its window [open, close].
    case arrival(star: Int, beat: Int, open: Int, close: Int)
    /// The ship arrived at `beat`, after the level's deadline.
    case deadline(beat: Int, deadline: Int)
    /// The leg drew corridor `corridor`, which is not a stroke of the symbol.
    case stroke(corridor: Int)
    /// The budget was spent without a win; the payload is the action count.
    case budget(Int)

    /// The stable failure code.
    public var code: String {
        switch self {
        case .departure, .arrival: "window"
        case .hazard: "hazard"
        case .deadline: "deadline"
        case .stroke: "stroke"
        case .budget: "budget"
        }
    }
}

/// The truth metric after an action (clarification Q4). It never decides by itself.
public struct StarlitCartoucheRouteReport: Sendable, Equatable {
    /// The ship's star.
    public let star: Int
    /// The current beat.
    public let beat: Int
    /// The corridors drawn, sorted.
    public let drawn: [Int]
    /// The symbol's strokes not yet drawn, sorted.
    public let missing: [Int]
    /// The corridors drawn outside the symbol, sorted.
    public let stray: [Int]
    /// missing + stray.
    public let mismatch: Int
    /// The fewest beats between a flown leg and a hazard on its corridor; nil when none shares a flown corridor.
    public let clearance: Int?
    /// Whether the drawn set equals the symbol and the ship is at the beacon.
    public let matched: Bool
}

/// The exact rules of the star chart (see the file header).
public enum StarlitCartoucheChart {
    /// The waits a leg may take.
    public static let waits: ClosedRange<Int> = 0...8

    /// The index of the corridor joining `i` and `j`, if any.
    public static func corridor(_ level: StarlitCartoucheLevel, joining i: Int, _ j: Int) -> Int? {
        for index in level.corridors.indices where level.corridors[index].joins(i, j) { return index }
        return nil
    }

    /// Whether the corridor `index` is flyable at `beat`.
    public static func flyable(_ level: StarlitCartoucheLevel, corridor index: Int, at beat: Int) -> Bool {
        let corridor: StarlitCartoucheCorridor = level.corridors[index]
        let pa: StarlitCartoucheVector = level.stars[corridor.a].position(at: beat)
        let pb: StarlitCartoucheVector = level.stars[corridor.b].position(at: beat)
        return pa.squaredDistance(to: pb) <= level.range * level.range
    }

    /// The leg from `star` at `beat` to `destination` after `wait` beats.
    ///
    /// - Throws: `.action(name)` for an unknown star, the same star, no corridor, a wait out of range or stars out of
    ///   range at the departure beat.
    public static func leg(_ level: StarlitCartoucheLevel, from star: Int, at beat: Int, to destination: Int,
                           wait: Int) throws(StarlitCartoucheError) -> StarlitCartoucheLeg {
        guard destination >= 0, destination < level.stars.count else { throw .action("unknown star") }
        guard destination != star else { throw .action("same star") }
        guard let index = corridor(level, joining: star, destination) else { throw .action("no corridor") }
        guard waits.contains(wait) else { throw .action("wait") }
        let depart: Int = beat + wait
        guard flyable(level, corridor: index, at: depart) else {
            let corridor: StarlitCartoucheCorridor = level.corridors[index]
            let distance: Int = level.stars[corridor.a].position(at: depart)
                .squaredDistance(to: level.stars[corridor.b].position(at: depart))
            throw .action("out of range: \(distance) > \(level.range * level.range)")
        }
        return StarlitCartoucheLeg(from: star, to: destination, corridor: index, wait: wait, depart: depart,
                                   arrive: depart + level.corridors[index].travel)
    }

    /// The failure of `leg`, or nil when it is clear (order: departure, hazard, arrival, deadline, stroke).
    public static func check(_ level: StarlitCartoucheLevel, leg: StarlitCartoucheLeg) -> StarlitCartoucheFailure? {
        let origin: StarlitCartoucheStar = level.stars[leg.from]
        if leg.depart > origin.close {
            return .departure(star: leg.from, beat: leg.depart, close: origin.close)
        }
        for index in level.hazards.indices {
            let hazard: StarlitCartoucheHazard = level.hazards[index]
            if hazard.corridor == leg.corridor, hazard.from <= leg.arrive, leg.depart <= hazard.to {
                return .hazard(corridor: leg.corridor, hazard: index, from: hazard.from, to: hazard.to)
            }
        }
        let target: StarlitCartoucheStar = level.stars[leg.to]
        if !target.admits(leg.arrive) {
            return .arrival(star: leg.to, beat: leg.arrive, open: target.open, close: target.close)
        }
        if leg.arrive > level.deadline { return .deadline(beat: leg.arrive, deadline: level.deadline) }
        if !level.symbol.contains(leg.corridor) { return .stroke(corridor: leg.corridor) }
        return nil
    }

    /// The beats between the closed intervals [a0, a1] and [b0, b1] (0 when they meet).
    static func gap(_ a0: Int, _ a1: Int, _ b0: Int, _ b1: Int) -> Int {
        if a1 < b0 { return b0 - a1 }
        if b1 < a0 { return a0 - b1 }
        return 0
    }

    /// The hazard clearance of `legs`: the fewest beats between a leg and a hazard on its corridor, nil when none.
    public static func clearance(_ level: StarlitCartoucheLevel, legs: [StarlitCartoucheLeg]) -> Int? {
        var best: Int? = nil
        for leg in legs {
            for hazard in level.hazards where hazard.corridor == leg.corridor {
                let g: Int = gap(leg.depart, leg.arrive, hazard.from, hazard.to)
                if let current = best { best = min(current, g) } else { best = g }
            }
        }
        return best
    }

    /// The truth metric of a route.
    public static func report(_ level: StarlitCartoucheLevel, star: Int, beat: Int, drawn: Set<Int>,
                              legs: [StarlitCartoucheLeg]) -> StarlitCartoucheRouteReport {
        let symbol: Set<Int> = Set(level.symbol)
        let missing: [Int] = symbol.subtracting(drawn).sorted()
        let stray: [Int] = drawn.subtracting(symbol).sorted()
        return StarlitCartoucheRouteReport(star: star, beat: beat, drawn: drawn.sorted(), missing: missing,
                                           stray: stray, mismatch: missing.count + stray.count,
                                           clearance: clearance(level, legs: legs),
                                           matched: missing.isEmpty && stray.isEmpty && star == level.beacon)
    }
}

/// A player action of the kernel: fly a leg to a star after a wait (clarification Q2).
public enum StarlitCartoucheAction: Sendable, Hashable, Codable {
    /// `leg(star, wait)`: wait `wait` beats (0 … 8), then fly the corridor to `star`.
    case leg(Int, Int)
}
