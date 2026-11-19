# Data Model: R02-F07

- **Pass `emissive`** (graph JSON): inputs `input`; params `threshold` [0,16] 1, `knee` [0,1] 0.5, `intensity` [0,4] 1,
  `radius` [1,16] 4, `quality` [0,1] 0 (rounded: 0 half, 1 quarter), `exposure` [−4,4] 0, `tonemap` [0,2] 0
  (rounded: 0 none, 1 Reinhard, 2 filmic). Output `.rgba8` at the pass's scale; estimate = output + 2 blur targets at
  8 B/px (half-float) or 4 B/px.
- **`composite.mode`**: [0,2]; 2 = premultiplied over.
- **`flashLimit.linear`**: [0,1] 0.
- **`RenderState.premultipliedBlended`**: blend `.premultiplied`, depth test off, depth write off.
- **`ToneMapOperator`** (pure): none, reinhard, filmic. **`EmissiveReference`** (pure): functions of clarification Q5.

As built (T-R02F07-013): the validator refuses a non-finite parameter on every pass
(`EffectGraphError.nonFiniteParameter`) and an out-of-range one only where `PassSchema.refusesOutOfRange` is true
(`emissive`; `parameterOutOfRange`); other passes still clamp, so `composite.mode` 3 becomes 2.
