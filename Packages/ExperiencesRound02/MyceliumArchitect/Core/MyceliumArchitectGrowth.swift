// MyceliumArchitectGrowth — feature 511 (R02-G22-01) T-R02G2201-002 (FR-R02G2201-003 … 006, 015; clarifications
// Q1 … Q3; research R2 … R9). The exact lattice, nutrient field, tip scoring, growth and judge of Mycelium Architect.
// Every value is a whole number: the field f(c) = Σ s · max(0, R − Chebyshev distance) over unconsumed nutrients;
// a tip's score (f(t) − f(c)) − κ·turn − ο·obstacles; ties to the smaller turn, then the lower direction number;
// orthogonal segments weigh 2 and diagonal ones 3. The report holds ordered arrays only, never dictionaries, so its
// iteration order is fixed on every device.

/// A cell of the board, named (column, row) from (0, 0) at the top left; ordered by (row, column).
public struct MyceliumArchitectCell: Sendable, Hashable, Codable, Comparable {
    /// The column, 0 … width − 1.
    public let column: Int
    /// The row, 0 … height − 1, increasing downward.
    public let row: Int

    /// The cell at `column`, `row`.
    public init(column: Int, row: Int) {
        self.column = column
        self.row = row
    }

    /// Orders cells by row, then column.
    public static func < (a: MyceliumArchitectCell, b: MyceliumArchitectCell) -> Bool {
        (a.row, a.column) < (b.row, b.column)
    }

    /// The neighbouring cell one step in `direction` (it may lie off the board).
    public func moved(_ direction: MyceliumArchitectDirection) -> MyceliumArchitectCell {
        let o = direction.offset
        return MyceliumArchitectCell(column: column + o.column, row: row + o.row)
    }

    /// The Chebyshev distance to `other`: the larger of the column and row differences.
    public func distance(to other: MyceliumArchitectCell) -> Int {
        max(abs(column - other.column), abs(row - other.row))
    }

    /// The cell in words, "(9, 4)".
    public var words: String { "(\(column), \(row))" }
}

/// One of the eight growth directions, numbered clockwise from north.
public enum MyceliumArchitectDirection: Int, Sendable, Codable, CaseIterable, Comparable {
    case north, northEast, east, southEast, south, southWest, west, northWest

    /// The column and row change of one step.
    public var offset: (column: Int, row: Int) {
        switch self {
        case .north: (0, -1)
        case .northEast: (1, -1)
        case .east: (1, 0)
        case .southEast: (1, 1)
        case .south: (0, 1)
        case .southWest: (-1, 1)
        case .west: (-1, 0)
        case .northWest: (-1, -1)
        }
    }

    /// Whether a step in this direction is diagonal (weight 3) rather than orthogonal (weight 2).
    public var isDiagonal: Bool { rawValue % 2 == 1 }

    /// The turn to `other` in 45° steps, 0 … 4: min(|k − h|, 8 − |k − h|).
    public func turn(to other: MyceliumArchitectDirection) -> Int {
        let d = abs(other.rawValue - rawValue)
        return min(d, 8 - d)
    }

    /// The direction a quarter turn clockwise, (k + 2) mod 8: the heading of a tip born at a nutrient.
    public var quarterClockwise: MyceliumArchitectDirection {
        MyceliumArchitectDirection(rawValue: (rawValue + 2) % 8)!
    }

    /// The compass name, "north-east".
    public var words: String {
        switch self {
        case .north: "north"
        case .northEast: "north-east"
        case .east: "east"
        case .southEast: "south-east"
        case .south: "south"
        case .southWest: "south-west"
        case .west: "west"
        case .northWest: "north-west"
        }
    }

    /// Orders directions by number.
    public static func < (a: MyceliumArchitectDirection, b: MyceliumArchitectDirection) -> Bool {
        a.rawValue < b.rawValue
    }
}

/// What the player places and seeds: nutrients and blockers on empty cells and directions seeded at the root.
public struct MyceliumArchitectArrangement: Sendable, Hashable, Codable {
    /// The placed nutrients, in ascending (row, column).
    public let nutrients: [MyceliumArchitectCell]
    /// The placed blockers, in ascending (row, column).
    public let blockers: [MyceliumArchitectCell]
    /// The seeded directions at the root, starting seeds included, in ascending number.
    public let seeds: [MyceliumArchitectDirection]

    /// An arrangement of these items, sorted.
    public init(nutrients: [MyceliumArchitectCell], blockers: [MyceliumArchitectCell],
                seeds: [MyceliumArchitectDirection]) {
        self.nutrients = nutrients.sorted()
        self.blockers = blockers.sorted()
        self.seeds = seeds.sorted()
    }
}

/// Why a run failed.
public enum MyceliumArchitectFailure: Sendable, Hashable, Codable {
    /// A tip (0-based) grew into a toxic cell at a pulse.
    case toxic(pulse: Int, tip: Int, cell: MyceliumArchitectCell)
    /// A tip's step would have taken the branch weight to `weight`, above the nutrient budget; nothing was grown.
    case starved(pulse: Int, tip: Int, cell: MyceliumArchitectCell, weight: Int, budget: Int)
    /// A terminal (0-based) was not reached once growth ended.
    case unreached(terminal: Int)
    /// Every terminal was reached but the branch weight is above the limit.
    case overweight(weight: Int, limit: Int)

    /// The failure code: toxic, starved, unreached or overweight.
    public var code: String {
        switch self {
        case .toxic: "toxic"
        case .starved: "starved"
        case .unreached: "unreached"
        case .overweight: "overweight"
        }
    }
}

/// One grown segment: a tip's step during a pulse.
public struct MyceliumArchitectStep: Sendable, Hashable {
    /// The pulse, 1 … P.
    public let pulse: Int
    /// The tip, 0-based.
    public let tip: Int
    /// The cell the tip left.
    public let from: MyceliumArchitectCell
    /// The direction of the step.
    public let direction: MyceliumArchitectDirection
    /// The cell grown.
    public let to: MyceliumArchitectCell
    /// The winning score.
    public let score: Int
    /// The segment weight, 2 or 3.
    public let weight: Int
    /// Whether the step consumed a nutrient.
    public let consumed: Bool
    /// The tip born on the consumed nutrient (0-based), or nil.
    public let newTip: Int?

    /// A step of these values.
    public init(pulse: Int, tip: Int, from: MyceliumArchitectCell, direction: MyceliumArchitectDirection,
                to: MyceliumArchitectCell, score: Int, weight: Int, consumed: Bool, newTip: Int?) {
        self.pulse = pulse
        self.tip = tip
        self.from = from
        self.direction = direction
        self.to = to
        self.score = score
        self.weight = weight
        self.consumed = consumed
        self.newTip = newTip
    }
}

/// The growth report of an arrangement: the field, every step, the grown network, the truth metric and the outcome.
public struct MyceliumArchitectReport: Sendable, Hashable {
    /// The nutrient field before growth, [row][column].
    public let field: [[Int]]
    /// Every grown step, in order.
    public let steps: [MyceliumArchitectStep]
    /// The grown cells in growth order, the root first.
    public let grown: [MyceliumArchitectCell]
    /// The pulse each grown cell was grown, aligned with ``grown`` (root: 0).
    public let grownPulses: [Int]
    /// Each grown cell's parent as an index into ``grown``, aligned with it (root: nil).
    public let parents: [Int?]
    /// The total branch weight.
    public let totalWeight: Int
    /// The pulses in which at least one tip was growing.
    public let pulsesRun: Int
    /// Each terminal's reach pulse, or nil when not reached.
    public let terminalPulses: [Int?]
    /// Each terminal's path weight from the root, or nil when not reached.
    public let terminalPathWeights: [Int?]
    /// The first failure, or nil when the run wins.
    public let failure: MyceliumArchitectFailure?

    /// A report of these values.
    public init(field: [[Int]], steps: [MyceliumArchitectStep], grown: [MyceliumArchitectCell], grownPulses: [Int],
                parents: [Int?], totalWeight: Int, pulsesRun: Int, terminalPulses: [Int?],
                terminalPathWeights: [Int?], failure: MyceliumArchitectFailure?) {
        self.field = field
        self.steps = steps
        self.grown = grown
        self.grownPulses = grownPulses
        self.parents = parents
        self.totalWeight = totalWeight
        self.pulsesRun = pulsesRun
        self.terminalPulses = terminalPulses
        self.terminalPathWeights = terminalPathWeights
        self.failure = failure
    }

    /// The node count, the root included (at most ``MyceliumArchitectGrowth/nodeCap``).
    public var nodeCount: Int { grown.count }

    /// The number of terminals reached.
    public var terminalsReached: Int { terminalPulses.filter { $0 != nil }.count }

    /// Whether the run wins.
    public var wins: Bool { failure == nil }
}

/// The lattice, field, growth and judge of Mycelium Architect.
public enum MyceliumArchitectGrowth {
    /// The weight of an orthogonal segment.
    public static let orthogonalWeight = 2
    /// The weight of a diagonal segment.
    public static let diagonalWeight = 3
    /// The node cap of the network: 1 + 4094 / 2.
    public static let nodeCap = 2048

    /// The segment weight of a step in `direction`.
    public static func weight(_ direction: MyceliumArchitectDirection) -> Int {
        direction.isDiagonal ? diagonalWeight : orthogonalWeight
    }

    /// The nutrient field of the level with these unconsumed nutrients (fixed and placed), [row][column].
    public static func field(_ level: MyceliumArchitectLevel, nutrients: [MyceliumArchitectCell]) -> [[Int]] {
        (0..<level.height).map { row in
            (0..<level.width).map { column in
                value(at: MyceliumArchitectCell(column: column, row: row), nutrients: nutrients,
                      strength: level.strength, reach: level.reach)
            }
        }
    }

    /// The nutrient value of one cell: Σ s · max(0, R − d(c, n)).
    static func value(at cell: MyceliumArchitectCell, nutrients: [MyceliumArchitectCell], strength: Int,
                      reach: Int) -> Int {
        var total = 0
        for n in nutrients {
            total += strength * max(0, reach - cell.distance(to: n))
        }
        return total
    }

    /// The growth report of `arrangement` on `level`: the run's steps, network, truth metric and judge (before each
    /// step `starved`, after it `toxic`; after growth `unreached`, then `overweight`; otherwise won).
    public static func report(_ level: MyceliumArchitectLevel,
                              arrangement: MyceliumArchitectArrangement) -> MyceliumArchitectReport {
        let width = level.width
        let height = level.height
        func index(_ c: MyceliumArchitectCell) -> Int { c.row * width + c.column }
        func onBoard(_ c: MyceliumArchitectCell) -> Bool {
            c.column >= 0 && c.column < width && c.row >= 0 && c.row < height
        }
        var obstacle = [Bool](repeating: false, count: width * height)
        for c in level.rocks { obstacle[index(c)] = true }
        for c in arrangement.blockers where onBoard(c) { obstacle[index(c)] = true }
        var toxic = [Bool](repeating: false, count: width * height)
        for c in level.toxins { toxic[index(c)] = true }
        var terminalOf = [Int](repeating: -1, count: width * height)
        for (i, c) in level.terminals.enumerated() { terminalOf[index(c)] = i }
        var nutrients = (level.fixedNutrients + arrangement.nutrients).sorted()
        let startField = field(level, nutrients: nutrients)

        func blocked(_ c: MyceliumArchitectCell) -> Bool { !onBoard(c) || obstacle[index(c)] }
        func obstacles(around c: MyceliumArchitectCell) -> Int {
            var count = 0
            for d in MyceliumArchitectDirection.allCases where blocked(c.moved(d)) { count += 1 }
            return count
        }

        var grownIndex = [Int](repeating: -1, count: width * height)
        var grown = [level.root]
        var grownPulses = [0]
        var parents: [Int?] = [nil]
        var pathWeights = [0]
        grownIndex[index(level.root)] = 0
        var tips: [(cell: MyceliumArchitectCell, heading: MyceliumArchitectDirection, growing: Bool)] =
            arrangement.seeds.map { (level.root, $0, true) }
        var steps: [MyceliumArchitectStep] = []
        var total = 0
        var pulsesRun = 0
        var terminalPulses = [Int?](repeating: nil, count: level.terminals.count)
        var terminalWeights = [Int?](repeating: nil, count: level.terminals.count)
        var failure: MyceliumArchitectFailure?

        func finish() -> MyceliumArchitectReport {
            if failure == nil, let missing = terminalPulses.firstIndex(where: { $0 == nil }) {
                failure = .unreached(terminal: missing)
            }
            if failure == nil, total > level.weightLimit {
                failure = .overweight(weight: total, limit: level.weightLimit)
            }
            return MyceliumArchitectReport(field: startField, steps: steps, grown: grown, grownPulses: grownPulses,
                                           parents: parents, totalWeight: total, pulsesRun: pulsesRun,
                                           terminalPulses: terminalPulses, terminalPathWeights: terminalWeights,
                                           failure: failure)
        }

        pulses: for pulse in 1...level.pulses {
            guard tips.contains(where: { $0.growing }) else { break }
            pulsesRun = pulse
            let count = tips.count
            for t in 0..<count where tips[t].growing {
                let from = tips[t].cell
                let heading = tips[t].heading
                let here = value(at: from, nutrients: nutrients, strength: level.strength, reach: level.reach)
                var best: (direction: MyceliumArchitectDirection, score: Int, turn: Int)?
                for d in MyceliumArchitectDirection.allCases {
                    let to = from.moved(d)
                    guard !blocked(to), grownIndex[index(to)] < 0 else { continue }
                    if d.isDiagonal {
                        let o = d.offset
                        let side1 = MyceliumArchitectCell(column: from.column + o.column, row: from.row)
                        let side2 = MyceliumArchitectCell(column: from.column, row: from.row + o.row)
                        if blocked(side1) && blocked(side2) { continue }
                    }
                    let turn = heading.turn(to: d)
                    let gain = value(at: to, nutrients: nutrients, strength: level.strength, reach: level.reach) - here
                    let score = gain - level.curvature * turn - level.obstacle * obstacles(around: to)
                    if let b = best {
                        if score > b.score || (score == b.score && turn < b.turn) {
                            best = (d, score, turn)
                        }
                    } else {
                        best = (d, score, turn)
                    }
                }
                guard let choice = best, choice.score >= 0 else {
                    tips[t].growing = false
                    continue
                }
                let to = from.moved(choice.direction)
                let w = weight(choice.direction)
                if total + w > level.nutrientBudget {
                    failure = .starved(pulse: pulse, tip: t, cell: to, weight: total + w, budget: level.nutrientBudget)
                    break pulses
                }
                total += w
                let parent = grownIndex[index(from)]
                grownIndex[index(to)] = grown.count
                grown.append(to)
                grownPulses.append(pulse)
                parents.append(parent)
                pathWeights.append(pathWeights[parent] + w)
                tips[t].cell = to
                tips[t].heading = choice.direction
                var newTip: Int?
                var consumed = false
                if let n = nutrients.firstIndex(of: to) {
                    nutrients.remove(at: n)
                    consumed = true
                    newTip = tips.count
                    tips.append((to, choice.direction.quarterClockwise, true))
                }
                steps.append(MyceliumArchitectStep(pulse: pulse, tip: t, from: from, direction: choice.direction,
                                                   to: to, score: choice.score, weight: w, consumed: consumed,
                                                   newTip: newTip))
                let term = terminalOf[index(to)]
                if term >= 0 {
                    terminalPulses[term] = pulse
                    terminalWeights[term] = pathWeights[pathWeights.count - 1]
                }
                if toxic[index(to)] {
                    failure = .toxic(pulse: pulse, tip: t, cell: to)
                    break pulses
                }
            }
        }
        return finish()
    }
}

/// A player action on a Mycelium Architect level.
public enum MyceliumArchitectAction: Sendable, Hashable, Codable {
    /// Place a nutrient on an empty cell; spends one action ("place nutrient").
    case nutrient(MyceliumArchitectCell)
    /// Place a blocker on an empty cell; spends one action ("block toxin").
    case blocker(MyceliumArchitectCell)
    /// Clear a placed nutrient or blocker; spends one action ("undo edits").
    case clear(MyceliumArchitectCell)
    /// Seed a direction at the root; spends one action ("seed filament").
    case seed(MyceliumArchitectDirection)
    /// Remove a seed the player added; spends one action.
    case unseed(MyceliumArchitectDirection)
    /// Advance the growth pulses ("commit graph"); spends nothing and ends the level.
    case run
}
