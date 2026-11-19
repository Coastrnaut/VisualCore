# Data Model: A25-P01

- **EffectID:** `grade`, `blur`, `distort`, `vignette`, `posterize` (raw strings, version 1 each).
- **ParameterSpec:** name, range (closed, finite), default (inside), whole (Bool).
- **EffectDefinition:** id, version, title, parameters (ordered), fingerprint (domain `a25.effect.v1`).
- **EffectNode:** id (1…65,535), effect (EffectID), enabled (Bool), values (name → Double, every parameter present).
- **EffectChain:** nodes (≤ 8, unique ids), fingerprint (domain `a25.effect-chain.v1`).
- **ChainEdit:** add(effect, at), remove(at), move(from, to), setEnabled(at, Bool), setValue(at, name, Double).
- **EditHistory:** undo and redo stacks of applied edits with their inverses, depth ≤ 64.
- **Chain file:** `{"body": {"nodes": [...]}, "kind": "a25.effect-chain", "version": 1}`, sorted keys, ≤ 65,536 bytes;
  refusals `damaged`, `newer-version`, `too-large`, `not-finite`, `out-of-range`, `unknown-effect`,
  `unknown-parameter`, `missing-parameter`, `too-many-nodes`, `duplicate-node`.
- **RGBAImage:** width, height, bytes (RGBA8, rows top-down); the test image 64 × 64 per the spec.
