# Feature Specification: Visual Programming Lab — Phase 04 Save/load, examples and diagnostics

**Feature Branch**: `169-vpl-p04-library-diagnostics` (spec directory only; work stays on `main`)

**Created**: 2026-11-18

**Status**: Draft

**Ledger gate**: A23-P04 (legacy ledger) · ID namespace FR-A23-4##, SC-A23-4##, T-A23-4##

**Input**: User description: archived manual `apps/23-visual-programming-lab.md` §9 Phase 04 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 04):**
  - MVP: cycle detection and clear invalid-connection feedback, now shown on the nodes themselves;
  - regression fixture: save and load preserve node identities, port links and layout;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gap built here:** G-LIBRARY of `docs/apps/visual-programming-lab/visualcore-contract.json`.
- **Still a candidate:** not available to a person until X-A23.
- **No VisualCore or ProjectM change.** Follow `specs/162-ss-p04-limits-error-ux` (Shader Studio's project library)
  and `specs/168-vpl-p03-graph-compiler`.

## Clarifications

### Session 2026-11-18

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- **Storage:** `ExperienceStorage` (VisualCoreExperience) holds an experience's files within `StorageQuota` (16 MiB and
  64 files); `write(_:to:)` is atomic and throws `StorageError.tooLarge`, `.quotaExceeded("files" | "bytes")` or
  `.writeFailed`, keeping the previous file of that name; `read`, `exists`, `list` and `remove` complete it.
- **Precedents:** Shader Studio's `ProjectLibrary` and Digital Zen Garden's `GardenLibrary` keep one file per item and
  an index; Zen Garden opens a saved garden into its core by building a snapshot and calling `shell.restore(_:)`.

- Q: How are graphs stored? → A: `GraphLibrary` in the experience, after `ProjectLibrary`:
  - `graph-<n>.json`: the envelope `{"body", "kind": "a23.saved-graph", "version": 1}` whose body is `{name, order,
    graph}`, the graph being the `GraphDocument` encoding embedded as a JSON object; at most 81,920 bytes; n is a
    counter, never reused while the index or a higher file exists;
  - `library.json`: the envelope `{"body", "kind": "a23.graph-library", "version": 1}` holding the counter and the
    names; the graph files are the truth;
  - caps: at most 24 graphs (unreadable files count); a name trimmed and 1…40 characters; names differing only in case
    are the same; messages "The library holds 24 graphs.", "A name has 1 to 40 characters." and "A graph is already
    called <name>.";
  - a file refused as `damaged`, `newer-version`, `too-large` or with the `GraphDocumentRefusal` code of its graph is
    listed as unreadable with that code, never opened, renamed or deleted automatically; the person may remove it.
- Q: How does an opened graph reach the core? → A: As Zen Garden does: the presenter builds a `LabCore` snapshot with
  the opened graph and no selection and calls `shell.restore(_:)`; a refused restore leaves the graph as it was. The
  preview compiles it at the next frame. The session snapshot (A23-P02) already keeps the open graph across a
  relaunch.
- Q: How is migration exercised when only one format exists? → A: The graph file stays schema 1. Reading goes through
  `GraphDocument.migrations` (`MigrationChain`); a test gives the library's reader a chain with a step from a synthetic
  version 0 shape (nodes named `items`) and proves an old file migrates and opens; a committed schema-1 sample written by
  today's encoder is read back unchanged (a stored-file sample, as Shader Studio's).
- Q: Which examples ship? → A: `LabExamples` in the experience, written in this repository: `clouds` (Time into Noise
  into Output), `soft-gradient` (a Constant colour into Gradient's start, Gradient into Blur into Output) and
  `mixed-clouds` (the journey graph); each opened through the same restore path from an "Examples" menu
  (`example-<id>`), recorded in `docs/apps/visual-programming-lab/licenses.md`.
- Q: How are problems mapped to nodes? → A: `GraphDiagnostics.byNode(_ result: CheckResult, in graph)` in the core
  (pure): `inputUnconnected(node, port)` → that node "Input <port> is empty."; `outputDisconnected(id)` → the Output
  "Nothing is connected to this Output."; `cycle(edges)` → every source node "This node is part of a loop.";
  `multipleOutputs(ids)` → each Output "Only one Output may exist."; connection-stage issues → the target node with the
  `EditMessages` sentence; `noOutput` and limits → no node (the graph-level status). The overlay draws a marked node
  with a dashed red outline and a "!" badge (not by colour alone) and the list form shows the sentences under the node;
  both are spoken.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Save a graph and open it again (Priority: P1) 🎯

A person names and saves the graph they built, keeps several graphs, and opens one later; it comes back with the same
nodes, connections, parameter values and layout. They can rename and remove saved graphs.

**Why this priority**: the manual's journey 3 (save the graph and reopen it) and the phase's regression fixture.

**Independent Test**: save the journey graph, open it in a new session, compare; rename and remove.

**Acceptance Scenarios**:

1. **Given** a saved graph, **When** it is opened again, **Then** its node identities, connections, parameter values
   and positions are exactly the same.
2. **Given** a saved graph, **When** it is renamed or removed, **Then** the list shows the change and the other graphs
   are untouched.
3. **Given** the library is full or a name is taken or empty, **Then** saving is refused with a message and nothing is
   written.

---

### User Story 2 - A damaged or newer file is never lost (Priority: P1)

A saved file that is damaged, or was written by a newer version of the app, is listed as unreadable with a reason; it
is never opened half-broken and never deleted unless the person removes it.

**Why this priority**: the manual's risk 3 (graph files must stay readable across versions; a migration policy).

**Independent Test**: place damaged, newer and oversized files in the library; list; open; check they remain.

**Acceptance Scenarios**:

1. **Given** a damaged file, **Then** it is listed as unreadable with a reason, opening it is refused, and the file
   is still there afterwards.
2. **Given** a file of an older format, **Then** it is migrated on opening (the migration path is exercised).

---

### User Story 3 - Start from an example (Priority: P2)

A person can start from one of a few example graphs written in the app (for example clouds, a soft gradient, mixed
clouds), each showing its picture in the preview.

**Why this priority**: the manual's journey 1 (open an example graph) and the first launch.

**Independent Test**: open each example; it is valid and compiles.

**Acceptance Scenarios**:

1. **Given** each example, **Then** it passes the checker, compiles within the budget and draws a picture.

---

### User Story 4 - Problems are shown on the nodes they concern (Priority: P2)

When the graph has a problem (an empty required input, a disconnected output, a loop), each node involved is marked
on the canvas and in the list form, with a sentence saying what is wrong, read by VoiceOver.

**Why this priority**: the phase's MVP (clear invalid-connection feedback) and the manual's render stage 4 (map
diagnostics to graph nodes).

**Independent Test**: build each invalid fixture; read the marks per node.

**Acceptance Scenarios**:

1. **Given** a Mix with an empty input, **Then** the Mix is marked with "input b is empty" and no other node is.
2. **Given** a disconnected Output, **Then** the Output is marked.
3. **Given** a valid graph, **Then** no node is marked.

### Edge Cases

- **The same graph saved twice under two names:** two entries.
- **A name of only spaces or past the length limit:** refused.
- **A file past the size limit:** refused on reading, listed, and kept.
- **The storage quota reached while saving:** refused with a message; nothing is half-written.
- **Opening a graph while the preview is compiling:** the opened graph compiles at the next frame.
- **The session restored after a relaunch:** the open graph returns from the session snapshot.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A23-401**: A person MUST be able to save the graph under a name, list, open, rename and remove saved graphs,
  within documented limits on count, name length and file size, in the experience's own storage.
- **FR-A23-402**: Opening a saved graph MUST restore its node identities, connections, parameter values and positions
  exactly.
- **FR-A23-403**: A damaged, newer or oversized file MUST be listed as unreadable with a reason, refused on opening and
  never deleted except by the person; an older format MUST be migrated when opened.
- **FR-A23-404**: At least three example graphs MUST exist, written in code with a licence and provenance record, each
  valid and drawable within the budget.
- **FR-A23-405**: Every checker problem MUST be shown on the node or nodes it concerns, on the canvas and in the list
  form, with a spoken sentence.
- **FR-A23-406**: Saving MUST never leave a partial file; a refusal MUST change nothing.

### Key Entities

- **Saved graph**: a name, an order, the graph file.
- **Library index**: the saved graphs and the unreadable entries with their reasons.
- **Example**: an identifier, a title, a graph, a licence line.
- **Node diagnostic**: a node and its sentences.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A23-401**: 100% of saved fixtures reopen with identical identities, connections, values and positions (the
  graph's fingerprint is equal).
- **SC-A23-402**: 100% of damaged, newer and oversized samples are listed with their reason, refused on opening and
  still present afterwards.
- **SC-A23-403**: The count, name and size limits are tested at and one past each bound.
- **SC-A23-404**: 100% of examples pass the checker, compile and draw a non-flat picture.
- **SC-A23-405**: For 100% of invalid fixtures, exactly the nodes named by the checker are marked.
- **SC-A23-406**: Each test finishes in under 10 seconds.

## Assumptions

- The graph file of A23-P01, the editor and canvas of A23-P02 and the preview of A23-P03 are reused.
- VisualCore's experience storage and its quota are reused unchanged (A23-P00 contract), as Shader Studio's library
  does.

## Traceability

| Source | Requirement |
|---|---|
| MVP: cycle detection and clear invalid-connection feedback | FR-A23-405 |
| Regression fixture: save and load preserve node identities, port links and layout | FR-A23-402, SC-A23-401 |
| Host owns the graphics context | Unchanged (no new drawing path) |
| Journeys 1 and 3 (open an example; save and reopen) | FR-A23-401, 404 |
| Manual risk 3 (migration policy) | FR-A23-403 |
| Version 0.1 features 04, 06 | FR-A23-401–405 |
| Contract G-LIBRARY | FR-A23-401–406 |

## Negative Requirements

- No VisualCore or ProjectM change; no availability to a person; no sharing, import or export of graphs; no network;
  no cloud storage; no artwork; no automatic deletion of any file.
