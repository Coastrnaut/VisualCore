// OdysseyQuality — feature 058 (A07-P05) T-A07-503 (FR-A07-502; SC-A07-501; clarification 1; research D2;
// data-model "OdysseyQuality"). Audio Odyssey's three quality levels as a `StreamingBudget`: pieces ahead 8/6/4,
// behind 2/2/1, draw distance (fog end) 64/48/32 units and element share 1/0.6/0.35, which scales the stars per piece
// (`starCount(level:)` = round(48 × share): 48/29/17). Level 0 is the full quality, higher levels are cheaper. The draw
// distance is exactly ahead × 8 units (lead decision of 2026-11-14: research D2's 110/80/50 exceeds the geometry
// ahead and `StreamingBudget` refuses it), so the fog ends where the window's last piece ends; the fog starts at
// 0.4 × the draw distance (40 % as the earlier 40…110 fog).
import Foundation
import VisualCoreScenes

/// The streaming budget of Audio Odyssey's quality levels.
public enum OdysseyQuality {
    /// The three levels, best first (research D2, draw distances = ahead × `WorldPieces.pieceLength`).
    public static let levels: [StreamingLevel] = [
        StreamingLevel(behind: 2, ahead: 8, drawDistance: 64, elementShare: 1),
        StreamingLevel(behind: 2, ahead: 6, drawDistance: 48, elementShare: 0.6),
        StreamingLevel(behind: 1, ahead: 4, drawDistance: 32, elementShare: 0.35),
    ]

    /// The budget over ``levels`` with pieces of `WorldPieces.pieceLength` units. Force-unwrapped because the levels
    /// are valid constants (at least one level, no value rising, every draw distance = ahead × piece length, shares in
    /// 0…1), which `LongDistanceTests` checks; a refused table is a programming error.
    public static let budget: StreamingBudget = StreamingBudget(levels: levels, pieceLength: WorldPieces.pieceLength)!

    /// The quality level names registered in the catalog, best first.
    public static let levelNames = ["level-0", "level-1", "level-2"]

    /// The level `index`, clamped to the budget's levels.
    public static func level(_ index: Int) -> StreamingLevel { budget.level(index) }

    /// The distance at which the fog starts at level `index` (clamped): 0.4 × the draw distance; the fog ends at the
    /// draw distance.
    public static func fogStart(level index: Int) -> Double { 0.4 * level(index).drawDistance }

    /// The stars per piece at level `index` (clamped): round(`WorldPieces.starsPerPiece` × element share).
    public static func starCount(level index: Int) -> Int {
        Int((Double(WorldPieces.starsPerPiece) * level(index).elementShare).rounded())
    }
}
