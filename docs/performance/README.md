# Performance baselines (feature 010 T-F909; FR-F905)

**These are host and simulator numbers. They are not device evidence** (constitution V). Device performance
claims come only from campaign II on D1 (iPhone15,4, iOS 27.0.1), D2 (iPad17,3, iPadOS 27.2) and
D3 (iPad15,7, iPadOS 26.5), using real AutomationRunner reports. The baselines here exist to catch regressions
between commits on the same Mac.

## Host — `baselines-host.json`

```bash
swift run -c release --package-path Packages/VisualCore VisualCoreBaselines --json > docs/performance/baselines-host.json
```

Each benchmark is warmed up once and then run 15 times. The file records the median, minimum and maximum
microseconds per operation, plus the host's macOS version, CPU, model and core count.

| Benchmark | What it measures |
|---|---|
| `particle-step-10k` | `ParticleSystem.step(1/60)` with 10,000 live particles, gravity + drag |
| `effect-graph-validate-16` | `EffectGraphValidator.validate` of a 16-pass chain at 1920×1080 |
| `shader-expand-include` | `ShaderLibrary.expand` with nested includes, defines and line map |
| `coordinate-mapping-roundtrip` | `ViewMetrics` point → world → point through a rotated, zoomed `Camera2D` |

## Simulator — `baselines-simulator.json`

```bash
xcodebuild build -project VisualCore.xcodeproj -scheme Showcase -configuration Release \
  -destination "generic/platform=iOS Simulator" -derivedDataPath Build/DerivedData/Showcase-measurement-sim \
  CODE_SIGNING_ALLOWED=NO SWIFT_ACTIVE_COMPILATION_CONDITIONS=VISUALCORE_AUTOMATION
python3 scripts/simulator_baselines.py \
  --app Build/DerivedData/Showcase-measurement-sim/Build/Products/Release-iphonesimulator/Showcase.app
```

The script uses the Showcase measurement build (Release + `VISUALCORE_AUTOMATION`) on the iOS 27.2 and 26.5
simulators. It runs `smoke` 3 times at 300 frames each and records the median frame time and p95. It runs
`launch` 10 times and records the median and maximum time from runner creation to the first presented frame.
Simulator GPU timing comes from the Mac's GPU through the simulator, so it says nothing about any iPhone or iPad.

## Updating

Rerun both commands on a quiet Mac, with no other build running, and commit the JSON together with the change that
explains it. Compare only against baselines recorded on the same host model.
