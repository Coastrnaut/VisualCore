# Feature Specification: R02-F02 — VisualCore public API compatibility and renderer capability probing

**Feature Branch**: `202-visualcore-public-api-compatibility-and-renderer-capability-probing` (spec directory only;
work stays on `main`)

**Created**: 2026-11-13

**Status**: Draft

**Ledger gate**: R02-F02 (migration ledger, shared round feature) · FR-R02F02-###, SC-R02F02-###, T-R02F02-###

**Input**: the archived R2-F02 `/speckit-specify` prompt (docs/archive/planning/rounds/round2.md:375) with the
canonical overrides of the invocation.

Canonical overrides:
- **Disposition (Auto-Creator.md section 13.4):** reuse. The public API baseline and the renderer's capability report
  already exist; this feature audits them, closes the gaps the audit found, and adds probes only where a named
  consumer needs them.
- **Superseded source items:** the price range (one USD 1.99 non-consumable, CLAUDE.md rule 3); "no IAP" (the one
  purchase is the only in-app purchase); the Round 2 lock (ImplementationLock-100); the prerequisite R2-F01 (UA-F00).
- **Who the users are:** the engineer writing a game or creative experience, who needs to know before relying on a GPU
  feature whether the running renderer offers it; the verification runner and the device campaign, which record what
  the renderer offered; and the owner, who needs public framework changes to stay compatible for the 100 experiences.
- **Device-only items:** the capability values of D1, D2 and D3 are recorded in the device campaign. **Owner-only:**
  none.
- **What exists today (read-only audit of 2026-11-13, names verified):**
  - The renderer's report (`RenderCapabilities` in VisualCoreRendering) holds the GL and GLSL version strings,
    renderer, vendor, EGL vendor, extensions, maximum texture size, maximum viewport, maximum renderbuffer size, and the
    fragment high and medium precision (optional, so older reports still decode). It is taken once when the render host
    is created (`RenderHost` init) and is **not** taken again when the context is recreated (`recreateContext`), though
    its documentation says it is captured once per context generation.
  - The GL entry points are loaded through EGL; the host refuses to start when an entry point is missing. After a
    context recreation the load result is ignored.
  - A real render-target probe exists for half-float colour buffers (`FloatRenderSupport`), redone per generation.
  - Not queried: maximum samples (MSAA), draw buffers, colour attachments, vertex and integer precision, vertex
    attributes, uniform vectors, texture units, varying vectors, the EGL version and EGL extensions.
  - No general record of the capabilities goes into the verification evidence; only one experience's automation
    records part of it.
  - API compatibility: `scripts/check_public_api.py` fails on an undocumented public declaration and on a difference
    from the tracked baseline `docs/api/visualcore-public-api.txt`.
  - The window surface has no MSAA or depth configuration; changing it departs from ADR-0002 (out of scope).

## Clarifications

### Session 2026-11-13

- Q: How does the evidence record, which lives in the pure package, carry the renderer's report without depending on
  the rendering package? → A: The record's environment gains an optional `renderer` value of a new pure type in the
  experience module (strings and whole numbers only, every field optional). The app's automation fills it from the
  render host's report when it writes the evidence. JSON key `renderer`; an evidence file without it stays valid.
  Rejected: a free-form string map, which would not be typed or checked, and a dependency from the pure package on the
  rendering package, which rule R2 forbids.
- Q: Where do the context generation and the ES 3.0 floor check live? → A: The report gains an optional `generation`,
  set by the render host each time it takes the report. The floor check is a pure function of the report in the
  rendering package that returns the list of findings; the verification runner does not fail on a finding, it
  records it (simulator values are not device values).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An experience can ask what the renderer offers (Priority: P1)

An engineer writing an experience reads, from the running renderer, whether multisampling, several draw buffers,
high vertex precision and the needed limits are available, and chooses a path that works.

**Independent Test**: on both simulator runtimes, the report of a fresh render host holds every queried value, and each
value meets the OpenGL ES 3.0 minimum (for example at least 4 draw buffers, at least 4 samples, a texture size of at
least 2048).

**Acceptance Scenarios**:
1. **Given** a render host, **When** its report is read, **Then** it holds the values listed in FR-R02F02-001.
2. **Given** a value the renderer does not report (an error from the query), **Then** that value is absent in the
   report, never zero passed off as a limit.

### User Story 2 - The report stays true after the context is rebuilt (Priority: P1)

After a lost context is recreated, the report describes the new context, and a missing entry point after the reload is
reported rather than ignored.

**Independent Test**: recreate the context of a host; the report's generation follows the context's, and the load
result of the reload is in the report.

**Acceptance Scenarios**:
1. **Given** a recreated context, **Then** the report is taken again and marked with the new generation.
2. **Given** a reload with missing entry points, **Then** the host is failed with a typed error naming the count, as
   at creation.

### User Story 3 - Evidence records the renderer (Priority: P2)

Every verification run records what the renderer offered, so a result can be read against the GPU it ran on.

**Independent Test**: one verification run of any experience writes the report into its evidence; the evidence
validator accepts it, and an older evidence file without it still validates.

### User Story 4 - The public API stays compatible (Priority: P2)

Every public change of the framework adds; nothing is removed or changed without a recorded decision; older stored
reports keep decoding.

**Independent Test**: the API check passes with only added lines; decoding a report written before this feature gives
the same values with the new fields absent.

### Edge Cases

- A query returns a GL error or a value below the ES 3.0 minimum: the value is recorded as reported; a below-minimum
  value is listed by the floor check as a finding, never silently raised.
- Context loss during the query: the partial report is discarded; the next generation queries again.
- A report written by a newer build with unknown fields: older readers ignore unknown fields; a report that cannot be
  decoded is refused with a message, never a crash.
- Memory pressure or background during the query: the query runs only while the context is current on the render
  thread; otherwise it waits for the next generation.
- Accessibility: no user interface is added; the report is developer-facing (stated, not applicable).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02F02-001**: The renderer's report MUST add, each optional: maximum samples, maximum draw buffers, maximum colour
  attachments, maximum vertex attributes, maximum vertex and fragment uniform vectors, maximum texture image units,
  maximum varying vectors, vertex high and medium float precision, fragment high integer precision, the EGL version and
  the EGL extensions, and the count of missing GL entry points.
- **FR-R02F02-002**: A value whose query fails MUST be absent from the report.
- **FR-R02F02-003**: The report MUST be taken again after every context recreation and carry the context generation
  it describes.
- **FR-R02F02-004**: A reload of the entry points after recreation with missing entry points MUST fail the host with
  the same typed error as at creation.
- **FR-R02F02-005**: A floor check MUST compare a report with the OpenGL ES 3.0 minimum values and list each value
  below its minimum.
- **FR-R02F02-006**: The verification evidence of every run MUST contain, in the environment's optional `renderer`
  value (a pure type with optional fields, clarification 1), the report of the host it ran on; evidence files without
  it MUST stay valid.
- **FR-R02F02-007**: Reports written before this feature MUST decode with the new values absent.
- **FR-R02F02-008**: Every new public declaration MUST be documented and in the API baseline; the API check MUST show
  only added lines; the reference regression MUST pass after the change.
- **FR-R02F02-009**: The window surface configuration MUST NOT change (no MSAA or depth on the window; ADR-0002).
  Multisampling is reported, not enabled.
- **FR-R02F02-010**: Copyright and originality: the feature adds only code; the GL constant values come from the
  already tracked declarations.

### Key Entities

- **Capability report**: the renderer's values for one context generation, each optional, plus the generation.
- **Floor finding**: a value, its ES 3.0 minimum and the reported value.

## Success Criteria *(mandatory)*

- **SC-R02F02-001**: On both simulator runtimes, 100% of the values of FR-R02F02-001 are present for a fresh host and
  0 floor findings are reported.
- **SC-R02F02-002**: After 3 of 3 context recreations, the report's generation equals the context's.
- **SC-R02F02-003**: A stored report from before this feature decodes in 1 of 1 test with the new values absent.
- **SC-R02F02-004**: 1 verification run writes the report into its evidence, and the evidence validator accepts both a
  new and an old evidence file.
- **SC-R02F02-005**: The API check shows 0 removed or changed lines and 0 undocumented declarations; the reference
  regression passes 7 of 7.

## Assumptions

- The simulator's ANGLE values are not device values; device values are recorded in the device campaign.
- Named consumers: the rounds' 3D games (samples, draw buffers), the bloom and post effects (colour attachments,
  formats), the shader playground and benchmark experiences (versions, precision, limits).
