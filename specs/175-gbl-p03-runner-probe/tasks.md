# Tasks: Graphics Benchmark Lab — Phase 03 Runner/profiler and capability probing

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/visualcore.md](contracts/visualcore.md), [contracts/experience.md](contracts/experience.md),
[quickstart.md](quickstart.md). Gate A24-P03 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A24-P03 --timeout 595 --name <check> -- <command>`.
- **Commits:** one after every task, with no trailers.
- **Checks:** read every check's exit before ticking, never in the same command.
- **Scope:** iOS 27 for the experience; the VisualCore change also runs the reference regression on iOS 27 and 26.
- **Precedent:** `specs/174-gbl-p02-workload-renderers/tasks.md`; a VisualCore change as in A21-P04.
- **Rollback:** revert the commits (the API baseline returns with them).

## Phase 1: Setup

- [X] T-A24-301 Baseline: cite the A24-P02 evidence (`.autonomy/checks/A24-P02.{gbl-ios27-2,app-unit,verify-27-2}.json`) — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P02.{gbl-ios27-2,app-unit,verify-27-2}.json exit 0 at A24-P02; Packages unchanged since b993d3a5
  on the tree recorded at A24-P02 (`b993d3a5`), whose Packages are unchanged since (owner ruling of 2026-11-14)

## Phase 2: VisualCore — U-RENDERINFO and U-GPUTIMER (P1)

- [X] T-A24-302 [P] In VisualCoreRendering: `ResourceRegistry.renderCapabilities` (public read, internal set) set by — Verified 2026-11-19: 2026-11-19: ResourceRegistry.renderCapabilities set in takeCapabilities; RegistryCapabilitiesTests pass (.autonomy/checks/A24-P03.rendering-new.json exit 0): equal to host.capabilities, follows recreateContext
  `RenderHost.takeCapabilities` beside `maxTextureSize`; `Tests/VisualCoreRenderingTests/RegistryCapabilitiesTests.swift`
  proves the registry's copy equals `RenderHost.capabilities` after the first frame and after `recreateContext()`
  (its `generation` follows) (FR-A24-303)
- [X] T-A24-303 [P] The loader's extension block (`CVisualCoreGLLoad.h`, `VCGLLoadFromEGL.c`): `vcglHasDisjointTimerQuery`, — Verified 2026-11-19: 2026-11-19: loader extension block (GL_TIME_ELAPSED_EXT, GL_GPU_DISJOINT_EXT, vcglHasDisjointTimerQuery, vcglGetQueryObjectui64vEXT) resolved optionally; generated header untouched; .autonomy/checks/A24-P03.rendering-new.json exit 0
  `vcglGetQueryObjectui64vEXT`, `GL_TIME_ELAPSED_EXT` 0x88BF, `GL_GPU_DISJOINT_EXT` 0x8FBB, resolved optionally (never
  counted as missing); the generated `CVisualCoreGL.h` untouched
- [X] T-A24-304 `Sources/VisualCoreRendering/GPUFrameTimer.swift` per contracts/visualcore.md and clarification Q2 — Verified 2026-11-19: 2026-11-19: GPUFrameTimer (ring of 4 GL_TIME_ELAPSED_EXT queries, ns to ms, disjoint discards, old generations never read); GPUFrameTimerTests pass (.autonomy/checks/A24-P03.rendering-new.json exit 0): 7 results of 0.06 to 12.4 ms within 4 frames on the simulator (not device evidence), nil without the extension, nothing after recreation
  (FR-A24-305): ring of 4 `GL_TIME_ELAPSED_EXT` queries, results in milliseconds ("nanoseconds / 1,000,000") only when
  available and not disjoint, a disjoint read discards every pending query, older generations never read, `release()`;
  `Tests/VisualCoreRenderingTests/GPUFrameTimerTests.swift`: where the extension is listed and resolved, a known draw
  gives a finite, non-negative time within 1,000 ms within 4 frames; a timer created before `recreateContext()` reads
  nothing afterwards; where it is not, `init?` is nil and the test says so
- [X] T-A24-305 The public API baseline (`python3 scripts/check_public_api.py --update`, then the check), `///` on every — Verified 2026-11-19: 2026-11-19: API baseline updated (13 additions), .autonomy/checks/A24-P03.public-api.json exit 0 (0 undocumented); README paragraphs in VisualCoreRendering and VisualCore; contract records ringSize and GPUFrameTime.init
  addition (`check_documented_api` for VisualCoreRendering), and the two README paragraphs
  (`Packages/VisualCoreRendering/README.md`, `Packages/VisualCore/README.md`) (FR-A24-308)

## Phase 3: Core — probe, dropped rule, report (P1)

- [X] T-A24-306 [P] Create `Core/{TimerProbe,DroppedFrameRule,RunReport}.swift` per data-model.md and clarifications — Verified 2026-11-19: 2026-11-19: TimerProbe, DroppedFrameRule (25 ms), RunReport (validated fields, thermal-changed) with tests; .autonomy/checks/A24-P03.gbl-core.json exit 0 (66 core tests)
  Q3–Q5 with their tests `CoreTests/{TimerProbeTests,DroppedFrameRuleTests,RunReportTests}.swift`: the probe's two
  outcomes; "interval > 1.5 × 1,000 / 60 ms" dropped; every report field validated ("strings 1…128 characters", the
  thermal raw values, the timing sources from the fixed set), `thermal-changed`
- [X] T-A24-307 Run file version 2 in `Core/BenchmarkRun.swift` (body `{case, report, samples, state, summary}`, a — Verified 2026-11-19: 2026-11-19: run file version 2 with report (migration 1 to 2 adds report null; version 3 refused); RunDocumentTests pass in .autonomy/checks/A24-P03.gbl-core.json
  `MigrationChain` step 1 → 2 adding `report: null`) and `CoreTests/RunDocumentTests.swift` (a version 1 file opens
  with no report; version 2 round-trips; version 3 refused as newer) (FR-A24-307)

## Phase 4: Experience — runner and report (P1, P2)

- [X] T-A24-308 [US1] [US2] [US4] In `Experience/{RunRecorder,BenchPresenter}.swift` (FR-A24-301, 302, 304, 306): the — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P03.gbl-ios27.json exit 0 (66 core and 42 experience tests); dropped from DroppedFrameRule, probe from renderCapabilities, GPUFrameTimer unless forced unsupported, gpuMs only for measured frames, GPU summary line only with GPU times
  dropped rule; stop at the next frame; the probe from `context.resources.renderCapabilities.extensions`; a
  `GPUFrameTimer` only when supported (seam `forceTimerUnsupported`), bracketing the workload draw; `gpuMs` filled from
  `poll()` results for measured frames; the summary text's GPU line only when GPU times exist
- [X] T-A24-309 [US3] `Experience/ReportSource.swift` (FR-A24-307): `utsname` machine, `operatingSystemVersion`, the — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P03.gbl-ios27.json exit 0 (66 core and 42 experience tests); ReportSource builds the report from public sources and the presenter attaches it to every ended run
  bundle's version and build, `renderCapabilities`, tier, `DeviceConditions.current()` at start and end; the report is
  attached to the finished run
- [X] T-A24-310 [US1] [US2] [US3] Tests `ExperienceTests/{GPUTimingTests,ReportTests}.swift` and `RecorderTests.swift` — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P03.gbl-ios27.json exit 0 (66 core and 42 experience tests); GPUTimingTests (supported on the simulator, measured frames timed 0.02 to 0.17 ms, not device evidence; forced unsupported none), ReportTests, RecorderTests (30 ms dropped, warm-up and cool-down excluded and counted)
  (SC-A24-301–304): warm-up and cool-down excluded and counted; on the simulator a run records GPU times that are
  finite, non-negative and within 1,000 ms for measured frames only; with the seam, none and the flag; every report
  field filled; a 30 ms interval flagged dropped and counted
- [X] T-A24-311 Write and run `specs/175-gbl-p03-runner-probe/scan-identifiers.sh` (`--name scan-identifiers`): no — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P03.scan-identifiers.json exit 0 (no identifier or private use in 38 Swift files)
  `identifierForVendor`, `advertisingIdentifier`, `UIDevice.current.name`, private framework or `dlopen` in
  `Packages/ExperiencesCreative/GraphicsBenchmarkLab` (SC-A24-304)

## Phase 5: Evidence

- [X] T-A24-312 VisualCore evidence: `--name rendering-tests` (the VisualCoreRendering test package on sim-27.2), — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P03.{rendering-tests,public-api,reference-1,reference-2}.json exit 0 (VisualCoreRendering 84 tests on sim-27.2; API baseline matches; reference regression 7 of 7 in two chunks)
  `--name public-api` (`python3 scripts/check_public_api.py`), `--name reference-1` and `--name reference-2` (the two
  reference chunks of quickstart.md) (SC-A24-305)
- [X] T-A24-313 Review checkpoint: `--name gbl-ios27` (both A24 test targets on sim-27.2, each test under 10 s), the — Verified 2026-11-19: 2026-11-19: review checkpoint: .autonomy/checks/A24-P03.{gbl-ios27,documented-api,isolation,core-purity}.json exit 0 (each test well under 10 s)
  documented API, isolation and core purity
- [ ] T-A24-314 Contract: G-RUNNER, G-REPORT, U-RENDERINFO and U-GPUTIMER closed by "A24-P03", rows whose gaps are all
  closed available (`--name contract`); the README of the experience updated
- [ ] T-A24-315 The catalog, packages, script tests, app and runner: `--name catalog`, `experience-packages`,
  `script-tests`; `xcodegen generate --spec project.yml`, then `--name app-unit`; `--name verify-27`
- [ ] T-A24-316 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A24-P03; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

301 → {302, 303, 306}; 303 → 304; {302, 304} → 305; 306 → 307; {305, 307} → 308 → 309 → 310 → 311 → 312 → 313 →
314 → 315 → 316.

## Parallel examples

- **Agent V:** 302, 303, 304 and the README paragraphs of 305. **Agent C:** 306, 307. **Agent E (after V and C):**
  308, 309, 310.
- **Lead:** 301, the API baseline, the scan, the runs, the contract and the commits.

## Implementation strategy

- **MVP:** the timer and the probe (303, 304, 306, 308).
- **Review checkpoint:** at 313.
- **Commits:** one per task.
