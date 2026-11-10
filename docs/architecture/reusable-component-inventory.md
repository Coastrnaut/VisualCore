# Reusable-component inventory (feature 001, T-F011)

Classification of every reference package and app (8 packages, 3 apps), with the reason and the
source cited. Machine form: `reference-inventory.json` (`role` field). "Reusable candidate" means
the *idea or algorithm* may be re-implemented app-neutrally in VisualCore. The reference is never
imported by VisualCore or the 25 apps (Constitution II, ADR-0003); only the F07 harness links it.

| Component | Role | Reason (cited) | VisualCore consequence |
|---|---|---|---|
| `Packages/ANGLERendering` | ProjectM-specific (seam is reusable) | `ANGLERenderer` stores `ProjectMEngine`, `NormalizedPCMReader`, `PresetPrewarmer` (`ANGLERenderer.swift`) | Re-implement the identical EGL sequence app-neutrally (ADR-0002, F02); keep `CANGLE` constants as reference |
| `Packages/Rendering` | ProjectM-specific (parts reusable) | `VisualizerRenderer` requires presets and PCM (`VisualizerRenderer.swift`); `GLESRenderer` uses Apple OpenGLES | Reuse ideas: `QualityGovernor` table (30 fps floor, 0.75 scale at critical), `FrameRateMeter`, `CFlashLimiter` luminance limiter → VisualCore diagnostics/effects (F02, F04) |
| `Packages/ProjectMBridge` | ProjectM-specific | Wraps the LGPL engine (`PMBridge.mm`) | F07 harness only |
| `Packages/PresetLibrary` | ProjectM-specific | MilkDrop preset index/scopes | Not used |
| `Packages/AudioCore` | Reusable candidate | Normalizer, ring buffers, resampler are app-neutral algorithms | App-neutral audio DSP/ring in VisualCore (F08), re-implemented with tests |
| `Packages/CaptureKit` | ProjectM-specific | CaptureLab source drivers incl. ScreenCaptureKit | Not used; lessons only (no allocations/locks in callbacks; D3 capture unavailable) |
| `Packages/CaptureUI` | ProjectM-specific | CaptureLab source chooser UI | Not used |
| `Packages/Diagnostics` | Reusable candidate | Session diagnostics/export primitives | Ideas for `VisualCoreDiagnostics` JSON reports (F02, F09) |
| `Apps/projectM-iOS` | ProjectM-specific | Shipping visualizer | Lessons: `AutomationRunner` under `DEBUG \|\| PROJECTM_AUTOMATION`, StoreKit test isolation |
| `Apps/CaptureLab` | ProjectM-specific | Capture diagnostics tester | Not used |
| `Apps/RendererLab` | Tooling | Renderer benchmark harness | Pattern for VisualCore Graphics Benchmark Lab / device runner |

Reference tooling to port (not import): `check_compliance.py` (done in F01), `verify_environment.py`
(done), `run_device_tests.py` (F09 device campaign runner), `check_privacy_manifest.py` (F09),
`generate_gles_loader.py` (pattern used by `scripts/generate_vcgl.py`).
