# VisualCore Application Brainstorm

**Document type:** Product strategy and application portfolio brainstorm  
**Project:** VisualCore  
**Foundation:** Existing ProjectM iOS rendering implementation  
**Status:** Exploration and planning  
**Last updated:** 2026-11-09

---

## 1. Executive Summary

VisualCore should become more than a reusable ProjectM renderer. The broader opportunity is to create a general-purpose real-time graphics foundation for iOS applications that can power:

- Music visualization and audio-reactive experiences
- Generative art and creative tools
- Interactive games and entertainment
- Educational and scientific visualization
- Ambient displays and lifestyle applications
- Developer and creator tools

The existing ProjectM iOS implementation provides a valuable starting point: a proven ANGLE-based OpenGL ES rendering pipeline backed by Metal. VisualCore should build on that working foundation rather than replace it, duplicate it, or introduce a parallel renderer without a demonstrated need.

The strategic principle is:

> Build applications that demonstrate different capabilities of the same graphics engine, rather than building several variations of ProjectM.

ProjectM remains the reference application and regression benchmark. New applications should demonstrate that VisualCore is independently useful outside the ProjectM use case.

## 2. Existing Technical Foundation

### 2.1 Rendering architecture

The current ProjectM iOS project already uses ANGLE to provide OpenGL ES rendering through its Metal backend. The proposed architecture is therefore:

```text
iOS Applications
    |
    +-- ProjectM
    +-- VisualCore Studio
    +-- Digital Aquarium
    +-- Simulation Lab
    +-- Future games and creative applications
            |
            v
       VisualCore
       Reusable runtime, graphics services, assets,
       effects, animation, scenes, diagnostics
            |
            v
       Existing ANGLE / EGL / OpenGL ES integration
            |
            v
       ANGLE Metal backend
            |
            v
       Apple Metal GPU
```

### 2.2 Important architectural decisions

- Preserve the existing ANGLE-to-Metal implementation.
- Do not build a second renderer or replace ANGLE as part of the initial foundation.
- Do not treat ANGLE feasibility as an open question; the existing ProjectM application is evidence that the integration works.
- Extract reusable infrastructure around ANGLE, such as EGL lifecycle management, render hosting, resource handling, frame scheduling, diagnostics, and shader asset management.
- Keep ProjectM engine behavior, presets, MilkDrop-specific logic, and ProjectM-specific audio visualization outside the VisualCore core.
- Keep ProjectM working throughout extraction and migration.
- Add native Metal-specific APIs only later, if a concrete use case justifies them.
- Audit the actual repository before making assumptions about package boundaries or implementation details.

### 2.3 VisualCore's intended role

VisualCore is a reusable graphics foundation, not necessarily a full game engine. Its initial scope should be driven by the needs of real applications. It should provide stable services and APIs for rendering, effects, assets, animation, scenes, input, and diagnostics without forcing every application to use every subsystem.

---

## 3. Application Idea Catalog

The following catalog contains 25 candidate applications across six categories. These are product concepts, not commitments to build every application.

### 3.1 Creative and visual applications

These are natural early use cases because they exercise shaders, framebuffers, textures, animation, procedural graphics, and GPU effects.

#### 1. Generative Art Studio

An interactive art application where users create evolving visual compositions using procedural shaders, particles, noise fields, fluid effects, mathematical patterns, and geometric forms.

**VisualCore capabilities exercised:**
- Shader pipelines and shader asset management
- Animation and time-based parameters
- Render targets and framebuffer management
- Procedural textures and geometry
- Presets and user-adjustable parameters
- Touch interaction and gesture controls

**Product opportunity:** A polished creative tool with beautiful built-in scenes, customization, saved compositions, and potentially export or sharing features.

#### 2. Fluid Art Playground

A touch-driven simulation for colorful ink, smoke, liquid, pigment, and flowing visual effects.

**VisualCore capabilities exercised:**
- Ping-pong framebuffers
- Texture feedback
- GPU simulation techniques
- Shader-based advection and diffusion effects
- Touch input as simulation forces
- Color blending and post-processing

**Product opportunity:** A visually satisfying creative toy with simple interactions and high-quality results.

#### 3. Fractal Explorer

An interactive explorer for Mandelbrot and Julia sets, with smooth zooming, animated palettes, and adjustable mathematical parameters.

**VisualCore capabilities exercised:**
- High-resolution fragment shaders
- Coordinate transforms
- Precision management
- Parameter animation
- Color mapping and palette systems

**Product opportunity:** An educational and artistic experience with shareable fractal images and curated explorations.

#### 4. Particle Universe

A creative particle system with gravitational fields, attractors, trails, emitters, touch interaction, and many possible visual arrangements.

**VisualCore capabilities exercised:**
- GPU-oriented particle simulation
- Buffer management
- Instanced rendering
- Blending and trails
- Interaction and simulation parameters

**Product opportunity:** A visually rich sandbox that can serve both as entertainment and as a showcase for GPU capabilities.

#### 5. Infinite Geometry

An application for animated geometric structures, kaleidoscopes, tiling patterns, impossible shapes, and procedural 3D compositions.

**VisualCore capabilities exercised:**
- Geometry rendering
- Shader effects
- Transformations
- Camera controls
- Procedural mesh generation

**Product opportunity:** A distinctive visual toy and generative-art experience.

### 3.2 Music, audio, and entertainment

ProjectM provides a strong starting point, but audio-driven experiences can extend well beyond conventional music visualization.

#### 6. VisualCore Music Lab

A modern music visualization application with waveform displays, spectrum analysis, 3D environments, procedural visual effects, and customizable scenes.

**VisualCore capabilities exercised:**
- Audio-reactive parameters
- Shader effects
- Post-processing
- Animation
- Scene and preset management

**Product opportunity:** A general-purpose visualization product that can share rendering technology with ProjectM without being a ProjectM clone.

#### 7. Audio Odyssey

An experience that transforms music into interactive virtual worlds. Users fly through tunnels, landscapes, particle fields, and environments that respond to sound.

**VisualCore capabilities exercised:**
- 3D scene rendering
- Camera systems
- Audio feature integration
- Procedural environments
- Animation and transitions

**Product opportunity:** An immersive entertainment experience with scene packs and customizable visual journeys.

#### 8. Oscilloscope Studio

A modern interpretation of classic audio oscilloscopes, Lissajous displays, spectrum analyzers, and waveform visualizations.

**VisualCore capabilities exercised:**
- Line rendering
- Waveform buffers
- Real-time data visualization
- Shader effects
- Multiple visualization modes

**Product opportunity:** A focused tool for audio enthusiasts, musicians, and technically curious users.

#### 9. Digital Aquarium

A relaxing interactive environment with procedural fish, aquatic plants, lighting, bubbles, underwater effects, and optional audio-reactive behavior.

**VisualCore capabilities exercised:**
- Sprite and object systems
- Animation
- Procedural environments
- Particles
- Scene management
- Touch interaction

**Product opportunity:** A polished ambient experience with customizable aquariums, creatures, environments, and behaviors.

### 3.3 Games and interactive experiences

These concepts test whether VisualCore can support applications with different rendering, input, and simulation requirements.

#### 10. Neon Arcade

A collection of visually distinctive arcade games built around simple mechanics, glowing effects, particle systems, and procedural backgrounds.

**VisualCore capabilities exercised:**
- 2D rendering
- Particles
- Animation
- Input handling
- Collision visualization
- Scene transitions

**Product opportunity:** A collection of small, polished games with a consistent visual identity.

#### 11. Physics Playground

An interactive sandbox for gravity, collisions, springs, magnets, fluids, and other physical interactions.

**VisualCore capabilities exercised:**
- Scene rendering
- Geometry
- Animation
- Shader-based effects
- Data visualization

**Product opportunity:** An educational and entertaining physics toy.

#### 12. Tiny Worlds

A collection of miniature procedural worlds users can explore, customize, and populate with objects.

**VisualCore capabilities exercised:**
- 3D scenes
- Camera and navigation
- Procedural meshes
- Lighting
- Materials and assets

**Product opportunity:** A creative exploration app with collectible environments and customization.

#### 13. Light Maze

A puzzle game involving beams of light, mirrors, reflections, portals, and dynamic geometric environments.

**VisualCore capabilities exercised:**
- Render targets
- Shaders
- Geometry and transformations
- Touch controls
- Compositing and visual feedback

**Product opportunity:** A visually distinctive puzzle game with increasingly complex mechanics.

### 3.4 Education and scientific visualization

These applications demonstrate that VisualCore can support more than entertainment.

#### 14. Solar System Explorer

An interactive 3D solar system with orbital mechanics, planetary details, time controls, and educational information.

**VisualCore capabilities exercised:**
- 3D scenes
- Camera controls
- Materials and lighting
- Animation
- Time-based simulation

**Product opportunity:** An educational astronomy experience with guided tours and interactive exploration.

#### 15. Molecular Explorer

A 3D viewer for molecules, atoms, bonds, crystal structures, and molecular interactions.

**VisualCore capabilities exercised:**
- Instanced geometry
- Materials
- Camera controls
- Lighting
- Structured scientific data visualization

**Product opportunity:** An educational and reference tool for students and science enthusiasts.

#### 16. Simulation Lab

A visual sandbox for cellular automata, fluid dynamics, reaction-diffusion, wave propagation, and other simulations.

**VisualCore capabilities exercised:**
- GPU simulation techniques using shaders and framebuffer feedback
- Numerical visualization
- Parameter controls
- Data visualization
- Animation and capture

**Product opportunity:** A flexible simulation playground with curated experiments and user-adjustable parameters.

#### 17. Interactive Anatomy

An educational 3D viewer for anatomical models with interactive layers, labels, lighting, and rotation.

**VisualCore capabilities exercised:**
- 3D model rendering
- Textures and materials
- Camera controls
- Lighting
- Labels and overlays

**Product opportunity:** An interactive anatomy reference and learning application.

### 3.5 Ambient, personalization, and lifestyle

These concepts could become polished, approachable consumer applications.

#### 18. Ambient Clock

A customizable clock with animated procedural backgrounds, weather-inspired effects, visual themes, and screen-friendly layouts.

**VisualCore capabilities exercised:**
- Shader backgrounds
- Animation
- Typography integration
- Scene transitions
- Configuration and presets

**Product opportunity:** A beautiful clock and ambient display with premium themes.

#### 19. Living Wallpapers

An application for generating animated visual environments and exporting still images or supported video formats for use as wallpapers and backgrounds.

**VisualCore capabilities exercised:**
- Offscreen rendering
- High-resolution rendering
- Effects and compositing
- Frame capture
- Export pipelines

**Product opportunity:** A creative background generator. Platform restrictions on live wallpaper behavior and export formats must be evaluated before implementation.

#### 20. Digital Zen Garden

A relaxing touch-based experience where users create patterns in sand, arrange stones, and generate evolving natural textures.

**VisualCore capabilities exercised:**
- Touch interaction
- Procedural textures
- Feedback shaders
- Animation
- Save and restore state

**Product opportunity:** A simple, polished relaxation and creativity application.

#### 21. Aurora

A full-screen ambient visual application with auroras, stars, clouds, weather-inspired effects, and customizable scenes.

**VisualCore capabilities exercised:**
- Procedural shaders
- Noise functions
- Particle systems
- Animation
- Blending and compositing

**Product opportunity:** An ambient visual experience with scene themes and optional soundscapes.

### 3.6 Developer and creator tools

These products may have a smaller audience than consumer entertainment applications, but they can make VisualCore more useful as an independently reusable framework.

#### 22. Shader Studio

A mobile shader playground for creating, editing, previewing, and sharing GLSL shaders.

**VisualCore capabilities exercised:**
- Shader compilation
- Diagnostics and error reporting
- Render previews
- Shader asset pipeline
- Parameter controls

**Product opportunity:** A focused creative coding tool. Mobile text editing and shader debugging UX will be important design challenges.

#### 23. Visual Programming Lab

A node-based visual programming environment for building interactive graphics without writing code.

**VisualCore capabilities exercised:**
- Render graph
- Compositing
- Parameter system
- Reusable effects
- Graph serialization

**Product opportunity:** A more ambitious creative tool that could eventually support reusable user-created visual projects.

#### 24. Graphics Benchmark Lab

A technical application for testing GPU performance, shader throughput, fill rate, rendering latency, and memory behavior across Apple devices.

**VisualCore capabilities exercised:**
- GPU timing
- Diagnostics
- Profiling
- Benchmark scenes
- Device and configuration reporting

**Product opportunity:** A developer-oriented utility and an internal performance-regression tool. Benchmark results must clearly distinguish repeatable measurements from device- and thermal-state-dependent observations.

#### 25. Effects Composer

A mobile effects editor where users combine shaders, color grading, distortion, blur, particles, and compositing effects.

**VisualCore capabilities exercised:**
- Render graph
- Framebuffer pipelines
- Shader library
- Effect parameters
- Preset serialization
- Offscreen rendering and export

**Product opportunity:** A creative visual-effects application with reusable effect chains and shareable looks.

---

## 4. Initial Product Prioritization

The following ranking is a strategic first-pass assessment. It is not based on measured App Store conversion, revenue, retention, or competitor analysis. Validate market assumptions before committing significant development resources.

| Rank | Application | Product potential | VisualCore value | Development difficulty | Strategic rationale |
|---:|---|---|---|---|---|
| 1 | Generative Art Studio | Very high | Very high | Medium | Broad visual appeal and exercises core shader/effect infrastructure |
| 2 | Fluid Art Playground | High | Very high | High | Strong interactive demonstration of GPU feedback and simulation |
| 3 | Digital Aquarium | High | High | Medium | Distinct product category and tests object/scene animation |
| 4 | Shader Studio | Medium–high | Very high | High | Directly showcases shader APIs and creator workflows |
| 5 | Digital Zen Garden | High | High | Medium | Focused, accessible interaction and procedural graphics |
| 6 | Audio Odyssey | Medium–high | Very high | High | Extends ProjectM experience into immersive 3D audio-reactive worlds |
| 7 | Particle Universe | Medium–high | Very high | Medium | Strong technical showcase and reusable GPU subsystem |
| 8 | Ambient Clock | High | Medium | Low | Relatively contained product scope and accessible audience |
| 9 | Simulation Lab | Medium–high | Very high | High | Establishes VisualCore as a broader simulation platform |
| 10 | Effects Composer | Medium–high | Very high | High | Could become a powerful creator product, but requires mature render graph and UX |

### 4.1 Selection criteria for a more rigorous ranking

For a future portfolio evaluation, score each application against explicit criteria:

1. **Market demand:** Evidence of user interest and search demand.
2. **Competition:** Number and strength of direct competitors.
3. **Differentiation:** Whether the concept offers a compelling reason to choose it.
4. **Monetization:** Plausible paid, subscription, consumable, or one-time purchase model.
5. **Retention:** Likelihood that users return after initial exploration.
6. **Development cost:** Engineering, design, content, testing, and maintenance effort.
7. **Technical leverage:** Amount of reusable VisualCore capability it exercises.
8. **Time to MVP:** Time required to deliver a polished first release.
9. **Platform fit:** Suitability for iPhone and iPad, including performance and interaction.
10. **Cross-product leverage:** Whether the work unlocks capabilities useful to other applications.

A weighted scoring model should be established before using scores to make investment decisions. Do not confuse a high technical value with high commercial potential.

---

## 5. Recommended Application Portfolio

Rather than building all 25 concepts, start with a small portfolio that validates different aspects of VisualCore and has plausible standalone product potential.

### 5.1 First product: VisualCore Studio

**Purpose:** Flagship demonstration and first independent application built on VisualCore.

Combine:
- Procedural art
- Fractals
- Particle effects
- Fluid-inspired effects
- Geometric patterns
- User-created compositions
- Presets and saved scenes

**Why first:**

It validates shader management, render targets, animation, effect composition, presets, and touch interaction without requiring a complete 3D game engine.

**Initial MVP concept:**
- A curated gallery of visual scenes
- Real-time interactive parameters
- Color and palette controls
- Save and restore favorite configurations
- Smooth transitions between scenes
- Export still images, where supported
- Performance and quality settings

**Potential later features:**
- User-created shader scenes
- Layered effects
- Scene sharing
- Video export
- Optional audio-reactive inputs
- Creator-oriented editing tools

### 5.2 Second product: Digital Aquarium

**Purpose:** Demonstrate that VisualCore supports a different application architecture, not just shader galleries.

Potential features:
- Procedural or animated fish
- Aquatic plants and environmental objects
- Water, bubbles, caustics, and lighting effects
- Multiple aquarium environments
- User interaction with creatures
- Customizable themes
- Optional audio-reactive behavior

**Why second:**

It validates sprites or objects, animation, scene management, environmental effects, and interaction.

### 5.3 Third product: Simulation Lab

**Purpose:** Establish VisualCore as a serious graphics and simulation platform.

Potential experiments:
- Cellular automata
- Reaction-diffusion
- Fluid-inspired simulations
- Wave propagation
- Particle systems
- Procedural growth
- Other shader-driven numerical visualizations

**Why third:**

It validates GPU-driven simulation patterns and parameterized experiments. It also creates reusable examples and test scenes for the framework.

### 5.4 Additional products after the first three

- **Shader Studio:** Creator-facing shader editing, compilation diagnostics, and sharing.
- **Audio Odyssey:** Immersive audio-reactive 3D environments.
- **Digital Zen Garden:** A focused, approachable consumer application.
- **Effects Composer:** A more advanced compositing and effects product.

---

## 6. VisualCore Capability-to-Application Validation Matrix

Every major VisualCore capability should have a real application use case and a test. This prevents the framework from becoming a collection of abstractions that only serve ProjectM.

| VisualCore capability | Best application to validate it | Example validation |
|---|---|---|
| ANGLE / EGL lifecycle | All applications | Repeated creation, suspension, resume, and teardown |
| Shader compilation and caching | VisualCore Studio | Compile, cache, invalidate, and report shader errors |
| Framebuffer management | Fluid Art Playground | Allocate, resize, bind, and release render targets |
| Texture feedback | Fluid Art Playground | Stable multi-frame feedback without unintended artifacts |
| GPU particle systems | Particle Universe | Sustained particle updates and rendering |
| 2D sprite rendering | Digital Aquarium | Animate and render many independent objects |
| 3D camera and scene management | Audio Odyssey | Camera movement, transforms, and scene transitions |
| Lighting and materials | Tiny Worlds | Consistent material and lighting behavior |
| Audio-reactive rendering | Music Lab | Stable delivery of audio-derived parameters to rendering |
| Input and gestures | Digital Zen Garden | Touch input, gesture mapping, and interaction latency |
| Offscreen rendering | Living Wallpapers | Render frames without a visible display surface |
| Render graph and compositing | Effects Composer | Compose multiple effects and manage dependencies |
| GPU profiling | Graphics Benchmark Lab | Collect repeatable timing and frame metrics |
| Resource and asset management | Digital Aquarium | Load, cache, release, and recover assets |
| Preset and scene serialization | VisualCore Studio | Save, load, validate, and migrate scene configurations |

### 6.1 Acceptance principle

A framework capability should not be considered complete merely because its API exists. It should have:

- At least one real application use case
- A defined behavioral contract
- Unit or integration coverage where practical
- A sample or showcase demonstrating correct use
- Lifecycle and error-handling behavior
- Performance measurements where relevant
- Documentation for consumers

---

## 7. Proposed VisualCore Module Ecosystem

These are candidate responsibilities, not a mandate to create one package per heading. Repository audit and application requirements should determine actual package boundaries.

### 7.1 VisualCore Runtime

Responsible for:
- ANGLE/EGL initialization and lifecycle
- Render surface and host integration
- Context and surface ownership
- Frame scheduling
- Synchronization and lifecycle transitions
- Common runtime configuration

### 7.2 VisualCore Graphics

Responsible for:
- Shader programs
- Textures
- Buffers
- Framebuffers
- Geometry
- Materials and rendering state
- Common OpenGL ES resource abstractions

### 7.3 VisualCore Effects

Responsible for:
- Blur
- Bloom
- Distortion
- Color grading
- Feedback effects
- Compositing
- Reusable shader-based post-processing

### 7.4 VisualCore Animation

Responsible for:
- Timelines
- Interpolation
- Easing
- Transitions
- Procedural animation
- Time-based parameter control

### 7.5 VisualCore Particles

Responsible for:
- Particle emitters
- Particle state
- GPU-oriented particle updates
- Trails and blending
- Forces and attractors
- Particle rendering

### 7.6 VisualCore Scenes

Responsible for:
- 2D and 3D scene organization
- Camera systems
- Transforms
- Scene lifecycle
- Object and component organization, if justified
- Scene transitions

### 7.7 VisualCore Audio

Responsible for:
- Audio feature interfaces
- Audio-derived visualization parameters
- Time-aligned parameter delivery
- Optional audio-reactive examples

ProjectM-specific audio processing should remain in the ProjectM integration unless it is genuinely generic.

### 7.8 VisualCore Assets

Responsible for:
- Shader asset loading
- Texture and image loading
- Model and geometry assets
- Preset and scene resources
- Resource caching and lifecycle
- Asset validation

### 7.9 VisualCore Diagnostics

Responsible for:
- GPU timing and performance metrics
- Frame rate and frame pacing
- Resource usage observations
- Shader compilation diagnostics
- Debug overlays
- Device and configuration reporting

---

## 8. Suggested Development Roadmap

The roadmap below is designed to build on the existing ProjectM iOS framework while keeping the new VisualCore repository independently consumable.

### Phase 0 — Repository and rendering audit

**Goal:** Understand the existing ProjectM repository and establish a trustworthy baseline.

Tasks:
- Add the ProjectM iOS repository as a Git submodule.
- Record the submodule URL, branch or pinned commit, and update policy.
- Inspect its package structure, build configuration, vendor dependencies, and existing documentation.
- Trace application startup through EGL context and surface creation.
- Trace OpenGL ES rendering through ANGLE's Metal backend to presentation.
- Identify render-loop ownership and lifecycle transitions.
- Inventory shaders, textures, framebuffers, buffers, and resource management.
- Identify reusable input, audio, asset, and diagnostics code.
- Build and run the existing application on a supported macOS/Xcode environment.
- Record baseline behavior and performance observations.

Deliverables:
- Repository audit
- Current rendering pipeline document
- Reusable component inventory
- VisualCore gap analysis
- Build and regression baseline

**Constraint:** Audit first. Do not modify production renderer code during the initial audit.

### Phase 1 — Extract shared ANGLE/EGL integration

**Goal:** Make the existing rendering integration consumable by VisualCore without changing its behavior.

Tasks:
- Identify the narrowest reusable boundary around ANGLE and EGL.
- Centralize context and surface lifecycle services where justified.
- Define ownership and teardown rules.
- Preserve the existing ANGLE version and configuration.
- Add regression tests or test harnesses around lifecycle operations.
- Keep ProjectM building and rendering throughout the extraction.

Deliverables:
- Reusable runtime integration
- Documented lifecycle contracts
- ProjectM regression validation

### Phase 2 — Establish VisualCore shared APIs

**Goal:** Create stable interfaces for common graphics services.

Candidate areas:
- Render host
- Frame scheduling
- Shader asset loading and compilation
- Texture and framebuffer lifecycle
- Resource management
- Input abstraction
- Timing and animation primitives
- Diagnostics and error reporting

Avoid adding APIs that do not yet have a concrete consumer.

### Phase 3 — Migrate ProjectM incrementally

**Goal:** Make ProjectM consume VisualCore without rewriting its rendering engine.

Tasks:
- Add a ProjectM adapter or integration layer.
- Replace one reusable service at a time.
- Keep ProjectM-specific engine and preset behavior in ProjectM.
- Compare output and lifecycle behavior before and after each migration.
- Keep the existing application usable as the reference benchmark.

Deliverables:
- ProjectM using selected VisualCore services
- Regression results
- Migration documentation

### Phase 4 — Build reusable shader and effects infrastructure

**Goal:** Support creative applications through a reusable GLSL and framebuffer pipeline.

Tasks:
- Shader asset and compilation management
- Shader diagnostics
- Render target abstractions
- Ping-pong framebuffer utilities
- Reusable post-processing effects
- Parameter binding and animation
- Preset serialization

First consumer: VisualCore Studio.

### Phase 5 — Add reusable scenes, particles, and interaction

**Goal:** Expand beyond full-screen shader effects.

Tasks:
- 2D object and sprite rendering
- Animation and timeline services
- Particle emitters and update strategies
- Camera and transform primitives
- Basic 3D scene services if justified
- Touch and gesture integration
- Scene lifecycle and transitions

Potential consumers: Digital Aquarium, Particle Universe, Tiny Worlds.

### Phase 6 — Build the independent VisualCore Studio application

**Goal:** Prove that VisualCore can support a new application without depending on ProjectM-specific engine behavior.

Tasks:
- Create a standalone app target.
- Consume VisualCore modules.
- Implement a curated scene gallery.
- Add parameter controls and presets.
- Add scene transitions and save/restore.
- Add image export if supported.
- Validate memory, performance, and lifecycle behavior.

**Critical acceptance test:** The standalone app must not require ProjectM engine or preset code to run.

### Phase 7 — Build Simulation Lab

**Goal:** Validate GPU-driven simulation and more demanding framebuffer workflows.

Tasks:
- Create a common simulation interface where useful.
- Implement cellular automata and reaction-diffusion examples.
- Add fluid-inspired or particle experiments.
- Add simulation parameter controls.
- Add reset, pause, and step controls.
- Profile performance and resource use.

### Phase 8 — Build Digital Aquarium

**Goal:** Validate object-centric scenes and a different product architecture.

Tasks:
- Scene and object lifecycle
- Animated creatures and environmental elements
- Water and lighting effects
- Interaction
- Asset loading and caching
- Scene persistence

### Phase 9 — Stabilize, document, and release VisualCore

**Goal:** Make VisualCore maintainable and usable by future applications.

Tasks:
- Public API review
- Module dependency review
- Documentation and examples
- Compatibility policy
- Dependency and license review
- CI and device validation
- Performance baselines
- Release packaging and versioning

---

## 9. Repository and Project Organization Considerations

The new VisualCore repository should integrate ProjectM as a submodule rather than copying its source into the new repository.

An illustrative layout:

```text
VisualCore/
├── .claude/
│   └── skills/
├── .github/
│   └── workflows/
├── .specify/
├── Apps/
│   ├── VisualCoreStudio/
│   ├── SimulationLab/
│   └── DigitalAquarium/
├── Packages/
│   ├── VisualCoreRuntime/
│   ├── VisualCoreGraphics/
│   ├── VisualCoreEffects/
│   ├── VisualCoreAnimation/
│   ├── VisualCoreParticles/
│   ├── VisualCoreScenes/
│   ├── VisualCoreAssets/
│   └── VisualCoreDiagnostics/
├── Integrations/
│   └── ProjectM/
├── Submodules/
│   └── projectm-ios/
├── Examples/
├── Tests/
├── docs/
│   ├── architecture/
│   ├── applications/
│   ├── decisions/
│   └── development/
├── scripts/
├── .gitmodules
├── CLAUDE.md
├── README.md
└── project.yml
```

This is illustrative. The actual layout should be adapted to the existing ProjectM repository, XcodeGen configuration, Swift package organization, and build tooling.

### 9.1 Submodule setup example

```bash
git submodule add https://github.com/Coastrnaut/projectm-ios.git Submodules/projectm-ios
git submodule update --init --recursive
git add .gitmodules Submodules/projectm-ios
git commit -m "Add ProjectM iOS reference implementation as submodule"
```

The superproject records a specific submodule commit. Updating the submodule should be a deliberate change with build and regression validation.

Example update workflow:

```bash
git submodule update --remote --merge Submodules/projectm-ios
git diff --submodule
git status
```

Do not automatically track a moving upstream branch in production builds without reviewing the resulting submodule commit.

---

## 10. Spec Kit and Claude Code Implementation Strategy

Use GitHub Spec Kit to make each phase an explicit, reviewable unit of work. Use Claude Code to inspect the repository, author specifications, plan changes, implement bounded tasks, and validate results.

Do not assume every Spec Kit installation has identical command names or options. First inspect the installed version and the repository's existing configuration.

### 10.1 Initial setup

Install and verify the tools according to their current official documentation. Then, from the new VisualCore repository:

```bash
git init
git submodule add https://github.com/Coastrnaut/projectm-ios.git Submodules/projectm-ios
git submodule update --init --recursive
```

Inspect the available Spec Kit commands:

```bash
specify --help
specify version
```

If Spec Kit is not initialized in the new repository, initialize it using the currently supported command and Claude Code agent option shown by `specify --help`. For example, installations commonly use a form similar to:

```bash
specify init . --ai claude
```

Verify the exact supported syntax for the installed release before executing it. Do not overwrite an existing configuration.

Start Claude Code from the VisualCore repository root:

```bash
claude
```

### 10.2 Suggested Spec Kit workflow

The following slash commands represent the commonly used Spec Kit workflow. Confirm the actual commands installed in the repository before running them:

```text
/speckit.constitution
/speckit.specify
/speckit.clarify
/speckit.plan
/speckit.checklist
/speckit.tasks
/speckit.analyze
/speckit.implement
```

Some installations use hyphenated command names, such as `/speckit-constitution` and `/speckit-implement`. Use the command names supplied by the installed Claude Code skills rather than blindly copying examples.

### 10.3 Constitution prompt

Use a constitution that establishes these project-wide rules:

```text
Create the VisualCore project constitution.

Project context:
VisualCore is a reusable iOS graphics foundation built around the
existing ProjectM iOS rendering implementation.

The existing ProjectM application already uses ANGLE to render
OpenGL ES through ANGLE's Metal backend.

Non-negotiable principles:
1. Preserve the existing ANGLE-to-Metal rendering implementation.
2. Do not introduce a second renderer without an approved, concrete
   requirement.
3. Keep ProjectM-specific engine, preset, and MilkDrop behavior out
   of VisualCore core modules.
4. Keep ProjectM building and functioning during every migration.
5. Audit before refactoring.
6. Every abstraction must have a concrete consumer or test use case.
7. Keep VisualCore independently consumable by applications that do
   not depend on ProjectM.
8. Document module boundaries and dependency direction.
9. Validate lifecycle, memory, and performance on supported Apple
   devices.
10. Preserve third-party licensing and dependency notices.

Require specifications, plans, tasks, tests, and documentation for
meaningful architectural changes.
```

### 10.4 Phase 0: Repository audit

Start with an audit-only specification:

```text
/speckit.specify
```

Prompt:

```text
Specify Phase 0: Audit the ProjectM iOS submodule and establish the
VisualCore architecture baseline.

The ProjectM iOS repository is included as a Git submodule.

Inspect:
- Repository structure and build configuration
- Swift, C++, Objective-C++, EGL, ANGLE, OpenGL ES, and Metal code
- ANGLE revision and configuration
- Context and surface lifecycle
- Render loop and presentation
- Shader, texture, buffer, and framebuffer management
- Input and touch integration
- Audio-to-render pipeline
- Resource management
- Tests, CI, scripts, and third-party licenses

Trace the actual rendering path from app initialization through
EGL/OpenGL ES, ANGLE's Metal backend, and presentation.

Identify reusable infrastructure and ProjectM-specific behavior.

Do not modify production source code.

Produce:
- docs/architecture/repository-audit.md
- docs/architecture/current-rendering-pipeline.md
- docs/architecture/reusable-component-inventory.md
- docs/architecture/visualcore-gap-analysis.md

Every finding must reference actual repository paths and symbols.
```

Then run the installed clarify, plan, tasks, and analyze commands. Phase 0 should not proceed to implementation until the baseline and findings are reviewed.

### 10.5 Phase 1: Extract ANGLE/EGL integration

Specification prompt:

```text
Specify the extraction of reusable ANGLE/EGL runtime integration
from the ProjectM reference implementation.

Preserve the existing ANGLE version, Metal backend, configuration,
and working rendering behavior.

Identify and extract only reusable integration responsibilities:
- EGL context lifecycle
- EGL surface lifecycle
- Render host integration
- Frame scheduling
- Synchronization
- Resource teardown
- Error reporting and diagnostics

Do not fork or rewrite ANGLE.
Do not create a replacement renderer.
Do not migrate ProjectM-specific engine logic.

Require ProjectM regression validation before and after each
meaningful extraction.
```

### 10.6 Phase 2: VisualCore shared APIs

Specification prompt:

```text
Specify the first stable VisualCore API layer.

Use Phase 0 audit findings and Phase 1 implementation as the source
of truth.

Evaluate candidate APIs for:
- Render host and lifecycle
- Frame scheduling
- Shader assets and compilation
- Texture and framebuffer lifecycle
- Resource management
- Timing and animation
- Input integration
- Diagnostics

Do not create a module solely because it appears in a proposed
architecture diagram. Every API must have a concrete consumer,
test, or documented near-term requirement.

Define ownership, threading, error handling, lifecycle, and
compatibility expectations.
```

### 10.7 Phase 3: ProjectM migration

Specification prompt:

```text
Specify the incremental migration of ProjectM to VisualCore.

ProjectM remains a working reference application and regression
benchmark.

Move one reusable responsibility at a time behind VisualCore APIs.
Keep ProjectM engine, presets, MilkDrop-specific behavior, and
application-specific audio processing in ProjectM.

For every migration:
- Preserve rendering output and lifecycle behavior.
- Define rollback boundaries.
- Add or update tests.
- Build and run the ProjectM application.
- Document the migrated responsibility.

Do not rewrite the renderer.
```

### 10.8 Phase 4: Shader and effects infrastructure

Specification prompt:

```text
Specify reusable shader and effects infrastructure for VisualCore.

Required areas:
- Shader asset loading
- Shader compilation and diagnostics
- Shader program lifecycle
- Texture and framebuffer abstractions
- Ping-pong framebuffer utilities
- Post-processing effects
- Effect parameter interfaces
- Animation of effect parameters
- Preset serialization

Use VisualCore Studio as the first independent consumer.

Keep APIs compatible with the existing ANGLE/OpenGL ES implementation.
```

### 10.9 Phase 5: Scenes, particles, and interaction

Specification prompt:

```text
Specify the next VisualCore capabilities for object-centric and
interactive graphics applications.

Evaluate:
- 2D object and sprite rendering
- Animation and timeline services
- Particle emitters and update strategies
- Camera and transform primitives
- Scene lifecycle and transitions
- Touch and gesture integration
- Basic 3D scene services where justified

Use Digital Aquarium, Particle Universe, and Tiny Worlds as
candidate consumers.

Do not introduce a complete game-engine architecture unless
application requirements demonstrate that it is necessary.
```

### 10.10 Phase 6: VisualCore Studio application

Specification prompt:

```text
Specify VisualCore Studio as the first standalone application
built on VisualCore.

It must not depend on ProjectM engine or preset code.

MVP:
- Curated gallery of procedural visual scenes
- Interactive parameter controls
- Color and palette controls
- Preset save and restore
- Smooth scene transitions
- Quality and performance settings
- Image export where supported

Use VisualCore APIs rather than embedding application-specific
graphics infrastructure in the app target.

The application must demonstrate independent consumption of the
VisualCore framework.
```

### 10.11 Phase 7: Simulation Lab

Specification prompt:

```text
Specify Simulation Lab as a standalone VisualCore application.

Initial experiments:
- Cellular automata
- Reaction-diffusion
- Fluid-inspired shader simulations
- Wave propagation
- Particle systems

Provide:
- Start, pause, reset, and step controls where meaningful
- Parameter adjustment
- Reproducible initial conditions where practical
- Performance and quality settings
- Clear explanation of each simulation

Use VisualCore's reusable rendering and resource APIs.
Do not couple the application to ProjectM.
```

### 10.12 Phase 8: Digital Aquarium

Specification prompt:

```text
Specify Digital Aquarium as an independent VisualCore application.

Initial capabilities:
- Animated fish or aquatic creatures
- Plants and environmental objects
- Water, bubbles, lighting, and visual effects
- Multiple aquarium environments
- User interaction
- Scene persistence
- Asset loading and caching

Use the application to validate object lifecycle, animation,
scene management, and interaction outside the ProjectM use case.
```

### 10.13 Phase 9: Stabilization and release

Specification prompt:

```text
Specify VisualCore stabilization and release readiness.

Cover:
- Public API review
- Module dependency review
- Documentation and sample applications
- Compatibility and versioning policy
- Dependency and license review
- CI and supported-device validation
- Performance baselines
- Memory and lifecycle testing
- Release packaging
- Migration guidance for future applications

Require evidence that VisualCore can be consumed by an application
that does not depend on ProjectM.
```

### 10.14 Bounded implementation loop

For each phase or independently testable feature:

1. Run specify.
2. Clarify ambiguities.
3. Run plan.
4. Review the architecture and dependency implications.
5. Run checklist and tasks.
6. Run analyze.
7. Review scope and resolve critical findings.
8. Run implement in bounded increments.
9. Run tests and builds.
10. Inspect the diff and update documentation.
11. Commit the completed work.

Do not ask an agent to implement all phases in one enormous operation. Keep each feature small enough to review and validate.

---

## 11. Claude Code Repository Instructions

The root `CLAUDE.md` should establish durable rules for every Claude Code session.

Suggested content:

```markdown
# VisualCore Development Instructions

## Project identity

VisualCore is a reusable iOS graphics foundation built around the
existing ProjectM iOS rendering implementation.

ProjectM is included as a Git submodule and remains the reference
application and regression benchmark.

## Rendering foundation

The existing ProjectM implementation uses ANGLE for OpenGL ES
rendering through ANGLE's Metal backend.

Preserve this architecture.

Do not:
- Replace ANGLE.
- Rewrite the existing renderer.
- Introduce a parallel renderer without an approved requirement.
- Copy ProjectM-specific engine logic into VisualCore.
- Assume repository internals without inspecting source.

## Development workflow

- Audit before refactoring.
- Follow the repository's Spec Kit specifications and plans.
- Implement bounded, reviewable tasks.
- Preserve the ProjectM build and runtime.
- Add tests for lifecycle and resource ownership.
- Document public APIs and architectural decisions.
- Verify third-party licenses and notices.

## Architecture

VisualCore must be independently consumable by applications
that do not depend on ProjectM.

ProjectM-specific behavior belongs in the ProjectM application
or its adapter layer.

Do not create abstractions without a concrete consumer or test.
```

---

## 12. Testing and Quality Strategy

### 12.1 Framework tests

Test:
- Context creation and destruction
- Surface creation, resize, and teardown
- Backgrounding and foregrounding
- Device orientation and size changes
- Shader compile failures
- Texture and framebuffer allocation and release
- Resource cache behavior
- Repeated scene creation and destruction
- Error propagation
- Thread and ownership assumptions

### 12.2 Application regression tests

Keep ProjectM as the permanent reference workload. Compare:
- Successful launch and initialization
- Rendering output
- Preset behavior
- Audio-reactive behavior
- Lifecycle transitions
- Memory behavior
- Frame pacing
- Crash and error logs

### 12.3 Performance validation

Use representative scenes and workloads. Record:
- Device model and OS version
- Rendering resolution
- Frame rate and frame-time distribution
- GPU timing where available
- Memory observations
- Thermal conditions
- Test duration
- Visual quality settings

Do not make performance claims from simulator-only testing. Validate on physical hardware.

### 12.4 Platform constraints

- iOS application builds and Metal validation require macOS and Xcode.
- Windows can be used for documentation, planning, and some Python automation, but it cannot replace the macOS/Xcode build and device-validation environment.
- Simulator results do not replace physical-device performance testing.
- Any video or wallpaper export capability must respect platform APIs and restrictions.

---

## 13. Python Automation Opportunities

Python scripts can support repository checks, documentation, and repeatable validation. Keep them focused and avoid using scripts to bypass the build system.

Candidate scripts:

| Script | Purpose |
|---|---|
| `scripts/audit_repository.py` | Inventory source files, targets, packages, shaders, and dependencies |
| `scripts/validate_packages.py` | Check expected module structure and dependency rules |
| `scripts/check_licenses.py` | Inventory third-party licenses and notices |
| `scripts/validate_shaders.py` | Check shader assets and basic metadata |
| `scripts/compare_projectm_baseline.py` | Organize or compare captured regression artifacts |
| `scripts/report_benchmarks.py` | Summarize benchmark results and environment metadata |

The scripts should emit machine-readable results where useful and return nonzero exit codes for actionable validation failures.

---

## 14. Risks and Mitigations

| Risk | Why it matters | Mitigation |
|---|---|---|
| Overengineering VisualCore | Framework work can outgrow real product needs | Require a concrete consumer or test for each abstraction |
| Breaking ProjectM | Existing product behavior is the foundation | Keep it as a regression app and migrate incrementally |
| Duplicating ANGLE integration | Creates competing lifecycle and rendering paths | Preserve and centralize the existing integration |
| ProjectM coupling | Makes VisualCore unusable independently | Enforce module boundaries and build standalone apps |
| Unclear resource ownership | Can cause leaks, stale GPU resources, and lifecycle bugs | Define ownership and teardown contracts |
| GPU performance variability | Devices and thermal states differ | Benchmark physical devices with recorded conditions |
| Excessive product scope | Too many apps delay a useful release | Build a small portfolio in deliberate stages |
| Unvalidated market assumptions | Technical appeal does not guarantee commercial success | Conduct competitor and user research before major investment |
| Platform restrictions | Capture, export, background execution, and wallpaper behavior vary | Verify platform APIs and App Store requirements early |
| Submodule drift | Upstream changes can break the superproject | Pin reviewed commits and validate updates |

---

## 15. Product Strategy and Commercial Considerations

A visually impressive prototype is not automatically a successful App Store product. Each candidate should be evaluated for:

- Clear target audience
- Core user problem or desire
- Distinctive value proposition
- Competitive landscape
- Onboarding and first-session experience
- Reasons to return
- Monetization model
- Content and feature expansion potential
- Support and maintenance costs
- Accessibility and device compatibility

Potential monetization models include:
- Paid application
- Freemium with paid scene or effect packs
- One-time feature unlock
- Subscription for ongoing content or advanced tools
- Creator-oriented paid features

Do not select a subscription model merely because it is common. It should correspond to recurring user value.

---

## 16. Recommended Long-Term Sequence

The recommended sequence is:

1. **ProjectM integration:** Extract reusable ANGLE/EGL integration and lifecycle services while keeping the existing application working.
2. **VisualCore Studio:** Establish shader, texture, framebuffer, effect, and preset APIs.
3. **Fluid Art Playground:** Validate framebuffer feedback, procedural simulation, and GPU-heavy workloads.
4. **Digital Aquarium:** Validate sprites, animation, scene management, and interaction.
5. **Simulation Lab:** Validate numerical simulations, particles, and demanding rendering scenarios.
6. **Shader Studio:** Add creator-facing shader editing, compilation diagnostics, and sharing.
7. **Application ecosystem:** Establish shared asset formats, presets, reusable components, and cross-application services.

VisualCore Studio should be the first new application, while ProjectM remains the permanent regression and reference application.

Together, they demonstrate two important things:

- VisualCore can support an existing sophisticated renderer without forcing a rewrite.
- VisualCore can support a completely independent graphics product without ProjectM-specific dependencies.

---

## 17. Immediate Next Steps

1. Create the new VisualCore Git repository.
2. Add `projectm-ios` as a submodule.
3. Establish the macOS/Xcode build environment.
4. Build and run the unmodified ProjectM reference application.
5. Capture a baseline of rendering behavior and performance.
6. Initialize or verify Spec Kit and Claude Code configuration.
7. Complete the Phase 0 repository and rendering audit.
8. Review the proposed module boundaries against actual source code.
9. Specify and implement only the first justified extraction.
10. Keep the application portfolio as a roadmap, not a commitment to build every concept.

## 18. Final Recommendation

Treat VisualCore as a reusable real-time graphics platform whose capabilities are proven through independent applications.

The most valuable initial portfolio is:

- **ProjectM:** Existing reference implementation and regression benchmark.
- **VisualCore Studio:** First independent creative application.
- **Digital Aquarium:** First object-centric interactive application.
- **Simulation Lab:** First scientific and GPU-simulation application.

This portfolio exercises distinct parts of the architecture without requiring a full game engine or a large number of applications upfront.

The long-term opportunity is not simply to publish several visually interesting apps. It is to create a reusable graphics foundation that makes the next app faster, more consistent, and more capable than the last.
