# Contract: test boundaries, ProjectM adapter, submodule policy, regression (FR-F108–FR-F111)

## Test boundaries (FR-F108)

| Layer | Where | Command | Evidence class |
|---|---|---|---|
| Pure VisualCore modules | macOS host | `swift test --package-path Packages/VisualCore` | functional |
| Rendering/effects/UI/audio bridge | iOS 27.2 **and** 26.5 simulators | `xcodebuild test -scheme VisualCoreRendering-Package …` | functional (pixel readback) |
| Apps/Showcase/harness UI | iOS simulators | XCUITest via `xcodebuild test` | functional |
| Compile coverage | generic iOS | `xcodebuild build -destination generic/platform=iOS CODE_SIGNING_ALLOWED=NO` | build |
| Performance, thermal, real audio, GPU lifecycle on hardware | D1/D2/D3 | campaign II only, after IMPLEMENTATION-LOCK | device |

## ProjectM reference adapter (FR-F109)

* Lives only in `Harnesses/ProjectMReference/` with its own `ProjectMReference.yml`, never in
  `project.yml`.
* **May:** create a `RenderHost`, supply a `RenderScene` that creates the unmodified `ProjectMEngine`
  with the host's EGL load proc, render the engine's upstream test preset, and expose diagnostics.
* **Must not:** modify any reference file, link ProjectM into another target, add preset-library or
  StoreKit code, or claim audio-source compatibility.
* LGPL: the engine stays a separate dynamic framework (as in the reference); the harness is not
  distributed (tester tool). Distribution would need a fresh linkage analysis.

## Submodule policy (FR-F110)

* `External/projectm-ios` is pinned by the superproject gitlink. Nested pins: projectM
  `Coastrnaut/projectm@ios` and ANGLE `Coastrnaut/angle@ios`.
* An agent never changes, updates, resets or cleans the submodule or its nested pins. Only gitignored
  build outputs from the reference's own scripts are allowed.
* A pin change requires an owner-approved ADR, an upstream-ready patch with an entry in the
  reference's `docs/projectm-patches.md`, then the full regression below.
* `scripts/check_reference_clean.py` runs before and after any reference build.

## Compatibility and regression (FR-F111)

| Trigger | Required checks |
|---|---|
| Any change in `Packages/VisualCoreRendering` (host, GL table, resources) | VisualCoreRendering sim tests on iOS 27.2 + 26.5; reference baseline `test-anglerendering-ios27/26`; `ProjectMReference` harness build + sim test (from F07) |
| Any change in `Packages/VisualCore` | host `swift test`; dependent sim tests |
| Reference pin change (owner-approved) | full `scripts/run_reference_baseline.py` sequence + clean checks + all of the above |
| Every commit | `validate_docs.py`, `check_compliance.py`, `check_dependencies.py`, `test_scripts.py` |
