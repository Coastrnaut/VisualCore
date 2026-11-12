# ADR-0009 — One VisualCore app with registered experiences, one purchase, and a 100-experience simulator gate

**Date:** 2026-11-11 · **Status:** accepted (owner directive of 2026-11-11, "State-Safe Consolidation and
Unified-App Migration Plan"). The constitution still has to be amended to match (gate `CONSTITUTION-2`); until then
this ADR prevails over the scope statements of constitution 1.5.0 wherever the two disagree.

This ADR records decisions. It changes no source code. Nothing in it is evidence that the unified app exists: at
the time of writing the repository contains four standalone creative apps (three complete, one partial), the
VisualCore framework and no game.

## Context

Until 2026-11-11 the plan was a *suite*: 25 separately shipped creative apps (the former `README.md`) followed by
eleven rounds of 25 separately sold puzzle games (`round2.md` … `round12.md`, "$2.99", "no in-app purchases"), each
round gated by a full physical-device campaign of the previous one. Thirty-five gates of that plan are sealed
(F00–F09 and A01-P00 … A04-P03); see [the baseline](../migration/pre-fable-baseline.md).

On 2026-11-11 the owner redirected the project: one app, one purchase, no advertising, all first-release content
implemented and simulator-verified before any device campaign, and one steering document. The planning corpus
(about 110 MB in 25 files) contained rules that contradict that direction and contradict each other. This ADR fixes
the decisions; `Auto-Creator.md` carries the design that follows from them.

## Decisions

### D-01 One app

There is one App Store app, publicly named **VisualCore**, with one shippable app target and one bundle identifier.
The 25 original creative apps and every round game are **experiences**: internally registered modules reached from
a unified launcher with common settings. The Showcase and the harnesses remain non-shipping development targets.
The name's availability is not verified and the bundle identifier is a placeholder (`dev.visualcore.VisualCore`);
both are owner decisions before distribution (OD-01, OD-02).

*Alternatives rejected:* keeping separate apps (contradicts the directive; 300 store records, 300 signing and review
cycles); a "hub" app that links out to separate apps (still many apps, breaks the single purchase).

### D-02 Launch scope: exactly 100 experiences

| Tier | Experiences | Source |
|---|---|---|
| Free forever (50) | A01–A25 | the 25 original creative apps |
| | R02-G01 … R02-G25 | Round 2 games (candidates ranked 1–25 of the 500-candidate study) |
| Premium (50) | R03-G01 … R03-G25 | Round 3 (ranked 26–50) |
| | R04-G01 … R04-G25 | Round 4 (ranked 51–75) |
| Backlog (200) | R05 … R12 | later premium additions, kept in descending score order |

The first release contains all 100, complete. The queues are not reordered and concepts are not substituted. The
content target of every Round 2 game is 100 solver-certified levels, which is that document's own latest revision
(the earlier figure of 80 remains a milestone inside the game's features).

### D-03 Monetization

Free download. Exactly one in-app purchase: a **non-consumable at USD 1.99** that unlocks the whole premium library,
including premium experiences added later. No advertising under any circumstances; no ad or tracking SDK, ad
identifier, rewarded ad, subscription, consumable, external payment path, dark pattern or required account. Prices
in other storefronts are whatever the owner configures in App Store Connect for the USD 1.99 base price.

Purchases made in the separate ProjectM-iOS app do not carry over: App Store entitlements belong to an app's own
products and cannot be transferred to another app. Nothing in VisualCore may suggest otherwise.

Family Sharing of the unlock is an owner decision (OD-03); the entitlement logic must handle family-shared ownership
and its revocation either way.

### D-04 Entitlement architecture

StoreKit 2 only. Entitlement is derived at run time from verified transactions (`Transaction.currentEntitlements`
at start and `Transaction.updates` while running); an unverified result never unlocks. No unlock flag is persisted
anywhere. Restore is `AppStore.sync()` behind an explicit button. Revocation and refunds lock the premium library
again. A previously verified entitlement works offline; a device that never purchased shows an honest locked state.
Free experiences never query the store and work when StoreKit is unavailable.

Premium is gated twice: at routing (the launcher will not navigate) and at session activation (the host will not
activate). Automation reaches premium experiences only through an entitlement fixture compiled under `DEBUG` or
`VISUALCORE_AUTOMATION`; the shipping Release binary must contain no fixture symbol or string (checked with `nm`
and a string scan). Local tests use `SKTestSession` with a `.storekit` file that holds exactly one product.

### D-05 ExperienceKit and one session host

Every experience implements one contract: deterministic `prepare(seed:)`, activate, fixed-step update, draw, input,
snapshot, restore, reset, suspend, resume, deactivate, diagnostics and automation hooks. The contract adapts the
existing VisualCore surfaces (`RenderScene`, `RenderHost`, `FixedStepRunner`, `DocumentStore`, `MigrationChain`,
`QualityPolicy`, `AutomationRunner`); it does not replace them. One session is active at a time, owns its GPU
resources through a budgeted registry, and proves zero live resources after deactivation. A failure in one
experience shows a recoverable failure view and never takes the app down. Names of new types are proposals until
`/speckit-plan` confirms them against real code.

### D-06 Modules, packages and identity

A small set of SwiftPM packages: the two existing framework packages (extended by new modules) and one experience
package per collection (`ExperiencesCreative`, `ExperiencesRound02`, `ExperiencesRound03`, `ExperiencesRound04`),
each experience contributing a pure core target and an experience target. Experiences depend only on the framework
and never on each other. Finer or coarser module granularity needs a measurement (clean and incremental build time,
app size) and a new ADR.

Every experience has an immutable code (`A01`, `R02-G01`) and an immutable runtime id `<code-lowercase>.<slug>`
(`a01.generative-art-studio`, `r02-g01.aurora-loom`) defined in `docs/catalog/experience-catalog.json`. Storage
namespaces, accessibility identifiers, evidence files and ledger gates are derived from them. Round 2's source ids
(`R2-…`) are normalized to `R02-…`; the source spelling is kept as an alias in the index.

### D-07 All 100 on the simulator before any device

No physical-device install, launch or test of the unified app happens until all 100 launch experiences are
implemented and pass host and iOS Simulator acceptance, and an independently rerun verification confirms 100 of 100
on one locked commit. That state is recorded as the gate **`ImplementationLock-100`** by
`scripts/migration_ledger.py` and nowhere else. A capability that needs hardware may be listed as *pending hardware
verification*; missing core gameplay, rendering, persistence or purchase behavior may not. Every per-round and
per-app device prerequisite in the planning corpus is superseded by this rule.

### D-08 Device sequence

After the lock: D1 (iPhone 15, `iPhone15,4`), then D2 (iPad Pro 13-inch M5, `iPad17,3`), then D3 (iPad A16,
`iPad15,7`), 100 experiences each, 300 rows in total. The live OS, build and identifier are detected before each
campaign and recorded outside tracked files. **D3 stays on iPadOS 26.5 and is never updated.** Manual VoiceOver
testing is non-gating. Device evidence recorded for other repositories or for the standalone apps is history and
does not certify the unified build.

### D-09 Code-driven visuals on the proven renderer

All worlds and signature effects are GLSL, procedural meshes, signed-distance fields, particles and deterministic
animation on the existing OpenGL ES 3.0 → EGL → ANGLE → Metal path. No human-made models, purchased art packs,
prompt-generated images or external image services are required. The rendering path is not forked or replaced
without a documented, test-backed need. ProjectM's integration and the pinned forks are preserved and stay out of
the app.

### D-10 Document hierarchy

| Document | Role |
|---|---|
| `README.md` | public face of the repository; states only what is true today |
| `setup.md` | reproducible machine and contributor setup |
| `Auto-Creator.md` | the single authoritative forward-looking design and autonomous steering document; edited as a book |
| `CLAUDE.md` | small automatically loaded bootstrap that points to the constitution, `Auto-Creator.md`, the checkpoint and the safety rules |
| `docs/archive/planning/` | every original planning document, byte-identical, with a manifest |
| `specs/`, `docs/decisions/`, `.autonomy/`, `docs/verification/` | records of completed work; never rewritten |

### D-11 Feature numbering

| Spec directories | Features | Ids inside | State |
|---|---|---|---|
| `001`–`010` | F00–F09 foundation | `FR-F<k>##` | sealed |
| `011`–`185` | A01-P00 … A25-P06 (ADR-0004) | `FR-A<nn>-<p>##` | `011`–`035` sealed, rest pending |
| `186`–`200` | UA-F00 … UA-F14 unified-app features | `FR-U<kk>-###` | new |
| `201`–`234` | R02-F01 … R02-F34 Round 2 shared features | per the archived prompts | ten are superseded by unified features |
| `301`–`550` | R02-G<gg>-<ff> Round 2 game features | per the archived prompts | new |
| `specs/rNN-fFF-*`, `specs/rNN-gGG-FF-*` | rounds 3–12 | per the archived prompts | new |

The directories of rounds 2–12 are the ones named in the archived prompts, so those prompts run verbatim.

### D-12 Two ledgers

The legacy ledger (`.autonomy/state.json`, written only by `Tools/python/desktop_runbook.py`) keeps every
foundation and original-app phase gate with its sealed evidence and continues to be used, in its original order,
for A04-P04 … A25-P06. Its gates `IMPLEMENTATION-LOCK`, `D1-A01` … `D3-A25`, `DEVICE-RECONCILE` and `SUITE-FINAL`
describe the old 25-app suite and are superseded; they are never recorded.

The migration ledger (`.autonomy/migration/ledger.json`, written only by `scripts/migration_ledger.py`) holds every
new gate: the consolidation, the constitution amendment, 15 unified-app features, the shared and per-game features
of rounds 2–4, one integration gate per experience (`X-<code>`), three locks, 300 device rows and release
preparation. An `X-A<nn>` gate requires its seven legacy phase gates to be pass. No completed gate, ticked task or
sealed evidence file is reset by the migration.

### D-13 Git discipline during the migration

All consolidation and migration work is committed on `migration/unified-app-plan`. Nothing is pushed or merged to
`main` until the owner chooses how (OD-04). No force push, no history rewriting, no `git reset --hard`. The earlier
standing permission to push every commit to `origin main` does not apply to this branch.

### D-14 Archive instead of deletion

The planning documents were moved with `git mv` to `docs/archive/planning/` without changing a byte; a manifest
records each original path and SHA-256, and `scripts/planning_archive.py verify` proves it against the baseline.
Requirements are carried forward through the catalog, the feature index and `Auto-Creator.md`, and each is labelled
in the traceability matrix; none is dropped because it is difficult.

## Conflicts resolved (all dated 2026-11-11)

| # | Source statement | Resolution | Reason |
|---|---|---|---|
| C-01 | 25 separately buildable apps, each with a target, bundle id and store record (former README §1, §11; constitution 1.5.0 scope) | superseded by D-01 | owner directive |
| C-02 | Round games are separate paid apps at "$2.99" (supplemental candidates "$3.99") with "no in-app purchases" and "no StoreKit product queries" | superseded by D-03, D-04 | owner directive; the no-advertising and no-tracking parts are kept and strengthened |
| C-03 | Each round starts only after the previous round's 75-row device campaign | superseded by D-07 | owner directive: all 100 on the simulator first |
| C-04 | Legacy lock after 25 apps, then 75 device gates | superseded by `ImplementationLock-100` and 300 rows (D-07, D-08, D-12) | scope grew from 25 to 100 |
| C-05 | One XcodeGen target and bundle id per game; "25-target CI" (R02-F30, Rnn-F10) | one target; the build features are absorbed by UA-F10 | D-01 |
| C-06 | Per-app Phase 06 store listings, screenshots and release dossiers | the quality gates of Phase 06 stay; store-listing parts are inapplicable and move to UA-F14 for the one app | D-01 |
| C-07 | Round 2 content target 80 levels versus "revised proposed ship target is 100 solver-certified levels" | 100 | the source's own later revision |
| C-08 | Former CLAUDE.md §0 rule 4: push every commit to `origin main` | suspended on the migration branch (D-13) | high-risk restructuring, owner directive |
| C-09 | Former CLAUDE.md said "README.md is the full specification" | `Auto-Creator.md` is the steering document; the former README is archived (D-10) | owner directive |
| C-10 | Round 2 ids `R2-…` versus rounds 3–12 `Rnn-…` | canonical `R02-…`, alias kept (D-06) | one scheme for ledger and validators |
| C-11 | `docs/verification/source-hashes.json` records an older README hash than the archived README | left as recorded evidence; the archive manifest holds the current hash | evidence is not rewritten |

## Owner decisions still open

| Id | Decision | Default used until decided |
|---|---|---|
| OD-01 | Is the name "VisualCore" available and cleared for the App Store? | display name VisualCore; no claim of availability |
| OD-02 | Final bundle identifier and product identifier | placeholders `dev.visualcore.VisualCore` and `dev.visualcore.VisualCore.premium` |
| OD-03 | Enable Family Sharing for the unlock? | recommended yes; code handles both |
| OD-04 | How and when `migration/unified-app-plan` is merged to `main` | stay on the branch |
| OD-05 | May the migration branch be pushed to `origin` as a branch? | not pushed; local commits plus an outside `git bundle` at each milestone |
| OD-06 | Signing team, certificates, profiles, sandbox tester, App Store Connect record and agreements | none; device work reports `BLOCKED_OWNER_ACTION` |
| OD-07 | Minimum OS and device families | iOS and iPadOS 26.0, iPhone and iPad (current project setting) |

## Consequences

- The constitution must be amended to 2.0.0 before any new feature is specified (prompt in
  `docs/catalog/unified-app-features.json` and Auto-Creator.md §19.2), followed by ADR-0010.
- `scripts/validate_docs.py` must learn the new namespaces (UA-F00) before the first new dossier is created.
- The four standalone app targets stay as non-shipping harnesses until their experiences pass in the unified app,
  then they are retired one by one (UA-F07). Their bundle identifiers are never shipped.
- The archived prompts of rounds 2–12 remain usable only together with the canonical override notes printed by
  `scripts/planning_index.py prompt --override`, because their text still says "separate app", "$2.99" and "after
  the device campaign".
- The legacy ledger will never reach its last gate. That is intended and documented in the migration ledger.
- One binary now carries every experience: build time, binary size, launch time and memory isolation become
  first-class budgets (UA-F06, UA-F10).

## What this ADR does not decide

Tuning of individual experiences, the final launcher design, storefront prices other than the USD 1.99 base, the
release date, and anything that needs an owner account or a physical device.
