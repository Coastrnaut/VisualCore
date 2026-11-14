# Research: A05-P00 (feature 039)

## 0. Verified facts (2026-11-13)

- `scripts/check_app_contract.py` (A01-P00) verifies cited files, declared symbols (public when required), products,
  gap coverage and renders the Markdown view; contracts exist for A01–A04 under `docs/apps/<slug>/`.
- `scripts/check_experience_packages.py` forbids unregistered experience targets (`EXTRA_TARGET`).
- Constitution 2.1.0 commit `427eea32`; reference pin `d93edd1`.
- R02-F04 (pipeline, depth targets) and R02-F05 (mesh compiler and validation) are recorded in the migration ledger.

## 1. Decisions

- **D1 Shell:** the one app is the shell (clarification 1); targets arrive in A05-P01.
- **D2 Matrix scope:** five brainstorm capabilities and the six version 0.1 features, plus the cross-cutting rows
  (persistence, still export, quality tiers, accessibility); availability rule of clarification 4.
- **D3 Regression:** two chunks as for every VisualCore-adjacent gate (`reference-engine-xcframework
  reference-build-projectm-ios-sim reference-clean`; `reference-test-anglerendering-ios27 reference-test-anglerendering-ios26
  projectm-reference-ios27 projectm-reference-ios26`).
