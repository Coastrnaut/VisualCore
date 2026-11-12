# VisualCore
## Comprehensive Architecture, Repository, and Spec-Kit Implementation Plan

**Project type:** Reusable iOS graphics framework and reference applications  
**Primary reference implementation:** [`Coastrnaut/projectm-ios`](https://github.com/Coastrnaut/projectm-ios)  
**Repository model:** New VisualCore repository with `projectm-ios` included as a Git submodule  
**AI implementation workflow:** GitHub Spec Kit + Claude Code  
**Primary platform:** iOS / iPadOS  
**Rendering foundation:** Existing ProjectM ANGLE + OpenGL ES + Metal path

---

## 1. Executive summary

VisualCore is a reusable graphics technology foundation for building iOS applications that need real-time GPU rendering, visual effects, generative graphics, audio-reactive visuals, interactive scenes, and potentially lightweight games.

The project will begin in a **new Git repository**. The existing `projectm-ios` repository will be integrated as a Git submodule and treated as the first reference implementation and compatibility benchmark.

This is not a greenfield renderer project. ProjectM iOS already has a working rendering stack based on:

- OpenGL ES application/rendering code;
- ANGLE as the OpenGL ES implementation;
- ANGLE's Metal backend for GPU execution and presentation.

VisualCore must preserve and reuse this proven path. It must not introduce a duplicate ANGLE integration, replace ANGLE, or assume that a second native Metal renderer is required.

The central engineering objective is to extract and formalize **reusable infrastructure around the existing renderer** while keeping ProjectM-specific behavior in ProjectM.

### The intended result

1. A new, independently versioned VisualCore repository.
2. The existing ProjectM iOS repository pinned as a Git submodule.
3. A documented and tested integration boundary between VisualCore and ProjectM.
4. Reusable APIs and modules for rendering lifecycle, resources, shaders, frame scheduling, diagnostics, input, effects, and reusable graphics systems.
5. ProjectM continuing to build and behave as it did before each extraction.
6. A standalone VisualCore showcase application that does not depend on ProjectM's visualization engine.
7. A repeatable Spec-Kit + Claude Code workflow for implementing each phase with traceable specifications, plans, tasks, and verification.

---

## 2. Foundational architecture decisions

These decisions are constraints for every implementation phase.

### 2.1 Preserve the existing ANGLE-to-Metal renderer

The baseline rendering architecture is:

```text
┌────────────────────────────────────────────────────┐
│                    iOS Applications                 │
│                                                    │
│  ProjectM       VisualCore Showcase      Future Apps│
└────────┬────────────────────┬───────────────────────┘
         │                    │
         ▼                    ▼
┌────────────────────────────────────────────────────┐
│                    VisualCore                      │
│                                                    │
│  Public APIs                                       │
│  Render lifecycle / scheduling                     │
│  Resource and shader services                     │
│  Effects / scenes / input / diagnostics            │
│  Reusable application integration                  │
└──────────────────────────┬─────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────┐
│       Existing ANGLE + OpenGL ES Integration       │
│                                                    │
│  EGL context and surface management                │
│  Existing ANGLE configuration and initialization   │
│  OpenGL ES rendering and resource operations       │
│  Existing synchronization and presentation path   │
└──────────────────────────┬─────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────┐
│                  ANGLE Metal Backend               │
│                                                    │
│                Apple Metal / GPU                   │
└────────────────────────────────────────────────────┘
```

This diagram expresses the intended logical ownership. The repository audit must determine which existing ProjectM components can be shared without moving or duplicating third-party code.

**Do not create a new ANGLE adapter/backend merely to make the architecture look modular.** The actual existing implementation is the starting point.

### 2.2 VisualCore is not a ProjectM rewrite

ProjectM is the first reference consumer, not the definition of every VisualCore feature.

Keep the following ProjectM-specific:

- MilkDrop preset loading and interpretation;
- ProjectM engine internals;
- preset-specific state and transitions;
- ProjectM-specific audio analysis and visualization semantics;
- compatibility behavior required by the existing ProjectM application.

Candidate VisualCore responsibilities, subject to repository audit:

- renderer host and lifecycle interfaces;
- EGL context/surface lifecycle services;
- render scheduling and frame timing;
- shared GPU resource abstractions;
- shader asset loading, compilation diagnostics, and caching;
- framebuffer and texture utilities;
- reusable post-processing effects;
- input and gesture translation;
- render diagnostics and performance instrumentation;
- reusable 2D/3D scenes, particles, animation, and procedural graphics;
- common asset and configuration support.

### 2.3 Extract only proven boundaries

Every extraction must answer:

1. Is the component genuinely reusable by a second app?
2. Does it have a stable API boundary?
3. Can it be tested independently?
4. Can ProjectM consume it without changing visible behavior?
5. Does extracting it reduce duplication or improve maintainability?
6. Is the dependency direction correct?

If the answer is unclear, document the candidate and defer extraction.

### 2.4 Avoid an unnecessary second renderer

VisualCore's initial rendering API should use the existing OpenGL ES path through ANGLE. Native Metal APIs may be considered later for a concrete use case that cannot be handled appropriately by the existing stack. They are not a prerequisite for VisualCore v1.

### 2.5 Keep the submodule authoritative

The ProjectM repository remains its own Git repository. VisualCore references a specific ProjectM commit through the submodule gitlink.

Do not copy ProjectM source files into VisualCore. Do not commit changes to ProjectM as if they were VisualCore-owned files. Changes intended for ProjectM should be committed and reviewed in the submodule repository, then the VisualCore superproject should update its pinned submodule commit.

---

## 3. Repository strategy

### 3.1 New repository

Suggested repository name:

```text
VisualCore
```

Suggested local layout:

```text
VisualCore/
├── .claude/
│   ├── agents/
│   ├── rules/
│   └── skills/
├── .github/
│   └── workflows/
├── .specify/
│   ├── memory/
│   └── templates/
├── Apps/
│   └── VisualCoreShowcase/
├── Packages/
│   ├── VisualCore/
│   ├── VisualCoreRendering/
│   ├── VisualCoreResources/
│   ├── VisualCoreShaders/
│   ├── VisualCoreEffects/
│   ├── VisualCoreInput/
│   ├── VisualCoreDiagnostics/
│   └── VisualCoreTestSupport/
├── External/
│   └── projectm-ios/          # Git submodule
├── Examples/
├── Tests/
├── Tools/
│   └── python/
├── docs/
│   ├── architecture/
│   ├── decisions/
│   ├── development/
│   └── verification/
├── specs/
├── scripts/
├── .gitmodules
├── CLAUDE.md
├── LICENSE
├── README.md
└── project.yml                # Add only if/when XcodeGen is selected
```

This is a target organization, not a requirement to create every directory or package immediately. Phase 0 must inspect the submodule and choose package boundaries based on actual code.

### 3.2 Add ProjectM as a submodule

From the new VisualCore repository root:

```bash
git submodule add https://github.com/Coastrnaut/projectm-ios.git External/projectm-ios
git submodule update --init --recursive
git status
```

Commit the submodule registration:

```bash
git add .gitmodules External/projectm-ios
git commit -m "chore: add projectm-ios reference submodule"
```

Clone the VisualCore repository on another machine:

```bash
git clone --recurse-submodules https://github.com/<OWNER>/VisualCore.git
cd VisualCore
```

If the repository has already been cloned without submodules:

```bash
git submodule update --init --recursive
```

Inspect the pinned submodule revision:

```bash
git submodule status
git -C External/projectm-ios status
git -C External/projectm-ios log -1 --oneline
```

### 3.3 Submodule update policy

Do not automatically track the latest ProjectM branch in production builds. Pin a known commit and update deliberately.

To fetch and inspect upstream changes:

```bash
git -C External/projectm-ios fetch origin
git -C External/projectm-ios log --oneline HEAD..origin/main
```

Review the upstream changes, test compatibility, then update the submodule pointer:

```bash
git -C External/projectm-ios checkout <REVIEWED_COMMIT>
git add External/projectm-ios
git commit -m "chore: update projectm-ios reference"
```

Use the actual upstream default branch if it is not `main`.

If ProjectM needs a change, work inside the submodule:

```bash
cd External/projectm-ios
git switch -c <projectm-change-branch>
# Make and test the ProjectM change.
git add .
git commit -m "feat: <description>"
git push -u origin <projectm-change-branch>
```

Then return to VisualCore and commit the updated submodule pointer after the ProjectM change has been reviewed/merged according to the chosen workflow.

### 3.4 Submodule rules for Claude Code

Add these rules to `CLAUDE.md`:

- Treat `External/projectm-ios` as an independently versioned repository.
- Never run destructive Git commands in the submodule.
- Never change the submodule commit without explicitly reporting it.
- Never silently vendor or duplicate ProjectM source.
- Before editing a submodule file, state why the change belongs in ProjectM rather than VisualCore.
- Preserve upstream remotes, branches, tags, license files, and notices.
- Record the tested submodule commit in verification reports.
- Do not run `git submodule update --remote` as an unattended implementation step.

---

## 4. Initial technology and platform assumptions

The audit phase must verify these assumptions before implementation.

| Area | Initial direction |
|---|---|
| Platform | iOS and iPadOS |
| Language | Swift for public app-facing APIs; existing C/C++/Objective-C++ where the renderer requires it |
| GPU path | Existing OpenGL ES through ANGLE, with ANGLE's Metal backend |
| Shader language | Existing GLSL/OpenGL ES shader conventions |
| Build | Preserve the existing ProjectM build system and Xcode project generation approach |
| Dependency integration | Preserve existing dependency pins and submodules |
| Tests | Swift tests plus native C/C++ tests where applicable |
| Automation | Python scripts for repository audits and deterministic validation |
| CI | macOS runners with supported Xcode versions |
| Hardware verification | Physical iOS devices for performance, lifecycle, and GPU behavior |

Do not change the ProjectM deployment target, ANGLE revision, compiler settings, or build system simply to align with a proposed VisualCore convention. First document the existing configuration and its rationale.

---

## 5. Proposed package responsibilities

Package boundaries are provisional. The audit and first architecture decision records must confirm or revise them.

### 5.1 `VisualCore`

Top-level public API and application integration layer.

Potential responsibilities:

- framework configuration;
- renderer creation and lifecycle;
- shared public types;
- capability reporting;
- application-facing service composition.

Must not contain ProjectM preset or MilkDrop logic.

### 5.2 `VisualCoreRendering`

Reusable rendering integration around the existing ANGLE implementation.

Potential responsibilities:

- render host abstractions;
- renderer lifecycle;
- EGL context and surface coordination;
- render-thread ownership;
- frame scheduling;
- resize and orientation handling;
- synchronization contracts;
- presentation lifecycle.

This package must reuse the existing ANGLE integration. It must not become a second ANGLE implementation.

### 5.3 `VisualCoreResources`

Shared GPU resource utilities.

Potential responsibilities:

- texture and buffer lifecycle helpers;
- framebuffer utilities;
- resource ownership and cleanup;
- resource cache policies;
- context-loss or renderer-recreation handling, where applicable;
- resource diagnostics.

### 5.4 `VisualCoreShaders`

Shader asset and program services.

Potential responsibilities:

- shader source organization;
- shader loading;
- include/preprocessing strategy if supported by the current shader toolchain;
- compile and link diagnostics;
- shader variants;
- optional cache;
- shader validation scripts.

Do not change existing ProjectM shader semantics as part of a generic shader service extraction.

### 5.5 `VisualCoreEffects`

Reusable graphics effects.

Potential responsibilities:

- post-processing passes;
- blur and glow;
- color transforms;
- distortion;
- compositing;
- reusable framebuffer pipelines.

Effects must be implemented as independent, composable units and verified on supported devices.

### 5.6 `VisualCoreInput`

Input and interaction translation.

Potential responsibilities:

- touch and gesture abstractions;
- coordinate conversion;
- pointer state;
- interaction routing;
- input lifecycle.

### 5.7 `VisualCoreDiagnostics`

Runtime observability.

Potential responsibilities:

- frame timing;
- GPU/CPU timing where measurable;
- render-thread diagnostics;
- resource counts;
- shader failures;
- lifecycle events;
- debug overlays and structured logs.

Avoid claiming GPU timing precision unless the actual platform APIs provide it.

### 5.8 `VisualCoreTestSupport`

Test fixtures, mock services, deterministic test helpers, and reusable test assets. It must not become a runtime dependency of production applications.

---

## 6. Dependency direction

The intended dependency direction is:

```text
VisualCoreShowcase ───────┐
                         ├──> VisualCore public APIs
ProjectM integration ─────┘             │
                                        ▼
                         VisualCore feature packages
                                        │
                                        ▼
                       Existing ANGLE/EGL integration
                                        │
                                        ▼
                               Metal backend
```

Rules:

- VisualCore packages must not depend on ProjectM engine modules.
- ProjectM may depend on VisualCore packages through a clearly documented integration layer.
- The showcase app must not import ProjectM engine or preset modules.
- Shared packages must not import app targets.
- Avoid cyclic package dependencies.
- Keep third-party ANGLE source and ownership with the existing dependency integration unless the audit proves a specific, justified change is required.

---

## 7. Multi-phase implementation roadmap

Each phase is a separate Spec-Kit feature with its own `spec.md`, `plan.md`, `tasks.md`, and verification evidence. Do not ask Claude to implement the entire roadmap in one unbounded run.

### Phase 0 — Repository integration and baseline audit

**Goal:** Establish the new repository, add the ProjectM submodule, and document the actual implementation before changing production code.

Tasks:

1. Create the VisualCore Git repository.
2. Add `projectm-ios` as `External/projectm-ios`.
3. Initialize and verify submodules.
4. Inventory all source targets, packages, build files, scripts, tests, and CI workflows.
5. Trace the app startup path into renderer initialization.
6. Trace EGL context and surface creation.
7. Trace OpenGL ES calls into ANGLE.
8. Confirm ANGLE's Metal backend configuration and presentation path.
9. Map render loop, synchronization, resize, orientation, and teardown.
10. Inventory shaders, textures, framebuffers, and GPU resources.
11. Identify ProjectM-only code and reusable candidates.
12. Build and run the unmodified ProjectM app using its documented workflow.
13. Record baseline frame timing and known behavior where measurable.
14. Record the exact submodule commit used for the baseline.

Deliverables:

```text
docs/architecture/repository-audit.md
docs/architecture/current-rendering-pipeline.md
docs/architecture/reusable-component-inventory.md
docs/architecture/visualcore-gap-analysis.md
docs/verification/projectm-baseline.md
```

**Exit gate:** ProjectM builds at the pinned submodule commit. The current rendering path is documented with real paths, symbols, targets, and dependency versions. No production source has been changed.

### Phase 1 — Architecture constitution and integration contracts

**Goal:** Define VisualCore principles and the boundaries between the new repository and ProjectM.

Tasks:

- Define public API stability policy.
- Define package ownership.
- Define lifecycle and threading contracts.
- Define resource ownership and cleanup contracts.
- Define error reporting and diagnostics.
- Define shader asset conventions.
- Define test strategy.
- Define submodule change policy.
- Record architectural decisions.

Deliverables:

```text
.specify/memory/constitution.md
docs/architecture/visualcore-architecture.md
docs/architecture/package-boundaries.md
docs/decisions/ADR-0001-rendering-foundation.md
docs/decisions/ADR-0002-projectm-submodule.md
docs/decisions/ADR-0003-package-boundaries.md
```

**Exit gate:** No unresolved ownership ambiguity between VisualCore and ProjectM.

### Phase 2 — Extract shared rendering lifecycle

**Goal:** Create the first reusable integration layer around the existing ANGLE/EGL path without changing renderer behavior.

Candidate work:

- renderer lifecycle interfaces;
- render host integration;
- context/surface coordination;
- render-thread rules;
- frame scheduling;
- resize and orientation;
- teardown and recreation;
- error propagation and logging.

Implementation rules:

- Move or wrap only components proven reusable by Phase 0.
- Preserve the current ProjectM rendering sequence.
- Keep ANGLE version and configuration unchanged.
- Avoid introducing an alternate renderer backend.
- Add compatibility tests around existing ProjectM behavior.

**Exit gate:** ProjectM uses the shared lifecycle integration and still renders as before. The new layer has tests and a documented public contract.

### Phase 3 — Shared GPU resource and shader services

**Goal:** Extract reusable resource management and shader infrastructure.

Candidate work:

- texture and buffer helpers;
- framebuffer utilities;
- resource lifecycle and cleanup;
- shader asset loader;
- shader compile/link diagnostics;
- optional shader cache;
- resource leak checks;
- shader validation tooling.

**Exit gate:** ProjectM can use the shared services without changing its visual output or preset semantics. Resource ownership is documented and tested.

### Phase 4 — Reusable effects and render pipelines

**Goal:** Create reusable effect building blocks independent of ProjectM's visualization engine.

Candidate effects:

- texture compositing;
- color transforms;
- blur;
- glow;
- distortion;
- image filters;
- multi-pass framebuffer pipelines.

Build effects as small components with explicit inputs, outputs, and resource ownership.

**Exit gate:** At least one effect is demonstrated in the showcase app without importing ProjectM.

### Phase 5 — Input, animation, scenes, and procedural graphics

**Goal:** Expand VisualCore from a rendering foundation into a reusable interactive graphics framework.

Candidate features:

- touch and gesture input;
- coordinate mapping;
- animation timelines;
- 2D scene primitives;
- 3D scene abstractions only where justified;
- particle systems;
- procedural geometry;
- reusable transitions;
- deterministic update loops.

**Exit gate:** A small interactive demo runs entirely on VisualCore and does not depend on ProjectM-specific code.

### Phase 6 — Standalone VisualCore Showcase application

**Goal:** Prove that VisualCore is independently useful.

The showcase should:

- initialize VisualCore without importing ProjectM engine modules;
- render using the shared ANGLE-backed path;
- demonstrate shader loading;
- demonstrate at least one effect;
- demonstrate input;
- expose diagnostics;
- include a repeatable smoke-test workflow.

Suggested showcase scenes:

1. Shader gradient and texture sample.
2. Animated geometry.
3. Touch-interactive distortion.
4. Particle system.
5. Multi-pass post-processing.
6. Optional audio-reactive scene if the audio input layer is independently designed and tested.

**Exit gate:** The showcase builds and runs with ProjectM engine code excluded from its dependency graph.

### Phase 7 — ProjectM integration and regression hardening

**Goal:** Make ProjectM a clean consumer of the shared framework where extraction is justified.

Tasks:

- replace duplicated integration code incrementally;
- keep ProjectM-specific engine and preset modules in the submodule;
- add integration tests;
- compare visual output against the Phase 0 baseline;
- verify lifecycle events and repeated foreground/background transitions;
- test device rotation and resize;
- check memory/resource cleanup;
- document any intentionally retained ProjectM-specific integration.

**Exit gate:** ProjectM remains functional and regression tests pass. Any remaining duplication is documented rather than forcefully abstracted.

### Phase 8 — Reuse validation with a second consumer

**Goal:** Prove that VisualCore is a framework, not merely a refactoring of ProjectM.

Create a second small demo or application target that:

- uses VisualCore APIs;
- uses the existing ANGLE-backed rendering foundation;
- has no dependency on ProjectM engine or preset code;
- demonstrates a different use case, such as a simple game scene or generative-art tool.

**Exit gate:** A second consumer can be built and maintained independently of ProjectM-specific code.

### Phase 9 — Stabilization, documentation, and release

**Goal:** Establish a maintainable initial release.

Tasks:

- API review;
- package dependency review;
- performance baseline and regression thresholds;
- license and attribution audit;
- supported device and OS matrix;
- documentation and examples;
- CI validation;
- versioning and release notes;
- sample app release build.

**Exit gate:** VisualCore has a documented supported API, reproducible build, tested sample, and release checklist.

---

## 8. Spec Kit setup

Use the official Spec Kit CLI and Claude Code integration. Check the installed CLI's help output before relying on flags because Spec Kit evolves.

### 8.1 Install prerequisites

On macOS:

```bash
xcode-select --install
```

Install Git, Python 3, `uv`, and Claude Code using their official installation instructions. Confirm:

```bash
git --version
python3 --version
uv --version
claude --version
```

Install Spec Kit CLI:

```bash
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
```

Verify:

```bash
specify --help
specify check
```

If the `specify` executable is not on `PATH`, follow the `uv` tool installation output and add its tool binary directory to your shell path.

### 8.2 Initialize Spec Kit in the new VisualCore repository

Run from the VisualCore repository root:

```bash
specify init --here --integration claude --script py
```

If the installed CLI uses different option syntax, inspect:

```bash
specify init --help
```

Use the Claude integration and Python script variant. Do not initialize Spec Kit inside `External/projectm-ios`.

After initialization, inspect what was created:

```bash
git status --short
find .specify -maxdepth 3 -type f
find .claude -maxdepth 4 -type f
```

Review generated templates and commands before committing. Confirm the generated command invocation style in Claude Code. The canonical Spec Kit documentation writes commands as `/speckit.*`; actual installed Claude integration files are authoritative for the local setup.

### 8.3 Start Claude Code

From the VisualCore repository root:

```bash
claude
```

Inside Claude Code, verify available commands:

```text
/help
```

Use the installed Spec Kit command names. The standard workflow is:

```text
/speckit.constitution
/speckit.specify
/speckit.clarify
/speckit.plan
/speckit.checklist
/speckit.tasks
/speckit.analyze
/speckit.implement
/speckit.converge
```

If the installed integration exposes skills with hyphenated names instead, use the exact names shown by `/help` and `.claude/skills/`.

### 8.4 Spec Kit command purpose

| Command | Purpose | When |
|---|---|---|
| `/speckit.constitution` | Establish project principles | Once at project start; update when principles change |
| `/speckit.specify` | Define feature behavior and requirements | Start of every feature |
| `/speckit.clarify` | Resolve ambiguous requirements | Before planning |
| `/speckit.plan` | Define technical architecture and implementation choices | After specification |
| `/speckit.checklist` | Generate requirements-quality checklist | Before task breakdown |
| `/speckit.tasks` | Generate dependency-ordered tasks | After plan |
| `/speckit.analyze` | Check consistency across specification, plan, and tasks | Before implementation |
| `/speckit.implement` | Execute tasks | In bounded phases |
| `/speckit.converge` | Find remaining gaps against artifacts | After implementation |

For substantial work, use all quality gates. Do not run `/speckit.implement` against an ambiguous or inconsistent plan.

---

## 9. Spec Kit feature organization

Use one feature per major implementation phase. Example feature directories:

```text
specs/
├── 001-repository-audit/
├── 002-visualcore-architecture/
├── 003-rendering-lifecycle/
├── 004-gpu-resources/
├── 005-shader-services/
├── 006-effects-pipeline/
├── 007-input-animation-scenes/
├── 008-showcase-app/
├── 009-projectm-integration/
├── 010-second-consumer/
└── 011-stabilization-release/
```

Use the actual feature directory format generated by your installed Spec Kit version. Do not manually assume that Git branch names select the active feature. The current Spec Kit implementation may track the active feature in `.specify/feature.json`; inspect the generated configuration and command documentation.

Keep feature branches aligned with the team's Git workflow, for example:

```text
001-repository-audit
002-visualcore-architecture
003-rendering-lifecycle
...
```

Do not create all feature specs as a substitute for completing the audit. It is fine to create roadmap placeholders, but implementation plans must be based on verified repository facts.

---

## 10. Initial Claude Code and Spec Kit prompts

The following are ready-to-use prompts. Run them in the VisualCore repository root.

### 10.1 Establish the constitution

```text
/speckit.constitution

Create the VisualCore engineering constitution.

This is a new reusable iOS graphics framework repository. The existing
Coastrnaut/projectm-ios repository is included as a Git submodule at
External/projectm-ios and is the first reference application.

Non-negotiable principles:

1. Preserve the existing ProjectM application and its working renderer.
2. ProjectM already uses ANGLE for OpenGL ES rendering through ANGLE's
   Metal backend. Reuse this proven integration.
3. Do not replace ANGLE, duplicate its implementation, or create a
   second renderer backend as part of the initial architecture.
4. VisualCore must not depend on ProjectM engine, MilkDrop, or preset
   implementation details.
5. Extract reusable boundaries only after inspecting real code.
6. Keep the ProjectM submodule independently versioned and pinned.
7. Never silently modify the submodule gitlink or third-party source.
8. Prefer small, independently testable packages with acyclic dependencies.
9. Preserve behavior during extraction and require regression evidence.
10. Use physical iOS devices for performance and GPU lifecycle claims.
11. Record architecture decisions and evidence in the repository.
12. Every feature must have specification, plan, tasks, and verification.

Include API design, testing, performance, licensing, documentation,
dependency, and release principles. Do not invent repository facts.
```

### 10.2 Phase 0 — repository audit specification

```text
/speckit.specify

Create the Phase 0 repository integration and baseline audit feature.

The new VisualCore repository contains the existing
Coastrnaut/projectm-ios repository as a Git submodule at
External/projectm-ios.

The purpose is to establish a verified understanding of the existing
codebase before any production source changes.

Required outcomes:
- Verify submodule configuration and pinned commit.
- Inventory source folders, build targets, package manifests, project
  generation files, scripts, tests, CI, dependencies, and licenses.
- Trace the iOS app startup to renderer initialization.
- Trace EGL context and surface creation.
- Trace OpenGL ES calls into ANGLE and identify the actual ANGLE Metal
  backend configuration and presentation path.
- Trace render scheduling, threading, synchronization, resize,
  orientation, teardown, and recreation.
- Inventory shaders, textures, framebuffers, and resource ownership.
- Identify ProjectM-specific modules versus reusable candidates.
- Establish a reproducible ProjectM build and baseline smoke test.
- Record the exact tested submodule commit.

Create audit documents under docs/architecture and a baseline report
under docs/verification.

Constraints:
- No production source code changes.
- No renderer rewrite.
- No ANGLE feasibility project; the integration already exists.
- No separate ANGLE adapter project.
- No speculative package extraction.
- Every finding must cite repository paths, symbols, targets, or build
  configuration.
- Unknowns must be labeled unknown and assigned a follow-up task.
```

Then run:

```text
/speckit.clarify Focus on submodule ownership, build reproducibility,
the exact ANGLE/EGL-to-Metal rendering path, and the evidence required
to declare the baseline verified.

/speckit.plan Use a repository-audit-first approach. The ProjectM
submodule is read-only for this feature. Use Python scripts for
repeatable inventory and validation. Do not change production code.

/speckit.checklist Focus on completeness of the repository inventory,
rendering-pipeline trace, dependency/license audit, and reproducible
baseline evidence.

/speckit.tasks

/speckit.analyze
```

Implementation prompt:

```text
/speckit.implement Implement only the Phase 0 audit and repository
integration tasks. Do not modify production source files or the
ProjectM submodule revision. Run available non-destructive checks.
Stop after producing the audit documents and baseline report.
```

Then:

```text
/speckit.converge
```

Review every finding and confirm the baseline manually before moving on.

### 10.3 Phase 1 — architecture specification

```text
/speckit.specify

Define the VisualCore architecture and integration contracts using
the completed Phase 0 audit as the source of truth.

Specify:
- package ownership and dependency direction;
- public versus internal APIs;
- rendering lifecycle and threading contracts;
- resource ownership and cleanup;
- shader asset and diagnostic services;
- error handling and logging;
- test boundaries;
- ProjectM adapter/integration responsibilities;
- submodule ownership and update policy;
- compatibility and regression requirements.

VisualCore must be independently usable by a second app. The ProjectM
engine and MilkDrop/preset semantics remain outside VisualCore.

The existing ANGLE/OpenGL ES/Metal implementation is the rendering
foundation. Do not create an ANGLE replacement or assume a separate
native Metal renderer is required.

Do not create package boundaries that are unsupported by the audit.
```

Run the standard quality workflow:

```text
/speckit.clarify Focus on package ownership, API stability, threading,
lifecycle, and dependency direction.
/speckit.plan Use the actual languages, targets, build system, and
dependency structure discovered in Phase 0.
/speckit.checklist Focus on architecture completeness and enforceable
boundaries.
/speckit.tasks
/speckit.analyze
```

Then implement only approved architecture documentation and minimal scaffolding:

```text
/speckit.implement Implement the architecture documentation, ADRs,
and only the package scaffolding explicitly approved by the plan.
Do not migrate renderer code in this phase.
/speckit.converge
```

### 10.4 Phase 2 — rendering lifecycle extraction

```text
/speckit.specify

Extract a reusable rendering lifecycle layer around the existing
ProjectM ANGLE/EGL integration.

The feature must provide a stable, testable VisualCore API for the
render lifecycle components proven reusable by the Phase 0 audit.

Scope may include renderer host, context/surface lifecycle,
render-thread ownership, frame scheduling, resize/orientation,
synchronization, teardown, and recreation.

Preserve the exact working ANGLE integration and configuration.
Do not fork or replace ANGLE. Do not create a second rendering backend.
Keep ProjectM-specific rendering and preset logic outside VisualCore.

Migrate ProjectM incrementally to the shared layer only where the
specification and audit justify it. Preserve behavior and provide
regression tests.
```

Run:

```text
/speckit.clarify Focus on thread ownership, EGL lifecycle, surface
recreation, app foreground/background, and failure recovery.
/speckit.plan Base every extraction on the Phase 0 source inventory.
Specify migration order, compatibility shims, tests, and rollback.
/speckit.checklist Focus on lifecycle correctness, thread safety,
resource cleanup, and preservation of ProjectM behavior.
/speckit.tasks
/speckit.analyze
```

Implement in bounded batches:

```text
/speckit.implement Implement only the foundational interfaces and
tests first. Do not migrate ProjectM call sites yet.
```

Build and test. Then:

```text
/speckit.implement Migrate one approved ProjectM integration boundary
at a time. Run the ProjectM build and regression tests after each
boundary. Stop if behavior changes unexpectedly.
```

Finally:

```text
/speckit.converge
```

### 10.5 Phase 3 — resources and shader services

```text
/speckit.specify

Create reusable VisualCore GPU resource and shader asset services
using the existing ANGLE/OpenGL ES implementation.

Include only audited reusable capabilities:
- texture and buffer lifecycle helpers;
- framebuffer utilities;
- resource ownership and cleanup;
- shader loading and diagnostics;
- shader variants and optional caching where justified;
- validation and leak-detection support.

Keep ProjectM shader behavior and preset semantics unchanged.
Do not introduce a new renderer backend or duplicate ANGLE.

Require tests for ownership, cleanup, failures, and shader compilation.
Demonstrate use from both ProjectM integration and a non-ProjectM test
or showcase target where practical.
```

Run the standard sequence:

```text
/speckit.clarify Focus on context ownership, resource lifetime,
shader compatibility, cache invalidation, and error reporting.
/speckit.plan Define the public APIs, package dependencies, test
strategy, and incremental ProjectM migration.
/speckit.checklist Focus on resource leaks, invalid lifecycle use,
shader diagnostics, and compatibility.
/speckit.tasks
/speckit.analyze
/speckit.implement Implement the resource and shader services in
small tested increments. Preserve ProjectM output.
/speckit.converge
```

### 10.6 Phase 4 — reusable effects

```text
/speckit.specify

Build reusable, composable GPU effects on VisualCore's existing
ANGLE-backed rendering path.

Start with a small set of effects selected from the Phase 0/3
capabilities, such as color transforms, compositing, blur, glow,
distortion, and multi-pass framebuffer pipelines.

Each effect must define inputs, outputs, resource ownership,
configuration, failure behavior, and test/demo coverage.

At least one effect must be usable by the standalone showcase without
ProjectM engine dependencies. Do not change ProjectM preset semantics.
```

Then use the standard clarify/plan/checklist/tasks/analyze/implement/converge sequence. Implement one effect at a time and measure performance on physical devices.

### 10.7 Phase 5 — input, animation, and scene primitives

```text
/speckit.specify

Add reusable interactive graphics capabilities to VisualCore:
touch/gesture input, coordinate conversion, animation/update timing,
simple 2D scene primitives, and a particle system.

Add 3D scene abstractions only if the architecture and use cases
justify them. Keep the update loop deterministic where practical.
Do not add dependencies on ProjectM or MilkDrop.

Provide a standalone interactive demo and automated tests for
coordinate mapping, animation timing, and state transitions.
```

Use the standard quality workflow and implement each subsystem separately.

### 10.8 Phase 6 — standalone showcase

```text
/speckit.specify

Create a VisualCore Showcase iOS application that demonstrates the
framework without importing ProjectM engine or preset modules.

It must use the shared VisualCore APIs and the existing ANGLE-backed
rendering path.

Demonstrate shader loading, animated rendering, at least one
post-processing effect, touch interaction, and diagnostics.

The showcase must build independently of ProjectM engine targets.
ProjectM may remain present in the repository as a submodule, but it
must not be a runtime or compile-time dependency of the showcase.
```

Use the standard quality workflow. Add a build-time dependency audit that verifies the showcase does not link ProjectM engine targets.

### 10.9 Phase 7 — ProjectM migration

```text
/speckit.specify

Migrate the approved reusable ProjectM integration points to
VisualCore APIs.

Use the Phase 0 baseline and the completed VisualCore APIs as the
acceptance reference.

Keep ProjectM engine, MilkDrop/preset handling, and app-specific
behavior in the ProjectM submodule.

Migrate incrementally. For each change:
- identify the duplicated or reusable boundary;
- explain why it belongs in VisualCore;
- preserve existing behavior;
- build and run regression checks;
- document any retained ProjectM-specific implementation.

Do not force extraction of code that is tightly coupled to ProjectM.
Do not change the ANGLE revision or renderer architecture without a
separate reviewed decision.
```

Use the standard quality workflow. Require before/after evidence for each migration batch.

### 10.10 Phase 8 — second consumer

```text
/speckit.specify

Create a second, deliberately small VisualCore consumer that is not
ProjectM and does not import ProjectM engine modules.

Choose a simple generative-art, interactive graphics, or game-like
demonstration. It must use only documented VisualCore APIs for
rendering, resources, shaders, effects, and input.

The purpose is to prove that VisualCore is independently reusable.
Add a dependency check and build/run smoke test.
```

### 10.11 Phase 9 — stabilization and release

```text
/speckit.specify

Prepare VisualCore for an initial stable release.

Cover public API review, supported OS/device matrix, package
dependency audit, performance baselines, regression tests, shader
validation, resource cleanup, license/notice compliance, documentation,
sample app, CI, versioning, and release notes.

Do not claim support for devices or OS versions that have not been
tested. Document known limitations and unsupported capabilities.
```

---

## 11. Claude Code repository guidance

Create a root `CLAUDE.md` with concise, durable instructions. Keep detailed procedures in skills so the root file does not become an oversized prompt.

Suggested initial `CLAUDE.md`:

```markdown
# VisualCore — Claude Code Instructions

## Mission
Build a reusable iOS graphics framework in this repository.
External/projectm-ios is the first reference application and is a Git
submodule, not a directory owned by this repository.

## Non-negotiable rendering constraint
ProjectM iOS already uses ANGLE for OpenGL ES rendering through
ANGLE's Metal backend. Preserve and reuse this implementation.
Do not replace ANGLE, duplicate its source/integration, or create a
second renderer backend without an approved ADR.

## Repository ownership
- VisualCore source belongs in this repository.
- External/projectm-ios remains independently versioned.
- Never silently change its pinned commit.
- Do not commit ProjectM changes as VisualCore-owned source.
- Keep third-party notices and license files intact.

## Architecture
- VisualCore must not depend on ProjectM engine or MilkDrop code.
- ProjectM-specific presets and visualization behavior remain in
  ProjectM.
- Keep package dependencies acyclic.
- Extract only components supported by repository evidence.

## Workflow
- Read the active feature's spec.md, plan.md, tasks.md, and checklists.
- Follow Spec Kit's specify -> clarify -> plan -> tasks -> analyze ->
  implement -> converge workflow.
- Implement one bounded phase at a time.
- Do not mark work complete without running the relevant checks.
- Update documentation and ADRs when architecture changes.

## Safety
- Inspect git status before editing.
- Never use destructive Git commands without explicit approval.
- Never reset, clean, force checkout, or rewrite history in the
  ProjectM submodule.
- Report all changes made inside the submodule.
- Do not modify signing identities, provisioning profiles, or secrets.

## Verification
- Record the exact submodule commit used for tests.
- Build with the repository's documented Xcode workflow.
- Run unit/integration tests and showcase smoke tests where available.
- Physical-device testing is required for performance and GPU
  lifecycle claims.
```

### 11.1 Suggested Claude Code skills

Create skills only after the audit reveals the actual build and test commands.

Suggested layout:

```text
.claude/skills/
├── audit-projectm/SKILL.md
├── verify-ios-build/SKILL.md
├── verify-rendering-regression/SKILL.md
├── review-submodule-change/SKILL.md
├── validate-shaders/SKILL.md
└── release-visualcore/SKILL.md
```

Potential agent definitions:

```text
.claude/agents/
├── repository-auditor.md
├── rendering-architect.md
├── ios-build-validator.md
├── shader-reviewer.md
└── dependency-license-reviewer.md
```

Use subagents for isolated audits and reviews, not to make concurrent edits to the same package or shared Spec Kit feature files.

---

## 12. Python automation

Use Python for deterministic repository checks and repeatable reports. Do not use Python to replace Xcode, the Swift compiler, or device testing.

Suggested scripts:

```text
Tools/python/
├── audit_repository.py
├── inspect_submodule.py
├── inventory_targets.py
├── validate_package_dependencies.py
├── check_projectm_boundary.py
├── validate_shader_assets.py
├── check_licenses.py
├── compare_baseline_reports.py
└── generate_verification_report.py
```

### 12.1 Submodule inspection script

Create `Tools/python/inspect_submodule.py`:

```python
#!/usr/bin/env python3
"""Report the ProjectM submodule state without modifying it."""

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
SUBMODULE = ROOT / "External" / "projectm-ios"


def run_git(*args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(SUBMODULE), *args],
        check=True,
        text=True,
        capture_output=True,
    )
    return result.stdout.strip()


def main() -> int:
    if not SUBMODULE.exists():
        print(f"ERROR: submodule path does not exist: {SUBMODULE}")
        return 1

    print(f"Submodule: {SUBMODULE}")
    print(f"Commit: {run_git('rev-parse', 'HEAD')}")
    print(f"Branch: {run_git('branch', '--show-current') or '(detached HEAD)'}")
    print("Working tree:")
    print(run_git("status", "--short") or "(clean)")
    print("Latest commit:")
    print(run_git("log", "-1", "--oneline"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

Run:

```bash
python3 Tools/python/inspect_submodule.py
```

### 12.2 Package dependency validation

Once package manifests and targets exist, implement a script that:

- discovers package manifests and Xcode targets;
- parses declared dependencies;
- constructs a directed dependency graph;
- rejects cycles;
- rejects VisualCore-to-ProjectM dependencies;
- rejects Showcase-to-ProjectM-engine dependencies;
- emits a machine-readable JSON report and human-readable Markdown report.

Do not hardcode package names before Phase 0 confirms the package layout.

### 12.3 Shader validation

The shader validator should:

- inventory shader files;
- identify shader language/version conventions;
- check required files and references;
- run an available compiler/validator when compatible with the shader dialect;
- preserve compiler output;
- distinguish static validation from runtime GPU validation.

A successful offline shader syntax check is not proof that the shader renders correctly on target devices.

### 12.4 License validation

The license audit should inventory:

- ProjectM license;
- ANGLE license and notices;
- all bundled third-party libraries;
- shader and texture asset attribution;
- copied code and generated artifacts.

Do not remove, rewrite, or consolidate license files without legal review.

---

## 13. Testing and quality strategy

### 13.1 Test layers

| Layer | Purpose |
|---|---|
| Python repository checks | Submodule state, dependency boundaries, inventory, license checks |
| Swift unit tests | Public API behavior, configuration, state transitions |
| C/C++ tests | Native helper behavior where appropriate |
| Shader validation | Static shader and asset checks |
| Integration tests | EGL/context/resource lifecycle |
| ProjectM regression | Existing app still builds and renders |
| Showcase smoke tests | Framework works without ProjectM |
| Physical-device tests | GPU behavior, performance, lifecycle, memory |

### 13.2 Regression requirements

For each extraction:

1. Record the baseline commit and build configuration.
2. Run the same ProjectM build/test procedure before and after.
3. Compare observable output where practical.
4. Exercise foreground/background transitions.
5. Exercise rotation and size changes.
6. Exercise renderer teardown and recreation.
7. Check resource cleanup and repeated scene changes.
8. Record device model, OS version, Xcode version, and tested submodule commit.

### 13.3 Performance

Do not set arbitrary performance targets before baseline measurement.

Phase 0 should record:

- frame rate and frame-time distribution;
- CPU render-thread cost;
- GPU timing if reliably measurable;
- memory use;
- shader compilation/loading behavior;
- startup and renderer initialization time.

After baseline collection, define acceptable regression budgets. Compare on the same device and OS where possible.

### 13.4 Physical-device testing

Simulator results are useful for functional development but insufficient for final claims about:

- GPU performance;
- thermal behavior;
- frame pacing;
- memory pressure;
- Metal-backed ANGLE behavior;
- real device lifecycle and display behavior.

---

## 14. CI strategy

Use macOS GitHub Actions runners for Xcode builds and tests. CI should:

1. Check out the VisualCore repository with submodules.
2. Record the ProjectM submodule commit.
3. Run Python repository validation.
4. Validate package dependency direction.
5. Run shader asset checks.
6. Build VisualCore packages.
7. Build the standalone showcase.
8. Run unit tests.
9. Build the ProjectM reference application using its documented configuration.
10. Upload logs and test results.

Example workflow skeleton (adjust scheme and destination after Phase 0):

```yaml
name: iOS CI

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

jobs:
  validate:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Select Xcode
        run: xcode-select -p

      - name: Python checks
        run: |
          python3 --version
          python3 Tools/python/inspect_submodule.py

      - name: Record submodule revision
        run: git submodule status

      # Add package, shader, showcase, and ProjectM build/test steps
      # only after the real schemes and destinations are verified.
```

Pin action versions according to the repository's security/update policy. Replace placeholder build steps only after the audit confirms actual Xcode schemes and destinations. Avoid inventing a scheme name.

---

## 15. Git workflow and pull request policy

Suggested branch names:

```text
main
feature/001-repository-audit
feature/002-architecture
feature/003-rendering-lifecycle
feature/004-resource-services
...
```

For each feature:

1. Create a feature branch.
2. Confirm the submodule commit.
3. Complete Spec Kit artifacts.
4. Implement a bounded task group.
5. Run tests.
6. Review diffs, including submodule gitlink changes.
7. Update documentation.
8. Open a pull request.
9. Merge only after required checks pass.

Pull requests that change `External/projectm-ios` must clearly state:

- whether the submodule pointer changed;
- why it changed;
- the upstream commit or PR;
- whether the submodule working tree is clean;
- which ProjectM build/tests were run.

Never merge a VisualCore PR with an unexplained submodule pointer change.

---

## 16. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Extracting code too early | Complete Phase 0 audit and baseline first |
| Breaking ProjectM rendering | Incremental migration and regression checks |
| Duplicating ANGLE | Preserve the existing integration and dependency pin |
| VisualCore becoming ProjectM-specific | Enforce dependency boundary and standalone showcase |
| Over-abstraction | Require a second-consumer use case or concrete reuse rationale |
| Submodule drift | Pin commits and review updates explicitly |
| Resource leaks | Ownership contracts, lifecycle tests, device profiling |
| Shader incompatibility | Preserve existing dialect and validate on actual devices |
| CI scheme assumptions | Discover real schemes during audit before adding build steps |
| AI agent making broad changes | Bounded Spec Kit implementation runs and explicit stop conditions |
| License/notice loss | Automated inventory plus manual review |

---

## 17. Definition of done

VisualCore v1 is not complete until all of the following are true:

- [ ] New VisualCore repository exists and builds.
- [ ] `projectm-ios` is integrated as a pinned Git submodule.
- [ ] Submodule ownership and update procedures are documented.
- [ ] Existing ANGLE-to-Metal rendering path is documented from actual source.
- [ ] VisualCore package boundaries are documented and acyclic.
- [ ] Shared rendering lifecycle APIs are tested.
- [ ] Shared resource and shader services are tested.
- [ ] At least one reusable effect is implemented.
- [ ] Standalone showcase builds without ProjectM engine dependencies.
- [ ] ProjectM builds and passes regression checks after approved integration.
- [ ] A second consumer demonstrates independent reuse.
- [ ] License and attribution audit is complete.
- [ ] CI runs repository checks and supported macOS/Xcode build tests.
- [ ] Device/OS support and known limitations are documented.
- [ ] Release notes and versioning policy are established.

---

## 18. Recommended first execution sequence

Do not begin by generating all packages or migrating source code. Start with this exact sequence.

### Step 1 — Create the new repository and add the submodule

```bash
mkdir VisualCore
cd VisualCore
git init
git branch -M main

git submodule add https://github.com/Coastrnaut/projectm-ios.git External/projectm-ios
git submodule update --init --recursive

git add .gitmodules External/projectm-ios
git commit -m "chore: initialize VisualCore with ProjectM reference submodule"
```

Create the remote GitHub repository and add it:

```bash
git remote add origin https://github.com/<OWNER>/VisualCore.git
git push -u origin main
```

### Step 2 — Install and initialize Spec Kit

```bash
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
specify check
specify init --here --integration claude --script py
```

Inspect the generated files and command names. Do not initialize Spec Kit inside the submodule.

### Step 3 — Add root Claude instructions

Create `CLAUDE.md` using the guidance in Section 11. Keep it concise and commit it.

### Step 4 — Launch Claude Code

```bash
claude
```

Run `/help` and verify the Spec Kit command names.

### Step 5 — Run Phase 0 only

Use the Phase 0 prompts in Section 10. Do not let Claude modify production source code.

### Step 6 — Review the audit

Manually verify:

- exact ProjectM submodule commit;
- app build procedure;
- actual renderer startup path;
- EGL/ANGLE/Metal path;
- target and package inventory;
- reusable component inventory;
- license/notice inventory.

### Step 7 — Approve architecture before extraction

Only after the audit is accepted should Phase 1 and Phase 2 begin.

### Step 8 — Implement one phase at a time

For every feature, follow:

```text
/speckit.specify
/speckit.clarify
/speckit.plan
/speckit.checklist
/speckit.tasks
/speckit.analyze
/speckit.implement
/speckit.converge
```

For large phases, scope `/speckit.implement` to one task group at a time. Run the relevant build and tests between groups.

---

## 19. Important implementation notes

- The repository audit is authoritative. If actual source organization differs from this proposed layout, update the plan rather than forcing the repository to match the diagram.
- Do not assume the ProjectM app uses a particular Xcode scheme, Swift package structure, or XcodeGen target name. Discover these from the submodule.
- Do not create an `ANGLE feasibility` phase. ANGLE is already in use.
- Do not create a separate `ANGLE adapter` as a speculative layer. Extract existing integration services only where a stable reusable boundary exists.
- Do not create a separate VisualCore Metal renderer for v1.
- Do not move ProjectM engine or preset logic into VisualCore.
- Do not update the submodule to the latest upstream commit without review.
- Do not claim that NIST-style shader checks, static analysis, or simulator tests establish physical-device correctness; use the right evidence for each claim.
- Do not let an AI agent treat a successful compile as proof that visual behavior is unchanged.

---

## 20. Reference documentation

Use these official references when installing or updating the workflow:

- [GitHub Spec Kit repository](https://github.com/github/spec-kit)
- [Spec Kit Agentic SDD command reference](https://github.com/github/spec-kit/blob/main/docs/reference/agentic-sdd.md)
- [Spec Kit core CLI reference](https://github.github.com/spec-kit/reference/core.html)
- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code/overview)
- [Claude Code skills and slash commands](https://docs.anthropic.com/en/docs/claude-code/slash-commands)
- [ProjectM iOS reference repository](https://github.com/Coastrnaut/projectm-ios)

Spec Kit command names and CLI options can evolve. Confirm the installed version with `specify --help`, `specify check`, and Claude Code `/help` before executing the workflow. The repository's generated integration files are the final authority for the local command syntax.

---

## Final architectural direction

**Build VisualCore around the working ProjectM technology, not by replacing it.**

The new repository owns the reusable framework. The ProjectM repository remains a pinned submodule and the first reference consumer. The existing ANGLE/OpenGL ES/Metal path remains the proven rendering foundation. Each reusable capability is extracted only after its implementation, ownership, and behavior are understood.

The first deliverable is not a new renderer. It is a verified architecture and baseline that makes the existing renderer reusable without breaking the application that already depends on it.
