# F00 — ProjectM-iOS reference audit (2026-11-10)

Gate F00 of the VisualCore implementation campaign. **Read-only**: nothing in
`External/projectm-ios` was modified, rebuilt or cleaned. Machine-readable data:
[`projectm-reference-audit.json`](projectm-reference-audit.json), toolchain:
[`../verification/environment-F00.json`](../verification/environment-F00.json), devices:
[`../verification/devices-observed.json`](../verification/devices-observed.json).
Evidence: `.autonomy/evidence/F00.json` (commands `scripts/verify_environment.py`,
`scripts/audit_projectm_reference.py`, `scripts/inventory_devices.py`, each run through
`desktop_runbook.py run-check`).

## 1. Pins and provenance

| Item | Value | Notes |
|---|---|---|
| `External/projectm-ios` | `1ad0b99` (superproject pin = checkout HEAD, clean) | owner's MIT-licensed app repo |
| `Vendor/projectM` | `c88894e` on `Coastrnaut/projectm` `ios` | equals the historical milestone commit recorded in the owner's guide |
| `Vendor/angle` | `29d1823` on `Coastrnaut/angle` `ios` (shallow) | `gclient` tree ≈ 12.1 GB (`du -sk` = 12,111,196 KB); never moved/cleaned |
| Preset packs | 5 shallow pinned submodules (`projectM-visualizer/presets-*`) | ProjectM reference content only; **not** a dependency of the 25 apps |

## 2. Rendering baseline actually present

* `Build/ANGLEFrameworks/libEGL.xcframework` and `libGLESv2.xcframework`, built by the reference's
  own `scripts/build_angle_xcframework.py` from the **pinned** ANGLE commit (ANGLE.json
  `angleCommit` = pin). Slices: `ios-arm64` (device) and `ios-arm64_x86_64-simulator`.
  `MinimumOSVersion 26.0`, `CFBundleShortVersionString 1.0` (App Store validation requirement met).
* GN args: Metal backend only (`angle_enable_metal=true`, GL/Vulkan/SwiftShader/null/wgpu off),
  release, non-component.
* Exports: libEGL 115 `egl*` entry points; libGLESv2 827 `gl*` entry points.
* `Build/ProjectM.xcframework` is **absent** in the checkout: only the ProjectM reference adapter
  (F07) needs it; it will be produced by the reference's own `scripts/build_projectm_xcframework.py`.
  The 25 apps never link it (VC-008).

## 3. Integration seam (actual source, `Packages/ANGLERendering`)

* `CANGLE` (C): declares the EGL subset from ANGLE's headers at the pinned commit; GL entry points
  are resolved through `eglGetProcAddress` (no `dlsym`).
* `ANGLERenderer` (Swift, `@MainActor`): `eglGetPlatformDisplay(EGL_PLATFORM_ANGLE_ANGLE,
  METAL)` → `eglInitialize` → RGBA8 ES3 config (window|pbuffer) → ES 3.0 context → 1×1 pbuffer
  placeholder kept current until the view has a size → `eglCreateWindowSurface` on a
  `CAMetalLayer` (BGRA8), recreated on drawable-size change → `CADisplayLink` frame loop on the
  main thread → `eglSwapBuffers`. Thermal/Low-Power frame caps via `QualityGovernor`; Reduce
  flashing via the C `FlashLimiter` post-pass. Teardown order: make placeholder current, destroy
  GPU objects, unbind, destroy surfaces and context.
* The ProjectM engine types (`ProjectMEngine`, `Preset`, `NormalizedPCMReader`) are woven into
  this renderer, so it **cannot** be reused as-is by app-neutral VisualCore. ADR-0002 records the
  decision: VisualCore re-implements the *same* EGL/ANGLE lifecycle (same libraries, same
  platform attributes, same surface strategy) without ProjectM types, and the F07 adapter proves
  the reference renderer still builds unchanged.

## 4. Toolchain (re-verified, not upgraded)

Xcode 27.2 (27B52), iOS SDK 27.2, Swift 6.4.2, XcodeGen 2.46.0, CMake 4.4.5, Python 3.15.2;
simulator runtimes iOS 26.5 (23F77) and iOS 27.2 present. All match `Configs/toolchain.json`.

## 5. Device inventory (no testing)

Only `xcrun devicectl list devices` was run. Physical devices are matched by
`hardwareProperties.productType` **and** `hardwareProperties.reality == "physical"` — CoreSimulator
devices with the same product type (e.g. a simulated `iPad15,7`) appear in the same list.

| Role | Product type | Observed OS | Dev Mode | Status |
|---|---|---|---|---|
| D1 | iPhone15,4 | iOS 27.0.1 (24A446) | enabled | baseline |
| D2 | iPad17,3 | iPadOS 27.2 (24B119) | enabled | baseline |
| D3 | iPad15,7 | iPadOS 26.5 (23F77) | enabled | baseline — never upgrade |

Hardware UDIDs are kept in `.autonomy/private/` (gitignored). No install, launch or XCTest was
issued; the device campaign is blocked by `desktop_runbook.py guard-device` until
IMPLEMENTATION-LOCK.

## 6. Licenses recorded

* projectm-ios: MIT (Coastrnaut / owner) — VisualCore may adapt its glue with attribution.
* projectM engine: LGPL-2.1 (`COPYING`, `LICENSE.txt`) — linked only by the F07 reference adapter;
  a linkage analysis is required before distributing anything that contains it.
* ANGLE: BSD-3-Clause plus third-party notices in `Build/ANGLEFrameworks/licenses/` (abseil,
  astc-encoder, libc++, libc++abi, llvm-libc, perfetto, protobuf, vulkan-headers, zlib) — every
  app that embeds ANGLE must ship these notices (tracked in `docs/licenses/`).

## 7. Reusable reference scripts found

`build_angle_xcframework.py`, `build_projectm_xcframework.py`, `check_compliance.py`,
`check_privacy_manifest.py`, `generate_gles_loader.py`, `run_device_tests.py`, `validate_docs.py`,
`test_scripts.py`, `verify_environment.py`. VisualCore ports the applicable checks into its own
`scripts/` rather than importing paths from the submodule.

## 8. Addendum 2026-11-10 — Spec Kit rework (feature `specs/001-baseline-audit`, ADR-0004)

F00 was sealed before its Spec Kit sequence ran. The archive's Phase 0 prompts were then run
(specify → clarify → plan → checklist → tasks → analyze → implement → converge). They added the
deliverables the archived Phase 0 required:

* [`repository-audit.md`](repository-audit.md) + [`reference-inventory.json`](reference-inventory.json): full inventory.
* [`current-rendering-pipeline.md`](current-rendering-pipeline.md): cited trace (48 citations, all resolved).
* [`reusable-component-inventory.md`](reusable-component-inventory.md) and [`visualcore-gap-analysis.md`](visualcore-gap-analysis.md).
* [`../verification/projectm-baseline.md`](../verification/projectm-baseline.md): reproducible build and simulator smoke of the unmodified reference.

The rework checks were recorded with `run-check` under the then-current gate F02 (names
`f00rework-*`), because the ledger accepts checks only for the current gate.
