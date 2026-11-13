# Tasks: R02-F03 — Numerical foundations and deterministic seeded scene time

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md)

Evidence: `python3 scripts/migration_ledger.py run-check --gate R02-F03 --name <check> -- <command>`. Commit after
each task (`scripts/tick_task.py`). Tests before code. Device-only items: none (no {device} task). Owner-only items:
none (no {owner} task). VisualCore changes, so the documentation, API-baseline and reference-regression tasks apply.

## Phase 1: Setup

- [X] T-R02F03-001 Baseline: `swift test --package-path Packages/VisualCore` passes before the change (check — Verified 2026-11-13: swift test Packages/VisualCore passed before the change (baseline-host); research.md section 0 audit re-verified at ebc51a2
  `baseline-host`); research.md §0 audit re-verified.

## Phase 2: User Story 1 — Independent named random streams (P1)

- [X] T-R02F03-002 [P] [US1] Tests first in `Packages/VisualCore/Tests/VisualCoreSimulationTests/SeedDerivationTests.swift`: — Verified 2026-11-13: SeedDerivationTests.swift 7 tests (goldens from an independent Python model: mix, FNV-1a of empty/a/layout, derive label and index, chaining, stream independence) pass
  `mix` equals the SplitMix64 first output for state 0 + golden increment; FNV-1a-64 of "" (`0xcbf29ce484222325`) and
  of "a" (`0xaf63dc4c8601ec8c`); golden `derive(42, label: "layout")`, `derive(42, index: 0)` and `(42, 1)`;
  labels "a"/"b" and indexes 0/1 pairwise different; chaining; `SeededRandom(seed:label:)` equals
  `SeededRandom(seed: derive(seed, label:))`; drawing from one stream does not change another.
- [X] T-R02F03-003 [US1] Write `Packages/VisualCore/Sources/VisualCoreSimulation/SeedDerivation.swift` per data-model — Verified 2026-11-13: SeedDerivation.swift (mix, fnv1a64, derive label/index; SeededRandom(seed:label:), (seed:index:)) with /// docs; its 7 tests pass (host-visualcore)
  "Sub-seed derivation" and contracts/api.md, with `///` on each public declaration.
- [X] T-R02F03-004 [US1] Acceptance: host tests pass (check `host-derivation`) (SC-R02F03-002). — Verified 2026-11-13: swift test Packages/VisualCore PASS incl. SeedDerivation tests (host-visualcore) (SC-R02F03-002)

## Phase 3: User Story 2 — Owned random algorithms (P1)

- [X] T-R02F03-005 [P] [US2] Tests first in `Packages/VisualCore/Tests/VisualCoreSimulationTests/SeededRandomChoiceTests.swift`: — Verified 2026-11-13: SeededRandomChoiceTests 7 tests (one-draw property, golden shuffle [1,8,3,0,4,5,9,6,2,7], picks, weighted counts [248,0,752], all four errors, no draw on error) pass
  `index(below:)` uses exactly one draw (state after equals one `next()`); golden shuffle of 0…9 with seed 7, a
  permutation, n − 1 draws; `pick` uniform golden and `.empty`; `weightedIndex([1, 0, 3])` 1,000 times from a fixed
  seed never returns 1 and equals golden counts; `.empty`, `.negativeWeight(i)`, `.nonFiniteWeight(i)`, `.zeroTotal`.
- [X] T-R02F03-006 [US2] Write `Packages/VisualCore/Sources/VisualCoreSimulation/SeededRandom+Choice.swift` (`index(below:)` — Verified 2026-11-13: SeededRandom+Choice.swift (index(below:) via multipliedFullWidth high half, Fisher-Yates from the end, pick, weightedIndex, RandomChoiceError) with /// docs; tests pass (host-visualcore)
  via the high half of `multipliedFullWidth`, Fisher–Yates from the end, `RandomChoiceError`).
- [X] T-R02F03-007 [US2] Acceptance: host tests pass and the existing `SeededRandomTests` are unchanged and pass — Verified 2026-11-13: host-visualcore PASS; existing SeededRandomTests (seed 42 golden) unchanged and passing (SC-R02F03-003, SC-R02F03-001)
  (check `host-choice`) (SC-R02F03-003, SC-R02F03-001).

## Phase 4: User Story 3 — Saved generator state (P2)

- [X] T-R02F03-008 [P] [US3] Tests first in `Packages/VisualCore/Tests/VisualCoreSimulationTests/SeededRandomStateTests.swift`: — Verified 2026-11-13: SeededRandomStateTests 8 tests (100-draw resume and equality, JSON round trip, version, word count, 9 malformed texts for words and seed, all-zero) pass
  after 100 draws, save, restore, next 100 identical and restored `==` original; JSON round trip; refused:
  `version` ≠ 1, word count ≠ 4, a word not "16 lower-case hexadecimal digits", all-zero words; existing equality
  unchanged.
- [X] T-R02F03-009 [US3] Write `Packages/VisualCore/Sources/VisualCoreSimulation/SeededRandom+State.swift` — Verified 2026-11-13: SeededRandom+State.swift (State version/seed/words, state, init(restoring:) throws(RandomStateError)); SeededRandom state words internal private(set) plus internal initializer, output unchanged; tests pass (host-visualcore)
  (`State { version, seed, words }`, `state`, `init(restoring:) throws(RandomStateError)`); if the state words must be
  read from the extension, change `private` to `fileprivate`/`internal` in `SeededRandom.swift` without changing
  output.
- [X] T-R02F03-010 [US3] Acceptance: host tests pass (check `host-state`) (SC-R02F03-004). — Verified 2026-11-13: host-visualcore PASS incl. state tests (SC-R02F03-004)

## Phase 5: User Story 4 — Shader hash twin (P2)

- [X] T-R02F03-011 [P] [US4] Tests first in `Packages/VisualCore/Tests/VisualCoreMathTests/ShaderHashTests.swift`: — Verified 2026-11-13: ShaderHashTests 5 tests (pcg goldens 129708002, 2831084092, 4099845390, 3861530882; float hash bit-pattern goldens from an independent Python model; -0 vs 0) pass
  `pcg` golden values for 0, 1, 12345, `UInt32.max` (computed from the `vc/hash.glsl` formula and committed);
  `hash11`, `hash21`, `hash22` goldens on a few floats (bit patterns, divide by 4294967296).
- [X] T-R02F03-012 [US4] Write `Packages/VisualCore/Sources/VisualCoreMath/ShaderHash.swift`. — Verified 2026-11-13: ShaderHash.swift (pcg, hash11, hash21, hash22) mirrors vc/hash.glsl; tests pass (host-visualcore)
- [X] T-R02F03-013 [US4] Write `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/ShaderHashParityTests.swift`: — Verified 2026-11-13: ShaderHashParityTests.swift renders vc_pcg per pixel into RGBA8 and compares every word (at least 64, 256 at 2x) with ShaderHash.pcg exactly; passes on sim-27.2 and sim-26.5 (rendering-tests-ios27, rendering-tests-ios26)
  a fragment shader including `vc/hash.glsl` writes the four bytes of `vc_pcg(index)` for 64 pixels into RGBA8; read
  back with `readPixels()` and compare with `ShaderHash.pcg` exactly.
- [X] T-R02F03-014 [US4] Acceptance: host tests (check `host-shader-hash`); rendering package on sim-27.2 and sim-26.5 — Verified 2026-11-13: host-visualcore PASS; VisualCoreRenderingTests 117 tests incl. ShaderHashParityTests pass on iOS 27.2 and 26.5 (rendering-tests-ios27, rendering-tests-ios26); default scheme runs (rendering-ios27/26, 15 UI tests) also pass (SC-R02F03-005)
  (checks `rendering-ios27`, `rendering-ios26`) with 64 of 64 matches (SC-R02F03-005).

## Phase 6: User Story 5 — Numeric hygiene (P2)

- [X] T-R02F03-015 [P] [US5] Tests first in `Packages/VisualCore/Tests/VisualCoreMathTests/NumericHygieneTests.swift`: — Verified 2026-11-13: NumericHygieneTests 7 tests (finite fallback; angle edges pi, 3pi, -7pi/2, 1e9; wrapped -0.5 mod 2, 2 mod 2, -0; errors; quantized 0.26/0.1, ties to even, errors) pass
  `finite` with NaN, ±∞ and a finite value; `normalizedAngle` for 0, π (→ −π), −π, 3π, −7π/2, 1e9 in [−π, π) and
  a whole number of turns away; `wrapped` for −0.5 mod 2, 2 mod 2 (→ 0), errors for modulus 0, −1, ∞, NaN input;
  `quantized` 0.26 step 0.1 → 3, −0.0 → 0, `.nonFinite`, `.nonPositiveStep`, `.outOfRange` for 1e300.
- [X] T-R02F03-016 [US5] Write `Packages/VisualCore/Sources/VisualCoreMath/NumericHygiene.swift` (`NumericError`). — Verified 2026-11-13: NumericHygiene.swift (finite, normalizedAngle, wrapped, quantized, NumericError) with /// docs; tests pass (host-visualcore)
- [X] T-R02F03-017 [US5] Acceptance: host tests pass (check `host-hygiene`) (SC-R02F03-006). — Verified 2026-11-13: host-visualcore PASS incl. hygiene tests (SC-R02F03-006)

## Phase 7: User Story 6 — Determinism document (P3)

- [X] T-R02F03-018 [P] [US6] Tests first in `scripts/tests/test_check_doc_names.py`: a document citing an unknown — Verified 2026-11-13: scripts/tests/test_check_doc_names.py 8 tests OK (unknown name fails, Type.member, non-name spans ignored, whole-word match, exit 2); script-tests PASS
  backticked public name fails; one citing only names of the API baseline passes; non-name code spans (paths, numbers)
  are ignored.
- [X] T-R02F03-019 [US6] Write `scripts/check_doc_names.py` (backticked identifiers that look like public type or member — Verified 2026-11-13: scripts/check_doc_names.py checks backticked public names against the API baseline; its tests pass (script-tests)
  names are checked against `docs/api/visualcore-public-api.txt`).
- [X] T-R02F03-020 [US6] Write `docs/architecture/determinism.md` (FR-R02F03-060, 061: step policy, integer-only — Verified 2026-11-13: docs/architecture/determinism.md: step policy, integer rules, float trust boundary, derivation, choice draw counts, saved state, shader twin, hygiene, replay, transform conventions, UIKit conversion
  rules, trust boundary of transcendental functions, stream derivation, replay format, transform conventions, UIKit
  y-down conversion).
- [X] T-R02F03-021 [US6] Acceptance: `python3 scripts/check_doc_names.py docs/architecture/determinism.md` passes — Verified 2026-11-13: check_doc_names.py docs/architecture/determinism.md PASS after the baseline update, 41 names (doc-names) (SC-R02F03-007)
  after the API baseline update (check `doc-names`) (SC-R02F03-007).

## Phase 8: Polish and cross-cutting

- [X] T-R02F03-022 API baseline: `python3 scripts/check_public_api.py --update` then `check_public_api.py` (check — Verified 2026-11-13: check_public_api.py --update: 2328 declarations, 0 undocumented, 32 additions equal to contracts/api.md; check_public_api PASS (public-api); check_documented_api --sources Apps/VisualCore PASS (documented-api)
  `public-api`); `python3 scripts/check_documented_api.py --sources Apps/VisualCore` (check `documented-api`).
- [X] T-R02F03-023 `Packages/VisualCore/README.md` section "Numerical foundations (feature 203, R02-F03)". — Verified 2026-11-13: Packages/VisualCore/README.md section Numerical foundations (feature 203, R02-F03) added; its new names exist in the API baseline
- [X] T-R02F03-024 Full host suite `swift test --package-path Packages/VisualCore` (check `host-visualcore`); record — Verified 2026-11-13: swift test Packages/VisualCore PASS (host-visualcore); new suites: SeededRandomChoice 0.030 s, ShaderHash 0.001 s, NumericHygiene 0.001 s, derivation and state tests at most 0.012 s each, all under 1 s (SC-R02F03-008)
  the duration of each new suite from the output, each under 1 s (SC-R02F03-008).
- [ ] T-R02F03-025 Committed digests unchanged: `python3 scripts/verify_experiences.py --only a01.generative-art-studio
  a02.fluid-art-playground a03.fractal-explorer --runtime 27` (check `verify-a01-a03`) and the ExperiencesCreative
  package tests with A04's committed digests and `seedStep`: `python3 scripts/xcodebuild_package.py --package
  Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test` (check
  `experiences-ios27`) (FR-R02F03-002, FR-R02F03-013).
- [ ] T-R02F03-026 Reference regression chunk 1: `python3 scripts/release_check.py --only reference-engine-xcframework
  reference-build-projectm-ios-sim reference-clean` (check `reference-1`).
- [ ] T-R02F03-027 Reference regression chunk 2: `python3 scripts/release_check.py --only
  reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27
  projectm-reference-ios26` (check `reference-2`).
- [ ] T-R02F03-028 Script tests `python3 scripts/test_scripts.py` (check `script-tests`).
- [ ] T-R02F03-029 Auto-Creator.md section 13 row R02-F03 as built via `docs/catalog/shared-feature-map.json` and
  `render_autocreator.py`; `validate_autocreator.py`, `validate_docs.py`, `migration_baseline.py verify`; CI of a
  commit with all changes finished with success.
- [ ] T-R02F03-030 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  R02-F03.

## Dependencies

001 → stories 1–6 (independent files; parallel) → 022 (baseline after all public additions) → 021 (document check
needs the baseline) → 023–029 → 030.

## Parallel execution (one writer per file)

Agent A: 002–003. Agent B: 005–006. Agent C: 008–009 (sole writer of `SeededRandom.swift`). Agent D: 011–013.
Agent E: 015–016. Agent F: 018–020. Lead: acceptances, 022–030.

## Implementation strategy

MVP: stories 1 and 2. Review checkpoint after each story's acceptance task.
