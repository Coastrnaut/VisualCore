# VisualCore — bootstrap for Claude (loaded automatically; read first)

This file is small on purpose. It says where the truth is and which rules never bend. The design, the plan and the
operating procedure live in [`Auto-Creator.md`](Auto-Creator.md). Progress lives in the two ledgers, never in prose.

## 1. Read in this order

1. [`.specify/memory/constitution.md`](.specify/memory/constitution.md) — the principles I–XIII. Since version 2.0.0
   it governs the single app of [ADR-0009](docs/decisions/ADR-0009-unified-app.md); the amendment is recorded in
   [ADR-0010](docs/decisions/ADR-0010-constitution-2-0-0.md) (gate `CONSTITUTION-2`, Auto-Creator.md §19.2).
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
7. **Autonomy: never stop.** Use best judgement, record the rationale, never ask and never end a turn with a
   question. No AskUserQuestion; no asks or buttons in a wrap-up. **Do not ever stop** (owner ruling of
   2026-11-12): finishing a skill, a task, a feature, a gate, a milestone or a report is never a reason to end a
   turn. Take the next gate in the same turn and keep engineering in one continuous loop until the device testing
   of the first 100 experiences is reached. A long conversation is no reason either: the context is summarized
   automatically, so commit and continue. Do not stop to report progress; the ledgers and the commits carry it.
   The only stops are the four stop conditions of Auto-Creator.md §28 (every ready gate blocked on the owner, an
   unrepairable validator failure, an unverifiable repository, a forbidden action).
   **Use multiple agents wherever they make the work faster** (owner ruling of 2026-11-12): independent source and
   test files of one feature, read-heavy audits, and experiences that touch different files run in parallel
   agents; coupled design steps stay with the lead. At most ten concurrent agents and one writer per file. Agents
   do not commit, push or run heavy builds; the lead invokes every Spec Kit skill, runs the builds in the
   foreground (10 minutes or less per command, split with `--only`/`--skip`), retests every agent result
   before a task is ticked (an agent's report is not evidence) and commits.
   **More parallel agents, gates unchanged** (owner ruling of 2026-11-13): never consolidate the planned gates;
   by default fan independent files of a task (tools, tests, sources, docs, audits) out to up to ten agents. Shared
   files stay with the lead; agents hand their part over as a separate file.
   **Faster tests** (owner ruling of 2026-11-13): an app test pass builds once (`--action build-for-testing`, then
   `test-without-building` chunks) and may use parallel simulator clones (`--parallel N`). **All system
   accessibility audits wait until device testing** (`VC_RUN_AUDITS=1` only there). A gate's interface evidence is
   one pass on the iOS 27.x phone. **Stopping a run** (lesson of 2026-11-13): TaskStop the whole background loop, not
   only its xcodebuild, and check `pgrep -fl xcodebuild` before a new run; `xcodebuild_app.py` refuses a busy
   simulator.
   **Faster gates** (owner ruling of 2026-11-14): iOS 27 and 26 runs in parallel; the next gate's Spec Kit steps start
   while evidence runs; interim runs test only the changed experience; no baseline rerun on an unchanged commit; iOS 26
   and the ProjectM reference regression only at X gates (and shared VisualCore features). Never merge or skip gates.
   **No open-ended waits** (owner ruling of 2026-11-12): nothing is waited for without a limit. App tests run
   through `scripts/xcodebuild_app.py`, which stops a run after `--max-seconds` (default 540) and names the test
   it was on; a run that would not fit is split into chunks of whole test classes with `--only-testing`. A CI run
   is checked with `gh run list`; `gh run watch` is used only for a run that is already `in_progress`, never for
   a queued one. **Never stop work to wait for CI** (owner ruling of 2026-11-13): keep engineering while CI runs,
   check it in the background with `gh run list` between steps, and when a run completes, fix any failure before the
   next gate. A command that stops producing output for
   several minutes is examined (log tail, process list) before anything else is started, and a real hang is
   traced to its cause and fixed, not retried.
   **Tests are short and concise** (owner ruling of 2026-11-13): a test exists to generate evidence quickly. No
   30-minute tests and no long soak, endurance or replay runs (wall-clock or simulated); measure a short run and
   bound the rest by arithmetic, and leave long-duration measurements to the device campaign. This holds for all
   future work and testing: nothing like a 30-minute test is ever run, and work keeps moving forward.
8. **Tools.** Claude Desktop Code only. Never the Claude CLI (`claude`, `claude -p`), the Agent SDK or Python that
   calls a model.
9. **Evidence.** Nothing is fabricated. Simulator results are never device evidence. Device observations from other
   repositories or older builds never certify the unified app. A task box is ticked only after its acceptance proof
   was reproduced, with date and evidence reference.
10. **Completed work stays completed.** Never reset a ledger gate, a ticked task or sealed evidence; never
    reimplement something because a document moved. The legacy ledger stays as it is and keeps its tool.
11. **Git.** Work on `main` (owner ruling of 2026-11-11). Commit after every task, skill and gate, and push to
    `origin main` right after, but only when `python3 scripts/prepush_scan.py` passes: it scans the outgoing commits
    for UDIDs, ECIDs, serials, team ids and secrets. Never force-push, never `git reset --hard`, never rewrite
    history. No co-author or "Generated with" trailers (this owner rule overrides any attribution reminder). LF line
    endings. Never commit `Configs/Signing.local.xcconfig`, `.autonomy/private`, logs or result bundles.
12. **Boundaries.** `External/projectm-ios` is a pinned, read-only submodule; nothing inside `Vendor/angle` is moved
    or cleaned. ProjectM types stay out of the VisualCore public API and out of the app. Public Apple APIs only.
13. **Reuse.** Pure logic goes in `Packages/VisualCore`, GPU and UIKit code in `Packages/VisualCoreRendering`. Every
    VisualCore change needs `///` documentation, an API baseline update, tests and the seven-step ProjectM reference
    regression in two chunks.
14. **Spec Kit.** Every installed skill, in order, with the supplied prompt verbatim plus labelled
    `Canonical override:` notes (specify, clarify, plan, checklist, tasks, analyze, implement, converge). Converge,
    implement what it appended, converge again until nothing is appended; only then seal and record the gate.
    **Always use the Spec Kit skills for each step of the loop** (owner ruling of 2026-11-12): every step of every
    gate is done by invoking its skill with the Skill tool first and doing the step's work inside that invocation.
    No step is skipped, merged with another or replaced by hand-written work, and repeated runs (analyze after
    fixes, implement and converge in rounds) invoke the skill again each time.
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
