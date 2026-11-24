// MoonlitMechanismMechanics — feature 431 (R02-G14-01) T-R02G1401-002 (FR-R02G1401-002, 003, 005, 014;
// SC-R02G1401-003, 004; clarifications Q2, Q3, Q4). The exact mechanics of Moonlit Mechanism's clockwork, in whole
// teeth and whole wall cells:
//   - a gear's direction is +1 when its distance from the driver (gear 0) in the train is even and −1 when odd; a handle
//     turn of t moves every gear to (phase + direction · t) mod T;
//   - a meshing pair (parent p, child c) with g = gcd(Tₚ, T_c) is aligned when (phaseₚ + phase_c) mod g equals the
//     child's alignment value a; its angular relation error is the cyclic distance between the two (0 … ⌊g / 2⌋). A
//     turn never changes it (the two gears move by +t and −t);
//   - the blade at pattern bit b of a gear at phase q sits at slot (b + q) mod T; a solid blade covers the gear's slot
//     offsets for that slot, measured from the gear's centre; at lamp height h every cell of the gear moves down by
//     h · depth rows (the light matrix: an integer shift growing with depth); cells outside the W × H wall are dropped;
//     cells are numbered row by row (row · W + column);
//   - a run checks the meshing pairs in child order and is `jammed` by the first misaligned one; it then walks the key
//     frames in order (the phases of the set-up turned by each key frame's turns): a shadow on a forbidden cell fails
//     `forbidden` (the lowest-numbered such cell); at a required key frame an uncovered target cell fails `missing` (the
//     count) and more stray cells than the allowance fail `stray` (the count); otherwise the run is won. The report
//     always lists every pair's error and every key frame's cast and counts (the truth metric), whatever decides.
// Nothing here reads a clock or a random source, and nothing uses floating point.

/// A wall cell or a slot offset: a column and a row (for an offset, from the gear's centre).
public struct MoonlitMechanismCell: Sendable, Hashable, Codable {
    /// The column (or column offset).
    public let column: Int
    /// The row (or row offset), rows counted downward.
    public let row: Int

    /// A cell or offset.
    public init(column: Int, row: Int) {
        self.column = column
        self.row = row
    }

    /// Decodes `[column, row]`.
    public init(from decoder: any Decoder) throws {
        var c = try decoder.unkeyedContainer()
        column = try c.decode(Int.self)
        row = try c.decode(Int.self)
    }

    /// Encodes `[column, row]`.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(column)
        try c.encode(row)
    }
}

/// A gear: a tooth count, a starting phase (whole teeth), a blade pattern (one bit per slot: solid or open), a depth
/// (how far the lamp's height moves its shadow), its centre on the wall at lamp height 0, its parent in the train (nil
/// for the driver), the alignment value of its mesh with the parent, and its slot table (per slot, the offsets a solid
/// blade at that slot covers).
public struct MoonlitMechanismGear: Sendable, Hashable, Codable {
    /// The tooth count, 6 … 20.
    public let teeth: Int
    /// The starting phase, 0 … teeth − 1.
    public let phase: Int
    /// The blade pattern: `blades[b]` is true when the blade at bit b is solid.
    public let blades: [Bool]
    /// The depth, 1 … 3.
    public let depth: Int
    /// The centre on the wall at lamp height 0.
    public let centre: MoonlitMechanismCell
    /// The parent in the train (a lower index), or nil for the driver.
    public let parent: Int?
    /// The alignment value of the mesh with the parent, 0 … gcd − 1 (0 for the driver).
    public let alignment: Int
    /// The slot table: `slots[k]` lists the offsets a solid blade at slot k covers.
    public let slots: [[MoonlitMechanismCell]]

    /// A gear; the level checks the ranges.
    public init(teeth: Int, phase: Int, blades: [Bool], depth: Int, centre: MoonlitMechanismCell, parent: Int?,
                alignment: Int, slots: [[MoonlitMechanismCell]]) {
        self.teeth = teeth
        self.phase = phase
        self.blades = blades
        self.depth = depth
        self.centre = centre
        self.parent = parent
        self.alignment = alignment
        self.slots = slots
    }
}

/// A key frame: the handle turns from the set-up, the target cells (cell numbers, sorted) and whether it is judged.
public struct MoonlitMechanismKeyFrame: Sendable, Hashable, Codable {
    /// The handle turns from the set-up, ≥ 0.
    public let turns: Int
    /// The target cells, sorted cell numbers.
    public let target: [Int]
    /// Whether the key frame's target must be matched.
    public let required: Bool

    /// A key frame; the level checks it.
    public init(turns: Int, target: [Int], required: Bool) {
        self.turns = turns
        self.target = target
        self.required = required
    }
}

/// The exact mechanics of a gear train.
public enum MoonlitMechanismTrain {
    /// The greatest common divisor of two positive numbers.
    public static func gcd(_ a: Int, _ b: Int) -> Int {
        var x: Int = a
        var y: Int = b
        while y != 0 { (x, y) = (y, x % y) }
        return x
    }

    /// `value` modulo `modulus`, in 0 ..< modulus.
    public static func mod(_ value: Int, _ modulus: Int) -> Int {
        let r: Int = value % modulus
        return r < 0 ? r + modulus : r
    }

    /// The distance of gear `index` from the driver in the train (0 for the driver).
    public static func distance(_ gears: [MoonlitMechanismGear], _ index: Int) -> Int {
        var steps: Int = 0
        var current: Int = index
        while let parent = gears[current].parent {
            steps += 1
            current = parent
        }
        return steps
    }

    /// The direction of gear `index`: +1 at an even distance from the driver, −1 at an odd one.
    public static func direction(_ gears: [MoonlitMechanismGear], _ index: Int) -> Int {
        distance(gears, index) % 2 == 0 ? 1 : -1
    }

    /// The phases after `turns` handle turns (negative turns turn back).
    public static func turned(_ gears: [MoonlitMechanismGear], phases: [Int], by turns: Int) -> [Int] {
        var result: [Int] = phases
        for index in gears.indices {
            result[index] = mod(phases[index] + direction(gears, index) * turns, gears[index].teeth)
        }
        return result
    }

    /// The angular relation error of the mesh of gear `child` with its parent: the cyclic distance between
    /// (phaseₚ + phase_c) mod g and the alignment value; 0 for the driver.
    public static func alignmentError(_ gears: [MoonlitMechanismGear], phases: [Int], child: Int) -> Int {
        guard let parent = gears[child].parent else { return 0 }
        let g: Int = gcd(gears[parent].teeth, gears[child].teeth)
        let d: Int = mod(phases[parent] + phases[child] - gears[child].alignment, g)
        return min(d, g - d)
    }

    /// The cells (sorted, distinct cell numbers row by row) the gears cast at `phases` with the lamp at `height` on a
    /// wall of `width` × `rows` cells.
    public static func cast(_ gears: [MoonlitMechanismGear], phases: [Int], height: Int, width: Int,
                            rows: Int) -> [Int] {
        var covered: [Bool] = Array(repeating: false, count: width * rows)
        for (index, gear) in gears.enumerated() {
            let shift: Int = height * gear.depth
            for bit in 0..<gear.teeth where gear.blades[bit] {
                let slot: Int = mod(bit + phases[index], gear.teeth)
                for offset in gear.slots[slot] {
                    let column: Int = gear.centre.column + offset.column
                    let row: Int = gear.centre.row + offset.row + shift
                    guard column >= 0, column < width, row >= 0, row < rows else { continue }
                    covered[row * width + column] = true
                }
            }
        }
        var cells: [Int] = []
        for (cell, on) in covered.enumerated() where on { cells.append(cell) }
        return cells
    }
}

/// How a run ends.
public enum MoonlitMechanismOutcome: Sendable, Hashable {
    /// Every pair aligned, every required key frame matched, no forbidden cell shadowed.
    case won
    /// The mesh of gear `child` with its parent is out of alignment.
    case jammed(child: Int)
    /// Key frame `frame` shadows forbidden cell `cell` (the lowest-numbered one).
    case forbidden(frame: Int, cell: Int)
    /// Required key frame `frame` leaves `count` target cells uncovered.
    case missing(frame: Int, count: Int)
    /// Required key frame `frame` casts `count` cells outside its target, more than the allowance.
    case stray(frame: Int, count: Int)
}

/// One key frame of a run: the phases, the cast cells and the overlap counts with the target and the forbidden cells.
public struct MoonlitMechanismFrameReport: Sendable, Equatable {
    /// The phases at the key frame.
    public let phases: [Int]
    /// The cast cells, sorted.
    public let cast: [Int]
    /// Target cells covered.
    public let covered: Int
    /// Target cells uncovered.
    public let missing: Int
    /// Cast cells outside the target.
    public let stray: Int
    /// Forbidden cells shadowed, sorted.
    public let forbidden: [Int]

    /// A frame report.
    public init(phases: [Int], cast: [Int], covered: Int, missing: Int, stray: Int, forbidden: [Int]) {
        self.phases = phases
        self.cast = cast
        self.covered = covered
        self.missing = missing
        self.stray = stray
        self.forbidden = forbidden
    }
}

/// The truth metric and the outcome of a run of a set-up: every pair's alignment error (index = child gear; 0 for the
/// driver), every key frame's report and the outcome the run gives.
public struct MoonlitMechanismRunReport: Sendable, Equatable {
    /// The alignment error of every gear's mesh with its parent (0 for the driver).
    public let errors: [Int]
    /// The key frames' reports, in order.
    public let frames: [MoonlitMechanismFrameReport]
    /// The outcome.
    public let outcome: MoonlitMechanismOutcome

    /// A run report.
    public init(errors: [Int], frames: [MoonlitMechanismFrameReport], outcome: MoonlitMechanismOutcome) {
        self.errors = errors
        self.frames = frames
        self.outcome = outcome
    }

    /// Whether every pair is aligned.
    public var aligned: Bool { errors.allSatisfy { $0 == 0 } }
}

extension MoonlitMechanismTrain {
    /// The run of the set-up `phases` with the lamp at `height` against `frames`, `forbidden` and `allowance` on a
    /// `width` × `rows` wall (see the file header for the order of decisions).
    public static func run(_ gears: [MoonlitMechanismGear], phases: [Int], height: Int, width: Int, rows: Int,
                           frames: [MoonlitMechanismKeyFrame], forbidden: [Int],
                           allowance: Int) -> MoonlitMechanismRunReport {
        var errors: [Int] = []
        for index in gears.indices { errors.append(alignmentError(gears, phases: phases, child: index)) }
        let forbiddenSet: Set<Int> = Set(forbidden)
        var reports: [MoonlitMechanismFrameReport] = []
        for frame in frames {
            let at: [Int] = turned(gears, phases: phases, by: frame.turns)
            let cells: [Int] = cast(gears, phases: at, height: height, width: width, rows: rows)
            let cellSet: Set<Int> = Set(cells)
            let targetSet: Set<Int> = Set(frame.target)
            var covered: Int = 0
            for cell in frame.target where cellSet.contains(cell) { covered += 1 }
            var stray: Int = 0
            for cell in cells where !targetSet.contains(cell) { stray += 1 }
            var hits: [Int] = []
            for cell in cells where forbiddenSet.contains(cell) { hits.append(cell) }
            reports.append(MoonlitMechanismFrameReport(phases: at, cast: cells, covered: covered,
                                                       missing: frame.target.count - covered, stray: stray,
                                                       forbidden: hits))
        }
        var outcome: MoonlitMechanismOutcome = .won
        if let child = errors.indices.first(where: { errors[$0] != 0 }) {
            outcome = .jammed(child: child)
        } else {
            for (index, report) in reports.enumerated() {
                if let cell = report.forbidden.first {
                    outcome = .forbidden(frame: index, cell: cell)
                    break
                }
                guard frames[index].required else { continue }
                if report.missing > 0 {
                    outcome = .missing(frame: index, count: report.missing)
                    break
                }
                if report.stray > allowance {
                    outcome = .stray(frame: index, count: report.stray)
                    break
                }
            }
        }
        return MoonlitMechanismRunReport(errors: errors, frames: reports, outcome: outcome)
    }
}

/// A player action: turn the handle by ±1 tooth, re-seat a gear (never the driver) by ±1 tooth, step the lamp by ±1
/// height, or run the machine through its key frames. Each spends one action.
public enum MoonlitMechanismAction: Sendable, Hashable, Codable {
    /// Turn the handle by `step` (±1) teeth: every gear moves in its direction.
    case turn(Int)
    /// Re-seat gear `gear` by `step` (±1) teeth.
    case reseat(Int, Int)
    /// Step the lamp by `step` (±1) heights.
    case lamp(Int)
    /// Run the machine: decides the level.
    case run
}
