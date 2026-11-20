// ConvexSolidCodingTests — feature 212 (R02-F12) T-R02F12-005 (FR-R02F12-007; SC-R02F12-005). A cube cut by three
// seeded planes with its ledger round-trips and encodes to identical bytes twice; schema 2, truncated JSON, a vertex
// pushed outward (non-convex), a face index out of range, a missing face (open) and a negative ledger volume are
// refused with their reasons.
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

@Suite struct ConvexSolidCodingTests {
    /// The unit cube cut by three seeded planes, with its ledger.
    static func document() throws -> ConvexSolidDocument {
        var random = SDFTestRandom(seed: 2_012)
        var ledger = VolumeLedger(solid: try ConvexSolid.box(min: Vec3(0, 0, 0), max: Vec3(1, 1, 1)))
        for _ in 0..<3 {
            var n = random.point(1)
            while n.length < 1e-3 { n = random.point(1) }
            n = n.normalized
            let q = Vec3(0.5, 0.5, 0.5) + random.point(0.25)
            _ = try ledger.cut(by: ClipPlane(normal: n, offset: n.dot(q)))
        }
        let solid = try #require(ledger.current)
        return ConvexSolidDocument(solid: solid, ledger: ledger)
    }

    /// The JSON object of `document`, changed by `edit`, as data.
    static func edited(_ edit: (inout [String: Any]) -> Void) throws -> Data {
        var object = try #require(try JSONSerialization.jsonObject(with: document().encoded()) as? [String: Any])
        edit(&object)
        return try JSONSerialization.data(withJSONObject: object)
    }

    /// The solid object of a document JSON object.
    static func solidObject(_ object: [String: Any]) -> [String: Any] { object["solid"] as? [String: Any] ?? [:] }

    static func refusal(_ data: Data) -> ConvexSolidError? {
        do { _ = try ConvexSolidDocument.decode(data); return nil } catch { return error }
    }

    @Test func aCutSolidWithItsLedgerRoundTrips() throws {
        let original = try Self.document()
        #expect(original.ledger?.entries.count == 3)
        #expect(original.solid.volume < 1)
        let data = try original.encoded()
        #expect(try original.encoded() == data)
        let back = try ConvexSolidDocument.decode(data)
        #expect(back == original)
        #expect(try back.encoded() == data)
        #expect(back.ledger?.isBalanced == true)
        let bare = ConvexSolidDocument(solid: original.solid)
        let bareData = try bare.encoded()
        #expect(!(String(decoding: bareData, as: UTF8.self).contains("ledger")))
        #expect(try ConvexSolidDocument.decode(bareData) == bare)
    }

    @Test func aNewerSchemaIsRefused() throws {
        let data = try Self.edited { $0["schema"] = 2 }
        #expect(Self.refusal(data) == .newerSchema(2))
        #expect(Self.refusal(try Self.edited { $0["schema"] = 0 })?.reasonCode == "r2-f12.malformed")
        #expect(Self.refusal(try Self.edited { $0["schema"] = "one" })?.reasonCode == "r2-f12.malformed")
        #expect(Self.refusal(try Self.edited { $0.removeValue(forKey: "schema") })?.reasonCode == "r2-f12.malformed")
    }

    @Test func truncatedJSONIsRefused() throws {
        let data = try Self.document().encoded()
        #expect(Self.refusal(data.prefix(data.count / 2))?.reasonCode == "r2-f12.malformed")
        #expect(Self.refusal(Data())?.reasonCode == "r2-f12.malformed")
    }

    @Test func aVertexPushedOutwardIsRefusedNotConvex() throws {
        let data = try Self.edited { object in
            var solid = Self.solidObject(object)
            var vertices = solid["vertices"] as? [[String: Any]] ?? []
            var sum = Vec3.zero
            for v in vertices {
                sum += Vec3(v["x"] as? Double ?? 0, v["y"] as? Double ?? 0, v["z"] as? Double ?? 0)
            }
            let centre = sum / Double(vertices.count)
            let v = vertices[0]
            let p = Vec3(v["x"] as? Double ?? 0, v["y"] as? Double ?? 0, v["z"] as? Double ?? 0)
            let pushed = centre + (p - centre) * 1.5
            vertices[0] = ["x": pushed.x, "y": pushed.y, "z": pushed.z]
            solid["vertices"] = vertices
            object["solid"] = solid
        }
        #expect(Self.refusal(data) == .notConvex)
    }

    @Test func aFaceIndexOutOfRangeIsRefusedMalformed() throws {
        let data = try Self.edited { object in
            var solid = Self.solidObject(object)
            var faces = solid["faces"] as? [[Int]] ?? []
            let count = (solid["vertices"] as? [Any])?.count ?? 0
            faces[0][0] = count + 7
            solid["faces"] = faces
            object["solid"] = solid
        }
        let error = Self.refusal(data)
        #expect(error?.reasonCode == "r2-f12.malformed")
        #expect(error == .malformed("index"))
    }

    @Test func aMissingFaceIsRefusedNotClosed() throws {
        let data = try Self.edited { object in
            var solid = Self.solidObject(object)
            var faces = solid["faces"] as? [[Int]] ?? []
            faces.removeLast()
            solid["faces"] = faces
            object["solid"] = solid
        }
        #expect(Self.refusal(data) == .notClosed)
    }

    @Test func aNegativeLedgerVolumeIsRefused() throws {
        let data = try Self.edited { object in
            var ledger = object["ledger"] as? [String: Any] ?? [:]
            var entries = ledger["entries"] as? [[String: Any]] ?? []
            entries[0]["removed"] = -0.25
            ledger["entries"] = entries
            object["ledger"] = ledger
        }
        #expect(Self.refusal(data) == .malformed("ledger volume"))
        let zero = try Self.edited { object in
            var ledger = object["ledger"] as? [String: Any] ?? [:]
            ledger["original"] = 0
            object["ledger"] = ledger
        }
        #expect(Self.refusal(zero)?.reasonCode == "r2-f12.malformed")
    }
}
