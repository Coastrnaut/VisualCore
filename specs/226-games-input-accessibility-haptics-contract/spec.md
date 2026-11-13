# Feature Specification: R02-F26 — Games input, accessibility and haptics contract

**Feature Branch**: `226-games-input-accessibility-haptics-contract` (spec directory only; work stays on `main`)

**Created**: 2026-11-13

**Status**: Draft

**Ledger gate**: R02-F26 (migration ledger, shared round feature) · FR-R02F26-###, SC-R02F26-###, T-R02F26-###

**Input**: the archived R2-F26 `/speckit-specify` prompt (docs/archive/planning/rounds/round2.md:1551) with the
canonical overrides of the invocation.

Canonical overrides:
- **Disposition (Auto-Creator.md section 13):** extend. Reduce Motion and Reduce Flashing, their settings and their
  hand-off to an experience already exist (UA-F04); this feature adds what games need on top: gesture arbitration, a
  non-gesture route for every gesture, announcements for VoiceOver, colour independence, and haptics.
- **Superseded source items:** the price range and "no IAP" (one USD 1.99 non-consumable, CLAUDE.md rule 3); the Round 2
  lock (ImplementationLock-100); R2-F25 (the session host and shell of UA-F03 and UA-F04); the source's GPU fixtures for
  stale contexts and GPU capabilities (this contract uses no GPU resource); report paths with their own hash logs (the
  ledger's evidence).
- **Who the users are:** a person playing a game of the app with touches, with VoiceOver, with Reduce Motion or Reduce
  Flashing, or with colour vision differences; a person who wants or does not want haptic feedback; and the engineer
  writing one of the 75 games, who needs one shared contract instead of 75 different ones.
- **Device-only items:** how haptics feel and that they fire (the simulator has no haptic engine); manual VoiceOver
  passes (recorded, not gating); the system accessibility audits (owner ruling of 2026-11-13: device campaign only).
  **Owner-only:** none.
- **What exists today (read-only audit of 2026-11-13, names verified):**
  - Recognizers for tap, double tap, long press, drag, pinch and rotate exist in VisualCoreScenes
    (`GestureRecognizers.swift`) with a pointer tracker; nothing decides which recognizer wins when several could; each
    presenter decides on its own (for example by the number of fingers).
  - An experience declares its controls (`ExperienceControl`) and receives actions from native controls and from the
    canvas through the same path; nothing checks that a canvas gesture also has a native control.
  - The canvas's VoiceOver label comes from the presenter's description; nothing announces a change (an outcome, a
    rejected move).
  - Reduce Motion and Reduce Flashing: preferences, system observer, settings section, launch hand-off, scene clock
    factor and flash limiter exist and stay as they are.
  - No haptics code exists anywhere; no haptics preference exists. The shell's preferences have schema 1 and decode
    missing fields as defaults.
  - Two `AccessibilityChoice` types exist (pure simulation module and shell model); this feature adds no third.

## Clarifications

### Session 2026-11-13

- Q: In which modules do the arbiter, the planners and the system adapters live, given the existing dependency
  directions? → A: The gesture arbiter goes in VisualCoreScenes next to the recognizers. The announcement and haptic
  planners and the state-sign check are pure and go in VisualCoreSimulation, beside the accessibility preferences,
  where VisualCoreUI can reach them. The players that call the system (feedback generators, accessibility
  announcements) go in VisualCoreUI behind a sink protocol so tests use a fake. The wiring goes in
  VisualCoreExperienceHost and the app. No new module, so no new package rule.
- Q: How does an experience declare which actions its canvas gestures send and which its native controls send? → A:
  Two sets on the presenter: the actions its gestures can send, and the actions its native controls can send. Both
  default to empty, so existing presenters compile unchanged. A shared check reports every gesture action that is
  missing from the native set. A01–A04 declare their sets. Rejected: inferring the sets from view code, which cannot
  be checked statically.
- Q: How do the haptics switch and the announcements reach a game, and where is the switch stored? → A: The shell
  preferences gain an optional `haptics` value (absent means on), with no schema change, because missing fields
  already decode as defaults. The launch hand-off gains `haptics: Bool`. The session's host owns one haptic player
  and one announcer on the main thread, and gives the presenter a handle to plan through. A game never calls UIKit
  directly.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Touches mean one thing at a time (Priority: P1)

A player drags a piece and a second finger lands: the game sees either a drag or a pinch, never both, and the same
touch sequence always gives the same actions.

**Independent Test**: replay recorded touch sequences (one finger, two fingers, a tap that becomes a drag, a cancelled
touch) through the arbiter: each gives one fixed list of actions, the same on every run.

**Acceptance Scenarios**:
1. **Given** one finger moving past the tap distance, **Then** the drag wins and no tap is sent.
2. **Given** a second finger during a drag, **Then** the drag ends (cancelled) and a pinch or rotate begins, by the
   game's declared priority.
3. **Given** a cancelled touch (system interruption, the app goes to the background), **Then** every active gesture
   ends as cancelled and sends no completing action.

---

### User Story 2 - Every gesture has a button (Priority: P1)

A player who cannot perform a gesture (a pinch, a long press) reaches the same result with a native control.

**Independent Test**: a check over an experience's declaration lists every canvas gesture whose actions no native
control can send; a game with such a gap fails its check.

**Acceptance Scenarios**:
1. **Given** a game whose pinch sends `zoom`, **When** it declares a native control that sends `zoom`, **Then** the
   check passes.
2. **Given** a game with a gesture action and no control for it, **Then** the check names the action.

---

### User Story 3 - VoiceOver hears what changes (Priority: P2)

A VoiceOver user hears when a move is rejected, when a level is won or lost, and the current state on request, without
a flood of announcements.

**Independent Test**: feed a sequence of state changes to the announcement planner; it yields the announcements in
order, merges changes within the rate limit, and never announces while the person disabled them.

### User Story 4 - Colour never carries meaning alone (Priority: P2)

A player with colour vision differences reads every state a colour shows through a shape, glyph or text as well.

**Independent Test**: a game's state palette declares for each state its colour and its non-colour sign; the check
fails a state with only a colour, and two states with the same sign.

### User Story 5 - Haptics, when wanted (Priority: P3)

A player feels a short confirmation on a placed piece and a distinct one on a rejected move; a player who turned haptics
off feels nothing.

**Independent Test**: the haptic planner maps game events to feedback kinds, limits their rate, and returns nothing when
the preference is off; a fake player records what would play.

### Edge Cases

- Non-finite or zero view sizes, more fingers than the game supports: rejected before arbitration, nothing sent.
- The app goes to the background or a system gesture takes the touch: every active gesture cancels.
- Many state changes in a short time: announcements and haptics are merged by their rate limit; the last state wins.
- Reduce Motion: animated transitions a game requests become instant; Reduce Flashing: no game rule depends on a flash.
- A stored preference file without the new haptics field decodes with haptics on (default); a damaged file is handled by
  the existing preference recovery.
- Memory pressure: the planners hold only a short queue (bounded), nothing is stored.

## Requirements *(mandatory)*

### Functional Requirements

**Gestures (story 1)**
- **FR-R02F26-001**: A shared arbiter MUST take pointer events and a game's declared gestures with priorities, and send
  at most one active gesture's actions at a time; a gesture that loses MUST end as cancelled.
- **FR-R02F26-002**: The arbiter MUST be deterministic: the same events give the same actions; it MUST reject
  non-finite positions and more pointers than declared.
- **FR-R02F26-003**: A cancelled touch MUST cancel every active gesture without a completing action.

**Alternatives (story 2)**
- **FR-R02F26-010**: An experience MUST declare which of its actions a canvas gesture can send; a check MUST list every
  such action that no native control can send.

**VoiceOver (story 3)**
- **FR-R02F26-020**: A planner MUST turn state changes into announcements (rejected move with its reason, outcome,
  level change) with a rate limit of one announcement per 0.5 seconds (changes within it merge to the newest), and
  none while VoiceOver is off. Announcement texts come from a string catalog, never built from raw identifiers.
- **FR-R02F26-021**: The app MUST post the planned announcements through the system's public accessibility
  announcement, and the canvas label MUST keep mirroring the current state (existing description path).

**Colour (story 4)**
- **FR-R02F26-030**: A game's state palette MUST give every state a colour and a distinct non-colour sign; a check MUST
  fail a state without a sign and two states with the same sign.

**Haptics (story 5)**
- **FR-R02F26-040**: A planner MUST map game events to feedback kinds (selection, success, warning, error, impact
  light/medium/heavy) with a rate limit of one feedback per 0.05 seconds (extra events in that window are dropped), and
  return nothing when haptics are off.
- **FR-R02F26-041**: The app MUST play planned feedback through the system's public feedback generators, outside the
  game's state: haptics never change the state digest.
- **FR-R02F26-042**: Settings MUST offer a haptics switch (default on), stored in the shell preferences as an optional
  field; preferences written before this feature decode with haptics on.

**Motion and flashing**
- **FR-R02F26-050**: The existing Reduce Motion and Reduce Flashing contract MUST be reused: a game receives both choices
  at launch; a game's animated transitions become instant under Reduce Motion; no game rule may depend on a flash.

**Boundaries**
- **FR-R02F26-060**: Public Apple APIs only; no permission prompt; no new stored data beyond the switch; every new public
  declaration documented and in the API baseline; the reference regression after the change.
- **FR-R02F26-061**: The system accessibility audits of this feature run in the device campaign; simulator tests check
  labels, identifiers and 44-point targets.

### Key Entities

- **Gesture declaration**: kind, priority, pointer count, actions it may send.
- **Announcement**: text, kind (rejection, outcome, level, state), time.
- **State sign**: state id, colour, non-colour sign.
- **Haptic event**: event kind, feedback kind, time.

## Success Criteria *(mandatory)*

- **SC-R02F26-001**: 8 of 8 recorded touch sequences give their expected action lists, identical over 3 runs each.
- **SC-R02F26-002**: The alternatives check passes for A01–A04's declarations and fails 1 of 1 planted gap.
- **SC-R02F26-003**: The announcement planner yields the expected list for 5 of 5 sequences and 0 announcements when off.
- **SC-R02F26-004**: The colour check fails 2 of 2 planted defects and passes a valid palette.
- **SC-R02F26-005**: The haptic planner yields the expected kinds for 5 of 5 sequences and 0 when off; a fake player
  receives exactly the planned feedback; the state digest is unchanged by haptics in 1 of 1 test.
- **SC-R02F26-006**: Preferences written before this feature decode with haptics on in 1 of 1 test; the switch keeps
  its value across a relaunch in 1 of 1 interface test.
- **SC-R02F26-007**: The API check shows only added lines; the reference regression passes 7 of 7.

## Assumptions

- The 75 games adopt the contract in their own gates; A01–A04 are not changed beyond what their declarations need for
  the alternatives check.
- Haptic feel and firing are device evidence ({device}); the simulator proves only the plans and the switch.
