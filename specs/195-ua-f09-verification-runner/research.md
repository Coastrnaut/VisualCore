# Research: UA-F09 — Experience verification runner and evidence schema

Read-only audit of 2026-11-12, by an audit agent at `dd989af`; the lead checked the facts the design rests on again
at `HEAD`. The decisions follow.

## 1. Audit of the sources the brief names

### Auto-Creator.md sections 6 and 22

- Contract rules E-01 to E-15 (section 6.1). Content completeness (6.2): a creative experience has a scenario
  per regression fixture of its card. A Round 2 game has 100 levels and 80 acceptance scenarios. A Round 3 or 4
  game also has 50 fault-injection cases.
- The forbidden list (6.3): placeholder content, mock-only gameplay, outside art (except a generated app icon),
  outcomes decided by the GPU or the clock, and unevidenced claims.
- Section 22.1 defines the nine scenarios and what each passes on. Games add `full-playthrough`, the acceptance
  scenarios, `hero` and the fault cases; creative experiences add their fixture scenarios; `endurance` runs ten
  minutes. A scenario is started only through the launch environment (`VISUALCORE_AUTORUN`), writes its
  evidence JSON and exits. No URL, file or other outside input can start one.
- Section 22.2: `scripts/verify_experiences.py` is the single driver, and the X gate commands use
  `--only <id> --runtime 27|26` and `--audits`. A result bundle counts after an independent `xcresulttool`
  check. Goldens support, never decide.
- Section 22.3 lists the fields of evidence schema version 1 (copied into data-model.md section 4). A record
  with `pass` and no observed evidence is rejected. Tracked summaries go under `docs/verification/`; raw files
  stay in `.autonomy/logs/` and `.autonomy/xcresults/`, referenced by hash.
- Section 22.4: the instrumented Release build carries `VISUALCORE_AUTOMATION`; the shipping Release build has no
  automation symbols. The lock run (`--lock`) is UA-F12. UA-F13 runs the same scenarios on devices with
  `devicectl`, copying the evidence JSON from the data container.
- Carried obligations: UA-F06 left `verify_experiences.py --only <sample id> --scenario endurance --runtime 27`.
  UA-F07 calls the driver with three ids.

### Code (verified)

- `ExperienceScenario` and `ExperienceScenarioResult` live in `VisualCoreExperience/ExperienceScenario.swift`,
  inside `#if DEBUG || VISUALCORE_AUTOMATION`. They hold a seed and entries (steps, then an optional
  `ScriptedAction`), with limits of 10,000 entries and 1,000,000 steps. `ExperienceEngine.run(_:)` and
  `runScenario(_:id:)` replay them through the real engine and report the final digest, the step index and the
  result codes. There are no expectations and no per-step digests.
- `ExperienceShell.run(_:)` (`#if DEBUG || VISUALCORE_AUTOMATION`) is the same on the shell. The type-erased
  `Experience` does not expose it.
- `ExperienceConformance` checks: seed determinism, snapshot round trip, reset equivalence, rejection keeps the
  digest, tier keeps the digest, shedding keeps the digest, replay reproduces the digest, profile matches tiers.
- `ExperienceDiagnostics` has `experience, state, seed, stepIndex, qualityTier, gpu, lastError, digest,
  rejectedTransitions, rejectedOperations, acceptedActions, rejectedActions, droppedTime, invalidFrames`, with
  custom coding (`decodeIfPresent` for optional fields). It has no outcome.
- `ExperienceCore` has no outcome member.
- `ExperienceSession` offers `open`, `close`, `retry`, `checkpoint`, `setScenePhase`, `handleMemoryWarning`,
  `recreateContext`, `refreshQuality`, `timeSource`, `diagnostics`, `lastCloseCounts`, `hostsAlive`,
  `performanceRecord` and `renderHost`. `RenderHost.readPixels()` returns the window framebuffer as RGBA.
  `ProcessMemory.footprint()` exists.
- `ExperiencePresenter` requires `setup, resize, draw, teardown, shedCaches, describe, makeControls`, with
  defaults for `resize` and `shedCaches`.
- `VisualCoreAutomation` (`AutomationRunner`, `AutomationReport`, `AutomationView`) is used only by the
  standalone apps. Its key `VISUALCORE_AUTORUN` names a mode. Reports go to `Documents/` and the process exits
  0/1/2.
- `scripts/run_automation_sim.py` picks a simulator by runtime and launches with `SIMCTL_CHILD_*` environment.
  It polls `simctl get_app_container … data` and copies the report out.
- `scripts/check_test_enumeration.py` compares declared XCTest methods with passed lines in a log; it counts no
  Swift Testing tests.
- Result bundles: `xcodebuild_package.py` writes `-resultBundlePath .autonomy/xcresults/<name>.xcresult`;
  `xcodebuild_app.py` writes none. `xcresulttool` is used only by the legacy runbook (`get test-results summary`,
  result must be passed). The installed `xcresulttool` offers `get test-results summary|tests|test-details` and
  `export attachments`.
- `check_release_symbols.py` and `check_experience_symbols.py` prove automation symbols absent from a Release
  build (with `--expect-present` and `--with-flag` for the instrumented build).
- The sample experience (`a99.contract-sample`, `VisualCoreTestSupport`) may be linked only into test targets
  (rule R5). Its presenter `SamplePresenter` is in the host test target. The fault `SlowPreparation` makes a
  cancellable slow preparation; `LossySnapshot` and `MutatingRejection` break restore and rejection.
- The app's debug experience is `#if DEBUG` only and registered under the five free fixture ids. The app reads
  launch arguments but no environment variable. `project.yml` has no `VISUALCORE_AUTOMATION` configuration. A
  flagged build passes `SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) VISUALCORE_AUTOMATION'`.
- `DebugInventory` (UA-F05) does not list `Documents/`.
- Planning catalog: games have `level_manifest.rows` (100), `acceptance_scenarios.rows` (80), `fault_injection.rows`
  (50 for Rounds 3 and 4); creative entries have `design.fixtures`. No game is implemented.
- Shipped sources: 0 TODO, FIXME, XXX, lorem or "coming soon"; 16 "placeholder" in code (the EGL placeholder
  surface in `RenderHost.swift`, one comment in `ExperienceSession.swift`), none in user-visible text. No
  raster file in shipped paths.

## 2. Decisions

### R1. The outcome

**Decision**: `ExperienceOutcome` (new, `VisualCoreExperience`): a stable `code` (for example `level-solved`,
`work-saved`, `target-reached`). `ExperienceCore` gains `var outcome: ExperienceOutcome? { get }` with a default of
nil; it is computed from the state and never stored. `ExperienceEngine.outcome` reads it, and
`ExperienceDiagnostics` gains an optional `outcome` (decoded if present, so older encoded diagnostics still read).
The sample core reports `target-reached` while the marker is on the target; the debug core reports
`taps-counted` once its count reaches 3. Neither change touches a digest, because digests are written by
`writeDigest`, which does not include the outcome. **Rationale**: clarification 1. **Alternatives**: an outcome in
the manifest only (a manifest could then set it, which is forbidden).

### R2. Manifests, evaluation and frame checks are pure

**Decision**: in `VisualCoreExperience`, inside `#if DEBUG || VISUALCORE_AUTOMATION`:
- `ScenarioManifest`: schema 1, experience id, kind, and the scenarios.
- `ScenarioManifestValidator`: the nine names, the extras of a game, and the content counts it is given.
- `ScenarioObservation` (what a run saw) and `ScenarioEvaluator` (observation against expectations → failures).
- `FrameChecks`: non-blank, black frame, histogram, non-finite values, silhouette bounds, on RGBA bytes or floats.
- `ScenarioRequest`: the launch-environment keys and their parsing.

The existing `ExperienceScenario` stays and is what the entries are converted to. **Rationale**: host-testable
(rule IV); shared by package tests and the app. **Alternatives**: put them in `VisualCoreAutomation` (it does not
know the experience contract) or in the app (not testable on the host).

### R3. The runner drives a real session

**Decision**: `ScenarioRunner` (new, `VisualCoreExperienceHost`, `#if DEBUG || VISUALCORE_AUTOMATION`, main
actor). It runs one scenario of a manifest against an open request through an `ExperienceSession`, and it is
the only place that sends a scenario's actions, through the experience's `handle`. After each action it reads the
digest from the diagnostics. Frames come from `renderHost.readPixels()` after a drawn frame. Probes come from a
new presenter requirement `probes(_ core:) -> [FrameProbe]` (default empty), which the shell exposes as
`Experience.frameProbes`. Scenario steps:

| Scenario | Session calls |
|---|---|
| launch-first-frame | `open`, lay out, draw one frame, `readPixels`, probes, `SessionStageTimings` |
| input-response, rejection, completion | `open`, then for each entry: advance the steps, `handle`, digest |
| save-restore | phase `save`: `open`, actions, `snapshot()` stored by `SavedStateStore`, exit; phase `restore`: `load`, `open` with the snapshot and `refusedSnapshotFails`, digest equals the expected digest |
| reset | `open`, actions, `reset()`, digest equals the fresh digest; storage of other ids unchanged |
| suspend-resume | `open` with a scripted `timeSource`, background, advance the script, foreground; step index and digest unchanged |
| teardown-reentry | open and `close()` N times (N from the manifest, default 5); close counts zero, `hostsAlive` 0; memory growth by the UA-F06 growth rule |
| cancel-prepare | `open` started, `close()` while preparing; result `.cancelled`; no action accepted after it |
| endurance | the UA-F06 endurance rule with the time the manifest names |

**Rationale**: FR-U09-010; the session is the path a person's input takes. **Alternatives**: run on the engine
alone (bypasses session lifecycle, frames and resources).

### R4. The app's entry

**Decision**: `Apps/VisualCore/App/Automation/ScenarioLaunch.swift` (new, `#if DEBUG || VISUALCORE_AUTOMATION`).
`VisualCoreApp` checks `ScenarioRequest.parse(ProcessInfo.processInfo.environment)` before it builds the model.
When the request is present, the app shows `ScenarioHostView` (one window with the session's host view) instead
of the root view. It runs the scenario after the first layout, writes the record atomically to
`Documents/visualcore-evidence/<run>/<id>.<scenario>.json` and exits. The registry it uses is the real registry,
plus, in debug builds, the debug experience under its first fixture id, with the debug experience's manifest
(clarification 5). The inventory gains the rule `Documents/visualcore-evidence/…` with the runner as its writer
(clarification 3). No URL scheme is added. **Rationale**: FR-U09-011, FR-U09-012, FR-U09-034.

### R5. The sample's path

**Decision**: the sample's manifest is a test fixture of the host test target. `ScenarioRunnerTests` runs its
nine scenarios on each simulator runtime. Each test attaches its record JSON to the result bundle as an
attachment named `evidence-<id>-<scenario>.json`. The driver, for `--only a99.contract-sample`, runs those tests
with `xcodebuild_package.py --only-testing`, checks the bundle with `xcresulttool`, exports the attachments and
validates them. Save-restore on this path uses two sessions in one test process, and its record says so in
`configuration.process` (`single`). **Rationale**: clarification 5; rule R5.

### R6. The driver and the validator

**Decision**: `scripts/verify_experiences.py` (new) and `scripts/check_evidence.py` (new, the schema 1
validator, imported by the driver). Driver steps per runtime, each with a time limit:
1. Host tests from a table of experiences.
2. One build, with a result bundle: `xcodebuild build` of the VisualCore scheme, Debug, generic simulator, into
   `Build/DerivedData/verify`.
3. Install on the simulator chosen by runtime and kind, which is booted with a bounded wait.
4. Per scenario, `simctl launch --terminate-running-process` with `SIMCTL_CHILD_VISUALCORE_AUTORUN*`. The driver
   waits for the record (limit) and the process exit (limit), copies the record, then removes it.
5. It completes `environment` (runtime and build from `simctl list -j runtimes`, device type, `xcodebuild
   -version`, `swift --version`, SDK build, host OS), `source` (commit, dirty flag, tree hash, submodule pins,
   SHA-256 of `Catalog/experiences.json`, SHA-256 of the app binary) and `artifacts`.
6. It validates, writes a summary under `docs/verification/<id>/`, and keeps the run state in
   `.autonomy/verify/state.json`.

A simulator that answers "Busy" is retried once after 20 s. Options are `--only`, `--skip`, `--scenario`,
`--runtime`, `--audits`, `--self-test`, `--dry-run`, `--max-seconds` and `--fresh`. **Rationale**: FR-U09-020 to
FR-U09-025; the no-open-ended-waits rule.

### R7. Result bundles

**Decision**: a bundle counts when `xcrun xcresulttool get test-results summary --path <b> --format json` reports
`result` `Passed` and failed count 0. The counts and destination come from the summary; the test list comes from
`get test-results tests`; attachments come from `export attachments`. `xcodebuild_app.py` gains `--result-name`
(a result bundle for app test runs), which the driver uses for UI-test evidence. **Rationale**: FR-U09-023.

### R8. Audits

**Decision**: `verify_experiences.py --audits` runs over `git ls-files` restricted to shipped paths (the app
target's sources and resources, `Catalog/experiences.json`, `Catalog/categories.json`, and the `Sources` of the
linked package products except `VisualCoreTestSupport`):
- **markers**: TODO, FIXME, XXX in comments and strings; "lorem ipsum", "coming soon", "placeholder" in the
  string catalog and in string literals passed to `Text`, `Label`, `Button`, `accessibilityLabel` and
  `accessibilityHint`.
- **raster**: any `.png .jpg .jpeg .gif .heic .webp .tif .tiff .bmp .psd .ico .icns` is a finding unless it is
  listed in `Catalog/generated-art.json` with its generator command and SHA-256. The list is empty today.
- **reducer bypass**: static (each entry's action names a declared control; an expected digest or outcome follows
  at least one action) and dynamic (from a record, accepted plus rejected counts in the experience's diagnostics
  equal the actions sent).
- **content counts**: the manifest's scenario counts against the planning catalog. For games: the acceptance
  scenarios, the fault cases and `content.levels` against the catalog rows.
- **direct GL**: `check_app_isolation.py` over the app and the experience sources.
- **network**: `check_compliance.py`.
- **entitlement**: printed as "not yet provided (UA-F08)" and never counted as passed.

**Rationale**: FR-U09-050 to FR-U09-055; clarifications 2 and 4.

### R9. Release absence

**Decision**: `check_release_symbols.py --forbid ScenarioRunner ScenarioLaunch ScenarioManifest
VISUALCORE_AUTORUN_EXPERIENCE` on the Release app (0 found). `check_experience_symbols.py --module pure` and
`--module host` gain the new type names, with `--with-flag` proving them present in a flagged build.
**Rationale**: FR-U09-012, SC-U09-004.

### R10. Self-test

**Decision**: `--self-test` runs, without a simulator, the validator's self-tests and the audit self-tests on
planted defects in a temporary copy of the files. With `--runtime`, it also runs the sample path, including the
`LossySnapshot` fault variant, whose save-restore must fail. The driver must exit non-zero and name the
scenario and the expectation for that case. **Rationale**: FR-U09-025, SC-U09-002.

## 3. As built (2026-11-12)

- The runner resets the experience right after the open's first frame, so a scenario starts from the state of a
  fresh preparation and its digests do not depend on how many frames the open drew. A restore opens with the scene
  in the background, so the restored state is read before any frame advances it.
- Endurance counts simulated time: 60 frames of 1/60 s per second, drawn in 60 blocks with one resource sample
  each, after a warm-up of 120 frames. A wall-clock loop with yields between frames grew the footprint by hundreds of
  megabytes; the block pattern of UA-F06 does not.
- Observation: a scissored clear on every frame grows the memory footprint on the iOS 26.5 simulator (9.3 MB over
  36,000 frames in the UA-F06 endurance test; flat without it). The sample presenter therefore draws its contrasting
  corner mark only when a verification test asks for it. The renderer is not changed.
- `MutatingRejection` cannot be observed through a session, because the engine discards a rejected action's
  changes; the deliberately failing state change of the runner tests is `WrongReset`.
- The sample's manifest is built in the test file from committed digests and a bare engine run. A JSON
  fixture is not needed; the manifest's JSON round trip is tested.
- `Experience` gained `frameProbes` and, in builds for testing or automation, `runScenario(_:)`; the runner plays
  entries through it, which hands each action to the engine's reducer as `handle(control:values:)` does.
- Incident (2026-11-12): a task commit staged the untracked raw run folder `.autonomy/verify/`. Its exported
  attachment manifest names the local iOS 27.2 simulator's identifier. The next commit untracked the folder and
  ignored it, and the push went through, because the pre-push scan read only the net change of the outgoing
  range; the identifier is therefore in the history of `9ed2fd0` on `origin/main`. History is never rewritten.
  The scan now reads every outgoing commit on its own (a test plants an identifier that one commit adds and the
  next removes), and `.autonomy/verify/` is ignored. The identifier names a local simulator, not hardware.
