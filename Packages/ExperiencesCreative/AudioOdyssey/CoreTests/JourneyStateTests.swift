// JourneyStateTests — feature 054 (A07-P01) T-A07-103 (FR-A07-121; data-model "JourneyState", schema 1). The state
// rules of Audio Odyssey, host-free and short: the first state, the JSON round trip, refusal of invalid payloads, the
// mutating rules and the digest text. Feature 055 (A07-P02) T-A07-204 (FR-A07-220; schema 2): the source field, the
// schema-1 → 2 decode (demo), the microphone round trip, refusal of an unknown source and `|source=` in the digest.
// Feature 056 (A07-P03) T-A07-302 (FR-A07-301–303, FR-A07-312, FR-A07-330; SC-A07-306; schema 3): the speed target,
// easing, calm motion and mappings; schema 1/2/3 decoding and refusals, snapping and clamping, the v3 digest text.
import Foundation
import Testing
import AudioOdysseyCore

@Suite struct JourneyStateTests {
    private func decode(_ json: String) throws -> JourneyState {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "inf",
                                                                         negativeInfinity: "-inf", nan: "nan")
        return try decoder.decode(JourneyState.self, from: Data(json.utf8))
    }

    private func payload(world: String = "0", distance: String = "12.5", speedChoice: String = "1",
                         speed: String = "3.25", source: String? = nil) -> String {
        "{\"world\":\(world),\"distance\":\(distance),\"speedChoice\":\(speedChoice),\"speed\":\(speed),"
            + "\"seed\":7,\"paused\":false" + (source.map { ",\"source\":\($0)" } ?? "") + "}"
    }

    @Test func theFirstStateIsTheTunnelAtMediumSpeed() {
        let state = JourneyState(seed: 3)
        #expect(JourneyState.schemaVersion == 3)
        #expect(state.world == .tunnel)
        #expect(state.distance == 0)
        #expect(state.speedChoice == .medium)
        #expect(state.speed == 0)
        #expect(state.seed == 3)
        #expect(!state.paused)
        #expect(state.source == .demo)
        #expect(state.speedTarget == 4 && state.easing == .standard && !state.calmMotion)
        #expect(state.mappings == JourneyWorld.allCases.map(WorldMapping.defaults(for:)))
    }

    @Test func speedChoicesAndWorldNamesMatchTheClarification() {
        #expect(SpeedChoice.allCases.map(\.unitsPerSecond) == [2, 4, 7])
        #expect(JourneyWorld.allCases.map(\.displayName) == ["Tunnel", "Landscape", "Star corridor"])
        #expect(JourneyWorld.allCases.map(\.rawValue) == [0, 1, 2])
    }

    @Test func jsonRoundTripKeepsEveryField() throws {
        let state = JourneyState(seed: .max, world: .starCorridor, distance: 12_345.678_9, speedChoice: .fast,
                                 speed: 6.5, paused: true)
        let data = try JSONEncoder().encode(state)
        let back = try JSONDecoder().decode(JourneyState.self, from: data)
        #expect(back == state)
        #expect(back.digestText == state.digestText)
    }

    @Test func aValidPayloadDecodes() throws {
        let state = try decode(payload())
        #expect(state.world == .tunnel)
        #expect(state.distance == 12.5)
        #expect(state.speed == 3.25)
        #expect(state.seed == 7)
    }

    @Test func invalidPayloadsAreRefused() {
        #expect(throws: (any Error).self) { try decode(payload(distance: "\"nan\"")) }
        #expect(throws: (any Error).self) { try decode(payload(distance: "\"inf\"")) }
        #expect(throws: (any Error).self) { try decode(payload(distance: "-1")) }
        #expect(throws: (any Error).self) { try decode(payload(speed: "\"nan\"")) }
        #expect(throws: (any Error).self) { try decode(payload(speed: "-0.5")) }
        #expect(throws: (any Error).self) { try decode(payload(world: "3")) }
        #expect(throws: (any Error).self) { try decode(payload(world: "-1")) }
        #expect(throws: (any Error).self) { try decode(payload(speedChoice: "5")) }
    }

    @Test func mutationsKeepTheRules() {
        var state = JourneyState(seed: 1)
        state.select(.landscape)
        state.select(.fast)
        state.setPaused(true)
        let accepted = state.update(distance: 40, speed: 5)
        #expect(accepted)
        #expect(state.world == .landscape && state.speedChoice == .fast && state.paused)
        let refusals = [state.update(distance: .nan, speed: 1), state.update(distance: -1, speed: 1),
                        state.update(distance: 1, speed: .infinity)]
        #expect(refusals == [false, false, false])
        #expect(state.distance == 40 && state.speed == 5)
        state.reseed()
        #expect(state.seed == 1 &+ JourneyState.seedStep)
        #expect(state.distance == 40 && state.world == .landscape)
        let clamped = JourneyState(seed: 0, distance: -5, speed: .nan)
        #expect(clamped.distance == 0 && clamped.speed == 0)
    }

    @Test func theDigestTextCoversEveryFieldAndRoundsTheSpeed() {
        let a = JourneyState(seed: 9, world: .landscape, distance: 2.5, speedChoice: .slow, speed: 1.000_000_4)
        let b = JourneyState(seed: 9, world: .landscape, distance: 2.5, speedChoice: .slow, speed: 1.000_000_1)
        #expect(a.digestText == b.digestText)
        #expect(a.digestText
            == "a07.journey.v3|world=1|distance=2.5|speedMicro=1000000|seed=9|paused=0|source=0"
            + "|speedTarget=2.0|easing=1|calm=0|map=0.1.4.1-1.1.4.1-3.1.4.1")
        var c = a
        c.setPaused(true)
        #expect(c.digestText != a.digestText)
        var d = a
        d.select(.tunnel)
        #expect(d.digestText != a.digestText)
        var e = a
        e.select(SourceKind.microphone)
        #expect(e.digestText.contains("|source=1|"))
        #expect(e.digestText != a.digestText)
        #expect(JourneyState(seed: 10, world: .landscape, distance: 2.5, speedChoice: .slow, speed: 1).digestText
            != a.digestText)
    }

    @Test func sourceNamesMatchTheClarification() {
        #expect(SourceKind.allCases.map(\.displayName) == ["Demo signal", "Microphone", "File"])
        #expect(SourceKind.allCases.map(\.rawValue) == [0, 1, 2])
    }

    @Test func aSchemaOnePayloadWithoutSourceDecodesAsDemo() throws {
        let state = try decode(payload())
        #expect(state.source == .demo)
        #expect(state.distance == 12.5 && state.speedChoice == .medium)
    }

    @Test func jsonRoundTripKeepsTheMicrophoneSource() throws {
        var state = JourneyState(seed: 4, world: .landscape, distance: 30, speedChoice: .slow, speed: 1.5)
        state.select(SourceKind.microphone)
        let back = try JSONDecoder().decode(JourneyState.self, from: JSONEncoder().encode(state))
        #expect(back == state)
        #expect(back.source == .microphone)
        #expect(try decode(payload(source: "2")).source == .file)
    }

    @Test func anUnknownSourceIsRefused() {
        #expect(throws: (any Error).self) { try decode(payload(source: "3")) }
        #expect(throws: (any Error).self) { try decode(payload(source: "-1")) }
        #expect(throws: (any Error).self) { try decode(payload(source: "\"mic\"")) }
    }

    @Test func selectingASourceKeepsTheFlight() {
        var state = JourneyState(seed: 2, world: .starCorridor, distance: 88, speedChoice: .fast, speed: 6)
        state.select(SourceKind.file)
        #expect(state.source == .file)
        #expect(state.distance == 88 && state.speed == 6 && state.world == .starCorridor && state.speedChoice == .fast)
    }

    // MARK: - Schema 3 (feature 056)

    private func mappingJSON(_ p: String = "0", _ ps: String = "1", _ l: String = "4", _ ls: String = "1") -> String {
        "{\"primary\":{\"channel\":\(p),\"sensitivity\":\(ps)},\"light\":{\"channel\":\(l),\"sensitivity\":\(ls)}}"
    }

    private func payloadThree(speedTarget: String = "5.5", easing: String = "2", calm: String = "true",
                              mappings: [String]? = nil, omit: String? = nil) -> String {
        let maps = mappings ?? [mappingJSON(), mappingJSON("1"), mappingJSON("3", "2", "0", "0")]
        var fields = ["\"world\":2", "\"distance\":40", "\"speedTarget\":\(speedTarget)", "\"speed\":3", "\"seed\":7",
                      "\"paused\":false", "\"source\":1", "\"easing\":\(easing)", "\"calmMotion\":\(calm)",
                      "\"mappings\":[\(maps.joined(separator: ","))]"]
        if let omit { fields.removeAll { $0.hasPrefix("\"\(omit)\"") } }
        return "{" + fields.joined(separator: ",") + "}"
    }

    @Test func schemaOneAndTwoPayloadsMapTheSpeedChoiceAndTakeTheDefaults() throws {
        for (choice, target) in [("0", 2.0), ("1", 4.0), ("2", 7.0)] {
            let one = try decode(payload(speedChoice: choice))
            let two = try decode(payload(speedChoice: choice, source: "1"))
            for state in [one, two] {
                #expect(state.speedTarget == target)
                #expect(state.easing == .standard && !state.calmMotion)
                #expect(state.mappings == WorldMapping.allDefaults)
                #expect(state.distance == 12.5 && state.speed == 3.25 && state.seed == 7)
            }
            #expect(two.source == .microphone)
        }
    }

    @Test func aSchemaThreePayloadDecodesEveryField() throws {
        let state = try decode(payloadThree())
        #expect(state.world == .starCorridor && state.distance == 40 && state.speed == 3 && state.source == .microphone)
        #expect(state.speedTarget == 5.5 && state.easing == .brisk && state.calmMotion)
        #expect(state.mapping(for: .starCorridor)
            == WorldMapping(primary: ChannelMapping(channel: .transient, sensitivity: .high),
                            light: ChannelMapping(channel: .low, sensitivity: .low)))
        #expect(state.mapping(for: .landscape) == WorldMapping.defaults(for: .landscape))
        #expect(try decode(payloadThree(speedTarget: "2.3")).speedTarget == 2.5)
    }

    @Test func invalidSchemaThreePayloadsAreRefused() {
        for bad in [payloadThree(speedTarget: "\"nan\""), payloadThree(speedTarget: "0.25"),
                    payloadThree(speedTarget: "7.5"), payloadThree(speedTarget: "-1"),
                    payloadThree(easing: "3"), payloadThree(easing: "-1"), payloadThree(calm: "2"),
                    payloadThree(mappings: [mappingJSON(), mappingJSON()]),
                    payloadThree(mappings: [mappingJSON(), mappingJSON(), mappingJSON(), mappingJSON()]),
                    payloadThree(mappings: [mappingJSON("5"), mappingJSON(), mappingJSON()]),
                    payloadThree(mappings: [mappingJSON(), mappingJSON("0", "3"), mappingJSON()]),
                    payloadThree(mappings: [mappingJSON(), mappingJSON(), mappingJSON("0", "1", "9")]),
                    payloadThree(omit: "easing"), payloadThree(omit: "calmMotion"), payloadThree(omit: "mappings")] {
            #expect(throws: (any Error).self) { try decode(bad) }
        }
    }

    @Test func theSpeedTargetIsSnappedAndClamped() {
        var state = JourneyState(seed: 1)
        for (input, snapped) in [(2.74, 2.5), (2.76, 3.0), (0.1, 0.5), (99, 7), (-3, 0.5)] {
            let accepted = state.setSpeedTarget(input)
            #expect(accepted && state.speedTarget == snapped)
        }
        let refusals = [state.setSpeedTarget(.nan), state.setSpeedTarget(.infinity)]
        #expect(refusals == [false, false])
        #expect(state.speedTarget == 0.5)
        state.select(SpeedChoice.fast)
        #expect(state.speedTarget == 7 && state.speedChoice == .fast)
        state.setSpeedTarget(3)
        #expect(state.speedChoice == .slow)
        state.setSpeedTarget(3.5)
        #expect(state.speedChoice == .medium)
        #expect(JourneyState(seed: 0, speedTarget: .nan).speedTarget == 4)
        #expect(JourneyState(seed: 0, speedTarget: 12).speedTarget == 7)
        #expect(JourneyState(seed: 0, speedChoice: .slow).speedTarget == 2)
    }

    @Test func mappingsAreKeptPerWorldAndReset() throws {
        var state = JourneyState(seed: 5)
        let custom = WorldMapping(primary: ChannelMapping(channel: .high, sensitivity: .high),
                                  light: ChannelMapping(channel: .transient, sensitivity: .low))
        state.setMapping(custom, for: .tunnel)
        state.select(JourneyWorld.landscape)
        #expect(state.mapping(for: .landscape) == WorldMapping.defaults(for: .landscape))
        state.select(JourneyWorld.tunnel)
        #expect(state.mapping(for: .tunnel) == custom)
        state.setEasing(.gentle)
        state.setCalmMotion(true)
        state.setSpeedTarget(1.5)
        let back = try JSONDecoder().decode(JourneyState.self, from: JSONEncoder().encode(state))
        #expect(back == state && back.digestText == state.digestText)
        #expect(state.digestText.hasSuffix("|speedTarget=1.5|easing=0|calm=1|map=2.2.3.0-1.1.4.1-3.1.4.1"))
        state.resetMappings()
        #expect(state.mappings == WorldMapping.allDefaults)
        #expect(state.easing == .gentle && state.calmMotion && state.speedTarget == 1.5)
        #expect(JourneyState(seed: 0, mappings: [custom]).mappings == WorldMapping.allDefaults)
    }

    @Test func theEncodedPayloadIsSchemaThree() throws {
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(JourneyState(seed: 2)))
        let keys = Set((object as? [String: Any])?.keys.map { $0 } ?? [])
        #expect(keys == ["world", "distance", "speedTarget", "speed", "seed", "paused", "source", "easing", "calmMotion",
                         "mappings"])
    }
}
