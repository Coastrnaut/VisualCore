// MusicLabCore — feature 047 (A06-P01) T-A06-104 (FR-A06-104, FR-A06-120, FR-A06-121; data-model "MusicLabState",
// "Actions"). The state of VisualCore Music Lab as an experience: a `MusicLabState` (selected source, demo seed and
// mode, mirrored microphone permission) and the preparation seed. Samples are never state; the presenter owns the
// audio sources and the sample ring buffer.
//
// Actions (all carried as numbers, as every experience action is):
//   source.demo, source.microphone, source.file  select a source. The microphone is refused with the rule
//                                                `a06.permission-denied` while the mirrored permission is denied or
//                                                restricted; while it is not determined it is accepted ("requesting":
//                                                the presenter asks once and falls back to the demo when refused).
//                                                `source.file` is sent by the presenter after it opened the picked
//                                                file; selecting the source already selected is accepted and changes
//                                                nothing (a second file replaces the first in the presenter).
//   demo.mode [0…3]                              melody, 440 Hz tone, 1 kHz tone, silence (rounded).
//   demo.reseed                                  a new melody: the demo seed moves on by the golden-ratio step.
//   permission.mirror [0…3]                      the presenter mirrors the system permission (not determined,
//                                                granted, denied, restricted); not in the digest, not in the snapshot.
//
// The file name decision: an action carries numbers only and the presenter cannot reach the engine's core by any other
// path, so the picked file's name (and its security-scoped URL) stays in the presenter, which records it in its display
// copy of the state (`MusicLabState.recordFileName`). The digest therefore holds the source, the demo seed and the demo
// mode, not the file name (a deviation from data-model.md's digest list, recorded here). A restored session whose
// source is a file cannot reopen the file (the URL is not storable); the presenter says so and draws silence until the
// person picks a file or another source.
//
// Snapshot schema 1: the persisted fields of `MusicLabState` (source, demoSeed, demoMode) as JSON; the preparation
// seed comes from the snapshot envelope.
import Foundation
import VisualCoreExperience
import VisualCoreMusicLabCore
import VisualCorePersistence

/// The state of VisualCore Music Lab. Schema version 1.
public struct MusicLabCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a06.visualcore-music-lab"

    /// The preparation seed; `reset()` returns to the demo melody with it.
    public private(set) var seed: UInt64
    /// The domain state (its `fileName` stays nil here; see the file name decision above).
    public private(set) var state: MusicLabState

    /// The state prepared from `seed`: the demo melody with `seed` as demo seed.
    init(seed: UInt64) {
        self.seed = seed
        state = MusicLabState(seed: seed)
    }

    // MARK: Contract

    /// Schema 2 since feature 049 (A06-P03, FR-A06-313): the step from schema 1 adds the Bars scene and the default
    /// mapping choices of every scene.
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: 2, steps: [
            1: { payload in
                var upgraded = payload
                upgraded["scene"] = MusicLabScene.bars.rawValue
                upgraded["mappings"] = MusicLabScene.defaultMappings().map { list in
                    list.map { ["feature": $0.feature, "gain": $0.gain] as [String: Any] }
                }
                return upgraded
            },
        ])
    }

    /// The ten controls: three sources, the demo mode, a new melody, the permission mirror, (feature 049) the scene, a
    /// mapping choice and a scene's mapping reset, and (feature 050) applying a preset: the scene and up to three
    /// choices in one action.
    public static var controls: [ExperienceControl] {
        let modes = Double(MusicLabState.demoModeRange.lowerBound)...Double(MusicLabState.demoModeRange.upperBound)
        let access = Double(MicrophoneAccess.notDetermined.rawValue)...Double(MicrophoneAccess.restricted.rawValue)
        return [
            ExperienceControl(id: "source.demo"),
            ExperienceControl(id: "source.microphone"),
            ExperienceControl(id: "source.file"),
            ExperienceControl(id: "demo.mode", ranges: [modes]),
            ExperienceControl(id: "demo.reseed"),
            ExperienceControl(id: "permission.mirror", ranges: [access]),
            ExperienceControl(id: "scene.select", ranges: [0...2]),
            ExperienceControl(id: "mapping.set", ranges: [0...2, 0...2, 0...6, MappingChoice.gainRange]),
            ExperienceControl(id: "mapping.reset", ranges: [0...2]),
            ExperienceControl(id: "preset.apply", ranges: [0...2, 0...6, MappingChoice.gainRange, 0...6,
                                                           MappingChoice.gainRange, 0...6, MappingChoice.gainRange]),
        ]
    }

    /// The demo melody with `seed` as its seed (`demoSeed = seed`).
    public static func prepare(seed: UInt64) async throws -> MusicLabCore {
        try Task.checkCancellation()
        return MusicLabCore(seed: seed)
    }

    /// Nothing: the state changes only through actions (the audio runs outside the state).
    public mutating func update(step: Int) {}

    /// Carries out a well-formed action (the engine checked the control, the value count and the ranges).
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        switch action.control {
        case "source.demo":
            state.select(.demo)
        case "source.file":
            state.select(.file)
        case "source.microphone":
            if let code = state.select(.microphone) { return .rejected(.rule(code: code)) }
        case "demo.mode":
            guard let x = v.first else { return .rejected(.wrongValueCount(expected: 1, found: 0)) }
            guard state.setDemoMode(Int(x.rounded())) else { return .rejected(.outOfRange(index: 0)) }
        case "demo.reseed":
            state.reseed()
        case "permission.mirror":
            guard let x = v.first else { return .rejected(.wrongValueCount(expected: 1, found: 0)) }
            guard let access = MicrophoneAccess(rawValue: Int(x.rounded())) else {
                return .rejected(.outOfRange(index: 0))
            }
            state.permission = access
        case "scene.select":
            guard let x = v.first, let scene = MusicLabScene(rawValue: Int(x.rounded())) else {
                return .rejected(.outOfRange(index: 0))
            }
            state.select(scene: scene)
        case "mapping.set":
            guard v.count == 4 else { return .rejected(.wrongValueCount(expected: 4, found: v.count)) }
            guard let scene = MusicLabScene(rawValue: Int(v[0].rounded())) else { return .rejected(.outOfRange(index: 0)) }
            guard let choice = MappingChoice(feature: Int(v[2].rounded()), gain: v[3]) else {
                return .rejected(.outOfRange(index: 2))
            }
            if let code = state.setMapping(scene: scene, slot: Int(v[1].rounded()), choice: choice) {
                return .rejected(.rule(code: code))
            }
        case "mapping.reset":
            guard let x = v.first, let scene = MusicLabScene(rawValue: Int(x.rounded())) else {
                return .rejected(.outOfRange(index: 0))
            }
            state.resetMappings(scene: scene)
        case "preset.apply":
            return applyPreset(v)
        default:
            return .rejected(.unknownControl(action.control))
        }
        return .accepted
    }

    /// `preset.apply [scene, feature₀, gain₀, feature₁, gain₁, feature₂, gain₂]` (feature 050, FR-A06-413): sets the scene
    /// and its choices; slots beyond the scene's parameter count must be zero (rule `a06.no-such-parameter`), an invalid
    /// choice is out of range. All-or-nothing: a refusal changes nothing.
    private mutating func applyPreset(_ v: [Double]) -> ActionResult {
        guard v.count == 7 else { return .rejected(.wrongValueCount(expected: 7, found: v.count)) }
        guard let scene = MusicLabScene(rawValue: Int(v[0].rounded())) else { return .rejected(.outOfRange(index: 0)) }
        let count = scene.parameters.count
        var choices: [MappingChoice] = []
        for slot in 0..<3 {
            let feature = v[1 + slot * 2], gain = v[2 + slot * 2]
            if slot < count {
                guard let choice = MappingChoice(feature: Int(feature.rounded()), gain: gain) else {
                    return .rejected(.outOfRange(index: 1 + slot * 2))
                }
                choices.append(choice)
            } else if feature != 0 || gain != 0 {
                return .rejected(.rule(code: MusicLabRule.noSuchParameter))
            }
        }
        var next = state
        next.select(scene: scene)
        for (slot, choice) in choices.enumerated() { next.setMapping(scene: scene, slot: slot, choice: choice) }
        state = next
        return .accepted
    }

    /// The outcome code reached once a source is selected — always, since every state selects one (the demo melody
    /// after the preparation); the completion scenario checks it after a source change (feature 195 outcomes).
    public static let outcomeCode = "source-selected"

    /// `source-selected` in every state (a source is always selected).
    public var outcome: ExperienceOutcome? { ExperienceOutcome(code: Self.outcomeCode) }

    /// Back to the demo melody with the preparation seed; the permission mirror (the system's, not the state's) is
    /// kept.
    public mutating func reset() {
        let permission = state.permission
        state = MusicLabState(seed: seed)
        state.permission = permission
    }

    /// The source, the demo seed, the demo mode, the scene and every mapping choice (feature and gain), in this order.
    /// The file name and the permission mirror stay out.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(state.source.rawValue)
        builder.add(state.demoSeed)
        builder.add(state.demoMode)
        builder.add(state.scene.rawValue)
        for list in state.mappings {
            for choice in list {
                builder.add(choice.feature)
                try builder.add(choice.gain)
            }
        }
    }

    /// The persisted fields of the state as JSON with sorted keys.
    public func snapshotPayload() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(state)
    }

    /// The core of a schema-2 payload (schema 1 arrives migrated) with the envelope's `seed` as preparation seed; a
    /// demo mode outside 0…3, an unknown source or scene, or invalid mappings are refused (the decoding throws).
    public static func restore(payload: Data, seed: UInt64) throws -> MusicLabCore {
        var core = MusicLabCore(seed: seed)
        core.state = try JSONDecoder().decode(MusicLabState.self, from: payload)
        return core
    }
}
