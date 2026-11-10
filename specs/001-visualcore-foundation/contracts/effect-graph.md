# Contract: Effect graph (FR-F018–FR-F023)

```json
{ "version": 1,
  "passes": [ { "id": "blurH", "type": "blur", "inputs": {"source": "scene"},
                "output": "blurA", "scale": 0.5, "params": {"radius": 4, "direction": [1,0]} } ],
  "output": "final" }
```

* `"scene"` is the reserved input name for the scene's rendered image; `output` names a pass output.
* Validation order: version supported → ≤ 32 passes → unique ids/outputs → known `type` →
  each input refers to `scene` or an output of another pass → no cycles (Kahn) → graph output exists
  → estimated memory = Σ(w·scale × h·scale × 4 bytes) for each distinct output (+ feedback history)
  ≤ quota (default 256 MiB, apps may lower).
* Errors: `unsupportedVersion`, `tooManyPasses(n)`, `duplicateID`, `duplicateOutput`,
  `unknownType`, `missingInput(pass, name)`, `cycle([ids])`, `missingOutput`, `overQuota(bytes)`.
* Execution: passes in topological order, deterministic tie-break by declaration order.
  A pass whose program fails is replaced by copy (pass-through) and reported once.
* Built-in types: `copy`, `colorMatrix`, `blur`, `bloom`, `distort`, `composite`, `feedback`,
  `flashLimit`.
