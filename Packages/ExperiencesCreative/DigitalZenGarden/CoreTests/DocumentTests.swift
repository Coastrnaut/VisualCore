// DocumentTests — feature 145 (A20-P01) T-A20-105 (FR-A20-101, FR-A20-102; SC-A20-101; clarification Q2). The empty
// garden; a garden with two strokes and two stones round-trips exactly; one hand-built sample per refusal code
// (damaged, newer-version, too-large, unknown-tray, unknown-tone, unknown-rake, unknown-stone, out-of-range,
// over-cap) gives that code and a sentence; a refused file leaves the open garden unchanged.
import Foundation
import Testing
import VisualCoreMath
@testable import DigitalZenGardenCore

@Suite struct DocumentTests {
    /// A garden with two strokes (one a dab) and two stones.
    private static var sample: GardenDocument {
        var document = GardenDocument.empty
        document.tone = "warm"
        let line = RakeStroke(rake: "fine-rake", points: [Vec2(0.1, 0.2), Vec2(0.104, 0.2), Vec2(0.108, 0.2)])
        let dab = RakeStroke(rake: "wide-rake", points: [Vec2(0.5, 0.5)], capped: true)
        document.strokes = [line, dab]
        let pebble = Stone(id: 1, kind: "river-pebble", position: Vec2(0.25, 0.75), rotation: 0.5, scale: 1.25,
                           depth: 0)
        let slate = Stone(id: 2, kind: "flat-slate", position: Vec2(1, 0), rotation: -Double.pi, scale: 2, depth: 1)
        document.stones = [pebble, slate]
        document.nextStoneID = 3
        return document
    }

    /// The refusal of `result`, or nil when it decoded.
    private static func refusal(_ result: Result<GardenDocument, DocumentRefusal>) -> DocumentRefusal? {
        if case let .failure(refusal) = result { return refusal }
        return nil
    }

    /// The JSON object of the sample's body.
    private static func body() throws -> [String: Any] {
        let data = try JSONEncoder().encode(sample)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// A hand-built file: the envelope `{kind, version, body}`.
    private static func file(_ body: [String: Any], kind: String = GardenDocument.kind, version: Int = 1) throws
        -> Data {
        var envelope: [String: Any] = [:]
        envelope["kind"] = kind
        envelope["version"] = version
        envelope["body"] = body
        return try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
    }

    /// Decodes `data` the way the app opens a file: the open garden is replaced only on success.
    private static func open(_ data: Data, into garden: inout GardenDocument) -> DocumentRefusal? {
        switch GardenDocument.decode(data) {
        case .success(let document):
            garden = document
            return nil
        case .failure(let refusal):
            return refusal
        }
    }

    /// The sample with `change` applied, as a file built by the encoder.
    private static func encodedFile(_ change: (inout GardenDocument) -> Void) throws -> Data {
        var document = sample
        change(&document)
        return try document.encoded()
    }

    @Test func theEmptyGardenIsDocumented() {
        let empty = GardenDocument.empty
        #expect(empty.tray == "small-tray")
        #expect(empty.tone == "pale")
        #expect(empty.stones.isEmpty)
        #expect(empty.strokes.isEmpty)
        #expect(empty.nextStoneID == 1)
        #expect(empty.validate() == nil)
        #expect(GardenDocument.kind == "a20.garden")
        #expect(GardenDocument.schemaVersion == 1)
        #expect(GardenDocument.maxBytes == 262_144)
        #expect(GardenDocument.maxStones == 24)
        #expect(GardenDocument.maxStrokes == 400)
        #expect(RakeStroke.maxPoints == 512)
    }

    @Test func theRoundTripIsExact() throws {
        let data = try Self.sample.encoded()
        let back = try GardenDocument.decode(data).get()
        #expect(back == Self.sample)
        #expect(try back.encoded() == data)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.hasPrefix("{\"body\":{"))
        #expect(text.hasSuffix("\"kind\":\"a20.garden\",\"version\":1}"))
    }

    @Test func aDamagedFileIsRefused() throws {
        #expect(Self.refusal(GardenDocument.decode(Data("not a garden".utf8))) == .damaged)
        let wrongKind = try Self.file(try Self.body(), kind: "a19.wallpaper-project")
        #expect(Self.refusal(GardenDocument.decode(wrongKind)) == .damaged)
        var body = try Self.body()
        body["tray"] = nil
        #expect(Self.refusal(GardenDocument.decode(try Self.file(body))) == .damaged)
        #expect(DocumentRefusal.damaged.code == "damaged")
    }

    @Test func aNewerVersionIsRefused() throws {
        let data = try Self.file(try Self.body(), version: 2)
        let refusal = Self.refusal(GardenDocument.decode(data))
        #expect(refusal == .newerVersion(2))
        #expect(refusal?.code == "newer-version")
    }

    @Test func aLargeFileIsRefused() {
        let data = Data(repeating: 0x20, count: GardenDocument.maxBytes + 1)
        let refusal = Self.refusal(GardenDocument.decode(data))
        #expect(refusal == .tooLarge(GardenDocument.maxBytes + 1))
        #expect(refusal?.code == "too-large")
    }

    @Test func unknownIdsAreRefused() throws {
        var body = try Self.body()
        body["tray"] = "huge-tray"
        let tray = Self.refusal(GardenDocument.decode(try Self.file(body)))
        #expect(tray == .unknownTray("huge-tray"))
        #expect(tray?.code == "unknown-tray")

        let tone = Self.refusal(GardenDocument.decode(try Self.encodedFile { $0.tone = "violet" }))
        #expect(tone == .unknownTone("violet"))
        #expect(tone?.code == "unknown-tone")

        let rake = Self.refusal(GardenDocument.decode(try Self.encodedFile { $0.strokes[1].rake = "comb" }))
        #expect(rake == .unknownRake("comb"))
        #expect(rake?.code == "unknown-rake")

        let stone = Self.refusal(GardenDocument.decode(try Self.encodedFile { $0.stones[0].kind = "brick" }))
        #expect(stone == .unknownStone("brick"))
        #expect(stone?.code == "unknown-stone")
    }

    @Test func outOfRangeValuesAreRefused() throws {
        let point = Self.refusal(GardenDocument.decode(try Self.encodedFile { $0.strokes[0].points[1].x = 1.5 }))
        #expect(point == .outOfRange("points"))
        #expect(point?.code == "out-of-range")
        let position = try Self.encodedFile { $0.stones[0].position.y = -0.1 }
        #expect(Self.refusal(GardenDocument.decode(position)) == .outOfRange("position"))
        let rotation = try Self.encodedFile { $0.stones[0].rotation = 4 }
        #expect(Self.refusal(GardenDocument.decode(rotation)) == .outOfRange("rotation"))
        let scale = try Self.encodedFile { $0.stones[1].scale = 0.25 }
        #expect(Self.refusal(GardenDocument.decode(scale)) == .outOfRange("scale"))
        let id = try Self.encodedFile { $0.stones[1].id = 1 }
        #expect(Self.refusal(GardenDocument.decode(id)) == .outOfRange("id"))
        let depth = try Self.encodedFile { $0.stones[1].depth = 0 }
        #expect(Self.refusal(GardenDocument.decode(depth)) == .outOfRange("depth"))
        let next = try Self.encodedFile { $0.nextStoneID = 2 }
        #expect(Self.refusal(GardenDocument.decode(next)) == .outOfRange("nextStoneID"))
        var nonFinite = Self.sample
        nonFinite.strokes[0].points[0].y = .nan
        #expect(nonFinite.validate() == .outOfRange("points"))
    }

    @Test func overCapContentIsRefused() throws {
        let empty = Self.refusal(GardenDocument.decode(try Self.encodedFile { $0.strokes[0].points = [] }))
        #expect(empty == .overCap("points"))
        #expect(empty?.code == "over-cap")
        let points = Array(repeating: Vec2(0.5, 0.5), count: RakeStroke.maxPoints + 1)
        let long = try Self.encodedFile { $0.strokes[0].points = points }
        #expect(Self.refusal(GardenDocument.decode(long)) == .overCap("points"))
        let strokes = try Self.encodedFile { document in
            document.strokes = Array(repeating: RakeStroke(rake: "fine-rake", points: [Vec2(0.5, 0.5)]),
                                     count: GardenDocument.maxStrokes + 1)
        }
        #expect(Self.refusal(GardenDocument.decode(strokes)) == .overCap("strokes"))
        var crowded = Self.sample
        crowded.stones = []
        for index in 0...GardenDocument.maxStones {
            crowded.stones.append(Stone(id: UInt32(index + 1), kind: "river-pebble", position: Vec2(0.5, 0.5),
                                        rotation: 0, scale: 1, depth: index))
        }
        crowded.nextStoneID = UInt32(GardenDocument.maxStones + 2)
        #expect(Self.refusal(GardenDocument.decode(try crowded.encoded())) == .overCap("stones"))
    }

    @Test func aRefusalLeavesTheOpenGardenUnchanged() throws {
        var garden = Self.sample
        let before = garden
        var samples = [Data("not a garden".utf8), Data(repeating: 0x20, count: GardenDocument.maxBytes + 1)]
        samples.append(try Self.file(try Self.body(), version: 2))
        samples.append(try Self.encodedFile { $0.tray = "huge-tray" })
        samples.append(try Self.encodedFile { $0.tone = "violet" })
        samples.append(try Self.encodedFile { $0.strokes[0].rake = "comb" })
        samples.append(try Self.encodedFile { $0.stones[0].kind = "brick" })
        samples.append(try Self.encodedFile { $0.stones[0].scale = 3 })
        samples.append(try Self.encodedFile { $0.strokes[0].points = [] })
        var codes = Set<String>()
        for data in samples {
            let refusal = try #require(Self.open(data, into: &garden))
            codes.insert(refusal.code)
            #expect(!refusal.sentence.isEmpty)
            #expect(garden == before)
        }
        #expect(codes.count == 9)
        #expect(Self.open(try GardenDocument.empty.encoded(), into: &garden) == nil)
        #expect(garden == .empty)
    }
}
