# Data model: A09-P03

| Type | Change | Rules |
|---|---|---|
| `FoodPellet` (core) | new: `position: Vec2` | finite, inside the swim bounds |
| `HabitatDocument` | `currentSchema = 3`; + `food: [FoodPellet]` (≤ 12; missing → []) | validation: count ≤ 12, positions finite and inside the bounds |
| `AquariumState` (snapshot) | schema 3; + `decorKind: Int` (0…catalog decor count − 1; missing → 0) | restore refuses an out-of-range kind |
| Feed | 3 pellets at x − 0.25, x, x + 0.25, clamped into the swim bounds | refused whole when count + 3 > 12 |
| Decor edit | place (kind, point clamped into the tank, rotation 0, scale 1), move (index, point clamped), remove (index) | ≤ 12 pieces; missing index refused |

State transitions: habitat change → food [] and starter decor; feed → +3 pellets; each step → sink, eat, floor removal.
Suspension → no steps.
