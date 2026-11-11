# Research: Fractal Explorer — Phase 06

## R1 — Privacy manifest

- **Decision**: build Release (generic iOS, unsigned), run `check_privacy_manifest.py --app` to list required-reason
  APIs in the binary and frameworks, then write `PrivacyInfo.xcprivacy` with exactly those categories and the reasons
  A01/A02 documented: FileTimestamp C617.1 (ANGLE `stat`, DocumentStore attributes in the app's own container) and
  SystemBootTime 35F9.1 (elapsed-time measurement: `systemUptime`, `CACurrentMediaTime`) if found. Tracking false, no
  domains, no collected data.

## R2 — Icon

- **Decision**: per clarification 1; `IconRenderTests` with `FE_WRITE_ICON=1` (as `TEST_RUNNER_FE_WRITE_ICON`) to write.

## R3 — Golden fixture

- **Decision**: a test helper with `FE_WRITE_FIXTURE=1` writes one bookmark through `BookmarkLibrary` into the
  fixture path (only when the file is absent); `MigrationTests` copies it into a temporary folder and loads it.

## R4 — Copy

- **Decision**: `CopyTests` reads the home description and the store listing (`docs/.../store-listing.md` is bundled?
  no — the test reads the repository file via `#filePath`) and rejects words: "fps", "fast", "faster", "real-time",
  "deep zoom", "unlimited", "infinite zoom", "iPhone 15", "iPad Pro", "M5", "A16", "benchmark", "guaranteed".
