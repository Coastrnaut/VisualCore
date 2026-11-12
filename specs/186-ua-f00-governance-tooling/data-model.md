# Data Model: UA-F00 — Governance tooling

All entities are tracked files or values derived from them. Nothing is stored outside the repository.

## 1. Numbering map

One rule gives every directory directly under `specs/` its namespace and its id shape. `<id>` below is the part
after `FR-`, `SC-` or `T-`.

| Directory form | Valid range | Namespace | Id shape | Example directory |
|---|---|---|---|---|
| `NNN-*` | 001–010 | `F<k>`, k = NNN − 1 | `F<k>` + two digits | `004-resources-shaders` |
| `NNN-*` | 011–185 | `A<nn>-<p>`, from NNN = 10 + (nn − 1) · 7 + p + 1 | `A<nn>-<p>` + two digits | `035-pu-p03-trails-emitters` |
| `NNN-*` | 186–200 | `U<kk>`, kk = NNN − 186 | `U<kk>-` + three digits | `186-ua-f00-governance-tooling` |
| `NNN-*` | 201–234 | `R02F<ff>`, ff = NNN − 200 | `R02F<ff>-` + three digits | `205-procedural-mesh-compiler-and-mesh-validation` |
| `NNN-*` | 301–550 | `R02G<gg><ff>`, NNN = 301 + (gg − 1) · 10 + (ff − 1) | `R02G<gg><ff>-` + three digits | `301-aurora-loom-playable-rule-kernel` |
| `rNN-fFF-*` | NN 03–12, FF 01–99 | `R<nn>F<ff>` | `R<nn>F<ff>-` + three digits | `r03-f02-gl-es-angle-compatibility-and-rende` |
| `rNN-gGG-FF-*` | NN 03–12, GG 01–25, FF 01–10 | `R<nn>G<gg><ff>` | `R<nn>G<gg><ff>-` + three digits | `r03-g01-01-domain-rules-normalized-action-cont` |

Outside the map (reported): 000, 235–300, 551 and above, a round below 03 or above 12, a game above 25, a game
feature above 10, a game directory without a feature number, and every other directory name.

Validation rules:

- A definition (`**FR-…**`, `**SC-…**`) in `spec.md` and a task id in `tasks.md` match the id shape of their
  directory completely.
- An id is defined once in the whole repository.
- Every feature directory named by a gate of the migration ledger is inside the map, and two gates never share a
  namespace.

## 2. Task line and tick

```text
- [ ] <task-id> <text>                                        open
- [X] <task-id> <text> — Verified YYYY-MM-DD: <evidence>      ticked
```

State transition: open → ticked, once, by the tick tool. The evidence is one line and not empty. `{device}` and
`{owner}` tasks stay open until a device run or the owner's action.

## 3. Scan pattern

| Field | Meaning |
|---|---|
| label | the name printed in a finding; unique |
| pattern | the expression that finds the value |
| allowed look-alikes | values of the same form that are not findings |

Labels after this feature: hardware identifier; device or simulator UUID; ECID; serial number; development team
setting; development team id; e-mail address; absolute home path; private key; GitHub token; GitHub fine-grained
token; Anthropic API key; AWS access key id.

A UUID that is not accepted is one finding of the pattern "device or simulator UUID". On a machine whose own
simulator list contains it, the finding's text is "simulator identifier not recorded" with the recording command;
that is a message of the same pattern, not a pattern of its own.

Allowed look-alikes: a UUID that starts with `00000000-0000-4000-8000-`; a UUID whose hash is in the hash list; the
address `git@github.com`; a home path with a placeholder (`/Users/<name>/`) or `/Users/Shared/`.

## 4. Forbidden path class

| Label | Paths |
|---|---|
| private device data | `.autonomy/private/` |
| logs | `.autonomy/logs/` |
| result bundles | `.autonomy/xcresults/`, any `*.xcresult` |
| reports | `.autonomy/reports/` |
| local signing file | `Configs/Signing.local.xcconfig` |
| provisioning profile | `*.mobileprovision` |
| key store | `*.p12` |
| signing key | `*.p8` |
| certificate | `*.cer` |

## 5. Simulator identifier hash list

File: `Configs/simulator-identifier-hashes.json`.

```json
{
  "schema": 1,
  "note": "SHA-256 of the upper-case identifiers of the development Mac's simulators. Written by scripts/prepush_scan.py --record-simulators. No identifier is stored.",
  "sha256": ["<64 hexadecimal digits>", "…"]
}
```

- `sha256` is sorted and has no duplicates; recording adds, never removes.
- The hash input is the identifier in upper case, encoded as UTF-8.
- A reader that finds a schema other than 1, or a file that is not valid JSON, treats the list as unreadable: the
  scan reports that as a finding, and the recorder stops without writing.
- A missing file is an empty list.

## 6. Migration ledger, attestation, evidence (unchanged formats)

- **Gate**: `id`, `kind`, `title`, `depends`, `status` (pending, pass, fail, blocked, superseded), `attempts`, and
  per kind `spec_dir`, `requires_legacy`, `rows`, `superseded_by`.
- **Attestation** (`.autonomy/migration/checks/<gate>.<name>.json`): `argv`, `command`, `exit_code`, `timed_out`,
  `started`, `finished`, `log`, `log_sha256`. One per name; never overwritten.
- **Evidence revision** (`.autonomy/migration/evidence/<gate>.json`, `<gate>.r2.json`, …): `revision`, `branch`,
  `dirty`, `passing_checks`, `failed_attempts`. A recorded revision is never replaced; its hash is in the ledger.
- State transitions of a gate: pending → pass (from evidence with a passing check); pending → blocked → pending;
  a device row may also become fail. A pass is never reset; `--reverify` adds a revision.

## 7. Prompt coverage report

Value returned by the coverage function and printed by the `coverage` command:

| Field | Meaning |
|---|---|
| features | number of pending launch features that were walked |
| prompts | number of non-empty stage prompts found |
| problems | one line per missing or empty prompt: `<feature> <stage>: <reason>` |

Sources: pending original-app phases from the legacy ledger with prompts from
`docs/process/speckit-prompt-manifest.json`; pending unified-app features from the briefs; pending shared round
features and game features from the migration ledger with prompts from `docs/catalog/feature-index.json` and the
archive. Superseded gates are not walked.

## 8. Override sentence of an archived round feature

```text
Canonical override: feature directory <spec directory>; requirement ids FR-<ns>-###, success criteria SC-<ns>-###, task ids T-<ns>-###.
```

`<spec directory>` is the gate's `spec_dir` in the migration ledger, or the proposed directory of the feature index
when the round is not in the ledger yet. `<ns>` is the namespace of section 1 for that directory.
