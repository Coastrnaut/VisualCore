// WorldPiecesTests — feature 054 (A07-P01) T-A07-103 (FR-A07-110, FR-A07-111; SC-A07-104; clarification 4). Pieces
// of the three worlds join watertight (tunnel and landscape: the last ring or row of piece i equals the first of piece
// i + 1 within 1e-9, by the vertex layout documented in WorldPieces.swift; star corridor: every star lies in its own
// piece by distance), stay within the vertex budget, are deterministic and differ by world. The median generation time
// is measured and printed, never asserted (CI runners are slower).
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
import AudioOdysseyCore

@Suite struct WorldPiecesTests {
    private let seeds: [UInt64] = [1, 2, 3, 4, 5]

    @Test func theConstantsMatchTheClarification() {
        #expect(WorldPieces.pieceLength == 8)
        #expect(WorldPieces.vertexBudget == 4_096)
        #expect(WorldPieces.window.behind == 2 && WorldPieces.window.ahead == 8)
        #expect(WorldPieces.indices(around: 0) == 0...8)
        #expect(WorldPieces.indices(around: 41) == 3...13)
        #expect(WorldPieces.indices(around: .nan) == 0...8)
    }

    @Test func tunnelAndLandscapeEdgesJoinExactly() throws {
        for world in [JourneyWorld.tunnel, .landscape] {
            let ranges = try #require(WorldPieces.edgeVertexRanges(world))
            for seed in seeds {
                let rail = JourneyRail.make(seed: seed)
                let pieces = (0...4).map { WorldPieces.piece(world, index: $0, rail: rail, seed: seed) }
                for i in 0..<4 {
                    let end = Array(pieces[i].positions[ranges.end])
                    let start = Array(pieces[i + 1].positions[ranges.start])
                    #expect(end.count == start.count && !end.isEmpty)
                    for (p, q) in zip(end, start) {
                        #expect((p - q).length <= 1e-9, "\(world) seed \(seed) piece \(i)")
                    }
                }
            }
        }
        #expect(WorldPieces.edgeVertexRanges(.starCorridor) == nil)
    }

    @Test func piecesJoinAcrossTheRailWrap() throws {
        let ranges = try #require(WorldPieces.edgeVertexRanges(.tunnel))
        let rail = JourneyRail.make(seed: 3)
        let last = Int(rail.length / WorldPieces.pieceLength)   // the piece that contains the wrap point
        let a = WorldPieces.piece(.tunnel, index: last, rail: rail, seed: 3)
        let b = WorldPieces.piece(.tunnel, index: last + 1, rail: rail, seed: 3)
        for (p, q) in zip(a.positions[ranges.end], b.positions[ranges.start]) {
            #expect((p - q).length <= 1e-9)
        }
    }

    @Test func everyStarBelongsToItsPiece() {
        for seed in seeds {
            for index in 0..<5 {
                let distances = WorldPieces.starDistances(index: index, seed: seed)
                #expect(distances.count == WorldPieces.starsPerPiece)
                let lower = Double(index) * WorldPieces.pieceLength, upper = Double(index + 1) * WorldPieces.pieceLength
                for d in distances {
                    #expect(d >= lower && d < upper, "seed \(seed) piece \(index): \(d)")
                }
            }
        }
    }

    @Test func piecesStayWithinTheBudgetAndAreWellFormed() {
        let rail = JourneyRail.make(seed: 1)
        for world in JourneyWorld.allCases {
            for index in [0, 1, 7] {
                let mesh = WorldPieces.piece(world, index: index, rail: rail, seed: 1)
                #expect(!mesh.positions.isEmpty && mesh.positions.count <= WorldPieces.vertexBudget, "\(world)")
                #expect(mesh.normals.count == mesh.positions.count && mesh.uvs.count == mesh.positions.count)
                #expect(mesh.indices.count % 3 == 0 && !mesh.indices.isEmpty)
                #expect(mesh.indices.allSatisfy { Int($0) < mesh.positions.count })
                #expect(mesh.positions.allSatisfy { $0.isFinite }, "\(world)")
            }
        }
    }

    @Test func piecesAreDeterministicAndDifferByWorld() {
        let rail = JourneyRail.make(seed: 2)
        for world in JourneyWorld.allCases {
            #expect(WorldPieces.piece(world, index: 3, rail: rail, seed: 2)
                == WorldPieces.piece(world, index: 3, rail: rail, seed: 2), "\(world)")
            #expect(WorldPieces.piece(world, index: 3, rail: rail, seed: 2)
                != WorldPieces.piece(world, index: 3, rail: rail, seed: 4), "\(world): seed matters")
        }
        let meshes = JourneyWorld.allCases.map { WorldPieces.piece($0, index: 3, rail: rail, seed: 2) }
        #expect(meshes[0] != meshes[1] && meshes[1] != meshes[2] && meshes[0] != meshes[2])
    }

    @Test func medianGenerationTimeIsMeasured() {
        let rail = JourneyRail.make(seed: 1)
        let clock = ContinuousClock()
        var samples: [Double] = []
        for i in 0..<20 {
            let world = JourneyWorld.allCases[i % JourneyWorld.allCases.count]
            let elapsed = clock.measure { _ = WorldPieces.piece(world, index: i, rail: rail, seed: 1) }
            let c = elapsed.components
            samples.append(Double(c.seconds) * 1e3 + Double(c.attoseconds) * 1e-15)
        }
        samples.sort()
        let median = (samples[9] + samples[10]) / 2
        print("WorldPieces median ms: \(median)")
        #expect(median.isFinite)
    }
}
