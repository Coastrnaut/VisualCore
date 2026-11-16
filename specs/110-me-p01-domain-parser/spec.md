# Feature Specification: Molecular Explorer — Phase 01 Atom/bond domain and strict XYZ parser

**Feature Branch**: `110-me-p01-domain-parser` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A15-P01 (legacy ledger) · ID namespace FR-A15-1##, SC-A15-1##, T-A15-1##

**Input**: User description: archived manual `apps/15-molecular-explorer.md` §9 Phase 01 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 01):** MVP — a shipping curated small-molecule library with source attributions;
  regression fixture — the XYZ parser rejects negative atom counts, NaNs and oversized files; graphics context
  ownership stays solely in the audited VisualCore host.
- **Gaps built here** (contract `docs/apps/molecular-explorer/visualcore-contract.json`): G-ELEMENTS (the element
  catalog with per-value source records), G-DOMAIN (atoms, bonds, molecules, caps, distance-based bond inference marked
  as estimated) and G-PARSER (the strict, bounded XYZ parser with typed refusals). The full molecule renderer and
  camera stay for A15-P02 (G-RENDER, G-CAMERA); picking, display modes and the panel for A15-P03; the persisted library,
  recent molecules and settings for A15-P04; the file import for A15-P05.
- **Experience:** created in `Packages/ExperiencesCreative/MolecularExplorer`, registered as a candidate with its
  scenario manifest; the slice draws the selected curated molecule's atoms and shows its attributions and counts, and a
  person changes the molecule with native controls — no placeholder.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; reference
  regression and iOS 26 at X-A15; every Spec Kit step runs.

## Clarifications

### Session 2026-11-15

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code and
in the fetched records: `VisualCoreScenes.Mesh.uvSphere`, `VisualCoreRendering.MeshRenderer` and `DepthMeshPass` with
an `OrbitCamera` are the drawing path Solar System Explorer uses; Solar System Explorer's `CitationAudit` is the
source-record pattern (allowed licenses `public-domain` and `CC0-1.0`); the registry has no candidate after X-A14
(`ExperienceRegistry.candidates` is empty); PubChem's periodic table (`/rest/pug/periodictable/JSON`) and the 3D
conformer records of CIDs 962, 297, 702, 241 and 2519 (`/rest/pug/compound/cid/<cid>/record/SDF?record_type=3d`,
fetched 2026-11-15; the raw records are kept for generating the fixtures) are works of the US National Library of
Medicine in the public domain.

- Q: Which elements are supported and where do their values come from? → A: Ten elements — H, C, N, O, F, P, S, Cl,
  Br, I (atomic numbers 1, 6, 7, 8, 9, 15, 16, 17, 35, 53). Name, atomic number, van der Waals radius and display
  colour from the PubChem periodic table (van der Waals radius in pm, stored in Å: 1.20, 1.70, 1.55, 1.52, 1.35,
  1.80, 1.80, 1.75, 1.83, 1.98; colours `FFFFFF`, `909090`, `3050F8`, `FF0D0D`, `90E050`, `FF8000`, `FFFF30`,
  `1FF01F`, `A62929`, `940094`), license `public-domain`. Single-bond covalent radii from B. Cordero et al.,
  "Covalent radii revisited", Dalton Transactions 2008 (Å: 0.31, 0.76, 0.71, 0.66, 0.57, 1.07, 1.05, 1.02, 1.20,
  1.39; carbon's sp³ value), recorded with license `factual-data` (numerical facts, cited for provenance). Allowed
  licenses: `public-domain`, `CC0-1.0`, `factual-data`; anything else is refused.
- Q: Which molecules ship in this phase's library, and from what? → A: Five, in this order: water (CID 962), methane
  (CID 297), ethanol (CID 702), benzene (CID 241), caffeine (CID 2519) — the manual's journey names water, caffeine and
  ethanol. Atoms, coordinates (Å) and recorded bonds with their orders come unchanged from each PubChem 3D conformer
  record (benzene's alternating orders as recorded); source "PubChem Compound CID <n>, 3D conformer", publisher
  "National Library of Medicine (NCBI)", license `public-domain`. The bundled form is XYZ text plus a bond list, so the
  library goes through the same parser as an imported file.
- Q: What are the parser's limits and refusal reasons? → A: At most 65,536 bytes of UTF-8 text; atom count a whole
  number 1…500 on the first line; each line at most 256 bytes; the comment cut to 256 characters; every coordinate
  finite with magnitude at most 1,000 Å; no two atoms closer than 0.4 Å; at most 2,000 bonds. Reasons: `empty`,
  `too-large`, `not-text` (not valid UTF-8), `bad-count` (missing, negative, zero, fractional or non-numeric),
  `too-many-atoms`, `count-mismatch`, `line-too-long`, `malformed-line`, `unknown-element`, `non-finite`,
  `out-of-range`, `overlapping-atoms`; each with the 1-based line where one applies. Limits are inclusive.
- Q: What is the bond-inference rule? → A: Two atoms are bonded when their distance is at most the sum of their
  covalent radii plus 0.4 Å (and not below the 0.4 Å overlap limit); the pairs are checked all against all (at most
  124,750 pairs at 500 atoms, bounded by arithmetic, no spatial grid); every inferred bond is single and marked
  inferred; the result is sorted by atom indices so it is the same in every run.
- Q: How does the slice look and what are its state and actions? → A: The selected molecule's atoms are UV spheres at
  0.35 × their van der Waals radius, coloured with the element's display colour and lit from the camera's side, framed
  by an orbit camera whose distance fits the molecule's bounding sphere; recorded bonds are counted but drawn from
  A15-P02. State schema 1 = the molecule index (0 = water … 4 = caffeine). Actions `molecule.select [0…4]`,
  `molecule.next`, `molecule.previous`; a value that is not a whole index, or a step past an end, is refused with
  `a15.invalid-choice`. Native controls: Previous molecule, Next molecule, a Molecule menu, and lines for the name and
  formula ("Caffeine — C8H10N4O2"), the counts ("24 atoms, 25 bonds") and the source ("PubChem Compound CID 2519,
  3D conformer — public domain"). The manifest has the standard scenarios and five fixtures, one per molecule.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Open a curated molecule with its source (Priority: P1) 🎯

A person opens Molecular Explorer and sees a small molecule from the bundled library drawn as atoms coloured by
element; choosing another molecule shows its atoms, its name and formula, its atom and bond counts and where its
structure came from.

**Why this priority**: the manual's first journey ("open curated water, caffeine and ethanol models") and the phase's
MVP.

**Independent Test**: open the experience; choose each molecule; read the drawn frame and the information lines.

**Acceptance Scenarios**:

1. **Given** the experience, **When** it opens, **Then** the first library molecule is drawn and its name, formula,
   counts and source are shown.
2. **Given** a molecule, **When** the next or previous molecule is chosen, **Then** the drawing and the information
   change, and a step past either end is refused with a reason.
3. **Given** any library molecule, **When** its record is read, **Then** it names its source, units and license.

---

### User Story 2 - Elements are known and sourced (Priority: P1)

The owner can trust the element data: every supported element has a symbol, name, atomic number, covalent radius,
van der Waals radius and display colour, each value with its source, units and license, audited and listed in a
committed document.

**Why this priority**: the constitution's data-provenance rule and gap G-ELEMENTS.

**Independent Test**: run the element audit; compare the committed document with the catalog.

**Acceptance Scenarios**:

1. **Given** the catalog, **When** audited, **Then** 0 problems are found and the committed document matches.
2. **Given** an element without a source, with a duplicate symbol or with a non-finite radius, **When** audited,
   **Then** the problem is named.

---

### User Story 3 - A strict parser refuses bad files (Priority: P1)

The engineer can trust structured input: XYZ text within fixed limits becomes a molecule, and every malformed, oversized
or out-of-range input is refused with a named reason and changes nothing.

**Why this priority**: the phase's regression fixture and gap G-PARSER.

**Independent Test**: parse the valid fixtures and one minimal input per refusal reason.

**Acceptance Scenarios**:

1. **Given** a valid XYZ text, **When** parsed, **Then** the atoms, elements and positions in ångström come out in order.
2. **Given** a negative or non-numeric atom count, a NaN or infinite coordinate, or a file over the size limit, **When**
   parsed, **Then** each is refused with its own reason.
3. **Given** any refused input, **When** the parse ends, **Then** no molecule is produced and the shown molecule is
   unchanged.

---

### User Story 4 - Bonds are inferred and labelled as estimates (Priority: P2)

A molecule without bond records gets bonds inferred from the distances between atoms and their covalent radii; every
inferred bond is marked as inferred, and on the curated molecules the inference finds the same connections as their
recorded bonds.

**Why this priority**: the manual's algorithm decision 2 and its domain rule (never present inferred connectivity as a
guaranteed structure).

**Independent Test**: run the inference on each curated molecule and compare with its recorded bonds.

**Acceptance Scenarios**:

1. **Given** a curated molecule, **When** its bonds are inferred from its coordinates, **Then** the inferred
   connections equal its recorded connections.
2. **Given** an inferred bond, **When** it is read, **Then** it is marked as inferred and has no claimed order beyond
   single.

### Edge Cases

- **Count line disagrees with the atom lines:** refused (`count-mismatch`), never truncated or padded.
- **Unknown element symbol, or a symbol in the wrong case:** symbols are matched case-insensitively and normalised
  (for example `cl` → `Cl`); a symbol not in the catalog is refused (`unknown-element`) with its line number.
- **Windows line endings, trailing spaces, a missing final newline, a leading UTF-8 byte-order mark:** accepted (the
  mark is ignored).
- **Extra columns after x y z (for example charges):** ignored; fewer than three coordinates is `malformed-line`.
- **The comment line:** kept as untrusted plain text, cut to its limit, never interpreted.
- **Two atoms at (almost) the same position:** refused (`overlapping-atoms`) below a stated minimum distance.
- **A single atom or a noble-gas-like isolated atom:** valid; it has no bonds.
- **Exactly at a limit:** the limit is inclusive; one more is refused.

## Requirements *(mandatory)*

### Functional Requirements

**Elements (story 2)**

- **FR-A15-101**: The experience MUST define an element catalog of the supported elements with symbol, name, atomic
  number, covalent radius (Å), van der Waals radius (Å) and display colour, each value with source, units and license;
  an audit MUST refuse missing sources, unsupported licenses, duplicate symbols or numbers and non-finite or
  non-positive radii, and a committed document generated from the catalog MUST match it.

**Domain (stories 1, 4)**

- **FR-A15-110**: The domain MUST model atoms (element, position in Å), bonds (two distinct atom indices, order, and a
  provenance of recorded or inferred) and molecules (id, title, formula, atoms, bonds, source record) with caps on atom
  and bond counts; out-of-range indices, self-bonds, duplicate bonds and non-finite positions are refused.
- **FR-A15-111**: Bond inference MUST connect two atoms when their distance is at most the sum of their covalent radii
  plus a stated tolerance, mark every such bond inferred and single, and produce the same bonds for the same atoms in
  any run.
- **FR-A15-112**: The formula MUST be derived from the atoms in a stated order (carbon first, then hydrogen, then the
  rest alphabetically; alphabetical when there is no carbon).

**Parser (story 3)**

- **FR-A15-120**: The XYZ parser MUST accept the standard layout (atom count, comment, one atom per line with symbol
  and x y z in Å) within fixed limits on bytes, atoms, line length, comment length and coordinate magnitude, and refuse
  every other input with a typed reason naming the line where one applies, producing nothing on refusal.
- **FR-A15-121**: The regression fixtures MUST include a negative atom count, a NaN coordinate and an oversized file,
  each refused with its own reason.

**Library and experience slice (story 1)**

- **FR-A15-130**: A curated library of small molecules MUST ship with each molecule's coordinates and recorded bonds,
  title, formula, source, units and license; every molecule passes the parser's limits and the domain's validation.
- **FR-A15-131**: The experience MUST draw the selected molecule's atoms through the one host's drawing path as lit
  spheres coloured by element at a stated display radius, framed so every atom is in view, with native controls to
  choose the previous, next or any molecule and lines showing the name, formula, atom and bond counts and the source;
  every control has an accessible label and value, and the canvas description names the molecule, its formula, its
  atom and bond counts and its elements by name (so no information depends on colour alone).
- **FR-A15-132**: The experience MUST be registered as a candidate with a scenario manifest (standard scenarios and at
  least one fixture per library molecule) and pass the runner on iOS 27.

### Key Entities

- **Element**: symbol, name, atomic number, covalent radius, van der Waals radius, display colour, source records.
- **Atom**: element, position (Å). **Bond**: atom pair, order, provenance (recorded or inferred).
- **Molecule**: id, title, formula, atoms, bonds, source record (title, publisher, link text, license, units).
- **Parse result**: a molecule, or a refusal (reason, line).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A15-101**: The element audit reports 0 problems and the committed document matches; each damaged-record fixture
  is refused with its reason.
- **SC-A15-102**: 100 % of valid parser fixtures parse exactly; 100 % of refusal fixtures (at least one per reason,
  including a negative count, a NaN and an oversized file) are refused with the expected reason.
- **SC-A15-103**: On 100 % of curated molecules, inferred connections equal recorded connections.
- **SC-A15-104**: Every library molecule draws a non-blank frame on the iOS 27 simulator; changing the molecule changes
  the drawn frame and the information lines.
- **SC-A15-105**: The runner's standard scenarios pass on iOS 27; every test runs in under 10 s.

## Assumptions

- The VisualCore pieces of the A15-P00 contract (UV sphere, lit mesh renderer, orbit camera, storage, manifest and
  runner) exist; the experience pattern of A13–A14 (Core, Experience with Adapter/, candidate registration) applies.
- Element and molecule values come from public-domain or openly licensed references; units are ångström.

## Traceability

| Source | Requirement |
|---|---|
| Phase 01 MVP: curated small-molecule library with source attributions | FR-A15-130, 131 |
| Regression fixture: parser rejects negative counts, NaNs and oversized files | FR-A15-120, 121, SC-A15-102 |
| Algorithm decision 1: XYZ with limits and explicit validation | FR-A15-120 |
| Algorithm decision 2 and domain rule: inferred bonds labelled, conservative thresholds | FR-A15-111, SC-A15-103 |
| Contract gaps G-ELEMENTS, G-DOMAIN, G-PARSER | FR-A15-101–121 |
| EGL/context ownership in the VisualCore host | FR-A15-131 |

## Negative Requirements

- No file import, document picker, picking, display-mode switch or persisted library in this phase; no bonds drawn as
  measured when inferred; no images, textures or data without a license; no network; no chemical safety, toxicity or
  medical claim.
