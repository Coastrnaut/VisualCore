# Tasks: Oscilloscope Studio — Phase 03 Spectrum and XY modes

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate A08-P03 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A08-P03 --timeout 600 --name <check> -- <command>`. Commit after every task (no trailers). iOS 27 only; reference regression at X-A08
(owner, 2026-11-14). No VisualCore change.

## Phase 1: Setup

- [X] T-A08-301 Baseline: cite the A08-P02 evidence on the unchanged tree (`.autonomy/checks/A08-P02.scope-ios27.json`, `.autonomy/checks/A08-P02.app-unit.json`, `.autonomy/checks/A08-P02.verify-27.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-14: 2026-11-14: tree unchanged since the A08-P02 record; cites .autonomy/checks/A08-P02.{scope-ios27,app-unit,verify-27}.json

## Phase 2: User Story 1 — a spectrum with honest annotation (P1) 🎯

- [X] T-A08-302 [P] [US1] Core: `ScopeDisplay.spectrum` (raw 2, spoken "spectrum") in `Packages/ExperiencesCreative/OscilloscopeStudio/Core/ScopeSettings.swift`; new `Core/SpectrumReadout.swift` (validity valid / noSignal / clipping / filling; frequency = bin × rate ÷ 4,096 rounded to 1 Hz; level rounded to 0.1 dB; value only when valid; peak via `SpectrumAnalyzer.peakBin`; clipping when any analysed |x| ≥ 1; filling when fewer than 4,096 frames written) and `Core/SpectrumView.swift` (strongest bin per pixel column on a log axis from 20 Hz to Nyquist; points 0 dBFS top to ≤ −100 dBFS bottom; decade marks 100 Hz / 1 kHz / 10 kHz below Nyquist; level marks every 20 dB); tests `CoreTests/{SpectrumReadoutTests,SpectrumViewTests,ScopeStateTests}.swift`: sines of 100 Hz, 440 Hz, 1 kHz, 5 kHz at amplitudes 0.5 and 0.1 at 48 kHz and 44.1 kHz read within one bin and 1.5 dB of 20·log10(amplitude); silence → noSignal; a clipped frame → clipping; 1,000 written frames → filling; at most one point per column and the highest point equals the strongest bin; marks at the expected x for 48 and 44.1 kHz; `display.select 2` round trip and A08-P02 snapshots unchanged (FR-A08-301–304; SC-A08-301–303) — Verified 2026-11-14: 2026-11-14: ScopeDisplay.spectrum, SpectrumReadout, SpectrumView + tests; OscilloscopeStudioCoreTests 50 tests pass on sim-27.2
- [X] T-A08-303 [US1] Experience: `ScopeCore` accepts `display.select [0…2]`; `ScopePresenter` spectrum view (newest 4,096 frames of the left or only channel via `latestFrames`/`latest`, one `SpectrumAnalyzer(size: 4096)` created once, decade and level marks as grid lines, the curve as one polyline, readout in `trace.status` and the description: "peak <f> Hz at <l> dBFS, relative to full scale" or the reason); `ScopeControls` View picker gains "Spectrum"; tests in `ExperienceTests/{ScopeCoreTests,ScopeSessionTests,ScopeRenderTests}.swift` (the 1 kHz test signal reads 1,000 Hz ± one bin at about −6 dBFS in the description; the sweep's readout moves upward over frames; silence says "no signal"; gain ×10 leaves the spectrum readout unchanged; spectrum frame differs from waveform and XY frames and is non-blank) (FR-A08-301–305, 320; SC-A08-301, 302) — Verified 2026-11-14: 2026-11-14: presenter spectrum view (one SpectrumAnalyzer, decade/level grid, polyline, readout in status and description), View picker Spectrum; OscilloscopeStudioExperienceTests 31 tests pass on sim-27.2

## Phase 3: User Story 3 — the mono XY fixture (P2)

- [X] T-A08-304 [US3] Extend `Experience/Adapter/ScopeManifest.swift` with fixtures for the spectrum view (`display.select [2]` on the 1 kHz sine) and for the microphone (mono) in XY (`source.select [2]`, `display.select [1]`), regenerate `scenario-manifest.json` (`UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`), update `ExperienceTests/ScopeManifestTests.swift`; the session test for the mono-XY mark (A08-P02) stays green (FR-A08-310; SC-A08-304) — Verified 2026-11-14: 2026-11-14: manifest fixtures 8 (spectrum) and 9 (microphone mono in XY), manifest regenerated (9 fixtures); ScopeManifestTests pass

## Phase 4: Polish & evidence

- [X] T-A08-305 Oscilloscope Studio tests on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P03 --timeout 600 --name scope-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing OscilloscopeStudioCoreTests OscilloscopeStudioExperienceTests`; each test < 10 s) (SC-A08-305) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A08-P03.scope-ios27.json exit 0 (core 50 + experience 31 + manifest 4)
- [X] T-A08-306 App build and unit (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P03 --timeout 600 --name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A08-P03.app-unit.json exit 0
- [X] T-A08-307 Runner iOS 27 (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P03 --timeout 600 --name verify-27 -- python3 scripts/verify_experiences.py --only a08.oscilloscope-studio --runtime 27`) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A08-P03.verify-27.json exit 0 (nine standard + nine fixture scenarios)
- [X] T-A08-308 Experience package check and the copy scan for forbidden unit words (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P03 --timeout 600 --name experience-packages -- python3 scripts/check_experience_packages.py`; `python3 Tools/python/desktop_runbook.py run-check --stage A08-P03 --timeout 600 --name os-copy -- /bin/sh -c "! grep -rniE '\"[^\"]*(dB SPL|volts|calibrated|certified)[^\"]*\"' Packages/ExperiencesCreative/OscilloscopeStudio/Experience"`: string literals only, so comments that deny such claims do not count) (FR-A08-320) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A08-P03.experience-packages.json and .autonomy/checks/A08-P03.os-copy.json exit 0
- [ ] T-A08-309 Contract: G-SPECTRUMLABELS closed by "A08-P03" (row M12 available with the experience's `SpectrumReadout`/`SpectrumView` as example and the VisualCore `SpectrumAnalyzer` evidence) and `python3 Tools/python/desktop_runbook.py run-check --stage A08-P03 --timeout 600 --name contract -- python3 scripts/check_app_contract.py --app oscilloscope-studio --render`
- [ ] T-A08-310 Script tests (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P03 --timeout 600 --name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A08-311 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A08-P03

## Dependencies

T-A08-301 → 302 → 303 → 304 → Polish.

## Parallel examples

Agent A: T-A08-302. Agent B: T-A08-303 after A. Lead: 304, contract, runs, commits.

## Implementation strategy

MVP: the spectrum view with its readout (US1 with US2's drawing bounds inside T-A08-302/303); then the fixtures;
evidence last.
