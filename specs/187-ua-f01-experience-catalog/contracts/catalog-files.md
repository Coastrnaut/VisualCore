# Contract: files under `Catalog/` and the build tool (UA-F01)

## Files

| File | Written by | Schema | Requirement |
|---|---|---|---|
| `Catalog/experiences.json` | `scripts/build_catalog.py` only | data-model.md sections 2 and 3 | FR-U01-040, FR-U01-041 |
| `Catalog/categories.json` | by hand, validated by the tool | data-model.md section 4 | FR-U01-022 |
| `Catalog/registrations.json` | by the feature that integrates an experience | data-model.md section 5 | FR-U01-040, FR-U01-042 |
| `Catalog/path-map.json` | by the feature that moves sources | data-model.md section 6 | FR-U01-046 |
| `Catalog/experience-ids.golden.txt` | `build_catalog.py --add-golden` only; it only grows | data-model.md section 7 | FR-U01-004 |
| `Packages/VisualCore/Tests/VisualCoreExperienceTests/Fixtures/Catalog/*` | copies of the five files, written by the tool | identical bytes | FR-U01-043 |

JSON files are written with two-space indentation, keys in the order of the data model, LF line endings and a
final line break, so the same inputs give the same bytes (FR-U01-044).

## `python3 scripts/build_catalog.py [--check] [--add-golden]`

| Situation | Behavior | Requirement |
|---|---|---|
| No option | writes `Catalog/experiences.json` and the test copies; prints `built Catalog/experiences.json: <n> experiences, <free> free, <premium> premium, <available> available`; exit 0 | FR-U01-040 |
| An entry's gate `X-<code>` is pass in `.autonomy/migration/ledger.json` | `available` is true; for any other status false | FR-U01-041 |
| An available experience has no registration; a registration names an id the planning catalog does not define; the registrations file has another schema | `ERROR: …` naming the id or the file; nothing written; exit 1 | FR-U01-042 |
| `--check` | compares the manifest, the golden list against the planning catalog and every test copy with what it would write; `PASS: runtime catalog, 0 problems` and exit 0, or one `PROBLEM:` line per difference (the first differing line of a file) and exit 1; writes nothing | FR-U01-043 |
| `--add-golden` | appends the ids of planning-catalog experiences that the golden list lacks, in catalog order; refuses when a listed id is missing from the planning catalog | FR-U01-004 |
| An input cannot be read, is not valid JSON or lacks an expected key; the launch allocation of the planning catalog is not 50 free and 50 premium with the stated codes | `ERROR: …` naming the file and the reason; nothing written; exit 1 | FR-U01-044, FR-U01-011 |
| Any run | reads the migration ledger, never writes it; writes each file through a temporary file and a rename | FR-U01-044, FR-U01-045 |

Derivations: `title` = `name`; `summary` = `design.summary` or `design.pitch`; `kind` = `creative` for
`creative-app`, `game` for `game`; `tier`, `family`, `order` as in the planning catalog; `category` =
`launcher_category`; `tags` = the family in tag form; `tile_seed` = the first four bytes of SHA-256 of the id as an
unsigned whole number; `palette`, `capabilities`, `quality_tiers`, `content` from the registration or empty and
`null`; `catalog_sha256` = SHA-256 of the planning catalog file. Only experiences with `release` equal to `launch`
enter the manifest, plus those of a backlog round once its gates exist in the ledger.
