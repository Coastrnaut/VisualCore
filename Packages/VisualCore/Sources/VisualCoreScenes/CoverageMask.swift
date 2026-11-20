// CoverageMask — feature 213 (R02-F13) T-R02F13-003 (FR-R02F13-003, FR-R02F13-004, FR-R02F13-007, FR-R02F13-008;
// research R4, R6; clarifications Q3, Q4). A bit mask over a rectangle [min, max] of the plane basis with width × height
// cells. A cell is covered when its centre lies inside a polygon (even–odd per polygon, union across polygons),
// computed row by row from the polygon's edge crossings at the row centre with the half-open rule (an edge counts when
// min(a.y, b.y) ≤ y < max(a.y, b.y)) and spans [x0, x1) in x, so a cell centre on an edge shared by two polygons is set
// by exactly one of them. Bits are packed row-major in UInt64 words, bit `x % 64` of word `y × wordsPerRow + x / 64`
// (least significant bit first), with padding bits zero. The digest is FNV-1a 64 over the words in little-endian byte
// order. `MaskComparison` gives exact intersection over union; `CoverageMaskDocument` is the stored form, JSON schema 1.
import Foundation
import VisualCoreMath

/// A packed cell-centre coverage mask over a rectangle of the plane basis (see the file header).
public struct CoverageMask: Sendable, Equatable {
    /// The largest accepted width or height, in cells.
    public static let maxSide = 2_048
    /// The lower corner of the covered rectangle.
    public let min: Vec2
    /// The upper corner of the covered rectangle (greater than `min` on both axes).
    public let max: Vec2
    /// The number of cells per row (1…`maxSide`).
    public let width: Int
    /// The number of rows (1…`maxSide`).
    public let height: Int
    /// The packed cells, row-major, `wordsPerRow` words per row, bit `x % 64` of word `y × wordsPerRow + x / 64`;
    /// padding bits beyond `width` in the last word of each row are always zero.
    public private(set) var words: [UInt64]

    /// An empty mask of `width` × `height` cells over [min, max]; throws `.maskSize` for a side outside 1…`maxSide`,
    /// `.nonFinite("region")` for a non-finite corner and `.malformed("region")` when `min` is not below `max` on both
    /// axes.
    public init(min: Vec2, max: Vec2, width: Int, height: Int) throws(ShadowError) {
        guard (1...Self.maxSide).contains(width), (1...Self.maxSide).contains(height) else {
            throw .maskSize(width: width, height: height)
        }
        guard min.x.isFinite, min.y.isFinite, max.x.isFinite, max.y.isFinite else { throw .nonFinite("region") }
        guard min.x < max.x, min.y < max.y, (max.x - min.x).isFinite, (max.y - min.y).isFinite else {
            throw .malformed("region")
        }
        self.min = min
        self.max = max
        self.width = width
        self.height = height
        words = Array(repeating: 0, count: ((width + 63) / 64) * height)
    }

    /// The number of UInt64 words in one row, `(width + 63) / 64`.
    public var wordsPerRow: Int { (width + 63) / 64 }

    /// The width and height of one cell in plane units.
    var cellSize: Vec2 { Vec2((max.x - min.x) / Double(width), (max.y - min.y) / Double(height)) }

    /// The centre of cell (x, y): `min + (index + 0.5) × cell size` on each axis.
    public func cellCentre(x: Int, y: Int) -> Vec2 {
        Vec2(centreX(x), centreY(y))
    }

    /// Whether cell (x, y) is covered; indices outside the mask read as uncovered.
    public subscript(x: Int, y: Int) -> Bool {
        guard x >= 0, x < width, y >= 0, y < height else { return false }
        return words[y * wordsPerRow + x / 64] >> UInt64(x % 64) & 1 == 1
    }

    /// Sets every cell whose centre lies inside `polygon` (even–odd rule, half-open edges; see the file header).
    /// Parts of the polygon outside the rectangle are clipped. A polygon with fewer than three points or with a
    /// non-finite point is ignored and sets nothing.
    public mutating func fill(_ polygon: [Vec2]) {
        guard polygon.count >= 3, polygon.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return }
        let lowY = polygon.map(\.y).min()!, highY = polygon.map(\.y).max()!
        let perRow = wordsPerRow
        var crossings: [Double] = []
        crossings.reserveCapacity(polygon.count)
        for row in 0..<height {
            let y = centreY(row)
            guard y >= lowY, y < highY else { continue }
            crossings.removeAll(keepingCapacity: true)
            for i in polygon.indices {
                let a = polygon[i], b = polygon[(i + 1) % polygon.count]
                guard Swift.min(a.y, b.y) <= y, y < Swift.max(a.y, b.y) else { continue }
                crossings.append(a.x + (y - a.y) * (b.x - a.x) / (b.y - a.y))
            }
            crossings.sort()
            var pair = 0
            while pair + 1 < crossings.count {
                let first = firstCell(atOrAfter: crossings[pair])
                let end = firstCell(atOrAfter: crossings[pair + 1])
                if first < end {
                    for x in first..<end { words[row * perRow + x / 64] |= 1 << UInt64(x % 64) }
                }
                pair += 2
            }
        }
    }

    /// Fills every polygon of `polygons` (the union of their coverages); invalid polygons are ignored as in `fill(_:)`.
    public mutating func fill(_ polygons: [[Vec2]]) {
        for polygon in polygons { fill(polygon) }
    }

    /// The number of covered cells.
    public var count: Int { words.reduce(0) { $0 + $1.nonzeroBitCount } }

    /// The covered area in plane units: `count` × cell area.
    public var area: Double {
        let cell = cellSize
        return Double(count) * cell.x * cell.y
    }

    /// FNV-1a 64 over the words' little-endian bytes (offset 0xcbf29ce484222325, prime 0x100000001b3).
    public var digest: UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for word in words {
            var w = word
            for _ in 0..<8 {
                hash ^= w & 0xff
                hash = hash &* 0x0000_0100_0000_01b3
                w >>= 8
            }
        }
        return hash
    }

    /// Creates a mask from already packed words; used by the stored form after validation.
    init(validatedMin min: Vec2, max: Vec2, width: Int, height: Int, words: [UInt64]) {
        self.min = min
        self.max = max
        self.width = width
        self.height = height
        self.words = words
    }

    private func centreX(_ x: Int) -> Double { min.x + (Double(x) + 0.5) * (max.x - min.x) / Double(width) }
    private func centreY(_ y: Int) -> Double { min.y + (Double(y) + 0.5) * (max.y - min.y) / Double(height) }

    /// The first column whose centre x is ≥ `bound`, clamped to 0…width (consistent with `cellCentre`).
    private func firstCell(atOrAfter bound: Double) -> Int {
        let estimate = ((bound - min.x) / (max.x - min.x)) * Double(width) - 0.5
        var x = Int(Swift.min(Swift.max(estimate.rounded(.up), 0), Double(width)))
        while x > 0, centreX(x - 1) >= bound { x -= 1 }
        while x < width, centreX(x) < bound { x += 1 }
        return x
    }
}

/// The exact overlap of two masks of the same region and resolution.
public struct MaskComparison: Sendable, Equatable {
    /// The number of cells covered in both masks.
    public let intersection: Int
    /// The number of cells covered in either mask.
    public let union: Int
    /// Intersection over union, `intersection / union`; two empty masks give 1.
    public var iou: Double { union == 0 ? 1 : Double(intersection) / Double(union) }

    /// Compares `a` and `b` cell by cell; throws `.mismatchedMasks` when their regions or sizes differ.
    public init(_ a: CoverageMask, _ b: CoverageMask) throws(ShadowError) {
        guard a.min == b.min, a.max == b.max, a.width == b.width, a.height == b.height else {
            throw .mismatchedMasks
        }
        var both = 0, either = 0
        for i in a.words.indices {
            both += (a.words[i] & b.words[i]).nonzeroBitCount
            either += (a.words[i] | b.words[i]).nonzeroBitCount
        }
        intersection = both
        union = either
    }
}

/// The stored form of a `CoverageMask`: JSON schema 1 with sorted keys,
/// `{"height":…,"max":{"x":…,"y":…},"min":{"x":…,"y":…},"schema":1,"width":…,"words":"<base64>"}`, where `words` is
/// the base64 of the words' little-endian bytes.
public struct CoverageMaskDocument: Sendable, Equatable {
    /// The schema version this build writes and the newest it reads.
    public static let schema = 1
    /// The stored mask.
    public let mask: CoverageMask

    /// Wraps `mask` for storing.
    public init(mask: CoverageMask) { self.mask = mask }

    /// The JSON bytes of the stored form (sorted keys, deterministic).
    public func encoded() throws -> Data {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(mask.words.count * 8)
        for word in mask.words {
            var w = word
            for _ in 0..<8 {
                bytes.append(UInt8(w & 0xff))
                w >>= 8
            }
        }
        let stored = Stored(
            schema: Self.schema, min: mask.min, max: mask.max, width: mask.width, height: mask.height,
            words: Data(bytes).base64EncodedString())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(stored)
    }

    /// Reads a stored form; throws `.newerSchema` for a schema above `schema`, `.malformed` for invalid JSON, a schema
    /// below 1, bad base64, a wrong word count or non-zero padding bits, and the mask's own refusals (`.maskSize`,
    /// `.nonFinite`, `.malformed("region")`) for an invalid region or size.
    public static func decode(_ data: Data) throws(ShadowError) -> CoverageMaskDocument {
        let decoder = JSONDecoder()
        let header: Header
        do { header = try decoder.decode(Header.self, from: data) } catch { throw .malformed("json") }
        guard header.schema <= schema else { throw .newerSchema(header.schema) }
        guard header.schema >= 1 else { throw .malformed("schema") }
        let stored: Stored
        do { stored = try decoder.decode(Stored.self, from: data) } catch { throw .malformed("json") }
        let empty = try CoverageMask(min: stored.min, max: stored.max, width: stored.width, height: stored.height)
        guard let bytes = Data(base64Encoded: stored.words) else { throw .malformed("words") }
        guard bytes.count == empty.words.count * 8 else { throw .malformed("words") }
        var words = [UInt64](repeating: 0, count: empty.words.count)
        let raw = [UInt8](bytes)
        for i in words.indices {
            var w: UInt64 = 0
            for k in 0..<8 { w |= UInt64(raw[i * 8 + k]) << UInt64(8 * k) }
            words[i] = w
        }
        let used = stored.width % 64
        if used != 0 {
            let padding = ~((UInt64(1) << UInt64(used)) - 1)
            let perRow = empty.wordsPerRow
            for row in 0..<stored.height where words[row * perRow + perRow - 1] & padding != 0 {
                throw .malformed("padding")
            }
        }
        return CoverageMaskDocument(
            mask: CoverageMask(
                validatedMin: stored.min, max: stored.max, width: stored.width, height: stored.height, words: words))
    }

    private struct Header: Decodable { let schema: Int }

    private struct Stored: Codable {
        let schema: Int
        let min: Vec2
        let max: Vec2
        let width: Int
        let height: Int
        let words: String
    }
}
