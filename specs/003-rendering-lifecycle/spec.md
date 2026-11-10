# Feature Specification: Phase 2 — Rendering Lifecycle Extraction

**Feature Branch**: `003-rendering-lifecycle` (spec directory only; work stays on `main`)

**Created**: 2026-11-10

**Status**: Draft

**Ledger gate**: F02 · ID namespace FR-F2##, SC-F2##, T-F2##

**Input**: User description: archived `sources/README.md` §10.4 Phase 2 prompt (verbatim in the
invocation), with the canonical override: the reference renderer stays unchanged. The VisualCore
host re-implements the audited EGL sequence per `specs/002-architecture-contracts/contracts/render-lifecycle.md`,
parity is shown by simulator pixel tests, and the reference baseline renderer tests rerun as the
regression. ProjectM call-site migration is done by the F07 harness.

## Clarifications

### Session 2026-11-10

Answered autonomously under the owner's standing approval (CLAUDE.md §2), recommended option chosen.

- Q: Who suspends rendering when the app goes to the background? → A: The host does it itself. It observes the app entering the background (suspend, after finishing pending GPU work) and returning to the foreground (resume), because iOS forbids GPU work in the background. Apps can additionally pause and resume explicitly (e.g. a user pause); an app-requested pause survives a foreground return.
- Q: When is the context recreated outside tests? → A: On explicit request (API, test hook) and automatically when EGL reports a lost context after a swap or make-current; both go through `reinitialized`.
- Q: What happens when window-surface creation keeps failing? → A: The host stays `surfaceInvalid` and retries on each layout. After 3 consecutive failures it reports an `allocation` error to observers once, then keeps retrying silently on later layouts.
- Q: What happens when a scene's setup throws? → A: The host records the error and reports it to observers. It stays alive and presents a clear (black) frame instead of the scene until a later recreation or scene replacement succeeds; it never crashes.
- Q: Apply the `/speckit-analyze` remediation (E1 surface-failure test hook, A1 version-string check)? → A: Yes, applied 2026-11-10 (no critical findings).
- Q: Can several hosts exist at once, and who owns the EGL display? → A: Yes. Each host owns its own unshared context and surfaces; all of them live on the main thread. The ANGLE Metal display is process-wide, initialized once and never terminated, exactly as in the reference (which never calls `eglTerminate`), because terminating it would invalidate other hosts' contexts.

## User Scenarios & Testing *(mandatory)*

Users: app developers adding a GPU view to any of the 25 apps or the Showcase.

### User Story 1 - Render a minimal scene through the proven renderer (Priority: P1) 🎯

A developer creates a render host, places its view in a window, supplies a scene that clears to a
color and draws a gradient quad, and sees exactly those pixels, rendered by the same ANGLE → Metal
path the reference uses.

**Why this priority**: The F02 exit evidence is an independent minimal scene rendering on a simulator.

**Independent Test**: A simulator test reads back pixels after one frame and compares them with
the expected colors within ±2 per channel.

**Acceptance Scenarios**:

1. **Given** a new host, **When** its view joins a window with a non-zero size, **Then** the state
   becomes *active* and the presented frame shows the scene's clear color.
2. **Given** a scene drawing a horizontal red-to-blue gradient, **When** a frame renders, **Then**
   the leftmost column is red-dominant and the rightmost blue-dominant.
3. **Given** the host is created, **When** capabilities are read, **Then** they report an OpenGL ES
   3.x version string from ANGLE, a renderer string, the extension list and the max texture size.

---

### User Story 2 - Survive resize, background and recreation (Priority: P1)

The developer's scene keeps rendering correctly when the view resizes or rotates, when the app goes
to the background and returns, and when the GPU context is recreated.

**Independent Test**: Simulator tests resize the view, suspend and resume, and force 100
recreations, checking the state history, generation counter and pixels after each.

**Acceptance Scenarios**:

1. **Given** an active host, **When** the view size changes, **Then** the drawing surface is
   rebuilt at the new pixel size and the scene is told the new size.
2. **Given** an active host, **When** suspended, **Then** no frames are drawn until resumed.
3. **Given** an active host, **When** the context is recreated, **Then** the generation increases
   by one, the scene's setup runs again and the next frame renders correctly.
4. **Given** a zero-size view, **When** layout happens, **Then** the host is *surfaceInvalid* and
   recovers on the next valid size without crashing.

---

### User Story 3 - Predictable lifecycle, threading and pacing (Priority: P2)

The developer can observe every lifecycle transition, rely on all rendering happening on the main
thread, and get frame pacing that respects thermal pressure and Low Power Mode.

**Independent Test**: Host unit tests of the state machine's allowed and rejected transitions;
simulator tests of observer callbacks and pacing decisions computed from given thermal/power inputs.

**Acceptance Scenarios**:

1. **Given** the lifecycle model, **When** a transition outside the contract is requested, **Then**
   it is rejected and counted, and the state is unchanged.
2. **Given** thermal state *serious*, **When** pacing is computed, **Then** the frame cap is 30 fps;
   at *critical* the render scale is 0.75.

### Edge Cases

- No ES3-capable configuration or missing GL entry points: creation fails with an `unsupported`
  error; nothing crashes.
- Window-surface creation fails: *surfaceInvalid*, retried on each layout; one `allocation` error after 3 failures.
- Scene setup throws: error reported, black frame presented, host alive.
- Two hosts at once (e.g. Showcase thumbnails): independent contexts, shared display, no interference.
- The view leaves the window: frame scheduling stops; it restarts when the view returns.
- Very long frame (debugger, background): delta clamped to 0.1 s.
- Destroy while suspended: teardown runs in contract order and leaves zero live GL objects that the
  host created.
- Physical-device frame pacing and thermal behavior: not claimed here (campaign II).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-F201**: The host MUST create the display on ANGLE's Metal platform, choose an RGBA8 ES 3.0
  window+pbuffer configuration, create an ES 3.0 context and a 1×1 placeholder surface, and create
  the window surface on the view's Metal layer (BGRA8). This is the audited reference sequence,
  using only the owner's prebuilt ANGLE frameworks.
- **FR-F202**: GL entry points MUST be resolved through ANGLE's EGL proc lookup into the generated
  table, and creation MUST fail with `unsupported` if any ES 3.0 entry point is missing.
- **FR-F203**: The host MUST implement the lifecycle states, transitions, observers, bounded history
  and generation counter of the lifecycle contract; illegal transitions are rejected and counted.
- **FR-F204**: All EGL/GL work of the visible context MUST run on the main thread, checked in debug builds.
- **FR-F205**: The window surface MUST be recreated whenever the drawable pixel size changes, and the
  scene MUST be notified of the new size.
- **FR-F206**: Frames MUST be scheduled by a display link that starts when the view joins a window and
  stops when it leaves, with the contract's frame-rate caps (default 60, 30 under serious/critical
  thermal state or Low Power Mode, render scale 0.75 at critical) and delta clamped to 0.1 s.
- **FR-F207**: Suspend and resume MUST pause and restart frame production without losing the surface. The host suspends itself when the app enters the background (after `glFinish`) and resumes on foreground unless the app requested a pause.
- **FR-F208**: Context recreation (on request, or automatically when EGL reports a lost context) MUST
  destroy and recreate the context, increment the generation, re-run scene setup and continue rendering.
- **FR-F214**: Window-surface creation failures MUST keep the host in `surfaceInvalid` with a retry on
  each layout, reporting one `allocation` error after 3 consecutive failures.
- **FR-F215**: A scene whose setup or render throws MUST NOT crash the host; the error is reported and a
  black frame is presented until a later recreation or scene replacement succeeds.
- **FR-F216**: The EGL display MUST be process-wide, initialized once and never terminated; multiple
  hosts may coexist, each with its own unshared context on the main thread.
- **FR-F209**: Teardown MUST follow the contract order and leave no host-created surfaces or contexts.
- **FR-F210**: The host MUST report capabilities: GL version, renderer, vendor, shading-language
  version, extension list, max texture size, max viewport dimensions.
- **FR-F211**: The host MUST offer one-frame rendering on demand and pixel readback of the presented
  frame (RGBA) for tests.
- **FR-F212**: A minimal, independent sample scene (clear plus gradient quad) MUST ship with the
  package tests and render on iOS 27.2 and iOS 26.5 simulators.
- **FR-F213**: The reference baseline renderer tests MUST be rerun after this feature and still pass
  (regression for the shared ANGLE seam).

### Key Entities

- **RenderHost**: lifecycle, generation, capabilities, surfaces, scheduler, scene.
- **RenderScene** (protocol): setup, resize, render, teardown.
- **RenderContext**: current generation, pixel size, GL access for the scene during callbacks.
- **FrameInfo**: index, time, clamped delta, target timestamp.
- **RenderCapabilities**: version strings, extensions, limits.
- **FramePacing**: cap, render scale, derived from thermal state and Low Power Mode.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-F201**: The minimal scene's pixels match expected colors within ±2/255 per channel on both
  simulator runtimes.
- **SC-F202**: 100 consecutive forced recreations finish with the generation at 101, zero crashes,
  and a correct frame after the last one.
- **SC-F203**: 100% of the transition table (all 49 state pairs) is covered by host unit tests.
- **SC-F204**: A developer integrates a working view with a custom scene in under 30 lines of app code.
- **SC-F205**: The reference baseline renderer tests still pass 13/13 on both runtimes after the feature.
- **SC-F206**: The package builds for simulator and generic iOS with zero ProjectM symbols (checker R1).

## Assumptions

- Prebuilt ANGLE frameworks at pin 29d1823 (verified by the Phase 0 audit).
- Simulator results are functional only; pacing and thermal behavior on hardware is validated in campaign II.
- Contracts from feature 002 are binding; differences need an ADR.
