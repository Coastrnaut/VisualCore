# Interactive Anatomy
## iOS application architecture and Spec Kit + Claude Code implementation manual

**Concept #17 of 25** | **Category:** Education and science | **Proposed app/repository target:** `InteractiveAnatomy`
**Planning status:** proposed implementation guide; not proof of an existing application or released VisualCore package. **Source:** `AppsBrainstorm.md` catalog item 17; `README.md` VisualCore architecture and Spec Kit strategy.
**Rendering invariant:** reuse the existing ProjectM-proven OpenGL ES → ANGLE → Metal infrastructure exposed by VisualCore. Never create a duplicate EGL/ANGLE backend or link ProjectM engine internals into this independent app.

---

## 1. Executive summary and source traceability

A labeled, layer-controlled 3D anatomy reference with trustworthy licensed models and plain-language descriptions.

### Original brainstorm concept

> An educational 3D viewer for anatomical models with interactive layers, labels, lighting, and rotation.

**VisualCore capabilities listed in the brainstorm:**
- 3D model rendering
- Textures and materials
- Camera controls
- Lighting
- Labels and overlays

**Original product opportunity:** An interactive anatomy reference and learning application.

**Recommended product hypothesis:** A carefully scoped, offline-capable first release can demonstrate a distinct graphics workload and validate reusable VisualCore APIs. Test this hypothesis with a functioning vertical slice before expanding content or monetization.

## 2. Product contract and scope

### Primary audiences
- Students learning gross anatomy
- Educators presenting anatomical structures
- General learners exploring body systems

### End-to-end user journeys
1. **Journey 1:** Open whole-body overview and select a system layer.
2. **Journey 2:** Rotate a model and tap an anatomical structure.
3. **Journey 3:** Read its description, toggle a nearby layer and search another structure.

### Version 0.1 feature contract
1. **Feature 01:** One clinically reviewed anatomy region rather than full body at MVP. Acceptance requires an implemented behavior and a test or documented manual verification—not a screenshot mock.
2. **Feature 02:** Toggleable layered mesh groups and accessible structure list. Acceptance requires an implemented behavior and a test or documented manual verification—not a screenshot mock.
3. **Feature 03:** Selection highlighting, labels and searchable metadata. Acceptance requires an implemented behavior and a test or documented manual verification—not a screenshot mock.
4. **Feature 04:** Camera orbit/zoom and isolation/ghost controls. Acceptance requires an implemented behavior and a test or documented manual verification—not a screenshot mock.
5. **Feature 05:** Reviewed factual text with citations and content provenance. Acceptance requires an implemented behavior and a test or documented manual verification—not a screenshot mock.
6. **Feature 06:** Download-free offline content pack for initial region. Acceptance requires an implemented behavior and a test or documented manual verification—not a screenshot mock.

### Explicit non-goals
- Diagnostic advice or treatment recommendation
- Full-body atlas without content/licensing review
- User-uploaded patient medical files

### Later-stage ideas, not MVP commitments
- More anatomical regions with independent licensing
- Quizzes and guided lessons
- AR visualization where device support warrants

## 3. UX blueprint

The first launch should reach a meaningful working graphic or educational interaction without requiring an account. Use SwiftUI for navigation, settings, labels and accessibility; host VisualCore rendering in a verified UIView/UIViewRepresentable integration that owns no duplicate GPU lifecycle.

**Proposed screen inventory** (adapt to the app-specific flows above):
| Screen | Responsibility | Concrete behavior |
|---|---|---|
| Home / gallery | Start without setup | Curated Interactive Anatomy example, recent scene and explicit entry point |
| Interactive scene | Primary VisualCore rendering surface | Touch and app-state changes mapped into validated domain commands |
| Inspector | Controls and explanations | Show effective parameter values, reset and valid ranges |
| Library / files | Persistence where relevant | Open, duplicate, save, import/export only via permitted system APIs |
| Settings / help | Quality, accessibility, privacy | Explain input permissions, limitations, credits and renderer fallback |

**Interaction design rules:** screen gestures must have a deterministic domain meaning; rendering can interpolate but cannot silently change persisted state. State-affecting controls should be testable independent of the GPU. All critical feedback must remain legible without bloom, color alone, or animation.

### State transitions to implement
```text
uninitialized → loading-assets → ready → active
                                  ↔ paused / backgrounded
                                  ↘ editing / exporting (if supported)
any GPU state → renderer-lost → recover-resources → ready
any document state → validation-error → recoverable-message
```

Do not upload application/scene state to a server by default. If future features introduce accounts, cloud sync or sharing, write a new privacy and threat-model spec before implementation.

## 4. Architecture: VisualCore consumer, not renderer fork

```text
InteractiveAnatomy SwiftUI app (navigation, accessibility, preferences)
    ↓ commands / immutable snapshots
InteractiveAnatomyCore (domain rules, models, persistence schemas, validation)
    ↓ render-state snapshot; never raw SwiftUI bindings
InteractiveAnatomyRendering (scene adapter, shaders, asset IDs, pass descriptions)
    ↓ public APIs discovered in the real VisualCore checkout
VisualCore runtime, shaders, effects, scenes, inputs, diagnostics
    ↓ shared EGL/context/render host as audited
Existing OpenGL ES → ANGLE → Metal implementation
    ↓
iOS device GPU and display
```

**Ownership policy:** The app owns its content, mathematical rules, domain schema, UI and business logic. VisualCore owns generic graphics infrastructure. `Coastrnaut/projectm-ios` remains VisualCore's pinned reference submodule, not an app dependency. Any VisualCore API needed but not present must be proposed upstream with a test and an API contract; do not stub an imaginary package into production.

### Contracts and threading
- A domain coordinator produces immutable render snapshots or bounded commands; presentation does not mutate simulation truth.
- The VisualCore render host controls the EGL context, resource lifetime, presentation and the required render thread/queue; all GL work obeys that ownership.
- Native SwiftUI overlays remain separate from shader drawing where legibility, hit-testing and VoiceOver need native controls.
- On scene resize, background, memory warning or renderer reset, reallocate GPU resources from versioned CPU state rather than persisting raw GL handles.
- Shaders are treated as bundled, versioned assets unless the specific product explicitly supports user-authored GLSL with additional guards.

### Application-specific components
- **`AnatomyCatalog.swift`**: data storage, schema validation, assets or export; implement the specific rules in §6 and make dependencies explicit.
- **`StructureSearch.swift`**: pure domain algorithms and behavior, covered by CPU unit fixtures; implement the specific rules in §6 and make dependencies explicit.
- **`LayerVisibility.swift`**: pure domain algorithms and behavior, covered by CPU unit fixtures; implement the specific rules in §6 and make dependencies explicit.
- **`PickingIndex.swift`**: pure domain algorithms and behavior, covered by CPU unit fixtures; implement the specific rules in §6 and make dependencies explicit.
- **`AnatomyScene.swift`**: pure domain algorithms and behavior, covered by CPU unit fixtures; implement the specific rules in §6 and make dependencies explicit.
- **`AnatomyRenderer.swift`**: renderer-facing render orchestration and GPU pass bindings; implement the specific rules in §6 and make dependencies explicit.

## 5. Suggested standalone repository and files

**Repository strategy:** start this application in its own Git repository that consumes the shared VisualCore framework through a pinned Swift package or approved Xcode integration. During development, an adjacent checkout `../VisualCore` is convenient; the definitive package products and distribution mechanism must be discovered in the VisualCore repository audit. Do **not** copy ANGLE sources or add `projectm-ios` as a second app submodule.

```text
InteractiveAnatomy/
├── .claude/
│   └── skills/                 # generated speckit-* skills; app skills optional
├── .specify/                 # generated Spec Kit configuration/scripts
│   └── memory/constitution.md
├── .github/workflows/ios-ci.yml
├── Apps/InteractiveAnatomy/
│   ├── InteractiveAnatomyApp.swift
│   ├── AppEnvironment.swift
│   ├── Views/HomeView.swift
│   ├── Views/SceneView.swift
│   ├── Views/InspectorView.swift
│   ├── Views/SettingsView.swift
│   ├── Features/            # feature-level coordinators and view models
│   ├── Resources/Assets.xcassets/
├── Packages/InteractiveAnatomyCore/Sources/InteractiveAnatomyCore/
│   ├── AnatomyCatalog.swift
│   ├── StructureSearch.swift
│   ├── LayerVisibility.swift
│   ├── PickingIndex.swift
│   ├── AnatomyScene.swift
├── Packages/InteractiveAnatomyRendering/Sources/InteractiveAnatomyRendering/
│   ├── AnatomyRenderer.swift
├── Packages/InteractiveAnatomyRendering/Resources/
│   ├── Resources/Regions/region_manifest.json
│   ├── Resources/LICENSES.md
├── Tests/InteractiveAnatomyCoreTests/DomainFixturesTests.swift
├── Tests/InteractiveAnatomyRenderingTests/RenderLifecycleTests.swift
├── Tests/InteractiveAnatomyUITests/PrimaryJourneyUITests.swift
├── TestAssets/                # deterministic inputs and golden fixtures
├── docs/architecture/visualcore-contract.md
├── docs/product/mvp-scope.md
├── docs/decisions/           # ADRs on simulation, shaders and scope
├── docs/testing/device-matrix.md
├── docs/release/privacy-and-credits.md
├── scripts/check_repo.py
├── scripts/select_simulator.py
├── specs/                    # generated feature specs, plans, tasks
├── CLAUDE.md
├── README.md
├── LICENSES.md
└── project.yml               # only if XcodeGen is chosen
```

**Important:** The paths above are design targets, not a claim that VisualCore already exposes packages with these names. Build an audited path-based SPM dependency first. After VisualCore is published, pin an immutable reviewed tag/revision. The project generator and package structure should be selected before the first implementation PR.

### File creation policy
- Generate the minimum Xcode app target and package source files required by the first vertical slice. Do not pre-create dozens of empty Swift files.
- Keep application shader files local when specific to this product; move a shader helper to VisualCore only after an independent use-case and regression tests justify reuse.
- Store data fixtures in JSON/CSV where appropriate, with explicit schema and license metadata; do not serialize GPU buffer addresses or EGL objects.
- Keep all feature specs under `specs/` created by Spec Kit; allow its installed release to determine feature numbering and active feature selection.

## 6. Domain model, algorithms and rendering design

### Versioned domain schemas (proposed types)
| Type | Field contract / required invariants |
|---|---|
| `AnatomicalStructure` | `AnatomicalStructure(id, standardName, synonyms, layer, meshIDs, description, sourceRefs)`. Validate on ingress; version persistent payloads and reject unsupported data safely. |
| `AnatomyRegion` | `AnatomyRegion(id, systems, coordinateConvention, boundingVolume, assetVersion)`. Validate on ingress; version persistent payloads and reject unsupported data safely. |
| `AnatomyView` | `AnatomyView(selectedID, visibleLayers, isolationMode, camera)`. Validate on ingress; version persistent payloads and reject unsupported data safely. |
| `ContentManifest` | `ContentManifest(assetLicense, clinicalReviewer, reviewDate, citations)`. Validate on ingress; version persistent payloads and reject unsupported data safely. |

Use explicit units and coordinate spaces in type names or documentation. Reject NaN/Inf, invalid counts, truncated files, unreasonable allocations and unsupported versions where applicable. Canonical storage should be pure data; expensive buffers can be reconstructed.

### Algorithm and correctness decisions
1. Create hierarchy allowing efficient visibility toggles, hit-test selection, and consistent parent transforms.
2. Use mesh grouping, per-structure identifiers and coarse CPU pick proxies.
3. Apply transparent ghosting only with correct draw order/depth policy; keep labels accessible in native UI.
4. All anatomical descriptions are reviewed editorial data; do not derive clinical statements from raw geometry.

### App-specific render sequence
1. **Stage 1:** Load region manifest and licensed mesh assets.
2. **Stage 2:** Compute visible/selected structure set and GPU material assignments.
3. **Stage 3:** Render opaque structures, ghosted layers and highlight pass.
4. **Stage 4:** Present native overlay labels, search and descriptions.

### Rendering lifecycle and frame budget
- Create resources only after VisualCore signals a valid owning EGL context; release/recreate on context loss and size changes.
- Separate fixed-step simulation, event handling, visual animation time and wall time when the product uses more than one.
- Treat device tier as policy data: resolution scale, effect counts, iterations and object count may change; domain correctness and user state may not.
- Validate framebuffer completeness, shader compile/link results, texture format support and GPU resource handles before presenting a frame.
- Record frame pacing, app-owned CPU time, allocation counts and renderer recovery on a real device before selecting release targets.

### Required capability audit against VisualCore
- **3D model rendering** — locate an existing package/API/contract and a working example in VisualCore; mark `available`, `requires adaptation`, or `upstream gap` in `docs/architecture/visualcore-contract.md`.
- **Textures and materials** — locate an existing package/API/contract and a working example in VisualCore; mark `available`, `requires adaptation`, or `upstream gap` in `docs/architecture/visualcore-contract.md`.
- **Camera controls** — locate an existing package/API/contract and a working example in VisualCore; mark `available`, `requires adaptation`, or `upstream gap` in `docs/architecture/visualcore-contract.md`.
- **Lighting** — locate an existing package/API/contract and a working example in VisualCore; mark `available`, `requires adaptation`, or `upstream gap` in `docs/architecture/visualcore-contract.md`.
- **Labels and overlays** — locate an existing package/API/contract and a working example in VisualCore; mark `available`, `requires adaptation`, or `upstream gap` in `docs/architecture/visualcore-contract.md`.

> **Domain-specific engineering rule:** Treat anatomy model and descriptions as educational reference, not medical guidance. Track explicit content review and licensing evidence.

## 7. Local environment and reproducible bootstrap

**Prerequisites:** macOS and Xcode for iOS build, signing, Simulator and physical-device tests; Git, Python 3, `uv`, and Claude Code CLI. Windows can prepare specifications and source but cannot validate the iOS rendering path without a macOS builder. Follow current vendor instructions for installation; verify tool versions rather than assuming they exist.

**Terminal on macOS — commands to create this app repository:**
```bash
mkdir InteractiveAnatomy && cd InteractiveAnatomy
git init -b main
git --version
python3 --version
uv --version
claude --version
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
specify version
specify init --help
specify init --here --integration claude --script py
specify check
git status --short
claude
```

Initialize Spec Kit **once** in a newly created repository. In a non-empty existing repo, commit/backup first and inspect `specify init --help`; `--force` may merge/overwrite managed files and must not be run blindly. Never run Spec Kit initialization inside the VisualCore or ProjectM submodule from an app repo.

**Current Claude Code integration:** Spec Kit creates `.claude/skills/speckit-<command>/SKILL.md`; invoke skills in Claude chat using **hyphens**, e.g. `/speckit-specify`, not the dotted spelling used in some generic documentation. Confirm actual skills with `find .claude/skills -name SKILL.md` and Claude `/help` because installed versions can differ. See official [Claude integration](https://github.github.com/spec-kit/integrations/claude.html).

**Terminal — verify a local VisualCore checkout without assuming package products:**
```bash
test -d ../VisualCore || { echo "Clone or locate the VisualCore repository beside this app first"; exit 1; }
git -C ../VisualCore status --short
find ../VisualCore -name Package.swift -not -path "*/.build/*" -print
git -C ../VisualCore submodule status
```

If `../VisualCore` does not yet provide a consumer package, create an upstream integration feature and stop at a no-op host skeleton. Do not invent `VisualCoreRenderer` product names or fake ANGLE integration code.

## 8. Paste-ready repository constitution and Claude policy

**Inside Claude Code chat, from this app repo:**
```text
/speckit-constitution Define the constitution for Interactive Anatomy. Build a standalone iOS/iPadOS VisualCore consumer, never a fork of projectm-ios. Reuse only audited VisualCore public APIs over the existing OpenGL ES→ANGLE→Metal integration. Domain rules and persisted files must be testable without GPU access. Keep the app offline-first, disclose permissions, use bounded GPU resources, support accessibility, record asset licenses, and prohibit unsupported scientific/platform claims. Require a ProjectM regression check whenever VisualCore is modified. Use Python 3 for repository automation; no PowerShell dependency. Implement only one approved Spec Kit phase at a time.
```

**Suggested root `CLAUDE.md` text** (create once; do not overwrite generated skill files):
```markdown
# Interactive Anatomy — Claude Code Engineering Rules

- Product goal: A labeled, layer-controlled 3D anatomy reference with trustworthy licensed models and plain-language descriptions.
- Read `docs/architecture/visualcore-contract.md` before editing graphics integration.
- VisualCore owns the graphics lifecycle; never create an independent ANGLE/EGL initialization path.
- Do not import ProjectM engine internals or duplicate third-party sources.
- Domain truth, deterministic tests and versioned persistence must not depend on GL contexts.
- Use Python scripts for repeatable source/schema/license validation.
- Request explicit approval before changing the adjacent VisualCore repository.
- Report uncertainty and platform limitations; do not invent APIs or test results.
- Complete Spec Kit clarify → plan → checklist → tasks → analyze before implementing a phase.
- Run relevant tests; log exact macOS/Xcode/device/VisualCore revisions used.
- Keep each PR bounded to one feature phase and document migration/rollback plan.
```

## 9. Implementation phases with **actual Spec Kit / Claude Code commands**

Run the following blocks **inside Claude Code chat**, **not** your shell. Each phase should produce its own `spec.md`, `plan.md`, `tasks.md`, tests and reviewable PR; use the actual active feature convention generated by your Spec Kit version. Execute the next phase only after the preceding acceptance checks pass. Slash commands below follow the current Claude skill installation; if your installed integration differs, inspect its generated `.claude/skills/`.

### Phase 00 — Foundation and VisualCore boundary audit

**Deliverable:** Produce read-only repository inventory; map VisualCore package products, EGL host, render thread, shader/resource APIs, Xcode build steps, actual source ownership and baseline ProjectM regression tests. Record open architectural gaps. Do not modify VisualCore or ProjectM.

**Review / acceptance gates:**
- An evidence-backed integration matrix references real files, symbols and package products
- The app can compile an empty SwiftUI shell before custom graphics integration
- A written stop/go decision identifies anything missing upstream

```text
/speckit-specify For Interactive Anatomy Phase 00 (Foundation and VisualCore boundary audit): Produce read-only repository inventory; map VisualCore package products, EGL host, render thread, shader/resource APIs, Xcode build steps, actual source ownership and baseline ProjectM regression tests. Record open architectural gaps. Do not modify VisualCore or ProjectM. Capture measurable user stories, edge cases, traceability to the brainstorm and negative requirements.
/speckit-clarify Review this Phase 00 spec for unverified VisualCore APIs, permissions, algorithm semantics, performance assumptions and unsupported iOS behavior. Ask only blocking questions; record decisions in spec artifacts.
/speckit-plan Create the Phase 00 technical plan. Give exact app-owned source paths, dependency direction, lifecycle contracts, data schemas, tests, build commands, migration and rollback; reference only APIs verified by the read-only audit.
/speckit-checklist Generate a Phase 00 checklist covering requirements completeness, privacy, architecture ownership, iOS lifecycle, testability, performance and release constraints as applicable.
/speckit-tasks Break Phase 00 into dependency-ordered tasks with specific files, tests, integration acceptance criteria, commit boundaries and review checkpoints.
/speckit-analyze Validate Phase 00 spec/plan/tasks consistency, remove speculative dependencies, identify missing tests, and stop if blockers remain.
/speckit-implement Execute only approved Phase 00 tasks in small groups. For each group implement tests first where sensible, run available build/validation, report changed files and results; do not modify VisualCore without an approved upstream task.
/speckit-converge Compare Phase 00 implementation with requirements and tests, append any unresolved tasks, and produce an evidence-based completion report.
```

**Stop point:** Review the diff, execute the phase-specific tests, and commit only when the phase meets its stated acceptance. In particular, absence of a working VisualCore host is a blocker, not permission to create a second backend.

### Phase 01 — Licensed content inventory and schema

**Deliverable:** Implement licensed content inventory and schema for Interactive Anatomy; scope only the smallest vertical slice that proves the feature, with domain tests, validated render behavior, and documented VisualCore contracts.

**Review / acceptance gates:**
- MVP requirement: One clinically reviewed anatomy region rather than full body at MVP
- Regression fixture: Every displayed label maps to an existing mesh/structure ID
- The app keeps EGL/context ownership solely in the audited VisualCore host

```text
/speckit-specify For Interactive Anatomy Phase 01 (Licensed content inventory and schema): Implement licensed content inventory and schema for Interactive Anatomy; scope only the smallest vertical slice that proves the feature, with domain tests, validated render behavior, and documented VisualCore contracts. Capture measurable user stories, edge cases, traceability to the brainstorm and negative requirements.
/speckit-clarify Review this Phase 01 spec for unverified VisualCore APIs, permissions, algorithm semantics, performance assumptions and unsupported iOS behavior. Ask only blocking questions; record decisions in spec artifacts.
/speckit-plan Create the Phase 01 technical plan. Give exact app-owned source paths, dependency direction, lifecycle contracts, data schemas, tests, build commands, migration and rollback; reference only APIs verified by the read-only audit.
/speckit-checklist Generate a Phase 01 checklist covering requirements completeness, privacy, architecture ownership, iOS lifecycle, testability, performance and release constraints as applicable.
/speckit-tasks Break Phase 01 into dependency-ordered tasks with specific files, tests, integration acceptance criteria, commit boundaries and review checkpoints.
/speckit-analyze Validate Phase 01 spec/plan/tasks consistency, remove speculative dependencies, identify missing tests, and stop if blockers remain.
/speckit-implement Execute only approved Phase 01 tasks in small groups. For each group implement tests first where sensible, run available build/validation, report changed files and results; do not modify VisualCore without an approved upstream task.
/speckit-converge Compare Phase 01 implementation with requirements and tests, append any unresolved tasks, and produce an evidence-based completion report.
```

**Stop point:** Review the diff, execute the phase-specific tests, and commit only when the phase meets its stated acceptance. In particular, absence of a working VisualCore host is a blocker, not permission to create a second backend.

### Phase 02 — Region scene/selection renderer

**Deliverable:** Implement region scene/selection renderer for Interactive Anatomy; scope only the smallest vertical slice that proves the feature, with domain tests, validated render behavior, and documented VisualCore contracts.

**Review / acceptance gates:**
- MVP requirement: Toggleable layered mesh groups and accessible structure list
- Regression fixture: Toggling layers never makes hidden structures selectable
- The app keeps EGL/context ownership solely in the audited VisualCore host

```text
/speckit-specify For Interactive Anatomy Phase 02 (Region scene/selection renderer): Implement region scene/selection renderer for Interactive Anatomy; scope only the smallest vertical slice that proves the feature, with domain tests, validated render behavior, and documented VisualCore contracts. Capture measurable user stories, edge cases, traceability to the brainstorm and negative requirements.
/speckit-clarify Review this Phase 02 spec for unverified VisualCore APIs, permissions, algorithm semantics, performance assumptions and unsupported iOS behavior. Ask only blocking questions; record decisions in spec artifacts.
/speckit-plan Create the Phase 02 technical plan. Give exact app-owned source paths, dependency direction, lifecycle contracts, data schemas, tests, build commands, migration and rollback; reference only APIs verified by the read-only audit.
/speckit-checklist Generate a Phase 02 checklist covering requirements completeness, privacy, architecture ownership, iOS lifecycle, testability, performance and release constraints as applicable.
/speckit-tasks Break Phase 02 into dependency-ordered tasks with specific files, tests, integration acceptance criteria, commit boundaries and review checkpoints.
/speckit-analyze Validate Phase 02 spec/plan/tasks consistency, remove speculative dependencies, identify missing tests, and stop if blockers remain.
/speckit-implement Execute only approved Phase 02 tasks in small groups. For each group implement tests first where sensible, run available build/validation, report changed files and results; do not modify VisualCore without an approved upstream task.
/speckit-converge Compare Phase 02 implementation with requirements and tests, append any unresolved tasks, and produce an evidence-based completion report.
```

**Stop point:** Review the diff, execute the phase-specific tests, and commit only when the phase meets its stated acceptance. In particular, absence of a working VisualCore host is a blocker, not permission to create a second backend.

### Phase 03 — Layers, search and descriptions

**Deliverable:** Implement layers, search and descriptions for Interactive Anatomy; scope only the smallest vertical slice that proves the feature, with domain tests, validated render behavior, and documented VisualCore contracts.

**Review / acceptance gates:**
- MVP requirement: Selection highlighting, labels and searchable metadata
- Regression fixture: Search synonyms resolve to the intended structure
- The app keeps EGL/context ownership solely in the audited VisualCore host

```text
/speckit-specify For Interactive Anatomy Phase 03 (Layers, search and descriptions): Implement layers, search and descriptions for Interactive Anatomy; scope only the smallest vertical slice that proves the feature, with domain tests, validated render behavior, and documented VisualCore contracts. Capture measurable user stories, edge cases, traceability to the brainstorm and negative requirements.
/speckit-clarify Review this Phase 03 spec for unverified VisualCore APIs, permissions, algorithm semantics, performance assumptions and unsupported iOS behavior. Ask only blocking questions; record decisions in spec artifacts.
/speckit-plan Create the Phase 03 technical plan. Give exact app-owned source paths, dependency direction, lifecycle contracts, data schemas, tests, build commands, migration and rollback; reference only APIs verified by the read-only audit.
/speckit-checklist Generate a Phase 03 checklist covering requirements completeness, privacy, architecture ownership, iOS lifecycle, testability, performance and release constraints as applicable.
/speckit-tasks Break Phase 03 into dependency-ordered tasks with specific files, tests, integration acceptance criteria, commit boundaries and review checkpoints.
/speckit-analyze Validate Phase 03 spec/plan/tasks consistency, remove speculative dependencies, identify missing tests, and stop if blockers remain.
/speckit-implement Execute only approved Phase 03 tasks in small groups. For each group implement tests first where sensible, run available build/validation, report changed files and results; do not modify VisualCore without an approved upstream task.
/speckit-converge Compare Phase 03 implementation with requirements and tests, append any unresolved tasks, and produce an evidence-based completion report.
```

**Stop point:** Review the diff, execute the phase-specific tests, and commit only when the phase meets its stated acceptance. In particular, absence of a working VisualCore host is a blocker, not permission to create a second backend.

### Phase 04 — Accessibility and offline content

**Deliverable:** Implement accessibility and offline content for Interactive Anatomy; scope only the smallest vertical slice that proves the feature, with domain tests, validated render behavior, and documented VisualCore contracts.

**Review / acceptance gates:**
- MVP requirement: Camera orbit/zoom and isolation/ghost controls
- Regression fixture: Asset provenance records license and review status
- The app keeps EGL/context ownership solely in the audited VisualCore host

```text
/speckit-specify For Interactive Anatomy Phase 04 (Accessibility and offline content): Implement accessibility and offline content for Interactive Anatomy; scope only the smallest vertical slice that proves the feature, with domain tests, validated render behavior, and documented VisualCore contracts. Capture measurable user stories, edge cases, traceability to the brainstorm and negative requirements.
/speckit-clarify Review this Phase 04 spec for unverified VisualCore APIs, permissions, algorithm semantics, performance assumptions and unsupported iOS behavior. Ask only blocking questions; record decisions in spec artifacts.
/speckit-plan Create the Phase 04 technical plan. Give exact app-owned source paths, dependency direction, lifecycle contracts, data schemas, tests, build commands, migration and rollback; reference only APIs verified by the read-only audit.
/speckit-checklist Generate a Phase 04 checklist covering requirements completeness, privacy, architecture ownership, iOS lifecycle, testability, performance and release constraints as applicable.
/speckit-tasks Break Phase 04 into dependency-ordered tasks with specific files, tests, integration acceptance criteria, commit boundaries and review checkpoints.
/speckit-analyze Validate Phase 04 spec/plan/tasks consistency, remove speculative dependencies, identify missing tests, and stop if blockers remain.
/speckit-implement Execute only approved Phase 04 tasks in small groups. For each group implement tests first where sensible, run available build/validation, report changed files and results; do not modify VisualCore without an approved upstream task.
/speckit-converge Compare Phase 04 implementation with requirements and tests, append any unresolved tasks, and produce an evidence-based completion report.
```

**Stop point:** Review the diff, execute the phase-specific tests, and commit only when the phase meets its stated acceptance. In particular, absence of a working VisualCore host is a blocker, not permission to create a second backend.

### Phase 05 — Scientific review and device QA

**Deliverable:** Implement scientific review and device qa for Interactive Anatomy; scope only the smallest vertical slice that proves the feature, with domain tests, validated render behavior, and documented VisualCore contracts.

**Review / acceptance gates:**
- MVP requirement: Reviewed factual text with citations and content provenance
- Regression fixture: VoiceOver structure list works without relying on 3D touch picking
- The app keeps EGL/context ownership solely in the audited VisualCore host

```text
/speckit-specify For Interactive Anatomy Phase 05 (Scientific review and device QA): Implement scientific review and device qa for Interactive Anatomy; scope only the smallest vertical slice that proves the feature, with domain tests, validated render behavior, and documented VisualCore contracts. Capture measurable user stories, edge cases, traceability to the brainstorm and negative requirements.
/speckit-clarify Review this Phase 05 spec for unverified VisualCore APIs, permissions, algorithm semantics, performance assumptions and unsupported iOS behavior. Ask only blocking questions; record decisions in spec artifacts.
/speckit-plan Create the Phase 05 technical plan. Give exact app-owned source paths, dependency direction, lifecycle contracts, data schemas, tests, build commands, migration and rollback; reference only APIs verified by the read-only audit.
/speckit-checklist Generate a Phase 05 checklist covering requirements completeness, privacy, architecture ownership, iOS lifecycle, testability, performance and release constraints as applicable.
/speckit-tasks Break Phase 05 into dependency-ordered tasks with specific files, tests, integration acceptance criteria, commit boundaries and review checkpoints.
/speckit-analyze Validate Phase 05 spec/plan/tasks consistency, remove speculative dependencies, identify missing tests, and stop if blockers remain.
/speckit-implement Execute only approved Phase 05 tasks in small groups. For each group implement tests first where sensible, run available build/validation, report changed files and results; do not modify VisualCore without an approved upstream task.
/speckit-converge Compare Phase 05 implementation with requirements and tests, append any unresolved tasks, and produce an evidence-based completion report.
```

**Stop point:** Review the diff, execute the phase-specific tests, and commit only when the phase meets its stated acceptance. In particular, absence of a working VisualCore host is a blocker, not permission to create a second backend.

### Phase 06 — Final verification, privacy, packaging and release

**Deliverable:** Complete release readiness for Interactive Anatomy: privacy/permission strings, accessibility, App Store asset/credit review, local data migration, CPU/GPU/device tests, crash recovery, and build/archive instructions. No fabricated measured performance claims.

**Review / acceptance gates:**
- Release checklist and artifact inventory are complete
- All required automated and device tests have attached results
- Unsupported promised features are removed from UI and marketing copy

```text
/speckit-specify For Interactive Anatomy Phase 06 (Final verification, privacy, packaging and release): Complete release readiness for Interactive Anatomy: privacy/permission strings, accessibility, App Store asset/credit review, local data migration, CPU/GPU/device tests, crash recovery, and build/archive instructions. No fabricated measured performance claims. Capture measurable user stories, edge cases, traceability to the brainstorm and negative requirements.
/speckit-clarify Review this Phase 06 spec for unverified VisualCore APIs, permissions, algorithm semantics, performance assumptions and unsupported iOS behavior. Ask only blocking questions; record decisions in spec artifacts.
/speckit-plan Create the Phase 06 technical plan. Give exact app-owned source paths, dependency direction, lifecycle contracts, data schemas, tests, build commands, migration and rollback; reference only APIs verified by the read-only audit.
/speckit-checklist Generate a Phase 06 checklist covering requirements completeness, privacy, architecture ownership, iOS lifecycle, testability, performance and release constraints as applicable.
/speckit-tasks Break Phase 06 into dependency-ordered tasks with specific files, tests, integration acceptance criteria, commit boundaries and review checkpoints.
/speckit-analyze Validate Phase 06 spec/plan/tasks consistency, remove speculative dependencies, identify missing tests, and stop if blockers remain.
/speckit-implement Execute only approved Phase 06 tasks in small groups. For each group implement tests first where sensible, run available build/validation, report changed files and results; do not modify VisualCore without an approved upstream task.
/speckit-converge Compare Phase 06 implementation with requirements and tests, append any unresolved tasks, and produce an evidence-based completion report.
```

**Stop point:** Review the diff, execute the phase-specific tests, and commit only when the phase meets its stated acceptance. In particular, absence of a working VisualCore host is a blocker, not permission to create a second backend.

## 10. Bounded Claude execution and Git workflow

**Terminal:**
```bash
git status --short
git diff --check
git diff --stat
git add -A
git commit -m "feat: complete reviewed implementation phase"
git log -3 --oneline
```

**Claude Code chat, at every task boundary:**
```text
Inspect the active Spec Kit tasks file. Implement only the next smallest dependency-complete task group. Before editing, list intended files, known VisualCore API contracts, test commands, and rollback steps. After editing, run tests and report actual results; do not claim device validation without device logs. Stop for review after this group.
```

Do not ask Claude to run all seven phases unattended. Spec Kit artifacts may expose architecture errors or rights/permission issues that materially change the following work. The Git baseline is reviewed per phase; commit evidence and tests in the application repository, and upstream patches separately.

## 11. Domain, renderer and UI verification matrix

| Layer | App-specific test | Evidence / gate |
|---|---|---|
| Pure domain model | Every displayed label maps to an existing mesh/structure ID | Automated fixture or documented physical-device observation with input/version captured |
| Pure domain model | Toggling layers never makes hidden structures selectable | Automated fixture or documented physical-device observation with input/version captured |
| App↔VisualCore integration | Search synonyms resolve to the intended structure | Automated fixture or documented physical-device observation with input/version captured |
| App↔VisualCore integration | Asset provenance records license and review status | Automated fixture or documented physical-device observation with input/version captured |
| Device or end-to-end | VoiceOver structure list works without relying on 3D touch picking | Automated fixture or documented physical-device observation with input/version captured |
| Shared render lifecycle | Repeated renderer create, resize, background, resume, context recovery, release | Device log with no stale EGL/GL handles or persistent GPU memory growth |
| App UI and accessibility | First-session flow, disabled states, Dynamic Type and VoiceOver fallback | UI test + human review on representative iPhone and iPad |
| VisualCore regression | If VisualCore changes, ProjectM remains functional at pinned submodule commit | Existing ProjectM build/smoke log; any difference reviewed |

### Implementation-level fixtures
- Fixture 1: Every displayed label maps to an existing mesh/structure ID.
- Fixture 2: Toggling layers never makes hidden structures selectable.
- Fixture 3: Search synonyms resolve to the intended structure.
- Fixture 4: Asset provenance records license and review status.
- Fixture 5: VoiceOver structure list works without relying on 3D touch picking.

### Simulator and device separation
- CI/simulator: test domain math, model migration, document round trips, permission-denied paths, basic UI and reproducible app builds.
- Physical iPhone/iPad: validate ANGLE Metal path, shader compilation, context loss, high-refresh/low-refresh behavior, thermals, memory, inputs and real audio/device sensor routes if relevant.
- When tests depend on audio, sensors or input permissions, use synthetic fixtures in CI; do not silently substitute test signals for production sources.
- Store exact Xcode, iOS, device, VisualCore revision, ProjectM submodule revision, preset and test duration with performance reports.

## 12. Profiling plan, budgets and graceful fallback

Before specifying absolute fps, startup or memory targets, measure a baseline on the reference app and at least one representative device. Decide thresholds in a separate acceptance ADR; do not publish invented benchmark numbers.

- Load only necessary meshes and reuse materials.
- Measure memory peak on older iPads and during repeated layer changes.
- Offer lower LOD without suppressing clinically important labels.

**Telemetry only as local diagnostics by default:** record per-pass timing if genuinely supported, present interval, app-side CPU duration, memory and resource counts, scene configuration, chosen quality tier and build IDs. Make collection opt-in if data ever leaves the device. Never label CPU timings as GPU timings.

**Fallback policy:** keep the app usable when expensive shader passes fail or a device is below target capability: reduce resolution/passes, use a simpler scene, preserve user state, and display a recoverable explanation. When no VisualCore render host exists, ship a native UI placeholder only for internal integration testing—not a misleading App Store release.

## 13. Risks, privacy, science/platform constraints and licenses

### App-specific risk register
1. **Risk 1:** Medical data mistakes can misinform—review sources and explicitly mark educational use. Document owner, verification method, and a release blocker condition in `docs/decisions/`.
2. **Risk 2:** High-poly purchased assets may have incompatible redistribution rights—audit before coding. Document owner, verification method, and a release blocker condition in `docs/decisions/`.
3. **Risk 3:** 3D labels can overlap—provide searchable native alternative. Document owner, verification method, and a release blocker condition in `docs/decisions/`.

### Cross-cutting obligations
- No private iOS APIs, undocumented system-level audio interception, automatic wallpaper changes or unsupported GPU access; test any requested platform capability against current public documentation.
- Apply least-privilege permission prompts, with useful demo/offline behavior for denied permissions. Document Photos, Files, microphone or audio rights only where that app actually needs them.
- Maintain licenses for ANGLE, VisualCore, ProjectM reference code and all bundled shaders, meshes, textures, fonts, datasets, sound and educational copy. Do not assume upstream assets may be redistributed.
- Use clear scientific/educational caveats wherever simulations or graphics are illustrative. Do not market a toy visualization as an instrument, diagnostic tool or accurate predictive model.
- Validate imported data formats, sizes, paths and schema versions; avoid executing untrusted user code except in the specifically constrained Shader Studio design.

### Content and App Store review checklist
- Document why each permission is necessary and the exact UI path requesting it.
- Provide privacy policy and required app data disclosures based on actual telemetry/storage behavior, not sample text.
- Check all media and code redistribution rights, attribution and trademark rules before the storefront submission.
- Keep claims in marketing and screenshots aligned to implemented working features and measured/attributed facts.

## 14. Xcode project, build, and CI commands

After selecting XcodeGen and writing a real `project.yml` during Phase 0/1, these are executable examples **from this app repo**. Scheme and target names must be confirmed with `xcodebuild -list`; do not assume VisualCore has a particular SPM product name.

```bash
# Use XcodeGen only if project.yml was adopted and reviewed
xcodegen generate
xcodebuild -list -project InteractiveAnatomy.xcodeproj
xcodebuild -project InteractiveAnatomy.xcodeproj -scheme InteractiveAnatomy -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build
xcrun simctl list devices available
SIMULATOR_UDID="$(python3 scripts/select_simulator.py)"
test -n "$SIMULATOR_UDID" || { echo "No available simulator"; exit 1; }
xcodebuild -project InteractiveAnatomy.xcodeproj -scheme InteractiveAnatomy -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" CODE_SIGNING_ALLOWED=NO test
python3 scripts/check_repo.py
```

If the repo uses an `.xcworkspace`, SwiftPM-generated project or a different scheme, inspect it and replace these paths; the test commands above do not constitute successful execution here. Build/sign/archive and test native ANGLE/Metal rendering on macOS with Xcode and a physical device.

### Minimal Python repository audit script

Create `scripts/check_repo.py` during the first phase. It should verify presence of essential architecture documents and app-owned shaders, then print the pinned VisualCore version using an actual resolved dependency file. Do not automatically download code or modify an upstream checkout.

```python
from pathlib import Path
import sys
root = Path(__file__).resolve().parents[1]
required = ["CLAUDE.md", "docs/architecture/visualcore-contract.md"]
missing = [name for name in required if not (root / name).is_file()]
for path in missing:
    print(f"MISSING: {path}", file=sys.stderr)
if missing:
    raise SystemExit(1)
print("Repository guidance and integration contract are present")
```

### Portable Python 3 simulator selection helper

Save as `scripts/select_simulator.py`; it reads `xcrun simctl` JSON and chooses a booted iOS simulator first, otherwise an available iPhone simulator. This helper does not create or boot a device; select/boot one manually if no compatible runtime is installed.

```python
import json
import subprocess
import sys
output = subprocess.check_output(
    ["xcrun", "simctl", "list", "devices", "available", "-j"], text=True)
data = json.loads(output)
devices = [device for runtime, group in data.get("devices", {}).items()
           if "iOS" in runtime for device in group
           if device.get("isAvailable", True) and "iPhone" in device.get("name", "")]
device = next((d for d in devices if d.get("state") == "Booted"),
              devices[0] if devices else None)
if device is None:
    sys.exit("No available iPhone simulator. Check Xcode runtimes.")
print(device["udid"])
```

### Minimal XcodeGen target layout

For a fresh repo, an initial `project.yml` can be generated with the following app-only starter; replace deployment target and bundle ID with validated project values, then add local package products only after the VisualCore audit.

```yaml
name: InteractiveAnatomy
options:
  bundleIdPrefix: com.example.visualcore
targets:
  InteractiveAnatomy:
    type: application
    platform: iOS
    deploymentTarget: "17.0"   # proposal, verify supported OS
    sources:
      - Apps/InteractiveAnatomy
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.example.visualcore.interactive-anatomy
```

Install XcodeGen through its official distribution if not already available, verify `xcodegen --version`, and run `xcodegen generate` only after this file and target source exist. Avoid storing unreviewed private package tokens in `project.yml` or CI.

### Suggested macOS GitHub Actions job (create after actual build validation)

```yaml
name: iOS CI
on: [push, pull_request]
jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Verify Python and repository artifacts
        run: python3 scripts/check_repo.py
      - name: Inspect Xcode and app schemes
        run: xcodebuild -list -project InteractiveAnatomy.xcodeproj
      - name: Build simulator target
        run: xcodebuild -project InteractiveAnatomy.xcodeproj -scheme InteractiveAnatomy -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build
```

Pin CI action revisions and the Xcode version according to your organization’s supply-chain rules; add simulator unit tests and any authenticated VisualCore package fetch only after configuration is proven to work. CI on macOS does not substitute for physical GPU regression testing.

## 15. Acceptance criteria and definition of done

A first-release candidate is acceptable only when **all** of the following can be demonstrated:

- [ ] MVP-01: One clinically reviewed anatomy region rather than full body at MVP.
- [ ] MVP-02: Toggleable layered mesh groups and accessible structure list.
- [ ] MVP-03: Selection highlighting, labels and searchable metadata.
- [ ] MVP-04: Camera orbit/zoom and isolation/ghost controls.
- [ ] MVP-05: Reviewed factual text with citations and content provenance.
- [ ] MVP-06: Download-free offline content pack for initial region.
- [ ] Standalone app uses public audited VisualCore APIs and shared ANGLE/Metal path, not ProjectM-specific engine internals.
- [ ] Render-state serializations are versioned, validated, and safe after background/resume and renderer reset.
- [ ] Native UI is usable with accessibility features; reduced motion and quality controls behave as stated.
- [ ] Domain and integration test cases in §11 pass; unresolved errors are documented, not marked passing.
- [ ] At least one physical device run with recorded build/OS/device metadata validates actual GPU behavior.
- [ ] No unsupported privacy, scientific or platform capability claims remain in the product UI or listing.
- [ ] Bundled third-party code, shaders, assets, educational facts and sounds have reviewed license/source records.
- [ ] Build from a clean macOS checkout succeeds and the final PR contains exact verification commands and results.
- [ ] Any VisualCore changes have their own upstream PR plus before/after ProjectM reference regression evidence.

## 16. Ordered next actions

1. Create a new `InteractiveAnatomy` app repo and initialize the Claude/Spec Kit Python variant (commands in §7).
2. Perform read-only VisualCore package/render-host inspection; resolve actual public APIs and upstream gaps.
3. Save the constitution and app-specific design decisions in reviewed repository artifacts.
4. Run Phase 00 through all eight quality gates; complete any upstream VisualCore feature as a separate, reviewed change.
5. Implement Phase 01 licensed content inventory and schema as the smallest testable vertical slice.
6. Continue the remaining phases one by one; compare every release claim against the acceptance matrix.
7. Archive evidence from physical device validation and review the release privacy/license checklist.

## 17. References and assumptions

- **User-provided architecture:** `README.md` — VisualCore comprehensive architecture and Spec Kit workflow; `AppsBrainstorm.md` — catalog item and product opportunity. This document preserves those conceptual foundations and adds proposed implementation choices; it is not an audit of the actual source repository.
- **Existing ProjectM reference:** https://github.com/Coastrnaut/projectm-ios
- **Spec Kit:** https://github.com/github/spec-kit and https://github.github.com/spec-kit/reference/core.html
- **Claude integration commands:** https://github.github.com/spec-kit/integrations/claude.html (hyphenated `/speckit-*` skills)
- **Apple platform documentation:** https://developer.apple.com/documentation/ — validate API permissions and platform restrictions when implementing.

> **Proposed architecture boundary:** Source-derived facts are limited to the 25 app concepts and VisualCore/ProjectM constraints described in the two provided Markdown documents. All schemas, file names, phase breakdowns, workflows and quality gates in this guide are engineering recommendations requiring repository audit and implementation verification.
