# VisualCore Constitution

Scope: the VisualCore monorepo — the VisualCore framework packages and one iPhone and iPad
application, VisualCore, with one shippable app target and modular registered experiences. The 25
original apps (A01–A25) and all round games are experiences of that app, not separate apps. The
Showcase and the harnesses, the ProjectM reference adapter among them, stay non-shipping. Canonical
sources: `Auto-Creator.md` and root `CLAUDE.md`; the original planning documents are archived
byte-identical under `docs/archive/planning/`, and the archived manuals are extracted to
`.autonomy/context/`.

## Core Principles

### I. Proven Renderer Only (NON-NEGOTIABLE)

- All GPU imagery uses OpenGL ES 3.0 through EGL on the owner's ANGLE fork Metal backend
  (`Coastrnaut/angle`, `ios` branch, prebuilt in `External/projectm-ios/Build/ANGLEFrameworks`).
- No second renderer, no direct-Metal replacement, no invented public EGL bridge.
- GL entry points are resolved with `eglGetProcAddress`; `dlopen`/`dlsym` are forbidden.

Rationale: the ANGLE → Metal path is the only renderer with recorded device evidence.

### II. App-Neutral Public API

- VisualCore modules expose render host, frame lifecycle, resources, shaders, effects graph,
  scenes, input, timing, optional audio features, diagnostics and test support.
- ProjectM engine and preset types MUST NOT appear in the VisualCore framework, in the app or in any
  experience; this is verified by package dependency graphs and linked-symbol scans of built
  products.
- `External/projectm-ios` is pinned, independently versioned and read-only. Its gitlink, nested
  pins and third-party sources are never modified silently; engine changes go upstream as logged
  patches through an owner-approved ADR.
- Packages are small, independently testable and acyclic. Boundaries are drawn only where the
  Phase 0 audit of real code supports them (`docs/architecture/reusable-component-inventory.md`).
- **Maximize reuse (owner instruction 2026-11-10):** logic that another experience could use MUST be
  built in a VisualCore module, generalized and app-neutral. Experience modules and the app target keep only
  product composition, content, copy, branding and genuinely one-off rules. Each such VisualCore change MUST
  ship with:
  - package tests and public `///` docs;
  - an API-baseline update;
  - the ProjectM reference regression (II-a).

  The owner's standing instruction is the approval for these upstream changes. Each plan of an app phase,
  or of any other feature that builds an experience, MUST say which VisualCore module owns each component.

### II-a. Preserve the Reference and Prove It

- The existing ProjectM-iOS app and its working renderer are preserved unchanged. Any VisualCore
  reuse of its behavior requires regression evidence: the reference baseline
  (`docs/verification/projectm-baseline.md`) is rerun when a shared seam changes. Because the
  submodule is read-only, "extraction" means re-implementing the audited behavior in VisualCore and
  proving parity, never editing the reference in place.

### III. Explicit GPU Lifecycle and Thread Ownership

- Render hosts follow the state machine
  `uninitialized → surfaceReady → active → suspended → surfaceInvalid → reinitialized → destroyed`.
- GPU handles carry the generation of the context that created them; stale handles are rejected.
- Each EGL context has exactly one owning thread; a Swift actor is not an EGL-thread guarantee.
- Context loss, resize and background transitions MUST be recoverable without crashing.

### IV. Host-Testable Domain Logic, Test-First

- Models, simulations, parsers, graphs, DSP and math live in pure Swift modules tested with
  `swift test` on the Mac host; GPU code is verified on iOS simulators with pixel readback.
- Simulations are deterministic: fixed timestep, explicit seeds, NaN/Infinity guards, bounded
  iteration counts and reference fixtures from independent formulas.

### V. Implementation Before Devices (NON-NEGOTIABLE)

- All 100 launch experiences (50 free: A01–A25 and R02-G01 … R02-G25; 50 premium: R03-G01 …
  R04-G25) are implemented and pass host and iOS Simulator acceptance, and `ImplementationLock-100`
  is recorded by `scripts/migration_ledger.py` from an independent rerun of all 100 on one commit,
  before any physical-device install, launch or test of the unified app or of any other target in
  this repository. `python3 scripts/migration_ledger.py guard-device` MUST pass first.
- A capability that only hardware can prove may be listed as pending hardware verification; core
  gameplay, rendering, persistence and purchase behavior may not.
- After the lock the devices run in this order, 100 experiences each (300 rows): D1 (`iPhone15,4`),
  then D2 (`iPad17,3`), then D3 (`iPad15,7`). D3 stays on iPadOS 26.5 and is never updated. The live
  OS version and build are detected before each campaign; hardware identifiers stay out of tracked
  files.
- After the lock the source changes only through targeted repairs of genuine device defects. A
  repair takes a new lock revision and a rerun of every device row it can affect.
- Historical device observations (other repositories, the standalone apps, older builds) never
  certify the unified build.
- Performance and GPU-lifecycle claims require physical-device evidence, which exists only from the
  device campaign; until then such claims are labelled "untested on device".

Rationale: ADR-0009 D-07 and D-08 (owner directive of 2026-11-11). The lock and the 75 device rows
of the former 25-app plan (`IMPLEMENTATION-LOCK` in the legacy ledger) are superseded and are never
recorded.

### VI. Evidence Over Assertion

- A gate passes only with `run-check` attestations: real command, exit 0, hashed log.
- Tasks are ticked only with `— Verified YYYY-MM-DD: <command/result>`.
- Simulator results are never performance or compatibility evidence; agent reports are not
  evidence. No fabricated waivers; owner-only steps are recorded as `BLOCKED_OWNER_ACTION`.
- Every feature has a specification, plan, tasks and verification produced by the full Spec Kit
  sequence (ADR-0004), and every architecture decision is a dated ADR in `docs/decisions/`.

### VII. Native, Accessible UI

- SwiftUI/UIKit own navigation, controls, help and permissions; the GPU owns imagery only.
- The app and every experience support VoiceOver labels, Dynamic Type, Reduce Motion, Reduce
  Flashing (photosensitivity limiter), non-color state cues and iPhone and iPad layouts.

### VIII. Public Apple APIs, Privacy and Truthful Capabilities

- No private APIs, ReplayKit capture workarounds, invented background modes or fake live
  wallpaper installation.
- Audio uses documented permissions only; realtime callbacks are lock-free and allocation-free;
  captured audio is not retained by default.
- The app has one `PrivacyInfo.xcprivacy`, audited against the built product.
- The app makes no network request of its own. Purchases go through StoreKit, which the system
  mediates. An experience that needs the network needs a new ADR first (ADR-0009 D-15).
- Reviews that need human judgement (distinctiveness, the visual quality of hero scenes,
  five-second goal recognition, outside-player comprehension, manual VoiceOver) are owner reviews.
  They are recorded before release, never gate a ledger gate or a lock, and are never reported as
  performed by an agent. Their automated proxies gate (ADR-0009 D-17).

### IX. Bounded Untrusted Input

- Shader source, node graphs, imported files and effect DAGs are size-, time- and
  memory-limited and cycle-checked.
- Persisted formats are versioned with migrations; writes are atomic and never destroy prior user
  work.

### X. Licensing and Provenance

- Every shader, dataset and asset records its source and license. ANGLE notices ship with every
  app that embeds ANGLE. projectM (LGPL-2.1) linkage is analysed before any distribution.
- Scientific content cites sources, units and uncertainty.

### XI. One App and Stable Experience Identity

- There is exactly one shippable app target and one bundle identifier. The Showcase, the harnesses
  and the standalone targets of A01–A04 are non-shipping development targets; the standalone
  targets are retired once their experiences pass in the unified app, and their bundle identifiers
  are never shipped. No new standalone app target is added.
- Every experience has an immutable code and an immutable id `<code>.<slug>` (the code in lower
  case), defined in `docs/catalog/experience-catalog.json`. Storage namespaces, accessibility
  identifiers, evidence files and ledger gates are derived from them.
- Experiences depend only on the framework and never on each other. An experience collection is one
  package in which each experience has its own independently testable targets (ADR-0009 D-06).
- ProjectM types stay out of the app (Principle II).
- The launch set of 100 experiences is never reduced, merged or substituted, and its queues are
  never reordered. A concept that fails its criteria is redesigned inside its concept, with the
  failed evidence and the redesign recorded in an ADR; if it still fails, its gate is blocked for
  the owner (ADR-0009 D-16).

Rationale: ADR-0009 D-01, D-02, D-06 and D-16 (owner directive of 2026-11-11). Stable ids keep saved
work, evidence and gates attached to an experience for as long as it exists.

### XII. One Purchase and No Advertising (NON-NEGOTIABLE)

- The app is a free download with exactly one in-app product: a non-consumable StoreKit 2 purchase
  at USD 1.99 that unlocks every premium experience, including those added later.
- No advertising of any kind, ever: no ads, ad or tracking SDKs, ad identifiers, rewarded ads,
  subscriptions, consumables, external payment paths, dark patterns or required accounts.
- Entitlement is derived at run time from verified StoreKit 2 transactions. An unverified result
  never unlocks, and no unlock flag is ever stored.
- Premium is gated twice: at routing and at experience activation. A free experience never queries
  the store.
- The test-only entitlement fixture MUST be absent from shipping Release binaries; this is verified
  by symbol and string scans of the built product.

Rationale: ADR-0009 D-03 and D-04 (owner directive of 2026-11-11).

### XIII. Code-Driven Visuals

- All worlds and signature effects are code: GLSL, procedural meshes, signed-distance fields,
  particles and deterministic animation on the existing OpenGL ES → ANGLE → Metal path
  (Principle I).
- No experience requires human-made models, purchased art packs, prompt-generated images or
  external image services. Bundled data keeps its license and provenance (Principle X).

Rationale: ADR-0009 D-09 (owner directive of 2026-11-11). Imagery that is code is generated, tested
and reproduced by the same toolchain that builds the app.

## Technology Constraints

- iOS/iPadOS deployment target 26.0; Swift 6 language mode with strict concurrency.
- XcodeGen 2.46.0 `project.yml` is the project source of truth; generated `.xcodeproj` is
  gitignored. Reusable logic lives in SwiftPM packages under `Packages/`.
- Signing: committed `Configs/Signing.xcconfig` contains only
  `#include? "Signing.local.xcconfig"`; simulator and generic-iOS builds use
  `CODE_SIGNING_ALLOWED=NO`. Teams, certificates and profiles are owner-provisioned.
- Reference toolchain pins live in `Configs/toolchain.json` and are verified, never silently
  upgraded.

## API, Testing, Performance, Documentation and Release Standards

- **API design:** public symbols are documented, `Sendable`-correct and versioned semantically
  per package; anything not needed by a consumer is `internal`. Breaking changes need an ADR and a
  migration note.
- **Testing:** every public API has host or simulator tests; GPU behavior is verified by pixel
  readback; regression of the reference baseline runs whenever a shared seam changes.
- **Performance:** budgets (frame rate floor 30 fps, memory quotas) are specified per feature;
  measurements count only from physical devices with ≥ 200 samples for percentage criteria.
- **Licensing:** third-party notices are bundled with each product; LGPL linkage is analysed
  before distribution; new dependencies need a license review.
- **Documentation:** each package has a README and API reference; `docs/architecture/` stays in
  sync with code (validated by `scripts/validate_docs.py`).
- **Dependencies:** acyclic, pinned, minimal; enforced by dependency and symbol scans.
- **Release:** a release candidate needs all gates green, a privacy/license audit of the built
  product and owner approval; App Store actions remain owner-only.

## Development Workflow

- Spec Kit skills (`.claude/skills/speckit-*`) run inside the Claude Desktop Code session; the
  Claude CLI is never invoked.
- One Spec Kit feature per ledger gate, with the feature numbering and the unique ID namespaces of
  Auto-Creator.md section 19 (foundation phase *k* `FR-Fk##`/`SC-Fk##`/`T-Fk##`; app NN phase P
  `FR-ANN-P##`/`SC-ANN-P##`/`T-ANN-P##`; unified-app feature KK `FR-UKK-###`/`SC-UKK-###`/`T-UKK-###`;
  shared round features and game features in the forms given there), validated by
  `scripts/validate_docs.py` (ADR-0004, ADR-0009 D-11). Every command runs with its supplied prompt
  verbatim, an archived prompt together with its labelled `Canonical override:` note, and every
  feature ends with converge plus its fix loop (`docs/process/speckit-prompt-manifest.json`,
  `docs/catalog/feature-index.json`, `docs/catalog/unified-app-features.json`).
- The legacy ledger `.autonomy/state.json`, written only by `Tools/python/desktop_runbook.py`, keeps
  the foundation and A-phase gates and stays in use, in its order, for the remaining A phases. The
  migration ledger `.autonomy/migration/ledger.json`, written only by `scripts/migration_ledger.py`,
  holds every new gate. A passed gate, a ticked task and sealed evidence are never reset
  (ADR-0009 D-12).
- Work is committed on `main`. Commit after every verified task, skill and fileset change, with LF line
  endings and no co-author or generator trailers. Push to `origin main` (`Coastrnaut/VisualCore`) right
  after each commit, and only after `python3 scripts/prepush_scan.py` passes (owner authorization of
  2026-11-10, owner ruling of 2026-11-11; ADR-0009 D-13). Never force-push, never rewrite history, and
  never push to another remote.
- One writer per repository file; at most 10 concurrent agents; one Xcode/test lane per Mac.

## App-Scoped Rules

Experience rules add to the principles above and never weaken them. Each subsection holds the rules
of one experience, ratified from the constitution prompt of its manual (ADR-0007, ADR-0008); in
these subsections "the app" and "this app" mean the experience named in the heading. A01–A04 were
built as standalone targets under `Apps/<Name>/` with the development bundle id
`dev.visualcore.<Name>`. Those targets are non-shipping harnesses until their experiences pass in
the unified app and are then retired (Principle XI). There is no separate app repository and no
second `projectm-ios` submodule.

### A01 Generative Art Studio (`a01.generative-art-studio`)

Ratified from the app manual's constitution prompt (2026-11-10).

- **Consumer, not fork:** an experience of the VisualCore app and a VisualCore consumer, never a fork of
  projectm-ios. It uses only audited VisualCore public APIs over the OpenGL ES → ANGLE → Metal
  integration. It MUST NOT create its own EGL/ANGLE initialization path or link ProjectM engine code.
- **GPU-free domain:** domain rules and persisted files (documents, parameter schemas, gallery, export
  jobs) MUST be testable without GPU access, through host `swift test`.
- **Offline-first:** no networking. Any permission (such as saving to Photos) is disclosed before use
  and requested only through public APIs.
- **Bounded GPU:**
  - every texture, render target and export size is capped;
  - shader parameters are validated and clamped before upload;
  - context loss rebuilds everything from versioned CPU state.
- **Accessibility:** native SwiftUI controls with VoiceOver labels, Dynamic Type, Reduce Motion and Reduce
  Flashing. The canvas has a spoken description.
- **Licenses and truthful claims:** every bundled asset and shader records its license and author. The
  app makes no unsupported scientific or platform claims.
- **Regression when VisualCore changes:** any VisualCore change made for this app MUST be followed by the
  ProjectM reference regression (`scripts/run_reference_baseline.py` steps and `check_reference_clean.py`).
- **Python only:** repository automation uses Python 3; there is no PowerShell dependency.
- **One phase at a time:** implement only one Spec Kit phase at a time (one ledger gate, ADR-0004), in order
  A01-P00 → A01-P06.

### A02 Fluid Art Playground (`a02.fluid-art-playground`)

Ratified from the app manual's constitution prompt (2026-11-11).

- **Consumer, not fork:** an experience of the VisualCore app and a VisualCore consumer, never a fork of
  projectm-ios. It uses only audited VisualCore public APIs over the OpenGL ES → ANGLE → Metal
  integration. It MUST NOT create its own EGL/ANGLE initialization path, a second renderer, or link
  ProjectM engine code.
- **Isolated solver with a CPU reference:** the fluid solver (advection, divergence, pressure, projection,
  splats) is an experience-domain component, not a new VisualCore renderer. It MUST have a CPU reference
  implementation on tiny grids that the GPU passes are checked against. The model is artistic and is never
  presented as physically accurate.
- **Reuse first (Principle II):** generic machinery the solver needs (ping-pong render targets, feedback
  passes, touch-to-force mapping, quality and thermal policy) goes into VisualCore with tests, docs, the API
  baseline and the reference regression. Only fluid-specific rules, content and UI stay in the experience.
- **GPU-free domain:** domain rules and persisted files (configurations, splat queues, quality profiles,
  saved scenes) MUST be testable without GPU access, through host `swift test`.
- **Offline-first:** no networking. Any permission is disclosed before use and requested only through
  public APIs.
- **Bounded GPU:**
  - grid sizes, pressure iterations, splats per frame and render targets are capped by a quality profile;
  - delta time is clamped after suspension;
  - no pass reads and writes the same texture;
  - context loss rebuilds everything from versioned CPU state.
- **Accessibility:** native SwiftUI controls with VoiceOver labels, Dynamic Type, Reduce Motion and Reduce
  Flashing. The canvas has a spoken description, and every gesture has a control alternative.
- **Licenses and truthful claims:** every bundled asset and shader records its license and author. No
  scientific or physical-accuracy claims.
- **Regression when VisualCore changes:** any VisualCore change made for this app MUST be followed by the
  ProjectM reference regression (`scripts/run_reference_baseline.py` steps and `check_reference_clean.py`).
- **Python only:** repository automation uses Python 3; there is no PowerShell dependency.
- **One phase at a time:** implement only one Spec Kit phase at a time (one ledger gate, ADR-0004), in order
  A02-P00 → A02-P06.

### A03 Fractal Explorer (`a03.fractal-explorer`)

Ratified from the app manual's constitution prompt (2026-11-11).

- **Consumer, not fork:** an experience of the VisualCore app and a VisualCore consumer, never a fork of
  projectm-ios. It uses only audited VisualCore public APIs over the OpenGL ES → ANGLE → Metal
  integration. It MUST NOT create its own EGL/ANGLE initialization path, a second renderer, or link
  ProjectM engine code.
- **Reuse first (Principle II):** generic machinery goes into VisualCore with tests, docs, the API baseline
  and the reference regression. This covers:
  - complex-plane viewports and screen↔plane transforms;
  - precision estimation and limits;
  - palettes and color mapping;
  - pinch/pan camera math;
  - bookmark persistence;
  - offscreen capture.

  Only the fractal formulas, curated content, tours and UI stay in the experience.
- **GPU-free domain:** viewport math, iteration and escape rules (with a CPU reference), the precision
  advisor and persisted bookmarks MUST be testable without GPU access, through host `swift test`.
- **Truthful precision:**
  - zoom is clamped where 32-bit shader precision stops being reliable, and the limit is shown;
  - there is no claim of unlimited deep zoom and no scientific claim beyond verified shader precision;
  - precision limits are measured on real devices before any compatibility claim.
- **Offline-first:** no networking. Any permission (such as saving to Photos) is disclosed before use and
  requested only through public APIs.
- **Bounded GPU:**
  - iteration caps, render-target and capture sizes are capped;
  - a render-cost estimate is shown before expensive work;
  - shader parameters are validated and clamped before upload;
  - context loss rebuilds everything from versioned CPU state.
- **Accessibility:** native SwiftUI controls with VoiceOver labels, Dynamic Type, Reduce Motion (palette
  animation and tours) and Reduce Flashing. The canvas has a spoken description that includes the mode and
  location, and every gesture has a control alternative.
- **Licenses and truthful claims:** every bundled asset, palette and shader records its license and author.
  Mathematical explanations are educational, never presented as research-grade.
- **Regression when VisualCore changes:** any VisualCore change made for this app MUST be followed by the
  ProjectM reference regression (`scripts/run_reference_baseline.py` steps and `check_reference_clean.py`).
- **Python only:** repository automation uses Python 3; there is no PowerShell dependency.
- **One phase at a time:** implement only one Spec Kit phase at a time (one ledger gate, ADR-0004), in order
  A03-P00 → A03-P06.

### A04 Particle Universe (`a04.particle-universe`)

Ratified from the app manual's constitution prompt (2026-11-11).

- **Consumer, not fork:** an experience of the VisualCore app and a VisualCore consumer, never a fork of
  projectm-ios. It uses only audited VisualCore public APIs over the OpenGL ES → ANGLE → Metal
  integration. It MUST NOT create its own EGL/ANGLE initialization path, a second renderer, or link
  ProjectM engine code.
- **Reuse first (Principle II):** generic machinery goes into VisualCore with tests, docs, the API baseline
  and the reference regression. This covers:
  - emitters, forces and fields, and the seeded fixed-step particle simulation;
  - particle buffers and instanced/batched drawing;
  - blending, trails and decay targets;
  - interaction-to-force mapping and quality tiers;
  - scene presets and scene persistence.

  The manual's rule "extract VisualCoreParticles only after a second app needs it" is already met: A01 uses
  VisualCore's `ParticleSystem` and `ParticleRenderer`. Only the curated presets, copy and UI stay in the
  experience.
- **GPU-free domain:** particle and emitter rules, force fields, the fixed-step CPU reference, scene schemas
  and persisted scenes MUST be testable without GPU access, through host `swift test`.
- **Truthful claims:** the simulation is an artistic sandbox, not an exact N-body or physical simulation;
  particle counts and frame rates are claimed only from device measurements.
- **Offline-first:** no networking, accounts or online preset marketplace. Any permission (such as saving to
  Photos) is disclosed before use and requested only through public APIs.
- **Bounded GPU:** particle counts, emitters, trail targets and capture sizes are capped; quality tiers lower
  the load under heat or Low Power Mode; parameters are validated and clamped before upload; context loss
  rebuilds everything from versioned CPU state.
- **Accessibility:** native SwiftUI controls with VoiceOver labels, Dynamic Type, Reduce Motion and Reduce
  Flashing (a reduced-flash mode limits bright pulses and trail flicker). The canvas has a spoken description
  of the scene, and every gesture has a control alternative.
- **Licenses:** every bundled preset, texture, palette and shader records its license and author.
- **Regression when VisualCore changes:** any VisualCore change made for this app MUST be followed by the
  ProjectM reference regression (`scripts/run_reference_baseline.py` steps and `check_reference_clean.py`).
- **Python only:** repository automation uses Python 3; there is no PowerShell dependency.
- **One phase at a time:** implement only one Spec Kit phase at a time (one ledger gate, ADR-0004), in order
  A04-P00 → A04-P06.

### A05 Infinite Geometry (`a05.infinite-geometry`)

Ratified from the app manual's constitution prompt (2026-11-13). Unlike A01–A04, this experience never had a
standalone target: it is built directly as an experience in `Packages/ExperiencesCreative`.

- **Consumer, not fork:** an experience of the VisualCore app and a VisualCore consumer, never a fork of
  projectm-ios. It uses only audited VisualCore public APIs over the OpenGL ES → ANGLE → Metal
  integration. It MUST NOT create its own EGL/ANGLE initialization path, a second renderer, or link
  ProjectM engine code.
- **Reuse first (Principle II):** generic machinery goes into VisualCore with tests, docs, the API baseline
  and the reference regression. This covers:
  - 2D symmetry and tiling transforms (wallpaper and kaleidoscope mappings);
  - procedural meshes, normals, bounds and mesh validation (VisualCore's `Mesh` and the R02-F05 compiler);
  - orbit, pan and zoom cameras with bounds;
  - signed-distance-field shader helpers and depth-tested mesh drawing;
  - presets, still export and quality tiers.

  Only the curated scenes, copy, explanations and UI stay in the experience.
- **GPU-free domain:** geometry transforms, symmetry rules, preset and camera schemas, mesh budgets and persisted
  presets MUST be testable without GPU access, through host `swift test`.
- **Truthful claims:** this is a visual and educational toy, not a CAD tool or an exact geometry solver; a
  stylized (shader-illusion) mode is labelled as such and never presented as exact geometry; performance numbers
  are claimed only from device measurements.
- **Offline-first:** no networking, accounts or online galleries. Any permission (such as saving to Photos) is
  disclosed before use and requested only through public APIs.
- **Bounded GPU:** vertex, index and draw-call budgets, subdivision and recursion depth, symmetry order, camera
  range and capture sizes are capped; quality tiers lower the load under heat or Low Power Mode; parameters are
  validated and clamped before upload; context loss rebuilds everything from versioned CPU state.
- **Accessibility:** native SwiftUI controls with VoiceOver labels, Dynamic Type, Reduce Motion (no automatic
  camera motion or rapid pattern animation) and Reduce Flashing. The canvas has a spoken description of the
  scene, and every gesture (orbit, pan, zoom) has a control alternative.
- **Licenses:** every bundled preset, palette and shader records its license and author; no imported meshes or
  textures.
- **Regression when VisualCore changes:** any VisualCore change made for this experience MUST be followed by the
  ProjectM reference regression (`scripts/run_reference_baseline.py` steps and `check_reference_clean.py`).
- **Python only:** repository automation uses Python 3; there is no PowerShell dependency.
- **One phase at a time:** implement only one Spec Kit phase at a time (one ledger gate, ADR-0004), in order
  A05-P00 → A05-P06.

### A06 VisualCore Music Lab (`a06.visualcore-music-lab`)

Ratified from the app manual's constitution prompt (2026-11-14). Like A05, it never had a standalone target: it is
built directly as an experience of the one app. Its product goal is an audio-reactive visualizer with oscillograms,
spectrum analysis and customizable scenes that is not a ProjectM clone.

- **Consumer, not fork:** an experience of the VisualCore app and a VisualCore consumer, never a fork of
  projectm-ios. It uses only audited VisualCore public APIs over the OpenGL ES → ANGLE → Metal
  integration. It MUST NOT create its own EGL/ANGLE initialization path, a second renderer, or link
  ProjectM engine code; ProjectM's preset formats and visuals are not imitated.
- **Reuse first (Principle II):** generic audio and visual machinery goes into VisualCore with tests, docs, the API
  baseline and the reference regression. This covers:
  - audio capture and file decoding behind one source interface, ring buffers, FFT, band energies, RMS and onset
    detection (the planned `VisualCoreAudio` and `VisualCoreAudioDSP` products);
  - audio-to-parameter mapping with smoothing and bounds;
  - waveform and spectrum drawing primitives, presets, still capture and quality tiers.

  Only the curated scenes, copy and UI stay in the experience.
- **GPU-free and device-free domain:** DSP, mappings, scene schemas and persisted presets MUST be testable without GPU
  access and without a microphone, through host `swift test` with synthetic signals (sines, noise, impulses) and
  committed audio fixtures.
- **Audio privacy:** microphone input is used only after the system permission request with a disclosed usage
  string, and only while the person has chosen live input; the experience MUST also work without the permission
  (bundled demo signals and files the person opens). Audio is analysed on the device only; nothing is recorded to
  disk unless the person saves, and no audio or analysis ever leaves the device.
- **Truthful claims:** an entertainment visualizer, not a measurement instrument; no claims of calibrated levels,
  pitch accuracy, health or hearing effects; latency and performance numbers are claimed only from device
  measurements.
- **Offline-first:** no networking, streaming services, accounts or online galleries.
- **Bounded resources:** audio buffer sizes, FFT sizes, band counts, particle and geometry budgets, capture sizes and
  frame work are capped; quality tiers lower the load under heat or Low Power Mode; the audio thread never blocks on
  rendering and never allocates in its callback; context loss rebuilds everything from versioned CPU state.
- **Accessibility:** native SwiftUI controls with VoiceOver labels, Dynamic Type, Reduce Motion (calmer, slower
  response) and Reduce Flashing (brightness and flash-rate caps on beat-driven effects). The canvas has a spoken
  description, and every gesture has a control alternative.
- **Licenses:** every bundled audio fixture, demo track, preset, palette and shader records its license and author;
  only original or license-cleared audio is bundled.
- **Regression when VisualCore changes:** any VisualCore change made for this experience MUST be followed by the
  ProjectM reference regression (at the experience's X gate per the owner ruling of 2026-11-14).
- **Python only:** repository automation uses Python 3; there is no PowerShell dependency.
- **One phase at a time:** implement only one Spec Kit phase at a time (one ledger gate, ADR-0004), in order
  A06-P00 → A06-P06.

### A07 Audio Odyssey (`a07.audio-odyssey`)

Ratified from the app manual's constitution prompt (2026-11-14). Like A05 and A06, it never had a standalone target:
it is built directly as an experience of the one app. Its product goal is an audio-reactive journey through
procedural tunnels, landscapes and star corridors on a controlled camera rail; it is not a ProjectM clone and not an
open-world game.

- **Consumer, not fork:** an experience of the VisualCore app and a VisualCore consumer, never a fork of
  projectm-ios. It uses only audited VisualCore public APIs over the OpenGL ES → ANGLE → Metal
  integration. It MUST NOT create its own EGL/ANGLE initialization path, a second renderer, or link
  ProjectM engine code; ProjectM's preset formats and visuals are not imitated.
- **Reuse first (Principle II):** the audio sources, ring buffer, FFT, band energies, onset detection, smoothing,
  audio-to-parameter mapping, analysis quality tiers and announcement plumbing that A06 put into `VisualCoreAudio`
  and `VisualCoreAudioDSP` are reused, not copied. New generic machinery (camera rails and easing, procedural tunnel
  and terrain meshes, depth fog, segment streaming with bounded pools) goes into VisualCore with tests, docs, the API
  baseline and the reference regression. Only the curated journeys, copy and UI stay in the experience.
- **GPU-free and device-free domain:** journey state, camera rail maths, segment generation, mappings and persisted
  presets MUST be testable without GPU access and without a microphone, through host `swift test` with synthetic
  signals and fixed seeds; the same seed and input give the same journey.
- **Audio privacy:** microphone input is used only after the system permission request with a disclosed usage
  string, and only while the person has chosen live input; the experience MUST also work without the permission
  (bundled demo signals and files the person opens). Audio is analysed on the device only; nothing is recorded, and
  no audio or analysis ever leaves the device. No system-wide capture of other apps' audio.
- **Comfort:** camera motion is continuous and eased: no hard cuts, sudden accelerations or audio-driven camera
  jolts; audio drives geometry and lighting more than the camera. Speed, sway and roll are capped and the person can
  lower them; Reduce Motion lowers flight speed and removes camera sway and roll, and pause is always one control
  away. Reduce Flashing caps brightness changes and flash rate of beat-driven effects.
- **Truthful claims:** an entertainment visualizer; no claims about relaxation, health, hearing, meditation or
  motion-sickness prevention, and no claims of calibrated levels or pitch accuracy; performance numbers are claimed
  only from device measurements.
- **Offline-first:** no networking, streaming services, accounts or online galleries.
- **Bounded resources:** segment counts, vertex and particle budgets, FFT sizes, draw distance and frame work are
  capped; quality tiers lower the load under heat or Low Power Mode; the audio thread never blocks on rendering and
  never allocates in its callback; context loss rebuilds everything from versioned CPU state.
- **Accessibility:** native SwiftUI controls with VoiceOver labels and Dynamic Type; the canvas has a spoken
  description of the journey and its state, and every gesture has a control alternative.
- **Licenses:** every bundled audio fixture, demo signal, preset, palette and shader records its license and author;
  only original or license-cleared audio is bundled.
- **Regression when VisualCore changes:** any VisualCore change made for this experience MUST be followed by the
  ProjectM reference regression (at the experience's X gate per the owner ruling of 2026-11-14).
- **Python only:** repository automation uses Python 3; there is no PowerShell dependency.
- **One phase at a time:** implement only one Spec Kit phase at a time (one ledger gate, ADR-0004), in order
  A07-P00 → A07-P06.

### A08 Oscilloscope Studio (`a08.oscilloscope-studio`)

Ratified from the app manual's constitution prompt (2026-11-14). Like A05–A07, it never had a standalone target: it
is built directly as an experience of the one app. Its product goal is a responsive, technically legible waveform,
XY (Lissajous) and spectrum display for permitted audio inputs; it is not a certified measuring instrument.

- **Consumer, not fork:** an experience of the VisualCore app and a VisualCore consumer, never a fork of
  projectm-ios. It uses only audited VisualCore public APIs over the OpenGL ES → ANGLE → Metal integration. It MUST
  NOT create its own EGL/ANGLE initialization path, a second renderer, or link ProjectM engine code.
- **Reuse first (Principle II):** the audio sources, permission handling, ring buffer, FFT, windowing, band energies
  and announcement plumbing in `VisualCoreAudio` and `VisualCoreAudioDSP` are reused, not copied. New generic
  machinery (trigger detection, timebase resampling, trace and line building, cursor measurement) goes into VisualCore
  with tests, docs, the API baseline and the reference regression when it is reusable; only the scope's presets, copy
  and UI stay in the experience.
- **GPU-free and device-free domain:** scope settings, trigger and timebase maths, trace building, spectrum
  annotation, cursors, freezes and persisted presets MUST be testable without GPU access and without a microphone,
  through `swift test` with synthetic sine, square and sweep signals; the same input and settings give the same trace.
- **Audio privacy:** microphone input is used only after the system permission request with the disclosed usage
  string, and only while the person has chosen live input; the experience MUST also work without the permission
  (bundled demo generator and files the person opens). Audio is analysed on the device only; nothing is recorded, and
  no audio, frozen trace or analysis leaves the device. No system-wide capture of other apps' audio, and no monitoring
  of the microphone to the speaker that could cause feedback.
- **Truthful claims:** an educational and creative display; no claims of calibrated levels, certified, laboratory or
  medical accuracy, and dB-style annotations are labelled relative (dBFS) unless a calibration exists. Units, clipping
  and the limits of the device's input (sample rate, channel count, latency) are stated where shown; performance
  numbers are claimed only from device measurements.
- **Offline-first:** no networking, streaming services, accounts or online galleries.
- **Bounded resources:** sample windows, FFT sizes, trace vertex counts, history depth and frame work are capped;
  quality tiers lower the load under heat or Low Power Mode; the audio thread never blocks on rendering and never
  allocates in its callback; context loss rebuilds everything from versioned CPU state.
- **Accessibility:** native SwiftUI controls with VoiceOver labels and Dynamic Type; the canvas has a spoken
  description of the mode, settings and measured values, every gesture (zoom, cursors) has a control alternative,
  and Reduce Motion and Reduce Flashing calm the trace's persistence and glow.
- **Licenses:** every bundled audio fixture, demo signal, preset, palette and shader records its license and author;
  only original or license-cleared audio is bundled.
- **Regression when VisualCore changes:** any VisualCore change made for this experience MUST be followed by the
  ProjectM reference regression (at the experience's X gate per the owner ruling of 2026-11-14).
- **Python only:** repository automation uses Python 3; there is no PowerShell dependency.
- **One phase at a time:** implement only one Spec Kit phase at a time (one ledger gate, ADR-0004), in order
  A08-P00 → A08-P06.

### A09 Digital Aquarium (`a09.digital-aquarium`)

Ratified from the app manual's constitution prompt (2026-11-14). Like A05–A08, it never had a standalone target: it
is built directly as an experience of the one app. Its product goal is a calming, customizable underwater habitat
with autonomous fish, plants, bubbles and soft lighting; it is an ambient display, not a realistic ecosystem or
animal-care simulator.

- **Consumer, not fork:** an experience of the VisualCore app and a VisualCore consumer, never a fork of
  projectm-ios. It uses only audited VisualCore public APIs over the OpenGL ES → ANGLE → Metal integration. It MUST
  NOT create its own EGL/ANGLE initialization path, a second renderer, or link ProjectM engine code.
- **Reuse first (Principle II):** scenes, primitives, particles, the seeded simulation clock, persistence and quality
  tiers already in VisualCore are reused, not copied. New generic machinery (bounded steering and neighbour search,
  depth-layered sprite batching, caustic and bubble effects) goes into VisualCore with tests, docs, the API baseline
  and the reference regression when it is reusable; species, habitat content, copy and UI stay in the experience.
- **Visuals are code:** fish, plants, decor, bubbles, caustics and lighting are procedural (shapes, SDFs, shaders and
  particles); no purchased, generated or hand-made artwork, sprites or textures.
- **GPU-free and device-free domain:** the habitat document, species catalog, fish behaviour (fixed-step, seeded),
  feeding and decoration placement and persisted habitats MUST be testable without GPU access through `swift test`;
  the same seed, inputs and steps give the same habitat state.
- **Offline-first and private:** no networking, accounts, online aquariums or purchasable creature economy; no
  permission beyond what a feature actually needs, each disclosed with a demo path when refused.
- **Truthful claims:** an illustrative, calming display; no claims of realistic animal behaviour, animal-care
  guidance, health, relaxation or sleep benefits, and performance or battery numbers only from device measurements.
- **Bounded resources:** fish, plant, bubble and particle counts, neighbour searches, draw batches and frame work are
  capped; quality tiers lower the load under heat, Low Power Mode and the ambient low-motion mode; context loss
  rebuilds everything from versioned CPU state.
- **Accessibility:** native SwiftUI controls with VoiceOver labels and Dynamic Type; the canvas has a spoken
  description of the habitat; every gesture (feed, place, move) has a control alternative; Reduce Motion and Reduce
  Flashing calm motion, shimmer and caustics.
- **Licenses:** every bundled species definition, palette, preset habitat and shader records its author and license;
  only original or license-cleared content is bundled.
- **Regression when VisualCore changes:** any VisualCore change made for this experience MUST be followed by the
  ProjectM reference regression (at the experience's X gate per the owner ruling of 2026-11-14).
- **Python only:** repository automation uses Python 3; there is no PowerShell dependency.
- **One phase at a time:** implement only one Spec Kit phase at a time (one ledger gate, ADR-0004), in order
  A09-P00 → A09-P06.

### A10 Neon Arcade (`a10.neon-arcade`)

Ratified from the app manual's constitution prompt (2026-11-14). Like A05–A09, it never had a standalone target: it
is built directly as an experience of the one app. Its product goal is a compact arcade game with glow, particles and
disciplined game logic — in version 0.1 one complete game, Neon Dodge (a player lane, falling hazards and collectible
orbs) — not a whole arcade collection, online leaderboard or user-generated levels.

- **Consumer, not fork:** an experience of the VisualCore app and a VisualCore consumer, never a fork of
  projectm-ios. It uses only audited VisualCore public APIs over the OpenGL ES → ANGLE → Metal integration. It MUST
  NOT create its own EGL/ANGLE initialization path, a second renderer, or link ProjectM engine code.
- **Reuse first (Principle II):** scenes, primitives, particles, glow and bloom passes, gestures, the seeded
  fixed-step clock, collision helpers, persistence and quality tiers already in VisualCore are reused, not copied.
  New generic machinery (for example broad-phase collision or a game-loop scheduler) goes into VisualCore with tests,
  docs, the API baseline and the reference regression when it is reusable; game rules, content, copy and UI stay in
  the experience.
- **Visuals and sound are code:** player, hazards, orbs, glow, particles and backgrounds are procedural; sounds, if
  any, are synthesized in code; no purchased, generated or hand-made artwork, sprites, textures or recordings.
- **Authoritative, GPU-free rules:** the game loop runs at a fixed step from a seed; collision, scoring, lives,
  waves and difficulty are decided by the domain alone and MUST be testable without GPU access through `swift test`;
  the same seed and inputs give the same outcome, and drawing never changes the game state.
- **Readability over effects:** glow, particles and screen effects never hide hazards, the player or the score; the
  collision shapes the rules use are the shapes the person sees.
- **Offline-first and private:** no networking, accounts, online leaderboards, ads, loot boxes or purchasable
  currency; local scores only; no permission beyond what a feature actually needs.
- **Truthful claims:** no claims of skill, reflex, cognitive or health benefits; performance or battery numbers only
  from device measurements.
- **Bounded resources:** hazards, orbs, particles, draw batches and per-step work are capped; quality tiers lower the
  load under heat and Low Power Mode; context loss rebuilds everything from versioned CPU state; backgrounding pauses
  the game and never fast-forwards it.
- **Accessibility:** native SwiftUI controls with VoiceOver labels and Dynamic Type; the canvas has a spoken
  description of the game state; touch steering has a control alternative with configurable sensitivity; sound and
  haptics have toggles; Reduce Motion and Reduce Flashing calm shake, flashes and glow pulses (no flashing above the
  platform's safe limits).
- **Licenses:** every bundled palette, pattern and shader records its author and license; only original or
  license-cleared content is bundled.
- **Regression when VisualCore changes:** any VisualCore change made for this experience MUST be followed by the
  ProjectM reference regression (at the experience's X gate per the owner ruling of 2026-11-14).
- **Python only:** repository automation uses Python 3; there is no PowerShell dependency.
- **One phase at a time:** implement only one Spec Kit phase at a time (one ledger gate, ADR-0004), in order
  A10-P00 → A10-P06.

### A11 Physics Playground (`a11.physics-playground`)

Ratified from the app manual's constitution prompt (2026-11-15). Like A05–A10, it never had a standalone target: it
is built directly as an experience of the one app. Its product goal is a deterministic 2D sandbox for gravity,
collisions, springs and forces with explanatory overlays — in version 0.1 circles and boxes with rigid-body
collision, constant gravity, springs and drag, spawn/grab/pin/delete gestures, pause, single step, time scale and
reset, presets (pendulum, spring chain, stacked objects) and optional velocity and force overlays with a measured
state panel — not a complete engineering simulation, a 3D soft-body or fluid solver, or a predictive tool.

- **Consumer, not fork:** an experience of the VisualCore app and a VisualCore consumer, never a fork of
  projectm-ios. It uses only audited VisualCore public APIs over the OpenGL ES → ANGLE → Metal integration. It MUST
  NOT create its own EGL/ANGLE initialization path, a second renderer, or link ProjectM engine code.
- **Reuse first (Principle II):** scenes, primitives, gestures, the seeded fixed-step clock and runner, `Collision2D`,
  persistence, quality tiers and accessibility planning already in VisualCore are reused, not copied. New generic
  machinery (for example a broad phase, polygon or box contacts, an impulse solver or spring integration) goes into
  VisualCore with tests, docs, the API baseline and the reference regression when it is reusable; experiment content,
  presets, copy and UI stay in the experience.
- **Visuals are code:** bodies, springs, vectors, panels and backgrounds are procedural; no purchased, generated or
  hand-made artwork, sprites, textures or recordings.
- **Authoritative, GPU-free physics:** the world advances at a fixed step independent of the frame rate; forces,
  collisions, constraints and integration are decided by the domain alone and MUST be testable without GPU access
  through `swift test`; the same document and inputs give the same result, and drawing never changes the state.
- **Stable and bounded:** body, contact and constraint counts, solver iterations, stiffness for the chosen step and
  speeds are capped; non-finite values are rejected; an experiment that would become unstable is clamped or refused,
  never allowed to explode.
- **Offline-first and private:** no networking, accounts, analytics or ads; experiments are stored only on the device;
  no permission beyond what a feature actually needs.
- **Truthful claims:** results are labelled as educational approximations; no claims of physical accuracy, engineering
  or safety prediction, or learning outcomes; performance or battery numbers only from device measurements.
- **Bounded resources:** draw batches and per-step work are capped; quality tiers lower the load under heat and Low
  Power Mode; context loss rebuilds everything from versioned CPU state; backgrounding pauses the simulation and never
  fast-forwards it.
- **Accessibility:** native SwiftUI controls with VoiceOver labels and Dynamic Type; the canvas has a spoken
  description of the experiment; every gesture (spawn, grab, pin, delete, spring) has a control alternative; Reduce
  Motion calms decorative motion without changing the physics.
- **Licenses:** every bundled preset, palette and shader records its author and license; only original or
  license-cleared content is bundled.
- **Regression when VisualCore changes:** any VisualCore change made for this experience MUST be followed by the
  ProjectM reference regression (at the experience's X gate per the owner ruling of 2026-11-14).
- **Python only:** repository automation uses Python 3; there is no PowerShell dependency.
- **One phase at a time:** implement only one Spec Kit phase at a time (one ledger gate, ADR-0004), in order
  A11-P00 → A11-P06.

### A12 Tiny Worlds (`a12.tiny-worlds`)

Ratified from the app manual's constitution prompt (2026-11-15). Like A05–A11, it never had a standalone target: it
is built directly as an experience of the one app. Its product goal is a curated gallery of miniature procedural
worlds explored with an orbit camera and gently customized — in version 0.1 three small world presets (island,
asteroid garden and miniature city), an orbit camera with constrained zoom, seeded terrain and mesh generation with
stable boundaries, prop placement and scene light adjustment, saved world compositions with thumbnails and a
dynamic detail tier within a GPU and memory budget — not infinite terrain or open-world streaming, multiplayer world
creation, photorealistic global illumination or full physics gameplay.

- **Consumer, not fork:** an experience of the VisualCore app and a VisualCore consumer, never a fork of
  projectm-ios. It uses only audited VisualCore public APIs over the OpenGL ES → ANGLE → Metal integration. It MUST
  NOT create its own EGL/ANGLE initialization path, a second renderer, or link ProjectM engine code.
- **Reuse first (Principle II):** scenes, cameras, procedural meshes, lighting, materials, gestures, the seeded
  fixed-step clock and runner, persistence, quality tiers and accessibility planning already in VisualCore are
  reused, not copied. New generic machinery (for example an orbit camera with constrained zoom, seeded terrain
  generation or mesh level-of-detail budgeting) goes into VisualCore with tests, docs, the API baseline and the
  reference regression when it is reusable; world presets, props, copy and UI stay in the experience.
- **Visuals are code:** terrain, props, skies, water and lighting are procedural meshes, SDFs and shaders; no
  purchased, generated or hand-made models, textures, sprites or recordings.
- **Deterministic, GPU-free worlds:** a world document (preset, seed, placed props, light settings) generates the
  same terrain and composition every time; generation, placement rules, camera limits and persisted files MUST be
  testable without GPU access through `swift test`, and drawing never changes the document.
- **Bounded:** terrain resolution, prop count, vertex and draw budgets and thumbnail size are capped; the detail
  tier lowers mesh density under the GPU and memory budget, heat and Low Power Mode; non-finite values and documents
  beyond the caps are refused, never allowed to grow without limit.
- **Offline-first and private:** no networking, accounts, analytics or ads; worlds and thumbnails are stored only on
  the device; no permission beyond what a feature actually needs, each disclosed.
- **Truthful claims:** no claims of scientific, geographic or platform accuracy; performance, memory or battery
  numbers only from device measurements.
- **Resilient GPU state:** context loss rebuilds every mesh and texture from versioned CPU state; backgrounding
  pauses animation and never fast-forwards it.
- **Accessibility:** native SwiftUI controls with VoiceOver labels and Dynamic Type; the canvas has a spoken
  description of the world and the camera; every gesture (orbit, zoom, place, select) has a control alternative;
  Reduce Motion calms ambient animation and camera easing.
- **Licenses:** every bundled preset, prop, palette and shader records its author and license; only original or
  license-cleared content is bundled.
- **Regression when VisualCore changes:** any VisualCore change made for this experience MUST be followed by the
  ProjectM reference regression (at the experience's X gate per the owner ruling of 2026-11-14).
- **Python only:** repository automation uses Python 3; there is no PowerShell dependency.
- **One phase at a time:** implement only one Spec Kit phase at a time (one ledger gate, ADR-0004), in order
  A12-P00 → A12-P06.

### A13 Light Maze (`a13.light-maze`)

Ratified from the app manual's constitution prompt (2026-11-15). Like A05–A12, it never had a standalone target: it
is built directly as an experience of the one app. Its product goal is a tactile light-reflection puzzle with clear
beams and deterministic rules — in version 0.1 at least 20 handcrafted levels with emitter, wall, mirror, target and
optional prism tiles; drag and rotate interactions snapped to the puzzle grid; deterministic beam propagation with
reflection and a finite bounce cap; level select, unlock progression, undo and restart with success feedback; glow and
colour cues that never hide the beam's path; and a built-in solvability check for level data — not photorealistic
optics with refraction physics, unvalidated user-generated level sharing or endless procedural level generation.

- **Consumer, not fork:** an experience of the VisualCore app and a VisualCore consumer, never a fork of
  projectm-ios. It uses only audited VisualCore public APIs over the OpenGL ES → ANGLE → Metal integration. It MUST
  NOT create its own EGL/ANGLE initialization path, a second renderer, or link ProjectM engine code.
- **Reuse first (Principle II):** geometry, ray and segment intersection, transforms, render targets, shaders,
  compositing, gestures, the seeded fixed-step clock and runner, persistence, quality tiers and accessibility planning
  already in VisualCore are reused, not copied. New generic machinery (for example 2D ray casting against segments
  with reflection, or a grid puzzle board model) goes into VisualCore with tests, docs, the API baseline and the
  reference regression when it is reusable; levels, tiles, copy and UI stay in the experience.
- **Visuals are code:** beams, glow, tiles and backgrounds are procedural geometry, SDFs and shaders; no purchased,
  generated or hand-made sprites, textures or recordings.
- **Deterministic, GPU-free rules:** a level document and its moves determine the beam path and the solved state
  exactly; propagation, snapping, progression, the solvability check and persisted files MUST be testable without GPU
  access through `swift test`, and drawing never changes the game state.
- **Bounded:** board size, tile count, beam segments and the bounce cap are fixed limits; glow passes, render targets
  and draw budgets are capped per quality level; non-finite values and documents beyond the caps are refused.
- **Offline-first and private:** no networking, accounts, analytics or ads; progress is stored only on the device; no
  permission beyond what a feature actually needs, each disclosed.
- **Truthful claims:** no claims of physical or scientific optics accuracy or learning outcomes; reflection follows
  the stated grid rule; performance, memory or battery numbers only from device measurements.
- **Resilient GPU state:** context loss rebuilds every render target and texture from versioned CPU state;
  backgrounding pauses animation and never fast-forwards it.
- **Accessibility:** native SwiftUI controls with VoiceOver labels and Dynamic Type; the board has a spoken
  description of the tiles, the beam path and the targets; every gesture (drag, rotate, select) has a control
  alternative; the beam and targets stay legible without glow, colour alone or animation; Reduce Motion and Reduce
  Flashing calm the success feedback.
- **Licenses:** every bundled level, palette and shader records its author and license; only original or
  license-cleared content is bundled.
- **Regression when VisualCore changes:** any VisualCore change made for this experience MUST be followed by the
  ProjectM reference regression (at the experience's X gate per the owner ruling of 2026-11-14).
- **Python only:** repository automation uses Python 3; there is no PowerShell dependency.
- **One phase at a time:** implement only one Spec Kit phase at a time (one ledger gate, ADR-0004), in order
  A13-P00 → A13-P06.

### A14 Solar System Explorer (`a14.solar-system-explorer`)

Ratified from the app manual's constitution prompt (2026-11-15). Like A05–A13, it never had a standalone target: it
is built directly as an experience of the one app. Its product goal is an educational solar system viewer that keeps
astronomical scale, simulated time and visibility-enhanced displays clearly apart — in version 0.1 the Sun and the
eight major planets with curated fact cards; orbit view, planet focus and camera navigation; play, pause and speed-up
of simulated motion with an explicit date and time; separate true-relative and visibility-enhanced size and distance
modes; guided tours with captions; and references and units on every educational claim — not a high-precision
ephemeris or live sky position, telescope alignment, or imagery and data taken without a license.

- **Consumer, not fork:** an experience of the VisualCore app and a VisualCore consumer, never a fork of
  projectm-ios. It uses only audited VisualCore public APIs over the OpenGL ES → ANGLE → Metal integration. It MUST
  NOT create its own EGL/ANGLE initialization path, a second renderer, or link ProjectM engine code.
- **Reuse first (Principle II):** 3D scenes, cameras, meshes, materials and lighting, the seeded fixed-step clock and
  runner, gestures, persistence, quality tiers and accessibility planning already in VisualCore are reused, not
  copied. New generic machinery (for example Kepler orbit propagation or a scaled-time clock) goes into VisualCore
  with tests, docs, the API baseline and the reference regression when it is reusable; bodies, facts, tours, copy and
  UI stay in the experience.
- **Visuals are code:** planet surfaces, rings, the Sun, orbits, labels' backdrops and the starfield are procedural
  geometry, noise and shaders made in code; the manual's licensed textures are replaced by procedural surfaces; no
  purchased, generated or hand-made images, textures or recordings.
- **Data with provenance:** every bundled number (orbital elements, radii, periods, distances, facts) records its
  source, epoch, units and license; only openly licensed or public-domain data is bundled, and the record is checked
  by a test.
- **Deterministic, GPU-free rules:** body positions for a given simulated date, the time controls, the scale modes,
  tours and persisted files MUST be testable without GPU access through `swift test`, and drawing never changes the
  simulation state.
- **Bounded:** body count, mesh detail, orbit sample count, time rate and the simulated date range are fixed limits;
  render targets and draw budgets are capped per quality level; non-finite values and documents beyond the caps are
  refused.
- **Offline-first and private:** no networking, accounts, analytics or ads; no live ephemeris download; state is
  stored only on the device; no permission beyond what a feature actually needs, each disclosed.
- **Truthful claims:** positions come from a stated simplified model over a stated date range, never presented as an
  observing or navigation tool; the visibility-enhanced mode is always labelled as not to scale; every educational
  claim shows its units and source; performance, memory or battery numbers only from device measurements.
- **Resilient GPU state:** context loss rebuilds every render target, mesh and texture from versioned CPU state;
  backgrounding pauses simulated time and never fast-forwards it.
- **Accessibility:** native SwiftUI controls with VoiceOver labels and Dynamic Type; the selected body, the simulated
  date, the time rate and the scale mode are spoken; every gesture (orbit, zoom, select) has a control alternative;
  information never depends on colour alone; Reduce Motion calms camera moves and tours.
- **Licenses:** every bundled data set, fact text, palette and shader records its author or source and license.
- **Regression when VisualCore changes:** any VisualCore change made for this experience MUST be followed by the
  ProjectM reference regression (at the experience's X gate per the owner ruling of 2026-11-14).
- **Python only:** repository automation uses Python 3; there is no PowerShell dependency.
- **One phase at a time:** implement only one Spec Kit phase at a time (one ledger gate, ADR-0004), in order
  A14-P00 → A14-P06.

### A15 Molecular Explorer (`a15.molecular-explorer`)

Ratified from the app manual's constitution prompt (2026-11-15). Like A05–A14, it never had a standalone target: it
is built directly as an experience of the one app. Its product goal is an approachable 3D molecule viewer with clear
atom and bond styling and constrained structured-data import — in version 0.1 a curated small-molecule library with
source attributions; ball-and-stick and space-filling display modes; orbit, pan, zoom and atom picking; element
labels, bond types and a metadata panel; a small XYZ file import with strict bounds and parser errors; and locally
kept recent molecules and visual settings — not medicinal chemistry, predictive molecular dynamics, trusted arbitrary
PDB or complex input, or chemical safety or therapeutic claims.

- **Consumer, not fork:** an experience of the VisualCore app and a VisualCore consumer, never a fork of
  projectm-ios. It uses only audited VisualCore public APIs over the OpenGL ES → ANGLE → Metal integration. It MUST
  NOT create its own EGL/ANGLE initialization path, a second renderer, or link ProjectM engine code.
- **Reuse first (Principle II):** 3D scenes, cameras, meshes (spheres, cylinders), instanced or batched drawing,
  materials and lighting, ray picking, gestures, persistence, quality tiers and accessibility planning already in
  VisualCore are reused, not copied. New generic machinery (for example a ray–sphere or ray–capsule picker, or a
  bounded text-record parser) goes into VisualCore with tests, docs, the API baseline and the reference regression
  when it is reusable; elements, molecules, bond rules, copy and UI stay in the experience.
- **Visuals are code:** atoms, bonds, labels' backdrops, highlights and backgrounds are procedural geometry and
  shaders made in code; no purchased, generated or hand-made images, textures, models or recordings.
- **Data with provenance:** every bundled element property (symbol, name, atomic number, covalent and van der Waals
  radius, display colour) and every curated molecule's coordinates record their source, units (ångström) and
  license; only openly licensed or public-domain data is bundled, and the record is checked by a test.
- **Strict, bounded import:** XYZ input is parsed by a pure parser with fixed limits (file size, atom count, line
  length, coordinate magnitude); unknown elements, non-finite or malformed values and documents beyond the caps are
  refused with a typed reason and change nothing; imported files are never executed or trusted beyond their text.
  Inferred bonds are marked as inferred, never presented as measured.
- **Deterministic, GPU-free rules:** parsing, bond inference, picking geometry, display modes, the library and
  persisted files MUST be testable without GPU access through `swift test`, and drawing never changes the state.
- **Bounded:** atom and bond counts, mesh detail, the recent list and import size are fixed limits; render targets
  and draw budgets are capped per quality level.
- **Offline-first and private:** no networking, accounts, analytics or ads; no download of molecule databases; state
  and imported molecules are stored only on the device; a file is read only when the person chooses it with the
  system document picker; no permission beyond what a feature actually needs, each disclosed.
- **Truthful claims:** structures are illustrative models from stated sources; radii and colours are display
  conventions with their source; no chemical safety, toxicity, medical or therapeutic claim; performance, memory or
  battery numbers only from device measurements.
- **Resilient GPU state:** context loss rebuilds every mesh, buffer and render target from versioned CPU state.
- **Accessibility:** native SwiftUI controls with VoiceOver labels and Dynamic Type; the molecule, the selected atom
  with its element and the display mode are spoken; every gesture (orbit, pan, zoom, pick) has a control
  alternative, including stepping through atoms; information never depends on colour alone (element symbols are
  shown and spoken); Reduce Motion calms camera moves.
- **Licenses:** every bundled data set, fact text, palette and shader records its author or source and license.
- **Regression when VisualCore changes:** any VisualCore change made for this experience MUST be followed by the
  ProjectM reference regression (at the experience's X gate per the owner ruling of 2026-11-14).
- **Python only:** repository automation uses Python 3; there is no PowerShell dependency.
- **One phase at a time:** implement only one Spec Kit phase at a time (one ledger gate, ADR-0004), in order
  A15-P00 → A15-P06.

### A16 Simulation Lab (`a16.simulation-lab`)

Ratified from the app manual's constitution prompt (2026-11-16). Like A05–A15, it never had a standalone target: it
is built directly as an experience of the one app. Its product goal is a gallery of inspectable simulations with
parameter panels and explicit numerical and educational limitations — in version 0.1 three simulation families
(cellular automata, reaction-diffusion and a 2D wave field); a clear parameter schema per experiment with seeded
starting conditions; pause, reset, single step, speed and a histogram or legend overlay; a deterministic tiny CPU
reference for each algorithm; a GPU ping-pong path with explicit boundary rules; and saved presets and still capture —
not a numerically certified scientific solver, large high-precision computation or multi-user experiments.

- **Consumer, not fork:** an experience of the VisualCore app and a VisualCore consumer, never a fork of
  projectm-ios. It uses only audited VisualCore public APIs over the OpenGL ES → ANGLE → Metal integration. It MUST
  NOT create its own EGL/ANGLE initialization path, a second renderer, or link ProjectM engine code.
- **Reuse first (Principle II):** offscreen targets, framebuffer feedback, fullscreen passes, shader compilation,
  quality tiers, capture, persistence and accessibility planning already in VisualCore are reused, not copied. New
  generic machinery (for example a ping-pong render-target pair or a float-texture capability probe) goes into
  VisualCore with tests, docs, the API baseline and the reference regression when it is reusable; the rules of each
  simulation, presets, copy and UI stay in the experience.
- **Visuals are code:** fields, colour ramps, overlays and backgrounds are shaders and procedural drawing made in
  code; no purchased, generated or hand-made images, textures or recordings.
- **Deterministic CPU truth:** every algorithm has a pure, seeded CPU reference on a tiny grid with stated boundary
  rules (wrap, clamp or fixed), testable through `swift test` without GPU access; the GPU path is compared with it
  within a documented tolerance on a tiny grid, and drawing never changes the state.
- **Validity safeguards:** parameters have stated ranges; time steps beyond the stability limit, non-finite values
  and invalid states are refused or clamped with a visible explanation and never corrupt the field; a resize or
  context loss rebuilds the targets from versioned CPU state without carrying corrupted values.
- **Resource separation:** a pass never reads the texture it writes; ping-pong pairs are explicit and asserted.
- **Bounded:** grid sizes, steps per frame, render targets, presets and capture sizes are fixed limits per quality
  level; float-texture support is probed and an available fallback is used or the family is disabled with a message.
- **Offline-first and private:** no networking, accounts, analytics or ads; presets and captures are stored only on
  the device or saved by the person through a system sheet; no permission beyond what a feature actually needs, each
  disclosed.
- **Truthful claims:** simulations are labelled as educational approximations with their method and limits; no
  claim of scientific accuracy, prediction or certification; performance, memory or battery numbers only from device
  measurements.
- **Accessibility:** native SwiftUI controls with VoiceOver labels and Dynamic Type; the experiment, its state
  (running, paused, step count) and parameter values are spoken; every gesture (seeding, painting) has a control
  alternative; information never depends on colour alone (legend values are shown and spoken); Reduce Motion and
  Reduce Flashing slow or pause rapidly changing fields.
- **Licenses:** every preset, palette, fact text and shader records its author or source and license.
- **Regression when VisualCore changes:** any VisualCore change made for this experience MUST be followed by the
  ProjectM reference regression (at the experience's X gate per the owner ruling of 2026-11-14).
- **Python only:** repository automation uses Python 3; there is no PowerShell dependency.
- **One phase at a time:** implement only one Spec Kit phase at a time (one ledger gate, ADR-0004), in order
  A16-P00 → A16-P06.

### A17 Interactive Anatomy (`a17.interactive-anatomy`)

Ratified from the app manual's constitution prompt (2026-11-16). Like A05–A16, it never had a standalone target: it
is built directly as an experience of the one app. Its product goal is a labelled, layer-controlled 3D reference of one
anatomy region with plain-language descriptions. Version 0.1 covers:
- one region, not the full body;
- toggleable layered structure groups and an accessible structure list;
- selection highlighting, labels and searchable metadata;
- camera orbit and zoom with isolate and ghost controls;
- factual text with citations and provenance;
- download-free offline content.

It is not diagnostic or treatment advice, a full-body atlas, or a viewer for patient files.

- **Consumer, not fork:** an experience of the VisualCore app and a VisualCore consumer, never a fork of
  projectm-ios. It uses only audited VisualCore public APIs over the OpenGL ES → ANGLE → Metal integration. It MUST
  NOT create its own EGL/ANGLE initialization path or a second renderer, or link ProjectM engine code.
- **Reuse first (Principle II):** meshes, materials, lighting, the orbit camera, picking, labels and overlays, quality
  tiers, persistence and accessibility planning already in VisualCore are reused, not copied. New generic machinery
  goes into VisualCore with tests, docs, the API baseline and the reference regression when it is reusable. The
  anatomy content, its structure graph, copy and UI stay in the experience.
- **Visuals are code:** every structure is procedural geometry built in code (parametric primitives, sweeps, lathes,
  SDF-derived meshes), labelled as a schematic model. No purchased, generated, scanned or hand-modelled meshes,
  textures or images. The shapes approximate the region's structures for orientation and are never presented as
  anatomically exact.
- **Testable without the GPU:** the structure graph (ids, names, systems, layers, parents, neighbours), search,
  selection, visibility, isolate and ghost state and the persisted files are pure, versioned models, tested through
  `swift test`. Drawing never changes the state.
- **Content provenance:** every name, description and fact carries its source and license, from public-domain or
  openly licensed references (for example Gray's Anatomy, 20th edition, 1918, public domain, and the Terminologia
  Anatomica names). A clinical or expert review of the text is a person's action. It stays recorded as an owner
  action until it is done, and until then the text is labelled as not reviewed by a clinician.
- **Educational, not medical:** the experience shows and speaks that it is an educational schematic. It makes no
  diagnostic, treatment, accuracy or certification claim, and never asks for or reads personal health data or
  patient files.
- **Bounded:** triangle, structure, label and draw-call counts are fixed limits per quality level. Search results,
  saved views and stored files have caps.
- **Offline-first and private:** no networking, accounts, analytics or ads, and all content is bundled. No
  permission beyond what a feature actually needs, and each one is disclosed.
- **Truthful claims:** performance, memory or battery numbers come only from device measurements. Copy promises only
  what the experience does.
- **Accessibility:** native SwiftUI controls with VoiceOver labels and Dynamic Type. The structure list is the control
  alternative to tapping the model. The selected structure, its system, its visibility and the camera's view are
  spoken. Information never depends on colour alone: layers and selection carry names. Reduce Motion replaces
  animated camera moves with cuts.
- **Licenses:** every content text, palette and shader records its source and license.

### A18 Ambient Clock (`a18.ambient-clock`)

Ratified from the app manual's constitution prompt (2026-11-16). Like A05–A17, it never had a standalone target: it
is built directly as an experience of the one app. Its product goal is a readable bedside or desk clock over a
procedural ambient visual. Version 0.1 covers:
- accurate, locale-aware time and date from the system calendar and time zone;
- four procedural visual themes with quality and motion controls;
- readable 12/24-hour typography with optional seconds;
- a theme editor with saveable favourites;
- a brightness-friendly night mode and a motion-reduction option;
- correct updates after returning to the foreground and after time-zone and daylight-saving changes.

It is not an alarm, a timer, a weather display or a guaranteed always-on screen.

- **Consumer, not fork:** an experience of the VisualCore app and a VisualCore consumer, never a fork of
  projectm-ios. It uses only audited VisualCore public APIs over the OpenGL ES → ANGLE → Metal integration. It MUST
  NOT create its own EGL/ANGLE initialization path or a second renderer, or link ProjectM engine code.
- **Reuse first (Principle II):** shaders, fields, palettes, parameters, quality tiers, persistence, text overlays
  and accessibility planning already in VisualCore are reused, not copied. New generic machinery goes into VisualCore
  with tests, docs, the API baseline and the reference regression when it is reusable. The clock's themes, layouts
  and copy stay in the experience.
- **Time is the system's:** the shown time and date come only from the system clock, calendar, locale and time zone.
  The production path has no simulated or offset clock. For determinism, the current date enters the experience as
  an injected value or an action, so tests and scenario replays use fixed dates. Time-zone, daylight-saving, locale
  and foreground changes update the display at once.
- **Visuals are code:** every theme is procedural (shaders, fields, particles, SDFs), with no purchased, generated or
  photographic image. Typography uses system fonts.
- **Testable without the GPU:** formatting (12/24 hours, seconds, locale), theme and favourite documents, night-mode
  and motion rules and the update schedule are pure, versioned models, tested through `swift test`. Drawing never
  changes the state.
- **Screen care:** a slow, bounded pixel drift and dimming protect OLED screens over long sessions. The experience
  never promises to keep the screen on; it may ask the system to stay awake only while it is visible, and says so.
- **Bounded:** frame cost, particle and shader budgets are fixed per quality level, and night mode lowers the frame
  rate and the brightness. Stored favourites have a cap.
- **Offline-first and private:** no networking, location, weather, accounts, analytics or ads. No permission
  beyond what a feature actually needs, and each one is disclosed.
- **Truthful claims:** performance, battery or thermal numbers come only from device measurements. Copy never
  claims more accuracy than the system clock gives.
- **Accessibility:** native SwiftUI controls with VoiceOver labels and Dynamic Type. The time is always spoken in
  full, and contrast stays readable in night mode. Information never depends on colour alone. Reduce Motion stills
  the animated themes.
- **Licenses:** every theme, palette and shader records its source and license.

### A19 Living Wallpapers (`a19.living-wallpapers`)

Ratified from the app manual's constitution prompt (2026-11-17). Like A05–A18, it never had a standalone target: it
is built directly as an experience of the one app. Its product goal is a creator of procedural backgrounds that the
person exports as correctly sized still images (and, only once proven feasible, short videos) and then applies
through the system's own controls. Version 0.1 covers:
- curated procedural backgrounds with colour presets;
- iPhone and iPad canvas templates with crop and safe-area guides;
- still-image export in common formats with a verified colour profile;
- an optional short video export, only after encoder and resource feasibility is shown;
- export progress, cancellation, error recovery and a local history;
- clear instructions for applying an exported image by hand.

It never sets the system wallpaper itself, never calls an export a live wallpaper, and does not render without limit
(no unlimited 8K output).

- **Consumer, not fork:** an experience of the VisualCore app and a VisualCore consumer, never a fork of
  projectm-ios. It uses only audited VisualCore public APIs over the OpenGL ES → ANGLE → Metal integration. It MUST
  NOT create its own EGL/ANGLE initialization path or a second renderer, or link ProjectM engine code.
- **Reuse first (Principle II):** shaders, palettes, parameters, quality tiers, render targets, persistence and
  accessibility planning already in VisualCore are reused, not copied. Offscreen rendering at output resolution,
  pixel read-back and encoding that other experiences can use go into VisualCore with tests, docs, the API baseline
  and the reference regression. The scenes, templates and copy stay in the experience.
- **Platform truth:** only public Apple APIs. An exported file is applied by the person through the system's own
  wallpaper controls, and the experience says so. Photos access is limited to what saving needs and is asked for only
  when the person saves there; export to Files goes through the system document or share interface and needs no
  Photos permission.
- **Visuals are code:** every background is procedural (shaders, fields, SDFs, particles), with no purchased,
  generated or photographic image. Typography uses system fonts.
- **Testable without the GPU:** the project document, canvas templates, crop and safe-area geometry, export
  requests and results, colour-profile choices and history are pure, versioned models tested through `swift test`.
  The same project renders the same picture at the same size; drawing never changes the state.
- **Bounded:** the output size is checked against the GPU's maximum texture size and a memory budget before any
  allocation; larger sizes use a documented tiled strategy or are refused with a clear fallback. Export never blocks
  the interface, can be cancelled, and leaves no orphan GPU resource or temporary file. The history has a cap.
- **Offline-first and private:** no networking, accounts, analytics or ads. Nothing leaves the device except a file
  the person chooses to save or hand to another app. Every permission is disclosed.
- **Truthful claims:** dimensions, file sizes and colour profiles stated in the interface are those of the written
  file. Performance, memory or thermal numbers come only from device measurements.
- **Accessibility:** native SwiftUI controls with VoiceOver labels and Dynamic Type. Export progress and results are
  announced. Information never depends on colour alone. Reduce Motion stills the animated preview.
- **Licenses:** every scene, palette and shader records its source and license.

## Governance

- Precedence: real Apple platform and toolchain behavior and observed test results → owner
  directives (ADR-0009, `Auto-Creator.md` and `CLAUDE.md`) → this constitution and the other ADRs →
  the planning archive (`docs/archive/planning/`) → generated code.
- Amendments use semantic versioning (MAJOR: principle removal/redefinition; MINOR: new or
  materially expanded principle/section; PATCH: clarification) with a dated rationale in
  `docs/decisions/`.
- Owner-only decisions (signing, App Store Connect, purchases, remote publication, D3's OS) cannot
  be amended or waived by an agent.
- Every gate review checks compliance with Principles I–XIII (including II-a); `scripts/check_compliance.py`
  enforces the mechanically checkable rules. The checks that Principles XI–XIII add arrive with the
  unified-app features of Auto-Creator.md section 20 and gate from then on.
- Amendment 2.0.0 (2026-11-11, MAJOR): the scope and Principle V are redefined and Principles XI–XIII are
  added to adopt ADR-0009 (owner directive of 2026-11-11). The dated rationale is
  `docs/decisions/ADR-0010-constitution-2-0-0.md`.
- Amendment 2.1.0 (2026-11-13, MINOR): App-Scoped Rules gain the A05 Infinite Geometry subsection, ratified from
  its manual's constitution prompt at gate A05-P00 (feature 039; ADR-0007, ADR-0008); no principle changes.
- Amendment 2.2.0 (2026-11-14, MINOR): App-Scoped Rules gain the A06 VisualCore Music Lab subsection, ratified
  from its manual's constitution prompt at gate A06-P00 (feature 046); no principle changes.
- Amendment 2.3.0 (2026-11-14, MINOR): App-Scoped Rules gain the A07 Audio Odyssey subsection, ratified from its
  manual's constitution prompt at gate A07-P00 (feature 053); no principle changes.
- Amendment 2.4.0 (2026-11-14, MINOR): App-Scoped Rules gain the A08 Oscilloscope Studio subsection, ratified from
  its manual's constitution prompt at gate A08-P00 (feature 060); no principle changes.
- Amendment 2.5.0 (2026-11-14, MINOR): App-Scoped Rules gain the A09 Digital Aquarium subsection, ratified from its
  manual's constitution prompt at gate A09-P00 (feature 067); no principle changes.
- Amendment 2.6.0 (2026-11-14, MINOR): App-Scoped Rules gain the A10 Neon Arcade subsection, ratified from its
  manual's constitution prompt at gate A10-P00 (feature 074); no principle changes.
- Amendment 2.7.0 (2026-11-15, MINOR): App-Scoped Rules gain the A11 Physics Playground subsection, ratified
  from its manual's constitution prompt at gate A11-P00 (feature 081); no principle changes.
- Amendment 2.8.0 (2026-11-15, MINOR): App-Scoped Rules gain the A12 Tiny Worlds subsection, ratified from its
  manual's constitution prompt at gate A12-P00 (feature 088); no principle changes.
- Amendment 2.9.0 (2026-11-15, MINOR): App-Scoped Rules gain the A13 Light Maze subsection, ratified from its
  manual's constitution prompt at gate A13-P00 (feature 095); no principle changes.
- Amendment 2.10.0 (2026-11-15, MINOR): App-Scoped Rules gain the A14 Solar System Explorer subsection, ratified
  from its manual's constitution prompt at gate A14-P00 (feature 102); no principle changes.
- Amendment 2.11.0 (2026-11-15, MINOR): App-Scoped Rules gain the A15 Molecular Explorer subsection, ratified
  from its manual's constitution prompt at gate A15-P00 (feature 109); no principle changes.
- Amendment 2.12.0 (2026-11-16, MINOR): App-Scoped Rules gain the A16 Simulation Lab subsection, ratified from
  its manual's constitution prompt at gate A16-P00 (feature 116); no principle changes.
- Amendment 2.13.0 (2026-11-16, MINOR): App-Scoped Rules gain the A17 Interactive Anatomy subsection, ratified
  from its manual's constitution prompt at gate A17-P00 (feature 123); no principle changes.
- Amendment 2.14.0 (2026-11-16, MINOR): App-Scoped Rules gain the A18 Ambient Clock subsection, ratified from its
  manual's constitution prompt at gate A18-P00 (feature 130); no principle changes.
- Amendment 2.15.0 (2026-11-17, MINOR): App-Scoped Rules gain the A19 Living Wallpapers subsection, ratified from
  its manual's constitution prompt at gate A19-P00 (feature 137); no principle changes.

**Version**: 2.15.0 | **Ratified**: 2026-11-10 | **Last Amended**: 2026-11-17
