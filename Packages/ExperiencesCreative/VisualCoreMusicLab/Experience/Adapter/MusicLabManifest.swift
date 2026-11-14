// MusicLabManifest — feature 047 (A06-P01) T-A06-106 (FR-A06-120). The scenarios the verification runner plays for
// VisualCore Music Lab: the nine standard ones and one `fixture-<n>` per regression fixture of the planning catalog
// (the content-count audit requires the five), all short (owner rule of 2026-11-13). The audio itself runs outside the
// state (sources fill a ring buffer the presenter draws), so the scenarios exercise the state the person chooses —
// source, demo mode, demo seed, permission mirror — and the expected digests are derived as the engine computes them
// (a `DigestBuilder` with the experience id as domain), like Infinite Geometry's manifest.
#if DEBUG || VISUALCORE_AUTOMATION
import VisualCoreExperience
import VisualCoreMusicLabCore

extension MusicLabCore {
    /// The seed of every scenario.
    public static let manifestSeed: UInt64 = 7

    /// The actions of input-response, save-restore and reset: the 1 kHz tone, a new melody, back to the melody.
    public static var inputEntries: [ScenarioStep] {
        [ScenarioStep(steps: 2, action: ScriptedAction("demo.mode", [2]), result: "accepted"),
         ScenarioStep(steps: 2, action: ScriptedAction("demo.reseed"), result: "accepted"),
         ScenarioStep(steps: 2, action: ScriptedAction("demo.mode", [0]), result: "accepted")]
    }

    /// The entries of rejection: a demo mode out of range and the microphone while access is denied.
    public static var rejectionEntries: [ScenarioStep] {
        [ScenarioStep(steps: 0, action: ScriptedAction("demo.mode", [9]), result: "action.out-of-range"),
         ScenarioStep(steps: 0, action: ScriptedAction("permission.mirror", [2]), result: "accepted"),
         ScenarioStep(steps: 0, action: ScriptedAction("source.microphone"),
                      result: "action.rule." + MusicLabRule.permissionDenied)]
    }

    /// The digest of the core prepared with `seed` after the accepted actions of `entries`, computed as the engine
    /// computes it; nil when the digest cannot be written.
    public static func expectedDigest(for id: ExperienceID, seed: UInt64, entries: [ScenarioStep]) -> String? {
        var core = MusicLabCore(seed: seed)
        for entry in entries {
            guard let action = entry.action else { continue }
            _ = core.apply(ExperienceAction(control: action.control, values: action.values, step: 0))
        }
        var builder = DigestBuilder(domain: id.rawValue)
        do { try core.writeDigest(into: &builder) } catch { return nil }
        return builder.finish().hex
    }

    /// The entries of the five regression fixtures of the planning catalog, in its order:
    /// 1. a synthetic sine wave peaks at the expected bin: the 440 Hz tone, then the 1 kHz tone (the spectrum itself is
    ///    proved by `SpectrumAnalyzerTests`; this scenario drives the tone sources through the session);
    /// 2. silence yields near-zero features and a stable display: the silence mode;
    /// 3. the audio callback never allocates: a long run of steps on the demo melody (the write path is proved
    ///    allocation-free by the DSP tests and review; the scenario keeps the source running while frames draw);
    /// 4. the permission-denied path stays usable in demo mode: access denied, the microphone refused, the demo kept;
    /// 5. interruption and route changes leave nothing stuck: file and demo sources switched back and forth (the
    ///    suspend-resume and teardown-reentry scenarios add the lifecycle side).
    public static var fixtureEntries: [[ScenarioStep]] {
        func step(_ control: String, _ values: [Double] = [], _ result: String = "accepted", steps: Int = 1) -> ScenarioStep {
            ScenarioStep(steps: steps, action: ScriptedAction(control, values), result: result)
        }
        return [
            [step("demo.mode", [1]), step("demo.mode", [2])],
            [step("demo.mode", [3])],
            [step("demo.reseed", steps: 30)],
            [step("permission.mirror", [2]), step("source.microphone", [], "action.rule." + MusicLabRule.permissionDenied),
             step("demo.mode", [1])],
            [step("source.file"), step("source.demo"), step("source.file"), step("source.demo")],
        ]
    }

    /// The manifest of the experience `id`.
    public static func manifest(for id: ExperienceID, seed: UInt64 = manifestSeed) -> ScenarioManifest {
        let input = inputEntries
        let initial = expectedDigest(for: id, seed: seed, entries: [])
        let final = expectedDigest(for: id, seed: seed, entries: input)
        var specs = [
            ScenarioSpec(name: "launch-first-frame", seed: seed, entries: [],
                         expect: ScenarioExpectations(initialDigest: initial)),
            ScenarioSpec(name: "input-response", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, finalDigest: final)),
            ScenarioSpec(name: "completion", seed: seed, entries: [
                ScenarioStep(steps: 2, action: ScriptedAction("demo.mode", [1]), result: "accepted"),
            ], expect: ScenarioExpectations(outcome: outcomeCode)),
            ScenarioSpec(name: "rejection", seed: seed, entries: rejectionEntries),
            ScenarioSpec(name: "save-restore", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, finalDigest: final)),
            ScenarioSpec(name: "reset", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, resetDigest: true)),
            ScenarioSpec(name: "suspend-resume", seed: seed, entries: []),
            ScenarioSpec(name: "teardown-reentry", seed: seed, entries: [], cycles: 5),
            ScenarioSpec(name: "cancel-prepare", seed: seed, entries: []),
        ]
        for (index, entries) in fixtureEntries.enumerated() {
            specs.append(ScenarioSpec(name: "fixture-\(index + 1)", seed: seed, entries: entries,
                                      expect: ScenarioExpectations(initialDigest: initial,
                                                                   finalDigest: expectedDigest(for: id, seed: seed,
                                                                                               entries: entries))))
        }
        return ScenarioManifest(experience: id, kind: .creative, scenarios: specs)
    }
}
#endif
