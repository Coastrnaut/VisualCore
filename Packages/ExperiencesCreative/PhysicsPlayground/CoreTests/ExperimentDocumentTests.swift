// ExperimentDocumentTests — feature 085 (A11-P04) T-A11-402 (FR-A11-403; clarifications 2 and 3; research D3;
// SC-A11-402). The saved experiment file, host-free and short: a round trip gives the identical document and bytes;
// grab and selection are removed; the origin's JSON form and its ranges; the name rules (cut to 24, trimmed, "Experiment
// N" when empty); each refusal — `damaged` (not JSON, empty, truncated, missing keys, a bad origin, a bad stored name,
// schema 0), `newer-version` (schema 2, even when the rest is unreadable) and `invalid-world` (an unsupported world
// schema, a malformed world, a world that does not validate); an older world schema inside a document migrates.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import PhysicsPlaygroundCore

@Suite struct ExperimentDocumentTests {
    private let catalog = MaterialCatalog.bundled

    /// An edited spring chain that has run, with a selection and a grab.
    private func editedWorld() -> PhysicsWorld {
        var random = SeededRandom(seed: 9)
        var world = Presets.make(.springChain, random: &random, catalog: catalog)
        for _ in 0..<45 { WorldSimulation.advanceHostStep(&world, catalog: catalog) }
        #expect(WorldSimulation.drop(&world, kind: .box, random: &random, catalog: catalog))
        world.selectedId = 2
        world.grab = Grab(bodyId: 3, localAnchor: Vec2(0.1, 0), target: Vec2(6, 5))
        world.showForces = true
        #expect(world.validate(catalog: catalog).isEmpty)
        return world
    }

    /// The JSON object of `data`.
    private func object(_ data: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// `object` as JSON data.
    private func data(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    @Test func aRoundTripIsIdenticalAndDropsGrabAndSelection() throws {
        let world = editedWorld()
        let document = ExperimentDocument(name: "My chain", origin: .preset(2), world: world, slot: 1)
        #expect(document.schema == 1 && document.name == "My chain" && document.origin == .preset(2))
        #expect(document.world.grab == nil && document.world.selectedId == nil)
        var expected = world
        expected.grab = nil; expected.selectedId = nil
        #expect(document.world == expected)
        let bytes = document.encoded()
        #expect(!bytes.isEmpty)
        let decoded = try ExperimentDocument.decode(bytes, catalog: catalog).get()
        #expect(decoded == document)
        #expect(decoded.encoded() == bytes)
        // Sorted keys at the top level, and the world written exactly as its own encoder writes it.
        let text = try #require(String(data: bytes, encoding: .utf8))
        #expect(text.hasPrefix("{\"name\":\"My chain\",\"origin\":{\"index\":2,\"kind\":\"preset\"},\"schema\":1,\"world\":"))
        #expect(text.contains(String(decoding: expected.encoded(), as: UTF8.self)))
        // A grab or selection set after making the document is still left out of the file.
        var touched = document
        touched.world.selectedId = 0
        #expect(touched.encoded() == bytes)
    }

    @Test func originsEncodeAsKindAndIndexWithinZeroToThree() throws {
        for origin in [ExperimentOrigin.preset(0), .preset(3), .slot(0), .slot(3)] {
            let data = try JSONEncoder().encode(origin)
            #expect(try JSONDecoder().decode(ExperimentOrigin.self, from: data) == origin)
            #expect(origin.isValid)
        }
        #expect(!ExperimentOrigin.slot(4).isValid && !ExperimentOrigin.preset(-1).isValid)
        #expect(ExperimentOrigin.freePlay == .preset(0) && ExperimentOrigin.slot(2).index == 2)
        for bad in [#"{"kind":"slot","index":4}"#, #"{"kind":"preset","index":-1}"#, #"{"kind":"file","index":0}"#,
                    #"{"kind":"slot"}"#] {
            #expect(throws: (any Error).self) { try JSONDecoder().decode(ExperimentOrigin.self, from: Data(bad.utf8)) }
        }
    }

    @Test func namesAreTrimmedCutToTwentyFourOrDefaulted() {
        #expect(ExperimentDocument.normalizedName("  Pendulum test \n", slot: 0) == "Pendulum test")
        let long = String(repeating: "abcdefghij", count: 3)
        #expect(ExperimentDocument.normalizedName(long, slot: 0) == String(long.prefix(24)))
        #expect(ExperimentDocument.normalizedName(long, slot: 0).count == 24)
        #expect(ExperimentDocument.normalizedName("", slot: 0) == "Experiment 1")
        #expect(ExperimentDocument.normalizedName("   ", slot: 3) == "Experiment 4")
        #expect(ExperimentDocument.normalizedName(String(repeating: "é", count: 30), slot: 0).count == 24)
        // A cut that ends in white space is trimmed again.
        #expect(ExperimentDocument.normalizedName(String(repeating: "a", count: 23) + " b", slot: 0)
                == String(repeating: "a", count: 23))
        let document = ExperimentDocument(name: "", origin: .slot(2), world: editedWorld(), slot: 2)
        #expect(document.name == "Experiment 3")
        #expect(ExperimentDocument.isValidName("x") && !ExperimentDocument.isValidName(""))
        #expect(!ExperimentDocument.isValidName(" x") && !ExperimentDocument.isValidName(long))
    }

    @Test func damagedFilesAreRefused() throws {
        let bytes = ExperimentDocument(name: "A", origin: .slot(0), world: editedWorld(), slot: 0).encoded()
        let truncated = bytes.prefix(bytes.count / 2)
        #expect(ExperimentDocument.decode(Data(truncated)) == .failure(.damaged))
        #expect(ExperimentDocument.decode(bytes.dropLast()) == .failure(.damaged))
        #expect(ExperimentDocument.decode(Data()) == .failure(.damaged))
        #expect(ExperimentDocument.decode(Data("not json".utf8)) == .failure(.damaged))
        #expect(ExperimentDocument.decode(Data("[1,2]".utf8)) == .failure(.damaged))
        let whole = try object(bytes)
        for key in ["schema", "name", "origin", "world"] {
            var missing = whole
            missing.removeValue(forKey: key)
            #expect(ExperimentDocument.decode(try data(missing)) == .failure(.damaged), "without \(key)")
        }
        for (key, value) in [("schema", "1" as Any), ("schema", 0 as Any), ("name", "" as Any),
                             ("name", String(repeating: "n", count: 25) as Any), ("name", 5 as Any),
                             ("origin", ["kind": "slot", "index": 7] as Any)] {
            var changed = whole
            changed[key] = value
            #expect(ExperimentDocument.decode(try data(changed)) == .failure(.damaged), "\(key) = \(value)")
        }
    }

    @Test func newerFilesAreRefusedWhateverTheyHold() throws {
        let bytes = ExperimentDocument(name: "A", origin: .slot(0), world: editedWorld(), slot: 0).encoded()
        var newer = try object(bytes)
        newer["schema"] = 2
        #expect(ExperimentDocument.decode(try data(newer)) == .failure(.newerVersion))
        #expect(ExperimentDocument.decode(Data(#"{"schema":2}"#.utf8)) == .failure(.newerVersion))
        #expect(ExperimentDocument.decode(Data(#"{"schema":99,"world":"later"}"#.utf8)) == .failure(.newerVersion))
    }

    @Test func invalidWorldsAreRefused() throws {
        let bytes = ExperimentDocument(name: "A", origin: .slot(0), world: editedWorld(), slot: 0).encoded()
        let whole = try object(bytes)
        var world = try #require(whole["world"] as? [String: Any])
        // An unsupported world schema, a malformed world and a world that does not validate.
        var unsupported = whole
        world["schema"] = 5
        unsupported["world"] = world
        #expect(ExperimentDocument.decode(try data(unsupported)) == .failure(.invalidWorld))
        var malformed = whole
        malformed["world"] = "a world"
        #expect(ExperimentDocument.decode(try data(malformed)) == .failure(.invalidWorld))
        var unsound = editedWorld()
        unsound.bodies[0].materialId = "gold"
        let refused = ExperimentDocument(name: "B", origin: .preset(1), world: unsound, slot: 0).encoded()
        #expect(ExperimentDocument.decode(refused) == .failure(.invalidWorld))
        var levels = editedWorld()
        levels.dragLevel = 0
        let mismatched = ExperimentDocument(name: "C", origin: .preset(1), world: levels, slot: 0).encoded()
        #expect(ExperimentDocument.decode(mismatched) == .failure(.invalidWorld))
    }

    @Test func anOlderWorldSchemaInsideADocumentMigrates() throws {
        let body = PhysicsBody(id: 0, shape: .circle(radius: 0.3), materialId: "wood", position: Vec2(4, 4))
        let old = PhysicsWorld.SchemaOne(bodies: [body], tick: 12, nextId: 1)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let worldObject = try JSONSerialization.jsonObject(with: try encoder.encode(old))
        let file = try data(["schema": 1, "name": "Old", "origin": ["kind": "preset", "index": 0],
                             "world": worldObject])
        let document = try ExperimentDocument.decode(file, catalog: catalog).get()
        #expect(document.world == PhysicsWorld.migrated(fromSchemaOne: old))
        #expect(document.world.schema == PhysicsWorld.schemaVersion && document.name == "Old")
    }

    @Test func refusalReasonsHaveTheirContractNames() {
        #expect(DocumentRefusal.allCases.map(\.rawValue) == ["damaged", "newer-version", "invalid-world"])
    }
}
