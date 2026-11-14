// ScopeManifest — feature 061 (A08-P01) T-A08-107 (FR-A08-120; SC-A08-105). The scenarios the verification runner plays
// for Oscilloscope Studio: the nine standard ones and one `fixture-<n>` per regression fixture this phase proves (the
// known 1 kHz sine at 1 ms/div gives 10 display periods; the 1 kHz sine gives the expected spectrum bin; a level beyond
// the signal gives no trigger; gain beyond full scale is marked clipped; the sweep triggers on a falling slope — five,
// the planning catalog's fixture count), all short (owner rule of 2026-11-13). Host steps change nothing in the scope state, so
// the expected digests are derived by playing the entries on a core exactly as the engine plays them (the steps of an
// entry, then its action) and digesting it with the experience id as domain, like Audio Odyssey's manifest. The
// measurements themselves are proved by `ScopeAcquisitionTests` and `ScopeSessionTests`.
#if DEBUG || VISUALCORE_AUTOMATION
import OscilloscopeStudioCore
import VisualCoreExperience

extension ScopeCore {
    /// The seed of every scenario.
    public static let manifestSeed: UInt64 = 7

    /// The actions of input-response, save-restore and reset: the square wave, gain ×2, 2 ms per division.
    public static var inputEntries: [ScenarioStep] {
        [ScenarioStep(steps: 10, action: ScriptedAction("signal.waveform", [1]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("gain.select", [2]), result: "accepted"),
         ScenarioStep(steps: 10, action: ScriptedAction("timebase.select", [4]), result: "accepted")]
    }

    /// The entries of rejection: a source out of range, a timebase out of range and a fractional gain choice.
    public static var rejectionEntries: [ScenarioStep] {
        [ScenarioStep(steps: 0, action: ScriptedAction("source.select", [3]), result: "action.out-of-range"),
         ScenarioStep(steps: 0, action: ScriptedAction("timebase.select", [-1]), result: "action.out-of-range"),
         ScenarioStep(steps: 0, action: ScriptedAction("gain.select", [1.5]),
                      result: "action.rule." + ScopeRule.invalidChoice)]
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (a rejected action changes nothing).
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> ScopeCore {
        var core = ScopeCore(seed: seed)
        var step = 0
        for entry in entries {
            for _ in 0..<max(0, entry.steps) {
                core.update(step: step)
                step += 1
            }
            guard let action = entry.action else { continue }
            _ = core.apply(ExperienceAction(control: action.control, values: action.values, step: step))
        }
        return core
    }

    /// The digest of the core prepared with `seed` after `entries`, computed as the engine computes it; nil when the
    /// digest cannot be written.
    public static func expectedDigest(for id: ExperienceID, seed: UInt64, entries: [ScenarioStep]) -> String? {
        let core = played(seed: seed, entries: entries)
        var builder = DigestBuilder(domain: id.rawValue)
        do { try core.writeDigest(into: &builder) } catch { return nil }
        return builder.finish().hex
    }

    /// The entries of the three regression fixtures of this phase:
    /// 1. display periods: the test signal's sine at 1 kHz, 1 ms per division, rising trigger at 0 (10 periods);
    /// 2. spectrum bin: the 1 kHz sine at 5 ms per division (the window whose spectrum peaks at the 1 kHz bin);
    /// 3. no trigger: normal mode with the level at 0.9, beyond the test signal's amplitude of 0.5;
    /// 4. clipping shown: gain ×10 on the 0.5 sine drives the trace beyond full scale (the window marks it clipped);
    /// 5. sweep on a falling trigger: the logarithmic sweep with the falling slope at 2 ms per division;
    /// 6. missing crossing in auto mode (feature 062): the level at 0.9 with the auto mode, the newest span shown;
    /// 7. the XY view (feature 062): the stereo test signal plotted left against right;
    /// 8. the spectrum view (feature 063): the 1 kHz sine analysed, its peak read at the 1 kHz bin;
    /// 9. the microphone (mono) in XY (feature 063, the manual's Phase 03 fixture): the XY view chosen, the waveform kept
    ///    and marked "XY needs two channels";
    /// 10. freeze with cursors (feature 064): frozen, cursors shown one tenth of the window apart, level at half scale;
    /// 11. zoom steps (feature 064): the timebase stepped down twice and up once, as two pinch-outs and a pinch-in send;
    /// 12. a preset applied (feature 064): the built-in "Bass detail" (index 1).
    /// 13. frozen capture metadata (feature 065, the manual's Phase 05 fixture): the test signal frozen, then the gain
    ///    raised and the timebase changed; the frozen window's sample rate, channel count, start, count and samples stay
    ///    as frozen (`ScopeSessionTests` checks the held window; the state keeps `frozen`).
    /// The flat line (silence) needs a silent source, which no action selects; `ScopeSessionTests` proves it in both
    /// modes with an injected silent source.
    public static var fixtureEntries: [[ScenarioStep]] {
        func step(_ control: String, _ values: [Double], steps: Int = 5) -> ScenarioStep {
            ScenarioStep(steps: steps, action: ScriptedAction(control, values), result: "accepted")
        }
        return [
            [step("source.select", [0]), step("signal.waveform", [0]), step("signal.frequency", [2]),
             step("timebase.select", [3]), step("trigger.slope", [0]), step("trigger.level", [0]), ScenarioStep(steps: 30)],
            [step("signal.waveform", [0]), step("signal.frequency", [2]), step("timebase.select", [5]),
             ScenarioStep(steps: 30)],
            [step("trigger.mode", [1]), step("trigger.level", [0.9]), ScenarioStep(steps: 30)],
            [step("signal.waveform", [0]), step("gain.select", [4]), ScenarioStep(steps: 30)],
            [step("signal.waveform", [2]), step("trigger.slope", [1]), step("timebase.select", [4]),
             ScenarioStep(steps: 30)],
            [step("trigger.mode", [0]), step("trigger.level", [0.9]), ScenarioStep(steps: 30)],
            [step("source.select", [0]), step("display.select", [1]), ScenarioStep(steps: 30)],
            [step("signal.waveform", [0]), step("signal.frequency", [2]), step("display.select", [2]),
             ScenarioStep(steps: 30)],
            [step("source.select", [2]), step("display.select", [1]), ScenarioStep(steps: 30)],
            [step("source.select", [0]), step("freeze.set", [1]), step("cursors.show", [1]), step("cursor.a", [0.1]),
             step("cursor.b", [0.2]), step("cursor.level", [0.5]), ScenarioStep(steps: 30)],
            [step("timebase.select", [3]), step("timebase.select", [2]), step("timebase.select", [1]),
             step("timebase.select", [2]), ScenarioStep(steps: 30)],
            [step("preset.apply", [1]), ScenarioStep(steps: 30)],
            [step("source.select", [0]), step("freeze.set", [1]), step("gain.select", [2]),
             step("timebase.select", [4]), ScenarioStep(steps: 30)],
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
                ScenarioStep(steps: 10, action: ScriptedAction("timebase.select", [2]), result: "accepted"),
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
