# ADR-0010 — Constitution 2.0.0: one app, one purchase, code-driven visuals, ImplementationLock-100

**Date:** 2026-11-11 · **Status:** accepted (owner directive of 2026-11-11 as recorded in
[ADR-0009](ADR-0009-unified-app.md); `/speckit-constitution` at gate `CONSTITUTION-2`)

This ADR records an amendment of the constitution. It changes no source code. Nothing in it is evidence that the
unified app exists.

## Context

Constitution 1.5.0 governed a suite of 25 separately shipped apps. Its scope paragraph, Principle V (a lock after
175 app gates, then 75 device rows), Principle VIII (a privacy manifest and justified networking for each app), its
workflow section (two ID namespaces and one ledger) and its precedence rule (the former README first) all described
that suite.

On 2026-11-11 the owner redirected the project to one app with one purchase (ADR-0009). ADR-0009 prevailed over
the scope statements of 1.5.0 until the constitution was amended, and it made the amendment the first gate after
the consolidation.

The amendment was made with `/speckit-constitution` and the single prompt of Auto-Creator.md section 19.2, which is
stored in `docs/catalog/unified-app-features.json`. The eleven per-round constitution prompts of the archive are
superseded by it (ADR-0009 C-23).

## Decision

Version 1.5.0 becomes **2.0.0** (MAJOR: the scope and Principle V are redefined). Ratified 2026-11-10, last amended
2026-11-11.

| # | Part | Change | ADR-0009 |
|---|---|---|---|
| 1 | Title and scope | "VisualCore Suite Constitution" becomes "VisualCore Constitution". The scope is the framework packages and one iPhone and iPad app with one shippable app target and registered experiences. A01–A25 and all round games are experiences, not separate apps. The Showcase and the harnesses stay non-shipping. The canonical sources are `Auto-Creator.md` and `CLAUDE.md`. | D-01, D-10, C-01, C-09 |
| 2 | Principle XI, new: One App and Stable Experience Identity | One shippable app target and one bundle identifier; no new standalone app target. Every experience has an immutable code and an immutable id `<code>.<slug>` from the catalog. Experiences depend only on the framework. ProjectM types stay out of the app. The launch set of 100 is never reduced, merged, substituted or reordered. | D-01, D-02, D-06, D-16 |
| 3 | Principle XII, new and non-negotiable: One Purchase and No Advertising | Free download and exactly one non-consumable StoreKit 2 product at USD 1.99 for every premium experience, present and future. No advertising, no ad or tracking SDKs, no ad identifiers, no rewarded ads, no subscriptions, no consumables, no external payment paths, no dark patterns, no required accounts. Entitlement comes from verified transactions and no unlock flag is stored. Premium is gated at routing and at activation. The test-only entitlement fixture is absent from shipping Release binaries. | D-03, D-04 |
| 4 | Principle XIII, new: Code-Driven Visuals | All worlds and signature effects are code on the existing OpenGL ES → ANGLE → Metal path. No experience requires human-made models, purchased art packs, prompt-generated images or external image services. | D-09, C-16 |
| 5 | Principle V, redefined: Implementation Before Devices | All 100 launch experiences pass host and simulator acceptance and `ImplementationLock-100` is recorded by `scripts/migration_ledger.py` before any device work. Then D1, D2 and D3 in that order with 100 experiences each. D3 stays on iPadOS 26.5. Historical device observations never certify the unified build. | D-07, D-08, C-03, C-04 |
| 6 | Principle VIII | One `PrivacyInfo.xcprivacy` for the app, audited against the built product. The app makes no network request of its own. Human-judgement reviews are owner reviews and do not gate. | D-15, D-17, C-06, C-13, C-15 |
| 7 | Development Workflow | The feature numbering and ID namespaces of Auto-Creator.md section 19. The legacy ledger keeps the foundation and A-phase gates; the migration ledger holds every new gate. Work is committed on `main` and pushed only after `scripts/prepush_scan.py` passes. | D-11, D-12, D-13 |
| 8 | App-Scoped Rules | The A01–A04 rules are kept. Wording about directories and targets that would be false in one app now speaks of experiences. | D-01, C-23 |
| 9 | Governance | Precedence: Apple platform and toolchain behavior and observed test results, then the owner directives (ADR-0009, `Auto-Creator.md`, `CLAUDE.md`), then the constitution and the other ADRs, then the planning archive, then generated code. Gate reviews cover Principles I–XIII. | D-10, C-09 |

Two sentences follow the new scope without a change of meaning: Principle II forbids ProjectM types "in the
VisualCore framework, in the app or in any experience" (formerly "in VisualCore or any of the 25 apps") and speaks of
experience modules in its reuse rule, and Principle VII says "the app and every experience" (formerly "every app").

Principles I, II-a, III, IV, VI, IX and X, the Technology Constraints and the standards section are byte-identical to
1.5.0. No requirement was deleted that ADR-0009 does not supersede.

## Judgement calls

The prompt left these points open. Each was decided for the reading that keeps more of 1.5.0 in force.

1. **Principle V forbids device work for every target in the repository, not only for the unified app.** 1.5.0
   forbade any device install before its lock. ADR-0009 D-08 moves the six open `{device}` tasks of the framework
   into the device sessions after the lock, and `python3 scripts/migration_ledger.py guard-device` refuses without
   naming a target. Limiting the rule to the unified app would have weakened a requirement that ADR-0009 keeps.
2. **Principle V carries three more rules of D-07 and D-08**, because they define what the lock means: a
   hardware-only capability may be pending hardware verification while core gameplay, rendering, persistence and
   purchase behavior may not; a repair after the lock takes a new lock revision and reruns the affected device rows;
   hardware identifiers stay out of tracked files.
3. **Principle XII says that no unlock flag is ever stored** (D-04). The prompt's list for the principle does not
   name it, but it is the rule that makes "entitlement from verified transactions" checkable.
4. **Principle XI has one sentence on package granularity** (D-06): a collection is one package and each experience
   has its own independently testable targets. Without it, Principle II's "packages are small" could be read
   against the collection packages.
5. **The precedence rule follows Auto-Creator.md section 2 word for word.** ADR-0009 stands with the owner
   directives; "the other ADRs" stand with the constitution.
6. **The section App-Scoped Rules keeps its name**, because Auto-Creator.md section 19.3, ADR-0007 and ADR-0008
   cite it. Its headings now carry the immutable experience id instead of a directory and a bundle identifier: the
   standalone targets are retired by UA-F07 and their bundle identifiers are never shipped. The rewording is
   limited to the introduction, the four headings, "a standalone iOS/iPadOS VisualCore consumer",
   "app-domain component" and three sentences that ended "stay in the app". Every other sentence of the four
   subsections is unchanged, and the introduction says that "the app" and "this app" there mean the experience.
7. **The Sync Impact Report is kept in this ADR.** The skill writes it as a comment at the top of the constitution
   and expects it to be removed before the commit; no committed version of the constitution has carried one.

## Sync impact report

Version change: 1.5.0 → 2.0.0.

| Kind | Items |
|---|---|
| Modified principles | II. App-Neutral Public API (wording); V. Implementation Before Devices (redefined); VII. Native, Accessible UI (wording); VIII. Public Apple APIs, Privacy and Truthful Capabilities (privacy manifest, network, human reviews). No title changed. |
| Added principles | XI. One App and Stable Experience Identity; XII. One Purchase and No Advertising (NON-NEGOTIABLE); XIII. Code-Driven Visuals |
| Added rules in sections | Development Workflow: numbering of Auto-Creator.md section 19, the two ledgers, work on `main` with the pre-push scan. Governance: the amendment record for 2.0.0. |
| Removed sections | none |
| Reworded without a change of meaning | title and scope; App-Scoped Rules (introduction, headings, target wording); Governance (precedence, range of principles under review) |
| Unchanged | I, II-a, III, IV, VI, IX, X; Technology Constraints; the standards section |
| Templates | none changed: the plan, specification and task templates read the constitution when they run |
| Deferred placeholders | none |

## What the amendment does not do

- It does not make the tooling enforce the new principles. `scripts/check_compliance.py` enforces what it enforced
  before: the renderer, private-API, ProjectM, networking, signing and background-mode rules. It already fails on
  any networking API in the scanned sources, because no allowlist file exists. The check for one shippable app
  target and for experience dependencies arrives with UA-F10, the store and fixture scans with UA-F08, and the
  no-advertising scan of the built app with UA-F11. Until then a gate review checks Principles XI–XIII by reading.
- It does not retire the standalone targets of A01–A04. They stay non-shipping harnesses until UA-F07.

## Consequences

- The Constitution Check of every later plan covers Principles I–XIII.
- Phase 00 of each remaining original app (A05–A25) adds its subsection under App-Scoped Rules with a MINOR bump, as
  ADR-0007 and ADR-0008 decided. With the override note it never restates a standalone-app scope.
- `CLAUDE.md` section 1 and Auto-Creator.md sections 4.1 and 19.2 described the constitution as 1.5.0 awaiting this
  amendment. They were corrected in the same commit.
- The amendment and this ADR are one commit. Reverting that commit is the rollback of milestone M1
  ([migration plan](../migration/migration-plan.md)).
