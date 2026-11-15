# Solar System Explorer — privacy and credits

Solar System Explorer is the experience `a14.solar-system-explorer` of the one VisualCore app (ADR-0009). It has no app
target, Info.plist or privacy manifest of its own: the app's declarations cover it. Feature 108 (A14-P06), FR-A14-601
and FR-A14-604 (research D1). Sources: `Packages/ExperiencesCreative/SolarSystemExplorer` (below: SSE).

## What is stored on the device

| What | Where | Written by | Content |
|---|---|---|---|
| Saved view | `view.json` in the experience's own storage folder, `Application Support/Experiences/a14.solar-system-explorer/` | `SSE/Experience/ViewStore.swift` through `ExperienceStorage.write` (atomic replace: a reader sees the complete old or the complete new file), only when the person presses Save view | One `SavedView` document (`SSE/Core/SavedView.swift`; file schema 1, sorted keys, at most 4,096 bytes): the selected body (0 … 8), the simulated date (days since J2000.0), the clock rate index (0 … 3), the view's yaw, pitch and zoom steps and the scale mode (Enhanced or True relative). No name of a person, no device data, no location and no address |
| Saved session state | `state.json` in the same folder | the app (`SavedStateStore`, `Apps/VisualCore/App/AppModel.swift`), not the experience | The session snapshot of the core (`SolarCore`, `SolarState` schema 4): the selected body, the simulated date, the view's yaw, pitch and zoom, the scale mode, the clock (playing or paused, rate, stop reason) and the tour (which tour, stop, step and whether it is paused), so that the experience reopens where it was. Snapshots of schemas 1 to 3 migrate to schema 4 (`SolarCoreTests.testASchema1EnvelopeMigrates`, `testASchema2EnvelopeMigrates`, `testASchema3EnvelopeMigrates`) |

Nothing else is persisted by the experience. The nine bodies, their values and sources, the orbital elements, Saturn's
rings, the tours and the published event dates are part of the code (`BodyCatalog.bundled`, `SourceRecords`,
`OrbitElements`, `RingRecord`, `Tour.bundled`, `EventChecks`) and are never written. Its sources write no named defaults
values (`ExperienceStorage.setValue` is not called), no other files and no `UserDefaults` values. Loading never writes:
with no `view.json` (no view saved yet, or after a data reset) Restore view answers "No view has been saved yet." and
changes nothing (`ViewStoreTests.testAMissingFileIsItsOwnResult`); a file that is damaged, too large, of a newer schema
or holds a value outside its range is refused with its reason (`damaged`, `oversized`, `newer-version`,
`out-of-range`), the view stays as it is, and the file is left byte for byte as it was until the next Save view
replaces it (`ViewStoreTests.testDamagedNewerAndOversizedFilesAreRefusedAndLeftUntouched`,
`SolarTimeTourSessionTests.testSaveChangeAndRestoreReturnTheViewAndRefusedFilesChangeNothing`,
`SavedViewTests.eachFieldOutOfRangeIsRefused`). A refused write throws the storage error and keeps the previous file. A
drawing failure fails the session and leaves `view.json` byte-identical
(`SolarRecoveryDrawTests.testAFailedDrawLeavesTheSavedViewUntouched`). A saved state of a newer schema or with damaged
content is refused and the Sun opens (`SolarSessionTests.testANewerSavedStateIsRefusedAndTheSunOpens`,
`testADamagedSavedStateIsRefusedAndTheSunOpens`). The saved view lives outside the engine state, so saving never
changes a state digest or a replay; restoring goes through the action `view.apply`.

Now sets the simulated date from the device's clock when it is pressed; the date is used for the view only and is not
stored unless the person then saves the view.

## How to delete

- **The saved view.** Save view replaces the stored `view.json` with the current view; there is only ever one saved
  view.
- **Solar System Explorer's data.** In the app's Settings, the data section lists every experience with stored data;
  its reset button for Solar System Explorer, after a confirmation, removes the experience's folder with `view.json` and
  the saved session state (`Apps/VisualCore/App/SettingsView.swift`, `AppModel.reset(_:)` with `ResetPlan.experience`).
  The next opening shows the Sun at J2000.0 with no saved view.
- **Everything.** The reset of all data in the same section, or removing the app, removes every experience's folder,
  the saved view and the saved session state included.

## Permissions

Solar System Explorer requests no permission and adds no usage string (FR-A14-601). Its registration declares no
permission (`"permissions": []` in `Catalog/registrations.json`), and it uses no sensor: no motion, location, contacts,
photo library, microphone or device camera. It is used only through the native controls; it plays no sound and gives
no haptic.

## What is not done

- **Nothing is sent.** There is no upload, sync, sign-in, user account, analytics or crash reporting by the experience.
  The saved view never leaves the device; there is no export.
- **No network, tracking, recording or sensors.** The sources of the experience contain no `URLSession`,
  `import Network`, `CLLocation`, `AVCapture`, `AVAudioRecorder`, `inputNode`, `installTap`, `CMMotion`, `CNContact`,
  `ASIdentifierManager` or `AppTrackingTransparency` (check `sse-no-network`, T-A14-603:
  `.autonomy/checks/A14-P06.sse-no-network.json`). The app tracks nothing (`NSPrivacyTracking` false, no tracking
  domains).
- **No change to the system screen.** The experience never sets the system screen brightness
  (`UIScreen.main.brightness`) and never disables the idle timer (`isIdleTimerDisabled`) (the same scan).
- **No personal data.** The person types nothing; the saved view holds a body index, a date, a rate, view steps and a
  scale mode only.

## Required-reason APIs and the app's privacy manifest

The app manifest `Apps/VisualCore/Resources/PrivacyInfo.xcprivacy` declares no tracking, no collected data types and
three accessed-API categories. The experience's uses fall under them; it adds none:

| Category and reason | Use by Solar System Explorer |
|---|---|
| `NSPrivacyAccessedAPICategoryFileTimestamp`, `C617.1` | `ExperienceStorage` reads file attributes (type and size) of the experience's own `view.json` when it is read or written |
| `NSPrivacyAccessedAPICategoryUserDefaults`, `CA92.1` | `ExperienceStorage` holds the app's `UserDefaults` for named values under the prefix `exp.a14.solar-system-explorer.`; Solar System Explorer stores none |
| `NSPrivacyAccessedAPICategorySystemBootTime`, `35F9.1` | Frame times, which pace the focus flight, the playing clock and the tours, come from the app's render host (`ExperienceSession`); the experience's sources read no boot time. Elapsed time inside the app only |

The built product is checked against this manifest by `release_check.py --only app-release-build
app-privacy-manifest app-no-tracking app-usage-descriptions` ([build-and-archive](../../release/build-and-archive.md);
T-A14-612).

## Credits

Every number Solar System Explorer shows comes from the sources below. The full table with value, units, source, epoch
and license per value is [data-sources.md](data-sources.md), generated from `BodyCatalog.bundled` by
`CitationAudit.markdown(_:)` and checked against it by `CitationAuditTests.theCommittedDataSourcesDocumentMatchesTheCatalog`
(34 values; 0 problems; allowed licenses public-domain and CC0-1.0). How the model compares with published events is
[scientific-review.md](scientific-review.md) (`ScientificReviewTests.theCommittedReviewMatchesTheModel`).

| Source | Used for | License |
|---|---|---|
| Planetary Fact Sheet — Metric, NASA Space Science Data Coordinated Archive (D. R. Williams, NASA Goddard Space Flight Center), nssdc.gsfc.nasa.gov/planetary/factsheet | Mean radius, semi-major axis, sidereal period and axial tilt of the eight planets | public domain (NASA) |
| Sun Fact Sheet, NASA Space Science Data Coordinated Archive (D. R. Williams), nssdc.gsfc.nasa.gov/planetary/factsheet/sunfact.html | The Sun's axial tilt | public domain (NASA) |
| Saturnian Rings Fact Sheet, NASA Space Science Data Coordinated Archive (D. R. Williams), nssdc.gsfc.nasa.gov/planetary/factsheet/satringfact.html | Inner and outer radius of Saturn's main rings and the Cassini division | public domain (NASA) |
| Resolution B3 on recommended nominal conversion constants, International Astronomical Union (2015), iau.org/static/resolutions/IAU2015_English.pdf | The Sun's nominal mean radius | public domain (as recorded in `SourceRecords`) |
| Keplerian Elements for Approximate Positions of the Major Planets, Table 1, E. M. Standish, NASA Jet Propulsion Laboratory Solar System Dynamics, ssd.jpl.nasa.gov/planets/approx_pos.html | The mean orbital elements at J2000.0 of the eight planets (the approximate Kepler model) | numerical facts, public domain |
| Mars close approaches and oppositions, NASA Mars Exploration Program | The published dates of four Mars oppositions the model is checked against (`EventChecks`) | public domain (NASA) |
| Earth's Seasons and Apsides, US Naval Observatory | The published dates of three Earth perihelia the model is checked against (`EventChecks`) | public domain (US government) |

- **The model.** Positions come from an approximate model: Kepler orbits from the planets' mean elements at epoch
  J2000.0, held fixed, for dates from 1950 to 2050; they are not an ephemeris. In the enhanced view, sizes and
  distances are enlarged and not to scale. The statement is shown in the app under "About this model"
  (`ScientificReview.modelStatement`).
- **Visuals.** Drawn by code only: the bodies are procedural spheres coloured per vertex from each body's
  `SurfaceRecipe` and seeded noise, Saturn's ring is a procedural annulus, the orbits are procedural tubes, the
  starfield is 400 seeded directions and the selection ring and markers are procedural shapes, all drawn at run time
  through the host's renderer. No image, texture, photograph, model, font or data file from a third party is bundled.
- **Sound.** None.
- **Code.** The experience's sources (catalog, source records, citation audit, orbit model, clock, tours, scientific
  review, surface recipes, meshes, layout, focus flight, presenter, controls and saved view) are this repository's own
  code. The experience depends only on the local packages `Packages/VisualCore` and `Packages/VisualCoreRendering`
  (`Packages/ExperiencesCreative/Package.swift`); it adds no third-party package. The app's third-party components
  (ANGLE and the libraries inside it, listed in `docs/legal/third-party.json`) are bundled under the app's `Licenses`
  folder, shown in the app's Acknowledgements and checked by `app-licenses`.
- **No third-party content.** Apart from the public-domain values above, no picture, sound, text or code from outside
  the project is in the experience.
- **Test samples.** The committed sample saved views (`view-valid.json`, `view-newer.json`, `view-damaged.json`,
  `view-oversized.json`; A14-P06, T-A14-605) are resources of the test target only; `scenario-manifest.json` is outside
  every target's path.
- **ProjectM.** Not used; no engine code, preset format or name of it is in the experience, and ProjectM types stay out
  of the app.
