# Data Model: R02-F03

## SeededRandom.State (version 1)

| Field | Type | Rule |
|---|---|---|
| `version` | Int | exactly 1; any other value → `RandomStateError.unsupportedVersion(Int)` |
| `seed` | String | 16 lower-case hexadecimal digits (the generator's `seed`) |
| `words` | [String] | exactly 4 entries of 16 lower-case hexadecimal digits (s0…s3); not all zero |

JSON example: `{"version":1,"seed":"000000000000002a","words":["…","…","…","…"]}`.
Errors (`RandomStateError`): `unsupportedVersion`, `wrongWordCount`, `malformedWord(String)`, `allZero`.
Restoring gives a generator equal (`==`) to the saved one and continuing its sequence.

## Sub-seed derivation

- `mix(z)`: `z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9; z = (z ^ (z >> 27)) &* 0x94D049BB133111EB; z ^ (z >> 31)`.
- `fnv1a64(label)`: offset basis `0xcbf29ce484222325`, prime `0x100000001b3`, over the UTF-8 bytes.
- `derive(seed, label:) = mix(seed ^ fnv1a64(label))`; `derive(seed, index:) = mix(seed ^ mix(index &+ 1))`.

## Choice inputs

- `index(below: n)`: n ≥ 1 (precondition documented; `pick`/`weightedIndex` report instead of trapping).
- Weights: non-empty, every weight finite and ≥ 0, positive finite sum; errors (`RandomChoiceError`): `empty`,
  `negativeWeight(index)`, `nonFiniteWeight(index)`, `zeroTotal`.
- Weighted choice: one draw `u = double() * total`, first index whose running sum exceeds `u` (skipping zero weights).

## Numeric hygiene

- `NumericError`: `nonFinite`, `nonPositiveModulus`, `nonPositiveStep`, `outOfRange`.
- `quantized(x, step)`: `Int64((x / step).rounded(.toNearestOrEven))`, −0 → 0; |x/step| ≥ 2^63 → `outOfRange`.
