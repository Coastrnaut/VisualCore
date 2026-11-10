# Feature Specification: VisualCore Foundation

**Feature Branch**: `001-visualcore-foundation` (directory only; work stays on `main`)
**Created**: 2026-11-10
**Status**: Draft
**Ledger gates**: F02–F09 (F00 audit and F01 governance precede this spec)
**ID namespace**: FR-F###, SC-F###, T-F###, R-F##
**Input**: Reusable app-neutral VisualCore framework around the owner's existing ANGLE → Metal
OpenGL ES path, plus Showcase, ProjectM reference adapter and a second independent consumer.
Sources: README §1, §4.1, §5.2, §7; archived `sources/README.md` §5–§7 Phases 2–9;
`docs/architecture/F00-reference-audit.md`.

## Clarifications

### Session 2026-11-10 (answered under the owner's delegated implementation intent; recommended option chosen)

- Q: Wrap the reference `ANGLERenderer` or re-implement its EGL sequence? → A: Re-implement the
  identical audited sequence in an app-neutral host (same frameworks, platform attributes, config,
  surface strategy); the reference renderer embeds ProjectM types and the submodule is read-only.
  Recorded in ADR-0002.
- Q: Which thread owns EGL? → A: The main thread (as in the reference); a dedicated render thread is
  deferred until device measurements justify it.
- Q: Package shape? → A: `Packages/VisualCore` (pure Swift, host-testable: math, scenes, effects
  graph model, shader preprocessing, diagnostics, audio DSP) and `Packages/VisualCoreRendering`
  (iOS-only: ANGLE binaries, GL table, host, resources, GPU effects, SwiftUI view, audio engine).
  Recorded in ADR-0003.
- Q: How do apps and the Showcase get Xcode targets? → A: One root XcodeGen `project.yml` with one
  target per app; the ProjectM reference harness has its own `Harnesses/ProjectMReference.yml` so its
  LGPL engine never enters the suite project.
- Q: Max frame rate default? → A: 60 fps; apps may opt in to ProMotion rates; 30 fps floor under
  thermal/Low Power pressure.

## User Scenarios & Testing *(mandatory)*

Primary users are the developers of the 25 suite apps (framework consumers); secondary users
are people who run the Showcase and second-consumer apps.

### User Story 1 - Render a GPU scene with the proven renderer (Priority: P1)

An app developer adds VisualCore to an app target, drops a render view into native UI, supplies
a small scene, and sees GPU imagery drawn through the same ANGLE → Metal path that ProjectM-iOS
already proved, without touching EGL directly.

**Why this priority**: Every one of the 25 apps depends on it; nothing else can be verified first.

**Independent Test**: A simulator test hosts the render view, draws a known solid color and a
gradient, reads pixels back and compares them with expected values.

**Acceptance Scenarios**:

1. **Given** a fresh app, **When** the render view joins a window, **Then** the host reaches the
   *active* state and the first frame is presented with the expected pixel colors.
2. **Given** an active host, **When** the view is resized or rotated, **Then** the drawing surface
   is recreated at the new pixel size and rendering continues without error.
3. **Given** an active host, **When** the app moves to the background and returns, **Then** the
   host suspends (no frames drawn) and resumes, and a forced context recreation rebuilds all
   app resources (new generation) without a crash.
4. **Given** a device in serious thermal state or Low Power Mode, **When** frames are scheduled,
   **Then** the frame-rate cap drops to 30 fps and never below.

---

### User Story 2 - Build reusable resources, shaders and multi-pass effects (Priority: P1)

A developer loads shader sources, gets readable compile errors with correct line numbers, creates
textures/framebuffers within a memory budget, and chains effect passes (blur, bloom, color,
distortion, composite, feedback) as a validated graph.

**Why this priority**: 20+ apps need shaders and post-processing; unbounded graphs are a safety risk.

**Independent Test**: Host tests validate graphs (ordering, cycles, quotas) and shader source
preprocessing; simulator tests compile real shaders and run a three-pass graph with pixel checks.

**Acceptance Scenarios**:

1. **Given** a shader with a syntax error on line 12 of an included snippet, **When** it is
   compiled, **Then** the diagnostic names the original file and line 12.
2. **Given** an effect graph containing a cycle or a missing input, **When** it is validated,
   **Then** it is rejected with a specific error before any GPU work.
3. **Given** a graph whose textures would exceed the app's memory budget, **When** it is built,
   **Then** it is rejected and the previous working graph keeps rendering.
4. **Given** Reduce Flashing is enabled, **When** a scene alternates black and white each frame,
   **Then** the displayed mean luminance changes by no more than the configured limit per second.

---

### User Story 3 - Deterministic interaction, animation and simulation helpers (Priority: P2)

A developer maps touches to scene coordinates, runs fixed-step simulations independent of display
rate, animates values with timelines and easing, uses seeded randomness, 3D math and procedural
meshes, and pools particles — all testable on the Mac host with a fake clock.

**Independent Test**: Host unit tests replay recorded inputs and seeds and compare to fixtures.

**Acceptance Scenarios**:

1. **Given** the same seed and input sequence, **When** a simulation runs twice at different
   display rates, **Then** state after N fixed steps is bit-identical.
2. **Given** a 2-second stall, **When** the fixed-step loop resumes, **Then** at most the
   configured catch-up steps run and the remainder is dropped and reported.
3. **Given** a touch at a view point, **When** mapped, **Then** normalized and pixel coordinates
   match the aspect-correct expectation for portrait and landscape.

---

### User Story 4 - Showcase proves the framework to people (Priority: P2)

A person opens the VisualCore Showcase, browses at least six live scenes (shader gradient,
animated geometry, touch distortion, particles, multi-pass post-processing, diagnostics), changes
parameters with accessible native controls, and sees live lifecycle diagnostics.

**Independent Test**: A simulator UI test opens every scene, checks rendering is non-blank and the
diagnostics counters advance, and toggles Reduce Flashing and context recreation.

**Acceptance Scenarios**:

1. **Given** VoiceOver is on, **When** the scene list is read, **Then** each scene and control has a
   meaningful label and value.
2. **Given** Reduce Motion is on, **When** an animated scene opens, **Then** motion is reduced
   while the scene stays usable.

---

### User Story 5 - Independence proof: ProjectM reference and second consumer (Priority: P3)

The owner's ProjectM engine renders through VisualCore's render host in a reference harness (proving
the seam), while a second non-ProjectM consumer app builds and runs with zero ProjectM symbols. An
optional audio feature bridge offers microphone and in-app playback analysis via public APIs.

**Independent Test**: Dependency-graph and symbol scans of the built Showcase and second consumer
contain no ProjectM symbols; the reference harness builds and renders on simulator; the unmodified
reference package tests still pass.

**Acceptance Scenarios**:

1. **Given** the built Showcase binary, **When** its symbols are scanned, **Then** no ProjectM
   engine or preset symbol is present.
2. **Given** microphone permission is denied, **When** the audio bridge starts, **Then** it reports
   "permission denied" and the visual scene keeps running with silent features.
3. **Given** synthetic audio, **When** features are computed, **Then** spectrum peak, band energies,
   RMS and onsets match reference values within tolerance, with no allocation in the realtime path.

### Edge Cases

- Surface creation fails (zero size, invalid layer): host stays in *surfaceInvalid*, retries on next
  layout, never crashes.
- A resource from an old context generation is used: rejected and counted, never passed to GL.
- Shader source exceeds size limit or never finishes linking: rejected with a diagnostic.
- Effect pass fails at runtime: the graph falls back to passing its input through and reports it.
- Simulation produces NaN/Infinity: the step is rejected and state resets to the last valid snapshot.
- Very long frame (debugger, background): delta time is clamped.
- Audio route change or interruption: analysis pauses and resumes; no stale buffer replay.
- Physical-device-only behavior (real frame pacing, thermal): deferred to campaign II and labeled.

## Requirements *(mandatory)*

### Functional Requirements

**Render host (F02)**

- **FR-F001**: The render host MUST create its display on ANGLE's Metal platform, an RGBA8 ES 3.0
  context, a 1×1 placeholder surface and a window surface bound to the view's Metal layer — the
  sequence audited in F00 — using the owner's prebuilt ANGLE frameworks only.
- **FR-F002**: The host MUST expose the lifecycle states uninitialized, surfaceReady, active,
  suspended, surfaceInvalid, reinitialized, destroyed, with only the documented transitions allowed
  and every transition observable by the app.
- **FR-F003**: Every context creation MUST increment a generation number; GPU handles carry their
  generation and handles from a different generation MUST be rejected.
- **FR-F004**: All rendering calls MUST happen on the host's owning thread (the main thread),
  enforced by checks in debug builds.
- **FR-F005**: The host MUST recreate the window surface whenever the drawable pixel size changes and
  notify the scene of the new size.
- **FR-F006**: The host MUST report capabilities (GL version string, renderer string, extension
  list, max texture size, max viewport) after context creation.
- **FR-F007**: Frame scheduling MUST cap at the display's rate (up to 60 fps by default, opt-in
  higher) and at 30 fps under serious/critical thermal state or Low Power Mode.
- **FR-F008**: The host MUST support forced context recreation (test and recovery path) that rebuilds
  scene resources through a callback.
- **FR-F009**: The host MUST provide synchronous pixel readback of the presented frame for tests.

**Resources and shaders (F03)**

- **FR-F010**: GL entry points MUST be resolved via ANGLE's EGL proc lookup into a function table;
  no dynamic-loader symbol lookup.
- **FR-F011**: Textures, buffers, framebuffers and programs MUST be owned by a resource registry that
  tracks bytes per category, enforces a configurable budget, and reports live counts for leak tests.
- **FR-F012**: Shader sources MUST support named snippet inclusion with a line map so diagnostics
  name the original file and line.
- **FR-F013**: Compile and link errors MUST be returned as structured diagnostics; a failing program
  never replaces a working one.
- **FR-F014**: Programs MUST be cached by source hash per generation.
- **FR-F015**: Uniform writes MUST be validated (name exists, type matches) with errors reported once.
- **FR-F016**: Shader source MUST be rejected above 64 KiB and includes deeper than 8 levels.
- **FR-F017**: The color-space policy MUST be documented: framebuffers store sRGB-encoded 8-bit
  values; effect math that needs linear light converts explicitly.

**Effects (F04)**

- **FR-F018**: Effect graphs MUST declare passes with named inputs/outputs and resolution scale and
  MUST be ordered topologically; cycles, missing inputs, duplicate outputs and unknown pass types
  are rejected.
- **FR-F019**: Graph validation MUST enforce a maximum of 32 passes and a texture-memory quota.
- **FR-F020**: Intermediate targets MUST come from a reusable pool keyed by size and format.
- **FR-F021**: Built-in passes MUST include copy, color transform (matrix + offset, gamma),
  separable Gaussian blur, bloom/glow, displacement distortion, alpha composite and feedback
  (previous-frame blend).
- **FR-F022**: A Reduce-Flashing limiter MUST bound the change in displayed mean luminance per second
  to a configurable limit (default 0.3/s).
- **FR-F023**: A failing pass MUST degrade to pass-through and be reported, without stopping the graph.

**Input, scenes and simulation (F05)**

- **FR-F024**: Input mapping MUST convert view points to normalized device, unit-square and pixel
  coordinates with aspect correction, and track multiple pointers with phases.
- **FR-F025**: A fixed-timestep clock MUST decouple simulation from presentation with clamped frame
  delta, a maximum catch-up step count and an interpolation alpha.
- **FR-F026**: A seeded deterministic RNG MUST produce identical sequences across runs and platforms.
- **FR-F027**: Timelines MUST support keyframes with standard easing curves and looping.
- **FR-F028**: Vector, matrix, quaternion, perspective/orthographic and orbit-camera math MUST be
  provided and tested against reference values.
- **FR-F029**: A pooled particle store MUST reuse slots and never exceed its fixed capacity.
- **FR-F030**: Procedural meshes MUST include grid, sphere and torus with normals and indices.
- **FR-F031**: Simulation helpers MUST detect non-finite values and restore the last valid snapshot.

**Showcase (F06)**

- **FR-F032**: The Showcase MUST present at least six scenes: shader gradient, animated geometry,
  touch distortion, particles, multi-pass post-processing and diagnostics.
- **FR-F033**: All Showcase controls MUST have accessibility labels, support Dynamic Type, and honor
  Reduce Motion and Reduce Flashing.
- **FR-F034**: The Showcase MUST display live diagnostics: lifecycle state, generation, frame count,
  frame-time median/p95, missed refresh slots, resource counts and thermal state.

**Reference adapter and second consumer (F07–F08)**

- **FR-F035**: A ProjectM reference harness MUST render the owner's unmodified engine through the
  VisualCore render host, living outside VisualCore and the 25 app dependency graphs.
- **FR-F036**: The unmodified reference ANGLE rendering package tests MUST be rerun as a regression.
- **FR-F037**: A second consumer app with no ProjectM dependency MUST build and render a distinct
  generative scene using only public VisualCore API.
- **FR-F038**: The optional audio bridge MUST use only documented microphone and in-app playback
  APIs, label system capture unavailable, use an allocation-free lock-free ring, and compute
  spectrum, band energies, RMS and onset features; captured audio is not stored.

**Stabilization (F09)**

- **FR-F039**: A compliance scanner MUST fail on dynamic-loader symbol lookup, private framework
  paths, ReplayKit capture, ProjectM imports outside the reference harness and committed signing
  identifiers.
- **FR-F040**: A symbol-isolation check MUST fail if a built non-reference product contains
  ProjectM symbols, and an automation check MUST fail if a shipping Release binary contains
  automation symbols.
- **FR-F041**: Each app target MUST carry a privacy manifest checked against required-reason API
  usage, plus bundled third-party license notices.
- **FR-F042**: An automation runner skeleton MUST compile only in debug or explicit automation
  builds, run a mode named by the launch environment, write a JSON report and exit.
- **FR-F043**: Public API documentation, package dependency rules and CI workflow definitions MUST
  exist; workflows are not pushed without owner authorization.

### Key Entities

- **RenderHost**: owns display/context/surfaces, lifecycle state, generation, frame scheduler.
- **RenderCapabilities**: version, renderer, extensions, limits.
- **GPUResource handle**: kind, GL name, byte size, owning generation.
- **ResourceBudget**: per-category byte limits and live counters.
- **ShaderSource / ShaderProgram**: named source with includes and line map; compiled program with
  uniform table and diagnostics.
- **EffectGraph / EffectPass**: passes, edges, resolution scale, quotas, validation result.
- **FixedStepClock, SeededRandom, Timeline, Camera, Mesh, ParticlePool**: deterministic helpers.
- **FrameMetrics / DiagnosticsSnapshot**: frame-time distribution, missed slots, thermal state.
- **AudioFeatures**: spectrum, bands, RMS, onset flag, source state.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-F001**: A developer integrates a working render view in under 30 lines of app code.
- **SC-F002**: 100% of pixel-readback rendering tests pass on both the iOS 27.2 and iOS 26.5
  simulators.
- **SC-F003**: 100 consecutive forced context recreations complete with zero leaked resources and
  zero crashes in simulator tests.
- **SC-F004**: 100% of invalid effect graphs in the fixture set (cycles, missing inputs, over-quota,
  over-pass-limit) are rejected before any GPU work.
- **SC-F005**: Deterministic simulations produce identical state for 10,000 steps across two runs
  and two display rates.
- **SC-F006**: Shader diagnostics report the correct source file and line for 100% of fixture errors.
- **SC-F007**: The Showcase exposes ≥6 scenes, each reachable with VoiceOver, and its UI smoke test
  passes on the simulator.
- **SC-F008**: Zero ProjectM symbols in the built Showcase and second-consumer binaries; zero
  automation symbols in shipping Release builds.
- **SC-F009**: Reduce Flashing keeps mean-luminance change ≤ 0.3 per second for a 30 Hz
  black/white strobe fixture.
- **SC-F010**: Audio feature extraction matches reference tones (peak bin within ±1 bin, RMS within
  1%) with zero allocations measured in the processing path on the host.

## Assumptions

- The prebuilt ANGLE XCFrameworks (pin 29d1823, iOS 26.0 minimum) are reused as-is; rebuilding them
  uses the reference's own script only if they become stale.
- Simulator GPU results prove functional correctness only; performance, thermal and real audio
  capture claims wait for the physical-device campaign.
- The main thread is the EGL owning thread, matching the audited reference renderer.
- System/App audio capture is out of scope for the shared bridge (only the original ProjectM
  CaptureLab implements it); apps label it unavailable.
- Deployment target iOS/iPadOS 26.0 so D3 (iPadOS 26.5) is supported.
