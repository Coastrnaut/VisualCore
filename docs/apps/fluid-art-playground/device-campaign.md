# Fluid Art Playground — device campaign plan (A02-P05)

**Status: automation ready, device run pending implementation lock** (CLAUDE.md §1, §8; constitution V). Nothing on
this page is device evidence. The simulator rehearsal (`A02-P05/t511-rehearse-*`) only shows that the runs start,
write a report and exit.

## How a run is started

The app contains the automation entry only in `DEBUG` or `VISUALCORE_AUTOMATION` builds (a Release build with
`SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) VISUALCORE_AUTOMATION` is the measurement build). The shipping
Release build has 0 automation symbols and 0 trigger strings (`check_release_symbols.py`). The only trigger is the
launch environment, set by `devicectl device process launch --environment-variables` (or `simctl` for rehearsal):

| Key | Values |
|---|---|
| `VISUALCORE_AUTORUN` | `smoke` (N frames), `launch` (first presented frame), `lifecycle` (pause, resume, context recreation every third cycle) |
| `VISUALCORE_AUTORUN_FRAMES` | 1…10,000 (default 120) |
| `VISUALCORE_AUTORUN_SEED` | unsigned 64-bit, default 1 |

The fluid runs in the deterministic test mode:
- fixed 1/60 s steps;
- quality tier pinned to Full;
- maximum force and splat cap;
- the VisualCore `SyntheticGestureScript` (4 pointers, 30 samples per stroke, 1,200 pt/s on a 390×844 pt script
  canvas).

After the mode's frames, the post-run check reads the velocity, pressure and dye fields back. A finding marks the
run "fail"; the checks are:
- every value is finite;
- dye is within 0…4;
- |v|·Δt is at most the longer grid edge;
- |p| ≤ 10⁴.

## Report

The report is `Documents/visualcore-automation-<mode>-<timestamp>.json` (schema 1). It records:
- mode, bundle, device model, OS, app version and build;
- frames and frame-time statistics (min, median, p95, max in ms; CPU-side timing, never labelled GPU time);
- time to first frame (launch), cycles and leaked resources (lifecycle);
- result (`pass`, `fail` or `error`) and a message.

On a pass the message is:

```
digest=<SHA-256 of the dye field> steps=<n> splats=<n> maxVelocity=<cells/s> maxDye=<v> maxPressure=<v> grid=<w>x<h> storage=<float16|unorm8>
```

The digest is compared between repeated runs on the same device. Across devices only finiteness, ranges and step
counts are compared (spec 023 assumptions). The report holds no personal data and stays in the app container until
copied.

## Rows for the campaign (all pending)

| Device | Runs per mode | Seeds | Status |
|---|---|---|---|
| D1 iPhone 15, iOS 27.0.1 | smoke 600 frames, launch ×200 (first after install separate), lifecycle 60 | 7 (repeat ×2 for the digest), 8 | automation ready, device run pending implementation lock |
| D2 iPad Pro 13-inch (M5), iPadOS 27.2 | same | same | automation ready, device run pending implementation lock |
| D3 iPad (A16), iPadOS 26.5 | same | same | automation ready, device run pending implementation lock |

Measured frame times are recorded, not judged. Thresholds come from a later acceptance ADR based on these
measurements (manual §12). Thermal state, battery and brightness are added by the campaign orchestrator
(`scripts/run_device_campaign.py`, CLAUDE.md §9).
