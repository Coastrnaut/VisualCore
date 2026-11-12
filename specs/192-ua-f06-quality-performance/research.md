# Research: UA-F06 — Quality profiles and performance observability

Read-only audit of 2026-11-12 (by an audit agent; every fact the design rests on was checked again by the lead
against the source at HEAD `111fbfc`), followed by the decisions.

## 1. Audit of the sources the brief names

### Auto-Creator.md section 12 (lines 2752 to 2843)

- 12.2 rule 3: shaders are compiled "during preparation"; load is measured apart from the first rendered frame.
  Rule 6: no direct GL or EGL in experience or app sources. Rule 8: a lower tier trades samples, layers and
  resolution; the meaning of the scene stays. Rule 10: compilation is checked for real.
- 12.4: each experience declares named tiers and what each means in numbers (resolution scale, particle or
  instance count, iteration count, effect passes); built on `QualityPolicy`, `DeviceConditions`, `FramePacing`,
  `ParticleBudget`, `RenderCostEstimate`; step down under serious thermal state or Low Power Mode, recover after
  the calm period; a tier change never changes domain state; a settings override pins a tier. The section names
  no type; **`QualityProfile` appears only in the brief and exists nowhere in the code (new)**.
- 12.5: budgets are proposals in `docs/performance/` with the confirming device measurement; simulator numbers
  are development signals only.
- 12.6: refresh misses are counted from display-link interval timelines; median, p95 and p99; at least 200 samples
  for percentage criteria; one launch sample per process, the first launch after an install excluded.
- 22.3 defines the evidence record (version 1) and gives its validator to UA-F09; `scripts/verify_experiences.py`
  is a planned script of UA-F09 (`scripts/validate_autocreator.py` lists it as planned) and **does not exist**.

### `Packages/VisualCore/Sources/VisualCoreDiagnostics` (no dependency, pure)

- `QualityPolicy` (struct, `Sendable, Equatable`): `init(tierCount:lowPowerCeiling: = 1, decisionInterval: = 2,
  calmPeriod: = 10)`, `tier`, `stepsDown`, `stepsUp`, `mutating decide(thermal:lowPower:now:) -> Int`,
  `mutating reset()`. One step per decision; hot is serious or critical; Low Power holds at the ceiling and
  blocks recovery; a non-finite `now` keeps the tier. `reset()` does not clear the step counters.
- `DeviceConditions` (struct): `thermal: FramePacing.Thermal`, `lowPower: Bool`, `static let nominal`,
  `static func current()` (reads `ProcessInfo` under `canImport(Darwin)`).
- `FramePacing`: a frame-rate cap (30 under heat or Low Power) and a render scale (0.75 at critical); `Thermal`
  enum (`nominal, fair, serious, critical`, `Int`, Codable). **No interval statistics.**
- `ParticleBudget`: `shares` per tier, `minimum`, `limit(requested:tier:)`.
- `RenderCostEstimate`: a work ratio, never a time.
- `ResourceLedger.Snapshot`: `liveCount`, `liveBytes`, `totalBytes`, `peakBytes`, `leaked`, … (Codable). Programs
  and shaders are ledgered with 0 bytes.
- Tests: `QualityPolicyTests` (9), `ParticleBudgetTests` (6), `FramePacingTests` (6), `RenderCostEstimateTests` (6),
  `ResourceLedgerTests` (7), `RenderLifecycleTests` (5).
- Used today only by the four standalone apps. **Nothing in the unified path uses `QualityPolicy` or
  `DeviceConditions`.**

### `docs/performance/`

`README.md`, `baselines-host.json`, `baselines-simulator.json`: host and simulator numbers of the Showcase,
stated as not device evidence. **No budget document.**

### The experience contract and the session (verified lines)

- `ExperienceCore.qualityTiers: Int` (default 1) and `mutating setQualityTier(_:)`; the engine keeps
  `qualityTier`, refuses an undeclared tier with `.invalidTier(_, tiers:)`, and applies the tier again after
  preparation and restore. `ExperienceConformance` has the check `.tierKeepsDigest` over every tier.
- `VisualCoreExperience` depends on `VisualCoreMath`, `VisualCoreSimulation`, `VisualCorePersistence`
  (`Packages/VisualCore/Package.swift:29`) and **not** on `VisualCoreDiagnostics`; `VisualCoreDiagnostics` has no
  dependency, so the edge `VisualCoreExperience → VisualCoreDiagnostics` creates no cycle.
- `Experience` (host protocol) has `setQualityTier(_:)` and no way to read the number or the names of the tiers.
- `SessionStageTimings` (`SessionLifecycle.swift:110`): `prepare`, `createHost`, `activate`, `firstFrame`, seconds,
  optional, synthesized Codable.
- `ExperienceSession.open` (`ExperienceSession.swift:159`): `prepare` is timed around the pure preparation;
  `createHost` around `RenderHost(scene:budget:)`, whose initializer runs the scene's `setup` — **this is where
  shaders compile, untimed on its own**; `firstFrame` ends at a frame forced with `renderOneFrame(present: false)`,
  so **it is a drawn, not a presented frame**. The private `SessionScene` wraps the experience's scene and calls
  `onFrame` after each frame drawn without error.
- `RenderHost` (`RenderHost.swift`): `presentedFrameCount` grows after a successful `eglSwapBuffers` (line 406);
  `displayLinkFired` has the link's `timestamp` and `targetTimestamp`; `framePacing` is public; **no observer of
  presented frames and no interval record**.
- `ResourceRegistry.compileCount` (`ResourceRegistry.swift:248`) grows with every program compiled; `cacheHits`
  beside it. **No compile duration.**
- The app (`Apps/VisualCore/App/AppModel.swift`): the override is applied after an open and whenever the session
  reaches running (`applyQualityOverride`, `watchSession`); automatic applies nothing.
- The catalog: `quality_tiers` is a list of at most 8 names per entry, empty for all 100 entries
  (`RealCatalogTests` asserts it); `ExperienceDescriptor.qualityTiers: [String]`.
- Nothing reads the memory footprint or records a launch time (`task_info`, `phys_footprint`: absent).

### Absorbed archive features

`R02-F32` (adaptive quality, frame-interval histograms, no false GPU statistics, a 30-minute probe), `R03-F09`
(report schema for D1 to D3, CPU and GPU time where observable, cold and hot start baselines, battery, memory,
thermals, shader warm-up), `R04-F09` (word for word R03-F09 with other consumers). The decisions per requirement
are in the specification's table.

## 2. Decisions

### R1. Where the pure types live

**Decision**: all pure types of this feature go into `VisualCoreDiagnostics`: `QualityProfile`, `QualityGovernor`,
`PacingMeter`, `GrowthRule`, `PerformanceRecord`. `VisualCoreExperience` gains the dependency on
`VisualCoreDiagnostics` so that an experience's logic can declare its profile.
**Rationale**: the brief places the profile "on top of QualityPolicy and DeviceConditions", which live there; its
first evidence command filters `VisualCoreDiagnosticsTests`; the module has no dependency, so the new edge is
acyclic. **Alternatives**: a new module (one more product for five files); the profile in `VisualCoreExperience`
(could not use `QualityPolicy` without the same edge).

### R2. The profile and the two existing declarations

**Decision**: `ExperienceCore` gains `static var qualityProfile: QualityProfile` with a default built from
`qualityTiers` (levels named `level-0` …, every budget 1 and 0 effect passes). An experience that means
something by its levels declares the profile; `qualityTiers` stays and must equal the profile's count. A pure
function reports the differences between a profile, a tier count and catalog names; the conformance run gains
the check `profileMatchesTiers`; the app's registry test compares every registered experience's profile names
with the catalog's `quality_tiers`.
**Rationale**: additive (existing cores keep compiling), one rule for the count and the names. **Alternative**:
replace `qualityTiers` by the profile (breaks every existing core and the baseline).

### R3. Who drives the level

**Decision**: the session. `QualityGovernor` (pure) owns a `QualityPolicy` and an optional pin and returns the
level in force for given conditions and a time; decisions are at least one second apart. `ExperienceSession`
gets `qualityPin: Int?` and a replaceable source of `DeviceConditions` (default `DeviceConditions.current()`),
applies the level after the preparation and before the host exists (the engine is ready then), and decides
again from its frame hook while running. The `Experience` protocol gains a read-only `qualityProfile` (default
in an extension: one level). The app only sets `session.qualityPin` from the stored override; its own
`applyQualityOverride` and session watching go away.
**Rationale**: first frame at the right level (FR-U06-013), Retry covered by construction, one place for the
rule. The frame scheduler's own reaction (cap and render scale) stays; the record names both.
**Alternative**: keep the logic in the app (first frame at level 0; every opener would repeat it).

### R4. Stage times, shader compilation and first present

**Decision**: `SessionStageTimings` gains `setup` (the scene's set-up, timed inside the session's scene wrapper),
`firstPresent` (from the start of the open to the first presented frame) and `programsCompiled`. `RenderHost`
gains `addPresentObserver`, called on the main thread after each successful present with the frame's index,
host time and target time. The session counts late compilations as the growth of
`resources.compileCount` after the experience became interactive, and starts a new baseline after a context
recreation (counted as a rebuild).
**Rationale**: the set-up is the moment shaders compile (clarification 1); a presented frame is observable only
after `eglSwapBuffers`. **Alternative**: infer the first present from `presentedFrameCount` in the next frame
(one frame late, and no interval data).

### R5. Pacing

**Decision**: `PacingMeter` (pure) takes the interval between two presented frames and the refresh period. An
interval of at most 1.5 periods is on time; a longer one misses `round(interval / period) − 1` refreshes.
Intervals go into 1,000 fixed bins of 0.25 ms (longer ones into the last bin); the median, p95 and p99 are the
upper edge of the bin that holds the percentile, so memory is constant. Non-finite or negative intervals are
counted as invalid. The session skips the first interval after a resume.
**Rationale**: FR-U06-030 to FR-U06-032 with exact, testable values. **Alternative**: keep every interval
(unbounded).

### R6. Memory footprint and launch time

**Decision**: `ProcessMemory.footprint()` in `VisualCoreRendering` reads the process footprint with
`task_info(TASK_VM_INFO)` (public Mach interface, no privacy-manifest reason) and returns nil when the call
fails. The launch time is taken by the app with `ContinuousClock` from the app type's initializer to the first
appearance of the launcher or the welcome; the first start is the one without stored preferences. The app hands
the value to the session, which puts it into the record.
**Rationale**: no boot-time interface (which would need a declared reason); the earliest app code is the
earliest moment the app can observe. **Limit**: time before the app's own code runs is not included; stated in
the record's documentation and in the budget document.

### R7. The performance record

**Decision**: `PerformanceRecord` (version 1), a value with optional measurements and one JSON text form with
sorted keys, at most 64 KiB, strict reading (unknown key, missing required key, wrong type, non-finite number,
newer version → a stable code). Units in the key names (`_ms`, `_bytes`). The session offers
`performanceRecord` while an experience is open and `lastPerformanceRecord` after it closed. Debug builds show
the last record in the settings diagnostics (`vc.performance`), which is how an interface test reads it.
**Rationale**: FR-U06-040 to FR-U06-043; UA-F09 embeds the value. **Alternative**: extend
`SessionDiagnostics` (a 16-argument public initializer would change).

### R8. Endurance

**Decision**: a package test in `VisualCoreExperienceHostTests` runs the sample experience for 36,000 drawn
frames of 1/60 s (72,000 steps), samples footprint and graphics bytes every 600 frames (60 samples), applies
`GrowthRule`, and compares the digest with the same scenario run by the engine alone. A leaking test presenter
proves the rule fails. `scripts/xcodebuild_package.py` gains `--only-testing` so that the run is one short
command per runtime.
**Rationale**: clarifications 2 and 5; `verify_experiences.py` is UA-F09's. **Alternative**: a wall-clock run
(does not fit a command; device task).

### R9. Budget document and its check

**Decision**: `docs/performance/budgets.md` holds the table of section 12.5 with the columns budget, proposal,
status (`proposal`), confirmed by (devices, scenario, samples). `scripts/check_performance_docs.py` fails when a
row lacks one of them, when a status is not `proposal` without a named device measurement, or when a file in
`docs/performance/` mentions a simulator without the fixed notice "Simulator numbers are development signals,
not device performance."; it becomes a step of `release_check.py`.

### R10. Settings

**Decision**: the picker of UA-F04 stays (automatic, 0 to 7); its note is rewritten to say what automatic does
and that a pinned level beyond an experience's levels means its last level. No per-experience override, no
schema change of the preferences.

## 3. Names from the brief, confirmed or corrected

| Name in the brief | Result |
|---|---|
| `QualityProfile` | new; created in `VisualCoreDiagnostics` (R1) |
| `QualityPolicy`, `DeviceConditions`, `FramePacing`, `ParticleBudget`, `RenderCostEstimate` | exist as described |
| "shaders compiled during prepare" | corrected: compiled in the set-up after the pure preparation (clarification 1) |
| "first present" | new measurement; today's `firstFrame` is an unpresented draw and stays as it is |
| "evidence records" | the record of section 22.3 is UA-F09's; this feature delivers its performance part (R7) |
| `scripts/verify_experiences.py --scenario endurance` | does not exist (UA-F09); the endurance proof here is a package test (R8) |
| "GPU ledger bytes" | `ResourceLedger.Snapshot.totalBytes` and `peakBytes` through `ResourceRegistry.stats` |
