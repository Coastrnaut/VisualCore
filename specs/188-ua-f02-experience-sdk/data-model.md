# Data model: UA-F02 — ExperienceKit

Signatures: [contracts/experience-core-api.md](contracts/experience-core-api.md) and
[contracts/experience-host-api.md](contracts/experience-host-api.md).

## 1. Lifecycle transitions (20 legal pairs)

| From | Legal targets |
|---|---|
| registered | preparing, failed |
| preparing | ready, deactivating, failed |
| ready | active, deactivating, failed |
| active | suspended, deactivating, failed |
| suspended | active, deactivating, failed |
| deactivating | inactive, failed |
| inactive | preparing, failed |
| failed | preparing, deactivating |

Every other ordered pair, including a state with itself, is rejected (44 pairs). A rejected attempt keeps the
state, adds one to `rejectedTransitions` and is appended to the history with `accepted == false`. The history
holds at most `historyLimit` events and drops the oldest first.

## 2. Operations and the states in which they are legal

| Operation | registered | preparing | ready | active | suspended | deactivating | inactive | failed |
|---|---|---|---|---|---|---|---|---|
| prepare | yes | – | – | – | – | – | yes | yes |
| activate | – | – | yes | – | – | – | – | – |
| update | – | – | – | yes | – | – | – | – |
| action | – | – | – | yes | – | – | – | – |
| snapshot | – | – | yes | yes | yes | – | – | – |
| restore | – | – | yes | yes | yes | – | – | – |
| reset | – | – | yes | yes | yes | – | – | – |
| setQualityTier | – | – | yes | yes | yes | – | – | – |
| shedCaches | – | – | yes | yes | yes | – | – | – |
| suspend | – | – | – | yes | – | – | – | – |
| resume | – | – | – | – | yes | – | – | – |
| deactivate | – | yes | yes | yes | yes | – | – | yes |

28 legal cells of 96. A refused operation adds one to `rejectedOperations`, throws
`ExperienceError.illegalOperation` (an action answers `.rejected(.notActive)`) and does not reach the core.

Effect on the state: prepare → preparing, then ready, failed, or (cancelled) deactivating and inactive; activate →
active; suspend → suspended; resume → active; deactivate → deactivating, then inactive or (GPU leak) failed. The
other operations keep the state.

## 3. Digest encoding

`DigestBuilder` appends fields to a byte sequence; `finish()` returns the SHA-256 of that sequence as 64
lower-case hexadecimal digits. All integers are big-endian.

| Field | Bytes |
|---|---|
| `Int` | `0x01`, then the value as a signed 64-bit integer (8 bytes) |
| `UInt64` | `0x02`, then 8 bytes |
| `Bool` | `0x03`, then `0x00` or `0x01` |
| `String` | `0x04`, then the number of UTF-8 bytes as 8 bytes, then the UTF-8 bytes |
| `[UInt8]` | `0x05`, then the count as 8 bytes, then the bytes |
| `Double` | `0x06`, then the IEEE 754 bit pattern as 8 bytes; negative zero is written as zero; NaN and infinities throw `DigestError.nonFinite(field:)` with the zero-based index of the field |
| sequence count | `0x07`, then the count as 8 bytes |

The domain text given to `init(domain:)` is written first, as a `String` field. The engine uses the experience id
as domain, so equal states of two different experiences have different digests. Because every field carries its
type and every variable-length field its length, two different field sequences never produce the same bytes.

A digest covers the domain state the core writes. It does not cover the step index of the engine, the quality
tier, caches, or anything of the presenter.

## 4. Snapshot envelope

Encoded form (UTF-8 JSON, keys in sorted order, no insignificant white space):

```json
{"checksum":"<64 hex>","digest":"<64 hex>","experience":"a99.contract-sample","format":1,
 "payload":"{\"energy\":3,…}","schema":2,"seed":"18446744073709551615","step":240}
```

| Key | Type | Rule |
|---|---|---|
| `format` | integer | exactly 1; anything else is `unknownFormat` |
| `experience` | text | a valid experience id; restore compares it with the engine's id (`wrongExperience`) |
| `schema` | integer ≥ 1 | the schema version of the experience that wrote the payload |
| `seed` | text | decimal digits of an unsigned 64-bit integer |
| `step` | integer ≥ 0 | the step index at capture |
| `digest` | text | 64 lower-case hexadecimal digits: the digest of the state at capture |
| `payload` | text | the UTF-8 text of one JSON object |
| `checksum` | text | SHA-256 of the payload's UTF-8 bytes, 64 lower-case hexadecimal digits |

Validation order of `init(data:)`: size (more than 1,048,576 bytes → `tooLarge`), JSON shape and field types
(`corrupt` with the reason), format (`unknownFormat`), experience id, seed and digest form (`corrupt`), checksum
(`checksumMismatch`), payload is a JSON object (`corrupt`). `init(experience:…payload:)` checks that the payload
is UTF-8 and a JSON object and that the encoded snapshot fits the size limit, and computes the checksum.

Restore, in the engine: wrong experience → `wrongExperience`; schema above the current version → `newerSchema`;
checksum again → `checksumMismatch`; schema below the current version → parse the payload, run
`Core.migrations.migrate(_:from:)` (`missingMigration`, or `corrupt` when a step throws), print with sorted keys;
`Core.restore(payload:seed:)` throws → `corrupt`; at the current schema version a digest different from the
envelope's → `stateMismatch`. Only after all checks the engine replaces core, seed and step index.

Versions: the envelope format is 1 and has no earlier version. The schema version of an experience starts at 1
and grows by one with each change of its payload; each change registers one step in the experience's
`MigrationChain`. The sample has schema version 2 and one step (1 → 2).

Storage: `DocumentStore<ExperienceSnapshot>(directory:kind:migrations:maxBytes:)` stores a snapshot as the value
of its own file envelope; the kind is the experience's storage namespace. The store's migration chain for that
kind stays at version 1 as long as the envelope format is 1.

## 5. Diagnostics

Fields as in the contract. Encoded for evidence with sorted keys; the seed is written as decimal text; absent
items are omitted (no `null` stand-ins with invented values).

## 6. Conformance checks

For every seed of the plan the helper prepares the core once through an engine (`E0`, ready, then active). A
"script" is: for each action of the plan, run `stepsPerSegment` steps, then handle the action; then run
`stepsPerSegment` steps once more.

| Check | Procedure | Fails when |
|---|---|---|
| seedDeterminism | prepare the same seed a second time | the two digests differ, or a preparation fails |
| snapshotRoundTrip | on a copy of `E0`: after each segment take a snapshot twice, encode, decode and restore into an engine prepared with another seed | the two snapshots differ, the restore is refused, or digest, seed or step index differ |
| resetEquivalence | on a copy of `E0`: run the script, then reset | the digest differs from the digest of `E0` right after preparation, or the step index is not 0 |
| rejectionKeepsDigest | for each action of `rejected`: when `ExperienceInput.validate` lets it through, apply it to a copy of the core itself (not through the engine) | the core accepts it, or the copy's digest differs from the original's |
| tierKeepsDigest | for each tier 0…`qualityTiers − 1`: set it on a copy of the core | a digest differs |
| sheddingKeepsDigest | shed caches on a copy of the core | the digest differs |
| replayReproducesDigest | run the script on two copies of `E0` | the final digests differ |

The comparison base of the reset check is the engine's own first digest, and the replay check starts from copies
of one prepared engine, so each of the seven faults of the sample fails exactly one check.

## 7. The sample experience (tests only)

Id `a99.contract-sample`. A 16 × 16 board with a marker, a target and a moving phase.

| State field | Type | Rule |
|---|---|---|
| `seed` | UInt64 | kept for reset |
| `x`, `y` | Int, 0…15 | marker position; start from the seed |
| `targetX`, `targetY` | Int, 0…15 | from the seed |
| `energy` | Int, 0…1,000,000 | grows by 1 per accepted move; added in schema version 2 |
| `tone` | Double, 0…1 | set by the control `tone` |
| `phase` | Double | advances by `stepDuration × 0.5` per step, wraps at 1 |
| `ticks` | Int | steps seen by the core |
| `tier`, `cache` | Int, [Int] | not part of the digest; the cache is rebuilt on demand |

Controls: `move` with two values in −1…1 (rounded to −1, 0 or 1 per axis; rejected with the rule code
`sample.wall` when the marker would leave the board, and with `sample.no-move` for 0, 0); `tone` with one value
in 0…1; `ping` without values. Quality tiers: 3. Step length: 1/120 s. Schema version 2; version 1 has no
`energy` and the step 1 → 2 adds `"energy": 0`.

Preparation derives every start value from the seed with `SplitMix64` and checks for cancellation between its
256 rounds.

Faults (marker types): unseeded preparation (prepares from the seed mixed with the uptime clock and keeps that
mixed value as its seed, so only the determinism of preparation is broken), lossy snapshot (omits
`tone`), wrong reset (keeps `energy`), mutating rejection (adds to `energy` before it rejects), tier changes state (writes
the tier into `energy`), shedding changes state (clears `tone`), clock in update (mixes the uptime clock into
`phase`), slow preparation (sleeps in small slices for up to 60 s, checking cancellation), failing preparation
(throws `ExperienceFailure(code: "sample.broken", …)`).

The sample presenter (test target of the host module) creates one 1 × 1 texture through the registry in `setup`,
releases it in `teardown`, and clears the framebuffer to the colour (x / 15, y / 15, tone); it counts its calls
so that tests can prove that nothing arrives after deactivation.
