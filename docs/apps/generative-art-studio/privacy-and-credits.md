# Generative Art Studio — privacy and credits

Release candidate 1.0.0 (1). This page is based on the app's actual behavior and on a scan of the Release build
(`scripts/check_privacy_manifest.py`). It is not sample text.

## Data

| What | Where | Leaves the device? |
|---|---|---|
| Saved compositions (name, family, seed, palette, parameter values, times, favorite flag) | `Application Support/Compositions/<uuid>.json` in the app's own container | No |
| Accessibility choices (Reduce Motion, Reduce Flashing: System/On/Off) | the app's own `UserDefaults` (`gas.a11y.reduceMotion`, `gas.a11y.reduceFlashing`) | No |
| Exported images | the app's temporary folder `tmp/Exports`, removed when the export sheet closes and at launch | Only when the user shares or saves them through the system share sheet |

- The app has no account, no analytics, no advertising, no tracking and no network code. The compliance check forbids
  networking APIs in app code.
- Privacy manifest: `NSPrivacyTracking` false, no tracking domains, no collected data types.
- App Store privacy label: **Data Not Collected**.

## Permissions

| Permission | Usage text | When iOS asks | UI path |
|---|---|---|---|
| Photos, add only (`NSPhotoLibraryAddUsageDescription`) | "Saves exported artwork to your photo library when you choose Save Image." | Only if the user picks **Save Image** in the share sheet | Scene → Export → Export Image → Share or Save Image → Save Image |

No other permission is declared or requested. The app reads the system Reduce Motion and Dim Flashing Lights
settings, which needs no permission.

## Required-reason APIs (privacy manifest)

| Category | Reason | Where the use is |
|---|---|---|
| UserDefaults | CA92.1: the app's own settings | SwiftUI `@AppStorage` for the two accessibility choices |
| File timestamp | C617.1: files inside the app container | `stat` in ANGLE's `libEGL`. A read-only source check shows a failed-`dlopen` diagnostic and `IsDirectory` on bundle and container paths; it reads no timestamps. |
| System boot time | 35F9.1: elapsed time inside the app | `CACurrentMediaTime`/`systemUptime` for frame timing (VisualCore), `mach_absolute_time` in ANGLE's `libGLESv2` |

Scan result (ledger check `A01-P06/t605-privacy-scan`): 3 categories detected = 3 declared, 0 undeclared, 0 unused.

## Credits and licenses

Shown in the app under **Settings → Acknowledgements**, with the full text of every shipped component.
`scripts/bundle_licenses.py` produces them from [`docs/legal/third-party.json`](../../legal/third-party.json):

- VisualCore (MIT);
- ANGLE (BSD-3-Clause) and its components: libc++ and libc++abi (Apache-2.0 WITH LLVM-exception), abseil-cpp,
  astc-encoder and Vulkan-Headers (Apache-2.0), llvm-libc (MIT, NCSA), perfetto (blessing, BSD-3-Clause, Apache-2.0),
  protobuf (BSD-3-Clause), zlib (Zlib);
- Robert Penner's easing equations (BSD-3-Clause, re-derived);
- xoshiro256** and SplitMix64 (public domain, re-implemented).

The app links no ProjectM code, presets or other LGPL components (dependency audit build phase, FR-A01-006).

**Art and content:** all four scene families, their shaders, palettes and presets, and the app icon are original to
this repository. The icon is the app's own render of the "Dusk" preset at t = 12 s (checked by `IconRenderTests`).
The app ships no fonts, sounds, textures or datasets.

## Owner actions

- Host the privacy policy below at a public URL and enter it in App Store Connect.
- Answer the App Privacy questionnaire with "Data Not Collected".

### Privacy policy text (to host)

> Generative Art Studio does not collect, store on a server, or share any personal data. Compositions and settings are
> saved only on your device. Images leave your device only when you share or save them yourself. The app has no
> accounts, analytics, advertising or tracking, and makes no network connections.
