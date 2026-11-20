// TerrainSettingsTests — feature 218 (R02-F18) T-R02F18-002 (FR-R02F18-007, FR-R02F18-008; clarification Q5). Every
// refusal of terrain settings and sky parameters with its reason code; both stored forms round-trip byte for byte; a newer
// schema and damaged data are refused.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

@Suite struct TerrainSettingsTests {
    @Test func terrainRefusals() throws {
        #expect(throws: TerrainError.terrainSize(0)) { try TerrainSettings(pieces: 0, pieceCells: 16, cellSize: 1, levels: 2, levelDistance: 10) }
        #expect(throws: TerrainError.terrainSize(65)) { try TerrainSettings(pieces: 65, pieceCells: 16, cellSize: 1, levels: 2, levelDistance: 10) }
        #expect(throws: TerrainError.pieceSize(12)) { try TerrainSettings(pieces: 4, pieceCells: 12, cellSize: 1, levels: 2, levelDistance: 10) }
        #expect(throws: TerrainError.pieceSize(256)) { try TerrainSettings(pieces: 4, pieceCells: 256, cellSize: 1, levels: 2, levelDistance: 10) }
        #expect(throws: TerrainError.levelCount(5)) { try TerrainSettings(pieces: 4, pieceCells: 16, cellSize: 1, levels: 5, levelDistance: 10) }
        #expect(throws: TerrainError.levelCount(0)) { try TerrainSettings(pieces: 4, pieceCells: 16, cellSize: 1, levels: 0, levelDistance: 10) }
        #expect(throws: TerrainError.levelDistance) { try TerrainSettings(pieces: 4, pieceCells: 16, cellSize: 0, levels: 2, levelDistance: 10) }
        #expect(throws: TerrainError.levelDistance) { try TerrainSettings(pieces: 4, pieceCells: 16, cellSize: 1, levels: 2, levelDistance: .nan) }
        #expect(throws: TerrainError.budget(0)) { try TerrainSettings(pieces: 4, pieceCells: 16, cellSize: 1, levels: 2, levelDistance: 10, vertexBudget: 0) }
        let settings = try TerrainSettings(pieces: 8, pieceCells: 32, cellSize: 0.5, levels: 5, levelDistance: 12)
        #expect(settings.size == 128)
        #expect(settings.vertexBudget == 262_144)
        let codes: [TerrainError] = [.terrainSize(1), .pieceSize(1), .levelCount(1), .levelDistance, .budget(1), .viewpoint,
                                     .newerSchema(2), .malformed("x")]
        let expected: [String] = ["terrain-size", "piece-size", "level-count", "level-distance", "budget", "viewpoint",
                                  "newer-schema", "malformed"]
        for k in 0..<codes.count { #expect(codes[k].reasonCode == "r2-f18." + expected[k]) }
    }

    @Test func skyRefusals() throws {
        var bad = SkyParameters()
        bad.horizon = Vec3(1.2, 0, 0)
        #expect(throws: SkyError.skyParameter("horizon")) { try bad.validated() }
        bad = SkyParameters()
        bad.sunRadius = 0.5
        #expect(throws: SkyError.skyParameter("sunRadius")) { try bad.validated() }
        bad = SkyParameters()
        bad.glowExponent = 0.5
        #expect(throws: SkyError.skyParameter("glowExponent")) { try bad.validated() }
        bad = SkyParameters()
        bad.glowStrength = .infinity
        #expect(throws: SkyError.skyParameter("glowStrength")) { try bad.validated() }
        #expect(try SkyParameters().validated() == SkyParameters())
        #expect(SkyError.direction.reasonCode == "r2-f18.direction")
        #expect(SkyError.skyParameter("x").reasonCode == "r2-f18.sky-parameter")
    }

    @Test func storedFormsRoundTripByteForByte() throws {
        let settings = try TerrainSettings(pieces: 6, pieceCells: 64, cellSize: 0.25, levels: 4, levelDistance: 7.5, vertexBudget: 100_000)
        let data = settings.encoded()
        #expect(try TerrainSettings.decode(data) == settings)
        #expect(try TerrainSettings.decode(data).encoded() == data)
        #expect(String(decoding: data, as: UTF8.self).contains("\"schema\":1"))
        var sky = SkyParameters()
        sky.dusk = Vec3(0.8, 0.3, 0.1)
        sky.glowExponent = 200
        let skyData = sky.encoded()
        #expect(try SkyParameters.decode(skyData) == sky)
        #expect(try SkyParameters.decode(skyData).encoded() == skyData)
    }

    @Test func newerAndDamagedFormsAreRefused() throws {
        var object = try #require(try JSONSerialization.jsonObject(with: try TerrainSettings(pieces: 2, pieceCells: 8, cellSize: 1, levels: 2, levelDistance: 4).encoded()) as? [String: Any])
        object["schema"] = 2
        #expect(throws: TerrainError.newerSchema(2)) { try TerrainSettings.decode(try JSONSerialization.data(withJSONObject: object)) }
        object["schema"] = 1
        object["pieceCells"] = 9
        #expect(throws: TerrainError.pieceSize(9)) { try TerrainSettings.decode(try JSONSerialization.data(withJSONObject: object)) }
        let damaged: [String] = ["", "{", "[]", #"{"schema":1}"#]
        for text in damaged {
            do {
                _ = try TerrainSettings.decode(Data(text.utf8))
                Issue.record("terrain accepted \(text)")
            } catch {
                #expect(error.reasonCode == "r2-f18.malformed", "\(text)")
            }
            do {
                _ = try SkyParameters.decode(Data(text.utf8))
                Issue.record("sky accepted \(text)")
            } catch {
                #expect(error.reasonCode == "r2-f18.malformed", "\(text)")
            }
        }
        var sky = try #require(try JSONSerialization.jsonObject(with: SkyParameters().encoded()) as? [String: Any])
        sky["schema"] = 3
        #expect(throws: SkyError.newerSchema(3)) { try SkyParameters.decode(try JSONSerialization.data(withJSONObject: sky)) }
        sky["schema"] = 1
        sky["sunRadius"] = 1.0
        #expect(throws: SkyError.skyParameter("sunRadius")) { try SkyParameters.decode(try JSONSerialization.data(withJSONObject: sky)) }
    }
}
