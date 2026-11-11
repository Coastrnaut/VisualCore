# Research: Phase 9

- **R1 API surface** — regex scan of public declarations (types, functions, properties, inits, cases in public enums),
  normalized to `module | kind | qualified-ish signature`; doc-comment rule: the nearest preceding non-attribute line is
  `///` (or a `/** */` block). Baseline is plain text for readable diffs.
- **R2 AutomationRunner** — mirrors the reference projectM-iOS runner (CLAUDE.md §9) app-neutrally: the app constructs it
  with a `RenderHost` and a scene factory; modes run on the main actor with `renderOneFrame`/presented frames;
  report JSON (`schema 1`, mode, bundle id, device model via `utsname`, OS, frames, frame-time stats, leaks, result);
  `exit(code)` via an injectable terminator (tests don't exit). Whole module body under `#if DEBUG || VISUALCORE_AUTOMATION`.
- **R3 Shader validation** — compile every built-in program source (render scenes, effects passes, renderers) plus every
  bundled `.glsl/.vert/.frag` in Showcase/harnesses (broken.frag expected to fail, by design) on both runtimes.
- **R4 Licenses** — inventory: ANGLE (BSD-3-Clause, Google/ANGLE authors), projectM (LGPL-2.1, harness only), Spec Kit
  (MIT, tooling), XcodeGen (MIT, tool), easing equations (Penner, BSD — re-implemented), xoshiro256**/SplitMix64
  (public domain — re-implemented), preset packs (reference only, not shipped by VisualCore). `check_licenses.py`
  verifies every binary/package dependency in Package.swift/project specs maps to an inventory entry.
- **R5 CI** — `macos-latest` runner, pinned XcodeGen not needed for CI jobs (no app builds), Python 3, `swift test`.
- **R6 Baselines** — `swift run -c release VisualCoreBaselines --json` prints medians of 15 repeats; simulator runs via
  `xcrun simctl launch` with `SIMCTL_CHILD_VISUALCORE_AUTORUN=smoke` and copying the report out of the app container.
