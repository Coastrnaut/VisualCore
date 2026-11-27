# Implementation Plan: R02-G21-08 — Binary Gardens: visual golden and solver regression

**Branch**: `508-binary-gardens-visual-golden-solver-regression` (spec directory only; work on `main`) | **Date**:
2026-11-27 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/508-binary-gardens-visual-golden-solver-regression/spec.md`

## Summary

Add Binary Gardens' regression net on Mushroom Weather's feature-498 pattern: a host solver regression over all 100
levels (the generated level equal to its witness's level part by part and by fingerprint; exact witness replay with
per-action fingerprints, digests and report, a win on exactly the final `run` and on no proper prefix; exact re-plan to
the witness's arrangement actions with `arrangementsByDepth[size − 1]`, `nearestMiss` and `nearestMissArrangement`
equal to the counterexample's and `work` equal to the difficulty's and at most `workBound`; thirteen named
alterations); a code-only golden set of 17 frame descriptions (`BinaryGardensGolden`, DEBUG or VISUALCORE_AUTOMATION
only, pinned in `golden-frames.json` with SHA-256 digests, 1/8-pixel quantum fallback and a self-check; the palette and
material table taken whole); simulator tests that render the 17 frames against their descriptions and bound memory
over 12 open–draw–warn–close cycles; a named CI step and a local command. The release check's forbidden-symbol list
gains `BinaryGardensGolden`. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-27, read-only)**: `BinaryGardensSolver.plan(_:maxDepth:workBound:)` returns `BinaryGardensPlan`
(`actions`, `arrangement`, `arrangementsByDepth`, `nearestMiss`, `nearestMissArrangement`, `work`; `workBound` 5,000);
`BinaryGardensBandProfile.of(band:).plan` is 1, 2, 3, 3, 4; `BinaryGardensWitness.decode` reads the 100 witness files
(schema 1: number, level, actions ending with `run`, digests, fingerprints after `begin`, after `dismissTutorial` on
levels 1 … 3 and after each action, report, counterexample `depth`, `arrangements`, `nearestMiss`, `arrangement`,
`failure`, difficulty with `work`, skipped); the catalog's largest work is 1,589 (level 88; level 81: 893), the total
23,464; `BinaryGardensExperienceCore.generated(number:)`, `level(number:)`, `freshPlay(of:)`, `certifiedActions(_:)`,
`heroTick(_:)`, `manifestSeed` and `levelNumber(forSeed:)` (seed s → level s % 100 + 1) exist;
`BinaryGardensSceneSnapshot(play:shownTick:levelNumber:time:)` leaves `preview` and `inspectedWorld` nil;
`BinaryGardensSceneGeometry` has `camera(aspect:)` (the authored orbit), `project`, `referencePoints` (barycentre,
worlds, stars, `gaugeMargin(0)`, `actionsBar(0, _)`), `tiltPipCentre`, `luminosityPips`, `litActions`, `paintOrder`;
`BinaryGardensPalette.all` (internal, 27 entries) and `BinaryGardensShaders.materials` (42 entries, codes 0 … 41, each
with its GLSL palette constant); `BinaryGardensSystemScene.release()` and `liveObjectCount` exist and the presenter's
`teardown` and `shedCaches` call `release()`; `ProcessMemory.footprint()` (VisualCoreRendering); the feature-503
frame-check helpers are `BinaryGardensTest` (1,152 × 768, `checkTick` 24, the 0.15 / 0.4 / 0.08 / 0.05 / 0.06
tolerances); CI half b's filter already includes `BinaryGardens`; locally Binary Gardens runs in round-two host chunk 2.
**Prerequisites recorded first** (planned, specified and tasked, not in code except 504's core parts): R02-G21-04
(feature 504: presenter and panel work still open), R02-G21-05 (feature 505: progress, modes, tutorial steps, snapshot
schema 2, digest v2, the regenerated scenario manifest), R02-G21-06 (feature 506: eased lights and the Reduce Flashing
glow cap in the scene and presenter) and R02-G21-07 (feature 507: schema 3, replay, the saved sound). The golden
baseline is generated only after all four are recorded; readers of their parts: the hero frame reads the scenario
manifest as 505 and 507 leave it, the simulator frames draw through the presenter as 504 and 506 leave it.
**Language/Version**: Swift 6 and Python 3. **Primary dependencies**: the Binary Gardens Core, `StableHash.sha256Hex`
of VisualCoreMath (no CryptoKit), VisualCoreRendering (`ProcessMemory.footprint()`, iOS tests). No new package, target,
GLSL, Objective-C++ or VisualCore API (no API baseline change). **Storage**: the pinned `golden-frames.json` only.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02 --filter BinaryGardensRegression`; simulator
package tests on sim-27.2; app unit tests; the reference regression in two chunks; script tests alone; seed 2_508.
**Target platform**: iOS 27.x and 26.5 simulators now; frame time and memory on D1–D3 after ImplementationLock-100.
**Performance (counted, never timed)**: the re-plan judges exactly 23,464 arrangements over the 100 levels (each one
kernel report over 48 ticks for at most 3 catalog worlds; at most 9,238 in the heaviest group, levels 81 … 90, and at
most 1,589 per level, under the 5,000 bound); the replays apply 463 checked fingerprints over 360 witness actions; the
prefix check runs 260 proper prefixes then `run` (520 kernel actions); 39 alterations (13 kinds × levels 1, 41, 81),
each level kind rebuilt through the initialiser from a fixed candidate list of at most 8 values; 17 descriptions, each
one snapshot of at most 4 plan actions and at most 1 + 3 + 2 + 3 projected points, 27 colours and 42 materials; the
simulator draws 17 golden frames and 12 × 4 = 48 memory frames.
**Constraints**: no wall-clock assertion; each test under 10 s (the 100-level solver checks in 10 groups of 10); the
golden manifest is rewritten only with `BINARY_GARDENS_WRITE_GOLDEN=1`; the memory bound applies only when the memory
class runs alone (`TEST_RUNNER_BINARY_GARDENS_MEMORY_ISOLATED=1`); nothing changes the rules, levels, witnesses or
state.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — frames drawn by the existing system scene; no renderer change. |
| II App-neutral API | PASS — game code in ExperiencesRound02; VisualCore unchanged. |
| II-a Preserve the reference | PASS — the reference regression runs in two chunks (7 of 7). |
| III GPU lifecycle | PASS — memory test proves `liveObjectCount` 0 after each close and warning, rebuilt next frame. |
| IV Host-testable | PASS — solver and golden-description checks on the host; rendering and memory on the simulator. |
| V Implementation before devices | PASS — device frame time and memory wait for D1–D3 (SC-R02G2108-007). |
| VI Evidence over assertion | PASS — counted work and pinned digests; agent results retested by the lead. |
| IX Bounded input | PASS — a damaged manifest fails naming file and frame; the search bound fails, never hangs. |
| X Licensing and provenance / XIII Code-driven visuals | PASS — baselines are code-computed descriptions, no images. |
| XI One app | PASS — the golden set is test-only and forbidden in the Release binary. |
| XII One purchase, no advertising | PASS — tier free; nothing sold or shown. |

Determinism (fixed seeds, seed 2_508 for alterations, counted work, no clock or random source) is checked under IV and
VI. Post-design re-check: PASS (the data model and contract add one DEBUG-only Core type and test files; no
dependency, target, public VisualCore name or state change).

## Project Structure

```text
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensGolden.swift
    new   frames, snapshot, description, digest, manifest, compare, writeIfRequested (lead)
Packages/ExperiencesRound02/BinaryGardens/golden-frames.json
    new   17 frames, schema 1; written with BINARY_GARDENS_WRITE_GOLDEN=1 after 507 is recorded (lead)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensRegressionSolverTests.swift
    new   100 levels in 10 groups; level, replay, prefixes, re-plan; 13 alterations on 1, 41, 81 (agent B)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensRegressionGoldenTests.swift
    new   frame set, digests vs pinned, quantum fallback, self-check, switch on a temp file (agent C)
Packages/ExperiencesRound02/BinaryGardens/ExperienceTests/BinaryGardensRegressionGoldenFrameTests.swift
    new   17 rendered frames vs descriptions with the feature-503 tolerances (agent C)
Packages/ExperiencesRound02/BinaryGardens/ExperienceTests/BinaryGardensRegressionMemoryTests.swift
    new   12 open-draw-warn-close cycles, liveObjectCount, 16 MB isolated bound (agent C)
scripts/binary_gardens_regression.py
    new   local command: host, then simulator; --dry-run, --skip-simulator (agent B)
scripts/test_scripts.py
    edit  BinaryGardensRegressionTests class (agent B drafts it as a separate file; lead inserts)
scripts/release_check.py
    edit  RELEASE_FORBIDDEN gains BinaryGardensGolden (lead)
.github/workflows/ci.yml
    edit  step "Binary Gardens regression (host)" in half b after Mushroom Weather's (lead)
docs/architecture/binary-gardens.md
Packages/ExperiencesRound02/README.md
docs/automatedtesting.md
README.md
    edit  regression net, golden set, local command, chunk 2 (lead)
```

`golden-frames.json` sits beside `scenario-manifest.json`, outside the Core target's path, and is read by `#filePath`.
Files are picked up by path; no app file is added, so `xcodegen generate` is not needed. The invariant test's fixed
10-file kernel list is unchanged (the new Core file is not a kernel file).

**Dependency graph**: features 504, 505, 506 and 507 recorded → baselines → solver regression (B; may be drafted
earlier, spec Q6) → `BinaryGardensGolden` and the pinned manifest (lead) → golden description tests (C) → simulator
golden-frame and memory tests (C) → local command and its script test (B), CI step, release check (lead) → docs.
**Migration**: none (no state change; the golden manifest is a new file at schema 1). **Rollback**: revert the
feature's commits; nothing persists and no saved state is touched. **CI**: the `ci` workflow's round02 half b filter
already runs `BinaryGardens` (no new half, no filter change); a named step runs the regression filter alone; the script
tests and the steering validators run on every push; the simulator suite and the reference regression run locally.

## Parallel work

Implementation starts after R02-G21-04 … 07 are recorded; agent B may draft the solver regression earlier in an
isolated copy, because the solver, levels and witnesses are fixed since R02-G21-02. Agent B (solver regression, local
command, script-test draft) and agent C (golden description tests, simulator golden-frame and memory tests, against the
contract) write their new files in isolated copies in parallel; the lead writes `BinaryGardensGolden`, pins the
manifest and edits the shared release check, CI workflow, `test_scripts.py` and docs. One writer per file; agents do
not build in the repository, commit or push; the lead runs every check, retests each agent result and records only
after every agent has reported. No agent runs `swift test` while a baseline or a chain of the lead runs.
