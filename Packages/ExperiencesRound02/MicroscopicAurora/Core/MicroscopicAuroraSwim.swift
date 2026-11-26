// MicroscopicAuroraSwim — feature 481 (R02-G19-01) T-R02G1901-002 (FR-R02G1901-002, 003, 004, 005, 014;
// SC-R02G1901-003, 004; clarifications Q1 … Q4). The exact swim of Microscopic Aurora: a dish of 24 × 24 cells of 256
// dish units with a round enclosure about (3072, 3072), the rim inside; a swarm whose every tick is one synchronous step
// of separation, alignment and cohesion plus the curl of up to three magnetic wells, each division truncating toward
// zero, the acceleration and then the velocity clamped per axis, then p ← p + v (semi-implicit Euler); trail density per
// cell over ticks 1 … T; the stencil's coverage in tenths of a percent rounded down; four-neighbour groups; coherence as
// the largest group of swimmers linked within the coherence radius; and the judge (per tick `exit` then `coherence`;
// after the swim `coverage` then `connectedness`). Integers only; no clock is read.

/// A point in dish units (256 per cell).
public struct MicroscopicAuroraPoint: Sendable, Hashable, Codable {
    /// The horizontal coordinate in dish units.
    public let x: Int
    /// The vertical coordinate in dish units.
    public let y: Int

    /// The point (x, y).
    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

/// One swimmer: an integer position and an integer velocity in dish units per tick.
public struct MicroscopicAuroraSwimmer: Sendable, Hashable, Codable {
    /// The position in dish units.
    public let position: MicroscopicAuroraPoint
    /// The velocity in dish units per tick.
    public let velocity: MicroscopicAuroraPoint

    /// A swimmer at `position` moving by `velocity` per tick.
    public init(position: MicroscopicAuroraPoint, velocity: MicroscopicAuroraPoint) {
        self.position = position
        self.velocity = velocity
    }
}

/// A dish cell by row and column (0 … 23), ordered row-major.
public struct MicroscopicAuroraCell: Sendable, Hashable, Codable, Comparable {
    /// The row, 0 … 23 (from the top of the dish's y axis).
    public let row: Int
    /// The column, 0 … 23.
    public let column: Int

    /// The cell at `row`, `column`.
    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }

    /// The cell's centre in dish units.
    public var centre: MicroscopicAuroraPoint {
        MicroscopicAuroraPoint(x: column * MicroscopicAuroraDish.unit + MicroscopicAuroraDish.unit / 2,
                               y: row * MicroscopicAuroraDish.unit + MicroscopicAuroraDish.unit / 2)
    }

    /// The cell's row-major index, 0 … 575.
    public var index: Int { row * MicroscopicAuroraDish.cells + column }

    /// Row-major order.
    public static func < (a: MicroscopicAuroraCell, b: MicroscopicAuroraCell) -> Bool { a.index < b.index }
}

/// The turning sense of a magnetic well.
public enum MicroscopicAuroraSense: String, Sendable, Codable, CaseIterable {
    /// Swimmers turn clockwise around the well.
    case clockwise
    /// Swimmers turn counterclockwise around the well.
    case counterclockwise

    /// −1 for clockwise, +1 for counterclockwise.
    public var sign: Int { self == .counterclockwise ? 1 : -1 }
}

/// A magnetic well: a cell, a strength 1 … 4 and a turning sense.
public struct MicroscopicAuroraWell: Sendable, Hashable, Codable {
    /// The strengths.
    public static let strengths: ClosedRange<Int> = 1...4

    /// The cell whose centre the well sits on.
    public let cell: MicroscopicAuroraCell
    /// The strength, 1 … 4.
    public let strength: Int
    /// The turning sense.
    public let sense: MicroscopicAuroraSense

    /// A well on `cell` of `strength` turning by `sense`.
    public init(cell: MicroscopicAuroraCell, strength: Int, sense: MicroscopicAuroraSense) {
        self.cell = cell
        self.strength = strength
        self.sense = sense
    }
}

/// The swarm rules of a level: radii in cells, weights, and the per-axis bounds.
public struct MicroscopicAuroraSwarmRules: Sendable, Hashable, Codable {
    /// The neighbour radii in cells.
    public static let neighbourRadii: ClosedRange<Int> = 2...6
    /// The coherence radii in cells.
    public static let coherenceRadii: ClosedRange<Int> = 2...8
    /// The weights of separation, alignment and cohesion.
    public static let weights: ClosedRange<Int> = 0...8
    /// The acceleration bounds per axis.
    public static let accelerations: ClosedRange<Int> = 2...16
    /// The speed bounds per axis.
    public static let speeds: ClosedRange<Int> = 8...48

    /// The neighbour radius ρ in cells (alignment and cohesion), 2 … 6.
    public let neighbourRadius: Int
    /// The separation radius σ in cells, 1 … ρ.
    public let separationRadius: Int
    /// The coherence radius κ in cells, 2 … 8.
    public let coherenceRadius: Int
    /// The separation weight wₛ, 0 … 8.
    public let separationWeight: Int
    /// The alignment weight wₐ, 0 … 8.
    public let alignmentWeight: Int
    /// The cohesion weight w_c, 0 … 8.
    public let cohesionWeight: Int
    /// The acceleration bound a_max per axis, 2 … 16.
    public let maxAcceleration: Int
    /// The speed bound v_max per axis, 8 … 48.
    public let maxSpeed: Int

    /// Swarm rules of the given values (checked by ``MicroscopicAuroraLevel``).
    public init(neighbourRadius: Int, separationRadius: Int, coherenceRadius: Int, separationWeight: Int,
                alignmentWeight: Int, cohesionWeight: Int, maxAcceleration: Int, maxSpeed: Int) {
        self.neighbourRadius = neighbourRadius
        self.separationRadius = separationRadius
        self.coherenceRadius = coherenceRadius
        self.separationWeight = separationWeight
        self.alignmentWeight = alignmentWeight
        self.cohesionWeight = cohesionWeight
        self.maxAcceleration = maxAcceleration
        self.maxSpeed = maxSpeed
    }

    /// The name of the first value outside its range, or nil.
    public var invalidValue: String? {
        guard Self.neighbourRadii.contains(neighbourRadius) else { return "neighbour radius" }
        guard (1...neighbourRadius).contains(separationRadius) else { return "separation radius" }
        guard Self.coherenceRadii.contains(coherenceRadius) else { return "coherence radius" }
        guard Self.weights.contains(separationWeight), Self.weights.contains(alignmentWeight),
              Self.weights.contains(cohesionWeight) else { return "weight" }
        guard Self.accelerations.contains(maxAcceleration) else { return "acceleration" }
        guard Self.speeds.contains(maxSpeed) else { return "speed" }
        return nil
    }
}

/// Why a played swim failed.
public enum MicroscopicAuroraFailure: Sendable, Hashable, Codable {
    /// Swimmer `swimmer` left the enclosure at `tick`.
    case exit(swimmer: Int, tick: Int)
    /// At `tick` the swarm's largest linked group had only `group` swimmers.
    case coherence(tick: Int, group: Int)
    /// Only `lit` stencil cells were lit; `needed` were required.
    case coverage(lit: Int, needed: Int)
    /// The lit stencil cells form more than one group; `cell` is the first not joined to the first one's group.
    case connectedness(cell: MicroscopicAuroraCell)

    /// The failure's code: `exit`, `coherence`, `coverage` or `connectedness`.
    public var code: String {
        switch self {
        case .exit: "exit"
        case .coherence: "coherence"
        case .coverage: "coverage"
        case .connectedness: "connectedness"
        }
    }
}

/// The exact report of one swim: the truth metric (FR-R02G1901-014). It describes; the judge's result is `failure`.
public struct MicroscopicAuroraReport: Sendable, Equatable {
    /// The ticks swum (T when the swim completed, else the failing tick).
    public let ticks: Int
    /// The swarm after the last tick swum.
    public let finalSwimmers: [MicroscopicAuroraSwimmer]
    /// The trail density of every cell, row-major (576 values).
    public let density: [Int]
    /// The lit stencil cells, row-major.
    public let litStencil: [MicroscopicAuroraCell]
    /// The stencil's coverage in tenths of a percent, rounded down.
    public let coverage: Int
    /// The number of four-neighbour groups of the lit stencil cells.
    public let groups: Int
    /// The smallest coherence seen (tick 0 included).
    public let smallestCoherence: Int
    /// The first tick at which the smallest coherence was seen.
    public let smallestCoherenceTick: Int
    /// The judge's failure, or nil when the swim wins.
    public let failure: MicroscopicAuroraFailure?

    /// Whether the swim wins.
    public var wins: Bool { failure == nil }
}

/// The dish and the exact swim.
public enum MicroscopicAuroraDish {
    /// Cells per side.
    public static let cells: Int = 24
    /// Dish units per cell.
    public static let unit: Int = 256
    /// The dish centre on each axis, in dish units.
    public static let centre: Int = 3072
    /// The curl's softening, 256² (one cell).
    public static let softening: Int = 65_536
    /// The curl's scale.
    public static let curlScale: Int = 4096

    /// Whether `point` is inside the enclosure of `radius` cells (the rim is inside).
    public static func isInside(_ point: MicroscopicAuroraPoint, radius: Int) -> Bool {
        let dx: Int = point.x - centre
        let dy: Int = point.y - centre
        let r: Int = radius * unit
        return dx * dx + dy * dy <= r * r
    }

    /// The cell holding `point` (⌊y/256⌋, ⌊x/256⌋); meaningful for points inside the enclosure.
    public static func cell(of point: MicroscopicAuroraPoint) -> MicroscopicAuroraCell {
        MicroscopicAuroraCell(row: floorDivide(point.y, unit), column: floorDivide(point.x, unit))
    }

    /// One synchronous tick: every acceleration from the swarm as it is, then every swimmer moves.
    public static func step(_ swimmers: [MicroscopicAuroraSwimmer], wells: [MicroscopicAuroraWell],
                            rules: MicroscopicAuroraSwarmRules) -> [MicroscopicAuroraSwimmer] {
        let rho: Int = rules.neighbourRadius * unit
        let sigma: Int = rules.separationRadius * unit
        let rho2: Int = rho * rho
        let sigma2: Int = sigma * sigma
        var next: [MicroscopicAuroraSwimmer] = []
        next.reserveCapacity(swimmers.count)
        for i in swimmers.indices {
            let p: MicroscopicAuroraPoint = swimmers[i].position
            let v: MicroscopicAuroraPoint = swimmers[i].velocity
            var sepX: Int = 0, sepY: Int = 0
            var sumVX: Int = 0, sumVY: Int = 0, sumPX: Int = 0, sumPY: Int = 0
            var count: Int = 0
            for j in swimmers.indices where j != i {
                let q: MicroscopicAuroraPoint = swimmers[j].position
                let dx: Int = p.x - q.x
                let dy: Int = p.y - q.y
                let d2: Int = dx * dx + dy * dy
                if d2 <= rho2 {
                    count += 1
                    sumVX += swimmers[j].velocity.x
                    sumVY += swimmers[j].velocity.y
                    sumPX += q.x
                    sumPY += q.y
                }
                if d2 <= sigma2 {
                    if d2 == 0 {
                        sepX += i < j ? 1 : -1
                    } else {
                        sepX += dx
                        sepY += dy
                    }
                }
            }
            var ax: Int = (rules.separationWeight * sepX) / 64
            var ay: Int = (rules.separationWeight * sepY) / 64
            if count > 0 {
                ax += (rules.alignmentWeight * (sumVX / count - v.x)) / 16
                ay += (rules.alignmentWeight * (sumVY / count - v.y)) / 16
                ax += (rules.cohesionWeight * (sumPX / count - p.x)) / 256
                ay += (rules.cohesionWeight * (sumPY / count - p.y)) / 256
            }
            for well in wells {
                let q: MicroscopicAuroraPoint = well.cell.centre
                let dx: Int = p.x - q.x
                let dy: Int = p.y - q.y
                let denominator: Int = dx * dx + dy * dy + softening
                let factor: Int = well.sense.sign * well.strength * curlScale
                ax += (factor * -dy) / denominator
                ay += (factor * dx) / denominator
            }
            ax = clamp(ax, rules.maxAcceleration)
            ay = clamp(ay, rules.maxAcceleration)
            let vx: Int = clamp(v.x + ax, rules.maxSpeed)
            let vy: Int = clamp(v.y + ay, rules.maxSpeed)
            next.append(MicroscopicAuroraSwimmer(position: MicroscopicAuroraPoint(x: p.x + vx, y: p.y + vy),
                                                 velocity: MicroscopicAuroraPoint(x: vx, y: vy)))
        }
        return next
    }

    /// The size of the largest group of swimmers linked within `radius` cells.
    public static func coherence(_ swimmers: [MicroscopicAuroraSwimmer], radius: Int) -> Int {
        let r: Int = radius * unit
        let r2: Int = r * r
        let n: Int = swimmers.count
        var group: [Int] = Array(repeating: -1, count: n)
        var largest: Int = 0
        for start in 0..<n where group[start] < 0 {
            group[start] = start
            var stack: [Int] = [start]
            var size: Int = 0
            while let a = stack.popLast() {
                size += 1
                let pa: MicroscopicAuroraPoint = swimmers[a].position
                for b in 0..<n where group[b] < 0 {
                    let pb: MicroscopicAuroraPoint = swimmers[b].position
                    let dx: Int = pa.x - pb.x
                    let dy: Int = pa.y - pb.y
                    if dx * dx + dy * dy <= r2 {
                        group[b] = start
                        stack.append(b)
                    }
                }
            }
            largest = max(largest, size)
        }
        return largest
    }

    /// The four-neighbour groups of `cells`, each a row-major sorted list, ordered by their first cell.
    public static func groupsOf(_ cells: [MicroscopicAuroraCell]) -> [[MicroscopicAuroraCell]] {
        let members: Set<MicroscopicAuroraCell> = Set(cells)
        var seen: Set<MicroscopicAuroraCell> = []
        var result: [[MicroscopicAuroraCell]] = []
        for start in cells.sorted() where !seen.contains(start) {
            seen.insert(start)
            var stack: [MicroscopicAuroraCell] = [start]
            var group: [MicroscopicAuroraCell] = []
            while let c = stack.popLast() {
                group.append(c)
                let neighbours: [MicroscopicAuroraCell] = [
                    MicroscopicAuroraCell(row: c.row - 1, column: c.column),
                    MicroscopicAuroraCell(row: c.row + 1, column: c.column),
                    MicroscopicAuroraCell(row: c.row, column: c.column - 1),
                    MicroscopicAuroraCell(row: c.row, column: c.column + 1),
                ]
                for n in neighbours where members.contains(n) && !seen.contains(n) {
                    seen.insert(n)
                    stack.append(n)
                }
            }
            result.append(group.sorted())
        }
        return result
    }

    /// The number of four-neighbour groups of `cells`.
    public static func groups(_ cells: [MicroscopicAuroraCell]) -> Int { groupsOf(cells).count }

    /// The fewest lit cells of a stencil of `size` cells whose coverage reaches `required` tenths of a percent.
    public static func neededCells(stencil size: Int, required: Int) -> Int {
        (required * size + 999) / 1000
    }

    /// The swim of `level` with `wells`, judged; with `keepPositions`, the positions of every tick swum (tick 0 first).
    public static func swim(_ level: MicroscopicAuroraLevel, wells: [MicroscopicAuroraWell],
                            keepPositions: Bool) -> (report: MicroscopicAuroraReport,
                                                     positions: [[MicroscopicAuroraPoint]]) {
        var swimmers: [MicroscopicAuroraSwimmer] = level.swimmers
        var positions: [[MicroscopicAuroraPoint]] = []
        if keepPositions { positions.append(swimmers.map(\.position)) }
        var density: [Int] = Array(repeating: 0, count: cells * cells)
        var smallest: Int = coherence(swimmers, radius: level.rules.coherenceRadius)
        var smallestTick: Int = 0
        var failure: MicroscopicAuroraFailure?
        var ticks: Int = 0
        for tick in 1...level.length {
            swimmers = step(swimmers, wells: wells, rules: level.rules)
            ticks = tick
            if keepPositions { positions.append(swimmers.map(\.position)) }
            if let k = swimmers.firstIndex(where: { !isInside($0.position, radius: level.radius) }) {
                failure = .exit(swimmer: k, tick: tick)
                break
            }
            for s in swimmers { density[cell(of: s.position).index] += 1 }
            let c: Int = coherence(swimmers, radius: level.rules.coherenceRadius)
            if c < smallest {
                smallest = c
                smallestTick = tick
            }
            if c < level.coherence {
                failure = .coherence(tick: tick, group: c)
                break
            }
        }
        let lit: [MicroscopicAuroraCell] = level.stencil.sorted().filter { density[$0.index] >= level.threshold }
        let coverage: Int = lit.count * 1000 / level.stencil.count
        let groups: [[MicroscopicAuroraCell]] = groupsOf(lit)
        if failure == nil {
            if coverage < level.coverage {
                failure = .coverage(lit: lit.count, needed: neededCells(stencil: level.stencil.count,
                                                                         required: level.coverage))
            } else if groups.count != 1, let first = groups.first {
                let joined: Set<MicroscopicAuroraCell> = Set(first)
                if let cell = lit.first(where: { !joined.contains($0) }) {
                    failure = .connectedness(cell: cell)
                }
            }
        }
        let report = MicroscopicAuroraReport(ticks: ticks, finalSwimmers: swimmers, density: density,
                                             litStencil: lit, coverage: coverage, groups: groups.count,
                                             smallestCoherence: smallest, smallestCoherenceTick: smallestTick,
                                             failure: failure)
        return (report, positions)
    }

    /// The report of `level` with `wells`.
    public static func report(_ level: MicroscopicAuroraLevel,
                              wells: [MicroscopicAuroraWell]) -> MicroscopicAuroraReport {
        swim(level, wells: wells, keepPositions: false).report
    }

    /// `value` clamped to ±`bound`.
    static func clamp(_ value: Int, _ bound: Int) -> Int { min(max(value, -bound), bound) }

    /// ⌊a / b⌋ for b > 0.
    static func floorDivide(_ a: Int, _ b: Int) -> Int {
        let q: Int = a / b
        return (a % b != 0 && a < 0) ? q - 1 : q
    }
}

/// A player action: place or change a well in a slot, empty a slot, or play the swim.
public enum MicroscopicAuroraAction: Sendable, Hashable, Codable {
    /// Put `well` into slot `slot` (0 … 2), or change the slot's well; spends one action.
    case place(slot: Int, well: MicroscopicAuroraWell)
    /// Empty slot `slot` (0 … 2); spends one action.
    case remove(slot: Int)
    /// Play the swim; spends nothing and ends the level.
    case play
}
