# Data model: UA-F09

Sections 1 to 3 are pure Swift in `VisualCoreExperience`. Everything except `ExperienceOutcome` is inside
`#if DEBUG || VISUALCORE_AUTOMATION`. Section 4 is the JSON record; section 5 is the driver's state.

## 1. Outcome (release)

`ExperienceOutcome`: `code: String` (1 to 64 characters of `a-z 0-9 -`). `ExperienceCore.outcome:
ExperienceOutcome?` (default nil, computed). `ExperienceEngine.outcome` and `ExperienceDiagnostics.outcome:
ExperienceOutcome?` (encoded only when present).

## 2. Scenario manifest (schema 1)

```
ScenarioManifest { schema: 1, experience: ExperienceID, kind: creative | game, round: Int? (games: 2, 3 or 4),
                   scenarios: [ScenarioSpec] }
ScenarioSpec     { name: String, seed: UInt64, entries: [ScenarioStep], expect: ScenarioExpectations,
                   cycles: Int? (teardown-reentry, 1…50), seconds: Int? (endurance, 1…600) }
ScenarioStep     { steps: Int (0…100_000), action: ScriptedAction?, result: accepted | <rejection code>?,
                   digest: String? (64 hex) }
ScenarioExpectations { initialDigest: String?, finalDigest: String?, outcome: String?,
                       probes: [String: String]? (probe name → expected value), resetDigest: Bool? }
```

Validation (`ScenarioManifestValidator.problems(manifest, controls:, content:) -> [String]`):
- The nine standard names are present.
- Names are unique, of 1 to 64 characters of `a-z 0-9 -`.
- At most 1,000 scenarios and 10,000 entries per scenario.
- Every action names a declared control, with a value count within the control's ranges.
- An expected outcome, final digest or entry digest needs at least one action before it, except in
  `launch-first-frame` and `reset`.
- A game also has `full-playthrough` and `hero`, `content.acceptance` scenarios whose names begin with
  `acceptance-`, and for round 3 or 4 `content.faults` scenarios whose names begin with `fault-`.
- A creative experience has `content.fixtures` scenarios whose names begin with `fixture-`.

`ContentRequirement { fixtures: Int, acceptance: Int, faults: Int, levels: Int }` is given by the caller (the driver
reads the planning catalog).

## 3. Observation and frame checks

```
ScenarioObservation { scenario, seed, steps: [StepObservation{control, values, result, digest}],
                      digests: {initial, final, afterRestore?, afterReset?}, outcome: String?,
                      frame: FrameObservation?, timing: {preparation, setup, firstPresent, programsCompiled},
                      resources: {footprint, gpuBytes, live, leaked}, actionsSent: Int, actionsHandled: Int,
                      failures: [String] }
FrameObservation { width, height, sha256, nonBlank: Bool, probes: [String: String] (observed) }
```

`ScenarioEvaluator.failures(spec, observation) -> [String]`: compares every expectation; an observation with
`actionsHandled != actionsSent` fails ("bypass"). `FrameChecks`:
- `isNonBlank(rgba)`: more than one distinct colour, and a luminance spread of at least 8 of 255.
- `isBlack(rgba)`: every pixel at most 4 of 255.
- `histogram(rgba, bins: 16)`.
- `hasNonFinite([Float])`.
- `silhouette(rgba, background:, tolerance:) -> (minX, minY, maxX, maxY)?`.

`FrameProbe { name, x, y (0…1), expected: String }`. The runner reads the pixel and classifies it (`dark`,
`light`, `red`, `green`, `blue`, or `other`, by dominant channel and luminance); a probe passes when the class
equals `expected`.

## 4. Evidence record (schema 1, Auto-Creator.md section 22.3)

| Field | Type | Filled by |
|---|---|---|
| `schema` | 1 | app |
| `experience`, `code`, `scenario`, `seed`, `result` (`pass`/`fail`/`error`) | string, string, string, string (decimal), string | app; `code` from the catalog (`A01` …, `sample`, `debug`) |
| `run` | `{id, attempt, lock_sha256: null}` | driver (id passed to the app) |
| `environment` | `{kind: simulator, os_version, os_build, device_type, xcode, swift, sdk, host_os, signing: none}` | driver |
| `source` | `{commit, dirty, tree, submodules: {path: sha}, catalog_sha256, app_sha256}` | driver |
| `configuration` | `{build: Debug/Release, automation: bool, quality_tier, entitlement: none, process: two-launch/single}` | app + driver |
| `steps` | `[{control, values, result, reason?, digest}]` | app |
| `digests` | `{initial, final, after_restore?, after_reset?}` | app |
| `frames` | `[{non_blank, probes: [{name, expected, observed, pass}], path, sha256}]` | app (path and hash completed by the driver) |
| `timing` | `{launch_ms?, preparation_ms, shader_compilation_ms, first_present_ms}` | app |
| `pacing` | `{samples, on_time, median_ms, p95_ms, p99_ms}` or null | app |
| `resources` | `{footprint_bytes, gpu_bytes, live, leaked}` | app |
| `thermal_state`, `low_power`, `battery` | string, bool, number or null | app |
| `artifacts` | `{result_bundle?, log, log_sha256, record_sha256}` | driver |
| `failures` | `[string]` | app + driver |

Validator rules (`scripts/check_evidence.py`):
- Every field is present with its type; `schema` is 1, and any other value is "unknown" or "newer".
- Hashes are 64 lower-case hex characters; `result` is one of three values.
- A `pass` has empty `failures`. Unless the scenario is `cancel-prepare` or `teardown-reentry`, a `pass` has at
  least one step or the scenario's digests. A drawing scenario (`launch-first-frame`, `hero`) has at least one
  frame with `non_blank` true and a hash.
- `environment.kind` is `simulator` or `device`. A record contains no value that looks like a UDID (8-4-4-4-12
  hex), an ECID or a serial.

## 5. Driver state and outputs

- `.autonomy/verify/state.json`: `{runs: {"<id>|<scenario>|<runtime>": {result, record_sha256, finished}}}`. A
  later run skips what passed unless `--fresh` is given.
- `.autonomy/verify/<run id>/`: records, frames, logs (untracked).
- `docs/verification/<id>/summary-<runtime>.json` (tracked): one line per scenario with the result and the record
  hash.
- Request keys (environment): `VISUALCORE_AUTORUN=scenario`, `VISUALCORE_AUTORUN_EXPERIENCE=<id>`,
  `VISUALCORE_AUTORUN_SCENARIO=<name>`, `VISUALCORE_AUTORUN_SEED=<decimal>`, `VISUALCORE_AUTORUN_RUN=<run id>`,
  `VISUALCORE_AUTORUN_PHASE=save|restore`, `VISUALCORE_AUTORUN_EXPECTED_DIGEST=<hex>` (the restore phase).
