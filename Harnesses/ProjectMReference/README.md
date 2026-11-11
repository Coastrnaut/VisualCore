# ProjectMReference harness

Runs the **unmodified** ProjectM engine (reference `External/projectm-ios` @ `d93edd1`, read-only) on VisualCore's
render host. It is the only target allowed to link reference modules (rule R1) and exists to prove and regress
the integration (feature 008 / ledger gate F07; contract `specs/008-projectm-integration/contracts/projectm-adapter.md`).

* `ProjectMScene` — the engine as a VisualCore `RenderScene` (created with `vcEGLLoadProc`, recreated per context
  generation, released with its context current, GL state handed back with `GLState.resetForVisualCore`).
* `EngineFramebufferPath` — the reference renderer's per-frame sequence into an offscreen target (baseline path A).
* `SyntheticSignal` — deterministic test audio; no capture. `ImageDiff` — A/B metric.
* App — preset picker of the upstream test presets (`Vendor/projectM/presets/tests`), live diagnostics, Reduce
  Flashing via VisualCore's `EffectScene` limiter.

```sh
xcodegen generate --spec Harnesses/ProjectMReference/ProjectMReference.yml
xcodebuild test -project Harnesses/ProjectMReference/ProjectMReference.xcodeproj -scheme ProjectMReference \
  -destination 'platform=iOS Simulator,id=<sim>' -test-timeouts-enabled YES -default-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO
```

Requires the reference's prebuilt `Build/ProjectM.xcframework` and `Build/ANGLEFrameworks` (built by the reference's
own scripts, `scripts/run_reference_baseline.py --step engine-xcframework`).

**Licensing:** tester tool, not distributed. The LGPL engine stays the reference's separate dynamic framework, as in
the reference app. Any distribution needs a fresh linkage analysis. Bundle id `dev.visualcore.harness.ProjectMReference`.

**Baseline criterion:** the engine animates on wall-clock time, so two identical renders differ slightly; the A/B test
measures the engine's own noise floor in the same run and requires the VisualCore path to be within it (SC-F702 as
amended 2026-11-10).
