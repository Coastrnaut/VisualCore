# Research: A01-P06

Verified by the read-only audit (2026-11-11):
- `VisualCoreAutomation.AutomationRunner(host:bundleID:outputDirectory:terminate:)`, `requestedMode()`,
  `requestedFrames()`, and the modes smoke, launch and lifecycle; the whole module is compiled only under
  `DEBUG || VISUALCORE_AUTOMATION` (Showcase precedent);
- `scripts/check_release_symbols.py` and `scripts/run_automation_sim.py` (`--app --runtime --mode --out`);
- `DocumentStore` atomic save with the internal `beforeReplace` hook (used by the Core tests);
- `CompositionLibrary.kind` and `init(directory:)`;
- `ExportRunner`, which writes into `tmp/Exports`.

- **R1 Required-reason table.** The shared scan detects these categories by symbol:
  - UserDefaults (`NSPrivacyAccessedAPICategoryUserDefaults`): the `NSUserDefaults` class reference, `CFPreferences*`;
  - file timestamps (`…FileTimestamp`): `stat`, `fstat`, `lstat`, `getattrlist`, `fgetattrlist`, plus the strings
    `NSFileCreationDate`, `NSFileModificationDate`, `creationDateKey` and `contentModificationDateKey` in the binary;
  - system boot time (`…SystemBootTime`): `mach_absolute_time`, `systemUptime`, `CACurrentMediaTime`;
  - disk space (`…DiskSpace`): `statfs`, `statvfs`, `fstatfs`, `volumeAvailableCapacity`;
  - active keyboards (`…ActiveKeyboards`): `activeInputModes`.

  Symbol scanning is conservative: it over-reports rather than misses. A detected category is declared only when a
  reason truthfully covers the use. Otherwise the code is changed or the release is blocked.
- **R2 Swift Foundation detection.** Swift `UserDefaults` and `FileManager.attributesOfItem` reach Objective-C
  through the Foundation overlay, so the binary references `_OBJC_CLASS_$_NSUserDefaults` and the attribute-key
  strings. The string scan uses the `__cstring` and `__objc_methname` contents (`strings -a`).
- **R3 Icon generation.** The hosted test renders the "Dusk" default at t = 12 s, 1024², through
  `ExportRunner.render(_:size:)`, and encodes it with `StillImageEncoder`. With `GAS_WRITE_ICON=1` it writes the
  repository path (derived from `#filePath`); otherwise it compares with the committed PNG (mean ≤ 1/255). An
  opaque, sRGB, 1024 PNG is what the single-size asset catalog requires.
- **R4 Launch cleanup.** At app start, `LaunchCleanup.run()` removes `tmp/Exports` (and only that folder). The
  store's hidden temporary files are already removed on load.
- **R5 Automation view.** `AutomationView(mode:bundleID:makeScene:configure:)` is a `UIViewRepresentable`: it creates
  the RenderHost with the scene and runs the mode after the first layout. On renderer failure it writes a
  `renderer-unavailable` report, as Showcase does now.
- **R6 Release config.** `docs/apps/<slug>/release.json` holds: `bundleID`, `version`, `build`,
  `allowedUsageDescriptions`, `requiredDocs`, `checklist` (path), `privacyManifest: true`, `icon: true`.
