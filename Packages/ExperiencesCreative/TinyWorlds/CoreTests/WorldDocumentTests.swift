// WorldDocumentTests — feature 091 (A12-P03) T-A12-302 (FR-A12-320, FR-A12-323; clarification Q4; research D4;
// SC-A12-302, SC-A12-303). The world document, host-free and short. The phase's regression fixture: a customised world
// on every preset (props of every kind at irregular coordinates, rotated, a changed light and view) saved and reopened
// keeps every prop's x, y, z, rotation and scale bit-identical, the same state, bytes and terrain digest. Refusals:
// too-large (over 64 KB, on decode and on encode), damaged (not JSON, truncated, wrong layout or schema, damaged
// state) and newer-version (document or state schema above 2); a schema-1 state inside a document reads with no props.
import Foundation
import Testing
import TinyWorldsCore

@Suite struct WorldDocumentTests {
    /// A customised world on `preset`: 8 props of every kind at irregular places, several rotated, one selected, a
    /// changed light and view.
    private func customised(preset: Int) throws -> WorldState {
        var state = editingState(preset: preset, seed: 20_261_115)
        let spots = validSpots(state, count: 8, offset: 0.1 + 1.0 / 3.0)
        #expect(spots.count == 8)
        for (n, spot) in spots.enumerated() {
            #expect(WorldEditing.place(kind: n % 4, x: spot.x, z: spot.z, in: &state) == nil)
            WorldEditing.rotate(degrees: Double(n) * 47.123456789 - 170, in: &state)
        }
        WorldEditing.select(3, in: &state)
        state.light.setAzimuth(271.828182845904)
        state.light.setElevation(31.4159265358979)
        state.light.setAmbient(0.577215664901532)
        state.view.orbit(yawDegrees: 12.5, pitchDegrees: 3.25)
        return state
    }

    @Test(arguments: [0, 1, 2])
    func propsReopenBitIdentical(preset: Int) throws {
        let state = try customised(preset: preset)
        let document = WorldDocument(state: state)
        let data = try document.encode().get()
        #expect(data.count <= WorldDocument.maxBytes)
        let reopened = try WorldDocument.decode(data).get()
        #expect(reopened == document && reopened.state == state)
        #expect(reopened.state.props.count == state.props.count)
        for (a, b) in zip(state.props, reopened.state.props) {
            #expect(a.kind == b.kind)
            #expect(a.x.bitPattern == b.x.bitPattern && a.y.bitPattern == b.y.bitPattern
                    && a.z.bitPattern == b.z.bitPattern)
            #expect(a.rotation.bitPattern == b.rotation.bitPattern && a.scale.bitPattern == b.scale.bitPattern)
        }
        #expect(reopened.state.light.azimuth.bitPattern == state.light.azimuth.bitPattern)
        #expect(reopened.state.view.yaw.bitPattern == state.view.yaw.bitPattern)
        #expect(try reopened.encode().get() == data, "re-saving gives the same bytes")
        #expect(try TerrainGenerator.digest(preset: reopened.state.preset, seed: reopened.state.seed)
                == TerrainGenerator.digest(preset: state.preset, seed: state.seed))
        #expect(reopened.state.selection == 3 && reopened.state.encoded() == state.encoded())
    }

    @Test func theDocumentLayoutAndName() throws {
        let document = WorldDocument(state: .initial)
        #expect(document.name == "Island, seed 1")
        #expect(WorldDocument.defaultName(for: editingState(preset: 1, seed: 9)) == "Asteroid garden, seed 9")
        let text = String(decoding: try document.encode().get(), as: UTF8.self)
        #expect(text.hasPrefix("{\"name\":\"Island, seed 1\",\"schema\":2,\"state\":{\"light\":"))
        #expect(WorldDocument.maxBytes == 65_536 && WorldDocument.schemaVersion == 2)
        #expect(Set(WorldDocumentRefusal.allCases.map(\.rawValue)) == ["damaged", "newer-version", "too-large"])
    }

    /// The initial document's JSON object, ready to be damaged.
    private func object() throws -> [String: Any] {
        let data = try WorldDocument(state: .initial).encode().get()
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func decode(_ object: [String: Any]) throws -> Result<WorldDocument, WorldDocumentRefusal> {
        WorldDocument.decode(try JSONSerialization.data(withJSONObject: object))
    }

    @Test func damagedNewerAndOversizedDocumentsAreRefused() throws {
        let data = try WorldDocument(state: try customised(preset: 0)).encode().get()
        #expect(WorldDocument.decode(Data("{not json".utf8)) == .failure(.damaged))
        #expect(WorldDocument.decode(Data()) == .failure(.damaged))
        for cut in [1, data.count / 3, data.count / 2, data.count - 1] {
            #expect(WorldDocument.decode(data.prefix(cut)) == .failure(.damaged), "truncated at \(cut)")
        }
        var damaged: [[String: Any]] = []
        for key in ["name", "schema", "state"] { var copy = try object(); copy[key] = nil; damaged.append(copy) }
        var copy = try object(); copy["schema"] = 1; damaged.append(copy)
        copy = try object(); copy["schema"] = "2"; damaged.append(copy)
        copy = try object(); copy["name"] = 7; damaged.append(copy)
        copy = try object(); copy["state"] = "island"; damaged.append(copy)
        var state = try #require((try object())["state"] as? [String: Any])
        state["presetIndex"] = 3
        copy = try object(); copy["state"] = state; damaged.append(copy)
        for payload in damaged { #expect(try decode(payload) == .failure(.damaged), "\(payload)") }

        copy = try object(); copy["schema"] = 3
        #expect(try decode(copy) == .failure(.newerVersion))
        var newerState = try #require((try object())["state"] as? [String: Any])
        newerState["schema"] = 3
        copy = try object(); copy["state"] = newerState
        #expect(try decode(copy) == .failure(.newerVersion))

        var padded = data
        padded.append(Data(repeating: 0x20, count: WorldDocument.maxBytes + 1 - data.count))
        #expect(padded.count == WorldDocument.maxBytes + 1)
        #expect(WorldDocument.decode(padded) == .failure(.tooLarge))
        #expect(WorldDocument.decode(padded.prefix(WorldDocument.maxBytes)).map(\.name) == .success("Island, seed 20261115"),
                "trailing spaces within the cap are still a document")
        let huge = WorldDocument(name: String(repeating: "x", count: WorldDocument.maxBytes), state: .initial)
        #expect(huge.encode() == .failure(.tooLarge))
    }

    @Test func aSchemaOneStateInsideADocumentReadsWithNoProps() throws {
        var root = try object()
        var state = try #require(root["state"] as? [String: Any])
        state["schema"] = 1
        for key in ["props", "selection", "light"] { state[key] = nil }
        root["state"] = state
        let document = try decode(root).get()
        #expect(document.state == .initial && document.name == "Island, seed 1")
    }
}
