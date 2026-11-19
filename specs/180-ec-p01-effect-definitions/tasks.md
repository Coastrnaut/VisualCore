# Tasks: Effects Composer — Phase 01 Effect definitions and render contracts

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/core.md](contracts/core.md), [quickstart.md](quickstart.md). Gate A25-P01 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A25-P01 --timeout 595 --name <check> -- <command>`.
- **Commits:** one after every task, with no trailers.
- **Checks:** read every check's exit before ticking, never in the same command.
- **Scope:** no VisualCore change; a pending core only.
- **Precedent:** `specs/173-gbl-p01-measurement-statistics/tasks.md`.
- **Rollback:** revert the commits.

## Phase 1: Setup

- [ ] T-A25-101 Baseline: cite the A25-P00 evidence (`.autonomy/checks/A25-P00.{app-build,no-change,experience-packages}.json`)
- [ ] T-A25-102 Add `EffectsComposerCore` (path `EffectsComposer/Core`; VisualCoreExperience, VisualCorePersistence) and
  `EffectsComposerCoreTests` (also VisualCoreRendering) to `Packages/ExperiencesCreative/Package.swift` (lead); the
  package check still passes as a pending core

## Phase 2: Story 1 — five effects with bounded parameters (P1) 🎯

- [ ] T-A25-103 [P] [US1] Create `Packages/ExperiencesCreative/EffectsComposer/Core/EffectDefinition.swift` per contracts/core.md and clarification Q1: `EffectID`,
  `ParameterSpec` (range closed and finite, default inside, whole), `EffectDefinition` (fingerprint domain
  `a25.effect.v1`), `EffectLibrary.all` (grade, blur, distort, vignette, posterize) and value validation naming the
  effect and parameter
- [ ] T-A25-104 [P] [US1] Write `Packages/ExperiencesCreative/EffectsComposer/CoreTests/DefinitionTests.swift`: every default validates; unknown, missing,
  non-finite, fractional-whole and out-of-range values are refused with their code; fingerprints are distinct and stable

## Phase 3: Story 2 — a chain that can be edited and undone exactly (P1)

- [ ] T-A25-105 [US2] Create `Packages/ExperiencesCreative/EffectsComposer/Core/EffectChain.swift` and `Packages/ExperiencesCreative/EffectsComposer/Core/ChainEditing.swift` per clarification Q2: at most 8
  nodes, identifiers 1…65,535 unique (smallest unused for a new node), the five edits with move's index semantics,
  `EditHistory` (undo and redo, depth 64, a new edit clears redo, a refused edit changes nothing), the chain
  fingerprint (domain `a25.effect-chain.v1`)
- [ ] T-A25-106 [P] [US2] Write `Packages/ExperiencesCreative/EffectsComposer/CoreTests/{ChainTests,HistoryTests}.swift`: caps and refusals; a recorded sequence of
  every edit kind undone to the start is equal with the same fingerprint, and redone to the end equal again; undo or redo
  with nothing to do is refused; the depth cap drops the oldest edit

## Phase 4: Story 3 and Story 4 — the render contract (P1, P2)

- [ ] T-A25-107 [P] [US3] [US4] Create `Packages/ExperiencesCreative/EffectsComposer/Core/{TestImage,EffectReference,EffectPrograms}.swift` per clarifications Q1
  and Q4: the 64 × 64 test image, `RGBAImage`, the CPU reference of each effect, and each effect's fragment program
  (input `u_source`, packed `u_params`/`u_params2` vec4 and `u_texel`)
- [ ] T-A25-108 [US3] [US4] Write `Packages/ExperiencesCreative/EffectsComposer/CoreTests/{ReferenceTests,ProgramRenderTests,OrderTests,RenderSupport}.swift`:
  reference identities (defaults of grade, radius-0 blur, amplitude-0 distort and amount-0 vignette leave the image
  unchanged); inside a `RenderHost` scene every program compiles with `FieldPass` and chosen pixels at defaults and at
  one non-default value match the reference within 2/255 (4/255 for distort); grade (contrast 2) then posterize (4)
  differs from the reverse, and undoing the swap gives a byte-identical picture (FR-A25-104, 105; SC-A25-103, 104)

## Phase 5: Story 5 — the chain file (P2)

- [ ] T-A25-109 [P] [US5] Create `Packages/ExperiencesCreative/EffectsComposer/Core/ChainDocument.swift` per clarification Q3 and write
  `Packages/ExperiencesCreative/EffectsComposer/CoreTests/ChainDocumentTests.swift`: byte-identical round trip; every refusal code from a damaged, newer,
  oversized, non-finite, out-of-range, unknown-effect, unknown-parameter, missing-parameter, too-many-nodes and
  duplicate-node file

## Phase 6: Records and evidence

- [ ] T-A25-110 Write `Packages/ExperiencesCreative/EffectsComposer/CoreTests/HostCountTests.swift` per clarification Q5 (FR-A25-107, SC-A25-106)
- [ ] T-A25-111 Core tests on sim-27.2, as a review checkpoint (SC-A25-106, FR-A25-108):
  - `--name ec-core-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme
    ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing EffectsComposerCoreTests`, with each
    test under 10 s;
  - the purity scan (`--name core-purity -- sh -c '! grep -rnE "import (UIKit|SwiftUI|OpenGLES|VisualCoreRendering)|vcgl|Date\\(\\)" Packages/ExperiencesCreative/EffectsComposer/Core'`);
  - the documented API (`--name documented-api -- python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/EffectsComposer`);
  - the isolation check (`--name isolation -- python3 scripts/check_app_isolation.py --experiences Packages/ExperiencesCreative/EffectsComposer`).
- [ ] T-A25-112 Contract `docs/apps/effects-composer/visualcore-contract.json`: G-MODEL and G-EFFECTS are closed by
  "A25-P01", and rows whose gaps are all closed become available with evidence (`--name contract -- python3
  scripts/check_app_contract.py --app effects-composer --render`); list the core in `docs/apps/effects-composer/README.md`
- [ ] T-A25-113 The packages, catalog and script tests and the app build:
  - `--name experience-packages -- python3 scripts/check_experience_packages.py`;
  - `--name catalog -- python3 scripts/build_catalog.py --check`;
  - `--name script-tests -- python3 scripts/test_scripts.py`;
  - `--name app-build -- python3 scripts/release_check.py --only app-build-for-testing-ios27`.
- [ ] T-A25-114 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A25-P01; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

101 → 102 → {103, 105, 107, 109}; 103 → {104, 105, 107, 109}; 105 → 106; 107 → 108; {103 … 109} → 110 → 111 → 112 →
113 → 114.

## Parallel examples

- **Agent M:** 103, 104, 105, 106, 109.
- **Agent R:** 107, 108, 110 (after 103's EffectDefinition exists).
- **Lead:** 101, 102, the runs, the contract, the commits.

## Implementation strategy

- **MVP:** the definitions and the chain with history (103–106).
- **Then:** the render contract (107, 108), the file (109), the host proof (110).
- **Review checkpoint:** at 111.
- **Commits:** one per task.
