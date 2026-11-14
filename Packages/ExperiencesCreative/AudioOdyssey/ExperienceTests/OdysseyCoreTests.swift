// OdysseyCoreTests — feature 054 (A07-P01) T-A07-104 (FR-A07-120, FR-A07-121, FR-A07-122; SC-A07-102). The adapter
// core of Audio Odyssey against the experience contract, short runs only (simulated steps, no wall clock): conformance
// over four seeds; the first journey; every action changing the digest and the Reduce Motion mirror leaving it as it
// was; a world switch keeping distance and speed; the speed easing within the standard limits; Reduce Motion capping
// the speed at 2.5 with no sway; pause easing to rest with the journey kept and resume continuing; refusals; the
// snapshot round trip, a damaged payload refused, and reset.
import Foundation
import Testing
@testable import AudioOdysseyExperience
import AudioOdysseyCore
import VisualCoreExperience
import VisualCoreMath

private let id = ExperienceID(rawValue: OdysseyCore.experienceID)!

private func engine(seed: UInt64 = 7) async throws -> ExperienceEngine<OdysseyCore> {
    var engine = ExperienceEngine<OdysseyCore>(id: id)
    try await engine.prepare(seed: seed)
    try engine.activate()
    return engine
}

private func core(_ engine: ExperienceEngine<OdysseyCore>) throws -> OdysseyCore {
    try #require(engine.core)
}

@Suite struct OdysseyCoreTests {
    @Test func controlsAndId() {
        #expect(OdysseyCore.experienceID == "a07.audio-odyssey")
        #expect(AudioOdysseyExperience.id?.rawValue == "a07.audio-odyssey")
        #expect(OdysseyCore.controls.map(\.id)
                == ["world.select", "speed.select", "flight.pause", "flight.resume", "journey.reseed",
                    "comfort.reduce-motion"])
        #expect(OdysseyCore.migrations.currentVersion == 1)
    }

    @Test func conformancePassesOverFourSeeds() async {
        let plan = ConformancePlan(
            seeds: [1, 7, 42, 0xFFFF_FFFF_FFFF_FFFF], stepsPerSegment: 12,
            actions: [ScriptedAction("speed.select", [2]), ScriptedAction("world.select", [1]),
                      ScriptedAction("flight.pause"), ScriptedAction("journey.reseed"),
                      ScriptedAction("flight.resume"), ScriptedAction("world.select", [2]),
                      ScriptedAction("comfort.reduce-motion", [1]), ScriptedAction("speed.select", [0])],
            rejected: [ScriptedAction("world.select", [3]), ScriptedAction("world.select", [.nan]),
                       ScriptedAction("speed.select", [-1]), ScriptedAction("flight.pause", [1]),
                       ScriptedAction("flight.resume"), ScriptedAction("comfort.reduce-motion", [2]),
                       ScriptedAction("bogus")])
        let report = await ExperienceConformance.run(OdysseyCore.self, id: id, plan: plan)
        for entry in report.entries { #expect(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    @Test func theFirstJourneyIsTheTunnelAtRestWithMediumChosen() async throws {
        let core = try core(try await engine(seed: 99))
        #expect(core.state == JourneyState(seed: 99))
        #expect(core.state.world == .tunnel)
        #expect(core.state.speedChoice == .medium)
        #expect(core.state.distance == 0 && core.state.speed == 0 && !core.state.paused)
        #expect(core.outcome == nil)
        #expect(!core.reduceMotion)
    }

    @Test func theFlightStartsWithoutAPromptAndEasesTowardMedium() async throws {
        var engine = try await engine()
        try engine.run(steps: 120)   // 1 s
        let state = try core(engine).state
        #expect(abs(state.speed - 1.5) < 1e-9, "1 s at 1.5 units/s² from rest: \(state.speed)")
        #expect(state.distance > 0)
        #expect(try core(engine).outcome?.code == OdysseyCore.outcomeCode)
    }

    @Test func eachActionChangesTheDigestAndTheMirrorDoesNot() async throws {
        var engine = try await engine()
        var last = try engine.digest()
        for (control, values) in [("world.select", [1.0]), ("world.select", [2.0]), ("speed.select", [2.0]),
                                  ("flight.pause", []), ("flight.resume", []), ("journey.reseed", [])] {
            #expect(engine.handle(control: control, values: values).isAccepted, "\(control) \(values)")
            let now = try engine.digest()
            #expect(now != last, "\(control) \(values) changes the digest")
            last = now
        }
        #expect(engine.handle(control: "comfort.reduce-motion", values: [1]).isAccepted)
        #expect(try core(engine).reduceMotion)
        #expect(try engine.digest() == last, "the Reduce Motion mirror is not in the digest")
    }

    @Test func aWorldSwitchKeepsDistanceAndSpeed() async throws {
        var engine = try await engine()
        try engine.run(steps: 240)
        let before = try core(engine).state
        for world in [JourneyWorld.landscape, .starCorridor, .tunnel, .starCorridor] {
            #expect(engine.handle(control: "world.select", values: [Double(world.rawValue)]).isAccepted)
            let state = try core(engine).state
            #expect(state.world == world)
            #expect(state.distance == before.distance)
            #expect(state.speed == before.speed)
            #expect(state.speedChoice == before.speedChoice && state.seed == before.seed)
        }
    }

    @Test func speedEasesWithinTheStandardLimits() async throws {
        var engine = try await engine()
        #expect(engine.handle(control: "speed.select", values: [0]).isAccepted)
        try engine.run(steps: 240)
        #expect(abs(try core(engine).state.speed - 2) < 1e-9, "slow reached")
        #expect(engine.handle(control: "speed.select", values: [2]).isAccepted)
        let limits = ComfortLimits.standard
        let dt = OdysseyCore.stepDuration
        var previous = try core(engine).state
        for _ in 0..<480 {   // 4 s: 2 → 7 takes 5 / 1.5 ≈ 3.33 s
            try engine.run(steps: 1)
            let state = try core(engine).state
            #expect(state.speed <= limits.maxSpeed)
            #expect(abs(state.speed - previous.speed) <= limits.maxAcceleration * dt + 1e-12)
            #expect(state.distance >= previous.distance)
            previous = state
        }
        #expect(abs(previous.speed - 7) < 1e-9, "fast reached within the time the limit allows")
    }

    @Test func reduceMotionCapsTheSpeedAndRemovesTheSway() async throws {
        var engine = try await engine()
        #expect(engine.handle(control: "comfort.reduce-motion", values: [1]).isAccepted)
        #expect(try core(engine).limits == .reducedMotion)
        #expect(engine.handle(control: "speed.select", values: [2]).isAccepted)
        var top = 0.0
        for _ in 0..<12 {   // 6 s in half-second segments
            try engine.run(steps: 60)
            let core = try core(engine)
            top = max(top, core.state.speed)
            #expect(core.state.speed <= ComfortLimits.reducedMotion.maxSpeed + 1e-12)
            #expect(core.flight.sway(limits: core.limits) == 0)
        }
        #expect(abs(top - 2.5) < 1e-9, "the reduced cap is reached and held: \(top)")
        // Off again: the standard limits apply and the speed rises past the reduced cap.
        #expect(engine.handle(control: "comfort.reduce-motion", values: [0]).isAccepted)
        try engine.run(steps: 120)
        #expect(try core(engine).state.speed > 2.5)
    }

    @Test func pauseEasesToRestAndKeepsTheJourneyAndResumeContinues() async throws {
        var engine = try await engine()
        try engine.run(steps: 360)   // 3 s: speed 4 reached after 2.67 s
        #expect(engine.handle(control: "flight.pause").isAccepted)
        let paused = try core(engine).state
        try engine.run(steps: 60)
        #expect(try core(engine).state.speed < paused.speed && core(engine).state.speed > 0, "eased, not stopped at once")
        try engine.run(steps: 360)
        let rest = try core(engine).state
        #expect(rest.speed == 0)
        try engine.run(steps: 120)
        let still = try core(engine).state
        #expect(still.distance == rest.distance, "held at rest")
        #expect(still.world == paused.world && still.seed == paused.seed && still.speedChoice == paused.speedChoice)
        #expect(still.paused)
        #expect(engine.handle(control: "flight.pause") == .rejected(.rule(code: OdysseyRule.alreadyPaused)))
        #expect(engine.handle(control: "flight.resume").isAccepted)
        try engine.run(steps: 120)
        let resumed = try core(engine).state
        #expect(resumed.distance > still.distance && resumed.speed > 0)
        #expect(engine.handle(control: "flight.resume") == .rejected(.rule(code: OdysseyRule.notPaused)))
    }

    @Test func outOfRangeAndMalformedActionsAreRefused() async throws {
        var engine = try await engine()
        let before = try engine.digest()
        #expect(engine.handle(control: "world.select", values: [3]) == .rejected(.outOfRange(index: 0)))
        #expect(engine.handle(control: "speed.select", values: []) == .rejected(.wrongValueCount(expected: 1, found: 0)))
        #expect(engine.handle(control: "journey.reseed", values: [1]) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        #expect(engine.handle(control: "bogus") == .rejected(.unknownControl("bogus")))
        #expect(try engine.digest() == before)
    }

    @Test func theSnapshotRoundTripsIntoAnotherSession() async throws {
        var first = try await engine(seed: 7)
        try first.run(steps: 200)
        #expect(first.handle(control: "world.select", values: [2]).isAccepted)
        #expect(first.handle(control: "speed.select", values: [0]).isAccepted)
        #expect(first.handle(control: "journey.reseed").isAccepted)
        try first.run(steps: 50)
        #expect(first.handle(control: "flight.pause").isAccepted)
        let snapshot = try first.snapshot()
        #expect(snapshot.schemaVersion == 1)
        let decoded = try ExperienceSnapshot(data: snapshot.encoded())
        var second = try await engine(seed: 3)
        try second.restore(decoded)
        #expect(try second.digest() == first.digest())
        #expect(try core(second).state == core(first).state)
        #expect(try core(second).preparationSeed == 7)
        // Both continue identically.
        try first.run(steps: 30)
        try second.run(steps: 30)
        #expect(try second.digest() == first.digest())
    }

    @Test func aDamagedPayloadIsRefusedAndChangesNothing() async throws {
        var engine = try await engine()
        let before = try engine.digest()
        for payload in [#"{"distance":-1,"paused":false,"seed":7,"speed":0,"speedChoice":1,"world":0}"#,
                        #"{"distance":0,"paused":false,"seed":7,"speed":0,"speedChoice":1,"world":5}"#,
                        #"{"distance":0,"paused":false,"seed":7,"speed":0,"speedChoice":9,"world":0}"#] {
            let snapshot = try ExperienceSnapshot(experience: id, schemaVersion: 1, seed: 7, stepIndex: 0, digest: before,
                                                  payload: Data(payload.utf8))
            #expect(throws: ExperienceError.self) { try engine.restore(snapshot) }
            #expect(try engine.digest() == before)
        }
    }

    @Test func resetReturnsToTheFirstJourneyAndKeepsTheMirror() async throws {
        var engine = try await engine(seed: 11)
        let prepared = try engine.digest()
        #expect(engine.handle(control: "comfort.reduce-motion", values: [1]).isAccepted)
        try engine.run(steps: 100)
        #expect(engine.handle(control: "world.select", values: [1]).isAccepted)
        #expect(engine.handle(control: "journey.reseed").isAccepted)
        try engine.reset()
        #expect(try engine.digest() == prepared)
        #expect(try core(engine).state == JourneyState(seed: 11))
        #expect(try core(engine).reduceMotion)
    }

    @Test func theSameStepsGiveTheSameJourney() async throws {
        func play(_ e: inout ExperienceEngine<OdysseyCore>) throws {
            try e.run(steps: 90)
            _ = e.handle(control: "speed.select", values: [2])
            try e.run(steps: 90)
            _ = e.handle(control: "world.select", values: [1])
            try e.run(steps: 90)
        }
        var a = try await engine(seed: 5)
        var b = try await engine(seed: 5)
        try play(&a)
        try play(&b)
        #expect(try a.digest() == b.digest())
        #expect(try core(a).state == core(b).state)
    }
}
