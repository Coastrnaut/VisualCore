# Quickstart: Phase 9 validation

1. `python3 scripts/release_check.py` → every step PASS (public API, licenses, docs, compliance, dependencies, documented API, host tests, rendering/effects sims both runtimes incl. shader validation and cleanup, Showcase + harness tests, reference regression, Release symbol check).
2. `python3 scripts/run_automation_sim.py --mode smoke --sim <27.2 sim> --out docs/performance/…` → JSON report, app exits.
3. Read `docs/release/support-matrix.md`, `known-limitations.md`, `release-notes-1.0.0-rc.1.md`.
4. Push → CI green for docs/compliance/scripts/host jobs.
Contract: [release-contract.md](contracts/release-contract.md).
