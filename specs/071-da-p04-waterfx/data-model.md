# Data model: A09-P04

| Type | Change | Rules |
|---|---|---|
| `StarterHabitat` | + `vents: [Double]` (x positions; missing → []) | each finite, 0.5…15.5; at most 4 |
| Bundled habitats | Reef vents [3.0, 12.5]; Kelp vents [5.5, 10.0] | — |
| Bubble (derived) | position from step, vent and index | y 1.0…9.0; ≤ 24 per vent, ≤ 48 total |
| Mote (derived) | position from step and index | 24; x wraps 0…16; y 1.5…8.5 |
| Depth layer (derived) | index mod 3 → scale, tint | 0.75/0.875/1.0; 0.35/0.15/0 |
| `AquariumAnnouncer` | interval 3 s, VoiceOver gate, lastTime, pending | not saved |

No saved-state change; `HabitatDocument` and the snapshot stay at schema 3.
