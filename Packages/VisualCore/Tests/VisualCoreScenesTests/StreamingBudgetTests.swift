// StreamingBudgetTests — feature 058 (A07-P05) T-A07-502 (FR-A07-501; gap G-JOURNEYBUDGET).
import Testing
@testable import VisualCoreScenes

/// Audio Odyssey's three levels (spec Clarifications Q1).
///
/// Each draw distance equals the window ahead of the camera (ahead × the A07 piece length of 8), the largest the rule
/// `drawDistance ≤ ahead × pieceLength` allows.
private let odysseyPieceLength = 8.0
private let odysseyLevels = [
    StreamingLevel(behind: 2, ahead: 8, drawDistance: 64, elementShare: 1),
    StreamingLevel(behind: 2, ahead: 6, drawDistance: 48, elementShare: 0.6),
    StreamingLevel(behind: 1, ahead: 4, drawDistance: 32, elementShare: 0.35),
]

private func replacing(_ index: Int, with level: StreamingLevel) -> [StreamingLevel] {
    var levels = odysseyLevels
    levels[index] = level
    return levels
}

@Test func streamingBudgetAcceptsTheOdysseyLevels() throws {
    let budget = try #require(StreamingBudget(levels: odysseyLevels, pieceLength: odysseyPieceLength))
    #expect(budget.levels == odysseyLevels)
    #expect(budget.pieceLength == odysseyPieceLength)
    #expect(StreamingBudget.maxLevels == 8)
    #expect(StreamingBudget(levels: [odysseyLevels[0]], pieceLength: odysseyPieceLength) != nil, "one level is enough")
    #expect(StreamingBudget(levels: Array(repeating: odysseyLevels[2], count: 8), pieceLength: odysseyPieceLength) != nil,
            "equal neighbours are non-increasing")
    #expect(StreamingBudget(levels: odysseyLevels, pieceLength: 7.9) == nil, "64 > 8 × 7.9: draw distance beyond the window")
}

@Test func streamingBudgetRefusesInvalidLists() {
    #expect(StreamingBudget(levels: [], pieceLength: 8) == nil)
    #expect(StreamingBudget(levels: Array(repeating: odysseyLevels[2], count: 9), pieceLength: odysseyPieceLength) == nil)
    #expect(StreamingBudget(levels: odysseyLevels, pieceLength: 0) == nil)
    #expect(StreamingBudget(levels: odysseyLevels, pieceLength: -8) == nil)
    #expect(StreamingBudget(levels: odysseyLevels, pieceLength: .nan) == nil)
    #expect(StreamingBudget(levels: odysseyLevels, pieceLength: .infinity) == nil)
}

@Test func streamingBudgetRefusesInvalidLevels() {
    let bad: [StreamingLevel] = [
        StreamingLevel(behind: -1, ahead: 4, drawDistance: 30, elementShare: 0.3),
        StreamingLevel(behind: 1, ahead: 0, drawDistance: 5, elementShare: 0.3),
        StreamingLevel(behind: 1, ahead: 4, drawDistance: 0, elementShare: 0.3),
        StreamingLevel(behind: 1, ahead: 4, drawDistance: -1, elementShare: 0.3),
        StreamingLevel(behind: 1, ahead: 4, drawDistance: .nan, elementShare: 0.3),
        StreamingLevel(behind: 1, ahead: 4, drawDistance: .infinity, elementShare: 0.3),
        StreamingLevel(behind: 1, ahead: 4, drawDistance: 32.001, elementShare: 0.3),
        StreamingLevel(behind: 1, ahead: 4, drawDistance: 30, elementShare: -0.01),
        StreamingLevel(behind: 1, ahead: 4, drawDistance: 30, elementShare: 1.01),
        StreamingLevel(behind: 1, ahead: 4, drawDistance: 30, elementShare: .nan),
    ]
    for level in bad {
        #expect(StreamingBudget(levels: replacing(2, with: level), pieceLength: odysseyPieceLength) == nil, "\(level)")
    }
    #expect(StreamingBudget(levels: replacing(2, with: StreamingLevel(behind: 1, ahead: 4, drawDistance: 32,
                                                                      elementShare: 0)), pieceLength: odysseyPieceLength) != nil,
            "draw distance exactly ahead × pieceLength and share 0 are allowed")
}

@Test func streamingBudgetRefusesRisingValues() {
    let first = StreamingLevel(behind: 2, ahead: 6, drawDistance: 40, elementShare: 0.5)
    // Each second level raises exactly one value above `first`; every level is valid on its own.
    let rising: [StreamingLevel] = [
        StreamingLevel(behind: 3, ahead: 6, drawDistance: 40, elementShare: 0.5),
        StreamingLevel(behind: 2, ahead: 7, drawDistance: 40, elementShare: 0.5),
        StreamingLevel(behind: 2, ahead: 6, drawDistance: 41, elementShare: 0.5),
        StreamingLevel(behind: 2, ahead: 6, drawDistance: 40, elementShare: 0.51),
    ]
    #expect(StreamingBudget(levels: [first, first], pieceLength: 8) != nil)
    for second in rising {
        #expect(StreamingBudget(levels: [second], pieceLength: 8) != nil, "valid alone: \(second)")
        #expect(StreamingBudget(levels: [first, second], pieceLength: 8) == nil, "\(second)")
        #expect(StreamingBudget(levels: [second, first], pieceLength: 8) != nil, "falling is fine: \(second)")
    }
    // Level 2 rising above level 1 in the Odyssey list.
    #expect(StreamingBudget(levels: replacing(2, with: StreamingLevel(behind: 3, ahead: 4, drawDistance: 50,
                                                                      elementShare: 0.35)), pieceLength: odysseyPieceLength) == nil)
}

@Test func streamingBudgetClampsTheLevelIndex() throws {
    let budget = try #require(StreamingBudget(levels: odysseyLevels, pieceLength: odysseyPieceLength))
    #expect(budget.level(-5) == odysseyLevels[0])
    #expect(budget.level(0) == odysseyLevels[0])
    #expect(budget.level(1) == odysseyLevels[1])
    #expect(budget.level(2) == odysseyLevels[2])
    #expect(budget.level(3) == odysseyLevels[2])
    #expect(budget.level(.max) == odysseyLevels[2])
    #expect(budget.level(.min) == odysseyLevels[0])
}

@Test func streamingBudgetVertexTotalIsWindowTimesPiece() throws {
    let budget = try #require(StreamingBudget(levels: odysseyLevels, pieceLength: odysseyPieceLength))
    #expect(budget.vertexTotal(level: 0, perPieceVertices: 1_000) == 11_000)
    #expect(budget.vertexTotal(level: 1, perPieceVertices: 1_000) == 9_000)
    #expect(budget.vertexTotal(level: 2, perPieceVertices: 1_000) == 6_000)
    #expect(budget.vertexTotal(level: 9, perPieceVertices: 1_000) == 6_000, "clamped")
    #expect(budget.vertexTotal(level: 0, perPieceVertices: 0) == 0)
    #expect(budget.vertexTotal(level: 0, perPieceVertices: -7) == 0, "never negative")
    #expect(budget.vertexTotal(level: 0, perPieceVertices: .max) == .max, "saturates")
}

@Test func streamingBudgetFitsAroundTheMeshBudgetLimit() throws {
    let budget = try #require(StreamingBudget(levels: odysseyLevels, pieceLength: odysseyPieceLength))
    let limit = MeshBudget(maxVertices: 11_000, maxIndices: 1_000_000)
    #expect(budget.fits(level: 0, perPieceVertices: 1_000, budget: limit), "exactly at the limit")
    #expect(!budget.fits(level: 0, perPieceVertices: 1_001, budget: limit))
    #expect(budget.fits(level: 2, perPieceVertices: 1_833, budget: limit), "6 × 1,833 = 10,998")
    #expect(!budget.fits(level: 2, perPieceVertices: 1_834, budget: limit), "6 × 1,834 = 11,004")
    #expect(budget.fits(level: 1, perPieceVertices: 1_222, budget: limit))
    #expect(!budget.fits(level: 1, perPieceVertices: 1_223, budget: limit))
}
