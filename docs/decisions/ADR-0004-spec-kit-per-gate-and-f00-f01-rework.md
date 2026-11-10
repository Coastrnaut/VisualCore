# ADR-0004 — One Spec Kit feature per ledger gate; F00/F01 process deviation and rework

**Date:** 2026-11-10 · **Status:** accepted

## Context

The archived foundation README (§10.1–10.11) gives a separate Spec Kit feature, with ready-made
prompts for `specify, clarify, plan, checklist, tasks, analyze, implement, converge`, for each
foundation Phase 0–9. Each app manual (§9) gives the same full prompt set for each of its Phases
00–06. On 2026-11-10 the first session sealed F00 and F01 without running those sequences, then
began a single hand-written feature covering F02–F09 that skipped clarify, plan, checklist, tasks
and analyze. The owner asked whether each Spec Kit command was being run with the given prompts. It
was not. Phase 0's archived exit gate ("ProjectM builds at the pinned submodule commit") was also
not met when F00 was sealed.

## Decision

1. **One feature per gate.** `specs/001`–`010` = Phases 0–9 (F00–F09); app *NN* phase *P* =
   `specs/<10 + (NN-1)·7 + P + 1>` (`011`–`185`). ID namespaces: foundation phase *k* → `FR-Fk##`,
   `SC-Fk##`, `T-Fk##`; app *NN* phase *P* → `FR-ANN-P##`, `SC-ANN-P##`, `T-ANN-P##`
   (`scripts/validate_docs.py`).
2. **Every command uses the archive's prompt text.** The prompt is quoted in the skill invocation.
   Where a canonical rule (README §1–18, CLAUDE.md) overrides the archive, the override is added
   after the quoted prompt as a labelled `Canonical override:` note. Examples: `/speckit.x` →
   installed `/speckit-x`; the read-only submodule replaces "migrate ProjectM call sites"; no
   physical-device measurement before IMPLEMENTATION-LOCK.
3. **Clarify** is answered by the agent under the owner's delegated intent (recommended option),
   recorded in each spec's Clarifications section.
4. **F00/F01 rework.** The ledger has no reopen command and `state.json` is not hand-edited. The
   original F00/F01 checks remain true for what they claim. Features `001` (Phase 0) and `002`
   (Phase 1) now run the full sequences with the archive prompts. Their missing deliverables,
   including the reference ProjectM build at the pinned commit, are produced as dated addenda
   evidence under `docs/verification/`. F02 is not sealed until both reworks converge.
5. The hand-written `specs/001-visualcore-foundation` dossier was removed (in git history at
   `a5f2417`). Constitution v1.0.0 stays: it came from the installed `/speckit-constitution`
   skill. The archive's §10.1 constitution prompt is re-run as an amendment check in feature 002.

## Amendment log

- 2026-11-10 — constitution **1.0.0 → 1.1.0** (MINOR), via `/speckit-constitution` with the archive
  §10.1 prompt. Added Principle II-a (preserve the reference, regression evidence, no in-place
  extraction) and the API/testing/performance/documentation/release standards section. Expanded II
  (acyclic small packages, audited boundaries, no silent gitlink change), V (device-only performance
  claims) and VI (spec/plan/tasks/verification per feature; ADRs). Updated the ID namespaces to
  ADR-0004. No principle removed.
