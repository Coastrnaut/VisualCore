// StreamingBudget — feature 058 (A07-P05) T-A07-502 (FR-A07-501; gap G-JOURNEYBUDGET).

/// One quality level of a streamed journey: how many pieces stay alive around the current piece, how far the
/// scene is drawn and what share of optional elements (for example stars) is shown.
public struct StreamingLevel: Sendable, Equatable {
    /// Pieces kept behind the current piece (≥ 0).
    public let behind: Int
    /// Pieces kept ahead of the current piece (≥ 1).
    public let ahead: Int
    /// Distance at which the scene ends, for example the fog end (> 0 and ≤ `ahead × pieceLength`).
    public let drawDistance: Double
    /// Share of optional elements drawn at this level (0…1).
    public let elementShare: Double

    /// Creates a level from its window, draw distance and element share; ``StreamingBudget`` validates it.
    public init(behind: Int, ahead: Int, drawDistance: Double, elementShare: Double) {
        self.behind = behind
        self.ahead = ahead
        self.drawDistance = drawDistance
        self.elementShare = elementShare
    }
}

/// An ordered list of streaming quality levels, level 0 the richest, each later level no larger in any value.
///
/// Pure arithmetic: it holds no meshes or GPU resources. A caller maps the host's quality level to a
/// ``StreamingLevel`` with ``level(_:)`` and checks the live mesh total against a ``MeshBudget`` with
/// ``fits(level:perPieceVertices:budget:)``.
public struct StreamingBudget: Sendable, Equatable {
    /// The most levels a budget accepts.
    public static let maxLevels = 8

    /// The levels, index 0 the richest.
    public let levels: [StreamingLevel]
    /// Length of one streamed piece along the path (> 0).
    public let pieceLength: Double

    /// Creates a budget.
    ///
    /// Returns `nil` when `levels` is empty or holds more than ``maxLevels`` entries, when `pieceLength` is not
    /// finite and positive, when a level has `behind < 0`, `ahead < 1`, a draw distance that is not finite, not
    /// positive or beyond `ahead × pieceLength`, or an element share outside 0…1, or when any of `behind`,
    /// `ahead`, `drawDistance` or `elementShare` rises from one level to the next.
    public init?(levels: [StreamingLevel], pieceLength: Double) {
        guard !levels.isEmpty, levels.count <= Self.maxLevels else { return nil }
        guard pieceLength.isFinite, pieceLength > 0 else { return nil }
        for level in levels {
            guard level.behind >= 0, level.ahead >= 1 else { return nil }
            guard level.drawDistance.isFinite, level.drawDistance > 0,
                  level.drawDistance <= Double(level.ahead) * pieceLength else { return nil }
            guard level.elementShare.isFinite, (0...1).contains(level.elementShare) else { return nil }
        }
        for (a, b) in zip(levels, levels.dropFirst()) {
            guard b.behind <= a.behind, b.ahead <= a.ahead, b.drawDistance <= a.drawDistance,
                  b.elementShare <= a.elementShare else { return nil }
        }
        self.levels = levels
        self.pieceLength = pieceLength
    }

    /// The level at `index`, clamped to `0…levels.count - 1`.
    public func level(_ index: Int) -> StreamingLevel {
        levels[min(max(index, 0), levels.count - 1)]
    }

    /// Vertices alive at `level` (clamped) when each piece holds `perPieceVertices` vertices:
    /// `(behind + ahead + 1) × perPieceVertices`. A negative vertex count counts as 0; an overflow saturates at
    /// `Int.max`.
    public func vertexTotal(level: Int, perPieceVertices: Int) -> Int {
        let l = self.level(level)
        let pieces = l.behind + l.ahead + 1
        let (total, overflow) = pieces.multipliedReportingOverflow(by: max(perPieceVertices, 0))
        return overflow ? Int.max : total
    }

    /// Whether the vertices alive at `level` (clamped) stay within `budget.maxVertices`.
    public func fits(level: Int, perPieceVertices: Int, budget: MeshBudget) -> Bool {
        vertexTotal(level: level, perPieceVertices: perPieceVertices) <= budget.maxVertices
    }
}
