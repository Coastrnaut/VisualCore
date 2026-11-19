# Feature Specification: Visual Programming Lab — Phase 01 Graph schema and type-checking fixtures

**Feature Branch**: `166-vpl-p01-graph-schema` (spec directory only; work stays on `main`)

**Created**: 2026-11-18

**Status**: Draft

**Ledger gate**: A23-P01 (legacy ledger) · ID namespace FR-A23-1##, SC-A23-1##, T-A23-1##

**Input**: User description: archived manual `apps/23-visual-programming-lab.md` §9 Phase 01 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 01):**
  - MVP: a typed node graph for scalar, colour, texture and time values. Here it is the graph's pure model, the node
    library's declared ports and parameters, and the checker. The canvas comes in A23-P02 and the preview in A23-P03;
  - regression fixture: a cycle is rejected with an identifiable path of edges;
  - graphics context ownership stays solely in the audited VisualCore host. The core issues no graphics call, and a
    graph is checked completely before any graphics work, proved inside the host by tests that see no graphics
    resource created for any checked graph.
- **Gaps built here:** G-MODEL and G-TYPES of `docs/apps/visual-programming-lab/visualcore-contract.json`, as a pending
  core in `Packages/ExperiencesCreative/VisualProgrammingLab/Core` until A23-P02 adds the experience.
- **No VisualCore or ProjectM change.** Follow `specs/159-ss-p01-glsl-diagnostics`.

## Clarifications

### Session 2026-11-18

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- **Parameters:** `ParameterDefinition` (VisualCoreParameters, pure) takes a name matching `^[a-zA-Z][a-zA-Z0-9_]{0,31}$`,
  a finite range with minimum < maximum and a default inside it, and throws `ParameterError` otherwise; it offers
  `clamped`, `range` and `defaultValue`.
- **Migration:** `MigrationChain(currentVersion:steps:)` (VisualCorePersistence, pure) migrates a JSON object payload
  step by step and throws `MigrationError.newerVersion` or `.missingStep`.
- **Fingerprint:** `DigestBuilder(domain:)` (VisualCoreExperience, pure; no UIKit) adds typed fields (`add(_:)` for
  Int, String, Bool, Double, which throws `DigestError.nonFinite` for NaN or infinity, and `add(count:)`) and
  `finish()` gives a `StateDigest` (SHA-256 through `StableHash`).
- **Host counts:** `RenderHost(scene:)` (VisualCoreRendering) runs a `RenderScene` off screen, and
  `ResourceRegistry.stats` gives `liveCount` per resource kind and `totalBytes`, as the Shader Studio core tests use.
- **Package layout:** a pending core is `<Name>Core` with `<Name>CoreTests` and no experience target (the pending-core
  allowance of `scripts/check_experience_packages.py`). Its tests may depend on VisualCoreRendering, as Shader Studio's
  did.

- Q: Which value types connect, and which ports does each node kind declare? → A: Four value types (scalar, colour,
  texture, time); a connection needs the same type on both ends, with no implicit conversion (time does not feed a
  scalar input). The library, with parameters as `ParameterDefinition`s:

  | Kind | Inputs (type, required?) | Outputs | Parameters (range, default) |
  |---|---|---|---|
  | `time` | none | `time` (time) | `rate` 0…4, 1 |
  | `constant` | none | `value` (scalar), `colour` (colour) | `value` −8…8, 1; `red`, `green`, `blue` 0…1, 1 |
  | `noise` | `time` (time, optional), `scale` (scalar, optional) | `image` (texture) | `scale` 0.5…32, 4; `octaves` 1…6, 4; `speed` 0…4, 0.5 |
  | `gradient` | `start` (colour, optional), `end` (colour, optional) | `image` (texture) | `angle` 0…360 degrees, 90 |
  | `mix` | `a` (texture, required), `b` (texture, required), `amount` (scalar, optional) | `image` (texture) | `amount` 0…1, 0.5 |
  | `blur` | `image` (texture, required), `radius` (scalar, optional) | `image` (texture) | `radius` 0…16 pixels, 4 |
  | `output` | `image` (texture, required) | none | none |

  An empty optional scalar input uses the parameter of the same name; an empty gradient colour input uses black
  (`start`) or white (`end`). The drawing of each kind comes in A23-P03.
- Q: What are the limits and the identities? → A: `GraphLimits`: at most 32 nodes and 64 connections. A node identity
  is an integer 1…9,999, unique in the graph. A canvas position is two finite numbers in canvas points, each within
  −4,096…4,096 (origin top-left, y down). Parameter values are finite and inside their definition's range; on reading
  a file they are refused, not clamped. A missing parameter takes its default; an undeclared one is refused by the
  checker.
- Q: What is the graph file? → A: `GraphDocument`, kind `a23.visual-graph`, schema 1, at most 65,536 bytes encoded,
  canonical JSON (sorted keys), so a round trip is byte-identical:
  - **Reading:** the body is parsed as a JSON object, passed through `MigrationChain(currentVersion: 1)` (no steps yet;
    the chain is the hook for schema 2), then decoded.
  - **Refusal codes:** `damaged` (not JSON, a wrong kind, a missing field, an unknown node kind, or a version below 1
    or with a missing step), `newer-version`, `too-large` (the file, or nodes or connections past the limits),
    `not-finite` and `out-of-range` (a position, an identity or a parameter value).
  - **Fingerprint:** a `StateDigest` from `DigestBuilder(domain: "a23.visual-graph")` over the version, the output
    node, the nodes in identity order (identity, kind, parameters in name order, position) and the connections in
    order (target node, target port, source node, source port).
- Q: How does the checker order nodes and name a cycle? → A: The checker returns either an accepted result (the
  order and the set of nodes reaching the output) or every refusal it found, in this order of stages, stopping after
  a stage that refused:
  1. limits;
  2. nodes (duplicate identity, undeclared parameter, value outside its range);
  3. connections (unknown node or port, from an input or into an output, type mismatch naming both types, an input
     fed twice, a duplicate connection);
  4. order: Kahn's algorithm, taking the smallest ready identity first. Any nodes left form at least one cycle. The
     named loop is found by walking backwards from the smallest remaining identity along its smallest incoming
     connection (by source identity, then port names) until a node repeats; it is reported in forward order,
     starting with the connection whose source has the smallest identity in the loop;
  5. output: `no-output`, `multiple-outputs`, `output-disconnected`, and `input-unconnected(node, port)` for each
     empty required input.

  The nodes reaching the output are found backwards from the output; the others are kept in the order and marked.
- Q: How is "checking happens before any graphics work" proved, and is anything drawn in this phase? → A: Nothing is
  drawn. A core test runs a scene on `RenderHost` that checks every fixture graph inside the scene's `setup` and
  `render`, with the host's context current, and compares `ResourceRegistry.stats` (`liveCount` for every kind and
  `totalBytes`) before and after. The core imports only pure products (VisualCoreParameters, VisualCorePersistence,
  VisualCoreExperience); the isolation check proves it issues no graphics call.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A graph is a small, bounded document (Priority: P1) 🎯

A person's graph holds its nodes (each with a kind, its parameter values and a place on the canvas), the connections
between their ports, and which node is the output. A graph that is damaged, of a newer version, too large or holds
impossible values is refused with a reason instead of being opened half-broken.

**Why this priority**: every later phase (canvas, compiler, files) builds on this document.

**Independent Test**: encode and decode graphs; feed damaged, newer, oversized and out-of-range samples; each is
refused with its reason.

**Acceptance Scenarios**:

1. **Given** a valid graph, **When** it is encoded and decoded, **Then** it is identical, with the same node
   identities, connections and canvas positions.
2. **Given** a graph of a newer version, a damaged file, a graph one node or one connection past its limit, or a
   parameter or position that is not a finite number, **When** it is read, **Then** it is refused with a named reason.
3. **Given** the same graph twice, **Then** its fingerprint is the same; **given** a graph with one value changed,
   **Then** its fingerprint differs.

---

### User Story 2 - Only matching ports connect (Priority: P1)

Every node kind declares its inputs and outputs, each with one value type: scalar, colour, texture or time. A
connection whose output type differs from the input's type is refused, naming both types, so a colour can never feed
a scalar input without an explicit converter.

**Why this priority**: the manual's fixture 2 and algorithm rule 2 (typed ports enforce composability).

**Independent Test**: try every pair of value types; connect to unknown nodes and ports, twice into one input, and from
an input.

**Acceptance Scenarios**:

1. **Given** a colour output and a scalar input, **When** they are connected, **Then** the connection is refused,
   naming colour and scalar.
2. **Given** an input that already has a connection, **When** a second one is added, **Then** it is refused.
3. **Given** every node kind, **Then** each declares its ports and bounded parameters, and every parameter's default
   lies inside its range.

---

### User Story 3 - A cycle is refused with its path (Priority: P1)

Before any graphics work, the graph is ordered so that every node comes after the nodes that feed it. A graph with a
loop is refused, and the refusal names the connections that form the loop, in order, so the person can see where to
cut it.

**Why this priority**: the phase's regression fixture and the manual's algorithm rule 1.

**Independent Test**: check graphs with loops of one, two and many nodes, and graphs without loops.

**Acceptance Scenarios**:

1. **Given** a loop A → B → C → A, **When** the graph is checked, **Then** it is refused and the refusal lists the three
   connections of the loop, each once, following the loop.
2. **Given** a node connected to itself, **Then** the loop of one connection is named.
3. **Given** a graph without loops, **Then** the order puts every node after all nodes that feed it, and the same graph
   always gives the same order.

---

### User Story 4 - A graph without a connected output says so (Priority: P2)

A graph must have exactly one output node, and that output must be fed. A graph with no output, two outputs, a
disconnected output or a required input left empty is refused with a clear reason naming the node and port.

**Why this priority**: the manual's fixture 3 ("disconnected Output gives clear error state").

**Independent Test**: check graphs missing an output, with two outputs, and with empty required inputs.

**Acceptance Scenarios**:

1. **Given** an output node with nothing connected, **Then** the check refuses the graph as "output disconnected".
2. **Given** a Mix node with one of its two image inputs empty, **Then** the check names that node and input.
3. **Given** a node whose optional input is empty, **Then** the check passes and that input uses the node's
   parameter.

---

### User Story 5 - Checking happens before any graphics work (Priority: P2)

Checking a graph never creates a graphics resource: every refused and every accepted graph is checked with the
graphics host running and its resource counts unchanged.

**Why this priority**: the constitution's A23 rule "validate before GPU work" and the phase's host-ownership gate.

**Independent Test**: check every fixture inside a running host and read its resource counts before and after.

**Acceptance Scenarios**:

1. **Given** the graphics host and every fixture graph, **When** each is checked, **Then** the host's counts of
   programs, textures and render targets are the same before and after.

### Edge Cases

- **An empty graph:** refused as having no output.
- **A graph at exactly the node and connection limits:** accepted; one past either limit is refused before any other
  check.
- **Two connections forming a loop through an otherwise valid graph:** refused as a cycle, never as another error.
- **Several separate loops:** one loop is named, the one reached first in node order, so the refusal is stable.
- **A node not connected to the output:** allowed and ordered, but marked as not reaching the output, so later
  phases can skip it.
- **A connection to a node or port that does not exist, or from an input:** refused by name.
- **A duplicate node identity or an unknown node kind:** refused by name.
- **A parameter the kind does not declare, or a missing one:** an unknown one is refused; a missing one takes its
  default.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A23-101**: A graph MUST hold a version, its nodes (identity, kind, parameter values, canvas position), its
  connections (source node and output port, target node and input port) and its output node, with documented limits
  on nodes and connections.
- **FR-A23-102**: A damaged, newer-version, oversized, non-finite or out-of-range graph MUST be refused with a named
  reason; a valid graph MUST round-trip exactly, and its fingerprint MUST depend only on its content.
- **FR-A23-103**: The node library MUST declare, for the kinds Time, Constant, Noise, Gradient, Mix, Blur and Output,
  each port's name, direction, value type (scalar, colour, texture or time) and whether it is required, and each
  parameter's range and default.
- **FR-A23-104**: The checker MUST refuse a connection whose types differ (naming both), to an unknown node or port,
  from an input, or into an input that is already fed.
- **FR-A23-105**: The checker MUST order the nodes so that each follows its inputs, deterministically, and MUST refuse
  a cycle with its path of connections in loop order.
- **FR-A23-106**: The checker MUST refuse a graph with no output, more than one output, a disconnected output or an
  empty required input, naming the node and port; it MUST mark nodes that do not reach the output.
- **FR-A23-107**: The core MUST be pure: no graphics call, clock read, network or interface framework; checking a graph
  MUST create no graphics resource.

### Key Entities

- **Graph**: version, nodes, connections, output node.
- **Node**: identity, kind, parameter values, canvas position.
- **Port**: node, name, direction, value type, required or optional.
- **Connection**: source node and port, target node and port.
- **Node kind**: name, ports, parameters with ranges and defaults.
- **Check result**: the order and the nodes reaching the output, or the refusals with their nodes, ports and path.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A23-101**: 100% of valid sample graphs round-trip exactly; 100% of refusal samples are refused with their
  reason; the limits are tested at and one past each bound.
- **SC-A23-102**: For all 16 pairs of value types, exactly the 4 matching pairs connect.
- **SC-A23-103**: 100% of the cycle fixtures (loops of 1, 2, 3 and 8 nodes, and two separate loops) are refused with
  exactly the connections of the named loop; 100% of acyclic fixtures give an order in which every node follows its
  inputs, identical across 10 runs.
- **SC-A23-104**: 100% of the output fixtures (none, two, disconnected, empty required input) are refused naming the
  node and port.
- **SC-A23-105**: Checking every fixture inside the running graphics host leaves its resource counts unchanged.
- **SC-A23-106**: Each test finishes in under 10 seconds.

## Assumptions

- The parameter definitions, migration chain, stable hashing and digest builder exist in VisualCore (A23-P00
  contract) and are reused unchanged.
- The exact limits are chosen and documented in this phase; they are checked on devices in the device campaign.
- The node kinds' drawing (their shaders) comes in A23-P03; this phase declares only their ports and parameters.

## Traceability

| Source | Requirement |
|---|---|
| MVP: typed node graph for scalar, colour, texture and time values | FR-A23-101, 103, 104 |
| Regression fixture: cycle is rejected with identifiable edge or path | FR-A23-105, SC-A23-103 |
| Host owns the graphics context | FR-A23-107, SC-A23-105 |
| Manual fixtures 1–3 (cycle path; colour into scalar; disconnected output) | FR-A23-104–106 |
| Algorithm rules 1–2 (topological order before GPU work; typed ports) | FR-A23-104, 105 |
| Version 0.1 features 01, 02 (ports only), 04 | FR-A23-101–106 |
| Brainstorm: render graph, parameter system, graph serialization | FR-A23-101–103 |
| Contract G-MODEL, G-TYPES | FR-A23-101–107 |

## Negative Requirements

- No VisualCore or ProjectM change; no experience target, registration or interface in this phase; no graphics call in
  the core; no network; no feedback or loop nodes; no arbitrary scripting; no artwork.
