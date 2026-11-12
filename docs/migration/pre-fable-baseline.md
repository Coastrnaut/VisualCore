# Pre-migration baseline (before the unified-app consolidation)

**Captured:** 2026-11-12T02:18:20Z (2026-11-11 21:18 local), on the project Mac Studio, from the local checkout.
**Machine-readable form:** [pre-fable-baseline.json](pre-fable-baseline.json) (Git identity, submodule pins, every
tracked file with size, SHA-256 and Git blob, ledger summary) and [pre-fable-baseline.sha256](pre-fable-baseline.sha256)
(`shasum -a 256 -c` format for all 2,324 tracked regular files).
**Re-check at any time:** `python3 scripts/migration_baseline.py verify`.

Everything the consolidation changes is explained relative to this state. The baseline was taken from the local
working tree, not from GitHub; the two were identical at capture time.

## 1. Git identity

| Item | Value |
|---|---|
| Branch at capture | `main` |
| Commit | `38d98ebb376088e18f053f3cc39d246a7e7dd3b3` — "Seal A04-P03: Particle Universe trails and multiple emitters (feature 035)", 2026-11-11T20:42:02-05:00 |
| Tree | `85466f56bb6484ec136f14b130b2b24d40733ef9` |
| Remote | `origin` = `https://github.com/Coastrnaut/VisualCore.git` |
| Local versus `origin/main` | 0 behind, 0 ahead (fetched at capture) |
| Working tree | clean: no modified, staged or untracked files; no stashes; only branch `main` |
| Migration branch | `migration/unified-app-plan`, created from the commit above; `main` is not changed by this work |

**File-name case note.** Git tracks the Round 2 document as `Round2.md`. The directory entry on this
case-insensitive volume is `round2.md`; it is the same file (11,989,899 bytes), and its own header names the
intended path `/round2.md`. A case-sensitive clone sees `Round2.md`. The archive normalizes the name to `round2.md`.

## 2. Outside-repository backup

`../VisualCore-pre-fable-backup-2026-11-11/` (sibling of the checkout, read-only):

- `VisualCore-all-refs-38d98eb.bundle` — `git bundle` of every ref with complete history
  (SHA-256 `6419d8dc34ea5b2a762c861c21e39f3285855ca760c649722f339bc35ee2eec9`; `git bundle verify` reports okay).
  Restore with `git clone VisualCore-all-refs-38d98eb.bundle VisualCore-restored`.
- Byte copies of the root planning documents, `.autonomy/state.json`, `.autonomy/evidence/`, `.autonomy/checks/`,
  `docs/brainstorm`, `docs/process`, `docs/decisions`, `docs/verification`, `.specify/` and `specs/`.
- `SHA256SUMS` over the 1,687 copied files; `shasum -a 256 -c SHA256SUMS` passed at creation.

The backup holds no signing material. It is not pushed anywhere.

## 3. Submodule and vendor pins

The repository has one direct submodule; everything else is nested inside it and is read-only for VisualCore.

| Path | Commit | State |
|---|---|---|
| `External/projectm-ios` | `d93edd178525444f86ed8b9f1e70aee7412871b2` | checked out (pinned by ADR-0005) |
| `External/projectm-ios/Vendor/angle` | `29d18232e8031430f1257b7509ceca20d195114d` | checked out |
| `External/projectm-ios/Vendor/projectM` | `c88894e966b3a862be148466b5d5c6e68d8bb9f1` | checked out |
| `External/projectm-ios/Vendor/projectM/vendor/projectm-eval` | `22fb0cfd8f2dfbcd2b68f2443e7f44e19b32c09a` | checked out |
| `External/projectm-ios/Vendor/presets/*` (5 packs) | see JSON | checked out |
| 77 further nested ANGLE dependencies | see JSON | not initialized as Git submodules (fetched by `gclient`) |

Built reference artifacts exist locally and are not tracked: `External/projectm-ios/Build/ANGLEFrameworks` and
`External/projectm-ios/Build/ProjectM.xcframework`.

## 4. Toolchain verified on this Mac (2026-11-11)

`python3 scripts/verify_environment.py` printed PASS at the start of the session: Xcode 27.2 (27B52), iOS SDK 27.2,
Swift 6.4.2, XcodeGen 2.46.0, CMake 4.4.5, Python 3.15.2, simulator runtimes iOS 27.2 and iOS 26.5. These match
`Configs/toolchain.json`.

## 5. What exists in source

| Area | Present at baseline |
|---|---|
| Framework packages | `Packages/VisualCore` (pure Swift, host-testable: Math, Simulation, Scenes, Parameters, Persistence, ShaderSource, EffectsGraph, Diagnostics, AudioDSP, TestSupport, Baselines) and `Packages/VisualCoreRendering` (CVisualCoreEGL, CVisualCoreGL, VisualCoreRendering, VisualCoreEffects, VisualCoreUI, VisualCoreAudio, VisualCoreAutomation) |
| App targets (`project.yml`) | `Showcase`, `GenerativeArtStudio`, `FluidArtPlayground`, `FractalExplorer`, `ParticleUniverse`, each with its test targets; bundle ids `dev.visualcore.<Name>` (owner-approved placeholders) |
| App domain packages | `GenerativeArtStudioCore`, `FluidArtPlaygroundCore`, `FractalExplorerCore`, `ParticleUniverseCore` |
| Harnesses | `InteractiveDemo`, `SecondConsumer` (Lumen Garden), `ProjectMReference` (own XcodeGen specs) |
| Spec Kit | `.specify/` (constitution, templates, Python scripts), nine installed skills under `.claude/skills/speckit-*` including `speckit-converge` |
| Feature dossiers | `specs/001` … `specs/035`: 35 features, 353 functional requirements, 201 success criteria, 477 ticked tasks, 6 open tasks (one `{device}`/`{owner}` task each in features 005–010) |
| Decisions | `docs/decisions/ADR-0001` … `ADR-0008` |
| CI | `.github/workflows/ci.yml` (host-only gates and a simulator build of the pure package) |
| Tracked files | 2,324 regular files, 120,343,601 bytes, plus one submodule link |

**Implemented experiences at baseline (from source and the ledger, not from planning text):**

| Original app | Ledger gates passed | State |
|---|---|---|
| A01 Generative Art Studio | A01-P00 … A01-P06 | all seven phases sealed (simulator and host evidence) |
| A02 Fluid Art Playground | A02-P00 … A02-P06 | all seven phases sealed |
| A03 Fractal Explorer | A03-P00 … A03-P06 | all seven phases sealed |
| A04 Particle Universe | A04-P00 … A04-P03 | four of seven phases sealed; next gate A04-P04 |
| A05 … A25 | none | planned only |
| Round 2 … Round 12 games (275) | none | planned only; no game source exists |

No physical-device test has been run in this repository: all 75 legacy device gates are `pending`. The device
observations quoted in the archived ProjectM-iOS playbook are history of another repository.

## 6. Ledgers, evidence and where they live

| Record | Path | Tracked | Baseline content |
|---|---|---|---|
| Legacy gate ledger | `.autonomy/state.json` | yes | schema 1, 263 gates: 35 `pass`, 228 `pending`; next `A04-P04`; SHA-256 `2604ffd8…b7ca` |
| Sealed gate evidence | `.autonomy/evidence/<gate>.json` | yes | 35 files (F00–F09, A01-P00 … A04-P03) |
| Command attestations | `.autonomy/checks/<gate>.<name>.json` | yes | 1,258 files (argv, exit status, log path and SHA-256, revision) |
| Aggregate ledger digest | — | — | `dca1437507cb9adc06b954fdea78bd54436d8854a67db38b549f4c073af014e2` over state, evidence and checks (definition in the JSON) |
| Command logs | `.autonomy/logs/` | no (ignored) | 143 entries, 33 MB, this Mac only |
| Xcode result bundles | `.autonomy/xcresults/` | no (ignored) | 61 bundles, 813 MB, this Mac only |
| Extracted source context | `.autonomy/context/` | no (ignored) | regenerated by `desktop_runbook.py bootstrap` from the embedded archive |
| Spec Kit task records | `specs/NNN-*/tasks.md` | yes | every ticked task carries "— Verified YYYY-MM-DD:" evidence text |
| Release records | `docs/release/`, `docs/apps/<app>/release.json` and checklists | yes | framework 1.0.0-rc.1 notes; three app release dossiers (simulator-only evidence, device rows pending) |
| Regression baselines | `docs/apps/*/regression-baseline.md`, `docs/verification/projectm-baseline.md`, `docs/performance/` | yes | ProjectM reference regression 7/7 after each VisualCore change |
| Device inventory observed | `docs/verification/devices-observed.json` | yes | roles D1, D2, D3 as observed during F00 |

Logs and result bundles are deliberately machine-local. The tracked attestations record each log's SHA-256, so a
log can be matched to its attestation but cannot be regenerated on another Mac.

## 7. Planning and steering documents at baseline

Sizes and full SHA-256 values are in the JSON (`planning_documents`). Summary:

| Document | Bytes | Role at baseline |
|---|---:|---|
| `README.md` | 1,753,038 | canonical specification chapters §1–§19 (141 KB) plus a verbatim archive of 33 source documents (§20); read by `Tools/python/desktop_runbook.py` and `scripts/source_hash_report.py` |
| `CLAUDE.md` | 49,484 | agent contract §0–§13 plus the verbatim ProjectM-iOS playbook (§14) |
| `setup.md` | 21,729 | new-Mac setup guide and a dated resume checkpoint |
| `Round2.md` (`round2.md`) | 11,989,899 | Stage Two: 34 shared features, 25 games, 2,273 Spec Kit prompts, embedded assertion outlines and the 500-candidate study |
| `round3.md` … `round12.md` | 9.5–9.7 MB each | ten rounds of 25 games, 12 shared features each, 2,097 prompts each; hashes match `manifest.json` |
| `START-HERE.md`, `DESKTOP-ONE-SHOT.md`, `manifest.json` | 5,051 / 6,079 / 4,132 | index, controller prompt and hash manifest for rounds 3–12 |
| `docs/brainstorm/*` (6 files) | 1.09 MB | 500×62 scoring table, top-25 selection, assertion outlines, rounds 3–12 selection, 26 supplemental candidates |
| `docs/process/speckit-prompt-manifest.{json,md}` | 737 KB | per-feature Spec Kit prompts for features 001–185, generated from the embedded archive |

## 8. Known conflicts between the planning corpus and the new direction

These are resolved in ADR-0009 and `Auto-Creator.md`; they are listed here so the starting point is explicit.

1. The corpus plans 25 separate apps (README) and 275 separate paid games (`round2.md` … `round12.md`, "$2.99",
   "no in-app purchases"). The new direction is one app with one non-consumable unlock.
2. Each round requires the previous round's full device campaign before it starts. The new direction requires all
   100 launch experiences to be implemented and simulator-verified before any device campaign of the unified app.
3. The round documents assume one XcodeGen target and bundle id per game. The new direction has one app target.
4. The legacy ledger has 75 per-app device gates. The unified app needs 100 experiences on each of three devices.

## 9. What this baseline does not prove

- It does not prove device behavior, performance, App Store readiness or name availability.
- Planning text in the round documents is not evidence of implemented software.
- Logs and result bundles outside Git exist only on this Mac; the outside backup does not include them.
