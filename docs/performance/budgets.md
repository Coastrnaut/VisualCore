# Performance budgets (feature 192, UA-F06; Auto-Creator.md section 12.5)

Simulator numbers are development signals, not device performance.

Every budget below is a **proposal**. A proposal becomes a requirement only when the named measurement on real
devices exists and is linked here; until then its status stays `proposal`. The devices are D1 (primary phone), D2
(high-resolution tablet) and D3 (compatibility tablet, lower tier). Device measurements run only after
ImplementationLock-100 (task T-U06-044 of feature 192 and the device campaign). Percentage criteria need at least
200 samples, each with sample id, scenario, seed, stage times and failure reason; first-run and cache-warm
samples are kept apart.

## Budgets

| Budget | Proposal | Status | Confirmed by |
|---|---|---|---|
| Cold launch to the usable launcher | no rendering context and no store wait before the launcher is usable; time from the start of the app's own code to the usable launcher recorded once per process | proposal | D1, D2, D3: scenario `launch`, 200 samples per device, first launch after an install kept apart |
| Open an experience to its first presented frame | preparation, shader set-up and first present recorded as separate stage times; no shader program compiled after the experience became interactive | proposal | D1, D2, D3: scenario `launch-first-frame`, 200 samples per device and experience tier |
| Frame pacing | at least 95% of display refreshes on time at the level in force | proposal | D1, D2, D3: scenario `steady`, 200 samples of ten seconds or more per device |
| Frame rate | 60 frames per second with automatic levels; a documented 30 frames per second mode is acceptable on the last level | proposal | D1, D2, D3: scenario `steady`, 200 samples per device |
| Input to visible response | median under 80 ms and 95th percentile under 150 ms, measured on one clock | proposal | D1, D2, D3: scenario `input-latency`, 200 samples per device |
| Start | cold and warm start recorded apart; a bounded set of shader variants compiled in the set-up | proposal | D1, D2, D3: scenarios `launch` (cold) and `relaunch` (warm), 200 samples per device |
| Memory and graphics bytes | bounded by the declared resource budget; flat over a ten-minute scenario (the growth rule of feature 192) | proposal | D1, D2, D3: scenario `endurance` on the wall clock, 200 samples per device; the simulator run of feature 192 is a development signal only |
| Clean build, incremental build and app size | recorded at every milestone | proposal | tooling: release build and size report of UA-F10 at every milestone (no device measurement) |

## What the app measures (feature 192)

The session writes one performance record per opened experience (`PerformanceRecord`, version 1): launch time,
preparation time, shader set-up time and the number of programs compiled, late compilations, time to the first
presented frame, the count of on-time and missed refreshes with the median, 95th and 99th percentile interval,
memory footprint, graphics bytes (current and peak), the quality level and whether it is pinned, steps down and
up, the frame-rate cap and resolution factor, thermal state and Low Power Mode.

Limits of these measurements:

- The launch time starts when the app's own code first runs. The time the system needs before that is not
  observable by the app and is not part of the value.
- The interval between presented frames is taken on the app's side after each present; it is not a measurement
  of the display itself.
- Time on the graphics processor is not observable on this rendering path and is not reported.
- Battery level, charging and display brightness are recorded by the device campaign, not by the app.

## Status of the numbers in this folder

`baselines-host.json` and `baselines-simulator.json` (see [README.md](README.md)) are host and simulator numbers
of the Showcase. They exist to catch regressions between commits on the same Mac and are never a statement about
a device.
