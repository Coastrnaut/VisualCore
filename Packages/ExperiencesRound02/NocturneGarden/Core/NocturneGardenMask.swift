// NocturneGardenMask — feature 381 (R02-G09-01) T-R02G0901-002 (FR-R02G0901-003, 005, 013, 014; clarifications Q2,
// Q4). The garden's shadow mask: the union of the blooms' cells clipped to the bed; the match |M ∩ T| / |M ∪ T|
// compared with the required fraction p / q by cross multiplication (an empty union never matches); the leak |M ∩ F|;
// and the boundary deviation, the truth metric: the symmetric Hausdorff distance in Chebyshev cells between the
// boundary cells of two sets. Exact integer arithmetic only.

/// A required match: the fraction numerator / denominator with 0 < numerator ≤ denominator ≤ 1 000, kept reduced.
public struct NocturneGardenRatio: Sendable, Hashable, Codable {
    /// The largest denominator; it keeps every cross product (at most 768 cells) far inside `Int`.
    public static let maxDenominator: Int = 1_000
    /// The whole: 1/1.
    public static let whole: NocturneGardenRatio = NocturneGardenRatio(reduced: 1, 1)

    /// The numerator p.
    public let numerator: Int
    /// The denominator q.
    public let denominator: Int

    /// The reduced fraction `numerator` / `denominator`.
    ///
    /// - Throws: `.level("match")` unless 0 < numerator ≤ denominator ≤ ``maxDenominator``.
    public init(_ numerator: Int, _ denominator: Int) throws(NocturneGardenError) {
        guard numerator > 0, numerator <= denominator, denominator <= Self.maxDenominator else {
            throw .level("match")
        }
        var a: Int = numerator
        var b: Int = denominator
        while b != 0 { (a, b) = (b, a % b) }
        self.init(reduced: numerator / a, denominator / a)
    }

    /// A fraction already checked and reduced.
    private init(reduced numerator: Int, _ denominator: Int) {
        self.numerator = numerator
        self.denominator = denominator
    }

    /// The fraction as text: "p/q" (FR-R02G0901-013).
    public var text: String { "\(numerator)/\(denominator)" }

    /// The stored keys.
    private enum Keys: String, CodingKey { case numerator, denominator }

    /// Decodes and re-checks a ratio; a value out of range is a data error.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let p: Int = try c.decode(Int.self, forKey: .numerator)
        let q: Int = try c.decode(Int.self, forKey: .denominator)
        do {
            try self.init(p, q)
        } catch {
            throw DecodingError.dataCorruptedError(forKey: .numerator, in: c, debugDescription: error.reasonCode)
        }
    }

    /// Encodes `{"denominator": q, "numerator": p}`.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(numerator, forKey: .numerator)
        try c.encode(denominator, forKey: .denominator)
    }
}

/// The set of dark cells in the bed (row-major indices row · width + column).
public struct NocturneGardenMask: Sendable, Hashable {
    /// The bed's width in cells.
    public let width: Int
    /// The bed's height in cells.
    public let height: Int
    /// The dark cells, every one inside the bed.
    public let cells: Set<Int>

    /// A mask of `cells` clipped to the bed.
    public init(width: Int, height: Int, cells: Set<Int>) {
        self.width = width
        self.height = height
        let count: Int = max(0, width) * max(0, height)
        self.cells = cells.filter { $0 >= 0 && $0 < count }
    }

    /// The union of the blooms' shadows under sun `elevation`, clipped to the bed (FR-R02G0901-003).
    public static func union(_ blooms: [NocturneGardenBloom], elevation: Int, width: Int,
                             height: Int) -> NocturneGardenMask {
        var cells: Set<Int> = []
        for bloom in blooms {
            cells.formUnion(bloom.cells(elevation: elevation, width: width, height: height))
        }
        return NocturneGardenMask(width: width, height: height, cells: cells)
    }

    /// |M ∩ other|: the cells dark here and in `other`.
    public func intersection(_ other: Set<Int>) -> Int {
        var count: Int = 0
        for cell in cells where other.contains(cell) { count += 1 }
        return count
    }

    /// |M ∪ other|: the cells dark here or in `other`.
    public func union(_ other: Set<Int>) -> Int {
        cells.count + other.count - intersection(other)
    }

    /// The leak |M ∩ F|: the dark cells among the `forbidden` cells.
    public func leak(forbidden: Set<Int>) -> Int {
        intersection(forbidden)
    }

    /// Whether |M ∩ T| / |M ∪ T| ≥ p / q, decided as |M ∩ T|·q ≥ p·|M ∪ T|; an empty union never matches.
    public static func matches(mask: NocturneGardenMask, target: Set<Int>, required: NocturneGardenRatio) -> Bool {
        let shared: Int = mask.intersection(target)
        let either: Int = mask.union(target)
        guard either > 0 else { return false }
        return shared * required.denominator >= required.numerator * either
    }

    /// The boundary cells of `set` in a bed of `width` × `height`: the cells of the set (inside the bed) with a
    /// 4-neighbour outside the set or on the bed's edge.
    public static func boundary(_ set: Set<Int>, width: Int, height: Int) -> Set<Int> {
        var result: Set<Int> = []
        let count: Int = max(0, width) * max(0, height)
        for cell in set where cell >= 0 && cell < count {
            let column: Int = cell % width
            let row: Int = cell / width
            let edge: Bool = column == 0 || row == 0 || column == width - 1 || row == height - 1
            if edge || !set.contains(cell - 1) || !set.contains(cell + 1) || !set.contains(cell - width)
                || !set.contains(cell + width) {
                result.insert(cell)
            }
        }
        return result
    }

    /// The boundary deviation (the truth metric, FR-R02G0901-014): the symmetric Hausdorff distance, in Chebyshev
    /// cells, between the boundary cells of `a` and of `b`. Two empty sets deviate by 0; when exactly one is empty the
    /// deviation is the stated maximum `width + height` (larger than any distance inside the bed). Cells outside the
    /// bed are ignored.
    public static func boundaryDeviation(_ a: Set<Int>, _ b: Set<Int>, width: Int, height: Int) -> Int {
        let first: [Int] = boundary(a, width: width, height: height).sorted()
        let second: [Int] = boundary(b, width: width, height: height).sorted()
        if first.isEmpty && second.isEmpty { return 0 }
        if first.isEmpty || second.isEmpty { return width + height }
        return max(directed(first, second, width: width), directed(second, first, width: width))
    }

    /// The directed Hausdorff distance: the largest, over cells of `from`, of the Chebyshev distance to the nearest
    /// cell of `to` (both non-empty).
    static func directed(_ from: [Int], _ to: [Int], width: Int) -> Int {
        var worst: Int = 0
        for p in from {
            var nearest: Int = Int.max
            for q in to {
                let d: Int = max(abs(p % width - q % width), abs(p / width - q / width))
                if d < nearest { nearest = d }
                if nearest <= worst { break }
            }
            worst = max(worst, nearest)
        }
        return worst
    }
}
