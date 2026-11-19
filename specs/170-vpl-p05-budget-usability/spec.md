# Feature Specification: Visual Programming Lab — Phase 05 Resource-budget and usability testing

**Feature Branch**: `170-vpl-p05-budget-usability` (spec directory only; work stays on `main`)

**Created**: 2026-11-19

**Status**: Draft

**Ledger gate**: A23-P05 (legacy ledger) · ID namespace FR-A23-5##, SC-A23-5##, T-A23-5##

**Input**: User description: archived manual `apps/23-visual-programming-lab.md` §9 Phase 05 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 05):**
  - MVP: the preview compiles a bounded acyclic graph (built at A23-P03) and stays within its budget under heavy use;
  - regression fixture: a simple graph produces the expected pixels and draws no pass it does not need;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gap built here:** G-DEVICE of `docs/apps/visual-programming-lab/visualcore-contract.json`: the device plan; its rows
  stay pending until after ImplementationLock-100 {device}.
- **Interface evidence:** one pass on the iOS 27.2 phone simulator; accessibility audits wait for the devices.
- **Still a candidate:** not available to a person until X-A23.
- **No VisualCore or ProjectM change.** Follow `specs/163-ss-p05-stress-recovery`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Heavy editing never grows the memory in use (Priority: P1) 🎯

A person edits for a long time: adding and removing nodes, rewiring, opening examples, building graphs that are
refused for the budget. The graphics resources in use stay at the level of the first cycle; nothing leaks.

**Why this priority**: the manual's risk 1 (texture memory from user graphs) and the phase's MVP.

**Independent Test**: run repeated edit, open and refusal cycles; compare the resource level after the first and the
last cycle.

**Acceptance Scenarios**:

1. **Given** 50 mixed cycles (edit, example, a budget refusal, a context rebuild), **Then** the resources in use
   after the last cycle equal those after the first, with no leak.
2. **Given** a refused graph, **Then** the resources in use are unchanged.

---

### User Story 2 - A simple graph draws exactly what it should (Priority: P1)

A Gradient into Output draws the expected ramp, and the preview runs only the passes the picture needs: nodes that do
not reach the Output, Time and Constant add no pass.

**Why this priority**: the phase's regression fixture and the manual's algorithm rule 3.

**Independent Test**: draw fixture graphs; compare pixels; count the passes drawn per frame.

**Acceptance Scenarios**:

1. **Given** Gradient into Output, **Then** the preview matches its reference and one picture pass plus the output
   pass are drawn.
2. **Given** the same graph with an unconnected Noise and a Constant, **Then** the same pixels and the same pass count.

---

### User Story 3 - The preview recovers in every state (Priority: P2)

Whatever state the preview is in (drawing, invalid graph, refused for the budget, failed, hidden), a context loss
or rebuild leaves the same picture and state and nothing leaks.

**Why this priority**: the host's lifecycle rules.

**Independent Test**: in each state, rebuild the context 10 times; compare.

**Acceptance Scenarios**:

1. **Given** each of the five states, **When** the context is rebuilt 10 times, **Then** the picture, state and
   resources in use are unchanged and nothing leaks.

---

### User Story 4 - A person can build and keep a graph on a phone (Priority: P2)

On a phone, a person can open the lab, connect ports through the list form, see a refused connection's sentence, save
a graph, and find it again after the app is closed and reopened.

**Why this priority**: the manual's risk 2 (touch wiring on small screens) and usability testing.

**Independent Test**: interface tests on the phone simulator.

**Acceptance Scenarios**:

1. **Given** the lab on a phone, **When** a source is chosen in the list form for an input, **Then** the connection
   appears and the status reads Ready.
2. **Given** a colour output chosen for a scalar input, **Then** the refusal sentence is shown.
3. **Given** a saved graph, **When** the app is closed and reopened, **Then** the graph is listed and opens.

---

### User Story 5 - The device checks are planned (Priority: P3)

The checks that only real devices can answer (texture memory of the largest example graphs, wiring on a small phone,
preview pacing, the accessibility audits) are written down per device, waiting for the device campaign.

**Why this priority**: the gap G-DEVICE; device testing comes after ImplementationLock-100.

**Independent Test**: read the plan; every row has steps, an expected result and the state pending.

### Edge Cases

- **A rebuild while a compile is waiting:** the compile happens once, at the first frame after the rebuild.
- **A budget refusal right after a context loss:** nothing is allocated; the refusal message stays.
- **The app closed while the library is writing:** the previous file stays (atomic writes, A23-P04).
- **A very small phone:** the list form reaches every port without dragging.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A23-501**: Repeated editing, example opening, budget refusals and context rebuilds MUST leave the graphics
  resources in use at the level of the first cycle, with no leak.
- **FR-A23-502**: A simple graph MUST draw its expected pixels with exactly the passes its picture needs; nodes not
  reaching the Output and value nodes MUST add no pass.
- **FR-A23-503**: In each preview state, a context rebuild MUST keep the picture, the state and the resource level,
  with no leak.
- **FR-A23-504**: The list-form connection, a refusal's sentence and a saved graph surviving a relaunch MUST be proved
  by interface tests on the phone simulator.
- **FR-A23-505**: A device plan MUST list, per device, the checks that need real hardware, each pending.

### Key Entities

- **Resource level**: the live objects per kind and the bytes in use.
- **Device plan row**: an identifier, the devices, steps, expected result, owner actions, state.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A23-501**: After 50 mixed cycles the resource level equals that after the first cycle, with 0 leaked.
- **SC-A23-502**: The simple-graph fixtures match their references within 2 of 255 and draw exactly 2 passes per frame.
- **SC-A23-503**: 10 rebuilds in each of 5 states keep the picture byte-identical and the level unchanged.
- **SC-A23-504**: The interface tests pass on the iOS 27.2 phone simulator, each in under 60 seconds.
- **SC-A23-505**: The device plan has rows for each of D1, D2 and D3, all pending.
- **SC-A23-506**: Each unit test finishes in under 10 seconds.

## Assumptions

- The preview, library and diagnostics of A23-P03 and A23-P04 are reused; the app's interface-test harness and its
  chunks are reused as Shader Studio's are.
- Measurements of memory and pacing on hardware wait for the device campaign {device}.

## Traceability

| Source | Requirement |
|---|---|
| MVP: preview compiles a bounded acyclic graph | FR-A23-501, 502 |
| Regression fixture: a simple graph gives expected pixels and avoids unnecessary passes | FR-A23-502, SC-A23-502 |
| Host owns the graphics context | FR-A23-503 |
| Manual risks 1 and 2 | FR-A23-501, 504 |
| Contract G-DEVICE | FR-A23-505 |

## Negative Requirements

- No VisualCore or ProjectM change; no availability to a person; no device install or test; no accessibility audit
  run before the devices; no measured device figure claimed; no network.
