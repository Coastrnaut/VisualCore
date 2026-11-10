# Research: Phase 0 baseline audit

## R-F001 Engine framework for the baseline
- **Decision**: Build `Build/ProjectM.xcframework` with the reference's own
  `scripts/build_projectm_xcframework.py`, run with `cwd=External/projectm-ios`.
- **Rationale**: CLAUDE.md §4 requires the reference's own scripts. The script writes only to the
  gitignored `Build/` and records `Build/ProjectM.xcframework.json` (commit, flags, tools).
- **Alternatives**: a VisualCore CMake build (rejected: second build system); skipping the engine
  (rejected: the archived Phase 0 exit gate requires ProjectM to build).

## R-F002 Generated projects
- **Decision**: `xcodegen generate --spec project.yml` and `--spec RendererLab.yml` inside the reference.
- **Rationale**: The reference `.gitignore` covers `*.xcodeproj/` and `Apps/*/Info.plist`, so
  generation leaves tracked files untouched. `check_reference_clean.py` proves it.
- **Alternatives**: `--project` into a VisualCore path (rejected: XcodeGen resolves package paths
  relative to the spec; moving the output risks behavior differences).

## R-F003 DerivedData and result bundles
- **Decision**: `-derivedDataPath Build/DerivedData/reference` and `-resultBundlePath
  .autonomy/xcresults/F00-*.xcresult` in VisualCore (both gitignored).
- **Rationale**: Keeps the reference tree clean and evidence local.

## R-F004 Simulator destinations
- **Decision**: Pick destinations by runtime, never by a hard-coded name. Builds use
  `generic/platform=iOS Simulator`; tests use the first available iPhone on iOS 27.2 and on iOS
  26.5, discovered via `xcrun simctl list -j devices available`.
- **Rationale**: Owner playbook: "choose by runtime … never hard-code a device name".

## R-F005 Which reference tests form the smoke
- **Decision**: the `ANGLERendering` package tests (renderer on ANGLE, includes pixel readback) on
  both runtimes, through `xcodebuild test -scheme ANGLERendering` in the package directory.
- **Rationale**: This is the renderer VisualCore reproduces. Audio/capture packages are
  ProjectM-specific and are inventoried, not required for the renderer baseline.
- **Unknown → follow-up**: whether every reference package test still passes on Xcode 27.2 is not
  claimed; the inventory lists them (T-F012 runs the renderer subset only).

## R-F006 Trace citation verification
- **Decision**: The trace document embeds citations as `` `path` · `symbol` ``. `inventory_reference.py
  --check-citations docs/architecture/current-rendering-pipeline.md` verifies each path exists and
  each symbol appears in it at the pinned commit.
- **Rationale**: Makes SC-F002 mechanically checkable.
