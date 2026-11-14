# Research: A06-P06

- **D1 Documents.** Same set and shape as `docs/apps/infinite-geometry/` (privacy-and-credits, store-listing with a
  traceability table claim → test, release-checklist `Item | Area | Status | Evidence`, device-campaign with device and
  pass criterion per measurement, release.json schema 1). Rationale: the release-document check and copy check already
  read this shape.
- **D2 Copy allow list.** audio, music, microphone (real features); all measured-claim patterns stay.
- **D3 Scan.** `grep -rnE 'URLSession|import Network|CoreMotion|CoreLocation|AVAudioRecorder|AVAssetWriter|write\(to:'`
  over `Packages/ExperiencesCreative/VisualCoreMusicLab/{Core,Experience}` and the VisualCoreAudio sources must find
  nothing (preset JSON goes through `ExperienceStorage.write`).
- **D4 Fixtures.** Five files as in spec clarification 3; the migration test copies them into a temporary
  `ExperienceStorage` and checks entries, counts and byte-identity.
- **D5 Failure seam.** `failNextDraw` → `MusicLabDrawError.injected`; the session's failure path as in
  `GeometryRecoveryTests`; preset files byte-identical; a new session draws.
- **D6 Interface chunk.** "m2": `MLScenesUITests` (scene buttons, palette, metrics text non-empty) and `MLPresetsUITests`
  (mapping strength slider, built-in preset Apply, Save current as…); candidate launch as `IGSupport`.
- **D7 Owner/device.** T-items for signing/archive/App Store Connect (BLOCKED_OWNER_ACTION) and the device campaign
  ({device}) stay open, as for A05-P06.
