# Planning archive

This directory holds the project's original planning documents, moved here unchanged on 2026-11-11 with `git mv` from the repository root (about 110 MB), together with verbatim extracted copies of documents that were embedded in them. `ARCHIVE-MANIFEST.json` records, for every document, its original path, archive path, size and SHA-256. Every file here is a verbatim historical document. Never edit, reformat, re-wrap or "fix" any of them, including typos, outdated commands and broken links: the hashes in the manifest and in `docs/migration/pre-fable-baseline.json` must keep matching.

The text of these documents describes an older plan: 25 separate apps, 275 separate paid games sold at "$2.99" and similar prices, and a full device campaign for each round before the next one starts. [ADR-0009](../../decisions/ADR-0009-unified-app.md) supersedes that plan; its decision D-14 records the reason for this move. The current plan is in the root [`Auto-Creator.md`](../../../Auto-Creator.md). Relative links inside the archived documents point at their old locations (the repository root) and are not maintained.

## How to verify

Run these from the repository root. All three use only the Python standard library.

```
python3 scripts/planning_archive.py verify
python3 scripts/migration_baseline.py verify
python3 scripts/planning_index.py verify
```

- `planning_archive.py verify` compares every archived file with the SHA-256 recorded for its original path in `docs/migration/pre-fable-baseline.json`, and re-checks the derived (extracted) copies and the rounds 3-12 hash manifest.
- `migration_baseline.py verify` proves that the legacy ledger (`.autonomy/state.json` as captured, `.autonomy/evidence/`, `.autonomy/checks/`) and the planning documents still exist with the captured content, at their original path or at the archive path recorded in `ARCHIVE-MANIFEST.json`.
- `planning_index.py verify` re-parses the archive and compares the result with the indexes in `docs/catalog/`.

## Documents

The manifest lists 25 original documents: 17 archived in this directory and 8 retained in place. Sizes are in bytes; the hash column is the first 12 hexadecimal characters of the SHA-256 in the manifest (the full value is in `ARCHIVE-MANIFEST.json`).

### Root documents

| Archive path | Original path | Bytes | SHA-256 (first 12) | Content |
|---|---|---:|---|---|
| [root/README-2026-11-10-full-specification.md](root/README-2026-11-10-full-specification.md) | `README.md` | 1,753,038 | `d07b49f0b9e8` | Former root README: specification chapters 1-19 for 25 apps plus the verbatim archive of 33 source documents |
| [root/CLAUDE-2026-11-11-agent-contract.md](root/CLAUDE-2026-11-11-agent-contract.md) | `CLAUDE.md` | 49,484 | `9185e1b48026` | Former root agent contract (sections 0-13) with the ProjectM-iOS playbook as section 14 |
| [root/setup-2026-11-11.md](root/setup-2026-11-11.md) | `setup.md` | 21,729 | `5c19416d4982` | New-Mac setup guide and session handoff, as at the baseline (copy; the root setup.md continues) |
| [root/START-HERE.md](root/START-HERE.md) | `START-HERE.md` | 5,051 | `eb33a768e6bf` | Index of rounds 3-12 with the game names of each round |
| [root/DESKTOP-ONE-SHOT.md](root/DESKTOP-ONE-SHOT.md) | `DESKTOP-ONE-SHOT.md` | 6,079 | `85028a0f4fdd` | Controller prompt for implementing rounds 3-12 one round at a time |
| [root/manifest.json](root/manifest.json) | `manifest.json` | 4,132 | `eb464a37078d` | Hash manifest and roster metadata for rounds 3-12 (excluded Round 2 names, baseline source hash) |

### Rounds 2-12

Rounds 3-12 each contain 12 shared features and 25 games; Round 2 contains 34 shared features and 25 games. They are planning text, not reports of implemented software.

| Archive path | Original path | Bytes | SHA-256 (first 12) | Content |
|---|---|---:|---|---|
| [rounds/round2.md](rounds/round2.md) | `Round2.md` | 11,989,899 | `f45d83dcc873` | Round 2 specification (names itself round2.md): 34 shared features, 25 games, assertion outlines, 500-candidate study |
| [rounds/round3.md](rounds/round3.md) | `round3.md` | 9,647,090 | `b1168ebe539a` | Round : 12 shared features and 25 games; planning text, not a report of implemented software |
| [rounds/round4.md](rounds/round4.md) | `round4.md` | 9,623,350 | `ad372fdcadf9` | Round : 12 shared features and 25 games; planning text, not a report of implemented software |
| [rounds/round5.md](rounds/round5.md) | `round5.md` | 9,652,437 | `1fd67d383fa3` | Round : 12 shared features and 25 games; planning text, not a report of implemented software |
| [rounds/round6.md](rounds/round6.md) | `round6.md` | 9,660,361 | `521f3b45c776` | Round : 12 shared features and 25 games; planning text, not a report of implemented software |
| [rounds/round7.md](rounds/round7.md) | `round7.md` | 9,626,810 | `d6b921633cd3` | Round : 12 shared features and 25 games; planning text, not a report of implemented software |
| [rounds/round8.md](rounds/round8.md) | `round8.md` | 9,639,293 | `fa9ac8733fd2` | Round : 12 shared features and 25 games; planning text, not a report of implemented software |
| [rounds/round9.md](rounds/round9.md) | `round9.md` | 9,575,532 | `f5bf53f52e2d` | Round : 12 shared features and 25 games; planning text, not a report of implemented software |
| [rounds/round10.md](rounds/round10.md) | `round10.md` | 9,649,785 | `91dc69b3f203` | Round : 12 shared features and 25 games; planning text, not a report of implemented software |
| [rounds/round11.md](rounds/round11.md) | `round11.md` | 9,645,721 | `0800ed35feb9` | Round : 12 shared features and 25 games; planning text, not a report of implemented software |
| [rounds/round12.md](rounds/round12.md) | `round12.md` | 9,514,217 | `fa816aadcf19` | Round : 12 shared features and 25 games; planning text, not a report of implemented software |

### Retained in place

The manifest lists these documents as kept at their original path; they are not copied into this directory, and the links point to them. Their bytes and SHA-256 are recorded in the manifest like the others.

| Archive path | Original path | Bytes | SHA-256 (first 12) | Content |
|---|---|---:|---|---|
| [../../brainstorm/Round-2-Refined-Premium-500x62-Scoring.csv](../../brainstorm/Round-2-Refined-Premium-500x62-Scoring.csv) | `docs/brainstorm/Round-2-Refined-Premium-500x62-Scoring.csv` | 625,464 | `ec6e19c82624` | CSV: 500 candidates scored on 62 criteria |
| [../../brainstorm/Round-2-Refined-Premium-Games-Study-500.md](../../brainstorm/Round-2-Refined-Premium-Games-Study-500.md) | `docs/brainstorm/Round-2-Refined-Premium-Games-Study-500.md` | 143,274 | `b9fc09a7a9e8` | Study of 500 candidate games with code-only graphics (research baseline 2026-11-10) |
| [../../brainstorm/Round-2-Refined-Top25-Selected.csv](../../brainstorm/Round-2-Refined-Top25-Selected.csv) | `docs/brainstorm/Round-2-Refined-Top25-Selected.csv` | 10,986 | `dd8a0f35f208` | CSV: the 25 games selected for Round 2 |
| [../../brainstorm/Round-2-Top25-Complete-AssertionOutlines.md](../../brainstorm/Round-2-Top25-Complete-AssertionOutlines.md) | `docs/brainstorm/Round-2-Top25-Complete-AssertionOutlines.md` | 183,839 | `56eccbb59a99` | Assertion outlines for the 25 Round 2 games |
| [../../brainstorm/round3-to-round12-selection.csv](../../brainstorm/round3-to-round12-selection.csv) | `docs/brainstorm/round3-to-round12-selection.csv` | 91,324 | `cffa03a7add8` | CSV: games assigned to rounds 3-12 in score order |
| [../../brainstorm/supplemental-26-provisional-candidates.csv](../../brainstorm/supplemental-26-provisional-candidates.csv) | `docs/brainstorm/supplemental-26-provisional-candidates.csv` | 33,679 | `b4db022471cd` | CSV: 26 supplemental provisional candidates |
| [../../process/speckit-prompt-manifest.json](../../process/speckit-prompt-manifest.json) | `docs/process/speckit-prompt-manifest.json` | 718,491 | `24873c2376fe` | Generated JSON: Spec Kit prompts for features 001-185 |
| [../../process/speckit-prompt-manifest.md](../../process/speckit-prompt-manifest.md) | `docs/process/speckit-prompt-manifest.md` | 18,490 | `9082c27f0755` | Summary of the Spec Kit prompt manifest (all 185 README features) |

## Extracted copies

`embedded/` holds the 33 documents that were embedded inside the former root README (`root/README-2026-11-10-full-specification.md`); each was verified against the SHA-256 in its `SOURCE-BEGIN` marker. They are in `embedded/sources/` (8 files) and `embedded/apps/` (25 files). `playbook/` holds the verbatim "Playbook: a new iOS app with Claude and Spec Kit, little human interaction (2026-11-10)", the byte range of the archived agent contract from that heading to the end of the file. Together these are the 34 derived entries of the manifest.

### Embedded sources

| Path | Bytes | SHA-256 (first 12) | Content |
|---|---:|---|---|
| [embedded/sources/README.md](embedded/sources/README.md) | 58,016 | `1ee7e5bdcc76` | Original VisualCore README: architecture, repository and Spec Kit implementation plan |
| [embedded/sources/AppsBrainstorm.md](embedded/sources/AppsBrainstorm.md) | 51,518 | `efdcf626fa1b` | Application portfolio brainstorm (25 concepts), last updated 2026-11-09 |
| [embedded/sources/VisualCore-25-App-Specs-Index.md](embedded/sources/VisualCore-25-App-Specs-Index.md) | 5,592 | `08dd90cd17e1` | Index of the 25 per-app manuals (same bytes as VisualCore-25-App-Specs/INDEX.md) |
| [embedded/sources/VisualCore-25-App-Specs/INDEX.md](embedded/sources/VisualCore-25-App-Specs/INDEX.md) | 5,592 | `08dd90cd17e1` | Index of the 25 per-app manuals (same bytes as VisualCore-25-App-Specs-Index.md) |
| [embedded/sources/VisualCore-25-App-Specs-manifest.json](embedded/sources/VisualCore-25-App-Specs-manifest.json) | 6,597 | `92f9c683553a` | JSON list of the 25 manuals: number, title, category, file name, lines, bytes, SHA-256 |
| [embedded/sources/ProjectM-iOS-CLAUDE.md](embedded/sources/ProjectM-iOS-CLAUDE.md) | 25,405 | `8f691031510a` | Agent guide of the ProjectM-iOS repository |
| [embedded/sources/devices.md](embedded/sources/devices.md) | 2,871 | `7ba8f719421a` | Test device inventory recorded 2026-11-08 |
| [embedded/sources/Previous-autopilot-runbook.md](embedded/sources/Previous-autopilot-runbook.md) | 98,820 | `492ec9ac2c9b` | Earlier CLI-oriented autonomous runbook (historical) |

### Embedded per-app manuals (25)

Each manual is an implementation plan for one of the 25 original app concepts.

| No. | App | File | Category | Bytes | SHA-256 (first 12) |
|---:|---|---|---|---:|---|
| 01 | Generative Art Studio | [01-generative-art-studio.md](embedded/apps/01-generative-art-studio.md) | Creative and visual | 55,738 | `557c444d28cf` |
| 02 | Fluid Art Playground | [02-fluid-art-playground.md](embedded/apps/02-fluid-art-playground.md) | Creative and visual | 54,695 | `99984107b80f` |
| 03 | Fractal Explorer | [03-fractal-explorer.md](embedded/apps/03-fractal-explorer.md) | Creative and visual | 54,149 | `8d96a21550b0` |
| 04 | Particle Universe | [04-particle-universe.md](embedded/apps/04-particle-universe.md) | Creative and visual | 53,849 | `118c17a296c1` |
| 05 | Infinite Geometry | [05-infinite-geometry.md](embedded/apps/05-infinite-geometry.md) | Creative and visual | 53,262 | `329159552c0a` |
| 06 | VisualCore Music Lab | [06-visualcore-music-lab.md](embedded/apps/06-visualcore-music-lab.md) | Music and audio | 54,507 | `428a8da52129` |
| 07 | Audio Odyssey | [07-audio-odyssey.md](embedded/apps/07-audio-odyssey.md) | Music and audio | 53,820 | `2bec53c4b2e2` |
| 08 | Oscilloscope Studio | [08-oscilloscope-studio.md](embedded/apps/08-oscilloscope-studio.md) | Music and audio | 53,641 | `4630f888041f` |
| 09 | Digital Aquarium | [09-digital-aquarium.md](embedded/apps/09-digital-aquarium.md) | Music and audio | 53,943 | `1621d0893b92` |
| 10 | Neon Arcade | [10-neon-arcade.md](embedded/apps/10-neon-arcade.md) | Games and interactive experiences | 53,518 | `5dc63ea3ccee` |
| 11 | Physics Playground | [11-physics-playground.md](embedded/apps/11-physics-playground.md) | Games and interactive experiences | 53,689 | `8457f8ead485` |
| 12 | Tiny Worlds | [12-tiny-worlds.md](embedded/apps/12-tiny-worlds.md) | Games and interactive experiences | 52,898 | `f6ca998dfd91` |
| 13 | Light Maze | [13-light-maze.md](embedded/apps/13-light-maze.md) | Games and interactive experiences | 53,224 | `5c62ef567f5f` |
| 14 | Solar System Explorer | [14-solar-system-explorer.md](embedded/apps/14-solar-system-explorer.md) | Education and science | 54,143 | `03a27d229017` |
| 15 | Molecular Explorer | [15-molecular-explorer.md](embedded/apps/15-molecular-explorer.md) | Education and science | 53,661 | `34563982f72f` |
| 16 | Simulation Lab | [16-simulation-lab.md](embedded/apps/16-simulation-lab.md) | Education and science | 54,097 | `20c7b0bf1325` |
| 17 | Interactive Anatomy | [17-interactive-anatomy.md](embedded/apps/17-interactive-anatomy.md) | Education and science | 53,794 | `933ec4e1c784` |
| 18 | Ambient Clock | [18-ambient-clock.md](embedded/apps/18-ambient-clock.md) | Ambient and lifestyle | 53,833 | `a719c2b74ccc` |
| 19 | Living Wallpapers | [19-living-wallpapers.md](embedded/apps/19-living-wallpapers.md) | Ambient and lifestyle | 54,065 | `c28927351b3f` |
| 20 | Digital Zen Garden | [20-digital-zen-garden.md](embedded/apps/20-digital-zen-garden.md) | Ambient and lifestyle | 53,494 | `b5bfc3915dc3` |
| 21 | Aurora | [21-aurora.md](embedded/apps/21-aurora.md) | Ambient and lifestyle | 52,674 | `1daca5bd25e2` |
| 22 | Shader Studio | [22-shader-studio.md](embedded/apps/22-shader-studio.md) | Developer and creator tools | 54,003 | `989b136f8e15` |
| 23 | Visual Programming Lab | [23-visual-programming-lab.md](embedded/apps/23-visual-programming-lab.md) | Developer and creator tools | 54,149 | `a7a4285d56c7` |
| 24 | Graphics Benchmark Lab | [24-graphics-benchmark-lab.md](embedded/apps/24-graphics-benchmark-lab.md) | Developer and creator tools | 54,575 | `02488510c4d1` |
| 25 | Effects Composer | [25-effects-composer.md](embedded/apps/25-effects-composer.md) | Developer and creator tools | 54,190 | `8ce0dd99f2db` |

### Playbook

| Path | Bytes | SHA-256 (first 12) | Content |
|---|---:|---|---|
| [playbook/Playbook-new-iOS-app-with-Claude-and-Spec-Kit-2026-11-10.md](playbook/Playbook-new-iOS-app-with-Claude-and-Spec-Kit-2026-11-10.md) | 12,778 | `a00764a5f29a` | Playbook section, from its heading to the end of the archived agent contract |

## How to find things

Print an archived Spec Kit prompt verbatim, after the tool checks it against the hash recorded in the index. `--override` appends the canonical override note of [`Auto-Creator.md`](../../../Auto-Creator.md) section 21 for that feature class:

```
python3 scripts/planning_index.py prompt --feature <ID> --stage <stage> --override
```

Print the planned level manifest of one game of rounds 3-12 (JSON):

```
python3 scripts/planning_index.py levels --experience <CODE>
```

[docs/catalog/experience-catalog.json](../../catalog/experience-catalog.json) and [docs/catalog/feature-index.json](../../catalog/feature-index.json) give the file and line span of every experience and feature in the archive (line numbers are 1-based). [`docs/migration/source-to-canonical-matrix.csv`](../../migration/source-to-canonical-matrix.csv) maps archived headings and features to the current documents.
