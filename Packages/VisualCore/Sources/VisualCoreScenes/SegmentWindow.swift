// SegmentWindow — feature 055 (A07-P02) T-A07-202 (FR-A07-201; gap G-SEGMENTSTREAM).

/// The work one ``SegmentWindow/advance(to:pieceLength:)`` call asks the caller to do.
///
/// Apply ``toRetire`` first (free the resources of those piece indices), then ``toBuild``.
public struct SegmentWindowStep: Sendable, Equatable {
    /// Piece indices that entered the window and should be built now, nearest to the current piece first.
    /// At most ``SegmentWindow/maxBuildsPerStep`` entries.
    public let toBuild: [Int]
    /// Piece indices that left the window and should be released now, in ascending order.
    public let toRetire: [Int]

    /// Creates a step from the indices to build and to retire.
    public init(toBuild: [Int], toRetire: [Int]) {
        self.toBuild = toBuild
        self.toRetire = toRetire
    }
}

/// A streaming window of piece indices along a one-dimensional path (for example tunnel segments).
///
/// The window keeps the pieces from `current - behind` (clamped at 0) through `current + ahead` alive, where
/// `current = floor(distance / pieceLength)`. It is pure index bookkeeping: it never holds meshes or GPU resources,
/// it never lists more than `behind + ahead + 1` live indices and it spreads building over frames by returning at
/// most ``maxBuildsPerStep`` new indices per call.
public struct SegmentWindow: Sendable, Equatable {
    /// The most piece indices a single ``advance(to:pieceLength:)`` call asks to build.
    public static let maxBuildsPerStep = 2

    /// Pieces kept behind the current piece.
    public let behind: Int
    /// Pieces kept ahead of the current piece.
    public let ahead: Int
    /// The resource budget the caller reserved; at least `behind + ahead + 1`.
    public let capacity: Int

    /// The live piece indices (built and not retired), sorted ascending.
    public private(set) var live: [Int] = []

    /// The current piece index of the last valid ``advance(to:pieceLength:)`` call, or `nil` before the first.
    public private(set) var current: Int?

    /// Creates an empty window.
    ///
    /// Returns `nil` when `behind`, `ahead` or `capacity` is negative or `capacity < behind + ahead + 1`.
    public init?(behind: Int, ahead: Int, capacity: Int) {
        guard behind >= 0, ahead >= 0, capacity >= 0 else { return nil }
        let (span, overflow) = behind.addingReportingOverflow(ahead)
        guard !overflow, span < Int.max, capacity >= span + 1 else { return nil }
        self.behind = behind
        self.ahead = ahead
        self.capacity = capacity
    }

    /// The piece indices the window wants alive for the current piece (empty before the first valid advance).
    public var desired: ClosedRange<Int>? {
        guard let current else { return nil }
        let low = current >= behind ? current - behind : 0
        let (high, overflow) = current.addingReportingOverflow(ahead)
        return low...(overflow ? Int.max : high)
    }

    /// Whether every desired piece index is live.
    public var isComplete: Bool {
        guard let desired else { return false }
        return live.count == desired.count && live.first == desired.lowerBound && live.last == desired.upperBound
    }

    /// Moves the window to `distance` along the path and returns the indices to retire and to build.
    ///
    /// Every live index outside the new window is retired in the same call; then up to ``maxBuildsPerStep`` missing
    /// indices are built, nearest to the current piece first (on a tie, the one ahead before the one behind).
    /// ``live`` is updated as if the caller applied the step. A non-finite `distance`, or a `pieceLength` that is not
    /// a finite positive number, returns an empty step and changes nothing. Negative distances clamp to piece 0.
    public mutating func advance(to distance: Double, pieceLength: Double) -> SegmentWindowStep {
        guard distance.isFinite, pieceLength.isFinite, pieceLength > 0 else {
            return SegmentWindowStep(toBuild: [], toRetire: [])
        }
        let raw = (distance / pieceLength).rounded(.down)
        let index: Int
        if raw.isNaN || raw <= 0 {
            index = 0
        } else if raw >= Double(Int.max / 2) {
            index = Int.max / 2
        } else {
            index = Int(raw)
        }
        current = index
        guard let window = desired else { return SegmentWindowStep(toBuild: [], toRetire: []) }

        let toRetire = live.filter { !window.contains($0) }
        let kept = live.filter { window.contains($0) }
        let keptSet = Set(kept)

        var toBuild: [Int] = []
        var offset = 0
        let maxOffset = max(ahead, behind)
        while toBuild.count < Self.maxBuildsPerStep, offset <= maxOffset {
            for candidate in offset == 0 ? [index] : [index + offset, index - offset] {
                guard toBuild.count < Self.maxBuildsPerStep else { break }
                if candidate >= 0, window.contains(candidate), !keptSet.contains(candidate) {
                    toBuild.append(candidate)
                }
            }
            offset += 1
        }
        live = (kept + toBuild).sorted()
        return SegmentWindowStep(toBuild: toBuild, toRetire: toRetire)
    }
}
