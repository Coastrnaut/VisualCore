// OdysseyCore — feature 054 (A07-P01) T-A07-104 (FR-A07-120, FR-A07-121, FR-A07-122; data-model "JourneyState",
// "Actions"). The state of Audio Odyssey as an experience: a `JourneyState` (world, unwrapped distance, speed choice,
// current speed, seed, paused), the preparation seed and the mirrored Reduce Motion setting. Each host step advances a
// `RailFlight` built from the journey state by the step duration under `ComfortLimits.standard` (or
// `.reducedMotion`) and writes the distance and speed back, so the flight lives entirely in the journey state; the
// presenter owns everything else (the rail, the piece meshes, the drawing).
//
// Actions (all carried as numbers, as every experience action is):
//   world.select [0…2]           tunnel, landscape, star corridor (rounded); distance and speed are kept, so the new
//                                world appears at the same rail position (story 1, scenario 2). The world already
//                                shown is accepted and changes nothing.
//   speed.select [0…2]           slow 2, medium 4, fast 7 units/s (rounded); the current speed eases toward it within
//                                the active comfort limits, never jumps.
//   flight.pause                 the flight eases to a stop; distance, world and speed choice are kept. Refused with
//                                the rule `a07.already-paused` while paused.
//   flight.resume                the flight eases back to the chosen speed from where it stopped. Refused with the
//                                rule `a07.not-paused` while flying.
//   journey.reseed               a new journey: the seed moves on by the golden-ratio step (a new rail and new pieces);
//                                distance, world and speed are kept.
//   comfort.reduce-motion [0…1]  the presenter mirrors the system Reduce Motion setting (1 on, 0 off). It selects the
//                                reduced comfort limits (speed ≤ 2.5 units/s, acceleration 0.75, no sway). Not in the
//                                digest and not in the snapshot; a reset keeps it.
//
// The Reduce Motion decision: data-model.md calls Reduce Motion a host setting, not an action. A core is prepared from
// a seed alone and the presenter cannot reach it except through actions, so the setting arrives as a mirror action
// like Music Lab's `permission.mirror` (recorded here as the deviation). The presenter sends it once the experience is
// active whenever the core's mirror differs from the factory's `reduceMotion`; a restored core starts with it off and
// is mirrored again on the next frame.
//
// Leaving and returning: a suspended experience runs no steps (the engine), so the flight holds still while away and
// continues from the saved state on return without catching up.
//
// Snapshot schema 1: the fields of `JourneyState` as JSON with sorted keys; the preparation seed comes from the
// snapshot envelope.
import Foundation
import AudioOdysseyCore
import VisualCoreExperience
import VisualCoreMath
import VisualCorePersistence

/// The rule codes of Audio Odyssey's refusals.
public enum OdysseyRule {
    /// `flight.pause` while the flight is already paused.
    public static let alreadyPaused = "a07.already-paused"
    /// `flight.resume` while the flight is not paused.
    public static let notPaused = "a07.not-paused"
}

/// The state of Audio Odyssey. Schema version 1.
public struct OdysseyCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a07.audio-odyssey"

    /// The preparation seed; `reset()` returns to the first journey with it.
    public private(set) var preparationSeed: UInt64
    /// The domain state: world, distance, speed choice, speed, seed, paused.
    public private(set) var state: JourneyState
    /// Whether the mirrored system Reduce Motion setting is on (not in the digest or the snapshot).
    public private(set) var reduceMotion = false

    /// The state prepared from `seed`: the tunnel at distance 0, medium speed chosen, at rest, flying.
    init(seed: UInt64) {
        preparationSeed = seed
        state = JourneyState(seed: seed)
    }

    // MARK: Flight

    /// The comfort limits in force: `.reducedMotion` while Reduce Motion is mirrored on, else `.standard`.
    public var limits: ComfortLimits { reduceMotion ? .reducedMotion : .standard }

    /// The flight the journey state describes: its distance and speed, the chosen speed as target and the pause flag.
    public var flight: RailFlight {
        RailFlight(distance: state.distance, speed: state.speed, targetSpeed: state.speedChoice.unitsPerSecond,
                   paused: state.paused)
    }

    // MARK: Contract

    /// Schema 1 (feature 054); no migrations yet.
    public static var migrations: MigrationChain { MigrationChain(currentVersion: 1) }

    /// The six controls: world, speed, pause, resume, a new journey and the Reduce Motion mirror.
    public static var controls: [ExperienceControl] {
        [
            ExperienceControl(id: "world.select", ranges: [0...2]),
            ExperienceControl(id: "speed.select", ranges: [0...2]),
            ExperienceControl(id: "flight.pause"),
            ExperienceControl(id: "flight.resume"),
            ExperienceControl(id: "journey.reseed"),
            ExperienceControl(id: "comfort.reduce-motion", ranges: [0...1]),
        ]
    }

    /// The first journey with `seed` as its seed.
    public static func prepare(seed: UInt64) async throws -> OdysseyCore {
        try Task.checkCancellation()
        return OdysseyCore(seed: seed)
    }

    /// Advances the flight by one step (`stepDuration`, 1/120 s) under the active comfort limits and records its
    /// distance and speed in the journey state.
    public mutating func update(step: Int) {
        var flight = self.flight
        flight.advance(by: Self.stepDuration, limits: limits)
        state.update(distance: flight.distance, speed: flight.speed)
    }

    /// Carries out a well-formed action (the engine checked the control, the value count and the ranges).
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        switch action.control {
        case "world.select":
            guard let x = v.first, x.isFinite, let world = JourneyWorld(rawValue: Int(x.rounded())) else {
                return .rejected(.outOfRange(index: 0))
            }
            state.select(world)
        case "speed.select":
            guard let x = v.first, x.isFinite, let choice = SpeedChoice(rawValue: Int(x.rounded())) else {
                return .rejected(.outOfRange(index: 0))
            }
            state.select(choice)
        case "flight.pause":
            guard !state.paused else { return .rejected(.rule(code: OdysseyRule.alreadyPaused)) }
            state.setPaused(true)
        case "flight.resume":
            guard state.paused else { return .rejected(.rule(code: OdysseyRule.notPaused)) }
            state.setPaused(false)
        case "journey.reseed":
            state.reseed()
        case "comfort.reduce-motion":
            guard let x = v.first, x.isFinite, (0...1).contains(x.rounded()) else {
                return .rejected(.outOfRange(index: 0))
            }
            reduceMotion = x.rounded() == 1
        default:
            return .rejected(.unknownControl(action.control))
        }
        return .accepted
    }

    /// The outcome code reached once the flight has moved along the rail; the completion scenario checks it.
    public static let outcomeCode = "journey-under-way"

    /// `journey-under-way` once the travelled distance is above 0; nil at the start.
    public var outcome: ExperienceOutcome? {
        state.distance > 0 ? ExperienceOutcome(code: Self.outcomeCode) : nil
    }

    /// Back to the first journey with the preparation seed; the Reduce Motion mirror (the system's) is kept.
    public mutating func reset() {
        state = JourneyState(seed: preparationSeed)
    }

    /// The canonical text of every journey field (`JourneyState.digestText`). The Reduce Motion mirror stays out.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(state.digestText)
    }

    /// The journey state as JSON with sorted keys.
    public func snapshotPayload() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(state)
    }

    /// The core of a schema-1 payload with the envelope's `seed` as preparation seed; a non-finite or negative distance
    /// or speed, or an unknown world or speed choice, is refused (the decoding throws).
    public static func restore(payload: Data, seed: UInt64) throws -> OdysseyCore {
        var core = OdysseyCore(seed: seed)
        core.state = try JSONDecoder().decode(JourneyState.self, from: payload)
        return core
    }
}
