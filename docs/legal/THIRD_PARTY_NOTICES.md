# Third-party notices — VisualCore 1.0.0-rc.1

Machine-readable inventory: [`third-party.json`](third-party.json), checked by `scripts/check_licenses.py` (every binary
or external package dependency must map to an entry with an allowed license and an existing license text).

## Shipped with any VisualCore-based app

| Component | License | Notes |
|---|---|---|
| VisualCore (this repository) | MIT | [`LICENSE`](../../LICENSE) |
| ANGLE (owner fork `Coastrnaut/angle@ios`, pin `29d1823`) — `libEGL`, `libGLESv2` | BSD-3-Clause | Copyright The ANGLE Project Authors |
| libc++, libc++abi (inside ANGLE) | Apache-2.0 WITH LLVM-exception | The LLVM Project |
| abseil-cpp, astc-encoder, Vulkan-Headers (inside ANGLE) | Apache-2.0 | The Abseil Authors; Arm Limited; The Khronos Group |
| llvm-libc (inside ANGLE) | MIT, NCSA | The LLVM Project |
| perfetto (inside ANGLE) | blessing, BSD-3-Clause, Apache-2.0 | The Android Open Source Project |
| protobuf (inside ANGLE) | BSD-3-Clause | Google Inc. |
| zlib (inside ANGLE) | Zlib | Jean-loup Gailly and Mark Adler |

The full license texts for ANGLE and its components are kept, unmodified, in the pinned reference at
`External/projectm-ios/Apps/projectM-iOS/Resources/Licenses/`. **Every distributed app must bundle these texts** and show
them. `scripts/bundle_licenses.py` bundles them, and `VisualCoreUI.AcknowledgementsView` shows them (feature 017; Generative
ArtStudio is the first adopter).

## Algorithms re-implemented in VisualCore (no third-party code copied)

- **xoshiro256\*\* and SplitMix64** (David Blackman and Sebastiano Vigna, released to the public domain;
  prng.di.unimi.it) — `VisualCoreSimulation.SeededRandom`, written from the published algorithm; golden values were
  checked against an independent implementation.
- **Easing curves** after Robert Penner's easing equations (published under the BSD license) — `VisualCoreMath.ease`,
  re-derived from the formulas. Attribution: "Easing Equations (c) 2001 Robert Penner" (BSD-3-Clause).

## Harness only — never linked into a shipped VisualCore target

| Component | License | Where |
|---|---|---|
| libprojectM (`Coastrnaut/projectm@ios`, pin `c88894e`) via `ProjectMBridge` | LGPL-2.1 | `Harnesses/ProjectMReference` (tester tool, not distributed) — see [LGPL analysis](lgpl-analysis.md) |
| glad, GLM, hlslparser, projectm-eval, stb_image (inside the engine) | WTFPL/CC0/Apache-2.0, MIT, MIT, MIT, MIT/Unlicense | same |
| Milkdrop preset packs | per-preset authors | reference content only; not used by VisualCore |

## Tools (not shipped)

XcodeGen 2.46.0 (MIT), GitHub Spec Kit 1.4.1.dev0 (MIT), Apple Xcode toolchain (Apple license).
