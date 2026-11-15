// WorldStateTests — feature 089 (A12-P01) T-A12-103 (FR-A12-111, FR-A12-122; clarification 4; research D4). The saved
// world state, host-free and short: the initial state; choosing a preset (0…2, others refused); a new seed from the
// generator that differs from the current one and continues the generator; the sorted-key JSON round trip is exact;
// damaged payloads (not JSON, truncated, missing keys, out-of-range preset, seed or view, broken generator) and newer
// payloads are refused with their reason.
//
// Feature 091 (A12-P03) T-A12-302 (FR-A12-320; clarifications Q2 and Q4): schema 2 with props, selection and light;
// schema-1 payloads decode with no props, no selection and the default light; damaged props, selections and lights are
// refused; a preset or seed change clears the props and the selection.
import Foundation
import Testing
import TinyWorldsCore
import VisualCoreSimulation

@Suite struct WorldStateTests {
    @Test func theInitialStateIsTheIslandWithSeedOne() {
        let state = WorldState.initial
        #expect(state.schema == 2 && state.presetIndex == 0 && state.seed == 1 && state.view == .default)
        #expect(state.props.isEmpty && state.selection == -1 && state.light == .default && state.selectedProp == nil)
        #expect(state.preset == .island)
        #expect(state.random == SeededRandom(seed: WorldState.generatorSeed).state)
    }

    @Test func choosingAPresetAcceptsOnlyZeroToTwo() {
        var state = WorldState.initial
        var accepted = state.choosePreset(2)
        #expect(accepted && state.preset == .miniatureCity)
        let before = state
        for index in [3, -1, Int.max] {
            accepted = state.choosePreset(index)
            #expect(!accepted, "preset \(index)")
        }
        #expect(state == before)
        accepted = state.choosePreset(1)
        #expect(accepted && state.preset == .asteroidGarden)
    }

    @Test func aNewSeedComesFromTheGeneratorAndContinuesIt() throws {
        var state = WorldState.initial
        var generator = SeededRandom(seed: WorldState.generatorSeed)
        let expected = UInt32(truncatingIfNeeded: generator.next() >> 32)
        let first = state.newSeed()
        #expect(first == expected && state.seed == expected && first != WorldState.defaultSeed)
        #expect(state.random == generator.state)
        let second = state.newSeed()
        #expect(second != first)
        var replay = WorldState.initial
        replay.newSeed()
        replay.newSeed()
        #expect(replay == state, "the same session draws the same seeds")
    }

    @Test func theJSONRoundTripIsExactAndSorted() throws {
        var state = WorldState.initial
        state.choosePreset(1)
        state.newSeed()
        state.view.orbit(yawDegrees: 33, pitchDegrees: -7)
        state.view.zoom(1.25)
        let data = state.encoded()
        #expect(WorldState.decode(data) == .success(state))
        #expect(try JSONDecoder().decode(WorldState.self, from: data) == state)
        #expect(state.encoded() == data)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.hasPrefix("{\"light\":{\"ambient\":0.35,\"azimuth\":30,\"elevation\":50},\"presetIndex\":1,"
                               + "\"props\":[],\"random\":{\"seed\":\"54494e5957524c44\",\"version\":1,"))
        #expect(text.contains(",\"schema\":2,\"seed\":\(state.seed),\"selection\":-1,\"view\":{\"distance\":"))
    }

    /// The initial state's JSON object, ready to be damaged.
    private func object() throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: WorldState.initial.encoded()) as? [String: Any])
    }

    private func decode(_ object: [String: Any]) throws -> Result<WorldState, WorldStateRefusal> {
        WorldState.decode(try JSONSerialization.data(withJSONObject: object))
    }

    @Test func damagedPayloadsAreRefused() throws {
        let data = WorldState.initial.encoded()
        #expect(WorldState.decode(Data("{not json".utf8)) == .failure(.damaged))
        #expect(WorldState.decode(data.prefix(data.count / 2)) == .failure(.damaged))
        #expect(WorldState.decode(Data()) == .failure(.damaged))
        var damaged: [[String: Any]] = []
        for key in ["schema", "presetIndex", "seed", "view", "random", "props", "selection", "light"] {
            var copy = try object(); copy[key] = nil; damaged.append(copy)
        }
        var copy = try object(); copy["schema"] = 0; damaged.append(copy)
        copy = try object(); copy["schema"] = "1"; damaged.append(copy)
        copy = try object(); copy["presetIndex"] = 3; damaged.append(copy)
        copy = try object(); copy["presetIndex"] = -1; damaged.append(copy)
        copy = try object(); copy["presetIndex"] = 1.5; damaged.append(copy)
        copy = try object(); copy["seed"] = 4_294_967_296; damaged.append(copy)
        copy = try object(); copy["seed"] = -1; damaged.append(copy)
        copy = try object(); copy["view"] = ["distance": 40, "pitch": 0.5, "yaw": 0]; damaged.append(copy)
        copy = try object(); copy["random"] = ["seed": "0", "version": 1, "words": []]; damaged.append(copy)
        let prop: [String: Any] = ["kind": 0, "rotation": 0, "scale": 1, "x": 1, "y": 0.5, "z": 1]
        for (key, value) in [("kind", 4), ("x", 5.6), ("z", -5.6), ("y", 2), ("rotation", 3.2), ("scale", 2)]
            as [(String, Any)] {
            var bad = prop; bad[key] = value
            copy = try object(); copy["props"] = [bad]; damaged.append(copy)
        }
        copy = try object(); copy["props"] = Array(repeating: prop, count: 25); damaged.append(copy)
        copy = try object(); copy["props"] = [prop]; copy["selection"] = 1; damaged.append(copy)
        copy = try object(); copy["selection"] = 0; damaged.append(copy)
        copy = try object(); copy["selection"] = -2; damaged.append(copy)
        copy = try object(); copy["light"] = ["ambient": 0.35, "azimuth": 360, "elevation": 50]; damaged.append(copy)
        copy = try object(); copy["light"] = ["ambient": 0.7, "azimuth": 30, "elevation": 50]; damaged.append(copy)
        copy = try object(); copy["light"] = ["ambient": 0.35, "azimuth": 30, "elevation": 9]; damaged.append(copy)
        copy = try object(); copy["props"] = [prop]; copy["selection"] = 0
        #expect(try decode(copy).map(\.selectedProp?.kind) == .success(.tree), "a valid prop and selection decode")
        copy = try object()
        copy["random"] = ["seed": String(repeating: "0", count: 16), "version": 1,
                          "words": Array(repeating: String(repeating: "0", count: 16), count: 4)]
        damaged.append(copy)
        for payload in damaged { #expect(try decode(payload) == .failure(.damaged), "\(payload)") }
        #expect(throws: (any Error).self) {
            var newer = try object(); newer["schema"] = 3
            _ = try JSONDecoder().decode(WorldState.self, from: try JSONSerialization.data(withJSONObject: newer))
        }
    }

    @Test func newerPayloadsAreRefusedWhateverElseTheyHold() throws {
        var newer = try object()
        newer["schema"] = 3
        #expect(try decode(newer) == .failure(.newerVersion))
        #expect(WorldState.decode(Data("{\"schema\":7}".utf8)) == .failure(.newerVersion))
        #expect(Set(WorldStateRefusal.allCases.map(\.rawValue)) == ["damaged", "newer-version"])
    }

    /// A schema-1 payload (A12-P01/P02) restores with no props, no selection and the default light, and is written
    /// back at schema 2.
    @Test func schemaOnePayloadsDecodeWithNoPropsAndTheDefaultLight() throws {
        var one = try object()
        one["schema"] = 1
        one["presetIndex"] = 2
        one["seed"] = 77
        for key in ["props", "selection", "light"] { one[key] = nil }
        let state = try decode(one).get()
        #expect(state.schema == 2 && state.presetIndex == 2 && state.seed == 77)
        #expect(state.props.isEmpty && state.selection == -1 && state.light == .default)
        #expect(state == WorldState(presetIndex: 2, seed: 77, view: .default, random: WorldState.initial.random))
        #expect(try JSONDecoder().decode(WorldState.self, from: JSONSerialization.data(withJSONObject: one)) == state)
        #expect(WorldState.decode(state.encoded()) == .success(state))
        one["props"] = "ignored at schema 1"
        #expect(try decode(one) == .success(state))
    }

    /// Changing the preset or the seed clears the props and the selection; re-choosing the same preset keeps them.
    @Test func aPresetOrSeedChangeClearsThePropsAndTheSelection() throws {
        var state = WorldState.initial
        #expect(WorldEditing.place(kind: 0, x: 0, z: 0, in: &state) == nil)
        #expect(state.props.count == 1 && state.selection == 0)
        state.choosePreset(0)
        #expect(state.props.count == 1 && state.selection == 0, "the same preset keeps the terrain and the props")
        state.choosePreset(2)
        #expect(state.props.isEmpty && state.selection == -1)
        #expect(WorldEditing.place(kind: 2, x: 0, z: 0, in: &state) == nil)
        state.newSeed()
        #expect(state.props.isEmpty && state.selection == -1)
        let refused = state
        #expect(!state.choosePreset(5) && state == refused)
    }
}
