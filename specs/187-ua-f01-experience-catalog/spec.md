# Feature Specification: UA-F01 — Experience catalog and stable identity

**Feature Branch**: `187-ua-f01-experience-catalog` (spec directory only; work stays on `main`)

**Created**: 2026-11-12

**Status**: Draft

**Ledger gate**: UA-F01 (migration ledger) · ID namespace FR-U01-###, SC-U01-###, T-U01-###

**Input**: User description: the UA-F01 `/speckit-specify` prompt of Auto-Creator.md section 20
(`docs/catalog/unified-app-features.json`), verbatim in the invocation.

Canonical overrides:
- **Feature directory and ids:** `specs/187-ua-f01-experience-catalog`; requirement ids FR-U01-###, success criteria
  SC-U01-###, task ids T-U01-###.
- **Names from the brief:** the pure module VisualCoreExperience in `Packages/VisualCore` with ExperienceID,
  ExperienceDescriptor, ExperienceTier, ExperienceCategory and CatalogManifest; the runtime manifest
  `Catalog/experiences.json`, `Catalog/categories.json` and `Catalog/path-map.json`; the tool
  `scripts/build_catalog.py`. They are proposals until `/speckit-plan` confirms them against the code. Other
  modules are not named.
- **Who the users are:** later features and their authors. The app shell reads the manifest to draw the launcher,
  the session host reads identity and tier, the purchase feature reads the tier, the verification runner and the
  ledgers derive names from the id. A person using the app sees the result only later, as the launcher.
- **Out of scope:** the launcher interface (UA-F04) and everything about purchases (UA-F08).
- **Device-only and owner-only items:** none.
- **What exists today:** the planning catalog `docs/catalog/experience-catalog.json` with 300 experiences, of which
  100 are the launch set. No experience is integrated in the unified app yet, so no experience is available.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every experience has one identity that never changes (Priority: P1) 🎯

An author of a later feature asks the catalog for an experience and gets its code and its runtime id, for example
`A05` and `a05.infinite-geometry`. The id is exactly the one of the planning catalog. Storage, accessibility
identifiers, evidence files and ledger gates are named from it, so it must never change: a committed golden list of
ids fails the tests the moment an id is altered, removed or reused.

**Why this priority**: saved work, purchases of the future and every piece of evidence are attached to the id. An
id that changes silently detaches all of them.

**Independent Test**: load the runtime manifest and compare its ids with the golden list and with the planning
catalog; then change one id in a copy and see the tests fail naming it.

**Acceptance Scenarios**:

1. **Given** the runtime manifest, **When** it is loaded, **Then** every entry's id is the lower-case code, a dot
   and the slug, exactly as the planning catalog records it.
2. **Given** an identity text, **When** it is parsed, **Then** a well-formed id yields its code and slug, and a
   malformed one (upper case in the id, a missing dot, an unknown code form, an empty or badly formed slug) is
   rejected with a reason.
3. **Given** the golden list of ids, **When** an id of the planning catalog or of the runtime manifest differs from
   it, is missing from it, or a listed id has disappeared, **Then** a test fails and names the id.
4. **Given** a new experience added to the planning catalog by a later round, **When** its id is added to the
   golden list, **Then** the tests pass again; no listed id may be edited or removed to make them pass.

---

### User Story 2 - The launch set is exactly 50 free and 50 premium (Priority: P1)

The manifest holds the 100 launch experiences: the 25 original creative experiences and the 25 Round 2 games are
free, the 50 games of Rounds 3 and 4 are premium. Any other allocation is refused when the manifest is validated,
so a wrong tier can never reach the purchase gate.

**Why this priority**: the tier decides what is free forever. A premium tier on a free experience, or the reverse,
would break the product's central promise.

**Independent Test**: validate the real manifest; then validate copies with one tier flipped, one launch experience
removed, one added twice, and see each refused with a typed reason.

**Acceptance Scenarios**:

1. **Given** the runtime manifest, **When** it is validated, **Then** it holds exactly 100 launch experiences: 50
   free with the codes A01–A25 and R02-G01–R02-G25, and 50 premium with the codes R03-G01–R04-G25.
2. **Given** a manifest in which a free launch code is premium, a premium launch code is free, a launch code is
   missing or a code outside the launch set is present, **When** it is validated, **Then** validation fails and
   names the code and the rule.
3. **Given** the planning catalog, **When** the manifest is built, **Then** the tier of each launch experience is
   the tier of the planning catalog and the catalog order is kept.

---

### User Story 3 - A damaged or foreign manifest is refused safely (Priority: P1)

The app reads the manifest at launch. A file that is too large, of an unknown schema version, with a duplicate id,
a missing field or a number that is not a finite whole number in range is refused with a typed error before any of
it is used. The loader never crashes and never returns a partly valid catalog.

**Why this priority**: the manifest is the first data the app trusts. Bounded, typed loading is a constitution
rule (Principle IX).

**Independent Test**: feed the loader one damaged fixture per error kind and see exactly the expected error; feed
it the real manifest and see it load.

**Acceptance Scenarios**:

1. **Given** data larger than the size cap, **When** it is loaded, **Then** the loader refuses it without parsing.
2. **Given** a manifest of a schema version the loader does not know, **When** it is loaded, **Then** the error
   names the found and the supported version.
3. **Given** a manifest with two entries of the same id or the same code, **When** it is loaded, **Then** the error
   names the duplicate.
4. **Given** an entry with a missing or wrongly typed field, an unknown tier, kind or category, an empty title, a
   text over its length limit or a list over its count limit, **When** it is loaded, **Then** the error names the
   entry and the field.
5. **Given** a number that is not finite, not whole or outside its range, **When** it is loaded, **Then** the error
   names the entry and the field.
6. **Given** bytes that are not a manifest at all, **When** they are loaded, **Then** the loader returns the typed
   error for unreadable data.

---

### User Story 4 - Only integrated experiences are available (Priority: P1)

The manifest marks an experience as available only when its integration gate `X-<code>` is pass in the migration
ledger. The build tool reads the ledger; nobody types the flag. Today no gate is pass, so the manifest lists 100
experiences and none is available.

**Why this priority**: an experience shown as available without a passed gate would be a claim without evidence.

**Independent Test**: build the manifest from the real ledger and see 0 available; build it from a temporary ledger
in which one gate is pass and see exactly that one available; ask the tool to check the committed manifest and see
it fail when the committed file differs from what the ledger gives.

**Acceptance Scenarios**:

1. **Given** the migration ledger of today, **When** the manifest is built, **Then** all 100 entries are present
   and none is available.
2. **Given** a ledger in which `X-A01` is pass, **When** the manifest is built, **Then** `a01.generative-art-studio`
   is available and the other 99 are not.
3. **Given** a gate that is pending, blocked or failed, **When** the manifest is built, **Then** its experience is
   not available.
4. **Given** a committed manifest that differs from what the planning catalog and the ledger produce, **When** the
   build tool runs in check mode, **Then** it fails and names the first difference; it writes nothing.
5. **Given** an available entry whose experience has not registered what an available experience must declare,
   **When** the manifest is built, **Then** the tool fails and names the experience.

---

### User Story 5 - Categories, tags and search behave the same everywhere (Priority: P2)

Every experience belongs to exactly one of seven launcher categories and carries its family as a tag. A search over
title, summary and tags returns the same experiences in the same order for the same text on every device, in every
language setting.

**Why this priority**: the launcher and its tests depend on a stable grouping and a stable order; a
locale-dependent search would make tests differ between machines.

**Independent Test**: group the real manifest by category and count; run a table of searches twice under two
different language settings and compare results and order.

**Acceptance Scenarios**:

1. **Given** the manifest, **When** it is grouped, **Then** every entry has exactly one of the categories create,
   audio, play, learn, ambient, tools and puzzle; the launch set has 5, 4, 4, 4, 4, 4 and 75 entries in that order.
2. **Given** an entry, **When** its tags are read, **Then** its family is among them.
3. **Given** the category list, **When** it is loaded, **Then** it holds the seven categories in launcher order,
   each with a title; a manifest entry of a category that the list does not hold is refused.
4. **Given** a search text, **When** the catalog is searched, **Then** letter case, accents and surrounding or
   repeated spaces do not matter, every word of the text must match, and the results are ordered by a stated rule
   that ends in catalog order.
5. **Given** the same search under two language settings (for example English and Turkish), **When** it runs,
   **Then** results and order are identical.
6. **Given** an empty search text, **When** the catalog is searched, **Then** all entries are returned in catalog
   order.

---

### User Story 6 - The registry and the manifest agree one to one (Priority: P2)

Later features register a factory for each experience they build. A pure check compares the ids of the registered
factories with the available entries of the manifest and reports every id that is on one side only. The app's tests
reuse the same check.

**Why this priority**: an available entry without a factory would open nothing; a factory without an entry would
be unreachable and unverified.

**Independent Test**: call the check with matching sets, with a factory too many, with an entry too many and with a
duplicate registration, and compare the report.

**Acceptance Scenarios**:

1. **Given** registered ids equal to the available ids, **When** the check runs, **Then** it reports a match.
2. **Given** an available entry without a registered factory, or a registered factory whose entry is missing or
   not available, **When** the check runs, **Then** the report lists each such id under its kind.
3. **Given** the same id registered twice, **When** the check runs, **Then** the report lists the duplicate.
4. **Given** today's manifest with no available entry and no registered factory, **When** the check runs, **Then**
   it reports a match.

---

### Edge Cases

- **Failure**: the build tool cannot read the planning catalog or the ledger, or the planning catalog changed its
  shape. It stops with a message that names the file and writes nothing.
- **Cancellation and interruption**: the build tool is interrupted. Each output file is either the old one or the
  complete new one, never a part.
- **Lifecycle interruption**: the app is suspended while the manifest loads. Loading is one bounded, synchronous
  step over data that is already in memory; it holds no file handle and has nothing to resume.
- **Memory pressure**: the loader refuses data over the cap before parsing, bounds every text and list, and keeps
  one catalog value; it needs no cache that could grow.
- **Corrupted data**: any damage gives a typed error (User Story 3); the app can show a failure and stay usable.
- **Newer-version data**: a manifest of a higher schema version is refused with the versions in the error; the
  loader never guesses at unknown fields of a known version: they are ignored only when the schema says so.
- **Unicode in text**: titles such as "Moire Observatory" or a future title with accents, a dotless or dotted
  capital I, or full-width letters are searched by the same folding on every device.
- **Backlog rounds**: an experience of Rounds 5 to 12 enters the manifest only when its round is added to the
  ledger; it is premium and its id joins the golden list.
- **An id that would collide**: two experiences can never share a code, an id or a slug within a code; the build
  tool and the loader both refuse it.

## Requirements *(mandatory)*

### Functional Requirements

**Identity**

- **FR-U01-001**: Every experience MUST have an immutable code of the form `A<nn>` or `R<rr>-G<gg>` and an immutable
  runtime id `<code in lower case>.<slug>`, where the slug consists of lower-case letters and digits in groups
  joined by single hyphens.
- **FR-U01-002**: The catalog module MUST parse an id text into code and slug, MUST give back exactly the same text
  for a valid id, and MUST reject a malformed id with a typed reason.
- **FR-U01-003**: The id and code of every entry of the runtime manifest MUST equal those of the planning catalog
  `docs/catalog/experience-catalog.json`.
- **FR-U01-004**: A committed golden list MUST hold the id of every experience of the planning catalog. A test
  MUST fail, naming the id, when an id of the planning catalog or of the runtime manifest is not in the list or
  when a listed id is missing from the planning catalog. The list only grows.
- **FR-U01-005**: Names derived from an experience (storage namespace, accessibility identifier prefix, evidence
  file name, integration gate) MUST be functions of the id or the code alone, offered by the catalog module, so
  that no feature builds them by hand.

**Tier and launch allocation**

- **FR-U01-010**: Every entry MUST have exactly one tier, free or premium. The tier of a launch experience MUST be
  the tier of the planning catalog.
- **FR-U01-011**: Validation of the manifest MUST fail unless the launch experiences are exactly the 50 free codes
  A01–A25 and R02-G01–R02-G25 and the 50 premium codes R03-G01–R04-G25, each once.
- **FR-U01-012**: An entry outside the launch set MUST belong to Rounds 5 to 12 and MUST be premium; any other
  entry MUST fail validation.
- **FR-U01-013**: Entries MUST keep the catalog order (1 to 300) of the planning catalog, without a repeated order
  number.

**Categories, tags and search**

- **FR-U01-020**: Every entry MUST have exactly one launcher category out of create, audio, play, learn, ambient,
  tools and puzzle; a creative experience MUST NOT be in puzzle and a game MUST be in puzzle.
- **FR-U01-021**: Every entry MUST carry its family, and its tags MUST contain the family in tag form.
- **FR-U01-022**: The category list MUST hold the seven categories in launcher order with a title each; it MUST be
  loaded with the same bounds and typed errors as the manifest, and a manifest entry whose category is not in the
  list MUST fail validation.
- **FR-U01-023**: Search MUST cover title, summary and tags; MUST ignore letter case, accents and extra spaces;
  MUST require every word of the search text to match; and MUST order results by a stated rule (a match in the
  title before a match only in tags, before a match only in the summary; ties in catalog order).
- **FR-U01-024**: Search MUST give identical results and order regardless of the device's language and region
  settings, and for an empty text MUST return every entry in catalog order.

**Bounded loading**

- **FR-U01-030**: The loader MUST refuse data over a stated size cap before parsing it.
- **FR-U01-031**: The loader MUST refuse a schema version other than the supported one and report both versions.
- **FR-U01-032**: The loader MUST refuse duplicate ids, duplicate codes and duplicate order numbers and name the
  duplicate.
- **FR-U01-033**: The loader MUST refuse an entry with a missing field, a field of the wrong type, an unknown
  tier, kind or category, an empty title, a text longer than its limit or a list longer than its limit, naming
  the entry and the field.
- **FR-U01-034**: The loader MUST refuse a number that is not finite, not whole where a whole number is required,
  or outside its stated range, naming the entry and the field.
- **FR-U01-035**: Every refusal MUST be one typed error value that a caller can compare; the loader MUST NOT crash
  and MUST NOT return a partly loaded catalog.
- **FR-U01-036**: Loading MUST be deterministic and MUST NOT read the clock, the language settings, the network or
  any file other than the data it was given.

**Availability and the build tool**

- **FR-U01-040**: The build tool MUST derive the runtime manifest from the planning catalog, the migration ledger
  and the registrations of experiences, and MUST record in the manifest the hash of the planning catalog it was
  built from.
- **FR-U01-041**: An entry MUST be marked available only when its integration gate `X-<code>` is pass in the
  migration ledger; for every other gate status it MUST be marked not available.
- **FR-U01-042**: The build tool MUST refuse to mark an experience available whose registration is missing, and
  MUST name it.
- **FR-U01-043**: The build tool MUST have a check mode that compares the committed manifest files with what it
  would write, fails naming the first difference, and writes nothing.
- **FR-U01-044**: The build tool MUST write each file completely or not at all, MUST produce the same bytes for
  the same inputs, and MUST stop with a message naming the file when an input cannot be read or has an unexpected
  shape.
- **FR-U01-045**: The build tool MUST only read the migration ledger; it MUST NOT write it.
- **FR-U01-046**: The runtime path map MUST exist with a schema version and an empty list of moves, and MUST be
  loadable with the same bounds; later features append a record for every source move they make.

**Registry check**

- **FR-U01-050**: A pure check MUST compare a list of registered experience ids with the manifest and report
  available entries without a registration, registrations without an available entry, and ids registered more
  than once.
- **FR-U01-051**: The check MUST need nothing but the manifest and the list of ids, so that the package tests and
  the app's tests can both call it.

**Framework obligations and boundaries**

- **FR-U01-060**: Every public symbol of the new module MUST have documentation, the API baseline MUST be updated,
  and the module MUST have package tests on the host and on the iOS 27.x and iOS 26.5 simulators.
- **FR-U01-061**: The ProjectM reference regression MUST be rerun after the framework change and MUST pass.
- **FR-U01-062**: The new module MUST be pure: no user-interface, graphics, store or network dependency, and no
  dependency on an experience.
- **FR-U01-063**: This feature MUST NOT add an app target, a launcher interface or purchase code, and MUST NOT
  change the reference submodule or the vendored tree.

### Key Entities

- **Experience identity**: code and runtime id; immutable; the source of every derived name.
- **Experience descriptor**: one entry of the manifest: identity, title, summary, kind (creative or game), tier,
  category, family, tags, catalog order, what the launcher draws its tile from, declared capabilities and quality
  tiers, content facts for a game, and whether it is available.
- **Tier**: free or premium; what the purchase gate will read.
- **Category**: one of seven launcher groups, with an order and a title.
- **Catalog manifest**: the validated set of descriptors with its schema version and the hash of the planning
  catalog it came from.
- **Registration**: what a built experience declares about itself (capabilities, quality tiers, tile data, content
  facts). None exists yet.
- **Golden id list**: the committed list of every id ever defined; it only grows.
- **Path map**: the record of source moves of the migration; empty until the first move.
- **Registry report**: the result of comparing registered ids with available entries.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-U01-001**: 100% of the 300 ids of the planning catalog are in the golden list and have the stated form;
  changing any one id in a copy makes at least one test fail and name it.
- **SC-U01-002**: The built manifest holds 100 entries: 50 free and 50 premium, with exactly the stated codes;
  each of at least 4 wrong allocations is refused with a typed reason.
- **SC-U01-003**: The category counts of the launch set are 5, 4, 4, 4, 4, 4 and 75; 100% of entries carry their
  family as a tag.
- **SC-U01-004**: A table of at least 12 searches gives identical results and order under two different language
  settings, and repeated runs give identical output.
- **SC-U01-005**: Each of at least 10 kinds of damaged manifest gives its own typed error; 0 crashes and 0 partly
  loaded catalogs across all fixtures.
- **SC-U01-006**: Built from today's ledger the manifest has 0 available entries; built from a ledger with 1
  passed integration gate it has exactly 1; the check mode fails on a manifest that was edited by hand.
- **SC-U01-007**: The registry check reports correctly in at least 5 cases: match, missing registration, extra
  registration, duplicate registration, and the empty catalog of today.
- **SC-U01-008**: Building the manifest twice from the same inputs gives byte-identical files.
- **SC-U01-009**: 100% of the public symbols of the new module are documented; the API baseline check passes; the
  package tests pass on the host and on both simulator runtimes; the reference regression passes 7 of 7 steps.
- **SC-U01-010**: Loading and validating the 100-entry manifest takes under 50 milliseconds on the development Mac
  in the host tests (a host figure, not a device claim).

## Assumptions

- The planning catalog is the single source of ids, names, tiers, categories, families and order. This feature
  does not change it.
- No experience has shipped. "Shipped id" in the brief is read as: every id that the planning catalog defines is
  frozen from now on, for the launch set and the backlog alike, because storage and evidence names are derived
  from ids long before the release.
- The manifest of today contains the 100 launch experiences. Backlog experiences enter when their round is added.
- A title is the name of the planning catalog; a summary is the catalog's one-sentence summary of a creative
  experience or the pitch of a game.
- No experience is registered yet, because the experience contract arrives with UA-F02 and the first adoptions
  with UA-F07. This feature defines what a registration contributes and proves the rules with fixtures.
- The manifest is small (well under a megabyte). Level catalogs of games are separate files that later features
  define; the manifest will carry only their counts and hashes.
- The manifest files live in the repository and are bundled with the app by a later feature (UA-F04); the loader
  takes data, not a location.
- Timings are host measurements on the development Mac, not device or app performance.
- Accessibility requirements do not apply here: the feature has no user interface. It supplies the stable
  accessibility identifier prefix that later interfaces use.
- No advertising, analytics, tracking or network code is involved.

## Traceability

| Source | Requirement |
|---|---|
| Acceptance 1 (ids exactly `<code>.<slug>`; golden list) | FR-U01-001–005, US1, SC-U01-001 |
| Acceptance 2 (50 free, 50 premium; any other allocation fails) | FR-U01-010–013, US2, SC-U01-002 |
| Acceptance 3 (one category, family as tag, deterministic locale-independent search) | FR-U01-020–024, US5, SC-U01-003, SC-U01-004 |
| Acceptance 4 (typed errors for schema, duplicates, missing fields, non-finite numbers, size cap) | FR-U01-030–036, US3, SC-U01-005 |
| Acceptance 5 (available only when `X-<code>` is pass) | FR-U01-040–045, US4, SC-U01-006, SC-U01-008 |
| Acceptance 6 (pure registry check, reused by app tests) | FR-U01-050, FR-U01-051, US6, SC-U01-007 |
| Acceptance 7 (documented API, baseline, package tests, reference regression) | FR-U01-060, FR-U01-061, SC-U01-009 |
| Scope: `Catalog/categories.json`, `Catalog/path-map.json` | FR-U01-022, FR-U01-046 |
| Out of scope: launcher interface, purchases | FR-U01-063 |
| Auto-Creator.md section 5.2 (identity), 5.4 (categories), 5.5 (availability) | FR-U01-001–005, FR-U01-020–024, FR-U01-041 |
| Auto-Creator.md section 11.2 (module, manifest schema, loader, registry check) | FR-U01-030–036, FR-U01-040, FR-U01-050 |
| ADR-0009 D-01, D-02, D-06 | FR-U01-011, FR-U01-001, FR-U01-062 |
| Constitution IX (bounded untrusted input), XI (stable identity), II (reuse obligations) | FR-U01-030–035, FR-U01-004, FR-U01-060, FR-U01-061 |
