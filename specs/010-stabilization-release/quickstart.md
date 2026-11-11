# Quickstart: Phase 9 validation

1. `python3 scripts/release_check.py` → every step PASS (30 steps: public API, licenses, docs incl. links, compliance,
   dependencies, documented API ×3, script tests, host tests, rendering/effects/automation sims on both runtimes incl.
   shader validation and cleanup, Showcase + harness tests on both runtimes, reference regression + clean, Showcase
   Release build, zero automation symbols, ProjectM independence). `--list` prints the commands.
2. Build the Showcase for the simulator (Debug, or the measurement build) and run
   `python3 scripts/run_automation_sim.py --app <Showcase.app> --runtime 27.2 --mode smoke --out .autonomy/logs/automation-sim`
   → JSON report copied out, the app exits; `--mode bogus` → error report, exit 1.
3. Read `docs/release/support-matrix.md`, `known-limitations.md`, `release-notes-1.0.0-rc.1.md` and
   `docs/performance/README.md`.
4. Push → CI green (`gh run list`, `gh run watch <id> --exit-status`) for the checks, host-tests and simulator-build jobs.

Contract: [release-contract.md](contracts/release-contract.md).
