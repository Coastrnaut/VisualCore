# Fractal Explorer — device campaign plan (A03-P05)

**Status: automation ready, device run pending implementation lock** (CLAUDE.md §1, §8; constitution V). Nothing on
this page is device evidence. The simulator rehearsal (`A03-P05/t507-rehearse-*`) only shows that the runs start,
write a report and exit.

## How a run is started

The app contains the automation entry only in `DEBUG` or `VISUALCORE_AUTOMATION` builds. The measurement build is
Release with `SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) VISUALCORE_AUTOMATION` (`t507-measure-build`: 501
automation symbols). The shipping Release build has 0 automation symbols and 0 trigger strings
(`t507-release-symbols`). The only trigger is the launch environment, set by `devicectl device process launch
--environment-variables` (or `simctl` for rehearsal):

| Key | Values |
|---|---|
| `VISUALCORE_AUTORUN` | `smoke` (N frames), `launch` (first presented frame), `lifecycle` (pause, resume, context recreation every third cycle), `precision` (zoom ladder), `tour` (curated tours with captures) |
| `VISUALCORE_AUTORUN_FRAMES` | 1…10,000 (default 120); for `tour`, a per-tour frame cap only when set |

VisualCore's `AutomationView` hosts the explorer's scene; the explorer model runs unhosted with animation off. Every
mode ends with the domain check "the shader compiled and rendered".

## The app modes

### `precision`

Reports the driver's fragment precision (`highpBits`, `highpRangeMax`, `mediumpBits`, `mantissaBitsUsed`), the render
limit (`maxRenderSize`) and the display scale. Then it walks a zoom ladder from the Seahorse Valley point (×4 per
step, up to 24 steps, stopping before the viewport's own 1e-15 scale). Each step is a 64 × 64-pixel patch drawn at
the screen's own plane step per device pixel, without the app's clamp, and compared with the 64-bit CPU reference.
A pixel counts as explained when its class matches, or when the CPU class changes within one pixel.

| Measurement | Meaning |
|---|---|
| `steps` | ladder steps drawn |
| `clampStep`, `clampZoom` | first step the app refuses to show (−1: none) |
| `breakdownStep`, `breakdownZoom` | first step explained below 99% (−1: none) |
| `minReliableAgreement` | lowest explained share among steps the app calls reliable |

`details.ladder` lists every step (zoom, level, clamped, agreement); `details.fallback` names the precision source.

**Pass rule:** every step the app calls reliable is ≥ 99% explained, and when the device breaks down within the
ladder the app clamps somewhere. Steps near the limit carry the app's "details may blur" banner and are recorded,
not judged (spec 030 findings).

### `tour`

Plays the three curated tours at 60 tour steps per second, times one presented frame per step (CPU-side, never GPU
time), captures a still at every stop at min(1024 px, the render limit) and checks it at 64 points against the CPU
reference (explained rule). It records `tours`, `stops`, `minStopAgreement`, `captureLongEdge`, frame-time statistics
and, in details, the thermal state and Low Power Mode at the start and the end and the per-tour agreements. No capture
file is left.

**Pass rule:** every frame renders, every stop ≥ 99%, no file left.

## Report

The report is `Documents/visualcore-automation-<mode>-<timestamp>.json` (schema 1). It records the mode, bundle,
device model, OS, app version and build, frames and frame-time statistics, the result and a message, and for the app
modes `measurements` and `details`. It holds no device identifiers, names or user data.

## Simulator rehearsal (2026-11-11, not device evidence)

| Mode | iOS 27.2 (iPhone19,2 simulator) | iOS 26.5 (iPhone18,1 simulator) |
|---|---|---|
| smoke 120 | pass | pass |
| launch | pass | pass |
| lifecycle | pass | pass |
| precision | pass: 22 steps, highp 23 bits, clamp step 8, breakdown step 6, min reliable 0.9939 | pass: same values |
| tour | pass: 3,780 frames, 9 stops | pass: 3,780 frames, 9 stops |

The simulator's precision is its own driver's; it says nothing about D1, D2 or D3.

## On-device privacy inspection (per device, CLAUDE.md §9)

After the runs on each device, list the whole app container (`devicectl device info files --domain-type
appDataContainer --domain-identifier dev.visualcore.FractalExplorer`), copy the app's preferences plist if present
and list its keys. Explain every entry and never suppress unknown ones:
- `Library/Application Support/Bookmarks` (only bookmarks the run created; normally empty);
- `Library/Caches` (Metal shader caches with `.pcm` files, which are not audio);
- `Library/Preferences`, `Library/SplashBoard`, `Library/Saved Application State`;
- automation reports in Documents (measurement builds only);
- empty `tmp/Captures` and `tmp/AutomationCaptures`.

Any other file fails the row. Record the listing without UDIDs or serials.

## Rows for the campaign (all pending)

| Device | Runs | Status |
|---|---|---|
| D1 iPhone 15, iOS 27.0.1 | smoke 600, launch ×200 (first after install separate), lifecycle 60, precision ×3, tour ×1 (then cooled) | automation ready, device run pending implementation lock |
| D2 iPad Pro 13-inch (M5), iPadOS 27.2 | same | automation ready, device run pending implementation lock |
| D3 iPad (A16), iPadOS 26.5 | same | automation ready, device run pending implementation lock |

Measured frame times are recorded, not judged; thresholds come from a later acceptance ADR based on these
measurements. A failed precision verdict on any device blocks every precision claim for that device.
