// MusicLabStateTests — feature 047 (A06-P01) T-A06-104 (FR-A06-102, FR-A06-104, FR-A06-121; data-model
// "MusicLabState"). The state rules of VisualCore Music Lab, host-free and short: the first state, the microphone rule
// per mirrored permission, the demo mode range, the reseed step, the file name rules and the persisted fields.
import Foundation
import Testing
import VisualCoreMusicLabCore

@Suite struct MusicLabStateTests {
    @Test func theFirstStateIsTheDemoMelodyWithTheSeed() {
        let state = MusicLabState(seed: 42)
        #expect(state.source == .demo)
        #expect(state.demoSeed == 42)
        #expect(state.demoMode == 0)
        #expect(state.demoModeName == "Melody")
        #expect(state.fileName == nil)
        #expect(state.permission == .notDetermined)
    }

    @Test func theMicrophoneIsRefusedOnlyWhileAccessIsOff() {
        for access in MicrophoneAccess.allCases {
            var state = MusicLabState(seed: 1)
            state.permission = access
            let refusal = state.select(.microphone)
            if access == .denied || access == .restricted {
                #expect(refusal == MusicLabRule.permissionDenied, "\(access)")
                #expect(state.source == .demo, "\(access): unchanged")
            } else {
                #expect(refusal == nil, "\(access)")
                #expect(state.source == .microphone, "\(access)")
            }
        }
    }

    @Test func theDemoModeStaysWithinItsRange() {
        var state = MusicLabState(seed: 1)
        for mode in MusicLabState.demoModeRange {
            let accepted = state.setDemoMode(mode)
            #expect(accepted)
            #expect(state.demoMode == mode)
        }
        let tooHigh = state.setDemoMode(4), tooLow = state.setDemoMode(-1)
        #expect(!tooHigh)
        #expect(!tooLow)
        #expect(state.demoMode == 3)
        #expect(MusicLabState(source: .demo, demoSeed: 1, demoMode: 4) == nil)
        #expect(MusicLabState(source: .file, demoSeed: 1, demoMode: 2)?.demoMode == 2)
    }

    @Test func reseedMovesTheSeedOnAndWraps() {
        var state = MusicLabState(seed: UInt64.max)
        state.reseed()
        #expect(state.demoSeed == UInt64.max &+ MusicLabState.seedStep)
        var other = MusicLabState(seed: 7)
        other.reseed()
        #expect(other.demoSeed != 7)
    }

    @Test func theFileNameIsTrimmedCutAndOnlyKeptForAFile() {
        var state = MusicLabState(seed: 1)
        state.recordFileName("song.wav")
        #expect(state.fileName == nil, "not a file source")
        state.select(.file)
        state.recordFileName("  song.wav \n")
        #expect(state.fileName == "song.wav")
        state.recordFileName(String(repeating: "a", count: 300) + ".m4a")
        #expect(state.fileName?.count == MusicLabState.fileNameLimit)
        state.recordFileName("   ")
        #expect(state.fileName == nil)
        state.recordFileName("tone.caf")
        state.select(.demo)
        #expect(state.fileName == nil, "leaving the file clears the name")
    }

    @Test func onlySourceSeedAndModeArePersisted() throws {
        var state = MusicLabState(seed: 0xFFFF_FFFF_FFFF_FFFF)
        state.permission = .granted
        state.select(.file)
        state.recordFileName("tone.wav")
        state.setDemoMode(2)
        let data = try JSONEncoder().encode(state)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["source", "demoSeed", "demoMode", "scene", "mappings"])
        let decoded = try JSONDecoder().decode(MusicLabState.self, from: data)
        #expect(decoded.source == .file)
        #expect(decoded.demoSeed == 0xFFFF_FFFF_FFFF_FFFF)
        #expect(decoded.demoMode == 2)
        #expect(decoded.fileName == nil)
        #expect(decoded.permission == .notDetermined)
    }

    @Test func aDamagedPayloadIsRefused() {
        let badMode = Data(#"{"demoMode":9,"demoSeed":1,"source":"demo","scene":0,"mappings":[]}"#.utf8)
        #expect(throws: (any Error).self) { try JSONDecoder().decode(MusicLabState.self, from: badMode) }
        let badSource = Data(#"{"demoMode":0,"demoSeed":1,"source":"radio","scene":0,"mappings":[]}"#.utf8)
        #expect(throws: (any Error).self) { try JSONDecoder().decode(MusicLabState.self, from: badSource) }
    }

    // Feature 049 (A06-P03) T-A06-305: the scene and the mapping choices.
    @Test func theSceneAndMappingsStartAtTheDefaultsAndPersist() throws {
        var state = MusicLabState(seed: 3)
        #expect(state.scene == .bars)
        #expect(state.mappings == MusicLabScene.defaultMappings())
        state.select(scene: .geometry)
        let choice = try #require(MappingChoice(feature: 0, gain: 2))
        #expect(state.setMapping(scene: .geometry, slot: 0, choice: choice) == nil)
        #expect(state.currentChoices[0] == choice)
        let decoded = try JSONDecoder().decode(MusicLabState.self, from: JSONEncoder().encode(state))
        #expect(decoded.scene == .geometry)
        #expect(decoded.mappings == state.mappings)
    }

    @Test func aSlotBeyondTheScenesParametersIsRefused() throws {
        var state = MusicLabState(seed: 3)
        let choice = try #require(MappingChoice(feature: 1, gain: 1))
        #expect(state.setMapping(scene: .bars, slot: 2, choice: choice) == MusicLabRule.noSuchParameter)
        #expect(state.mappings == MusicLabScene.defaultMappings())
        #expect(state.setMapping(scene: .geometry, slot: 2, choice: choice) == nil)
        state.resetMappings(scene: .geometry)
        #expect(state.mappings == MusicLabScene.defaultMappings())
    }

    @Test func damagedScenesOrMappingsAreRefused() throws {
        let good = try JSONEncoder().encode(MusicLabState(seed: 1))
        var object = try #require(try JSONSerialization.jsonObject(with: good) as? [String: Any])
        object["scene"] = 3
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(MusicLabState.self, from: JSONSerialization.data(withJSONObject: object))
        }
        object["scene"] = 0
        object["mappings"] = [[["feature": 0, "gain": 1]]]
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(MusicLabState.self, from: JSONSerialization.data(withJSONObject: object))
        }
    }
}
