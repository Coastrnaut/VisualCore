# Tiny Worlds — privacy and credits

Tiny Worlds is the experience `a12.tiny-worlds` of the one VisualCore app (ADR-0009). It has no app target, Info.plist
or privacy manifest of its own: the app's declarations cover it. Feature 094 (A12-P06), FR-A12-601 and FR-A12-604.
Sources: `Packages/ExperiencesCreative/TinyWorlds` (below: TW).

## What is stored on the device

| What | Where | Written by | Content |
|---|---|---|---|
| Saved worlds | `world-0.json` … `world-3.json` (`world-<slot>.json`, one file per slot) in the experience's own storage folder, `Application Support/Experiences/a12.tiny-worlds/` | `TW/Experience/WorldStore.swift` through `ExperienceStorage.write` (atomic replace: a reader sees the complete old or the complete new file), only when the person taps Save on a slot | One `WorldDocument` (file schema 2, at most 64 KB): the slot name made from the preset and the seed (such as "Island, seed 1"; the person types nothing) and the world state: the preset, the seed, the placed props (kind and position, at most 24), the selection, the light (sun direction and ambient level), the view (orbit angles and distance) and the state of the generator that draws new seeds. No date, no name of a person, no device data and no address |
| Thumbnails | `world-0.png` … `world-3.png` (`world-<slot>.png`) in the same folder | `WorldStore.swift`, written after the document of the same slot, only when a still renderer drew one | A 160 × 120 PNG picture of the saved world, at most 64 KB, drawn from the world itself by code. A slot saved without a picture has its old picture removed, so a slot never shows the picture of an earlier world |
| Saved session state | `state.json` in the same folder | the app (`SavedStateStore`, `Apps/VisualCore/App/AppModel.swift`), not the experience | The session snapshot of the core (`WorldsCore`, snapshot schema 2): the same world state as above, so that the world reopens where it was. Snapshots of schema 1 are migrated on restore (`WorldsEditingTests.testTheSchemaOneExampleMigrates`) |

Nothing else is persisted by the experience. The presets, palettes, props, prop palettes and packs are part of the code
(`ContentCatalog.bundled`, `WorldPreset.swift`, `PropCatalog.swift`, `WorldPack.swift`) and are never written. Its
sources write no named defaults values (`ExperienceStorage.setValue` is not called), no other files and no
`UserDefaults` values. Reading a slot never writes: a file that is damaged, half-written, of a newer schema or too large
is refused with its reason in the slot's status line and left byte for byte as it was until the person saves over it
(`WorldStoreTests.testRefusedFilesAreReportedAndLeftUntouched`,
`WorldSampleFileTests.testTheCommittedSamplesOpenOrAreRefused`). An interrupted write keeps the previous file
(`WorldStoreTests.testAnInterruptedWriteKeepsThePreviousFileByteIdentical`); a refused slot changes nothing and reports
its reason (`WorldStoreTests.testARefusedSlotChangesNothingAndReportsItsReason`). A saved state of a newer schema or
with damaged content is refused and the default world opens
(`WorldsSessionTests.testANewerSavedStateIsRefusedAndTheDefaultWorldOpens`,
`testADamagedSavedStateIsRefusedAndTheDefaultWorldOpens`). A drawing failure leaves the saved files untouched
(`WorldsRecoveryDrawTests.testAFailedDrawLeavesSavedWorldsUntouched`).

## How to delete

- **One saved world.** In the experience's Saved worlds group, the Clear button of a slot removes that slot's
  `world-<slot>.json` and `world-<slot>.png` (`WorldsPresenter.clearWorld(slot:)`, `WorldStore.clear(slot:)`;
  `WorldStoreTests.testEmptyAndInvalidSlotsAndClearing`). Saving to a slot replaces what it held.
- **Tiny Worlds' data.** In the app's Settings, the data section lists every experience with stored data; its reset
  button for Tiny Worlds, after a confirmation, removes the experience's folder with every saved world, every thumbnail
  and the saved session state (`Apps/VisualCore/App/SettingsView.swift`, `AppModel.reset(_:)` with
  `ResetPlan.experience`). The next opening starts with the island, seed 1, and four empty slots.
- **Everything.** The reset of all data in the same section, or removing the app, removes every experience's folder,
  the saved worlds, their thumbnails and the saved session state included.

## Permissions

Tiny Worlds requests no permission and adds no usage string (FR-A12-601). Its registration declares no permission
(`"permissions": []` in `Catalog/registrations.json`), and it uses no sensor: no motion, location, contacts, photo
library, microphone or camera. Exploring and editing use only touches on the canvas (drag, pinch, tap) and the native
controls. The experience plays no sound and sends no haptic feedback.

## What is not done

- **Nothing is sent.** There is no upload, sync, sign-in, user account, online gallery, analytics or crash reporting
  by the experience. Saved worlds and their thumbnails never leave the device; there is no export.
- **No network, tracking, recording or sensors.** The sources of the experience contain no `URLSession`,
  `import Network`, `CLLocation`, `AVCapture`, `AVAudioRecorder`, `inputNode`, `installTap`, `CMMotion`, `CNContact`,
  `ASIdentifierManager` or `AppTrackingTransparency` (check `tw-no-network`, T-A12-603:
  `.autonomy/checks/A12-P06.tw-no-network.json`). The app tracks nothing (`NSPrivacyTracking` false, no tracking
  domains).
- **No change to the system screen.** The experience never sets the system screen brightness
  (`UIScreen.main.brightness`) and never disables the idle timer (`isIdleTimerDisabled`) (the same scan).
- **Low Power Mode is read, not changed.** The public `ProcessInfo` state selects the lightest drawing tier; the world
  does not change with it (`WorldsQualityTests.testLowPowerModeDrawsTheLightestTierFromTheFirstFrame`,
  `WorldsRenderTests.testALevelChangeRebuildsOnlyTheTerrainRendererAndKeepsTheDigest`).

## Required-reason APIs and the app's privacy manifest

The app manifest `Apps/VisualCore/Resources/PrivacyInfo.xcprivacy` declares no tracking, no collected data types and
three accessed-API categories. The experience's uses fall under them; it adds none:

| Category and reason | Use by Tiny Worlds |
|---|---|
| `NSPrivacyAccessedAPICategoryFileTimestamp`, `C617.1` | `ExperienceStorage` reads file attributes (type and size) of the experience's own files when a saved world or thumbnail is read or written |
| `NSPrivacyAccessedAPICategoryUserDefaults`, `CA92.1` | `ExperienceStorage` holds the app's `UserDefaults` for named values under the prefix `exp.a12.tiny-worlds.`; Tiny Worlds stores none |
| `NSPrivacyAccessedAPICategorySystemBootTime`, `35F9.1` | Frame times, the view's easing and the memory-warning hold come from the app's render host (`ExperienceSession`); the experience's sources read no boot time. Elapsed time inside the app only |

The built product is checked against this manifest by `release_check.py --only app-release-build
app-privacy-manifest app-no-tracking app-usage-descriptions` ([build-and-archive](../../release/build-and-archive.md);
T-A12-613).

## Credits

- **Content.** The three presets (Island, Asteroid garden, Miniature city), their three palettes, the four props (Tree,
  Rock, House, Lantern), their four prop palettes and the three packs (Island, Asteroid garden, Miniature city) are
  original content by the VisualCore project under the MIT license. The full table with author and license per item is
  [content-licenses.md](content-licenses.md), generated from `ContentCatalog.bundled` by `LicenseAudit.markdown(_:)`
  and checked against it by `LicenseAuditTests.theCommittedLicenseDocumentMatchesTheCatalog` (3 presets, 3 palettes,
  4 props, 4 prop palettes, 3 packs; 0 problems). The worlds are stylised dioramas generated from a seed, not maps of
  any place.
- **Visuals.** Drawn by code only: the terrain, the sea or void, the props, the sky, the light and the fog are
  procedural meshes and shaders generated at run time through the host's renderers. No image, model, texture, font or
  data file from a third party is bundled; the thumbnails are drawn from the world on the device.
- **Code.** The experience's sources (presets, terrain generation and colouring, props, packs, editing, camera policy,
  ground picking, world documents and store, presenter, gestures and controls) are this repository's own code; the
  seeded gradient noise and the height-field terrain it uses are VisualCore's own code
  (`Packages/VisualCore/Sources/VisualCoreScenes`). The experience depends only on the local packages
  `Packages/VisualCore` and `Packages/VisualCoreRendering` (`Packages/ExperiencesCreative/Package.swift`); it adds no
  third-party package. The app's third-party components (ANGLE and the libraries inside it, listed in
  `docs/legal/third-party.json`) are bundled under the app's `Licenses` folder, shown in the app's Acknowledgements and
  checked by `app-licenses`.
- **Test samples.** The four committed sample world files (`world-valid.json`, `world-newer.json`,
  `world-damaged.json`, `world-truncated.json`) are resources of the test target only (A12-P06, T-A12-606);
  `scenario-manifest.json` is outside every target's path.
- **ProjectM.** Not used; no engine code, preset format or name of it is in the experience, and ProjectM types stay out
  of the app.
