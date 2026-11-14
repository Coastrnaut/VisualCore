// JourneyStateTests — feature 054 (A07-P01) T-A07-103 (FR-A07-121; data-model "JourneyState", schema 1). The state
// rules of Audio Odyssey, host-free and short: the first state, the JSON round trip, refusal of invalid payloads, the
// mutating rules and the digest text.
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
                         speed: String = "3.25") -> String {
        "{\"world\":\(world),\"distance\":\(distance),\"speedChoice\":\(speedChoice),\"speed\":\(speed),"
            + "\"seed\":7,\"paused\":false}"
    }

    @Test func theFirstStateIsTheTunnelAtMediumSpeed() {
        let state = JourneyState(seed: 3)
        #expect(JourneyState.schemaVersion == 1)
        #expect(state.world == .tunnel)
        #expect(state.distance == 0)
        #expect(state.speedChoice == .medium)
        #expect(state.speed == 0)
        #expect(state.seed == 3)
        #expect(!state.paused)
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
            == "a07.journey.v1|world=1|distance=2.5|speedChoice=0|speedMicro=1000000|seed=9|paused=0")
        var c = a
        c.setPaused(true)
        #expect(c.digestText != a.digestText)
        var d = a
        d.select(.tunnel)
        #expect(d.digestText != a.digestText)
        #expect(JourneyState(seed: 10, world: .landscape, distance: 2.5, speedChoice: .slow, speed: 1).digestText
            != a.digestText)
    }
}
