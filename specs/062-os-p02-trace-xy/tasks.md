# Tasks: Oscilloscope Studio — Phase 02 Timebase/trigger waveform renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate A08-P02 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A08-P02 --timeout 600 --name <check> -- <command>`. Commit after every task (no trailers). iOS 27 only; reference regression at X-A08
(owner, 2026-11-14).

## Phase 1: Setup

- [ ] T-A08-201 Baseline: cite the A08-P01 evidence on the unchanged tree (`.autonomy/checks/A08-P01.experience-ios27-2.json`, `.autonomy/checks/A08-P01.app-unit.json`, `.autonomy/checks/A08-P01.verify-27-2.json`) instead of a rerun (owner ruling of 2026-11-14)

## Phase 2: Foundational (VisualCore, stories 1 and 2)

- [ ] T-A08-202 [P] [US2] Write `Packages/VisualCore/Tests/VisualCoreAudioDSPTests/MinMaxDecimatorTests.swift` first, then `Packages/VisualCore/Sources/VisualCoreAudioDSP/MinMaxDecimator.swift` per contracts/api.md ("column = ⌊i × N / count⌋", identity when count ≤ N, columns clamped to 1…8,192, non-finite samples skipped, `ColumnRange(min:max:)`, public with `///` docs); tests: squares, single-sample impulses at every position and seeded noise of 2,400 samples reduced to 100…1,000 columns keep every column's true extremes and never exceed the column count; identity for 300 samples / 400 columns; NaN skipped; zero or negative columns → 1 column (FR-A08-201; SC-A08-201)
- [ ] T-A08-203 [P] [US2] Add `Primitive.polyline([Vec2], width: Double)` and `maxPolylinePoints = 8_192` to `Packages/VisualCore/Sources/VisualCoreScenes/SceneGraph.swift` (`bounded`: first 8,192 finite points, |width| finite; `contains`: distance to any segment ≤ width / 2) with tests in `Packages/VisualCore/Tests/VisualCoreScenesTests/SceneGraphTests.swift` (bounding, non-finite points dropped, contains on and off the line; the four existing cases unchanged) (FR-A08-202, 203)
- [ ] T-A08-204 [US2] Draw `.polyline` in `Packages/VisualCoreRendering/Sources/VisualCoreRendering/PrimitiveRenderer.swift` (one quad per non-zero segment, as `.line`, in the same batch) with tests in `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/PrimitiveRendererTests.swift`: a polyline of N points gives 2 (N − 1) triangles for non-zero segments, zero-length segments skipped, rendered pixels equal the same segments drawn as `.line` nodes within 1 % of covered pixels, existing primitive tests unchanged (FR-A08-202, 203; SC-A08-202)

## Phase 3: User Story 1 — a Lissajous figure from stereo input (P1) 🎯

- [ ] T-A08-205 [P] [US1] Core: `ScopeDisplay` {waveform, xy} in `Packages/ExperiencesCreative/OscilloscopeStudio/Core/ScopeSettings.swift`, `ScopeState` schema 2 with `display` (decoder reads schema-1 shape as waveform) in `Core/ScopeState.swift`, `Core/ScopeTrace.swift` (`waveformPoints(_:in:)` zig-zag of column ranges, `xyPoints(left:right:gain:in:)` clamped to ±1 in a centred square); tests in `CoreTests/{ScopeStateTests,ScopeTraceTests}.swift` (schema-2 round trip, schema-1 payload decodes as waveform, digest includes display; zig-zag has 2 points per column and spans each column's min…max; XY points equal scaled pairs, clamped) (FR-A08-211, 212; SC-A08-203)
- [ ] T-A08-206 [US1] Experience: `ScopeCore` schema 2 with migration 1 → 2 (adds `display` 0), action `display.select [0…1]`, `schemaOneExample()` for the registry; `ScopePresenter` draws one polyline per channel from `MinMaxDecimator` over the pixel columns of the grid (waveform) or one XY polyline (stereo windows), mono windows in XY show the waveform with the mark "XY needs two channels" and say so; description names the view and, in XY, the test signal's 2 : 3 ratio; `ScopeControls` adds a display picker (`display.select`, label and identifier); registry passes the schema-1 example in `Apps/VisualCore/App/ExperienceRegistry.swift`; tests in `ExperienceTests/{ScopeCoreTests,ScopeSessionTests,ScopeRenderTests}.swift` (display action; migration of a stored schema-1 snapshot; XY points equal scaled window pairs; mono XY falls back with the mark and returns to XY with a stereo source; polyline node count ≤ 2 per frame; point count ≤ 2 × columns; XY and waveform frames differ) (FR-A08-210–213)

## Phase 4: User Story 3 — the trigger fixture (P2)

- [ ] T-A08-207 [US3] Extend `Experience/Adapter/ScopeManifest.swift` with fixtures for the flat line (silence-level trigger in auto and normal) and the missing crossing in both modes and for XY (`display.select [1]`), regenerate `scenario-manifest.json` (`TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`), update `ExperienceTests/ScopeManifestTests.swift`; session tests prove "no trigger" (auto) and "waiting" (normal) for silence and for a level above the amplitude (FR-A08-213, 220; SC-A08-204)

## Phase 5: Polish & evidence

- [ ] T-A08-208 VisualCore host tests (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P02 --timeout 600 --name visualcore-host -- swift test --package-path Packages/VisualCore --filter "MinMaxDecimatorTests|SceneGraphTests"`)
- [ ] T-A08-209 Renderer tests on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P02 --timeout 600 --name renderer-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --only-testing VisualCoreRenderingTests/PrimitiveRendererTests`)
- [ ] T-A08-210 Oscilloscope Studio tests on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P02 --timeout 600 --name scope-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing OscilloscopeStudioCoreTests OscilloscopeStudioExperienceTests`)
- [ ] T-A08-211 App build and unit (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P02 --timeout 600 --name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`)
- [ ] T-A08-212 Runner iOS 27 (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P02 --timeout 600 --name verify-27 -- python3 scripts/verify_experiences.py --only a08.oscilloscope-studio --runtime 27`)
- [ ] T-A08-213 Experience package check (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P02 --timeout 600 --name experience-packages -- python3 scripts/check_experience_packages.py`)
- [ ] T-A08-214 Public API and docs: `check_public_api.py --update`, `python3 Tools/python/desktop_runbook.py run-check --stage A08-P02 --timeout 600 --name public-api -- python3 scripts/check_public_api.py`; `Packages/VisualCore/README.md` (decimator, polyline) and `Packages/VisualCoreRendering/README.md` (polyline drawing); contract G-DECIMATION, G-TRACESTRIP and G-XYMODE closed by "A08-P02" and `python3 Tools/python/desktop_runbook.py run-check --stage A08-P02 --timeout 600 --name contract -- python3 scripts/check_app_contract.py --app oscilloscope-studio --render`
- [ ] T-A08-215 Script tests (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P02 --timeout 600 --name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A08-216 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A08-P02

## Dependencies

T-A08-201 → (202 ∥ 203 ∥ 205) → 204 (needs 203) → 206 (needs 202–205) → 207 → Polish.

## Parallel examples

Agent A: T-A08-202 + T-A08-203. Agent B: T-A08-205. Agent C: T-A08-204 after A. Agent D: T-A08-206 after A–C.
Lead: 207, docs, contract, runs, commits.

## Implementation strategy

MVP: decimated trace strips and the XY view; then the trigger fixtures; evidence last.
