# Tasks: Molecular Explorer — Phase 01 Atom/bond domain and strict XYZ parser

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/domain.md](contracts/domain.md), [quickstart.md](quickstart.md). Gate A15-P01 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A15-P01 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. iOS 27 only. Precedent:
`specs/103-sse-p01-catalog/tasks.md`.

## Phase 1: Setup

- [X] T-A15-101 Baseline: cite the last evidence on an unchanged `Packages` tree (`.autonomy/checks/A15-P00.{app-build,no-change}.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-15: cited .autonomy/checks/A15-P00.app-build.json and A15-P00.no-change.json (exit 0) on the Packages tree unchanged since A15-P00 (no rerun)

## Phase 2: Foundational — the core (stories 2–4)

- [X] T-A15-102 [US2] Create `Packages/ExperiencesCreative/MolecularExplorer/Core/{Elements,SourceRecord,ElementAudit}.swift` per contracts/domain.md and data-model.md (ten elements H, C, N, O, F, P, S, Cl, Br, I with the exact values of spec Clarifications Q1; "symbols and numbers unique; radii finite, 0.1…3.0 Å"; one `SourceRecord` per stored value; licenses ∈ {`public-domain`, `CC0-1.0`, `factual-data`}; case-insensitive `element(symbol:)`; `ElementAudit.problems` and `markdown`) with `CoreTests/{ElementsTests,ElementAuditTests}.swift` (ten elements in atomic-number order with the clarified values; audit 0 problems; missing source, unsupported license, duplicate symbol and non-finite radius each refused with its reason) (FR-A15-101; SC-A15-101) — Verified 2026-11-15: Core/Elements, SourceRecord, ElementAudit (ten elements with the clarified PubChem and Cordero values, 50 source records, allowed licenses public-domain, CC0-1.0, factual-data; the Cordero DOI 10.1039/b801115j verified through Crossref) with ElementsTests and ElementAuditTests; core targets added to Package.swift; written by an agent, retested in .autonomy/checks/A15-P01.me-core.json exit 0 (46 core tests)
- [X] T-A15-103 [US3] Create `Core/{Molecule,XYZParser}.swift` (atoms "finite; magnitude ≤ 1,000 Å", bonds "indices in range; no self or duplicate bonds", order 1…3, origin recorded/inferred; molecule caps "atoms (1…500), bonds (0…2,000)", "no two atoms closer than 0.4 Å"; Hill-order formula; the parser's limits and twelve reasons of Clarifications Q3 with 1-based lines; line endings, trailing spaces, missing final newline and a leading byte-order mark accepted; extra columns ignored; comment cut to 256 characters) with `CoreTests/{MoleculeTests,XYZParserTests,ParserRegressionTests}.swift` (valid fixtures exact; one minimal input per reason; a lower-case symbol (`cl`) normalised to `Cl`; the manual's regression fixtures — a negative count, a NaN coordinate and a 65,537-byte file — each refused with its own reason; limits inclusive) (FR-A15-110, 112, 120, 121; SC-A15-102) — Verified 2026-11-15: Core/Molecule (caps, refusals, Hill formula) and XYZParser (limits and the twelve reasons; BOM, CRLF, trailing spaces and missing final newline accepted; the comment line cut to 256 characters and the 256-byte limit on the count and atom lines, spec wording aligned) with MoleculeTests, XYZParserTests and ParserRegressionTests (negative count bad-count, nan non-finite, 65,537 bytes too-large); retested in .autonomy/checks/A15-P01.me-core.json exit 0
- [ ] T-A15-104 [US4] Create `Core/BondInference.swift` (covalent radii sum plus 0.4 Å; all pairs; single, inferred, sorted) with `CoreTests/BondInferenceTests.swift` (deterministic; isolated atom has none; water two O–H bonds) (FR-A15-111)
- [ ] T-A15-105 [US1] Generate `Core/MoleculeLibrary.swift` from the five PubChem 3D conformer records kept from the clarification session (CIDs 962, 297, 702, 241, 2519; XYZ text plus recorded bonds with orders; source "PubChem Compound CID <n>, 3D conformer", publisher "National Library of Medicine (NCBI)", license `public-domain`, units Å) and `Core/MoleculeState.swift` (schema 1, selection 0…4, damaged or newer refused) with `CoreTests/{MoleculeLibraryTests,MoleculeStateTests}.swift` (five molecules in order with atom/bond counts 3/2, 5/4, 9/8, 12/12, 24/25 and formulas H2O, CH4, C2H6O, C6H6, C8H10N4O2; every molecule parses and validates; every molecule's source record has title, publisher, units Å and a license in the allowed set, audited by `ElementAudit.problems(molecules:)`; inferred connections equal recorded connections on all five; state codec) (FR-A15-111, 130; SC-A15-103)

## Phase 3: Story 1 — the experience

- [ ] T-A15-106 [US1] Create the targets in `Packages/ExperiencesCreative/Package.swift` (`MolecularExplorerCore`, `MolecularExplorerCoreTests`, `MolecularExplorerExperience`, `MolecularExplorerExperienceTests`, product `MolecularExplorerExperience`) and `Packages/ExperiencesCreative/MolecularExplorer/Experience/{Adapter/MoleculeCore.swift,MoleculePresenter.swift,MoleculeControls.swift,MolecularExplorerExperience.swift}` (actions `molecule.select [0…4]`, `molecule.next`, `molecule.previous`, refusal `a15.invalid-choice`; atoms as lit UV spheres at 0.35 × the van der Waals radius in element colours through `DepthMeshPass` and an `OrbitCamera` fitted to the bounding sphere; renderers created together, rebuilt after context recreation, released together; canvas description with molecule, formula, counts and element names; controls Previous molecule, Next molecule, Molecule menu and the name/formula, counts and source lines, identifiers `experience.a15.molecular-explorer.<name>`) and tests `ExperienceTests/{MoleculeCoreTests,MoleculeSessionTests,MoleculeRenderTests,MoleculeTestSupport}.swift` (actions and refusals; every molecule draws a non-blank frame; changing the molecule changes the drawn pixels, the lines and the description) (FR-A15-131; SC-A15-104)
- [ ] T-A15-107 [US1] Register: `Catalog/registrations.json` entry for a15 (summary, capabilities ≤ 40 characters each, quality_tiers ["level-0"], palette, manifest) and the fixture copy `Packages/VisualCore/Tests/VisualCoreExperienceTests/Fixtures/Catalog/registrations.json`, candidate in `Apps/VisualCore/App/ExperienceRegistry.swift`, `project.yml` dependency, `scripts/test_scripts.py` products list, `RealCatalogTests` registrations and the `AppModelTests` synthetic candidate id moved from a15 to a16 (FR-A15-132)
- [ ] T-A15-108 [US1] Write `Experience/Adapter/MoleculeManifest.swift` (nine standard scenarios + five fixtures, one per molecule, by actions) and generate `Packages/ExperiencesCreative/MolecularExplorer/scenario-manifest.json` (`UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`) with `ExperienceTests/MoleculeManifestTests.swift` (FR-A15-132)

## Phase 4: Story 2 — sources recorded

- [ ] T-A15-109 [US2] Generate `docs/apps/molecular-explorer/data-sources.md` from `ElementAudit.markdown()` (elements and the five molecules' sources) with a test in `CoreTests/ElementAuditTests.swift` comparing the committed file (through `#filePath`, regenerated with `UPDATE_DATA_SOURCES=1` or `TEST_RUNNER_UPDATE_DATA_SOURCES=1`); link it from `docs/apps/molecular-explorer/README.md` (FR-A15-101, 130; SC-A15-101)
- [ ] T-A15-110 [US2] Contract `docs/apps/molecular-explorer/visualcore-contract.json`: G-ELEMENTS, G-DOMAIN and G-PARSER closed by "A15-P01" (the line-reader assessment recorded in G-PARSER); their rows updated (`--name contract -- python3 scripts/check_app_contract.py --app molecular-explorer --render`)

## Phase 5: Records and evidence

- [ ] T-A15-111 Molecular Explorer tests on sim-27.2 (`--name me-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing MolecularExplorerCoreTests MolecularExplorerExperienceTests`) and the documented-API check (`--name documented-api -- python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/MolecularExplorer`) (SC-A15-101–105)
- [ ] T-A15-112 App build and unit (`xcodegen generate --spec project.yml`; `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`) and runner (`--name verify-27 -- python3 scripts/verify_experiences.py --only a15.molecular-explorer --runtime 27`) (SC-A15-105)
- [ ] T-A15-113 Packages and script tests (`--name experience-packages -- python3 scripts/check_experience_packages.py`; `--name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A15-114 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A15-P01; update README.md in the record commit (rule 16) and `docs/automatedtesting.md` if a test tool, rule or lesson changed (rule 17)

## Dependencies

T-A15-101 → 102 → 103 → 104 → 105 → 106 → (107 ∥ 109) → 108 → 110 → 111 → 112 → 113 → 114.

## Parallel examples

Agent A: T-A15-102–104 (core, after the lead's Package.swift targets). Agent B: T-A15-106 experience sources and tests
after A. Lead: Package.swift, the library generator (105), registrations, registry, project.yml, xcodegen, manifest and
document regeneration, contract, runs, commits.

## Implementation strategy

MVP: the core with the parser regression fixtures (102–105), then the drawn molecule (106–108), then sources recorded
(109–110). Review checkpoints after 105 (core tests), after 108 and at 111.
