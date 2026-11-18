# Tasks: Shader Studio — Phase 02 Compile and last-good-preview path

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/experience.md](contracts/experience.md), [quickstart.md](quickstart.md). Gate A22-P02 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A22-P02 --timeout 595 --name <check> -- <command>`.
- **Commits:** one after every task, with no trailers.
- **Checks:** read every check's exit before ticking, never in the same command.
- **Scope:** iOS 27 only; no VisualCore change.
- **Precedent:** `specs/153-au-p02-scene-controls/tasks.md`.
- **Rollback:** revert the commits.

## Phase 1: Setup

- [X] T-A22-201 Baseline: cite the A22-P01 evidence (`.autonomy/checks/A22-P01.{ss-core-ios27-2,app-build,experience-packages}.json`) — Verified 2026-11-17: 2026-11-17: A22-P01 evidence cited: .autonomy/checks/A22-P01.ss-core-ios27-2.json, A22-P01.app-build.json and A22-P01.experience-packages.json, all exit 0; no Packages change since the A22-P01 record commit 5133f65e
  on the tree recorded at A22-P01 (`5133f65e`), whose Packages are unchanged since (owner ruling of 2026-11-14)
- [X] T-A22-202 Add the targets `ShaderStudioExperience` (path `ShaderStudio/Experience`) and — Verified 2026-11-18: 2026-11-18: ShaderStudioExperience and ShaderStudioExperienceTests targets and the ShaderStudioExperience product in Packages/ExperiencesCreative/Package.swift (VisualCorePersistence added for MigrationChain); .autonomy/checks/A22-P02.ss-ios27.json exit 0
  `ShaderStudioExperienceTests` (path `ShaderStudio/ExperienceTests`), with the products of plan.md and the
  `ShaderStudioExperience` library product, to `Packages/ExperiencesCreative/Package.swift` (lead)

## Phase 2: Story 1 — start from a template and run it (P1) 🎯

- [X] T-A22-203 [US1] Create `Packages/ExperiencesCreative/ShaderStudio/Experience/Adapter/StudioCore.swift` per data-model.md: — Verified 2026-11-18: 2026-11-18: Adapter/StudioCore.swift: snapshot schema 1, digest a22.shader-studio.v1 over template and 16 normalized values, runs in the snapshot only; template.select, uniform.set, shader.run; rules a22.not-whole, a22.no-uniform; restore refusals; .autonomy/checks/A22-P02.ss-ios27.json exit 0; written by an agent, retested
  - "snapshot schema 1, digest `a22.shader-studio.v1` over template and values";
  - `template` "0…2, integer"; `values` "16 entries, 0…1"; `runs`;
  - the actions `template.select [0…2]`, `uniform.set [0…15, 0…1]` and `shader.run [1…1]`;
  - the rules `a22.not-whole` and `a22.no-uniform`;
  - restore refusals for damaged or out-of-range snapshots;
  - `///` on every declaration
  (FR-A22-201, 205)
- [X] T-A22-204 [US1] Create `Experience/{PreviewPipeline,StudioPresenter,StudioControls,ShaderStudioExperience}.swift` — Verified 2026-11-18: 2026-11-18: PreviewPipeline (newest request, validate, compile through context.resources.program at the next draw, at most one per frame, swap a FullScreenShaderScene only on success, compileCount, rebuild after context loss), StudioPresenter (document, setSource seam, denormalized uniforms, 30 fps, level-0, no GL call), StudioControls (template, run, uniform-k, status, diagnostics with spoken labels), ShaderStudioExperience.make(id:storage:); isolation PASS; .autonomy/checks/A22-P02.ss-ios27.json and A22-P02.isolation.json exit 0; written by an agent, retested
  per clarifications Q2–Q4 and contracts/experience.md (FR-A22-201–206):
  - `PreviewPipeline` takes the newest request, validates it and compiles through `context.resources.program` at the
    next draw, at most once per frame. A `FullScreenShaderScene` (`ShaderBundle(files:)` of the assembly) is swapped in
    only on success. It counts compiles (`compileCount`), drops the pending request on teardown, and rebuilds the
    last good scene after a context loss or resize.
  - `StudioPresenter` holds the document. `setSource(_:)` is the seam for tests and A22-P03. It reads the run count
    and template from the core, and sets the live scene's parameters from the denormalized values.
    `maxFramesPerSecond` is 30, the tier is `level-0`, and there is no GL call of its own.
  - `StudioControls` has the template picker, Run, uniform sliders, status and diagnostics, with the identifiers
    `template`, `run`, `uniform-<k>`, `status` and `diagnostics`, and spoken labels.
  - `ShaderStudioExperience.make(id:storage:)` follows `AuroraExperience`.
- [X] T-A22-205 [US1] Write `ExperienceTests/{StudioTestSupport,StudioCoreTests}.swift` (SC-A22-204): — Verified 2026-11-18: 2026-11-18: StudioTestSupport and StudioCoreTests (actions, refusals, digest ignores runs; each template draws Compiled off screen); .autonomy/checks/A22-P02.ss-ios27.json exit 0 (26 experience tests); written by an agent, retested
  - the actions and refusals, and a digest that ignores the run count;
  - each template draws in the session host off screen with the status Compiled.

## Phase 3: Story 2 — a broken shader never breaks the preview (P1)

- [X] T-A22-206 [US2] Write `ExperienceTests/{LastGoodPreviewTests,RunQueueTests}.swift` (SC-A22-201–203): — Verified 2026-11-18: 2026-11-18: LastGoodPreviewTests and RunQueueTests: compile error, link error (an unwritten varying), refused source and a failing first run leave the read-back pixels byte-identical; diagnostics on the authored lines; a fix replaces the picture and clears them; three runs before a frame give one compile; a template switch while pending compiles the new template; teardown with a pending request compiles nothing; .autonomy/checks/A22-P02.ss-ios27.json exit 0; written by an agent, retested
  - each failure leaves the read-back pixels byte-identical: a compile error, a link error, a refused source, and a
    first run that fails;
  - diagnostics are on the authored lines, and a fix replaces the picture and clears them;
  - a warnings-only compile replaces the preview and lists its warnings;
  - three runs before one frame give `compileCount` + 1;
  - a template switch while a request is pending compiles the new template;
  - closing with a request pending compiles nothing.

## Phase 4: Stories 3 and 4 — uniforms and interruptions (P2)

- [X] T-A22-207 [US3, US4] Write `ExperienceTests/{UniformPreviewTests,RebuildTests}.swift` (FR-A22-205, 206): — Verified 2026-11-18: 2026-11-18: UniformPreviewTests (two values give different pictures and no compile; out-of-range and fractional indices refused) and RebuildTests (recreateContext and a resize redraw the same shader with the same values, nothing leaked); .autonomy/checks/A22-P02.ss-ios27.json exit 0; written by an agent, retested
  - two values of a uniform give different pictures and no compile;
  - an out-of-range or fractional index is refused;
  - after `recreateContext` and after a resize, the same shader draws with the same values.

## Phase 5: Registration and evidence

- [X] T-A22-208 Register the candidate (FR-A22-207): — Verified 2026-11-18: 2026-11-18: Catalog/registrations.json candidate a22.shader-studio (five capabilities of at most 40 characters, quality tier level-0, palette, manifest, permissions []), build_catalog; ExperienceRegistry candidate shaderStudio (no examples, schema 1); project.yml product ShaderStudioExperience; the synthetic candidate in AppModelTests moved to a23.visual-programming-lab; RealCatalogTests and test_scripts lists; .autonomy/checks/A22-P02.catalog.json, A22-P02.realcatalog.json, A22-P02.experience-packages.json and A22-P02.script-tests-2.json exit 0 (the first script-tests attempt failed on the content-count audit: 4 fixtures below 5, fixed)
  - a `Catalog/registrations.json` entry for a22: capabilities of at most 40 characters each, quality_tiers
    ["level-0"], a palette, manifest `Packages/ExperiencesCreative/ShaderStudio/scenario-manifest.json`, permissions
    []; then run `python3 scripts/build_catalog.py`;
  - in `Apps/VisualCore/App/ExperienceRegistry.swift`, the candidate `shaderStudio` (no examples: schema 1) inside an
    `extension ExperienceRegistry`;
  - the `project.yml` product;
  - in `Apps/VisualCore/Tests/Unit/AppModelTests.swift`, the synthetic candidate id moves to
    `a23.visual-programming-lab`;
  - the candidate lists in the app and script tests.
- [X] T-A22-209 Write `Experience/Adapter/StudioManifest.swift` (nine standard scenarios, plus fixtures per template and — Verified 2026-11-18: 2026-11-18: Adapter/StudioManifest.swift (StudioCore.manifest(for:): nine standard scenarios and fixtures gradient, noise-flow, rings and broken-run-keeps-preview), StudioManifestTests, scenario-manifest.json generated and matching; .autonomy/checks/A22-P02.ss-ios27.json exit 0; written by an agent, retested
  for a broken run that keeps the preview) and `ExperienceTests/StudioManifestTests.swift`. Generate
  `scenario-manifest.json` with `UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`.
- [X] T-A22-210 Review checkpoint: — Verified 2026-11-18: 2026-11-18: review checkpoint: .autonomy/checks/A22-P02.ss-ios27-3.json exit 0 (51 core and 26 experience tests on sim-27.2, each under 10 s), A22-P02.documented-api.json, A22-P02.isolation.json and A22-P02.core-purity.json exit 0
  - Shader Studio tests on sim-27.2: `--name ss-ios27 -- python3 scripts/xcodebuild_package.py --package
    Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test
    --only-testing ShaderStudioCoreTests ShaderStudioExperienceTests`;
  - the documented API, isolation and core purity.
- [ ] T-A22-211 Contract: G-PREVIEW and G-RUN are closed by "A22-P02", and rows whose gaps are all closed become
  available with evidence (`--name contract`)
- [ ] T-A22-212 The catalog, app and runner checks, with the packages and script tests:
  - the catalog (`--name catalog`);
  - the app build and unit tests: `xcodegen generate --spec project.yml`, then `--name app-unit -- python3
    scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`;
  - the runner: `--name verify-27 -- python3 scripts/verify_experiences.py --only a22.shader-studio --runtime 27`.
- [ ] T-A22-213 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A22-P02; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

201 → 202 → 203 → 204 → {205, 206, 207, 209} → 208 → 210 → 211 → 212 → 213.
- **Test files:** 205–207 and 209 are separate files.
- **Registration:** 208 needs 209's manifest.

## Parallel examples

- **Agent C:** 203 and 205.
- **Agent P:** 204, 206 and 207.
- **Agent M:** 209, after 203.
- **Lead:** Package.swift (202), the registration (208), the runs, the contract and the commits.

## Implementation strategy

- **MVP:** the core and the preview pipeline (203, 204), with the last-good regression fixture (206).
- **Then:** uniforms and rebuild (207), the manifest and registration (208, 209) and the evidence.
- **Review checkpoint:** at 210.
- **Commits:** one per task.
