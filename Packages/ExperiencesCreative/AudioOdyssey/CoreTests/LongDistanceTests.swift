// LongDistanceTests — feature 058 (A07-P05) T-A07-503 (FR-A07-502, FR-A07-510; SC-A07-501, SC-A07-502; clarification 2).
// At distance 10^9 (piece index 1.25 × 10^8) the pieces of every world still join: the last ring (row) of piece i
// equals the first of piece i + 1 within 1e-6 (tunnel, landscape), and the stars of the two pieces lie in their own
// distance ranges, those of piece i before those of piece i + 1 (star corridor). Audio Odyssey's quality budget is a
// valid `StreamingBudget` (draw distances 64/48/32 = ahead × 8, fog start 0.4 × that), its levels are non-increasing, the star counts are 48/29/17 and every level's window of the
// real pieces fits the mesh budget justified below.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
import AudioOdysseyCore

@Suite struct LongDistanceTests {
    private let seed: UInt64 = 7
    /// The piece that starts at distance 10^9: 10^9 / 8.
    private let farIndex = 125_000_000

    @Test func theFarIndexStartsAtOneBillion() {
        #expect(Double(farIndex) * WorldPieces.pieceLength == 1e9)
        #expect(WorldPieces.pieceIndex(of: 1e9) == farIndex)
    }

    @Test func tunnelAndLandscapePiecesJoinAtOneBillion() throws {
        let rail = JourneyRail.make(seed: seed)
        for world in [JourneyWorld.tunnel, .landscape] {
            let ranges = try #require(WorldPieces.edgeVertexRanges(world))
            let a = WorldPieces.piece(world, index: farIndex, rail: rail, seed: seed)
            let b = WorldPieces.piece(world, index: farIndex + 1, rail: rail, seed: seed)
            let end = Array(a.positions[ranges.end]), start = Array(b.positions[ranges.start])
            #expect(end.count == start.count && !end.isEmpty)
            var worst = 0.0
            for (p, q) in zip(end, start) {
                #expect(p.x.isFinite && p.y.isFinite && p.z.isFinite)
                worst = max(worst, (p - q).length)
            }
            #expect(worst <= 1e-6, "\(world) join gap \(worst)")
        }
    }

    @Test func starCorridorPiecesJoinAtOneBillion() {
        let rail = JourneyRail.make(seed: seed)
        let length = WorldPieces.pieceLength
        let a = WorldPieces.starDistances(index: farIndex, seed: seed)
        let b = WorldPieces.starDistances(index: farIndex + 1, seed: seed)
        #expect(a.count == WorldPieces.starsPerPiece && b.count == WorldPieces.starsPerPiece)
        let lowerA = Double(farIndex) * length, lowerB = Double(farIndex + 1) * length
        #expect(a.allSatisfy { $0 >= lowerA && $0 < lowerB })
        #expect(b.allSatisfy { $0 >= lowerB && $0 < lowerB + length })
        #expect((a.max() ?? .infinity) < (b.min() ?? -.infinity))
        for index in [farIndex, farIndex + 1] {
            let mesh = WorldPieces.piece(.starCorridor, index: index, rail: rail, seed: seed)
            #expect(!mesh.positions.isEmpty)
            #expect(mesh.positions.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
        }
    }

    @Test func theQualityBudgetIsValidAndMatchesResearchD2() {
        #expect(StreamingBudget(levels: OdysseyQuality.levels, pieceLength: WorldPieces.pieceLength) != nil)
        let budget = OdysseyQuality.budget
        #expect(budget.pieceLength == WorldPieces.pieceLength)
        #expect(budget.levels.map(\.ahead) == [8, 6, 4])
        #expect(budget.levels.map(\.behind) == [2, 2, 1])
        #expect(budget.levels.map(\.drawDistance) == [64, 48, 32])
        for level in budget.levels {
            #expect(level.drawDistance == Double(level.ahead) * WorldPieces.pieceLength)
        }
        let fogStarts: [Double] = (0..<3).map { OdysseyQuality.fogStart(level: $0) }
        let expectedFogStarts: [Double] = [64, 48, 32].map { 0.4 * $0 }
        #expect(fogStarts == expectedFogStarts)
        #expect(OdysseyQuality.fogStart(level: 7) == OdysseyQuality.fogStart(level: 2))
        #expect(budget.levels.map(\.elementShare) == [1, 0.6, 0.35])
        #expect(OdysseyQuality.levelNames == ["level-0", "level-1", "level-2"])
        #expect(OdysseyQuality.level(-3) == budget.levels[0] && OdysseyQuality.level(9) == budget.levels[2])
    }

    @Test func levelsAndStarCountsDoNotIncrease() {
        // 48 × 0.6 = 28.8 → 29; 48 × 0.35 = 16.8 → 17.
        #expect((0..<3).map { OdysseyQuality.starCount(level: $0) } == [48, 29, 17])
        let levels = OdysseyQuality.budget.levels
        for (better, cheaper) in zip(levels, levels.dropFirst()) {
            #expect(cheaper.ahead <= better.ahead && cheaper.behind <= better.behind)
            #expect(cheaper.drawDistance <= better.drawDistance && cheaper.elementShare <= better.elementShare)
        }
    }

    /// Each piece is its own mesh within `WorldPieces.vertexBudget` (4,096); the whole window of one level is held to
    /// 16 such pieces' worth, 65,536 vertices (6 indices per vertex at most), which bounds the geometry resident at
    /// once. The per-piece counts are measured from real pieces, at full element share (the upper bound).
    @Test func everyLevelFitsTheMeshBudget() {
        let rail = JourneyRail.make(seed: seed)
        let windowBudget = MeshBudget(maxVertices: 16 * WorldPieces.vertexBudget,
                                      maxIndices: 6 * 16 * WorldPieces.vertexBudget)
        for world in JourneyWorld.allCases {
            let perPiece = WorldPieces.piece(world, index: farIndex, rail: rail, seed: seed).positions.count
            #expect(perPiece > 0 && perPiece <= WorldPieces.vertexBudget, "\(world) \(perPiece)")
            var previous = Int.max
            for level in 0..<OdysseyQuality.budget.levels.count {
                let total = OdysseyQuality.budget.vertexTotal(level: level, perPieceVertices: perPiece)
                let l = OdysseyQuality.level(level)
                #expect(total == (l.behind + l.ahead + 1) * perPiece)
                #expect(total <= previous)
                #expect(OdysseyQuality.budget.fits(level: level, perPieceVertices: perPiece, budget: windowBudget),
                        "\(world) level \(level) total \(total)")
                previous = total
            }
        }
    }
}
