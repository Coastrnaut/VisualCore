// SDFCodingTests — feature 211 (R02-F11) T-R02F11-003 (FR-R02F11-007; clarification Q4). A nested shape using every
// node kind round-trips and encodes to identical bytes twice; a newer schema, an unknown kind, a negative radius in
// the data, truncated JSON, 257 nodes, a non-unit quaternion, a missing or non-integer schema and pathological
// nesting are each refused with their error, never trapped.
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

@Suite("SDFCoding")
struct SDFCodingTests {
    /// A shape that uses all thirteen node kinds.
    static func everyKind() throws -> SDFShape {
        let plane = try SDFShape.plane(normal: Vec3(0, 1, 0), offset: -2)
        let sphere = try SDFShape.sphere(radius: 0.75)
        let box = try SDFShape.box(halfExtents: Vec3(1, 0.5, 0.25))
        let rounded = try SDFShape.roundedBox(halfExtents: Vec3(1, 1, 1), radius: 0.125)
        let capsule = try SDFShape.capsule(a: Vec3(-1, 0, 0), b: Vec3(1, 0.1, 0.3), radius: 0.2)
        let torus = try SDFShape.torus(major: 1.5, minor: 0.3)
        let rotation = Quat(axis: Vec3(0.3, 1, -0.2), angle: 0.7)
        let left = try SDFShape.union([plane, sphere.translated(by: Vec3(0.1, 2.5, -3))])
        let right = try SDFShape.intersection([box, rounded.rotated(by: rotation)])
        let carved = try SDFShape.subtraction(left, right)
        let blended = try SDFShape.smoothUnion(capsule, torus.scaled(by: 1.25), radius: 0.4)
        return try SDFShape.union([carved, blended])
    }

    static func data(_ json: String) -> Data { Data(json.utf8) }

    static func refusal(_ json: String) -> SDFError? {
        do {
            _ = try SDFDocument.decode(data(json))
            return nil
        } catch {
            return error
        }
    }

    @Test func everyKindRoundTripsWithIdenticalBytes() throws {
        let document = SDFDocument(shape: try Self.everyKind())
        let first = try document.encoded()
        let second = try document.encoded()
        #expect(first == second)
        let decoded = try SDFDocument.decode(first)
        #expect(decoded == document)
        #expect(try decoded.encoded() == first)
        let text = String(decoding: first, as: UTF8.self)
        #expect(text.hasPrefix("{\"schema\":1,\"shape\":{"))
        for kind in ["plane", "sphere", "box", "roundedBox", "capsule", "torus", "union", "intersection",
                     "subtraction", "smoothUnion", "translated", "rotated", "scaled"] {
            #expect(text.contains("\"kind\":\"\(kind)\""), "missing kind \(kind)")
        }
    }

    @Test func handWrittenFixtureDecodes() throws {
        let json = #"{"schema":1,"shape":{"kind":"translated","offset":{"x":1,"y":2,"z":3},"#
            + #""child":{"kind":"sphere","radius":2}}}"#
        let document = try SDFDocument.decode(Self.data(json))
        #expect(document.shape == (try SDFShape.sphere(radius: 2).translated(by: Vec3(1, 2, 3))))
    }

    @Test func newerSchemaIsRefused() {
        let error = Self.refusal(#"{"schema":2,"shape":{"kind":"sphere","radius":1}}"#)
        #expect(error == .newerSchema(2))
        #expect(error?.reasonCode == "r2-f11.newer-schema")
    }

    @Test func missingOrBadSchemaIsMalformed() {
        for json in [#"{"shape":{"kind":"sphere","radius":1}}"#, #"{"schema":"1","shape":{"kind":"sphere","radius":1}}"#,
                     #"{"schema":1.5,"shape":{"kind":"sphere","radius":1}}"#,
                     #"{"schema":0,"shape":{"kind":"sphere","radius":1}}"#] {
            #expect(Self.refusal(json)?.reasonCode == "r2-f11.malformed", "\(json)")
        }
    }

    @Test func unknownKindIsRefused() {
        let error = Self.refusal(#"{"schema":1,"shape":{"kind":"union","children":[{"kind":"blob","radius":1}]}}"#)
        #expect(error == .unknownKind("blob"))
    }

    @Test func negativeRadiusIsRefusedByTheMaker() {
        #expect(Self.refusal(#"{"schema":1,"shape":{"kind":"sphere","radius":-1}}"#) == .nonPositive("radius"))
    }

    @Test func truncatedJSONIsMalformed() throws {
        let full = try SDFDocument(shape: Self.everyKind()).encoded()
        for cut in [1, full.count / 2, full.count - 1] {
            let error = Self.refusal(String(decoding: full.prefix(cut), as: UTF8.self))
            #expect(error?.reasonCode == "r2-f11.malformed", "cut at \(cut)")
        }
        #expect(Self.refusal(#"{"schema":1,"shape":{"kind":"sphere"}}"#)?.reasonCode == "r2-f11.malformed")
        #expect(Self.refusal(#"{"schema":1,"shape":{"kind":"sphere","radius":"big"}}"#)?.reasonCode
            == "r2-f11.malformed")
    }

    @Test func twoHundredFiftySevenNodesAreRefused() {
        // A union of 8 unions of 31 spheres: 1 + 8 + 248 = 257 nodes, every union within 32 children.
        let sphere = #"{"kind":"sphere","radius":1}"#
        let inner = #"{"kind":"union","children":["# + Array(repeating: sphere, count: 31).joined(separator: ",") + "]}"
        let json = #"{"schema":1,"shape":{"kind":"union","children":["#
            + Array(repeating: inner, count: 8).joined(separator: ",") + "]}}"
        #expect(Self.refusal(json) == .tooManyNodes(257))
    }

    @Test func nonUnitQuaternionIsRefused() {
        let json = #"{"schema":1,"shape":{"kind":"rotated","rotation":{"x":0,"y":0,"z":0,"w":2},"#
            + #""child":{"kind":"sphere","radius":1}}}"#
        #expect(Self.refusal(json) == .notUnitRotation)
    }

    @Test func pathologicalNestingIsRefusedWithoutTrapping() {
        func nested(_ levels: Int) -> String {
            var node = #"{"kind":"sphere","radius":1}"#
            for _ in 0..<levels { node = #"{"kind":"scaled","factor":1,"child":"# + node + "}" }
            return #"{"schema":1,"shape":"# + node + "}"
        }
        // 40 levels pass the reader; the makers refuse at depth 33 (SDFShape.maxDepth 32); 100 are refused by the reader at 65.
        #expect(Self.refusal(nested(40)) == .tooDeep(33))
        #expect(Self.refusal(nested(100)) == .tooDeep(65))
        // Far beyond any reader limit: refused (by the parser or the reader), never a crash.
        #expect(Self.refusal(nested(5_000)) != nil)
    }
}

/// Feature 211 (R02-F11) T-R02F11-003, SC-R02F11-005: a plane whose normal is not axis-aligned round-trips bit for bit,
/// because the maker keeps a normal that is already of unit length.
@Test func aSlantedPlaneRoundTripsBitForBit() throws {
    let plane = try SDFShape.plane(normal: Vec3(1, 2, 3), offset: 0.25)
    let document = SDFDocument(shape: plane)
    let data = try document.encoded()
    let back = try SDFDocument.decode(data)
    #expect(back == document)
    #expect(try back.encoded() == data)
}
