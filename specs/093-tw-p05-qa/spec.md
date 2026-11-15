# Feature Specification: Tiny Worlds — Phase 05 Memory, thermal and content QA

**Feature Branch**: `093-tw-p05-qa` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A12-P05 (legacy ledger) · ID namespace FR-A12-5##, SC-A12-5##, T-A12-5##

**Input**: User description: archived manual `apps/12-tiny-worlds.md` §9 Phase 05 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 05):** MVP — saved world composition and thumbnails (built in A12-P03, audited here
  under stress); regression fixture — world load and unload cycles do not retain stale graphics objects; graphics
  context ownership stays solely in the VisualCore host.
- **Gap built here** (contract `docs/apps/tiny-worlds/visualcore-contract.json`): G-DETAIL (app-local) — the detail
  tier table (terrain resolution, prop and draw caps, thumbnail size) and its response to memory warnings, heat and Low
  Power Mode, never changing the world.
- **Quality levels** stay declared as three (since A12-P02); the experience's declared count, the drawing's levels and
  the catalog registration agree.
- **Device QA:** frame pacing, thermals, memory and touch latency on real devices are planned in a device-campaign
  document; device tasks are tagged {device} and run only after ImplementationLock-100.
- **Storefront:** no per-app listing (ADR-0009); the catalog entry is written truthfully here, every capability backed
  by a named test, with no claims of scientific, geographic or platform accuracy.
- **Owner rulings:** short tests; measure briefly and bound longer runs by arithmetic; no wall-clock assertions on CI;
  iOS 27 at phase gates; reference regression and iOS 26 at X-A12; every Spec Kit step runs.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The world stays light when the device is under pressure (Priority: P1) 🎯

When the device warns about memory, heats up or enters Low Power Mode, a person keeps exploring the same world drawn
with less detail, and when the pressure passes the detail returns — the world itself never changes.

**Why this priority**: the phase's name and gap; protects the experience on real devices.

**Independent Test**: drive the tier policy with simulated memory warnings, thermal states and Low Power Mode; read the
chosen tier, the counts and the world digest.

**Acceptance Scenarios**:

1. **Given** a world at full detail, **When** a memory warning arrives, **Then** the lowest tier is used within one
   frame and its counts stay within budget, and the world's digest is unchanged.
2. **Given** a serious or critical thermal state or Low Power Mode, **When** the policy runs, **Then** the tier steps
   down as stated, and steps back up only after the pressure has eased for the stated time.

---

### User Story 2 - Opening and closing worlds leaves nothing behind (Priority: P1)

The engineer can trust that switching packs, opening saved worlds, closing and reopening the experience and losing the
graphics context any number of times leaves no graphics objects behind.

**Why this priority**: the manual's regression fixture for this phase.

**Independent Test**: count live graphics objects across repeated cycles; compare with the count after the first
cycle.

**Acceptance Scenarios**:

1. **Given** a run of cycles (pack switches, slot opens, tier changes, context recreations, close and reopen), **When**
   each cycle ends, **Then** the live object count equals the first cycle's count and closing leaves zero.

---

### User Story 3 - Saved worlds hold under stress (Priority: P2)

A person saves and reopens worlds at every tier and after pack switches, and every reopened world matches what was
saved, with a thumbnail of the capped size.

**Independent Test**: save and reopen across tiers and packs; compare documents, digests and thumbnails.

**Acceptance Scenarios**:

1. **Given** a world saved at any tier, **When** reopened at another, **Then** its document and digest are identical
   and its thumbnail is within the capped size.

---

### User Story 4 - The catalog says only what is proven (Priority: P2)

The owner can trust that every capability in Tiny Worlds' catalog entry is backed by a named test and that no copy
claims accuracy or measured performance.

**Independent Test**: read the README's capability-to-proof table; run the claims scan.

**Acceptance Scenarios**:

1. **Given** the catalog registration, **When** each capability is looked up, **Then** a proving test exists for it.
2. **Given** the claims scan, **When** run over the catalog entry and the README, **Then** it finds no refused claim.

### Edge Cases

- **Repeated memory warnings:** stay at the lowest tier; never below it; no rebuild storm (at most one rebuild per tier
  change).
- **Thermal state flapping:** stepping up waits for a hold time, so the tier changes at most once per hold time.
- **Low Power Mode on at launch:** the lowest tier from the first frame.
- **A thumbnail requested at the lowest tier:** same capped size; drawn at the current tier.
- **Context loss during a tier change:** rebuilds once, at the new tier.
- **Device-only measures** (frame pacing, temperature, memory high-water mark, touch latency): planned, not claimed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A12-501**: A tier table MUST state per tier the terrain resolution, the prop cap drawn, the draw cap and the
  thumbnail size; lower tiers MUST never raise a count.
- **FR-A12-502**: A tier policy MUST choose the tier from the host's quality level, memory warnings, the thermal state
  and Low Power Mode, with stated step-down and step-up rules and a hold time; changing the tier MUST NOT change the
  world or its digest.
- **FR-A12-503**: Load and unload cycles (pack switches, slot opens, tier changes, context recreations, close and
  reopen) MUST leave no stale graphics objects.
- **FR-A12-504**: Saved worlds MUST round-trip identically across tiers and packs, with thumbnails within the cap.
- **FR-A12-505**: The experience's declared quality levels, the drawing's levels and the registration MUST agree.
- **FR-A12-506**: The catalog entry (name, summary, capabilities) MUST be backed by a README capability-to-proof table
  of existing tests, and a claims scan MUST refuse accuracy and measured-performance words.
- **FR-A12-507**: A device-campaign document MUST list the device-only measurements and audits as {device} tasks.

### Key Entities

- **Tier**: index 0…2, terrain cells, prop draw cap, draw cap, thumbnail size.
- **Pressure**: memory warning, thermal state, Low Power Mode.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A12-501**: For every pack and tier, counts stay within the tier's budget and lower tiers never raise a count.
- **SC-A12-502**: 100 % of simulated pressure sequences produce the stated tiers; 0 world digests change.
- **SC-A12-503**: After 20 load/unload cycles the live graphics object count equals the first cycle's; closing leaves 0.
- **SC-A12-504**: 100 % of saved worlds reopen identically across tiers and packs.
- **SC-A12-505**: Every registered capability names an existing test; the claims scan finds 0 refused claims.
- **SC-A12-506**: The runner's nine scenarios pass on iOS 27; every test runs in under 10 s.

## Assumptions

- The three detail levels, packs, saved worlds and thumbnails of A12-P02–P04 exist; the host passes a quality level
  and Low Power Mode as it does for Physics Playground and Neon Arcade; the resource registry counts live objects.

## Traceability

| Source | Requirement |
|---|---|
| Phase 05 MVP: saved world composition and thumbnails (under stress) | FR-A12-504 |
| Regression fixture: load/unload cycles retain no stale GPU objects | FR-A12-503, SC-A12-503 |
| EGL/context ownership in the VisualCore host | FR-A12-503 |
| Manual feature 6: dynamic detail tier based on GPU/memory budget | FR-A12-501, 502, 505 |
| Constitution A12: bounded, truthful claims | FR-A12-501, 506, 507 |
| Contract gap G-DETAIL | FR-A12-501–503 |

## Negative Requirements

- No measured performance, memory or battery numbers claimed; no new content; no network.
