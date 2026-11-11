# Contract: second consumer (Phase 8)

```swift
// GardenKit (host-testable)
public struct Garden { init(seed: UInt64); capacity; minSpacing; harvestRadius; growthDuration
  mutating func plant(at: Vec2) -> PlantResult; mutating func tap(at: Vec2) -> TapResult
  mutating func drag(velocity: Vec2); mutating func step(_ dt: Double)
  var flowers: [Flower]; var score: Int; var breeze: Vec2; var plantedCount: Int; var bloomingCount: Int }
public struct Flower { id; position; plantedAt; stage; growth }
public enum PlantResult { case planted(Int), tooClose, full }; public enum TapResult { case harvested(Int), notReady, nothing }
```

UI contract: `garden.canvas` (direct interaction, VoiceOver label/hint), `garden.diagnostics`
(`planted=… blooming=… score=… particles=…`), `garden.reset` button; launch argument `-uitestReduceMotion YES|NO`.

Checks:
```text
python3 scripts/audit_showcase_dependencies.py --spec Harnesses/SecondConsumer/SecondConsumer.yml --target SecondConsumer --sources Harnesses/SecondConsumer [--app …]
python3 scripts/check_documented_api.py --sources Harnesses/SecondConsumer [--packages Packages] [--docs …]   # exit 0/1/2
```
Bundle id `dev.visualcore.harness.SecondConsumer`.
