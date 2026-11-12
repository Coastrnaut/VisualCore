# Quickstart: validate UA-F06

Run from the repository root on `main`. Every command finishes within ten minutes.

## Evidence commands

Each is recorded with `python3 scripts/migration_ledger.py run-check --gate UA-F06 --name <check-name> --
<command>` (simulator and reference commands with `--timeout 600`).

| Check name | Command | Expected |
|---|---|---|
| `diagnostics-host` | `swift test --package-path Packages/VisualCore --filter VisualCoreDiagnosticsTests` | every test passes (profile, governor, pacing, growth rule, record) |
| `host-visualcore` | `swift test --package-path Packages/VisualCore` | every test passes |
| `pure-ios27`, `pure-ios26` | `python3 scripts/xcodebuild_package.py --package Packages/VisualCore --scheme VisualCore-Package --destination sim-27.2 --action test` (and `sim-26.5`) | TEST SUCCEEDED |
| `rendering-ios27`, `rendering-ios26` | `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --result-name ua-f06-ios27` (and `sim-26.5`, `ua-f06-ios26`) | TEST SUCCEEDED |
| `endurance-ios27`, `endurance-ios26` | `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --only-testing VisualCoreExperienceHostTests/EnduranceTests` (and `sim-26.5`) | the ten-minute scenario passes the growth rule; the leaking experience fails it |
| `app-…-a/-b/-c/-d` | `python3 scripts/xcodebuild_app.py --scheme VisualCore --runtime 27.2 --kind phone --only-testing …` in the four chunks of UA-F04, for phone and tablet on 27.2 and 26.5 | tests and enumeration guard pass |
| `performance-docs` | `python3 scripts/check_performance_docs.py` | every budget is a proposal with its confirming measurement; no simulator number without the notice |
| `release-symbols` | `python3 scripts/check_release_symbols.py --app <release app> --forbid DebugLaunch DebugExperience vc.performance` | 0 found |
| `public-api`, `documented-api-*`, `dependencies` | `python3 scripts/check_public_api.py` (after `--update`), `python3 scripts/check_documented_api.py --sources …`, `python3 scripts/check_dependencies.py` | pass |
| `build-<Scheme>` | the seven consumer builds (Showcase, four apps, two harnesses) | exit 0 |
| `reference-a`, `reference-b` | `python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean` and `--only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26` | 3 of 3 and 4 of 4 |
| `script-tests`, `docs`, `steering` | `python3 scripts/test_scripts.py`, `python3 scripts/validate_docs.py`, `python3 scripts/validate_autocreator.py` | pass |

### The brief's second evidence command

The brief names `python3 scripts/verify_experiences.py --only <sample id> --scenario endurance --runtime 27`.
That tool is created by UA-F09 (Auto-Creator.md section 22.2) and does not exist. It is recorded here as the
command UA-F09 will make runnable; it is **not** run for this gate. The endurance scenario is proven today by the
checks `endurance-ios27` and `endurance-ios26` above (the sample id is `a99.contract-sample`).

## Validation scenarios

1. **Profile**: `QualityProfileTests` — three levels with names and four budgets; 12 invalid profiles refused
   with their reason; element and iteration limits; `QualityDeclaration.problems` for a wrong count and wrong
   names. The conformance run of the sample core reports `profileMatchesTiers`.
2. **Automatic and pinned**: `QualityGovernorTests` — a script of 20 or more condition changes; `SessionQualityTests`
   on the simulator — the first frame of an open is drawn at the pinned level; a retried open too; no decision
   while suspended.
3. **Stages and shaders**: `SessionPerformanceTests` — separate `prepare`, `setup`, `firstPresent`; absent
   values after a failed or cancelled open; a presenter that compiles a program in its tenth frame gives one
   late compilation and `passes == false`; a context recreation counts a rebuild.
4. **Pacing and record**: `PacingMeterTests` — five scripted sequences; `PerformanceRecordTests` — round trip and
   eight refused texts.
5. **Endurance**: `EnduranceTests` — 36,000 frames, 60 samples, flat verdict, equal digests; the leak fails.
6. **App**: the unit tests read `session.lastPerformanceRecord` after an open and a close; an interface test
   opens a fixture experience, goes to the settings and reads `vc.performance`; the launch time is present once.
7. **Documents**: `check_performance_docs.py` on `docs/performance/` and on a scratch copy with a simulator
   number without the notice (exit 1).

## Device and owner tasks

`{device}`: pacing, memory, thermal and shader-compile measurements on D1, D2 and D3 with at least 200 samples,
after ImplementationLock-100. `{owner}`: none.
