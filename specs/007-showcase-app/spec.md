# Feature Specification: Phase 6 — Standalone VisualCore Showcase Application

**Feature Branch**: `007-showcase-app` (spec directory only; work stays on `main`)

**Created**: 2026-11-10

**Status**: Draft

**Ledger gate**: F06 · ID namespace FR-F6##, SC-F6##, T-F6##

**Input**: User description: archived `sources/README.md` §10.8 Phase 6 prompt (verbatim in the invocation),
plus the canonical override: the app lives under `Showcase/{App,Resources,Shaders,Tests}` with a README, uses a
native accessible SwiftUI UI, shows live lifecycle/context-loss diagnostics, ships a repeatable smoke test, and
defers device measurements to campaign II (constitution V). Scene list from README Phase 6.

## User Scenarios & Testing *(mandatory)*

Users: developers evaluating or adopting VisualCore (including the authors of the 25 apps), reviewers checking
that the framework is independent of ProjectM, and people exploring the scenes on an iPhone or iPad.

### User Story 1 - Browse and run real scenes (Priority: P1) 🎯

A person opens the Showcase, sees a list of scenes with short descriptions, opens one and sees it render and
animate; they can go back and open another.

**Independent Test**: A UI smoke test opens every scene in turn and confirms frames are being presented and the
scene's own status reports success.

**Acceptance Scenarios**:

1. **Given** the app launches, **When** the scene list appears, **Then** it lists at least five scenes: shader gradient and texture sample, animated geometry, touch-interactive distortion, particle system, multi-pass post-processing.
2. **Given** a scene is opened, **When** one second passes, **Then** the presented-frame count has increased and the scene reports no error.
3. **Given** a scene is open, **When** the person returns to the list and opens another, **Then** the first scene's GPU resources are released (no leaks reported).

---

### User Story 2 - Shader loading and post-processing (Priority: P1)

A developer sees shaders loaded from the app's bundled shader files (with includes) and at least one multi-pass
post-processing effect applied to a scene, and can switch the effect on and off.

**Independent Test**: The texture scene samples a bundled texture; the post-processing scene runs a graph of at
least three passes; a test reads back pixels to confirm each.

**Acceptance Scenarios**:

1. **Given** the shader gradient scene, **When** it renders, **Then** its shaders come from bundled `.glsl` files resolved with an include, and the bundled texture is visible.
2. **Given** the post-processing scene, **When** the effect is toggled off and on, **Then** the output changes and returns, and the active pass list is shown.
3. **Given** a bundled shader fails to compile (fault-injection setting), **When** the scene loads, **Then** a readable error with file and line is shown instead of a crash.

---

### User Story 3 - Touch interaction (Priority: P1)

A person drags on the distortion scene and sees the image ripple under the finger; in the particle scene a drag
spawns particles and a pinch zooms.

**Independent Test**: UI test drags and pinches and reads the scene's diagnostics.

**Acceptance Scenarios**:

1. **Given** the distortion scene, **When** the person drags, **Then** the distortion center follows the finger (reported in diagnostics).
2. **Given** the particle scene, **When** the person drags, **Then** particles appear; **When** they pinch out, **Then** the zoom increases.

---

### User Story 4 - Live diagnostics and context loss (Priority: P2)

A developer opens a diagnostics panel showing frame rate, frame count, lifecycle state, context generation, GPU
resource counts and bytes, warnings and errors, and can trigger a simulated context loss to watch the scene
recover.

**Independent Test**: UI test opens the panel, triggers context loss, and confirms the generation increments,
rendering resumes and no resources leak.

**Acceptance Scenarios**:

1. **Given** any scene, **When** the diagnostics panel is shown, **Then** it displays frame rate, frames, lifecycle state, generation, live resources/bytes and warning count, updated at least twice per second.
2. **Given** a scene, **When** "Simulate context loss" is pressed, **Then** the generation increases by one, frames continue within one second, and leaked resources stay zero.
3. **Given** the app goes to the background and returns, **When** it resumes, **Then** the lifecycle shows suspended then active and rendering continues.

---

### User Story 5 - Proven independence from ProjectM (Priority: P1)

A reviewer runs a build-time dependency audit that proves the Showcase neither compiles against nor links any
ProjectM engine, preset or reference-bridge module, even though ProjectM stays in the repository as a submodule.

**Independent Test**: The audit inspects the project specification, the resolved dependency graph, the source
imports and the built binary; it fails on any ProjectM dependency and passes for the Showcase.

**Acceptance Scenarios**:

1. **Given** the Showcase project, **When** the audit runs, **Then** it reports zero ProjectM targets, packages, imports, linked frameworks and symbols, and exits successfully.
2. **Given** a deliberately contaminated fixture (a ProjectM import or package reference), **When** the audit runs on it, **Then** it fails and names the offending item.

### Edge Cases

- Rendering unavailable (host creation fails): the scene shows an explanatory error instead of a blank screen.
- Bundled shader or texture missing: readable error naming the file.
- Rapid scene switching: resources of the previous scene are released before or when the next starts; no leak.
- Rotation and iPad multitasking resizes: scenes resize without distortion of touch mapping.
- Reduce Motion: animated scenes slow or stop motion and timelines jump to end values; Reduce Flashing (on when Reduce Motion is on, user-toggleable) appends the flash limiter to post-processing.
- VoiceOver: every scene has a spoken description of what it shows and how to interact; controls are labelled.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-F601**: The Showcase MUST be an independently buildable iOS/iPadOS app under `Showcase/` with its own project specification, scheme and tests, depending only on VisualCore packages (no ProjectM engine, preset or reference-bridge modules at compile or run time).
- **FR-F602**: It MUST render through the shared VisualCore render host on the existing ANGLE-backed path.
- **FR-F603**: It MUST provide at least five scenes: (1) shader gradient + texture sample, (2) animated geometry, (3) touch-interactive distortion, (4) particle system, (5) multi-pass post-processing. An audio-reactive scene is out of scope until the audio input layer exists (feature F08 or later apps).
- **FR-F604**: Shaders MUST be loaded from bundled shader files through the VisualCore shader library, including at least one include; compile errors MUST be shown with file and line.
- **FR-F605**: The post-processing scene MUST run an effect graph of at least three passes, toggleable, showing the active pass order.
- **FR-F606**: Scenes MUST respond to touch: distortion follows a drag; particles spawn on drag and the camera zooms on pinch.
- **FR-F607**: A diagnostics panel MUST show frame rate, presented frames, lifecycle state, context generation, live GPU resources and bytes, peak bytes, warnings and the last error, refreshed at least twice per second, and offer "Simulate context loss".
- **FR-F608**: Opening another scene or leaving a scene MUST release its GPU resources (zero leaked after teardown).
- **FR-F609**: The UI MUST be native SwiftUI with VoiceOver labels and hints, Dynamic Type, Reduce Motion and Reduce Flashing support.
- **FR-F610**: A build-time dependency audit MUST verify the Showcase does not link or import ProjectM engine targets (project spec, package graph, source imports, built binary symbols and frameworks) and MUST fail on a contaminated fixture.
- **FR-F611**: A repeatable smoke test MUST open every scene, verify frames advance with no error, exercise touch and context loss, and run on iOS 27.2 and 26.5 simulators.
- **FR-F612**: The Showcase MUST include a README describing scenes, how to build, run the smoke test and the audit.

### Key Entities

- **ShowcaseScene descriptor**: id, title, summary, accessibility description, interaction hint, factory.
- **Diagnostics snapshot**: fps, frames, lifecycle state, generation, live resources/bytes, peak bytes, warnings, last error.
- **Audit report**: checked items (spec, graph, imports, binary) with findings and pass/fail.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-F601**: The smoke test opens 100% of the scenes (≥ 5) and each presents new frames within 2 seconds with no reported error, on both iOS 27.2 and 26.5 simulators.
- **SC-F602**: The dependency audit reports 0 ProjectM items for the Showcase and detects 100% of contaminated fixtures (import, package reference, linked framework, symbol).
- **SC-F603**: After visiting every scene and a simulated context loss, leaked GPU resources are 0.
- **SC-F604**: Every scene and control has a VoiceOver label; the scene list stays usable at the largest accessibility text size.
- **SC-F605**: Simulated context loss recovers with the generation incremented and frames resuming within 1 second.

## Assumptions

- Simulator runs are functional evidence only; frame rate, thermal and memory on D1–D3 belong to campaign II (constitution V).
- The Showcase is a developer showcase, not an App Store product in this phase; bundle id and branding are placeholders until the owner approves (CLAUDE.md §8).
- The texture is a small, original, generated asset committed with the app (no third-party license).
