# Research: A08-P06

- **D1 Documents.** Same set and shape as `docs/apps/audio-odyssey/` (privacy-and-credits, store-listing with a
  traceability table claim → test, release-checklist `Item | Area | Status | Evidence`, device-campaign with device and
  pass criterion per measurement, release.json schema 1). Rationale: the release-document check and copy check read this
  shape. Alternative (a new format) rejected: no tool reads it.
- **D2 Copy allow list.** audio, microphone (real inputs); "music" stays refused (the scope names no music feature);
  all measured-claim patterns stay.
- **D3 Signal units.** The four lines (five hits) of `ScopePresenter.swift` that the copy check flags ("20 Hz", "100 Hz", "0 Hz")
  name units of the displayed signal; each gets `// copy-claims: allow (signal unit)`. Alternative (rewording to avoid
  numbers) rejected: the axis words must name their marks for VoiceOver.
- **D4 Scan.** `grep -rnE 'URLSession|import Network|CoreMotion|CoreLocation|AVAudioRecorder|AVAssetWriter'` over
  `Packages/ExperiencesCreative/OscilloscopeStudio` and the VisualCoreAudio sources must find nothing (preset JSON goes
  through `ExperienceStorage`).
- **D5 Fixtures.** Five files as in spec clarification 3; the migration test copies them into a temporary
  `ExperienceStorage` (`ScopeTest.temporaryStorage()`), opens a `ScopePresetStore` and checks entries, settings,
  counts (`unreadable` 2, `newer` 1) and byte-identity.
- **D6 Failure seam.** `failNextDraw` → `ScopeDrawError.injected`; the session's failure path as in
  `OdysseyRecoveryDrawTests`; preset files byte-identical; a new session draws.
- **D7 Interface chunk.** "p2": `OSScopeUITests` (waveform picker, timebase, gain, view XY and spectrum) and
  `OSPresetsUITests` (freeze toggle, cursors, built-in preset apply, save); candidate launch as `AOSupport`; the test
  signal only.
- **D8 Owner/device.** Signing, archive and App Store Connect stay BLOCKED_OWNER_ACTION in the release checklist and
  `docs/release/build-and-archive.md`; device rows stay `device` until ImplementationLock-100.
