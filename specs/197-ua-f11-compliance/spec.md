# Feature Specification: UA-F11 — Privacy, licensing, no-advertising audit and distinctiveness

**Feature Branch**: `197-ua-f11-compliance` (spec directory only; work stays on `main`)

**Created**: 2026-11-13

**Status**: Draft

**Ledger gate**: UA-F11 (migration ledger) · ID namespace FR-U11-###, SC-U11-###, T-U11-###

**Input**: User description: the UA-F11 `/speckit-specify` prompt of Auto-Creator.md section 20
(`docs/catalog/unified-app-features.json`), verbatim in the invocation, with the owner's rulings of 2026-11-13.

Canonical overrides:
- **Feature directory and ids:** `specs/197-ua-f11-compliance`; FR-U11-###, SC-U11-###, T-U11-###.
- **Names from the brief:** `PrivacyInfo.xcprivacy`, `scripts/check_privacy_manifest.py`, `scripts/check_licenses.py`,
  `scripts/bundle_licenses.py`, `docs/legal` (with `docs/legal/third-party.json`), Info.plist, ADR-0009 D-16 and
  D-17, the migration ledger and the catalog. Other modules are not named here.
- **Who the users are:** the owner, who must be able to submit the app knowing that what the store is told
  (privacy answers, licenses, metadata) is true of the built product; the player, who gets an app without
  advertising, tracking or unexplained permission prompts and can read every license; and the engineer adding the
  next experience, whose change fails fast when it adds a permission, a tracking library, ProjectM code or a
  mechanic that another experience already has.
- **Owner rulings of 2026-11-13 that bind this feature:** tests are short; system accessibility audits wait for the
  device campaign; independent files are fanned out to parallel agents.
- **Out of scope:** submitting anything to App Store Connect; the store metadata text itself and the privacy
  policy (UA-F14 drafts them from the inputs of this feature). **Device-only items:** none. **Owner-only items:**
  the legal review of licenses and App Store answers; trademark and name clearance (with the age rating); the
  human distinctiveness review (D-17, non-gating).
- **What exists today (read-only audit of 2026-11-13, `Build/agent-notes/UA-F11-audit.md`, names re-verified):**
  - `Apps/VisualCore/Resources/PrivacyInfo.xcprivacy` declares the required-reason categories UserDefaults (CA92.1),
    FileTimestamp (C617.1) and DiskSpace (35F9.1), no tracking, no tracking domains and no collected data.
    `check_privacy_manifest.py --app` already compares a manifest with the reason APIs found in a built app and its
    embedded frameworks; it has not been run as evidence on the current Release app.
  - `project.yml` gives the app one usage description, `NSPhotoLibraryAddUsageDescription` (A01's Save Image).
    `scripts/check_app_release.py` checks usage descriptions only against per-legacy-app `release.json` files; the
    one app has no such list. The capabilities that experiences declare in the catalog and in the app's
    registrations are free text; none names a system permission.
  - No check scans the built app for advertising, analytics or tracking libraries, the advertising identifier or
    the tracking-authorization framework. `scripts/check_compliance.py` scans sources only and has no such rule.
    `scripts/check_release_symbols.py --forbid` can already search every binary of an app for given texts.
  - `check_licenses.py` maps every package and binary dependency to `docs/legal/third-party.json`;
    `bundle_licenses.py` copies the shipped licenses into the app at build time; the app's About screen shows them.
    Nothing asserts that the built app's license set equals the shipped inventory.
  - `scripts/audit_showcase_dependencies.py --target VisualCore` runs in every app build and rejects ProjectM in
    project specs, packages, imports and binaries; it has no recorded run on the current Release app.
  - Nothing builds or checks a distinctiveness matrix. The catalog has 100 launch experiences under three design
    schemas: A01–A25 (creative apps: summary and primary capability, no win rule), R02 (core abstraction, controls,
    core action, victory) and R03/R04 (core abstraction, player action, win predicate). In R03/R04 the core
    abstraction and the win predicate are family templates shared by clusters of up to 13 games; the player actions
    are all different. The six close pairs named by the Round 2 source are R02-G01/G10, G02/G03, G09/G14, G08/G24,
    G17/G18 and G13/G12.
  - No metadata-input generator exists. Integration gates X-A01 to X-A03 are pass; the others are pending.

## Absorbed source requirements

Archived prompts read with `python3 scripts/planning_index.py prompt --feature <ID> --stage specify` (R02-F33 at
round2.md:1894, R03-F12 at round3.md:997, R04-F12 at round4.md:998). Every unique requirement:

| Source | Requirement | Disposition | Reason |
|---|---|---|---|
| R02-F33 | Originality matrices across the games | Adopted | FR-U11-060..066 (one matrix over all 100 launch experiences instead of one per round) |
| R02-F33 | Independent UX and goal per game | Adapted | Expressed as "no two share a mechanic" on core abstraction, player action and win rule (FR-U11-061) |
| R02-F33 | Static app icons from vector code | Superseded | One app, one icon, owned by the shell and store work (UA-F14); per-game icons do not exist in the one app (ADR-0009) |
| R02-F33 | Legal audit | Adapted | Automated scans gate (FR-U11-010..050); the legal review itself is an owner item (FR-U11-090) |
| R02-F33 | Release packaging, USD 1.99–4.99 one-time purchase per game, no IAP | Superseded | ADR-0009: one free app with one USD 1.99 non-consumable (UA-F05); packaging is UA-F14 |
| R02-F33 | User journeys, deterministic tests, observability, accessibility, excluded scope | Adopted | User stories, short deterministic checks with self-tests, machine-readable reports (FR-U11-080) |
| R02-F33 | Schema migration | Adapted | Applies to the new report and configuration files: each has a schema version and a newer version is refused (FR-U11-081) |
| R03-F12 / R04-F12 | Audit all products for similarities | Adopted | FR-U11-060..066 |
| R03-F12 / R04-F12 | Audit licenses | Adopted | FR-U11-030..033 |
| R03-F12 / R04-F12 | Audit privacy | Adopted | FR-U11-001..004, 010..013 |
| R03-F12 / R04-F12 | No advertising, ad SDK, advertising identifiers, IAP, subscriptions, service login | Adopted (ads, identifiers, trackers, sign-in SDKs); IAP part Superseded | FR-U11-020..025; the one non-consumable is governed by UA-F05 |
| R03-F12 / R04-F12 | Audit evidentiary gaps; converge only when valid results exist | Adopted | FR-U11-082: the gate records only reports produced from the current build |
| R03-F12 / R04-F12 | Screenshots captured from the GL renderer, not mockups | Superseded here | Owned by each experience's verification (UA-F09 runner); this feature makes no images |
| R03-F12 / R04-F12 | 5 stories, 12 requirements, 8 success conditions, 3 counterexamples | Adapted | Story and requirement counts follow the seven acceptance items; counterexamples are the planted-defect self-tests (FR-U11-083) |
| R03-F12 / R04-F12 | Conditions for rejecting a duplicate | Adapted | A duplicate is never rejected or merged: it is redesigned inside its concept (D-16, FR-U11-064) |
| R03-F12 / R04-F12 | No external image generation or hand-made graphics | Superseded here | Constitution principle on code-only visuals; checked by each experience's verification and asset provenance (Auto-Creator.md §15.4), not by this feature |

## Clarifications

### Session 2026-11-13

- Q: Where does an experience declare the system permissions it needs? → A: In the app's registration data: a
  `permissions` list of vocabulary words on each experience's registration, next to its free-text capabilities; the
  vocabulary (word → usage-description key) is its own versioned file. No public Swift API changes; A01 declares
  `photo-library-add`.
- Q: Which catalog fields form the (core abstraction, player action, win rule) triple for each schema? → A: R03/R04:
  core abstraction, player action, win predicate. R02: core abstraction, core action, victory. A01–A25: launcher
  category as core abstraction, primary capability as player action, and the fixed win rule "open-ended".
- Q: What similarity measure and threshold decide "shares a mechanic"? → A: Jaccard similarity of normalized
  player-action word sets (lower case, words of three or more letters, stop words removed, a trailing plural "s"
  dropped), compared across all pairs; threshold 0.5. On 2026-11-13 the highest launch pair is 0.375 (A23/A25).
- Q: Which built-app checks run in CI, where the app links stand-in ANGLE frameworks? → A: The tracking scan, the
  license assertion and the ProjectM audit run on both the CI Release build and the local Release build; the
  privacy-manifest audit runs only on the local Release build with the real ANGLE frameworks, since the stand-ins
  would hide ANGLE's reason APIs. Gate evidence comes from the local run.
- Q: How does a report prove it scanned the current build? → A: Gate evidence comes only from release-check runs,
  which build the app in the same run; each report records the source revision, whether the working tree was
  clean, the configuration and the SHA-256 of the scanned main executable. A standalone run records the digest but
  is never gate evidence.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The privacy manifest is true of the built app (Priority: P1)

The owner needs the app's privacy manifest to declare exactly the required-reason APIs that the built app and its
embedded frameworks use, with no tracking and no collected data, so the store's privacy questions can be answered
truthfully.

**Why this priority**: an inaccurate manifest is a submission rejection and a false statement to players.

**Independent Test**: build the Release app and run the manifest audit on it; then run the audit's self-test, which
plants an undeclared reason API and a tracking flag and expects failures.

**Acceptance Scenarios**:

1. **Given** the current Release app, **When** the manifest audit runs, **Then** every reason-API category found in
   any binary of the app is declared with an approved reason, no declared category is unused, tracking is false, and
   the audit passes.
2. **Given** a build that uses a reason API the manifest does not declare, **When** the audit runs, **Then** it
   fails and names the category and the binary.
3. **Given** a manifest that declares tracking, tracking domains or collected data, **When** the audit runs, **Then**
   it fails.

---

### User Story 2 - Permission prompts only for what experiences use (Priority: P1)

The player sees a system permission prompt only when an experience they opened needs it, and the app's property
list carries usage descriptions only for permissions that registered experiences declare.

**Why this priority**: an unused usage description is a store rejection risk and misleads the privacy label.

**Independent Test**: run the usage-description check on the generated property list and the app's registrations;
then on fixtures with an extra key and with a missing key.

**Acceptance Scenarios**:

1. **Given** the registered experiences and the built app's property list, **When** the check runs, **Then** the set
   of usage-description keys equals the union of the permissions declared by registered experiences (today: photo
   library add, from A01).
2. **Given** a usage description that no registered experience declares, **When** the check runs, **Then** it fails
   and names the key.
3. **Given** a registered experience that declares a permission without its usage description, **When** the check
   runs, **Then** it fails and names the experience and the key.
4. **Given** a permission word the controlled vocabulary does not know, **When** the check runs, **Then** it fails.

---

### User Story 3 - No advertising, analytics or tracking anywhere in the app (Priority: P1)

The owner needs proof that the built app contains no advertising, analytics or tracking library, does not use the
advertising identifier or the tracking-authorization framework, and makes no network request of its own.

**Why this priority**: "no advertising of any kind, ever" is a rule that never bends.

**Independent Test**: run the binary scan on the Release app; run its self-test, which plants each forbidden kind
of finding in a fixture app and expects a failure for each.

**Acceptance Scenarios**:

1. **Given** the current Release app, **When** the scan runs over every binary, linked library and bundled file,
   **Then** it reports zero findings and passes.
2. **Given** a fixture app that links the advertising-support or tracking-transparency framework, references the
   advertising identifier, or contains a known advertising, analytics or attribution library name, **When** the scan
   runs, **Then** it fails and names each finding with the binary that holds it.
3. **Given** source code that imports an advertising or tracking framework, **When** the source compliance check
   runs, **Then** it fails before any build.

---

### User Story 4 - Every license is bundled, complete and shown (Priority: P2)

The player can read every third-party license in the app, and the owner knows the bundled set equals the legal
inventory.

**Why this priority**: required by the licenses (ANGLE and its components) and needed for the owner's legal review.

**Independent Test**: run the license inventory check and the built-app license assertion on the Release app; open
the acknowledgements screen in an interface test.

**Acceptance Scenarios**:

1. **Given** the repository, **When** the license inventory check runs, **Then** every package and binary dependency
   of the app maps to an inventory entry with an allowed license and an existing text.
2. **Given** the Release app, **When** the built-app license assertion runs, **Then** the bundled license set equals
   the inventory entries marked as shipped, each text is non-empty and matches the repository text byte for byte.
3. **Given** a shipped inventory entry whose text is missing from the built app, or a bundled text with no
   inventory entry, **When** the assertion runs, **Then** it fails and names it.
4. **Given** the app, **When** a player opens About and then the acknowledgements, **Then** every shipped license is
   listed by name and its text can be read.

---

### User Story 5 - ProjectM is not in the app (Priority: P2)

The owner needs proof that no ProjectM engine or preset code, symbol, library or file is in the shipped app.

**Why this priority**: ProjectM is LGPL reference material of the harness only; shipping it changes the license
obligations.

**Independent Test**: run the dependency audit with the binary layer on the Release app; run its existing planted-
defect tests.

**Acceptance Scenarios**:

1. **Given** the Release app, **When** the dependency audit runs, **Then** no ProjectM symbol, linked library,
   bundle path or preset file is found and only the two ANGLE libraries are embedded.
2. **Given** a fixture app with a ProjectM symbol or preset file, **When** the audit runs, **Then** it fails.

---

### User Story 6 - No two launch experiences share a mechanic (Priority: P2)

The owner needs a matrix over all pairs of the 100 launch experiences showing that each has its own mechanic, with
the six close pairs from the Round 2 source examined first, so the store listing and players see 100 different
experiences.

**Why this priority**: distinctiveness is a store-review and product-identity risk, but a near-duplicate is fixed by
redesign, not removal.

**Independent Test**: generate the matrix from the catalog; run the check; run its self-test with a planted
duplicate pair.

**Acceptance Scenarios**:

1. **Given** the catalog's 100 launch experiences, **When** the matrix is generated, **Then** it has one row per
   unordered pair (4,950 rows), each with the compared core abstraction, player action and win rule, a similarity
   score and a verdict, and the six named close pairs are listed first.
2. **Given** the current catalog, **When** the check runs, **Then** no pair has the verdict "shares a mechanic" and
   the check passes.
3. **Given** a planted pair with the same mechanic, **When** the check runs, **Then** it fails, names the pair and
   states that the later experience in queue order is redesigned inside its concept; the check never proposes
   removing or merging an experience.
4. **Given** the matrix, **When** the owner reviews it, **Then** the review is recorded as an owner item and does not
   gate.

---

### User Story 7 - Metadata inputs list only integrated experiences (Priority: P3)

The owner and UA-F14 need a machine-readable list of the experiences that may be described in store metadata: only
those whose integration gate is pass, with the facts the store text may state (name, tier, category, declared
permissions).

**Why this priority**: the store text is written later (UA-F14); this feature only guarantees its inputs are true.

**Independent Test**: generate the inputs from the ledger and the catalog; compare with the ledger's pass gates; run
the generator on a fixture ledger with a pending gate.

**Acceptance Scenarios**:

1. **Given** the ledger with X-A01..X-A03 pass, **When** the generator runs, **Then** the inputs list exactly those
   three experiences.
2. **Given** an experience whose integration gate is pending, failed or absent, **When** the generator runs, **Then**
   that experience is not in the inputs.
3. **Given** the inputs, **When** the privacy-answers part is generated, **Then** it states "data not collected" and
   "no tracking" only while the scans of stories 1 and 3 pass on the same build.

### Edge Cases

- **Failure:** any scanner that cannot read a binary, a property list or a manifest fails with the path and reason;
  an unreadable input is never treated as clean.
- **Missing build:** a check that needs the built app and finds none fails and says which build to run; it never
  falls back to the source tree.
- **Stale build:** gate evidence comes only from release-check runs that build the app in the same run; each report
  records the revision, a clean-tree flag, the configuration and the main executable's SHA-256.
- **Cancellation and interruption:** an interrupted scan or generation leaves no partial report; reports are written
  whole or not at all, so a rerun starts clean.
- **Memory pressure:** scans stream binaries and files instead of loading the whole app at once; a large app does not
  change the result.
- **Corrupted or newer-version data:** a configuration, vocabulary, matrix or input file with a newer schema version
  or that does not parse fails with its path; it is never silently upgraded or ignored.
- **System-written strings:** system frameworks linked by the app (UIKit, StoreKit) may contain words that look like
  advertising terms; the scan inspects the app's own binaries and embedded frameworks, not the operating system, and
  any allowance is written down with the reason it is safe.
- **Experiences without a win rule:** the creative experiences A01–A25 have no win rule; the matrix compares them
  on core abstraction and player action and records "open-ended" as their win rule.
- **Shared family templates:** R03/R04 games of one family share a core abstraction and win-rule template by design;
  a shared template alone is not a shared mechanic.
- **Backlog experiences:** rounds 5–12 are not in the matrix and not in the metadata inputs.

## Requirements *(mandatory)*

### Functional Requirements

**Privacy manifest (story 1)**
- **FR-U11-001**: The app MUST have exactly one privacy manifest. The manifest audit MUST run on the built Release
  app, including every embedded framework, and pass only when the declared reason-API categories equal the
  categories found and every declared reason is approved for its category.
- **FR-U11-002**: The audit MUST fail when the manifest declares tracking, tracking domains or collected data types.
- **FR-U11-003**: The audit MUST be a step of the release check and its report MUST record the scanned app's
  revision and configuration.
- **FR-U11-004**: The audit MUST keep its planted-defect self-tests (undeclared category, unused category, tracking
  flag).

**Usage descriptions (story 2)**
- **FR-U11-010**: Each permission an experience needs MUST be declared in its registration as a `permissions` list
  of words from a controlled, versioned vocabulary; each word maps to exactly one usage-description key. A01
  declares `photo-library-add`.
- **FR-U11-011**: A check MUST pass only when the built app's usage-description keys equal the union of the keys of
  the permissions declared by registered experiences; an extra key, a missing key or an unknown word fails.
- **FR-U11-012**: Every usage-description text MUST be non-empty and name the experience feature that asks.
- **FR-U11-013**: The check MUST be a step of the release check and run in CI on the project files.

**No advertising, analytics or tracking (story 3)**
- **FR-U11-020**: A scan of the built app MUST fail on any linked advertising-support or tracking-transparency
  framework, any reference to the advertising identifier or tracking-authorization calls, and any name from a
  maintained deny list of advertising, analytics, attribution and crash-reporting libraries. The deny list MUST cover
  each of these four kinds with at least three widely used libraries.
- **FR-U11-021**: The scan MUST cover the main executable, every embedded framework and library and every bundled
  file, and report each finding with its file.
- **FR-U11-022**: The source compliance check MUST fail on an import of the advertising-support or
  tracking-transparency frameworks and on the deny-listed names.
- **FR-U11-023**: Any finding MUST fail the gate; allowances are listed in the deny-list file with a reason and are
  never added to make a finding pass.
- **FR-U11-024**: The app MUST make no network request of its own; the existing networking rules of the source check
  and of experience verification stay in force and are part of this gate's evidence.
- **FR-U11-025**: The scan MUST be a step of the release check and its self-test MUST plant one defect of each kind.

**Licenses (story 4)**
- **FR-U11-030**: The license inventory check MUST pass: every package and binary dependency of the app is in
  `docs/legal/third-party.json` with an allowed license and an existing text.
- **FR-U11-031**: A built-app assertion MUST pass only when the bundled license set equals the inventory entries
  marked as shipped and every bundled text equals its repository text.
- **FR-U11-032**: The app MUST show every shipped license by name with its full text in the acknowledgements; each
  row has a VoiceOver label (the component name), a stable identifier and a touch target of at least 44 points, and
  the text reflows at every Dynamic Type size (system audits of this screen run in the device campaign).
- **FR-U11-033**: License texts MUST never be removed, rewritten or merged by the agent.

**ProjectM (story 5)**
- **FR-U11-040**: The dependency audit with its binary layer MUST pass on the Release app: no ProjectM symbol,
  library, bundle path or preset file; only the ANGLE libraries embedded.
- **FR-U11-041**: The audit MUST be recorded as a release-check step on the Release app.

**Distinctiveness (story 6)**
- **FR-U11-060**: A generator MUST build a distinctiveness matrix over all unordered pairs of the 100 launch
  experiences from the catalog, normalizing the three design schemas to (core abstraction, player action, win rule):
  R03/R04 core abstraction, player action, win predicate; R02 core abstraction, core action, victory; A01–A25
  launcher category, primary capability, "open-ended".
- **FR-U11-061**: Two experiences MUST be judged to share a mechanic when their normalized triples are equal, when
  their player actions are equal, or when the Jaccard similarity of their normalized player-action word sets is at
  or above 0.5 (normalization: lower case, words of three or more letters, stop words removed, trailing plural "s"
  dropped). A shared core abstraction or win-rule template alone MUST NOT count as a shared mechanic.
- **FR-U11-062**: The six close pairs named by the Round 2 source MUST be listed first in the matrix with their
  scores.
- **FR-U11-063**: A check MUST fail when any pair shares a mechanic, when the matrix is older than the catalog, or
  when it does not cover exactly the launch set.
- **FR-U11-064**: A failure MUST name the pair and require a redesign of the later experience in queue order inside
  its concept; nothing may propose to merge, drop, replace or reorder an experience (D-16).
- **FR-U11-065**: Names and slugs of the launch experiences MUST be unique, and the check MUST fail on a name in a
  maintained list of well-known game titles.
- **FR-U11-066**: The matrix MUST be generated deterministically: the same catalog gives byte-identical output.

**Metadata inputs (story 7)**
- **FR-U11-070**: A generator MUST produce the metadata inputs listing only launch experiences whose integration
  gate is pass in the migration ledger, with name, tier, category and declared permissions.
- **FR-U11-071**: The inputs MUST include privacy answers ("data not collected", "no tracking") derived from the
  passing scans of the same build, and refuse to state them when those scans have not passed.
- **FR-U11-072**: The generator MUST never read or write App Store Connect.

**Common**
- **FR-U11-080**: Every check MUST write a machine-readable report and a one-line PASS or FAIL summary.
- **FR-U11-081**: Every new configuration or report file MUST carry a schema version; a newer or unparsable version
  fails.
- **FR-U11-082**: Gate evidence MUST come from reports produced on the current revision's build.
- **FR-U11-083**: Every new check MUST have a self-test that plants at least one defect it must catch, and each check
  MUST finish in under one minute on the reference host.

**Owner-only items**
- **FR-U11-090**: The legal review of licenses and of the App Store privacy answers MUST be recorded as
  BLOCKED_OWNER_ACTION with exact steps and never performed by the agent.
- **FR-U11-091**: Trademark and name clearance (with the age rating) MUST be recorded as BLOCKED_OWNER_ACTION.
- **FR-U11-092**: The human distinctiveness review MUST be recorded as an owner review that does not gate (D-17).

### Key Entities

- **Permission declaration:** an experience id and the controlled-vocabulary words of the permissions it needs.
- **Permission vocabulary:** word → usage-description key, with a schema version.
- **Tracking deny list:** frameworks, symbols and library names that fail the scan; allowances with reasons.
- **Distinctiveness matrix:** schema version, catalog digest, threshold, rows (pair, normalized triples, score,
  verdict), close pairs first.
- **Metadata inputs:** schema version, ledger revision, experiences (id, name, tier, category, permissions), privacy
  answers with the reports they come from.
- **Check report:** check name, revision, configuration, findings, verdict.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-U11-001**: On the current Release app, the privacy manifest audit reports 0 undeclared and 0 unused
  reason-API categories, and its self-test catches 3 of 3 planted defects.
- **SC-U11-002**: The app's usage-description keys equal the declared-permission union (1 key today), and the check
  catches 3 of 3 planted defects (extra key, missing key, unknown word).
- **SC-U11-003**: The tracking scan reports 0 findings on the Release app and catches 100% of planted defects (one
  per kind: framework link, identifier reference, deny-listed library name, source import).
- **SC-U11-004**: 100% of shipped inventory entries are bundled byte-identical in the Release app, and 100% are
  listed in the acknowledgements screen.
- **SC-U11-005**: The ProjectM audit finds 0 ProjectM symbols, libraries or files in the Release app.
- **SC-U11-006**: The matrix covers 4,950 of 4,950 launch pairs with 0 shared mechanics; the 6 close pairs are its
  first 6 rows; a planted duplicate is caught; two generations are byte-identical.
- **SC-U11-007**: The metadata inputs list exactly the experiences whose integration gate is pass (3 today), and 0
  pending experiences.
- **SC-U11-008**: Every new check finishes in under 60 seconds and runs as a release-check step; the owner items
  are recorded as BLOCKED_OWNER_ACTION.

## Assumptions

- The Release app is built by the existing release check on the reference host. CI builds it with stand-in ANGLE
  frameworks and runs the tracking scan, license assertion and ProjectM audit on that build; the privacy-manifest
  audit needs the real ANGLE frameworks and runs locally.
- The advertising and analytics deny list is a maintained text list in the repository; a clean scan is evidence,
  not legal assurance.
- The similarity score is the Jaccard measure of FR-U11-061 with threshold 0.5, recorded in the matrix.
- The list of well-known game titles is a maintained repository file with no web lookup.
- Permissions for A06–A08 (microphone) are declared when those experiences are integrated; this feature provides
  the vocabulary and the check, not their usage descriptions.
- UA-F04 and UA-F10 are pass in the migration ledger.
- Built-app checks run on the iOS Simulator Release build, which is compiled from the same sources and links the
  same frameworks as the device build; scanning the signed device archive belongs to release packaging (UA-F14) and
  the device campaign, not to this gate. No requirement of this feature needs a device.
