# Contract: release (G-RELEASE)

- `scan-sources-release.sh`: refuses the clarification's list in `Packages/ExperiencesCreative/EffectsComposer`; allows
  `PhotosUI`, `PhotosPicker`, `ShareLink` only in `Experience/ECControls.swift` and requires each there; prints PASS or
  FAIL with lines; exit 0/1.
- `scan-claims-release.sh`: refuses the clarification's words (whole words, case-insensitive) in the store listing,
  the registration's summary and capabilities, and the interface Swift; requires "Nothing is sent" in the store text;
  checks that every test named in the store listing's claims table exists under the experience's tests; exit 0/1.
- `release_check.py --only experience-release-a25 copy-claims-a25` passes.
- Recovery: with two saved looks, `failNextDraw` then one draw fails the session with "The picture could not be
  drawn."; every storage file byte-identical; a new session lists and opens both looks.
- Samples: per data-model.md; every file byte-identical after reading.
- Interface: `ECReleaseUITests` (chunk `g3`): status "Ready", no effect row, `export-png`, `export-jpeg`,
  `export-heic`, `test-picture` present with the labels "Export as PNG" and "Use the test picture", no `share`, no
  saved look; under 60 s.
