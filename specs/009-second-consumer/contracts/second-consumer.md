# Contract: second consumer (Phase 8)

```swift
// GardenKit (host-testable)
public struct Garden { init(seed: UInt64)
  static let capacity = 24, minSpacing = 40.0, harvestRadius = 30.0, growthDuration = 4.0, seedFraction = 0.15,
             breezeTimeConstant = 1.0, breezeScale = 0.5, maxBreeze = 300.0
  mutating func plant(at: Vec2) -> PlantResult; mutating func tap(at: Vec2) -> TapResult
  mutating func interact(at: Vec2) -> InteractionResult      // the game's tap: harvest, notReady, or plant
  mutating func drag(velocity: Vec2); mutating func step(_ dt: Double)
  var flowers: [Flower]; var score: Int; var breeze: Vec2; var time: Double; var plantedCount: Int; var bloomingCount: Int }
public struct Flower: Identifiable { id; position; plantedAt; hue (0…1, seeded); stage; growth }
public enum FlowerStage { seed, growing, bloom, harvested }
public enum PlantResult { case planted(Int), tooClose, full }; public enum TapResult { case harvested(Int), notReady, nothing }
public enum InteractionResult { case planted(Int), harvested(Int), notReady, tooClose, full }
```

UI contract: `garden.title`, `garden.hint` (what the last tap did), `garden.canvas` (direct interaction, VoiceOver label/hint), `garden.diagnostics`
(`planted=… blooming=… score=… particles=…`), `garden.reset` button; launch argument `-uitestReduceMotion YES|NO`.

Checks:
```text
python3 scripts/audit_showcase_dependencies.py --spec Harnesses/SecondConsumer/SecondConsumer.yml --target SecondConsumer --sources Harnesses/SecondConsumer [--app …]
python3 scripts/check_documented_api.py --sources Harnesses/SecondConsumer [--packages Packages] [--docs …]   # exit 0/1/2
```
Bundle id `dev.visualcore.harness.SecondConsumer`.
