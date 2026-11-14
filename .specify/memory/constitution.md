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

**Version**: 2.1.0 | **Ratified**: 2026-11-10 | **Last Amended**: 2026-11-13
