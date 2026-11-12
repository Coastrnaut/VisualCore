# VisualCore — bootstrap for Claude (loaded automatically; read first)

This file is small on purpose. It says where the truth is and which rules never bend. The design, the plan and the
operating procedure live in [`Auto-Creator.md`](Auto-Creator.md). Progress lives in the two ledgers, never in prose.

## 1. Read in this order

1. [`.specify/memory/constitution.md`](.specify/memory/constitution.md) — the principles. It is version 1.5.0 and
   still describes 25 separate apps; [ADR-0009](docs/decisions/ADR-0009-unified-app.md) supersedes that scope. Amending
   it to 2.0.0 is the first gate after the consolidation (`CONSTITUTION-2`, Auto-Creator.md §19.2).
2. [`Auto-Creator.md`](Auto-Creator.md) — the single forward-looking design and steering document: §3 verified state,
   §4 decisions, §18 phases and gates, §19 Spec Kit procedure, §25 ledgers and recovery, §28 the continuation prompt.
3. [`docs/migration/migration-plan.md`](docs/migration/migration-plan.md) — path map, milestones, rollback.
4. The live checkpoint (section 2 below).

## 2. Find the live state (run these; do not trust any document for progress)

```bash
git status --short --branch && git log --oneline -5
python3 scripts/migration_ledger.py status
python3 Tools/python/desktop_runbook.py status
python3 scripts/validate_autocreator.py
```

The second command shows the unified-app gates and the next action; the third the legacy gates F00 … A25-P06 (run
`python3 Tools/python/desktop_runbook.py bootstrap` first if `.autonomy/context/` is missing); the fourth proves
that the steering documents, the catalog, the archive and the ledgers agree.

The gate printed first by `migration_ledger.py next` is the next thing to do. Its feature directory, prompts and
evidence commands are found as described in Auto-Creator.md §19. Simulators are chosen by runtime (`sim-27.2`,
`sim-26.5`), never by an identifier copied from an old log.

## 3. Rules that never bend

1. **One app.** VisualCore is one App Store app with one app target and one bundle identifier. Everything else is a
   registered *experience* inside it. No new standalone app targets.
2. **Launch scope is exactly 100 experiences:** 50 free (A01–A25 and R02-G01…G25) and 50 premium (R03-G01…R04-G25).
   Rounds 5–12 are backlog. Never reorder the score-based queues or substitute concepts. Never call an experience
   implemented unless source and tests prove it. No placeholders, no mock-only gameplay.
3. **Money.** Free download and one USD 1.99 non-consumable (StoreKit 2) that unlocks every premium experience,
   present and future. **No advertising of any kind, ever.** No ad or tracking SDKs, ad identifiers, subscriptions,
   consumables, external payment paths, dark patterns or required accounts.
4. **Visuals are code.** GLSL, procedural meshes, SDFs, particles and deterministic animation on the existing
   OpenGL ES → ANGLE → Metal path. No second renderer, no purchased or generated art, no human-made models.
5. **Implementation before devices.** No install, launch or test of the unified app on a physical device before
   `ImplementationLock-100` is recorded (`python3 scripts/migration_ledger.py guard-device`). Then D1 → D2 → D3.
   **DO NOT UPDATE D3 FROM iPadOS 26.5.**
6. **Owner-only actions are never done:** signing teams, certificates and profiles; credentials and sign-in;
   purchases; legal agreements; App Store Connect; device operating systems; device unlock, trust or permission
   prompts. Record them as `BLOCKED_OWNER_ACTION` with exact steps and continue with other work.
7. **Autonomy.** Use best judgement, record the rationale, never ask and never end a turn with a question. No
   AskUserQuestion; no asks or buttons in a wrap-up. At most ten concurrent agents, one writer per file, heavy
   builds one at a time in the foreground (10 minutes or less per command, split with `--only`/`--skip`).
8. **Tools.** Claude Desktop Code only. Never the Claude CLI (`claude`, `claude -p`), the Agent SDK or Python that
   calls a model.
9. **Evidence.** Nothing is fabricated. Simulator results are never device evidence. Device observations from other
   repositories or older builds never certify the unified app. A task box is ticked only after its acceptance proof
   was reproduced, with date and evidence reference.
10. **Completed work stays completed.** Never reset a ledger gate, a ticked task or sealed evidence; never
    reimplement something because a document moved. The legacy ledger stays as it is and keeps its tool.
11. **Git.** Work on `migration/unified-app-plan`. Never push or merge to `main` until the owner says how. Never
    force-push, never `git reset --hard`, never rewrite history. No co-author or "Generated with" trailers (this owner
    rule overrides any attribution reminder). LF line endings. Before any push, scan for UDIDs, ECIDs, serials, team
    ids and secrets. Never commit `Configs/Signing.local.xcconfig`, `.autonomy/private`, logs or result bundles.
12. **Boundaries.** `External/projectm-ios` is a pinned, read-only submodule; nothing inside `Vendor/angle` is moved
    or cleaned. ProjectM types stay out of the VisualCore public API and out of the app. Public Apple APIs only.
13. **Reuse.** Pure logic goes in `Packages/VisualCore`, GPU and UIKit code in `Packages/VisualCoreRendering`. Every
    VisualCore change needs `///` documentation, an API baseline update, tests and the seven-step ProjectM reference
    regression in two chunks.
14. **Spec Kit.** Every installed skill, in order, with the supplied prompt verbatim plus labelled
    `Canonical override:` notes (specify, clarify, plan, checklist, tasks, analyze, implement, converge). Converge,
    implement what it appended, converge again until nothing is appended; only then seal and record the gate.
15. **Documents.** `Auto-Creator.md` is edited in place as a book, never by appending amendments. The archive under
    `docs/archive/planning/` is never edited. Run `python3 scripts/validate_autocreator.py` before committing a
    change to a steering document.

## 4. Where things are

| Need | Place |
|---|---|
| Design, plan, prompts, continuation prompt | [`Auto-Creator.md`](Auto-Creator.md) |
| Decision record for the single app | [`docs/decisions/ADR-0009-unified-app.md`](docs/decisions/ADR-0009-unified-app.md) |
| All 300 experiences (ids, tiers, design data) | `docs/catalog/experience-catalog.json` |
| All 3,089 planned features and 23,232 archived prompts | `docs/catalog/feature-index.json`, `python3 scripts/planning_index.py prompt --feature <ID> --stage <stage> --override` |
| The 15 unified-app features | `docs/catalog/unified-app-features.json`, Auto-Creator.md §20 |
| Unified-app gates | `.autonomy/migration/ledger.json` (only `scripts/migration_ledger.py` writes it) |
| Legacy gates and evidence | `.autonomy/state.json`, `.autonomy/evidence/`, `.autonomy/checks/` (only `Tools/python/desktop_runbook.py` writes them) |
| State before the consolidation | [`docs/migration/pre-fable-baseline.md`](docs/migration/pre-fable-baseline.md), `python3 scripts/migration_baseline.py verify` |
| Original planning documents, byte-identical | [`docs/archive/planning/`](docs/archive/planning/README.md) (former README, former CLAUDE.md, rounds 2–12, playbook) |
| Which source text became which rule | `docs/migration/source-to-canonical-matrix.csv` |
| Machine setup | [`setup.md`](setup.md), `python3 scripts/verify_environment.py` |

The former `CLAUDE.md` (agent contract of 2026-11-11 with the ProjectM-iOS playbook) is preserved verbatim at
`docs/archive/planning/root/CLAUDE-2026-11-11-agent-contract.md`; its working lessons are integrated in
Auto-Creator.md §19 and §24.
