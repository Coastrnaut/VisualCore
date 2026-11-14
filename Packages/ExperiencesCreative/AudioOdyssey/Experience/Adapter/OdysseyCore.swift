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
// Feature 055 (A07-P02) T-A07-205 (FR-A07-220, FR-A07-221; data-model "Actions", "JourneyState" schema 2): the audio
// source joins the journey state, with four actions modelled on Music Lab's (A06):
//   source.demo                  the built-in demo signal (always accepted; the first choice and the fallback).
//   source.microphone            the live microphone. Refused with the rule `a07.permission-denied` while the mirrored
//                                permission is denied or restricted (no system prompt, the demo keeps playing);
//                                accepted while it is not determined (the presenter then asks once and falls back to
//                                the demo when refused) or granted.
//   source.file                  a picked audio file; sent by the presenter only after it opened the file. The file's
//                                name and URL stay in the presenter (actions carry numbers only), so neither is state.
//   permission.mirror [0…3]      the presenter mirrors the system microphone permission (not determined, granted,
//                                denied, restricted). Not in the digest and not in the snapshot; a reset keeps it.
// Selecting a source keeps distance, speed, world and seed: the flight never restarts (story 3, scenario 2).
//
// Snapshot schema 2: the fields of `JourneyState` (schema 1 plus `source`) as JSON with sorted keys; the preparation
// seed comes from the snapshot envelope. The migration from schema 1 adds `source = 0` (the demo signal);
// `schemaOneExample()` is the stored schema-1 payload the registry's migration check restores.
//
// Feature 056 (A07-P03) T-A07-303 (FR-A07-301–303, FR-A07-311, FR-A07-312, FR-A07-320, FR-A07-330; data-model
// "Actions", "JourneyState" schema 3): the pace and the mapping join the journey state.
//   speed.select [0…2]           kept: presets the continuous speed target to slow 2, medium 4 or fast 7 units/s.
//   speed.set [0.5…7]            the continuous speed target, snapped to the 0.5 grid (the slider); the current speed
//                                eases toward it within the active limits.
//   easing.select [0…2]          gentle, standard, brisk (rounded): the active acceleration limit × 0.33/0.66/1.0
//                                (never above the comfort maximum).
//   comfort.calm [0…1]           the in-app calm motion (1 on, 0 off): persisted and in the digest. Calm motion in
//                                effect = this or the mirrored system Reduce Motion; it selects `.reducedMotion`
//                                (speed ≤ 2.5 units/s, no sway, no roll).
//   mapping.set [t, c, s]        on the CURRENT world: response t (0 primary, 1 light) ← envelope channel c (low 0,
//                                mid 1, high 2, transient 3, overall 4) with sensitivity s (low 0, medium 1, high 2),
//                                all rounded; the other response and the other worlds keep theirs.
//   mapping.reset                every world back to its default mapping.
// The flight advances under `limits`: `.reducedMotion` while calm motion is in effect, else `.standard`, with
// `maxAcceleration` multiplied by the easing's factor; the target is `state.speedTarget`.
//
// Snapshot schema 3: the fields of `JourneyState` schema 3 (speedTarget, easing, calmMotion, mappings instead of
// speedChoice) as JSON with sorted keys. The step 2 → 3 leaves the payload as it is: `JourneyState`'s decoder reads the
// schema-1/2 shape (speedChoice → 2/4/7, standard easing, calm motion off, default mappings) and refuses a damaged one.
// `schemaOneExample()` and `schemaTwoExample()` are the stored payloads the registry's migration check restores.
//
// Feature 057 (A07-P04) T-A07-403 (FR-A07-402; research D2; data-model "Action preset.apply"): one more action.
//   preset.apply [16]            a whole journey in one step: [world, then for tunnel, landscape and star corridor:
//                                primary channel, primary sensitivity, light channel, light sensitivity, then speed
//                                target, easing, calm (0 or 1)] (`JourneyPreset.actionValues`). The engine checks the
//                                declared ranges; `JourneyPreset.fromActionValues` then refuses any value that is not
//                                a whole number naming a case (or a calm other than 0 or 1) with the rule
//                                `a07.invalid-preset`, and a refusal changes nothing. Accepted, the world, the
//                                mappings of all three worlds, the speed target, the easing and calm motion are set
//                                together; distance, current speed, seed, source and pause are kept, so the flight
//                                eases to the new target within the active limits and never jumps.
// The snapshot schema stays 3 (the action changes only fields already in the state).
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
    /// `source.microphone` while the mirrored microphone permission is denied or restricted (feature 055).
    public static let permissionDenied = "a07.permission-denied"
    /// `preset.apply` with a value that names no world, channel, sensitivity or easing, or a calm value other than 0
    /// or 1 (feature 057).
    public static let invalidPreset = "a07.invalid-preset"
}

/// The microphone permission as Audio Odyssey mirrors it from the system (feature 055). The system stays the
/// authority; the mirror only lets the core refuse the microphone as a rule while access is off. The raw values are
/// the values of the `permission.mirror` action.
public enum OdysseyMicrophoneAccess: Int, Sendable, CaseIterable {
    /// Never asked: choosing the microphone asks once.
    case notDetermined = 0
    /// Allowed: the microphone can run.
    case granted = 1
    /// Refused by the person: the microphone is refused and the way to Settings is shown.
    case denied = 2
    /// Not allowed on this device: refused like `denied`.
    case restricted = 3

    /// Whether choosing the microphone is refused as a rule (denied or restricted).
    public var refusesMicrophone: Bool { self == .denied || self == .restricted }
}

/// The state of Audio Odyssey. Schema version 3 (feature 055 adds the audio source; feature 056 the continuous speed
/// target, the easing, calm motion and the per-world mappings).
public struct OdysseyCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a07.audio-odyssey"

    /// The preparation seed; `reset()` returns to the first journey with it.
    public private(set) var preparationSeed: UInt64
    /// The domain state: world, distance, speed target, speed, seed, paused, source, easing, calm motion, mappings.
    public private(set) var state: JourneyState
    /// Whether the mirrored system Reduce Motion setting is on (not in the digest or the snapshot).
    public private(set) var reduceMotion = false
    /// The mirrored system microphone permission (feature 055; not in the digest or the snapshot).
    public private(set) var permission: OdysseyMicrophoneAccess = .notDetermined

    /// The state prepared from `seed`: the tunnel at distance 0, medium speed chosen, at rest, flying.
    init(seed: UInt64) {
        preparationSeed = seed
        state = JourneyState(seed: seed)
    }

    // MARK: Flight

    /// Whether calm motion is in effect: the in-app setting (`state.calmMotion`) or the mirrored system Reduce Motion.
    public var calmInEffect: Bool { state.calmMotion || reduceMotion }

    /// The comfort limits in force: `.reducedMotion` while calm motion is in effect, else `.standard`, with the
    /// acceleration limit multiplied by the easing's factor (0.33, 0.66 or 1; never above the comfort maximum).
    public var limits: ComfortLimits {
        var limits: ComfortLimits = calmInEffect ? .reducedMotion : .standard
        limits.maxAcceleration *= min(1, max(0, state.easing.accelerationFactor))
        return limits
    }

    /// The flight the journey state describes: its distance and speed, the speed target and the pause flag.
    public var flight: RailFlight {
        RailFlight(distance: state.distance, speed: state.speed, targetSpeed: state.speedTarget, paused: state.paused)
    }

    // MARK: Contract

    /// Schema 3 since feature 056 (A07-P03): the step from schema 1 adds the audio source (the demo signal); the step
    /// from schema 2 leaves the payload as it is, because `JourneyState`'s decoder reads the schema-1/2 shape (speed
    /// choice → 2/4/7 units/s, standard easing, calm motion off, the default mappings).
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: 3, steps: [
            1: { payload in
                var upgraded = payload
                upgraded["source"] = SourceKind.demo.rawValue
                return upgraded
            },
            2: { payload in payload },
        ])
    }

    /// The stored example of schema 1 for the registry's migration check (feature 055, T-A07-206): the feature 054
    /// payload (world, distance, speed choice, speed, seed, paused; no source) of a landscape flight under way with
    /// `seed`, with the digest its restore must give — the same journey with the demo signal, the fast preset (7 units/s)
    /// as speed target and the schema-3 defaults. Nil only if the encoding failed.
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample? {
        let expected = JourneyState(seed: seed, world: .landscape, distance: 12.5, speedChoice: .fast, speed: 3,
                                    paused: false, source: .demo)
        let payload: [String: Any] = ["world": expected.world.rawValue, "distance": expected.distance,
                                      "speedChoice": SpeedChoice.fast.rawValue, "speed": expected.speed,
                                      "seed": expected.seed, "paused": expected.paused]
        return example(version: 1, seed: seed, payload: payload, expected: expected)
    }

    /// The stored example of schema 2 for the registry's migration check (feature 056, T-A07-303): the feature 055
    /// payload (schema 1 plus `source`) of a paused star-corridor flight with the microphone chosen and the slow
    /// preset, with the digest its restore must give — the same journey with the speed target 2 units/s, standard
    /// easing, calm motion off and the default mappings. Nil only if the encoding failed.
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample? {
        let expected = JourneyState(seed: seed, world: .starCorridor, distance: 40.25, speedChoice: .slow, speed: 1.5,
                                    paused: true, source: .microphone)
        let payload: [String: Any] = ["world": expected.world.rawValue, "distance": expected.distance,
                                      "speedChoice": SpeedChoice.slow.rawValue, "speed": expected.speed,
                                      "seed": expected.seed, "paused": expected.paused,
                                      "source": SourceKind.microphone.rawValue]
        return example(version: 2, seed: seed, payload: payload, expected: expected)
    }

    /// A stored example of `version` with `payload` and the digest of a core prepared with `seed` holding `expected`.
    private static func example(version: Int, seed: UInt64, payload: [String: Any],
                                expected state: JourneyState) -> MigrationExample? {
        guard let id = ExperienceID(rawValue: experienceID) else { return nil }
        var expected = OdysseyCore(seed: seed)
        expected.state = state
        var builder = DigestBuilder(domain: id.rawValue)
        guard (try? expected.writeDigest(into: &builder)) != nil,
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let snapshot = try? ExperienceSnapshot(experience: id, schemaVersion: version, seed: seed, stepIndex: 0,
                                                     digest: builder.finish(), payload: data),
              let encoded = try? snapshot.encoded() else { return nil }
        return MigrationExample(version: version, snapshot: encoded, expectedDigest: builder.finish().hex)
    }

    /// The sixteen controls: world, speed preset, pause, resume, a new journey, the Reduce Motion mirror, (feature 055)
    /// the three sources and the microphone permission mirror, (feature 056) the continuous speed, the easing, calm
    /// motion, the mapping of the current world and the mapping reset, and (feature 057) the whole-journey
    /// `preset.apply` with its sixteen values.
    public static var controls: [ExperienceControl] {
        let access = Double(OdysseyMicrophoneAccess.notDetermined.rawValue)...Double(OdysseyMicrophoneAccess.restricted.rawValue)
        let channels = Double(EnvelopeChannel.low.rawValue)...Double(EnvelopeChannel.overall.rawValue)
        let sensitivities = Double(Sensitivity.low.rawValue)...Double(Sensitivity.high.rawValue)
        return [
            ExperienceControl(id: "world.select", ranges: [0...2]),
            ExperienceControl(id: "speed.select", ranges: [0...2]),
            ExperienceControl(id: "flight.pause"),
            ExperienceControl(id: "flight.resume"),
            ExperienceControl(id: "journey.reseed"),
            ExperienceControl(id: "comfort.reduce-motion", ranges: [0...1]),
            ExperienceControl(id: "source.demo"),
            ExperienceControl(id: "source.microphone"),
            ExperienceControl(id: "source.file"),
            ExperienceControl(id: "permission.mirror", ranges: [access]),
            ExperienceControl(id: "speed.set", ranges: [JourneyState.speedTargetRange]),
            ExperienceControl(id: "easing.select", ranges: [0...2]),
            ExperienceControl(id: "comfort.calm", ranges: [0...1]),
            ExperienceControl(id: "mapping.set", ranges: [0...1, channels, sensitivities]),
            ExperienceControl(id: "mapping.reset"),
            ExperienceControl(id: "preset.apply", ranges: presetRanges),
        ]
    }

    /// The declared ranges of the sixteen `preset.apply` values (the layout of `JourneyPreset.actionValues`).
    static var presetRanges: [ClosedRange<Double>] {
        let worlds = 0...Double(JourneyWorld.allCases.count - 1)
        let channels = Double(EnvelopeChannel.low.rawValue)...Double(EnvelopeChannel.overall.rawValue)
        let sensitivities = Double(Sensitivity.low.rawValue)...Double(Sensitivity.high.rawValue)
        let easings = Double(Easing.gentle.rawValue)...Double(Easing.brisk.rawValue)
        var ranges: [ClosedRange<Double>] = [worlds]
        for _ in JourneyWorld.allCases { ranges += [channels, sensitivities, channels, sensitivities] }
        ranges += [JourneyState.speedTargetRange, easings, 0...1]
        return ranges
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
        case "source.demo":
            state.select(SourceKind.demo)
        case "source.file":
            state.select(SourceKind.file)
        case "source.microphone":
            guard !permission.refusesMicrophone else { return .rejected(.rule(code: OdysseyRule.permissionDenied)) }
            state.select(SourceKind.microphone)
        case "permission.mirror":
            guard let x = v.first, x.isFinite, let access = OdysseyMicrophoneAccess(rawValue: Int(x.rounded())) else {
                return .rejected(.outOfRange(index: 0))
            }
            permission = access
        case "speed.set":
            guard let x = v.first, x.isFinite, JourneyState.speedTargetRange.contains(x) else {
                return .rejected(.outOfRange(index: 0))
            }
            state.setSpeedTarget(x)
        case "easing.select":
            guard let x = v.first, x.isFinite, let easing = Easing(rawValue: Int(x.rounded())) else {
                return .rejected(.outOfRange(index: 0))
            }
            state.setEasing(easing)
        case "comfort.calm":
            guard let x = v.first, x.isFinite, (0...1).contains(x.rounded()) else {
                return .rejected(.outOfRange(index: 0))
            }
            state.setCalmMotion(x.rounded() == 1)
        case "mapping.set":
            guard v.count == 3 else { return .rejected(.wrongValueCount(expected: 3, found: v.count)) }
            guard v[0].isFinite, (0...1).contains(v[0].rounded()) else { return .rejected(.outOfRange(index: 0)) }
            guard v[1].isFinite, let channel = EnvelopeChannel(rawValue: Int(v[1].rounded())) else {
                return .rejected(.outOfRange(index: 1))
            }
            guard v[2].isFinite, let sensitivity = Sensitivity(rawValue: Int(v[2].rounded())) else {
                return .rejected(.outOfRange(index: 2))
            }
            var mapping = state.mapping(for: state.world)
            let source = ChannelMapping(channel: channel, sensitivity: sensitivity)
            if v[0].rounded() == 0 { mapping.primary = source } else { mapping.light = source }
            state.setMapping(mapping, for: state.world)
        case "mapping.reset":
            state.resetMappings()
        case "preset.apply":
            return applyPreset(v)
        default:
            return .rejected(.unknownControl(action.control))
        }
        return .accepted
    }

    /// `preset.apply` (feature 057): validates all sixteen values first, then sets the world, the three mappings, the
    /// speed target, the easing and calm motion together. All-or-nothing: a refusal changes nothing. Distance, speed,
    /// seed, source and pause are kept, so the flight eases to the new target.
    private mutating func applyPreset(_ v: [Double]) -> ActionResult {
        guard v.count == JourneyPreset.actionValueCount else {
            return .rejected(.wrongValueCount(expected: JourneyPreset.actionValueCount, found: v.count))
        }
        guard let preset = JourneyPreset.fromActionValues(v) else {
            return .rejected(.rule(code: OdysseyRule.invalidPreset))
        }
        var next = state
        next.select(preset.world)
        for world in JourneyWorld.allCases { next.setMapping(preset.mappings[world.rawValue], for: world) }
        guard next.setSpeedTarget(preset.speedTarget) else { return .rejected(.rule(code: OdysseyRule.invalidPreset)) }
        next.setEasing(preset.easing)
        next.setCalmMotion(preset.calmMotion)
        state = next
        return .accepted
    }

    /// The outcome code reached once the flight has moved along the rail; the completion scenario checks it.
    public static let outcomeCode = "journey-under-way"

    /// `journey-under-way` once the travelled distance is above 0; nil at the start.
    public var outcome: ExperienceOutcome? {
        state.distance > 0 ? ExperienceOutcome(code: Self.outcomeCode) : nil
    }

    /// Back to the first journey with the preparation seed (the demo signal); the Reduce Motion and microphone
    /// permission mirrors (the system's) are kept.
    public mutating func reset() {
        state = JourneyState(seed: preparationSeed)
    }

    /// The canonical text of every journey field (`JourneyState.digestText`, `a07.journey.v3`: with the source, the
    /// speed target, the easing, calm motion and the mappings). The Reduce Motion and permission mirrors stay out.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(state.digestText)
    }

    /// The journey state (schema 3) as JSON with sorted keys.
    public func snapshotPayload() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(state)
    }

    /// The core of a schema-3 payload (schema 1 and 2 arrive migrated) with the envelope's `seed` as preparation seed;
    /// a non-finite or negative distance or speed, a speed target outside 0.5…7, or an unknown world, speed choice,
    /// source, easing, channel or sensitivity, or a mapping count other than 3, is refused (the decoding throws).
    public static func restore(payload: Data, seed: UInt64) throws -> OdysseyCore {
        var core = OdysseyCore(seed: seed)
        core.state = try JSONDecoder().decode(JourneyState.self, from: payload)
        return core
    }
}
