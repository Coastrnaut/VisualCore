# ADR-0001 — Ledger, evidence and repository state policy

**Date:** 2026-11-10 · **Status:** accepted (routine decision under delegated implementation intent)

## Context

README §17 extracts `Tools/python/desktop_runbook.py` and bootstraps `.autonomy/`. CLAUDE.md §10
leaves "tracked or otherwise durable" to setup time. Spec Kit 1.4.1.dev0 was already initialized
in commit `b17f60f` (`.specify/`, `.claude/skills/speckit-*`), with no `claude -p` event dispatch in
the installed skills or workflow; the `specify` executable is not on PATH.

## Decision

1. **Tracked:** `Tools/python/desktop_runbook.py` (byte-identical to README §19),
   `.autonomy/state.json`, `.autonomy/evidence/`, `.autonomy/checks/` (small JSON with log hashes).
2. **Ignored but durable on this Mac:** `.autonomy/logs/`, `.autonomy/xcresults/`,
   `.autonomy/reports/`, `.autonomy/private/` (UDIDs/serials), `.autonomy/context/` (re-extractable
   from README with hash verification), `.autonomy/desktop.lock/`. Logs can be large and may hold
   machine paths; the attestation JSON keeps their SHA-256 so tampering is detectable.
3. **Spec Kit is not re-initialized.** The existing installation is used through the
   model-invocable `.claude/skills/speckit-*` skills inside the Desktop session (VC-009).
4. One feature dossier per foundation (`specs/001-visualcore-foundation/`) and per app
   (`specs/0NN-app-<slug>/`); ledger stage IDs map onto phases inside each dossier (README §5.3).
5. ID namespaces: foundation `FR-F###`, `SC-F###`, `T-F###`; app *NN* uses `FR-ANN-###`,
   `SC-ANN-###`, `T-ANN-###`, `R-ANN-##` so `scripts/validate_docs.py` can detect collisions.

## Consequences

A fresh session on this Mac resumes from `state.json`; a fresh clone elsewhere keeps the
attestations but must rerun checks to regenerate logs before `audit` passes.
