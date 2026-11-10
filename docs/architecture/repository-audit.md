# Repository audit — ProjectM-iOS reference (feature 001, T-F006)

Generated from `docs/architecture/reference-inventory.json` (`scripts/inventory_reference.py`) and
`docs/architecture/projectm-reference-audit.json` (`scripts/audit_projectm_reference.py`). Paths are relative
to `External/projectm-ios` at the pinned commit. Read-only: no reference file was changed
(`scripts/check_reference_clean.py`).

## Pins

| Item | Commit | Remote / branch |
|---|---|---|
| Superproject gitlink → reference HEAD | `1ad0b99` (equal: True) | Coastrnaut/projectm-ios |
| `Vendor/angle` | `29d1823` | Coastrnaut/angle.git ios |
| `Vendor/presets/cream-of-the-crop` | `0180df2` | projectM-visualizer/presets-cream-of-the-crop.git  |
| `Vendor/presets/en-d` | `fff71ea` | projectM-visualizer/presets-en-d.git  |
| `Vendor/presets/milkdrop-original` | `e03b83e` | projectM-visualizer/presets-milkdrop-original.git  |
| `Vendor/presets/milkdrop-texture-pack` | `6368812` | projectM-visualizer/presets-milkdrop-texture-pack.git  |
| `Vendor/presets/projectm-classic` | `14a6244` | projectM-visualizer/presets-projectm-classic.git  |
| `Vendor/projectM` | `c88894e` | Coastrnaut/projectm.git ios |

## Packages (SwiftPM manifests) (8)

| Path | Role | Detail |
|---|---|---|
| `Packages/ANGLERendering/Package.swift` | projectm-specific | targets: libEGL, libGLESv2, CANGLE, ANGLERendering, ANGLERenderingTests; local_deps: ../AudioCore, ../ProjectMBridge, ../Rendering; reason: EGL/ANGLE lifecycle is reusable in principle but ANGLERenderer hard-wires Projec |
| `Packages/AudioCore/Package.swift` | reusable-candidate | targets: AudioCore, AudioCoreTests; local_deps: ; reason: PCM normalization, ring buffers and resampling are app-neutral; types are named for the visualizer; platforms: iOS, macOS |
| `Packages/CaptureKit/Package.swift` | projectm-specific | targets: CaptureKit, CaptureKitTests; local_deps: ../AudioCore; reason: System/App Capture + microphone + in-app playback drivers for CaptureLab; ScreenCaptureKit path is product-specific; platforms: iOS, macOS |
| `Packages/CaptureUI/Package.swift` | projectm-specific | targets: CaptureUI, CaptureUITests; local_deps: ../CaptureKit, ../AudioCore; reason: SwiftUI for CaptureLab source selection; platforms: iOS, macOS |
| `Packages/Diagnostics/Package.swift` | reusable-candidate | targets: Diagnostics; local_deps: ../AudioCore; reason: session diagnostics/export primitives; platforms: iOS, macOS |
| `Packages/PresetLibrary/Package.swift` | projectm-specific | targets: PresetLibrary, PresetLibraryTests; local_deps: ; reason: MilkDrop preset index, scopes, search; platforms: iOS, macOS |
| `Packages/ProjectMBridge/Package.swift` | projectm-specific | targets: ProjectM, ProjectMBridge, ProjectMBridgeTests; local_deps: ; reason: Swift/ObjC bridge to the LGPL projectM engine; platforms: iOS |
| `Packages/Rendering/Package.swift` | projectm-specific | targets: CFlashLimiter, Rendering, RenderingTests; local_deps: ../AudioCore, ../ProjectMBridge; reason: VisualizerRenderer protocol, preset repository and GLES (Apple OpenGLES) backend for the engine; QualityGovernor/Fra |

## Test targets (8)

| Path | Role | Detail |
|---|---|---|
| `Packages/ANGLERendering/Tests/ANGLERenderingTests` | projectm-specific | swift_files: 2; test_funcs: 13 |
| `Packages/AudioCore/Tests/AudioCoreTests` | reusable-candidate | swift_files: 9; test_funcs: 77 |
| `Packages/CaptureKit/Tests/CaptureKitTests` | projectm-specific | swift_files: 5; test_funcs: 80 |
| `Packages/CaptureUI/Tests/CaptureUITests` | projectm-specific | swift_files: 2; test_funcs: 10 |
| `Packages/Diagnostics/Tests/DiagnosticsTests` | reusable-candidate | swift_files: 1; test_funcs: 8 |
| `Packages/PresetLibrary/Tests/PresetLibraryTests` | projectm-specific | swift_files: 4; test_funcs: 14 |
| `Packages/ProjectMBridge/Tests/ProjectMBridgeTests` | projectm-specific | swift_files: 1; test_funcs: 13 |
| `Packages/Rendering/Tests/RenderingTests` | projectm-specific | swift_files: 5; test_funcs: 25 |

## Project generation (XcodeGen) (2)

| Path | Role | Detail |
|---|---|---|
| `project.yml` | tooling | targets: CaptureLab, CaptureLabUITests, projectM-iOS, projectM-iOSTests, projectM-iOSUITests; schemes: projectM-iOS, CaptureLab; deployment_target: 26.0 |
| `RendererLab.yml` | tooling | targets: RendererLab; schemes: ; deployment_target: 26.0 |

## Apps (3)

| Path | Role | Detail |
|---|---|---|
| `Apps/CaptureLab` | projectm-specific | xcodegen_spec: project.yml; reason: tester-only capture diagnostics app; swift_files: 5 |
| `Apps/projectM-iOS` | projectm-specific | xcodegen_spec: project.yml; reason: shipping visualizer app; swift_files: 35 |
| `Apps/RendererLab` | tooling | xcodegen_spec: RendererLab.yml; reason: renderer benchmark harness for ADR-0003; swift_files: 3 |

## Scripts (14)

| Path | Role | Detail |
|---|---|---|
| `scripts/build_angle_xcframework.py` | tooling | Build ANGLE (Metal backend) as iOS xcframeworks from a pinned source (task T076; ADR-0003 Option B; |
| `scripts/build_preset_index.py` | tooling | Build the preset library index and archive (feature 002; tasks T204, T205, T214). |
| `scripts/build_projectm_xcframework.py` | tooling | Build the projectM engine as a dynamic `Build/ProjectM.xcframework` (task T065; RI-011; ADR-0004). |
| `scripts/check_capturelab_export.py` | tooling | Host-side check of a CaptureLab diagnostics export (task T039; used after CaptureLabUITests). |
| `scripts/check_compliance.py` | tooling | Constitution compliance check, run on every merge (tasks T014/T015). |
| `scripts/check_privacy_manifest.py` | tooling | Check a built app against its privacy manifest (task T106; FR-066). macOS only (uses nm). |
| `scripts/collect_licenses.py` | tooling | Collect the license texts for the Licenses screen (task T103; FR-067, ADR-0004, ADR-0005). |
| `scripts/generate_gles_loader.py` | tooling | Generate the static OpenGL ES 3.0 load-proc table for ProjectMBridge (tasks T068/T069, T071). |
| `scripts/generate_reference_audio.py` | tooling | Generate the deterministic In-App Playback reference track (task T044, FR-006, SC-006). |
| `scripts/make_diagnostic_project.py` | tooling | Generate a temporary diagnostic CaptureLab project (owner review 2026-11-08, ADR-0001 ruling 12). |
| `scripts/run_device_tests.py` | tooling | Run feature 002's device tests from the Mac (T238 performance and size, T239 purchase checks, |
| `scripts/test_scripts.py` | tooling | Tests for the repository scripts. Run: python scripts/test_scripts.py (Windows or macOS). |
| `scripts/validate_docs.py` | tooling | Validate cross-references in the specification documents (task T003). |
| `scripts/verify_environment.py` | tooling | Check the build toolchain against the pins in ADR-0002 (task T004). |

## CI (1)

| Path | Role | Detail |
|---|---|---|
| `.github/workflows/ios-ci.yml` | tooling | jobs: docs-and-compliance, host-tests-linux, build-and-test-apple, engine-xcframework, angle-xcframeworks, build-ios27 |

## Dependencies (submodules) (7)

| Path | Role | Detail |
|---|---|---|
| `Vendor/angle` | reusable-candidate | commit: 29d18232e8031430f1257b7509ceca20d195114d |
| `Vendor/presets/cream-of-the-crop` | content | commit: 0180df21f5e0bd39b9060cc5de420ed2f1f9e509 |
| `Vendor/presets/en-d` | content | commit: fff71ea81223109f3558351667eef851f2781c96 |
| `Vendor/presets/milkdrop-original` | content | commit: e03b83e3338d8f1ed6cbcf908c719f249ef24288 |
| `Vendor/presets/milkdrop-texture-pack` | content | commit: 6368812f27bc747b517218fbf89d21d59afce4d9 |
| `Vendor/presets/projectm-classic` | content | commit: 14a6244a7d32eb7e114e1a92d1cb93358cdcc54a |
| `Vendor/projectM` | projectm-specific | commit: c88894e966b3a862be148466b5d5c6e68d8bb9f1 |

## Licenses (13)

| Path | Role | Detail |
|---|---|---|
| `LICENSE` | content | MIT License |
| `Vendor/projectM/COPYING` | content | /** |
| `Vendor/angle/LICENSE` | content | // Copyright 2018 The ANGLE Project Authors. |
| `Build/ANGLEFrameworks/licenses/ANGLE.txt` | content | ANGLE third-party notice (build output) |
| `Build/ANGLEFrameworks/licenses/abseil-cpp.txt` | content | ANGLE third-party notice (build output) |
| `Build/ANGLEFrameworks/licenses/astc-encoder.txt` | content | ANGLE third-party notice (build output) |
| `Build/ANGLEFrameworks/licenses/libc++.txt` | content | ANGLE third-party notice (build output) |
| `Build/ANGLEFrameworks/licenses/libc++abi.txt` | content | ANGLE third-party notice (build output) |
| `Build/ANGLEFrameworks/licenses/llvm-libc.txt` | content | ANGLE third-party notice (build output) |
| `Build/ANGLEFrameworks/licenses/perfetto.txt` | content | ANGLE third-party notice (build output) |
| `Build/ANGLEFrameworks/licenses/protobuf.txt` | content | ANGLE third-party notice (build output) |
| `Build/ANGLEFrameworks/licenses/vulkan-headers.txt` | content | ANGLE third-party notice (build output) |
| `Build/ANGLEFrameworks/licenses/zlib.txt` | content | ANGLE third-party notice (build output) |

## Historical documents (context only, VC-016) (2)

| Path | Role | Detail |
|---|---|---|
| `specs` | content | files: 27; note: historical context only (VC-016); never VisualCore evidence |
| `docs` | content | files: 110; note: historical context only (VC-016); never VisualCore evidence |

## Unknowns

- None for the inventory itself. Rendering unknowns U-F001–U-F003 are in `current-rendering-pipeline.md`.
