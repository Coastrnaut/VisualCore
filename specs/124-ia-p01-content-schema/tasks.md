# Tasks: Interactive Anatomy — Phase 01 Licensed content inventory and schema

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/core.md](contracts/core.md), [quickstart.md](quickstart.md). Gate A17-P01 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A17-P01 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. iOS 27 only. No test may raise a system prompt.
Precedent: `specs/117-sl-p01-algorithms/tasks.md`.

## Phase 1: Setup

- [X] T-A17-101 Baseline: cite the A17-P00 evidence on an unchanged `Packages` tree (`.autonomy/checks/A17-P00.{app-build,no-change}.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-16: 2026-11-16: A17-P00 evidence cited: .autonomy/checks/A17-P00.app-build.json and A17-P00.no-change.json, both exit 0; the Packages tree is unchanged since the A17-P00 record commit 4c74bdf1 (git diff --stat empty)

## Phase 2: Foundational — the core targets

- [X] T-A17-102 Add the targets `InteractiveAnatomyCore` (path `InteractiveAnatomy/Core`, dependency `VisualCoreMath`, `resources: [.copy("Content")]`) and `InteractiveAnatomyCoreTests` (path `InteractiveAnatomy/CoreTests`) to `Packages/ExperiencesCreative/Package.swift` (the lead writes this file); no experience target, product or registration (FR-A17-106; clarification Q5) — Verified 2026-11-16: 2026-11-16: targets InteractiveAnatomyCore and InteractiveAnatomyCoreTests in Package.swift (38ab1b90); .autonomy/checks/A17-P01.ia-core-ios27.json exit 0 (24 tests in 3 suites, iOS 27)

## Phase 3: Story 1 — a trustworthy content inventory (P1) 🎯 MVP

- [X] T-A17-103 [P] [US1] Create `Packages/ExperiencesCreative/InteractiveAnatomy/Core/AnatomyModel.swift` per contracts/core.md and data-model.md: `AnatomyRegion` (schema 1, id `region.knee.right`, systems, convention "cm, +Y superior, +Z anterior, +X lateral", bounds min/max `Vec3` "bounds finite, min < max", contentVersion 1, meshes, structures, manifest), `AnatomicalStructure` (id `knee.<name>`, standardName, englishName, synonyms, layer (nil only for the root), parent?, neighbours, meshIDs "1–3; root 0", description, sourceRefs "≥ 1"), `AnatomyLayer` {bones, cartilage, ligaments}, `ProceduralMeshDeclaration` (id `mesh.<structure>.<part>`, kind ∈ {revolution, tube, extrusion, sphere}), `ContentManifest` (textLicense `original`, geometryLicense `original`, review {status `not-reviewed`, reviewer nil, date nil}, citations with license ∈ {public-domain, original, facts}; `reviewSentence` "Not reviewed by a clinician."), `AnatomyLabel`; every public symbol with `///` (FR-A17-101, 104) — Verified 2026-11-16: 2026-11-16: AnatomyModel.swift per contracts/core.md, every public symbol documented (.autonomy/checks/A17-P01.documented-api.json exit 0); .autonomy/checks/A17-P01.ia-core-ios27.json exit 0 (24 tests in 3 suites, iOS 27)
- [X] T-A17-104 [P] [US1] Create `Packages/ExperiencesCreative/InteractiveAnatomy/Core/Content/knee-right.json`: the right knee, 15 structures: the root `knee.joint` (no layer, no meshes) and its 14 joint parts of clarification Q1 in three layers (bones; cartilage and menisci; ligaments and tendons), each part with 1–3 of the 14–42 mesh declarations, citations Gray 1918 (public-domain) and Terminologia Anatomica 1998 (facts); original descriptions of 1–3 sentences, ≤ 400 characters, form, position and connections only; ≤ 262,144 bytes (FR-A17-102, 107; research D1–D4) — Verified 2026-11-16: 2026-11-16: knee-right.json 14,819 bytes: root knee.joint and 14 parts in three layers, 20 meshes, 8 citations, symmetric neighbours; BundledRegionTests in .autonomy/checks/A17-P01.ia-core-ios27.json exit 0 (24 tests in 3 suites, iOS 27)
- [X] T-A17-105 [P] [US1] Write `Packages/ExperiencesCreative/InteractiveAnatomy/CoreTests/BundledRegionTests.swift`: the bundled region decodes and validates; 15 structures (the root and 14 parts), every part with a source, a description and 1–3 mesh ids; three layers present; the review sentence is "Not reviewed by a clinician."; under 10 s (SC-A17-101; FR-A17-104, 105) — Verified 2026-11-16: 2026-11-16: BundledRegionTests pass in .autonomy/checks/A17-P01.ia-core-ios27.json exit 0 (24 tests in 3 suites, iOS 27)
- [X] T-A17-106 [P] [US1] Write `docs/apps/interactive-anatomy/content-sources.md`: the citations, their licenses, how the descriptions were written, the review status and the owner's review action (BLOCKED_OWNER_ACTION: clinical review), no modern atlas text (research D2, D3) — Verified 2026-11-16: 2026-11-16: docs/apps/interactive-anatomy/content-sources.md records the eight citations and their licenses (public-domain, facts, original), how the descriptions were written, the procedural geometry and the review status not-reviewed with the BLOCKED_OWNER_ACTION clinical review; validate_docs.py PASS

## Phase 4: Story 2 — every label maps to something real (P1)

- [X] T-A17-107 [US2] Create `Packages/ExperiencesCreative/InteractiveAnatomy/Core/{AnatomyContent,ContentRefusal}.swift`: `AnatomyContent.maxBytes = 262_144`, `decode` (size, decode, schema, validate), `validate` returning the first problem, `labels` (one per joint part: structure, englishName, first mesh; none for the root), `bundledRightKnee` over `Bundle.module`, `encoded` with sorted keys; `ContentRefusal` reasons {damaged, newer-version, too-large, missing-reference, duplicate-id, parent-cycle, empty-text, unsourced, bad-license, non-finite, colliding-synonym, clinical-text}, each with a sentence naming the problem; nothing crashes (FR-A17-103, 107) — Verified 2026-11-16: 2026-11-16: AnatomyContent.swift and ContentRefusal.swift (twelve reasons; rule order a-j plus symmetric neighbours); .autonomy/checks/A17-P01.ia-core-ios27.json exit 0 (24 tests in 3 suites, iOS 27)
- [ ] T-A17-108 [P] [US2] Write `Packages/ExperiencesCreative/InteractiveAnatomy/CoreTests/ContentValidationTests.swift`: one test per refusal reason, each naming the offending id in the sentence; every bundled label resolves to a structure and an existing mesh id; a description with a clinical word, more than 3 sentences or more than 400 characters is refused (SC-A17-102; FR-A17-103, 107)

## Phase 5: Story 3 — content that is safe to store and evolve (P2)

- [ ] T-A17-109 [P] [US3] Write `Packages/ExperiencesCreative/InteractiveAnatomy/CoreTests/ContentCodecTests.swift`: `encoded` then `decode` gives an equal region and equal bytes; damaged JSON, schema 2 and 262,145 bytes are refused with `damaged`, `newer-version` and `too-large` (SC-A17-103)

## Phase 6: Records and evidence

- [ ] T-A17-110 Contract `docs/apps/interactive-anatomy/visualcore-contract.json`: G-CONTENT closed by "A17-P01"; rows whose gaps are all closed become available (`--name contract -- python3 scripts/check_app_contract.py --app interactive-anatomy --render`)
- [ ] T-A17-111 Core tests on sim-27.2 (`--name ia-core-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing InteractiveAnatomyCoreTests`) and the documented-API check (`--name documented-api -- python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/InteractiveAnatomy`) (SC-A17-101–104)
- [ ] T-A17-112 Packages, script tests and the app build (`--name experience-packages -- python3 scripts/check_experience_packages.py`; `--name script-tests -- python3 scripts/test_scripts.py`; `--name app-build -- python3 scripts/release_check.py --only app-build-for-testing-ios27`); the app and its registry are unchanged (SC-A17-104; FR-A17-106)
- [ ] T-A17-113 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A17-P01; update README.md in the record commit (rule 16) and `docs/automatedtesting.md` if a test tool, rule or lesson changed (rule 17)

## Dependencies

T-A17-101 → 102 → {103, 104, 105, 106} → 107 → {108, 109} → 110 → 111 → 112 → 113. 105, 108 and 109 are written
against contracts/core.md and compile once 103 and 107 exist.

## Parallel examples

Lead first: the targets in Package.swift (102). Agent A: the sources and the JSON (103, 104, 107). Agent B: the three
test files (105, 108, 109). Lead: content-sources.md (106), the contract, the runs, the commits.

## Implementation strategy

MVP: the model and the bundled knee (103–105). Validation (107, 108) and the codec (109) close the phase. Review
checkpoints after 105 (the bundled region validates) and at 111.
