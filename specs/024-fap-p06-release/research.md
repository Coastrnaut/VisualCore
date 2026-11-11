# Research: Fluid Art Playground — Phase 06

## R1. Temporary capture folder

- **Decision**: `VisualCorePersistence.TemporaryFolder`. Captures go to `tmp/Captures`; launch and close clean it up.
- **Rationale**:
  - Every app that exports or shares files (A01 exports, future capture apps) needs the same "unique file in an
    app-owned temp folder, removed at launch" pattern.
  - It is Foundation-only, so it belongs in a pure module (R2).
- **Alternatives**:
  - Copying A01's app-local `LaunchCleanup`: duplication.
  - Changing A01 now: it is sealed; its adoption is recorded as reuse debt.

## R2. Icon

- **Decision**: render the icon from the deterministic test mode (seed 3, Glowing dye, 90 frames), offscreen at
  1024², and verify it with a provenance test (mean ≤ 1/255).
- **Rationale**: the app's own art, reproducible (feature 023 showed byte-identical renders on both runtimes) and
  free of third-party assets. This mirrors A01's `IconRenderTests`.

## R3. Privacy manifest content

- **Decision**: declare exactly what `check_privacy_manifest.py` reports for the Release build.
- **Rationale**: the scanner is the shared source of truth. A01's reasons for the ANGLE frameworks were
  source-checked and still apply (same pin).
- **Note**: the app has no UserDefaults or @AppStorage of its own (grep of `Apps/FluidArtPlayground`).

## R4. Release step wiring

- **Decision**: add `docs/apps/fluid-art-playground/release.json`. `release_check.py` then adds the
  `app-release-fluid-art-playground` step automatically: unsigned Release build, symbols, privacy scan and release
  check.
- **Rationale**: no script change is needed; this is the same path as A01.

## R5. No-persistence check

- **Decision**: an app unit test lists the app's own defaults domain keys and the container's Documents and Library
  (excluding system caches), after a session that opens the playground, paints, captures and closes.
- **Rationale**: it proves FR-A02-606 instead of assuming it. Device container checks follow in campaign II
  (CLAUDE.md §9 privacy).
