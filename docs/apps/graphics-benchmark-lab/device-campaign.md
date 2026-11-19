# Graphics Benchmark Lab — device campaign plan (A24-P05, feature 177)

These checks need real devices. They run only after `ImplementationLock-100` (CLAUDE.md rule 5), in the order
D1 → D2 → D3, and D3 is not updated from iPadOS 26.5. Until then every row is pending, and no frame interval, CPU
time, GPU time, spread, pacing, heat, battery or accessibility figure is claimed anywhere. Simulator results never
stand in for these rows: the simulator does not run the device's GPU driver, gives no thermal state and no Low Power
Mode cadence on real hardware, and does not drive the display of an iPhone or an iPad. Every row is a device task
(FR-A24-506, SC-A24-505 in [the feature spec](../../../specs/177-gbl-p05-repeatability-review/spec.md)) and closes the
device part of gap G-DEVICE in [visualcore-contract.json](visualcore-contract.json) ([.md](visualcore-contract.md)).
Runs are short (minutes at most, no soak); a longer session is bounded by arithmetic from the short run, never run
(owner ruling of 2026-11-13). The pattern is Visual Programming Lab's
[device campaign](../visual-programming-lab/device-campaign.md).

Graphics Benchmark Lab (`a24.graphics-benchmark-lab`) runs three built-in benchmark cases (`BenchmarkCase.builtIn`) on
the OpenGL ES → ANGLE → Metal path: Textured quads (`quads`, version 1: 8 layers over a 256 × 256 texture), Shader
ALU (`alu`, version 1: 64 iterations per fragment) and Particles (`particles`, version 1: 5,000 particles), each at
resolution 1.0 and with the plan warm-up 3 s, measurement 10 s, cool-down 5 s (`BenchmarkCase.builtInPlan`), so one
run lasts 18 s. The presenter asks for at most 60 frames per second (`BenchPresenter.maxFramesPerSecond`); a frame is
dropped when its interval exceeds 1.5 × 1,000 / 60 ms, that is more than 25 ms (`DroppedFrameRule.thresholdMs`), and
its interval still counts in the summary. The recorder (`RunRecorder`) records each frame's interval, the presenter's
CPU time and, where a timer exists, the GPU time of measurement-phase frames; a value outside 0…1,000 ms ends the run
as interrupted. The GPU time comes from `GPUFrameTimer` (VisualCoreRendering) over `GL_EXT_disjoint_timer_query`: the
presenter decides `timerSupport` with `TimerProbe.decide(extensions:)` over the context's render capabilities, the
timer returns only available, non-disjoint results from a ring of 4 queries, and a disjoint read discards the pending
queries and raises `disjointCount`. Each ended run carries a `RunReport`: device model, OS, app version and build,
renderer and GL version, quality tier, thermal state ("nominal", "fair", "serious", "critical") and Low Power Mode at
the start and the end, the timing sources used, and the flag `thermal-changed` when the two thermal states differ. A
saved run is qualified as valid, qualified or invalid with its reasons, and the repeatability view (`repeatability`)
of an opened result lists the comparable trials of the same case fingerprint, device model, OS version, app build and
tier with each trial's interval p50 and p95 and the spread; "About these numbers" (`explain`) explains the limits. The
library holds at most 12 results, so a series is saved and compared before the next one replaces it. The devices are
D1 iPhone 15 (iOS 27), D2 iPad Pro 13-inch (M5) and D3 iPad (A16) on iPadOS 26.5.

Owner actions: the devices in hand, unlocking them, trusting the computer, the developer-mode and signing steps,
installing the development build, charging and unplugging, Low Power Mode, and turning VoiceOver and the text size on
and off in Settings are done by the owner. Each such step is recorded as `BLOCKED_OWNER_ACTION` with its exact steps
when the campaign reaches it, and the other rows continue.

A note on the lengths: 5 trials of one case take 5 × 18 s = 90 s of running, the three cases 270 s (4.5 minutes); a
10-run series of Particles takes 10 × 18 s = 180 s (3 minutes). A longer series is bounded by arithmetic from these
runs, never run. Every figure in a row's result is recorded as read on the device, with no figure claimed beforehand.

| Row | Device | Steps | Expected result | Owner actions | State |
|---|---|---|---|---|---|
| GBL-D1-D1 | D1 | Open Graphics Benchmark Lab on the development build. For each case (Textured quads, Shader ALU, Particles) in turn: run it 5 times to "Finished", save each result, open the last one and read its repeatability view; remove the 5 results before the next case. | Each run reads "Finished" with its percentiles and qualification; the repeatability view lists 5 comparable trials with each trial's p50 and p95 of the frame interval and the spread of each; a trial that is not comparable is listed with its reason; the trials and spread are recorded as read, with no figure claimed beforehand | device in hand, unlock, trust, developer mode, signing, install | pending |
| GBL-D1-D2 | D2 | As GBL-D1-D1 on D2. | As GBL-D1-D1 | device in hand, unlock, trust, developer mode, signing, install | pending |
| GBL-D1-D3 | D3 | As GBL-D1-D1 on D3. | As GBL-D1-D1 | device in hand, unlock, trust, developer mode, signing, install | pending |
| GBL-D2-D1 | D1 | On battery, run Particles 10 times back to back to "Finished" and save each result; open each and read its report's thermal state at the start and the end and its qualification. | Every report names a thermal state at the start and the end; a run whose state changed carries `thermal-changed` and is qualified ("The thermal state changed during the run"); a run at serious or critical is qualified ("The device was hot (serious)" or "(critical)"); a run with no caveat is valid; the states seen over the series are recorded as read, and a longer series is bounded by arithmetic from this one | charging and unplugging; as GBL-D1-D1 | pending |
| GBL-D2-D2 | D2 | As GBL-D2-D1 on D2. | As GBL-D2-D1 | charging and unplugging; as GBL-D1-D2 | pending |
| GBL-D2-D3 | D3 | As GBL-D2-D1 on D3. | As GBL-D2-D1 | charging and unplugging; as GBL-D1-D3 | pending |
| GBL-D3-D1 | D1 | Run Textured quads once with Low Power Mode off and once with it on, saving both; open each and read its report and qualification; then open the repeatability view of the second. | The report shows Low Power Mode off and on at the start and the end as set; the run with it on is qualified with "Low Power Mode was on", the run with it off carries no such reason; any change of cadence is recorded as read, with no figure claimed | Low Power Mode on and off; as GBL-D1-D1 | pending |
| GBL-D3-D2 | D2 | As GBL-D3-D1 on D2. | As GBL-D3-D1 | Low Power Mode on and off; as GBL-D1-D2 | pending |
| GBL-D3-D3 | D3 | As GBL-D3-D1 on D3. | As GBL-D3-D1 | Low Power Mode on and off; as GBL-D1-D3 | pending |
| GBL-D4-D1 | D1 | Run each case once to "Finished" and read its summary's interval percentiles and dropped-frame count; note the display's refresh as the system reports it. | The presenter draws at most 60 frames per second whatever the display's refresh; a frame counts as dropped only when its interval exceeds 25 ms, and a run with dropped frames is qualified ("Some frames were dropped"); the pacing and the dropped count are recorded as read, with no figure claimed beforehand | as GBL-D1-D1 | pending |
| GBL-D4-D2 | D2 | As GBL-D4-D1 on D2. | As GBL-D4-D1, on the iPad's display | as GBL-D1-D2 | pending |
| GBL-D4-D3 | D3 | As GBL-D4-D1 on D3. | As GBL-D4-D1, on the iPad's display | as GBL-D1-D3 | pending |
| GBL-D5-D1 | D1 | On the development build, read the presenter's `timerSupport` after the first frame (through the debugger) and the report's timing sources; run each case once and read the GPU distribution of its summary and the timer's `disjointCount`. | The probe result is recorded as read (supported, or unsupported with its reason); when supported, every GPU time is finite and below the frame interval it belongs to, only measurement-phase frames carry one, and `disjointCount` is recorded; when unsupported, no GPU time is shown or exported and CPU time is never labelled GPU time | as GBL-D1-D1 | pending |
| GBL-D5-D2 | D2 | As GBL-D5-D1 on D2. | As GBL-D5-D1 | as GBL-D1-D2 | pending |
| GBL-D5-D3 | D3 | As GBL-D5-D1 on D3. | As GBL-D5-D1 | as GBL-D1-D3 | pending |
| GBL-D6-D1 | D1 | The deferred accessibility audits (`VC_RUN_AUDITS=1`, run only on devices; owner ruling of 2026-11-13). With VoiceOver on, choose a case, start a run, hear the status through to "Finished", save, open the result, its repeatability view and "About these numbers"; set the largest accessibility text size and repeat. | VoiceOver reaches every control with its spoken label and reads the status, the qualification and each heading of the explanation; at the largest text size every control stays reachable and no text is cut off; the system audits report no issue, and any issue found is recorded as a follow-up task | VoiceOver and the text size on and off in Settings; as GBL-D1-D1 | pending |
| GBL-D6-D2 | D2 | As GBL-D6-D1 on D2. | As GBL-D6-D1, at the iPad size in the regular width | VoiceOver and the text size on and off in Settings; as GBL-D1-D2 | pending |
| GBL-D6-D3 | D3 | As GBL-D6-D1 on D3. | As GBL-D6-D1, at the iPad size in the regular width | VoiceOver and the text size on and off in Settings; as GBL-D1-D3 | pending |

## Record

Results are entered here only from a run on the named device after `ImplementationLock-100`, with the date, the build
(commit) and the evidence reference. A failed expectation is recorded as a follow-up task, not a pass.

| Row | Date | Build | Result | Evidence |
|---|---|---|---|---|

No device number is claimed.
