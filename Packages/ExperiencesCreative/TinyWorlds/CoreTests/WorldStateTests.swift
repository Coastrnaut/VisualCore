// WorldStateTests — feature 089 (A12-P01) T-A12-103 (FR-A12-111, FR-A12-122; clarification 4; research D4). The saved
// world state, host-free and short: the initial state; choosing a preset (0…2, others refused); a new seed from the
// generator that differs from the current one and continues the generator; the sorted-key JSON round trip is exact;
// damaged payloads (not JSON, truncated, missing keys, out-of-range preset, seed or view, broken generator) and newer
// payloads are refused with their reason.
import Foundation
import Testing
import TinyWorldsCore
import VisualCoreSimulation

@Suite struct WorldStateTests {
    @Test func theInitialStateIsTheIslandWithSeedOne() {
        let state = WorldState.initial
        #expect(state.schema == 1 && state.presetIndex == 0 && state.seed == 1 && state.view == .default)
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
        #expect(text.hasPrefix("{\"presetIndex\":1,\"random\":{\"seed\":\"54494e5957524c44\",\"version\":1,"))
        #expect(text.contains(",\"schema\":1,\"seed\":\(state.seed),\"view\":{\"distance\":"))
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
        for key in ["schema", "presetIndex", "seed", "view", "random"] {
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
        copy = try object()
        copy["random"] = ["seed": String(repeating: "0", count: 16), "version": 1,
                          "words": Array(repeating: String(repeating: "0", count: 16), count: 4)]
        damaged.append(copy)
        for payload in damaged { #expect(try decode(payload) == .failure(.damaged), "\(payload)") }
        #expect(throws: (any Error).self) {
            var newer = try object(); newer["schema"] = 2
            _ = try JSONDecoder().decode(WorldState.self, from: try JSONSerialization.data(withJSONObject: newer))
        }
    }

    @Test func newerPayloadsAreRefusedWhateverElseTheyHold() throws {
        var newer = try object()
        newer["schema"] = 2
        #expect(try decode(newer) == .failure(.newerVersion))
        #expect(WorldState.decode(Data("{\"schema\":7}".utf8)) == .failure(.newerVersion))
        #expect(Set(WorldStateRefusal.allCases.map(\.rawValue)) == ["damaged", "newer-version"])
    }
}
