# VisualCore — Auto-Creator

**The single design and steering document of the VisualCore app.**
Edition of 2026-11-11 (milestone M0, consolidation). Authority: owner directive of 2026-11-11 and
[ADR-0009](docs/decisions/ADR-0009-unified-app.md).

This is a book, not a log. It is edited in place: when a rule changes, the sentence changes and the decision is
recorded in an ADR. Only section 3 states facts about the present, and it is dated. Everything else is intent
unless the sentence says "exists today". Progress is never written here; it lives in the two ledgers (section 25).

Parts of this file are generated from tracked data and sit between `GENERATED` markers. Do not edit them by hand:
change the data and run `python3 scripts/render_autocreator.py`.

## Contents

<!-- GENERATED:BEGIN toc -->
- **[Part I — Orientation](#part-i--orientation)**
  - [1. Vision](#1-vision)
  - [2. How to use this document](#2-how-to-use-this-document)
  - [3. Verified state at the consolidation (2026-11-11)](#3-verified-state-at-the-consolidation-2026-11-11)
- **[Part II — Product](#part-ii--product)**
  - [4. Product constraints and decisions](#4-product-constraints-and-decisions)
  - [5. Catalog, tiers and pricing](#5-catalog-tiers-and-pricing)
  - [6. The common experience contract](#6-the-common-experience-contract)
  - [7. Free library I: the 25 creative experiences (A01–A25)](#7-free-library-i-the-25-creative-experiences-a01a25)
  - [8. Free library II: the 25 Round 2 games](#8-free-library-ii-the-25-round-2-games)
  - [9. Premium library: Rounds 3 and 4](#9-premium-library-rounds-3-and-4)
  - [10. Backlog: Rounds 5–12](#10-backlog-rounds-512)
- **[Part III — Architecture](#part-iii--architecture)**
  - [11. App architecture](#11-app-architecture)
  - [12. Rendering, quality and performance](#12-rendering-quality-and-performance)
  - [13. Shared features and reuse](#13-shared-features-and-reuse)
  - [14. Purchases and entitlement](#14-purchases-and-entitlement)
  - [15. Persistence, privacy, accessibility and legal](#15-persistence-privacy-accessibility-and-legal)
  - [16. Repository layout](#16-repository-layout)
- **[Part IV — Execution](#part-iv--execution)**
  - [17. Migration design](#17-migration-design)
  - [18. Phases, milestones and gates](#18-phases-milestones-and-gates)
  - [19. Spec Kit procedure and numbering](#19-spec-kit-procedure-and-numbering)
  - [20. Unified-app features: briefs and prompts](#20-unified-app-features-briefs-and-prompts)
  - [21. Prompt catalog for archived features and canonical overrides](#21-prompt-catalog-for-archived-features-and-canonical-overrides)
  - [22. The simulator gate and ImplementationLock-100](#22-the-simulator-gate-and-implementationlock-100)
  - [23. Device protocol](#23-device-protocol)
  - [24. CI, release and owner-only actions](#24-ci-release-and-owner-only-actions)
  - [25. Ledgers, evidence and recovery](#25-ledgers-evidence-and-recovery)
  - [26. Source traceability](#26-source-traceability)
  - [27. Glossary](#27-glossary)
  - [28. Continuation prompt](#28-continuation-prompt)
<!-- GENERATED:END toc -->

# Part I — Orientation

## 1. Vision

VisualCore is one app for iPhone and iPad. It is a library of creative tools and puzzle games in which every
picture on screen is drawn by code: shaders, procedural geometry, particles and deterministic animation. A person
downloads one app, opens a launcher, picks an experience and is inside it within a moment. Fifty experiences are
free forever. Fifty more open with a single purchase of USD 1.99, and that purchase also covers every premium
experience added later. There is no advertising, no tracking, no subscription and no account, and everything
works offline.

The first release contains exactly 100 complete experiences:

- the 25 original VisualCore creative apps (A01–A25): generative art, fluids, fractals, particles, music
  visualization, simulations, explorers, ambient pieces and creative tools;
- the 25 Round 2 puzzle games, the family-balanced selection from the 500-candidate study;
- the 25 Round 3 and 25 Round 4 puzzle games, which form the premium library.

Two hundred further games (Rounds 5–12) are specified and wait in score order as later premium additions.

**Why one app.** One download and one purchase are simple for people. One binary means one quality bar, one
launcher, one settings screen, one accessibility implementation, one privacy manifest and one review. The
experiences share the VisualCore framework, so a fix in the renderer or the puzzle kernel improves all of them.

**What "complete" means.** An experience is complete when it launches, renders through the real renderer, responds
to input, saves, resets and restores, reaches a meaningful outcome (a finished piece of work or a solved level and
a reason to come back), and passes its automated tests on the iOS Simulator. A screen with a title and a colored
rectangle is not an experience. Section 6 is the exact contract.

**How the release is earned.** All 100 experiences are implemented and verified on simulators first. Only when an
independent rerun confirms 100 of 100 on one locked commit (`ImplementationLock-100`) does the app touch the three
test devices: iPhone 15, then iPad Pro M5, then iPad A16 on iPadOS 26.5. Submission to the App Store needs a
separate owner authorization.

**Measures of success for the first release.**

| Measure | Target | Where it is checked |
|---|---|---|
| Experiences that pass the common contract on both simulator runtimes | 100 of 100 | `ImplementationLock-100` (section 22) |
| Device rows that pass | 300 of 300 (100 on each of D1, D2, D3) | `DEVICE-RECONCILE-100` (section 23) |
| Advertising, analytics or tracking code in the shipped binary | none | UA-F11 scans (section 15) |
| In-app products | exactly one non-consumable at USD 1.99 | UA-F08 tests (section 14) |
| Raster or third-party art in experiences | none | UA-F09 audit (section 22) |
| Experiences reachable without network, account or permission prompt | all free ones at first launch | UA-F04 tests (section 11.7) |

## 2. How to use this document

**Readers.** The autonomous engineer (Claude in Claude Desktop Code) and the owner.

**Reading paths.**

| You want to | Read |
|---|---|
| Resume work after any interruption | `CLAUDE.md`, then sections 3, 18 and 25, then the prompt in section 28 |
| Specify or implement a unified-app feature | section 19, the feature's brief and prompts in section 20, the architecture sections it names |
| Implement an experience | section 6, its card in section 7, 8 or 9, sections 19 and 21 |
| Verify an experience or take a lock | section 22 |
| Run the device campaign | section 23 |
| Prepare a release | section 24 |
| Find where an old requirement went | section 26 and `docs/migration/source-to-canonical-matrix.csv` |

**Precedence when sources disagree.** (1) Real Apple platform and toolchain behavior and observed test results.
(2) Owner directives: ADR-0009, this document and `CLAUDE.md`. (3) The constitution and the other ADRs. (4) The
planning archive. (5) Generated code. A requirement is never dropped because it is hard: it is implemented,
planned, superseded with a reason, or blocked with the owner action it needs. An obsolete command, path or tool name
in an archived document never cancels the requirement behind it: the requirement moves to the current mechanism.
Inside the archive, an app's own manual outranks the brainstorm that preceded it. Between two owner rules, the later
dated one wins.

**Status words.** They are never merged into one green label.

| Word | Meaning |
|---|---|
| `IMPLEMENTED` | source and functional behavior exist |
| `BUILT` | the real compiler succeeded |
| `SIMULATOR_VERIFIED` | real simulator tests passed and are recorded |
| `DEVICE_VERIFIED` | real signed hardware tests passed with result bundles and reports |
| `READY_FOR_OWNER_RELEASE_REVIEW` | every mandatory check passed; owner actions remain |
| `BLOCKED_OWNER_ACTION` | work stops on this item until the owner acts; the exact steps are recorded |
| `NOT_RUN` | a required check that has not been executed; never shown as pass or as fail |
| `AUTOMATION_READY` | the automation for a device-only check exists and passes its dry run; the check itself has not run |
| `NOT_REQUIRED` | waived by a dated owner ruling, written next to the still unticked task as "not required (owner ruling YYYY-MM-DD): reason" |

**Identifiers.**

| Thing | Form | Example |
|---|---|---|
| Experience code | `A<nn>` or `R<rr>-G<gg>` | `A05`, `R02-G01` |
| Experience runtime id | `<code in lower case>.<slug>` | `a05.infinite-geometry`, `r02-g01.aurora-loom` |
| Unified-app feature | `UA-F<kk>` | `UA-F03` |
| Shared round feature | `R<rr>-F<ff>` | `R02-F05` |
| Game feature | `R<rr>-G<gg>-<ff>` | `R02-G01-03` |
| Original app phase | `A<nn>-P<p>` | `A04-P04` |
| Integration gate of an experience | `X-<code>` | `X-A05`, `X-R03-G01` |
| Device row | `DEV<n>-<code>` | `DEV3-R04-G25` |
| Decision, conflict, owner decision | `D-<nn>`, `C-<nn>`, `OD-<nn>` | ADR-0009 |

**Editing rules.** Keep the section numbers stable: tools, prompts and the feature briefs cite them. Put a new rule
where it belongs and delete the sentence it replaces. Run `python3 scripts/render_autocreator.py` and
`python3 scripts/validate_autocreator.py` before committing. The continuation prompt is always the last section
and nothing follows it.

## 3. Verified state at the consolidation (2026-11-11)

Everything in this section was observed in the repository on 2026-11-11 and is recorded in
[`docs/migration/pre-fable-baseline.md`](docs/migration/pre-fable-baseline.md) and its JSON manifest. It is a
snapshot. For the live state run the commands at the end of the section.

### 3.1 What exists

| Area | State on 2026-11-11 | Evidence |
|---|---|---|
| Repository | before the consolidation `main` was at commit `38d98eb`; the consolidation was made on branch `migration/unified-app-plan` and, by owner ruling of 2026-11-11, fast-forwarded into `main` and pushed | baseline §1, ADR-0009 D-13 |
| Framework | `Packages/VisualCore` (pure Swift: Math, Simulation, Scenes, Parameters, Persistence, ShaderSource, EffectsGraph, Diagnostics, TestSupport, Baselines) and `Packages/VisualCoreRendering` (EGL and GL shims, Rendering, Effects, UI, Automation) | legacy gates F00–F09, `specs/001`–`010` |
| Framework modules without functionality | `VisualCoreAudio` and `VisualCoreAudioDSP` hold only a version constant | ADR-0006 |
| Showcase and harnesses | `Showcase`, `InteractiveDemo`, `SecondConsumer` (Lumen Garden), `ProjectMReference` | gates F05–F08 |
| A01 Generative Art Studio | standalone app, all seven phases sealed | gates A01-P00 … A01-P06, `specs/011`–`017` |
| A02 Fluid Art Playground | standalone app, all seven phases sealed | gates A02-P00 … A02-P06, `specs/018`–`024` |
| A03 Fractal Explorer | standalone app, all seven phases sealed | gates A03-P00 … A03-P06, `specs/025`–`031` |
| A04 Particle Universe | standalone app, four of seven phases sealed | gates A04-P00 … A04-P03, `specs/032`–`035` |
| A05–A25 | not started | — |
| Games of Rounds 2–12 (275) | planned only; no source exists | — |
| Unified app `Apps/VisualCore/` | does not exist | — |
| StoreKit code | none in the repository | — |
| Legacy ledger | 35 of 263 gates pass; next legacy gate `A04-P04` | `.autonomy/state.json`, 35 evidence files, 1,258 attestations |
| Feature dossiers | 35 (`specs/001`–`035`): 353 functional requirements, 201 success criteria, 477 ticked tasks | `python3 scripts/validate_docs.py` |
| Open tasks | six, all tagged `{device}`: T-F418, T-F523, T-F613, T-F714, T-F810, T-F915 | `specs/005`–`010` |
| Physical-device tests | none has ever been run in this repository | all legacy device gates pending |
| Reference | `External/projectm-ios` pinned at `d93edd1`, read-only; reference regression 7 of 7 after each framework change | ADR-0005 |
| Toolchain | Xcode 27.2 (27B52), iOS SDK 27.2, Swift 6.4.2, XcodeGen 2.46.0, CMake 4.4.5, Python 3.15.2; simulator runtimes iOS 27.2 and iOS 26.5 | `python3 scripts/verify_environment.py`, `Configs/toolchain.json` |
| Deployment target | iOS and iPadOS 26.0, iPhone and iPad | `project.yml` |
| CI | host gates (ledger, documents, compliance, dependencies, API, licenses, script tests, host tests) and a simulator build of the framework | `.github/workflows/ci.yml` |
| Constitution | version 1.5.0; describes 25 separate apps and is superseded in scope by ADR-0009 until amended | `.specify/memory/constitution.md` |

"Sealed" means: the phase passed its host and simulator checks and its evidence file is in `.autonomy/evidence/`.
It does not mean device-verified, and it says nothing about the unified app.

### 3.2 What the consolidation added (M0)

| Item | Place |
|---|---|
| Baseline of the state before the consolidation, with a backup outside the repository | `docs/migration/pre-fable-baseline.*`, `scripts/migration_baseline.py` |
| Archive of every planning document, byte-identical | `docs/archive/planning/`, `scripts/planning_archive.py` |
| Catalog of 300 experiences and index of 3,089 features with 23,232 archived prompts | `docs/catalog/`, `scripts/planning_index.py` |
| Decisions | `docs/decisions/ADR-0009-unified-app.md` |
| Briefs and prompts of the 15 unified-app features | `docs/catalog/unified-app-features.json`, section 20 |
| Migration ledger with 1,233 gates | `.autonomy/migration/ledger.json`, `scripts/migration_ledger.py` |
| Numbering support in the tools | `scripts/validate_docs.py`, `scripts/tick_task.py` |
| Traceability matrix | `docs/migration/source-to-canonical-matrix.csv` |
| This document, `README.md`, `setup.md`, `CLAUDE.md`, the migration plan | repository root, `docs/migration/migration-plan.md` |
| Validators | `scripts/validate_autocreator.py`, `scripts/render_autocreator.py --check` |

The consolidation changed no app or framework source.

### 3.3 Live state

```bash
git status --short --branch && git log --oneline -5
python3 scripts/migration_ledger.py status
python3 Tools/python/desktop_runbook.py status
python3 scripts/validate_autocreator.py
```

# Part II — Product

## 4. Product constraints and decisions

### 4.1 Constraints that do not change

These come from the owner. A change needs a new owner directive and a new ADR.

| Id | Constraint | Enforced by |
|---|---|---|
| P-01 | One App Store app named VisualCore, one app target, one bundle identifier, a unified launcher and common settings. Experiences are internal modules with stable identifiers. | constitution principle XI, UA-F04, UA-F10, `scripts/check_dependencies.py` |
| P-02 | The first release contains exactly 100 complete experiences: 50 free forever (A01–A25, R02-G01 … R02-G25) and 50 premium (R03-G01 … R04-G25). Rounds 5–12 are backlog. Queues are not reordered, concepts are not substituted. | catalog validation (UA-F01), `scripts/validate_autocreator.py`, the three locks |
| P-03 | Free download and one non-consumable in-app purchase at USD 1.99 that unlocks all premium experiences, present and future. StoreKit 2, verified transactions, restore, revocation and refund handling, offline entitlement, local `SKTestSession` tests. | UA-F08, section 14 |
| P-04 | No advertising under any circumstances. No ad SDK, ad identifier, rewarded ad, subscription, consumable, dark pattern, external payment path or required account. | UA-F11 scans, constitution principle XII |
| P-05 | Premium is gated in production. Automation reaches premium only through a test-only entitlement fixture that is absent from the shipping Release binary. | UA-F08, `scripts/check_release_symbols.py` |
| P-06 | All visuals are code: GLSL, procedural meshes and SDFs, particles, geometry, deterministic animation, on the existing OpenGL ES → ANGLE → Metal path. No required human-made models, purchased art or generated images. The rendering path is not forked or replaced without a documented, test-backed need. ProjectM's integration and pinned forks are preserved. | constitution principles I and XIII, UA-F09 audit |
| P-07 | All 100 experiences are implemented and pass host and simulator acceptance before any device campaign of the unified app. No placeholders, no mock-only gameplay. Earlier device observations do not certify the unified build. | `ImplementationLock-100`, `python3 scripts/migration_ledger.py guard-device` |
| P-08 | Devices in fixed order after the lock: D1 iPhone 15 (`iPhone15,4`), D2 iPad Pro 13-inch M5 (`iPad17,3`), D3 iPad A16 (`iPad15,7`). D3 stays on iPadOS 26.5. The live OS, build and identifier are detected before each campaign. Unrun tests are never reported as passed. Manual VoiceOver testing is non-gating. | section 23, UA-F13 |
| P-09 | Unattended work uses best judgement, at most ten concurrent agents, one writer per file and serialized heavy builds. An agent's statement never replaces a test. | `CLAUDE.md`, section 19 |
| P-10 | Nothing is submitted, purchased, signed with changed credentials or published without distinct owner authorization. | section 24.3 |
| P-11 | Completed work stays completed: source, commits, tests, task records, ledger ids, device reports, branch and submodule pins. A new integration gate may be pending while the original work stays verified. | section 25, `scripts/migration_baseline.py verify` |
| P-12 | `README.md` is the public face, `setup.md` the setup guide, this document the single forward-looking design, `CLAUDE.md` a small bootstrap. Original documents stay in a searchable archive. | ADR-0009 D-10, D-14 |

### 4.2 Decisions

The reasoning, the alternatives and the resolved conflicts (C-01 … C-24) are in ADR-0009. In short:

| Id | Decision | Design section |
|---|---|---|
| D-01 | One app, experiences as registered modules | 11 |
| D-02 | Launch scope of exactly 100, 50 free and 50 premium | 5 |
| D-03 | One USD 1.99 non-consumable, no advertising | 14 |
| D-04 | Entitlement derived from verified transactions, gated at routing and at activation | 14 |
| D-05 | ExperienceKit contract and one session host | 11.3–11.6 |
| D-06 | Few packages, two targets per experience, immutable ids | 11.2, 16 |
| D-07 | All 100 on the simulator before any device; `ImplementationLock-100` | 22 |
| D-08 | D1, then D2, then D3; D3 never updated | 23 |
| D-09 | Code-driven visuals on the proven renderer | 12 |
| D-10 | Document hierarchy | 2 |
| D-11 | Feature numbering | 19.1 |
| D-12 | Two ledgers | 25 |
| D-13 | The consolidation was made on a branch; since the owner's ruling of 2026-11-11 work happens on `main` and is pushed after every commit | 24.4 |
| D-14 | Archive instead of deletion | 26 |
| D-15 | The app is fully offline: no network request of its own; purchases go through StoreKit | 15.2 |
| D-16 | The launch set is never reduced: a failing concept is redesigned inside its concept, never dropped, merged or replaced | 6.5 |
| D-17 | Human-judgement reviews are owner reviews and do not gate simulator gates or locks; their automated proxies do | 6.5, 23.3 |
| D-18 | Backlog rounds are added one at a time after the release, each with its own lock and its own device rows | 18.4 |

### 4.3 Owner decisions that are open

Work continues with the default until the owner decides. None of them blocks implementation before the device
campaign.

| Id | Decision | Default in use |
|---|---|---|
| OD-01 | Availability and clearance of the name "VisualCore" on the App Store | display name VisualCore; availability is not claimed anywhere |
| OD-02 | Final bundle identifier and product identifier | `dev.visualcore.VisualCore`, `dev.visualcore.VisualCore.premium` |
| OD-03 | Family Sharing for the unlock | recommended on; code handles both |
| OD-04 | How and when the migration branch is merged to `main` | **decided 2026-11-11:** fast-forwarded into `main`; work continues on `main` |
| OD-05 | Pushing | **decided 2026-11-11:** `main` is pushed to `origin` after every commit, after the pre-push scan |
| OD-06 | Signing team, certificates, profiles, sandbox tester, App Store Connect record and agreements | none; device work reports `BLOCKED_OWNER_ACTION` |
| OD-07 | Minimum OS and device families. The roster covers iOS 27 on iPhone and iPadOS 26.5 and 27 on iPad; an iPhone on iOS 26 is not covered by any test device | iOS and iPadOS 26.0, iPhone and iPad; published claims name only the tested models and OS versions |
| OD-08 | Length of the device stress sessions (about 60 device-hours for the launch games as the sources specify them) | as the sources say: 30 minutes on each device for a Round 2 game, 30 minutes on D3 for a game of Rounds 3 and 4, ten minutes for a creative experience whose class warrants it |
| OD-09 | Who performs the human reviews (distinctiveness, visual quality of hero scenes, five-second goal recognition, outside-player comprehension, VoiceOver) and when | the owner, before release; recorded, non-gating for gates and locks |
| OD-10 | What happens to a launch experience that still fails after a redesign inside its concept | its gate stays blocked; nothing is dropped, merged or replaced |
| OD-11 | Confirmation of the 26 supplemental candidates, whose scores are provisional, before Rounds 11 and 12 | they keep their place at the end of the queue |

### 4.4 Non-goals of the first release

Accounts, cloud sync, leaderboards, social features, user-generated content sharing, a second purchase of any kind,
network features, a macOS or visionOS app, live wallpaper installation (the platform does not offer it to
third-party apps), capture of other apps' audio beyond what public APIs permit, and any experience outside the 100.

## 5. Catalog, tiers and pricing

### 5.1 The catalog

`docs/catalog/experience-catalog.json` is the planning catalog of all 300 experiences. It is generated from the
archive by `scripts/planning_index.py build` and carries, for each experience, its identity, tier, launcher
category, family, score, design data and the exact file and line span of its source chapter.

<!-- GENERATED:BEGIN catalog-summary -->
| Collection | Codes | Experiences | Kind | Tier | Release | Source document |
|---|---|---:|---|---|---|---|
| original | A01 … A25 | 25 | creative-app | free | launch | `docs/archive/planning/embedded/apps/` (25 manuals) |
| round-02 | R02-G01 … R02-G25 | 25 | game | free | launch | `docs/archive/planning/rounds/round2.md` |
| round-03 | R03-G01 … R03-G25 | 25 | game | premium | launch | `docs/archive/planning/rounds/round3.md` |
| round-04 | R04-G01 … R04-G25 | 25 | game | premium | launch | `docs/archive/planning/rounds/round4.md` |
| round-05 | R05-G01 … R05-G25 | 25 | game | premium-backlog | backlog | `docs/archive/planning/rounds/round5.md` |
| round-06 | R06-G01 … R06-G25 | 25 | game | premium-backlog | backlog | `docs/archive/planning/rounds/round6.md` |
| round-07 | R07-G01 … R07-G25 | 25 | game | premium-backlog | backlog | `docs/archive/planning/rounds/round7.md` |
| round-08 | R08-G01 … R08-G25 | 25 | game | premium-backlog | backlog | `docs/archive/planning/rounds/round8.md` |
| round-09 | R09-G01 … R09-G25 | 25 | game | premium-backlog | backlog | `docs/archive/planning/rounds/round9.md` |
| round-10 | R10-G01 … R10-G25 | 25 | game | premium-backlog | backlog | `docs/archive/planning/rounds/round10.md` |
| round-11 | R11-G01 … R11-G25 | 25 | game | premium-backlog | backlog | `docs/archive/planning/rounds/round11.md` |
| round-12 | R12-G01 … R12-G25 | 25 | game | premium-backlog | backlog | `docs/archive/planning/rounds/round12.md` |
| **Total** | | **300** | | 50 free, 50 premium, 200 premium backlog | 100 launch, 200 backlog | |
<!-- GENERATED:END catalog-summary -->

### 5.2 Identity

- The **code** (`A05`, `R02-G01`) and the **runtime id** (`a05.infinite-geometry`) of an experience never change
  once the experience has shipped. A display name may change; the id does not. A removed experience's id is never
  reused.
- Storage namespaces, defaults keys, accessibility identifiers, evidence file names, scenario manifests and ledger
  gates are all derived from the runtime id or the code. Nothing else may serve as an identifier.
- The order column of the catalog (1–300) is the release and implementation order: the original apps in their
  original order, then each round in its source order, which is descending score.
- Round 2's source ids are written `R2-…` in the archive. The canonical form is `R02-…`; the tools accept both.

### 5.3 Tiers and price

| Tier | Meaning | Who can open it |
|---|---|---|
| `free` | free forever | everyone, with no purchase, account or network |
| `premium` | part of the premium library at launch | holders of the unlock |
| `premium-backlog` | planned premium addition after launch | holders of the unlock, once released |

The unlock is one non-consumable product at USD 1.99. It is bought once and covers every premium experience,
including those added after the purchase. A free experience never becomes premium. Prices in the archive
("$2.99", "$3.99", "$1.99–$4.99 one-time purchase" per game) describe separately sold games and are superseded;
no price other than USD 1.99 appears in the product.

### 5.4 Launcher categories

Every experience has exactly one launcher category and keeps its family as a tag: `create`, `audio`, `play`,
`learn`, `ambient`, `tools` for the creative experiences and `puzzle` for the games. The 75 launch puzzles are
grouped by family inside their category. Search covers title, summary and tags and is deterministic and
locale-independent.

### 5.5 Availability

The app ships a runtime manifest, `Catalog/experiences.json`, which `scripts/build_catalog.py` builds from the
planning catalog (UA-F01). An experience is listed as available only when its integration gate `X-<code>` is pass
in the migration ledger, and only when it has a registration in `Catalog/registrations.json`; nobody types the flag.
Planned experiences are never shown as available, and store metadata is generated only from available ones.

### 5.6 The 100 launch experiences

<!-- GENERATED:BEGIN experience-index -->
| # | Code | Runtime id | Name | Category | Family | Tier | Integration gate |
|---:|---|---|---|---|---|---|---|
| 1 | [A01](#a01-generative-art-studio) | `a01.generative-art-studio` | Generative Art Studio | create | Creative and visual | free | `X-A01` |
| 2 | [A02](#a02-fluid-art-playground) | `a02.fluid-art-playground` | Fluid Art Playground | create | Creative and visual | free | `X-A02` |
| 3 | [A03](#a03-fractal-explorer) | `a03.fractal-explorer` | Fractal Explorer | create | Creative and visual | free | `X-A03` |
| 4 | [A04](#a04-particle-universe) | `a04.particle-universe` | Particle Universe | create | Creative and visual | free | `X-A04` |
| 5 | [A05](#a05-infinite-geometry) | `a05.infinite-geometry` | Infinite Geometry | create | Creative and visual | free | `X-A05` |
| 6 | [A06](#a06-visualcore-music-lab) | `a06.visualcore-music-lab` | VisualCore Music Lab | audio | Music and audio | free | `X-A06` |
| 7 | [A07](#a07-audio-odyssey) | `a07.audio-odyssey` | Audio Odyssey | audio | Music and audio | free | `X-A07` |
| 8 | [A08](#a08-oscilloscope-studio) | `a08.oscilloscope-studio` | Oscilloscope Studio | audio | Music and audio | free | `X-A08` |
| 9 | [A09](#a09-digital-aquarium) | `a09.digital-aquarium` | Digital Aquarium | audio | Music and audio | free | `X-A09` |
| 10 | [A10](#a10-neon-arcade) | `a10.neon-arcade` | Neon Arcade | play | Games and interactive experiences | free | `X-A10` |
| 11 | [A11](#a11-physics-playground) | `a11.physics-playground` | Physics Playground | play | Games and interactive experiences | free | `X-A11` |
| 12 | [A12](#a12-tiny-worlds) | `a12.tiny-worlds` | Tiny Worlds | play | Games and interactive experiences | free | `X-A12` |
| 13 | [A13](#a13-light-maze) | `a13.light-maze` | Light Maze | play | Games and interactive experiences | free | `X-A13` |
| 14 | [A14](#a14-solar-system-explorer) | `a14.solar-system-explorer` | Solar System Explorer | learn | Education and science | free | `X-A14` |
| 15 | [A15](#a15-molecular-explorer) | `a15.molecular-explorer` | Molecular Explorer | learn | Education and science | free | `X-A15` |
| 16 | [A16](#a16-simulation-lab) | `a16.simulation-lab` | Simulation Lab | learn | Education and science | free | `X-A16` |
| 17 | [A17](#a17-interactive-anatomy) | `a17.interactive-anatomy` | Interactive Anatomy | learn | Education and science | free | `X-A17` |
| 18 | [A18](#a18-ambient-clock) | `a18.ambient-clock` | Ambient Clock | ambient | Ambient and lifestyle | free | `X-A18` |
| 19 | [A19](#a19-living-wallpapers) | `a19.living-wallpapers` | Living Wallpapers | ambient | Ambient and lifestyle | free | `X-A19` |
| 20 | [A20](#a20-digital-zen-garden) | `a20.digital-zen-garden` | Digital Zen Garden | ambient | Ambient and lifestyle | free | `X-A20` |
| 21 | [A21](#a21-aurora) | `a21.aurora` | Aurora | ambient | Ambient and lifestyle | free | `X-A21` |
| 22 | [A22](#a22-shader-studio) | `a22.shader-studio` | Shader Studio | tools | Developer and creator tools | free | `X-A22` |
| 23 | [A23](#a23-visual-programming-lab) | `a23.visual-programming-lab` | Visual Programming Lab | tools | Developer and creator tools | free | `X-A23` |
| 24 | [A24](#a24-graphics-benchmark-lab) | `a24.graphics-benchmark-lab` | Graphics Benchmark Lab | tools | Developer and creator tools | free | `X-A24` |
| 25 | [A25](#a25-effects-composer) | `a25.effects-composer` | Effects Composer | tools | Developer and creator tools | free | `X-A25` |
| 26 | [R02-G01](#r02-g01-aurora-loom) | `r02-g01.aurora-loom` | Aurora Loom | puzzle | Light and color | free | `X-R02-G01` |
| 27 | [R02-G02](#r02-g02-lissajous-labyrinth) | `r02-g02.lissajous-labyrinth` | Lissajous Labyrinth | puzzle | Wave mathematics | free | `X-R02-G02` |
| 28 | [R02-G03](#r02-g03-wave-knot-keeper) | `r02-g03.wave-knot-keeper` | Wave Knot Keeper | puzzle | Wave mathematics | free | `X-R02-G03` |
| 29 | [R02-G04](#r02-g04-hue-compass) | `r02-g04.hue-compass` | Hue Compass | puzzle | Chromatic logic | free | `X-R02-G04` |
| 30 | [R02-G05](#r02-g05-colorfall-canyons) | `r02-g05.colorfall-canyons` | Colorfall Canyons | puzzle | Light and color | free | `X-R02-G05` |
| 31 | [R02-G06](#r02-g06-chrono-constellator) | `r02-g06.chrono-constellator` | Chrono Constellator | puzzle | Temporal puzzles | free | `X-R02-G06` |
| 32 | [R02-G07](#r02-g07-amethyst-escape) | `r02-g07.amethyst-escape` | Amethyst Escape | puzzle | Crystal solids | free | `X-R02-G07` |
| 33 | [R02-G08](#r02-g08-faceted-forge) | `r02-g08.faceted-forge` | Faceted Forge | puzzle | Crystal solids | free | `X-R02-G08` |
| 34 | [R02-G09](#r02-g09-nocturne-garden) | `r02-g09.nocturne-garden` | Nocturne Garden | puzzle | Shadow construction | free | `X-R02-G09` |
| 35 | [R02-G10](#r02-g10-backwards-aurora) | `r02-g10.backwards-aurora` | Backwards Aurora | puzzle | Temporal puzzles | free | `X-R02-G10` |
| 36 | [R02-G11](#r02-g11-echo-cartographer) | `r02-g11.echo-cartographer` | Echo Cartographer | puzzle | Logic and patterns | free | `X-R02-G11` |
| 37 | [R02-G12](#r02-g12-harmonic-bridges) | `r02-g12.harmonic-bridges` | Harmonic Bridges | puzzle | Acoustic geometry | free | `X-R02-G12` |
| 38 | [R02-G13](#r02-g13-acoustic-constellator) | `r02-g13.acoustic-constellator` | Acoustic Constellator | puzzle | Acoustic geometry | free | `X-R02-G13` |
| 39 | [R02-G14](#r02-g14-moonlit-mechanism) | `r02-g14.moonlit-mechanism` | Moonlit Mechanism | puzzle | Shadow construction | free | `X-R02-G14` |
| 40 | [R02-G15](#r02-g15-voxel-origami) | `r02-g15.voxel-origami` | Voxel Origami | puzzle | Spatial origami | free | `X-R02-G15` |
| 41 | [R02-G16](#r02-g16-starlit-cartouche) | `r02-g16.starlit-cartouche` | Starlit Cartouche | puzzle | Celestial exploration | free | `X-R02-G16` |
| 42 | [R02-G17](#r02-g17-celestial-eclipse-lab) | `r02-g17.celestial-eclipse-lab` | Celestial Eclipse Lab | puzzle | Celestial exploration | free | `X-R02-G17` |
| 43 | [R02-G18](#r02-g18-apsides-workshop) | `r02-g18.apsides-workshop` | Apsides Workshop | puzzle | Orbital dynamics | free | `X-R02-G18` |
| 44 | [R02-G19](#r02-g19-microscopic-aurora) | `r02-g19.microscopic-aurora` | Microscopic Aurora | puzzle | Micro ecosystems | free | `X-R02-G19` |
| 45 | [R02-G20](#r02-g20-mushroom-weather) | `r02-g20.mushroom-weather` | Mushroom Weather | puzzle | Micro ecosystems | free | `X-R02-G20` |
| 46 | [R02-G21](#r02-g21-binary-gardens) | `r02-g21.binary-gardens` | Binary Gardens | puzzle | Orbital dynamics | free | `X-R02-G21` |
| 47 | [R02-G22](#r02-g22-mycelium-architect) | `r02-g22.mycelium-architect` | Mycelium Architect | puzzle | Organic growth | free | `X-R02-G22` |
| 48 | [R02-G23](#r02-g23-erosion-painter) | `r02-g23.erosion-painter` | Erosion Painter | puzzle | Terrain alchemy | free | `X-R02-G23` |
| 49 | [R02-G24](#r02-g24-crystal-quarry) | `r02-g24.crystal-quarry` | Crystal Quarry | puzzle | Terrain alchemy | free | `X-R02-G24` |
| 50 | [R02-G25](#r02-g25-starlight-surveyors) | `r02-g25.starlight-surveyors` | Starlight Surveyors | puzzle | Cosmic puzzles | free | `X-R02-G25` |
| 51 | [R03-G01](#r03-g01-harmonic-helix) | `r03-g01.harmonic-helix` | Harmonic Helix | puzzle | Wave mathematics | premium | `X-R03-G01` |
| 52 | [R03-G02](#r03-g02-ripple-clockwork) | `r03-g02.ripple-clockwork` | Ripple Clockwork | puzzle | Wave mathematics | premium | `X-R03-G02` |
| 53 | [R03-G03](#r03-g03-prism-symphony) | `r03-g03.prism-symphony` | Prism Symphony | puzzle | Chromatic logic | premium | `X-R03-G03` |
| 54 | [R03-G04](#r03-g04-harmonic-archipelago) | `r03-g04.harmonic-archipelago` | Harmonic Archipelago | puzzle | Wave mathematics | premium | `X-R03-G04` |
| 55 | [R03-G05](#r03-g05-color-alchemy-spires) | `r03-g05.color-alchemy-spires` | Color Alchemy Spires | puzzle | Chromatic logic | premium | `X-R03-G05` |
| 56 | [R03-G06](#r03-g06-gradient-locksmith) | `r03-g06.gradient-locksmith` | Gradient Locksmith | puzzle | Chromatic logic | premium | `X-R03-G06` |
| 57 | [R03-G07](#r03-g07-bessel-fountain) | `r03-g07.bessel-fountain` | Bessel Fountain | puzzle | Wave mathematics | premium | `X-R03-G07` |
| 58 | [R03-G08](#r03-g08-phase-prism) | `r03-g08.phase-prism` | Phase Prism | puzzle | Wave mathematics | premium | `X-R03-G08` |
| 59 | [R03-G09](#r03-g09-polar-waveglass) | `r03-g09.polar-waveglass` | Polar Waveglass | puzzle | Wave mathematics | premium | `X-R03-G09` |
| 60 | [R03-G10](#r03-g10-standing-wave-garden) | `r03-g10.standing-wave-garden` | Standing Wave Garden | puzzle | Wave mathematics | premium | `X-R03-G10` |
| 61 | [R03-G11](#r03-g11-sinewave-sculptor) | `r03-g11.sinewave-sculptor` | Sinewave Sculptor | puzzle | Wave mathematics | premium | `X-R03-G11` |
| 62 | [R03-G12](#r03-g12-neon-mosaic-route) | `r03-g12.neon-mosaic-route` | Neon Mosaic Route | puzzle | Chromatic logic | premium | `X-R03-G12` |
| 63 | [R03-G13](#r03-g13-spectrum-garden) | `r03-g13.spectrum-garden` | Spectrum Garden | puzzle | Chromatic logic | premium | `X-R03-G13` |
| 64 | [R03-G14](#r03-g14-surface-sonata) | `r03-g14.surface-sonata` | Surface Sonata | puzzle | Wave mathematics | premium | `X-R03-G14` |
| 65 | [R03-G15](#r03-g15-interference-orchard) | `r03-g15.interference-orchard` | Interference Orchard | puzzle | Wave mathematics | premium | `X-R03-G15` |
| 66 | [R03-G16](#r03-g16-color-vaults) | `r03-g16.color-vaults` | Color Vaults | puzzle | Chromatic logic | premium | `X-R03-G16` |
| 67 | [R03-G17](#r03-g17-photon-orchard) | `r03-g17.photon-orchard` | Photon Orchard | puzzle | Chromatic logic | premium | `X-R03-G17` |
| 68 | [R03-G18](#r03-g18-wavefront-weaver) | `r03-g18.wavefront-weaver` | Wavefront Weaver | puzzle | Wave mathematics | premium | `X-R03-G18` |
| 69 | [R03-G19](#r03-g19-pendulum-timeglass) | `r03-g19.pendulum-timeglass` | Pendulum Timeglass | puzzle | Temporal puzzles | premium | `X-R03-G19` |
| 70 | [R03-G20](#r03-g20-time-lock-labyrinth) | `r03-g20.time-lock-labyrinth` | Time-Lock Labyrinth | puzzle | Temporal puzzles | premium | `X-R03-G20` |
| 71 | [R03-G21](#r03-g21-phase-garden) | `r03-g21.phase-garden` | Phase Garden | puzzle | Temporal puzzles | premium | `X-R03-G21` |
| 72 | [R03-G22](#r03-g22-moire-observatory) | `r03-g22.moire-observatory` | Moire Observatory | puzzle | Wave mathematics | premium | `X-R03-G22` |
| 73 | [R03-G23](#r03-g23-aurora-geode) | `r03-g23.aurora-geode` | Aurora Geode | puzzle | Crystal solids | premium | `X-R03-G23` |
| 74 | [R03-G24](#r03-g24-snowflake-foundry) | `r03-g24.snowflake-foundry` | Snowflake Foundry | puzzle | Crystal solids | premium | `X-R03-G24` |
| 75 | [R03-G25](#r03-g25-geode-locksmith) | `r03-g25.geode-locksmith` | Geode Locksmith | puzzle | Crystal solids | premium | `X-R03-G25` |
| 76 | [R04-G01](#r04-g01-icy-polyhedron) | `r04-g01.icy-polyhedron` | Icy Polyhedron | puzzle | Crystal solids | premium | `X-R04-G01` |
| 77 | [R04-G02](#r04-g02-crystal-phase-shift) | `r04-g02.crystal-phase-shift` | Crystal Phase Shift | puzzle | Crystal solids | premium | `X-R04-G02` |
| 78 | [R04-G03](#r04-g03-diamond-pulse) | `r04-g03.diamond-pulse` | Diamond Pulse | puzzle | Crystal solids | premium | `X-R04-G03` |
| 79 | [R04-G04](#r04-g04-octahedral-orchard) | `r04-g04.octahedral-orchard` | Octahedral Orchard | puzzle | Crystal solids | premium | `X-R04-G04` |
| 80 | [R04-G05](#r04-g05-echo-harmonics) | `r04-g05.echo-harmonics` | Echo Harmonics | puzzle | Wave mathematics | premium | `X-R04-G05` |
| 81 | [R04-G06](#r04-g06-memory-marble) | `r04-g06.memory-marble` | Memory Marble | puzzle | Temporal puzzles | premium | `X-R04-G06` |
| 82 | [R04-G07](#r04-g07-echoes-of-stone) | `r04-g07.echoes-of-stone` | Echoes of Stone | puzzle | Temporal puzzles | premium | `X-R04-G07` |
| 83 | [R04-G08](#r04-g08-hourglass-gravity) | `r04-g08.hourglass-gravity` | Hourglass Gravity | puzzle | Temporal puzzles | premium | `X-R04-G08` |
| 84 | [R04-G09](#r04-g09-color-vortex) | `r04-g09.color-vortex` | Color Vortex | puzzle | Chromatic logic | premium | `X-R04-G09` |
| 85 | [R04-G10](#r04-g10-candle-geometry) | `r04-g10.candle-geometry` | Candle Geometry | puzzle | Shadow construction | premium | `X-R04-G10` |
| 86 | [R04-G11](#r04-g11-umbra-rings) | `r04-g11.umbra-rings` | Umbra Rings | puzzle | Shadow construction | premium | `X-R04-G11` |
| 87 | [R04-G12](#r04-g12-nightfall-sculptor) | `r04-g12.nightfall-sculptor` | Nightfall Sculptor | puzzle | Shadow construction | premium | `X-R04-G12` |
| 88 | [R04-G13](#r04-g13-lumen-sudoku) | `r04-g13.lumen-sudoku` | Lumen Sudoku | puzzle | Chromatic logic | premium | `X-R04-G13` |
| 89 | [R04-G14](#r04-g14-eclipse-lantern) | `r04-g14.eclipse-lantern` | Eclipse Lantern | puzzle | Shadow construction | premium | `X-R04-G14` |
| 90 | [R04-G15](#r04-g15-clockwave-harbor) | `r04-g15.clockwave-harbor` | Clockwave Harbor | puzzle | Temporal puzzles | premium | `X-R04-G15` |
| 91 | [R04-G16](#r04-g16-prism-pathways) | `r04-g16.prism-pathways` | Prism Pathways | puzzle | Spatial puzzles | premium | `X-R04-G16` |
| 92 | [R04-G17](#r04-g17-longlight-labyrinth) | `r04-g17.longlight-labyrinth` | Longlight Labyrinth | puzzle | Shadow construction | premium | `X-R04-G17` |
| 93 | [R04-G18](#r04-g18-iridescent-channels) | `r04-g18.iridescent-channels` | Iridescent Channels | puzzle | Chromatic logic | premium | `X-R04-G18` |
| 94 | [R04-G19](#r04-g19-lattice-bloom) | `r04-g19.lattice-bloom` | Lattice Bloom | puzzle | Crystal solids | premium | `X-R04-G19` |
| 95 | [R04-G20](#r04-g20-glass-knot-studio) | `r04-g20.glass-knot-studio` | Glass Knot Studio | puzzle | Crystal solids | premium | `X-R04-G20` |
| 96 | [R04-G21](#r04-g21-time-ribbon-relay) | `r04-g21.time-ribbon-relay` | Time Ribbon Relay | puzzle | Temporal puzzles | premium | `X-R04-G21` |
| 97 | [R04-G22](#r04-g22-gemstone-telegraph) | `r04-g22.gemstone-telegraph` | Gemstone Telegraph | puzzle | Wave optics | premium | `X-R04-G22` |
| 98 | [R04-G23](#r04-g23-soundglass-observatory) | `r04-g23.soundglass-observatory` | Soundglass Observatory | puzzle | Acoustic geometry | premium | `X-R04-G23` |
| 99 | [R04-G24](#r04-g24-refraction-foundry) | `r04-g24.refraction-foundry` | Refraction Foundry | puzzle | Wave optics | premium | `X-R04-G24` |
| 100 | [R04-G25](#r04-g25-prism-terrace) | `r04-g25.prism-terrace` | Prism Terrace | puzzle | Crystal solids | premium | `X-R04-G25` |
<!-- GENERATED:END experience-index -->

## 6. The common experience contract

Every experience, creative or game, free or premium, satisfies this contract before its integration gate can be
recorded. The contract is what "implemented" means in this project.

### 6.1 Behavior

| Id | Requirement |
|---|---|
| E-01 Launch | Opening the experience from the launcher reaches a rendered, interactive first frame without a crash, a blank frame or a blocking prompt. Shaders are compiled during preparation, not on the first interactive frame. |
| E-02 Real rendering | The picture comes from the experience's own scene through the session host and the real renderer. A frame passes a non-blank check and a semantic probe that depends on the experience's state (for example: the placed emitter is visible where it was placed). |
| E-03 Input | Every documented control changes the domain state in the documented way. Input is normalized into domain actions. An invalid action is rejected with a typed reason and leaves the state digest unchanged. Touch is the primary input: a game can be completed with touch alone and never requires a keyboard, pointer, controller, network, motion sensor, microphone, camera or location. |
| E-04 Determinism | `prepare(seed:)` with the same seed gives the same state digest. Domain updates run in fixed steps and do not depend on frame rate. Outcomes are decided by CPU state, never by reading back pixels. |
| E-05 Save and restore | State is saved automatically at suspension and at safe points. After termination and relaunch the experience restores to the same digest. A snapshot from an older schema migrates; a corrupted or newer one produces a recoverable message with Reset and never a crash. |
| E-06 Reset | Reset returns the experience to the state of a fresh preparation with the same seed and clears only its own storage. |
| E-07 Outcome | The experience reaches a meaningful outcome and gives a reason to return: a creative experience produces and keeps a piece of work (preset, composition, export) as its manual requires; a game can be won and lost by its exact rules, records progress, and offers the next level. A UI test of every game reaches win, failure, undo, replay and persistence of the replay: full gameplay, not a looping demo. |
| E-08 Suspend and resume | Backgrounding stops clocks and work; foregrounding resumes without catching up and without a visible jump. Interruptions (calls, audio session interruptions, split view resize) are handled. |
| E-09 Teardown and re-entry | Leaving releases every GPU resource of the session (live and leaked counts are zero). Opening the experience again, or another one, works; 50 open and close cycles do not grow memory or GPU bytes. |
| E-10 Cancellation | Leaving while the experience is still preparing cancels the work; nothing arrives after deactivation. |
| E-11 Failure isolation | An error during preparation, setup or rendering shows a failure view with Retry and Back. The app stays usable. |
| E-12 Accessibility | Controls are native, labelled and reachable with VoiceOver; text scales through Dynamic Type XXXL without clipped controls; Reduce Motion and Reduce Flashing are honored; no rule or state is conveyed by color alone; touch targets meet platform size. |
| E-13 Quality tiers | The experience declares quality tiers with concrete budgets. Changing tier never changes the state digest. Tiers step down under serious thermal state or Low Power Mode. |
| E-14 Privacy | No network use. No data leaves the device. Permissions are requested only when a feature needs them and denial leaves the experience usable with a truthful message. |
| E-15 Entitlement | A premium experience cannot be opened without the entitlement, neither through the launcher nor by any other route. A free experience never queries the store. |

### 6.2 Content completeness

- **Creative experiences (A01–A25).** Every required feature of the card in section 7 is implemented, every
  regression fixture of the card is an automated test, and all seven phases of the app are sealed in the legacy
  ledger.
- **Round 2 games.** The 100 levels of the game's level catalog (chapter section 18; it is canonical where the
  chapter's earlier, shorter manifests differ), each generated from its seed and certified solvable by the game's
  solver with a stored witness; the 80 acceptance scenarios of chapter section 19 as automated tests; a tutorial
  that teaches every rule the levels use; hints; undo where the rules allow it; progress and best results kept;
  the ten game features of section 8 sealed.
- **Round 3 and 4 games.** The 100 levels of the game's archived level manifest, each with its seed, a machine
  checkable win witness and a rejection case; the 80 acceptance scenarios and the 50 fault-injection cases of its
  chapter as automated tests; the ten game features of section 9 sealed.
- **Levels are generated, not written down.** Seeds are built before certification. A seed without a valid and
  unambiguous solution is rejected, and the next salt is taken deterministically and logged. Every level replays
  deterministically and gives the same digest on ten repeats. Repeats are found by a canonical puzzle hash.
  Round 2 levels fall into five difficulty bands; level 001 teaches one control; levels 020, 040, 060, 080 and 100
  close a chapter. Levels of Rounds 3 and 4 form ten worlds of ten with rising limits (section 6.6).
- The level counts are requirements, not goals. A level that exists only as a row in a document is not done. If
  100 valid levels cannot be produced, that is a recorded design blocker, never a reason to fabricate levels. A
  game with fewer certified levels than its source specifies does not pass.

### 6.3 What is not allowed

1. Placeholder content: empty levels, repeated levels under different numbers, "coming soon" screens, lorem ipsum,
   TODO or FIXME markers in shipped sources.
2. Mock-only gameplay: a scenario or test that bypasses the real reducer, solver or renderer; a win state that is
   set rather than reached; a screenshot or recorded video standing in for rendering.
3. Raster art, models or audio made outside the repository, with one exception: the app icon, which is generated
   by a script in the repository.
4. A rule or outcome decided by the GPU, by wall-clock time or by floating-point behavior that differs between the
   simulator and devices.
5. Unbounded work: a loop, recursion, allocation or shader iteration count without a documented limit.
6. A claim in any document, test name or metadata that an experience is implemented, verified or performant
   without the evidence defined in section 22.
7. Anything fabricated: a scheme, a device identifier, a run, a benchmark, an entitlement, a dataset or a
   screenshot. Blocked is never reported as skipped or as passed, and a failed required test never becomes optional.
8. A static scene without independent logic. Skipped is never success.

### 6.4 Evidence for the integration gate

`X-<code>` is recorded only from sealed evidence of these commands (details in section 22.2): the experience's
host tests; the nine scenarios on the iOS 27.x and iOS 26.5 simulators through the verification runner; the UI
tests and accessibility audit of the experience in the unified app; the no-placeholder audits; and, when the
experience changed the framework, the API checks and the ProjectM reference regression.

Capabilities that only hardware can prove (microphone signal quality, thermal behavior, real frame pacing, haptics)
are listed for the experience as *pending hardware verification* and become tasks of the device campaign. Core
gameplay, rendering, persistence and purchase behavior can never be on that list.

Three groups of free experiences have claims that only devices can prove, and for them the line is drawn
explicitly. The audio experiences A06–A08 are complete on the simulator when their logic, interface, synthetic
signal paths, permission handling and persistence pass; the claim that a particular audio source works is a
device task. A24 Graphics Benchmark Lab is complete when its scenes, measurement pipeline and reports work; the
measurements themselves are device results. For A09, A18 and A21, idle power and thermal behavior are device
tasks.

### 6.5 Rules for every game

1. Each game has at least one real three-dimensional interaction, a win state and a fail state, pause and replay,
   and progress that is kept offline.
2. Each chapter states twelve invariants and each is a test: fixed step, input budget, goal, repeatability, undo, a
   witness per level, honest failure, finite values, atomic save, renderer purity, nothing sold inside the game,
   and novelty.
3. Every gesture has a stepper alternative. No solution depends on timing precision or on flicker.
4. Quality tiers trade samples, layers and resolution and never change what a scene means or what a level requires.
5. Saves are atomic, carry a checksum and recover from corruption.
6. The automation of each game has these run modes: launch, tutorial, win, fail, undo, restore, hero, stress,
   accessibility, container scan, exit.
7. A game's constants (tolerances, budgets, step size) change only through a recorded decision with a test that
   proves the change.
8. The hero scene is checked at a fixed camera and seed: a screenshot with a semantic description of the scene,
   histogram, no black frame, no non-finite value, silhouette bounds, and a tolerant pixel comparison. A known-good
   reference image is never overwritten.
9. **Human reviews do not gate.** Whether a scene is beautiful, whether two games feel distinct, whether a
   newcomer understands the goal within five seconds and the outside-player comprehension test are owner reviews
   (OD-09). They are recorded before release. The automated checks of this section and of section 22 are what
   gates.
10. **The launch set is never reduced.** The sources allow a concept to be killed, pivoted or merged after a
    prototype. For the 100 launch experiences that verdict is not available: a concept that fails its criteria is
    redesigned inside its concept, with the failed evidence and the redesign recorded in an ADR. If it still
    fails, its gate is blocked for the owner (OD-10). Nothing is dropped, merged or replaced.

### 6.6 Additional rules for the games of Rounds 3 to 12

These are the constants of the chapter template that all 250 later games share.

- **Time and state.** A fixed tick of 1/120 s (1/240 s only where a collision proof needs it), integer ticks,
  bounded controls and versioned `Codable` state. No GPU value and no frame delta decides an outcome.
- **Actions.** Typed actions carry a control id, a tick and coordinates. An illegal action gets a typed rejection
  and changes nothing. A win requires all conditions to hold together for a number of fixed ticks that the chapter
  states (five to eight). Pause, undo and retry are always available. A failure never corrupts a save.
- **Proof.** The solver gives, for every shipped level, a machine-readable witness (actions and digest) and a
  contrasting invalid action. A level with no witness, with an unintended second solution or with unreachable
  targets is rejected. A non-finite value or a zero step fails the test.
- **First session.** Six beats in two minutes; the goal stated in fewer than twelve words; one finger manipulates,
  two fingers orbit; controls of at least 44 by 44 points; state announced to VoiceOver; symbols besides color; a
  camera reset; undo.
- **Rendering.** Immutable render snapshots; no baked raster hero art; GL resources rebuilt from CPU scene data
  after a context loss; every shader variant compiles on both runtimes; one golden seed and camera manifest per
  game, produced by the real renderer.
- **Levels.** Ten worlds of ten levels. From world to world the solver depth limit rises from 14 to 50 moves, the
  gesture travel of the witness from 145 to 280 points, and the number of controls from one to four; each new
  rule gets one tutorial level without penalty. Each level has an objective, a difficulty, a predicate, a move
  budget, a certified replay, a rejected-action certificate, scene and camera, accessibility notes, quality tiers,
  a checksum and a stable id, and six generated artifacts (witness, reject, render, input, access, sha256). A
  missing or unsolved level is rejected.
- **Scenarios.** The 80 acceptance scenarios (S001 to S080) rotate through twelve classes: load and reset, win,
  failure, undo and redo, replay, gesture, accessibility, graphics, performance, privacy, backgrounding and OS
  compatibility; each names its level, seed, negative path and proof file. All classes run as host tests; the
  simulator runs may be a stratified sample. The table alone is not evidence.
- **Fault injection.** The 50 cases (F001 to F050) apply 25 mutations twice, among them context recreation, pause
  and resume, a zero tick, non-finite input, a corrupt save and a lost surface. The logic digest stays
  deterministic; rendering recovers or fails with a typed error.

## 7. Free library I: the 25 creative experiences (A01–A25)

These are the 25 original VisualCore apps. Each was specified as a separate app with seven phases (P00 audit, P01
to P05 feature phases, P06 final verification). They are now experiences of the one app, and the phases remain
the unit of work:

- Each phase is one Spec Kit feature (`specs/011` … `specs/185`, ADR-0004) and one gate of the **legacy** ledger,
  operated with `Tools/python/desktop_runbook.py` in the original order. The next legacy gate on 2026-11-11 was
  `A04-P04`.
- The phase prompts are the archived ones (`python3 scripts/speckit_prompts.py --feature NNN`), used verbatim
  together with the canonical override printed by `python3 scripts/planning_index.py prompt --feature A<nn>-P<p>
  --override`: no standalone target, no bundle identifier, no store listing; sources live in the experience
  modules of section 16.
- Phase 06 keeps its quality, privacy, accessibility and regression gates. Its store-listing, pricing and per-app
  release-dossier parts are inapplicable (C-06).
- When all seven phases are sealed, the experience is verified inside the unified app and its integration gate
  `X-A<nn>` is recorded in the migration ledger (section 22.2).

A01, A02 and A03 are complete as standalone apps and A04 is partly complete (section 3); UA-F07 adopts them into
the unified app without changing their behavior (section 17).

Standard for every creative experience: a meaningful product with its own identity, real working controls, the
core interaction and persistence of its manual, deterministic sample data, stress and error scenarios, and
documented supported and unsupported platform features. A module that compiles but lacks its core interaction
fails.

All 25 are mandatory and are built in the order 01 to 25. The "waves" of the source are hints about shared
dependencies, not a different order.

Minimum proof per phase:

| Phase | Minimum proof before the gate |
|---|---|
| P00 | read-only audit of the framework surfaces the app will use; gaps recorded |
| P01 | host unit tests of the domain core and basic simulator UI tests |
| P02 | real GPU scene evidence on the simulator |
| P03 | every mandatory workflow, including its negative cases |
| P04 | content parsing and validation of snapshots and exports |
| P05 | quotas and limits, accessibility, privacy, localization readiness, crash and fuzz tests |
| P06 | independent full verification of the whole experience |

Rules by class of experience:

- **Simulations** (fluid, particles, rays, physics, fractals, orbits): fixed step, explicit units and camera
  conventions, saved seed and configuration, bounded iteration counts, a stated policy for overflow and non-finite
  values, and comparison with independent CPU reference formulas.
- **Audio** (A06–A08): the source is chosen natively and labelled honestly, including "unavailable"; permission
  denial, route changes and interruptions are handled; real-time callbacks neither allocate nor wait on a lock;
  buffers and latency are bounded; captured audio is not retained.
- **Science** (A14, A15, A17): sourced data with revision notes and uncertainty where it matters; accuracy is
  reviewed separately from rendering; anatomy is education, never diagnosis or treatment.
- **Authoring tools** (A22, A23, A25): untrusted shaders, graphs and imports are bounded; cycles and invalid paths
  are rejected; passes, texture memory and compile time have caps; a failure is handled gracefully.
- **Ambient** (A18–A21): export of images and video only through the public share and save APIs, checked before
  the feature is designed; the app never claims to install an always-running animated wallpaper; battery,
  brightness, Reduce Motion and Reduce Flashing are respected.
- **Benchmark** (A24): repeatable measurements are kept apart from thermal and device-dependent ones; no GPU
  timing precision is claimed unless a platform API provides it.
- Every parser, shader compile and graph evaluation is bounded, recoverable and fuzz-tested; sizes, ranges and
  durations have limits.

The manuals are plans, not evidence, and the API, file and package names in them are provisional. Monetization
ideas in the brainstorm (paid packs, premium themes, scene packs, collectible environments, subscriptions) are
superseded: every creative experience is free and complete.

**Code-only visuals apply here too.** Some manuals mention licensed or purchased meshes, textures, atlases or
streamed asset packs (A12 Tiny Worlds, A17 Interactive Anatomy). Under P-06 the geometry and imagery of those
experiences are generated by code. Bundled *data* (numbers, names, structures, measurements) is allowed with a
license and a provenance record. The card text below is the source's wording; this paragraph prevails.

<!-- GENERATED:BEGIN cards-creative -->
### A01 Generative Art Studio

`a01.generative-art-studio` · free · category create · family Creative and visual · legacy gates `A01-P00` … `A01-P06` (specs 011–017) · integration gate `X-A01`

A curated, touch-responsive procedural-art studio that converts parameterized GPU scenes into saveable compositions.

- **Primary capability:** visual parameter editor, deterministic GLSL art, export/presets. **Main validity risk:** reproducible image, project schema and export fidelity.
- **Capabilities:** Shader pipelines and shader asset management; Animation and time-based parameters; Render targets and framebuffer management; Procedural textures and geometry; Presets and user-adjustable parameters; Touch interaction and gesture controls. **For:** Casual makers wanting attractive output without code; Visual artists exploring iterative procedural imagery; Creators looking for repeatable exports.
- **Journeys:** (1) Open gallery, preview a scene, enter live edit, adjust palette and motion, save a named composition. (2) Reopen a saved composition and verify the same seed and parameter values restore the scene. (3) Export one full-resolution still after checking the crop and resolution.
- **Required features:** (1) Four genuinely distinct scene families: gradient noise, raymarched shapes, geometric tiling and particles. (2) Parameter panel with constrained ranges, immediate previews and reset. (3) Seed-based reproducibility and gallery presets. (4) Versioned local document store with favorites and duplication. (5) Still export via offscreen render with proper color space and aspect handling. (6) Scene pause, scrub time and accessibility-friendly motion reduction.
- **Non-goals:** User-authored arbitrary GLSL during MVP; Social accounts, cloud sharing and subscription infrastructure; Timeline editing and multi-pass user-authored graphs. **Later ideas (not in the first release):** Layered compositing and mask tools; Shareable preset format with integrity checks; Video export and user shader authoring.
- **Domain types (proposed contracts):** `ArtDocument(id UUID, schemaVersion Int, sceneID String, seed UInt64, paletteID String, parameters Map<String, Float>, previewTime Seconds)`; `ShaderParameter(id, units, minimum, maximum, default, UITransform)`; `GalleryEntry(presetID, thumbnailAsset, compatibleEngineVersion)`; `ExportJob(sizePixels, format, colorProfile, requestedTime)`.
- **Components named by the manual:** `ArtDocument.swift` (data storage); `ParameterSchema.swift` (domain); `GalleryCatalog.swift` (data storage); `ArtSceneController.swift` (domain); `ArtRenderer.swift` (renderer); `ShaderSceneRegistry.swift` (renderer); `ExportCoordinator.swift` (data storage).
- **Algorithm decisions:** (1) Separate document determinism from wall-clock animation; render using stored seed plus explicit simulation time. (2) Validate parameter schemas before uploading uniforms; define migration rules when effects change. (3) Prefer analytic shader scene families before adding heavy simulation; compose in linear light then present in sRGB. (4) Keep previews cancellable and thumbnails cached by scene version, seed and parameter hash.
- **Render stages:** (1) Load preset and validated parameter values. (2) Build per-scene uniforms and allocate shader resources through VisualCore. (3) Execute scene program, optional simple effect pass and tone/color mapping. (4) Present to ANGLE/EGL-backed surface; offline still export reuses the same render path with a separate target.
- **Engineering rule:** First independent art consumer should test VisualCore shader registry, parameter uniforms, presets and export without linking ProjectM engine code.
- **Regression fixtures (acceptance):** (1) Given same seed and explicit time, parameter serialization round-trips and image comparison remains within defined GPU tolerances. (2) Corrupt or future schema versions surface a recoverable error. (3) Rapid palette edits do not leak programs, textures or FBOs. (4) Export dimensions and alpha/color profiles match user selection. (5) Background/foreground recreation restores scene without stale GL handles.
- **Profiling:** Measure 30/60 fps configurations on target devices, avoid hard guarantees before benchmarks; Keep compilation off the interaction critical path where supported; cache verified binaries only when valid; Reduce iteration counts and resolution before dropping interaction frames.
- **Risks:** Preset migrations can silently change visual results—version presets and retain snapshot fixtures; Shaders may compile differently across devices—track compile logs and maintain low-complexity fallbacks; Export at large sizes can exceed GPU limits—tile or cap according to queried limits.
- **Phases:** P00 Foundation and VisualCore boundary audit; P01 Gallery and domain contract; P02 Shader scenes and parameter controls; P03 Save and restore compositions; P04 Offscreen still export; P05 Polish, accessibility and regression; P06 Final verification, privacy, packaging and release.
- **Source:** `docs/archive/planning/embedded/apps/01-generative-art-studio.md` (lines 1–652). Prompts: `python3 scripts/speckit_prompts.py --feature 011` … `--feature 017`, each with the override of `python3 scripts/planning_index.py prompt --feature A01-P00 --override`.

### A02 Fluid Art Playground

`a02.fluid-art-playground` · free · category create · family Creative and visual · legacy gates `A02-P00` … `A02-P06` (specs 018–024) · integration gate `X-A02`

A tactile ink-and-fluid playground driven by a bounded GPU-feedback simulation with clear quality presets.

- **Primary capability:** FBO feedback, stable paint/fluid simulation. **Main validity risk:** timestep stability, mass/energy and resize recovery.
- **Capabilities:** Ping-pong framebuffers; Texture feedback; GPU simulation techniques; Shader-based advection and diffusion effects; Touch input as simulation forces; Color blending and post-processing. **For:** Families and casual players who want immediate visual response; Creators seeking satisfying ink, smoke and dye compositions.
- **Journeys:** (1) Swipe to inject pigment and velocity; pinch to change brush radius. (2) Switch dye palette and simulation viscosity; reset to a known starting state. (3) Pause, step a frame, resume and capture a still.
- **Required features:** (1) 2D velocity and dye fields on a bounded simulation grid. (2) Multi-touch splat input with capped injection rate and smooth resampling. (3) Adjustable viscosity, dissipation and pressure iteration quality. (4) Distinct ink, smoke and glowing-dye palettes. (5) Pause, reset, deterministic seeded test mode, and still capture. (6) Configurable simulation resolution with thermal downgrade.
- **Non-goals:** Physically accurate water surface simulation; Arbitrary 3D fluid dynamics; Unbounded particle emission or background compute. **Later ideas (not in the first release):** Obstacles and flow masks; Export animated loops; Advanced vorticity confinement and multi-layer media.
- **Domain types (proposed contracts):** `FluidConfiguration(gridWidth, gridHeight, timeStep, pressureIterations, dyeDissipation, velocityDissipation, viscosity)`; `Splat(positionNormalized, radius, forceVector, rgba, timestamp)`; `FluidState(velocityPingPong, dyePingPong, pressurePingPong, divergence, obstacles)`; `QualityProfile(gridScale, maxSplatsPerFrame, solverIterations)`.
- **Components named by the manual:** `FluidConfig.swift` (domain); `SplatQueue.swift` (domain); `FluidSimulation.swift` (domain); `FluidRenderGraph.swift` (renderer); `QualityController.swift` (domain).
- **Algorithm decisions:** (1) Use semi-Lagrangian advection for MVP, with explicitly documented numerical diffusion. (2) Compute divergence, iterative pressure estimate and velocity projection using ping-pong framebuffers. (3) Clamp delta time and cap splat count to avoid instability after a long app suspension. (4) Define coordinate and framebuffer orientation; no read/write feedback to the same bound texture. (5) Expose test-mode fixed time step and seed; document that the model is artistic, not physical validation.
- **Render stages:** (1) Drain and normalize touch splats. (2) Apply velocity and dye injection pass. (3) Advect velocity and dye; compute divergence; run pressure Jacobi passes; subtract pressure gradient. (4) Composite dye with display palette and bloom; present via existing ANGLE-backed render host.
- **Engineering rule:** The fluid solver must be an isolated app-domain component with a reference CPU test implementation for a handful of tiny grids, not a new VisualCore renderer.
- **Regression fixtures (acceptance):** (1) Uniform dye at rest decays only according to configured dissipation. (2) Zero-velocity test keeps a known dye pattern bounded. (3) Boundary modes have fixture tests and no out-of-bounds sampling. (4) Every ping-pong pass writes to a different target from its sampled input. (5) Suspend/resume causes bounded catch-up, not hundreds of solver steps.
- **Profiling:** Baseline low resolution first; expose quality tiers with measured frame time; Track per-pass timing if supported, memory footprint and dye field resolution; Gracefully reduce pressure iterations before reducing touch responsiveness.
- **Risks:** FBO formats and texture filtering support vary—probe actual ANGLE/GL ES capabilities and select fallback formats; Solver cost grows with screen size and iterations—separate simulation from presentation resolution; High-frequency touch events may overwhelm input—coalesce and bound queues.
- **Phases:** P00 Foundation and VisualCore boundary audit; P01 Ping-pong feedback validation; P02 Core fluid advection and splat injection; P03 Pressure projection and quality control; P04 Interaction and capture UX; P05 Numerical fixtures and device stress tests; P06 Final verification, privacy, packaging and release.
- **Source:** `docs/archive/planning/embedded/apps/02-fluid-art-playground.md` (lines 1–650). Prompts: `python3 scripts/speckit_prompts.py --feature 018` … `--feature 024`, each with the override of `python3 scripts/planning_index.py prompt --feature A02-P00 --override`.

### A03 Fractal Explorer

`a03.fractal-explorer` · free · category create · family Creative and visual · legacy gates `A03-P00` … `A03-P06` (specs 025–031) · integration gate `X-A03`

A navigable, explanatory Mandelbrot and Julia set explorer with reproducible camera bookmarks.

- **Primary capability:** deep zoom, precision-aware fractal renderer. **Main validity risk:** zoom precision, shader limits, deterministic viewport.
- **Capabilities:** High-resolution fragment shaders; Coordinate transforms; Precision management; Parameter animation; Color mapping and palette systems. **For:** Math learners comparing fractal parameters; Artists looking for palette and composition exploration.
- **Journeys:** (1) Start from curated location, pinch to zoom and drag to pan. (2) Switch Mandelbrot/Julia and scrub Julia seed. (3) Save a coordinate bookmark; render a still with visible precision warning if necessary.
- **Required features:** (1) Mandelbrot and Julia modes with accessible mode explanations. (2) Continuous pinch/pan and animated palette controls. (3) Location bookmarks including coordinates and rendering precision mode. (4) Adjustable iteration cap with explicit render-cost estimate. (5) Still capture and curated guided tours. (6) Visible limits and graceful clamping when the requested zoom exceeds reliable numerical precision.
- **Non-goals:** Unlimited deep zoom claimed on 32-bit floating point; Scientific claims about precision beyond verified shader support; Community gallery and user-coded formulas. **Later ideas (not in the first release):** Perturbation/reference-orbit precision acceleration; Formula editor; Recorded fly-through animations.
- **Domain types (proposed contracts):** `FractalView(centerX, centerY, scale, aspect, mode, juliaCReal, juliaCImag)`; `FractalParameters(maxIterations, escapeRadius, paletteID, smoothing, antialiasSamples)`; `FractalBookmark(schemaVersion, view, parameters, displayName)`; `PrecisionStatus(requestedZoom, effectiveMantissa, warning)`.
- **Components named by the manual:** `ComplexViewport.swift` (domain); `FractalState.swift` (domain); `BookmarkStore.swift` (data storage); `PrecisionAdvisor.swift` (domain); `GestureMath.swift` (domain); `FractalRenderer.swift` (renderer).
- **Algorithm decisions:** (1) Pixel-to-complex mapping must account for aspect ratio and resolution-independent gesture updates. (2) Implement escape-time iteration and smoothed color bands with explicit guard against NaN/Inf. (3) Audit float precision on target ANGLE-backed devices before promising deep zoom; employ documented emulated double or CPU tile fallback only if needed. (4) Calculate preview with reduced iteration count while user is moving, then refine at rest.
- **Render stages:** (1) Map touch/camera state into complex plane. (2) Dispatch shader for escape-time count and smooth escape value. (3) Apply independently controlled color palette and optional supersampling. (4) Composite guidance overlay and present; use offscreen high-resolution path for capture.
- **Engineering rule:** Render precision must be presented as an engineering limitation of the selected ANGLE/OpenGL ES shader path, not solved by silently introducing a Metal renderer.
- **Regression fixtures (acceptance):** (1) Known points: Mandelbrot origin interior, c=2 outside, and known Julia samples. (2) Zoom under centered pinch keeps selected complex coordinate stationary. (3) Aspect-ratio changes preserve center and avoid distortion. (4) Precision-warning thresholds are based on measured/known representation limits. (5) Saved bookmarks round-trip and reproduce views within tolerances.
- **Profiling:** Profile panning frame pacing independently from high-quality settled render; Bound GPU loops and adapt iteration count to zoom and interaction; Test landscape, portrait and split-view display transforms.
- **Risks:** 32-bit precision causes jitter or blank screens at deep zoom—do not market unbounded zoom; Extreme iteration counts can freeze UI—cap and add asynchronous refinement; Gesture transform bugs accumulate—use double on CPU view state and stable coordinate transforms.
- **Phases:** P00 Foundation and VisualCore boundary audit; P01 Complex-plane math and fixtures; P02 Fractal shaders and precision probe; P03 Navigation and bookmarks; P04 High-resolution capture and tours; P05 Device precision and performance validation; P06 Final verification, privacy, packaging and release.
- **Source:** `docs/archive/planning/embedded/apps/03-fractal-explorer.md` (lines 1–645). Prompts: `python3 scripts/speckit_prompts.py --feature 025` … `--feature 031`, each with the override of `python3 scripts/planning_index.py prompt --feature A03-P00 --override`.

### A04 Particle Universe

`a04.particle-universe` · free · category create · family Creative and visual · legacy gates `A04-P00` … `A04-P06` (specs 032–038) · integration gate `X-A04`

An interactive particle-field sandbox featuring emitters, forces, trails and presets.

- **Primary capability:** performant particle instancing and trails. **Main validity risk:** pooling, spawn bounding, frame pacing.
- **Capabilities:** GPU-oriented particle simulation; Buffer management; Instanced rendering; Blending and trails; Interaction and simulation parameters. **For:** Casual visual explorers; Creative coders evaluating particle dynamics; STEM learners experimenting with attractive and repulsive fields.
- **Journeys:** (1) Choose starfield preset, tap to create attractor, drag to move it. (2) Change emitter type and particle lifetime and toggle trails. (3) Pause, reseed and replay a deterministic scene to compare behavior.
- **Required features:** (1) Multiple emitter families with bounded particle counts. (2) Point attractors, repulsors and gravity/wind fields. (3) Adjustable particle size, lifetime, color gradient and trail strength. (4) Instanced/sprite batch rendering with performance fallback. (5) Pause/reseed/save a scene. (6) Device-adaptive quality and reduced-flash mode.
- **Non-goals:** Unlimited-N-body exact physical simulation; Online particle preset marketplace; Networked multi-user simulation. **Later ideas (not in the first release):** 3D gravitational scenes; Particle interaction with imported images; Preset sharing with safe schema validation.
- **Domain types (proposed contracts):** `Particle(position2D, velocity2D, age, lifetime, color, size, seed)`; `Emitter(kind, spawnRate, position, spread, initialVelocity, seed)`; `ForceField(kind, center, strength, falloff, radius)`; `ParticleScene(emitters, forces, qualityTier, timeScale, trailDecay)`.
- **Components named by the manual:** `ParticleScene.swift` (domain); `ParticleEmitter.swift` (domain); `ForceField.swift` (domain); `ParticleSimulator.swift` (domain); `ParticleRenderer.swift` (renderer); `TrailBuffer.swift` (renderer).
- **Algorithm decisions:** (1) Begin with a deterministic fixed-step CPU reference for small populations and compare GPU behavior later. (2) Use bounded acceleration, damping, respawn rules and border wrap/reflect semantics. (3) Pick buffer/texture-backed state update based on audited GL ES features; avoid unsupported compute assumptions. (4) Use decay ping-pong render targets for trails and separate simulation from presentation resolution.
- **Render stages:** (1) Collect input-generated force changes. (2) Update particles with fixed timestep and capped substeps. (3) Stream or update GPU particle state and draw in batched instanced quads/points. (4) Fade and composite trail target, tone map and present.
- **Engineering rule:** Provide a standalone particle feature test harness so VisualCoreParticles is extracted only after a second app needs the same abstraction.
- **Regression fixtures (acceptance):** (1) Replay seed, controls and fixed-step stream reproduces position fixtures on CPU. (2) High particle count respects configured cap and yields to quality controller. (3) Trail FBOs resize and clear without texture leaks. (4) Force singularities do not produce NaN/Inf positions. (5) Resume from background does not fast-forward unbounded time.
- **Profiling:** Instrument particle update cost, draw count, memory and p95 frame time; Decouple visual sparkle from high physical particle count; Set quality policy from measurements on at least one low- and one high-end device.
- **Risks:** GPU buffer/instance support may not match assumptions—probe before selecting data layout; Additive blending may be uncomfortable—offer flash and brightness limits; Particle count increases thermal pressure—cap and adapt tiers.
- **Phases:** P00 Foundation and VisualCore boundary audit; P01 Seeded particle domain model; P02 One emitter and one force in render loop; P03 Trails and multiple emitters; P04 Scene editor and persistence; P05 Profiling and low-end device tuning; P06 Final verification, privacy, packaging and release.
- **Source:** `docs/archive/planning/embedded/apps/04-particle-universe.md` (lines 1–647). Prompts: `python3 scripts/speckit_prompts.py --feature 032` … `--feature 038`, each with the override of `python3 scripts/planning_index.py prompt --feature A04-P00 --override`.

### A05 Infinite Geometry

`a05.infinite-geometry` · free · category create · family Creative and visual · legacy gates `A05-P00` … `A05-P06` (specs 039–045) · integration gate `X-A05`

An animated geometry laboratory for tilings, kaleidoscopes, procedural objects and camera-driven compositions.

- **Primary capability:** animated procedural geometry/camera. **Main validity risk:** geometry correctness and numerical bounds.
- **Capabilities:** Geometry rendering; Shader effects; Transformations; Camera controls; Procedural mesh generation. **For:** Visual-art hobbyists; Designers exploring symmetry and pattern families; Learners who benefit from geometric demonstrations.
- **Journeys:** (1) Browse tessellation or kaleidoscope scene. (2) Change symmetry order and geometry depth. (3) Orbit a 3D composition and save a named parameter preset.
- **Required features:** (1) At least two 2D tiling modes and one 3D procedural composition. (2) Touch orbit/pan/zoom with reset and camera bounds. (3) Symmetry group, repetition count, scale and palette controls. (4) Deterministic presets and still export. (5) Adaptive mesh tessellation and render-quality settings. (6) On-screen parameter explanations.
- **Non-goals:** General-purpose CAD or exact geometry solver; Import/export arbitrary mesh formats in MVP; Unlimited recursion depth. **Later ideas (not in the first release):** User-defined shape graphs; AR placement if justified; Animated vector/video export.
- **Domain types (proposed contracts):** `GeometryPreset(kind, symmetryOrder, repeats, paletteID, seed, camera, schemaVersion)`; `ParametricShape(type, controlPoints, resolution, materialID)`; `CameraPose(position, target, FOV, near, far)`; `MeshBudget(maxVertices, maxIndices, maxDrawCalls)`.
- **Components named by the manual:** `GeometryPreset.swift` (domain); `SymmetryMapping.swift` (domain); `ProceduralMeshBuilder.swift` (domain); `OrbitCamera.swift` (domain); `GeometrySceneController.swift` (domain); `GeometryRenderer.swift` (renderer).
- **Algorithm decisions:** (1) Implement mathematically stable coordinate transforms for wallpaper/kaleidoscope mappings. (2) Use signed-distance-field fragments for simple repeated patterns, vertex meshes for selected 3D objects. (3) Precompute bounded meshes outside render callback and cache by parameter signature. (4) Keep normal generation and winding consistent; cap subdivision and clip planes.
- **Render stages:** (1) Resolve preset, camera and symmetry parameters. (2) Generate/cache mesh when topology changes. (3) Render 2D SDF or 3D mesh scene using GL ES programs and depth state. (4) Apply simple post-process and export/present through VisualCore target.
- **Engineering rule:** Use the shared VisualCore scene and camera APIs only if the audited API really supports these use cases; document missing requirements as upstream feature requests.
- **Regression fixtures (acceptance):** (1) Symmetry order one is identity and higher orders repeat correctly. (2) Mesh generation has index bounds and valid normals. (3) Zoom and FOV clamps avoid singular or clipped camera states. (4) Repeated preset transitions leave GPU objects stable. (5) Non-square displays keep geometric proportions.
- **Profiling:** Cap vertex count, draw calls and geometry regeneration frequency; Track mesh cache hit/miss and upload stalls; Provide lower-poly preview while expensive meshes are prepared.
- **Risks:** High tessellation spikes CPU/memory—mesh budget and async generation; Shader-based illusions can be misleading to learners—label exact versus stylized modes; Floating point transform drift—normalize camera and transforms.
- **Phases:** P00 Foundation and VisualCore boundary audit; P01 Geometry transforms and presets; P02 2D kaleidoscope renderer; P03 3D mesh and camera; P04 Scene editing and export; P05 Mesh/cache/device regression; P06 Final verification, privacy, packaging and release.
- **Source:** `docs/archive/planning/embedded/apps/05-infinite-geometry.md` (lines 1–645). Prompts: `python3 scripts/speckit_prompts.py --feature 039` … `--feature 045`, each with the override of `python3 scripts/planning_index.py prompt --feature A05-P00 --override`.

### A06 VisualCore Music Lab

`a06.visualcore-music-lab` · free · category audio · family Music and audio · legacy gates `A06-P00` … `A06-P06` (specs 046–052) · integration gate `X-A06`

A modern audio-reactive visualizer with oscillograms, spectrum analysis and customizable graphics scenes that is not a ProjectM clone.

- **Primary capability:** authorized audio input, FFT and visual mapping. **Main validity risk:** source capability honesty, callback safety, permissions.
- **Capabilities:** Audio-reactive parameters; Shader effects; Post-processing; Animation; Scene and preset management. **For:** Musicians testing dynamics visually; People playing owned or in-app-controlled audio; Users seeking microphone-reactive visuals.
- **Journeys:** (1) Choose microphone or an app-owned audio file and grant permission where needed. (2) Switch waveform, spectrum and reactive geometric scene. (3) Calibrate gain, adjust colors and save a scene preset.
- **Required features:** (1) Microphone permission-gated live input and local file audio the app can legally decode. (2) RMS, peak, FFT spectrum and smoothed beat-energy signals. (3) Three visually different scenes: bars, waveform rings and 3D-ish responsive geometry. (4) Source/status indicator and audio-interruption recovery. (5) Parameter presets, local persistence and accessibility text metrics. (6) Silent demo signal for offline testing.
- **Non-goals:** Capturing protected/other apps system audio such as Spotify without supported APIs; Reusing MilkDrop engine code as default implementation; Recording/uploading microphone audio to servers. **Later ideas (not in the first release):** MIDI control and OSC-style controls if appropriate; Additional owned-file and streaming inputs via legal APIs; On-device visual recordings with clear consent.
- **Domain types (proposed contracts):** `AudioSource(kind microphone|localFile|demo, permissionState, route)`; `AudioFeatures(timestamp, rms, peak, bandEnergies, spectralFlux)`; `ReactiveMapping(feature, gain, attack, release, clamp, targetUniform)`; `MusicPreset(sceneID, paletteID, mappings, schemaVersion)`.
- **Components named by the manual:** `AudioSourceController.swift` (audio acquisition or signal-feature mapping); `PCMBufferRing.swift` (audio acquisition or signal-feature mapping); `SpectrumAnalyzer.swift` (audio acquisition or signal-feature mapping); `FeatureSmoother.swift` (domain); `AudioReactiveMapping.swift` (audio acquisition or signal-feature mapping); `MusicSceneRenderer.swift` (renderer).
- **Algorithm decisions:** (1) Use AVAudioEngine/AVAudioSession only for approved audio sources and handle route/interruptions explicitly. (2) Compute windowed FFT from bounded ring buffer outside realtime audio callback; avoid allocations/locks in callback. (3) Time-stamp audio features and interpolate/smooth parameters at render-frame boundary. (4) Keep source source/permission state separate from graphics and avoid assuming projectM audio capture API supports arbitrary apps.
- **Render stages:** (1) Acquire PCM from permitted source. (2) Convert to mono or per-channel visualization buffers and compute bounded features. (3) Smooth and map features to uniforms at frame cadence. (4) Render scene passes with VisualCore shaders; present or display silent demo fallback.
- **Engineering rule:** Use only documented Apple audio sources; do not promise systemwide audio capture for streaming services. Clearly label demo signal versus real microphone/file inputs.
- **Regression fixtures (acceptance):** (1) Synthetic sine wave produces peak at expected FFT bin within tolerance. (2) Silence yields zero/near-zero features and stable display. (3) Audio callback never performs dynamic allocations on the hot path. (4) Permission-denied path is still usable in demo mode. (5) Interruption and route-change transitions do not leave audio engine or EGL state stuck.
- **Profiling:** Monitor audio callback underruns, feature latency and render p95 frame time independently; Maintain realtime-safe callback policy and bounded ring buffer; Throttle heavy FFT/graphics work on thermal pressure without altering capture consent.
- **Risks:** iOS generally does not expose arbitrary other-app audio capture—market supported inputs only; Audio route/device timing varies—timestamp and smooth feature transfer; Sharing code with ProjectM could accidentally import ProjectM-specific logic—enforce module boundary.
- **Phases:** P00 Foundation and VisualCore boundary audit; P01 Audio source and permission shell; P02 FFT/feature analysis with fixtures; P03 Three visual scenes and mapping editor; P04 Presets and recovery UX; P05 Audio/render performance and accessibility; P06 Final verification, privacy, packaging and release.
- **Source:** `docs/archive/planning/embedded/apps/06-visualcore-music-lab.md` (lines 1–645). Prompts: `python3 scripts/speckit_prompts.py --feature 046` … `--feature 052`, each with the override of `python3 scripts/planning_index.py prompt --feature A06-P00 --override`.

### A07 Audio Odyssey

`a07.audio-odyssey` · free · category audio · family Music and audio · legacy gates `A07-P00` … `A07-P06` (specs 053–059) · integration gate `X-A07`

An audio-reactive journey through procedural tunnels, particle corridors and moving landscapes.

- **Primary capability:** music-reactive immersive visual journey. **Main validity risk:** limited audio access, comfort/sickness mitigation.
- **Capabilities:** 3D scene rendering; Camera systems; Audio feature integration; Procedural environments; Animation and transitions. **For:** Entertainment users wanting immersive visuals; Creators seeking audio-driven ambient journeys.
- **Journeys:** (1) Select a legally available audio source or demo soundtrack. (2) Pick tunnel, landscape or star-corridor journey and start flight. (3) Adjust speed/sensitivity, pause scene and switch to low-motion mode.
- **Required features:** (1) Three distinct procedural environments with controlled camera rail. (2) Audio features mapped to scene geometry/lighting rather than hard cuts. (3) Manual flight speed, camera easing and reduced-motion setting. (4) Microphone/local-app-owned-audio/demo input modes. (5) Save environment + mapping presets. (6) Stable pause/resume and thermal quality downgrade.
- **Non-goals:** Systemwide capture of third-party protected audio; VR/headset support in MVP; Real-time open-world exploration and navigation. **Later ideas (not in the first release):** Curated audio journeys and scene packs; User-controlled path branches; Compatible spatial audio presentation if justified.
- **Domain types (proposed contracts):** `JourneyState(worldID, distance, speed, cameraPose, seed, paused)`; `WorldDescriptor(meshRule, materialIDs, eventMappings, horizonPolicy)`; `AudioReactiveEnvelope(low, mid, high, transient, timestamp)`; `ComfortSettings(maxCameraAcceleration, flashLimit, horizonLock)`.
- **Components named by the manual:** `JourneyController.swift` (domain); `ProceduralTunnel.swift` (domain); `LandscapeSegments.swift` (domain); `CameraRail.swift` (domain); `AudioJourneyMapper.swift` (audio acquisition or signal-feature mapping); `MotionComfort.swift` (domain); `OdysseyRenderer.swift` (renderer).
- **Algorithm decisions:** (1) Generate a bounded streaming corridor/terrain mesh around camera and retire segments behind viewer. (2) Use smoothed, clamped audio envelopes to alter color, scale and geometry only within stable bounds. (3) Model camera travel on deterministic path; keep world origin rebasing if distance grows. (4) Separate comfort settings from audiovisual defaults to mitigate simulator sickness.
- **Render stages:** (1) Decode permitted audio and create feature envelope. (2) Advance deterministic journey timeline and update nearby procedural segments. (3) Render terrain/tunnel, audio-reactive materials and particles. (4) Composite fog and post effect; present via VisualCore, with reduced-motion camera fallback.
- **Engineering rule:** Do not claim support for arbitrary background music capture; specify app-owned audio files, demo audio, or consented microphone capture.
- **Regression fixtures (acceptance):** (1) Procedural chunks have watertight joins and bounded generation time. (2) Camera speed and acceleration respect comfort limits. (3) Source switching does not reset EGL context. (4) Demo waveform produces stable and measurable scene response. (5) Long-duration travel avoids coordinate precision collapse.
- **Profiling:** Measure segment generation, buffer upload time, p95 frame time and long-session energy use; Prioritize smooth camera and feature updates over decorative particle count; Screen brightness/flash controls must override presets.
- **Risks:** Audio input limitations identical to Music Lab—make source UX transparent; Fast camera motion can cause nausea—provide static/low-motion mode; Streaming geometry may stall render thread—build on worker then safely upload at render boundary.
- **Phases:** P00 Foundation and VisualCore boundary audit; P01 Journey/camera comfort contract; P02 Streaming procedural tunnel; P03 Audio envelope mapping; P04 Multi-world presets and UI; P05 Long-session performance and accessiblity verification; P06 Final verification, privacy, packaging and release.
- **Source:** `docs/archive/planning/embedded/apps/07-audio-odyssey.md` (lines 1–647). Prompts: `python3 scripts/speckit_prompts.py --feature 053` … `--feature 059`, each with the override of `python3 scripts/planning_index.py prompt --feature A07-P00 --override`.

### A08 Oscilloscope Studio

`a08.oscilloscope-studio` · free · category audio · family Music and audio · legacy gates `A08-P00` … `A08-P06` (specs 060–066) · integration gate `X-A08`

A responsive and technically legible waveform, Lissajous and spectrum display for permitted audio inputs.

- **Primary capability:** waveform/timebase/trigger measurement. **Main validity risk:** units, clipping, latency, routing and calibration.
- **Capabilities:** Line rendering; Waveform buffers; Real-time data visualization; Shader effects; Multiple visualization modes. **For:** Musicians and audio enthusiasts; Makers exploring signals; Educators demonstrating time and frequency domains.
- **Journeys:** (1) Grant mic access or open local audio, select waveform mode. (2) Adjust gain, trigger level and timebase. (3) Switch to XY Lissajous or spectrogram-like display and freeze a frame.
- **Required features:** (1) Time-domain waveform with adjustable gain/timebase and selectable trigger. (2) Stereo XY/Lissajous view using available stereo input. (3) FFT spectrum mode with calibrated dB-style annotation where valid. (4) Freeze/capture, cursors and touch zoom. (5) Demo synthetic sine/square/sweep generator for tests. (6) Permission-aware audio input state and safe mic monitoring policy.
- **Non-goals:** Certified calibrated measurement instrument; Arbitrary system audio interception; Medical or lab-grade accuracy claims. **Later ideas (not in the first release):** CSV export of analyzed sample windows with consent; Advanced measurements such as THD with calibration caveats; Additional local supported audio inputs.
- **Domain types (proposed contracts):** `SignalWindow(sampleRate, channelCount, sampleCount, timestamp)`; `ScopeSettings(mode, triggerLevel, triggerSlope, timebase, gain, channelMode)`; `ScopeTrace(points, channelLabels, min, max)`; `SpectrumSettings(fftSize, windowFunction, referenceLevel)`.
- **Components named by the manual:** `AudioInput.swift` (audio acquisition or signal-feature mapping); `TriggerEngine.swift` (domain); `TimebaseModel.swift` (domain); `ScopeTraceBuilder.swift` (audio acquisition or signal-feature mapping); `SpectrumAnalyzer.swift` (audio acquisition or signal-feature mapping); `ScopeRenderer.swift` (renderer).
- **Algorithm decisions:** (1) Use ring-buffer snapshots with correct sample-rate accounting and trigger crossing detection. (2) Implement windowed FFT with bin-frequency mapping and correct log-domain zero guards. (3) Resample decimated display points to avoid drawing more geometry than pixels. (4) Separate real measured levels from relative/un-calibrated display values; annotate source limitations.
- **Render stages:** (1) Capture approved PCM samples. (2) Prepare triggered time window or spectral frame. (3) Convert samples into bounded line/strip vertex buffers. (4) Render grid, trace and labels in separate passes; handle freeze without stopping input unnecessarily.
- **Engineering rule:** Do not present apparent dB or voltage values as calibrated without a known input reference. Demo waveform is essential for simulator and CI tests.
- **Regression fixtures (acceptance):** (1) Known sine frequency maps to expected display periods and spectrum bin. (2) Trigger detection handles flatline and missing crossing. (3) Stereo XY view is disabled or clearly marked for mono sources. (4) No clipping or false precision in displayed units. (5) Freeze captures consistent sample metadata.
- **Profiling:** Separate acquisition sample rate from rendered frame rate; Use downsampling preserving min/max envelopes for high-frequency traces; Monitor ring-buffer overrun, input latency and frame-time jitter.
- **Risks:** Mic channels may be mono and routes change—negotiate actual format at runtime; Accurate line rendering can be expensive—decimate while preserving peaks; Terminology might imply calibrated hardware—provide explicit caveat.
- **Phases:** P00 Foundation and VisualCore boundary audit; P01 Audio fixture and acquisition interface; P02 Timebase/trigger waveform renderer; P03 Spectrum and XY modes; P04 Cursors, freeze and presets; P05 Device-route and accuracy audits; P06 Final verification, privacy, packaging and release.
- **Source:** `docs/archive/planning/embedded/apps/08-oscilloscope-studio.md` (lines 1–645). Prompts: `python3 scripts/speckit_prompts.py --feature 060` … `--feature 066`, each with the override of `python3 scripts/planning_index.py prompt --feature A08-P00 --override`.

### A09 Digital Aquarium

`a09.digital-aquarium` · free · category audio · family Music and audio · legacy gates `A09-P00` … `A09-P06` (specs 067–073) · integration gate `X-A09`

A calming, customizable underwater habitat with autonomous fish, plants, bubbles and soft lighting.

- **Primary capability:** real-time animated agents, ambient scene. **Main validity risk:** steady energy/memory and long-running performance.
- **Capabilities:** Sprite and object systems; Animation; Procedural environments; Particles; Scene management; Touch interaction. **For:** Families looking for a safe ambient experience; Casual collectors who customize habitats; Users wanting a passive beautiful display.
- **Journeys:** (1) Choose starter habitat and watch animated fish. (2) Tap to feed or gently attract fish. (3) Place a plant, adjust lighting and save the aquarium.
- **Required features:** (1) One complete aquarium with two fish species and plants. (2) Bounded 2D/2.5D school behaviors and swim animation. (3) Tap-to-feed and decoration placement gestures. (4) Bubbles, caustics, depth layers and environmental particles. (5) Persistent habitat configurations and safe restore. (6) Low-motion/low-power ambient mode with auto dimming.
- **Non-goals:** Realistic ecosystem or animal care simulator; Purchasable creature economy in MVP; Online multi-user aquarium. **Later ideas (not in the first release):** Audio-reactive lighting with legally permitted sources; Seasonal habitat packs; More complex social fish behavior.
- **Domain types (proposed contracts):** `AquariumDocument(id, version, waterColor, plants, fish, decor, lighting)`; `FishAgent(species, position, velocity, heading, behavior, animationPhase)`; `AquariumHabitat(bounds, obstacles, currentField, depthLayers)`; `FeedingEvent(position, timestamp, attractionRadius)`.
- **Components named by the manual:** `AquariumDocument.swift` (data storage); `FishBehaviorSystem.swift` (domain); `SpeciesCatalog.swift` (data storage); `HabitatEditor.swift` (domain); `AquariumScene.swift` (domain); `AquariumRenderer.swift` (renderer).
- **Algorithm decisions:** (1) Use bounded steering forces for separation, alignment and cohesion with a small neighbor search. (2) Fish orientation and fin animation follow velocity with smoothed heading. (3) Keep habitat edits deterministic and separately serialized from transient fish motion. (4) Reuse sprites/materials by species, batch draw calls and soft-mask water effects.
- **Render stages:** (1) Load habitat assets and document state. (2) Update fish agents and plant animations in fixed steps. (3) Render depth-ordered background, fauna, vegetation, bubbles and caustics. (4) Composite subtle color grade and present with quality scaling.
- **Engineering rule:** Use Digital Aquarium to validate VisualCore scenes, assets, particles and frame lifecycle as a second independent consumer after VisualCore Studio.
- **Regression fixtures (acceptance):** (1) Fish avoid leaving designated swim bounds. (2) Save/load preserves species, decor transforms and lighting. (3) Background/resume does not fast-forward fish simulation. (4) Asset catalog rejects missing/unsupported resources gracefully. (5) Long-running scene keeps fish count, particle count and GPU memory bounded.
- **Profiling:** Target long-session thermal stability, not merely peak FPS; Allow user-defined quality and low-power sleep behavior; Measure batching efficiency, persistent memory and frame pacing after 15-minute ambient sessions.
- **Risks:** Asset provenance and third-party artwork licensing are central—ship only owned/licensed media; Too many independent sprites cause draw overhead—batch or atlas; AI-generated motion can look erratic—use capped forces and animation smoothing.
- **Phases:** P00 Foundation and VisualCore boundary audit; P01 Habitat model and content license audit; P02 Fish movement and visual prototype; P03 Editing, feeding and save system; P04 Lighting, particles and accessibility; P05 Ambient device testing and release content; P06 Final verification, privacy, packaging and release.
- **Source:** `docs/archive/planning/embedded/apps/09-digital-aquarium.md` (lines 1–649). Prompts: `python3 scripts/speckit_prompts.py --feature 067` … `--feature 073`, each with the override of `python3 scripts/planning_index.py prompt --feature A09-P00 --override`.

### A10 Neon Arcade

`a10.neon-arcade` · free · category play · family Games and interactive experiences · legacy gates `A10-P00` … `A10-P06` (specs 074–080) · integration gate `X-A10`

A compact collection of highly legible arcade games with glow, particles and disciplined game logic.

- **Primary capability:** arcade input, fixed-step logic, score persistence. **Main validity risk:** device input latency, deterministic replay.
- **Capabilities:** 2D rendering; Particles; Animation; Input handling; Collision visualization; Scene transitions. **For:** Casual mobile players; Kids and families looking for simple controls; Developers evaluating VisualCore for game loops.
- **Journeys:** (1) Launch a polished one-thumb dodge game, learn rules in five seconds. (2) Survive timed waves, get feedback on collision and score. (3) Restart instantly, unlock alternative visual palettes and track local high score.
- **Required features:** (1) One complete game first: Neon Dodge with player lane, falling hazards and collectible orbs. (2) Deterministic fixed-step update loop and authoritative collision rules. (3) Start/pause/restart/game-over flows with local scores. (4) Touch steering with configurable sensitivity. (5) Particles, glow and visual feedback constrained by game readability. (6) Sound/haptic toggles and reduced-flash controls.
- **Non-goals:** An entire arcade collection before first release; Unmoderated online leaderboards or user-generated levels; Monetized loot boxes. **Later ideas (not in the first release):** Second game with a separate rules engine and shared renderer; On-device achievements; Signed replay exchange.
- **Domain types (proposed contracts):** `GameRun(seed, elapsedTicks, score, lives, paused, waveIndex)`; `PlayerState(position, velocity, hitbox, invulnerabilityTicks)`; `SpawnWave(patternID, spawnTick, hazardDefinitions)`; `HighScore(boardVersion, score, achievedAt)`.
- **Components named by the manual:** `GameRun.swift` (domain); `FixedStepClock.swift` (domain); `CollisionSolver.swift` (domain); `WaveDirector.swift` (domain); `HighScoreStore.swift` (data storage); `NeonDodgeRenderer.swift` (renderer).
- **Algorithm decisions:** (1) Advance game world with fixed delta tick independent of display frame rate. (2) Use continuous or swept collision for fast moving hazards to prevent tunneling. (3) Separate collision geometry from sprites and post-effects. (4) Serialize deterministic input events for test replays; render may interpolate but never decides hit outcomes.
- **Render stages:** (1) Process touch input into intent vector. (2) Run input and wave spawning on fixed-step simulation. (3) Resolve collision/scoring on CPU domain model. (4) Render layered sprites, hazards, additive glow and feedback particles through VisualCore.
- **Engineering rule:** Keep graphics effects a VisualCore client, not the authoritative game simulation. Visual readability is a functional acceptance criterion.
- **Regression fixtures (acceptance):** (1) Recorded input replay produces identical score and collision ticks. (2) Background/resume freezes simulation rather than catching up. (3) Swept collision catches high-speed hazards. (4) High score is not corrupted by abrupt termination. (5) Hitboxes remain readable when bloom quality settings change.
- **Profiling:** Prioritize predictable input-to-action latency and p95 frame time; Measure overdraw and avoid full-screen expensive bloom on low tiers; Run 30 and 60 Hz timing tests for equivalent simulation outcomes.
- **Risks:** Effects that obscure obstacles hurt playability—cap bloom and preserve contrast; Frame-rate-dependent game logic causes inconsistent difficulty—fixed timestep; Additional games multiply maintenance—ship one vertical slice and validate retention.
- **Phases:** P00 Foundation and VisualCore boundary audit; P01 Fixed-step engine and collision fixtures; P02 Neon Dodge complete mechanics; P03 Visual effects and audio/haptics; P04 Scores and accessibility; P05 Balance, device QA and storefront; P06 Final verification, privacy, packaging and release.
- **Source:** `docs/archive/planning/embedded/apps/10-neon-arcade.md` (lines 1–647). Prompts: `python3 scripts/speckit_prompts.py --feature 074` … `--feature 080`, each with the override of `python3 scripts/planning_index.py prompt --feature A10-P00 --override`.

### A11 Physics Playground

`a11.physics-playground` · free · category play · family Games and interactive experiences · legacy gates `A11-P00` … `A11-P06` (specs 081–087) · integration gate `X-A11`

A deterministic sandbox for gravity, collisions, springs and forces with explanatory overlays.

- **Primary capability:** rigid-body/world simulation and interaction. **Main validity risk:** contacts, conservation/energy drift, collision validity.
- **Capabilities:** Scene rendering; Geometry; Animation; Shader-based effects; Data visualization. **For:** Children experimenting with motion; Teachers giving live demonstrations; Physics enthusiasts seeking an approachable simulation toy.
- **Journeys:** (1) Drop objects into a stage and start gravity. (2) Draw a spring between objects and alter stiffness. (3) Pause, single-step, inspect energy and reset from a preset.
- **Required features:** (1) 2D circles and boxes with rigid-body collision. (2) Constant gravity, springs and drag forces. (3) Object spawn, grab, pin and delete gestures. (4) Simulation pause/single step, time scale and reset. (5) Presets for pendulum, spring chain and stacked objects. (6) Optional velocity/force vector overlays and measured state panel.
- **Non-goals:** Physically complete engineering simulation; Real 3D soft bodies or fluid solver; Safety-critical prediction claims. **Later ideas (not in the first release):** Inclined planes, rotational motors and magnets; Data-plot export and classroom activities; More sophisticated 3D constraints.
- **Domain types (proposed contracts):** `PhysicsBody(id, shape, mass, inertia, pose, velocity, restitution, friction)`; `SpringConstraint(bodyA, bodyB, restLength, stiffness, damping)`; `WorldSettings(gravity, fixedTimeStep, solverIterations, boundary)`; `ExperimentDocument(schemaVersion, bodies, constraints, settings)`.
- **Components named by the manual:** `PhysicsWorld.swift` (domain); `RigidBody.swift` (domain); `CollisionDetection.swift` (domain); `ContactSolver.swift` (domain); `SpringConstraint.swift` (domain); `ExperimentStore.swift` (data storage); `PhysicsRenderer.swift` (renderer).
- **Algorithm decisions:** (1) Start with a fixed-step CPU 2D solver and broadphase for a small object count. (2) Use impulse-based collision with restitution/friction and conservative positional correction. (3) Apply spring forces with stability guardrails and bounded stiffness for chosen dt. (4) Compute diagnostics separately; explicitly label results as educational approximations.
- **Render stages:** (1) Collect editor operations. (2) Advance force accumulator, broadphase and narrowphase collision. (3) Solve constraints and integrate poses at bounded fixed time step. (4) Upload transforms and draw rigid bodies, vector arrows and contact effects.
- **Engineering rule:** Do not offload simulation into a shader merely because VisualCore offers GPUs; choose CPU deterministic baseline and use VisualCore strictly for visualization.
- **Regression fixtures (acceptance):** (1) Two-body elastic collision approximates expected momentum within solver tolerance. (2) Resting stack remains bounded over long runs. (3) Mass zero is treated as static and never divided by zero. (4) Spring energy test has known bounded behavior. (5) Identical initial state and event stream reproduce deterministic CPU results.
- **Profiling:** Measure CPU solver time separately from GPU draw time; Maintain maximum active-body budget and optional sleep detection; Reduced-quality mode lowers draw complexity without changing simulation laws.
- **Risks:** Numerical instability from large dt or stiff springs—fixed substeps and parameter caps; Users may assume engineering accuracy—document educational model and units; Object count may grow without limit—enforce scene budget.
- **Phases:** P00 Foundation and VisualCore boundary audit; P01 Physics model/units and deterministic tests; P02 Contacts and spring solver; P03 Gesture editor and overlays; P04 Saved experiments and tutorials; P05 Numerical stability/performance audit; P06 Final verification, privacy, packaging and release.
- **Source:** `docs/archive/planning/embedded/apps/11-physics-playground.md` (lines 1–646). Prompts: `python3 scripts/speckit_prompts.py --feature 081` … `--feature 087`, each with the override of `python3 scripts/planning_index.py prompt --feature A11-P00 --override`.

### A12 Tiny Worlds

`a12.tiny-worlds` · free · category play · family Games and interactive experiences · legacy gates `A12-P00` … `A12-P06` (specs 088–094) · integration gate `X-A12`

A curated gallery of miniature procedural environments with orbit navigation and gentle customization.

- **Primary capability:** procedural worlds, 3D scene camera/assets. **Main validity risk:** content bounds, memory, camera/navigation correctness.
- **Capabilities:** 3D scenes; Camera and navigation; Procedural meshes; Lighting; Materials and assets. **For:** Players who enjoy miniature dioramas; Creators arranging small worlds; Users seeking low-pressure exploration.
- **Journeys:** (1) Open a tiny island with animated scenery. (2) Orbit and zoom camera to explore. (3) Change terrain seed, place one prop and save the world.
- **Required features:** (1) Three small world presets: island, asteroid garden and miniature city. (2) Orbit camera with constrained zoom and comfortable control. (3) Seeded terrain/mesh generation with stable boundaries. (4) Prop placement and scene light adjustment. (5) Saved world composition and thumbnails. (6) Dynamic detail tier based on GPU/memory budget.
- **Non-goals:** Infinite terrain or open-world streaming; Multiplayer world creation; Photorealistic GI and full physics gameplay. **Later ideas (not in the first release):** Interactive citizens and ambient ecology; World-to-world transitions; Sharing signed deterministic world seeds.
- **Domain types (proposed contracts):** `TinyWorld(seed, biomeID, terrainParams, props, lighting, schemaVersion)`; `TerrainChunk(coord, meshLOD, assetVersion)`; `WorldProp(assetID, transform, variationSeed)`; `CameraRig(orbitYaw, pitch, distance, focus)`.
- **Components named by the manual:** `TinyWorldDocument.swift` (data storage); `TerrainGenerator.swift` (domain); `MeshLODBuilder.swift` (domain); `PropCatalog.swift` (data storage); `WorldEditor.swift` (domain); `OrbitCamera.swift` (domain); `TinyWorldRenderer.swift` (renderer).
- **Algorithm decisions:** (1) Use deterministic height/shape noise with reproducible seed and edge-consistent normal generation. (2) Generate bounded geometry at load/edit time, not every frame. (3) Separate visual meshes from coarse selection/picking geometry. (4) Maintain near/far and world unit conventions and avoid camera penetration.
- **Render stages:** (1) Load world descriptor and seed. (2) Generate or retrieve terrain meshes, instance props and configure lighting. (3) Render geometry depth/opaque then particles/atmosphere. (4) Apply color grading and UI overlays before presentation.
- **Engineering rule:** Tiny Worlds is the strongest reason to evaluate VisualCore 3D scenes and assets after an audited graphics feature baseline exists.
- **Regression fixtures (acceptance):** (1) Same seed and settings yield identical mesh hashes in reference generator. (2) All LOD indices remain in bounds. (3) Placed props persist at exact transforms. (4) Orbit camera respects limits, no clipping through terrain. (5) World load/unload cycles do not retain stale GPU objects.
- **Profiling:** Profile scene load, mesh generation time, draw count, overdraw and peak memory; Limit visible chunks, use baked/simple lighting on low tiers; Keep camera responsive during geometry rebuilds.
- **Risks:** Procedural meshes may spike startup—async generation and loading indicator; Asset size can dominate app download—use atlases and instancing; World editing conflicts with generation—commit snapshots atomically.
- **Phases:** P00 Foundation and VisualCore boundary audit; P01 Procedural seed and mesh fixtures; P02 Camera/scene renderer; P03 World customization and persistence; P04 Three environment packs; P05 Memory/thermal and content QA; P06 Final verification, privacy, packaging and release.
- **Source:** `docs/archive/planning/embedded/apps/12-tiny-worlds.md` (lines 1–646). Prompts: `python3 scripts/speckit_prompts.py --feature 088` … `--feature 094`, each with the override of `python3 scripts/planning_index.py prompt --feature A12-P00 --override`.

### A13 Light Maze

`a13.light-maze` · free · category play · family Games and interactive experiences · legacy gates `A13-P00` … `A13-P06` (specs 095–101) · integration gate `X-A13`

A precise, tactile light-reflection puzzle game with visually rich beams and deterministic rules.

- **Primary capability:** puzzle rays, reflection, deterministic solutions. **Main validity risk:** ray intersection/snap rules and level solver.
- **Capabilities:** Render targets; Shaders; Geometry and transformations; Touch controls; Compositing and visual feedback. **For:** Puzzle fans; Children learning reflection geometry; Players wanting short, meaningful sessions.
- **Journeys:** (1) Rotate a mirror to redirect a beam into target sensor. (2) Complete three introductory levels. (3) Restart or request hint, then progress through a small curated set.
- **Required features:** (1) At least 20 handcrafted levels with emitter, wall, mirror, target and optional prism tile. (2) Drag/rotate interactions snapped to puzzle grid. (3) Deterministic ray propagation with reflection and finite bounce cap. (4) Level select, unlock progression, undo/restart and success feedback. (5) Visual glow and color cues without hiding beam connectivity. (6) Built-in solvability test for level data.
- **Non-goals:** Photorealistic optics with refraction physics; Unvalidated user-generated level sharing; Endless procedural level generation. **Later ideas (not in the first release):** Additional beam colors, splitters and portals; Level editor and local puzzle packs; Optional puzzle replay sharing.
- **Domain types (proposed contracts):** `PuzzleGrid(width, height, cellSize, tiles, schemaVersion)`; `OpticalElement(type, cell, orientation, wavelengthMode, active)`; `BeamSegment(start, end, colorChannel, sourceID, bounceIndex)`; `PuzzleProgress(levelID, completed, bestMoves)`.
- **Components named by the manual:** `PuzzleGrid.swift` (domain); `RayTracer2D.swift` (domain); `OpticalRules.swift` (domain); `LevelValidator.swift` (domain); `ProgressStore.swift` (data storage); `LightMazeRenderer.swift` (renderer).
- **Algorithm decisions:** (1) Compute ray/segment intersection on CPU from exact grid geometry; treat shader beam rendering as presentation only. (2) Avoid self-intersection with explicit epsilon and last-hit tracking; cap bounces and detect cycles. (3) Propagate color channels through splitters only when authored in rules; start with monochrome in Phase 1. (4) Use solver/replay tests to verify solutions and guard against unintended shortcuts.
- **Render stages:** (1) Apply user mirror edit to immutable grid snapshot. (2) Recompute beam tree and sensor states on CPU. (3) Generate glowing beam quads from exact segments, render mirrors, walls and targets. (4) Animate solved feedback without changing logical results.
- **Engineering rule:** Formal puzzle rules and level validation matter more than animation features. A shader must never decide if the puzzle is solved.
- **Regression fixtures (acceptance):** (1) Incidence angle equals reflection angle within tolerance. (2) Repeating mirror loops end at bounded bounce budget. (3) All shipping levels have at least one verified solution. (4) Undo restores exact previous grid and beam state. (5) Beam visual endpoints match ray solver coordinates.
- **Profiling:** Low scene complexity; optimize latency and deterministic state changes rather than throughput; Keep bloom capped so color-coded logic stays legible; Use battery-friendly idle rendering when puzzle state is unchanged.
- **Risks:** Visual beams can diverge from logical paths—single source of truth in CPU tracer; Puzzle content is expensive to design—ship small validated set; Touch rotation imprecision—snap to grid and provide large tap targets.
- **Phases:** P00 Foundation and VisualCore boundary audit; P01 Grid/ray reflection solver and fixtures; P02 Rendering and tap interactions; P03 Core levels and progress; P04 Hints/accessibility/visual polish; P05 Content solvability and release QA; P06 Final verification, privacy, packaging and release.
- **Source:** `docs/archive/planning/embedded/apps/13-light-maze.md` (lines 1–645). Prompts: `python3 scripts/speckit_prompts.py --feature 095` … `--feature 101`, each with the override of `python3 scripts/planning_index.py prompt --feature A13-P00 --override`.

### A14 Solar System Explorer

`a14.solar-system-explorer` · free · category learn · family Education and science · legacy gates `A14-P00` … `A14-P06` (specs 102–108) · integration gate `X-A14`

An educational solar system viewer that cleanly distinguishes astronomical scale, time simulation and artistically exaggerated displays.

- **Primary capability:** orbital/data-driven 3D visualization. **Main validity risk:** unit/time accuracy and source citations.
- **Capabilities:** 3D scenes; Camera controls; Materials and lighting; Animation; Time-based simulation. **For:** Students learning planetary order and relative motion; Families exploring space together; Astronomy hobbyists seeking a visually compelling primer.
- **Journeys:** (1) Open orbit overview with labeled planets. (2) Select planet to inspect a fact card and orbit. (3) Change simulation date/rate, reset to present and take guided tour.
- **Required features:** (1) Sun and eight major planets with curated fact cards and licensed textures. (2) Orbit view, planet focus and camera navigation. (3) Play/pause/speed up simulated motion with explicit date/time display. (4) Separate true-relative and visibility-enhanced size/distance modes. (5) Guided tours with narration-free captions. (6) References and units displayed on educational claims.
- **Non-goals:** NASA-grade ephemeris or high precision live sky position; Real-time telescope alignment; Unlicensed imagery/data scraping. **Later ideas (not in the first release):** Additional dwarf planets and moons; Source-specific ephemeris datasets with validation; Educational quizzes and AR exploration.
- **Domain types (proposed contracts):** `CelestialBody(id, meanRadiusKm, semiMajorAxisAU, periodDays, axialTiltDeg, textureID, sourceRef)`; `OrbitElements(modelVersion, epochUTC, parameters, validityRange)`; `SolarView(camera, simulationUTC, timeRate, scaleMode, selectedBody)`; `FactCard(bodyID, fact, value, units, citation)`.
- **Components named by the manual:** `CelestialBodyCatalog.swift` (data storage); `OrbitCalculator.swift` (domain); `UnitConversion.swift` (domain); `SolarClock.swift` (domain); `PlanetFocusController.swift` (domain); `SolarRenderer.swift` (renderer).
- **Algorithm decisions:** (1) Start with labeled approximate Kepler or simplified analytic orbits, not precision ephemerides. (2) Keep double-precision orbital state on CPU and convert camera-relative positions for GPU. (3) Make AU/km conversions explicit and separate physical radii from visual display scale. (4) Label timestamps and time zones; clock speed cannot imply predictive precision beyond model scope.
- **Render stages:** (1) Advance simulation time and compute orbit positions in double precision. (2) Produce camera-relative model transforms and LOD choices. (3) Render star background, Sun, planets, orbit trails and labels. (4) Show educational card overlays and scale mode legend.
- **Engineering rule:** Scientific model is educational approximation; preserve traceable sources for facts, imagery and data and distinguish real versus illustrative scales.
- **Regression fixtures (acceptance):** (1) Known approximate orbital periods and radii match stored catalog within tolerances. (2) AU to km conversion and simulated date changes remain consistent. (3) Scale-mode label updates accurately and visibly. (4) Body focus and camera transitions do not cross near clip unpredictably. (5) All displayed facts reference a bundled reviewed source.
- **Profiling:** Choose physically honest mode with LOD and educational visibility mode with recorded choices; Prefer static starfield and bounded orbit geometry to heavy postprocessing; Test long timescales for numerical issues and UI date overflow.
- **Risks:** False precision and scientific inaccuracies—label approximate model and source epoch; Real scales render planets invisible—provide explicit exaggeration mode; NASA imagery usage requires license/credit verification, not blanket assumptions.
- **Phases:** P00 Foundation and VisualCore boundary audit; P01 Scientific catalog/units and citation audit; P02 Approximate orbit computation with fixtures; P03 Camera and 3D body rendering; P04 Time controls/guided tours; P05 Scientific review and device QA; P06 Final verification, privacy, packaging and release.
- **Source:** `docs/archive/planning/embedded/apps/14-solar-system-explorer.md` (lines 1–645). Prompts: `python3 scripts/speckit_prompts.py --feature 102` … `--feature 108`, each with the override of `python3 scripts/planning_index.py prompt --feature A14-P00 --override`.

### A15 Molecular Explorer

`a15.molecular-explorer` · free · category learn · family Education and science · legacy gates `A15-P00` … `A15-P06` (specs 109–115) · integration gate `X-A15`

An approachable 3D molecule viewer with clear atom/bond styling and constrained structured-data import.

- **Primary capability:** molecule dataset parser and 3D picking. **Main validity risk:** scientific dataset licensing/validation, bonds/units.
- **Capabilities:** Instanced geometry; Materials; Camera controls; Lighting; Structured scientific data visualization. **For:** Chemistry students; Teachers explaining molecular shape; Hobbyists exploring small molecules and structures.
- **Journeys:** (1) Open curated water, caffeine and ethanol models. (2) Rotate/zoom, select an atom and view element metadata. (3) Change ball-and-stick vs space-filling display, optionally import validated XYZ file.
- **Required features:** (1) Shipping curated small-molecule library with source attributions. (2) Ball-and-stick and space-filling rendering modes. (3) Touch orbit, pan, zoom and atom picking. (4) Element labels, bond types and metadata panel. (5) Small XYZ file import with strict bounds and parser errors. (6) Local recent molecules and visual settings.
- **Non-goals:** Complete medicinal chemistry or predictive molecular dynamics; Trusting arbitrary PDB/complex input without validation; Chemical safety or therapeutic claims. **Later ideas (not in the first release):** Validated PDB subset and crystal unit cells; Measurement tools for bond angles/distances; Molecular animation with scientifically sourced data.
- **Domain types (proposed contracts):** `Atom(id, atomicNumber, elementSymbol, positionAngstrom, chargeOptional)`; `Bond(atomA, atomB, order, sourceInferred)`; `Molecule(id, title, atoms, bonds, source, formatVersion)`; `ViewerSettings(style, atomScale, bondRadius, labelMode, camera)`.
- **Components named by the manual:** `XYZParser.swift` (data storage); `ElementCatalog.swift` (data storage); `Molecule.swift` (domain); `BondInference.swift` (domain); `AtomPicker.swift` (domain); `MolecularRenderer.swift` (renderer).
- **Algorithm decisions:** (1) Parse XYZ with limits on atoms, lines and UTF-8 length; explicit unit and format validation. (2) If bond connectivity is inferred from distances, label it as an estimate and apply element-specific conservative thresholds. (3) Use atom/bond instancing or batching where GL ES support permits. (4) Pick via CPU ray-to-sphere tests for MVP; persist normalized camera transform independently from molecule data.
- **Render stages:** (1) Load trusted bundled or validated XYZ molecule. (2) Normalize center/scale and derive visual atom/bond representations. (3) Render instanced spheres, cylinders and labels with depth. (4) Read back no GPU data by default; apply selection highlight based on CPU picking.
- **Engineering rule:** Use verified element data; do not market inferred bond connectivity as a guaranteed chemical structure.
- **Regression fixtures (acceptance):** (1) XYZ parser rejects negative atom counts, NaNs and oversized files. (2) Built-in water and ethanol coordinate tests produce expected atom count. (3) Atom selection is correct for camera transforms and occlusion policy. (4) Bond inference is deterministic and marked inferred. (5) Model switch and orientation restore do not leak buffers.
- **Profiling:** Cap atoms/bonds and draw calls by device tier; fail clearly before OOM; Normalize geometry to avoid precision loss; Use quality tiers for tessellation while keeping selection and labels legible.
- **Risks:** Untrusted molecule files may exhaust memory—strict parsers and size caps; Inferred bonds can be scientifically wrong—metadata labels and explicit-source preference; Fine labels create accessibility barriers—include textual element lists and focus navigation.
- **Phases:** P00 Foundation and VisualCore boundary audit; P01 Atom/bond domain and strict XYZ parser; P02 Camera/atom/bond renderer; P03 Selection and display styles; P04 Curated molecule content and persistence; P05 Import fuzz/error and scientific review; P06 Final verification, privacy, packaging and release.
- **Source:** `docs/archive/planning/embedded/apps/15-molecular-explorer.md` (lines 1–645). Prompts: `python3 scripts/speckit_prompts.py --feature 109` … `--feature 115`, each with the override of `python3 scripts/planning_index.py prompt --feature A15-P00 --override`.

### A16 Simulation Lab

`a16.simulation-lab` · free · category learn · family Education and science · legacy gates `A16-P00` … `A16-P06` (specs 116–122) · integration gate `X-A16`

A gallery of inspectable GPU simulations with parameter panels and explicit numerical/educational limitations.

- **Primary capability:** numerical simulation presets, graphs. **Main validity risk:** convergence, step control, invalid-state safeguards.
- **Capabilities:** GPU simulation techniques using shaders and framebuffer feedback; Numerical visualization; Parameter controls; Data visualization; Animation and capture. **For:** STEM hobbyists; Educators demonstrating patterns and dynamics; Visual artists discovering reaction-diffusion forms.
- **Journeys:** (1) Pick cellular automaton preset and tap to seed it. (2) Switch to Gray-Scott reaction-diffusion and edit feed/kill values. (3) Pause, single-step and compare two parameter presets.
- **Required features:** (1) Three simulation families: cellular automata, reaction-diffusion and 2D wave field. (2) Clear parameter schema per experiment and seeded starting conditions. (3) Pause, reset, step, speed and histogram/legend overlay. (4) Deterministic tiny CPU reference for each algorithm. (5) GPU ping-pong texture path with explicit boundary rules. (6) Save presets and capture stills.
- **Non-goals:** Numerically certified scientific solver; Large high-precision computation clusters; Simultaneous multiuser experiments. **Later ideas (not in the first release):** Procedural growth and advanced particle simulations; Parameter sweeps and comparison panels; Exported numerical grids with format/version metadata.
- **Domain types (proposed contracts):** `SimulationSpec(kind, gridSize, timeStep, boundaryMode, seed, parameterMap, algorithmVersion)`; `SimulationState(readTexture, writeTexture, stepIndex, captureMetadata)`; `ParameterDefinition(id, type, bounds, units, description)`; `ExperimentPreset(spec, paletteID, annotation)`.
- **Components named by the manual:** `SimulationSpec.swift` (domain); `SimulationScheduler.swift` (domain); `CellularAutomatonCPU.swift` (domain); `GrayScottCPU.swift` (domain); `WaveFieldCPU.swift` (domain); `GPUSimulationRunner.swift` (renderer).
- **Algorithm decisions:** (1) For cellular automata define precise neighborhood/rule and boundary mode. (2) For Gray-Scott define discrete Laplacian stencil, diffusion constants, feed/kill, step size and explicit stability bounds. (3) For wave equation use bounded numerical scheme with discrete Courant condition. (4) Reference CPU grids must be compared to GPU output within declared tolerance and rounding differences.
- **Render stages:** (1) Validate model spec and allocate ping-pong targets. (2) Initialize seeded fields and run N capped steps per display frame. (3) Swap states only after complete passes. (4) Render scalar field through scientific palette and optional isoline/legend overlay.
- **Engineering rule:** This app must validate actual framebuffer feedback and numerical behavior of VisualCore without implying that a successful visual result establishes scientific accuracy.
- **Regression fixtures (acceptance):** (1) Life blinker oscillator has known two-step period. (2) Gray-Scott tiny-grid GPU vs CPU error stays inside documented tolerance. (3) Invalid time steps rejected or clamped with visible explanation. (4) Pause and one-step advance exactly one discrete iteration. (5) Size change reallocates targets without carrying corrupted state.
- **Profiling:** Separate simulation steps/second from display FPS and cap steps per frame; Monitor GPU memory and solver pass count; Support lower simulation resolution while preserving parameter meaning and consistent legends.
- **Risks:** Numeric outcomes depend on precision/filtering—document format and pass semantics; Incorrect shader read/write feedback can produce undefined behavior—assert resource separation; Scientific visuals may look authoritative—make educational approximation labeling obvious.
- **Phases:** P00 Foundation and VisualCore boundary audit; P01 Algorithm specifications and CPU fixtures; P02 Cellular automata GPU parity; P03 Reaction-diffusion/wave algorithms; P04 Experiment UI, presets and capture; P05 Numerical/device validation and release; P06 Final verification, privacy, packaging and release.
- **Source:** `docs/archive/planning/embedded/apps/16-simulation-lab.md` (lines 1–648). Prompts: `python3 scripts/speckit_prompts.py --feature 116` … `--feature 122`, each with the override of `python3 scripts/planning_index.py prompt --feature A16-P00 --override`.

### A17 Interactive Anatomy

`a17.interactive-anatomy` · free · category learn · family Education and science · legacy gates `A17-P00` … `A17-P06` (specs 123–129) · integration gate `X-A17`

A labeled, layer-controlled 3D anatomy reference with trustworthy licensed models and plain-language descriptions.

- **Primary capability:** interactive educational anatomy. **Main validity risk:** medical accuracy, licensed models and no diagnosis claims.
- **Capabilities:** 3D model rendering; Textures and materials; Camera controls; Lighting; Labels and overlays. **For:** Students learning gross anatomy; Educators presenting anatomical structures; General learners exploring body systems.
- **Journeys:** (1) Open whole-body overview and select a system layer. (2) Rotate a model and tap an anatomical structure. (3) Read its description, toggle a nearby layer and search another structure.
- **Required features:** (1) One clinically reviewed anatomy region rather than full body at MVP. (2) Toggleable layered mesh groups and accessible structure list. (3) Selection highlighting, labels and searchable metadata. (4) Camera orbit/zoom and isolation/ghost controls. (5) Reviewed factual text with citations and content provenance. (6) Download-free offline content pack for initial region.
- **Non-goals:** Diagnostic advice or treatment recommendation; Full-body atlas without content/licensing review; User-uploaded patient medical files. **Later ideas (not in the first release):** More anatomical regions with independent licensing; Quizzes and guided lessons; AR visualization where device support warrants.
- **Domain types (proposed contracts):** `AnatomicalStructure(id, standardName, synonyms, layer, meshIDs, description, sourceRefs)`; `AnatomyRegion(id, systems, coordinateConvention, boundingVolume, assetVersion)`; `AnatomyView(selectedID, visibleLayers, isolationMode, camera)`; `ContentManifest(assetLicense, clinicalReviewer, reviewDate, citations)`.
- **Components named by the manual:** `AnatomyCatalog.swift` (data storage); `StructureSearch.swift` (domain); `LayerVisibility.swift` (domain); `PickingIndex.swift` (domain); `AnatomyScene.swift` (domain); `AnatomyRenderer.swift` (renderer).
- **Algorithm decisions:** (1) Create hierarchy allowing efficient visibility toggles, hit-test selection, and consistent parent transforms. (2) Use mesh grouping, per-structure identifiers and coarse CPU pick proxies. (3) Apply transparent ghosting only with correct draw order/depth policy; keep labels accessible in native UI. (4) All anatomical descriptions are reviewed editorial data; do not derive clinical statements from raw geometry.
- **Render stages:** (1) Load region manifest and licensed mesh assets. (2) Compute visible/selected structure set and GPU material assignments. (3) Render opaque structures, ghosted layers and highlight pass. (4) Present native overlay labels, search and descriptions.
- **Engineering rule:** Treat anatomy model and descriptions as educational reference, not medical guidance. Track explicit content review and licensing evidence.
- **Regression fixtures (acceptance):** (1) Every displayed label maps to an existing mesh/structure ID. (2) Toggling layers never makes hidden structures selectable. (3) Search synonyms resolve to the intended structure. (4) Asset provenance records license and review status. (5) VoiceOver structure list works without relying on 3D touch picking.
- **Profiling:** Load only necessary meshes and reuse materials; Measure memory peak on older iPads and during repeated layer changes; Offer lower LOD without suppressing clinically important labels.
- **Risks:** Medical data mistakes can misinform—review sources and explicitly mark educational use; High-poly purchased assets may have incompatible redistribution rights—audit before coding; 3D labels can overlap—provide searchable native alternative.
- **Phases:** P00 Foundation and VisualCore boundary audit; P01 Licensed content inventory and schema; P02 Region scene/selection renderer; P03 Layers, search and descriptions; P04 Accessibility and offline content; P05 Scientific review and device QA; P06 Final verification, privacy, packaging and release.
- **Source:** `docs/archive/planning/embedded/apps/17-interactive-anatomy.md` (lines 1–645). Prompts: `python3 scripts/speckit_prompts.py --feature 123` … `--feature 129`, each with the override of `python3 scripts/planning_index.py prompt --feature A17-P00 --override`.

### A18 Ambient Clock

`a18.ambient-clock` · free · category ambient · family Ambient and lifestyle · legacy gates `A18-P00` … `A18-P06` (specs 130–136) · integration gate `X-A18`

An elegant, low-power clock that pairs accurate local timekeeping with responsive procedural backgrounds.

- **Primary capability:** ambient timed scene with native clock behavior. **Main validity risk:** OS time-zone/DST and battery use.
- **Capabilities:** Shader backgrounds; Animation; Typography integration; Scene transitions; Configuration and presets. **For:** People wanting a bedside or desk clock; Users who enjoy customizable ambient displays; Accessibility-focused users needing clear large typography.
- **Journeys:** (1) Pick clock layout and procedural theme. (2) Adjust contrast, 12/24-hour mode and seconds display. (3) Place device on stand and watch clock remain accurate over time changes.
- **Required features:** (1) Accurate locale-aware time/date using system calendar and time zone. (2) Four procedural visual themes with quality and motion controls. (3) Readable 12/24-hour typography and optional seconds. (4) Theme editor with saveable favorites. (5) Brightness-friendly night mode and motion-reduction option. (6) Foreground resume/time-zone/DST update handling.
- **Non-goals:** Permanent screen-on guarantees regardless of OS policy; Background rendering while iOS suspends the app; Unverified weather forecast integration. **Later ideas (not in the first release):** Weather-inspired themes using user-supplied location/consented data; Complication-like information cards inside app; Theme sharing.
- **Domain types (proposed contracts):** `ClockPreferences(timeFormat, showSeconds, calendarID, timeZonePolicy, localePolicy)`; `ThemePreset(shaderID, palette, speed, contrast, quality)`; `ClockState(nowInstant, displayComponents, nextTickDeadline, appearance)`; `AmbientPolicy(dimLevel, motionReduced, disableIdleTimerWhileActive)`.
- **Components named by the manual:** `ClockPreferences.swift` (domain); `ClockCalendarFormatter.swift` (domain); `TimeChangeObserver.swift` (domain); `ThemeStore.swift` (data storage); `AmbientSceneRenderer.swift` (renderer); `NightModeController.swift` (domain).
- **Algorithm decisions:** (1) Use Date/Calendar/Locale/TimeZone for actual clock semantics; schedule UI updates based on next appropriate second/minute boundaries. (2) Treat foreground transitions, significant-time changes and system time-zone changes as invalidation triggers. (3) Keep typography in accessible native UI over VisualCore background so clock remains readable when rendering pauses. (4) Handle always-on/idle timer only according to supported platform policies and user settings.
- **Render stages:** (1) Acquire system time and display preferences. (2) Render ambient shader scene at adaptive frame cadence. (3) Overlay text from native time model and label widgets. (4) Stop/reduce work when not visible and restore exact time after foreground.
- **Engineering rule:** The time label must remain correct even if shader rendering is unavailable; do not conflate display animation time with wall clock.
- **Regression fixtures (acceptance):** (1) DST transition and 12/24-hour formatting tests use fixed calendar fixtures. (2) Timezone change invalidates displayed components correctly. (3) Theme colors pass contrast review for primary time text. (4) App resume does not show old time while GPU refreshes. (5) Frame scheduling lowers work for static background/seconds disabled.
- **Profiling:** Prioritize battery and readability over continuous 60 fps; Dynamic frame cadence and night low-power tier; Validate prolonged plugged-in/unplugged sessions and screen visibility.
- **Risks:** Thermal and OLED burn-in concerns—subtle pixel drift/dimming and idle policy; Time correctness errors break trust—use system time, no simulated clock in production; Weather implies permissions/data terms—keep out of MVP unless source selected.
- **Phases:** P00 Foundation and VisualCore boundary audit; P01 Clock/timezone correctness and accessibility; P02 Native clock overlay and one shader theme; P03 Theme customization and persistence; P04 Power/visibility controls; P05 Overnight device tests and App Store QA; P06 Final verification, privacy, packaging and release.
- **Source:** `docs/archive/planning/embedded/apps/18-ambient-clock.md` (lines 1–647). Prompts: `python3 scripts/speckit_prompts.py --feature 130` … `--feature 136`, each with the override of `python3 scripts/planning_index.py prompt --feature A18-P00 --override`.

### A19 Living Wallpapers

`a19.living-wallpapers` · free · category ambient · family Ambient and lifestyle · legacy gates `A19-P00` … `A19-P06` (specs 137–143) · integration gate `X-A19`

A creator that exports striking still or supported video background files while respecting iOS wallpaper restrictions.

- **Primary capability:** animated art export / share workflows. **Main validity risk:** no fictitious system live-wallpaper installation API.
- **Capabilities:** Offscreen rendering; High-resolution rendering; Effects and compositing; Frame capture; Export pipelines. **For:** People designing custom backgrounds; Creators generating shareable ambient video loops; Users wanting device-tailored image dimensions.
- **Journeys:** (1) Choose a scene and wallpaper aspect template. (2) Personalize palette and animation and preview safe crop. (3) Export a correctly sized still to Photos or Files with explicit permission.
- **Required features:** (1) Curated procedural backgrounds and color presets. (2) iPhone/iPad canvas templates and cropping guides. (3) Still-image export in common image formats with verified color profile. (4) Short optional video export only after encoder/resource feasibility is demonstrated. (5) Export progress, cancellation, error recovery and local history. (6) Clear instructions for manually applying an exported image.
- **Non-goals:** Automatically setting system wallpaper via unsupported/private APIs; Claiming the export is an iOS live wallpaper if no public mechanism permits that behavior; Unlimited 8K rendering on all devices. **Later ideas (not in the first release):** Video loops using supported codecs and share options; Background packs; Cross-device export templates.
- **Domain types (proposed contracts):** `WallpaperProject(sceneID, seed, palette, aspectTemplate, animationTime, schemaVersion)`; `CanvasTemplate(widthPx, heightPx, safeAreaGuide, orientation)`; `ExportRequest(fileType, dimensions, frameRateOptional, durationOptional, colorProfile)`; `ExportResult(url, pixels, bytes, warnings)`.
- **Components named by the manual:** `WallpaperProject.swift` (domain); `CanvasTemplates.swift` (domain); `CropPreview.swift` (renderer); `ExportCoordinator.swift` (data storage); `ImageColorPipeline.swift` (domain); `WallpaperRenderer.swift` (renderer).
- **Algorithm decisions:** (1) Offscreen renderer owns independent render target and pixel-readback contract; query max texture size before allocation. (2) For stills, render at output resolution or documented tiled strategy with identical scene coordinates. (3) Enforce output framing, alpha and color-management checks; use platform encoders for video when available. (4) Photos library save is permission-mediated; Files share sheet can work without persistent broad Photos access.
- **Render stages:** (1) Load editable composition. (2) Render preview with crop overlay at screen resolution. (3) Render offscreen target to pixel buffer, encode and save/share using supported iOS APIs. (4) Verify final dimensions and clean up temporary resources on cancellation.
- **Engineering rule:** Explicitly state exported files must be applied by the user through iOS system controls; live wallpaper functionality cannot be assumed.
- **Regression fixtures (acceptance):** (1) Exported image dimensions and color profile match selected template. (2) Cancel/export retry leaves no orphan temporary GPU resources. (3) Unsupported sizes show clear fallback. (4) Share works without requiring broad photo library permission. (5) App never claims to set wallpapers automatically.
- **Profiling:** Profile memory and frame capture timing independently from preview FPS; Query GL max texture size and memory headroom; Offer lower resolutions and avoid blocking UI during encoding.
- **Risks:** OS wallpaper behavior changes and third-party live wallpaper APIs are restricted—avoid impossible feature promise; Very high resolution exports cause OOM—query limits and use tiles or cap; Video encoding consumes disk and thermal budget—progress and cancel policy.
- **Phases:** P00 Foundation and VisualCore boundary audit; P01 Platform API/export contract verification; P02 Offscreen still renderer; P03 Project/preset editing and crop UI; P04 Save/share and permission paths; P05 Resolution/color/thermal device tests; P06 Final verification, privacy, packaging and release.
- **Source:** `docs/archive/planning/embedded/apps/19-living-wallpapers.md` (lines 1–645). Prompts: `python3 scripts/speckit_prompts.py --feature 137` … `--feature 143`, each with the override of `python3 scripts/planning_index.py prompt --feature A19-P00 --override`.

### A20 Digital Zen Garden

`a20.digital-zen-garden` · free · category ambient · family Ambient and lifestyle · legacy gates `A20-P00` … `A20-P06` (specs 144–150) · integration gate `X-A20`

A calm tactile sand-raking and stone-arrangement experience with persistent compositions.

- **Primary capability:** tactile strokes and procedural sand/water. **Main validity risk:** gesture responsiveness and export history.
- **Capabilities:** Touch interaction; Procedural textures; Feedback shaders; Animation; Save and restore state. **For:** People looking for a quiet creative ritual; Families exploring tactile design; Users seeking sensory-friendly interaction.
- **Journeys:** (1) Choose a small sand tray and rake pattern by dragging. (2) Place a stone, rotate it and undo the last action. (3) Switch rake styles and save the garden.
- **Required features:** (1) One tray with visual sand relief, two rake styles and a stone palette. (2) Continuous multi-sample touch strokes and brush preview. (3) Stone placement, rotate, delete and layer-aware selection. (4) Undo/redo for strokes and placements. (5) Save/load named gardens with lightweight stroke history. (6) Low-stimulation mode with sound and animation off by default.
- **Non-goals:** Truly granular material physics; Online galleries or multiplayer sessions; Generative AI content or intrusive engagement loops. **Later ideas (not in the first release):** Additional tray textures, terrain and water motifs; Export still/short timelapse; Apple Pencil pressure handling with device checks.
- **Domain types (proposed contracts):** `GardenDocument(version, traySize, sandTone, stones, strokes, seed)`; `RakeStroke(pointsNormalized, brushID, width, depth, timestamp)`; `StoneInstance(assetID, transform, depthOrder)`; `UndoCommand(kind, before, after)`.
- **Components named by the manual:** `GardenDocument.swift` (data storage); `StrokeResampler.swift` (domain); `RakeBrush.swift` (domain); `UndoRedoStack.swift` (domain); `StonePlacement.swift` (domain); `GardenRenderer.swift` (renderer).
- **Algorithm decisions:** (1) Resample touch path to uniform spatial distance and cap samples per stroke. (2) Apply rake texture into height/displacement feedback target or CPU stroke mesh based on visual verification. (3) Persist normalized coordinates independent of screen size; rebuild render texture deterministically from compact command log. (4) Use command-based undo rather than GPU texture snapshots when possible.
- **Render stages:** (1) Restore garden document and replay strokes to rake target. (2) Process touch commands and update sand height/normal layers. (3) Render sand relief, stone sprites/meshes and soft shadows. (4) Composite subtle vignette then present with frame idling when still.
- **Engineering rule:** Preserve local work offline and keep interaction latency low; animation is subordinate to the feeling of precise touch.
- **Regression fixtures (acceptance):** (1) Undo/redo yields identical command list and reconstructed image within tolerance. (2) Fast drags have no gaps after resampling. (3) Changing orientation preserves stone positions and stroke paths. (4) Memory remains bounded for long gesture histories. (5) Reduced-motion state disables incidental animations.
- **Profiling:** Render on demand while idle; monitor only interaction bursts; Bound command-history size and checkpoint strategy; Use static lighting on low-power tier.
- **Risks:** GPU feedback undo can be expensive—use command replay and checkpoints; Touch precision suffers at small sizes—offer brush zoom; Relaxation UX can be disrupted by bright effects—quiet defaults.
- **Phases:** P00 Foundation and VisualCore boundary audit; P01 Document/stroke math and fixtures; P02 Sand and rake renderer; P03 Stone manipulation and undo; P04 Persistence/accessibility/export still; P05 Responsiveness and idle-power QA; P06 Final verification, privacy, packaging and release.
- **Source:** `docs/archive/planning/embedded/apps/20-digital-zen-garden.md` (lines 1–647). Prompts: `python3 scripts/speckit_prompts.py --feature 144` … `--feature 150`, each with the override of `python3 scripts/planning_index.py prompt --feature A20-P00 --override`.

### A21 Aurora

`a21.aurora` · free · category ambient · family Ambient and lifestyle · legacy gates `A21-P00` … `A21-P06` (specs 151–157) · integration gate `X-A21`

A full-screen ambient aurora experience with procedural skies, gentle stars and optional soundscapes.

- **Primary capability:** procedural atmospheric motion and ambience. **Main validity risk:** glare/flashing, thermal performance, color space.
- **Capabilities:** Procedural shaders; Noise functions; Particle systems; Animation; Blending and compositing. **For:** People wanting a soothing display; Relaxation and focus users; Visual art enthusiasts who enjoy animated atmospheric scenes.
- **Journeys:** (1) Choose a calm aurora landscape preset. (2) Tune color, cloud density, star count and speed. (3) Set quiet mode, lower brightness and save the scene.
- **Required features:** (1) Three procedural sky presets with aurora ribbons, stars and cloud layers. (2) Color, motion and intensity controls with sensible bounds. (3) Scene transition and saveable preferences. (4) Low-power/static view and reduced-flash mode. (5) Optional locally bundled, licensed ambient loop with separate audio control. (6) Full-screen UI that can hide controls and restore them by tap.
- **Non-goals:** Forecast of actual aurora activity; Dynamic weather integration in MVP; Mandatory background audio or guaranteed always-on screen behavior. **Later ideas (not in the first release):** Soundscape packs; Sleep timer and crossfade themes; Licensed background export.
- **Domain types (proposed contracts):** `AuroraScene(seed, palette, ribbonCount, turbulence, cloudiness, stars, animationSpeed)`; `AmbientControls(soundEnabled, volume, motionReduced, lowPower)`; `SceneTransition(fromID, toID, progress, duration)`; `PresetCatalog(id, version, attribution)`.
- **Components named by the manual:** `AuroraScene.swift` (domain); `AtmosphericNoise.swift` (domain); `SceneTransitions.swift` (domain); `AmbientSoundController.swift` (domain); `AuroraRenderer.swift` (renderer).
- **Algorithm decisions:** (1) Use layered procedural noise and slowly advected color bands rather than expensive physically-based atmosphere. (2) Keep ribbon frequency, luminance and flashes within comfort bounds. (3) Distinguish wall-clock idle time from rendered animation time to avoid massive jumps after background. (4) Provide static fallback frame when shader feature/precision not supported.
- **Render stages:** (1) Load scene preset and per-layer parameters. (2) Render starfield/clouds, aurora ribbon layers and soft glow in bounded passes. (3) Composite with explicit luminance cap. (4) Present or render a static frame when motion reduced.
- **Engineering rule:** The app is ambient art, not a physical weather or aurora forecast; label scenes as stylized and avoid geolocation in MVP.
- **Regression fixtures (acceptance):** (1) Reduced-motion scene produces a stable frame. (2) Scene transition cannot exceed user luminance cap. (3) Sound setting remains independent of visualization lifecycle. (4) Repeated theme changes release GPU targets. (5) Low-power mode reduces frame cadence without visible time discontinuity.
- **Profiling:** Focus on long-session power, screen brightness and thermal trend; Adaptive frame rate and cloud layer resolution; Verify accessibility controls and app interruptions.
- **Risks:** Expensive volumetric-like layers can drain battery—favor 2D layered shaders; Bright flashing imagery may discomfort users—enforce intensity controls; Ambient soundtrack licensing—ship only reviewed, attributed media.
- **Phases:** P00 Foundation and VisualCore boundary audit; P01 Noise/ribbon shader prototype; P02 Scene selection and controls; P03 Multi-layer compositing and presets; P04 Audio/low-power UX; P05 Long-run thermal and comfort validation; P06 Final verification, privacy, packaging and release.
- **Source:** `docs/archive/planning/embedded/apps/21-aurora.md` (lines 1–644). Prompts: `python3 scripts/speckit_prompts.py --feature 151` … `--feature 157`, each with the override of `python3 scripts/planning_index.py prompt --feature A21-P00 --override`.

### A22 Shader Studio

`a22.shader-studio` · free · category tools · family Developer and creator tools · legacy gates `A22-P00` … `A22-P06` (specs 158–164) · integration gate `X-A22`

A mobile GLSL ES editor that compiles local shaders, shows diagnostics and safely previews bounded work.

- **Primary capability:** bounded shader playground, errors/presets. **Main validity risk:** untrusted GLSL, compile limits and freeze recovery.
- **Capabilities:** Shader compilation; Diagnostics and error reporting; Render previews; Shader asset pipeline; Parameter controls. **For:** Creative coders iterating away from desktop; Students learning GLSL ES; Developers inspecting VisualCore shader tooling.
- **Journeys:** (1) Open a starter fragment shader template. (2) Modify a uniform and compile. (3) See line-correlated errors, fix them and save the project.
- **Required features:** (1) Code editor with syntax assistance and line-numbered diagnostics. (2) Local GLSL ES fragment shader templates with defined uniforms and texture inputs. (3) Explicit Compile/Run action and last-known-good preview fallback. (4) Parameter inspector for bounded uniforms. (5) Local project save/open and versioned shader files. (6) Resource/complexity limits, watchdog UX and recoverable failures.
- **Non-goals:** Arbitrary privileged native code execution; Public unmoderated shader marketplace; Strong sandbox claims against malicious GPU shader code. **Later ideas (not in the first release):** User-defined multi-pass effects with resource constraints; Version-controlled shader gallery and import/export; Education walkthroughs and test shader suite.
- **Domain types (proposed contracts):** `ShaderProject(id, version, sourceGLSL, inputs, uniforms, resourceLimits)`; `ShaderDiagnostic(file, line, columnOptional, severity, message, compilerVendor)`; `PreviewState(lastGoodProgramID, compileStatus, elapsedMs)`; `ShaderTemplate(requiredVersion, uniforms, passes)`.
- **Components named by the manual:** `ShaderProject.swift` (renderer); `ShaderSourceValidator.swift` (renderer); `CompileDiagnosticMapper.swift` (domain); `GLSLTemplateCatalog.swift` (data storage); `ShaderPreviewCoordinator.swift` (renderer); `ShaderStudioRenderer.swift` (renderer).
- **Algorithm decisions:** (1) Compile GLSL ES in owning render context and capture complete logs; map source lines correctly even after inserted template code. (2) Prevalidate source size, pass count and uniforms before any compile. (3) Constrain execution to controlled preview surface with capped dimensions and frame rate; a GPU shader may still hang or destabilize a driver, so do not advertise full isolation. (4) Retain last-good shader program and restore on failure or lifecycle change.
- **Render stages:** (1) Edit source in native text surface. (2) Validate metadata, request compile on render queue and collect diagnostics. (3) If compile/link succeeds, atomically swap programs and render controlled preview scene. (4) Otherwise preserve previous known-good preview and present actionable errors.
- **Engineering rule:** Never run user shader source on the audio/UI thread. GLSL is GPU code, not a secure sandbox, and compile errors require explicit reporting.
- **Regression fixtures (acceptance):** (1) Compiler-error line mapping points to actual authored line. (2) Compilation failure never replaces working preview. (3) Oversized project is rejected before GPU work. (4) Missing uniforms and incompatible GLES versions show specific guidance. (5) Compile/run repeated cycles do not leak shader/program objects.
- **Profiling:** Cap preview resolution/FPS, program count and per-session compile attempts; Measure compile/link time and shader presentation time separately; Provide safe default templates and clear recovery if renderer resets.
- **Risks:** User GLSL can trigger expensive driver behavior—cap input/preview and offer stop/reset, but do not promise execution sandbox; Keyboard/editor ergonomics on iPhone—prioritize iPad and hardware keyboard; Shader language/version support may vary by ANGLE—query capabilities and expose compatibility profile.
- **Phases:** P00 Foundation and VisualCore boundary audit; P01 GLSL/diagnostic contract and editor shell; P02 Compile and last-good-preview path; P03 Uniform inspector/persistence; P04 Resource limits and error UX; P05 Stress-test shader failures and device recovery; P06 Final verification, privacy, packaging and release.
- **Source:** `docs/archive/planning/embedded/apps/22-shader-studio.md` (lines 1–647). Prompts: `python3 scripts/speckit_prompts.py --feature 158` … `--feature 164`, each with the override of `python3 scripts/planning_index.py prompt --feature A22-P00 --override`.

### A23 Visual Programming Lab

`a23.visual-programming-lab` · free · category tools · family Developer and creator tools · legacy gates `A23-P00` … `A23-P06` (specs 165–171) · integration gate `X-A23`

A constrained node-graph editor for composing parameterized visuals without writing shader code.

- **Primary capability:** typed node graph and effect composition. **Main validity risk:** cycle rejection, bounded resources, project migration.
- **Capabilities:** Render graph; Compositing; Parameter system; Reusable effects; Graph serialization. **For:** Creative users who prefer visual programming; Educators demonstrating dataflow; Developers validating VisualCore graph abstractions.
- **Journeys:** (1) Open example graph with Noise → Colorize → Output. (2) Add a Mix node and connect typed ports. (3) See preview update, save graph and reopen it.
- **Required features:** (1) Typed node graph for scalar, color, texture and time values. (2) Initial node library: Time, Constant, Noise, Gradient, Mix, Blur, Output. (3) Touch graph canvas with wire routing, zoom and selection. (4) Cycle detection and clear invalid-connection feedback. (5) Preview renderer that compiles/translates a bounded acyclic graph. (6) Versioned graph persistence with migration hooks.
- **Non-goals:** Arbitrary scripting/code execution; Unbounded loops or feedback nodes in MVP; Desktop-class node editor with hundreds of nodes. **Later ideas (not in the first release):** Custom subgraphs and feedback nodes with explicit frame delay; Graph export to static preset; Community sharing with schema/security review.
- **Domain types (proposed contracts):** `GraphNode(id, kind, parameterValues, position)`; `GraphPort(nodeID, portID, valueType, direction)`; `GraphEdge(sourceNode, sourcePort, targetNode, targetPort)`; `VisualGraph(version, nodes, edges, outputNodeID)`; `CompiledGraph(orderedNodes, allocations, diagnostics)`.
- **Components named by the manual:** `VisualGraph.swift` (domain); `NodeRegistry.swift` (domain); `TypeChecker.swift` (domain); `TopologicalSort.swift` (domain); `RenderGraphCompiler.swift` (renderer); `GraphCanvas.swift` (domain); `GraphPreviewRenderer.swift` (renderer).
- **Algorithm decisions:** (1) Validate graph topology by topological sort and reject cycles before GPU work. (2) Use declared typed input/output ports to enforce composability. (3) Compile known nodes into a bounded render pass schedule; separate graph interpreter and renderer. (4) Cache compiled subgraphs by content hash and invalidate downstream nodes on edits. (5) Keep feedback/cyclic effects out until explicit state ownership is designed.
- **Render stages:** (1) Apply graph edit to immutable model. (2) Validate ports and dependency ordering. (3) Compile known node operators into VisualCore passes and allocate textures based on lifetimes. (4) Render preview, map diagnostics to graph nodes and present.
- **Engineering rule:** Node graph semantics are a product-specific dependency layer on top of VisualCoreEffects, not an excuse to introduce a second rendering backend.
- **Regression fixtures (acceptance):** (1) Cycle is rejected with identifiable edge/path. (2) Color cannot connect to scalar input without explicit converter. (3) Disconnected Output gives clear error state. (4) Save/load preserves node IDs, port links and layout. (5) A simple graph produces expected pixel fixtures and avoids unnecessary passes.
- **Profiling:** Measure compile time, pass count, temporary memory and preview latency; Use low-res preview while editing; Validate graph resource budget before allocating GPU targets.
- **Risks:** User-generated graphs can consume excessive FBO memory—static budget before compile; Complex touch wiring can be frustrating—large targets and zoom; Stable graph file formats require migration policy.
- **Phases:** P00 Foundation and VisualCore boundary audit; P01 Graph schema and type-checking fixtures; P02 Node canvas and connections; P03 Bounded graph compiler and preview; P04 Save/load, examples and diagnostics; P05 Resource-budget and usability testing; P06 Final verification, privacy, packaging and release.
- **Source:** `docs/archive/planning/embedded/apps/23-visual-programming-lab.md` (lines 1–648). Prompts: `python3 scripts/speckit_prompts.py --feature 165` … `--feature 171`, each with the override of `python3 scripts/planning_index.py prompt --feature A23-P00 --override`.

### A24 Graphics Benchmark Lab

`a24.graphics-benchmark-lab` · free · category tools · family Developer and creator tools · legacy gates `A24-P00` … `A24-P06` (specs 172–178) · integration gate `X-A24`

A transparent, repeatable suite of GPU graphics workloads and instrumentation with measured-device caveats.

- **Primary capability:** reference render scenes and performance capture. **Main validity risk:** reproducible results; no fabricated hardware metrics.
- **Capabilities:** GPU timing; Diagnostics; Profiling; Benchmark scenes; Device and configuration reporting. **For:** iOS graphics engineers; Framework maintainers verifying regressions; Technically curious users comparing their own devices.
- **Journeys:** (1) Choose fill-rate stress scene and fixed preset. (2) Run a structured warmup and measurement session. (3) Review fps/frame-time distribution and save result with device and test metadata.
- **Required features:** (1) Repeatable baseline scenes: textured quads, shader ALU stress and particles. (2) Warmup, controlled measurement and cooldown phases. (3) Frame-time percentile, CPU submit time and optional supported GPU timer metrics. (4) Device/OS/build/quality/thermal-context report with provenance. (5) Results export as versioned JSON or CSV. (6) In-app explanation of benchmark limits and variability.
- **Non-goals:** Ranking all devices from single run as scientific truth; GPU timer claims without supported extension/profiler; Collecting private hardware identifiers or automatic uploads. **Later ideas (not in the first release):** Trend charts and local run comparison; Automated CI performance probe with dedicated devices; Optional anonymized opt-in result sharing after privacy review.
- **Domain types (proposed contracts):** `BenchmarkCase(id, version, shaderHash, drawCount, targetResolution, resourceBudget)`; `BenchmarkRun(id, deviceModel, osVersion, appBuild, ANGLEBuild, startedAt, duration, state)`; `FrameMeasurement(frameIndex, cpuMs, presentMs, gpuMsOptional, dropped)`; `Summary(p50, p95, p99, warmupExcluded, sampleCount, qualityFlags)`.
- **Components named by the manual:** `BenchmarkCatalog.swift` (data storage); `BenchmarkRunner.swift` (domain); `FrameMetricsCollector.swift` (domain); `TimingCapabilityProbe.swift` (domain); `Statistics.swift` (domain); `ResultsStore.swift` (data storage); `BenchmarkSceneRenderer.swift` (renderer).
- **Algorithm decisions:** (1) Build fixed deterministic scenes with versioned assets and recorded config. (2) Partition warmup from measurement and use monotonic clocks. (3) Only report GPU time if implementation confirms accurate, non-disjoint timing support; never substitute CPU timings with GPU label. (4) Record thermal state/visibility/charger context as available and mark any comparability caveats. (5) Use statistical distributions, not just average FPS.
- **Render stages:** (1) Load case and verify config/assets. (2) Warm up renderer under fixed workload. (3) Capture frame timings with supported instrumentation during measured interval. (4) Persist raw samples, compute percentiles and display caveated report with export.
- **Engineering rule:** Measurement provenance is a feature requirement; do not rank devices or claim rigorous GPU throughput from unsupported timing sources.
- **Regression fixtures (acceptance):** (1) Statistics p50/p95/p99 match fixture samples including edge cases. (2) Unsupported GPU timer produces null, not fabricated zeros. (3) Measurement excludes warmup interval. (4) Identical case version and settings are stored with run. (5) App background/thermal interruption flags a run as invalid/qualified.
- **Profiling:** Define baseline per-device measurement windows and revisit after VisualCore changes; Record CPU/GPU measurement method and confidence; Limit stress durations and allow immediate stop.
- **Risks:** Thermal throttling and display refresh skew results—record context and repeat trials; GL timing extension availability uncertain—feature detect, avoid false GPU claims; Aggressive stress testing can overheat devices—bound duration and implement cooldown/stop.
- **Phases:** P00 Foundation and VisualCore boundary audit; P01 Measurement methodology and fixture statistics; P02 Three deterministic workload renderers; P03 Runner/profiler and capability probing; P04 Results persistence/export; P05 Repeatability, thermal and methodology review; P06 Final verification, privacy, packaging and release.
- **Source:** `docs/archive/planning/embedded/apps/24-graphics-benchmark-lab.md` (lines 1–647). Prompts: `python3 scripts/speckit_prompts.py --feature 172` … `--feature 178`, each with the override of `python3 scripts/planning_index.py prompt --feature A24-P00 --override`.

### A25 Effects Composer

`a25.effects-composer` · free · category tools · family Developer and creator tools · legacy gates `A25-P00` … `A25-P06` (specs 179–185) · integration gate `X-A25`

A visual effects-chain editor for building, previewing and exporting reusable shader looks.

- **Primary capability:** multi-pass effect graph, reusable composition. **Main validity risk:** texture lifecycle, DAG ordering and memory caps.
- **Capabilities:** Render graph; Framebuffer pipelines; Shader library; Effect parameters; Preset serialization; Offscreen rendering and export. **For:** Creative users modifying images and backgrounds; Motion designers prototyping looks; Developers testing render-pass composition.
- **Journeys:** (1) Open built-in test image. (2) Add Blur → Color Grade → Distortion, reorder effects. (3) Adjust parameters, compare before/after and export a processed still.
- **Required features:** (1) Linear chain editor with five built-in effects and bounded parameters. (2) Editable reorder, enable/disable and immediate preview. (3) Before/after compare and preset saves. (4) Local image import via system picker with scoped access. (5) Still export with dimension/format validation. (6) Controlled render target pooling and shader compile diagnostics.
- **Non-goals:** General video non-linear editor; Arbitrary custom feedback loops or user code in MVP; Batch importing cloud libraries without consent. **Later ideas (not in the first release):** DAG editor with branches/masks and feedback semantics; Supported video export and animated effects; Export effects as validated VisualCore presets.
- **Domain types (proposed contracts):** `EffectNode(id, kind, enabled, parameterMap, inputFormat, outputFormat)`; `EffectChain(version, sourceRef, orderedNodes, outputSettings)`; `ImageSource(id, pixelSize, colorSpace, accessPolicy)`; `RenderPlan(passes, intermediateTargets, textureLifetimes, validationErrors)`.
- **Components named by the manual:** `EffectChain.swift` (domain); `EffectRegistry.swift` (domain); `RenderPlanCompiler.swift` (renderer); `ImageImportCoordinator.swift` (data storage); `EffectParameterEditor.swift` (domain); `EffectsComposerRenderer.swift` (renderer); `ExportCoordinator.swift` (data storage).
- **Algorithm decisions:** (1) Implement linear chain first, but represent each effect as typed input/output pass. (2) Validate supported texture formats, color space, dimensions and parameter ranges before graph compilation. (3) Ping-pong or pool intermediate FBO targets; no sampling currently attached output texture. (4) Preserve unprocessed source for compare, and decouple preview resolution from full-quality export.
- **Render stages:** (1) Import allowed image or bundled fixture. (2) Decode source, validate color and texture requirements. (3) Compile effect chain to ordered VisualCore passes and allocate temporary targets. (4) Composite preview/before-after; offscreen re-run and encode output at export resolution.
- **Engineering rule:** Keep MVP graph a linear, acyclic pipeline; preserve the ability to add a typed DAG later without promising arbitrary node semantics.
- **Regression fixtures (acceptance):** (1) Effect order changes output and can be undone precisely. (2) Disabled effect is equivalent to identity within tolerance. (3) Temporary targets never alias read/write in a pass. (4) Imported image color profile and orientation are handled correctly. (5) Full-size export matches preview parameters within color/resampling tolerances.
- **Profiling:** Measure per-effect GPU cost, FBO allocations and preview latency; Downscale live preview while preserving export path; Cache unchanged pass results based on source/effect hashes when justified.
- **Risks:** Color-space mistakes create wrong output—explicit linear/sRGB pass boundaries; Large images exceed texture limits—query/cap or tile; Intermediate render targets can grow without bound—lifetime analysis and fixed pool.
- **Phases:** P00 Foundation and VisualCore boundary audit; P01 Effect definitions and render contracts; P02 Linear pass compiler and preview; P03 Chain editing/import/compare; P04 Still export/presets; P05 Color, memory and device robustness; P06 Final verification, privacy, packaging and release.
- **Source:** `docs/archive/planning/embedded/apps/25-effects-composer.md` (lines 1–651). Prompts: `python3 scripts/speckit_prompts.py --feature 179` … `--feature 185`, each with the override of `python3 scripts/planning_index.py prompt --feature A25-P00 --override`.
<!-- GENERATED:END cards-creative -->

## 8. Free library II: the 25 Round 2 games

Round 2 holds the 25 games selected from the 500-candidate study (`docs/brainstorm/`): the best-scoring
candidates with at most two per mechanic family, numbered 1 to 25 in the study's "selected top 25" column. Every game is a
deterministic puzzle whose world is drawn entirely by code. Each has 23 chapters in the archive (first play, exact
rules and victory proof, invariants, visual identity, content design, persistence, accessibility, file inventory,
shared dependencies, prompts, acceptance matrix, seed contracts, hardware plan, risks and more) and an assertion
outline; the card gives the line span.

Every Round 2 game is built from the same ten features, in order. Each is one Spec Kit feature with eight archived
stage prompts and one gate of the migration ledger:

<!-- GENERATED:BEGIN game-features-round02 -->
| # | Feature | Requirement in the source | Reading in the single app |
|---:|---|---|---|
| 01 | Playable rule kernel | Implement deterministic state transition and exact win/failure evaluation | unchanged |
| 02 | Level generator and solver witness | Generate solvable seeded levels with certificates and difficulty metrics | unchanged; 100 certified levels |
| 03 | Procedural materials and hero renderer | Render signature geometry and materials entirely in shaders and generated meshes | unchanged |
| 04 | Gameplay spatial interaction | Implement native gesture-to-world actions, undo and camera behavior | unchanged |
| 05 | Progression and player teaching | Provide tutorial hints, pacing, goals and meaningful premium content | unchanged; the game is free, "premium content" means complete content |
| 06 | Polish and accessiblity | Ship clear native overlays, accessibility, reduce-flashing, audio and haptics | unchanged |
| 07 | Persistence and replay | Atomic saves, deterministic fixed seeds, migration and reconcilable scores | storage through the experience context (UA-F05) |
| 08 | Visual golden/solver regression | Execute CPU solver fixtures, screenshot baselines, memory checks and CI | unchanged; goldens are supporting evidence |
| 09 | Simulator integration and full app lock | Compile actual target, XCUITest, logic test, all-level solvability and release config | no app target: register the experience and pass its scenario set in the unified app (UA-F09) |
| 10 | Device automation preparation | Build automation runner and acceptance contract but do not launch a device yet | scenario set and device-row definition only; no device contact before ImplementationLock-100 (UA-F13) |
<!-- GENERATED:END game-features-round02 -->

The games depend on the shared features of section 13.4. A game's first feature becomes ready when the unified
session host (UA-F03) and the shared features it uses are sealed.

<!-- GENERATED:BEGIN cards-round02 -->
### R02-G01 Aurora Loom

`r02-g01.aurora-loom` · free · category puzzle · family Light and color · score 94.8 · rank 1 · candidate G162 · features `R02-G01-01` … `R02-G01-10` (specs 301–310) · integration gate `X-R02-G01`

Weave and phase-shift 3D luminous ribbons into target harmonies.

- **Objective:** make three luminous ribbons share a target harmonic phase at four gates. **Victory:** all four gate samples stay within angular tolerance for two complete periods. **Failure:** phase mismatch exceeds gate tolerance after the move allowance.
- **Controls:** drag an anchor to displace a ribbon, rotate an orbital dial to change phase; two-finger pan camera.
- **Model:** core abstraction spectral ribbon phase; state: A ribbon is a swept cubic spline with phase q(s,t)=k*s+omega*t+phi; controls quantize k and phi into sixteen stable ticks; fixed step 0.008333 s; solver: bounded phase-gradient coordinate descent with exact grid search fallback; truth metric: wrapped phase residual, no aesthetic-only success check.
- **Look (code only):** camera-depth layered auroral silk with refractive-looking interference; geometry: parallel transport ribbon frame with bevel edge shading; signature shader: Layered ribbon meshes with wave displacement and fragment interference patterns; palette: polar teal, magenta, acid-gold.
- **Content:** 100 solver-certified levels: the catalog in lines 2884–2989 is canonical (`python3 scripts/planning_index.py levels --experience R02-G01`); 80 acceptance scenarios in lines 2990–3075. The chapter header's earlier figure ("80 solver-certified stages") and its shorter manifests are milestones only.
- **Shared features used:** R02-F02, R02-F03, R02-F04, R02-F05, R02-F06, R02-F07, R02-F08, R02-F10, R02-F22, R02-F23, R02-F24, R02-F26; the remaining shared dependencies of the source are delivered by unified-app features (section 13).
- **Source:** `docs/archive/planning/rounds/round2.md` lines 2061–3144 (23 sections); assertion outline lines 29449–29513. Prompts: `python3 scripts/planning_index.py prompt --feature R02-G01-01 --override`.

### R02-G02 Lissajous Labyrinth

`r02-g02.lissajous-labyrinth` · free · category puzzle · family Wave mathematics · score 94.3 · rank 2 · candidate G456 · features `R02-G02-01` … `R02-G02-10` (specs 311–320) · integration gate `X-R02-G02`

Tune two coupled frequencies so a moving point traces a safe path.

- **Objective:** tune two integer frequency ratios and phases so a tracer passes every illuminated checkpoint without contacting hazards. **Victory:** all checkpoints visited in order over a complete fundamental period. **Failure:** the point enters an obstacle volume during its required lap.
- **Controls:** rotate the dual dials for frequency and phase; tap preview and trace scrubber.
- **Model:** core abstraction three-axis harmonic path planning; state: x=A*sin(a*t+phi), y=B*sin(b*t), z=C*cos(c*t+psi); ratios from 1:1 to 9:8 with rational periods; fixed step 0.004167 s; solver: enumerate coprime frequency pairs and phase offsets with segment-swept collision tests; truth metric: minimum segment-obstacle clearance and checkpoint arc order.
- **Look (code only):** luminous ink threads composing a slow-motion 3D mathematical flower; geometry: adaptive curve tessellation with tangent-space width; signature shader: elegant 3D luminous harmonic curves weave through obstacles; Analytic oscillators, Fourier curve meshes, interference heightfields and emissive color; palette: cobalt, violet and copper.
- **Content:** 100 solver-certified levels: the catalog in lines 3987–4092 is canonical (`python3 scripts/planning_index.py levels --experience R02-G02`); 80 acceptance scenarios in lines 4093–4178. The chapter header's earlier figure ("90 solver-certified stages") and its shorter manifests are milestones only.
- **Shared features used:** R02-F02, R02-F03, R02-F04, R02-F05, R02-F06, R02-F07, R02-F08, R02-F22, R02-F23, R02-F24, R02-F26; the remaining shared dependencies of the source are delivered by unified-app features (section 13).
- **Source:** `docs/archive/planning/rounds/round2.md` lines 3145–4247 (23 sections); assertion outline lines 29514–29578. Prompts: `python3 scripts/planning_index.py prompt --feature R02-G02-01 --override`.

### R02-G03 Wave Knot Keeper

`r02-g03.wave-knot-keeper` · free · category puzzle · family Wave mathematics · score 94.3 · rank 3 · candidate G466 · features `R02-G03-01` … `R02-G03-10` (specs 321–330) · integration gate `X-R02-G03`

Drag spectral control points to untie closed three-dimensional wave knots.

- **Objective:** move spectral handles until one closed knot matches a designated untangled embedding while preserving strand continuity. **Victory:** projected signed crossing graph and knot invariant satisfy the target configuration. **Failure:** a restricted segment intersection or tension bound violation occurs.
- **Controls:** drag depth-aware handles with snapping; two-finger orbit for occlusion disambiguation.
- **Model:** core abstraction topological strand manipulation; state: closed Catmull-Rom or cubic B-spline samples; handle motion must preserve minimum clearance unless explicit crossing gates permit changes; fixed step 0.008333 s; solver: constraint relaxation on control points with segment intersection and isotopy checks; truth metric: crossing graph parity and clearance margins.
- **Look (code only):** glasslike light ropes braided through space with beat-driven caustic pulses; geometry: parallel-transport tube splines and additive glow shells; signature shader: luminous torus knots pulse in synchronized colors; Analytic oscillators, Fourier curve meshes, interference heightfields and emissive color; palette: pearl, sapphire and ember.
- **Content:** 100 solver-certified levels: the catalog in lines 5054–5159 is canonical (`python3 scripts/planning_index.py levels --experience R02-G03`); 80 acceptance scenarios in lines 5160–5245. The chapter header's earlier figure ("72 solver-certified stages") and its shorter manifests are milestones only.
- **Shared features used:** R02-F02, R02-F03, R02-F04, R02-F05, R02-F06, R02-F07, R02-F08, R02-F22, R02-F23, R02-F24, R02-F26; the remaining shared dependencies of the source are delivered by unified-app features (section 13).
- **Source:** `docs/archive/planning/rounds/round2.md` lines 4248–5314 (23 sections); assertion outline lines 29579–29643. Prompts: `python3 scripts/planning_index.py prompt --feature R02-G03-01 --override`.

### R02-G04 Hue Compass

`r02-g04.hue-compass` · free · category puzzle · family Chromatic logic · score 94.21 · rank 4 · candidate G400 · features `R02-G04-01` … `R02-G04-10` (specs 331–340) · integration gate `X-R02-G04`

Rotate a spectral compass to find a hidden target in a colored fog field.

- **Objective:** infer a hidden hue target by rotating an illuminated 3D compass and interpreting local spectral gradients. **Victory:** align the bearing and hue band within both specified tolerances. **Failure:** selection outside angular threshold or exhausted probes.
- **Controls:** swipe to rotate compass, press to sample a clue, separate high-contrast colorblind symbols.
- **Model:** core abstraction chromatic inference in fog; state: hue hue=(atan2(y,x)+offset)/(2*pi); clues use hue differences and optical depth; luminance remains independently perceivable; fixed step 0.016667 s; solver: sample known target field with discretized compass bearings and uniqueness tests; truth metric: angular error with noncolor secondary state.
- **Look (code only):** prismatic glass vectors floating within luminous spectral fog; geometry: instanced translucent prisms and analytic fog depth; signature shader: 3D color cones and moving luminous vector arrows; GLSL hue transforms, procedural glass polygons, spline light tubes and glow; palette: full-spectrum wheel with grayscale evidence glyphs.
- **Content:** 100 solver-certified levels: the catalog in lines 6130–6235 is canonical (`python3 scripts/planning_index.py levels --experience R02-G04`); 80 acceptance scenarios in lines 6236–6321. The chapter header's earlier figure ("76 solver-certified stages") and its shorter manifests are milestones only.
- **Shared features used:** R02-F02, R02-F03, R02-F04, R02-F05, R02-F06, R02-F07, R02-F09, R02-F10, R02-F22, R02-F23, R02-F24, R02-F26; the remaining shared dependencies of the source are delivered by unified-app features (section 13).
- **Source:** `docs/archive/planning/rounds/round2.md` lines 5315–6390 (23 sections); assertion outline lines 29644–29708. Prompts: `python3 scripts/planning_index.py prompt --feature R02-G04-01 --override`.

### R02-G05 Colorfall Canyons

`r02-g05.colorfall-canyons` · free · category puzzle · family Light and color · score 94.13 · rank 5 · candidate G161 · features `R02-G05-01` … `R02-G05-10` (specs 341–350) · integration gate `X-R02-G05`

Carve sluices to direct colored light-fluid into target basins.

- **Objective:** route three color-fluids into correct basins by carving limited channels on a small terrain. **Victory:** target basins reach required dye fractions without overflow after a bounded tick count. **Failure:** too much incorrect dye enters a protected target basin.
- **Controls:** drag short sluice edits and tap valves; pause/step/undo.
- **Model:** core abstraction conservative terrain-channel dye transport; state: cell volumes q_{t+1}=q_t+inflow-outflow; fixed dt and capacity; color mass is conserved separately; no unstable free-surface CFD; fixed step 0.016667 s; solver: coarse-grid deterministic water routing with graph reachability and conservation assertions; truth metric: total fluid and dye-mass drift per tick.
- **Look (code only):** liquid neon waterfalls carving bright channels across miniature mesa terrain; geometry: heightfield mesh, generated surface normals, shader flow-map bands; signature shader: Heightfield canyons with spectral dye particles and flow-map water shaders; palette: electric cyan, coral, yellow.
- **Content:** 100 solver-certified levels: the catalog in lines 7256–7361 is canonical (`python3 scripts/planning_index.py levels --experience R02-G05`); 80 acceptance scenarios in lines 7362–7447. The chapter header's earlier figure ("100 solver-certified stages") and its shorter manifests are milestones only.
- **Shared features used:** R02-F02, R02-F03, R02-F04, R02-F05, R02-F06, R02-F07, R02-F10, R02-F16, R02-F17, R02-F18, R02-F22, R02-F23, R02-F24, R02-F26; the remaining shared dependencies of the source are delivered by unified-app features (section 13).
- **Source:** `docs/archive/planning/rounds/round2.md` lines 6391–7516 (23 sections); assertion outline lines 29709–29773. Prompts: `python3 scripts/planning_index.py prompt --feature R02-G05-01 --override`.

### R02-G06 Chrono Constellator

`r02-g06.chrono-constellator` · free · category puzzle · family Temporal puzzles · score 94.02 · rank 6 · candidate G450 · features `R02-G06-01` … `R02-G06-10` (specs 351–360) · integration gate `X-R02-G06`

Record and replay a constellation's motion until all stars align.

- **Objective:** record short time loops of orbiting stars so their luminous trails coincide with a target constellation. **Victory:** all star nodes enter target cells on the same tick, with stable target topology. **Failure:** unsatisfied stars collide during the synchronization window.
- **Controls:** scrub timeline; drag a star start marker; record and rewind without ambiguity.
- **Model:** core abstraction time-based synchronized star routing; state: timeline is an event log of tick-indexed actions; replay uses fixed-step deterministic integration and signed snapshots; fixed step 0.008333 s; solver: integer-tick phase search for replay windows and time offsets; truth metric: tick-accurate replay hash and synchronized target-cell occupancy.
- **Look (code only):** glowing temporal ribbons resembling a woven astronomical score; geometry: polyline history cache with predictable alpha decay; signature shader: 3D star traces accumulate into glowing history ribbons; Deterministic timeline buffers, ghost trails, reversible deformation shaders; palette: indigo, silver and rose.
- **Content:** 100 solver-certified levels: the catalog in lines 8336–8441 is canonical (`python3 scripts/planning_index.py levels --experience R02-G06`); 80 acceptance scenarios in lines 8442–8527. The chapter header's earlier figure ("78 solver-certified stages") and its shorter manifests are milestones only.
- **Shared features used:** R02-F02, R02-F03, R02-F04, R02-F05, R02-F06, R02-F07, R02-F08, R02-F14, R02-F22, R02-F23, R02-F24, R02-F26; the remaining shared dependencies of the source are delivered by unified-app features (section 13).
- **Source:** `docs/archive/planning/rounds/round2.md` lines 7517–8596 (23 sections); assertion outline lines 29774–29838. Prompts: `python3 scripts/planning_index.py prompt --feature R02-G06-01 --override`.

### R02-G07 Amethyst Escape

`r02-g07.amethyst-escape` · free · category puzzle · family Crystal solids · score 93.99 · rank 7 · candidate G299 · features `R02-G07-01` … `R02-G07-10` (specs 361–370) · integration gate `X-R02-G07`

Rotate crystalline layers to open a route for a rolling pearl.

- **Objective:** rotate nested crystal shells to align apertures and roll a pearl from center to exit. **Victory:** pearl moves through the designated exit gap in the outer shell. **Failure:** pearl enters a blocked wedge or move budget expires.
- **Controls:** drag each shell bezel, tap advance pearl, double tap isolate layer.
- **Model:** core abstraction nested faceted 3D maze; state: shell rings rotate in fixed increments; connectivity graph is recomputed at angle changes; pearl uses deterministic pocket transitions; fixed step 0.008333 s; solver: breadth-first search over discretized shell angles and pearl pocket indices; truth metric: graph route length and reachable exit proof.
- **Look (code only):** layered amethyst gem cathedral with dancing internal facet highlights; geometry: procedurally beveled wedge polyhedra with analytic faceting; signature shader: translucent nested polygons with shifting specular highlights; Beveled polyhedra, faceted signed-distance fields, instanced lattices and faux dispersion; palette: amethyst purple and cool platinum.
- **Content:** 100 solver-certified levels: the catalog in lines 9420–9525 is canonical (`python3 scripts/planning_index.py levels --experience R02-G07`); 80 acceptance scenarios in lines 9526–9611. The chapter header's earlier figure ("80 solver-certified stages") and its shorter manifests are milestones only.
- **Shared features used:** R02-F02, R02-F03, R02-F04, R02-F05, R02-F06, R02-F07, R02-F11, R02-F12, R02-F22, R02-F23, R02-F24, R02-F26; the remaining shared dependencies of the source are delivered by unified-app features (section 13).
- **Source:** `docs/archive/planning/rounds/round2.md` lines 8597–9680 (23 sections); assertion outline lines 29839–29903. Prompts: `python3 scripts/planning_index.py prompt --feature R02-G07-01 --override`.

### R02-G08 Faceted Forge

`r02-g08.faceted-forge` · free · category puzzle · family Crystal solids · score 93.98 · rank 8 · candidate G291 · features `R02-G08-01` … `R02-G08-10` (specs 371–380) · integration gate `X-R02-G08`

Place cleavage planes to split a glowing crystal into target solids.

- **Objective:** cut a glowing crystal by placing a bounded number of planes to match target volumes and facet counts. **Victory:** piece-volume vector and face-class multiset match the objective within tolerance. **Failure:** a cut creates disallowed slivers or consumes all remaining cuts.
- **Controls:** drag cut-plane rim and depth slider; tap commit for cinematic split.
- **Model:** core abstraction finite convex polyhedra partitioning; state: planes n·x=d split convex polyhedra; compute oriented intersections; reject degenerate tiny faces; volume from signed tetrahedra; fixed step 0.008333 s; solver: convex half-space polytope clipping and exact-oriented face classification with tolerances; truth metric: volume conservation and manifold/edge incidence.
- **Look (code only):** incandescent mineral interiors opening like a geometric blossom; geometry: half-space clipping generates per-piece indexed meshes; signature shader: fast SDF cuts reveal incandescent geometric interiors; Beveled polyhedra, faceted signed-distance fields, instanced lattices and faux dispersion; palette: ice glass, ruby, inner amber.
- **Content:** 100 solver-certified levels: the catalog in lines 10512–10617 is canonical (`python3 scripts/planning_index.py levels --experience R02-G08`); 80 acceptance scenarios in lines 10618–10703. The chapter header's earlier figure ("84 solver-certified stages") and its shorter manifests are milestones only.
- **Shared features used:** R02-F02, R02-F03, R02-F04, R02-F05, R02-F06, R02-F07, R02-F11, R02-F12, R02-F22, R02-F23, R02-F24, R02-F26; the remaining shared dependencies of the source are delivered by unified-app features (section 13).
- **Source:** `docs/archive/planning/rounds/round2.md` lines 9681–10772 (23 sections); assertion outline lines 29904–29968. Prompts: `python3 scripts/planning_index.py prompt --feature R02-G08-01 --override`.

### R02-G09 Nocturne Garden

`r02-g09.nocturne-garden` · free · category puzzle · family Shadow construction · score 93.96 · rank 9 · candidate G368 · features `R02-G09-01` … `R02-G09-10` (specs 381–390) · integration gate `X-R02-G09`

Arrange glowing blooms to create a target flower-shaped dark silhouette.

- **Objective:** arrange procedurally grown flowers so their projected shadows form a target silhouette. **Victory:** target mask IoU exceeds requirement and no penalty-region pixels exceed budget. **Failure:** shadow area leaks into prohibited outline regions.
- **Controls:** drag stems, pinch scale, slide sun elevation; silhouette preview as exact diagnostic.
- **Model:** core abstraction silhouette composition; state: orthographic projected polygon union rasterized into a deterministic low-resolution mask; quality measured by IoU plus boundary deviation; fixed step 0.016667 s; solver: grid-snapped candidate placements with stencil overlap and shape-distance scoring; truth metric: mask intersection-over-union and contour Hausdorff proxy.
- **Look (code only):** black botanical silhouettes climbing through luminous pearlescent mist; geometry: L-system stems, leaf polygons and projected shadow mesh; signature shader: deep black botanical shadows on colored mist planes; Procedural solids, CPU polygonal 3D shadow projections, soft shadow approximation; palette: midnight blue, lantern coral and parchment gold.
- **Content:** 100 solver-certified levels: the catalog in lines 11588–11693 is canonical (`python3 scripts/planning_index.py levels --experience R02-G09`); 80 acceptance scenarios in lines 11694–11779. The chapter header's earlier figure ("76 solver-certified stages") and its shorter manifests are milestones only.
- **Shared features used:** R02-F02, R02-F03, R02-F04, R02-F05, R02-F06, R02-F07, R02-F13, R02-F19, R02-F22, R02-F23, R02-F24, R02-F26; the remaining shared dependencies of the source are delivered by unified-app features (section 13).
- **Source:** `docs/archive/planning/rounds/round2.md` lines 10773–11848 (23 sections); assertion outline lines 29969–30033. Prompts: `python3 scripts/planning_index.py prompt --feature R02-G09-01 --override`.

### R02-G10 Backwards Aurora

`r02-g10.backwards-aurora` · free · category puzzle · family Temporal puzzles · score 93.96 · rank 10 · candidate G451 · features `R02-G10-01` … `R02-G10-10` (specs 391–400) · integration gate `X-R02-G10`

Correct a hidden signal by reversing sections of an auroral wave.

- **Objective:** reverse selected intervals of a flowing aurora so corrupted waveform sections reconstruct an original target. **Victory:** reconstructed waveform matches target checkpoints and seam limits. **Failure:** seams exceed curvature limits after reversing.
- **Controls:** tap segment ends, swipe the interval to reverse, timeline freeze preview.
- **Model:** core abstraction piecewise reversible wave field; state: signal samples in signed fixed precision; interval reversal must preserve seam continuity and bounded curvature; fixed step 0.008333 s; solver: interval dynamic programming over reversible wave segments and endpoint continuity constraints; truth metric: normalized signal edit distance and continuity.
- **Look (code only):** rivers of aurora folding backward through time in synchronized waves; geometry: tessellated temporal ribbon with direction-coded pulses; signature shader: auroral ribbons fold backward along procedural timelines; Deterministic timeline buffers, ghost trails, reversible deformation shaders; palette: deep ocean cyan, pale lilac, midnight.
- **Content:** 100 solver-certified levels: the catalog in lines 12665–12770 is canonical (`python3 scripts/planning_index.py levels --experience R02-G10`); 80 acceptance scenarios in lines 12771–12856. The chapter header's earlier figure ("76 solver-certified stages") and its shorter manifests are milestones only.
- **Shared features used:** R02-F02, R02-F03, R02-F04, R02-F05, R02-F06, R02-F07, R02-F08, R02-F10, R02-F14, R02-F22, R02-F23, R02-F24, R02-F26; the remaining shared dependencies of the source are delivered by unified-app features (section 13).
- **Source:** `docs/archive/planning/rounds/round2.md` lines 11849–12925 (23 sections); assertion outline lines 30034–30098. Prompts: `python3 scripts/planning_index.py prompt --feature R02-G10-01 --override`.

### R02-G11 Echo Cartographer

`r02-g11.echo-cartographer` · free · category puzzle · family Logic and patterns · score 93.91 · rank 11 · candidate G181 · features `R02-G11-01` … `R02-G11-10` (specs 401–410) · integration gate `X-R02-G11`

Touch to emit a pulse, mark reflected obstacles, locate hidden beacons; seeded room generator.

- **Objective:** emit timed sonar pulses to identify invisible walls and locate hidden beacons with limited energy. **Victory:** every beacon triangulated and tapped inside a spatial tolerance. **Failure:** energy is exhausted without locating all beacons.
- **Controls:** tap to emit pulse; triangulate via dragging markers; rotate 3D camera.
- **Model:** core abstraction reflective line-of-sight chamber mapping; state: raycast wave returns with path-length delay; echoes based on static convex segments; deterministic time-of-flight per beam; fixed step 0.008333 s; solver: grid chamber generator with connected-component and unique beacon inference proof; truth metric: ray travel distance agreement and beacon localization error.
- **Look (code only):** dark temples briefly crystallizing into wireframe from expanding cyan light; geometry: SDF primitives plus instanced wireframe edge strips; signature shader: Signed-distance chamber topology, instanced wireframe surfaces, expanding normal-aware echo waves; palette: abyss black, sonar mint and opal.
- **Content:** 100 solver-certified levels: the catalog in lines 13770–13875 is canonical (`python3 scripts/planning_index.py levels --experience R02-G11`); 80 acceptance scenarios in lines 13876–13961. The chapter header's earlier figure ("90 solver-certified stages") and its shorter manifests are milestones only.
- **Shared features used:** R02-F02, R02-F03, R02-F04, R02-F05, R02-F06, R02-F07, R02-F09, R02-F11, R02-F16, R02-F22, R02-F23, R02-F24, R02-F26; the remaining shared dependencies of the source are delivered by unified-app features (section 13).
- **Source:** `docs/archive/planning/rounds/round2.md` lines 12926–14030 (23 sections); assertion outline lines 30099–30163. Prompts: `python3 scripts/planning_index.py prompt --feature R02-G11-01 --override`.

### R02-G12 Harmonic Bridges

`r02-g12.harmonic-bridges` · free · category puzzle · family Acoustic geometry · score 93.81 · rank 12 · candidate G217 · features `R02-G12-01` … `R02-G12-10` (specs 411–420) · integration gate `X-R02-G12`

Tune suspended strings so their resonances solidify walkable bridges.

- **Objective:** tune suspended strings until stable antinodes create connected walkways between islands. **Victory:** start to goal reachability sustained for required window. **Failure:** bridge breaks during a crossing-window step.
- **Controls:** pluck to audition frequency, drag tuning peg, tap freeze to test walkway.
- **Model:** core abstraction standing-wave bridge formation; state: y(x,t)=sum A_n sin(n*pi*x/L)*cos(omega_n*t+phi_n); solidity threshold from time-averaged envelope; fixed step 0.008333 s; solver: discrete rational string-mode search with graph edge existence and reachability; truth metric: mode amplitude envelope and bridge graph connectivity.
- **Look (code only):** strings swelling into translucent glowing architecture as they find resonance; geometry: swept strings and radial wave-shell strip meshes; signature shader: oscillating wave membranes stretch between crystalline anchors; Instanced line meshes, transient wave shells, acoustically inspired distance-field reveals; palette: warm copper, cyan membranes and mist violet.
- **Content:** 100 solver-certified levels: the catalog in lines 14857–14962 is canonical (`python3 scripts/planning_index.py levels --experience R02-G12`); 80 acceptance scenarios in lines 14963–15048. The chapter header's earlier figure ("82 solver-certified stages") and its shorter manifests are milestones only.
- **Shared features used:** R02-F02, R02-F03, R02-F04, R02-F05, R02-F06, R02-F07, R02-F08, R02-F22, R02-F23, R02-F24, R02-F26; the remaining shared dependencies of the source are delivered by unified-app features (section 13).
- **Source:** `docs/archive/planning/rounds/round2.md` lines 14031–15117 (23 sections); assertion outline lines 30164–30228. Prompts: `python3 scripts/planning_index.py prompt --feature R02-G12-01 --override`.

### R02-G13 Acoustic Constellator

`r02-g13.acoustic-constellator` · free · category puzzle · family Acoustic geometry · score 93.81 · rank 13 · candidate G230 · features `R02-G13-01` … `R02-G13-10` (specs 421–430) · integration gate `X-R02-G13`

Connect drifting musical nodes so their shared harmonics form celestial diagrams.

- **Objective:** connect drifting nodes so coupled oscillators lock into a target celestial symbol. **Victory:** target graph edges exist and phase-coherence exceeds threshold for hold interval. **Failure:** edge budget exceeded or graph disconnects under drift.
- **Controls:** drag links between 3D stars, tap a node to phase nudge, orbit to inspect.
- **Model:** core abstraction graph resonance synchronization; state: phase_i += omega_i*dt + K sum sin(phase_j-phase_i)*dt; cap max degree; require spectral phase coherence; fixed step 0.008333 s; solver: graph spanning tree/cycle search plus bounded oscillator synchronization simulation; truth metric: Kuramoto order parameter and graph-isomorphism labeling.
- **Look (code only):** celestial musical diagrams pulsing along silver filaments; geometry: instanced ellipsoids and shader-tinted spline links; signature shader: 3D oscillatory curves become glowing star networks; Instanced line meshes, transient wave shells, acoustically inspired distance-field reveals; palette: star white, teal resonance and plum.
- **Content:** 100 solver-certified levels: the catalog in lines 15952–16057 is canonical (`python3 scripts/planning_index.py levels --experience R02-G13`); 80 acceptance scenarios in lines 16058–16143. The chapter header's earlier figure ("85 solver-certified stages") and its shorter manifests are milestones only.
- **Shared features used:** R02-F02, R02-F03, R02-F04, R02-F05, R02-F06, R02-F07, R02-F08, R02-F09, R02-F16, R02-F22, R02-F23, R02-F24, R02-F26; the remaining shared dependencies of the source are delivered by unified-app features (section 13).
- **Source:** `docs/archive/planning/rounds/round2.md` lines 15118–16212 (23 sections); assertion outline lines 30229–30293. Prompts: `python3 scripts/planning_index.py prompt --feature R02-G13-01 --override`.

### R02-G14 Moonlit Mechanism

`r02-g14.moonlit-mechanism` · free · category puzzle · family Shadow construction · score 93.73 · rank 14 · candidate G370 · features `R02-G14-01` … `R02-G14-10` (specs 431–440) · integration gate `X-R02-G14`

Rotate a clockwork machine until its combined moving shadows spell symbols.

- **Objective:** rotate interlocking gear assemblies so timed projected shadows spell designated geometric symbols. **Victory:** silhouettes match target frames at required tick samples. **Failure:** interlocking gears violate mesh phase constraints or occlude prohibited target area.
- **Controls:** turn a gear handle, adjust lamp height, scrub shadow sequence.
- **Model:** core abstraction clockwork shadow composition; state: angular phases constrained by integer tooth count; projected polygons transformed by light matrix and tested across key frames; fixed step 0.008333 s; solver: discretized phase search with gear ratio constraints and silhouette union metric; truth metric: angular relation error and target-mask overlap per frame.
- **Look (code only):** translucent clockwork casting moving ink shadows onto an illuminated paper wall; geometry: involute-inspired approximated gear outlines extruded procedurally; signature shader: interlocking shadow gears on a luminous paper wall; Procedural solids, CPU polygonal 3D shadow projections, soft shadow approximation; palette: aged gold, lunar blue and ink.
- **Content:** 100 solver-certified levels: the catalog in lines 17029–17134 is canonical (`python3 scripts/planning_index.py levels --experience R02-G14`); 80 acceptance scenarios in lines 17135–17220. The chapter header's earlier figure ("77 solver-certified stages") and its shorter manifests are milestones only.
- **Shared features used:** R02-F02, R02-F03, R02-F04, R02-F05, R02-F06, R02-F07, R02-F13, R02-F22, R02-F23, R02-F24, R02-F26; the remaining shared dependencies of the source are delivered by unified-app features (section 13).
- **Source:** `docs/archive/planning/rounds/round2.md` lines 16213–17289 (23 sections); assertion outline lines 30294–30358. Prompts: `python3 scripts/planning_index.py prompt --feature R02-G14-01 --override`.

### R02-G15 Voxel Origami

`r02-g15.voxel-origami` · free · category puzzle · family Spatial origami · score 93.7 · rank 15 · candidate G426 · features `R02-G15-01` … `R02-G15-10` (specs 441–450) · integration gate `X-R02-G15`

Reconfigure hinged voxels into a target solid without collisions.

- **Objective:** fold hinged cube nets into target solids without self-intersection. **Victory:** occupied voxel set matches target up to allowed global rotation. **Failure:** self-collision or disconnected hierarchy on a move.
- **Controls:** tap hinge, drag arc to discrete angle, rotate view with two fingers, undo.
- **Model:** core abstraction grid-connected hinged polycube folding; state: each cube occupies integer local lattice coordinates; hinge angle one of {0,90,180,270} degrees; tree hierarchy; reject interpenetrations; fixed step 0.008333 s; solver: A-star over hinge-angle lattice states with swept AABB collision filter; truth metric: collision-free occupancy and canonical polycube hash.
- **Look (code only):** chains of luminous cubes collapsing into radiant sculptural forms; geometry: instanced cubes with chamfered normals and hinge transform tree; signature shader: glowing cube nets morph into compact 3D sculptures; Reconfigurable polyhedral nets, articulated hinges, procedural faceted materials; palette: frosted ivory, laser turquoise and hot pink edge.
- **Content:** 100 solver-certified levels: the catalog in lines 18127–18232 is canonical (`python3 scripts/planning_index.py levels --experience R02-G15`); 80 acceptance scenarios in lines 18233–18318. The chapter header's earlier figure ("88 solver-certified stages") and its shorter manifests are milestones only.
- **Shared features used:** R02-F02, R02-F03, R02-F04, R02-F05, R02-F06, R02-F07, R02-F22, R02-F23, R02-F24, R02-F26; the remaining shared dependencies of the source are delivered by unified-app features (section 13).
- **Source:** `docs/archive/planning/rounds/round2.md` lines 17290–18387 (23 sections); assertion outline lines 30359–30423. Prompts: `python3 scripts/planning_index.py prompt --feature R02-G15-01 --override`.

### R02-G16 Starlit Cartouche

`r02-g16.starlit-cartouche` · free · category puzzle · family Celestial exploration · score 93.56 · rank 16 · candidate G355 · features `R02-G16-01` … `R02-G16-10` (specs 451–460) · integration gate `X-R02-G16`

Connect a moving starship route into a prescribed ancient symbol.

- **Objective:** navigate a ship through a moving 3D star chart to draw a target symbol with light trails. **Victory:** route graph draws correct symbol and reaches final beacon in time. **Failure:** route crosses hazard tube or violates node time window.
- **Controls:** tap route nodes to queue legs, drag time slider, preview gliding 3D route.
- **Model:** core abstraction symbolic route planning in moving starfields; state: ship transitions between node orbits on quantized launch ticks; completed trail projected into an authored glyph skeleton; fixed step 0.008333 s; solver: time-expanded graph search over navigable star corridors; truth metric: projected glyph skeleton mismatch and hazard clearance.
- **Look (code only):** sapphire ship leaving comet-calligraphy across a rotating firmament; geometry: procedural star spheres and motion-blurred polyline trails; signature shader: luminous paths across three-dimensional star charts; Procedural planets and ring systems, layered star spheres and emission shaders; palette: deep ultramarine, meteor gold and pearl.
- **Content:** 100 solver-certified levels: the catalog in lines 19212–19317 is canonical (`python3 scripts/planning_index.py levels --experience R02-G16`); 80 acceptance scenarios in lines 19318–19403. The chapter header's earlier figure ("80 solver-certified stages") and its shorter manifests are milestones only.
- **Shared features used:** R02-F02, R02-F03, R02-F04, R02-F05, R02-F06, R02-F07, R02-F08, R02-F14, R02-F15, R02-F22, R02-F23, R02-F24, R02-F26; the remaining shared dependencies of the source are delivered by unified-app features (section 13).
- **Source:** `docs/archive/planning/rounds/round2.md` lines 18388–19472 (23 sections); assertion outline lines 30424–30488. Prompts: `python3 scripts/planning_index.py prompt --feature R02-G16-01 --override`.

### R02-G17 Celestial Eclipse Lab

`r02-g17.celestial-eclipse-lab` · free · category puzzle · family Celestial exploration · score 93.43 · rank 17 · candidate G359 · features `R02-G17-01` … `R02-G17-10` (specs 461–470) · integration gate `X-R02-G17`

Position miniature orbits so sequential eclipses form a target sequence.

- **Objective:** position and phase miniature celestial orbits to create eclipses in a specified time order. **Victory:** target occultation labels occur in exact order within time windows. **Failure:** unwanted eclipse occurs before required eclipse.
- **Controls:** drag orbital handles, rotate time dial, step through predicted eclipse timeline.
- **Model:** core abstraction occultation sequence planning; state: discs projected from orbital positions; circle-circle overlap computed analytically, validate depth ordering to disambiguate occultations; fixed step 0.008333 s; solver: analytical circle/ellipse overlap interval enumeration and phase search; truth metric: ordered interval overlap timestamps and visibility classification.
- **Look (code only):** glowing planetary crescents eclipsing into razor-edge corona halos; geometry: analytic orbital rings, signed circle masks and eclipse glow shaders; signature shader: precise shadow crescents over glowing planetary discs; Procedural planets and ring systems, layered star spheres and emission shaders; palette: corona gold, ink navy and muted ember.
- **Content:** 100 solver-certified levels: the catalog in lines 20284–20389 is canonical (`python3 scripts/planning_index.py levels --experience R02-G17`); 80 acceptance scenarios in lines 20390–20475. The chapter header's earlier figure ("74 solver-certified stages") and its shorter manifests are milestones only.
- **Shared features used:** R02-F02, R02-F03, R02-F04, R02-F05, R02-F06, R02-F07, R02-F13, R02-F15, R02-F22, R02-F23, R02-F24, R02-F26; the remaining shared dependencies of the source are delivered by unified-app features (section 13).
- **Source:** `docs/archive/planning/rounds/round2.md` lines 19473–20544 (23 sections); assertion outline lines 30489–30553. Prompts: `python3 scripts/planning_index.py prompt --feature R02-G17-01 --override`.

### R02-G18 Apsides Workshop

`r02-g18.apsides-workshop` · free · category puzzle · family Orbital dynamics · score 93.14 · rank 18 · candidate G254 · features `R02-G18-01` … `R02-G18-10` (specs 471–480) · integration gate `X-R02-G18`

Tune orbital eccentricity to sweep precise regions of a miniature sky.

- **Objective:** tune eccentricity, orientation and apsides so an orbiter sweeps a sequence of prescribed sky sectors. **Victory:** required area bins and apsis targets satisfied in order. **Failure:** orbit intersects an exclusion planet or fails target area tolerance.
- **Controls:** drag periapsis knob and semi-major axis, turn time crank, play orbit.
- **Model:** core abstraction analytical conic orbital tuning; state: M=E-e*sin(E); solve bounded Newton with bisection fallback; r=a(1-e*cos E); area swept via quadrature; fixed step 0.008333 s; solver: bounded numeric search over eccentricity/orientation samples using Kepler anomaly inversion; truth metric: Kepler residual and swept-area deviation.
- **Look (code only):** cosmic compass with loops of luminescent elliptical epicycles; geometry: adaptive analytic ellipse tessellation; signature shader: celestial paths trace luminous ellipses at varying depths; Numerical gravitation in fixed steps, analytic orbit curves, procedural planets and starfields; palette: glacial white, deep rose and midnight.
- **Content:** 100 solver-certified levels: the catalog in lines 21364–21469 is canonical (`python3 scripts/planning_index.py levels --experience R02-G18`); 80 acceptance scenarios in lines 21470–21555. The chapter header's earlier figure ("78 solver-certified stages") and its shorter manifests are milestones only.
- **Shared features used:** R02-F02, R02-F03, R02-F04, R02-F05, R02-F06, R02-F07, R02-F08, R02-F15, R02-F22, R02-F23, R02-F24, R02-F26; the remaining shared dependencies of the source are delivered by unified-app features (section 13).
- **Source:** `docs/archive/planning/rounds/round2.md` lines 20545–21624 (23 sections); assertion outline lines 30554–30618. Prompts: `python3 scripts/planning_index.py prompt --feature R02-G18-01 --override`.

### R02-G19 Microscopic Aurora

`r02-g19.microscopic-aurora` · free · category puzzle · family Micro ecosystems · score 93.06 · rank 19 · candidate G415 · features `R02-G19-01` … `R02-G19-10` (specs 481–490) · integration gate `X-R02-G19`

Manipulate magnetic swimmers to build a glowing bacterial pattern.

- **Objective:** control a small field of magnetic swimmers so their luminous trails compose target living patterns. **Victory:** trailing density occupies target stencil with sufficient connectedness. **Failure:** swarm exits enclosure or destroys required coherence.
- **Controls:** drag up to three magnetic wells, scrub speed, tap freeze field.
- **Model:** core abstraction deterministic magnetic boid swarms; state: boids use bounded separation/alignment/cohesion accelerations plus magnetic curl field; stable fixed-step integration; fixed step 0.008333 s; solver: low-dimensional field strength search with seeded boid simulator and shape-loss evaluation; truth metric: swarm density distribution and pattern connectivity.
- **Look (code only):** bioluminescent protozoa making aurora-like ribbons under a microscope; geometry: instanced tapered capsules, deterministic ribbon trails; signature shader: slender luminous boids form wave-like living ribbons; L-system miniature flora, deterministic boids, bioluminescence and simple water planes; palette: sea glass green, heliotrope, white.
- **Content:** 100 solver-certified levels: the catalog in lines 22452–22557 is canonical (`python3 scripts/planning_index.py levels --experience R02-G19`); 80 acceptance scenarios in lines 22558–22643. The chapter header's earlier figure ("82 solver-certified stages") and its shorter manifests are milestones only.
- **Shared features used:** R02-F02, R02-F03, R02-F04, R02-F05, R02-F06, R02-F07, R02-F09, R02-F20, R02-F22, R02-F23, R02-F24, R02-F26; the remaining shared dependencies of the source are delivered by unified-app features (section 13).
- **Source:** `docs/archive/planning/rounds/round2.md` lines 21625–22712 (23 sections); assertion outline lines 30619–30683. Prompts: `python3 scripts/planning_index.py prompt --feature R02-G19-01 --override`.

### R02-G20 Mushroom Weather

`r02-g20.mushroom-weather` · free · category puzzle · family Micro ecosystems · score 93.04 · rank 20 · candidate G414 · features `R02-G20-01` … `R02-G20-10` (specs 491–500) · integration gate `X-R02-G20`

Arrange fungi to create a stable forest humidity network.

- **Objective:** arrange fungi and adjust microclimate to maintain stable humidity lanes between mushroom colonies. **Victory:** all target colonies sustain preferred humidity band for T cycles. **Failure:** sensitive colony dries out or mold saturation exceeds upper bound.
- **Controls:** drag spore pods, open or close canopy vents, shift moonlight intensity.
- **Model:** core abstraction localized moisture diffusion and growth; state: humidity_{t+1}=humidity_t+D*laplacian*dt - evaporation + release; growth triggered by time-integrated thresholds; fixed step 0.016667 s; solver: grid diffusion with bounded evapotranspiration and reachability checks; truth metric: humidity conservation with source/sink ledger and colony survival intervals.
- **Look (code only):** glowing umbrella caps breathing droplets into a midnight miniature forest; geometry: procedural lathed stalks and SDF mushroom caps; signature shader: translucent mushroom caps sparkle with moisture gradients; L-system miniature flora, deterministic boids, bioluminescence and simple water planes; palette: fern jade, amber spores and deep blue.
- **Content:** 100 solver-certified levels: the catalog in lines 23529–23634 is canonical (`python3 scripts/planning_index.py levels --experience R02-G20`); 80 acceptance scenarios in lines 23635–23720. The chapter header's earlier figure ("76 solver-certified stages") and its shorter manifests are milestones only.
- **Shared features used:** R02-F02, R02-F03, R02-F04, R02-F05, R02-F06, R02-F07, R02-F19, R02-F20, R02-F21, R02-F22, R02-F23, R02-F24, R02-F26; the remaining shared dependencies of the source are delivered by unified-app features (section 13).
- **Source:** `docs/archive/planning/rounds/round2.md` lines 22713–23789 (23 sections); assertion outline lines 30684–30748. Prompts: `python3 scripts/planning_index.py prompt --feature R02-G20-01 --override`.

### R02-G21 Binary Gardens

`r02-g21.binary-gardens` · free · category puzzle · family Orbital dynamics · score 93.0 · rank 21 · candidate G249 · features `R02-G21-01` … `R02-G21-10` (specs 501–510) · integration gate `X-R02-G21`

Balance twin stars to keep orbiting flower worlds within a light zone.

- **Objective:** adjust two stellar orbits to maintain tiny garden planets inside a moving illumination window. **Victory:** each garden world has stable illumination window across a full cycle. **Failure:** world receives lethal low/high flux for too many ticks.
- **Controls:** drag star distance rings, tilt orbit plane, inspect each miniature world.
- **Model:** core abstraction toy circumbinary habitability simulation; state: approximate flux=sum luminosity_i/max(r_i^2,r_min^2); orbit curves analytic; plants respond to integrated flux bands; fixed step 0.008333 s; solver: bounded coupled-orbit parameter sweep with sampling of received flux; truth metric: per-world integrated normalized flux and survival.
- **Look (code only):** two suns painting crossing sunrise bands over tiny flowering spheres; geometry: cube-sphere planet mesh and shader-only seasonal banding; signature shader: twin light discs and procedural luminous planet ecologies; Numerical gravitation in fixed steps, analytic orbit curves, procedural planets and starfields; palette: warm vermilion, ice blue and mint world.
- **Content:** 100 solver-certified levels: the catalog in lines 24616–24721 is canonical (`python3 scripts/planning_index.py levels --experience R02-G21`); 80 acceptance scenarios in lines 24722–24807. The chapter header's earlier figure ("81 solver-certified stages") and its shorter manifests are milestones only.
- **Shared features used:** R02-F02, R02-F03, R02-F04, R02-F05, R02-F06, R02-F07, R02-F15, R02-F19, R02-F21, R02-F22, R02-F23, R02-F24, R02-F26; the remaining shared dependencies of the source are delivered by unified-app features (section 13).
- **Source:** `docs/archive/planning/rounds/round2.md` lines 23790–24876 (23 sections); assertion outline lines 30749–30813. Prompts: `python3 scripts/planning_index.py prompt --feature R02-G21-01 --override`.

### R02-G22 Mycelium Architect

`r02-g22.mycelium-architect` · free · category puzzle · family Organic growth · score 92.91 · rank 22 · candidate G276 · features `R02-G22-01` … `R02-G22-10` (specs 511–520) · integration gate `X-R02-G22`

Feed fungal networks so glowing veins form a target graph around rocks.

- **Objective:** feed nutrient sources so living luminous fungal veins grow into a specified network without crossing toxins. **Victory:** required terminals connected with at most specified branch weight. **Failure:** network enters toxic volume or exceeds nutrient budget.
- **Controls:** place nutrients and blockers, advance growth pulses, undo edits.
- **Model:** core abstraction branching graph flow optimization; state: each tip chooses max nutrient-gradient direction minus curvature and obstacle penalties; graph cap 2048 nodes; fixed step 0.016667 s; solver: graph shortest path plus deterministic branching-growth heuristic and target topology check; truth metric: root-to-terminal connectivity, total branch cost and forbidden-zone hits.
- **Look (code only):** organic veins pulsing like a starlit subterranean city; geometry: instanced tapered cylinder branch segments and procedural cap mushrooms; signature shader: recursive hyphae bloom under translucent luminous caps; Recursive L-systems, instanced leaves, flow network evolution and bioluminescent materials; palette: emerald, copper and violet roots.
- **Content:** 100 solver-certified levels: the catalog in lines 25709–25814 is canonical (`python3 scripts/planning_index.py levels --experience R02-G22`); 80 acceptance scenarios in lines 25815–25900. The chapter header's earlier figure ("84 solver-certified stages") and its shorter manifests are milestones only.
- **Shared features used:** R02-F02, R02-F03, R02-F04, R02-F05, R02-F06, R02-F07, R02-F16, R02-F19, R02-F21, R02-F22, R02-F23, R02-F24, R02-F26; the remaining shared dependencies of the source are delivered by unified-app features (section 13).
- **Source:** `docs/archive/planning/rounds/round2.md` lines 24877–25969 (23 sections); assertion outline lines 30814–30878. Prompts: `python3 scripts/planning_index.py prompt --feature R02-G22-01 --override`.

### R02-G23 Erosion Painter

`r02-g23.erosion-painter` · free · category puzzle · family Terrain alchemy · score 92.9 · rank 23 · candidate G321 · features `R02-G23-01` … `R02-G23-10` (specs 521–530) · integration gate `X-R02-G23`

Raise and lower terrain to coax rain into carving a target canyon.

- **Objective:** sculpt hills and rainfall patterns until erosion carves a prescribed canyon network. **Victory:** drainage graph and canyon height profile match target within tolerances. **Failure:** protected ridges disappear or target region floods.
- **Controls:** brush height with two-finger scale, tap cloud cells, run/pause epochs.
- **Model:** core abstraction heightfield erosion with capped sediment flow; state: water flux obeys local downhill differences; erode min(k*flow, sediment capacity); deposition restores sediment; clamps conserve material ledger; fixed step 0.016667 s; solver: iterative heightfield transport with deterministic hydraulic approximations and seed replay; truth metric: mass ledger terrain+sediment and outlet graph.
- **Look (code only):** mesas dissolving into shining rivulets under spectacular algorithmic weather; geometry: adaptive tessellated heightfield and flowing shader streaks; signature shader: procedural heightfields channel glowing water and sediment; Deterministic heightfields, erosion approximation, instanced scenery and raster-free sky; palette: sunset vermilion, turquoise rain and violet shadow.
- **Content:** 100 solver-certified levels: the catalog in lines 26785–26890 is canonical (`python3 scripts/planning_index.py levels --experience R02-G23`); 80 acceptance scenarios in lines 26891–26976. The chapter header's earlier figure ("76 solver-certified stages") and its shorter manifests are milestones only.
- **Shared features used:** R02-F02, R02-F03, R02-F04, R02-F05, R02-F06, R02-F07, R02-F17, R02-F18, R02-F22, R02-F23, R02-F24, R02-F26; the remaining shared dependencies of the source are delivered by unified-app features (section 13).
- **Source:** `docs/archive/planning/rounds/round2.md` lines 25970–27045 (23 sections); assertion outline lines 30879–30943. Prompts: `python3 scripts/planning_index.py prompt --feature R02-G23-01 --override`.

### R02-G24 Crystal Quarry

`r02-g24.crystal-quarry` · free · category puzzle · family Terrain alchemy · score 92.9 · rank 24 · candidate G334 · features `R02-G24-01` … `R02-G24-10` (specs 531–540) · integration gate `X-R02-G24`

Choose fracture paths to reveal a target gem network in rock.

- **Objective:** choose break lines to expose a hidden gem network in a procedural rock body. **Victory:** all target seam nodes exposed with host rock stability preserved. **Failure:** critical gem is destroyed or energy limit reached.
- **Controls:** drag guided cleavage stroke, tap inspect mineral glow, rotate core.
- **Model:** core abstraction terrain-contained voxel fracture network; state: rock consists of bounded convex chunks from deterministic Voronoi seeds; split along known planes, not dynamic brittle FEM; fixed step 0.008333 s; solver: seeded lattice graph with cut-set path planning and exposed target constraints; truth metric: reachable exposed seam count and stable chunk adjacency.
- **Look (code only):** black slate parting to show incandescent crystalline constellations; geometry: deterministic Voronoi chunk meshes with internal seam shader; signature shader: glowing mineral seams emerge through geometric stone fractures; Deterministic heightfields, erosion approximation, instanced scenery and raster-free sky; palette: slate obsidian, emerald and molten rose.
- **Content:** 100 solver-certified levels: the catalog in lines 27883–27988 is canonical (`python3 scripts/planning_index.py levels --experience R02-G24`); 80 acceptance scenarios in lines 27989–28074. The chapter header's earlier figure ("86 solver-certified stages") and its shorter manifests are milestones only.
- **Shared features used:** R02-F02, R02-F03, R02-F04, R02-F05, R02-F06, R02-F07, R02-F11, R02-F12, R02-F16, R02-F18, R02-F22, R02-F23, R02-F24, R02-F26; the remaining shared dependencies of the source are delivered by unified-app features (section 13).
- **Source:** `docs/archive/planning/rounds/round2.md` lines 27046–28143 (23 sections); assertion outline lines 30944–31008. Prompts: `python3 scripts/planning_index.py prompt --feature R02-G24-01 --override`.

### R02-G25 Starlight Surveyors

`r02-g25.starlight-surveyors` · free · category puzzle · family Cosmic puzzles · score 92.84 · rank 25 · candidate G122 · features `R02-G25-01` … `R02-G25-10` (specs 541–550) · integration gate `X-R02-G25`

Rotate a 3D observatory until starlight aligns through viewports.

- **Objective:** rotate a three-axis observatory until projected star rays align through multiple lens apertures. **Victory:** all designated rays intersect their required lenses in correct sequence. **Failure:** a required ray passes outside a viewport on a checkpoint tick.
- **Controls:** drag gimbals, pinch zoom lens, tap lock orientation.
- **Model:** core abstraction perspective projection alignment; state: camera basis R=RzRyRx; project each star into a normalized pinhole viewport with stable near-plane constraints; fixed step 0.008333 s; solver: finite camera-angle/target quantization search and analytic projective ray intersection; truth metric: reprojection residual and aperture intersection errors.
- **Look (code only):** geometric constellations crystallizing into a radiant planetary instrument; geometry: procedural star sprites as points, gimbal meshes and ray tubes; signature shader: Parametric star volumes, glowing triangulation rays and projection-matched constellations; palette: deep ink, pearl rays and gold gears.
- **Content:** 100 solver-certified levels: the catalog in lines 28970–29075 is canonical (`python3 scripts/planning_index.py levels --experience R02-G25`); 80 acceptance scenarios in lines 29076–29161. The chapter header's earlier figure ("82 solver-certified stages") and its shorter manifests are milestones only.
- **Shared features used:** R02-F02, R02-F03, R02-F04, R02-F05, R02-F06, R02-F07, R02-F09, R02-F22, R02-F23, R02-F24, R02-F26; the remaining shared dependencies of the source are delivered by unified-app features (section 13).
- **Source:** `docs/archive/planning/rounds/round2.md` lines 28144–29230 (23 sections); assertion outline lines 31009–31073. Prompts: `python3 scripts/planning_index.py prompt --feature R02-G25-01 --override`.
<!-- GENERATED:END cards-round02 -->

## 9. Premium library: Rounds 3 and 4

Rounds 3 and 4 hold the first 50 of the remaining candidates in descending score order
(`docs/brainstorm/round3-to-round12-selection.csv`). They come from the same scoring matrix as Round 2. Because
Round 2 was limited to two games per family, some games of Rounds 3 and 4 score higher than some Round 2 games;
the queue is the source's and is not rearranged. The games open with the single purchase. Their chapters share
one structure: identity and non-goals, exact state and rules, first-session storyboard, renderer
recipe, content and progression, file inventory, prompts, a manifest of 100 levels, 80 acceptance scenarios, a
fault-injection matrix, and a hardware plan.

Work on the premium library starts after the free library is locked and the purchase feature (UA-F08) is sealed.
Every game of Rounds 3 to 12 is built from the same ten features:

<!-- GENERATED:BEGIN game-features-rounds03-12 -->
| # | Feature | Requirement in the source | Reading in the single app |
|---:|---|---|---|
| 01 | Domain rules & normalized action contract | Implement exact game state, action sanitization, illegal move failures and win predicates; no renderer-owned truth | unchanged |
| 02 | Deterministic solver, proof and replay | Make solver produce machine-checkable win witness and rejection cases; replay hash equal across process launches | unchanged |
| 03 | Procedural level compiler and authored curriculum | Implement seeded generation, difficulty bands, uniqueness/reachability checks and 96- or 100-level complete catalog | unchanged; 100 levels |
| 04 | Procedural geometry scene compiler | Generate all mesh geometry in code with bounded vertices, manifold rules and context ownership | unchanged |
| 05 | GLSL lighting and post-processing visual signature | Implement original GLSL ES shader pipeline, real renderer hero scenes, safe bloom, adaptive visual quality | unchanged |
| 06 | Touch and spatial interaction | Implement tap, drag, depth picking, undo, camera orbit and keyboard/assistive alternatives | unchanged |
| 07 | Onboarding, progression and accessibility | Build multi-step tutorial, level selection, reliable feedback, reduce flashing, color-independent clues | unchanged |
| 08 | Persistence, privacy and offline paid completion | Version profiles, local save and migration; no ads, IAP, subscriptions, image-model dependency or mandatory network | storage through the experience context (UA-F05); "paid completion" is the shared premium entitlement (UA-F08), never a purchase inside the game |
| 09 | Unit, integration, simulator and shader regression | Make native app compile on all supported simulators, test real game states, generate goldens and capture evidence | one app: the experience compiles in the unified app and passes its scenario set on both simulator runtimes |
| 10 | Implementation lock and device-ready production packaging | XcodeGen target integration, automation-only signed build, manifests, artifact hashing and no fabricated device success | no per-game target or signed build: register the experience, hash its manifests, define its device row (UA-F12, UA-F13) |
<!-- GENERATED:END game-features-rounds03-12 -->

### 9.1 Round 3

<!-- GENERATED:BEGIN cards-round03 -->
### R03-G01 Harmonic Helix

`r03-g01.harmonic-helix` · premium · category puzzle · family Wave mathematics · score 94.18 · rank 5 · candidate G459 · features `R03-G01-01` … `R03-G01-10` (`specs/r03-g01-01-* … -10-*`) · integration gate `X-R03-G01`

Adjust phase offsets so three spirals touch fixed target rings.

- **Win:** a sampled curve must visit target waypoints in order while avoiding forbidden volumes. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Tune harmonics and phase to achieve a target three-dimensional pattern.
- **Model:** core abstraction harmonic field; state: u(t)=Σ A_i sin(ω_i t+φ_i) and 3D path sampling; quantize ω_i ratios and phases; solver: bounded integer-frequency enumeration + adaptive swept-segment collision; numeric risks: phase wrapping, singular derivative, aliased camera under grazing views.
- **Look (code only):** spinning luminous helices form a suspended braid; Analytic oscillators, Fourier curve meshes, interference heightfields and emissive color; geometry: parallel-transport ribbons, interference color and normal-based emission.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 1920–2023, scenarios in lines 2024–2107, fault injection in lines 2108–2160); golden seed `bae47f3d5665`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round3.md` lines 1103–2167 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R03-G01`; assertion outline lines 27730–27759. Prompts: `python3 scripts/planning_index.py prompt --feature R03-G01-01 --override`.

### R03-G02 Ripple Clockwork

`r03-g02.ripple-clockwork` · premium · category puzzle · family Wave mathematics · score 94.17 · rank 6 · candidate G461 · features `R03-G02-01` … `R03-G02-10` (`specs/r03-g02-01-* … -10-*`) · integration gate `X-R03-G02`

Synchronize circular waves so particles hit target nodes at exact times.

- **Win:** a sampled curve must visit target waypoints in order while avoiding forbidden volumes. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Tune harmonics and phase to achieve a target three-dimensional pattern.
- **Model:** core abstraction harmonic field; state: u(t)=Σ A_i sin(ω_i t+φ_i) and 3D path sampling; quantize ω_i ratios and phases; solver: bounded integer-frequency enumeration + adaptive swept-segment collision; numeric risks: phase wrapping, singular derivative, aliased camera under grazing views.
- **Look (code only):** nested spectral ripples cross floating gear rings; Analytic oscillators, Fourier curve meshes, interference heightfields and emissive color; geometry: parallel-transport ribbons, interference color and normal-based emission.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 2985–3088, scenarios in lines 3089–3172, fault injection in lines 3173–3225); golden seed `506c8d52fb34`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round3.md` lines 2168–3232 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R03-G02`; assertion outline lines 27760–27789. Prompts: `python3 scripts/planning_index.py prompt --feature R03-G02-01 --override`.

### R03-G03 Prism Symphony

`r03-g03.prism-symphony` · premium · category puzzle · family Chromatic logic · score 94.1 · rank 8 · candidate G401 · features `R03-G03-01` … `R03-G03-10` (`specs/r03-g03-01-* … -10-*`) · integration gate `X-R03-G03`

Combine three color waveforms into a target spatial chord.

- **Win:** satisfy a target spectral pattern subject to unique-neighbor exclusion constraints. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Match spectral state in 3D without conflicting colors.
- **Model:** core abstraction spectral constraint grid; state: discrete hue index h in Z_12; edge transfer h_next=(h+δ) mod 12; secondary glyph code; solver: constraint propagation + backtracking with uniqueness proof; numeric risks: accessibility, near-similar hues, fake additive mixing rules.
- **Look (code only):** rotating spectral wave tubes and rhythmic animated glow; GLSL hue transforms, procedural glass polygons, spline light tubes and glow; geometry: GLSL color wheel, translucent solids and emissive edge tubes.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 4050–4153, scenarios in lines 4154–4237, fault injection in lines 4238–4290); golden seed `63a2b8d85734`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round3.md` lines 3233–4297 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R03-G03`; assertion outline lines 27790–27819. Prompts: `python3 scripts/planning_index.py prompt --feature R03-G03-01 --override`.

### R03-G04 Harmonic Archipelago

`r03-g04.harmonic-archipelago` · premium · category puzzle · family Wave mathematics · score 94.07 · rank 9 · candidate G465 · features `R03-G04-01` … `R03-G04-10` (`specs/r03-g04-01-* … -10-*`) · integration gate `X-R03-G04`

Tune waves across floating islands to build temporary bridges.

- **Win:** a sampled curve must visit target waypoints in order while avoiding forbidden volumes. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Tune harmonics and phase to achieve a target three-dimensional pattern.
- **Model:** core abstraction harmonic field; state: u(t)=Σ A_i sin(ω_i t+φ_i) and 3D path sampling; quantize ω_i ratios and phases; solver: bounded integer-frequency enumeration + adaptive swept-segment collision; numeric risks: phase wrapping, singular derivative, aliased camera under grazing views.
- **Look (code only):** glowing wave membranes form ephemeral walkways; Analytic oscillators, Fourier curve meshes, interference heightfields and emissive color; geometry: parallel-transport ribbons, interference color and normal-based emission.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 5115–5218, scenarios in lines 5219–5302, fault injection in lines 5303–5355); golden seed `8d4a4d38325e`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round3.md` lines 4298–5362 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R03-G04`; assertion outline lines 27820–27849. Prompts: `python3 scripts/planning_index.py prompt --feature R03-G04-01 --override`.

### R03-G05 Color Alchemy Spires

`r03-g05.color-alchemy-spires` · premium · category puzzle · family Chromatic logic · score 94.07 · rank 10 · candidate G396 · features `R03-G05-01` … `R03-G05-10` (`specs/r03-g05-01-* … -10-*`) · integration gate `X-R03-G05`

Stack color-transforming towers to turn incoming beams into a target spectrum.

- **Win:** satisfy a target spectral pattern subject to unique-neighbor exclusion constraints. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Match spectral state in 3D without conflicting colors.
- **Model:** core abstraction spectral constraint grid; state: discrete hue index h in Z_12; edge transfer h_next=(h+δ) mod 12; secondary glyph code; solver: constraint propagation + backtracking with uniqueness proof; numeric risks: accessibility, near-similar hues, fake additive mixing rules.
- **Look (code only):** luminous radial gradients and faceted glass spires; GLSL hue transforms, procedural glass polygons, spline light tubes and glow; geometry: GLSL color wheel, translucent solids and emissive edge tubes.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 6180–6283, scenarios in lines 6284–6367, fault injection in lines 6368–6420); golden seed `3a3459ae096a`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round3.md` lines 5363–6427 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R03-G05`; assertion outline lines 27850–27879. Prompts: `python3 scripts/planning_index.py prompt --feature R03-G05-01 --override`.

### R03-G06 Gradient Locksmith

`r03-g06.gradient-locksmith` · premium · category puzzle · family Chromatic logic · score 94.07 · rank 11 · candidate G397 · features `R03-G06-01` … `R03-G06-10` (`specs/r03-g06-01-* … -10-*`) · integration gate `X-R03-G06`

Rotate color wheels around a 3D lock until matching hues align.

- **Win:** satisfy a target spectral pattern subject to unique-neighbor exclusion constraints. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Match spectral state in 3D without conflicting colors.
- **Model:** core abstraction spectral constraint grid; state: discrete hue index h in Z_12; edge transfer h_next=(h+δ) mod 12; secondary glyph code; solver: constraint propagation + backtracking with uniqueness proof; numeric risks: accessibility, near-similar hues, fake additive mixing rules.
- **Look (code only):** iridescent concentric tori and saturated light rings; GLSL hue transforms, procedural glass polygons, spline light tubes and glow; geometry: GLSL color wheel, translucent solids and emissive edge tubes.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 7245–7348, scenarios in lines 7349–7432, fault injection in lines 7433–7485); golden seed `e367736dd077`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round3.md` lines 6428–7492 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R03-G06`; assertion outline lines 27880–27909. Prompts: `python3 scripts/planning_index.py prompt --feature R03-G06-01 --override`.

### R03-G07 Bessel Fountain

`r03-g07.bessel-fountain` · premium · category puzzle · family Wave mathematics · score 94.06 · rank 12 · candidate G467 · features `R03-G07-01` … `R03-G07-10` (`specs/r03-g07-01-* … -10-*`) · integration gate `X-R03-G07`

Choose radial wave modes that raise a fountain into a target sculpture.

- **Win:** a sampled curve must visit target waypoints in order while avoiding forbidden volumes. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Tune harmonics and phase to achieve a target three-dimensional pattern.
- **Model:** core abstraction harmonic field; state: u(t)=Σ A_i sin(ω_i t+φ_i) and 3D path sampling; quantize ω_i ratios and phases; solver: bounded integer-frequency enumeration + adaptive swept-segment collision; numeric risks: phase wrapping, singular derivative, aliased camera under grazing views.
- **Look (code only):** concentric liquid-looking waves form a glowing tower; Analytic oscillators, Fourier curve meshes, interference heightfields and emissive color; geometry: parallel-transport ribbons, interference color and normal-based emission.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 8310–8413, scenarios in lines 8414–8497, fault injection in lines 8498–8550); golden seed `0959d641f3bd`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round3.md` lines 7493–8557 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R03-G07`; assertion outline lines 27910–27939. Prompts: `python3 scripts/planning_index.py prompt --feature R03-G07-01 --override`.

### R03-G08 Phase Prism

`r03-g08.phase-prism` · premium · category puzzle · family Wave mathematics · score 94.06 · rank 13 · candidate G464 · features `R03-G08-01` … `R03-G08-10` (`specs/r03-g08-01-* … -10-*`) · integration gate `X-R03-G08`

Route coherent light packets through wave-splitting chambers.

- **Win:** a sampled curve must visit target waypoints in order while avoiding forbidden volumes. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Tune harmonics and phase to achieve a target three-dimensional pattern.
- **Model:** core abstraction harmonic field; state: u(t)=Σ A_i sin(ω_i t+φ_i) and 3D path sampling; quantize ω_i ratios and phases; solver: bounded integer-frequency enumeration + adaptive swept-segment collision; numeric risks: phase wrapping, singular derivative, aliased camera under grazing views.
- **Look (code only):** interference beads light up along crystal facets; Analytic oscillators, Fourier curve meshes, interference heightfields and emissive color; geometry: parallel-transport ribbons, interference color and normal-based emission.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 9375–9478, scenarios in lines 9479–9562, fault injection in lines 9563–9615); golden seed `e70d5c960d47`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round3.md` lines 8558–9622 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R03-G08`; assertion outline lines 27940–27969. Prompts: `python3 scripts/planning_index.py prompt --feature R03-G08-01 --override`.

### R03-G09 Polar Waveglass

`r03-g09.polar-waveglass` · premium · category puzzle · family Wave mathematics · score 94.06 · rank 14 · candidate G470 · features `R03-G09-01` … `R03-G09-10` (`specs/r03-g09-01-* … -10-*`) · integration gate `X-R03-G09`

Tune radial and angular wave modes to turn a disk into an iris pattern.

- **Win:** a sampled curve must visit target waypoints in order while avoiding forbidden volumes. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Tune harmonics and phase to achieve a target three-dimensional pattern.
- **Model:** core abstraction harmonic field; state: u(t)=Σ A_i sin(ω_i t+φ_i) and 3D path sampling; quantize ω_i ratios and phases; solver: bounded integer-frequency enumeration + adaptive swept-segment collision; numeric risks: phase wrapping, singular derivative, aliased camera under grazing views.
- **Look (code only):** brilliant glasslike polar waves bloom into petal geometry; Analytic oscillators, Fourier curve meshes, interference heightfields and emissive color; geometry: parallel-transport ribbons, interference color and normal-based emission.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 10440–10543, scenarios in lines 10544–10627, fault injection in lines 10628–10680); golden seed `d4ee0bf798a3`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round3.md` lines 9623–10687 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R03-G09`; assertion outline lines 27970–27999. Prompts: `python3 scripts/planning_index.py prompt --feature R03-G09-01 --override`.

### R03-G10 Standing Wave Garden

`r03-g10.standing-wave-garden` · premium · category puzzle · family Wave mathematics · score 94.0 · rank 16 · candidate G458 · features `R03-G10-01` … `R03-G10-10` (`specs/r03-g10-01-* … -10-*`) · integration gate `X-R03-G10`

Change boundary lengths so growing peaks lift tiny seeds into sockets.

- **Win:** a sampled curve must visit target waypoints in order while avoiding forbidden volumes. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Tune harmonics and phase to achieve a target three-dimensional pattern.
- **Model:** core abstraction harmonic field; state: u(t)=Σ A_i sin(ω_i t+φ_i) and 3D path sampling; quantize ω_i ratios and phases; solver: bounded integer-frequency enumeration + adaptive swept-segment collision; numeric risks: phase wrapping, singular derivative, aliased camera under grazing views.
- **Look (code only):** rippling 3D membrane meshes and glowing resonant crest lines; Analytic oscillators, Fourier curve meshes, interference heightfields and emissive color; geometry: parallel-transport ribbons, interference color and normal-based emission.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 11505–11608, scenarios in lines 11609–11692, fault injection in lines 11693–11745); golden seed `88a14c4016de`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round3.md` lines 10688–11752 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R03-G10`; assertion outline lines 28000–28029. Prompts: `python3 scripts/planning_index.py prompt --feature R03-G10-01 --override`.

### R03-G11 Sinewave Sculptor

`r03-g11.sinewave-sculptor` · premium · category puzzle · family Wave mathematics · score 94.0 · rank 17 · candidate G462 · features `R03-G11-01` … `R03-G11-10` (`specs/r03-g11-01-* … -10-*`) · integration gate `X-R03-G11`

Add harmonics to shape a luminous loop into a specified silhouette.

- **Win:** a sampled curve must visit target waypoints in order while avoiding forbidden volumes. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Tune harmonics and phase to achieve a target three-dimensional pattern.
- **Model:** core abstraction harmonic field; state: u(t)=Σ A_i sin(ω_i t+φ_i) and 3D path sampling; quantize ω_i ratios and phases; solver: bounded integer-frequency enumeration + adaptive swept-segment collision; numeric risks: phase wrapping, singular derivative, aliased camera under grazing views.
- **Look (code only):** smooth 3D Fourier curves evolve like molten jewelry; Analytic oscillators, Fourier curve meshes, interference heightfields and emissive color; geometry: parallel-transport ribbons, interference color and normal-based emission.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 12570–12673, scenarios in lines 12674–12757, fault injection in lines 12758–12810); golden seed `1c24ecd155b9`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round3.md` lines 11753–12817 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R03-G11`; assertion outline lines 28030–28059. Prompts: `python3 scripts/planning_index.py prompt --feature R03-G11-01 --override`.

### R03-G12 Neon Mosaic Route

`r03-g12.neon-mosaic-route` · premium · category puzzle · family Chromatic logic · score 93.97 · rank 20 · candidate G399 · features `R03-G12-01` … `R03-G12-10` (`specs/r03-g12-01-* … -10-*`) · integration gate `X-R03-G12`

Move translucent tiles so a color wave traverses every square once.

- **Win:** satisfy a target spectral pattern subject to unique-neighbor exclusion constraints. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Match spectral state in 3D without conflicting colors.
- **Model:** core abstraction spectral constraint grid; state: discrete hue index h in Z_12; edge transfer h_next=(h+δ) mod 12; secondary glyph code; solver: constraint propagation + backtracking with uniqueness proof; numeric risks: accessibility, near-similar hues, fake additive mixing rules.
- **Look (code only):** glowing glass tiles light in a cascading chain; GLSL hue transforms, procedural glass polygons, spline light tubes and glow; geometry: GLSL color wheel, translucent solids and emissive edge tubes.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 13635–13738, scenarios in lines 13739–13822, fault injection in lines 13823–13875); golden seed `835a4d9dbe83`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round3.md` lines 12818–13882 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R03-G12`; assertion outline lines 28060–28089. Prompts: `python3 scripts/planning_index.py prompt --feature R03-G12-01 --override`.

### R03-G13 Spectrum Garden

`r03-g13.spectrum-garden` · premium · category puzzle · family Chromatic logic · score 93.97 · rank 21 · candidate G407 · features `R03-G13-01` … `R03-G13-10` (`specs/r03-g13-01-* … -10-*`) · integration gate `X-R03-G13`

Balance light wavelengths to make responsive flowers bloom in a pattern.

- **Win:** satisfy a target spectral pattern subject to unique-neighbor exclusion constraints. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Match spectral state in 3D without conflicting colors.
- **Model:** core abstraction spectral constraint grid; state: discrete hue index h in Z_12; edge transfer h_next=(h+δ) mod 12; secondary glyph code; solver: constraint propagation + backtracking with uniqueness proof; numeric risks: accessibility, near-similar hues, fake additive mixing rules.
- **Look (code only):** colored petal geometry and lens-flare-like bloom; GLSL hue transforms, procedural glass polygons, spline light tubes and glow; geometry: GLSL color wheel, translucent solids and emissive edge tubes.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 14700–14803, scenarios in lines 14804–14887, fault injection in lines 14888–14940); golden seed `599996756323`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round3.md` lines 13883–14947 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R03-G13`; assertion outline lines 28090–28119. Prompts: `python3 scripts/planning_index.py prompt --feature R03-G13-01 --override`.

### R03-G14 Surface Sonata

`r03-g14.surface-sonata` · premium · category puzzle · family Wave mathematics · score 93.95 · rank 24 · candidate G463 · features `R03-G14-01` … `R03-G14-10` (`specs/r03-g14-01-* … -10-*`) · integration gate `X-R03-G14`

Tune vibrating heightfield patches to balance rolling beads.

- **Win:** a sampled curve must visit target waypoints in order while avoiding forbidden volumes. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Tune harmonics and phase to achieve a target three-dimensional pattern.
- **Model:** core abstraction harmonic field; state: u(t)=Σ A_i sin(ω_i t+φ_i) and 3D path sampling; quantize ω_i ratios and phases; solver: bounded integer-frequency enumeration + adaptive swept-segment collision; numeric risks: phase wrapping, singular derivative, aliased camera under grazing views.
- **Look (code only):** iridescent standing wave membranes move under a dark ceiling; Analytic oscillators, Fourier curve meshes, interference heightfields and emissive color; geometry: parallel-transport ribbons, interference color and normal-based emission.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 15765–15868, scenarios in lines 15869–15952, fault injection in lines 15953–16005); golden seed `39f215dcc95b`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round3.md` lines 14948–16012 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R03-G14`; assertion outline lines 28120–28149. Prompts: `python3 scripts/planning_index.py prompt --feature R03-G14-01 --override`.

### R03-G15 Interference Orchard

`r03-g15.interference-orchard` · premium · category puzzle · family Wave mathematics · score 93.95 · rank 25 · candidate G468 · features `R03-G15-01` … `R03-G15-10` (`specs/r03-g15-01-* … -10-*`) · integration gate `X-R03-G15`

Coordinate emitter phases so growth spots light up on distant trees.

- **Win:** a sampled curve must visit target waypoints in order while avoiding forbidden volumes. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Tune harmonics and phase to achieve a target three-dimensional pattern.
- **Model:** core abstraction harmonic field; state: u(t)=Σ A_i sin(ω_i t+φ_i) and 3D path sampling; quantize ω_i ratios and phases; solver: bounded integer-frequency enumeration + adaptive swept-segment collision; numeric risks: phase wrapping, singular derivative, aliased camera under grazing views.
- **Look (code only):** overlapping oscillatory beams paint trees with spectral cells; Analytic oscillators, Fourier curve meshes, interference heightfields and emissive color; geometry: parallel-transport ribbons, interference color and normal-based emission.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 16830–16933, scenarios in lines 16934–17017, fault injection in lines 17018–17070); golden seed `94f88079e3ed`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round3.md` lines 16013–17077 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R03-G15`; assertion outline lines 28150–28179. Prompts: `python3 scripts/planning_index.py prompt --feature R03-G15-01 --override`.

### R03-G16 Color Vaults

`r03-g16.color-vaults` · premium · category puzzle · family Chromatic logic · score 93.95 · rank 26 · candidate G402 · features `R03-G16-01` … `R03-G16-10` (`specs/r03-g16-01-* … -10-*`) · integration gate `X-R03-G16`

Route light through nested chambers with subtractive filter gates.

- **Win:** satisfy a target spectral pattern subject to unique-neighbor exclusion constraints. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Match spectral state in 3D without conflicting colors.
- **Model:** core abstraction spectral constraint grid; state: discrete hue index h in Z_12; edge transfer h_next=(h+δ) mod 12; secondary glyph code; solver: constraint propagation + backtracking with uniqueness proof; numeric risks: accessibility, near-similar hues, fake additive mixing rules.
- **Look (code only):** colorful refracted-looking pools inside faceted rooms; GLSL hue transforms, procedural glass polygons, spline light tubes and glow; geometry: GLSL color wheel, translucent solids and emissive edge tubes.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 17895–17998, scenarios in lines 17999–18082, fault injection in lines 18083–18135); golden seed `860f8fc32474`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round3.md` lines 17078–18142 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R03-G16`; assertion outline lines 28180–28209. Prompts: `python3 scripts/planning_index.py prompt --feature R03-G16-01 --override`.

### R03-G17 Photon Orchard

`r03-g17.photon-orchard` · premium · category puzzle · family Chromatic logic · score 93.95 · rank 27 · candidate G410 · features `R03-G17-01` … `R03-G17-10` (`specs/r03-g17-01-* … -10-*`) · integration gate `X-R03-G17`

Route colored beams to activate fruit in a 3D glass orchard.

- **Win:** satisfy a target spectral pattern subject to unique-neighbor exclusion constraints. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Match spectral state in 3D without conflicting colors.
- **Model:** core abstraction spectral constraint grid; state: discrete hue index h in Z_12; edge transfer h_next=(h+δ) mod 12; secondary glyph code; solver: constraint propagation + backtracking with uniqueness proof; numeric risks: accessibility, near-similar hues, fake additive mixing rules.
- **Look (code only):** floating crystalline fruits flare above dark foliage; GLSL hue transforms, procedural glass polygons, spline light tubes and glow; geometry: GLSL color wheel, translucent solids and emissive edge tubes.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 18960–19063, scenarios in lines 19064–19147, fault injection in lines 19148–19200); golden seed `0ca3decfbe2c`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round3.md` lines 18143–19207 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R03-G17`; assertion outline lines 28210–28239. Prompts: `python3 scripts/planning_index.py prompt --feature R03-G17-01 --override`.

### R03-G18 Wavefront Weaver

`r03-g18.wavefront-weaver` · premium · category puzzle · family Wave mathematics · score 93.93 · rank 28 · candidate G457 · features `R03-G18-01` … `R03-G18-10` (`specs/r03-g18-01-* … -10-*`) · integration gate `X-R03-G18`

Place wave sources so peak interference draws a target contour.

- **Win:** a sampled curve must visit target waypoints in order while avoiding forbidden volumes. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Tune harmonics and phase to achieve a target three-dimensional pattern.
- **Model:** core abstraction harmonic field; state: u(t)=Σ A_i sin(ω_i t+φ_i) and 3D path sampling; quantize ω_i ratios and phases; solver: bounded integer-frequency enumeration + adaptive swept-segment collision; numeric risks: phase wrapping, singular derivative, aliased camera under grazing views.
- **Look (code only):** expanding translucent wave shells converge into bright nodes; Analytic oscillators, Fourier curve meshes, interference heightfields and emissive color; geometry: parallel-transport ribbons, interference color and normal-based emission.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 20025–20128, scenarios in lines 20129–20212, fault injection in lines 20213–20265); golden seed `eafb77aa08af`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round3.md` lines 19208–20272 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R03-G18`; assertion outline lines 28240–28269. Prompts: `python3 scripts/planning_index.py prompt --feature R03-G18-01 --override`.

### R03-G19 Pendulum Timeglass

`r03-g19.pendulum-timeglass` · premium · category puzzle · family Temporal puzzles · score 93.9 · rank 30 · candidate G442 · features `R03-G19-01` … `R03-G19-10` (`specs/r03-g19-01-* … -10-*`) · integration gate `X-R03-G19`

Shift timelines to synchronize three moving pendulum shadows.

- **Win:** synchronize target events at the same integer tick without invalid contacts. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Edit events in a short loop to produce a future alignment.
- **Model:** core abstraction fixed-step timeline; state: state[k+1]=F(state[k],actions[k]); snapshot every 120 ticks and hash canonical state; solver: bounded time-expanded search with cycle memoization; numeric risks: desynchronization, unbounded history, ambiguous rewind interface.
- **Look (code only):** phase-offset ghosted machinery and stacked motion echoes; Deterministic timeline buffers, ghost trails, reversible deformation shaders; geometry: motion trails, reversible shader deformation and ghost snapshots.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 21090–21193, scenarios in lines 21194–21277, fault injection in lines 21278–21330); golden seed `887b3cb85fa4`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round3.md` lines 20273–21337 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R03-G19`; assertion outline lines 28270–28299. Prompts: `python3 scripts/planning_index.py prompt --feature R03-G19-01 --override`.

### R03-G20 Time-Lock Labyrinth

`r03-g20.time-lock-labyrinth` · premium · category puzzle · family Temporal puzzles · score 93.9 · rank 31 · candidate G447 · features `R03-G20-01` … `R03-G20-10` (`specs/r03-g20-01-* … -10-*`) · integration gate `X-R03-G20`

Synchronize repeating gates with a moving light traveler.

- **Win:** synchronize target events at the same integer tick without invalid contacts. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Edit events in a short loop to produce a future alignment.
- **Model:** core abstraction fixed-step timeline; state: state[k+1]=F(state[k],actions[k]); snapshot every 120 ticks and hash canonical state; solver: bounded time-expanded search with cycle memoization; numeric risks: desynchronization, unbounded history, ambiguous rewind interface.
- **Look (code only):** clockwork doors pulse in offset temporal loops; Deterministic timeline buffers, ghost trails, reversible deformation shaders; geometry: motion trails, reversible shader deformation and ghost snapshots.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 22155–22258, scenarios in lines 22259–22342, fault injection in lines 22343–22395); golden seed `3580540ea92d`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round3.md` lines 21338–22402 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R03-G20`; assertion outline lines 28300–28329. Prompts: `python3 scripts/planning_index.py prompt --feature R03-G20-01 --override`.

### R03-G21 Phase Garden

`r03-g21.phase-garden` · premium · category puzzle · family Temporal puzzles · score 93.9 · rank 32 · candidate G449 · features `R03-G21-01` … `R03-G21-10` (`specs/r03-g21-01-* … -10-*`) · integration gate `X-R03-G21`

Bring three time-shifted flowers into bloom at the same instant.

- **Win:** synchronize target events at the same integer tick without invalid contacts. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Edit events in a short loop to produce a future alignment.
- **Model:** core abstraction fixed-step timeline; state: state[k+1]=F(state[k],actions[k]); snapshot every 120 ticks and hash canonical state; solver: bounded time-expanded search with cycle memoization; numeric risks: desynchronization, unbounded history, ambiguous rewind interface.
- **Look (code only):** overlapping spectral petal states form temporal mandalas; Deterministic timeline buffers, ghost trails, reversible deformation shaders; geometry: motion trails, reversible shader deformation and ghost snapshots.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 23220–23323, scenarios in lines 23324–23407, fault injection in lines 23408–23460); golden seed `a59ecfd09dcd`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round3.md` lines 22403–23467 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R03-G21`; assertion outline lines 28330–28359. Prompts: `python3 scripts/planning_index.py prompt --feature R03-G21-01 --override`.

### R03-G22 Moire Observatory

`r03-g22.moire-observatory` · premium · category puzzle · family Wave mathematics · score 93.88 · rank 33 · candidate G460 · features `R03-G22-01` … `R03-G22-10` (`specs/r03-g22-01-* … -10-*`) · integration gate `X-R03-G22`

Rotate layered lattices until interference reveals hidden constellation points.

- **Win:** a sampled curve must visit target waypoints in order while avoiding forbidden volumes. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Tune harmonics and phase to achieve a target three-dimensional pattern.
- **Model:** core abstraction harmonic field; state: u(t)=Σ A_i sin(ω_i t+φ_i) and 3D path sampling; quantize ω_i ratios and phases; solver: bounded integer-frequency enumeration + adaptive swept-segment collision; numeric risks: phase wrapping, singular derivative, aliased camera under grazing views.
- **Look (code only):** shimmering 3D grid volumes and projected moiré fringes; Analytic oscillators, Fourier curve meshes, interference heightfields and emissive color; geometry: parallel-transport ribbons, interference color and normal-based emission.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 24285–24388, scenarios in lines 24389–24472, fault injection in lines 24473–24525); golden seed `850b92ced8fb`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round3.md` lines 23468–24532 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R03-G22`; assertion outline lines 28360–28389. Prompts: `python3 scripts/planning_index.py prompt --feature R03-G22-01 --override`.

### R03-G23 Aurora Geode

`r03-g23.aurora-geode` · premium · category puzzle · family Crystal solids · score 93.86 · rank 34 · candidate G303 · features `R03-G23-01` … `R03-G23-10` (`specs/r03-g23-01-* … -10-*`) · integration gate `X-R03-G23`

Tune internal light sources to project a matching aurora outside crystal.

- **Win:** place, cleave or rotate pieces until target mass/volume and adjacency topology match. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Rotate/cut/exchange crystal solids to meet 3D geometry rules.
- **Model:** core abstraction convex-solid graph; state: vertex planes n·x<=d; polytope clipping with epsilon-scaled robust predicates; solver: exact discrete state BFS + convex clipping check on candidate action; numeric risks: zero-area faces, z-order transparencies, unmanifold mesh.
- **Look (code only):** refraction-style caustics across faceted shells; Beveled polyhedra, faceted signed-distance fields, instanced lattices and faux dispersion; geometry: generated bevel prisms, layered facet reflection and gradient interiors.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 25350–25453, scenarios in lines 25454–25537, fault injection in lines 25538–25590); golden seed `11a4807c47d0`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round3.md` lines 24533–25597 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R03-G23`; assertion outline lines 28390–28419. Prompts: `python3 scripts/planning_index.py prompt --feature R03-G23-01 --override`.

### R03-G24 Snowflake Foundry

`r03-g24.snowflake-foundry` · premium · category puzzle · family Crystal solids · score 93.86 · rank 35 · candidate G304 · features `R03-G24-01` … `R03-G24-10` (`specs/r03-g24-01-* … -10-*`) · integration gate `X-R03-G24`

Configure six symmetric branching rules to make a target ice form.

- **Win:** place, cleave or rotate pieces until target mass/volume and adjacency topology match. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Rotate/cut/exchange crystal solids to meet 3D geometry rules.
- **Model:** core abstraction convex-solid graph; state: vertex planes n·x<=d; polytope clipping with epsilon-scaled robust predicates; solver: exact discrete state BFS + convex clipping check on candidate action; numeric risks: zero-area faces, z-order transparencies, unmanifold mesh.
- **Look (code only):** animated fractal dendrites grow into fragile crystalline spires; Beveled polyhedra, faceted signed-distance fields, instanced lattices and faux dispersion; geometry: generated bevel prisms, layered facet reflection and gradient interiors.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 26415–26518, scenarios in lines 26519–26602, fault injection in lines 26603–26655); golden seed `6d98f43a3216`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round3.md` lines 25598–26662 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R03-G24`; assertion outline lines 28420–28449. Prompts: `python3 scripts/planning_index.py prompt --feature R03-G24-01 --override`.

### R03-G25 Geode Locksmith

`r03-g25.geode-locksmith` · premium · category puzzle · family Crystal solids · score 93.84 · rank 36 · candidate G293 · features `R03-G25-01` … `R03-G25-10` (`specs/r03-g25-01-* … -10-*`) · integration gate `X-R03-G25`

Cut and rotate nested geode rings to align hidden crystalline keys.

- **Win:** place, cleave or rotate pieces until target mass/volume and adjacency topology match. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Rotate/cut/exchange crystal solids to meet 3D geometry rules.
- **Model:** core abstraction convex-solid graph; state: vertex planes n·x<=d; polytope clipping with epsilon-scaled robust predicates; solver: exact discrete state BFS + convex clipping check on candidate action; numeric risks: zero-area faces, z-order transparencies, unmanifold mesh.
- **Look (code only):** iridescent concentric shells and sparkling interior facets; Beveled polyhedra, faceted signed-distance fields, instanced lattices and faux dispersion; geometry: generated bevel prisms, layered facet reflection and gradient interiors.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 27480–27583, scenarios in lines 27584–27667, fault injection in lines 27668–27720); golden seed `2bbb37564d01`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round3.md` lines 26663–27727 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R03-G25`; assertion outline lines 28450–28480. Prompts: `python3 scripts/planning_index.py prompt --feature R03-G25-01 --override`.
<!-- GENERATED:END cards-round03 -->

### 9.2 Round 4

<!-- GENERATED:BEGIN cards-round04 -->
### R04-G01 Icy Polyhedron

`r04-g01.icy-polyhedron` · premium · category puzzle · family Crystal solids · score 93.84 · rank 37 · candidate G294 · features `R04-G01-01` … `R04-G01-10` (`specs/r04-g01-01-* … -10-*`) · integration gate `X-R04-G01`

Reconfigure edges of frozen solids while preserving volume.

- **Win:** place, cleave or rotate pieces until target mass/volume and adjacency topology match. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Rotate/cut/exchange crystal solids to meet 3D geometry rules.
- **Model:** core abstraction convex-solid graph; state: vertex planes n·x<=d; polytope clipping with epsilon-scaled robust predicates; solver: exact discrete state BFS + convex clipping check on candidate action; numeric risks: zero-area faces, z-order transparencies, unmanifold mesh.
- **Look (code only):** geometric frost geometry and glowing beveled edge networks; Beveled polyhedra, faceted signed-distance fields, instanced lattices and faux dispersion; geometry: generated bevel prisms, layered facet reflection and gradient interiors.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 1921–2024, scenarios in lines 2025–2108, fault injection in lines 2109–2161); golden seed `d8041a475a2d`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round4.md` lines 1104–2168 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R04-G01`; assertion outline lines 27731–27760. Prompts: `python3 scripts/planning_index.py prompt --feature R04-G01-01 --override`.

### R04-G02 Crystal Phase Shift

`r04-g02.crystal-phase-shift` · premium · category puzzle · family Crystal solids · score 93.84 · rank 38 · candidate G301 · features `R04-G02-01` … `R04-G02-10` (`specs/r04-g02-01-* … -10-*`) · integration gate `X-R04-G02`

Change a mineral lattice phase to unlock a three-dimensional channel.

- **Win:** place, cleave or rotate pieces until target mass/volume and adjacency topology match. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Rotate/cut/exchange crystal solids to meet 3D geometry rules.
- **Model:** core abstraction convex-solid graph; state: vertex planes n·x<=d; polytope clipping with epsilon-scaled robust predicates; solver: exact discrete state BFS + convex clipping check on candidate action; numeric risks: zero-area faces, z-order transparencies, unmanifold mesh.
- **Look (code only):** tiny voxel cells snap into new reflective-looking structures; Beveled polyhedra, faceted signed-distance fields, instanced lattices and faux dispersion; geometry: generated bevel prisms, layered facet reflection and gradient interiors.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 2986–3089, scenarios in lines 3090–3173, fault injection in lines 3174–3226); golden seed `d9471f65f7b3`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round4.md` lines 2169–3233 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R04-G02`; assertion outline lines 27761–27790. Prompts: `python3 scripts/planning_index.py prompt --feature R04-G02-01 --override`.

### R04-G03 Diamond Pulse

`r04-g03.diamond-pulse` · premium · category puzzle · family Crystal solids · score 93.81 · rank 39 · candidate G305 · features `R04-G03-01` … `R04-G03-10` (`specs/r04-g03-01-* … -10-*`) · integration gate `X-R04-G03`

Time crystal rotations so a traveling flash survives every split.

- **Win:** place, cleave or rotate pieces until target mass/volume and adjacency topology match. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Rotate/cut/exchange crystal solids to meet 3D geometry rules.
- **Model:** core abstraction convex-solid graph; state: vertex planes n·x<=d; polytope clipping with epsilon-scaled robust predicates; solver: exact discrete state BFS + convex clipping check on candidate action; numeric risks: zero-area faces, z-order transparencies, unmanifold mesh.
- **Look (code only):** fast staccato light cascades over geometric gemstone machinery; Beveled polyhedra, faceted signed-distance fields, instanced lattices and faux dispersion; geometry: generated bevel prisms, layered facet reflection and gradient interiors.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 4051–4154, scenarios in lines 4155–4238, fault injection in lines 4239–4291); golden seed `7d7fde9d2c72`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round4.md` lines 3234–4298 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R04-G03`; assertion outline lines 27791–27820. Prompts: `python3 scripts/planning_index.py prompt --feature R04-G03-01 --override`.

### R04-G04 Octahedral Orchard

`r04-g04.octahedral-orchard` · premium · category puzzle · family Crystal solids · score 93.79 · rank 42 · candidate G296 · features `R04-G04-01` … `R04-G04-10` (`specs/r04-g04-01-* … -10-*`) · integration gate `X-R04-G04`

Connect branching octahedron clusters into a stable luminous canopy.

- **Win:** place, cleave or rotate pieces until target mass/volume and adjacency topology match. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Rotate/cut/exchange crystal solids to meet 3D geometry rules.
- **Model:** core abstraction convex-solid graph; state: vertex planes n·x<=d; polytope clipping with epsilon-scaled robust predicates; solver: exact discrete state BFS + convex clipping check on candidate action; numeric risks: zero-area faces, z-order transparencies, unmanifold mesh.
- **Look (code only):** glowing Platonic solid growth and spectral shadow play; Beveled polyhedra, faceted signed-distance fields, instanced lattices and faux dispersion; geometry: generated bevel prisms, layered facet reflection and gradient interiors.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 5116–5219, scenarios in lines 5220–5303, fault injection in lines 5304–5356); golden seed `be8b0dc787cf`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round4.md` lines 4299–5363 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R04-G04`; assertion outline lines 27821–27850. Prompts: `python3 scripts/planning_index.py prompt --feature R04-G04-01 --override`.

### R04-G05 Echo Harmonics

`r04-g05.echo-harmonics` · premium · category puzzle · family Wave mathematics · score 93.78 · rank 43 · candidate G469 · features `R04-G05-01` … `R04-G05-10` (`specs/r04-g05-01-* … -10-*`) · integration gate `X-R04-G05`

Adjust frequency bands to expose a hidden geometric object.

- **Win:** a sampled curve must visit target waypoints in order while avoiding forbidden volumes. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Tune harmonics and phase to achieve a target three-dimensional pattern.
- **Model:** core abstraction harmonic field; state: u(t)=Σ A_i sin(ω_i t+φ_i) and 3D path sampling; quantize ω_i ratios and phases; solver: bounded integer-frequency enumeration + adaptive swept-segment collision; numeric risks: phase wrapping, singular derivative, aliased camera under grazing views.
- **Look (code only):** translucent waves reveal resonant contours on solids; Analytic oscillators, Fourier curve meshes, interference heightfields and emissive color; geometry: parallel-transport ribbons, interference color and normal-based emission.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 6181–6284, scenarios in lines 6285–6368, fault injection in lines 6369–6421); golden seed `a696a0b7dd9e`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round4.md` lines 5364–6428 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R04-G05`; assertion outline lines 27851–27880. Prompts: `python3 scripts/planning_index.py prompt --feature R04-G05-01 --override`.

### R04-G06 Memory Marble

`r04-g06.memory-marble` · premium · category puzzle · family Temporal puzzles · score 93.76 · rank 44 · candidate G448 · features `R04-G06-01` … `R04-G06-10` (`specs/r04-g06-01-* … -10-*`) · integration gate `X-R04-G06`

Replay and edit a previous rolling trajectory to avoid a collision.

- **Win:** synchronize target events at the same integer tick without invalid contacts. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Edit events in a short loop to produce a future alignment.
- **Model:** core abstraction fixed-step timeline; state: state[k+1]=F(state[k],actions[k]); snapshot every 120 ticks and hash canonical state; solver: bounded time-expanded search with cycle memoization; numeric risks: desynchronization, unbounded history, ambiguous rewind interface.
- **Look (code only):** translucent ghost marbles retrace glowing splines; Deterministic timeline buffers, ghost trails, reversible deformation shaders; geometry: motion trails, reversible shader deformation and ghost snapshots.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 7246–7349, scenarios in lines 7350–7433, fault injection in lines 7434–7486); golden seed `c645c001a850`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round4.md` lines 6429–7493 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R04-G06`; assertion outline lines 27881–27910. Prompts: `python3 scripts/planning_index.py prompt --feature R04-G06-01 --override`.

### R04-G07 Echoes of Stone

`r04-g07.echoes-of-stone` · premium · category puzzle · family Temporal puzzles · score 93.76 · rank 45 · candidate G452 · features `R04-G07-01` … `R04-G07-10` (`specs/r04-g07-01-* … -10-*`) · integration gate `X-R04-G07`

Carve a stone once per loop to reroute future light pulses.

- **Win:** synchronize target events at the same integer tick without invalid contacts. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Edit events in a short loop to produce a future alignment.
- **Model:** core abstraction fixed-step timeline; state: state[k+1]=F(state[k],actions[k]); snapshot every 120 ticks and hash canonical state; solver: bounded time-expanded search with cycle memoization; numeric risks: desynchronization, unbounded history, ambiguous rewind interface.
- **Look (code only):** new cuts cast successive glowing temporal shadow maps; Deterministic timeline buffers, ghost trails, reversible deformation shaders; geometry: motion trails, reversible shader deformation and ghost snapshots.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 8311–8414, scenarios in lines 8415–8498, fault injection in lines 8499–8551); golden seed `b2db91f634a4`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round4.md` lines 7494–8558 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R04-G07`; assertion outline lines 27911–27940. Prompts: `python3 scripts/planning_index.py prompt --feature R04-G07-01 --override`.

### R04-G08 Hourglass Gravity

`r04-g08.hourglass-gravity` · premium · category puzzle · family Temporal puzzles · score 93.75 · rank 46 · candidate G446 · features `R04-G08-01` … `R04-G08-10` (`specs/r04-g08-01-* … -10-*`) · integration gate `X-R04-G08`

Reverse one local gravity field at a chosen time to route falling pearls.

- **Win:** synchronize target events at the same integer tick without invalid contacts. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Edit events in a short loop to produce a future alignment.
- **Model:** core abstraction fixed-step timeline; state: state[k+1]=F(state[k],actions[k]); snapshot every 120 ticks and hash canonical state; solver: bounded time-expanded search with cycle memoization; numeric risks: desynchronization, unbounded history, ambiguous rewind interface.
- **Look (code only):** trails split into past and future gravity arcs; Deterministic timeline buffers, ghost trails, reversible deformation shaders; geometry: motion trails, reversible shader deformation and ghost snapshots.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 9376–9479, scenarios in lines 9480–9563, fault injection in lines 9564–9616); golden seed `e19d6c1f3631`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round4.md` lines 8559–9623 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R04-G08`; assertion outline lines 27941–27970. Prompts: `python3 scripts/planning_index.py prompt --feature R04-G08-01 --override`.

### R04-G09 Color Vortex

`r04-g09.color-vortex` · premium · category puzzle · family Chromatic logic · score 93.74 · rank 47 · candidate G409 · features `R04-G09-01` … `R04-G09-10` (`specs/r04-g09-01-* … -10-*`) · integration gate `X-R04-G09`

Position angular emitters to bring rotating color streams into phase.

- **Win:** satisfy a target spectral pattern subject to unique-neighbor exclusion constraints. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Match spectral state in 3D without conflicting colors.
- **Model:** core abstraction spectral constraint grid; state: discrete hue index h in Z_12; edge transfer h_next=(h+δ) mod 12; secondary glyph code; solver: constraint propagation + backtracking with uniqueness proof; numeric risks: accessibility, near-similar hues, fake additive mixing rules.
- **Look (code only):** spiraling spectral particles converge on a bright core; GLSL hue transforms, procedural glass polygons, spline light tubes and glow; geometry: GLSL color wheel, translucent solids and emissive edge tubes.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 10441–10544, scenarios in lines 10545–10628, fault injection in lines 10629–10681); golden seed `018bd67e4c30`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round4.md` lines 9624–10688 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R04-G09`; assertion outline lines 27971–28000. Prompts: `python3 scripts/planning_index.py prompt --feature R04-G09-01 --override`.

### R04-G10 Candle Geometry

`r04-g10.candle-geometry` · premium · category puzzle · family Shadow construction · score 93.73 · rank 49 · candidate G379 · features `R04-G10-01` … `R04-G10-10` (`specs/r04-g10-01-* … -10-*`) · integration gate `X-R04-G10`

Move tiny light sources around solids to animate a shadow poem.

- **Win:** arrange solids so projected shadows form a required shape or route. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Construct 3D shapes whose target shadow matches an image or path.
- **Model:** core abstraction projective shadow geometry; state: shadow mask=∪Π_light(occluder solids), compare raster IoU and Hausdorff boundary; solver: finite pose search and deterministic silhouette raster validator; numeric risks: shadow self-intersection, ambiguous depth, darkness hides interactions.
- **Look (code only):** flickering low-poly forms generate flowing edge shadows; Procedural solids, CPU polygonal 3D shadow projections, soft shadow approximation; geometry: CPU-projected analytic soft shadow stencil with light shaft geometry.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 11506–11609, scenarios in lines 11610–11693, fault injection in lines 11694–11746); golden seed `f23c5b3ea989`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round4.md` lines 10689–11753 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R04-G10`; assertion outline lines 28001–28030. Prompts: `python3 scripts/planning_index.py prompt --feature R04-G10-01 --override`.

### R04-G11 Umbra Rings

`r04-g11.umbra-rings` · premium · category puzzle · family Shadow construction · score 93.73 · rank 50 · candidate G376 · features `R04-G11-01` … `R04-G11-10` (`specs/r04-g11-01-* … -10-*`) · integration gate `X-R04-G11`

Arrange orbital rings to form target overlapping dark discs.

- **Win:** arrange solids so projected shadows form a required shape or route. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Construct 3D shapes whose target shadow matches an image or path.
- **Model:** core abstraction projective shadow geometry; state: shadow mask=∪Π_light(occluder solids), compare raster IoU and Hausdorff boundary; solver: finite pose search and deterministic silhouette raster validator; numeric risks: shadow self-intersection, ambiguous depth, darkness hides interactions.
- **Look (code only):** moving eclipse zones and concentric iridescent edges; Procedural solids, CPU polygonal 3D shadow projections, soft shadow approximation; geometry: CPU-projected analytic soft shadow stencil with light shaft geometry.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 12571–12674, scenarios in lines 12675–12758, fault injection in lines 12759–12811); golden seed `e9351ec850bb`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round4.md` lines 11754–12818 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R04-G11`; assertion outline lines 28031–28060. Prompts: `python3 scripts/planning_index.py prompt --feature R04-G11-01 --override`.

### R04-G12 Nightfall Sculptor

`r04-g12.nightfall-sculptor` · premium · category puzzle · family Shadow construction · score 93.73 · rank 51 · candidate G380 · features `R04-G12-01` … `R04-G12-10` (`specs/r04-g12-01-* … -10-*`) · integration gate `X-R04-G12`

Transform a mesh through a sequence of target shadow silhouettes.

- **Win:** arrange solids so projected shadows form a required shape or route. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Construct 3D shapes whose target shadow matches an image or path.
- **Model:** core abstraction projective shadow geometry; state: shadow mask=∪Π_light(occluder solids), compare raster IoU and Hausdorff boundary; solver: finite pose search and deterministic silhouette raster validator; numeric risks: shadow self-intersection, ambiguous depth, darkness hides interactions.
- **Look (code only):** slowly morphing signed-distance solid and moving projection; Procedural solids, CPU polygonal 3D shadow projections, soft shadow approximation; geometry: CPU-projected analytic soft shadow stencil with light shaft geometry.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 13636–13739, scenarios in lines 13740–13823, fault injection in lines 13824–13876); golden seed `9af6deddabbf`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round4.md` lines 12819–13883 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R04-G12`; assertion outline lines 28061–28090. Prompts: `python3 scripts/planning_index.py prompt --feature R04-G12-01 --override`.

### R04-G13 Lumen Sudoku

`r04-g13.lumen-sudoku` · premium · category puzzle · family Chromatic logic · score 93.72 · rank 52 · candidate G408 · features `R04-G13-01` … `R04-G13-10` (`specs/r04-g13-01-* … -10-*`) · integration gate `X-R04-G13`

Solve a three-dimensional color placement puzzle across layered cubes.

- **Win:** satisfy a target spectral pattern subject to unique-neighbor exclusion constraints. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Match spectral state in 3D without conflicting colors.
- **Model:** core abstraction spectral constraint grid; state: discrete hue index h in Z_12; edge transfer h_next=(h+δ) mod 12; secondary glyph code; solver: constraint propagation + backtracking with uniqueness proof; numeric risks: accessibility, near-similar hues, fake additive mixing rules.
- **Look (code only):** cubes form glowing volumetric patterns at solution; GLSL hue transforms, procedural glass polygons, spline light tubes and glow; geometry: GLSL color wheel, translucent solids and emissive edge tubes.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 14701–14804, scenarios in lines 14805–14888, fault injection in lines 14889–14941); golden seed `943b02787855`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round4.md` lines 13884–14948 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R04-G13`; assertion outline lines 28091–28120. Prompts: `python3 scripts/planning_index.py prompt --feature R04-G13-01 --override`.

### R04-G14 Eclipse Lantern

`r04-g14.eclipse-lantern` · premium · category puzzle · family Shadow construction · score 93.72 · rank 53 · candidate G372 · features `R04-G14-01` … `R04-G14-10` (`specs/r04-g14-01-* … -10-*`) · integration gate `X-R04-G14`

Reposition planets and lamps so a room's shadow sequence repeats.

- **Win:** arrange solids so projected shadows form a required shape or route. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Construct 3D shapes whose target shadow matches an image or path.
- **Model:** core abstraction projective shadow geometry; state: shadow mask=∪Π_light(occluder solids), compare raster IoU and Hausdorff boundary; solver: finite pose search and deterministic silhouette raster validator; numeric risks: shadow self-intersection, ambiguous depth, darkness hides interactions.
- **Look (code only):** orbital shadow choreography with golden rim lights; Procedural solids, CPU polygonal 3D shadow projections, soft shadow approximation; geometry: CPU-projected analytic soft shadow stencil with light shaft geometry.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 15766–15869, scenarios in lines 15870–15953, fault injection in lines 15954–16006); golden seed `65bfcb689cf6`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round4.md` lines 14949–16013 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R04-G14`; assertion outline lines 28121–28150. Prompts: `python3 scripts/planning_index.py prompt --feature R04-G14-01 --override`.

### R04-G15 Clockwave Harbor

`r04-g15.clockwave-harbor` · premium · category puzzle · family Temporal puzzles · score 93.7 · rank 55 · candidate G454 · features `R04-G15-01` … `R04-G15-10` (`specs/r04-g15-01-* … -10-*`) · integration gate `X-R04-G15`

Phase-shift small orbital vessels to dock in a single time window.

- **Win:** synchronize target events at the same integer tick without invalid contacts. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Edit events in a short loop to produce a future alignment.
- **Model:** core abstraction fixed-step timeline; state: state[k+1]=F(state[k],actions[k]); snapshot every 120 ticks and hash canonical state; solver: bounded time-expanded search with cycle memoization; numeric risks: desynchronization, unbounded history, ambiguous rewind interface.
- **Look (code only):** stacked orbit trails converge in synchronized flashes; Deterministic timeline buffers, ghost trails, reversible deformation shaders; geometry: motion trails, reversible shader deformation and ghost snapshots.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 16831–16934, scenarios in lines 16935–17018, fault injection in lines 17019–17071); golden seed `8d9166536a6a`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round4.md` lines 16014–17078 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R04-G15`; assertion outline lines 28151–28180. Prompts: `python3 scripts/planning_index.py prompt --feature R04-G15-01 --override`.

### R04-G16 Prism Pathways

`r04-g16.prism-pathways` · premium · category puzzle · family Spatial puzzles · score 93.7 · rank 56 · candidate G021 · features `R04-G16-01` … `R04-G16-10` (`specs/r04-g16-01-* … -10-*`) · integration gate `X-R04-G16`

Rotate prisms to connect color-filtered light emitters to terminal crystals.

- **Win:** connect separated spatial checkpoints through valid geometry transformations. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Existing concept input requires game-specific design verification.
- **Model:** core abstraction finite polyhedral space; state: state=(position,orientation,configuration) on quantized 3D lattice; solver: BFS/A* through spatial transformation graph; numeric risks: occlusion, motion sickness, path uniqueness.
- **Look (code only):** Parametric glass/prism meshes, wavelength-band beams, approximated Fresnel and bloom; geometry: SDF-style surfaces, translucent prisms and selected-edge glow.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 17896–17999, scenarios in lines 18000–18083, fault injection in lines 18084–18136); golden seed `a62461020363`. Score basis: Inherited original 200; previously scored.
- **Source:** `docs/archive/planning/rounds/round4.md` lines 17079–18143 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R04-G16`; assertion outline lines 28181–28210. Prompts: `python3 scripts/planning_index.py prompt --feature R04-G16-01 --override`.

### R04-G17 Longlight Labyrinth

`r04-g17.longlight-labyrinth` · premium · category puzzle · family Shadow construction · score 93.68 · rank 57 · candidate G375 · features `R04-G17-01` … `R04-G17-10` (`specs/r04-g17-01-* … -10-*`) · integration gate `X-R04-G17`

Shift time-of-day to reveal a hidden route drawn by cast shadows.

- **Win:** arrange solids so projected shadows form a required shape or route. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Construct 3D shapes whose target shadow matches an image or path.
- **Model:** core abstraction projective shadow geometry; state: shadow mask=∪Π_light(occluder solids), compare raster IoU and Hausdorff boundary; solver: finite pose search and deterministic silhouette raster validator; numeric risks: shadow self-intersection, ambiguous depth, darkness hides interactions.
- **Look (code only):** traveling sundial shadows across maze geometry; Procedural solids, CPU polygonal 3D shadow projections, soft shadow approximation; geometry: CPU-projected analytic soft shadow stencil with light shaft geometry.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 18961–19064, scenarios in lines 19065–19148, fault injection in lines 19149–19201); golden seed `6b408b8d3cc7`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round4.md` lines 18144–19208 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R04-G17`; assertion outline lines 28211–28240. Prompts: `python3 scripts/planning_index.py prompt --feature R04-G17-01 --override`.

### R04-G18 Iridescent Channels

`r04-g18.iridescent-channels` · premium · category puzzle · family Chromatic logic · score 93.67 · rank 58 · candidate G406 · features `R04-G18-01` … `R04-G18-10` (`specs/r04-g18-01-* … -10-*`) · integration gate `X-R04-G18`

Reorder wavelength filters to route colors through branching tubes.

- **Win:** satisfy a target spectral pattern subject to unique-neighbor exclusion constraints. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Match spectral state in 3D without conflicting colors.
- **Model:** core abstraction spectral constraint grid; state: discrete hue index h in Z_12; edge transfer h_next=(h+δ) mod 12; secondary glyph code; solver: constraint propagation + backtracking with uniqueness proof; numeric risks: accessibility, near-similar hues, fake additive mixing rules.
- **Look (code only):** transparent tube networks carry brilliant gradient pulses; GLSL hue transforms, procedural glass polygons, spline light tubes and glow; geometry: GLSL color wheel, translucent solids and emissive edge tubes.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 20026–20129, scenarios in lines 20130–20213, fault injection in lines 20214–20266); golden seed `44ca2683182b`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round4.md` lines 19209–20273 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R04-G18`; assertion outline lines 28241–28270. Prompts: `python3 scripts/planning_index.py prompt --feature R04-G18-01 --override`.

### R04-G19 Lattice Bloom

`r04-g19.lattice-bloom` · premium · category puzzle · family Crystal solids · score 93.66 · rank 59 · candidate G292 · features `R04-G19-01` … `R04-G19-10` (`specs/r04-g19-01-* … -10-*`) · integration gate `X-R04-G19`

Rotate repeated crystal unit cells until a glowing lattice closes.

- **Win:** place, cleave or rotate pieces until target mass/volume and adjacency topology match. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Rotate/cut/exchange crystal solids to meet 3D geometry rules.
- **Model:** core abstraction convex-solid graph; state: vertex planes n·x<=d; polytope clipping with epsilon-scaled robust predicates; solver: exact discrete state BFS + convex clipping check on candidate action; numeric risks: zero-area faces, z-order transparencies, unmanifold mesh.
- **Look (code only):** instanced translucent polyhedra form kaleidoscopic architecture; Beveled polyhedra, faceted signed-distance fields, instanced lattices and faux dispersion; geometry: generated bevel prisms, layered facet reflection and gradient interiors.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 21091–21194, scenarios in lines 21195–21278, fault injection in lines 21279–21331); golden seed `e31684a8ce1a`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round4.md` lines 20274–21338 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R04-G19`; assertion outline lines 28271–28300. Prompts: `python3 scripts/planning_index.py prompt --feature R04-G19-01 --override`.

### R04-G20 Glass Knot Studio

`r04-g20.glass-knot-studio` · premium · category puzzle · family Crystal solids · score 93.66 · rank 60 · candidate G297 · features `R04-G20-01` … `R04-G20-10` (`specs/r04-g20-01-* … -10-*`) · integration gate `X-R04-G20`

Thread transparent geometric ropes through interlocking crystal loops.

- **Win:** place, cleave or rotate pieces until target mass/volume and adjacency topology match. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Rotate/cut/exchange crystal solids to meet 3D geometry rules.
- **Model:** core abstraction convex-solid graph; state: vertex planes n·x<=d; polytope clipping with epsilon-scaled robust predicates; solver: exact discrete state BFS + convex clipping check on candidate action; numeric risks: zero-area faces, z-order transparencies, unmanifold mesh.
- **Look (code only):** tubular spline geometry and shimmering facets; Beveled polyhedra, faceted signed-distance fields, instanced lattices and faux dispersion; geometry: generated bevel prisms, layered facet reflection and gradient interiors.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 22156–22259, scenarios in lines 22260–22343, fault injection in lines 22344–22396); golden seed `54741054cbda`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round4.md` lines 21339–22403 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R04-G20`; assertion outline lines 28301–28330. Prompts: `python3 scripts/planning_index.py prompt --feature R04-G20-01 --override`.

### R04-G21 Time Ribbon Relay

`r04-g21.time-ribbon-relay` · premium · category puzzle · family Temporal puzzles · score 93.63 · rank 61 · candidate G441 · features `R04-G21-01` … `R04-G21-10` (`specs/r04-g21-01-* … -10-*`) · integration gate `X-R04-G21`

Rewind a moving light ribbon while changing one obstacle per loop.

- **Win:** synchronize target events at the same integer tick without invalid contacts. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Edit events in a short loop to produce a future alignment.
- **Model:** core abstraction fixed-step timeline; state: state[k+1]=F(state[k],actions[k]); snapshot every 120 ticks and hash canonical state; solver: bounded time-expanded search with cycle memoization; numeric risks: desynchronization, unbounded history, ambiguous rewind interface.
- **Look (code only):** luminous ribbon retains branching past trajectories; Deterministic timeline buffers, ghost trails, reversible deformation shaders; geometry: motion trails, reversible shader deformation and ghost snapshots.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 23221–23324, scenarios in lines 23325–23408, fault injection in lines 23409–23461); golden seed `d0bc7a43b428`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round4.md` lines 22404–23468 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R04-G21`; assertion outline lines 28331–28360. Prompts: `python3 scripts/planning_index.py prompt --feature R04-G21-01 --override`.

### R04-G22 Gemstone Telegraph

`r04-g22.gemstone-telegraph` · premium · category puzzle · family Wave optics · score 93.62 · rank 62 · candidate G212 · features `R04-G22-01` … `R04-G22-10` (`specs/r04-g22-01-* … -10-*`) · integration gate `X-R04-G22`

Encode and decode light pulses across a network of faceted prism towers.

- **Win:** route or phase-align rays through specified optical stations. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Tap and rotate optical elements; observe ray path; solve light-path constraint.
- **Model:** core abstraction ray/wave optical graph; state: Snell n1 sinθ1=n2 sinθ2; Fresnel-inspired aesthetic only, numeric ray solver owns truth; solver: bounded ray graph traversal with plane intersections and reflection/refraction validation; numeric risks: false physical accuracy, firefly pixels, excessive transparency.
- **Look (code only):** faceted gems flashing wavelength-coded trails; Analytic beam volumes, layered caustic projections, SDF optics and gradient materials; geometry: projected caustics, beam cylinders, chromatic dispersion approximations.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 24286–24389, scenarios in lines 24390–24473, fault injection in lines 24474–24526); golden seed `a0a33adfcbbe`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round4.md` lines 23469–24533 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R04-G22`; assertion outline lines 28361–28390. Prompts: `python3 scripts/planning_index.py prompt --feature R04-G22-01 --override`.

### R04-G23 Soundglass Observatory

`r04-g23.soundglass-observatory` · premium · category puzzle · family Acoustic geometry · score 93.62 · rank 63 · candidate G227 · features `R04-G23-01` … `R04-G23-10` (`specs/r04-g23-01-* … -10-*`) · integration gate `X-R04-G23`

Tilt sound-sensitive glass to project wave shapes into geometric constellations.

- **Win:** place emitters so returning wavefronts reveal an ordered signal pattern. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Position/trigger resonators and infer hidden 3D structure.
- **Model:** core abstraction pulse propagation graph; state: arrival_time(x)=||x-source||/c with bounded distance field and quantized pulse ticks; solver: discrete emitter search with exact arrival-order and occlusion checks; numeric risks: misleading sound analogy, ring overdraw and strobe risk.
- **Look (code only):** iridescent sheet deformations and scanline nebulae; Instanced line meshes, transient wave shells, acoustically inspired distance-field reveals; geometry: expanding ring meshes, volumetric-look pulse shells and glowing distance bands.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 25351–25454, scenarios in lines 25455–25538, fault injection in lines 25539–25591); golden seed `752aef8eaa60`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round4.md` lines 24534–25598 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R04-G23`; assertion outline lines 28391–28420. Prompts: `python3 scripts/planning_index.py prompt --feature R04-G23-01 --override`.

### R04-G24 Refraction Foundry

`r04-g24.refraction-foundry` · premium · category puzzle · family Wave optics · score 93.61 · rank 64 · candidate G209 · features `R04-G24-01` … `R04-G24-10` (`specs/r04-g24-01-* … -10-*`) · integration gate `X-R04-G24`

Shape virtual lenses to focus colored beams at targets inside a glass furnace.

- **Win:** route or phase-align rays through specified optical stations. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Tap and rotate optical elements; observe ray path; solve light-path constraint.
- **Model:** core abstraction ray/wave optical graph; state: Snell n1 sinθ1=n2 sinθ2; Fresnel-inspired aesthetic only, numeric ray solver owns truth; solver: bounded ray graph traversal with plane intersections and reflection/refraction validation; numeric risks: false physical accuracy, firefly pixels, excessive transparency.
- **Look (code only):** curved Fresnel-like patterns around translucent procedural solids; Analytic beam volumes, layered caustic projections, SDF optics and gradient materials; geometry: projected caustics, beam cylinders, chromatic dispersion approximations.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 26416–26519, scenarios in lines 26520–26603, fault injection in lines 26604–26656); golden seed `0910bf9c5b24`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round4.md` lines 25599–26663 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R04-G24`; assertion outline lines 28421–28450. Prompts: `python3 scripts/planning_index.py prompt --feature R04-G24-01 --override`.

### R04-G25 Prism Terrace

`r04-g25.prism-terrace` · premium · category puzzle · family Crystal solids · score 93.6 · rank 65 · candidate G295 · features `R04-G25-01` … `R04-G25-10` (`specs/r04-g25-01-* … -10-*`) · integration gate `X-R04-G25`

Stack rotating faceted platforms to redirect beams toward a center.

- **Win:** place, cleave or rotate pieces until target mass/volume and adjacency topology match. **Failure:** budget overrun, impossible state certificate, invalid component collisions, exhausted moves/time if explicitly signaled in the UI.
- **Controls:** Rotate/cut/exchange crystal solids to meet 3D geometry rules.
- **Model:** core abstraction convex-solid graph; state: vertex planes n·x<=d; polytope clipping with epsilon-scaled robust predicates; solver: exact discrete state BFS + convex clipping check on candidate action; numeric risks: zero-area faces, z-order transparencies, unmanifold mesh.
- **Look (code only):** sharp glints and colored refraction approximations; Beveled polyhedra, faceted signed-distance fields, instanced lattices and faux dispersion; geometry: generated bevel prisms, layered facet reflection and gradient interiors.
- **Content:** 100 planned levels; 80 acceptance scenarios; 50 fault-injection cases (levels in lines 27481–27584, scenarios in lines 27585–27668, fault injection in lines 27669–27721); golden seed `cdea0f8b4b64`. Score basis: Newly proposed 300; assessed from analog family prior.
- **Source:** `docs/archive/planning/rounds/round4.md` lines 26664–27728 (11 sections); levels as JSON: `python3 scripts/planning_index.py levels --experience R04-G25`; assertion outline lines 28451–28481. Prompts: `python3 scripts/planning_index.py prompt --feature R04-G25-01 --override`.
<!-- GENERATED:END cards-round04 -->

## 10. Backlog: Rounds 5–12

Two hundred further games are specified to the same depth as Rounds 3 and 4 and are kept in descending score
order. They are not part of the first release and nothing about them is implemented. After the release they are
added as premium experiences in bounded batches, one round at a time, never out of order
(`python3 scripts/migration_ledger.py add-round --round N`, section 18.4). Buyers of the unlock receive them
without a further purchase. Round 11 ends with one and Round 12 consists of 25 supplemental candidates
(`docs/brainstorm/supplemental-26-provisional-candidates.csv`). Their scores are provisional estimates and they
rank beneath every original candidate; they keep their place at the end of the queue. The sources give no rule
for confirming them, so that is the owner's call before those rounds start.

<!-- GENERATED:BEGIN backlog -->
| # | Code | Runtime id | Name | Family | Score | Source rank | Pitch | Source lines |
|---:|---|---|---|---|---:|---|---|---|
| 101 | R05-G01 | `r05-g01.shadow-mosaic` | Shadow Mosaic | Shadow construction | 93.6 | 66 | Fill a target silhouette with overlapping projected 3D solids | `round5.md` 1105–2169 |
| 102 | R05-G02 | `r05-g02.mirror-silhouette` | Mirror Silhouette | Shadow construction | 93.59 | 67 | Rotate mirrors and prisms to create a shadow image from indirect beams | `round5.md` 2170–3234 |
| 103 | R05-G03 | `r05-g03.frozen-current` | Frozen Current | Temporal puzzles | 93.59 | 68 | Pause and resume separate fluid streams to build a three-dimensional flow knot | `round5.md` 3235–4299 |
| 104 | R05-G04 | `r05-g04.luminous-inversion` | Luminous Inversion | Chromatic logic | 93.57 | 69 | Toggle dark and light zones to guide a glowing seed through an obstacle field | `round5.md` 4300–5364 |
| 105 | R05-G05 | `r05-g05.lightwell-labyrinth` | Lightwell Labyrinth | Wave optics | 93.56 | 71 | Connect light shafts across stacked rooms using reflective shutters | `round5.md` 5365–6429 |
| 106 | R05-G06 | `r05-g06.crystal-papercraft` | Crystal Papercraft | Spatial origami | 93.56 | 72 | Convert flat polygon outlines into crystalline structures under constraints | `round5.md` 6430–7494 |
| 107 | R05-G07 | `r05-g07.tetrahedral-labyrinth` | Tetrahedral Labyrinth | Spatial origami | 93.56 | 73 | Open selected solid faces to uncover a hidden route across cell layers | `round5.md` 7495–8559 |
| 108 | R05-G08 | `r05-g08.time-tessellation` | Time Tessellation | Temporal puzzles | 93.56 | 74 | Schedule tile rotations so their projected paths form a pattern | `round5.md` 8560–9624 |
| 109 | R05-G09 | `r05-g09.chrono-orchard` | Chrono Orchard | Temporal puzzles | 93.56 | 75 | Plant seed events at different times so growing trees form target arches | `round5.md` 9625–10689 |
| 110 | R05-G10 | `r05-g10.future-shadow` | Future Shadow | Temporal puzzles | 93.56 | 76 | Position occluders now to meet a target shadow several seconds later | `round5.md` 10690–11754 |
| 111 | R05-G11 | `r05-g11.bellflower-cavern` | Bellflower Cavern | Acoustic geometry | 93.56 | 77 | Strike floating bells in sequence to open procedural caves | `round5.md` 11755–12819 |
| 112 | R05-G12 | `r05-g12.petal-palace` | Petal Palace | Folded architecture | 93.54 | 78 | Close and unfold radial walls to route visitors represented by light points | `round5.md` 12820–13884 |
| 113 | R05-G13 | `r05-g13.tessera-passage` | Tessera Passage | Folded architecture | 93.53 | 79 | Flip triangular platforms to connect a route across voids | `round5.md` 13885–14949 |
| 114 | R05-G14 | `r05-g14.looped-waterfall` | Looped Waterfall | Temporal puzzles | 93.53 | 80 | Change time offsets to bring waterfall drops into matching sockets | `round5.md` 14950–16014 |
| 115 | R05-G15 | `r05-g15.iris-cascade` | Iris Cascade | Chromatic logic | 93.52 | 81 | Control an iris aperture chain to pass a precise sequence of colored pulses | `round5.md` 16015–17079 |
| 116 | R05-G16 | `r05-g16.hypercube-windows` | Hypercube Windows | Spatial origami | 93.52 | 82 | Rotate projections of a four-dimensional object to find a 3D path | `round5.md` 17080–18144 |
| 117 | R05-G17 | `r05-g17.opal-circuit` | Opal Circuit | Wave optics | 93.49 | 83 | Route flowing light through crystal switches whose colors change with orientation | `round5.md` 18145–19209 |
| 118 | R05-G18 | `r05-g18.cinder-symphony` | Cinder Symphony | Particle fields | 93.49 | 84 | Tune upward thermal flows so ember particles strike bells | `round5.md` 19210–20274 |
| 119 | R05-G19 | `r05-g19.spectral-cathedral` | Spectral Cathedral | Wave optics | 93.49 | 85 | Tune colored crystal ribs to produce a target spatial light chord | `round5.md` 20275–21339 |
| 120 | R05-G20 | `r05-g20.resonance-locksmith` | Resonance Locksmith | Acoustic geometry | 93.49 | 86 | Match three-dimensional standing-wave nodes to unlock a sealed chamber | `round5.md` 21340–22404 |
| 121 | R05-G21 | `r05-g21.tessellation-reef` | Tessellation Reef | Crystal solids | 93.46 | 87 | Cover a curved reef with nonoverlapping crystal polyhedra | `round5.md` 22405–23469 |
| 122 | R05-G22 | `r05-g22.frequency-ferryman` | Frequency Ferryman | Acoustic geometry | 93.43 | 89 | Navigate a tiny craft through moving standing-wave walls by changing pitch | `round5.md` 23470–24534 |
| 123 | R05-G23 | `r05-g23.caustic-courtyard` | Caustic Courtyard | Wave optics | 93.42 | 90 | Rotate mirrored arches so moving light rings illuminate hidden floor runes | `round5.md` 24535–25599 |
| 124 | R05-G24 | `r05-g24.photon-loom` | Photon Loom | Wave optics | 93.42 | 91 | Cross filaments of light through three-dimensional knots without tangling them | `round5.md` 25600–26664 |
| 125 | R05-G25 | `r05-g25.stardust-weaver` | Stardust Weaver | Particle fields | 93.42 | 92 | Draw attraction fields that braid star dust into luminous ribbons | `round5.md` 26665–27729 |
| 126 | R06-G01 | `r06-g01.iridescent-vault` | Iridescent Vault | Wave optics | 93.42 | 93 | Turn geometric irises until a hidden safe reveals its sequence of colors | `round6.md` 1106–2170 |
| 127 | R06-G02 | `r06-g02.silhouette-bridge` | Silhouette Bridge | Shadow construction | 93.41 | 94 | Position cubes and cylinders to cast a traversable shadow bridge | `round6.md` 2171–3235 |
| 128 | R06-G03 | `r06-g03.silhouette-reef` | Silhouette Reef | Shadow construction | 93.41 | 95 | Plant rigid coral branches to cast a single shadow creature | `round6.md` 3236–4300 |
| 129 | R06-G04 | `r06-g04.glass-shade` | Glass Shade | Shadow construction | 93.41 | 96 | Place semitransparent panels to achieve a prescribed multicolor shadow | `round6.md` 4301–5365 |
| 130 | R06-G05 | `r06-g05.shadowclock-atelier` | Shadowclock Atelier | Shadow construction | 93.41 | 97 | Build a geometric sculpture whose shadow marks the correct time | `round6.md` 5366–6430 |
| 131 | R06-G06 | `r06-g06.hinge-labyrinth` | Hinge Labyrinth | Folded architecture | 93.4 | 98 | Pivot groups of rooms to create a continuous walkable route | `round6.md` 6431–7495 |
| 132 | R06-G07 | `r06-g07.spectrum-loomhouse` | Spectrum Loomhouse | Chromatic logic | 93.39 | 99 | Weave colored ribbons between pegs without invalid crossings | `round6.md` 7496–8560 |
| 133 | R06-G08 | `r06-g08.chroma-ribbons` | Chroma Ribbons | Chromatic logic | 93.39 | 100 | Twist layered ribbons to make a specified projected color arrangement | `round6.md` 8561–9625 |
| 134 | R06-G09 | `r06-g09.kinetic-tessera` | Kinetic Tessera | Spatial origami | 93.39 | 101 | Drag triangulated folds to form a target three-dimensional relief | `round6.md` 9626–10690 |
| 135 | R06-G10 | `r06-g10.polyhedral-tea-garden` | Polyhedral Tea Garden | Spatial origami | 93.38 | 102 | Fold garden terraces around a solid core to route water between plants | `round6.md` 10691–11755 |
| 136 | R06-G11 | `r06-g11.chord-chamber` | Chord Chamber | Acoustic geometry | 93.38 | 103 | Rearrange floating resonators until three sound fields overlap at the goal | `round6.md` 11756–12820 |
| 137 | R06-G12 | `r06-g12.polyhedron-courier` | Polyhedron Courier | Spatial origami | 93.37 | 104 | Guide a bead over faces of a rotating polyhedron by unfolding pathways | `round6.md` 12821–13885 |
| 138 | R06-G13 | `r06-g13.origami-orbit` | Origami Orbit | Spatial origami | 93.37 | 105 | Fold thin solar sails to capture light and change a miniature orbit | `round6.md` 13886–14950 |
| 139 | R06-G14 | `r06-g14.dustlight-labyrinth` | Dustlight Labyrinth | Particle fields | 93.36 | 106 | Illuminate particle streams only at correct points to infer invisible exits | `round6.md` 14951–16015 |
| 140 | R06-G15 | `r06-g15.rotary-stairwell` | Rotary Stairwell | Folded architecture | 93.35 | 107 | Twist stacked tower floors to create a continuous helix to the summit | `round6.md` 16016–17080 |
| 141 | R06-G16 | `r06-g16.chromatic-observatory` | Chromatic Observatory | Wave optics | 93.35 | 108 | Align observatory shutters to separate three overlapping constellations | `round6.md` 17081–18145 |
| 142 | R06-G17 | `r06-g17.vibration-garden` | Vibration Garden | Acoustic geometry | 93.35 | 109 | Tune ground resonators to make dormant geometric plants unfold | `round6.md` 18146–19210 |
| 143 | R06-G18 | `r06-g18.pulse-flock` | Pulse Flock | Particle fields | 93.34 | 110 | Synchronize multiple swarms by changing phase and field shape | `round6.md` 19211–20275 |
| 144 | R06-G19 | `r06-g19.spiral-net` | Spiral Net | Spatial origami | 93.33 | 111 | Flatten and refold connected surfaces until two geometric marks meet | `round6.md` 20276–21340 |
| 145 | R06-G20 | `r06-g20.nebula-navigator` | Nebula Navigator | Celestial exploration | 93.31 | 112 | Chart a safe route through drifting interstellar fog using timed beacon flashes | `round6.md` 21341–22405 |
| 146 | R06-G21 | `r06-g21.sonic-origami` | Sonic Origami | Acoustic geometry | 93.31 | 113 | Fold sound-reflecting panels into resonant three-dimensional instruments | `round6.md` 22406–23470 |
| 147 | R06-G22 | `r06-g22.nebular-weave` | Nebular Weave | Celestial exploration | 93.3 | 114 | Adjust magnetic controls to turn drifting dust into constellation curtains | `round6.md` 23471–24535 |
| 148 | R06-G23 | `r06-g23.gemstone-transit` | Gemstone Transit | Crystal solids | 93.28 | 115 | Switch faceted nodes so traveling pulses reach the correct gems | `round6.md` 24536–25600 |
| 149 | R06-G24 | `r06-g24.radiant-staircase` | Radiant Staircase | Wave optics | 93.28 | 116 | Place luminous stairs to guide bouncing light upward through a tower | `round6.md` 25601–26665 |
| 150 | R06-G25 | `r06-g25.echo-current` | Echo Current | Acoustic geometry | 93.28 | 117 | Turn sound mirrors to push an acoustic energy packet through branching spaces | `round6.md` 26666–27730 |
| 151 | R07-G01 | `r07-g01.tuning-forest` | Tuning Forest | Acoustic geometry | 93.28 | 118 | Find resonant paths through an array of glowing tuning-fork trees | `round7.md` 1107–2171 |
| 152 | R07-G02 | `r07-g02.folded-constellations` | Folded Constellations | Spatial origami | 93.25 | 119 | Fold a paper star map to align distant star groups across depth | `round7.md` 2172–3236 |
| 153 | R07-G03 | `r07-g03.accordion-universe` | Accordion Universe | Spatial origami | 93.25 | 120 | Compress linked space strips to bring drifting planets into alignment | `round7.md` 3237–4301 |
| 154 | R07-G04 | `r07-g04.wavepool-mosaic` | Wavepool Mosaic | Fluid flow | 93.24 | 121 | Arrange baffles so colliding ripples reveal a target colored floor pattern | `round7.md` 4302–5366 |
| 155 | R07-G05 | `r07-g05.petal-swarm` | Petal Swarm | Particle fields | 93.23 | 122 | Direct geometric petals as a coherent flock through floating hoops | `round7.md` 5367–6431 |
| 156 | R07-G06 | `r07-g06.mirror-orchard` | Mirror Orchard | Wave optics | 93.23 | 123 | Redirect sunbeams among tiny reflective trees to ripen luminous fruit | `round7.md` 6432–7496 |
| 157 | R07-G07 | `r07-g07.firefly-signal` | Firefly Signal | Particle fields | 93.23 | 124 | Organize swarms of light points into evolving formation signals | `round7.md` 7497–8561 |
| 158 | R07-G08 | `r07-g08.borealis-swarm` | Borealis Swarm | Particle fields | 93.23 | 125 | Shepherd illuminated particles through auroral portals | `round7.md` 8562–9626 |
| 159 | R07-G09 | `r07-g09.meteor-sketch` | Meteor Sketch | Particle fields | 93.23 | 126 | Aim showers of particles to sketch a star symbol before they fade | `round7.md` 9627–10691 |
| 160 | R07-G10 | `r07-g10.cube-unfurl` | Cube Unfurl | Folded architecture | 93.23 | 127 | Choose a net arrangement for a cube whose faces contain matching channels | `round7.md` 10692–11756 |
| 161 | R07-G11 | `r07-g11.echo-gallery` | Echo Gallery | Acoustic geometry | 93.23 | 128 | Find the shortest route through invisible galleries using reflections of sound | `round7.md` 11757–12821 |
| 162 | R07-G12 | `r07-g12.folded-lighthouse` | Folded Lighthouse | Folded architecture | 93.21 | 129 | Fold a tower outward to redirect its beacon into hidden coves | `round7.md` 12822–13886 |
| 163 | R07-G13 | `r07-g13.unfolded-city` | Unfolded City | Spatial origami | 93.2 | 130 | Expand a tiny 3D city into a planar blueprint to connect streets | `round7.md` 13887–14951 |
| 164 | R07-G14 | `r07-g14.pulse-beacon-chase` | Pulse Beacon Chase | Acoustic geometry | 93.19 | 131 | Track a moving beacon through obscured chambers using limited pings | `round7.md` 14952–16016 |
| 165 | R07-G15 | `r07-g15.foldscape` | Foldscape | Spatial puzzles | 93.18 | 132 | Fold panels to connect safe paths for a moving light seed | `round7.md` 16017–17081 |
| 166 | R07-G16 | `r07-g16.exoplanet-atlas` | Exoplanet Atlas | Celestial exploration | 93.17 | 133 | Derive a target planetary composition from orbital readings | `round7.md` 17082–18146 |
| 167 | R07-G17 | `r07-g17.wave-choir` | Wave Choir | Light and color | 93.15 | 134 | Align phase and amplitude so interacting sound waves solve a spatial chord | `round7.md` 18147–19211 |
| 168 | R07-G18 | `r07-g18.quartz-labyrinth` | Quartz Labyrinth | Crystal solids | 93.14 | 136 | Carve a short corridor inside a rotating transparent mineral block | `round7.md` 19212–20276 |
| 169 | R07-G19 | `r07-g19.lantern-interference` | Lantern Interference | Wave optics | 93.13 | 137 | Slide floating lamps until their overlapping wavefronts trace a solution glyph | `round7.md` 20277–21341 |
| 170 | R07-G20 | `r07-g20.shooting-star-garden` | Shooting Star Garden | Particle fields | 93.13 | 138 | Plant gravity wells to catch falling stars without collisions | `round7.md` 21342–22406 |
| 171 | R07-G21 | `r07-g21.pulsar-keeper` | Pulsar Keeper | Celestial exploration | 93.1 | 139 | Rotate detection dishes to follow rhythmic pulsar beams through space | `round7.md` 22407–23471 |
| 172 | R07-G22 | `r07-g22.comet-harbor` | Comet Harbor | Celestial exploration | 93.1 | 140 | Dock light sails at orbiting stations using prediction arcs | `round7.md` 23472–24536 |
| 173 | R07-G23 | `r07-g23.interstellar-orchard` | Interstellar Orchard | Celestial exploration | 93.1 | 141 | Cultivate glowing seed-worlds by balancing starlight and orbital distance | `round7.md` 24537–25601 |
| 174 | R07-G24 | `r07-g24.penumbra-puzzlebox` | Penumbra Puzzlebox | Shadow construction | 93.1 | 142 | Adjust occluders until multiple overlapping shadow softness regions match | `round7.md` 25602–26666 |
| 175 | R07-G25 | `r07-g25.shadow-orchard-keeper` | Shadow Orchard Keeper | Shadow construction | 93.1 | 143 | Prune procedural tree branches until their projection matches a glyph | `round7.md` 26667–27731 |
| 176 | R08-G01 | `r08-g01.origami-observatory` | Origami Observatory | Folded architecture | 93.1 | 144 | Reconfigure a folding dome so its star apertures align | `round8.md` 1108–2172 |
| 177 | R08-G02 | `r08-g02.halo-locksmith` | Halo Locksmith | Wave optics | 93.08 | 145 | Adjust concentric light gates until a spectral key can travel through them | `round8.md` 2173–3237 |
| 178 | R08-G03 | `r08-g03.tesseract-lanterns` | Tesseract Lanterns | Wave optics | 93.08 | 146 | Reorient rotating cube lanterns to illuminate inaccessible dimensional corners | `round8.md` 3238–4302 |
| 179 | R08-G04 | `r08-g04.infinity-fold` | Infinity Fold | Spatial origami | 93.07 | 147 | Rotate linked panels to make an impossible-looking continuous walkway | `round8.md` 4303–5367 |
| 180 | R08-G05 | `r08-g05.mirrorfold-lab` | Mirrorfold Lab | Spatial origami | 93.07 | 148 | Fold reflective polygons until a beam loops back to its source | `round8.md` 5368–6432 |
| 181 | R08-G06 | `r08-g06.particle-ballet` | Particle Ballet | Light and color | 93.05 | 150 | Draw orbital gestures to move swarms into emergent shapes | `round8.md` 6433–7497 |
| 182 | R08-G07 | `r08-g07.algae-planet` | Algae Planet | Micro ecosystems | 93.04 | 152 | Balance daylight and nutrient rings around a tiny water-covered planet | `round8.md` 7498–8562 |
| 183 | R08-G08 | `r08-g08.fold-tide` | Fold Tide | Folded architecture | 93.04 | 153 | Lift and crease flexible water tiles to redirect a moving current | `round8.md` 8563–9627 |
| 184 | R08-G09 | `r08-g09.origami-windmill` | Origami Windmill | Folded architecture | 93.04 | 154 | Fold and unfold a rotor to capture changing winds | `round8.md` 9628–10692 |
| 185 | R08-G10 | `r08-g10.paper-skybridges` | Paper Skybridges | Folded architecture | 93.04 | 155 | Fold connected panels to span a gap without breaking a path | `round8.md` 10693–11757 |
| 186 | R08-G11 | `r08-g11.kaleidoscope-bridge` | Kaleidoscope Bridge | Folded architecture | 93.04 | 156 | Rotate hinged mirrored plates to connect a fragmented world image | `round8.md` 11758–12822 |
| 187 | R08-G12 | `r08-g12.color-currents` | Color Currents | Light and color | 93.02 | 157 | Move current sources to braid contrasting ribbons into goal vortices | `round8.md` 12823–13887 |
| 188 | R08-G13 | `r08-g13.confetti-gravity` | Confetti Gravity | Particle fields | 93.02 | 158 | Redirect gravity so multicolored particles pass through moving rings | `round8.md` 13888–14952 |
| 189 | R08-G14 | `r08-g14.magnetic-snow` | Magnetic Snow | Particle fields | 93.02 | 159 | Position polar magnets to build specific drifting snowflake constellations | `round8.md` 14953–16017 |
| 190 | R08-G15 | `r08-g15.twilight-moths` | Twilight Moths | Micro ecosystems | 93.0 | 160 | Guide motion-reactive geometric moths through a nocturnal flower garden | `round8.md` 16018–17082 |
| 191 | R08-G16 | `r08-g16.comet-shepherd` | Comet Shepherd | Orbital dynamics | 93.0 | 162 | Place temporary gravity wells to herd a family of comets into target orbits | `round8.md` 17083–18147 |
| 192 | R08-G17 | `r08-g17.sundial-constellation` | Sundial Constellation | Wave optics | 93.0 | 163 | Rotate miniature celestial mechanisms until multiple projected shadows agree | `round8.md` 18148–19212 |
| 193 | R08-G18 | `r08-g18.dust-ring-sculptor` | Dust Ring Sculptor | Celestial exploration | 92.96 | 164 | Move planet moons to shape bright rings into geometric motifs | `round8.md` 19213–20277 |
| 194 | R08-G19 | `r08-g19.ringed-worlds` | Ringed Worlds | Celestial exploration | 92.96 | 165 | Arrange moons to make orbiting ring shadows hit prescribed coordinates | `round8.md` 20278–21342 |
| 195 | R08-G20 | `r08-g20.origami-snow-globe` | Origami Snow Globe | Spatial origami | 92.96 | 166 | Fold an enclosing shell around a glittering swarm without trapping it | `round8.md` 21343–22407 |
| 196 | R08-G21 | `r08-g21.sonar-ruins` | Sonar Ruins | Acoustic geometry | 92.96 | 167 | Locate hidden landmarks by choosing pulse positions and interpreting returning echoes | `round8.md` 22408–23472 |
| 197 | R08-G22 | `r08-g22.whisper-atlas` | Whisper Atlas | Acoustic geometry | 92.96 | 168 | Reconstruct lost miniature cities from sparse sonar returns | `round8.md` 23473–24537 |
| 198 | R08-G23 | `r08-g23.sporefall` | Sporefall | Micro ecosystems | 92.94 | 169 | Choose safe release points for airborne glowing spores to seed distant islands | `round8.md` 24538–25602 |
| 199 | R08-G24 | `r08-g24.crystal-pond` | Crystal Pond | Micro ecosystems | 92.91 | 170 | Grow tessellated lily pads to balance light and water circulation | `round8.md` 25603–26667 |
| 200 | R08-G25 | `r08-g25.blacklight-planetarium` | Blacklight Planetarium | Celestial exploration | 92.91 | 171 | Reveal hidden stars by rotating ultraviolet-like filters around a dome | `round8.md` 26668–27732 |
| 201 | R09-G01 | `r09-g01.accordion-isles` | Accordion Isles | Folded architecture | 92.91 | 173 | Compress and stretch modular land strips until destinations touch | `round9.md` 1109–2173 |
| 202 | R09-G02 | `r09-g02.mirror-page` | Mirror Page | Folded architecture | 92.91 | 174 | Fold mirrored pages to project a specified shape into a shadow box | `round9.md` 2174–3238 |
| 203 | R09-G03 | `r09-g03.sky-quilt` | Sky Quilt | Folded architecture | 92.91 | 175 | Sew polygon panels into a draped three-dimensional floating quilt | `round9.md` 3239–4303 |
| 204 | R09-G04 | `r09-g04.glasshouse-prisms` | Glasshouse Prisms | Spatial puzzles | 92.91 | 176 | Reorient rooms and prism edges to illuminate all flowers | `round9.md` 4304–5368 |
| 205 | R09-G05 | `r09-g05.tidal-lens` | Tidal Lens | Fluid flow | 92.91 | 177 | Focus circular water waves to move tiny floating pearls into sockets | `round9.md` 5369–6433 |
| 206 | R09-G06 | `r09-g06.shadow-sculptor` | Shadow Sculptor | Spatial puzzles | 92.89 | 180 | Transform volume objects until their projected silhouette matches a target | `round9.md` 6434–7498 |
| 207 | R09-G07 | `r09-g07.tidal-petals` | Tidal Petals | Micro ecosystems | 92.88 | 181 | Control wave amplitude to keep floating flowers in a safe pattern | `round9.md` 7499–8563 |
| 208 | R09-G08 | `r09-g08.tidal-trio` | Tidal Trio | Orbital dynamics | 92.86 | 182 | Use three orbital bodies to stretch a luminous ocean into a pattern | `round9.md` 8564–9628 |
| 209 | R09-G09 | `r09-g09.vine-spiral` | Vine Spiral | Organic growth | 92.85 | 183 | Train recursive vines around towers to reach high solar patches | `round9.md` 9629–10693 |
| 210 | R09-G10 | `r09-g10.mobius-tram` | Mobius Tram | Folded architecture | 92.82 | 185 | Change twists in a looped railway to deliver a packet to the right side | `round9.md` 10694–11758 |
| 211 | R09-G11 | `r09-g11.star-nursery` | Star Nursery | Celestial exploration | 92.81 | 186 | Merge sparse gas clouds into a series of luminous protostars | `round9.md` 11759–12823 |
| 212 | R09-G12 | `r09-g12.cosmic-pendulum` | Cosmic Pendulum | Orbital dynamics | 92.81 | 187 | Dampen chained orbital oscillations before a timed planetary eclipse | `round9.md` 12824–13888 |
| 213 | R09-G13 | `r09-g13.glass-reef-gardener` | Glass Reef Gardener | Micro ecosystems | 92.8 | 188 | Plant algorithmic corals to shelter a moving school of luminous fish-like particles | `round9.md` 13889–14953 |
| 214 | R09-G14 | `r09-g14.bioluminescent-tide` | Bioluminescent Tide | Micro ecosystems | 92.8 | 189 | Guide nutrient currents so tiny tidepool organisms light in sequence | `round9.md` 14954–16018 |
| 215 | R09-G15 | `r09-g15.myco-river` | Myco River | Micro ecosystems | 92.8 | 190 | Connect fungal nodes so nutrients cross a miniature forest stream | `round9.md` 16019–17083 |
| 216 | R09-G16 | `r09-g16.moss-labyrinth` | Moss Labyrinth | Organic growth | 92.79 | 191 | Grow and prune moss to reveal safe corridors for moving light seeds | `round9.md` 17084–18148 |
| 217 | R09-G17 | `r09-g17.crystal-resonance` | Crystal Resonance | Light and color | 92.79 | 192 | Tap crystal nodes to tune resonance and open light gates | `round9.md` 18149–19213 |
| 218 | R09-G18 | `r09-g18.meteor-crater-lab` | Meteor Crater Lab | Terrain alchemy | 92.77 | 193 | Choose impact angles to imprint target crater arrangements | `round9.md` 19214–20278 |
| 219 | R09-G19 | `r09-g19.solar-flare-pilot` | Solar Flare Pilot | Celestial exploration | 92.76 | 194 | Steer a drone through repeating safe lanes between star eruptions | `round9.md` 20279–21343 |
| 220 | R09-G20 | `r09-g20.gravity-window` | Gravity Window | Celestial exploration | 92.75 | 195 | Move lenses of distorted space to reveal hidden distant objects | `round9.md` 21344–22408 |
| 221 | R09-G21 | `r09-g21.neon-clay` | Neon Clay | Light and color | 92.75 | 196 | Press and split neon clay masses to match an expressive sculpture | `round9.md` 22409–23473 |
| 222 | R09-G22 | `r09-g22.ringworld-courier` | Ringworld Courier | Orbital dynamics | 92.74 | 197 | Dock a glowing capsule by synchronizing motion with rotating rings | `round9.md` 23474–24538 |
| 223 | R09-G23 | `r09-g23.biolume-nursery` | Biolume Nursery | Organic growth | 92.72 | 198 | Balance nutrients so tiny living lamps bloom in a coordinated sequence | `round9.md` 24539–25603 |
| 224 | R09-G24 | `r09-g24.prismatic-rapids` | Prismatic Rapids | Fluid flow | 92.72 | 199 | Redirect colored currents through a field of translucent pylons | `round9.md` 25604–26668 |
| 225 | R09-G25 | `r09-g25.orbital-orchard` | Orbital Orchard | Cosmic puzzles | 92.72 | 200 | Tune moon orbits so solar light lands on floating garden seeds | `round9.md` 26669–27733 |
| 226 | R10-G01 | `r10-g01.firefly-pollination` | Firefly Pollination | Micro ecosystems | 92.7 | 201 | Lead firefly clusters through timed flower openings | `round10.md` 1110–2174 |
| 227 | R10-G02 | `r10-g02.orbit-mosaic` | Orbit Mosaic | Orbital dynamics | 92.69 | 202 | Link time-synchronized satellite paths into a closed decorative pattern | `round10.md` 2175–3239 |
| 228 | R10-G03 | `r10-g03.satellite-lace` | Satellite Lace | Orbital dynamics | 92.68 | 203 | Weave nonintersecting satellite paths through moving orbital gates | `round10.md` 3240–4304 |
| 229 | R10-G04 | `r10-g04.moonrise-mechanic` | Moonrise Mechanic | Orbital dynamics | 92.68 | 204 | Adjust a microplanet spin until three moon shadows create a target symbol | `round10.md` 4305–5369 |
| 230 | R10-G05 | `r10-g05.solar-mirror-fleet` | Solar Mirror Fleet | Orbital dynamics | 92.67 | 205 | Position orbital reflectors to illuminate darkness on multiple small worlds | `round10.md` 5370–6434 |
| 231 | R10-G06 | `r10-g06.cobalt-tide-clock` | Cobalt Tide Clock | Fluid flow | 92.67 | 206 | Synchronize wave gates to transport a bead at the crest of each surge | `round10.md` 6435–7499 |
| 232 | R10-G07 | `r10-g07.meteor-ballet` | Meteor Ballet | Celestial exploration | 92.63 | 207 | Time a tiny probe's maneuvers to pass between meteor showers | `round10.md` 7500–8564 |
| 233 | R10-G08 | `r10-g08.laser-ribbon` | Laser Ribbon | Light and color | 92.63 | 208 | Manipulate luminous 3D fields in laser ribbon to complete clear spatial goals | `round10.md` 8565–9629 |
| 234 | R10-G09 | `r10-g09.asteroid-calligrapher` | Asteroid Calligrapher | Orbital dynamics | 92.62 | 209 | Arrange small asteroids so their projected paths spell a glyph over time | `round10.md` 9630–10694 |
| 235 | R10-G10 | `r10-g10.microgravity-meadows` | Microgravity Meadows | Orbital dynamics | 92.62 | 210 | Reorient gravity vector to guide seeds across a rounded asteroid garden | `round10.md` 10695–11759 |
| 236 | R10-G11 | `r10-g11.spore-observatory` | Spore Observatory | Organic growth | 92.61 | 211 | Release timed spore clouds so colonies land on matching star-shaped beds | `round10.md` 11760–12824 |
| 237 | R10-G12 | `r10-g12.root-constellation` | Root Constellation | Micro ecosystems | 92.61 | 212 | Orient seeds so root networks form a specified underground star map | `round10.md` 12825–13889 |
| 238 | R10-G13 | `r10-g13.lichen-cathedral` | Lichen Cathedral | Organic growth | 92.59 | 213 | Grow patterned lichen across 3D arches according to moisture rules | `round10.md` 13890–14954 |
| 239 | R10-G14 | `r10-g14.glacier-sculptor` | Glacier Sculptor | Terrain alchemy | 92.59 | 214 | Route slow-moving ice to connect isolated valleys | `round10.md` 14955–16019 |
| 240 | R10-G15 | `r10-g15.terrace-rivers` | Terrace Rivers | Terrain alchemy | 92.59 | 215 | Carve terraces that carry water through three target gardens | `round10.md` 16020–17084 |
| 241 | R10-G16 | `r10-g16.crankwave-lab` | Crankwave Lab | Kinetic geometry | 92.58 | 216 | Tune linkages to produce a specified three-dimensional wave trajectory | `round10.md` 17085–18149 |
| 242 | R10-G17 | `r10-g17.volcano-glassworks` | Volcano Glassworks | Terrain alchemy | 92.57 | 217 | Dig channels to cool lava into a prescribed geometric structure | `round10.md` 18150–19214 |
| 243 | R10-G18 | `r10-g18.rainchain-atelier` | Rainchain Atelier | Fluid flow | 92.57 | 218 | Construct suspended drip chains that strike bells in a required rhythm | `round10.md` 19215–20279 |
| 244 | R10-G19 | `r10-g19.glow-maze` | Glow Maze | Light and color | 92.56 | 219 | Manipulate luminous 3D fields in glow maze to complete clear spatial goals | `round10.md` 20280–21344 |
| 245 | R10-G20 | `r10-g20.stellar-pinball` | Stellar Pinball | Orbital dynamics | 92.55 | 220 | Bend a tiny meteor through slingshot arcs to hit celestial targets | `round10.md` 21345–22409 |
| 246 | R10-G21 | `r10-g21.capillary-conductor` | Capillary Conductor | Organic growth | 92.54 | 221 | Redirect fluid through leaf-vein networks to revive a miniature canopy | `round10.md` 22410–23474 |
| 247 | R10-G22 | `r10-g22.seed-orbitarium` | Seed Orbitarium | Organic growth | 92.53 | 222 | Choose microgravity plant growth directions to assemble closed canopy rings | `round10.md` 23475–24539 |
| 248 | R10-G23 | `r10-g23.lava-maze` | Lava Maze | Terrain alchemy | 92.52 | 223 | Open basalt gates before a flowing lava front hardens | `round10.md` 24540–25604 |
| 249 | R10-G24 | `r10-g24.root-lanterns` | Root Lanterns | Organic growth | 92.51 | 224 | Steer underground roots toward nutrient nodes using directional gradients | `round10.md` 25605–26669 |
| 250 | R10-G25 | `r10-g25.crystal-fungus` | Crystal Fungus | Organic growth | 92.51 | 225 | Guide a hybrid fungal-crystal organism to bridge gaps without fracture | `round10.md` 26670–27734 |
| 251 | R11-G01 | `r11-g01.phosphor-tangle` | Phosphor Tangle | Organic growth | 92.51 | 226 | Untangle luminous algae tendrils by manipulating local attraction fields | `round11.md` 1111–2175 |
| 252 | R11-G02 | `r11-g02.branch-choir` | Branch Choir | Organic growth | 92.51 | 227 | Arrange growth cues so tree branches produce spatial harmonic silhouettes | `round11.md` 2176–3240 |
| 253 | R11-G03 | `r11-g03.gravity-harp` | Gravity Harp | Orbital dynamics | 92.5 | 228 | Pluck planetoid orbits into a harmonic chord without collisions | `round11.md` 3241–4305 |
| 254 | R11-G04 | `r11-g04.petal-circuit` | Petal Circuit | Organic growth | 92.46 | 229 | Propagate electrical pulses through a garden of connected petal-flowers | `round11.md` 4306–5370 |
| 255 | R11-G05 | `r11-g05.glow-river` | Glow River | Light and color | 92.46 | 230 | Manipulate luminous 3D fields in glow river to complete clear spatial goals | `round11.md` 5371–6435 |
| 256 | R11-G06 | `r11-g06.prism-garden` | Prism Garden | Light and color | 92.46 | 231 | Manipulate luminous 3D fields in prism garden to complete clear spatial goals | `round11.md` 6436–7500 |
| 257 | R11-G07 | `r11-g07.dune-resonator` | Dune Resonator | Terrain alchemy | 92.45 | 232 | Set wind emitters to form specified rippling patterns in sand | `round11.md` 7501–8565 |
| 258 | R11-G08 | `r11-g08.reflection-pool` | Reflection Pool | Light and color | 92.44 | 233 | Manipulate luminous 3D fields in reflection pool to complete clear spatial goals | `round11.md` 8566–9630 |
| 259 | R11-G09 | `r11-g09.silt-cartographer` | Silt Cartographer | Fluid flow | 92.41 | 234 | Change current direction to uncover a hidden relief map in sand | `round11.md` 9631–10695 |
| 260 | R11-G10 | `r11-g10.balance-bazaar` | Balance Bazaar | Kinetic geometry | 92.39 | 235 | Arrange geometrical weights to keep a stack of moving sculpture plates steady | `round11.md` 10696–11760 |
| 261 | R11-G11 | `r11-g11.mountain-lightkeeper` | Mountain Lightkeeper | Terrain alchemy | 92.38 | 236 | Reposition peaks so the sun touches marked landforms at sunrise | `round11.md` 11761–12825 |
| 262 | R11-G12 | `r11-g12.ridge-relay` | Ridge Relay | Terrain alchemy | 92.38 | 237 | Raise mountain ridges to guide gliding light signals between summits | `round11.md` 12826–13890 |
| 263 | R11-G13 | `r11-g13.gossamer-reef` | Gossamer Reef | Micro ecosystems | 92.36 | 238 | Grow strands of silk-like coral to catch falling motes without blocking water | `round11.md` 13891–14955 |
| 264 | R11-G14 | `r11-g14.kepler-carousel` | Kepler Carousel | Orbital dynamics | 92.36 | 239 | Predict where multiple planets meet and place time-limited orbital gates | `round11.md` 14956–16020 |
| 265 | R11-G15 | `r11-g15.spectrum-seasons` | Spectrum Seasons | Light and color | 92.34 | 240 | Manipulate luminous 3D fields in spectrum seasons to complete clear spatial goals | `round11.md` 16021–17085 |
| 266 | R11-G16 | `r11-g16.coral-calculus` | Coral Calculus | Organic growth | 92.32 | 241 | Guide reef growth to surround safe areas without blocking currents | `round11.md` 17086–18150 |
| 267 | R11-G17 | `r11-g17.river-meander` | River Meander | Terrain alchemy | 92.32 | 242 | Nudge a river's banks to connect nutrient deposits without flooding | `round11.md` 18151–19215 |
| 268 | R11-G18 | `r11-g18.seafloor-cartographer` | Seafloor Cartographer | Terrain alchemy | 92.27 | 243 | Change local currents to uncover a hidden 3D underwater map | `round11.md` 19216–20280 |
| 269 | R11-G19 | `r11-g19.suspended-equilibrium` | Suspended Equilibrium | Kinetic geometry | 92.26 | 244 | Place magnetic counterweights to hold a floating geometric shrine in balance | `round11.md` 20281–21345 |
| 270 | R11-G20 | `r11-g20.tidepool-relief` | Tidepool Relief | Terrain alchemy | 92.19 | 245 | Alter coastline elevations to trap water in small safe pools | `round11.md` 21346–22410 |
| 271 | R11-G21 | `r11-g21.horizon-sculpt` | Horizon Sculpt | Terrain alchemy | 92.19 | 246 | Move terrain control points to form a precise sky silhouette | `round11.md` 22411–23475 |
| 272 | R11-G22 | `r11-g22.sandline-architect` | Sandline Architect | Terrain alchemy | 92.18 | 247 | Tilt a miniature desert to make dunes expose buried monuments | `round11.md` 23476–24540 |
| 273 | R11-G23 | `r11-g23.orbiting-chimes` | Orbiting Chimes | Kinetic geometry | 92.13 | 248 | Route a bouncing point among rotating musical rings | `round11.md` 24541–25605 |
| 274 | R11-G24 | `r11-g24.bonsai-rain-engine` | Bonsai Rain Engine | Organic growth | 92.08 | 249 | Shape miniature canopies to collect enough rainfall for new shoots | `round11.md` 25606–26670 |
| 275 | R11-G25 | `r11-g25.holographic-tides` | Holographic Tides | Wave optics | 91.79 | supplemental (provisional score) | Rotate interference plates until three moving light crests focus on marked shoreline gates | `round11.md` 26671–27735 |
| 276 | R12-G01 | `r12-g01.isochron-spires` | Isochron Spires | Temporal puzzles | 91.76 | supplemental (provisional score) | Sequence phase-shifted towers so a single pulse visits every crest at the same cycle | `round12.md` 1112–2176 |
| 277 | R12-G02 | `r12-g02.spectral-rainwright` | Spectral Rainwright | Light and color | 91.74 | supplemental (provisional score) | Place refractors to route colored rainfall into monochromatic basins | `round12.md` 2177–3241 |
| 278 | R12-G03 | `r12-g03.topology-lantern` | Topology Lantern | Spatial origami | 91.72 | supplemental (provisional score) | Fold a closed lantern net into a nonselfintersecting illuminated 3D manifold | `round12.md` 3242–4306 |
| 279 | R12-G04 | `r12-g04.vortex-observatory` | Vortex Observatory | Fluid flow | 91.69 | supplemental (provisional score) | Counter-steer three stable vortices to carry tracer islands across a shallow pool | `round12.md` 4307–5371 |
| 280 | R12-G05 | `r12-g05.granular-aurora` | Granular Aurora | Particle fields | 91.67 | supplemental (provisional score) | Reshape a bounded force field to sort glowing grains into target constellations | `round12.md` 5372–6436 |
| 281 | R12-G06 | `r12-g06.gyroid-harbor` | Gyroid Harbor | Spatial origami | 91.64 | supplemental (provisional score) | Rotate and align periodic gyroid portals for a continuous courier route | `round12.md` 6437–7501 |
| 282 | R12-G07 | `r12-g07.chromatic-kites` | Chromatic Kites | Chromatic logic | 91.62 | supplemental (provisional score) | Choose kite orientation and spectrum to satisfy wind-gated color checkpoints | `round12.md` 7502–8566 |
| 283 | R12-G08 | `r12-g08.voxel-bloom-engine` | Voxel Bloom Engine | Folded architecture | 91.59 | supplemental (provisional score) | Hinge voxel petals into prescribed 3D flower patterns without self-collision | `round12.md` 8567–9631 |
| 284 | R12-G09 | `r12-g09.polarization-workshop` | Polarization Workshop | Wave optics | 91.57 | supplemental (provisional score) | Rotate optical filter axes so a laser passes a chain of polarization gates | `round12.md` 9632–10696 |
| 285 | R12-G10 | `r12-g10.magnetic-origami` | Magnetic Origami | Spatial origami | 91.54 | supplemental (provisional score) | Position attractors to fold magnetic polyhedral sheets into stable targets | `round12.md` 10697–11761 |
| 286 | R12-G11 | `r12-g11.seismic-rosette` | Seismic Rosette | Terrain alchemy | 91.51 | supplemental (provisional score) | Place resonant sources to inscribe a target contour in a vibrating sand terrace | `round12.md` 11762–12826 |
| 287 | R12-G12 | `r12-g12.photonic-cartwheel` | Photonic Cartwheel | Wave mathematics | 91.49 | supplemental (provisional score) | Tune rotating harmonics to align petals of a circular interference wheel | `round12.md` 12827–13891 |
| 288 | R12-G13 | `r12-g13.neutrino-grove` | Neutrino Grove | Particle fields | 91.47 | supplemental (provisional score) | Modulate nonphysical particle scattering fields to steer light dots through grove gates | `round12.md` 13892–14956 |
| 289 | R12-G14 | `r12-g14.surface-tension-atelier` | Surface Tension Atelier | Fluid flow | 91.44 | supplemental (provisional score) | Raise pins within a shallow mesh to transport a marble through curvature basins | `round12.md` 14957–16021 |
| 290 | R12-G15 | `r12-g15.torus-garden` | Torus Garden | Kinetic geometry | 91.42 | supplemental (provisional score) | Align rotating toroidal rings to capture and release seeds into numbered receptacles | `round12.md` 16022–17086 |
| 291 | R12-G16 | `r12-g16.penumbra-relay` | Penumbra Relay | Shadow construction | 91.39 | supplemental (provisional score) | Position procedural occluders to pass a moving shadow token across islands | `round12.md` 17087–18151 |
| 292 | R12-G17 | `r12-g17.tidal-musicbox` | Tidal Musicbox | Fluid flow | 91.37 | supplemental (provisional score) | Gate miniature waves so resonant water clocks strike target rhythm slots | `round12.md` 18152–19216 |
| 293 | R12-G18 | `r12-g18.crystal-growth-compass` | Crystal Growth Compass | Crystal solids | 91.34 | supplemental (provisional score) | Place crystal nucleation seeds and grow a bounded lattice matching target normals | `round12.md` 19217–20281 |
| 294 | R12-G19 | `r12-g19.gravitation-weave` | Gravitation Weave | Orbital dynamics | 91.32 | supplemental (provisional score) | Select discrete gravitational masses to form three intertwined safe orbital loops | `round12.md` 20282–21346 |
| 295 | R12-G20 | `r12-g20.harmonic-sandscape` | Harmonic Sandscape | Terrain alchemy | 91.29 | supplemental (provisional score) | Tune vibration frequencies to transport grains into stable relief outlines | `round12.md` 21347–22411 |
| 296 | R12-G21 | `r12-g21.orbitloom-lanterns` | Orbitloom Lanterns | Celestial exploration | 91.26 | supplemental (provisional score) | Schedule lantern satellites to trace specified constellation curves | `round12.md` 22412–23476 |
| 297 | R12-G22 | `r12-g22.fractal-shoal` | Fractal Shoal | Micro ecosystems | 91.24 | supplemental (provisional score) | Balance branching coral growth and light availability in a bounded marine diorama | `round12.md` 23477–24541 |
| 298 | R12-G23 | `r12-g23.volumetric-kaleidoscope` | Volumetric Kaleidoscope | Wave optics | 91.22 | supplemental (provisional score) | Rotate mirrored plane arrays to connect a ray to a target through repeated reflections | `round12.md` 24542–25606 |
| 299 | R12-G24 | `r12-g24.luminal-topography` | Luminal Topography | Terrain alchemy | 91.19 | supplemental (provisional score) | Sculpt a heightfield so sunset shadows illuminate a sequence of beacons | `round12.md` 25607–26671 |
| 300 | R12-G25 | `r12-g25.helio-pendulum-lab` | Helio Pendulum Lab | Kinetic geometry | 91.17 | supplemental (provisional score) | Tune coupled pendulums to project synchronized solar paths within a time window | `round12.md` 26672–27736 |
<!-- GENERATED:END backlog -->

# Part III — Architecture

Names of types, modules and files that do not exist today are **proposals**. They are marked "(new)" where they
first appear, and the `/speckit-plan` stage of the owning feature confirms or corrects each against the real code.
Names without that mark exist in the source today.

## 11. App architecture

```
┌──────────────────────────── Apps/VisualCore (new) ───────────────────────────┐
│ VisualCoreApp · launcher · search · settings · about · paywall · onboarding  │
│ AppModel: catalog, entitlement, session, preferences                         │
└───────────────┬──────────────────────────────┬───────────────────────────────┘
                │ opens one experience          │ reads
┌───────────────▼───────────────┐   ┌───────────▼────────────┐  ┌──────────────┐
│ VisualCoreExperienceHost (new)│   │ VisualCoreExperience   │  │ VisualCore-  │
│ ExperienceSession, HostView   │   │ (new, pure): ids,      │  │ Store (new)  │
│ one RenderHost + budget       │   │ catalog, lifecycle,    │  │ StoreKit 2   │
└───────────────┬───────────────┘   │ snapshots, entitlement │  └──────────────┘
                │ runs               └────────────────────────┘
┌───────────────▼──────────────────────────────────────────────────────────────┐
│ Experience packages (new): ExperiencesCreative · ExperiencesRound02 ·         │
│ ExperiencesRound03 · ExperiencesRound04 — per experience a pure Core target   │
│ and an Experience target; experiences never import each other                 │
└───────────────┬──────────────────────────────────────────────────────────────┘
                │ use
┌───────────────▼──────────────────────────────────────────────────────────────┐
│ Packages/VisualCore (pure) · Packages/VisualCoreRendering (GPU, UIKit)        │
│ OpenGL ES 3.0 → EGL → ANGLE → Metal                                           │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 11.1 App target and shell

- `Apps/VisualCore/` (created by UA-F04) is the only shippable target. It contains the SwiftUI app type, the launcher, search,
  category views, the experience route, settings, the about and acknowledgements screens, the paywall and the
  onboarding. It owns navigation, accessibility identifiers, free and premium labelling and the app lifecycle.
- The app links the framework packages and the experience packages statically. Experiences are registered in
  explicit lists (one per experience package) that are generated or validated from the catalog. Nothing is loaded
  dynamically; `dlopen` and `dlsym` stay forbidden.
- The launcher uses no GL. Tiles are drawn with SwiftUI from each experience's palette and seed, so opening the
  app creates no rendering context and costs no shader compilation.
- Independent start-up work (catalog load, preference load, entitlement refresh) runs concurrently. The launcher
  never waits for the store.
- `Showcase`, the harnesses and, until they are retired, the four standalone apps remain non-shipping targets.
- ProjectM engine and preset code is never linked into the app (checked on the built product).
- The app target's Swift module is named `VisualCoreApp` so that it cannot be confused with the
  framework package `VisualCore`; the display name stays VisualCore.
- Placeholder identifiers approved by the owner stay as they are until OD-02 is decided: `dev.visualcore.<Name>`
  (the Showcase is `dev.visualcore.Showcase`, the harnesses `dev.visualcore.harness.*`). The App Store name is
  settled before the bundle identifier, because the identifier is permanent once a build is uploaded and the
  in-app product hangs off it; a later rename changes only target, scheme and product name. The home-screen name
  is `CFBundleDisplayName`.

### 11.2 Catalog and identity

- Pure module `VisualCoreExperience` (in `Packages/VisualCore`, UA-F01) defines `ExperienceCode`, `ExperienceID`,
  `ExperienceDescriptor`, `ExperienceTier`, `ExperienceKind`, `ExperienceCategory`, a validated `CatalogManifest`,
  `CategoryList`, `CatalogSearch`, `RegistryReport` and `SourceMoveMap`. Every name derived from an experience
  comes from `ExperienceID`: the gate `X-<code>`, the storage namespace and evidence name (the id) and the
  accessibility prefix `experience.<id>`.
- `scripts/build_catalog.py` derives the runtime manifest `Catalog/experiences.json` from the planning catalog,
  the migration ledger (availability) and `Catalog/registrations.json`, where an integrated experience declares
  its capabilities, quality tiers, tile colors and content facts; `Catalog/categories.json` holds category order
  and titles; `Catalog/path-map.json` records every executed source move (the plan of the moves is
  `docs/migration/path-map.json`). `python3 scripts/build_catalog.py --check` proves that the committed files and
  the copies the package tests use are what the tool writes; CI runs it.
- The loader refuses data over 1,048,576 bytes, unknown schema versions, keys the schema does not define,
  duplicate ids, missing fields, values over their limits and numbers that are not finite, whole and in range,
  each with one typed `CatalogError` (constitution IX). The launch allocation (50 free, 50 premium) is a rule of
  the loader, not data.
- A registry check proves a one-to-one match between manifest entries marked available and registered
  factories. `Catalog/experience-ids.golden.txt` lists all 300 ids of the planning catalog and only grows: any
  change of an id is a test failure.
- Search folds text without any language setting (compatibility decomposition, no combining marks, lower case,
  dotless i as i) and orders results by the weakest field a word needed (title, tags, summary), then by catalog
  order.

Schema of the runtime manifest (`Catalog/experiences.json`, schema version 1):

| Field | Type | Meaning |
|---|---|---|
| `schema`, `catalog_sha256` | number, string | manifest version and the hash of the planning catalog it was built from |
| `id`, `code` | string | immutable runtime id and catalog code |
| `title`, `summary` | string | display text |
| `kind` | `creative` or `game` | |
| `tier` | `free` or `premium` | what the entitlement gate reads |
| `category`, `family`, `tags` | string, string, list | launcher grouping and search |
| `order` | number | catalog order |
| `palette`, `tile_seed` | list of `#RRGGBB` colors, number | what the launcher draws the tile from; the seed is derived from the id |
| `capabilities` | list | for example `microphone`, `export-image`; drives usage descriptions and the privacy audit |
| `quality_tiers` | list | declared tier names |
| `content` | object or null | for a registered game: `levels` and `catalog_sha256` of its bundled level catalog; the level catalog itself is a separate file of the game's features |
| `available` | boolean | true only when `X-<code>` is pass |

Data models that the features define (all versioned, all with bounded decoding): the experience descriptor above;
the snapshot envelope (experience id, schema version, seed, step index, state payload, digest); the level catalog
of a game (level id, seed, band or world, move budget, witness hash); the scenario manifest of an experience
(scenario name, seed, actions, expected digests and probes); the entitlement state; the evidence record of
section 22.3; the lock manifest of section 22.4.

### 11.3 ExperienceKit: the experience contract

Every experience implements one contract. It adapts what exists (`RenderScene`, `RenderHost`, `FixedStepRunner`,
`DocumentEnvelope`, `MigrationChain`, `QualityPolicy`, `AutomationRunner`) and replaces none of it. The pure parts
(state machine, snapshot envelope, digests, conformance helpers) live in `VisualCoreExperience`; the parts that
need SwiftUI or a render host live in `VisualCoreExperienceHost` (new, in `Packages/VisualCoreRendering`).

| Operation | Obligation |
|---|---|
| `prepare(seed:)` | Asynchronous and cancellable. Builds all CPU state deterministically from the seed and compiles shaders through the session. Same seed, same state digest. |
| activate | GPU objects exist and the first frame can be drawn. |
| update | Fixed-step domain update, independent of frame rate, no GL calls. |
| draw | Through the existing `RenderScene` contract. Reads immutable state. No GPU result decides an outcome. |
| input | Gestures are normalized into domain actions. Each action is accepted or rejected with a typed reason; a rejected action leaves the digest unchanged. |
| snapshot / restore | A versioned envelope with migrations. `restore(snapshot())` reproduces the digest. |
| state and GPU | A snapshot is a pure, versioned value. GPU objects are a cache that can be rebuilt from it; a GPU handle is never persisted. |
| reset | Equals a fresh `prepare` with the same seed. |
| suspend / resume | Clocks stop; rebuildable caches may be dropped; resume does not catch up. |
| deactivate | Every GPU resource of the session is released. |
| diagnostics | State, seed, step index, quality tier, live GPU resource counts, last error, digest. |
| automation | Scenario hooks compiled only under `DEBUG` or `VISUALCORE_AUTOMATION`. |

Lifecycle states: `registered → preparing → ready → active ⇄ suspended → deactivating → inactive`, and `failed`
from any state. The lifecycle is a pure reducer with exhaustive transition tests; illegal transitions are rejected
and counted.

A reusable conformance helper (`ExperienceConformance`) runs these checks for the core of any experience on the
host: seed determinism, snapshot round trip, reset equivalence, rejection leaves the digest unchanged, tier change
leaves the digest unchanged, cache shedding leaves the digest unchanged, and replay reproduces the digest. Every
experience's test target calls it.

The shape UA-F02 built (contracts in `specs/188-ua-f02-experience-sdk/contracts/`): an experience has two parts.
The author writes a pure, `Sendable` value type, the core, and a main-actor class, the presenter. The framework
supplies the engine that drives the core through the lifecycle and the shell that joins both behind the
type-erased protocol `Experience`, which is what the session host sees.

```swift
// VisualCoreExperience (pure): the domain state and its rules
public protocol ExperienceCore: Sendable {
    static var migrations: MigrationChain { get }       // schema version of the snapshot payload
    static var controls: [ExperienceControl] { get }
    static var qualityTiers: Int { get }
    static var stepDuration: Double { get }             // 1/240 … 1/30 s, default 1/120
    static func prepare(seed: UInt64) async throws -> Self
    mutating func update(step: Int)
    mutating func apply(_ action: ExperienceAction) -> ActionResult
    mutating func reset()
    mutating func setQualityTier(_ tier: Int)
    mutating func shedCaches()
    func writeDigest(into builder: inout DigestBuilder) throws(DigestError)
    func snapshotPayload() throws -> Data
    static func restore(payload: Data, seed: UInt64) throws -> Self
}

// VisualCoreExperienceHost (main actor): the picture and the controls
@MainActor public protocol ExperiencePresenter: AnyObject {
    associatedtype Core: ExperienceCore
    func setup(_ context: RenderContext) throws
    func resize(_ context: RenderContext)
    func draw(_ core: Core, tier: Int, context: RenderContext, frame: FrameInfo) throws   // the core is a value
    func teardown(_ context: RenderContext)
    func shedCaches()
    func describe(_ core: Core) -> String
    func makeControls(_ port: ExperienceActionPort) -> AnyView
}
```

`ExperienceEngine<Core>` is a value type: it owns the lifecycle, the fixed-step clock and the core, checks every
operation against the lifecycle first, validates actions before the core sees them, puts the state back when the
core rejects an action, and compares a restored state with the digest in its snapshot. `ExperienceShell<Presenter>`
runs the core's preparation off the main actor, asks the engine for steps on each frame while active, and ends a
deactivation only when the render host's registry shows no live and no leaked object. The digest is SHA-256 over a
typed, length-marked encoding (`DigestBuilder`, `StableHash`). Scenario hooks (`ExperienceScenario`) compile only
under `DEBUG` or `VISUALCORE_AUTOMATION`; `scripts/check_experience_symbols.py` proves their absence from release
builds of both modules.

### 11.4 Session host

- `ExperienceSession` (UA-F03, in `VisualCoreExperienceHost`) is the one object that opens and closes experiences
  for the whole app. An open request carries a factory for the experience, the seed, an optional snapshot, the
  `ResourceBudget`, a memory-pressure limit and a time limit for preparation. The session builds a new experience
  for every open and every Retry, owns exactly one `RenderHost`, and hands snapshots to a sink the opener
  supplies. `ExperienceHostView` shows the existing `RenderSurface` together with the experience's native
  controls, and the session's own views for preparing, failure (Retry and Back) and messages.
- One session is active at a time. Opening another experience closes the current one completely, proves that
  its resource registry is empty, and only then prepares the next. Of two competing opens the newest wins; the
  other ends as superseded.
- Activation order: resolve entitlement (the caller, before it asks the session) → `prepare(seed:)` → restore the
  given snapshot → apply the quality level in force → create the render host with the budget (the scene's set-up
  compiles the shaders) → activate → first frame → interactive. Each stage is timed separately for the evidence
  record: preparation, set-up with the number of programs compiled, and the time to the first presented frame. A
  render host exists only after a successful preparation.
- Deactivation order: stop clocks → final snapshot → begin deactivation → destroy the render host → read the
  counts → end deactivation (zero live and zero leaked resources, or a recorded leak failure) → idle.
- The session's decisions (its seven states and their legal changes, the order of a close, the memory-pressure
  rule) are pure values in `VisualCoreExperience` (`SessionLifecycle`), tested on the host.
- As built by UA-F05: a request can say that a refused snapshot fails the open (`refusedSnapshotFails`). The
  open then ends as a failure of the stage `restore`, before a render host exists and without a call of the
  sink, so an experience never starts on a fresh state while a stored one exists that it could not read.
  `checkpoint()` hands the open experience's snapshot to the sink between a suspension and a close; the app
  calls it five seconds after an accepted action.
  `ExperienceHostView` takes an optional retry action; the app's Retry opens the experience with the state
  stored now, not with the snapshot the failed open began with.

### 11.5 Threads and GPU ownership

- Everything that touches EGL or GL runs on the main actor, as the framework does today. A Swift actor is not by
  itself an EGL-thread guarantee; the session asserts the owning thread.
- CPU-heavy preparation (level generation, mesh building, solver checks) may run off the main actor in pure,
  `Sendable` code and hands finished values to the main actor. It never calls GL and it honors cancellation.
- GPU objects are created only through the session's registry and are tagged with the context generation. They
  are destroyed on deactivation. After a context loss they are rebuilt from CPU state and the digest is unchanged.
- Frames are scheduled by the existing `FrameScheduler`; domain time advances in fixed steps through
  `FixedStepRunner`. A slow frame never changes an outcome.
- Solvers that prove a level solvable run in tests and tools; the app ships the certificates as data and does not
  need to re-solve at run time.

### 11.6 Failure isolation, cancellation and lifecycle

- Errors are typed. A failure in preparation, setup or rendering is caught by the session, recorded in
  diagnostics and shown as a failure view with Retry and Back.
- Leaving during preparation cancels it. No callback of an experience arrives after its deactivation.
- Scene phases: background and inactive suspend, active resumes. A memory warning sheds caches; a session whose
  live bytes are still above its memory-pressure limit (by default half of the budget) closes with a message. Termination is safe because state was saved at suspension.
- Swift traps cannot be caught, so shipped code paths that read stored or user-influenced data use no
  `fatalError`, forced unwrap or unchecked index; inputs are bounded and validated.
- Preparation has a time limit; exceeding it is a failure like any other.
- Below the experience lifecycle sits the render host's own: uninitialized, surface ready, active, suspended,
  surface invalid, reinitialized, destroyed. GPU handles belong to a context generation. Simulator tests cover
  re-entrancy, resize, rapid scene change, background and foreground, and termination.

### 11.7 Navigation, settings and onboarding

- Routes: catalog, experience, settings, about, purchase. The last route, the last experience and the catalog
  filter are restored after termination. There is no URL scheme and no route that an outside input can open.
- First run goes straight to the launcher and into a running free experience with no account, purchase or
  permission prompt. A permission (for example the microphone in the audio experiences) is requested only when
  the person uses that feature.
- Settings: Reduce Motion and Reduce Flashing choices (existing `AccessibilitySettingsSection`), a quality
  override, reset of one experience's data and of all data, the privacy statement, restore purchases, and
  acknowledgements (existing `AcknowledgementsView` and `LicenseInventory`).
- Each tile shows the tier as text, not only as color or glyph. Accessibility identifiers are stable:
  `vc.tile.<id>` for tiles, `vc.route.<name>` for routes, `experience.<id>.<control>` inside an experience.
- A DEBUG-only launch argument `-openExperience <id>` opens one experience for tests. The debug support of the app
  (`Apps/VisualCore/App/DebugSupport/`, wholly inside `#if DEBUG`) also offers a fixture catalog, a debug
  experience and arguments that erase the app's data and skip the welcome; none of it is in a release build.
- The app's tests run with `python3 scripts/xcodebuild_app.py --scheme VisualCore --runtime <27.2|26.5> --kind
  <phone|tablet>`: the simulator is chosen by runtime and kind (for a phone the narrowest available one), and
  the enumeration guard runs on the log. A run is made in chunks of whole test classes with `--only-testing`,
  each under ten minutes; the guard then covers the classes of the chunk.
- As built by UA-F04: settings and about are list rows above the tiles, and the way back from a route is a row
  of its content (a navigation bar clips text at the largest sizes and keeps its buttons below 44 points); the
  search is a text field in the first row; a registration's factory receives the stored reduce-motion and
  reduce-flashing choices; the shell's pure decisions (launcher sections,
  startup, preferences, reset plan) live in `VisualCoreExperience` (`ShellModel.swift`).
- As built by UA-F05: a stored state that cannot be read shows a notice on the experience route in place of the
  experience (`vc.unreadable`, with `vc.unreadable.reset` and `vc.unreadable.back`); nothing runs behind it.
  Reset keeps a copy of the stored state and starts afresh; Back returns to the catalog and changes nothing.
  The debug support gained `-vcDamageState <truncated|garbage|newer|other>` (damages every stored state before
  the model starts), `-vcStrayItems` (one file and one defaults key that no inventory rule lists) and the
  container inventory in the settings diagnostics (`vc.inventory`). The interface tests of persistence are two
  further chunks: `VisualCoreUITests/PersistenceUITests` and `VisualCoreUITests/PersistenceDamageUITests`.

## 12. Rendering, quality and performance

### 12.1 The rendering path (exists today)

OpenGL ES 3.0 calls go through EGL to the owner's ANGLE fork, which renders with Metal. `RenderHost` owns the
context and the frame loop, `RenderScene` is what an experience draws through, `RenderSurface` is the SwiftUI view,
`ResourceRegistry` and `ResourceLedger` account for every GPU object, and `FrameScheduler` paces frames. The design
is described in `docs/architecture/visualcore-architecture.md`; `docs/architecture/current-rendering-pipeline.md`
traces the ProjectM-iOS reference pipeline that `RenderHost` re-implements.

### 12.2 Rules

1. There is one renderer. No direct Metal renderer, no second GL stack, no public EGL bridge.
2. `Vendor/angle` and the ProjectM fork inside `External/projectm-ios` are not edited, moved or cleaned. A
   genuinely necessary engine change is an upstream-ready patch with a log, never a local rewrite.
3. Shaders are GLSL ES 3.00, expanded and validated by the existing shader pipeline, compiled during preparation.
   Measure load separately from the first rendered frame.
4. Gameplay truth is CPU state. Shaders portray it. No readback decides an outcome.
5. Color handling follows `docs/rendering/color-space.md`. Color space, alpha convention and units are explicit in
   every pipeline; the alpha convention (premultiplied or straight) is not yet written down there and is added by
   the first feature that blends. Bloom and emissive passes go through the flash limiter.
6. Experience and app sources contain no direct GL or EGL calls (`scripts/check_app_isolation.py`).
7. Untrusted or user-authored input (shader text in Shader Studio, graphs in Visual Programming Lab and Effects
   Composer) is bounded: pass counts, texture memory, compile time and iteration counts have limits, cycles and
   invalid paths are rejected, and a failure never hangs the app.
8. **Optical truth boundary.** Bloom, reflective-looking color, translucency and caustic-looking gradients are
   presentation. The CPU model computes intersections, phases, conservation and projection. A lower tier may
   trade samples, layers and resolution while the meaning of the scene stays identical.
9. No compute shaders and no unbounded volumetric ray marching: neither fits GLSL ES 3.00 on this path.
10. Shader compilation and `glGetError` are checked for real. The GL ES and extension fingerprint of each device
    is recorded during the device campaign.
11. Dependency trees are handled with care: never `git clean -fdx` inside them, never wipe, move or delete the
    large `gclient` tree of ANGLE, build the reference binaries only with the reference project's own scripts
    (they write only to `Build/ANGLEFrameworks`), and keep the forks pinned (`Coastrnaut/projectm` and
    `Coastrnaut/angle`, branch `ios`). The submodule is never vendored, its pin never changes without a recorded
    decision, `git submodule update --remote` is never run unattended, and the tested commit is recorded. The
    reference's deployment target, ANGLE revision, compiler settings and build system are never changed to fit a
    VisualCore convention.
12. No new ANGLE adapter or backend is added for the sake of modularity. Native Metal is considered only for a
    proven, concrete need, with an ADR.

### 12.3 Fidelity during the migration

Moving an existing app into the unified app must not change what it draws. The committed fixtures stay
bit-identical (A01 replay and baselines, A02 and A03 fixtures, A04 `replay-v1.json`), the simulator baselines in
`docs/performance/` are rerun, and the ProjectM reference regression stays at 7 of 7 after any framework change.

### 12.4 Quality profiles

Each experience declares named tiers and what each tier means in concrete numbers (resolution scale, particle or
instance count, iteration count, effect passes). The profile builds on the existing `QualityPolicy`,
`DeviceConditions`, `FramePacing`, `ParticleBudget` and `RenderCostEstimate`: tiers step down under serious thermal
state or Low Power Mode and recover after the calm period. A tier change never changes domain state. A settings
override lets a person pin a tier.

As built by UA-F06: `QualityProfile` (one to eight named levels, each with a resolution share, an element share,
an iteration share and a number of effect passes; no budget rises from one level to the next) is declared by an
experience's logic (`ExperienceCore.qualityProfile`) and checked by the conformance run against its tier count and
by the app's registry test against the catalog's level names. `QualityGovernor` gives the level in force: the
pinned level, or the tier of the existing `QualityPolicy` for the device conditions, decided at most once per
second. The session owns the governor: it applies the level after the preparation and before a render host exists,
decides again while the experience runs, takes no decision while it is suspended, and applies a changed pin at
once. The app only hands the stored override to the session. The frame scheduler's own reaction to heat (frame-rate
cap and resolution factor on the display surface) is unchanged; an experience applies its level's resolution share
to what it draws, and the record names both.

### 12.5 Budgets

Budgets are written as proposals in `docs/performance/` together with the device measurement that will confirm
them. Simulator numbers are development signals and are never presented as performance results. No target becomes a
requirement before a measured baseline exists, and comparisons are made on the same device and OS. The first values
to confirm on devices:

| Budget | Proposal | Confirmed by |
|---|---|---|
| Cold launch to an interactive launcher | no rendering context, no store wait | D1, D2, D3 measurements, at least 200 samples |
| Open an experience to its first frame | preparation, shader compilation and first present recorded separately | same |
| Frame pacing in an active experience | at least 95 % of refresh slots on time at the selected tier | same |
| Frame rate | 60 frames per second with adaptive tiers; a documented 30 frames per second mode is acceptable on the lower tier | same |
| Input to visible response | median under 80 ms and p95 under 150 ms, measured on one clock | same |
| Start | cold and warm start recorded separately; bounded shader variants are prewarmed | same |
| Memory and GPU bytes of a session | bounded by the declared `ResourceBudget`; flat over a 10-minute scenario | simulator trend, then devices |
| Clean build, incremental build, app size | recorded at every milestone | UA-F10 |

### 12.6 Measurement method

- Count refresh misses from display-link interval timelines; report median, p95 and p99 frame time, first frame,
  shader compilation, memory and thermal state, never a hand-read frame rate.
- Every percentage criterion uses at least 200 independent samples with per-sample ids, scenario, seed, stage
  timings and failure reason. First-run and cache-warm runs are separated.
- D1 is the primary reference, D2 the high-resolution tier, D3 the compatibility and lower-tier budget. Devices
  are not forced to the same quality; adaptive quality is reported.
- Scrolling and animation smoothness are read from an in-app display-link frame meter (on-time frames, missed
  refresh slots), shown with a launch flag and read by a UI test that interacts for ten seconds or more.
- Installed size is compared on thinned archives (`thinning = <thin-for-all-variants>`, the "App Thinning Size
  Report.txt" of each device model), not on debug simulator builds.
- Reports name thermal state, sample ids, app hash, device model, OS, battery and charging state, brightness, the
  frame-time distribution and memory.
- Launch time takes one sample per process launch. The first launch after installation belongs to onboarding and
  is excluded.
- A result that only just passes is repeated and reported with its variance.
- As built by UA-F06: the session produces one `PerformanceRecord` (version 1) per opened experience, which the
  evidence record of UA-F09 embeds: launch time (from the first code of the app to the usable launcher, once per
  process, first start marked), preparation, shader set-up and programs compiled, late compilations (programs
  compiled after the experience became interactive; rebuilds after a lost context are counted apart), the time to
  the first presented frame, pacing from the interval between presented frames (`PacingMeter`: on-time and missed
  refreshes, median, 95th and 99th percentile from fixed bins, constant memory), memory footprint
  (`ProcessMemory`), graphics bytes with their peak, the level in force, thermal state and Low Power Mode. An
  absent measurement has no value. `GrowthRule` judges a series of samples; the endurance scenario of the sample
  experience (36,000 drawn frames, 72,000 steps) passes it on the simulator. The budgets are in
  `docs/performance/budgets.md`, checked by `scripts/check_performance_docs.py`. The on-screen frame meter of
  this section is built by UA-F09 on these counts.
- Data the launcher sorts or indexes is sorted at build time, not at launch.

## 13. Shared features and reuse

### 13.1 What the framework provides today

| Module | Package | Provides (public types that exist) |
|---|---|---|
| VisualCoreMath | VisualCore | `Vec2`, `Vec3`, `Vec4`, `Mat3`, `Mat4`, `Quat`, `OrbitCamera`, `Camera2D`, `EasingCurve`, `TourTimeline`, `PrecisionAdvisor` |
| VisualCoreSimulation | VisualCore | `FixedStepRunner`, `FixedStepClock`, `SceneClock`, `SeededRandom`, `Timeline`, `ControlStream`, `PlaybackState`, `ParticleSystem`, `ParticleForce`, `FieldGrid`, `TrailDecay`, `AccessibilityPreferences` |
| VisualCoreScenes | VisualCore | gesture recognizers (`TapRecognizer`, `DragRecognizer`, `PinchRecognizer`, `RotateRecognizer`, `LongPressRecognizer`, `DoubleTapRecognizer`), `PointerTracker`, `Mesh`, `SceneNode`, `ExportGeometry` |
| VisualCoreParameters | VisualCore | `ParameterSchema`, `Preset`, `Palette`, `ParameterHash`, `ParameterEditor` |
| VisualCorePersistence | VisualCore | `DocumentStore`, `NamedLibrary`, `DocumentEnvelope`, `MigrationChain` |
| VisualCoreShaderSource | VisualCore | `ShaderLibrary`, `ExpandedShader`, `InfoLogParser`, `ShaderCacheKey` |
| VisualCoreEffectsGraph | VisualCore | `EffectGraphDescription`, `EffectGraphValidator`, `FlashLimiterModel` |
| VisualCoreDiagnostics | VisualCore | `QualityPolicy`, `DeviceConditions`, `FramePacing`, `ParticleBudget`, `RenderCostEstimate`, `ResourceLedger`, `ResourceBudget`, `RenderLifecycle` |
| VisualCoreTestSupport | VisualCore | `ImageComparison`, `ImageStatistics` (test targets only) |
| VisualCoreRendering | VisualCoreRendering | `RenderHost`, `RenderScene`, `RenderContext`, `ResourceRegistry`, `ShaderProgram`, `ShaderBundle`, `RenderTarget`, `PingPongTarget`, `FieldPass`, `MeshRenderer`, `PrimitiveRenderer`, `ParticleRenderer`, `ParticleLayerScene`, `TrailLayer`, `StillCapture`, `RenderCapabilities`, `FloatRenderSupport` |
| VisualCoreEffects | VisualCoreRendering | `EffectRenderer`, `EffectScene` |
| VisualCoreUI | VisualCoreRendering | `RenderSurface`, `ParameterPanel`, `AccessibilitySettingsSection`, `AccessibleColors`, `AcknowledgementsView`, `LicenseInventory` |
| VisualCoreAutomation | VisualCoreRendering | `AutomationRunner`, `AutomationReport`, `AutomationView` |
| VisualCoreAudio, VisualCoreAudioDSP | both | version constants only; audio acquisition and DSP are still to be built by the audio experiences (A06–A08) |

The authoritative list is the API baseline `docs/api/visualcore-public-api.txt`.

### 13.2 Proposed new modules

| Module (new) | Package | Purpose | Introduced by |
|---|---|---|---|
| VisualCoreExperience | VisualCore | ids, catalog, lifecycle reducer, snapshots, entitlement policy, conformance helpers | UA-F01, UA-F02 |
| VisualCoreExperienceHost | VisualCoreRendering | session, host view, failure view, scenario runner | UA-F02, UA-F03, UA-F09 |
| VisualCoreStore | VisualCoreRendering | StoreKit 2 purchase controller behind a protocol | UA-F08 |
| VisualCoreGeometry | VisualCore | mesh compiler, curves, ribbons, tubes, SDF and CSG proxies, convex clipping, terrain, vegetation | R02-F05 and later |
| VisualCorePuzzle | VisualCore | puzzle contract, seeded generation, solver certification, grid and graph solvers, level catalogs | R02-F16, R02-F23 |

A few logical modules are preferred over many small packages. A change of module granularity needs a measurement
of build time and size and an ADR.

### 13.3 Reuse rules

1. Before writing logic inside an experience, check whether an existing or new framework module should own it,
   and record the choice in the feature's plan. Experiences keep composition, content, copy and genuinely one-off
   rules.
2. Pure logic goes in `Packages/VisualCore` and is host-testable. GPU and UIKit code goes in
   `Packages/VisualCoreRendering`.
3. The package rules of ADR-0003 hold: only the ProjectM reference harness touches reference modules (R1); pure
   sources import only system modules and each other (R2); the target graph is acyclic (R3); packages never import
   app or harness modules (R4); test support serves test targets only (R5). Added for the single app: experiences
   never import each other, and nothing imports an experience except the app's registry.
4. Every framework change gets `///` documentation, an API baseline update
   (`python3 scripts/check_public_api.py --update`), its own package tests, and the seven-step ProjectM reference
   regression run in two chunks.
5. No API without a concrete consumer, and no general game-engine architecture unless a requirement demands it.
   Before a new shared boundary is created, the six questions of the original framework plan are answered
   (`docs/archive/planning/embedded/sources/README.md`, "boundary" questions); if the answers are unclear, the need
   is documented and the boundary deferred.
6. A framework capability is complete only with a consumer, a contract, tests, a sample, lifecycle and error
   behavior, measurements and documentation.

### 13.4 Round 2 shared features

The source planned 34 shared features. Ten are delivered by unified-app features and have no gate of their own;
the other 24 are gates of the migration ledger. "Reuses today" lists types that exist.

<!-- GENERATED:BEGIN shared-round02 -->
| Feature | Title and deliverable | Consumers | Disposition | Reuses today | New code goes to | Gate | Note |
|---|---|---|---|---|---|---|---|
| R02-F01 | **Round 1 evidence & reproducible baseline audit** — verify repo status; prior 25 app builds; simulator results; D1-D3 campaign; tool versions; git pins | ALL | superseded | — | — | no gate: superseded by UA-F00 | Replaced by the pre-migration baseline, the two ledgers and UA-F00; no Round 1 device exit gate exists any more (C-03). |
| R02-F02 | **VisualCore public API compatibility and renderer capability probing** — query actual EGL/GL ES entry points; extensions; drawbuffer formats; MSAA; shader versions; instrumentation | ALL | reuse | `RenderCapabilities` | VisualCoreRendering | `R02-F02` | Audit only: the public API baseline (docs/api/visualcore-public-api.txt, scripts/check_public_api.py) and RenderCapabilities already exist; add capability probes only where a game needs one. |
| R02-F03 | **Numerical foundations and deterministic seeded scene time** — fixed step clock; seed hashing; stable math; IEEE hygiene; replay logs; transform conventions | ALL | reuse | `SeededRandom`, `SplitMix64`, `FixedStepClock`, `SceneClock`, `FixedStepRunner`, `TimeStepPolicy` | VisualCoreMath, VisualCoreSimulation | `R02-F03` | Deterministic time and randomness exist; add only missing numeric helpers with tests. |
| R02-F04 | **GPU resource ownership and pipeline lifetime** — per-context residency; resource caches; immutable descriptors; main loop ownership; destruction ordering | ALL | reuse | `ResourceRegistry`, `ResourceLedger`, `ResourceBudget`, `RenderLifecycle` | VisualCoreRendering, VisualCoreDiagnostics | `R02-F04` | Ownership rules exist; the session-level rules are delivered by UA-F03. |
| R02-F05 | **Procedural mesh compiler and mesh validation** — indexed vertices; surfaces; bevels; tubes; manifold validation; normals; bounds | ALL | new | `Mesh`, `MeshRenderer`, `PrimitiveRenderer` | (new) VisualCoreGeometry, VisualCoreRendering | `R02-F05` | Indexed mesh compiler with bevels, tubes, manifold and bounds validation on top of the existing Mesh and MeshRenderer. |
| R02-F06 | **Shader domain-specific parameters and GL ES safe compilation** — shader preprocessing; embedded program variants; precision qualifiers; compile diagnostics; stable uniforms | ALL | extend | `ShaderLibrary`, `ShaderBundle`, `ShaderProgram`, `InfoLogParser`, `ShaderCacheKey` | VisualCoreShaderSource, VisualCoreRendering | `R02-F06` | Typed per-domain shader parameters and safe GLSL ES compilation on the existing shader pipeline. |
| R02-F07 | **Linear-color/HDR-look emissive pass and mobile-safe bloom** — linear scene values; half resolution blur; tone mapping; pre-multiplied alpha; flash reduction | ALL | extend | `EffectRenderer`, `FloatRenderSupport`, `FlashLimiterModel`, `RenderTarget` | VisualCoreEffects | `R02-F07` | Linear-colour emissive pass and mobile-safe bloom; the bloom and flash limiter of VisualCoreEffects are the starting point. |
| R02-F08 | **Curve, ribbon, and tube batch renderer** — adaptive curves; parallel transport; continuous texture coordinates; tangent frame and collapse | Aurora Loom; Lissajous Labyrinth; Wave Knot Keeper; Chrono Constellator; Backwards Aurora; Harmonic Bridges; Acoustic Constellator; Starlit Cartouche; Apsides Workshop | new | `Mesh`, `MeshRenderer` | (new) VisualCoreGeometry, VisualCoreRendering | `R02-F08` | Curve, ribbon and tube batches with parallel-transport frames. |
| R02-F09 | **Instancing and point/beam renderer** — instanced sprites/solids; transparent depth ordering; beam geometry and fragment falloff | Hue Compass; Echo Cartographer; Acoustic Constellator; Microscopic Aurora; Starlight Surveyors | extend | `ParticleRenderer`, `ParticleBlend`, `ParticleLayerScene`, `ParticleSystem` | VisualCoreRendering | `R02-F09` | Instanced points exist; add beams and generic instancing. |
| R02-F10 | **Spectral color & non-color clue accessibility** — hue transforms; perceptual luminance; shape encoding; colorblind presets; noncolor status | Aurora Loom; Hue Compass; Colorfall Canyons; Backwards Aurora | extend | `Palette`, `AccessibleColors`, `AccessibilityPreferences` | VisualCoreParameters, VisualCoreUI | `R02-F10` | Spectral palettes plus non-colour clues (shape, pattern, label) for every colour-coded rule. |
| R02-F11 | **SDF and constructive geometry proxy library** — analytic plane/sphere/box distance; signed volume sampling; conservative raymarch option | Amethyst Escape; Faceted Forge; Echo Cartographer; Crystal Quarry | new | — | (new) VisualCoreGeometry, VisualCoreShaderSource | `R02-F11` | Signed-distance and constructive-geometry library with CPU proxies that decide outcomes. |
| R02-F12 | **Convex solid clipping & polygon robustness** — half-space mesh intersection; stable epsilon; face winding; volume ledger; degenerate removal | Faceted Forge; Crystal Quarry; Amethyst Escape | new | — | (new) VisualCoreGeometry | `R02-F12` | Robust convex clipping and polygon operations, pure and host-tested. |
| R02-F13 | **Shadow stencil and geometric silhouette analysis** — projection of 3D polygons; rasterized mask; intersection-over-union; no GPU readback for logic | Nocturne Garden; Moonlit Mechanism; Celestial Eclipse Lab | new | `MeshRenderer` | (new) VisualCoreGeometry, VisualCoreRendering | `R02-F13` | Shadow volumes or stencils and silhouette analysis; CPU decides, GPU portrays. |
| R02-F14 | **Deterministic timeline and reversible history** — event log; snapshot ring; rewind; timeline editing; replay hashes; save migration | Chrono Constellator; Backwards Aurora; Starlit Cartouche | extend | `Timeline`, `TimelineEvent`, `FixedStepRunner`, `ControlStream`, `PlaybackState` | VisualCoreSimulation | `R02-F14` | Reversible history and scrubbing on the existing timeline and replay stream. |
| R02-F15 | **Conic orbit and eclipse geometry** — Kepler anomaly solver; projected overlap; phase stepping; visibility classification | Celestial Eclipse Lab; Apsides Workshop; Binary Gardens; Starlit Cartouche | new | `OrbitCamera` | VisualCoreMath | `R02-F15` | Conic orbits and eclipse geometry, pure and host-tested. |
| R02-F16 | **Grid, graph, and route-solver toolkit** — BFS/A*; time-expanded graphs; cut sets; graph isomorphism subsets; solver certificates | Colorfall Canyons; Echo Cartographer; Acoustic Constellator; Mycelium Architect; Crystal Quarry | new | — | (new) VisualCorePuzzle | `R02-F16` | Grid, graph and route solvers used by solvability certification. |
| R02-F17 | **Fluid-heightfield transport and conservation** — conservative flows; explicit bounded steps; dye mass; erosion; stable clamps | Colorfall Canyons; Erosion Painter | extend | `FieldGrid`, `FieldPass`, `PingPongTarget`, `FieldUniform` | VisualCoreSimulation, VisualCoreRendering | `R02-F17` | Height-field transport with conservation checks on the existing field passes. |
| R02-F18 | **Procedural terrain mesh and skydome** — heightfield LOD; deterministic erosion masks; raster-free procedural sky | Colorfall Canyons; Erosion Painter; Crystal Quarry | new | `Mesh`, `MeshRenderer` | (new) VisualCoreGeometry, VisualCoreRendering | `R02-F18` | Procedural terrain meshes and a sky dome. |
| R02-F19 | **Organic grammar & compact vegetation generator** — L-systems; parametric petals, caps, stems; deterministic instancing | Nocturne Garden; Mushroom Weather; Binary Gardens; Mycelium Architect | new | `SeededRandom` | (new) VisualCoreGeometry | `R02-F19` | Compact grammar-based vegetation generator. |
| R02-F20 | **Bounded swarm and steering simulation** — deterministic boids; neighborhood grid; magnetic fields; density raster | Microscopic Aurora; Mushroom Weather | new | `ParticleSystem`, `FixedStepRunner` | VisualCoreSimulation | `R02-F20` | Bounded swarm and steering simulation. |
| R02-F21 | **Diffusion, nutrient, and viability field solver** — explicit stable diffusion; local sources/sinks; bounded graph growth; conservation reports | Mushroom Weather; Binary Gardens; Mycelium Architect | new | `FieldGrid` | VisualCoreSimulation | `R02-F21` | Diffusion, nutrient and viability field solver. |
| R02-F22 | **Spatial controls and analytic picking** — ray/plane intersection; depth-aware handles; undo semantics; assistive controls | ALL | extend | `TapRecognizer`, `DragRecognizer`, `PinchRecognizer`, `RotateRecognizer`, `LongPressRecognizer`, `DoubleTapRecognizer`, `PointerTracker`, `OrbitCamera`, `Camera2D` | VisualCoreScenes, VisualCoreMath | `R02-F22` | Gesture recognizers and cameras exist; add analytic picking and world-space controls. |
| R02-F23 | **Puzzle contract, seed generation and solver certification** — immutable level schemas; explicit solutions; uniqueness mode; fairness budget; deterministic validation | ALL | new | `FixedStepSimulation`, `ParameterHash` | (new) VisualCorePuzzle | `R02-F23` | Puzzle contract, seeded generation and solver certification; the lifecycle and digest parts are delivered by UA-F02. |
| R02-F24 | **Procedural content authoring, balancing and catalogs** — build-time generated catalogs; tutorial contracts; difficulty progression; deterministic checks | ALL | new | `Preset`, `NamedLibrary` | (new) VisualCorePuzzle, scripts/ | `R02-F24` | Content authoring, balancing and level catalogs generated and validated by tools. |
| R02-F25 | **Shared native iOS shell and evidence-friendly UI** — SwiftUI menus, progress, pause/resume, accessibility and transparent render hosting | ALL | superseded | `RenderSurface` | — | no gate: superseded by UA-F03, UA-F04 | The shared shell is the one app: UA-F03 (session) and UA-F04 (launcher, navigation, settings). |
| R02-F26 | **Games input/accessibility/haptics contract** — gesture arbitration; VoiceOver mirrors; color independence; Reduce Motion/Flashing | ALL | extend | `AccessibilitySettingsSection`, `SystemAccessibilityObserver`, `AccessibilityPreferences`, `EffectiveAccessibility` | VisualCoreUI, VisualCoreSimulation | `R02-F26` | Input, accessibility and haptics contract for games; shell-level parts are in UA-F04. |
| R02-F27 | **Offline premium entitlement and zero-ads compliance** — standalone purchase; zero IAP; no ad/network SDK; privacy manifest and static analysis | ALL | superseded | — | — | no gate: superseded by UA-F08, UA-F11 | Entitlement is UA-F08 (one non-consumable); the zero-advertising audit is UA-F11. The source's 'no StoreKit' rule is superseded (C-02). |
| R02-F28 | **Game profile migration and atomic save engine** — checksum JSON; transactional saves; versioned objectives; recovery state | ALL | superseded | `DocumentStore`, `NamedLibrary`, `MigrationChain`, `DocumentEnvelope` | — | no gate: superseded by UA-F05 | Per-experience storage, migrations and atomic saves are UA-F05 on VisualCorePersistence. |
| R02-F29 | **Visual regression, shader, and mesh golden harness** — fixed seeds; reference angles; platform-delta tolerances; pixel snapshots with human checks | ALL | superseded | `StillCapture`, `ImageComparison`, `ImageStatistics` | — | no gate: superseded by UA-F09 | Golden, shader and mesh regression harness is part of the verification runner UA-F09. |
| R02-F30 | **Suite build matrix, xcodegen and CI orchestration** — 25 app schemes; package tests; simulator testplans; exact tool pins; isolate signing | ALL | superseded | — | — | no gate: superseded by UA-F10 | One app target: build matrix and CI are UA-F10 (C-05). |
| R02-F31 | **Device automation harness and report schema** — devicectl wrappers; launch modes; xresult archive; per-run JSON; checksums | ALL | superseded | `AutomationRunner`, `AutomationReport` | — | no gate: superseded by UA-F09, UA-F13 | Simulator part in UA-F09, device part in UA-F13. |
| R02-F32 | **Graphics frame pacing and D3 thermal adaptation** — adaptive quality; frame interval histograms; no false GPU statistics; 30 min sustained probe | ALL | superseded | `FramePacing`, `QualityPolicy`, `DeviceConditions` | — | no gate: superseded by UA-F06 | Quality profiles and pacing are UA-F06; D3 measurements happen after the lock. |
| R02-F33 | **Game identity distinctiveness & release packaging** — originality matrices; independent UX/goal; static app icons from vector code; legal audit | ALL | superseded | — | — | no gate: superseded by UA-F11, UA-F14 | Distinctiveness audit is UA-F11; packaging is UA-F14 for the one app. |
| R02-F34 | **Cross-game reconciliation and Round 2 evidence lock** — 25×3 device reports; no pending regression; full provenance and audit summary | ALL | superseded | — | — | no gate: superseded by UA-F12 | Reconciliation before devices is LOCK-FREE-50 and UA-F12; its device part is DEVICE-RECONCILE-100 (C-18). |
<!-- GENERATED:END shared-round02 -->

### 13.5 Shared features of Rounds 3–12

Each later round repeats the same twelve shared features for its own game families. Five are delivered by
unified-app features. The other seven are gates per round (`R03-F02` … `R03-F08`, `R04-F02` … `R04-F08`) and each
extends what earlier rounds built; a feature that finds nothing missing records the audit and a verified reuse
adapter instead of duplicate code.

<!-- GENERATED:BEGIN shared-rounds03-12 -->
| Feature | Title and deliverable (Round 3 wording) | Disposition | Reuses today | New code goes to | Gates at launch | Note |
|---|---|---|---|---|---|---|
| Rnn-F01 | **Round boundary preflight, source provenance and prior-device exit** — Read previous README/round2..roundN-1 actual evidence and verify all previous games against signed device manifest, never mark passed from Markdown | superseded | — | — | no gate: superseded | Round boundary and prior-device exit are replaced by the ledgers and UA-F00 (C-03). |
| Rnn-F02 | **GL ES / ANGLE compatibility and renderer API audit** — Revalidate existing VisualCore interfaces, vendor pins, Xcode source and 26.5/27.2 shader compile assumptions | reuse | `RenderCapabilities`, `ShaderPrecision` | VisualCoreRendering | `R03-F02`, `R04-F02` | Re-audit of the renderer API and GLSL ES assumptions for the round's families; no new code unless the audit finds a gap. |
| Rnn-F03 | **Mathematical kernels and bounded numeric solvers** — Add genuinely missing family-specific math only; deterministic CPU output with error proof and replay hashes | extend | `Vec3`, `Mat4`, `Quat`, `SeededRandom` | VisualCoreMath | `R03-F03`, `R04-F03` | Only the family-specific math that is genuinely missing, with error bounds and replay hashes. |
| Rnn-F04 | **Procedural surface, ribbon and shape compiler improvements** — Generate code-only geometry through explicit validated mesh ownership and independent logic snapshots | extend | `Mesh`, `MeshRenderer` | (new) VisualCoreGeometry | `R03-F04`, `R04-F04` | Extends the Round 2 mesh, ribbon and surface compilers (R02-F05, R02-F08). |
| Rnn-F05 | **Shader variant compilation and emissive pass** — Improve modular GLSL ES transforms and bloom without requiring unsupported compute/Metal backend rewrite | extend | `ShaderLibrary`, `ShaderBundle`, `EffectRenderer` | VisualCoreShaderSource, VisualCoreEffects | `R03-F05`, `R04-F05` | Shader variants and the emissive pass on top of R02-F06 and R02-F07. |
| Rnn-F06 | **Family-specific scene batching and object picking** — Establish draw instance budgets and analytic picking for the 25 actual game signatures | extend | `ParticleRenderer`, `PointerTracker` | VisualCoreRendering, VisualCoreScenes | `R03-F06`, `R04-F06` | Family-specific batching and object picking on top of R02-F09 and R02-F22. |
| Rnn-F07 | **Seeded generation, uniqueness and progression proof** — Generate all levels and machine check complete solution, counterexamples, difficulty and seeded visual variety | extend | `SeededRandom`, `ParameterHash` | (new) VisualCorePuzzle | `R03-F07`, `R04-F07` | Seeded generation, uniqueness and progression proofs on top of R02-F23 and R02-F24. |
| Rnn-F08 | **Touch control, camera and accessibility adapter** — Support semantic 3D controls, VoiceOver alternatives, motion reduction, color-independent clues and layout scaling | extend | `OrbitCamera`, `AccessibilityPreferences` | VisualCoreScenes, VisualCoreUI | `R03-F08`, `R04-F08` | Touch, camera and accessibility adapters on top of R02-F22 and R02-F26. |
| Rnn-F09 | **Battery, memory, thermals and shader warmup benchmarks** — Prepare D1-D3 report schema, CPU/GPU time where observable, and asset-free cold/hot start baselines | superseded | `FramePacing`, `QualityPolicy`, `DeviceConditions` | — | no gate: superseded | Benchmarks are prepared by UA-F06 and measured on devices after the lock. |
| Rnn-F10 | **XcodeGen, SwiftPM and 25-target CI integration** — Merge targets into existing repo without rebuilding vendor forks, corrupting signing or duplicating framework files | superseded | — | — | no gate: superseded | One target instead of 25: UA-F10 (C-05). |
| Rnn-F11 | **Device automation fixtures and evidence collection** — Prepare devicectl automation with launch modes, JSON export, xcresult, stress and lock verification | superseded | `AutomationRunner` | — | no gate: superseded | Simulator evidence in UA-F09, device fixtures in UA-F13. |
| Rnn-F12 | **Suite originality, legal, no-ads and final reconciliation** — Audit all products, similarities, licenses, privacy and evidentiary gaps; converge only when valid results exist | superseded | — | — | no gate: superseded | Originality, legal and no-advertising audits are UA-F11; final reconciliation is UA-F12. |
<!-- GENERATED:END shared-rounds03-12 -->

### 13.6 Binding rules for every shared feature

Round 2 attaches a binding supplement to all its shared-feature prompts (source section 4.3). It stands:

1. Every feature begins with an audit for genuine reuse. An API that has not been found, compiled and tested in
   the local checkout is only a proposal.
2. The source's type sketches (`GameTick`, `GameActionEnvelope`, `LevelIdentity`, `RuleRejection`,
   `DeterministicGameModel`) are proposals, not existing names. They map onto ExperienceKit and
   `VisualCorePuzzle`; a wrapper is written only where the repository lacks an equivalent, as a thin adapter. A
   sketch is compiled against the pinned Swift before it is adopted; where typed throws are unavailable, plain
   throws with a typed validation layer are used.
3. Gates of the supplement, each proven by a test:

| Area | Gate |
|---|---|
| CPU puzzle models | action traces replay to identical canonical hashes on the host and on both simulator runtimes |
| Solvers and certification | 100 levels per game with real solver witnesses and no placeholder |
| Renderer adapters | real shader compilation and `glGetError` checks; device fingerprints recorded during the campaign |
| Procedural assets | the same code and seed give identical logical artifact hashes |
| Gameplay accessibility | an alternative to drag, tap precision, color, motion and audio in every game; semantic UI tests and an accessible replay |
| Content provenance | every shipped level manifest parses and validates; no level exists only in a document |
| Evidence | simulator and device results are never mixed; device evidence only after the lock |
| Hygiene | no advertising, subscription, private API or misleading clone branding in the built app or its frameworks |

4. No gameplay input and no graphics result depends on a network connection.
5. A deficiency found while testing these rules becomes a new, uniquely numbered task that goes through the full
   Spec Kit progression. It is never fixed by a quiet shortcut.

### 13.7 Known gaps of the framework

Found on 2026-11-11 by comparing the original framework plan with the source. Each gap is closed in the framework
by the first feature that needs it, after that feature's own audit has confirmed it.

| Gap today | Needed by | Note |
|---|---|---|
| Depth, stencil and multisampling: the window surface is color-only and `RenderTarget` has a color attachment only | the 3D creative experiences (A05, A07, A12, A14, A15, A17), the 3D games, R02-F13 | a depth attachment on off-screen targets is the smaller step; changing the window configuration departs from the audited sequence of ADR-0002 and needs a new ADR |
| 3D mesh pipeline: three generators and one Lambert-lit `MeshRenderer`; no materials, textured meshes, mesh instancing, picking or level of detail | R02-F05, R02-F08, R02-F09, R02-F22 and every 3D experience | geometry goes to `VisualCoreGeometry`, drawing to `VisualCoreRendering` |
| Audio: capture with spectrum, bands and onsets; audio output and procedural sound; haptics | A06–A08; A10, A21; the games (R02-F26) | `VisualCoreAudio` and `VisualCoreAudioDSP` are placeholders |
| Text inside GL scenes | labels of A14, A15, A17, the clock face of A18, glyphs in puzzles | decided per experience: a native overlay first, procedural glyph geometry where the text is part of the scene; no font atlas from outside |
| Image decoding into textures and a textured sprite batch | A25 (image import), 2D experiences | `Texture` takes raw RGBA and `PrimitiveRenderer` draws flat color today |
| Physics and collision | A10, A11 | pure code in `VisualCoreSimulation` |
| Scene transitions and video export | A19 and the ambient experiences | export through public APIs only |
| GPU timing | A24 | no precision claim without a platform API |
| Game-controller input, a fake clock and fixtures in test support, a shared diagnostics overlay, asset metrics, a shader preset format | several | deliberately not built so far (ADR-0006) |

## 14. Purchases and entitlement

### 14.1 The product

One non-consumable product. Placeholder identifier `dev.visualcore.VisualCore.premium`. Price USD 1.99. It unlocks
every premium experience, including those released later. There is no second product, no subscription, no
consumable, no trial timer and no external purchase path. Purchases made in the separate ProjectM-iOS app do not
transfer and the app never suggests they do.

### 14.2 Architecture

- Module `VisualCoreStore` (new) holds a purchase controller on StoreKit 2 behind a `StoreClient` protocol with a
  live and a fake implementation. The entitlement policy (`EntitlementState`) is pure and lives in
  `VisualCoreExperience`.
- Entitlement is computed from verified `Transaction.currentEntitlements` at start and from `Transaction.updates`
  while the app runs. An unverified result never unlocks. **No unlock flag is stored anywhere**: not in defaults,
  not in a file, not in the keychain.
- Restore is `AppStore.sync()` behind an explicit button. Refund and revocation lock the premium library again.
  Family-shared ownership and its loss are handled.
- A previously verified entitlement works offline. A device that never purchased shows an honest locked state
  offline, never an error that looks like a bug.
- Store lookups never block the launcher or the first interactive frame.
- The locked or unlocked state while offline is derived from StoreKit's own results, never from a reachability
  API: the app uses no networking API at all, and the compliance scan rejects one (even `NWPathMonitor`).
- The archive's Round 2 rule that forbids a StoreKit configuration file and an entitlement fixture belongs to the
  superseded "no in-app purchase" plan (C-02). Both exist here, for tests only.
- Gating happens twice: the launcher refuses to navigate to a locked premium experience and the session refuses
  to activate it. Free experiences never query the store and work when StoreKit is unavailable.

### 14.3 States with a tested UI

Unknown while loading, free, premium (purchased or family-shared), purchasing, pending approval (Ask to Buy),
cancelled, failed with a reason, restored, revoked. Each state has an accessible presentation. The paywall states
plainly that this is a one-time purchase that unlocks current and future premium experiences. It has no countdown,
no nagging and no pre-selected option.

### 14.4 Testing

- A local `.storekit` configuration with exactly one product; a test fails if another product, a subscription or a
  consumable is added. The file carries no synced application identifier.
- `SKTestSession` with cleared transactions drives purchase, pending, failure, refund and restore.
- The app that hosts unit tests switches to the fake store when `XCTestConfigurationFilePath` is set, so no product
  request runs before the test session exists and no Apple Account prompt appears.
- UI tests that are not about buying use the launch argument `-uitestEntitlement free|premium|revoked`, compiled
  only under `DEBUG` or `VISUALCORE_AUTOMATION`.
- The pending-transaction handler is pure code with its own tests; an approval is delivered in tests through the
  test session (`buyProduct`), never through a real Ask to Buy flow.
- No real purchase, Ask to Buy flow or account sign-in is ever automated.

### 14.5 Shipping checks

The Release binary contains no fixture symbol or string and links no advertising, analytics or tracking framework
(`scripts/check_release_symbols.py`, extended by UA-F08 and UA-F11). Owner-only: creating the product in App Store
Connect, the Paid Apps agreement, the price, the Family Sharing choice and a sandbox tester.

## 15. Persistence, privacy, accessibility and legal

### 15.1 Persistence

- Each experience has an isolated namespace: files under `Application Support/Experiences/<id>/` and defaults keys
  with the prefix `exp.<id>.`. It reaches storage only through the handle the shell hands over when it opens the
  experience (`ExperienceStorage`, in the launch value): named files and named values, names of 1 to 128
  characters of `A-Z a-z 0-9 . _ -` that do not start with a dot, at most 64 files of 16 MiB in total and 64
  values of 4 KiB. A refused operation changes nothing. Tests prove that two experiences cannot read each
  other's data and that no name leaves the folder; `scripts/check_app_isolation.py --no-direct-storage` proves
  that an experience's sources name no file or defaults interface.
- The saved state of an experience is the text of its `ExperienceSnapshot` (format 1, at most 1 MiB, with
  checksum, schema version and migrations through `MigrationChain`) in `state.json` of its folder
  (`SavedStateStore`). Writes are atomic: a hidden temporary file in the same folder, then a replace; leftover
  temporary files are removed at the start. A state equal to the stored one is not written again.
  Each registered experience carries one stored example of every earlier schema version with the digest it
  restores to (`SnapshotMigrationCheck`); the app's unit test runs the check for every registration.
- The state is saved at a suspension, at a close and five seconds after an accepted action (one save for a burst
  of actions). A save that fails is recorded in the diagnostics and never stops the experience.
- A truncated, damaged, foreign, too large or newer-version state never starts the experience: the app shows a
  notice with Reset and Back. Reset moves the file to a quarantined copy (`quarantine-<n>.json`, at most three,
  the oldest removed first) and starts afresh; Back changes nothing. No shipped path that reads stored data
  uses a deliberate crash (`scripts/check_app_isolation.py --no-crash-on-stored-data`).
- Reset of one experience clears exactly its namespace: its folder and its defaults values. Reset of all data
  clears every namespace, the session state and the copy of an unreadable session state
  (`vc.shell.preferences.unreadable`, kept once before such a value is overwritten).
- A container inventory lists the only files and defaults keys that may exist (`ContainerInventory`; the rule
  list is in the app's debug support). An interface test reads the inventory after a scripted use on both
  simulator runtimes. Files and keys the system writes are allowed by a rule that states how the origin was
  established, not ignored wholesale: the defaults property list, the Metal caches (`com.apple.metal`,
  `com.apple.metalfe`, with files ending in `.pcm`, which are not audio), the launch-screen pictures of
  SplashBoard, UIKit's saved application state and the split view's column key. StoreKit's
  `SKTransactionUpdatesLastChecked` key is added with the purchase feature. Unknown files are never suppressed.
- No iCloud and no sync.

### 15.2 Privacy

- The app makes no network request of its own. Purchases go through StoreKit.
- Compliance is code: `scripts/check_compliance.py` allows public APIs only and rejects `dlopen`, `dlsym` and
  networking APIs. It runs in CI and before every commit. Also excluded: private frameworks, capture workarounds
  through ReplayKit, unsupported screen-recording entitlements and invented background modes.
- No data leaves the device. No analytics, tracking, advertising identifier or third-party SDK.
- One `PrivacyInfo.xcprivacy`, audited against the built app including dependencies
  (`scripts/check_privacy_manifest.py`). A checked-in manifest alone proves nothing.
- Usage descriptions exist only for capabilities that registered experiences use. Captured audio is processed in
  memory and not retained by default. Real-time audio callbacks do not allocate or wait on locks.
- Export-compliance declarations, the privacy policy, the license agreement text and the privacy answers are
  drafted from the built product (UA-F14). Usage descriptions are the union of what the registered experiences
  need, for example the microphone for A06–A08. The privacy label of the app therefore reflects every
  experience, including the few that ask for a permission. Exports carry no microphone data and no hidden metadata.

### 15.3 Accessibility and comfort

Native controls with VoiceOver labels and stable identifiers; Dynamic Type through XXXL without clipped controls;
iPhone and iPad layouts in the orientations each experience supports; Reduce Motion and Reduce Flashing honored by
every experience; no rule or state conveyed by color alone; meaningful empty, permission-denied and error states;
the flash limiter in every emissive pipeline. Accessibility audits run in the UI tests of each experience. Manual
VoiceOver testing on devices is recorded and is non-gating.

### 15.4 Licensing and originality

- ANGLE notices and every third-party license are bundled and shown in the app; `docs/legal/third-party.json` is
  complete; `scripts/check_licenses.py` passes.
- ProjectM and its presets are reference material of the harness. They are not linked into or shipped with the
  app; a symbol and dependency scan of the built app proves it.
- Every shader and generated asset in the bundle has provenance in the repository.
- License files are never removed, rewritten or merged without a legal review by the owner.
- The LGPL analysis of the actual linkage is `docs/legal/lgpl-analysis.md`; licenses of every component are
  recorded before anything is distributed.
- A distinctiveness matrix over all pairs of the 100 launch experiences (core abstraction, player action, win
  rule) shows that no two share a mechanic. The six close pairs named by the Round 2 source are checked first. A
  near-duplicate is redesigned before the lock; it is never merged or dropped (section 6.5). Names, trademarks
  and the age rating are owner reviews.
- Scans look for advertising SDKs, advertising identifiers, trackers, remote image pipelines, placeholder branding
  and copied art or audio. A clean scan is evidence, not legal assurance.
- Scientific content (astronomy, molecules, anatomy) carries sources and revision notes and is educational, not
  diagnostic.

## 16. Repository layout

Marks: **existing** stays as it is; **modify** stays and grows; **new** is created by the named feature; **move**
is relocated with `git mv` after parity is proven; **retire** is removed once its replacement is verified;
**archive** was moved to the archive by the consolidation. Nothing marked new exists today.

```
VisualCore/
├── README.md                     existing   public face
├── Auto-Creator.md               existing   this document
├── setup.md                      existing   machine setup
├── CLAUDE.md                     existing   bootstrap
├── LICENSE                       existing
├── project.yml                   modify     one shippable target "VisualCore" (UA-F04, UA-F10)
├── .claude/skills/speckit-*      existing   nine Spec Kit skills
├── .specify/                     modify     constitution 2.0.0 (CONSTITUTION-2)
├── .github/workflows/ci.yml      modify     validators and the unified build (UA-F00, UA-F10)
├── .github/workflows/push-scan.yml  existing  scan of every pushed range, never cancelled (UA-F00)
├── .autonomy/
│   ├── state.json, evidence/, checks/        existing   legacy ledger (never reset)
│   └── migration/ledger.json, evidence/, checks/   existing   migration ledger
├── Apps/
│   ├── VisualCore/               existing   the app: App/, Resources/, Tests/Unit, Tests/UI (created by UA-F04)
│   ├── GenerativeArtStudio/      move       → Packages/ExperiencesCreative/GenerativeArtStudio (UA-F07), then retire the target
│   ├── FluidArtPlayground/       move       likewise
│   ├── FractalExplorer/          move       likewise
│   └── ParticleUniverse/         move       likewise
├── Packages/
│   ├── VisualCore/               modify     + VisualCoreExperience (catalog UA-F01, experience contract UA-F02, storage handle and saved state UA-F05), VisualCoreGeometry, VisualCorePuzzle
│   ├── VisualCoreRendering/      modify     + VisualCoreExperienceHost (presenter, port, shell: UA-F02; session: UA-F03), VisualCoreStore
│   ├── ExperiencesCreative/      new        A01–A25: <Name>/Core, <Name>/Experience, <Name>/Shaders, tests
│   ├── ExperiencesRound02/       new        R02-G01 … G25
│   ├── ExperiencesRound03/       new        R03-G01 … G25
│   └── ExperiencesRound04/       new        R04-G01 … G25
├── Catalog/                      existing   experiences.json (generated), categories.json, registrations.json, path-map.json, experience-ids.golden.txt (UA-F01)
├── Showcase/                     existing   non-shipping framework showcase
├── Harnesses/                    existing   InteractiveDemo, SecondConsumer, ProjectMReference
├── External/projectm-ios/        existing   pinned read-only submodule
├── Configs/                      existing   toolchain.json, Signing.xcconfig (the local signing file is never committed), simulator-identifier-hashes.json
├── Tools/python/desktop_runbook.py   existing   legacy ledger tool
├── scripts/                      modify     + build_catalog.py, check_experience_symbols.py, xcodebuild_app.py, check_performance_docs.py, storage rules in check_app_isolation.py (UA-F05), verify_experiences.py, run_device_campaign.py
├── specs/                        modify     001–035 existing; 036–550 and rNN-* as features are specified
└── docs/
    ├── decisions/                modify     ADR-0001 … ADR-0009, then ADR-0010 (constitution 2.0.0)
    ├── catalog/                  existing   experience catalog, feature index, briefs, shared-feature map
    ├── migration/                existing   baseline, plan, path map, traceability matrix
    ├── archive/planning/         archive    every original planning document, byte-identical
    ├── brainstorm/, process/     existing   scoring study and the prompt manifest for features 001–185
    ├── verification/, performance/, release/, apps/   existing   evidence and records of completed work
    └── architecture/, api/, testing/, rendering/, legal/   existing
```

Naming conventions for new code: experience directory and module prefix are the experience name in upper camel
case (`InfiniteGeometry`); targets are `<Name>Core` (pure, host-testable) and `<Name>Experience` (SwiftUI and
scene); test targets add `Tests`; UI tests live in `Apps/VisualCore/Tests/UI/<Name>/`. Xcode projects are
generated with the pinned XcodeGen and are not committed. Shader caches, build output, derived data, preview
videos and generated indexes never enter Git. Third-party content enters only as a pinned, shallow submodule
(`git submodule update --init --depth 1 <path>`), never as a copy. The complete old-to-new
path map is in [`docs/migration/migration-plan.md`](docs/migration/migration-plan.md) and
`docs/migration/path-map.json`.

Dependency direction, enforced by `scripts/check_dependencies.py`:

```
Apps/VisualCore ──► Experiences* ──► VisualCoreRendering ──► VisualCore
       │                                   ▲
       └──► VisualCoreExperienceHost, VisualCoreStore ──┘
Experiences never import each other. Nothing in the app imports ProjectM.
```

# Part IV — Execution

## 17. Migration design

The migration turns four standalone apps and a plan for 296 more products into one app without losing anything
that is already verified. The file-level plan, the path map and the risk register are in
[`docs/migration/migration-plan.md`](docs/migration/migration-plan.md).

### 17.1 Principles

1. **Adapters first.** An existing app first becomes an experience through a thin adapter, with its sources where
   they are. Behavior does not change.
2. **Parity before moving.** Sources move (`git mv`, so history follows) only after the experience passes in the
   unified app: its Core package tests pass unchanged, its committed fixtures and checksums are bit-identical, and
   every UI test of the standalone app has a counterpart in the unified app.
3. **Retire last.** A standalone target leaves `project.yml` only after its experience is verified on both
   simulator runtimes. Until then it remains a non-shipping harness.
4. **One experience at a time.** Each adoption is its own commit series and can be reverted alone.
5. **Records are never rewritten.** Dossiers `specs/001`–`035`, ADR-0001 … 0008, legacy evidence and release
   dossiers under `docs/apps/` stay as history. A note may be added that store listings are superseded; nothing is
   deleted or re-ticked.

### 17.2 Adopting an existing app (UA-F07)

For each of A01, A02, A03 and A04, in that order:

1. Write the experience adapter over the existing scene and model types and register it.
2. Run the conformance helper and the session-host tests against it.
3. Port the UI tests into the unified app; keep a table of old and new test names; prove with the enumeration
   guard (`scripts/check_test_enumeration.py`) that none was lost.
4. Run the verification runner for the experience on both simulator runtimes.
5. Move the sources along the path map, update `Catalog/path-map.json`, and run steps 2 to 4 again.
6. Remove the standalone target from `project.yml` and regenerate the project.
7. Record `X-A01`, `X-A02` and `X-A03`. `X-A04` waits for the legacy gates A04-P04 … A04-P06.

### 17.3 Continuing the original apps

A04-P04 … A25-P06 keep their feature numbers (`specs/036` … `specs/185`), their archived prompts and their gates in
the legacy ledger, in the original order. What changes is where the code goes: the experience modules of
section 16 instead of a standalone app, and no per-app store work. An app that has not been started begins
directly as an experience; no standalone target is created for it.

### 17.4 What completed work maps to

| Completed and sealed | Stays valid as | New check that is still pending |
|---|---|---|
| F00–F09 framework foundation | the framework every experience uses | none; the reference regression reruns with every framework change |
| A01, A02, A03 (all phases) | the experience's domain logic, scenes, tests and fixtures | `X-A01`, `X-A02`, `X-A03`: adoption and the nine scenarios in the unified app |
| A04-P00 … A04-P03 | the first four phases of the experience | A04-P04 … P06 in the legacy ledger, then `X-A04` |
| Legacy `{device}` tasks T-F418, T-F523, T-F613, T-F714, T-F810, T-F915 | open, unchanged | run with the device campaign (section 23) or retired with a recorded reason if the unified app makes one inapplicable |
| Release dossiers and store-listing drafts of A01–A03 | history | UA-F14 prepares the one app's release |

No ledger gate, ticked task or evidence file of the left column is changed by the right column.

### 17.5 Retirements

| Retired | When | Record kept |
|---|---|---|
| The four standalone app targets and their bundle identifiers | after the experience's `X-` gate | `Catalog/path-map.json`, Git history |
| Per-app `Info.plist`, asset catalogs and privacy manifests | with the target | merged into the app's single set |
| Legacy gates `IMPLEMENTATION-LOCK`, `D1-A01` … `D3-A25`, `DEVICE-RECONCILE`, `SUITE-FINAL` | never run | superseded note in the migration ledger |
| Per-round device campaigns and per-game store work in the archived prompts | never run | canonical overrides (section 21) |

### 17.6 Rollback

Every milestone is a series of small commits on `main`. An adoption step is reverted with
`git revert` of its commits; the standalone target still exists until step 6 of section 17.2, so the app remains
buildable throughout. The state before the consolidation is recoverable from `main`, from the baseline manifest
and from the `git bundle` outside the repository. History is never rewritten and nothing is force-pushed.

## 18. Phases, milestones and gates

### 18.1 Milestones

| Milestone | Content | Exit gate |
|---|---|---|
| M0 Consolidation | archive, catalog, decisions, this document, ledgers, validators | `M0-CONSOLIDATION` |
| M1 Governance | constitution 2.0.0 and ADR-0010; governance tooling | `CONSTITUTION-2`, `UA-F00` |
| M2 Walking skeleton | catalog, ExperienceKit, session host, app shell, persistence, quality profiles, verification runner, build and CI, compliance, lock tooling — proven end to end with one experience | `UA-F01` … `UA-F06`, `UA-F09` … `UA-F12` |
| M3 Adoption | A01–A04 become experiences | `UA-F07`, `X-A01`, `X-A02`, `X-A03` |
| M4 Creative library | A04-P04 … A25-P06 in the legacy ledger, each app verified in the unified app | `X-A04` … `X-A25` |
| M5 Round 2 | 24 shared features, 250 game features, 25 games | `X-R02-G01` … `X-R02-G25`, then `LOCK-FREE-50` |
| M6 Purchase | the single StoreKit 2 unlock | `UA-F08` |
| M7 Premium library | shared and game features of Rounds 3 and 4, 50 games | `X-R03-G01` … `X-R04-G25`, then `LOCK-PREMIUM-50` |
| M8 Lock | device lab tooling; independent rerun of all 100 | `UA-F13`, `ImplementationLock-100` |
| M9 Devices | D1, then D2, then D3; fixes and reruns | `DEV1-CAMPAIGN`, `DEV2-CAMPAIGN`, `DEV3-CAMPAIGN`, `DEVICE-RECONCILE-100` |
| M10 Release preparation | artifacts, metadata, compliance; submission only with owner authorization | `UA-F14`, `RELEASE-PREP` |
| M11 and later | Rounds 5–12 in score order, one round per batch | `LOCK-ROUND-NN`, `RECONCILE-ROUND-NN` |

The mandated order is: unified-app features first; the 50 free experiences while the shell, quality profiles,
persistence and evidence harness mature; then the purchase; then the 50 premium experiences; then the lock; then
devices; then release preparation; then the backlog.

### 18.2 Gates in the migration ledger

<!-- GENERATED:BEGIN gate-structure -->
| Kind | Gates | First … last |
|---|---:|---|
| milestone | 1 | `M0-CONSOLIDATION` |
| governance | 1 | `CONSTITUTION-2` |
| unified-feature | 15 | `UA-F00` … `UA-F14` |
| experience | 100 | `X-A01` … `X-R04-G25` |
| shared-round-feature | 58 | `R02-F01` … `R04-F12` |
| game-feature | 750 | `R02-G01-01` … `R04-G25-10` |
| lock | 4 | `LOCK-FREE-50` … `DEVICE-RECONCILE-100` |
| device-row | 300 | `DEV1-A01` … `DEV3-R04-G25` |
| device-campaign | 3 | `DEV1-CAMPAIGN` … `DEV3-CAMPAIGN` |
| release | 1 | `RELEASE-PREP` |
| **Total** | **1233** | |

Execution order stored in the ledger (first to last):

1. `M0-CONSOLIDATION`
2. `CONSTITUTION-2`
3. `UA-F00` … `UA-F12` (12 gates)
4. `X-A01` … `X-A25` (25 gates)
5. `R02-F01` … `R02-F34` (34 gates)
6. `R02-G01-01` … `X-R02-G25` (275 gates)
7. `LOCK-FREE-50`
8. `UA-F08`
9. `R03-F01` … `R03-F12` (12 gates)
10. `R03-G01-01` … `X-R03-G25` (275 gates)
11. `R04-F01` … `R04-F12` (12 gates)
12. `R04-G01-01` … `X-R04-G25` (275 gates)
13. `LOCK-PREMIUM-50`
14. `UA-F13`
15. `ImplementationLock-100`
16. `DEV1-A01` … `DEV1-R04-G25` (100 gates)
17. `DEV1-CAMPAIGN`
18. `DEV2-A01` … `DEV2-R04-G25` (100 gates)
19. `DEV2-CAMPAIGN`
20. `DEV3-A01` … `DEV3-R04-G25` (100 gates)
21. `DEV3-CAMPAIGN`
22. `DEVICE-RECONCILE-100`
23. `UA-F14`
24. `RELEASE-PREP`
<!-- GENERATED:END gate-structure -->

### 18.3 Readiness and order

- A gate is ready when all its dependencies are pass (or superseded by gates that are pass) and, for an `X-A<nn>`
  gate, when its seven legacy gates are pass. `python3 scripts/migration_ledger.py next` prints the ready gates in
  execution order; **the first line is the next thing to do**. When that line says it waits for legacy gates, the
  next thing to do is the legacy gate printed by `python3 Tools/python/desktop_runbook.py status`.
- Dependencies encode technical prerequisites and the mandated phase order (`UA-F08` after `LOCK-FREE-50`, the
  premium rounds after `UA-F08`, `UA-F13` after `LOCK-PREMIUM-50`, `UA-F14` after `DEVICE-RECONCILE-100`). The
  order inside a phase is the catalog order.
- A gate that cannot proceed because of an owner-only action is blocked with
  `python3 scripts/migration_ledger.py block --gate <G> --reason "BLOCKED_OWNER_ACTION: <exact steps>"`; work
  continues with the next ready gate. Nothing else justifies skipping a gate.
- An experience gate is never recorded with a known failing requirement, and never to keep a schedule.

### 18.4 Backlog rounds

After `RELEASE-PREP`, `python3 scripts/migration_ledger.py add-round --round 5` appends the gates of Round 5
(shared features, 250 game features, 25 integration gates, a round lock, 75 device rows, a reconciliation gate).
Round N+1 is added only after Round N. Each round is one bounded batch and ends with its own lock and device rows
before anything of it is released. A regression of an earlier round that is found during a round is fixed in
that round.

### 18.5 Parallel work

At most ten agents work at once and one writer owns each file. Research, reviews, test fixtures and separate
experiences are good parallel units; the integration session owns `project.yml`, the package manifests, the
catalog, `tasks.md`, the ledgers and this document. Heavy builds, simulator test runs and all device jobs run one
at a time on the one Mac. An agent's report is a claim: inspect the diff and rerun the tests before ticking a task.
Two Spec Kit features are never in progress in the same working tree.
One session writes; any other session only analyses, in its own Git worktree. No schedule that starts further
schedules, no agent that starts copies of itself, and no automation of the Claude Desktop interface.

Defaults when no one can be asked: inspect the real API before designing against it; measure before optimizing;
fix and rerun instead of weakening a test; report blocked instead of inventing a result; choose the simplest
defensible option and record why.

## 19. Spec Kit procedure and numbering

Spec Kit is installed (`.specify/`, nine skills under `.claude/skills/`). It is never reinitialized, and completed
dossiers are never recreated. Skills run inside the Claude Desktop Code conversation, never through a CLI.

### 19.1 Numbering

| Spec directory | Feature | Ids in the dossier | Prompts |
|---|---|---|---|
| `specs/001`–`010` | F00–F09 | `FR-F<k>##`, `SC-F<k>##`, `T-F<k>##` | sealed |
| `specs/011`–`185` | A<nn>-P<p>, number = 10 + (nn − 1) · 7 + p + 1 | `FR-A<nn>-<p>##`, `SC-A<nn>-<p>##`, `T-A<nn>-<p>##` | `scripts/speckit_prompts.py --feature NNN` |
| `specs/186`–`200` | UA-F00 … UA-F14, number = 186 + kk | `FR-U<kk>-###`, `SC-U<kk>-###`, `T-U<kk>-###` | section 20 |
| `specs/201`–`234` | R02-F<ff>, number = 200 + ff | `FR-R02F<ff>-###`, `SC-…`, `T-…` | archive, section 21 |
| `specs/301`–`550` | R02-G<gg>-<ff>, number = 301 + (gg − 1) · 10 + (ff − 1) | `FR-R02G<gg><ff>-###`, `SC-…`, `T-…` | archive, section 21 |
| `specs/r<nn>-f<ff>-*` | R<nn>-F<ff>, rounds 3–12 | `FR-R<nn>F<ff>-###`, `SC-…`, `T-…` | archive, section 21 |
| `specs/r<nn>-g<gg>-<ff>-*` | R<nn>-G<gg>-<ff>, rounds 3–12 | `FR-R<nn>G<gg><ff>-###`, `SC-…`, `T-…` | archive, section 21 |

The exact directory of every pending feature is the `spec_dir` printed by
`python3 scripts/migration_ledger.py show --gate <id>`. Where an archived prompt says "assign ids under R2-F05" or
"unique R03-F03-Txxx ids", the forms above are used. `scripts/validate_docs.py` enforces the namespaces and the
uniqueness of every id; a ticked task without "— Verified YYYY-MM-DD:" fails validation.

### 19.2 First gate after the consolidation: the constitution

Constitution 1.5.0 described 25 separate apps. Before any new feature is specified it is amended to
2.0.0 with `/speckit-constitution` and this prompt (also printed by
`python3 scripts/planning_index.py prompt --feature CONSTITUTION-2`):

<!-- GENERATED:BEGIN constitution-prompt -->
```text
/speckit-constitution Amend the VisualCore constitution from 1.5.0 to 2.0.0 (MAJOR: scope and Principle V are redefined) to adopt ADR-0009. Keep Principles I, II, II-a, III, IV, VI, VII, VIII, IX and X and every app-scoped rule for A01-A04 in force; change only what ADR-0009 changes, and record a dated rationale that cites ADR-0009. Required amendments: (1) Scope: one iPhone/iPad application, VisualCore, with one shippable app target and modular registered experiences; the Showcase and the harnesses stay non-shipping; the 25 original apps and all round games are experiences, not separate apps. (2) Add Principle XI, One App and Stable Experience Identity: exactly one shippable app target and bundle identifier; every experience has an immutable id '<code>.<slug>' from docs/catalog/experience-catalog.json; experiences never depend on each other; ProjectM types stay out of the app; the launch set of 100 experiences is never reduced, merged or substituted (ADR-0009 D-16). (3) Add Principle XII, One Purchase and No Advertising (NON-NEGOTIABLE): free download; exactly one non-consumable StoreKit 2 product at USD 1.99 unlocking every premium experience including future ones; no ads, ad SDKs, ad identifiers, rewarded ads, subscriptions, consumables, external payment paths, dark patterns or required accounts; premium gating at routing and at experience activation; the test-only entitlement fixture must be absent from shipping Release binaries. (4) Add Principle XIII, Code-Driven Visuals: all worlds and signature effects are GLSL, procedural meshes, SDFs, particles and deterministic animation on the existing OpenGL ES to ANGLE to Metal path; no required human-made models, purchased art packs, prompt-generated images or external image services. (5) Redefine Principle V, Implementation Before Devices: all 100 launch experiences (50 free, 50 premium) are implemented and pass host and simulator acceptance, and ImplementationLock-100 is recorded by scripts/migration_ledger.py, before any physical-device install, launch or test of the unified app; then D1, D2, D3 in that order, 100 experiences each; D3 stays on iPadOS 26.5; historical device observations never certify the unified build. (6) Principle VIII: one PrivacyInfo.xcprivacy for the app, audited against the built product; the app makes no network request of its own (ADR-0009 D-15); human-judgement reviews are owner reviews and do not gate (D-17). (7) Development Workflow: feature numbering and ID namespaces of Auto-Creator.md section 19; the legacy ledger .autonomy/state.json keeps the A-phase gates; .autonomy/migration/ledger.json holds every new gate; work is committed on main and pushed to origin main after every commit, only after scripts/prepush_scan.py passes (owner ruling of 2026-11-11). (8) App-Scoped Rules: keep the A01-A04 rules, reworded from 'app' to 'experience' only where the directory or target wording would otherwise be false. (9) Governance precedence: Apple and toolchain behavior and observed tests, then Auto-Creator.md and CLAUDE.md, then this constitution and ADRs, then the planning archive, then generated code. Do not delete or weaken any requirement that ADR-0009 does not supersede. After amending, update the Sync Impact Report, run python3 scripts/validate_docs.py, and write ADR-0010 recording the amendment.
```
<!-- GENERATED:END constitution-prompt -->

Then: write `docs/decisions/ADR-0010-constitution-2-0-0.md`, run `python3 scripts/validate_docs.py`, and record
the gate:

```bash
python3 scripts/migration_ledger.py run-check --gate CONSTITUTION-2 --name docs -- python3 scripts/validate_docs.py
python3 scripts/migration_ledger.py run-check --gate CONSTITUTION-2 --name steering -- python3 scripts/validate_autocreator.py
python3 scripts/migration_ledger.py seal --gate CONSTITUTION-2
python3 scripts/migration_ledger.py record --gate CONSTITUTION-2
```

The eleven per-round `/speckit-constitution` prompts of the archive are superseded by this single amendment, which
[ADR-0010](docs/decisions/ADR-0010-constitution-2-0-0.md) records.

### 19.3 The loop for one feature

One feature per gate. The same loop serves every feature; only the source of the prompts and the ledger differ.

**A. Feature in the migration ledger** (unified-app, shared round and game features):

```bash
python3 scripts/migration_ledger.py next --limit 1
python3 scripts/migration_ledger.py show --gate <GATE>
mkdir -p <spec_dir> && printf '{\n  "feature_directory": "%s"\n}\n' <spec_dir> > .specify/feature.json
python3 scripts/planning_index.py prompt --feature <GATE> --override
```

The first command prints the gate, the second its spec directory and dependencies, the third points Spec Kit at
the directory, the fourth prints the eight prompts with the override note.

**B. Phase of an original app** (legacy ledger):

```bash
python3 Tools/python/desktop_runbook.py status
mkdir -p specs/<NNN>-<slug> && printf '{\n  "feature_directory": "%s"\n}\n' specs/<NNN>-<slug> > .specify/feature.json
python3 scripts/speckit_prompts.py --feature <NNN>
python3 scripts/planning_index.py prompt --feature A<nn>-P<p> --override
```

The first command prints the gate (for example A04-P04, which is feature 036), the third the prompts of the phase,
the fourth the override note to append to each prompt.

Then, in the conversation, in this order and without skipping one:

1. `/speckit-specify` with the specify prompt.
2. `/speckit-clarify` — answer every question yourself, recommended option first, and record each answer under
   Clarifications in `spec.md`.
3. `/speckit-plan` — begin with a read-only audit of the real sources; reference only verified APIs.
4. `/speckit-checklist` — evaluate every item yourself, record the evaluation, correct the specification.
5. `/speckit-tasks` — tests before the code they prove; `{device}` and `{owner}` tasks for what the simulator
   cannot prove.
6. `/speckit-analyze` — apply the fixes and repeat until no critical or high finding remains.
7. `/speckit-implement` — small verified groups; real builds and tests; evidence for every tick.
8. `/speckit-converge` — implement what it appended and converge again, until a run appends nothing.

Each prompt is used verbatim. Additions are labelled `Canonical override:` and never replace prompt text. A skill
is never replaced by hand-written artifacts.

- Before each skill, confirm that `.specify/feature.json` names the feature's directory.
- Start a feature by reading its sources in full: the brief or the card and, for an original app, the one manual
  of that app. Read archived material in bounded pieces, and never describe a part that was not read.
- Every task names its file path, its test and its exact expected result.
- A convergence run does not report "converged" when only a plan, empty source files, an agent's claim or mocked
  tests exist.
- Phase 00 of an original app starts with the manual's own `/speckit-constitution` prompt (printed first by
  `scripts/speckit_prompts.py` for that feature). It adds the experience's rules under App-Scoped Rules of the
  constitution (ADR-0007, ADR-0008) and, with the override, never restates a standalone-app scope.
- Use the skill names that are installed (`ls .claude/skills`); a missing skill is no reason to invent a command.
- An owner waiver, an Apple entitlement decision or a legal approval is never invented. A waived task keeps its
  box unticked and carries the owner's dated ruling.
- Run `python3 scripts/verify_environment.py` at the start of a session. A pinned tool is never installed or
  upgraded silently.

Record evidence and close the gate. In the migration ledger:

```bash
python3 scripts/migration_ledger.py run-check --gate <GATE> --name <check> -- <command and arguments>
python3 scripts/migration_ledger.py seal --gate <GATE>
python3 scripts/migration_ledger.py record --gate <GATE>
```

In the legacy ledger (its `run-check` defaults to a timeout of 1800 seconds, so the limit is passed explicitly; the
last command refreshes the catalog's implementation state):

```bash
python3 Tools/python/desktop_runbook.py run-check --stage <GATE> --name <check> --timeout 600 -- <command and arguments>
python3 Tools/python/desktop_runbook.py seal --stage <GATE>
python3 Tools/python/desktop_runbook.py record --stage <GATE> --evidence .autonomy/evidence/<GATE>.json
python3 scripts/planning_index.py build
```

Commit after every skill, every task and every recorded gate. Then take the next gate in the same turn. Nothing in
this loop is a stopping point: not a finished skill, task, feature, gate or milestone, not a progress note and not
a long conversation (the app summarizes the context by itself). The loop runs without a pause until the device
campaign of the 100 launch experiences; only the four stop conditions of section 28 end a turn (owner ruling of
2026-11-12).

### 19.4 Tasks, ticks and evidence

- A task is ticked only after its acceptance proof was reproduced in this session, in the form
  `- [X] <id> … — Verified YYYY-MM-DD: <command and result>`. `python3 scripts/tick_task.py <spec_dir> <task-id>
  "<evidence>" "<commit subject>"` does this, validates the documents and commits; it adds the "— Verified" prefix
  itself and pushes only when the branch is `main` and the pre-push scan is clean. It refuses without changing a
  file when the task is missing, ticked or listed twice or the evidence is empty or has a line break; when the
  validation fails after the tick it restores the task list and commits nothing; when the scan finds something or
  the push fails, the commit stays local and the tool says so.
- `{device}` tasks stay open until the device campaign. `{owner}` tasks stay open until the owner acts. Neither
  blocks a simulator gate, and neither is ever ticked from a simulator result.
- Evidence is a real command run through `run-check`. Logs go to `.autonomy/logs/` (not tracked); attestations
  with the log's SHA-256 and sealed evidence files are tracked.
- An evidence command is an argument list, never a shell string: no shell wrapper and no inline script. The
  migration ledger refuses both.
- Long commands run in the foreground with a timeout of ten minutes or less; larger suites are split with
  `--only` and `--skip`. A job is never left in the background at the end of a turn.

### 19.5 Working lessons that are rules

- Run `xcodebuild` tests with `-test-timeouts-enabled YES -default-test-execution-time-allowance 180`, write the
  complete output to a file and read the file; never pipe a live build through `tail`. After a UI run, check with
  `scripts/check_test_enumeration.py` that every declared test actually ran.
- Run `xcodegen generate` after adding or moving test files; a run that executed zero tests is not evidence.
- For a hang: check the process's elapsed time, take a simulator screenshot
  (`xcrun simctl io <udid> screenshot <path>`) and read the last "Test Case … started" line.
- Choose simulators by runtime, not by an identifier from an old log. Isolate runtimes between parallel workers.
  Erase a corrupted simulator only after saving the diagnostics.
- In SwiftUI, keep per-frame state out of views that hold controls: a per-frame re-render swallows taps.
  Lazy lists create rows only when scrolled into view; labels may contain grouped numbers.
- A framework change needs the seven-step reference regression in two chunks, then a clean build-for-testing of
  the consumers. A noise-floor-relative reference criterion that fails once is rerun unchanged once, and the
  failed attempt stays in the record.
- Percentage criteria need at least 200 samples; fewer is a development signal, not a result.
- Commands that address a simulator or a device are filled in from live `xcrun` output, run with an explicit
  timeout and write their complete output to a file. `|| true` is never appended to hide a failure.
- One simulator per lane. Permissions are reset between scenarios with `xcrun simctl privacy`.
- Never test on a simulator that another job is using. Erase a simulator whose state looks wrong, after saving
  what is needed.
- In UI tests, toolbar items exist only on the view that declares them, and values are read from
  `XCUIElement.label`. A snapshot test inspects the scene's output, not merely that a screen opened.
- A failure is repaired at its smallest cause; the exact tests are rerun; the new attempt is appended to the
  record; an acceptance criterion is never weakened to pass.
- A stage prompt is copied from the output of `scripts/planning_index.py prompt` or `scripts/speckit_prompts.py`,
  never retyped from memory: the evidence commands differ from feature to feature. A skill is invoked before any of
  its work is done; an analysis written first is not a run of `/speckit-analyze`.
- CI runs on every push, so `main` is kept green commit by commit: a test task is seen to fail locally and is then
  committed together with the implementation it proves, and a commit that adds a public symbol also updates the
  API baseline (`python3 scripts/check_public_api.py --update`); the final baseline review remains its own task.
- In `zsh`, a command kept in a variable is not split into words; use a shell function for repeated `run-check`
  calls.

## 20. Unified-app features: briefs and prompts

Fifteen features build what the planning corpus never had: the one app around the experiences. Each is one Spec
Kit feature and one gate. The briefs are data (`docs/catalog/unified-app-features.json`); this section is rendered
from them, and `python3 scripts/planning_index.py prompt --feature UA-F<kk> [--stage <stage>]` prints the same
prompts for copying. Dependencies shown are the ledger's: every feature also depends on `CONSTITUTION-2`, and
three carry a phase dependency (section 18.3).

Each feature ends the same way: `/speckit-converge` and `/speckit-implement` alternate until a convergence run
appends nothing; then the gate is sealed and recorded from real evidence.

<!-- GENERATED:BEGIN unified-features -->
### UA-F00 Governance tooling: feature numbering, validators and ledger operation

| | |
|---|---|
| Spec directory | `specs/186-ua-f00-governance-tooling` |
| Ids | `FR-U00-###`, `SC-U00-###`, `T-U00-###` |
| Ledger gate | `UA-F00`; depends on `CONSTITUTION-2` |
| Read first | Auto-Creator.md sections 19 and 25; ADR-0009 D-11, D-12; ADR-0004; scripts/validate_docs.py; scripts/tick_task.py; scripts/migration_ledger.py; scripts/prepush_scan.py |
| Absorbs | R02-F01 (Round 1 evidence audit: replaced by the baseline and the ledgers) |

**Scope.** Make the repository tooling understand the unified numbering map so that every later feature can be specified, validated, ticked and recorded mechanically: extend scripts/validate_docs.py namespaces, keep scripts/tick_task.py and scripts/prepush_scan.py as the only way a commit is pushed, wire the new validators into CI, and keep scripts/migration_ledger.py as the only writer of the migration ledger.

**Acceptance.**

1. validate_docs.py accepts spec directories 186-200 (namespace U<kk>), 201-234 (R02F<ff>), 301-550 (R02G<gg><ff>) and specs/rNN-fFF-* / specs/rNN-gGG-FF-* (RnnFff / RnnGggff), enforces unique FR/SC/T ids inside each namespace, and still passes the 35 existing dossiers unchanged.
2. Each new namespace has a positive and a negative fixture test in scripts/test_scripts.py.
3. tick_task.py ticks tasks of every namespace, refuses when validate_docs.py fails, and pushes only on branch main and only after scripts/prepush_scan.py passes.
4. For every pending feature of the launch scope, a test proves that a non-empty prompt exists for all eight stages (scripts/speckit_prompts.py for 036-185, scripts/planning_index.py prompt for archived and UA features).
5. migration_ledger.py self-tests cover: dependency order refusal, duplicate attestation refusal, changed-log refusal, device gate before ImplementationLock-100 refusal, Claude CLI refusal, legacy-gate requirement of X-A gates.
6. .github/workflows/ci.yml runs validate_autocreator.py, planning_archive.py verify, planning_index.py verify and migration_ledger.py validate.
7. scripts/prepush_scan.py has self-tests for every pattern it claims to find and for the forbidden tracked paths, and CI runs it over the pushed range.

**Evidence commands.**

- `python3 scripts/test_scripts.py`
- `python3 scripts/validate_docs.py`
- `python3 scripts/validate_autocreator.py`
- `python3 scripts/migration_ledger.py validate`
- `python3 scripts/prepush_scan.py`

**Device-only, after ImplementationLock-100 (`{device}` tasks).** None.

**Owner-only (`{owner}` tasks).** None.

**Out of scope.** Any app or framework source; Changing the legacy ledger or its tool.

#### UA-F00 `/speckit-specify`

```text
/speckit-specify Feature UA-F00: Governance tooling: feature numbering, validators and ledger operation.
SCOPE: Make the repository tooling understand the unified numbering map so that every later feature can be specified, validated, ticked and recorded mechanically: extend scripts/validate_docs.py namespaces, keep scripts/tick_task.py and scripts/prepush_scan.py as the only way a commit is pushed, wire the new validators into CI, and keep scripts/migration_ledger.py as the only writer of the migration ledger.
DEPENDS ON: none (each must be pass in the migration ledger before this feature is implemented).
SOURCES TO READ FIRST: Auto-Creator.md sections 19 and 25; ADR-0009 D-11, D-12; ADR-0004; scripts/validate_docs.py; scripts/tick_task.py; scripts/migration_ledger.py; scripts/prepush_scan.py.
ABSORBED SOURCE REQUIREMENTS: R02-F01 (Round 1 evidence audit: replaced by the baseline and the ledgers). Read each archived feature with python3 scripts/planning_index.py prompt --feature <ID> --stage specify, and list every unique requirement in the specification as adopted, adapted or superseded with the reason.
ACCEPTANCE (each item becomes at least one functional requirement and one measurable success criterion): (1) validate_docs.py accepts spec directories 186-200 (namespace U<kk>), 201-234 (R02F<ff>), 301-550 (R02G<gg><ff>) and specs/rNN-fFF-* / specs/rNN-gGG-FF-* (RnnFff / RnnGggff), enforces unique FR/SC/T ids inside each namespace, and still passes the 35 existing dossiers unchanged. (2) Each new namespace has a positive and a negative fixture test in scripts/test_scripts.py. (3) tick_task.py ticks tasks of every namespace, refuses when validate_docs.py fails, and pushes only on branch main and only after scripts/prepush_scan.py passes. (4) For every pending feature of the launch scope, a test proves that a non-empty prompt exists for all eight stages (scripts/speckit_prompts.py for 036-185, scripts/planning_index.py prompt for archived and UA features). (5) migration_ledger.py self-tests cover: dependency order refusal, duplicate attestation refusal, changed-log refusal, device gate before ImplementationLock-100 refusal, Claude CLI refusal, legacy-gate requirement of X-A gates. (6) .github/workflows/ci.yml runs validate_autocreator.py, planning_archive.py verify, planning_index.py verify and migration_ledger.py validate. (7) scripts/prepush_scan.py has self-tests for every pattern it claims to find and for the forbidden tracked paths, and CI runs it over the pushed range.
OUT OF SCOPE: (1) Any app or framework source. (2) Changing the legacy ledger or its tool.
DEVICE-ONLY VERIFICATION (tasks tagged {device}, run only after ImplementationLock-100): none.
OWNER-ONLY ITEMS (tasks tagged {owner}, never performed by the agent): none.
BOUNDARIES: one app target (VisualCore) and one bundle identifier; experiences never depend on each other; the OpenGL ES to ANGLE to Metal path is the only renderer and is not forked; External/projectm-ios is read-only and ProjectM types stay out of the VisualCore public API and out of the app; public Apple APIs only; no advertising, analytics or tracking code and no network use; pure logic goes in Packages/VisualCore and GPU or UIKit code in Packages/VisualCoreRendering; every public symbol gets /// documentation and the API baseline is updated; no physical-device action before ImplementationLock-100; owner-only actions are recorded as BLOCKED_OWNER_ACTION and never performed.
Write prioritized user stories that can each be tested alone, acceptance scenarios, and edge cases for failure, cancellation, lifecycle interruption, memory pressure and corrupted or newer-version data where they apply. State requirements as observable behavior; name existing modules only where the brief names them.
Canonical override: feature directory specs/186-ua-f00-governance-tooling; requirement ids FR-U00-###, success criteria SC-U00-###, task ids T-U00-###.
```

#### UA-F00 `/speckit-clarify`

```text
/speckit-clarify Review the UA-F00 specification for unverified VisualCore or Apple APIs, lifecycle and thread-ownership assumptions, data-format and migration semantics, performance statements that need a device, and anything that contradicts ADR-0009 or the Auto-Creator.md sections named in the sources. Ask only questions whose answer changes the design, at most five.
Canonical override: feature directory specs/186-ua-f00-governance-tooling; requirement ids FR-U00-###, success criteria SC-U00-###, task ids T-U00-###. Answer every question yourself under the owner's standing delegation, recommended option first, and record each answer in spec.md under Clarifications.
```

#### UA-F00 `/speckit-plan`

```text
/speckit-plan Create the technical plan for UA-F00. Begin with a read-only audit of the existing sources named in the brief and record it in research.md; reference only APIs the audit verified. Give exact source paths, each marked existing, new, move or modify; module and dependency direction; public API; lifecycle and thread-ownership contracts; data schemas with versions and migrations; the tests of each layer (host, package tests on the iOS 27.x and iOS 26.5 simulators, app UI tests); build and test commands; rollback. Check the plan against every constitution principle. quickstart.md must contain these evidence commands: python3 scripts/test_scripts.py; python3 scripts/validate_docs.py; python3 scripts/validate_autocreator.py; python3 scripts/migration_ledger.py validate; python3 scripts/prepush_scan.py. When VisualCore changes: python3 scripts/check_public_api.py --update, python3 scripts/check_documented_api.py, and the seven-step ProjectM reference regression in two chunks.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/186-ua-f00-governance-tooling; requirement ids FR-U00-###, success criteria SC-U00-###, task ids T-U00-###. The clarification decisions are binding.
```

#### UA-F00 `/speckit-checklist`

```text
/speckit-checklist Generate the requirements-quality checklist for UA-F00: completeness, clarity, consistency, measurability, lifecycle and failure coverage, privacy and no-advertising constraints, accessibility, the split between simulator-verifiable and device-only requirements, and traceability to the sources.
Canonical override: feature directory specs/186-ua-f00-governance-tooling; requirement ids FR-U00-###, success criteria SC-U00-###, task ids T-U00-###. Evaluate every item yourself under the owner's standing delegation, record the evaluation in the checklist, and correct the specification for every failed item before continuing.
```

#### UA-F00 `/speckit-tasks`

```text
/speckit-tasks Break UA-F00 into dependency-ordered tasks with exact files, tests written before the code they prove, an integration acceptance task per user story, commit boundaries and review checkpoints. Include one task for every evidence command of quickstart.md; the documentation, API-baseline and ProjectM-regression tasks when VisualCore changes; one task tagged {device} for every device-only item and one tagged {owner} for every owner-only item; and a final task that runs /speckit-converge until it appends nothing.
Canonical override: feature directory specs/186-ua-f00-governance-tooling; requirement ids FR-U00-###, success criteria SC-U00-###, task ids T-U00-###. Tasks start at T-U00-001. Evidence is recorded with python3 scripts/migration_ledger.py run-check --gate UA-F00 --name <check-name> -- <command>.
```

#### UA-F00 `/speckit-analyze`

```text
/speckit-analyze Validate the UA-F00 specification, plan and tasks: requirements without tasks, tasks without requirements, speculative dependencies, missing tests, ambiguous terms, and conflicts with the constitution or ADR-0009. Stop if a critical finding remains.
Canonical override: feature directory specs/186-ua-f00-governance-tooling; requirement ids FR-U00-###, success criteria SC-U00-###, task ids T-U00-###. Apply the fixes yourself under the owner's standing delegation, record them in the artifacts, and run the analysis again until no critical or high finding remains.
```

#### UA-F00 `/speckit-implement`

```text
/speckit-implement Implement UA-F00 task by task in small verified groups. Run the real builds and tests (host tests, package tests on the iOS 27.x and iOS 26.5 simulators, app tests where the feature has UI); a task is never ticked from reading code. Tasks tagged {device} or {owner} stay open, are listed in the final report and do not block the gate.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/186-ua-f00-governance-tooling; requirement ids FR-U00-###, success criteria SC-U00-###, task ids T-U00-###. Record each passing command with python3 scripts/migration_ledger.py run-check --gate UA-F00 --name <check-name> -- <command>.
```

#### UA-F00 `/speckit-converge`

```text
/speckit-converge Assess the code against the UA-F00 specification, plan and tasks and append every remaining gap as a task. Then run /speckit-implement for the appended tasks and /speckit-converge again; repeat until a run appends nothing and reports what it checked. Only then seal and record the gate: python3 scripts/migration_ledger.py seal --gate UA-F00 && python3 scripts/migration_ledger.py record --gate UA-F00.
Canonical override: feature directory specs/186-ua-f00-governance-tooling; requirement ids FR-U00-###, success criteria SC-U00-###, task ids T-U00-###. Appended tasks continue the T-U00-### sequence.
```

### UA-F01 Experience catalog and stable identity

| | |
|---|---|
| Spec directory | `specs/187-ua-f01-experience-catalog` |
| Ids | `FR-U01-###`, `SC-U01-###`, `T-U01-###` |
| Ledger gate | `UA-F01`; depends on `CONSTITUTION-2`, `UA-F00` |
| Read first | Auto-Creator.md sections 5 and 11.2; ADR-0009 D-01, D-02, D-06; docs/catalog/experience-catalog.json; Packages/VisualCore (VisualCoreParameters, VisualCorePersistence for bounded decoding patterns) |
| Absorbs | — |

**Scope.** Add the pure module VisualCoreExperience to Packages/VisualCore (new) with ExperienceID, ExperienceDescriptor, ExperienceTier, ExperienceCategory and a validated CatalogManifest, plus the runtime manifest Catalog/experiences.json, Catalog/categories.json, Catalog/path-map.json (all new) and scripts/build_catalog.py (new) that derives the runtime manifest from the planning catalog and the registered experiences.

**Acceptance.**

1. Experience ids are exactly '<code>.<slug>' of docs/catalog/experience-catalog.json; a committed golden list makes any change of a shipped id a test failure.
2. Among launch experiences the manifest holds exactly 50 free (A01-A25, R02-G01..G25) and 50 premium (R03-G01..R04-G25); any other allocation fails validation.
3. Every experience has one launcher category (create, audio, play, learn, ambient, tools, puzzle) and its family as a tag; search over title, summary and tags is deterministic and locale-independent.
4. The loader rejects unknown schema versions, duplicate ids, missing fields, non-finite numbers and files over the size cap (Constitution IX) with typed errors.
5. The runtime manifest lists an experience as available only when its integration gate X-<code> is pass in the migration ledger; planned experiences are never shown as available.
6. A pure registry check proves a one-to-one match between manifest entries and registered factories; it is reused by the app tests.
7. Public API documented, API baseline updated, package tests added, ProjectM reference regression rerun.

**Evidence commands.**

- `swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests`
- `python3 scripts/build_catalog.py --check`
- `python3 scripts/check_public_api.py`
- `python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`

**Device-only, after ImplementationLock-100 (`{device}` tasks).** None.

**Owner-only (`{owner}` tasks).** None.

**Out of scope.** Launcher UI; StoreKit.

#### UA-F01 `/speckit-specify`

```text
/speckit-specify Feature UA-F01: Experience catalog and stable identity.
SCOPE: Add the pure module VisualCoreExperience to Packages/VisualCore (new) with ExperienceID, ExperienceDescriptor, ExperienceTier, ExperienceCategory and a validated CatalogManifest, plus the runtime manifest Catalog/experiences.json, Catalog/categories.json, Catalog/path-map.json (all new) and scripts/build_catalog.py (new) that derives the runtime manifest from the planning catalog and the registered experiences.
DEPENDS ON: UA-F00 (each must be pass in the migration ledger before this feature is implemented).
SOURCES TO READ FIRST: Auto-Creator.md sections 5 and 11.2; ADR-0009 D-01, D-02, D-06; docs/catalog/experience-catalog.json; Packages/VisualCore (VisualCoreParameters, VisualCorePersistence for bounded decoding patterns).
ACCEPTANCE (each item becomes at least one functional requirement and one measurable success criterion): (1) Experience ids are exactly '<code>.<slug>' of docs/catalog/experience-catalog.json; a committed golden list makes any change of a shipped id a test failure. (2) Among launch experiences the manifest holds exactly 50 free (A01-A25, R02-G01..G25) and 50 premium (R03-G01..R04-G25); any other allocation fails validation. (3) Every experience has one launcher category (create, audio, play, learn, ambient, tools, puzzle) and its family as a tag; search over title, summary and tags is deterministic and locale-independent. (4) The loader rejects unknown schema versions, duplicate ids, missing fields, non-finite numbers and files over the size cap (Constitution IX) with typed errors. (5) The runtime manifest lists an experience as available only when its integration gate X-<code> is pass in the migration ledger; planned experiences are never shown as available. (6) A pure registry check proves a one-to-one match between manifest entries and registered factories; it is reused by the app tests. (7) Public API documented, API baseline updated, package tests added, ProjectM reference regression rerun.
OUT OF SCOPE: (1) Launcher UI. (2) StoreKit.
DEVICE-ONLY VERIFICATION (tasks tagged {device}, run only after ImplementationLock-100): none.
OWNER-ONLY ITEMS (tasks tagged {owner}, never performed by the agent): none.
BOUNDARIES: one app target (VisualCore) and one bundle identifier; experiences never depend on each other; the OpenGL ES to ANGLE to Metal path is the only renderer and is not forked; External/projectm-ios is read-only and ProjectM types stay out of the VisualCore public API and out of the app; public Apple APIs only; no advertising, analytics or tracking code and no network use; pure logic goes in Packages/VisualCore and GPU or UIKit code in Packages/VisualCoreRendering; every public symbol gets /// documentation and the API baseline is updated; no physical-device action before ImplementationLock-100; owner-only actions are recorded as BLOCKED_OWNER_ACTION and never performed.
Write prioritized user stories that can each be tested alone, acceptance scenarios, and edge cases for failure, cancellation, lifecycle interruption, memory pressure and corrupted or newer-version data where they apply. State requirements as observable behavior; name existing modules only where the brief names them.
Canonical override: feature directory specs/187-ua-f01-experience-catalog; requirement ids FR-U01-###, success criteria SC-U01-###, task ids T-U01-###.
```

#### UA-F01 `/speckit-clarify`

```text
/speckit-clarify Review the UA-F01 specification for unverified VisualCore or Apple APIs, lifecycle and thread-ownership assumptions, data-format and migration semantics, performance statements that need a device, and anything that contradicts ADR-0009 or the Auto-Creator.md sections named in the sources. Ask only questions whose answer changes the design, at most five.
Canonical override: feature directory specs/187-ua-f01-experience-catalog; requirement ids FR-U01-###, success criteria SC-U01-###, task ids T-U01-###. Answer every question yourself under the owner's standing delegation, recommended option first, and record each answer in spec.md under Clarifications.
```

#### UA-F01 `/speckit-plan`

```text
/speckit-plan Create the technical plan for UA-F01. Begin with a read-only audit of the existing sources named in the brief and record it in research.md; reference only APIs the audit verified. Give exact source paths, each marked existing, new, move or modify; module and dependency direction; public API; lifecycle and thread-ownership contracts; data schemas with versions and migrations; the tests of each layer (host, package tests on the iOS 27.x and iOS 26.5 simulators, app UI tests); build and test commands; rollback. Check the plan against every constitution principle. quickstart.md must contain these evidence commands: swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests; python3 scripts/build_catalog.py --check; python3 scripts/check_public_api.py; python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean. When VisualCore changes: python3 scripts/check_public_api.py --update, python3 scripts/check_documented_api.py, and the seven-step ProjectM reference regression in two chunks.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/187-ua-f01-experience-catalog; requirement ids FR-U01-###, success criteria SC-U01-###, task ids T-U01-###. The clarification decisions are binding.
```

#### UA-F01 `/speckit-checklist`

```text
/speckit-checklist Generate the requirements-quality checklist for UA-F01: completeness, clarity, consistency, measurability, lifecycle and failure coverage, privacy and no-advertising constraints, accessibility, the split between simulator-verifiable and device-only requirements, and traceability to the sources.
Canonical override: feature directory specs/187-ua-f01-experience-catalog; requirement ids FR-U01-###, success criteria SC-U01-###, task ids T-U01-###. Evaluate every item yourself under the owner's standing delegation, record the evaluation in the checklist, and correct the specification for every failed item before continuing.
```

#### UA-F01 `/speckit-tasks`

```text
/speckit-tasks Break UA-F01 into dependency-ordered tasks with exact files, tests written before the code they prove, an integration acceptance task per user story, commit boundaries and review checkpoints. Include one task for every evidence command of quickstart.md; the documentation, API-baseline and ProjectM-regression tasks when VisualCore changes; one task tagged {device} for every device-only item and one tagged {owner} for every owner-only item; and a final task that runs /speckit-converge until it appends nothing.
Canonical override: feature directory specs/187-ua-f01-experience-catalog; requirement ids FR-U01-###, success criteria SC-U01-###, task ids T-U01-###. Tasks start at T-U01-001. Evidence is recorded with python3 scripts/migration_ledger.py run-check --gate UA-F01 --name <check-name> -- <command>.
```

#### UA-F01 `/speckit-analyze`

```text
/speckit-analyze Validate the UA-F01 specification, plan and tasks: requirements without tasks, tasks without requirements, speculative dependencies, missing tests, ambiguous terms, and conflicts with the constitution or ADR-0009. Stop if a critical finding remains.
Canonical override: feature directory specs/187-ua-f01-experience-catalog; requirement ids FR-U01-###, success criteria SC-U01-###, task ids T-U01-###. Apply the fixes yourself under the owner's standing delegation, record them in the artifacts, and run the analysis again until no critical or high finding remains.
```

#### UA-F01 `/speckit-implement`

```text
/speckit-implement Implement UA-F01 task by task in small verified groups. Run the real builds and tests (host tests, package tests on the iOS 27.x and iOS 26.5 simulators, app tests where the feature has UI); a task is never ticked from reading code. Tasks tagged {device} or {owner} stay open, are listed in the final report and do not block the gate.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/187-ua-f01-experience-catalog; requirement ids FR-U01-###, success criteria SC-U01-###, task ids T-U01-###. Record each passing command with python3 scripts/migration_ledger.py run-check --gate UA-F01 --name <check-name> -- <command>.
```

#### UA-F01 `/speckit-converge`

```text
/speckit-converge Assess the code against the UA-F01 specification, plan and tasks and append every remaining gap as a task. Then run /speckit-implement for the appended tasks and /speckit-converge again; repeat until a run appends nothing and reports what it checked. Only then seal and record the gate: python3 scripts/migration_ledger.py seal --gate UA-F01 && python3 scripts/migration_ledger.py record --gate UA-F01.
Canonical override: feature directory specs/187-ua-f01-experience-catalog; requirement ids FR-U01-###, success criteria SC-U01-###, task ids T-U01-###. Appended tasks continue the T-U01-### sequence.
```

### UA-F02 ExperienceKit: the experience contract

| | |
|---|---|
| Spec directory | `specs/188-ua-f02-experience-sdk` |
| Ids | `FR-U02-###`, `SC-U02-###`, `T-U02-###` |
| Ledger gate | `UA-F02`; depends on `CONSTITUTION-2`, `UA-F01` |
| Read first | Auto-Creator.md sections 6 and 11.3; ADR-0009 D-05; Packages/VisualCoreRendering (RenderScene, RenderHost, RenderSurface); Packages/VisualCore (FixedStepRunner, PlaybackState, DocumentStore, MigrationChain, RenderLifecycle) |
| Absorbs | R02-F23 puzzle contract (the lifecycle and digest parts; solver certification stays in R02-F23) |

**Scope.** Define the contract every experience implements, adapting existing VisualCore surfaces instead of duplicating them: lifecycle (prepare(seed:), activate, suspend, resume, deactivate), fixed-step update, draw through RenderScene, normalized input with typed accept or reject, snapshot, restore, reset, diagnostics and automation hooks. Pure parts (state machine, snapshot envelope, digests, conformance helpers) go in VisualCoreExperience; the SwiftUI and RenderHost parts go in a new module VisualCoreExperienceHost in Packages/VisualCoreRendering.

**Acceptance.**

1. The lifecycle is a pure reducer (registered, preparing, ready, active, suspended, deactivating, inactive, failed) with exhaustive transition tests; illegal transitions are rejected and counted.
2. prepare(seed:) is deterministic: the same seed gives the same initial state digest; a reusable ExperienceConformance test helper checks this for any experience.
3. restore(snapshot()) reproduces the digest; reset() equals a fresh prepare with the same seed; snapshots are versioned envelopes with migrations.
4. Input is normalized into domain actions; a rejected action leaves the digest unchanged and returns a typed reason.
5. Update runs in fixed steps independent of frame rate; drawing reads immutable state; no GPU result decides an outcome.
6. Diagnostics expose state, seed, step index, quality tier, live GPU resource counts, last error and digest.
7. Automation hooks compile only under DEBUG or VISUALCORE_AUTOMATION.
8. A sample experience used only by tests exercises the whole contract on the host and on both simulator runtimes; public API documented and baselined.

**Evidence commands.**

- `swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests`
- `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --result-name ua-f02-ios27`
- `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-26.5 --action test --result-name ua-f02-ios26`

**Device-only, after ImplementationLock-100 (`{device}` tasks).** None.

**Owner-only (`{owner}` tasks).** None.

**Out of scope.** The session host; Any real experience.

#### UA-F02 `/speckit-specify`

```text
/speckit-specify Feature UA-F02: ExperienceKit: the experience contract.
SCOPE: Define the contract every experience implements, adapting existing VisualCore surfaces instead of duplicating them: lifecycle (prepare(seed:), activate, suspend, resume, deactivate), fixed-step update, draw through RenderScene, normalized input with typed accept or reject, snapshot, restore, reset, diagnostics and automation hooks. Pure parts (state machine, snapshot envelope, digests, conformance helpers) go in VisualCoreExperience; the SwiftUI and RenderHost parts go in a new module VisualCoreExperienceHost in Packages/VisualCoreRendering.
DEPENDS ON: UA-F01 (each must be pass in the migration ledger before this feature is implemented).
SOURCES TO READ FIRST: Auto-Creator.md sections 6 and 11.3; ADR-0009 D-05; Packages/VisualCoreRendering (RenderScene, RenderHost, RenderSurface); Packages/VisualCore (FixedStepRunner, PlaybackState, DocumentStore, MigrationChain, RenderLifecycle).
ABSORBED SOURCE REQUIREMENTS: R02-F23 puzzle contract (the lifecycle and digest parts; solver certification stays in R02-F23). Read each archived feature with python3 scripts/planning_index.py prompt --feature <ID> --stage specify, and list every unique requirement in the specification as adopted, adapted or superseded with the reason.
ACCEPTANCE (each item becomes at least one functional requirement and one measurable success criterion): (1) The lifecycle is a pure reducer (registered, preparing, ready, active, suspended, deactivating, inactive, failed) with exhaustive transition tests; illegal transitions are rejected and counted. (2) prepare(seed:) is deterministic: the same seed gives the same initial state digest; a reusable ExperienceConformance test helper checks this for any experience. (3) restore(snapshot()) reproduces the digest; reset() equals a fresh prepare with the same seed; snapshots are versioned envelopes with migrations. (4) Input is normalized into domain actions; a rejected action leaves the digest unchanged and returns a typed reason. (5) Update runs in fixed steps independent of frame rate; drawing reads immutable state; no GPU result decides an outcome. (6) Diagnostics expose state, seed, step index, quality tier, live GPU resource counts, last error and digest. (7) Automation hooks compile only under DEBUG or VISUALCORE_AUTOMATION. (8) A sample experience used only by tests exercises the whole contract on the host and on both simulator runtimes; public API documented and baselined.
OUT OF SCOPE: (1) The session host. (2) Any real experience.
DEVICE-ONLY VERIFICATION (tasks tagged {device}, run only after ImplementationLock-100): none.
OWNER-ONLY ITEMS (tasks tagged {owner}, never performed by the agent): none.
BOUNDARIES: one app target (VisualCore) and one bundle identifier; experiences never depend on each other; the OpenGL ES to ANGLE to Metal path is the only renderer and is not forked; External/projectm-ios is read-only and ProjectM types stay out of the VisualCore public API and out of the app; public Apple APIs only; no advertising, analytics or tracking code and no network use; pure logic goes in Packages/VisualCore and GPU or UIKit code in Packages/VisualCoreRendering; every public symbol gets /// documentation and the API baseline is updated; no physical-device action before ImplementationLock-100; owner-only actions are recorded as BLOCKED_OWNER_ACTION and never performed.
Write prioritized user stories that can each be tested alone, acceptance scenarios, and edge cases for failure, cancellation, lifecycle interruption, memory pressure and corrupted or newer-version data where they apply. State requirements as observable behavior; name existing modules only where the brief names them.
Canonical override: feature directory specs/188-ua-f02-experience-sdk; requirement ids FR-U02-###, success criteria SC-U02-###, task ids T-U02-###.
```

#### UA-F02 `/speckit-clarify`

```text
/speckit-clarify Review the UA-F02 specification for unverified VisualCore or Apple APIs, lifecycle and thread-ownership assumptions, data-format and migration semantics, performance statements that need a device, and anything that contradicts ADR-0009 or the Auto-Creator.md sections named in the sources. Ask only questions whose answer changes the design, at most five.
Canonical override: feature directory specs/188-ua-f02-experience-sdk; requirement ids FR-U02-###, success criteria SC-U02-###, task ids T-U02-###. Answer every question yourself under the owner's standing delegation, recommended option first, and record each answer in spec.md under Clarifications.
```

#### UA-F02 `/speckit-plan`

```text
/speckit-plan Create the technical plan for UA-F02. Begin with a read-only audit of the existing sources named in the brief and record it in research.md; reference only APIs the audit verified. Give exact source paths, each marked existing, new, move or modify; module and dependency direction; public API; lifecycle and thread-ownership contracts; data schemas with versions and migrations; the tests of each layer (host, package tests on the iOS 27.x and iOS 26.5 simulators, app UI tests); build and test commands; rollback. Check the plan against every constitution principle. quickstart.md must contain these evidence commands: swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests; python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --result-name ua-f02-ios27; python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-26.5 --action test --result-name ua-f02-ios26. When VisualCore changes: python3 scripts/check_public_api.py --update, python3 scripts/check_documented_api.py, and the seven-step ProjectM reference regression in two chunks.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/188-ua-f02-experience-sdk; requirement ids FR-U02-###, success criteria SC-U02-###, task ids T-U02-###. The clarification decisions are binding.
```

#### UA-F02 `/speckit-checklist`

```text
/speckit-checklist Generate the requirements-quality checklist for UA-F02: completeness, clarity, consistency, measurability, lifecycle and failure coverage, privacy and no-advertising constraints, accessibility, the split between simulator-verifiable and device-only requirements, and traceability to the sources.
Canonical override: feature directory specs/188-ua-f02-experience-sdk; requirement ids FR-U02-###, success criteria SC-U02-###, task ids T-U02-###. Evaluate every item yourself under the owner's standing delegation, record the evaluation in the checklist, and correct the specification for every failed item before continuing.
```

#### UA-F02 `/speckit-tasks`

```text
/speckit-tasks Break UA-F02 into dependency-ordered tasks with exact files, tests written before the code they prove, an integration acceptance task per user story, commit boundaries and review checkpoints. Include one task for every evidence command of quickstart.md; the documentation, API-baseline and ProjectM-regression tasks when VisualCore changes; one task tagged {device} for every device-only item and one tagged {owner} for every owner-only item; and a final task that runs /speckit-converge until it appends nothing.
Canonical override: feature directory specs/188-ua-f02-experience-sdk; requirement ids FR-U02-###, success criteria SC-U02-###, task ids T-U02-###. Tasks start at T-U02-001. Evidence is recorded with python3 scripts/migration_ledger.py run-check --gate UA-F02 --name <check-name> -- <command>.
```

#### UA-F02 `/speckit-analyze`

```text
/speckit-analyze Validate the UA-F02 specification, plan and tasks: requirements without tasks, tasks without requirements, speculative dependencies, missing tests, ambiguous terms, and conflicts with the constitution or ADR-0009. Stop if a critical finding remains.
Canonical override: feature directory specs/188-ua-f02-experience-sdk; requirement ids FR-U02-###, success criteria SC-U02-###, task ids T-U02-###. Apply the fixes yourself under the owner's standing delegation, record them in the artifacts, and run the analysis again until no critical or high finding remains.
```

#### UA-F02 `/speckit-implement`

```text
/speckit-implement Implement UA-F02 task by task in small verified groups. Run the real builds and tests (host tests, package tests on the iOS 27.x and iOS 26.5 simulators, app tests where the feature has UI); a task is never ticked from reading code. Tasks tagged {device} or {owner} stay open, are listed in the final report and do not block the gate.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/188-ua-f02-experience-sdk; requirement ids FR-U02-###, success criteria SC-U02-###, task ids T-U02-###. Record each passing command with python3 scripts/migration_ledger.py run-check --gate UA-F02 --name <check-name> -- <command>.
```

#### UA-F02 `/speckit-converge`

```text
/speckit-converge Assess the code against the UA-F02 specification, plan and tasks and append every remaining gap as a task. Then run /speckit-implement for the appended tasks and /speckit-converge again; repeat until a run appends nothing and reports what it checked. Only then seal and record the gate: python3 scripts/migration_ledger.py seal --gate UA-F02 && python3 scripts/migration_ledger.py record --gate UA-F02.
Canonical override: feature directory specs/188-ua-f02-experience-sdk; requirement ids FR-U02-###, success criteria SC-U02-###, task ids T-U02-###. Appended tasks continue the T-U02-### sequence.
```

### UA-F03 Experience host and session lifecycle

| | |
|---|---|
| Spec directory | `specs/189-ua-f03-experience-host` |
| Ids | `FR-U03-###`, `SC-U03-###`, `T-U03-###` |
| Ledger gate | `UA-F03`; depends on `CONSTITUTION-2`, `UA-F02` |
| Read first | Auto-Creator.md sections 11.4 to 11.6; ADR-0009 D-05; Packages/VisualCoreRendering (RenderHost, ResourceRegistry, ResourceBudget, FrameScheduler); Packages/VisualCore (ResourceLedger, QualityPolicy, DeviceConditions) |
| Absorbs | R02-F04 GPU resource ownership (session-level rules); R02-F25 shared shell (session part) |

**Scope.** Implement ExperienceSession and ExperienceHostView in VisualCoreExperienceHost: one active experience at a time, RenderHost creation through the session with a resource budget, activation and deactivation with proof of zero live GPU resources, failure isolation, cancellation, scene-phase handling, memory-pressure handling and context-loss recovery.

**Acceptance.**

1. Only one session is active; opening another deactivates the first before the new one prepares.
2. After deactivation the session's ResourceRegistry reports zero live resources and zero leaked; 50 open and close cycles of the sample experience keep these at zero on both simulator runtimes.
3. An error in prepare, setup or render shows a failure view with Retry and Back; the app stays usable and the failure is recorded in diagnostics.
4. Leaving during prepare cancels the work; no callback arrives after deactivation.
5. Background suspends (clock stopped, host paused) and foreground resumes without catching up; interruptions are honored.
6. A memory warning sheds caches; if the session is still over its budget it deactivates with a message.
7. A forced context recreation rebuilds GPU objects from CPU state and keeps the state digest.
8. Experience and app sources contain no direct GL or EGL calls (scripts/check_app_isolation.py extended to experience modules).

**Evidence commands.**

- `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --result-name ua-f03-ios27`
- `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-26.5 --action test --result-name ua-f03-ios26`
- `python3 scripts/check_app_isolation.py --app Apps/VisualCore`

**Device-only, after ImplementationLock-100 (`{device}` tasks).** Memory and thermal behavior of long sessions on D1, D2 and D3 (after ImplementationLock-100).

**Owner-only (`{owner}` tasks).** None.

**Out of scope.** Launcher and settings UI; Purchases.

#### UA-F03 `/speckit-specify`

```text
/speckit-specify Feature UA-F03: Experience host and session lifecycle.
SCOPE: Implement ExperienceSession and ExperienceHostView in VisualCoreExperienceHost: one active experience at a time, RenderHost creation through the session with a resource budget, activation and deactivation with proof of zero live GPU resources, failure isolation, cancellation, scene-phase handling, memory-pressure handling and context-loss recovery.
DEPENDS ON: UA-F02 (each must be pass in the migration ledger before this feature is implemented).
SOURCES TO READ FIRST: Auto-Creator.md sections 11.4 to 11.6; ADR-0009 D-05; Packages/VisualCoreRendering (RenderHost, ResourceRegistry, ResourceBudget, FrameScheduler); Packages/VisualCore (ResourceLedger, QualityPolicy, DeviceConditions).
ABSORBED SOURCE REQUIREMENTS: R02-F04 GPU resource ownership (session-level rules); R02-F25 shared shell (session part). Read each archived feature with python3 scripts/planning_index.py prompt --feature <ID> --stage specify, and list every unique requirement in the specification as adopted, adapted or superseded with the reason.
ACCEPTANCE (each item becomes at least one functional requirement and one measurable success criterion): (1) Only one session is active; opening another deactivates the first before the new one prepares. (2) After deactivation the session's ResourceRegistry reports zero live resources and zero leaked; 50 open and close cycles of the sample experience keep these at zero on both simulator runtimes. (3) An error in prepare, setup or render shows a failure view with Retry and Back; the app stays usable and the failure is recorded in diagnostics. (4) Leaving during prepare cancels the work; no callback arrives after deactivation. (5) Background suspends (clock stopped, host paused) and foreground resumes without catching up; interruptions are honored. (6) A memory warning sheds caches; if the session is still over its budget it deactivates with a message. (7) A forced context recreation rebuilds GPU objects from CPU state and keeps the state digest. (8) Experience and app sources contain no direct GL or EGL calls (scripts/check_app_isolation.py extended to experience modules).
OUT OF SCOPE: (1) Launcher and settings UI. (2) Purchases.
DEVICE-ONLY VERIFICATION (tasks tagged {device}, run only after ImplementationLock-100): (1) Memory and thermal behavior of long sessions on D1, D2 and D3 (after ImplementationLock-100).
OWNER-ONLY ITEMS (tasks tagged {owner}, never performed by the agent): none.
BOUNDARIES: one app target (VisualCore) and one bundle identifier; experiences never depend on each other; the OpenGL ES to ANGLE to Metal path is the only renderer and is not forked; External/projectm-ios is read-only and ProjectM types stay out of the VisualCore public API and out of the app; public Apple APIs only; no advertising, analytics or tracking code and no network use; pure logic goes in Packages/VisualCore and GPU or UIKit code in Packages/VisualCoreRendering; every public symbol gets /// documentation and the API baseline is updated; no physical-device action before ImplementationLock-100; owner-only actions are recorded as BLOCKED_OWNER_ACTION and never performed.
Write prioritized user stories that can each be tested alone, acceptance scenarios, and edge cases for failure, cancellation, lifecycle interruption, memory pressure and corrupted or newer-version data where they apply. State requirements as observable behavior; name existing modules only where the brief names them.
Canonical override: feature directory specs/189-ua-f03-experience-host; requirement ids FR-U03-###, success criteria SC-U03-###, task ids T-U03-###.
```

#### UA-F03 `/speckit-clarify`

```text
/speckit-clarify Review the UA-F03 specification for unverified VisualCore or Apple APIs, lifecycle and thread-ownership assumptions, data-format and migration semantics, performance statements that need a device, and anything that contradicts ADR-0009 or the Auto-Creator.md sections named in the sources. Ask only questions whose answer changes the design, at most five.
Canonical override: feature directory specs/189-ua-f03-experience-host; requirement ids FR-U03-###, success criteria SC-U03-###, task ids T-U03-###. Answer every question yourself under the owner's standing delegation, recommended option first, and record each answer in spec.md under Clarifications.
```

#### UA-F03 `/speckit-plan`

```text
/speckit-plan Create the technical plan for UA-F03. Begin with a read-only audit of the existing sources named in the brief and record it in research.md; reference only APIs the audit verified. Give exact source paths, each marked existing, new, move or modify; module and dependency direction; public API; lifecycle and thread-ownership contracts; data schemas with versions and migrations; the tests of each layer (host, package tests on the iOS 27.x and iOS 26.5 simulators, app UI tests); build and test commands; rollback. Check the plan against every constitution principle. quickstart.md must contain these evidence commands: python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --result-name ua-f03-ios27; python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-26.5 --action test --result-name ua-f03-ios26; python3 scripts/check_app_isolation.py --app Apps/VisualCore. When VisualCore changes: python3 scripts/check_public_api.py --update, python3 scripts/check_documented_api.py, and the seven-step ProjectM reference regression in two chunks.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/189-ua-f03-experience-host; requirement ids FR-U03-###, success criteria SC-U03-###, task ids T-U03-###. The clarification decisions are binding.
```

#### UA-F03 `/speckit-checklist`

```text
/speckit-checklist Generate the requirements-quality checklist for UA-F03: completeness, clarity, consistency, measurability, lifecycle and failure coverage, privacy and no-advertising constraints, accessibility, the split between simulator-verifiable and device-only requirements, and traceability to the sources.
Canonical override: feature directory specs/189-ua-f03-experience-host; requirement ids FR-U03-###, success criteria SC-U03-###, task ids T-U03-###. Evaluate every item yourself under the owner's standing delegation, record the evaluation in the checklist, and correct the specification for every failed item before continuing.
```

#### UA-F03 `/speckit-tasks`

```text
/speckit-tasks Break UA-F03 into dependency-ordered tasks with exact files, tests written before the code they prove, an integration acceptance task per user story, commit boundaries and review checkpoints. Include one task for every evidence command of quickstart.md; the documentation, API-baseline and ProjectM-regression tasks when VisualCore changes; one task tagged {device} for every device-only item and one tagged {owner} for every owner-only item; and a final task that runs /speckit-converge until it appends nothing.
Canonical override: feature directory specs/189-ua-f03-experience-host; requirement ids FR-U03-###, success criteria SC-U03-###, task ids T-U03-###. Tasks start at T-U03-001. Evidence is recorded with python3 scripts/migration_ledger.py run-check --gate UA-F03 --name <check-name> -- <command>.
```

#### UA-F03 `/speckit-analyze`

```text
/speckit-analyze Validate the UA-F03 specification, plan and tasks: requirements without tasks, tasks without requirements, speculative dependencies, missing tests, ambiguous terms, and conflicts with the constitution or ADR-0009. Stop if a critical finding remains.
Canonical override: feature directory specs/189-ua-f03-experience-host; requirement ids FR-U03-###, success criteria SC-U03-###, task ids T-U03-###. Apply the fixes yourself under the owner's standing delegation, record them in the artifacts, and run the analysis again until no critical or high finding remains.
```

#### UA-F03 `/speckit-implement`

```text
/speckit-implement Implement UA-F03 task by task in small verified groups. Run the real builds and tests (host tests, package tests on the iOS 27.x and iOS 26.5 simulators, app tests where the feature has UI); a task is never ticked from reading code. Tasks tagged {device} or {owner} stay open, are listed in the final report and do not block the gate.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/189-ua-f03-experience-host; requirement ids FR-U03-###, success criteria SC-U03-###, task ids T-U03-###. Record each passing command with python3 scripts/migration_ledger.py run-check --gate UA-F03 --name <check-name> -- <command>.
```

#### UA-F03 `/speckit-converge`

```text
/speckit-converge Assess the code against the UA-F03 specification, plan and tasks and append every remaining gap as a task. Then run /speckit-implement for the appended tasks and /speckit-converge again; repeat until a run appends nothing and reports what it checked. Only then seal and record the gate: python3 scripts/migration_ledger.py seal --gate UA-F03 && python3 scripts/migration_ledger.py record --gate UA-F03.
Canonical override: feature directory specs/189-ua-f03-experience-host; requirement ids FR-U03-###, success criteria SC-U03-###, task ids T-U03-###. Appended tasks continue the T-U03-### sequence.
```

### UA-F04 The VisualCore app shell: launcher, navigation, settings and onboarding

| | |
|---|---|
| Spec directory | `specs/190-ua-f04-app-shell` |
| Ids | `FR-U04-###`, `SC-U04-###`, `T-U04-###` |
| Ledger gate | `UA-F04`; depends on `CONSTITUTION-2`, `UA-F01`, `UA-F03` |
| Read first | Auto-Creator.md sections 11.1 and 11.7; ADR-0009 D-01; project.yml; Packages/VisualCoreRendering/Sources/VisualCoreUI |
| Absorbs | R02-F25 shared native shell; R02-F26 input and accessibility contract (shell-level parts) |

**Scope.** Create Apps/VisualCore/ (new) as the only shippable app target: SwiftUI launcher with categories and search, routes (catalog, experience, settings, about), free and premium labels, onboarding to a first working experience, settings (accessibility, quality, data reset, privacy text) and acknowledgements. Placeholder bundle id dev.visualcore.VisualCore; display name VisualCore.

**Acceptance.**

1. project.yml defines one application target VisualCore with unit and UI test targets; it builds unsigned for the generic iOS Simulator.
2. The launcher shows every available experience grouped by category, with search; each tile has a stable accessibility identifier vc.tile.<id> and a text label of its tier (not color alone).
3. Routes catalog, experience, settings and about work on iPhone and iPad layouts and through Dynamic Type XXXL without clipped controls.
4. First run reaches a running free experience with no account, purchase or permission prompt.
5. Settings offer Reduce Motion and Reduce Flashing choices (VisualCoreUI), a quality override, per-experience and global data reset, and the privacy statement.
6. The app makes no network request; the offline rule of scripts/check_compliance.py covers Apps/VisualCore.
7. UI tests and accessibility audits pass on iOS 27.x and 26.5 simulators with the enumeration guard; the DEBUG-only launch argument -openExperience <id> opens one experience for tests.

**Evidence commands.**

- `xcodegen generate --spec project.yml`
- `xcodebuild test -project VisualCore.xcodeproj -scheme VisualCore -destination "platform=iOS Simulator,id=<27.x udid>" -test-timeouts-enabled YES -default-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO`
- `python3 scripts/check_test_enumeration.py --sources Apps/VisualCore/Tests --log <log>`
- `python3 scripts/check_compliance.py`

**Device-only, after ImplementationLock-100 (`{device}` tasks).** Launcher layout and VoiceOver spot check on D1, D2, D3 (manual VoiceOver is non-gating).

**Owner-only (`{owner}` tasks).** Verify that the App Store name VisualCore is available and choose the final bundle identifier before distribution.

**Out of scope.** StoreKit and the paywall (UA-F08); Individual experiences.

#### UA-F04 `/speckit-specify`

```text
/speckit-specify Feature UA-F04: The VisualCore app shell: launcher, navigation, settings and onboarding.
SCOPE: Create Apps/VisualCore/ (new) as the only shippable app target: SwiftUI launcher with categories and search, routes (catalog, experience, settings, about), free and premium labels, onboarding to a first working experience, settings (accessibility, quality, data reset, privacy text) and acknowledgements. Placeholder bundle id dev.visualcore.VisualCore; display name VisualCore.
DEPENDS ON: UA-F01, UA-F03 (each must be pass in the migration ledger before this feature is implemented).
SOURCES TO READ FIRST: Auto-Creator.md sections 11.1 and 11.7; ADR-0009 D-01; project.yml; Packages/VisualCoreRendering/Sources/VisualCoreUI.
ABSORBED SOURCE REQUIREMENTS: R02-F25 shared native shell; R02-F26 input and accessibility contract (shell-level parts). Read each archived feature with python3 scripts/planning_index.py prompt --feature <ID> --stage specify, and list every unique requirement in the specification as adopted, adapted or superseded with the reason.
ACCEPTANCE (each item becomes at least one functional requirement and one measurable success criterion): (1) project.yml defines one application target VisualCore with unit and UI test targets; it builds unsigned for the generic iOS Simulator. (2) The launcher shows every available experience grouped by category, with search; each tile has a stable accessibility identifier vc.tile.<id> and a text label of its tier (not color alone). (3) Routes catalog, experience, settings and about work on iPhone and iPad layouts and through Dynamic Type XXXL without clipped controls. (4) First run reaches a running free experience with no account, purchase or permission prompt. (5) Settings offer Reduce Motion and Reduce Flashing choices (VisualCoreUI), a quality override, per-experience and global data reset, and the privacy statement. (6) The app makes no network request; the offline rule of scripts/check_compliance.py covers Apps/VisualCore. (7) UI tests and accessibility audits pass on iOS 27.x and 26.5 simulators with the enumeration guard; the DEBUG-only launch argument -openExperience <id> opens one experience for tests.
OUT OF SCOPE: (1) StoreKit and the paywall (UA-F08). (2) Individual experiences.
DEVICE-ONLY VERIFICATION (tasks tagged {device}, run only after ImplementationLock-100): (1) Launcher layout and VoiceOver spot check on D1, D2, D3 (manual VoiceOver is non-gating).
OWNER-ONLY ITEMS (tasks tagged {owner}, never performed by the agent): (1) Verify that the App Store name VisualCore is available and choose the final bundle identifier before distribution.
BOUNDARIES: one app target (VisualCore) and one bundle identifier; experiences never depend on each other; the OpenGL ES to ANGLE to Metal path is the only renderer and is not forked; External/projectm-ios is read-only and ProjectM types stay out of the VisualCore public API and out of the app; public Apple APIs only; no advertising, analytics or tracking code and no network use; pure logic goes in Packages/VisualCore and GPU or UIKit code in Packages/VisualCoreRendering; every public symbol gets /// documentation and the API baseline is updated; no physical-device action before ImplementationLock-100; owner-only actions are recorded as BLOCKED_OWNER_ACTION and never performed.
Write prioritized user stories that can each be tested alone, acceptance scenarios, and edge cases for failure, cancellation, lifecycle interruption, memory pressure and corrupted or newer-version data where they apply. State requirements as observable behavior; name existing modules only where the brief names them.
Canonical override: feature directory specs/190-ua-f04-app-shell; requirement ids FR-U04-###, success criteria SC-U04-###, task ids T-U04-###.
```

#### UA-F04 `/speckit-clarify`

```text
/speckit-clarify Review the UA-F04 specification for unverified VisualCore or Apple APIs, lifecycle and thread-ownership assumptions, data-format and migration semantics, performance statements that need a device, and anything that contradicts ADR-0009 or the Auto-Creator.md sections named in the sources. Ask only questions whose answer changes the design, at most five.
Canonical override: feature directory specs/190-ua-f04-app-shell; requirement ids FR-U04-###, success criteria SC-U04-###, task ids T-U04-###. Answer every question yourself under the owner's standing delegation, recommended option first, and record each answer in spec.md under Clarifications.
```

#### UA-F04 `/speckit-plan`

```text
/speckit-plan Create the technical plan for UA-F04. Begin with a read-only audit of the existing sources named in the brief and record it in research.md; reference only APIs the audit verified. Give exact source paths, each marked existing, new, move or modify; module and dependency direction; public API; lifecycle and thread-ownership contracts; data schemas with versions and migrations; the tests of each layer (host, package tests on the iOS 27.x and iOS 26.5 simulators, app UI tests); build and test commands; rollback. Check the plan against every constitution principle. quickstart.md must contain these evidence commands: xcodegen generate --spec project.yml; xcodebuild test -project VisualCore.xcodeproj -scheme VisualCore -destination "platform=iOS Simulator,id=<27.x udid>" -test-timeouts-enabled YES -default-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO; python3 scripts/check_test_enumeration.py --sources Apps/VisualCore/Tests --log <log>; python3 scripts/check_compliance.py. When VisualCore changes: python3 scripts/check_public_api.py --update, python3 scripts/check_documented_api.py, and the seven-step ProjectM reference regression in two chunks.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/190-ua-f04-app-shell; requirement ids FR-U04-###, success criteria SC-U04-###, task ids T-U04-###. The clarification decisions are binding.
```

#### UA-F04 `/speckit-checklist`

```text
/speckit-checklist Generate the requirements-quality checklist for UA-F04: completeness, clarity, consistency, measurability, lifecycle and failure coverage, privacy and no-advertising constraints, accessibility, the split between simulator-verifiable and device-only requirements, and traceability to the sources.
Canonical override: feature directory specs/190-ua-f04-app-shell; requirement ids FR-U04-###, success criteria SC-U04-###, task ids T-U04-###. Evaluate every item yourself under the owner's standing delegation, record the evaluation in the checklist, and correct the specification for every failed item before continuing.
```

#### UA-F04 `/speckit-tasks`

```text
/speckit-tasks Break UA-F04 into dependency-ordered tasks with exact files, tests written before the code they prove, an integration acceptance task per user story, commit boundaries and review checkpoints. Include one task for every evidence command of quickstart.md; the documentation, API-baseline and ProjectM-regression tasks when VisualCore changes; one task tagged {device} for every device-only item and one tagged {owner} for every owner-only item; and a final task that runs /speckit-converge until it appends nothing.
Canonical override: feature directory specs/190-ua-f04-app-shell; requirement ids FR-U04-###, success criteria SC-U04-###, task ids T-U04-###. Tasks start at T-U04-001. Evidence is recorded with python3 scripts/migration_ledger.py run-check --gate UA-F04 --name <check-name> -- <command>.
```

#### UA-F04 `/speckit-analyze`

```text
/speckit-analyze Validate the UA-F04 specification, plan and tasks: requirements without tasks, tasks without requirements, speculative dependencies, missing tests, ambiguous terms, and conflicts with the constitution or ADR-0009. Stop if a critical finding remains.
Canonical override: feature directory specs/190-ua-f04-app-shell; requirement ids FR-U04-###, success criteria SC-U04-###, task ids T-U04-###. Apply the fixes yourself under the owner's standing delegation, record them in the artifacts, and run the analysis again until no critical or high finding remains.
```

#### UA-F04 `/speckit-implement`

```text
/speckit-implement Implement UA-F04 task by task in small verified groups. Run the real builds and tests (host tests, package tests on the iOS 27.x and iOS 26.5 simulators, app tests where the feature has UI); a task is never ticked from reading code. Tasks tagged {device} or {owner} stay open, are listed in the final report and do not block the gate.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/190-ua-f04-app-shell; requirement ids FR-U04-###, success criteria SC-U04-###, task ids T-U04-###. Record each passing command with python3 scripts/migration_ledger.py run-check --gate UA-F04 --name <check-name> -- <command>.
```

#### UA-F04 `/speckit-converge`

```text
/speckit-converge Assess the code against the UA-F04 specification, plan and tasks and append every remaining gap as a task. Then run /speckit-implement for the appended tasks and /speckit-converge again; repeat until a run appends nothing and reports what it checked. Only then seal and record the gate: python3 scripts/migration_ledger.py seal --gate UA-F04 && python3 scripts/migration_ledger.py record --gate UA-F04.
Canonical override: feature directory specs/190-ua-f04-app-shell; requirement ids FR-U04-###, success criteria SC-U04-###, task ids T-U04-###. Appended tasks continue the T-U04-### sequence.
```

### UA-F05 Session state, per-experience persistence, reset and restore

| | |
|---|---|
| Spec directory | `specs/191-ua-f05-session-persistence` |
| Ids | `FR-U05-###`, `SC-U05-###`, `T-U05-###` |
| Ledger gate | `UA-F05`; depends on `CONSTITUTION-2`, `UA-F03`, `UA-F04` |
| Read first | Auto-Creator.md section 15.1; Packages/VisualCore/Sources/VisualCorePersistence (DocumentStore, NamedLibrary, MigrationChain) |
| Absorbs | R02-F28 profile migration and atomic save engine |

**Scope.** Give each experience an isolated storage namespace and the app a restorable session: storage root Application Support/Experiences/<id>/ and defaults prefix exp.<id>., autosave at suspend and safe points, restore after relaunch, per-experience and global reset, versioned migrations and a container inventory test.

**Acceptance.**

1. An experience can only reach its own storage through its context; a test proves two experiences cannot read each other's data.
2. The last route, last experience and catalog filter are restored after termination and relaunch.
3. Autosave is atomic; a truncated, corrupted or newer-version snapshot produces a recoverable message with Reset, keeps a quarantined copy, and never crashes.
4. Reset experience clears exactly that namespace; Reset all data clears every namespace and the session state.
5. Each experience with stored data has a migration test from every earlier schema version.
6. A container inventory test lists only allowed files and defaults keys (StoreKit and Metal cache files are allowed after their provenance is checked).

**Evidence commands.**

- `swift test --package-path Packages/VisualCore --filter 'VisualCoreExperienceTests|VisualCorePersistenceTests'`
- `xcodebuild test -project VisualCore.xcodeproj -scheme VisualCore -only-testing:VisualCoreUITests/PersistenceUITests -destination "platform=iOS Simulator,id=<udid>" CODE_SIGNING_ALLOWED=NO`

**Device-only, after ImplementationLock-100 (`{device}` tasks).** Container inventory on a real device after the campaign.

**Owner-only (`{owner}` tasks).** None.

**Out of scope.** iCloud or any sync.

#### UA-F05 `/speckit-specify`

```text
/speckit-specify Feature UA-F05: Session state, per-experience persistence, reset and restore.
SCOPE: Give each experience an isolated storage namespace and the app a restorable session: storage root Application Support/Experiences/<id>/ and defaults prefix exp.<id>., autosave at suspend and safe points, restore after relaunch, per-experience and global reset, versioned migrations and a container inventory test.
DEPENDS ON: UA-F03, UA-F04 (each must be pass in the migration ledger before this feature is implemented).
SOURCES TO READ FIRST: Auto-Creator.md section 15.1; Packages/VisualCore/Sources/VisualCorePersistence (DocumentStore, NamedLibrary, MigrationChain).
ABSORBED SOURCE REQUIREMENTS: R02-F28 profile migration and atomic save engine. Read each archived feature with python3 scripts/planning_index.py prompt --feature <ID> --stage specify, and list every unique requirement in the specification as adopted, adapted or superseded with the reason.
ACCEPTANCE (each item becomes at least one functional requirement and one measurable success criterion): (1) An experience can only reach its own storage through its context; a test proves two experiences cannot read each other's data. (2) The last route, last experience and catalog filter are restored after termination and relaunch. (3) Autosave is atomic; a truncated, corrupted or newer-version snapshot produces a recoverable message with Reset, keeps a quarantined copy, and never crashes. (4) Reset experience clears exactly that namespace; Reset all data clears every namespace and the session state. (5) Each experience with stored data has a migration test from every earlier schema version. (6) A container inventory test lists only allowed files and defaults keys (StoreKit and Metal cache files are allowed after their provenance is checked).
OUT OF SCOPE: (1) iCloud or any sync.
DEVICE-ONLY VERIFICATION (tasks tagged {device}, run only after ImplementationLock-100): (1) Container inventory on a real device after the campaign.
OWNER-ONLY ITEMS (tasks tagged {owner}, never performed by the agent): none.
BOUNDARIES: one app target (VisualCore) and one bundle identifier; experiences never depend on each other; the OpenGL ES to ANGLE to Metal path is the only renderer and is not forked; External/projectm-ios is read-only and ProjectM types stay out of the VisualCore public API and out of the app; public Apple APIs only; no advertising, analytics or tracking code and no network use; pure logic goes in Packages/VisualCore and GPU or UIKit code in Packages/VisualCoreRendering; every public symbol gets /// documentation and the API baseline is updated; no physical-device action before ImplementationLock-100; owner-only actions are recorded as BLOCKED_OWNER_ACTION and never performed.
Write prioritized user stories that can each be tested alone, acceptance scenarios, and edge cases for failure, cancellation, lifecycle interruption, memory pressure and corrupted or newer-version data where they apply. State requirements as observable behavior; name existing modules only where the brief names them.
Canonical override: feature directory specs/191-ua-f05-session-persistence; requirement ids FR-U05-###, success criteria SC-U05-###, task ids T-U05-###.
```

#### UA-F05 `/speckit-clarify`

```text
/speckit-clarify Review the UA-F05 specification for unverified VisualCore or Apple APIs, lifecycle and thread-ownership assumptions, data-format and migration semantics, performance statements that need a device, and anything that contradicts ADR-0009 or the Auto-Creator.md sections named in the sources. Ask only questions whose answer changes the design, at most five.
Canonical override: feature directory specs/191-ua-f05-session-persistence; requirement ids FR-U05-###, success criteria SC-U05-###, task ids T-U05-###. Answer every question yourself under the owner's standing delegation, recommended option first, and record each answer in spec.md under Clarifications.
```

#### UA-F05 `/speckit-plan`

```text
/speckit-plan Create the technical plan for UA-F05. Begin with a read-only audit of the existing sources named in the brief and record it in research.md; reference only APIs the audit verified. Give exact source paths, each marked existing, new, move or modify; module and dependency direction; public API; lifecycle and thread-ownership contracts; data schemas with versions and migrations; the tests of each layer (host, package tests on the iOS 27.x and iOS 26.5 simulators, app UI tests); build and test commands; rollback. Check the plan against every constitution principle. quickstart.md must contain these evidence commands: swift test --package-path Packages/VisualCore --filter 'VisualCoreExperienceTests|VisualCorePersistenceTests'; xcodebuild test -project VisualCore.xcodeproj -scheme VisualCore -only-testing:VisualCoreUITests/PersistenceUITests -destination "platform=iOS Simulator,id=<udid>" CODE_SIGNING_ALLOWED=NO. When VisualCore changes: python3 scripts/check_public_api.py --update, python3 scripts/check_documented_api.py, and the seven-step ProjectM reference regression in two chunks.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/191-ua-f05-session-persistence; requirement ids FR-U05-###, success criteria SC-U05-###, task ids T-U05-###. The clarification decisions are binding.
```

#### UA-F05 `/speckit-checklist`

```text
/speckit-checklist Generate the requirements-quality checklist for UA-F05: completeness, clarity, consistency, measurability, lifecycle and failure coverage, privacy and no-advertising constraints, accessibility, the split between simulator-verifiable and device-only requirements, and traceability to the sources.
Canonical override: feature directory specs/191-ua-f05-session-persistence; requirement ids FR-U05-###, success criteria SC-U05-###, task ids T-U05-###. Evaluate every item yourself under the owner's standing delegation, record the evaluation in the checklist, and correct the specification for every failed item before continuing.
```

#### UA-F05 `/speckit-tasks`

```text
/speckit-tasks Break UA-F05 into dependency-ordered tasks with exact files, tests written before the code they prove, an integration acceptance task per user story, commit boundaries and review checkpoints. Include one task for every evidence command of quickstart.md; the documentation, API-baseline and ProjectM-regression tasks when VisualCore changes; one task tagged {device} for every device-only item and one tagged {owner} for every owner-only item; and a final task that runs /speckit-converge until it appends nothing.
Canonical override: feature directory specs/191-ua-f05-session-persistence; requirement ids FR-U05-###, success criteria SC-U05-###, task ids T-U05-###. Tasks start at T-U05-001. Evidence is recorded with python3 scripts/migration_ledger.py run-check --gate UA-F05 --name <check-name> -- <command>.
```

#### UA-F05 `/speckit-analyze`

```text
/speckit-analyze Validate the UA-F05 specification, plan and tasks: requirements without tasks, tasks without requirements, speculative dependencies, missing tests, ambiguous terms, and conflicts with the constitution or ADR-0009. Stop if a critical finding remains.
Canonical override: feature directory specs/191-ua-f05-session-persistence; requirement ids FR-U05-###, success criteria SC-U05-###, task ids T-U05-###. Apply the fixes yourself under the owner's standing delegation, record them in the artifacts, and run the analysis again until no critical or high finding remains.
```

#### UA-F05 `/speckit-implement`

```text
/speckit-implement Implement UA-F05 task by task in small verified groups. Run the real builds and tests (host tests, package tests on the iOS 27.x and iOS 26.5 simulators, app tests where the feature has UI); a task is never ticked from reading code. Tasks tagged {device} or {owner} stay open, are listed in the final report and do not block the gate.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/191-ua-f05-session-persistence; requirement ids FR-U05-###, success criteria SC-U05-###, task ids T-U05-###. Record each passing command with python3 scripts/migration_ledger.py run-check --gate UA-F05 --name <check-name> -- <command>.
```

#### UA-F05 `/speckit-converge`

```text
/speckit-converge Assess the code against the UA-F05 specification, plan and tasks and append every remaining gap as a task. Then run /speckit-implement for the appended tasks and /speckit-converge again; repeat until a run appends nothing and reports what it checked. Only then seal and record the gate: python3 scripts/migration_ledger.py seal --gate UA-F05 && python3 scripts/migration_ledger.py record --gate UA-F05.
Canonical override: feature directory specs/191-ua-f05-session-persistence; requirement ids FR-U05-###, success criteria SC-U05-###, task ids T-U05-###. Appended tasks continue the T-U05-### sequence.
```

### UA-F06 Quality profiles and performance observability

| | |
|---|---|
| Spec directory | `specs/192-ua-f06-quality-performance` |
| Ids | `FR-U06-###`, `SC-U06-###`, `T-U06-###` |
| Ledger gate | `UA-F06`; depends on `CONSTITUTION-2`, `UA-F03` |
| Read first | Auto-Creator.md section 12; Packages/VisualCore/Sources/VisualCoreDiagnostics (QualityPolicy, DeviceConditions, FramePacing, ParticleBudget, RenderCostEstimate); docs/performance/README.md |
| Absorbs | R02-F32 frame pacing and D3 thermal adaptation; R03-F09 and R04-F09 benchmark preparation |

**Scope.** Define QualityProfile (tiers mapped to concrete budgets) per experience on top of QualityPolicy and DeviceConditions, a settings override, and metrics for launch, first frame (prepare, shader compilation and first present measured separately), frame pacing, memory and GPU ledger bytes, written into the evidence records.

**Acceptance.**

1. Every experience declares tiers; a tier change never changes the domain state digest.
2. Tiers step down under serious thermal state or Low Power Mode and recover after the calm period (existing QualityPolicy semantics).
3. Evidence records contain launch time, prepare time, shader compile time, first-present time, frame pacing counts, memory footprint, GPU bytes and thermal state.
4. Budgets are written as proposals in docs/performance with the device measurement that will confirm them; simulator numbers are never presented as performance results.
5. Shaders are compiled during prepare, not on the first interactive frame.
6. A 10-minute scenario shows no unbounded growth of memory or GPU bytes on the simulator.

**Evidence commands.**

- `swift test --package-path Packages/VisualCore --filter VisualCoreDiagnosticsTests`
- `python3 scripts/verify_experiences.py --only <sample id> --scenario endurance --runtime 27`

**Device-only, after ImplementationLock-100 (`{device}` tasks).** Frame pacing, memory, thermal and shader-compile measurements on D1, D2, D3 with at least 200 samples for percentage criteria.

**Owner-only (`{owner}` tasks).** None.

**Out of scope.** Tuning individual experiences.

#### UA-F06 `/speckit-specify`

```text
/speckit-specify Feature UA-F06: Quality profiles and performance observability.
SCOPE: Define QualityProfile (tiers mapped to concrete budgets) per experience on top of QualityPolicy and DeviceConditions, a settings override, and metrics for launch, first frame (prepare, shader compilation and first present measured separately), frame pacing, memory and GPU ledger bytes, written into the evidence records.
DEPENDS ON: UA-F03 (each must be pass in the migration ledger before this feature is implemented).
SOURCES TO READ FIRST: Auto-Creator.md section 12; Packages/VisualCore/Sources/VisualCoreDiagnostics (QualityPolicy, DeviceConditions, FramePacing, ParticleBudget, RenderCostEstimate); docs/performance/README.md.
ABSORBED SOURCE REQUIREMENTS: R02-F32 frame pacing and D3 thermal adaptation; R03-F09 and R04-F09 benchmark preparation. Read each archived feature with python3 scripts/planning_index.py prompt --feature <ID> --stage specify, and list every unique requirement in the specification as adopted, adapted or superseded with the reason.
ACCEPTANCE (each item becomes at least one functional requirement and one measurable success criterion): (1) Every experience declares tiers; a tier change never changes the domain state digest. (2) Tiers step down under serious thermal state or Low Power Mode and recover after the calm period (existing QualityPolicy semantics). (3) Evidence records contain launch time, prepare time, shader compile time, first-present time, frame pacing counts, memory footprint, GPU bytes and thermal state. (4) Budgets are written as proposals in docs/performance with the device measurement that will confirm them; simulator numbers are never presented as performance results. (5) Shaders are compiled during prepare, not on the first interactive frame. (6) A 10-minute scenario shows no unbounded growth of memory or GPU bytes on the simulator.
OUT OF SCOPE: (1) Tuning individual experiences.
DEVICE-ONLY VERIFICATION (tasks tagged {device}, run only after ImplementationLock-100): (1) Frame pacing, memory, thermal and shader-compile measurements on D1, D2, D3 with at least 200 samples for percentage criteria.
OWNER-ONLY ITEMS (tasks tagged {owner}, never performed by the agent): none.
BOUNDARIES: one app target (VisualCore) and one bundle identifier; experiences never depend on each other; the OpenGL ES to ANGLE to Metal path is the only renderer and is not forked; External/projectm-ios is read-only and ProjectM types stay out of the VisualCore public API and out of the app; public Apple APIs only; no advertising, analytics or tracking code and no network use; pure logic goes in Packages/VisualCore and GPU or UIKit code in Packages/VisualCoreRendering; every public symbol gets /// documentation and the API baseline is updated; no physical-device action before ImplementationLock-100; owner-only actions are recorded as BLOCKED_OWNER_ACTION and never performed.
Write prioritized user stories that can each be tested alone, acceptance scenarios, and edge cases for failure, cancellation, lifecycle interruption, memory pressure and corrupted or newer-version data where they apply. State requirements as observable behavior; name existing modules only where the brief names them.
Canonical override: feature directory specs/192-ua-f06-quality-performance; requirement ids FR-U06-###, success criteria SC-U06-###, task ids T-U06-###.
```

#### UA-F06 `/speckit-clarify`

```text
/speckit-clarify Review the UA-F06 specification for unverified VisualCore or Apple APIs, lifecycle and thread-ownership assumptions, data-format and migration semantics, performance statements that need a device, and anything that contradicts ADR-0009 or the Auto-Creator.md sections named in the sources. Ask only questions whose answer changes the design, at most five.
Canonical override: feature directory specs/192-ua-f06-quality-performance; requirement ids FR-U06-###, success criteria SC-U06-###, task ids T-U06-###. Answer every question yourself under the owner's standing delegation, recommended option first, and record each answer in spec.md under Clarifications.
```

#### UA-F06 `/speckit-plan`

```text
/speckit-plan Create the technical plan for UA-F06. Begin with a read-only audit of the existing sources named in the brief and record it in research.md; reference only APIs the audit verified. Give exact source paths, each marked existing, new, move or modify; module and dependency direction; public API; lifecycle and thread-ownership contracts; data schemas with versions and migrations; the tests of each layer (host, package tests on the iOS 27.x and iOS 26.5 simulators, app UI tests); build and test commands; rollback. Check the plan against every constitution principle. quickstart.md must contain these evidence commands: swift test --package-path Packages/VisualCore --filter VisualCoreDiagnosticsTests; python3 scripts/verify_experiences.py --only <sample id> --scenario endurance --runtime 27. When VisualCore changes: python3 scripts/check_public_api.py --update, python3 scripts/check_documented_api.py, and the seven-step ProjectM reference regression in two chunks.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/192-ua-f06-quality-performance; requirement ids FR-U06-###, success criteria SC-U06-###, task ids T-U06-###. The clarification decisions are binding.
```

#### UA-F06 `/speckit-checklist`

```text
/speckit-checklist Generate the requirements-quality checklist for UA-F06: completeness, clarity, consistency, measurability, lifecycle and failure coverage, privacy and no-advertising constraints, accessibility, the split between simulator-verifiable and device-only requirements, and traceability to the sources.
Canonical override: feature directory specs/192-ua-f06-quality-performance; requirement ids FR-U06-###, success criteria SC-U06-###, task ids T-U06-###. Evaluate every item yourself under the owner's standing delegation, record the evaluation in the checklist, and correct the specification for every failed item before continuing.
```

#### UA-F06 `/speckit-tasks`

```text
/speckit-tasks Break UA-F06 into dependency-ordered tasks with exact files, tests written before the code they prove, an integration acceptance task per user story, commit boundaries and review checkpoints. Include one task for every evidence command of quickstart.md; the documentation, API-baseline and ProjectM-regression tasks when VisualCore changes; one task tagged {device} for every device-only item and one tagged {owner} for every owner-only item; and a final task that runs /speckit-converge until it appends nothing.
Canonical override: feature directory specs/192-ua-f06-quality-performance; requirement ids FR-U06-###, success criteria SC-U06-###, task ids T-U06-###. Tasks start at T-U06-001. Evidence is recorded with python3 scripts/migration_ledger.py run-check --gate UA-F06 --name <check-name> -- <command>.
```

#### UA-F06 `/speckit-analyze`

```text
/speckit-analyze Validate the UA-F06 specification, plan and tasks: requirements without tasks, tasks without requirements, speculative dependencies, missing tests, ambiguous terms, and conflicts with the constitution or ADR-0009. Stop if a critical finding remains.
Canonical override: feature directory specs/192-ua-f06-quality-performance; requirement ids FR-U06-###, success criteria SC-U06-###, task ids T-U06-###. Apply the fixes yourself under the owner's standing delegation, record them in the artifacts, and run the analysis again until no critical or high finding remains.
```

#### UA-F06 `/speckit-implement`

```text
/speckit-implement Implement UA-F06 task by task in small verified groups. Run the real builds and tests (host tests, package tests on the iOS 27.x and iOS 26.5 simulators, app tests where the feature has UI); a task is never ticked from reading code. Tasks tagged {device} or {owner} stay open, are listed in the final report and do not block the gate.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/192-ua-f06-quality-performance; requirement ids FR-U06-###, success criteria SC-U06-###, task ids T-U06-###. Record each passing command with python3 scripts/migration_ledger.py run-check --gate UA-F06 --name <check-name> -- <command>.
```

#### UA-F06 `/speckit-converge`

```text
/speckit-converge Assess the code against the UA-F06 specification, plan and tasks and append every remaining gap as a task. Then run /speckit-implement for the appended tasks and /speckit-converge again; repeat until a run appends nothing and reports what it checked. Only then seal and record the gate: python3 scripts/migration_ledger.py seal --gate UA-F06 && python3 scripts/migration_ledger.py record --gate UA-F06.
Canonical override: feature directory specs/192-ua-f06-quality-performance; requirement ids FR-U06-###, success criteria SC-U06-###, task ids T-U06-###. Appended tasks continue the T-U06-### sequence.
```

### UA-F07 Adoption of the existing apps A01 to A04 as experiences

| | |
|---|---|
| Spec directory | `specs/193-ua-f07-legacy-adoption` |
| Ids | `FR-U07-###`, `SC-U07-###`, `T-U07-###` |
| Ledger gate | `UA-F07`; depends on `CONSTITUTION-2`, `UA-F02`, `UA-F03`, `UA-F04`, `UA-F05` |
| Read first | Auto-Creator.md section 17; docs/migration/migration-plan.md; Apps/GenerativeArtStudio, Apps/FluidArtPlayground, Apps/FractalExplorer, Apps/ParticleUniverse; specs/011 to specs/035 |
| Absorbs | — |

**Scope.** Expose Generative Art Studio, Fluid Art Playground, Fractal Explorer and the implemented phases of Particle Universe as experiences of the unified app through thin adapters, without changing domain behavior; port their UI tests; move their sources along the path map with git mv after parity is proven; retire each standalone target only then.

**Acceptance.**

1. The four Core packages pass their existing host tests unchanged; committed fixtures and checksums stay bit-identical (A01 replay and baselines, A02 and A03 fixtures, A04 replay-v1.json).
2. Each adopted experience passes the ExperienceConformance helper and the session host tests.
3. Every UI test of the standalone apps has a counterpart in the unified app; a mapping table lists old and new test names and the enumeration guard proves none was lost.
4. Sources move with git mv to the paths of docs/migration/migration-plan.md only after the two items above pass; Catalog/path-map.json records each move.
5. A standalone target is removed from project.yml only after its experience is verified in the unified app on both simulator runtimes.
6. The legacy ledger is unchanged; X-A01, X-A02 and X-A03 are recorded in the migration ledger; X-A04 stays pending until A04-P04..P06 are sealed.
7. ProjectM reference regression 7 of 7 and reference-clean after any VisualCore change; docs/apps release dossiers stay as history with a note that store listings are superseded.

**Evidence commands.**

- `swift test --package-path <each Core package>`
- `python3 scripts/verify_experiences.py --only a01.generative-art-studio a02.fluid-art-playground a03.fractal-explorer --runtime 27 26`
- `python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`

**Device-only, after ImplementationLock-100 (`{device}` tasks).** None.

**Owner-only (`{owner}` tasks).** None.

**Out of scope.** New features for these apps; A04-P04..P06 (run from the archived prompts).

#### UA-F07 `/speckit-specify`

```text
/speckit-specify Feature UA-F07: Adoption of the existing apps A01 to A04 as experiences.
SCOPE: Expose Generative Art Studio, Fluid Art Playground, Fractal Explorer and the implemented phases of Particle Universe as experiences of the unified app through thin adapters, without changing domain behavior; port their UI tests; move their sources along the path map with git mv after parity is proven; retire each standalone target only then.
DEPENDS ON: UA-F02, UA-F03, UA-F04, UA-F05 (each must be pass in the migration ledger before this feature is implemented).
SOURCES TO READ FIRST: Auto-Creator.md section 17; docs/migration/migration-plan.md; Apps/GenerativeArtStudio, Apps/FluidArtPlayground, Apps/FractalExplorer, Apps/ParticleUniverse; specs/011 to specs/035.
ACCEPTANCE (each item becomes at least one functional requirement and one measurable success criterion): (1) The four Core packages pass their existing host tests unchanged; committed fixtures and checksums stay bit-identical (A01 replay and baselines, A02 and A03 fixtures, A04 replay-v1.json). (2) Each adopted experience passes the ExperienceConformance helper and the session host tests. (3) Every UI test of the standalone apps has a counterpart in the unified app; a mapping table lists old and new test names and the enumeration guard proves none was lost. (4) Sources move with git mv to the paths of docs/migration/migration-plan.md only after the two items above pass; Catalog/path-map.json records each move. (5) A standalone target is removed from project.yml only after its experience is verified in the unified app on both simulator runtimes. (6) The legacy ledger is unchanged; X-A01, X-A02 and X-A03 are recorded in the migration ledger; X-A04 stays pending until A04-P04..P06 are sealed. (7) ProjectM reference regression 7 of 7 and reference-clean after any VisualCore change; docs/apps release dossiers stay as history with a note that store listings are superseded.
OUT OF SCOPE: (1) New features for these apps. (2) A04-P04..P06 (run from the archived prompts).
DEVICE-ONLY VERIFICATION (tasks tagged {device}, run only after ImplementationLock-100): none.
OWNER-ONLY ITEMS (tasks tagged {owner}, never performed by the agent): none.
BOUNDARIES: one app target (VisualCore) and one bundle identifier; experiences never depend on each other; the OpenGL ES to ANGLE to Metal path is the only renderer and is not forked; External/projectm-ios is read-only and ProjectM types stay out of the VisualCore public API and out of the app; public Apple APIs only; no advertising, analytics or tracking code and no network use; pure logic goes in Packages/VisualCore and GPU or UIKit code in Packages/VisualCoreRendering; every public symbol gets /// documentation and the API baseline is updated; no physical-device action before ImplementationLock-100; owner-only actions are recorded as BLOCKED_OWNER_ACTION and never performed.
Write prioritized user stories that can each be tested alone, acceptance scenarios, and edge cases for failure, cancellation, lifecycle interruption, memory pressure and corrupted or newer-version data where they apply. State requirements as observable behavior; name existing modules only where the brief names them.
Canonical override: feature directory specs/193-ua-f07-legacy-adoption; requirement ids FR-U07-###, success criteria SC-U07-###, task ids T-U07-###.
```

#### UA-F07 `/speckit-clarify`

```text
/speckit-clarify Review the UA-F07 specification for unverified VisualCore or Apple APIs, lifecycle and thread-ownership assumptions, data-format and migration semantics, performance statements that need a device, and anything that contradicts ADR-0009 or the Auto-Creator.md sections named in the sources. Ask only questions whose answer changes the design, at most five.
Canonical override: feature directory specs/193-ua-f07-legacy-adoption; requirement ids FR-U07-###, success criteria SC-U07-###, task ids T-U07-###. Answer every question yourself under the owner's standing delegation, recommended option first, and record each answer in spec.md under Clarifications.
```

#### UA-F07 `/speckit-plan`

```text
/speckit-plan Create the technical plan for UA-F07. Begin with a read-only audit of the existing sources named in the brief and record it in research.md; reference only APIs the audit verified. Give exact source paths, each marked existing, new, move or modify; module and dependency direction; public API; lifecycle and thread-ownership contracts; data schemas with versions and migrations; the tests of each layer (host, package tests on the iOS 27.x and iOS 26.5 simulators, app UI tests); build and test commands; rollback. Check the plan against every constitution principle. quickstart.md must contain these evidence commands: swift test --package-path <each Core package>; python3 scripts/verify_experiences.py --only a01.generative-art-studio a02.fluid-art-playground a03.fractal-explorer --runtime 27 26; python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26. When VisualCore changes: python3 scripts/check_public_api.py --update, python3 scripts/check_documented_api.py, and the seven-step ProjectM reference regression in two chunks.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/193-ua-f07-legacy-adoption; requirement ids FR-U07-###, success criteria SC-U07-###, task ids T-U07-###. The clarification decisions are binding.
```

#### UA-F07 `/speckit-checklist`

```text
/speckit-checklist Generate the requirements-quality checklist for UA-F07: completeness, clarity, consistency, measurability, lifecycle and failure coverage, privacy and no-advertising constraints, accessibility, the split between simulator-verifiable and device-only requirements, and traceability to the sources.
Canonical override: feature directory specs/193-ua-f07-legacy-adoption; requirement ids FR-U07-###, success criteria SC-U07-###, task ids T-U07-###. Evaluate every item yourself under the owner's standing delegation, record the evaluation in the checklist, and correct the specification for every failed item before continuing.
```

#### UA-F07 `/speckit-tasks`

```text
/speckit-tasks Break UA-F07 into dependency-ordered tasks with exact files, tests written before the code they prove, an integration acceptance task per user story, commit boundaries and review checkpoints. Include one task for every evidence command of quickstart.md; the documentation, API-baseline and ProjectM-regression tasks when VisualCore changes; one task tagged {device} for every device-only item and one tagged {owner} for every owner-only item; and a final task that runs /speckit-converge until it appends nothing.
Canonical override: feature directory specs/193-ua-f07-legacy-adoption; requirement ids FR-U07-###, success criteria SC-U07-###, task ids T-U07-###. Tasks start at T-U07-001. Evidence is recorded with python3 scripts/migration_ledger.py run-check --gate UA-F07 --name <check-name> -- <command>.
```

#### UA-F07 `/speckit-analyze`

```text
/speckit-analyze Validate the UA-F07 specification, plan and tasks: requirements without tasks, tasks without requirements, speculative dependencies, missing tests, ambiguous terms, and conflicts with the constitution or ADR-0009. Stop if a critical finding remains.
Canonical override: feature directory specs/193-ua-f07-legacy-adoption; requirement ids FR-U07-###, success criteria SC-U07-###, task ids T-U07-###. Apply the fixes yourself under the owner's standing delegation, record them in the artifacts, and run the analysis again until no critical or high finding remains.
```

#### UA-F07 `/speckit-implement`

```text
/speckit-implement Implement UA-F07 task by task in small verified groups. Run the real builds and tests (host tests, package tests on the iOS 27.x and iOS 26.5 simulators, app tests where the feature has UI); a task is never ticked from reading code. Tasks tagged {device} or {owner} stay open, are listed in the final report and do not block the gate.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/193-ua-f07-legacy-adoption; requirement ids FR-U07-###, success criteria SC-U07-###, task ids T-U07-###. Record each passing command with python3 scripts/migration_ledger.py run-check --gate UA-F07 --name <check-name> -- <command>.
```

#### UA-F07 `/speckit-converge`

```text
/speckit-converge Assess the code against the UA-F07 specification, plan and tasks and append every remaining gap as a task. Then run /speckit-implement for the appended tasks and /speckit-converge again; repeat until a run appends nothing and reports what it checked. Only then seal and record the gate: python3 scripts/migration_ledger.py seal --gate UA-F07 && python3 scripts/migration_ledger.py record --gate UA-F07.
Canonical override: feature directory specs/193-ua-f07-legacy-adoption; requirement ids FR-U07-###, success criteria SC-U07-###, task ids T-U07-###. Appended tasks continue the T-U07-### sequence.
```

### UA-F08 Premium entitlement and the single StoreKit 2 purchase

| | |
|---|---|
| Spec directory | `specs/194-ua-f08-entitlement-store` |
| Ids | `FR-U08-###`, `SC-U08-###`, `T-U08-###` |
| Ledger gate | `UA-F08`; depends on `CONSTITUTION-2`, `UA-F01`, `UA-F03`, `UA-F04`, `LOCK-FREE-50` |
| Read first | Auto-Creator.md section 14; ADR-0009 D-03, D-04; docs/archive/planning/playbook (StoreKit lessons); scripts/check_release_symbols.py |
| Absorbs | R02-F27 premium entitlement and zero-ads compliance (the entitlement part; 'no StoreKit' is superseded) |

**Scope.** Add the module VisualCoreStore (new, Packages/VisualCoreRendering) with a PurchaseController on StoreKit 2 behind a StoreClient protocol (live and fake), the EntitlementState policy in VisualCoreExperience, gating at routing and at session activation, the paywall and restore UI in the app shell, a local .storekit configuration with exactly one non-consumable product, and the DEBUG-only entitlement fixture.

**Acceptance.**

1. Exactly one product exists: non-consumable, placeholder id dev.visualcore.VisualCore.premium, USD 1.99 in the local .storekit file; a test fails if another product, a subscription or a consumable is added.
2. Entitlement comes only from verified Transaction.currentEntitlements and Transaction.updates; no unlock flag is stored anywhere (source scan and container inventory).
3. A premium experience is refused both by routing and by session activation without entitlement; free experiences never query the store and work when StoreKit is unavailable.
4. Purchase, pending (Ask to Buy), cancel, failure, restore, refund or revocation and family-shared ownership each have a tested state and accessible UI.
5. A previously verified entitlement works offline; a device that never purchased shows an honest locked state offline.
6. Tests use SKTestSession with cleared transactions and no synced application id, a fake store in the unit-test host, and the fixture -uitestEntitlement free|premium|revoked in UI tests.
7. The Release binary contains no fixture symbol or string and links no advertising, analytics or tracking framework (scripts/check_release_symbols.py extended).
8. Paywall copy states a one-time purchase that unlocks current and future premium experiences; no timers, nagging or external purchase paths.

**Evidence commands.**

- `swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests`
- `xcodebuild test -project VisualCore.xcodeproj -scheme VisualCore -only-testing:VisualCoreTests/StoreTests -destination "platform=iOS Simulator,id=<udid>" CODE_SIGNING_ALLOWED=NO`
- `python3 scripts/check_release_symbols.py --app <Release app>`

**Device-only, after ImplementationLock-100 (`{device}` tasks).** Purchase sheet, Ask to Buy and restore on a real device with a sandbox account.

**Owner-only (`{owner}` tasks).** Create the non-consumable in App Store Connect, accept the Paid Apps agreement, set the price, decide Family Sharing, provide a sandbox tester.

**Out of scope.** Any second product; Server-side validation; Accounts.

#### UA-F08 `/speckit-specify`

```text
/speckit-specify Feature UA-F08: Premium entitlement and the single StoreKit 2 purchase.
SCOPE: Add the module VisualCoreStore (new, Packages/VisualCoreRendering) with a PurchaseController on StoreKit 2 behind a StoreClient protocol (live and fake), the EntitlementState policy in VisualCoreExperience, gating at routing and at session activation, the paywall and restore UI in the app shell, a local .storekit configuration with exactly one non-consumable product, and the DEBUG-only entitlement fixture.
DEPENDS ON: UA-F01, UA-F03, UA-F04 (each must be pass in the migration ledger before this feature is implemented).
SOURCES TO READ FIRST: Auto-Creator.md section 14; ADR-0009 D-03, D-04; docs/archive/planning/playbook (StoreKit lessons); scripts/check_release_symbols.py.
ABSORBED SOURCE REQUIREMENTS: R02-F27 premium entitlement and zero-ads compliance (the entitlement part; 'no StoreKit' is superseded). Read each archived feature with python3 scripts/planning_index.py prompt --feature <ID> --stage specify, and list every unique requirement in the specification as adopted, adapted or superseded with the reason.
ACCEPTANCE (each item becomes at least one functional requirement and one measurable success criterion): (1) Exactly one product exists: non-consumable, placeholder id dev.visualcore.VisualCore.premium, USD 1.99 in the local .storekit file; a test fails if another product, a subscription or a consumable is added. (2) Entitlement comes only from verified Transaction.currentEntitlements and Transaction.updates; no unlock flag is stored anywhere (source scan and container inventory). (3) A premium experience is refused both by routing and by session activation without entitlement; free experiences never query the store and work when StoreKit is unavailable. (4) Purchase, pending (Ask to Buy), cancel, failure, restore, refund or revocation and family-shared ownership each have a tested state and accessible UI. (5) A previously verified entitlement works offline; a device that never purchased shows an honest locked state offline. (6) Tests use SKTestSession with cleared transactions and no synced application id, a fake store in the unit-test host, and the fixture -uitestEntitlement free|premium|revoked in UI tests. (7) The Release binary contains no fixture symbol or string and links no advertising, analytics or tracking framework (scripts/check_release_symbols.py extended). (8) Paywall copy states a one-time purchase that unlocks current and future premium experiences; no timers, nagging or external purchase paths.
OUT OF SCOPE: (1) Any second product. (2) Server-side validation. (3) Accounts.
DEVICE-ONLY VERIFICATION (tasks tagged {device}, run only after ImplementationLock-100): (1) Purchase sheet, Ask to Buy and restore on a real device with a sandbox account.
OWNER-ONLY ITEMS (tasks tagged {owner}, never performed by the agent): (1) Create the non-consumable in App Store Connect, accept the Paid Apps agreement, set the price, decide Family Sharing, provide a sandbox tester.
BOUNDARIES: one app target (VisualCore) and one bundle identifier; experiences never depend on each other; the OpenGL ES to ANGLE to Metal path is the only renderer and is not forked; External/projectm-ios is read-only and ProjectM types stay out of the VisualCore public API and out of the app; public Apple APIs only; no advertising, analytics or tracking code and no network use; pure logic goes in Packages/VisualCore and GPU or UIKit code in Packages/VisualCoreRendering; every public symbol gets /// documentation and the API baseline is updated; no physical-device action before ImplementationLock-100; owner-only actions are recorded as BLOCKED_OWNER_ACTION and never performed.
Write prioritized user stories that can each be tested alone, acceptance scenarios, and edge cases for failure, cancellation, lifecycle interruption, memory pressure and corrupted or newer-version data where they apply. State requirements as observable behavior; name existing modules only where the brief names them.
Canonical override: feature directory specs/194-ua-f08-entitlement-store; requirement ids FR-U08-###, success criteria SC-U08-###, task ids T-U08-###.
```

#### UA-F08 `/speckit-clarify`

```text
/speckit-clarify Review the UA-F08 specification for unverified VisualCore or Apple APIs, lifecycle and thread-ownership assumptions, data-format and migration semantics, performance statements that need a device, and anything that contradicts ADR-0009 or the Auto-Creator.md sections named in the sources. Ask only questions whose answer changes the design, at most five.
Canonical override: feature directory specs/194-ua-f08-entitlement-store; requirement ids FR-U08-###, success criteria SC-U08-###, task ids T-U08-###. Answer every question yourself under the owner's standing delegation, recommended option first, and record each answer in spec.md under Clarifications.
```

#### UA-F08 `/speckit-plan`

```text
/speckit-plan Create the technical plan for UA-F08. Begin with a read-only audit of the existing sources named in the brief and record it in research.md; reference only APIs the audit verified. Give exact source paths, each marked existing, new, move or modify; module and dependency direction; public API; lifecycle and thread-ownership contracts; data schemas with versions and migrations; the tests of each layer (host, package tests on the iOS 27.x and iOS 26.5 simulators, app UI tests); build and test commands; rollback. Check the plan against every constitution principle. quickstart.md must contain these evidence commands: swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests; xcodebuild test -project VisualCore.xcodeproj -scheme VisualCore -only-testing:VisualCoreTests/StoreTests -destination "platform=iOS Simulator,id=<udid>" CODE_SIGNING_ALLOWED=NO; python3 scripts/check_release_symbols.py --app <Release app>. When VisualCore changes: python3 scripts/check_public_api.py --update, python3 scripts/check_documented_api.py, and the seven-step ProjectM reference regression in two chunks.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/194-ua-f08-entitlement-store; requirement ids FR-U08-###, success criteria SC-U08-###, task ids T-U08-###. The clarification decisions are binding.
```

#### UA-F08 `/speckit-checklist`

```text
/speckit-checklist Generate the requirements-quality checklist for UA-F08: completeness, clarity, consistency, measurability, lifecycle and failure coverage, privacy and no-advertising constraints, accessibility, the split between simulator-verifiable and device-only requirements, and traceability to the sources.
Canonical override: feature directory specs/194-ua-f08-entitlement-store; requirement ids FR-U08-###, success criteria SC-U08-###, task ids T-U08-###. Evaluate every item yourself under the owner's standing delegation, record the evaluation in the checklist, and correct the specification for every failed item before continuing.
```

#### UA-F08 `/speckit-tasks`

```text
/speckit-tasks Break UA-F08 into dependency-ordered tasks with exact files, tests written before the code they prove, an integration acceptance task per user story, commit boundaries and review checkpoints. Include one task for every evidence command of quickstart.md; the documentation, API-baseline and ProjectM-regression tasks when VisualCore changes; one task tagged {device} for every device-only item and one tagged {owner} for every owner-only item; and a final task that runs /speckit-converge until it appends nothing.
Canonical override: feature directory specs/194-ua-f08-entitlement-store; requirement ids FR-U08-###, success criteria SC-U08-###, task ids T-U08-###. Tasks start at T-U08-001. Evidence is recorded with python3 scripts/migration_ledger.py run-check --gate UA-F08 --name <check-name> -- <command>.
```

#### UA-F08 `/speckit-analyze`

```text
/speckit-analyze Validate the UA-F08 specification, plan and tasks: requirements without tasks, tasks without requirements, speculative dependencies, missing tests, ambiguous terms, and conflicts with the constitution or ADR-0009. Stop if a critical finding remains.
Canonical override: feature directory specs/194-ua-f08-entitlement-store; requirement ids FR-U08-###, success criteria SC-U08-###, task ids T-U08-###. Apply the fixes yourself under the owner's standing delegation, record them in the artifacts, and run the analysis again until no critical or high finding remains.
```

#### UA-F08 `/speckit-implement`

```text
/speckit-implement Implement UA-F08 task by task in small verified groups. Run the real builds and tests (host tests, package tests on the iOS 27.x and iOS 26.5 simulators, app tests where the feature has UI); a task is never ticked from reading code. Tasks tagged {device} or {owner} stay open, are listed in the final report and do not block the gate.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/194-ua-f08-entitlement-store; requirement ids FR-U08-###, success criteria SC-U08-###, task ids T-U08-###. Record each passing command with python3 scripts/migration_ledger.py run-check --gate UA-F08 --name <check-name> -- <command>.
```

#### UA-F08 `/speckit-converge`

```text
/speckit-converge Assess the code against the UA-F08 specification, plan and tasks and append every remaining gap as a task. Then run /speckit-implement for the appended tasks and /speckit-converge again; repeat until a run appends nothing and reports what it checked. Only then seal and record the gate: python3 scripts/migration_ledger.py seal --gate UA-F08 && python3 scripts/migration_ledger.py record --gate UA-F08.
Canonical override: feature directory specs/194-ua-f08-entitlement-store; requirement ids FR-U08-###, success criteria SC-U08-###, task ids T-U08-###. Appended tasks continue the T-U08-### sequence.
```

### UA-F09 Experience verification runner and evidence schema

| | |
|---|---|
| Spec directory | `specs/195-ua-f09-verification-runner` |
| Ids | `FR-U09-###`, `SC-U09-###`, `T-U09-###` |
| Ledger gate | `UA-F09`; depends on `CONSTITUTION-2`, `UA-F02`, `UA-F03`, `UA-F04` |
| Read first | Auto-Creator.md sections 6 and 22; Packages/VisualCoreRendering/Sources/VisualCoreAutomation (AutomationRunner, AutomationReport); scripts/run_automation_sim.py; scripts/check_test_enumeration.py |
| Absorbs | R02-F29 golden harness; R02-F31 device automation harness and report schema (simulator part); R03-F11 and R04-F11 evidence collection (simulator part) |

**Scope.** Build the single deterministic verification runner: a scenario manifest per experience, an in-app scenario runner compiled only for DEBUG or VISUALCORE_AUTOMATION, the host driver scripts/verify_experiences.py (new) for host tests and simulator scenarios, the versioned evidence schema with its validator, and the no-placeholder audits.

**Acceptance.**

1. Every experience ships the scenarios launch-first-frame, input-response, completion, rejection, save-restore, reset, suspend-resume, teardown-reentry and cancel-prepare, expressed as domain actions.
2. The in-app runner runs one scenario by experience id and seed, writes evidence JSON and exits; it cannot be reached from a URL or any public input.
3. verify_experiences.py runs host tests and simulator scenarios per runtime, collects JSON, screenshots and result bundles, is resumable with --only and --skip, and exits non-zero on any failure.
4. Evidence records follow the schema of Auto-Creator.md section 22.3 and are checked by a validator with self-tests.
5. Audits fail on TODO or placeholder markers in shipped sources, on raster art other than the generated app icon, on scenarios that bypass the real reducer, and on content counts below the source specification.
6. Rendered frames pass non-blank and semantic probe checks; golden images are supporting evidence only.
7. Each record names the simulator runtime build, device type, Xcode build, commit and app binary hash.
8. The driver has self-tests with the sample experience, including a deliberately failing scenario.
9. A result bundle counts only after xcrun xcresulttool, run independently, reports the tests as passed; the driver records test counts, failures, destination and attachments from the bundle.
10. Games additionally run the 80 acceptance scenarios of their chapter, a hero scenario with automatic image checks (histogram, no black frame, no non-finite value, silhouette bounds) and, from Round 3 on, the 50 fault-injection cases.

**Evidence commands.**

- `python3 scripts/test_scripts.py`
- `python3 scripts/verify_experiences.py --self-test`
- `python3 scripts/verify_experiences.py --only <sample id> --runtime 27 26`

**Device-only, after ImplementationLock-100 (`{device}` tasks).** None.

**Owner-only (`{owner}` tasks).** None.

**Out of scope.** Physical devices (UA-F13).

#### UA-F09 `/speckit-specify`

```text
/speckit-specify Feature UA-F09: Experience verification runner and evidence schema.
SCOPE: Build the single deterministic verification runner: a scenario manifest per experience, an in-app scenario runner compiled only for DEBUG or VISUALCORE_AUTOMATION, the host driver scripts/verify_experiences.py (new) for host tests and simulator scenarios, the versioned evidence schema with its validator, and the no-placeholder audits.
DEPENDS ON: UA-F02, UA-F03, UA-F04 (each must be pass in the migration ledger before this feature is implemented).
SOURCES TO READ FIRST: Auto-Creator.md sections 6 and 22; Packages/VisualCoreRendering/Sources/VisualCoreAutomation (AutomationRunner, AutomationReport); scripts/run_automation_sim.py; scripts/check_test_enumeration.py.
ABSORBED SOURCE REQUIREMENTS: R02-F29 golden harness; R02-F31 device automation harness and report schema (simulator part); R03-F11 and R04-F11 evidence collection (simulator part). Read each archived feature with python3 scripts/planning_index.py prompt --feature <ID> --stage specify, and list every unique requirement in the specification as adopted, adapted or superseded with the reason.
ACCEPTANCE (each item becomes at least one functional requirement and one measurable success criterion): (1) Every experience ships the scenarios launch-first-frame, input-response, completion, rejection, save-restore, reset, suspend-resume, teardown-reentry and cancel-prepare, expressed as domain actions. (2) The in-app runner runs one scenario by experience id and seed, writes evidence JSON and exits; it cannot be reached from a URL or any public input. (3) verify_experiences.py runs host tests and simulator scenarios per runtime, collects JSON, screenshots and result bundles, is resumable with --only and --skip, and exits non-zero on any failure. (4) Evidence records follow the schema of Auto-Creator.md section 22.3 and are checked by a validator with self-tests. (5) Audits fail on TODO or placeholder markers in shipped sources, on raster art other than the generated app icon, on scenarios that bypass the real reducer, and on content counts below the source specification. (6) Rendered frames pass non-blank and semantic probe checks; golden images are supporting evidence only. (7) Each record names the simulator runtime build, device type, Xcode build, commit and app binary hash. (8) The driver has self-tests with the sample experience, including a deliberately failing scenario. (9) A result bundle counts only after xcrun xcresulttool, run independently, reports the tests as passed; the driver records test counts, failures, destination and attachments from the bundle. (10) Games additionally run the 80 acceptance scenarios of their chapter, a hero scenario with automatic image checks (histogram, no black frame, no non-finite value, silhouette bounds) and, from Round 3 on, the 50 fault-injection cases.
OUT OF SCOPE: (1) Physical devices (UA-F13).
DEVICE-ONLY VERIFICATION (tasks tagged {device}, run only after ImplementationLock-100): none.
OWNER-ONLY ITEMS (tasks tagged {owner}, never performed by the agent): none.
BOUNDARIES: one app target (VisualCore) and one bundle identifier; experiences never depend on each other; the OpenGL ES to ANGLE to Metal path is the only renderer and is not forked; External/projectm-ios is read-only and ProjectM types stay out of the VisualCore public API and out of the app; public Apple APIs only; no advertising, analytics or tracking code and no network use; pure logic goes in Packages/VisualCore and GPU or UIKit code in Packages/VisualCoreRendering; every public symbol gets /// documentation and the API baseline is updated; no physical-device action before ImplementationLock-100; owner-only actions are recorded as BLOCKED_OWNER_ACTION and never performed.
Write prioritized user stories that can each be tested alone, acceptance scenarios, and edge cases for failure, cancellation, lifecycle interruption, memory pressure and corrupted or newer-version data where they apply. State requirements as observable behavior; name existing modules only where the brief names them.
Canonical override: feature directory specs/195-ua-f09-verification-runner; requirement ids FR-U09-###, success criteria SC-U09-###, task ids T-U09-###.
```

#### UA-F09 `/speckit-clarify`

```text
/speckit-clarify Review the UA-F09 specification for unverified VisualCore or Apple APIs, lifecycle and thread-ownership assumptions, data-format and migration semantics, performance statements that need a device, and anything that contradicts ADR-0009 or the Auto-Creator.md sections named in the sources. Ask only questions whose answer changes the design, at most five.
Canonical override: feature directory specs/195-ua-f09-verification-runner; requirement ids FR-U09-###, success criteria SC-U09-###, task ids T-U09-###. Answer every question yourself under the owner's standing delegation, recommended option first, and record each answer in spec.md under Clarifications.
```

#### UA-F09 `/speckit-plan`

```text
/speckit-plan Create the technical plan for UA-F09. Begin with a read-only audit of the existing sources named in the brief and record it in research.md; reference only APIs the audit verified. Give exact source paths, each marked existing, new, move or modify; module and dependency direction; public API; lifecycle and thread-ownership contracts; data schemas with versions and migrations; the tests of each layer (host, package tests on the iOS 27.x and iOS 26.5 simulators, app UI tests); build and test commands; rollback. Check the plan against every constitution principle. quickstart.md must contain these evidence commands: python3 scripts/test_scripts.py; python3 scripts/verify_experiences.py --self-test; python3 scripts/verify_experiences.py --only <sample id> --runtime 27 26. When VisualCore changes: python3 scripts/check_public_api.py --update, python3 scripts/check_documented_api.py, and the seven-step ProjectM reference regression in two chunks.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/195-ua-f09-verification-runner; requirement ids FR-U09-###, success criteria SC-U09-###, task ids T-U09-###. The clarification decisions are binding.
```

#### UA-F09 `/speckit-checklist`

```text
/speckit-checklist Generate the requirements-quality checklist for UA-F09: completeness, clarity, consistency, measurability, lifecycle and failure coverage, privacy and no-advertising constraints, accessibility, the split between simulator-verifiable and device-only requirements, and traceability to the sources.
Canonical override: feature directory specs/195-ua-f09-verification-runner; requirement ids FR-U09-###, success criteria SC-U09-###, task ids T-U09-###. Evaluate every item yourself under the owner's standing delegation, record the evaluation in the checklist, and correct the specification for every failed item before continuing.
```

#### UA-F09 `/speckit-tasks`

```text
/speckit-tasks Break UA-F09 into dependency-ordered tasks with exact files, tests written before the code they prove, an integration acceptance task per user story, commit boundaries and review checkpoints. Include one task for every evidence command of quickstart.md; the documentation, API-baseline and ProjectM-regression tasks when VisualCore changes; one task tagged {device} for every device-only item and one tagged {owner} for every owner-only item; and a final task that runs /speckit-converge until it appends nothing.
Canonical override: feature directory specs/195-ua-f09-verification-runner; requirement ids FR-U09-###, success criteria SC-U09-###, task ids T-U09-###. Tasks start at T-U09-001. Evidence is recorded with python3 scripts/migration_ledger.py run-check --gate UA-F09 --name <check-name> -- <command>.
```

#### UA-F09 `/speckit-analyze`

```text
/speckit-analyze Validate the UA-F09 specification, plan and tasks: requirements without tasks, tasks without requirements, speculative dependencies, missing tests, ambiguous terms, and conflicts with the constitution or ADR-0009. Stop if a critical finding remains.
Canonical override: feature directory specs/195-ua-f09-verification-runner; requirement ids FR-U09-###, success criteria SC-U09-###, task ids T-U09-###. Apply the fixes yourself under the owner's standing delegation, record them in the artifacts, and run the analysis again until no critical or high finding remains.
```

#### UA-F09 `/speckit-implement`

```text
/speckit-implement Implement UA-F09 task by task in small verified groups. Run the real builds and tests (host tests, package tests on the iOS 27.x and iOS 26.5 simulators, app tests where the feature has UI); a task is never ticked from reading code. Tasks tagged {device} or {owner} stay open, are listed in the final report and do not block the gate.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/195-ua-f09-verification-runner; requirement ids FR-U09-###, success criteria SC-U09-###, task ids T-U09-###. Record each passing command with python3 scripts/migration_ledger.py run-check --gate UA-F09 --name <check-name> -- <command>.
```

#### UA-F09 `/speckit-converge`

```text
/speckit-converge Assess the code against the UA-F09 specification, plan and tasks and append every remaining gap as a task. Then run /speckit-implement for the appended tasks and /speckit-converge again; repeat until a run appends nothing and reports what it checked. Only then seal and record the gate: python3 scripts/migration_ledger.py seal --gate UA-F09 && python3 scripts/migration_ledger.py record --gate UA-F09.
Canonical override: feature directory specs/195-ua-f09-verification-runner; requirement ids FR-U09-###, success criteria SC-U09-###, task ids T-U09-###. Appended tasks continue the T-U09-### sequence.
```

### UA-F10 Build, project and CI consolidation

| | |
|---|---|
| Spec directory | `specs/196-ua-f10-build-ci` |
| Ids | `FR-U10-###`, `SC-U10-###`, `T-U10-###` |
| Ledger gate | `UA-F10`; depends on `CONSTITUTION-2`, `UA-F04` |
| Read first | Auto-Creator.md sections 16 and 24; project.yml; .github/workflows/ci.yml; scripts/release_check.py; scripts/check_dependencies.py |
| Absorbs | R02-F30 suite build matrix; R03-F10 and R04-F10 target integration (one target instead of 25) |

**Scope.** Consolidate the build: one application target in project.yml, experience packages Packages/ExperiencesCreative, ExperiencesRound02, ExperiencesRound03 and ExperiencesRound04 (new) with validated manifests, dependency rules for experiences, release_check.py steps for the unified app split into chunks under ten minutes, CI jobs, and recorded build-time and size budgets.

**Acceptance.**

1. project.yml has exactly one application target that is shippable; harnesses keep their own specs; standalone app targets disappear as UA-F07 completes.
2. Experience modules depend only on the VisualCore framework packages; scripts/check_dependencies.py fails on an experience importing another experience or any ProjectM module.
3. Package manifests of the experience packages are generated or validated from the catalog; a missing or extra target fails.
4. release_check.py offers unified-app steps (unit, UI in chunks, experience verification subsets), each finishing within ten minutes.
5. CI runs the host gates on every push and pull request and builds the app for the simulator; nothing in CI needs signing.
6. Clean-build time, incremental build time and app size are recorded at each milestone; a module-granularity change needs an ADR with the measurement.

**Evidence commands.**

- `xcodegen generate --spec project.yml`
- `python3 scripts/check_dependencies.py`
- `python3 scripts/release_check.py --only docs compliance dependencies public-api licenses script-tests`
- `xcodebuild build -project VisualCore.xcodeproj -scheme VisualCore -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`

**Device-only, after ImplementationLock-100 (`{device}` tasks).** None.

**Owner-only (`{owner}` tasks).** None.

**Out of scope.** Signing, archives and distribution.

#### UA-F10 `/speckit-specify`

```text
/speckit-specify Feature UA-F10: Build, project and CI consolidation.
SCOPE: Consolidate the build: one application target in project.yml, experience packages Packages/ExperiencesCreative, ExperiencesRound02, ExperiencesRound03 and ExperiencesRound04 (new) with validated manifests, dependency rules for experiences, release_check.py steps for the unified app split into chunks under ten minutes, CI jobs, and recorded build-time and size budgets.
DEPENDS ON: UA-F04 (each must be pass in the migration ledger before this feature is implemented).
SOURCES TO READ FIRST: Auto-Creator.md sections 16 and 24; project.yml; .github/workflows/ci.yml; scripts/release_check.py; scripts/check_dependencies.py.
ABSORBED SOURCE REQUIREMENTS: R02-F30 suite build matrix; R03-F10 and R04-F10 target integration (one target instead of 25). Read each archived feature with python3 scripts/planning_index.py prompt --feature <ID> --stage specify, and list every unique requirement in the specification as adopted, adapted or superseded with the reason.
ACCEPTANCE (each item becomes at least one functional requirement and one measurable success criterion): (1) project.yml has exactly one application target that is shippable; harnesses keep their own specs; standalone app targets disappear as UA-F07 completes. (2) Experience modules depend only on the VisualCore framework packages; scripts/check_dependencies.py fails on an experience importing another experience or any ProjectM module. (3) Package manifests of the experience packages are generated or validated from the catalog; a missing or extra target fails. (4) release_check.py offers unified-app steps (unit, UI in chunks, experience verification subsets), each finishing within ten minutes. (5) CI runs the host gates on every push and pull request and builds the app for the simulator; nothing in CI needs signing. (6) Clean-build time, incremental build time and app size are recorded at each milestone; a module-granularity change needs an ADR with the measurement.
OUT OF SCOPE: (1) Signing, archives and distribution.
DEVICE-ONLY VERIFICATION (tasks tagged {device}, run only after ImplementationLock-100): none.
OWNER-ONLY ITEMS (tasks tagged {owner}, never performed by the agent): none.
BOUNDARIES: one app target (VisualCore) and one bundle identifier; experiences never depend on each other; the OpenGL ES to ANGLE to Metal path is the only renderer and is not forked; External/projectm-ios is read-only and ProjectM types stay out of the VisualCore public API and out of the app; public Apple APIs only; no advertising, analytics or tracking code and no network use; pure logic goes in Packages/VisualCore and GPU or UIKit code in Packages/VisualCoreRendering; every public symbol gets /// documentation and the API baseline is updated; no physical-device action before ImplementationLock-100; owner-only actions are recorded as BLOCKED_OWNER_ACTION and never performed.
Write prioritized user stories that can each be tested alone, acceptance scenarios, and edge cases for failure, cancellation, lifecycle interruption, memory pressure and corrupted or newer-version data where they apply. State requirements as observable behavior; name existing modules only where the brief names them.
Canonical override: feature directory specs/196-ua-f10-build-ci; requirement ids FR-U10-###, success criteria SC-U10-###, task ids T-U10-###.
```

#### UA-F10 `/speckit-clarify`

```text
/speckit-clarify Review the UA-F10 specification for unverified VisualCore or Apple APIs, lifecycle and thread-ownership assumptions, data-format and migration semantics, performance statements that need a device, and anything that contradicts ADR-0009 or the Auto-Creator.md sections named in the sources. Ask only questions whose answer changes the design, at most five.
Canonical override: feature directory specs/196-ua-f10-build-ci; requirement ids FR-U10-###, success criteria SC-U10-###, task ids T-U10-###. Answer every question yourself under the owner's standing delegation, recommended option first, and record each answer in spec.md under Clarifications.
```

#### UA-F10 `/speckit-plan`

```text
/speckit-plan Create the technical plan for UA-F10. Begin with a read-only audit of the existing sources named in the brief and record it in research.md; reference only APIs the audit verified. Give exact source paths, each marked existing, new, move or modify; module and dependency direction; public API; lifecycle and thread-ownership contracts; data schemas with versions and migrations; the tests of each layer (host, package tests on the iOS 27.x and iOS 26.5 simulators, app UI tests); build and test commands; rollback. Check the plan against every constitution principle. quickstart.md must contain these evidence commands: xcodegen generate --spec project.yml; python3 scripts/check_dependencies.py; python3 scripts/release_check.py --only docs compliance dependencies public-api licenses script-tests; xcodebuild build -project VisualCore.xcodeproj -scheme VisualCore -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO. When VisualCore changes: python3 scripts/check_public_api.py --update, python3 scripts/check_documented_api.py, and the seven-step ProjectM reference regression in two chunks.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/196-ua-f10-build-ci; requirement ids FR-U10-###, success criteria SC-U10-###, task ids T-U10-###. The clarification decisions are binding.
```

#### UA-F10 `/speckit-checklist`

```text
/speckit-checklist Generate the requirements-quality checklist for UA-F10: completeness, clarity, consistency, measurability, lifecycle and failure coverage, privacy and no-advertising constraints, accessibility, the split between simulator-verifiable and device-only requirements, and traceability to the sources.
Canonical override: feature directory specs/196-ua-f10-build-ci; requirement ids FR-U10-###, success criteria SC-U10-###, task ids T-U10-###. Evaluate every item yourself under the owner's standing delegation, record the evaluation in the checklist, and correct the specification for every failed item before continuing.
```

#### UA-F10 `/speckit-tasks`

```text
/speckit-tasks Break UA-F10 into dependency-ordered tasks with exact files, tests written before the code they prove, an integration acceptance task per user story, commit boundaries and review checkpoints. Include one task for every evidence command of quickstart.md; the documentation, API-baseline and ProjectM-regression tasks when VisualCore changes; one task tagged {device} for every device-only item and one tagged {owner} for every owner-only item; and a final task that runs /speckit-converge until it appends nothing.
Canonical override: feature directory specs/196-ua-f10-build-ci; requirement ids FR-U10-###, success criteria SC-U10-###, task ids T-U10-###. Tasks start at T-U10-001. Evidence is recorded with python3 scripts/migration_ledger.py run-check --gate UA-F10 --name <check-name> -- <command>.
```

#### UA-F10 `/speckit-analyze`

```text
/speckit-analyze Validate the UA-F10 specification, plan and tasks: requirements without tasks, tasks without requirements, speculative dependencies, missing tests, ambiguous terms, and conflicts with the constitution or ADR-0009. Stop if a critical finding remains.
Canonical override: feature directory specs/196-ua-f10-build-ci; requirement ids FR-U10-###, success criteria SC-U10-###, task ids T-U10-###. Apply the fixes yourself under the owner's standing delegation, record them in the artifacts, and run the analysis again until no critical or high finding remains.
```

#### UA-F10 `/speckit-implement`

```text
/speckit-implement Implement UA-F10 task by task in small verified groups. Run the real builds and tests (host tests, package tests on the iOS 27.x and iOS 26.5 simulators, app tests where the feature has UI); a task is never ticked from reading code. Tasks tagged {device} or {owner} stay open, are listed in the final report and do not block the gate.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/196-ua-f10-build-ci; requirement ids FR-U10-###, success criteria SC-U10-###, task ids T-U10-###. Record each passing command with python3 scripts/migration_ledger.py run-check --gate UA-F10 --name <check-name> -- <command>.
```

#### UA-F10 `/speckit-converge`

```text
/speckit-converge Assess the code against the UA-F10 specification, plan and tasks and append every remaining gap as a task. Then run /speckit-implement for the appended tasks and /speckit-converge again; repeat until a run appends nothing and reports what it checked. Only then seal and record the gate: python3 scripts/migration_ledger.py seal --gate UA-F10 && python3 scripts/migration_ledger.py record --gate UA-F10.
Canonical override: feature directory specs/196-ua-f10-build-ci; requirement ids FR-U10-###, success criteria SC-U10-###, task ids T-U10-###. Appended tasks continue the T-U10-### sequence.
```

### UA-F11 Privacy, licensing, no-advertising audit and distinctiveness

| | |
|---|---|
| Spec directory | `specs/197-ua-f11-compliance` |
| Ids | `FR-U11-###`, `SC-U11-###`, `T-U11-###` |
| Ledger gate | `UA-F11`; depends on `CONSTITUTION-2`, `UA-F04`, `UA-F10` |
| Read first | Auto-Creator.md section 15; scripts/check_privacy_manifest.py; scripts/check_licenses.py; scripts/bundle_licenses.py; docs/legal |
| Absorbs | R02-F33 distinctiveness and release packaging; R03-F12 and R04-F12 originality, legal and no-ads audits (pre-device part) |

**Scope.** One privacy manifest audited against the built app, usage descriptions only for capabilities of registered experiences, a no-advertising scan of linked frameworks, symbols and strings, bundled license notices, proof that ProjectM is not linked into the app, a distinctiveness matrix over the launch experiences, and truthful metadata inputs.

**Acceptance.**

1. PrivacyInfo.xcprivacy matches the required-reason APIs found in the built app (scripts/check_privacy_manifest.py).
2. Info.plist usage descriptions exist only for capabilities declared by registered experiences.
3. A scan of the built app finds no advertising, analytics or tracking SDK, no AdSupport or AppTrackingTransparency use and no ad identifiers; any finding fails the gate.
4. ANGLE notices and every third-party license are bundled and shown in the app; docs/legal/third-party.json is complete.
5. A symbol and dependency scan proves no ProjectM engine or preset code is in the app.
6. A distinctiveness matrix over all pairs of the launch experiences (core abstraction, player action, win rule) shows no two share a mechanic; a near-duplicate is redesigned before the lock and is never merged or dropped (ADR-0009 D-16); the human distinctiveness review is an owner review (D-17).
7. Metadata inputs are generated only from experiences whose integration gate is pass.

**Evidence commands.**

- `python3 scripts/check_privacy_manifest.py --app <built app>`
- `python3 scripts/check_licenses.py`
- `python3 scripts/check_compliance.py`
- `python3 scripts/check_release_symbols.py --app <Release app>`

**Device-only, after ImplementationLock-100 (`{device}` tasks).** None.

**Owner-only (`{owner}` tasks).** Legal review of licenses and App Store answers; Trademark and name clearance.

**Out of scope.** Submitting anything to App Store Connect.

#### UA-F11 `/speckit-specify`

```text
/speckit-specify Feature UA-F11: Privacy, licensing, no-advertising audit and distinctiveness.
SCOPE: One privacy manifest audited against the built app, usage descriptions only for capabilities of registered experiences, a no-advertising scan of linked frameworks, symbols and strings, bundled license notices, proof that ProjectM is not linked into the app, a distinctiveness matrix over the launch experiences, and truthful metadata inputs.
DEPENDS ON: UA-F04, UA-F10 (each must be pass in the migration ledger before this feature is implemented).
SOURCES TO READ FIRST: Auto-Creator.md section 15; scripts/check_privacy_manifest.py; scripts/check_licenses.py; scripts/bundle_licenses.py; docs/legal.
ABSORBED SOURCE REQUIREMENTS: R02-F33 distinctiveness and release packaging; R03-F12 and R04-F12 originality, legal and no-ads audits (pre-device part). Read each archived feature with python3 scripts/planning_index.py prompt --feature <ID> --stage specify, and list every unique requirement in the specification as adopted, adapted or superseded with the reason.
ACCEPTANCE (each item becomes at least one functional requirement and one measurable success criterion): (1) PrivacyInfo.xcprivacy matches the required-reason APIs found in the built app (scripts/check_privacy_manifest.py). (2) Info.plist usage descriptions exist only for capabilities declared by registered experiences. (3) A scan of the built app finds no advertising, analytics or tracking SDK, no AdSupport or AppTrackingTransparency use and no ad identifiers; any finding fails the gate. (4) ANGLE notices and every third-party license are bundled and shown in the app; docs/legal/third-party.json is complete. (5) A symbol and dependency scan proves no ProjectM engine or preset code is in the app. (6) A distinctiveness matrix over all pairs of the launch experiences (core abstraction, player action, win rule) shows no two share a mechanic; a near-duplicate is redesigned before the lock and is never merged or dropped (ADR-0009 D-16); the human distinctiveness review is an owner review (D-17). (7) Metadata inputs are generated only from experiences whose integration gate is pass.
OUT OF SCOPE: (1) Submitting anything to App Store Connect.
DEVICE-ONLY VERIFICATION (tasks tagged {device}, run only after ImplementationLock-100): none.
OWNER-ONLY ITEMS (tasks tagged {owner}, never performed by the agent): (1) Legal review of licenses and App Store answers. (2) Trademark and name clearance.
BOUNDARIES: one app target (VisualCore) and one bundle identifier; experiences never depend on each other; the OpenGL ES to ANGLE to Metal path is the only renderer and is not forked; External/projectm-ios is read-only and ProjectM types stay out of the VisualCore public API and out of the app; public Apple APIs only; no advertising, analytics or tracking code and no network use; pure logic goes in Packages/VisualCore and GPU or UIKit code in Packages/VisualCoreRendering; every public symbol gets /// documentation and the API baseline is updated; no physical-device action before ImplementationLock-100; owner-only actions are recorded as BLOCKED_OWNER_ACTION and never performed.
Write prioritized user stories that can each be tested alone, acceptance scenarios, and edge cases for failure, cancellation, lifecycle interruption, memory pressure and corrupted or newer-version data where they apply. State requirements as observable behavior; name existing modules only where the brief names them.
Canonical override: feature directory specs/197-ua-f11-compliance; requirement ids FR-U11-###, success criteria SC-U11-###, task ids T-U11-###.
```

#### UA-F11 `/speckit-clarify`

```text
/speckit-clarify Review the UA-F11 specification for unverified VisualCore or Apple APIs, lifecycle and thread-ownership assumptions, data-format and migration semantics, performance statements that need a device, and anything that contradicts ADR-0009 or the Auto-Creator.md sections named in the sources. Ask only questions whose answer changes the design, at most five.
Canonical override: feature directory specs/197-ua-f11-compliance; requirement ids FR-U11-###, success criteria SC-U11-###, task ids T-U11-###. Answer every question yourself under the owner's standing delegation, recommended option first, and record each answer in spec.md under Clarifications.
```

#### UA-F11 `/speckit-plan`

```text
/speckit-plan Create the technical plan for UA-F11. Begin with a read-only audit of the existing sources named in the brief and record it in research.md; reference only APIs the audit verified. Give exact source paths, each marked existing, new, move or modify; module and dependency direction; public API; lifecycle and thread-ownership contracts; data schemas with versions and migrations; the tests of each layer (host, package tests on the iOS 27.x and iOS 26.5 simulators, app UI tests); build and test commands; rollback. Check the plan against every constitution principle. quickstart.md must contain these evidence commands: python3 scripts/check_privacy_manifest.py --app <built app>; python3 scripts/check_licenses.py; python3 scripts/check_compliance.py; python3 scripts/check_release_symbols.py --app <Release app>. When VisualCore changes: python3 scripts/check_public_api.py --update, python3 scripts/check_documented_api.py, and the seven-step ProjectM reference regression in two chunks.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/197-ua-f11-compliance; requirement ids FR-U11-###, success criteria SC-U11-###, task ids T-U11-###. The clarification decisions are binding.
```

#### UA-F11 `/speckit-checklist`

```text
/speckit-checklist Generate the requirements-quality checklist for UA-F11: completeness, clarity, consistency, measurability, lifecycle and failure coverage, privacy and no-advertising constraints, accessibility, the split between simulator-verifiable and device-only requirements, and traceability to the sources.
Canonical override: feature directory specs/197-ua-f11-compliance; requirement ids FR-U11-###, success criteria SC-U11-###, task ids T-U11-###. Evaluate every item yourself under the owner's standing delegation, record the evaluation in the checklist, and correct the specification for every failed item before continuing.
```

#### UA-F11 `/speckit-tasks`

```text
/speckit-tasks Break UA-F11 into dependency-ordered tasks with exact files, tests written before the code they prove, an integration acceptance task per user story, commit boundaries and review checkpoints. Include one task for every evidence command of quickstart.md; the documentation, API-baseline and ProjectM-regression tasks when VisualCore changes; one task tagged {device} for every device-only item and one tagged {owner} for every owner-only item; and a final task that runs /speckit-converge until it appends nothing.
Canonical override: feature directory specs/197-ua-f11-compliance; requirement ids FR-U11-###, success criteria SC-U11-###, task ids T-U11-###. Tasks start at T-U11-001. Evidence is recorded with python3 scripts/migration_ledger.py run-check --gate UA-F11 --name <check-name> -- <command>.
```

#### UA-F11 `/speckit-analyze`

```text
/speckit-analyze Validate the UA-F11 specification, plan and tasks: requirements without tasks, tasks without requirements, speculative dependencies, missing tests, ambiguous terms, and conflicts with the constitution or ADR-0009. Stop if a critical finding remains.
Canonical override: feature directory specs/197-ua-f11-compliance; requirement ids FR-U11-###, success criteria SC-U11-###, task ids T-U11-###. Apply the fixes yourself under the owner's standing delegation, record them in the artifacts, and run the analysis again until no critical or high finding remains.
```

#### UA-F11 `/speckit-implement`

```text
/speckit-implement Implement UA-F11 task by task in small verified groups. Run the real builds and tests (host tests, package tests on the iOS 27.x and iOS 26.5 simulators, app tests where the feature has UI); a task is never ticked from reading code. Tasks tagged {device} or {owner} stay open, are listed in the final report and do not block the gate.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/197-ua-f11-compliance; requirement ids FR-U11-###, success criteria SC-U11-###, task ids T-U11-###. Record each passing command with python3 scripts/migration_ledger.py run-check --gate UA-F11 --name <check-name> -- <command>.
```

#### UA-F11 `/speckit-converge`

```text
/speckit-converge Assess the code against the UA-F11 specification, plan and tasks and append every remaining gap as a task. Then run /speckit-implement for the appended tasks and /speckit-converge again; repeat until a run appends nothing and reports what it checked. Only then seal and record the gate: python3 scripts/migration_ledger.py seal --gate UA-F11 && python3 scripts/migration_ledger.py record --gate UA-F11.
Canonical override: feature directory specs/197-ua-f11-compliance; requirement ids FR-U11-###, success criteria SC-U11-###, task ids T-U11-###. Appended tasks continue the T-U11-### sequence.
```

### UA-F12 ImplementationLock-100: independent verification of all 100 experiences

| | |
|---|---|
| Spec directory | `specs/198-ua-f12-implementation-lock` |
| Ids | `FR-U12-###`, `SC-U12-###`, `T-U12-###` |
| Ledger gate | `UA-F12`; depends on `CONSTITUTION-2`, `UA-F09`, `UA-F10`, `UA-F11` |
| Read first | Auto-Creator.md section 22; ADR-0009 D-07; scripts/migration_ledger.py |
| Absorbs | R02-F34 cross-game reconciliation and evidence lock; legacy gate IMPLEMENTATION-LOCK |

**Scope.** Provide the independent rerun that proves 100 of 100: scripts/verify_experiences.py --lock on a clean tree with fresh derived data, the lock manifest docs/verification/implementation-lock-100.json (new), and the rule that only scripts/migration_ledger.py may record the gate ImplementationLock-100 from a valid manifest.

**Acceptance.**

1. The lock run starts from a clean working tree at one commit and fresh derived data, and reruns host tests, package tests, shader compilation, UI flows and every scenario set for all 100 experiences on the iOS 27.x and 26.5 simulators.
2. The lock manifest records commit, tree hash, catalog hash, tool versions, simulator runtimes and, per experience, the evidence file hashes and results.
3. migration_ledger.py records ImplementationLock-100 only when the manifest validates: 100 entries, 50 free and 50 premium, all pass, purchase scenarios pass, audits pass.
4. A capability that needs hardware may be listed as pending hardware verification; no core gameplay, rendering, persistence or purchase requirement may be listed there.
5. Any change of tracked source after the lock invalidates it; the re-lock procedure is documented and tested.
6. The device guard of migration_ledger.py refuses every D gate until the lock is pass.

**Evidence commands.**

- `python3 scripts/verify_experiences.py --lock`
- `python3 scripts/migration_ledger.py validate`
- `python3 scripts/migration_ledger.py guard-device`

**Device-only, after ImplementationLock-100 (`{device}` tasks).** None.

**Owner-only (`{owner}` tasks).** None.

**Out of scope.** Running devices.

#### UA-F12 `/speckit-specify`

```text
/speckit-specify Feature UA-F12: ImplementationLock-100: independent verification of all 100 experiences.
SCOPE: Provide the independent rerun that proves 100 of 100: scripts/verify_experiences.py --lock on a clean tree with fresh derived data, the lock manifest docs/verification/implementation-lock-100.json (new), and the rule that only scripts/migration_ledger.py may record the gate ImplementationLock-100 from a valid manifest.
DEPENDS ON: UA-F09, UA-F10, UA-F11 (each must be pass in the migration ledger before this feature is implemented).
SOURCES TO READ FIRST: Auto-Creator.md section 22; ADR-0009 D-07; scripts/migration_ledger.py.
ABSORBED SOURCE REQUIREMENTS: R02-F34 cross-game reconciliation and evidence lock; legacy gate IMPLEMENTATION-LOCK. Read each archived feature with python3 scripts/planning_index.py prompt --feature <ID> --stage specify, and list every unique requirement in the specification as adopted, adapted or superseded with the reason.
ACCEPTANCE (each item becomes at least one functional requirement and one measurable success criterion): (1) The lock run starts from a clean working tree at one commit and fresh derived data, and reruns host tests, package tests, shader compilation, UI flows and every scenario set for all 100 experiences on the iOS 27.x and 26.5 simulators. (2) The lock manifest records commit, tree hash, catalog hash, tool versions, simulator runtimes and, per experience, the evidence file hashes and results. (3) migration_ledger.py records ImplementationLock-100 only when the manifest validates: 100 entries, 50 free and 50 premium, all pass, purchase scenarios pass, audits pass. (4) A capability that needs hardware may be listed as pending hardware verification; no core gameplay, rendering, persistence or purchase requirement may be listed there. (5) Any change of tracked source after the lock invalidates it; the re-lock procedure is documented and tested. (6) The device guard of migration_ledger.py refuses every D gate until the lock is pass.
OUT OF SCOPE: (1) Running devices.
DEVICE-ONLY VERIFICATION (tasks tagged {device}, run only after ImplementationLock-100): none.
OWNER-ONLY ITEMS (tasks tagged {owner}, never performed by the agent): none.
BOUNDARIES: one app target (VisualCore) and one bundle identifier; experiences never depend on each other; the OpenGL ES to ANGLE to Metal path is the only renderer and is not forked; External/projectm-ios is read-only and ProjectM types stay out of the VisualCore public API and out of the app; public Apple APIs only; no advertising, analytics or tracking code and no network use; pure logic goes in Packages/VisualCore and GPU or UIKit code in Packages/VisualCoreRendering; every public symbol gets /// documentation and the API baseline is updated; no physical-device action before ImplementationLock-100; owner-only actions are recorded as BLOCKED_OWNER_ACTION and never performed.
Write prioritized user stories that can each be tested alone, acceptance scenarios, and edge cases for failure, cancellation, lifecycle interruption, memory pressure and corrupted or newer-version data where they apply. State requirements as observable behavior; name existing modules only where the brief names them.
Canonical override: feature directory specs/198-ua-f12-implementation-lock; requirement ids FR-U12-###, success criteria SC-U12-###, task ids T-U12-###.
```

#### UA-F12 `/speckit-clarify`

```text
/speckit-clarify Review the UA-F12 specification for unverified VisualCore or Apple APIs, lifecycle and thread-ownership assumptions, data-format and migration semantics, performance statements that need a device, and anything that contradicts ADR-0009 or the Auto-Creator.md sections named in the sources. Ask only questions whose answer changes the design, at most five.
Canonical override: feature directory specs/198-ua-f12-implementation-lock; requirement ids FR-U12-###, success criteria SC-U12-###, task ids T-U12-###. Answer every question yourself under the owner's standing delegation, recommended option first, and record each answer in spec.md under Clarifications.
```

#### UA-F12 `/speckit-plan`

```text
/speckit-plan Create the technical plan for UA-F12. Begin with a read-only audit of the existing sources named in the brief and record it in research.md; reference only APIs the audit verified. Give exact source paths, each marked existing, new, move or modify; module and dependency direction; public API; lifecycle and thread-ownership contracts; data schemas with versions and migrations; the tests of each layer (host, package tests on the iOS 27.x and iOS 26.5 simulators, app UI tests); build and test commands; rollback. Check the plan against every constitution principle. quickstart.md must contain these evidence commands: python3 scripts/verify_experiences.py --lock; python3 scripts/migration_ledger.py validate; python3 scripts/migration_ledger.py guard-device. When VisualCore changes: python3 scripts/check_public_api.py --update, python3 scripts/check_documented_api.py, and the seven-step ProjectM reference regression in two chunks.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/198-ua-f12-implementation-lock; requirement ids FR-U12-###, success criteria SC-U12-###, task ids T-U12-###. The clarification decisions are binding.
```

#### UA-F12 `/speckit-checklist`

```text
/speckit-checklist Generate the requirements-quality checklist for UA-F12: completeness, clarity, consistency, measurability, lifecycle and failure coverage, privacy and no-advertising constraints, accessibility, the split between simulator-verifiable and device-only requirements, and traceability to the sources.
Canonical override: feature directory specs/198-ua-f12-implementation-lock; requirement ids FR-U12-###, success criteria SC-U12-###, task ids T-U12-###. Evaluate every item yourself under the owner's standing delegation, record the evaluation in the checklist, and correct the specification for every failed item before continuing.
```

#### UA-F12 `/speckit-tasks`

```text
/speckit-tasks Break UA-F12 into dependency-ordered tasks with exact files, tests written before the code they prove, an integration acceptance task per user story, commit boundaries and review checkpoints. Include one task for every evidence command of quickstart.md; the documentation, API-baseline and ProjectM-regression tasks when VisualCore changes; one task tagged {device} for every device-only item and one tagged {owner} for every owner-only item; and a final task that runs /speckit-converge until it appends nothing.
Canonical override: feature directory specs/198-ua-f12-implementation-lock; requirement ids FR-U12-###, success criteria SC-U12-###, task ids T-U12-###. Tasks start at T-U12-001. Evidence is recorded with python3 scripts/migration_ledger.py run-check --gate UA-F12 --name <check-name> -- <command>.
```

#### UA-F12 `/speckit-analyze`

```text
/speckit-analyze Validate the UA-F12 specification, plan and tasks: requirements without tasks, tasks without requirements, speculative dependencies, missing tests, ambiguous terms, and conflicts with the constitution or ADR-0009. Stop if a critical finding remains.
Canonical override: feature directory specs/198-ua-f12-implementation-lock; requirement ids FR-U12-###, success criteria SC-U12-###, task ids T-U12-###. Apply the fixes yourself under the owner's standing delegation, record them in the artifacts, and run the analysis again until no critical or high finding remains.
```

#### UA-F12 `/speckit-implement`

```text
/speckit-implement Implement UA-F12 task by task in small verified groups. Run the real builds and tests (host tests, package tests on the iOS 27.x and iOS 26.5 simulators, app tests where the feature has UI); a task is never ticked from reading code. Tasks tagged {device} or {owner} stay open, are listed in the final report and do not block the gate.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/198-ua-f12-implementation-lock; requirement ids FR-U12-###, success criteria SC-U12-###, task ids T-U12-###. Record each passing command with python3 scripts/migration_ledger.py run-check --gate UA-F12 --name <check-name> -- <command>.
```

#### UA-F12 `/speckit-converge`

```text
/speckit-converge Assess the code against the UA-F12 specification, plan and tasks and append every remaining gap as a task. Then run /speckit-implement for the appended tasks and /speckit-converge again; repeat until a run appends nothing and reports what it checked. Only then seal and record the gate: python3 scripts/migration_ledger.py seal --gate UA-F12 && python3 scripts/migration_ledger.py record --gate UA-F12.
Canonical override: feature directory specs/198-ua-f12-implementation-lock; requirement ids FR-U12-###, success criteria SC-U12-###, task ids T-U12-###. Appended tasks continue the T-U12-### sequence.
```

### UA-F13 Device lab: the D1, D2, D3 campaign for 100 experiences

| | |
|---|---|
| Spec directory | `specs/199-ua-f13-device-lab` |
| Ids | `FR-U13-###`, `SC-U13-###`, `T-U13-###` |
| Ledger gate | `UA-F13`; depends on `CONSTITUTION-2`, `UA-F12`, `LOCK-PREMIUM-50` |
| Read first | Auto-Creator.md section 23; docs/archive/planning/playbook (devicectl lessons); scripts/inventory_devices.py; Packages/VisualCoreRendering/Sources/VisualCoreAutomation |
| Absorbs | R02-F31 device automation harness (device part); R03-F11 and R04-F11 device fixtures; legacy gates D1-A01 to D3-A25 and DEVICE-RECONCILE |

**Scope.** Write scripts/run_device_campaign.py (new): refuse before the lock, discover D1, D2 and D3 by product type, record the live OS and build, install one signed automation build per device, run every experience by id with its scenario set, pull JSON exports and result bundles, apply the stop rules, and produce the per-device and per-experience evidence and the reconciliation report. It is noninteractive and has a dry-run mode.

**Acceptance.**

1. The script refuses to run when ImplementationLock-100 is not pass or the tree differs from the locked commit.
2. Devices are matched by hardwareProperties.productType (iPhone15,4, iPad17,3, iPad15,7); the live OS and build are recorded; D3 is refused with a blocker if it is not on iPadOS 26.5; no UDID is written to a tracked file.
3. One Release build with VISUALCORE_AUTOMATION is installed once per device; each experience runs by id and exports its evidence JSON, which is copied back with devicectl.
4. Percentage criteria use at least 200 samples; launch, first frame, frame pacing, memory and thermal state are recorded per experience; a Round 2 game runs its 30-minute stress session on each device, a game of Rounds 3 and 4 on D3, and a creative experience a ten-minute sustained scenario where its class warrants it (ADR-0009 C-14, OD-08).
5. A renderer or test-integrity failure halts the campaign on that device; a localized failure is recorded and the campaign continues; reconciliation lists every non-pass row.
6. Owner-needed states (locked device, trust, signing, permissions, purchase sheet) produce BLOCKED_OWNER_ACTION with exact steps and never wait for input; --dry-run prints the plan.
7. The shipping Release binary has no automation symbols (nm check).

**Evidence commands.**

- `python3 scripts/run_device_campaign.py --dry-run`
- `python3 scripts/test_scripts.py`
- `python3 scripts/check_release_symbols.py --app <Release app>`

**Device-only, after ImplementationLock-100 (`{device}` tasks).** All 300 rows: 100 experiences on D1, then D2, then D3.

**Owner-only (`{owner}` tasks).** Provision signing (Configs/Signing.local.xcconfig), unlock and trust devices, keep D3 on iPadOS 26.5, grant microphone permission, operate purchase sheets.

**Out of scope.** Any device test before the lock; Updating device operating systems.

#### UA-F13 `/speckit-specify`

```text
/speckit-specify Feature UA-F13: Device lab: the D1, D2, D3 campaign for 100 experiences.
SCOPE: Write scripts/run_device_campaign.py (new): refuse before the lock, discover D1, D2 and D3 by product type, record the live OS and build, install one signed automation build per device, run every experience by id with its scenario set, pull JSON exports and result bundles, apply the stop rules, and produce the per-device and per-experience evidence and the reconciliation report. It is noninteractive and has a dry-run mode.
DEPENDS ON: UA-F12 (each must be pass in the migration ledger before this feature is implemented).
SOURCES TO READ FIRST: Auto-Creator.md section 23; docs/archive/planning/playbook (devicectl lessons); scripts/inventory_devices.py; Packages/VisualCoreRendering/Sources/VisualCoreAutomation.
ABSORBED SOURCE REQUIREMENTS: R02-F31 device automation harness (device part); R03-F11 and R04-F11 device fixtures; legacy gates D1-A01 to D3-A25 and DEVICE-RECONCILE. Read each archived feature with python3 scripts/planning_index.py prompt --feature <ID> --stage specify, and list every unique requirement in the specification as adopted, adapted or superseded with the reason.
ACCEPTANCE (each item becomes at least one functional requirement and one measurable success criterion): (1) The script refuses to run when ImplementationLock-100 is not pass or the tree differs from the locked commit. (2) Devices are matched by hardwareProperties.productType (iPhone15,4, iPad17,3, iPad15,7); the live OS and build are recorded; D3 is refused with a blocker if it is not on iPadOS 26.5; no UDID is written to a tracked file. (3) One Release build with VISUALCORE_AUTOMATION is installed once per device; each experience runs by id and exports its evidence JSON, which is copied back with devicectl. (4) Percentage criteria use at least 200 samples; launch, first frame, frame pacing, memory and thermal state are recorded per experience; a Round 2 game runs its 30-minute stress session on each device, a game of Rounds 3 and 4 on D3, and a creative experience a ten-minute sustained scenario where its class warrants it (ADR-0009 C-14, OD-08). (5) A renderer or test-integrity failure halts the campaign on that device; a localized failure is recorded and the campaign continues; reconciliation lists every non-pass row. (6) Owner-needed states (locked device, trust, signing, permissions, purchase sheet) produce BLOCKED_OWNER_ACTION with exact steps and never wait for input; --dry-run prints the plan. (7) The shipping Release binary has no automation symbols (nm check).
OUT OF SCOPE: (1) Any device test before the lock. (2) Updating device operating systems.
DEVICE-ONLY VERIFICATION (tasks tagged {device}, run only after ImplementationLock-100): (1) All 300 rows: 100 experiences on D1, then D2, then D3.
OWNER-ONLY ITEMS (tasks tagged {owner}, never performed by the agent): (1) Provision signing (Configs/Signing.local.xcconfig), unlock and trust devices, keep D3 on iPadOS 26.5, grant microphone permission, operate purchase sheets.
BOUNDARIES: one app target (VisualCore) and one bundle identifier; experiences never depend on each other; the OpenGL ES to ANGLE to Metal path is the only renderer and is not forked; External/projectm-ios is read-only and ProjectM types stay out of the VisualCore public API and out of the app; public Apple APIs only; no advertising, analytics or tracking code and no network use; pure logic goes in Packages/VisualCore and GPU or UIKit code in Packages/VisualCoreRendering; every public symbol gets /// documentation and the API baseline is updated; no physical-device action before ImplementationLock-100; owner-only actions are recorded as BLOCKED_OWNER_ACTION and never performed.
Write prioritized user stories that can each be tested alone, acceptance scenarios, and edge cases for failure, cancellation, lifecycle interruption, memory pressure and corrupted or newer-version data where they apply. State requirements as observable behavior; name existing modules only where the brief names them.
Canonical override: feature directory specs/199-ua-f13-device-lab; requirement ids FR-U13-###, success criteria SC-U13-###, task ids T-U13-###.
```

#### UA-F13 `/speckit-clarify`

```text
/speckit-clarify Review the UA-F13 specification for unverified VisualCore or Apple APIs, lifecycle and thread-ownership assumptions, data-format and migration semantics, performance statements that need a device, and anything that contradicts ADR-0009 or the Auto-Creator.md sections named in the sources. Ask only questions whose answer changes the design, at most five.
Canonical override: feature directory specs/199-ua-f13-device-lab; requirement ids FR-U13-###, success criteria SC-U13-###, task ids T-U13-###. Answer every question yourself under the owner's standing delegation, recommended option first, and record each answer in spec.md under Clarifications.
```

#### UA-F13 `/speckit-plan`

```text
/speckit-plan Create the technical plan for UA-F13. Begin with a read-only audit of the existing sources named in the brief and record it in research.md; reference only APIs the audit verified. Give exact source paths, each marked existing, new, move or modify; module and dependency direction; public API; lifecycle and thread-ownership contracts; data schemas with versions and migrations; the tests of each layer (host, package tests on the iOS 27.x and iOS 26.5 simulators, app UI tests); build and test commands; rollback. Check the plan against every constitution principle. quickstart.md must contain these evidence commands: python3 scripts/run_device_campaign.py --dry-run; python3 scripts/test_scripts.py; python3 scripts/check_release_symbols.py --app <Release app>. When VisualCore changes: python3 scripts/check_public_api.py --update, python3 scripts/check_documented_api.py, and the seven-step ProjectM reference regression in two chunks.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/199-ua-f13-device-lab; requirement ids FR-U13-###, success criteria SC-U13-###, task ids T-U13-###. The clarification decisions are binding.
```

#### UA-F13 `/speckit-checklist`

```text
/speckit-checklist Generate the requirements-quality checklist for UA-F13: completeness, clarity, consistency, measurability, lifecycle and failure coverage, privacy and no-advertising constraints, accessibility, the split between simulator-verifiable and device-only requirements, and traceability to the sources.
Canonical override: feature directory specs/199-ua-f13-device-lab; requirement ids FR-U13-###, success criteria SC-U13-###, task ids T-U13-###. Evaluate every item yourself under the owner's standing delegation, record the evaluation in the checklist, and correct the specification for every failed item before continuing.
```

#### UA-F13 `/speckit-tasks`

```text
/speckit-tasks Break UA-F13 into dependency-ordered tasks with exact files, tests written before the code they prove, an integration acceptance task per user story, commit boundaries and review checkpoints. Include one task for every evidence command of quickstart.md; the documentation, API-baseline and ProjectM-regression tasks when VisualCore changes; one task tagged {device} for every device-only item and one tagged {owner} for every owner-only item; and a final task that runs /speckit-converge until it appends nothing.
Canonical override: feature directory specs/199-ua-f13-device-lab; requirement ids FR-U13-###, success criteria SC-U13-###, task ids T-U13-###. Tasks start at T-U13-001. Evidence is recorded with python3 scripts/migration_ledger.py run-check --gate UA-F13 --name <check-name> -- <command>.
```

#### UA-F13 `/speckit-analyze`

```text
/speckit-analyze Validate the UA-F13 specification, plan and tasks: requirements without tasks, tasks without requirements, speculative dependencies, missing tests, ambiguous terms, and conflicts with the constitution or ADR-0009. Stop if a critical finding remains.
Canonical override: feature directory specs/199-ua-f13-device-lab; requirement ids FR-U13-###, success criteria SC-U13-###, task ids T-U13-###. Apply the fixes yourself under the owner's standing delegation, record them in the artifacts, and run the analysis again until no critical or high finding remains.
```

#### UA-F13 `/speckit-implement`

```text
/speckit-implement Implement UA-F13 task by task in small verified groups. Run the real builds and tests (host tests, package tests on the iOS 27.x and iOS 26.5 simulators, app tests where the feature has UI); a task is never ticked from reading code. Tasks tagged {device} or {owner} stay open, are listed in the final report and do not block the gate.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/199-ua-f13-device-lab; requirement ids FR-U13-###, success criteria SC-U13-###, task ids T-U13-###. Record each passing command with python3 scripts/migration_ledger.py run-check --gate UA-F13 --name <check-name> -- <command>.
```

#### UA-F13 `/speckit-converge`

```text
/speckit-converge Assess the code against the UA-F13 specification, plan and tasks and append every remaining gap as a task. Then run /speckit-implement for the appended tasks and /speckit-converge again; repeat until a run appends nothing and reports what it checked. Only then seal and record the gate: python3 scripts/migration_ledger.py seal --gate UA-F13 && python3 scripts/migration_ledger.py record --gate UA-F13.
Canonical override: feature directory specs/199-ua-f13-device-lab; requirement ids FR-U13-###, success criteria SC-U13-###, task ids T-U13-###. Appended tasks continue the T-U13-### sequence.
```

### UA-F14 Release preparation (owner-gated)

| | |
|---|---|
| Spec directory | `specs/200-ua-f14-release-preparation` |
| Ids | `FR-U14-###`, `SC-U14-###`, `T-U14-###` |
| Ledger gate | `UA-F14`; depends on `CONSTITUTION-2`, `UA-F11`, `UA-F13`, `DEVICE-RECONCILE-100` |
| Read first | Auto-Creator.md section 24; docs/archive/planning/playbook (App Store Connect and release); docs/release |
| Absorbs | R02-F33 release packaging (one app instead of 25) |

**Scope.** Prepare, without submitting: version and build numbers, the archive configuration, screenshots captured from real runs with a provenance manifest, metadata drafts derived from the verified catalog, the StoreKit product checklist, review notes and the final compliance run.

**Acceptance.**

1. Version and build numbers are set in project.yml; an unsigned archive build succeeds.
2. Every screenshot comes from a real simulator or device run and is listed with experience id, seed, commit and device in a provenance manifest; no mock-ups.
3. Name, subtitle, description, keywords, privacy answers, in-app purchase name and description and review notes are drafted from experiences that are implemented and verified; future content is described as planned.
4. The final compliance, privacy, license and symbol checks pass on the release candidate.
5. Nothing is uploaded or submitted; the owner checklist lists every remaining manual step.

**Evidence commands.**

- `python3 scripts/release_check.py`
- `python3 scripts/check_app_release.py --app <archive app>`

**Device-only, after ImplementationLock-100 (`{device}` tasks).** None.

**Owner-only (`{owner}` tasks).** Signing and upload; App Store Connect record, agreements, pricing, in-app purchase submission, review submission.

**Out of scope.** Submission to App Review.

#### UA-F14 `/speckit-specify`

```text
/speckit-specify Feature UA-F14: Release preparation (owner-gated).
SCOPE: Prepare, without submitting: version and build numbers, the archive configuration, screenshots captured from real runs with a provenance manifest, metadata drafts derived from the verified catalog, the StoreKit product checklist, review notes and the final compliance run.
DEPENDS ON: UA-F11, UA-F13 (each must be pass in the migration ledger before this feature is implemented).
SOURCES TO READ FIRST: Auto-Creator.md section 24; docs/archive/planning/playbook (App Store Connect and release); docs/release.
ABSORBED SOURCE REQUIREMENTS: R02-F33 release packaging (one app instead of 25). Read each archived feature with python3 scripts/planning_index.py prompt --feature <ID> --stage specify, and list every unique requirement in the specification as adopted, adapted or superseded with the reason.
ACCEPTANCE (each item becomes at least one functional requirement and one measurable success criterion): (1) Version and build numbers are set in project.yml; an unsigned archive build succeeds. (2) Every screenshot comes from a real simulator or device run and is listed with experience id, seed, commit and device in a provenance manifest; no mock-ups. (3) Name, subtitle, description, keywords, privacy answers, in-app purchase name and description and review notes are drafted from experiences that are implemented and verified; future content is described as planned. (4) The final compliance, privacy, license and symbol checks pass on the release candidate. (5) Nothing is uploaded or submitted; the owner checklist lists every remaining manual step.
OUT OF SCOPE: (1) Submission to App Review.
DEVICE-ONLY VERIFICATION (tasks tagged {device}, run only after ImplementationLock-100): none.
OWNER-ONLY ITEMS (tasks tagged {owner}, never performed by the agent): (1) Signing and upload. (2) App Store Connect record, agreements, pricing, in-app purchase submission, review submission.
BOUNDARIES: one app target (VisualCore) and one bundle identifier; experiences never depend on each other; the OpenGL ES to ANGLE to Metal path is the only renderer and is not forked; External/projectm-ios is read-only and ProjectM types stay out of the VisualCore public API and out of the app; public Apple APIs only; no advertising, analytics or tracking code and no network use; pure logic goes in Packages/VisualCore and GPU or UIKit code in Packages/VisualCoreRendering; every public symbol gets /// documentation and the API baseline is updated; no physical-device action before ImplementationLock-100; owner-only actions are recorded as BLOCKED_OWNER_ACTION and never performed.
Write prioritized user stories that can each be tested alone, acceptance scenarios, and edge cases for failure, cancellation, lifecycle interruption, memory pressure and corrupted or newer-version data where they apply. State requirements as observable behavior; name existing modules only where the brief names them.
Canonical override: feature directory specs/200-ua-f14-release-preparation; requirement ids FR-U14-###, success criteria SC-U14-###, task ids T-U14-###.
```

#### UA-F14 `/speckit-clarify`

```text
/speckit-clarify Review the UA-F14 specification for unverified VisualCore or Apple APIs, lifecycle and thread-ownership assumptions, data-format and migration semantics, performance statements that need a device, and anything that contradicts ADR-0009 or the Auto-Creator.md sections named in the sources. Ask only questions whose answer changes the design, at most five.
Canonical override: feature directory specs/200-ua-f14-release-preparation; requirement ids FR-U14-###, success criteria SC-U14-###, task ids T-U14-###. Answer every question yourself under the owner's standing delegation, recommended option first, and record each answer in spec.md under Clarifications.
```

#### UA-F14 `/speckit-plan`

```text
/speckit-plan Create the technical plan for UA-F14. Begin with a read-only audit of the existing sources named in the brief and record it in research.md; reference only APIs the audit verified. Give exact source paths, each marked existing, new, move or modify; module and dependency direction; public API; lifecycle and thread-ownership contracts; data schemas with versions and migrations; the tests of each layer (host, package tests on the iOS 27.x and iOS 26.5 simulators, app UI tests); build and test commands; rollback. Check the plan against every constitution principle. quickstart.md must contain these evidence commands: python3 scripts/release_check.py; python3 scripts/check_app_release.py --app <archive app>. When VisualCore changes: python3 scripts/check_public_api.py --update, python3 scripts/check_documented_api.py, and the seven-step ProjectM reference regression in two chunks.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/200-ua-f14-release-preparation; requirement ids FR-U14-###, success criteria SC-U14-###, task ids T-U14-###. The clarification decisions are binding.
```

#### UA-F14 `/speckit-checklist`

```text
/speckit-checklist Generate the requirements-quality checklist for UA-F14: completeness, clarity, consistency, measurability, lifecycle and failure coverage, privacy and no-advertising constraints, accessibility, the split between simulator-verifiable and device-only requirements, and traceability to the sources.
Canonical override: feature directory specs/200-ua-f14-release-preparation; requirement ids FR-U14-###, success criteria SC-U14-###, task ids T-U14-###. Evaluate every item yourself under the owner's standing delegation, record the evaluation in the checklist, and correct the specification for every failed item before continuing.
```

#### UA-F14 `/speckit-tasks`

```text
/speckit-tasks Break UA-F14 into dependency-ordered tasks with exact files, tests written before the code they prove, an integration acceptance task per user story, commit boundaries and review checkpoints. Include one task for every evidence command of quickstart.md; the documentation, API-baseline and ProjectM-regression tasks when VisualCore changes; one task tagged {device} for every device-only item and one tagged {owner} for every owner-only item; and a final task that runs /speckit-converge until it appends nothing.
Canonical override: feature directory specs/200-ua-f14-release-preparation; requirement ids FR-U14-###, success criteria SC-U14-###, task ids T-U14-###. Tasks start at T-U14-001. Evidence is recorded with python3 scripts/migration_ledger.py run-check --gate UA-F14 --name <check-name> -- <command>.
```

#### UA-F14 `/speckit-analyze`

```text
/speckit-analyze Validate the UA-F14 specification, plan and tasks: requirements without tasks, tasks without requirements, speculative dependencies, missing tests, ambiguous terms, and conflicts with the constitution or ADR-0009. Stop if a critical finding remains.
Canonical override: feature directory specs/200-ua-f14-release-preparation; requirement ids FR-U14-###, success criteria SC-U14-###, task ids T-U14-###. Apply the fixes yourself under the owner's standing delegation, record them in the artifacts, and run the analysis again until no critical or high finding remains.
```

#### UA-F14 `/speckit-implement`

```text
/speckit-implement Implement UA-F14 task by task in small verified groups. Run the real builds and tests (host tests, package tests on the iOS 27.x and iOS 26.5 simulators, app tests where the feature has UI); a task is never ticked from reading code. Tasks tagged {device} or {owner} stay open, are listed in the final report and do not block the gate.
DISCIPLINE: work in Claude Desktop Code on branch main (never the Claude CLI); commit after every task and push with python3 scripts/prepush_scan.py --push. Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must be confirmed or corrected against real code and the correction recorded. Never claim device performance from simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... — Verified YYYY-MM-DD: <command and result>'. Commits carry no trailers.
Canonical override: feature directory specs/200-ua-f14-release-preparation; requirement ids FR-U14-###, success criteria SC-U14-###, task ids T-U14-###. Record each passing command with python3 scripts/migration_ledger.py run-check --gate UA-F14 --name <check-name> -- <command>.
```

#### UA-F14 `/speckit-converge`

```text
/speckit-converge Assess the code against the UA-F14 specification, plan and tasks and append every remaining gap as a task. Then run /speckit-implement for the appended tasks and /speckit-converge again; repeat until a run appends nothing and reports what it checked. Only then seal and record the gate: python3 scripts/migration_ledger.py seal --gate UA-F14 && python3 scripts/migration_ledger.py record --gate UA-F14.
Canonical override: feature directory specs/200-ua-f14-release-preparation; requirement ids FR-U14-###, success criteria SC-U14-###, task ids T-U14-###. Appended tasks continue the T-U14-### sequence.
```
<!-- GENERATED:END unified-features -->

## 21. Prompt catalog for archived features and canonical overrides

### 21.1 Where every prompt is

The archive contains a complete Spec Kit prompt for every stage of every planned feature. None was dropped or
rewritten. `docs/catalog/feature-index.json` records, for each feature, the file, the line span of each of its
eight prompts and the SHA-256 of its section; `scripts/planning_index.py prompt` prints a prompt verbatim after
checking that hash.

<!-- GENERATED:BEGIN prompt-catalog -->
| Features | Count | Archived stage prompts | Prompts are in | Print with |
|---|---:|---:|---|---|
| Foundation phases F00–F09 (sealed) | 10 | in the manifest | `docs/process/speckit-prompt-manifest.json` (extracted from the archive) | `python3 scripts/speckit_prompts.py --feature <NNN>` |
| Original app phases A01-P00 … A25-P06 | 175 | in the manifest | `docs/process/speckit-prompt-manifest.json` (extracted from the archive) | `python3 scripts/speckit_prompts.py --feature <NNN>` plus `python3 scripts/planning_index.py prompt --feature A<nn>-P<p> --override` |
| Round 2 shared features | 34 | 272 | `docs/archive/planning/rounds/` | `python3 scripts/planning_index.py prompt --feature <ID> --stage <stage> --override` |
| Round 2 game features | 250 | 2,000 | `docs/archive/planning/rounds/` | `python3 scripts/planning_index.py prompt --feature <ID> --stage <stage> --override` |
| Rounds 3–4 shared features | 24 | 192 | `docs/archive/planning/rounds/` | `python3 scripts/planning_index.py prompt --feature <ID> --stage <stage> --override` |
| Rounds 3–4 game features | 500 | 4,000 | `docs/archive/planning/rounds/` | `python3 scripts/planning_index.py prompt --feature <ID> --stage <stage> --override` |
| Rounds 5–12 (backlog) shared features | 96 | 768 | `docs/archive/planning/rounds/` | `python3 scripts/planning_index.py prompt --feature <ID> --stage <stage> --override` |
| Rounds 5–12 (backlog) game features | 2,000 | 16,000 | `docs/archive/planning/rounds/` | `python3 scripts/planning_index.py prompt --feature <ID> --stage <stage> --override` |
| Unified-app features UA-F00 … UA-F14 (new) | 15 | 120 rendered | `docs/catalog/unified-app-features.json`, section 20 | `python3 scripts/planning_index.py prompt --feature UA-F<kk>` |
| Constitution prompts of rounds 2–12 | 11 | superseded | archive | replaced by the amendment of section 19.2 |
| **Archived features in the index** | **3,089** | **23,232** | | |
<!-- GENERATED:END prompt-catalog -->

The prompts of rounds 3–12 are six-line blocks (header, target, product intent, implementation boundaries, Spec
Kit discipline, stage instruction); two of the six lines are constant across the corpus. Round 2 prompts are
single lines. The catalog is deduplicated by reference, not by rewriting: the index points at the one archived
copy of each prompt.

Each archived prompt of rounds 3–12 carries its own stage rules, which stand: a specification with five user
stories, twelve requirements, eight success conditions and three counterexamples; tasks with unique ids and a seed
per test; an implementation that records exit codes and never deletes an assertion. The archive also contains
harmless template artifacts, which are read as intended: Round 12 mentions a following round that does not exist,
Round 3's constitution prompt names an empty range of earlier rounds, and rounds 3–9 write some ids without
zero padding (`R3-F03`).

### 21.2 Canonical overrides

The archived prompts were written for separate apps. They are used verbatim, followed by one of these notes
(printed automatically with `--override`). The notes change the packaging and the order of device work; they never
weaken a functional, quality or testing requirement. For a round feature, `--override` then prints one more
sentence with the feature's directory from the ledger and its three id forms, for example
"Canonical override: feature directory specs/301-aurora-loom-playable-rule-kernel; requirement ids
FR-R02G0101-###, success criteria SC-R02G0101-###, task ids T-R02G0101-###." The namespace is the one the document
validator derives from the directory, so the prompt and the validator cannot disagree.

<!-- GENERATED:BEGIN canonical-overrides -->
For every game feature (example: a feature of R02-G01):

```text
Canonical override (ADR-0009, Auto-Creator.md section 21): this game is experience R02-G01 inside the single VisualCore app. Create no app target, bundle identifier, XcodeGen scheme or per-game store listing; add an experience module and register it in the catalog. Ignore the source's price, 'no IAP', per-round device campaign and prior-round device prerequisites: entitlement comes from the shared purchase controller (tier: free), and physical-device testing happens only after ImplementationLock-100. Use the spec directory and requirement-ID namespace of Auto-Creator.md section 19. All other requirements of the prompt stand.
```

For every shared round feature:

```text
Canonical override (ADR-0009, Auto-Creator.md section 21): implement this shared feature in the existing VisualCore packages for the single VisualCore app. First check Auto-Creator.md section 13: if an existing module or a unified-app feature already provides the contract, write the audit and a verified reuse adapter instead of a duplicate. Ignore prerequisites that demand a completed device campaign of an earlier round; devices are tested only after ImplementationLock-100. Use the numbering of Auto-Creator.md section 19.
```

For every phase of an original app (example: A05-P01, feature 040):

```text
Canonical override (ADR-0009, Auto-Creator.md section 21): this app is experience A05 inside the single VisualCore app. Do not create or extend a standalone app target, bundle identifier, in-app product or store listing. Visuals are code only: where the prompt or the manual mentions licensed or purchased models, textures, atlases or asset packs, generate the geometry and imagery in code; bundled data (numbers, names, structures) needs a license and provenance record. The app makes no network request. Until UA-F07 has moved an app, its sources stay where they are; afterwards and for every app not yet started the sources are the experience modules named in Auto-Creator.md section 16. Store-listing, pricing and per-app release-dossier parts of Phase 06 are inapplicable; its quality, privacy, accessibility and regression gates stand. Physical-device tasks are tagged {device} and run only after ImplementationLock-100. Feature directory and ids follow ADR-0004 (specs/040-*, FR-A05-1##, SC-A05-1##, T-A05-1##); evidence is recorded with Tools/python/desktop_runbook.py run-check --stage A05-P01. All other requirements of the prompt stand.
```
<!-- GENERATED:END canonical-overrides -->

### 21.3 Reading archived prompts

| The archived text says | Read it as |
|---|---|
| "app", "target", "bundle id", "scheme" for a game or a creative app | the experience module and its registration in the one app |
| a price, "paid app", "premium complete offline app", "no IAP", "no StoreKit" | the experience's tier in the catalog and the shared entitlement of section 14; the experience itself contains no purchase code |
| "no advertising, analytics, tracking, login, external image generation" | unchanged and binding |
| "after the Round N device campaign", "prior-round device exit" | the dependencies in the migration ledger; devices only after `ImplementationLock-100` |
| "implementation lock" inside a game feature | the experience's integration gate `X-<code>` |
| "device automation preparation" | the scenario set and the definition of the device row; no device contact |
| "CLAUDE.md", "README.md" as scope | this document and `CLAUDE.md` |
| "80 solver-certified stages" (Round 2) | 100 certified levels; 80 is the first milestone |
| "96- or 100-level catalog" (rounds 3–12) | 100 levels, as in the game's level manifest |
| "premium", "paid once", "one-time purchase" in a Round 2 game | the game is free: all its content without any purchase |
| `ROUND2_AUTOMATION`, `ROUND2_AUTORUN` | `VISUALCORE_AUTOMATION`, `VISUALCORE_AUTORUN` |
| `Apps/<Game>`, `Round2*` packages, `GameModules`, `docs/games/<slug>` | the experience module of section 16 |
| `docs/test-reports/`, `docs/adr/` | `docs/verification/`, `docs/decisions/` |
| `Application Support/<Game>/v1/progress.json` | the experience's storage namespace (section 15.1) |
| `.autonomy/round2-state.json`, Round 2's own gate list, `specs/599-round2-suite-audit` | the migration ledger, `LOCK-FREE-50`, UA-F12 |
| "GO, PIVOT, COMBINE, NO_GO", kill criteria | redesign inside the concept; never drop, merge or replace (section 6.5) |
| a human review as a gate | an owner review, recorded and non-gating (section 6.5) |
| a 30-minute stress session | kept as written: on each device for a Round 2 game, on D3 for a game of rounds 3–12 (section 23.3) |
| licensed or purchased meshes, textures, atlases, asset packs | geometry and imagery generated by code; bundled data with license and provenance (section 7) |
| a network allowlist, "audit each network requirement" | no network request at all (section 15.2) |
| `[device]`, `[owner]` task tags | `{device}`, `{owner}` |
| `ROUND<N>_AUTOMATION`, `Packages/Round<N>*`, `.autonomy/round<N>-state.json`, `org.visualcore.round<N>.<game>`, `specs/r<nn>-shared-*`, `specs/r<nn>-game-*` | the names of this document: `VISUALCORE_AUTOMATION`, the experience packages, the migration ledger, the runtime id, the spec directory printed by the ledger |
| `hardwareUDID` in an evidence record, `docs/test-reports/round<N>/` | identifiers only in untracked private files; tracked summaries under `docs/verification/` |
| per-game `Info.plist`, privacy manifest, store metadata, bundle identifier | the one app's single set (C-05, C-06) |
| each round's or each manual's "standalone app" scope in a `/speckit-constitution` prompt | constitution 2.0.0; an original app's prompt adds only its experience rules (section 19.3) |

### 21.4 Level manifests and assertion outlines

Every game has, in its chapter, a manifest of 100 levels (Round 2: chapter section 18; rounds 3–12: section 8)
and a table of 80 acceptance scenarios; games of rounds 3–12 add 50 fault-injection cases.
`python3 scripts/planning_index.py levels --experience <CODE>` prints a level manifest as JSON, and the catalog
records the line span and row count of every table. They are requirements of the game's features: the manifest
for the level compiler, the scenario tables for the tests.

Every game also has an assertion outline; the catalog records its line span and hash, and the Round 2 outlines
are also kept as `docs/brainstorm/Round-2-Top25-Complete-AssertionOutlines.md`. An outline is a decision argument
(claims, reasons, evidence, strongest objection, kill criteria), never proof. Its acceptance contracts are planned
tests: the solver replay agrees at fixed seeds, no geometry is missing, and the goal is recognizable (the human
five-second review is an owner review). Each claim of an outline is traced to an observation of the built
experience in that experience's evidence.

## 22. The simulator gate and ImplementationLock-100

### 22.1 The scenario set

Every experience ships a scenario manifest with at least these nine scenarios, written as domain actions and run
by the in-app scenario runner (compiled only under `DEBUG` or `VISUALCORE_AUTOMATION`):

| Scenario | Passes when |
|---|---|
| `launch-first-frame` | the experience prepares, activates and presents a non-blank frame whose semantic probe matches the initial state; stage timings are recorded |
| `input-response` | a scripted sequence of accepted actions produces the expected digests step by step |
| `completion` | the scripted solution or workflow reaches the outcome (level solved, work saved or exported) through the real reducer |
| `rejection` | invalid actions are rejected with the expected typed reasons and the digest does not change |
| `save-restore` | snapshot, terminate, relaunch, restore: the digest is identical |
| `reset` | reset gives the digest of a fresh preparation and clears only this experience's storage |
| `suspend-resume` | background and foreground: clocks stop and resume without catch-up; the digest is unchanged while suspended |
| `teardown-reentry` | after leaving, live and leaked GPU resources are zero; re-entering works; repeated cycles do not grow memory |
| `cancel-prepare` | leaving during preparation cancels it and nothing arrives afterwards |

Games add `full-playthrough` over their certified levels (host-side, through the same reducer), the 80 acceptance
scenarios of their chapter, a `hero` scenario (section 6.5) and, from Round 3 on, the 50 fault-injection cases.
Creative experiences add one scenario per regression fixture of their card. An `endurance` scenario of ten minutes
shows flat memory and GPU bytes. Scenarios are deterministic: fixed seeds, no wall-clock dependence. A scenario
is started only through the launch environment (`VISUALCORE_AUTORUN`), writes its evidence JSON and exits; no
URL, file or other outside input can start one.

### 22.2 Verifying one experience (the `X-<code>` gate)

`scripts/verify_experiences.py` (new, UA-F09) is the single driver. It runs the experience's host tests, builds
the app once, runs the scenario set on each simulator runtime, collects the evidence JSON, screenshots and result
bundles, runs the audits, and exits non-zero on any failure. It is resumable with `--only` and `--skip`.

```bash
python3 scripts/migration_ledger.py run-check --gate X-<CODE> --name host -- swift test --package-path Packages/<ExperiencePackage> --filter <Name>
python3 scripts/migration_ledger.py run-check --gate X-<CODE> --name sim27 -- python3 scripts/verify_experiences.py --only <id> --runtime 27
python3 scripts/migration_ledger.py run-check --gate X-<CODE> --name sim26 -- python3 scripts/verify_experiences.py --only <id> --runtime 26
python3 scripts/migration_ledger.py run-check --gate X-<CODE> --name audits -- python3 scripts/verify_experiences.py --only <id> --audits
python3 scripts/migration_ledger.py seal --gate X-<CODE> && python3 scripts/migration_ledger.py record --gate X-<CODE>
```

The audits fail on: TODO, FIXME or placeholder markers in shipped sources; raster art other than the generated
app icon; a scenario that bypasses the real reducer; content counts below the source specification; a direct GL
call outside the framework; a premium experience that opens without entitlement; any network symbol.

Rendered frames must pass the non-blank check and the semantic probes. Golden images are supporting evidence
only: they catch regressions but a matching image never proves a rule.
Image checks use tolerances and domain invariants, never exact pixels across devices, and paired comparisons run
on the same hardware. An offline shader check or a successful compile never proves that rendering is correct or
unchanged.

A result bundle counts only after `xcrun xcresulttool` has been run on it independently and reports the tests as
passed; the summary printed by the build is not proof. The runner records test counts, failures, destination and
attachments from the bundle.

### 22.3 Evidence schema

One record per experience, scenario and environment. The validator of UA-F09 enforces the schema; version 1:

| Field | Content |
|---|---|
| `schema`, `experience`, `code`, `scenario`, `seed`, `result` | identity and outcome (`pass` or `fail`) |
| `run` | run id, attempt number and, after the lock, the SHA-256 of the lock manifest |
| `environment` | `kind` (`simulator` or `device`), OS version and build, device type or product type, Xcode, Swift and SDK builds, host OS, signing mode |
| `source` | commit, dirty flag, tree hash, submodule pins, catalog hash, SHA-256 of the app binary |
| `configuration` | build configuration, automation flag, quality tier, entitlement fixture |
| `steps` | each action with accepted or rejected, reason, digest after |
| `digests` | initial, final, after restore, after reset |
| `frames` | non-blank result, probes with outcomes, screenshot path and SHA-256 |
| `timing` | launch, preparation, shader compilation, first present, in milliseconds, each measured separately |
| `pacing` | samples, on-time count, median, p95 and p99 frame time (development signal on simulators) |
| `resources` | memory footprint, GPU bytes, live and leaked GPU objects after teardown |
| `thermal_state`, `low_power`, `battery` | as reported by the system; on devices also charging state and brightness |
| `artifacts` | result bundle path, log path and SHA-256 |
| `failures` | list of failed expectations with messages |

Device records add the device role and never contain a hardware identifier; identifiers stay in untracked private
artifacts, and a tracked record may carry only a salted hash of one. A record with result `pass` and no observed
evidence is rejected. Tracked summaries live under `docs/verification/`; raw logs, screenshots and result bundles stay in the
untracked `.autonomy/logs/` and `.autonomy/xcresults/` and are referenced by hash.

### 22.4 The three locks

| Gate | Requires | Proves |
|---|---|---|
| `LOCK-FREE-50` | `X-` gates of all 50 free experiences; UA-F10, UA-F11, UA-F12 | an independent rerun of the 50 free experiences passes on both runtimes |
| `LOCK-PREMIUM-50` | `X-` gates of all 50 premium experiences; `LOCK-FREE-50`; UA-F08 | the same for the premium library, and the purchase scenarios pass |
| `ImplementationLock-100` | both locks and UA-F13 | 100 of 100 on one locked commit |

The lock run (`python3 scripts/verify_experiences.py --lock`, new, UA-F12) is independent of earlier results: it
starts from a clean working tree at one commit with fresh derived data and reruns host tests, package tests,
shader compilation, UI flows and every scenario set for all 100 experiences on the iOS 27.x and iOS 26.5
simulators. It writes the lock manifest `docs/verification/implementation-lock-100.json` (new): commit, tree
hash, catalog hash, tool versions, simulator runtimes and, per experience, the evidence hashes and results.
`scripts/migration_ledger.py` records the gate only from a manifest that validates: 100 entries, 50 free and 50
premium, all pass, purchase scenarios pass, audits pass. The lock also checks that the Release build has no
automation symbols, no ProjectM symbols, no private API use and no signing material in Git.

A single skipped mandatory test rejects the lock. The lock report lists the real commands with their exit codes,
the Xcode and SDK builds, the commit, an audit of unimplemented features and the known platform limits.

Before the lock, a build for `generic/platform=iOS` without installation is a compile check and is never reported
as a device test; there is no early smoke test on D1. APIs newer than the deployment target are weak-linked and
guarded by availability checks, and the run on the iOS 26.5 simulator, not compilation alone, proves that path. An
instrumented Release build (`SWIFT_ACTIVE_COMPILATION_CONDITIONS` containing `VISUALCORE_AUTOMATION`) is a valid
performance build; the shipping Release build has no automation code or symbols (`nm -U` and a symbol scan).
Allowed before the lock: host tests, package tests, shader compilation, headless CPU fixtures, simulator
screenshots and UI tests, and compile checks against the device SDK. A lock is never granted on file counts.

### 22.5 After the lock

Any change of tracked app or framework source after the lock invalidates it. The repair path is: fix, rerun the
affected experiences and the shared regressions on the simulators, rerun the lock (a new revision of its
evidence, recorded with `--reverify`), then rerun the affected device rows. History is kept: every revision has
its own evidence file.

The same holds before the lock: after a change of a shared framework module, the experiences that depend on it are
verified again before their next gate, and the new revision is recorded with `--reverify`.

### 22.6 Pending hardware verification

The lock manifest may list, per experience, capabilities that only hardware can prove: microphone input quality,
haptics, real frame pacing and thermal behavior, multi-window resizing on iPad, display-specific layout. Each
entry names the device task that will verify it. Core gameplay, rendering correctness, persistence and purchase
behavior are never on this list.

## 23. Device protocol

### 23.1 Preconditions

1. `python3 scripts/migration_ledger.py guard-device` passes (the lock is recorded) and the working tree is the
   locked commit.
2. The owner has provisioned signing (`Configs/Signing.local.xcconfig`, never committed), paired and trusted the
   devices, enabled Developer Mode, unlocked them and set Auto-Lock to Never for the session. If any of this is
   missing, the campaign records `BLOCKED_OWNER_ACTION` with the exact steps and does not wait for input.
3. No device operating system is updated, erased or restored by the agent. **D3 stays on iPadOS 26.5.** If D3
   reports another version, the campaign on D3 is blocked and the owner is told.

### 23.2 Devices

| Role | Device | Product type | OS at the 2026-11-08 inventory | Purpose |
|---|---|---|---|---|
| D1 | iPhone 15 | `iPhone15,4` | iOS 27.0.1 | reference phone: ergonomics, startup, pacing, audio modes |
| D2 | iPad Pro 13-inch (M5) | `iPad17,3` | iPadOS 27.2 | high tier: large layouts, resolution, multitasking |
| D3 | iPad (A16) | `iPad15,7` | iPadOS 26.5 | the only iOS 26 fixture and the lower tier; never updated |

The inventory is history. Before each campaign the devices are discovered with
`xcrun devicectl list devices --json-output <file>` and matched by `hardwareProperties.productType`; the live OS
version and build are recorded in the evidence. Hardware identifiers are written only to untracked private files.
The roster is final: no other device is requested.

### 23.3 Campaign

`scripts/run_device_campaign.py` (new, UA-F13) runs the campaign without interaction and has a dry-run mode. The
exact `devicectl` and `xcodebuild` flags are checked against the pinned Xcode's `--help`, not copied from old
notes; the test destination needs the hardware identifier, not the `devicectl` device id.
It can rehearse on a simulator, serializes Xcode operations, has retry and time budgets, gives every run its own
result bundle path and never assumes that a device name is unique. The command shapes to confirm are: `devicectl
device install app`; `devicectl device process launch` with `--terminate-existing` and the scenario in
`--environment-variables`; `devicectl device info files` for the app's data container; `devicectl device copy
from` for the evidence file; `devicectl device info processes` and `devicectl device process terminate`.
A row is recorded as pass or fail, or it is blocked for the owner; a single scenario inside a row may be not
applicable (item 4 below); skipped is never success.

For one device, in catalog order (A01 … A25, R02-G01 … R04-G25):

1. Install one Release build with `VISUALCORE_AUTOMATION` once.
2. For each experience: launch it by id with its scenario set, wait for the app to write its evidence JSON and
   exit, copy the JSON and the result bundle back, validate them, record the row
   (`python3 scripts/migration_ledger.py record --gate DEV<n>-<code> --result pass|fail`).
3. Minimum per row: launch, native UI flow, a real rendered scene, touch and accessibility checks, pause and
   resume (and resize where it applies), persisted state after relaunch, export where the experience has one, the
   container inventory, a frame, memory and thermal trace, and a real result bundle. A Round 2 game runs its 30-minute
   stress session on each device; a game of Rounds 3 and 4 runs it on D3, at its maximum bounded complexity; a
   creative experience runs a ten-minute sustained scenario where its class warrants it; all with cool-down
   windows (OD-08). Percentage criteria use at least 200 samples, with first-run
   and warm runs separated. Frame rate is never read from a screenshot.
4. A specialized scenario may be `not_applicable` only when the experience genuinely lacks that capability on
   that OS or device; the row itself stays mandatory.

**Stop rules.** A failure of the renderer, of the harness or of test integrity (blank frames across experiences,
the runner not exiting, evidence that does not validate) halts the campaign on that device. A failure limited to
one experience is recorded as a failed row and the campaign continues. A locked device, a trust or permission
prompt, a signing problem or a purchase sheet is `BLOCKED_OWNER_ACTION`.

**Order.** All 100 on D1, then all 100 on D2, then all 100 on D3. A device's campaign gate needs every row
attempted. The purchase sheet, Ask to Buy and restore on a device with a sandbox account are owner-operated.
Manual VoiceOver passes are recorded and non-gating; the automated accessibility checks of a row do gate: the
accessibility audit of the UI tests, a label and an identifier on every control, and layouts at the largest text
size. The six open legacy `{device}` tasks (section 17.4) are run in the same sessions.

Each campaign has a run id and records the commit and the Xcode and SDK fingerprint. D1 and D2 run different minor
versions of iOS 27: before a difference is blamed on the form factor, compare OS, memory, refresh rate, GPU and
configuration. A row that only just passes is repeated and reported with its variance. Published claims name only
the tested models and OS versions. Every row records the exact OS version and build; after any OS
change on D1 or D2 the inventory is recorded again. One destination per device, and a cool-down between
performance runs. A performance baseline is labelled with model, OS, Xcode build, ANGLE commit and seed.

### 23.4 Device differentiators of the creative experiences

These checks come from the original test matrix and apply on top of the common minimum.

| Experience | Device checks | Differentiation |
|---|---|---|
| A01 Generative Art Studio | all baseline presets render; slider ranges; seed-repeatable export; orientation and resume | D1 ergonomics; D2 large canvas; D3 shader and pacing budget |
| A02 Fluid Art Playground | touch injection; stable run; ping-pong lifecycle; finite values; export | D3 lower tier; no NaN or stuck render |
| A03 Fractal Explorer | zoom, pan and deep-precision transitions; shader errors; reproducible screenshot | precision differences between GPUs; D3 fallbacks |
| A04 Particle Universe | burst ceilings; trails; suspend and restart; pool reuse | D3 adapts count and quality with the same functional result |
| A05 Infinite Geometry | scene progression; camera; clipping; geometry snapshot | aspect ratios; no camera jumps |
| A06 VisualCore Music Lab | in-app playback; microphone permission and denial; FFT and first-frame metrics | system or app capture only where the OS really offers it; unavailable on D3 |
| A07 Audio Odyssey | music-driven camera; safe-motion modes; routing and stop | D3 audio fallback; Reduce Motion and Flashing |
| A08 Oscilloscope Studio | calibrated synthetic signal and timebase trigger on the real display; permitted sources | D3 microphone and in-app modes only |
| A09 Digital Aquarium | agent animation; customization; long-running thermal and memory sweep | D3 energy floor; D2 wide layout |
| A10 Neon Arcade | touch and controller input; pacing; score persistence and replay | latency on D1 versus D2; fixed step on D3 |
| A11 Physics Playground | collisions; save and replay; no explosions or NaN | frame rate affects visuals, never the simulation |
| A12 Tiny Worlds | scene switching; camera; streaming within budget | D3 memory tier; iPad controls |
| A13 Light Maze | levels; exact reflection; reproducible win state | touch targets; high-density accuracy |
| A14 Solar System Explorer | time controls; validated ephemeris and units; picking labels | identical scientific values on all three |
| A15 Molecular Explorer | import validation; bond geometry; selection and labels | fast rejection of invalid data; no memory failure on D3 |
| A16 Simulation Lab | solver bounds; reference trajectories; export and restart | comparable numerical results; D3 fallback |
| A17 Interactive Anatomy | labels with source revisions; rotate and zoom; navigation | VoiceOver and picking on both iPads |
| A18 Ambient Clock | time zones and daylight saving; ambient shader; suspend | lifecycle differences between OS versions; tablet layout |
| A19 Living Wallpapers | image and video export; share sheet; persistence | no "install live wallpaper" action exists and none is tested |
| A20 Digital Zen Garden | stroke replay and undo; haptics where supported; export; low motion | gesture precision on D1; drawing area on iPad |
| A21 Aurora | presets; brightness and flash limiter; capture and relaunch | high refresh on D1 and D2; reduced tier on D3 |
| A22 Shader Studio | valid and invalid shaders; error, time and resource limits; recovery | no hang from untrusted shaders; D3 instruction budget |
| A23 Visual Programming Lab | graph editing; cycle rejection; propagation; save and reopen | compact editor on D1; large editor on D2 |
| A24 Graphics Benchmark Lab | calibrated scenes; frame timing; thermal and memory records | real measurements on each device; a simulator number is never a device result |
| A25 Effects Composer | multi-pass graph; texture reuse; memory cap; deterministic export | D3 texture ceiling; full resolution on D2 |

A claim that an external audio source works needs ten minutes of non-silent diagnostic capture on a supported
device; shorter samples and simulator behavior prove nothing.

### 23.5 Repairs during the campaign

After the lock the code is frozen except for targeted repairs of genuine device defects. Record the failing test
first. Make the smallest patch. Rerun the experience's host and simulator checks, rerun the lock (section 22.5),
then rerun every device row the change can affect; a change in shared code makes all earlier rows that depend on
it stale. Failed attempts are kept, never overwritten. No new feature is added during the campaign.
A repaired case links its old run and its new run, with one result bundle per device, experience and attempt.

### 23.6 Reconciliation

`DEVICE-RECONCILE-100` is recorded when all 300 rows are pass on the final locked commit. Every row whose
evidence was recorded at an older commit is rerun unless the change since then demonstrably cannot affect it. The
final report states 100 of 100 simulator-verified and how many of 300 device rows are verified, or the precise
incomplete or blocked state.
A matrix that is complete but contains failures is collected evidence, not a passing suite. One script finds
missing rows, duplicate run ids, model mismatches, OS changes between runs and gaps.

## 24. CI, release and owner-only actions

### 24.1 Continuous integration

Today CI runs the host gates on every push and pull request (`.github/workflows/ci.yml`): legacy ledger and
archive validation, document validation, the steering validators (`scripts/validate_autocreator.py`,
`scripts/planning_archive.py verify`, `scripts/planning_index.py verify`, `scripts/migration_ledger.py validate`),
compliance, dependency rules, public and documented API, licenses, script tests, host tests, and a simulator build
of the framework. Nothing in CI is signed. Planned: UA-F10 adds the unified app's simulator build. Expensive
simulator suites stay local, run through `scripts/release_check.py` in chunks of ten minutes or less.

A second workflow, `.github/workflows/push-scan.yml`, runs `scripts/prepush_scan.py` over exactly the commits of
each push (from the commit before the push to the pushed commit) and of each pull request (from the merge base to
its head), with the full history. It is the detection behind the rule that commits are pushed only through
`scripts/tick_task.py` or `scripts/prepush_scan.py --push`: a push made any other way is still read. Its
concurrency group is the commit itself and it never cancels, because a cancelled scan would leave commits unread;
`ci.yml` may cancel, because its checks describe the newest commit. The scan gives the verdict of the development
Mac: simulator identifiers are accepted only through the tracked hashes of
`Configs/simulator-identifier-hashes.json` (`python3 scripts/prepush_scan.py --record-simulators` adds them).

Rules for CI changes: every job has a timeout and a concurrency group; caches of the reference frameworks are
keyed by the Xcode build, the fork commits and the build flags; `[skip ci]` is used only for documentation-only
pushes; free CI minutes are never assumed. A change of CI or of code that CI covers is confirmed by a real run
after the push (`gh run list --branch main --limit 1`, then `gh run watch <id> --exit-status`).

The sources also plan a fast documentation and compliance gate and package tests on Linux, cached reference
frameworks passed between jobs, a job on the newest Xcode image, XcodeGen installed from its release with a
pinned SHA-256, the simulator chosen by runtime, each job fetching only what it needs, and restricted write
permissions. UA-F10 decides which of these the one app's CI adopts; whether the pure package builds on Linux has
not been verified here. Rendering and UI suites stay local for as long as they need the locally built ANGLE
frameworks. `[skip ci]` is never used on the last commit of a push that changes code or CI. A dependent job that
was skipped because an upstream job was cancelled is investigated before the code is blamed.

### 24.2 Release preparation (UA-F14)

Version and build numbers in `project.yml`; an unsigned archive build; screenshots only from real simulator or
device runs, each listed with experience id, seed, commit and device in a provenance manifest; name, subtitle,
description, keywords, privacy answers, the in-app purchase's name and description and the review notes drafted
only from experiences whose integration gate is pass; future content described as planned; the final compliance,
privacy, license and symbol checks on the release candidate. Nothing is uploaded or submitted.

Signing: `Configs/Signing.xcconfig` holds only the optional include of the owner's local file; unsigned builds pass
`CODE_SIGNING_ALLOWED=NO`; `-allowProvisioningUpdates` is used only with credentials the owner has already
provisioned; prebuilt frameworks carry a valid `CFBundleShortVersionString` and `MinimumOSVersion`, or the archive
is rejected. The hand-off list for the owner: icon, export-compliance key, privacy policy, license agreement,
review notes, name check, version and build numbers, screenshots at the exact store sizes, and previews (a
preview without audio is silent).

Release provenance records the submodule revision, lock files, tool versions, schema versions, the license
inventory, the build configuration and the test matrix.

### 24.3 Owner-only actions

The agent prepares everything up to the boundary, records the block and continues elsewhere.

| Action | Needed for |
|---|---|
| Choose the signing team; create certificates and profiles; write `Configs/Signing.local.xcconfig` | device builds |
| Pair, trust and unlock devices; enable Developer Mode; answer permission prompts | device campaign |
| Keep D3 on iPadOS 26.5 | device campaign |
| Create the app record and the in-app purchase in App Store Connect; accept agreements; set prices; decide Family Sharing | purchase on devices, release |
| Provide a sandbox tester; operate purchase sheets and Ask to Buy | purchase rows on devices |
| Verify the name, trademarks and legal texts; choose the final bundle identifier | release |
| Upload, submit for review, release | release |

A block records the object, the observed error, the command, the time and the safe action for the owner:
`BLOCKED_OWNER_ACTION: <what is needed> | gate <id> | observed: <error> | command: <command> | steps: 1. … 2. … |
verify with: <command>`. An owner waiver leaves the task unticked and adds the line
`not required (owner ruling YYYY-MM-DD): <reason>`.

The playbook of the ProjectM-iOS project asked the owner questions up front, let a script wait for a key press and
let the agent operate App Store Connect once authorized. None of that is carried over: the agent never asks,
never waits for input and never operates an owner account. Purchase sheets, system pickers, Airplane Mode and the
first microphone permission are owner-operated.

### 24.4 Git

- Work on `main` (owner ruling of 2026-11-11). Commit after every task, skill and gate and push to `origin main`
  right after. Never force-push; never rewrite history; never `git reset --hard`. The branch
  `migration/unified-app-plan` is the record of the consolidation and is not used any more.
- Small commits whose subject names the feature and the task ids (for a skill: `speckit-tasks: feature 189,
  T-U03-001 to T-U03-040`), made with the Git identity the owner configured (not a no-reply address), with no
  co-author or "Generated with" trailers and LF line endings. Verified work is never left uncommitted, and
  uncommitted changes of the owner are never reset, cleaned or overwritten.
- Before any push: `python3 scripts/prepush_scan.py` must pass. It scans every added line of the outgoing commits
  for hardware identifiers, ECIDs, serial numbers, team ids, e-mail addresses, home paths, keys and tokens, and
  refuses tracked private paths. `python3 scripts/prepush_scan.py --push` scans and then pushes;
  `scripts/tick_task.py` does the same after ticking a task.
- Never committed: `Configs/Signing.local.xcconfig`, `.autonomy/private/`, logs, result bundles, container exports.
- At each milestone exit, write a bundle outside the repository:
  `mkdir -p ../VisualCore-backups && git bundle create ../VisualCore-backups/VisualCore-<gate>-$(git rev-parse --short HEAD).bundle --all`.

## 25. Ledgers, evidence and recovery

### 25.1 The two ledgers

| | Legacy ledger | Migration ledger |
|---|---|---|
| File | `.autonomy/state.json` | `.autonomy/migration/ledger.json` |
| Only writer | `Tools/python/desktop_runbook.py` | `scripts/migration_ledger.py` |
| Holds | F00–F09 and A01-P00 … A25-P06 (and superseded suite gates that are never run) | everything new: consolidation, constitution, unified features, round features, `X-` gates, locks, device rows, release |
| Evidence | `.autonomy/evidence/`, `.autonomy/checks/` | `.autonomy/migration/evidence/`, `.autonomy/migration/checks/` |
| Order | strict, one gate at a time | dependency graph; `next` prints the execution order |
| Link | — | each `X-A<nn>` requires its seven legacy gates; the ledger records the legacy state at its creation |

Rules for both: a gate is recorded only from sealed evidence of real commands; the ledger files, the evidence
files and the attestations are never edited by hand; a passed gate is never reset. A gate may be verified again
after a source change (`--reverify`); each revision keeps its own evidence.

One integration session records gates at a time. The legacy tool keeps its lease (`claim --owner`, `release`);
another session's lease is never cleared without proof that the session is dead. The legacy tool is the tracked
file `Tools/python/desktop_runbook.py`: it was re-pointed at the archived specification during the consolidation
and is never re-extracted from the copy embedded in the archived README.

A check has four results and they are never merged: pass, fail, blocked, not run.

### 25.2 What is tracked

Tracked: both ledgers, sealed evidence, attestations (with each log's SHA-256), the catalog and index, the
dossiers, the archive, summaries under `docs/verification/`. Not tracked and local to this Mac: command logs
(`.autonomy/logs/`), result bundles (`.autonomy/xcresults/`), the extracted context of the legacy tool
(`.autonomy/context/`, rebuilt with `desktop_runbook.py bootstrap`), private device data (`.autonomy/private/`),
the built reference frameworks.

### 25.3 Validators

| Command | Proves |
|---|---|
| `python3 scripts/validate_autocreator.py` | this document, the catalog, the briefs, the matrix, the archive and both ledgers agree; the 100 allocations; all stage prompts exist; no forbidden claim, price or secret; the continuation prompt is last |
| `python3 scripts/render_autocreator.py --check` | the generated blocks match their data |
| `python3 scripts/migration_ledger.py validate` | ledger structure, dependency graph, evidence hashes, the legacy link |
| `python3 Tools/python/desktop_runbook.py validate` | legacy ledger and its source archive |
| `python3 scripts/migration_baseline.py verify` | planning documents, legacy evidence and passed gates are unchanged since the baseline |
| `python3 scripts/planning_archive.py verify` | the archive is byte-identical to the originals |
| `python3 scripts/planning_index.py verify` | catalog and index match the archive and the legacy ledger |
| `python3 scripts/planning_index.py coverage` | every pending feature of the launch scope has a non-empty prompt for all eight stages; prints the number of features and prompts |
| `python3 scripts/validate_docs.py` | every directory under `specs/` is in the numbering map; every requirement, criterion and task id has the exact shape of its directory and is unique; verified ticks, ADR headers, links |
| `python3 scripts/prepush_scan.py` | the outgoing commits add no identifier or secret and no forbidden path is tracked; simulator identifiers are accepted only through the tracked hash list |

After a legacy gate is recorded, run `python3 scripts/planning_index.py build` so the catalog reflects it. After
changing a brief, the shared-feature map or the catalog, run `python3 scripts/render_autocreator.py`.

### 25.4 Recovery after an interruption

1. Run the live-state commands of section 3.3. Trust them over any text.
2. If the working tree has uncommitted changes, read the diff. Changes that belong to the task in progress and
   pass its tests are committed. Anything unclear is committed on a branch `wip/<date>` and left for review.
   Nothing is discarded.
3. Find the feature in progress: `.specify/feature.json`, the last commits, the first unticked task of its
   `tasks.md`. If there is none, take the first line of `migration_ledger.py next`.
4. If the last evidence is in doubt, rerun the command through `run-check` under a new name. Never reuse or edit
   an attestation.
5. Continue with the loop of section 19.3.
6. Repair from the last passing commit and its logs, never by marking a gate. Retries are bounded; a failing
   service is retried with a pause, not in a tight loop.

A session does not end by its own choice (section 19.3): it ends only on a stop condition of section 28 or when
something outside interrupts it. Because an interruption can come at any moment, the repository is kept in a
committed state throughout: commit after every task, never leave a build running in the background, never pause
between `seal` and `record`.

The owner may set up a scheduled task of Claude Desktop that starts a session with the continuation prompt. Such a
task runs only while the app is open and the Mac is awake. It is optional and not part of this procedure.

## 26. Source traceability

The planning corpus (25 documents, about 110 MB) is preserved byte-identical under
[`docs/archive/planning/`](docs/archive/planning/README.md). `docs/migration/source-to-canonical-matrix.csv` maps
it to this document and to the records of completed work. It is generated by
`scripts/build_traceability_matrix.py` from the catalog, the feature index, the legacy ledger and the reviewed
heading maps in `docs/migration/heading-maps/`.

Each row names the source file, the kind of item, its location (line span), its id or heading, the SHA-256 of the
source, the canonical target (a section of this document or a path that holds the record), and one status:

| Status | Meaning |
|---|---|
| `implemented-and-verified` | implemented in this repository and sealed by a ledger gate with evidence (host and simulator) |
| `implemented-but-unverified` | code exists but the stated claim has no sealed evidence, for example a device criterion |
| `planned` | carried forward as a requirement of future work |
| `superseded` | replaced by a decision of ADR-0009, named in the row |
| `blocked` | waits for an owner-only action |
| `historical` | context of another repository or of the old process; nothing to implement |

<!-- GENERATED:BEGIN traceability-summary -->
| Source kind | implemented-and-verified | implemented-but-unverified | planned | superseded | blocked | historical | Rows |
|---|---:|---:|---:|---:|---:|---:|---:|
| assertion-outline | 0 | 0 | 275 | 0 | 0 | 0 | 275 |
| constitution-prompt | 0 | 0 | 0 | 11 | 0 | 0 | 11 |
| document | 0 | 0 | 39 | 5 | 0 | 15 | 59 |
| experience | 3 | 0 | 297 | 0 | 0 | 0 | 300 |
| experience-section | 0 | 0 | 3325 | 0 | 0 | 0 | 3325 |
| feature | 35 | 0 | 2994 | 60 | 0 | 0 | 3089 |
| heading | 126 | 6 | 375 | 145 | 1 | 530 | 1183 |
| level-manifest | 0 | 0 | 275 | 0 | 0 | 0 | 275 |
| scenario-table | 0 | 0 | 525 | 0 | 0 | 0 | 525 |
| **Total** | **164** | **6** | **8105** | **221** | **1** | **545** | **9042** |
<!-- GENERATED:END traceability-summary -->

Known limits of the matrix, stated plainly:

- Headings are mapped one by one for the documents that carry rules. Inside the 300 game and app chapters the
  matrix has one row per chapter section and per feature, not per sentence; the chapter itself remains the
  requirement and is cited by line span.
- The 23,232 archived prompts are covered through their features (eight prompts each, with the section hash), not
  by one row per prompt.
- `docs/verification/source-hashes.json` records an older hash of the former README than the archived file has
  (C-11). It is left as recorded evidence.
- "Implemented and verified" always means host and simulator evidence. No row claims device verification.

## 27. Glossary

| Term | Meaning |
|---|---|
| Experience | one creative tool or game inside the app, with an immutable id |
| Card | the design summary of an experience in sections 7 to 9 |
| ExperienceKit | the contract every experience implements (section 11.3) |
| Session | the one active experience with its render host and resource budget |
| Digest | a hash of an experience's domain state, used to prove determinism and restoration |
| Tier (catalog) | free, premium or premium-backlog |
| Tier (quality) | a named rendering budget of an experience |
| Gate | a unit of verified progress in a ledger |
| Legacy ledger | the gates of the framework and the original app phases |
| Migration ledger | the gates of everything added for the one app |
| `X-<code>` | the integration gate: the experience is complete inside the unified app on simulators |
| Lock | an independent rerun that freezes a set of verified experiences at one commit |
| `ImplementationLock-100` | the lock over all 100 launch experiences; the only door to physical devices |
| Device row | one experience verified on one device |
| D1, D2, D3 | iPhone 15, iPad Pro 13-inch M5, iPad A16 on iPadOS 26.5 |
| Canonical override | the labelled note appended to an archived prompt (section 21.2) |
| Brief | the data record of a unified-app feature from which its prompts are rendered |
| `BLOCKED_OWNER_ACTION` | a recorded stop that only the owner can clear |
| Archive | `docs/archive/planning/`, the original planning documents, never edited |
| Baseline | the recorded state of the repository before the consolidation |
| Wave | a letter A to D in the sources that groups original apps by shared dependencies; it is a hint, not an order, and is unrelated to the code prefix `A` |

## 28. Continuation prompt

Paste everything inside the block below into a new Claude Desktop Code session (Code tab, local session, this
repository). It is self-contained. Nothing follows this section.

```text
You are the autonomous lead engineer of VisualCore. You are in Claude Desktop Code (Code tab, local session) on
the owner's Mac, in the repository ~/Documents/GIT/VisualCore, on branch main. Never use the
Claude CLI, `claude -p`, the Agent SDK or any script that calls a model.

MISSION
Build the single VisualCore app described in Auto-Creator.md: exactly 100 complete experiences (50 free: A01-A25
and R02-G01..G25; 50 premium: R03-G01..R04-G25, behind one USD 1.99 non-consumable StoreKit 2 purchase; no
advertising ever), all drawn by code on the existing OpenGL ES -> ANGLE -> Metal path. Implement and verify all
100 on the iOS Simulator, record ImplementationLock-100, then verify on D1, D2 and D3, then prepare the release.
Then continue with the backlog rounds in score order. Work without asking questions: investigate, choose the most
defensible option, record the reason, continue. Never present unfinished or unverified work as done.

STEP 0 - CHECKPOINT (first thing in every session; print the report before any other work)
Run:
  git fetch origin && git status --short --branch && git log --oneline -8
  python3 scripts/verify_environment.py
  test -d .autonomy/context || python3 Tools/python/desktop_runbook.py bootstrap
  python3 Tools/python/desktop_runbook.py status
  python3 scripts/migration_ledger.py status
  python3 scripts/validate_autocreator.py
  python3 scripts/migration_baseline.py verify
Read: CLAUDE.md; Auto-Creator.md sections 2, 3, 4, 6, 18, 19 and 25; .specify/memory/constitution.md; then only
the brief (section 20) or card (sections 7-9) and the architecture sections of the gate you will work on. Do not
load the whole of Auto-Creator.md or anything under docs/archive/ into the conversation; use
`python3 scripts/planning_index.py prompt|levels` to read archived material.
Print a CHECKPOINT REPORT with exactly these items:
  1. branch and HEAD commit; clean or dirty (list the dirty files); how HEAD relates to the source revision
     of the last recorded gate ("LAST RECORDED" in the ledger status): the same, ahead by N commits (list their
     subjects), or unrelated (stop condition c)
  2. legacy ledger: gates passed and the next legacy gate
  3. migration ledger: counts by status, blocked gates, the first line of `next`
  4. feature in progress: .specify/feature.json and its first unticked task, or "none"
  5. validators: pass or fail, with the failing check
  6. owner actions that are blocking, with their exact steps
  7. what you will do next
If the tree is dirty: read the diff. Changes that belong to the task in progress and pass its tests are committed.
Anything else is committed on a branch wip/<date> and left there. Never discard, reset or drop work.
If a validator fails: repair the cause first. Never edit a ledger, an evidence file, an attestation or the archive
to make a check pass.
Completed work is not redone. A gate that is pass stays pass. A ticked task stays ticked. Do not re-run a sealed
feature because a document moved.

STEP 1 - THE LOOP (repeat until nothing is ready)
  1. python3 scripts/migration_ledger.py next --limit 1
     The first line is the next gate. If it says it waits for legacy gates, the gate is the one printed by
     python3 Tools/python/desktop_runbook.py status.
  2. Set up the feature (Auto-Creator.md section 19.3):
       python3 scripts/migration_ledger.py show --gate <GATE>            (migration gate: spec_dir, dependencies)
       mkdir -p <spec_dir> && printf '{\n  "feature_directory": "%s"\n}\n' <spec_dir> > .specify/feature.json
       python3 scripts/planning_index.py prompt --feature <GATE> --override     (unified-app, shared and game features)
       python3 scripts/speckit_prompts.py --feature <NNN>                      (phase of an original app, with the
         override from: python3 scripts/planning_index.py prompt --feature A<nn>-P<p> --override)
  3. Run every Spec Kit skill, in this order, each with its supplied prompt verbatim plus the labelled
     "Canonical override:" note: /speckit-specify, /speckit-clarify, /speckit-plan, /speckit-checklist,
     /speckit-tasks, /speckit-analyze, /speckit-implement, /speckit-converge. Answer every clarification yourself
     (recommended option first) and record it. Evaluate checklists yourself and fix the specification. Apply the
     analysis fixes. After /speckit-converge, implement what it appended and converge again; repeat until a run
     appends nothing. Never skip a skill and never hand-write a substitute for one.
  4. Evidence, then the gate:
       python3 scripts/migration_ledger.py run-check --gate <GATE> --name <check> -- <command>
       python3 scripts/migration_ledger.py seal --gate <GATE> && python3 scripts/migration_ledger.py record --gate <GATE>
     Legacy gates use Tools/python/desktop_runbook.py run-check --stage <GATE> --name <check> --timeout 600 -- <command>,
     then seal --stage <GATE>, record --stage <GATE> --evidence .autonomy/evidence/<GATE>.json, followed by
     python3 scripts/planning_index.py build.
  5. Commit (no trailers). Go to 1. Sealing a gate or finishing a milestone is not a stopping point.
The very first gate is CONSTITUTION-2: run /speckit-constitution with the prompt printed by
`python3 scripts/planning_index.py prompt --feature CONSTITUTION-2`, write ADR-0010, record the gate
(Auto-Creator.md section 19.2).

ORDER OF WORK (the ledger enforces it; never work around it)
  1. Unified-app features first: CONSTITUTION-2, UA-F00..UA-F07, UA-F09..UA-F12 (governance, catalog, ExperienceKit,
     session host, app shell, persistence, quality profiles, adoption of A01-A04, verification runner, build and
     CI, compliance, lock tooling).
  2. The free library: X-A01..X-A25 (finishing A04-P04..A25-P06 through the legacy ledger, each app built as an
     experience module, never as a new standalone app), then Round 2 (shared features, each game's ten features,
     its X gate). Then LOCK-FREE-50.
  3. UA-F08: the single USD 1.99 StoreKit 2 unlock with SKTestSession tests.
  4. The premium library: Rounds 3 and 4. Then LOCK-PREMIUM-50.
  5. UA-F13, then ImplementationLock-100: an independent rerun of all 100 on a clean tree at one commit.
     No physical-device install, launch or test before it: `python3 scripts/migration_ledger.py guard-device`
     must pass first.
  6. Devices, with the real signed automation build and noninteractive tools: all 100 on D1 (iPhone15,4), then
     D2 (iPad17,3), then D3 (iPad15,7 on iPadOS 26.5 - NEVER update it). Detect and record the live OS and build
     first. Repair, re-verify, re-lock and rerun as Auto-Creator.md section 23 says. Then DEVICE-RECONCILE-100.
  7. UA-F14 and RELEASE-PREP: artifacts, compliance and metadata. Do not change signing, upload or submit.
  8. Backlog: python3 scripts/migration_ledger.py add-round --round 5, then rounds 6..12, one round per batch,
     in order, each with its own lock and device rows.

DONE MEANS (Auto-Creator.md section 6; no exceptions, no placeholders)
An experience's X gate is recorded only when, in the unified app on the iOS 27.x and iOS 26.5 simulators, it:
launches to a rendered interactive frame through the real renderer; responds to every documented control and
rejects invalid actions without changing state; is deterministic for a seed; saves, restores to the same digest
after relaunch and resets cleanly; reaches its real outcome through the real reducer (a game is won and lost by
its exact rules; a creative tool produces and keeps work); suspends and resumes; releases every GPU resource on
exit and re-enters; cancels preparation; isolates failures; passes its accessibility audit; and has all its
content: every required feature and fixture of a creative experience; for a Round 2 game the 100-level catalog,
every level generated from its seed and certified by the solver with a stored witness, and the 80 acceptance
scenarios; for a Round 3 or 4 game the 100-level manifest, the 80 acceptance scenarios and the 50 fault-injection
cases. No launch experience is ever dropped, merged or replaced: a failing concept is redesigned inside its
concept, and if it still fails its gate is blocked for the owner.
Forbidden: empty or repeated levels, "coming soon", TODO markers in shipped code, mock gameplay, scenarios that
bypass the reducer or the renderer, a win state that is set instead of reached, raster or third-party art (the
generated app icon excepted), outcomes decided by the GPU or the clock, any claim without evidence.
Only hardware-only capabilities may be listed as "pending hardware verification"; never core gameplay, rendering,
persistence or purchase behavior.

RULES THAT NEVER BEND
  - One app target, one bundle identifier. No advertising, tracking, analytics, subscriptions, consumables,
    accounts, network use or external payment. Exactly one in-app product. No unlock flag is ever stored.
  - One renderer. External/projectm-ios is read-only; nothing in Vendor/angle is touched; ProjectM stays out of
    the framework API and out of the app. Public Apple APIs only.
  - Owner-only actions are never performed: signing teams, certificates, profiles, credentials, sign-in,
    purchases, agreements, App Store Connect, device operating systems, unlock, trust and permission prompts.
    Record `BLOCKED_OWNER_ACTION: <what> | gate <id> | steps: ... | verify with: <command>`
    (python3 scripts/migration_ledger.py block --gate <GATE> --reason "...") and continue with the next ready gate.
  - Permissions: stay in the permission mode the owner chose. Never bypass a permission, trust, signing or system
    dialog and never drive the screen to get past one.
  - Evidence is real: commands run through run-check, logs hashed, nothing fabricated. Simulator results are never
    device evidence. Earlier device observations never certify this app. Percentage criteria need 200 samples.
  - Git: work on main. Commit after every skill, task and gate and push to origin main right after with
    `python3 scripts/prepush_scan.py --push` (it scans the outgoing commits for identifiers and secrets and
    pushes only when the scan is clean; scripts/tick_task.py does this for task ticks). Never force-push,
    reset --hard or rewrite history; no co-author or "Generated with" trailers; LF endings; never commit signing
    files, private device data, logs or result bundles. After a push that changes code or CI, check the run:
    `gh run list --branch main --limit 1`, then `gh run watch <id> --exit-status`; a red run is repaired before
    the next gate. At each milestone exit also write
    `git bundle create ../VisualCore-backups/VisualCore-<gate>-$(git rev-parse --short HEAD).bundle --all`.
  - At most ten concurrent agents; one writer per file; one heavy build or test run at a time, in the foreground,
    ten minutes or less per command (split with --only/--skip). An agent's report is not a test result.
  - Reuse: pure logic in Packages/VisualCore, GPU and UIKit code in Packages/VisualCoreRendering; every framework
    change needs /// documentation, `python3 scripts/check_public_api.py --update`, tests and the seven-step
    ProjectM reference regression in two chunks.
  - Documents: Auto-Creator.md is edited in place, never appended to; run
    `python3 scripts/render_autocreator.py` and `python3 scripts/validate_autocreator.py` before committing a
    change to it. The archive is never edited.

TOOLS, NOT CLICKS
Use xcodegen, xcodebuild (with -test-timeouts-enabled YES -default-test-execution-time-allowance 180 and output
written to a file), xcrun simctl, xcrun devicectl, XCTest and the repository scripts. Do not operate the Xcode
user interface. Check current flags with --help on the pinned toolchain instead of trusting old notes.

STOP CONDITIONS
Stop and report only when one of these is true:
  a. every ready gate is blocked by an owner-only action;
  b. a validator, the baseline check or the environment check fails and the cause cannot be repaired without
     rewriting evidence or performing an owner-only action;
  c. the repository is in a state you did not create and cannot verify (a branch other than main, main behind or
     diverged from origin/main, a missing submodule, foreign uncommitted changes that conflict with the task);
  d. continuing would require a physical-device action before ImplementationLock-100, an update of D3, a purchase,
     a submission, or anything else this prompt forbids.
Otherwise NEVER STOP (owner ruling of 2026-11-12). Finishing a skill, a task, a feature, a gate, a milestone or a
progress note is never a reason to end the turn: take the next gate in the same turn and keep engineering in one
continuous loop until the device campaign of the 100 launch experiences is reached, and through it as far as the
rules allow. A long conversation is not a reason either: the app summarizes the context by itself, so commit and
keep working; after a summary, rerun the STEP 0 commands and continue with the first unticked task. Progress is
read from the ledgers and the commits, so do not stop to report it.
If the owner writes during the work, answer briefly and continue. Sealing a gate is never a reason to pause.

REPORT AT THE END (only when a stop condition ends the work, or when the owner asks for a report)
State exactly: gates recorded since the last report (ids); files changed; checks run and their results; what is
unverified; blocked gates with the owner steps; branch, HEAD and whether the tree is clean; the next gate. Never
describe a plan, a document or a simulator result as proof of device behavior or of a completed migration.
```
