# Data model: UA-F06

All types of sections 1 to 5 are pure values in `VisualCoreDiagnostics` (`Sendable`, `Equatable`).

## 1. QualityProfile (new)

| Field | Type | Rule |
|---|---|---|
| `levels` | `[QualityLevel]` | 1 to 8 (`QualityProfile.maxLevels = 8`); index 0 is the best |

`QualityLevel`:

| Field | Type | Rule |
|---|---|---|
| `name` | `String` | 1 to 40 characters, unique in the profile |
| `resolutionShare` | `Double` | finite, more than 0, at most 1 |
| `elementShare` | `Double` | finite, 0 to 1 |
| `iterationShare` | `Double` | finite, 0 to 1 |
| `effectPasses` | `Int` | 0 or more, at most 64 |

No budget of level n+1 is larger than the same budget of level n. Creation throws `QualityProfileError`
(`.noLevel`, `.tooManyLevels(Int)`, `.invalidName(level:)`, `.duplicateName(level:)`,
`.outOfRange(level:budget:)`, `.rising(level:budget:)`; `budget` is one of `resolutionShare, elementShare,
iterationShare, effectPasses`). Nothing is repaired.

Derived: `count`, `names`, `level(_ index:)` (clamped to the last level), `elements(requested:level:minimum:)`
and `iterations(requested:level:minimum:)` (`min(requested, max(minimum, floor(requested × share)))`, 0 for a
request of 0 or less), `static func uniform(levels:)` (names `level-0` …, every share 1, 0 passes; the count is
clamped to 1…8), `static let single`.

`QualityDeclaration.problems(profile:tierCount:catalogNames:) -> [String]`: a text for each difference (the
count differs from the tier count; the names differ from the catalog names, when catalog names are given).

## 2. QualityGovernor (new)

State: a `QualityPolicy` (tier count = the profile's count, Low Power ceiling `min(1, count − 1)`, decision
interval 2 s, calm period 10 s — the existing defaults), `pin: Int?`, the time of the last decision.

| Operation | Rule |
|---|---|
| `init(levelCount:pin:)` | count clamped to 1…8 |
| `levelInForce` | the pin clamped to the last level, or the policy's tier |
| `decide(conditions:now:) -> Int` | with a pin: returns the pinned level and takes no policy decision; without: asks the policy when at least `minimumInterval` (1 s) passed since the last decision or none was taken; a non-finite `now` changes nothing |
| `setPin(_:)` | changing to automatic starts the policy from tier 0 with its timing forgotten |
| `resume()` | forgets the timing, so that calm starts again after a suspension |
| `stepsDown`, `stepsUp` | the policy's counters |

## 3. PacingMeter and PacingSummary (new)

`PacingMeter`: 1,000 bins of 0.25 ms (`binWidth`, `binCount`), counters.

| Operation | Rule |
|---|---|
| `record(interval:period:)` | seconds; non-finite, negative or zero interval, or non-finite or non-positive period → `invalid += 1`; else one sample; on time when `interval ≤ 1.5 × period`, otherwise `missed += max(1, round(interval / period) − 1)` |
| `skipNext()` | the next interval is dropped (first frame after a resume) |
| `summary` | `PacingSummary` |

`PacingSummary` (Codable): `samples`, `onTime`, `missed`, `invalid` (Int), `medianMs`, `p95Ms`, `p99Ms`
(`Double?`, nil without samples; the upper edge of the bin that holds the percentile, in milliseconds).

## 4. ResourceSample and GrowthRule (new)

`ResourceSample`: `footprintBytes: Int?`, `gpuBytes: Int`.

`GrowthRule.judge(_ samples: [ResourceSample]) -> GrowthVerdict`:

- fewer than 60 samples → `.tooFewSamples(Int)`;
- warm-up = the first tenth (rounded down, at least 1);
- graphics bytes: the largest value after the warm-up may not exceed the largest of the warm-up → otherwise
  `.grew(quantity: "gpu_bytes", by:)`;
- footprint (only when every sample has one): median of the last quarter minus the median of the first quarter
  after the warm-up may not exceed `max(8 MiB, 5% of that first median)` → otherwise
  `.grew(quantity: "memory_footprint_bytes", by:)`;
- otherwise `.flat(footprintChecked: Bool)`.

## 5. PerformanceRecord, version 1 (new)

JSON object with sorted keys; at most 65,536 bytes; numbers finite; an absent measurement has no key.

| Key | Type | Required | Meaning |
|---|---|---|---|
| `version` | int | yes | 1 |
| `experience` | string | yes | the experience id |
| `presented` | bool | yes | whether frames reached a display |
| `quality_level` | int | yes | the level in force |
| `quality_pinned` | bool | yes | pinned or automatic |
| `quality_levels` | int | yes | the profile's count |
| `steps_down`, `steps_up` | int | yes | of the session |
| `thermal` | string | yes | `nominal, fair, serious, critical` |
| `low_power` | bool | yes | |
| `frame_cap_fps` | int | yes | the frame pacing's cap |
| `render_scale` | number | yes | the frame pacing's factor |
| `pacing` | object | yes | `samples, on_time, missed, invalid` (int), `median_ms, p95_ms, p99_ms` (number, absent without samples) |
| `gpu_bytes`, `gpu_peak_bytes` | int | yes | from the resource ledger |
| `late_compilations`, `rebuilds`, `memory_events` | int | yes | counters |
| `launch_ms` | number | no | start of the app's code to the usable launcher |
| `first_launch` | bool | no | present with `launch_ms` |
| `prepare_ms`, `setup_ms`, `first_present_ms` | number | no | stage times |
| `programs_compiled` | int | no | at the end of the set-up |
| `memory_footprint_bytes` | int | no | |

Reading (`init(data:)`) refuses with `PerformanceRecordError` and a stable `code`: `.tooLarge`
(`performance.too-large`), `.corrupt(reason:)` (`performance.corrupt`), `.newerVersion(Int)`
(`performance.newer-version`), `.unknownVersion(Int)` (`performance.unknown-version`), `.missingField(String)`
(`performance.missing-field`), `.unknownField(String)` (`performance.unknown-field`),
`.invalidValue(String)` (`performance.invalid-value`). `encoded()` gives the text; `passes: Bool` is false when
`late_compilations > 0`. There is no earlier version, so no migration; a later version adds a migration step
and keeps reading version 1.

## 6. Session additions (`VisualCoreExperience`, `VisualCoreExperienceHost`)

- `SessionStageTimings` gains `setup: Double?`, `firstPresent: Double?` (seconds, as the existing fields) and
  `programsCompiled: Int?`. Old encoded timings decode with these absent.
- `ExperienceCore.qualityProfile` (static, default `QualityProfile.uniform(levels: qualityTiers)`);
  `ConformanceCheck.profileMatchesTiers`.
- `Experience.qualityProfile` (default `QualityProfile.single`; `ExperienceShell` returns its core's).
- `ExperienceSession`: `qualityPin: Int?`, `conditions: @MainActor () -> DeviceConditions`, `qualityLevel: Int`,
  `launch: LaunchTiming?`, `performanceRecord: PerformanceRecord?`, `lastPerformanceRecord: PerformanceRecord?`,
  `refreshQuality(now:)`.
- `LaunchTiming` (pure): `milliseconds: Double`, `firstLaunch: Bool`.
- `RenderHost.addPresentObserver(_:)` with `PresentedFrame { index: Int, time: Double, targetTime: Double }`.
- `ProcessMemory.footprint() -> Int?`.

## 7. Identifiers

`vc.performance` (debug builds, settings diagnostics): the text of the last performance record.

## 8. Budget document

`docs/performance/budgets.md`: a table with the columns `Budget`, `Proposal`, `Status`, `Confirmed by`. `Status`
is `proposal` until a device measurement is linked. `Confirmed by` names devices (D1, D2, D3), the scenario and
the number of samples.

## 9. As built (recorded after T-U06-029)

- `QualityPolicy` gained `forgetTiming()` (keeps the tier, restarts the calm period); `QualityGovernor.resume()`
  uses it. The contract had said the policy's API stays unchanged.
- The pin is stored as given; `levelInForce` clamps it to the levels of the experience.
- The session does not use `PacingMeter.skipNext()`: it forgets the time of the last presented frame at a
  suspension, so that no interval spans the time away.
- The level in force is applied through `Experience.setQualityTier` when the experience is ready, active or
  suspended; an experience whose logic refuses the level keeps the level it has.
- Late compilations are computed when a record is read: compilations since the baseline taken when the session
  became running, plus those counted before a context rebuild. After a context loss that the host repairs itself
  the baseline is taken again at the next drawn frame.
- The presenter variants of the tests (late compilation, leak) are private types of their test files, not
  additions to `SamplePresenter.swift`.
- The endurance run draws its 36,000 frames without presenting them and takes well under a second on the
  simulator: it proves that app memory and ledger bytes do not grow, not rendering throughput.
- The app's launch start is `AppLaunch.start`, taken in the app type's initializer; a first start is one that finds
  no stored preferences (also after a reset of all data).
- `ShellID.performance` and `SettingsView.performanceText` exist only in debug builds.
- The sample core gained the fault `WrongProfileCount` for the conformance test.

