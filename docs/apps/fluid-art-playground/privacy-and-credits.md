# Fluid Art Playground — privacy and credits

Release candidate 1.0.0 (1). This page is based on the app's actual behavior, its tests and a scan of the Release
build (`scripts/check_privacy_manifest.py`). It is not sample text.

## Data

| What | Where | Leaves the device? |
|---|---|---|
| Nothing persisted: no settings, no documents, no saved fluids | — (`PrivacyTests.testSessionStoresNothing`: 0 defaults keys, no files) | — |
| The latest captured picture | the app's temporary folder `tmp/Captures` (VisualCore `TemporaryFolder`). Only one file exists; it is removed when the playground closes and at every launch (`CrashRecoveryTests`). | Only when the person shares or saves it through the system share sheet |

- The app has no account, analytics, advertising, tracking or network code. The compliance check forbids networking
  APIs in app code.
- Touch paths are used only to move the fluid in the current frame. They are never recorded or stored.
- Privacy manifest: `NSPrivacyTracking` false, no tracking domains, no collected data types.
- App Store privacy label: **Data Not Collected**.
- Debug and automation builds may write automation reports (`visualcore-automation-*.json`) to Documents for the
  device campaign. They are never shipped (the Release build has 0 automation symbols, per
  `check_release_symbols.py`), so they are outside this statement.
- Migration: nothing is stored, so there is nothing to migrate. `FluidConfiguration` schema version 1 is the starting
  point if a later version persists settings.

## Permissions

| Permission | Usage text | When iOS asks | UI path |
|---|---|---|---|
| Photos, add only (`NSPhotoLibraryAddUsageDescription`) | "Fluid Art Playground saves your captured picture to Photos only when you choose Save Image." | Only if the person picks **Save Image** in the share sheet | Playground → Capture → Share or Save Image → Save Image |

No other permission is declared or requested (`PrivacyTests.testOnlyPhotosAddUsageStringIsDeclared`). The app reads
the thermal state, Low Power Mode and the Dim Flashing Lights setting, which need no permission.

## Required-reason APIs (privacy manifest)

| Category | Reason | Where the use is |
|---|---|---|
| File timestamp | C617.1: files inside the app container | `stat` in ANGLE's `libEGL` (same pinned build as A01). A read-only source check shows a failed-`dlopen` diagnostic and `IsDirectory` on bundle and container paths; it reads no timestamps. |
| System boot time | 35F9.1: elapsed time inside the app | `CACurrentMediaTime` and `systemUptime` for frame timing and the quality policy (VisualCore), and `mach_absolute_time` in ANGLE's `libGLESv2` |

There is no UserDefaults category: the app stores no settings. Scan result (ledger check `A02-P06/t605-privacy-scan`):
2 categories detected = 2 declared, 0 undeclared, 0 unused.

## Credits and licenses

They are shown in the app under **Home → Acknowledgements**, with the full text of every shipped component.
`scripts/bundle_licenses.py` produces them from [`docs/legal/third-party.json`](../../legal/third-party.json):

- VisualCore (MIT), this repository, which includes the app;
- ANGLE (BSD-3-Clause) and its components:
  - libc++ and libc++abi (Apache-2.0 WITH LLVM-exception);
  - abseil-cpp, astc-encoder and Vulkan-Headers (Apache-2.0);
  - llvm-libc (MIT, NCSA);
  - perfetto (blessing, BSD-3-Clause, Apache-2.0);
  - protobuf (BSD-3-Clause);
  - zlib (Zlib);
- Robert Penner's easing equations (BSD-3-Clause, re-derived);
- xoshiro256** and SplitMix64 (public domain, re-implemented).

The app links no ProjectM code, presets or other LGPL components (dependency audit build phase, FR-A02-006).

**Art and content:**
- The solver, shaders, palettes and the app icon are original to this repository.
- The icon is the app's own render: the deterministic test mode (gentle setting), seed 3, Glowing dye, 90 frames,
  checked by `IconRenderTests`.
- The fluid is an artistic simulation, not a physically accurate one.
- The app ships no fonts, sounds, textures or datasets.

## Owner actions

- Host the privacy policy below at a public URL and enter it in App Store Connect.
- Answer the App Privacy questionnaire with "Data Not Collected".

### Privacy policy text (to host)

> Fluid Art Playground does not collect, store on a server, or share any personal data. It saves nothing about you
> on your device either: no settings and no drawings are kept. A captured picture leaves your device only when you
> share or save it yourself. The app has no accounts, analytics, advertising or tracking, and makes no network
> connections.
