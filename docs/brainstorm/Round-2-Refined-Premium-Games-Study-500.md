# VisualCore Premium 3D Games — Refined Round 2: 500 Candidates, Code-Only Graphics

**Research baseline:** November 10, 2026 · **Scope:** iOS/iPadOS · **VisualCore path:** existing OpenGL ES → ANGLE → Metal · **Business:** one upfront purchase, no advertising, ad SDKs, IAP or subscriptions.

**Scope of evidence:** 500 ideas assessed, **not** 500 researched apps and **not** 500 prototypes. Exactly 200 concepts preserve the previous research matrix; 300 genuinely new concepts were written and scored against declared genre/technical priors. Numeric scores are screening judgments and are not forecasts, experimental results, consumer surveys or audited sales.

## Executive decision: launch a portfolio of experiments, not 25 clones

The screening examined **500** concepts across **62** explicit scoring criteria. **249** pass every proposed code-only/visual/gameplay gate (**20** from the original 200; **229** from the new 300). **25** enter a diverse portfolio shortlist (**4** inherited; **21** newly proposed). Scores favor genuine shader and procedural spectacle, but *a top-25 ranking is a decision to prototype, not a commitment to publish every candidate*.

### Hard requirements

- Graphics originate in procedural geometry, signed distance fields, GLSL ES, parametric meshes, instancing, particles, lighting, algorithms and simulation. There are **zero AI-generated images**, photographic background plates, manually sculpted characters, purchased level art or commissioned texture requirements.
- Use **only the existing VisualCore / projectM-iOS rendering bridge**, through the established ANGLE Metal backend. Do not replace ANGLE, recreate an independent Metal renderer, or ship different backends for each game.
- The visual effect must materially embody a decision in gameplay: steering, folding, redirecting, growing, balancing, tuning or routing. A screensaver with a score counter does not qualify.
- Every game is complete for an upfront $1.99–$4.99 purchase; no ads anywhere, ad SDKs, rewarded screens, analytics ad identifiers, microtransactions, subscriptions, user accounts or live-services infrastructure.
- All physics and visual render loops are bounded and deterministic enough for automation and adaptive quality on D3. This is an *engineering estimate* pending instrumented device tests.
- A portfolio release must satisfy Apple’s originality and spam guidance: no clones of existing games, and no two VisualCore offerings that differ only by visuals or theme. Similar ideas should be merged into a single substantial game.

### Top 25 ordered for creative/technical prototyping

| # | Candidate | Mechanic family | Heuristic score | Visual score | Price | Distinguishing rule |
|---:|---|---|---:|---:|---:|---|
| 1 | **Aurora Loom** | Light and color | 94.80 | 97.83 | $2.99 | Weave and phase-shift 3D luminous ribbons into target harmonies |
| 2 | **Lissajous Labyrinth** | Wave mathematics | 94.30 | 98.21 | $2.99 | Tune two coupled frequencies so a moving point traces a safe path |
| 3 | **Wave Knot Keeper** | Wave mathematics | 94.30 | 98.21 | $2.99 | Drag spectral control points to untie closed three-dimensional wave knots |
| 4 | **Hue Compass** | Chromatic logic | 94.21 | 98.09 | $2.99 | Rotate a spectral compass to find a hidden target in a colored fog field |
| 5 | **Colorfall Canyons** | Light and color | 94.13 | 97.46 | $2.99 | Carve sluices to direct colored light-fluid into target basins |
| 6 | **Chrono Constellator** | Temporal puzzles | 94.02 | 97.48 | $3.99 | Record and replay a constellation's motion until all stars align |
| 7 | **Amethyst Escape** | Crystal solids | 93.99 | 97.90 | $3.99 | Rotate crystalline layers to open a route for a rolling pearl |
| 8 | **Faceted Forge** | Crystal solids | 93.98 | 97.82 | $3.99 | Place cleavage planes to split a glowing crystal into target solids |
| 9 | **Nocturne Garden** | Shadow construction | 93.96 | 97.82 | $3.99 | Arrange glowing blooms to create a target flower-shaped dark silhouette |
| 10 | **Backwards Aurora** | Temporal puzzles | 93.96 | 97.47 | $3.99 | Correct a hidden signal by reversing sections of an auroral wave |
| 11 | **Echo Cartographer** | Logic and patterns | 93.91 | 96.03 | $3.99 | Touch to emit a pulse, mark reflected obstacles, locate hidden beacons; seeded room… |
| 12 | **Harmonic Bridges** | Acoustic geometry | 93.81 | 97.18 | $3.99 | Tune suspended strings so their resonances solidify walkable bridges |
| 13 | **Acoustic Constellator** | Acoustic geometry | 93.81 | 97.10 | $3.99 | Connect drifting musical nodes so their shared harmonics form celestial diagrams |
| 14 | **Moonlit Mechanism** | Shadow construction | 93.73 | 97.69 | $3.99 | Rotate a clockwork machine until its combined moving shadows spell symbols |
| 15 | **Voxel Origami** | Spatial origami | 93.70 | 97.41 | $3.99 | Reconfigure hinged voxels into a target solid without collisions |
| 16 | **Starlit Cartouche** | Celestial exploration | 93.56 | 97.97 | $3.99 | Connect a moving starship route into a prescribed ancient symbol |
| 17 | **Celestial Eclipse Lab** | Celestial exploration | 93.43 | 97.80 | $3.99 | Position miniature orbits so sequential eclipses form a target sequence |
| 18 | **Apsides Workshop** | Orbital dynamics | 93.14 | 97.37 | $3.99 | Tune orbital eccentricity to sweep precise regions of a miniature sky |
| 19 | **Microscopic Aurora** | Micro ecosystems | 93.06 | 97.60 | $3.99 | Manipulate magnetic swimmers to build a glowing bacterial pattern |
| 20 | **Mushroom Weather** | Micro ecosystems | 93.04 | 97.53 | $3.99 | Arrange fungi to create a stable forest humidity network |
| 21 | **Binary Gardens** | Orbital dynamics | 93.00 | 97.26 | $3.99 | Balance twin stars to keep orbiting flower worlds within a light zone |
| 22 | **Mycelium Architect** | Organic growth | 92.91 | 97.31 | $3.99 | Feed fungal networks so glowing veins form a target graph around rocks |
| 23 | **Erosion Painter** | Terrain alchemy | 92.90 | 97.24 | $3.99 | Raise and lower terrain to coax rain into carving a target canyon |
| 24 | **Crystal Quarry** | Terrain alchemy | 92.90 | 97.24 | $3.99 | Choose fracture paths to reveal a target gem network in rock |
| 25 | **Starlight Surveyors** | Cosmic puzzles | 92.84 | 96.05 | $3.99 | Rotate a 3D observatory until starlight aligns through viewports |

## 1. Market evidence: what is known, and what is not

- **The mobile gaming market is huge, but not a premium-sales forecast.** Sensor Tower’s [State of Gaming 2026](https://sensortower.com/press/press-release-sensor-tower-state-of-gaming-gaming-drove-52-billion-downloads-82b-iap-revenue-on-mobile-and-12b-premium-revenue-on-steam) reports approximately **$82 billion of 2025 mobile game in-app-purchase revenue** and approximately 52 billion game downloads across mobile, PC and consoles. That $82 billion figure does not represent purchases of upfront-priced iOS games. Gaming downloads per minute are a global scale statistic, not a customer acquisition forecast.

- **People demonstrably pay upfront for some mobile games.** Apple’s [2025 U.S. iPhone top-paid list](https://apps.apple.com/us/iphone/room/6756363168) includes Minecraft, Balatro, Geometry Dash, Bloons TD 6, Stardew Valley, and other recognizable products. Those titles are unusually established competitors; no percentage can be inferred for unknown VisualCore games.

- **Premium, calm, visually distinctive desktop mechanics have audience evidence.** [Tiny Glade](https://store.steampowered.com/app/2198150/Tiny_Glade/) and [Dorfromantik](https://store.steampowered.com/app/1455840/Dorfromantik/) have real positive Steam customer reviews; [Mini Metro](https://store.steampowered.com/app/287980/Mini_Metro/) demonstrates a minimalist routing loop; [Glass Masquerade](https://store.steampowered.com/app/511470/Glass_Masquerade/) shows demand for stylized art puzzles; [Poly Bridge 3](https://store.steampowered.com/app/1850160/Poly_Bridge_3/) shows engagement with construction-physics systems. These are **genre precedents, not proposals to copy**.

- **PC platform context, not sales attribution.** The [October 2026 Steam hardware survey](https://store.steampowered.com/hwsurvey/) reported approximately **93.70% Windows, 3.95% Linux and 2.35% macOS** among respondents. A game working across Windows/macOS/Linux helps demonstrate broad design appeal, but these percentages are neither revenue shares nor iOS conversion metrics.

- **Steam visibility does not equal predictable money.** SteamDB’s [relaxing-game catalog](https://steamdb.info/tag/1654/?min_reviews=500) exposes relative review/follower/peak-player measures; pricing and review counts are public but unit sales cannot be inferred reliably by simply multiplying reviews by a constant. This portfolio therefore does not invent per-candidate sales numbers.

### A platform-portability precedent (verified from product listings)

| Comparable PC product | Verified lesson | Porting caveat |
|---|---|---|
| [[Tiny Glade](https://store.steampowered.com/app/2198150/Tiny_Glade/)] | Procedural diorama creation has strong positive reception; its official Steam store lists Windows, macOS and Linux requirements | Its rendering budgets, assets, controls and developer recognition do not automatically carry to iPhone |
| [[Mini Metro](https://store.steampowered.com/app/287980/Mini_Metro/)] | A small visual ruleset can deliver meaningful strategy without elaborate character animation | Its map-driven 2D interaction differs from three-dimensional spectacle |
| [[Dorfromantik](https://store.steampowered.com/app/1455840/Dorfromantik/)] | Geometry and systems can deliver relaxation with decision-making | Procedural 3D landscapes need device-level simplification |
| [[Glass Masquerade](https://store.steampowered.com/app/511470/Glass_Masquerade/)] | Art-led premium puzzles can accumulate a dedicated audience | A new 3D optics game must not mimic protected stained-glass motifs or arrangements |
| [[Poly Bridge 3](https://store.steampowered.com/app/1850160/Poly_Bridge_3/)] | Physics construction can support complete, rule-driven play | A phone needs shorter stages, cheaper simulation and touch-first controls |

## 2. Copyright, App Store policy and the danger of indistinguishable games

The [U.S. Copyright Office](https://www.copyright.gov/register/tx-games.html) says that a game idea or playing method is not itself protected by copyright, but specific artwork, text and other expression can be. This is not a license to reuse game code, exact levels, names, trademarks, audio, distinctive visual identity or copied marketing. Open-source licenses must be audited if any source is considered, and no code from other games is required for the shortlisted titles.

Apple [App Review Guidelines 4.1 and 4.3](https://developer.apple.com/app-store/review/guidelines/) flag copycats and repeated near-identical apps. **The goal is not to flood the App Store with 25 shader reskins.** For every candidate the product team must document one mechanic, one content structure and one user experience that differs materially from every other shipped app; merge overlapping ideas when they do not pass the distinctiveness review.

## 3. All 62 criteria, rubric and score calculation

Each criterion is rated on a **1–5 ordinal judgment scale** (1 = weak, 3 = plausible, 5 = strong). Decimal ratings indicate heuristic prioritization, *not measured accuracy*. Original 200 candidates retain their earlier 50 and 12 ratings; 300 new concepts receive scores from their old-category reference averages plus documented text/trait modifiers (see the included code). No row has its own directly observed purchase conversion data.

**Commercial/engineering subtotal:** `C = 20 × Σ(criterion_rating × original_weight × group_multiplier) / Σ(original_weight × group_multiplier)`, with multipliers Market 0.78, Competition 0.86, Premium 1.00, Experience 1.22, Engineering 1.29.

**Visual subtotal:** `V = 20 × Σ(visual_rating × visual_weight) / Σ(visual_weight)`. **Final screening score:** `0.30 × C + 0.70 × V`. The 70% weighting prioritizes code-generatable spectacle. **Eligibility is assessed independently before shortlisting**; an unqualified game cannot win by a high weighted average.

### Original 50 criteria (all retained)

| Code | Category | Criterion | Original weight | Group multiplier | Description |
|---|---|---|---:|---:|---|
| M01 | Market | PC analog demand | 5 | 0.78 | Strength of public PC comparable signals, NOT sales forecast |
| M02 | Market | iOS paid-category proof | 5 | 0.78 | Strength of analogy with paid iOS game charts |
| M03 | Market | Android paid-category proof | 3 | 0.78 | Strength of analogy with paid Android puzzle chart |
| M04 | Market | Comparable review breadth | 3 | 0.78 | Review count as imperfect interest proxy, never units sold |
| M05 | Market | Evergreen theme | 5 | 0.78 | Will the premise remain relevant without live trends? |
| M06 | Market | Broad age appeal | 3 | 0.78 | Potential for more than one narrow demographic |
| M07 | Market | Instant explanation | 4 | 0.78 | Can a user explain the hook after watching 10 seconds? |
| M08 | Market | Emotional payoff | 4 | 0.78 | Delight, curiosity, mastery or calm |
| M09 | Market | Repeat-session appeal | 5 | 0.78 | Will purchasers return voluntarily? |
| M10 | Market | Organic search clarity | 4 | 0.78 | Discoverable descriptive intent, no branded borrowing |
| C11 | Competition | Avoids saturated direct clones | 5 | 0.86 | Higher score means LESS direct competition |
| C12 | Competition | Distinct mechanism | 5 | 0.86 | Core loop stands on its own rather than reskinning |
| C13 | Competition | Recognizable original art | 4 | 0.86 | Visually differentiates in screenshots |
| C14 | Competition | Underserved niche | 3 | 0.86 | Addresses a plausible underserved play intent |
| C15 | Competition | Justifies premium position | 4 | 0.86 | Can compete on completeness rather than attention extraction |
| C16 | Competition | ASO keyword clarity | 3 | 0.86 | App Store search keywords clear, generic and lawful |
| C17 | Competition | Competitive MVP scope | 4 | 0.86 | Can deliver compelling value without giant team |
| C18 | Competition | PC-to-touch adaptation gap | 3 | 0.86 | Distinct touch advantage versus mouse-first products |
| C19 | Competition | No incumbent network dependency | 4 | 0.86 | Not reliant on friends/network effects |
| C20 | Competition | Portfolio differentiation | 3 | 0.86 | Adds a new motif or shared package, limits cannibalization |
| P21 | Premium | Pay-once satisfaction | 5 | 1.0 | Complete paid game, no ads or IAP required |
| P22 | Premium | No-ad design coherence | 5 | 1.0 | No reward/video/ad economy dependency |
| P23 | Premium | Complete base content | 5 | 1.0 | Compelling scope without future updates |
| P24 | Premium | $1.99-$4.99 plausibility | 4 | 1.0 | Likely perceived value at small premium ticket |
| P25 | Premium | Low refund/disappointment risk | 5 | 1.0 | Accurate screenshots and a complete gameplay promise |
| P26 | Premium | Low support burden | 3 | 1.0 | Small server-free game reduces support costs |
| P27 | Premium | No ongoing live ops | 5 | 1.0 | No season, server or daily content treadmill |
| P28 | Premium | Organic recommendations | 4 | 1.0 | Can inspire word-of-mouth and unprompted sharing |
| P29 | Premium | Content shelf-life | 5 | 1.0 | Replay through systems, not endless hand-authored levels |
| P30 | Premium | Offline save/export | 3 | 1.0 | Local storage and optional user-initiated exports |
| U31 | Experience | Touch gesture precision | 5 | 1.22 | Tap, drag, rotate, flick or paint works well |
| U32 | Experience | Ten-second wow moment | 5 | 1.22 | Immediate visual or mechanical hook |
| U33 | Experience | Short-session fitness | 4 | 1.22 | Satisfying play in 2-10 minutes |
| U34 | Experience | Accessibility potential | 4 | 1.22 | Readable, alternative inputs, reduce motion/flashing |
| U35 | Experience | Low onboarding friction | 4 | 1.22 | Few explicit tutorials needed |
| U36 | Experience | Emergence from simple rules | 5 | 1.22 | Small model generates interesting consequences |
| U37 | Experience | Screenshot/trailer strength | 4 | 1.22 | Strong art at app-store small thumbnail scale |
| U38 | Experience | Fair learning curve | 4 | 1.22 | Not dependent on hidden or arbitrary solutions |
| U39 | Experience | Low motion sickness risk | 4 | 1.22 | Camera motion and flicker controllable |
| U40 | Experience | Offline-first use | 5 | 1.22 | No account/network needed to play |
| E41 | Engineering | OpenGL ES / ANGLE fit | 5 | 1.29 | Can be expressed via existing ANGLE→Metal pipeline |
| E42 | Engineering | VisualCore reuse | 5 | 1.29 | Shared camera, effects, scene, input, capture, profiling |
| E43 | Engineering | Numerical/physics tractability | 4 | 1.29 | Can be tested deterministically |
| E44 | Engineering | Older D3 device suitability | 5 | 1.29 | Can target A16 iPadOS 26.5 |
| E45 | Engineering | Sustained performance headroom | 5 | 1.29 | Thermal/battery safe frame budgets |
| E46 | Engineering | Small-team production scope | 5 | 1.29 | MVP feasible without unbounded assets |
| E47 | Engineering | Procedural content economics | 4 | 1.29 | Replay from deterministic generation |
| E48 | Engineering | Automatable QA | 4 | 1.29 | Seeded runs, screenshot baselines and event logs |
| E49 | Engineering | Clean-room IP safety | 5 | 1.29 | Original code, art, music, design and names |
| E50 | Engineering | Shared-package reuse | 5 | 1.29 | Cross-game engines amortize maintenance |

### 12 visual-production criteria (mandatory thresholds)

| Code | Criterion | Visual weight | Minimum | What is judged |
|---|---|---:|---:|---|
| V01 | Spectacular actual in-engine screenshot | 6 | 4.60 | Instant wow in a true VisualCore frame; not a marketing mock-up |
| V02 | Impressive animation and moving light | 6 | 4.50 | Motion is part of art and rules, not a decorative background |
| V03 | Real interactive 3D space | 5 | 4.35 | Three-dimensional geometry, occlusion, viewpoint and spatial controls |
| V04 | GLSL ES and ANGLE procedural effects fit | 8 | 4.60 | Distinctive shader-driven spectacle feasible with known GLES features |
| V05 | Fully programmatic geometry and materials | 6 | 4.45 | Everything hero-quality can be created in code with procedural generators |
| V06 | Zero image-generation requirements | 11 | 4.90 | No OpenAI/Claude/raster prompt generation needed for final art |
| V07 | Zero humanoid rigs / mocap dependency | 5 | 4.85 | No manual character design, complex rigging, or outsourced animation |
| V08 | No manual art asset pipeline | 10 | 4.90 | No hand-modeled meshes, painted backgrounds or texture artists required |
| V09 | Visual richness across procedural seeds | 4 | 4.15 | Hundreds of visually distinct puzzles/scenes possible from deterministic rules |
| V10 | D3 A16 plausible thermal and frame budget | 6 | 3.80 | Preliminary likelihood under GLES3/ANGLE on iPad A16, unverified until measured |
| V11 | Automatable real-render visual validation | 5 | 4.35 | Seeded camera, automated screenshots, timings and image comparisons |
| V12 | Strong VisualCore module reuse | 5 | 4.35 | Uses renderer, scene, material, mesh, input, benchmark APIs |

**Additional gating:** `P23 ≥ 3.55` for premium content depth; `U36 ≥ 3.65` for replayable rules; `C12 ≥ 3.60` for genuine mechanism differentiation. All finalist monetization is paid once, without any advertisement or in-app purchase. These gates are screening assertions until playable evidence arrives.

## 4. Population and qualification audit

- **Pool:** 200 inherited candidates + 300 newly written ideas = **500 distinct IDs and distinct names**.
- **Qualified:** 249 / 500 (**49.8%**) based on conceptual scores, with 251 currently rejected.
- **By origin:** 20 / 200 inherited pass; 229 / 300 new pass.
- **Shortlist:** 4 inherited and 21 newly proposed.

### Major threshold failures across rejected candidates (a concept may fail multiple checks)

| Gate | Rejected candidates failing it |
|---|---:|
| V08 | 132 |
| C12 | 130 |
| V06 | 128 |
| V01 | 119 |
| V04 | 117 |
| V07 | 96 |
| V02 | 89 |
| V10 | 68 |
| V11 | 57 |
| V05 | 50 |
| V12 | 40 |
| U36 | 23 |
| V09 | 20 |
| V03 | 5 |

### Category balance of the final portfolio

| Mechanic family | Shortlist count | Total eligible candidates in family |
|---|---:|---:|
| Acoustic geometry | 2 | 15 |
| Celestial exploration | 2 | 15 |
| Chromatic logic | 1 | 15 |
| Cosmic puzzles | 1 | 2 |
| Crystal solids | 2 | 15 |
| Light and color | 2 | 13 |
| Logic and patterns | 1 | 1 |
| Micro ecosystems | 2 | 13 |
| Orbital dynamics | 2 | 15 |
| Organic growth | 1 | 15 |
| Shadow construction | 2 | 15 |
| Spatial origami | 1 | 15 |
| Temporal puzzles | 2 | 15 |
| Terrain alchemy | 2 | 15 |
| Wave mathematics | 2 | 15 |

## 5. Sensitivity: what changes if we trust visuals less or more?

The same fixed inputs were recomputed at **50%** and **80%** visual emphasis; this is not statistical sensitivity from observed consumer data. Changing assumptions or overruling a hard gate can materially reorder concepts.

| Selected title | Current rank (70% visuals, capped portfolio) | Raw rank at 50% visuals | Raw rank at 80% visuals |
|---|---:|---:|---:|
| Aurora Loom | 1 | 1 | 1 |
| Lissajous Labyrinth | 2 | 6 | 2 |
| Wave Knot Keeper | 3 | 7 | 3 |
| Hue Compass | 4 | 8 | 4 |
| Colorfall Canyons | 5 | 3 | 23 |
| Chrono Constellator | 6 | 5 | 28 |
| Amethyst Escape | 7 | 29 | 16 |
| Faceted Forge | 8 | 24 | 20 |
| Nocturne Garden | 9 | 30 | 22 |
| Backwards Aurora | 10 | 9 | 35 |
| Echo Cartographer | 11 | 2 | 105 |
| Harmonic Bridges | 12 | 15 | 53 |
| Acoustic Constellator | 13 | 10 | 57 |
| Moonlit Mechanism | 14 | 70 | 42 |
| Voxel Origami | 15 | 53 | 54 |
| Starlit Cartouche | 16 | 140 | 45 |
| Celestial Eclipse Lab | 17 | 161 | 61 |
| Apsides Workshop | 18 | 183 | 119 |
| Microscopic Aurora | 19 | 212 | 115 |
| Mushroom Weather | 20 | 210 | 120 |
| Binary Gardens | 21 | 194 | 151 |
| Mycelium Architect | 22 | 217 | 163 |
| Erosion Painter | 23 | 213 | 167 |
| Crystal Quarry | 24 | 214 | 168 |
| Starlight Surveyors | 25 | 133 | 277 |

**Interpretation:** Close scores (especially differences under 1 point) should be considered effectively tied. The cap on overlapping mechanic families is intentional; the selected rank is not always the raw score rank. No claim of high statistical predictive power is justified.

## 6. Revenue economics without ads or in-app purchases

The only monetization event is buying the app. The following is simple arithmetic under assumed **15% or 30% platform fees**, ignoring taxes, refunds, localization, overhead, development labor and variable costs. Eligibility for any reduced fee is not assumed. These are **scenarios, not forecasts**.

| Price | Gross at 500 purchases | Net at 500 / 15% assumed | Net at 2,000 / 15% assumed | Net at 10,000 / 30% assumed |
|---:|---:|---:|---:|---:|
| $1.99 | $995 | $846 | $3,383 | $13,930 |
| $2.99 | $1,495 | $1,271 | $5,083 | $20,930 |
| $3.99 | $1,995 | $1,696 | $6,783 | $27,930 |
| $4.99 | $2,495 | $2,121 | $8,483 | $34,930 |

**Go/no-go arithmetic:** At $3.99 and an illustrative 15% fee, each paid installation nets $3.3915 before refunds and taxes. Recovering a hypothetical $10,000 cash expense would require approximately 2,949 paid installations under those assumptions. This is not the expected number of buyers; it is a check on development scope. Human opportunity cost still matters even when Claude writes most code.

## 7. VisualCore architecture: code must create the art

```text
Claude Desktop → Swift/XcodeGen/SwiftPM + GLSL ES source
                         ↓
                  App-specific rule model
                         ↓
          VisualCore scene/mesh/material/FX APIs
                         ↓
              OpenGL ES 3.0 / EGL via ANGLE
                         ↓
                  Existing Metal backend
                         ↓
                 iPhone/iPad physical GPU
```

Keep owned `Vendor/projectM` and `Vendor/angle` forks pinned; do not delete the large ANGLE dependency checkout or place generated frameworks in a case-colliding folder. Procedural building blocks should include: `SDFPrimitives`, `MeshExtrusion`, `Instancing`, `SceneGraph`, `ColorScience`, `SoftLightApprox`, `ParticleBatch`, `RibbonRenderer`, `HeightfieldSim`, `FixedStepPhysics`, `OrbitMath`, `SeededLevelGenerator`, `VisualSnapshotHarness`, `GPUFrameTelemetry`, `AccessibleControlOverlay`. Names are proposed, not pre-existing audited APIs. Use feature negotiation; do not rely on unsupported GLES compute shaders or costly full volumetric raymarches.

### Low-cost ways to appear luxurious

- Use band-limited gradients, high-quality normals, disciplined emissive layers and restrained bloom as core shader styles. More passes do not automatically mean more beauty.
- Represent auroras, waves, light ribbons and fluid channels as tessellated spline strips with GLSL displacement rather than true high-cost volume simulation.
- Approximate refraction with normal-based color separation and screen-space cues; do not assert physically accurate caustics without a validated optical model.
- Batch instanced geometry and point sprites, pool particle buffers, cache compiled shader variants and preprocess parametric mesh topology.
- Prefer fixed-seed deterministic level and scene generation. Make gameplay physics stable across devices; rendering may choose dynamic resolution and particle caps.
- Test hero scenes without overlays, then at normal small-phone display scale including touch affordances, accessibility and visual comfort.
- Every app uses its own gameplay systems, progress structure, voice and product identity. Share engine code but do not ship repetitive templates.

## 8. Implementation and physical-device strategy

**Desktop-first full implementation:** Claude Code in the Claude Desktop application writes all game features, specs, code, unit tests, host and simulator UI tests. Do not invoke Claude CLI as a supervisor. Finish the entire set of chosen distinct app targets and freeze code before launching the official three-device testing campaign, as specified in the VisualCore master runbook. Machine commands may run through Desktop Code tasks.

**Recorded device matrix (verify live connection and OS version before testing):**

| Device | Hardware | Recorded OS | Role |
|---|---|---|---|
| D1 | iPhone 15, iPhone15,4 | iOS 27.0.1 | iPhone interaction and frame pacing reference |
| D2 | iPad Pro 13-inch M5, iPad17,3 | iPadOS 27.2 | Large-screen scaling and high-end visual effects |
| D3 | iPad A16, iPad15,7 | iPadOS 26.5 | Oldest-performance tier, backward-compatibility proof; **never update** |

**Verification after implementation lock:** use `devicectl` with record-and-exit in-app automation runners, signed local builds, real `xcresult` bundles and structured per-seed render exports. Capture cold start, first frame, level success, touch misses, actual frame pacing, shader compilation hitches, GPU time, thermal state, visible image quality and crash-free operation. Target 60fps where feasible, with a documented 30fps quality mode if it meets player-quality criteria; do not convert any assumption into a “passed” badge. Run each game sequentially on D1 → D2 → D3, collect evidence and then fix, relock and rerun impacted suites. Never automate privileged device dialogs by bypassing Apple controls.

**Automated art acceptance:** a seed-camera matrix captures 10 hero views per game, validates no missing surfaces, NaNs, black frames, wrong aspect ratios or offscreen UI, then flags perceptual differences for a limited human quality audit. Automated image comparison alone cannot establish “stunning”; a minimal outside-player screenshot comprehension test must occur before launch, even if most code is AI-authored.

**Must-stop failures:** forced new art assets; unverified licensing; app looks flat despite numerical score; 10-second goal cannot be explained; D3 shader compilation stutters; significant heat; frequent crashes; visually indistinguishable portfolio members; market comparator too remote to support the business case.

## 9. Top 25: original product hypotheses and implementation sketches

### 01. Aurora Loom — 94.80 / 100

**Premise:** Weave and phase-shift 3D luminous ribbons into target harmonies.

**Visual hook, rendered in code:** Layered ribbon meshes with wave displacement and fragment interference patterns.

**Touch-first interaction:** Existing concept input requires game-specific design verification.

**Premium packaging:** $2.99 complete, offline and paid once. Estimated production scope: **10 person-weeks** is an initial heuristic, not a project estimate backed by benchmarking.

**Why it might win:** the player visibly sculpts the same live system that makes the screen extraordinary. `G162` reaches a visual score of 97.83/100 on conceptual screening, with all twelve code-only thresholds met.

**Market analog / competition:** [Glass Masquerade official Steam store](https://store.steampowered.com/app/511470/Glass_Masquerade/); this is category-level evidence only. Also compare its moment-to-moment mechanic against other selected titles—especially Colorfall Canyons.

**Top risk:** thermal and overdraw risk on D3; crowding among optical/geometry premium games.

**Falsifiable vertical slice:** implement ten seeded frequency settings whose targets can be evaluated by a numeric tolerance; record whether the game is fun *without* the hero shader, and separately record whether the hero shader runs sustainably on D3.

**AssertionOutline:** see Section 01 in `Round-2-Top25-Complete-AssertionOutlines.md` for all three claims, twelve reasons, twelve evidence items, objections and stop conditions.

### 02. Lissajous Labyrinth — 94.30 / 100

**Premise:** Tune two coupled frequencies so a moving point traces a safe path.

**Visual hook, rendered in code:** elegant 3D luminous harmonic curves weave through obstacles; Analytic oscillators, Fourier curve meshes, interference heightfields and emissive color.

**Touch-first interaction:** Tune harmonics and phase to achieve a target three-dimensional pattern.

**Premium packaging:** $2.99 complete, offline and paid once. Estimated production scope: **10 person-weeks** is an initial heuristic, not a project estimate backed by benchmarking.

**Why it might win:** the player visibly sculpts the same live system that makes the screen extraordinary. `G456` reaches a visual score of 98.21/100 on conceptual screening, with all twelve code-only thresholds met.

**Market analog / competition:** [Glass Masquerade official Steam store](https://store.steampowered.com/app/511470/Glass_Masquerade/); this is category-level evidence only. Also compare its moment-to-moment mechanic against other selected titles—especially Wave Knot Keeper.

**Top risk:** thermal and overdraw risk on D3; crowding among optical/geometry premium games; may look more like a graphics demo than a game.

**Falsifiable vertical slice:** implement ten replayable seeded levels with a deterministic solution checker and failure reason; record whether the game is fun *without* the hero shader, and separately record whether the hero shader runs sustainably on D3.

**AssertionOutline:** see Section 02 in `Round-2-Top25-Complete-AssertionOutlines.md` for all three claims, twelve reasons, twelve evidence items, objections and stop conditions.

### 03. Wave Knot Keeper — 94.30 / 100

**Premise:** Drag spectral control points to untie closed three-dimensional wave knots.

**Visual hook, rendered in code:** luminous torus knots pulse in synchronized colors; Analytic oscillators, Fourier curve meshes, interference heightfields and emissive color.

**Touch-first interaction:** Tune harmonics and phase to achieve a target three-dimensional pattern.

**Premium packaging:** $2.99 complete, offline and paid once. Estimated production scope: **10 person-weeks** is an initial heuristic, not a project estimate backed by benchmarking.

**Why it might win:** the player visibly sculpts the same live system that makes the screen extraordinary. `G466` reaches a visual score of 98.21/100 on conceptual screening, with all twelve code-only thresholds met.

**Market analog / competition:** [Glass Masquerade official Steam store](https://store.steampowered.com/app/511470/Glass_Masquerade/); this is category-level evidence only. Also compare its moment-to-moment mechanic against other selected titles—especially Lissajous Labyrinth.

**Top risk:** thermal and overdraw risk on D3; crowding among optical/geometry premium games; may look more like a graphics demo than a game.

**Falsifiable vertical slice:** implement ten seeded frequency settings whose targets can be evaluated by a numeric tolerance; record whether the game is fun *without* the hero shader, and separately record whether the hero shader runs sustainably on D3.

**AssertionOutline:** see Section 03 in `Round-2-Top25-Complete-AssertionOutlines.md` for all three claims, twelve reasons, twelve evidence items, objections and stop conditions.

### 04. Hue Compass — 94.21 / 100

**Premise:** Rotate a spectral compass to find a hidden target in a colored fog field.

**Visual hook, rendered in code:** 3D color cones and moving luminous vector arrows; GLSL hue transforms, procedural glass polygons, spline light tubes and glow.

**Touch-first interaction:** Match spectral state in 3D without conflicting colors.

**Premium packaging:** $2.99 complete, offline and paid once. Estimated production scope: **9 person-weeks** is an initial heuristic, not a project estimate backed by benchmarking.

**Why it might win:** the player visibly sculpts the same live system that makes the screen extraordinary. `G400` reaches a visual score of 98.09/100 on conceptual screening, with all twelve code-only thresholds met.

**Market analog / competition:** [Glass Masquerade official Steam store](https://store.steampowered.com/app/511470/Glass_Masquerade/); this is category-level evidence only. Also compare its moment-to-moment mechanic against other selected titles—especially other geometry and visual puzzles.

**Top risk:** crowding among optical/geometry premium games; may look more like a graphics demo than a game.

**Falsifiable vertical slice:** implement ten replayable seeded levels with a deterministic solution checker and failure reason; record whether the game is fun *without* the hero shader, and separately record whether the hero shader runs sustainably on D3.

**AssertionOutline:** see Section 04 in `Round-2-Top25-Complete-AssertionOutlines.md` for all three claims, twelve reasons, twelve evidence items, objections and stop conditions.

### 05. Colorfall Canyons — 94.13 / 100

**Premise:** Carve sluices to direct colored light-fluid into target basins.

**Visual hook, rendered in code:** Heightfield canyons with spectral dye particles and flow-map water shaders.

**Touch-first interaction:** Existing concept input requires game-specific design verification.

**Premium packaging:** $2.99 complete, offline and paid once. Estimated production scope: **13 person-weeks** is an initial heuristic, not a project estimate backed by benchmarking.

**Why it might win:** the player visibly sculpts the same live system that makes the screen extraordinary. `G161` reaches a visual score of 97.46/100 on conceptual screening, with all twelve code-only thresholds met.

**Market analog / competition:** [Glass Masquerade official Steam store](https://store.steampowered.com/app/511470/Glass_Masquerade/); this is category-level evidence only. Also compare its moment-to-moment mechanic against other selected titles—especially Aurora Loom.

**Top risk:** thermal and overdraw risk on D3; crowding among optical/geometry premium games.

**Falsifiable vertical slice:** implement ten replayable seeded levels with a deterministic solution checker and failure reason; record whether the game is fun *without* the hero shader, and separately record whether the hero shader runs sustainably on D3.

**AssertionOutline:** see Section 05 in `Round-2-Top25-Complete-AssertionOutlines.md` for all three claims, twelve reasons, twelve evidence items, objections and stop conditions.

### 06. Chrono Constellator — 94.02 / 100

**Premise:** Record and replay a constellation's motion until all stars align.

**Visual hook, rendered in code:** 3D star traces accumulate into glowing history ribbons; Deterministic timeline buffers, ghost trails, reversible deformation shaders.

**Touch-first interaction:** Edit events in a short loop to produce a future alignment.

**Premium packaging:** $3.99 complete, offline and paid once. Estimated production scope: **14 person-weeks** is an initial heuristic, not a project estimate backed by benchmarking.

**Why it might win:** the player visibly sculpts the same live system that makes the screen extraordinary. `G450` reaches a visual score of 97.48/100 on conceptual screening, with all twelve code-only thresholds met.

**Market analog / competition:** [Baba Is You official Steam store](https://store.steampowered.com/app/736260/Baba_Is_You/); this is category-level evidence only. Also compare its moment-to-moment mechanic against other selected titles—especially Backwards Aurora.

**Top risk:** thermal and overdraw risk on D3; replay rules may become hard to communicate.

**Falsifiable vertical slice:** implement ten replayable seeded levels with a deterministic solution checker and failure reason; record whether the game is fun *without* the hero shader, and separately record whether the hero shader runs sustainably on D3.

**AssertionOutline:** see Section 06 in `Round-2-Top25-Complete-AssertionOutlines.md` for all three claims, twelve reasons, twelve evidence items, objections and stop conditions.

### 07. Amethyst Escape — 93.99 / 100

**Premise:** Rotate crystalline layers to open a route for a rolling pearl.

**Visual hook, rendered in code:** translucent nested polygons with shifting specular highlights; Beveled polyhedra, faceted signed-distance fields, instanced lattices and faux dispersion.

**Touch-first interaction:** Rotate/cut/exchange crystal solids to meet 3D geometry rules.

**Premium packaging:** $3.99 complete, offline and paid once. Estimated production scope: **12 person-weeks** is an initial heuristic, not a project estimate backed by benchmarking.

**Why it might win:** the player visibly sculpts the same live system that makes the screen extraordinary. `G299` reaches a visual score of 97.90/100 on conceptual screening, with all twelve code-only thresholds met.

**Market analog / competition:** [Glass Masquerade official Steam store](https://store.steampowered.com/app/511470/Glass_Masquerade/); this is category-level evidence only. Also compare its moment-to-moment mechanic against other selected titles—especially Faceted Forge.

**Top risk:** crowding among optical/geometry premium games.

**Falsifiable vertical slice:** implement ten seeded stages with routes independently checked by graph reachability and failure recovery; record whether the game is fun *without* the hero shader, and separately record whether the hero shader runs sustainably on D3.

**AssertionOutline:** see Section 07 in `Round-2-Top25-Complete-AssertionOutlines.md` for all three claims, twelve reasons, twelve evidence items, objections and stop conditions.

### 08. Faceted Forge — 93.98 / 100

**Premise:** Place cleavage planes to split a glowing crystal into target solids.

**Visual hook, rendered in code:** fast SDF cuts reveal incandescent geometric interiors; Beveled polyhedra, faceted signed-distance fields, instanced lattices and faux dispersion.

**Touch-first interaction:** Rotate/cut/exchange crystal solids to meet 3D geometry rules.

**Premium packaging:** $3.99 complete, offline and paid once. Estimated production scope: **11 person-weeks** is an initial heuristic, not a project estimate backed by benchmarking.

**Why it might win:** the player visibly sculpts the same live system that makes the screen extraordinary. `G291` reaches a visual score of 97.82/100 on conceptual screening, with all twelve code-only thresholds met.

**Market analog / competition:** [Glass Masquerade official Steam store](https://store.steampowered.com/app/511470/Glass_Masquerade/); this is category-level evidence only. Also compare its moment-to-moment mechanic against other selected titles—especially Amethyst Escape.

**Top risk:** crowding among optical/geometry premium games.

**Falsifiable vertical slice:** implement ten replayable seeded levels with a deterministic solution checker and failure reason; record whether the game is fun *without* the hero shader, and separately record whether the hero shader runs sustainably on D3.

**AssertionOutline:** see Section 08 in `Round-2-Top25-Complete-AssertionOutlines.md` for all three claims, twelve reasons, twelve evidence items, objections and stop conditions.

### 09. Nocturne Garden — 93.96 / 100

**Premise:** Arrange glowing blooms to create a target flower-shaped dark silhouette.

**Visual hook, rendered in code:** deep black botanical shadows on colored mist planes; Procedural solids, CPU polygonal 3D shadow projections, soft shadow approximation.

**Touch-first interaction:** Construct 3D shapes whose target shadow matches an image or path.

**Premium packaging:** $3.99 complete, offline and paid once. Estimated production scope: **11 person-weeks** is an initial heuristic, not a project estimate backed by benchmarking.

**Why it might win:** the player visibly sculpts the same live system that makes the screen extraordinary. `G368` reaches a visual score of 97.82/100 on conceptual screening, with all twelve code-only thresholds met.

**Market analog / competition:** [Baba Is You official Steam store](https://store.steampowered.com/app/736260/Baba_Is_You/); this is category-level evidence only. Also compare its moment-to-moment mechanic against other selected titles—especially Moonlit Mechanism.

**Top risk:** crowding among optical/geometry premium games.

**Falsifiable vertical slice:** implement ten object poses evaluated with projected silhouette overlap and tolerances; record whether the game is fun *without* the hero shader, and separately record whether the hero shader runs sustainably on D3.

**AssertionOutline:** see Section 09 in `Round-2-Top25-Complete-AssertionOutlines.md` for all three claims, twelve reasons, twelve evidence items, objections and stop conditions.

### 10. Backwards Aurora — 93.96 / 100

**Premise:** Correct a hidden signal by reversing sections of an auroral wave.

**Visual hook, rendered in code:** auroral ribbons fold backward along procedural timelines; Deterministic timeline buffers, ghost trails, reversible deformation shaders.

**Touch-first interaction:** Edit events in a short loop to produce a future alignment.

**Premium packaging:** $3.99 complete, offline and paid once. Estimated production scope: **13 person-weeks** is an initial heuristic, not a project estimate backed by benchmarking.

**Why it might win:** the player visibly sculpts the same live system that makes the screen extraordinary. `G451` reaches a visual score of 97.47/100 on conceptual screening, with all twelve code-only thresholds met.

**Market analog / competition:** [Baba Is You official Steam store](https://store.steampowered.com/app/736260/Baba_Is_You/); this is category-level evidence only. Also compare its moment-to-moment mechanic against other selected titles—especially Chrono Constellator.

**Top risk:** thermal and overdraw risk on D3; replay rules may become hard to communicate.

**Falsifiable vertical slice:** implement ten seeded frequency settings whose targets can be evaluated by a numeric tolerance; record whether the game is fun *without* the hero shader, and separately record whether the hero shader runs sustainably on D3.

**AssertionOutline:** see Section 10 in `Round-2-Top25-Complete-AssertionOutlines.md` for all three claims, twelve reasons, twelve evidence items, objections and stop conditions.

### 11. Echo Cartographer — 93.91 / 100

**Premise:** Touch to emit a pulse, mark reflected obstacles, locate hidden beacons; seeded room generator.

**Visual hook, rendered in code:** Signed-distance chamber topology, instanced wireframe surfaces, expanding normal-aware echo waves.

**Touch-first interaction:** Existing concept input requires game-specific design verification.

**Premium packaging:** $3.99 complete, offline and paid once. Estimated production scope: **13 person-weeks** is an initial heuristic, not a project estimate backed by benchmarking.

**Why it might win:** the player visibly sculpts the same live system that makes the screen extraordinary. `G181` reaches a visual score of 96.03/100 on conceptual screening, with all twelve code-only thresholds met.

**Market analog / competition:** [Baba Is You official Steam store](https://store.steampowered.com/app/736260/Baba_Is_You/); this is category-level evidence only. Also compare its moment-to-moment mechanic against other selected titles—especially other geometry and visual puzzles.

**Top risk:** thermal and overdraw risk on D3.

**Falsifiable vertical slice:** implement ten growth scenarios with fixed-step cellular state and reproducible outcomes; record whether the game is fun *without* the hero shader, and separately record whether the hero shader runs sustainably on D3.

**AssertionOutline:** see Section 11 in `Round-2-Top25-Complete-AssertionOutlines.md` for all three claims, twelve reasons, twelve evidence items, objections and stop conditions.

### 12. Harmonic Bridges — 93.81 / 100

**Premise:** Tune suspended strings so their resonances solidify walkable bridges.

**Visual hook, rendered in code:** oscillating wave membranes stretch between crystalline anchors; Instanced line meshes, transient wave shells, acoustically inspired distance-field reveals.

**Touch-first interaction:** Position/trigger resonators and infer hidden 3D structure.

**Premium packaging:** $3.99 complete, offline and paid once. Estimated production scope: **12 person-weeks** is an initial heuristic, not a project estimate backed by benchmarking.

**Why it might win:** the player visibly sculpts the same live system that makes the screen extraordinary. `G217` reaches a visual score of 97.18/100 on conceptual screening, with all twelve code-only thresholds met.

**Market analog / competition:** [Baba Is You official Steam store](https://store.steampowered.com/app/736260/Baba_Is_You/); this is category-level evidence only. Also compare its moment-to-moment mechanic against other selected titles—especially Acoustic Constellator.

**Top risk:** thermal and overdraw risk on D3.

**Falsifiable vertical slice:** implement ten replayable seeded levels with a deterministic solution checker and failure reason; record whether the game is fun *without* the hero shader, and separately record whether the hero shader runs sustainably on D3.

**AssertionOutline:** see Section 12 in `Round-2-Top25-Complete-AssertionOutlines.md` for all three claims, twelve reasons, twelve evidence items, objections and stop conditions.

### 13. Acoustic Constellator — 93.81 / 100

**Premise:** Connect drifting musical nodes so their shared harmonics form celestial diagrams.

**Visual hook, rendered in code:** 3D oscillatory curves become glowing star networks; Instanced line meshes, transient wave shells, acoustically inspired distance-field reveals.

**Touch-first interaction:** Position/trigger resonators and infer hidden 3D structure.

**Premium packaging:** $3.99 complete, offline and paid once. Estimated production scope: **11 person-weeks** is an initial heuristic, not a project estimate backed by benchmarking.

**Why it might win:** the player visibly sculpts the same live system that makes the screen extraordinary. `G230` reaches a visual score of 97.10/100 on conceptual screening, with all twelve code-only thresholds met.

**Market analog / competition:** [Baba Is You official Steam store](https://store.steampowered.com/app/736260/Baba_Is_You/); this is category-level evidence only. Also compare its moment-to-moment mechanic against other selected titles—especially Harmonic Bridges.

**Top risk:** thermal and overdraw risk on D3.

**Falsifiable vertical slice:** implement ten seeded frequency settings whose targets can be evaluated by a numeric tolerance; record whether the game is fun *without* the hero shader, and separately record whether the hero shader runs sustainably on D3.

**AssertionOutline:** see Section 13 in `Round-2-Top25-Complete-AssertionOutlines.md` for all three claims, twelve reasons, twelve evidence items, objections and stop conditions.

### 14. Moonlit Mechanism — 93.73 / 100

**Premise:** Rotate a clockwork machine until its combined moving shadows spell symbols.

**Visual hook, rendered in code:** interlocking shadow gears on a luminous paper wall; Procedural solids, CPU polygonal 3D shadow projections, soft shadow approximation.

**Touch-first interaction:** Construct 3D shapes whose target shadow matches an image or path.

**Premium packaging:** $3.99 complete, offline and paid once. Estimated production scope: **12 person-weeks** is an initial heuristic, not a project estimate backed by benchmarking.

**Why it might win:** the player visibly sculpts the same live system that makes the screen extraordinary. `G370` reaches a visual score of 97.69/100 on conceptual screening, with all twelve code-only thresholds met.

**Market analog / competition:** [Baba Is You official Steam store](https://store.steampowered.com/app/736260/Baba_Is_You/); this is category-level evidence only. Also compare its moment-to-moment mechanic against other selected titles—especially Nocturne Garden.

**Top risk:** crowding among optical/geometry premium games.

**Falsifiable vertical slice:** implement ten object poses evaluated with projected silhouette overlap and tolerances; record whether the game is fun *without* the hero shader, and separately record whether the hero shader runs sustainably on D3.

**AssertionOutline:** see Section 14 in `Round-2-Top25-Complete-AssertionOutlines.md` for all three claims, twelve reasons, twelve evidence items, objections and stop conditions.

### 15. Voxel Origami — 93.70 / 100

**Premise:** Reconfigure hinged voxels into a target solid without collisions.

**Visual hook, rendered in code:** glowing cube nets morph into compact 3D sculptures; Reconfigurable polyhedral nets, articulated hinges, procedural faceted materials.

**Touch-first interaction:** Fold and rotate a 3D net to complete a connectivity puzzle.

**Premium packaging:** $3.99 complete, offline and paid once. Estimated production scope: **12 person-weeks** is an initial heuristic, not a project estimate backed by benchmarking.

**Why it might win:** the player visibly sculpts the same live system that makes the screen extraordinary. `G426` reaches a visual score of 97.41/100 on conceptual screening, with all twelve code-only thresholds met.

**Market analog / competition:** [Baba Is You official Steam store](https://store.steampowered.com/app/736260/Baba_Is_You/); this is category-level evidence only. Also compare its moment-to-moment mechanic against other selected titles—especially other geometry and visual puzzles.

**Top risk:** thermal and overdraw risk on D3; crowding among optical/geometry premium games.

**Falsifiable vertical slice:** implement ten replayable seeded levels with a deterministic solution checker and failure reason; record whether the game is fun *without* the hero shader, and separately record whether the hero shader runs sustainably on D3.

**AssertionOutline:** see Section 15 in `Round-2-Top25-Complete-AssertionOutlines.md` for all three claims, twelve reasons, twelve evidence items, objections and stop conditions.

### 16. Starlit Cartouche — 93.56 / 100

**Premise:** Connect a moving starship route into a prescribed ancient symbol.

**Visual hook, rendered in code:** luminous paths across three-dimensional star charts; Procedural planets and ring systems, layered star spheres and emission shaders.

**Touch-first interaction:** Plot trajectories and align celestial events.

**Premium packaging:** $3.99 complete, offline and paid once. Estimated production scope: **13 person-weeks** is an initial heuristic, not a project estimate backed by benchmarking.

**Why it might win:** the player visibly sculpts the same live system that makes the screen extraordinary. `G355` reaches a visual score of 97.97/100 on conceptual screening, with all twelve code-only thresholds met.

**Market analog / competition:** [Superflight official Steam store](https://store.steampowered.com/app/732430/Superflight); this is category-level evidence only. Also compare its moment-to-moment mechanic against other selected titles—especially Celestial Eclipse Lab.

**Top risk:** thermal and overdraw risk on D3; numerical and spatial explanation complexity.

**Falsifiable vertical slice:** implement ten seeded stages with routes independently checked by graph reachability and failure recovery; record whether the game is fun *without* the hero shader, and separately record whether the hero shader runs sustainably on D3.

**AssertionOutline:** see Section 16 in `Round-2-Top25-Complete-AssertionOutlines.md` for all three claims, twelve reasons, twelve evidence items, objections and stop conditions.

### 17. Celestial Eclipse Lab — 93.43 / 100

**Premise:** Position miniature orbits so sequential eclipses form a target sequence.

**Visual hook, rendered in code:** precise shadow crescents over glowing planetary discs; Procedural planets and ring systems, layered star spheres and emission shaders.

**Touch-first interaction:** Plot trajectories and align celestial events.

**Premium packaging:** $3.99 complete, offline and paid once. Estimated production scope: **13 person-weeks** is an initial heuristic, not a project estimate backed by benchmarking.

**Why it might win:** the player visibly sculpts the same live system that makes the screen extraordinary. `G359` reaches a visual score of 97.80/100 on conceptual screening, with all twelve code-only thresholds met.

**Market analog / competition:** [Superflight official Steam store](https://store.steampowered.com/app/732430/Superflight); this is category-level evidence only. Also compare its moment-to-moment mechanic against other selected titles—especially Starlit Cartouche.

**Top risk:** thermal and overdraw risk on D3; numerical and spatial explanation complexity.

**Falsifiable vertical slice:** implement ten replayable seeded levels with a deterministic solution checker and failure reason; record whether the game is fun *without* the hero shader, and separately record whether the hero shader runs sustainably on D3.

**AssertionOutline:** see Section 17 in `Round-2-Top25-Complete-AssertionOutlines.md` for all three claims, twelve reasons, twelve evidence items, objections and stop conditions.

### 18. Apsides Workshop — 93.14 / 100

**Premise:** Tune orbital eccentricity to sweep precise regions of a miniature sky.

**Visual hook, rendered in code:** celestial paths trace luminous ellipses at varying depths; Numerical gravitation in fixed steps, analytic orbit curves, procedural planets and starfields.

**Touch-first interaction:** Tune gravitation and launch windows to achieve stable goals.

**Premium packaging:** $3.99 complete, offline and paid once. Estimated production scope: **13 person-weeks** is an initial heuristic, not a project estimate backed by benchmarking.

**Why it might win:** the player visibly sculpts the same live system that makes the screen extraordinary. `G254` reaches a visual score of 97.37/100 on conceptual screening, with all twelve code-only thresholds met.

**Market analog / competition:** [Superflight official Steam store](https://store.steampowered.com/app/732430/Superflight); this is category-level evidence only. Also compare its moment-to-moment mechanic against other selected titles—especially Binary Gardens.

**Top risk:** thermal and overdraw risk on D3; numerical and spatial explanation complexity.

**Falsifiable vertical slice:** implement ten replayable seeded levels with a deterministic solution checker and failure reason; record whether the game is fun *without* the hero shader, and separately record whether the hero shader runs sustainably on D3.

**AssertionOutline:** see Section 18 in `Round-2-Top25-Complete-AssertionOutlines.md` for all three claims, twelve reasons, twelve evidence items, objections and stop conditions.

### 19. Microscopic Aurora — 93.06 / 100

**Premise:** Manipulate magnetic swimmers to build a glowing bacterial pattern.

**Visual hook, rendered in code:** slender luminous boids form wave-like living ribbons; L-system miniature flora, deterministic boids, bioluminescence and simple water planes.

**Touch-first interaction:** Balance one ecosystem variable to satisfy a clear spatial objective.

**Premium packaging:** $3.99 complete, offline and paid once. Estimated production scope: **15 person-weeks** is an initial heuristic, not a project estimate backed by benchmarking.

**Why it might win:** the player visibly sculpts the same live system that makes the screen extraordinary. `G415` reaches a visual score of 97.60/100 on conceptual screening, with all twelve code-only thresholds met.

**Market analog / competition:** [Tiny Glade official Steam store](https://store.steampowered.com/app/2198150/Tiny_Glade/); this is category-level evidence only. Also compare its moment-to-moment mechanic against other selected titles—especially Mushroom Weather.

**Top risk:** thermal and overdraw risk on D3; replay rules may become hard to communicate.

**Falsifiable vertical slice:** implement ten replayable seeded levels with a deterministic solution checker and failure reason; record whether the game is fun *without* the hero shader, and separately record whether the hero shader runs sustainably on D3.

**AssertionOutline:** see Section 19 in `Round-2-Top25-Complete-AssertionOutlines.md` for all three claims, twelve reasons, twelve evidence items, objections and stop conditions.

### 20. Mushroom Weather — 93.04 / 100

**Premise:** Arrange fungi to create a stable forest humidity network.

**Visual hook, rendered in code:** translucent mushroom caps sparkle with moisture gradients; L-system miniature flora, deterministic boids, bioluminescence and simple water planes.

**Touch-first interaction:** Balance one ecosystem variable to satisfy a clear spatial objective.

**Premium packaging:** $3.99 complete, offline and paid once. Estimated production scope: **15 person-weeks** is an initial heuristic, not a project estimate backed by benchmarking.

**Why it might win:** the player visibly sculpts the same live system that makes the screen extraordinary. `G414` reaches a visual score of 97.53/100 on conceptual screening, with all twelve code-only thresholds met.

**Market analog / competition:** [Tiny Glade official Steam store](https://store.steampowered.com/app/2198150/Tiny_Glade/); this is category-level evidence only. Also compare its moment-to-moment mechanic against other selected titles—especially Microscopic Aurora.

**Top risk:** thermal and overdraw risk on D3; replay rules may become hard to communicate.

**Falsifiable vertical slice:** implement ten replayable seeded levels with a deterministic solution checker and failure reason; record whether the game is fun *without* the hero shader, and separately record whether the hero shader runs sustainably on D3.

**AssertionOutline:** see Section 20 in `Round-2-Top25-Complete-AssertionOutlines.md` for all three claims, twelve reasons, twelve evidence items, objections and stop conditions.

### 21. Binary Gardens — 93.00 / 100

**Premise:** Balance twin stars to keep orbiting flower worlds within a light zone.

**Visual hook, rendered in code:** twin light discs and procedural luminous planet ecologies; Numerical gravitation in fixed steps, analytic orbit curves, procedural planets and starfields.

**Touch-first interaction:** Tune gravitation and launch windows to achieve stable goals.

**Premium packaging:** $3.99 complete, offline and paid once. Estimated production scope: **14 person-weeks** is an initial heuristic, not a project estimate backed by benchmarking.

**Why it might win:** the player visibly sculpts the same live system that makes the screen extraordinary. `G249` reaches a visual score of 97.26/100 on conceptual screening, with all twelve code-only thresholds met.

**Market analog / competition:** [Superflight official Steam store](https://store.steampowered.com/app/732430/Superflight); this is category-level evidence only. Also compare its moment-to-moment mechanic against other selected titles—especially Apsides Workshop.

**Top risk:** thermal and overdraw risk on D3; numerical and spatial explanation complexity.

**Falsifiable vertical slice:** implement ten replayable seeded levels with a deterministic solution checker and failure reason; record whether the game is fun *without* the hero shader, and separately record whether the hero shader runs sustainably on D3.

**AssertionOutline:** see Section 21 in `Round-2-Top25-Complete-AssertionOutlines.md` for all three claims, twelve reasons, twelve evidence items, objections and stop conditions.

### 22. Mycelium Architect — 92.91 / 100

**Premise:** Feed fungal networks so glowing veins form a target graph around rocks.

**Visual hook, rendered in code:** recursive hyphae bloom under translucent luminous caps; Recursive L-systems, instanced leaves, flow network evolution and bioluminescent materials.

**Touch-first interaction:** Grow/prune branching organisms to satisfy spatial or timing constraints.

**Premium packaging:** $3.99 complete, offline and paid once. Estimated production scope: **13 person-weeks** is an initial heuristic, not a project estimate backed by benchmarking.

**Why it might win:** the player visibly sculpts the same live system that makes the screen extraordinary. `G276` reaches a visual score of 97.31/100 on conceptual screening, with all twelve code-only thresholds met.

**Market analog / competition:** [Dorfromantik official Steam store](https://store.steampowered.com/app/1455840/); this is category-level evidence only. Also compare its moment-to-moment mechanic against other selected titles—especially other geometry and visual puzzles.

**Top risk:** thermal and overdraw risk on D3; replay rules may become hard to communicate.

**Falsifiable vertical slice:** implement ten replayable seeded levels with a deterministic solution checker and failure reason; record whether the game is fun *without* the hero shader, and separately record whether the hero shader runs sustainably on D3.

**AssertionOutline:** see Section 22 in `Round-2-Top25-Complete-AssertionOutlines.md` for all three claims, twelve reasons, twelve evidence items, objections and stop conditions.

### 23. Erosion Painter — 92.90 / 100

**Premise:** Raise and lower terrain to coax rain into carving a target canyon.

**Visual hook, rendered in code:** procedural heightfields channel glowing water and sediment; Deterministic heightfields, erosion approximation, instanced scenery and raster-free sky.

**Touch-first interaction:** Reshape terrain to redirect natural flows or light.

**Premium packaging:** $3.99 complete, offline and paid once. Estimated production scope: **14 person-weeks** is an initial heuristic, not a project estimate backed by benchmarking.

**Why it might win:** the player visibly sculpts the same live system that makes the screen extraordinary. `G321` reaches a visual score of 97.24/100 on conceptual screening, with all twelve code-only thresholds met.

**Market analog / competition:** [Dorfromantik official Steam store](https://store.steampowered.com/app/1455840/); this is category-level evidence only. Also compare its moment-to-moment mechanic against other selected titles—especially Crystal Quarry.

**Top risk:** thermal and overdraw risk on D3.

**Falsifiable vertical slice:** implement ten replayable seeded levels with a deterministic solution checker and failure reason; record whether the game is fun *without* the hero shader, and separately record whether the hero shader runs sustainably on D3.

**AssertionOutline:** see Section 23 in `Round-2-Top25-Complete-AssertionOutlines.md` for all three claims, twelve reasons, twelve evidence items, objections and stop conditions.

### 24. Crystal Quarry — 92.90 / 100

**Premise:** Choose fracture paths to reveal a target gem network in rock.

**Visual hook, rendered in code:** glowing mineral seams emerge through geometric stone fractures; Deterministic heightfields, erosion approximation, instanced scenery and raster-free sky.

**Touch-first interaction:** Reshape terrain to redirect natural flows or light.

**Premium packaging:** $3.99 complete, offline and paid once. Estimated production scope: **14 person-weeks** is an initial heuristic, not a project estimate backed by benchmarking.

**Why it might win:** the player visibly sculpts the same live system that makes the screen extraordinary. `G334` reaches a visual score of 97.24/100 on conceptual screening, with all twelve code-only thresholds met.

**Market analog / competition:** [Dorfromantik official Steam store](https://store.steampowered.com/app/1455840/); this is category-level evidence only. Also compare its moment-to-moment mechanic against other selected titles—especially Erosion Painter.

**Top risk:** thermal and overdraw risk on D3.

**Falsifiable vertical slice:** implement ten replayable seeded levels with a deterministic solution checker and failure reason; record whether the game is fun *without* the hero shader, and separately record whether the hero shader runs sustainably on D3.

**AssertionOutline:** see Section 24 in `Round-2-Top25-Complete-AssertionOutlines.md` for all three claims, twelve reasons, twelve evidence items, objections and stop conditions.

### 25. Starlight Surveyors — 92.84 / 100

**Premise:** Rotate a 3D observatory until starlight aligns through viewports.

**Visual hook, rendered in code:** Parametric star volumes, glowing triangulation rays and projection-matched constellations.

**Touch-first interaction:** Existing concept input requires game-specific design verification.

**Premium packaging:** $3.99 complete, offline and paid once. Estimated production scope: **12 person-weeks** is an initial heuristic, not a project estimate backed by benchmarking.

**Why it might win:** the player visibly sculpts the same live system that makes the screen extraordinary. `G122` reaches a visual score of 96.05/100 on conceptual screening, with all twelve code-only thresholds met.

**Market analog / competition:** [Glass Masquerade official Steam store](https://store.steampowered.com/app/511470/Glass_Masquerade/); this is category-level evidence only. Also compare its moment-to-moment mechanic against other selected titles—especially other geometry and visual puzzles.

**Top risk:** thermal and overdraw risk on D3.

**Falsifiable vertical slice:** implement ten replayable seeded levels with a deterministic solution checker and failure reason; record whether the game is fun *without* the hero shader, and separately record whether the hero shader runs sustainably on D3.

**AssertionOutline:** see Section 25 in `Round-2-Top25-Complete-AssertionOutlines.md` for all three claims, twelve reasons, twelve evidence items, objections and stop conditions.

## 10. Full 500-game ranked inventory

Every row below is in descending **heuristic score**, even if its hard gate fails. Only explicitly qualified games may enter the shortlist. The companion scoring CSV contains **all 62 individual ratings for every row**, complete goals and visuals, price assumptions, comparable-source URLs, traceable provenance and rejection reasons.

| Raw rank | ID | Candidate | Family | Score | Eligible | Goal and distinguishing action |
|---:|---|---|---|---:|---|---|
| 1 | G162 | Aurora Loom | Light and color | 94.80 | YES | Weave and phase-shift 3D luminous ribbons into target harmonies |
| 2 | G456 | Lissajous Labyrinth | Wave mathematics | 94.30 | YES | Tune two coupled frequencies so a moving point traces a safe path |
| 3 | G466 | Wave Knot Keeper | Wave mathematics | 94.30 | YES | Drag spectral control points to untie closed three-dimensional wave knots |
| 4 | G400 | Hue Compass | Chromatic logic | 94.21 | YES | Rotate a spectral compass to find a hidden target in a colored fog field |
| 5 | G459 | Harmonic Helix | Wave mathematics | 94.18 | YES | Adjust phase offsets so three spirals touch fixed target rings |
| 6 | G461 | Ripple Clockwork | Wave mathematics | 94.17 | YES | Synchronize circular waves so particles hit target nodes at exact times |
| 7 | G161 | Colorfall Canyons | Light and color | 94.13 | YES | Carve sluices to direct colored light-fluid into target basins |
| 8 | G401 | Prism Symphony | Chromatic logic | 94.10 | YES | Combine three color waveforms into a target spatial chord |
| 9 | G465 | Harmonic Archipelago | Wave mathematics | 94.07 | YES | Tune waves across floating islands to build temporary bridges |
| 10 | G396 | Color Alchemy Spires | Chromatic logic | 94.07 | YES | Stack color-transforming towers to turn incoming beams into a target spectrum |
| 11 | G397 | Gradient Locksmith | Chromatic logic | 94.07 | YES | Rotate color wheels around a 3D lock until matching hues align |
| 12 | G467 | Bessel Fountain | Wave mathematics | 94.06 | YES | Choose radial wave modes that raise a fountain into a target sculpture |
| 13 | G464 | Phase Prism | Wave mathematics | 94.06 | YES | Route coherent light packets through wave-splitting chambers |
| 14 | G470 | Polar Waveglass | Wave mathematics | 94.06 | YES | Tune radial and angular wave modes to turn a disk into an iris pattern |
| 15 | G450 | Chrono Constellator | Temporal puzzles | 94.02 | YES | Record and replay a constellation's motion until all stars align |
| 16 | G458 | Standing Wave Garden | Wave mathematics | 94.00 | YES | Change boundary lengths so growing peaks lift tiny seeds into sockets |
| 17 | G462 | Sinewave Sculptor | Wave mathematics | 94.00 | YES | Add harmonics to shape a luminous loop into a specified silhouette |
| 18 | G299 | Amethyst Escape | Crystal solids | 93.99 | YES | Rotate crystalline layers to open a route for a rolling pearl |
| 19 | G291 | Faceted Forge | Crystal solids | 93.98 | YES | Place cleavage planes to split a glowing crystal into target solids |
| 20 | G399 | Neon Mosaic Route | Chromatic logic | 93.97 | YES | Move translucent tiles so a color wave traverses every square once |
| 21 | G407 | Spectrum Garden | Chromatic logic | 93.97 | YES | Balance light wavelengths to make responsive flowers bloom in a pattern |
| 22 | G368 | Nocturne Garden | Shadow construction | 93.96 | YES | Arrange glowing blooms to create a target flower-shaped dark silhouette |
| 23 | G451 | Backwards Aurora | Temporal puzzles | 93.96 | YES | Correct a hidden signal by reversing sections of an auroral wave |
| 24 | G463 | Surface Sonata | Wave mathematics | 93.95 | YES | Tune vibrating heightfield patches to balance rolling beads |
| 25 | G468 | Interference Orchard | Wave mathematics | 93.95 | YES | Coordinate emitter phases so growth spots light up on distant trees |
| 26 | G402 | Color Vaults | Chromatic logic | 93.95 | YES | Route light through nested chambers with subtractive filter gates |
| 27 | G410 | Photon Orchard | Chromatic logic | 93.95 | YES | Route colored beams to activate fruit in a 3D glass orchard |
| 28 | G457 | Wavefront Weaver | Wave mathematics | 93.93 | YES | Place wave sources so peak interference draws a target contour |
| 29 | G181 | Echo Cartographer | Logic and patterns | 93.91 | YES | Touch to emit a pulse, mark reflected obstacles, locate hidden beacons; seeded room generator |
| 30 | G442 | Pendulum Timeglass | Temporal puzzles | 93.90 | YES | Shift timelines to synchronize three moving pendulum shadows |
| 31 | G447 | Time-Lock Labyrinth | Temporal puzzles | 93.90 | YES | Synchronize repeating gates with a moving light traveler |
| 32 | G449 | Phase Garden | Temporal puzzles | 93.90 | YES | Bring three time-shifted flowers into bloom at the same instant |
| 33 | G460 | Moire Observatory | Wave mathematics | 93.88 | YES | Rotate layered lattices until interference reveals hidden constellation points |
| 34 | G303 | Aurora Geode | Crystal solids | 93.86 | YES | Tune internal light sources to project a matching aurora outside crystal |
| 35 | G304 | Snowflake Foundry | Crystal solids | 93.86 | YES | Configure six symmetric branching rules to make a target ice form |
| 36 | G293 | Geode Locksmith | Crystal solids | 93.84 | YES | Cut and rotate nested geode rings to align hidden crystalline keys |
| 37 | G294 | Icy Polyhedron | Crystal solids | 93.84 | YES | Reconfigure edges of frozen solids while preserving volume |
| 38 | G301 | Crystal Phase Shift | Crystal solids | 93.84 | YES | Change a mineral lattice phase to unlock a three-dimensional channel |
| 39 | G305 | Diamond Pulse | Crystal solids | 93.81 | YES | Time crystal rotations so a traveling flash survives every split |
| 40 | G217 | Harmonic Bridges | Acoustic geometry | 93.81 | YES | Tune suspended strings so their resonances solidify walkable bridges |
| 41 | G230 | Acoustic Constellator | Acoustic geometry | 93.81 | YES | Connect drifting musical nodes so their shared harmonics form celestial diagrams |
| 42 | G296 | Octahedral Orchard | Crystal solids | 93.79 | YES | Connect branching octahedron clusters into a stable luminous canopy |
| 43 | G469 | Echo Harmonics | Wave mathematics | 93.78 | YES | Adjust frequency bands to expose a hidden geometric object |
| 44 | G448 | Memory Marble | Temporal puzzles | 93.76 | YES | Replay and edit a previous rolling trajectory to avoid a collision |
| 45 | G452 | Echoes of Stone | Temporal puzzles | 93.76 | YES | Carve a stone once per loop to reroute future light pulses |
| 46 | G446 | Hourglass Gravity | Temporal puzzles | 93.75 | YES | Reverse one local gravity field at a chosen time to route falling pearls |
| 47 | G409 | Color Vortex | Chromatic logic | 93.74 | YES | Position angular emitters to bring rotating color streams into phase |
| 48 | G370 | Moonlit Mechanism | Shadow construction | 93.73 | YES | Rotate a clockwork machine until its combined moving shadows spell symbols |
| 49 | G379 | Candle Geometry | Shadow construction | 93.73 | YES | Move tiny light sources around solids to animate a shadow poem |
| 50 | G376 | Umbra Rings | Shadow construction | 93.73 | YES | Arrange orbital rings to form target overlapping dark discs |
| 51 | G380 | Nightfall Sculptor | Shadow construction | 93.73 | YES | Transform a mesh through a sequence of target shadow silhouettes |
| 52 | G408 | Lumen Sudoku | Chromatic logic | 93.72 | YES | Solve a three-dimensional color placement puzzle across layered cubes |
| 53 | G372 | Eclipse Lantern | Shadow construction | 93.72 | YES | Reposition planets and lamps so a room's shadow sequence repeats |
| 54 | G426 | Voxel Origami | Spatial origami | 93.70 | YES | Reconfigure hinged voxels into a target solid without collisions |
| 55 | G454 | Clockwave Harbor | Temporal puzzles | 93.70 | YES | Phase-shift small orbital vessels to dock in a single time window |
| 56 | G021 | Prism Pathways | Spatial puzzles | 93.70 | YES | Rotate prisms to connect color-filtered light emitters to terminal crystals |
| 57 | G375 | Longlight Labyrinth | Shadow construction | 93.68 | YES | Shift time-of-day to reveal a hidden route drawn by cast shadows |
| 58 | G406 | Iridescent Channels | Chromatic logic | 93.67 | YES | Reorder wavelength filters to route colors through branching tubes |
| 59 | G292 | Lattice Bloom | Crystal solids | 93.66 | YES | Rotate repeated crystal unit cells until a glowing lattice closes |
| 60 | G297 | Glass Knot Studio | Crystal solids | 93.66 | YES | Thread transparent geometric ropes through interlocking crystal loops |
| 61 | G441 | Time Ribbon Relay | Temporal puzzles | 93.63 | YES | Rewind a moving light ribbon while changing one obstacle per loop |
| 62 | G212 | Gemstone Telegraph | Wave optics | 93.62 | YES | Encode and decode light pulses across a network of faceted prism towers |
| 63 | G227 | Soundglass Observatory | Acoustic geometry | 93.62 | YES | Tilt sound-sensitive glass to project wave shapes into geometric constellations |
| 64 | G209 | Refraction Foundry | Wave optics | 93.61 | YES | Shape virtual lenses to focus colored beams at targets inside a glass furnace |
| 65 | G295 | Prism Terrace | Crystal solids | 93.60 | YES | Stack rotating faceted platforms to redirect beams toward a center |
| 66 | G371 | Shadow Mosaic | Shadow construction | 93.60 | YES | Fill a target silhouette with overlapping projected 3D solids |
| 67 | G374 | Mirror Silhouette | Shadow construction | 93.59 | YES | Rotate mirrors and prisms to create a shadow image from indirect beams |
| 68 | G455 | Frozen Current | Temporal puzzles | 93.59 | YES | Pause and resume separate fluid streams to build a three-dimensional flow knot |
| 69 | G403 | Luminous Inversion | Chromatic logic | 93.57 | YES | Toggle dark and light zones to guide a glowing seed through an obstacle field |
| 70 | G355 | Starlit Cartouche | Celestial exploration | 93.56 | YES | Connect a moving starship route into a prescribed ancient symbol |
| 71 | G211 | Lightwell Labyrinth | Wave optics | 93.56 | YES | Connect light shafts across stacked rooms using reflective shutters |
| 72 | G433 | Crystal Papercraft | Spatial origami | 93.56 | YES | Convert flat polygon outlines into crystalline structures under constraints |
| 73 | G434 | Tetrahedral Labyrinth | Spatial origami | 93.56 | YES | Open selected solid faces to uncover a hidden route across cell layers |
| 74 | G453 | Time Tessellation | Temporal puzzles | 93.56 | YES | Schedule tile rotations so their projected paths form a pattern |
| 75 | G443 | Chrono Orchard | Temporal puzzles | 93.56 | YES | Plant seed events at different times so growing trees form target arches |
| 76 | G445 | Future Shadow | Temporal puzzles | 93.56 | YES | Position occluders now to meet a target shadow several seconds later |
| 77 | G220 | Bellflower Cavern | Acoustic geometry | 93.56 | YES | Strike floating bells in sequence to open procedural caves |
| 78 | G312 | Petal Palace | Folded architecture | 93.54 | YES | Close and unfold radial walls to route visitors represented by light points |
| 79 | G314 | Tessera Passage | Folded architecture | 93.53 | YES | Flip triangular platforms to connect a route across voids |
| 80 | G444 | Looped Waterfall | Temporal puzzles | 93.53 | YES | Change time offsets to bring waterfall drops into matching sockets |
| 81 | G404 | Iris Cascade | Chromatic logic | 93.52 | YES | Control an iris aperture chain to pass a precise sequence of colored pulses |
| 82 | G436 | Hypercube Windows | Spatial origami | 93.52 | YES | Rotate projections of a four-dimensional object to find a 3D path |
| 83 | G215 | Opal Circuit | Wave optics | 93.49 | YES | Route flowing light through crystal switches whose colors change with orientation |
| 84 | G388 | Cinder Symphony | Particle fields | 93.49 | YES | Tune upward thermal flows so ember particles strike bells |
| 85 | G202 | Spectral Cathedral | Wave optics | 93.49 | YES | Tune colored crystal ribs to produce a target spatial light chord |
| 86 | G218 | Resonance Locksmith | Acoustic geometry | 93.49 | YES | Match three-dimensional standing-wave nodes to unlock a sealed chamber |
| 87 | G300 | Tessellation Reef | Crystal solids | 93.46 | YES | Cover a curved reef with nonoverlapping crystal polyhedra |
| 88 | G359 | Celestial Eclipse Lab | Celestial exploration | 93.43 | YES | Position miniature orbits so sequential eclipses form a target sequence |
| 89 | G229 | Frequency Ferryman | Acoustic geometry | 93.43 | YES | Navigate a tiny craft through moving standing-wave walls by changing pitch |
| 90 | G201 | Caustic Courtyard | Wave optics | 93.42 | YES | Rotate mirrored arches so moving light rings illuminate hidden floor runes |
| 91 | G208 | Photon Loom | Wave optics | 93.42 | YES | Cross filaments of light through three-dimensional knots without tangling them |
| 92 | G382 | Stardust Weaver | Particle fields | 93.42 | YES | Draw attraction fields that braid star dust into luminous ribbons |
| 93 | G207 | Iridescent Vault | Wave optics | 93.42 | YES | Turn geometric irises until a hidden safe reveals its sequence of colors |
| 94 | G367 | Silhouette Bridge | Shadow construction | 93.41 | YES | Position cubes and cylinders to cast a traversable shadow bridge |
| 95 | G373 | Silhouette Reef | Shadow construction | 93.41 | YES | Plant rigid coral branches to cast a single shadow creature |
| 96 | G378 | Glass Shade | Shadow construction | 93.41 | YES | Place semitransparent panels to achieve a prescribed multicolor shadow |
| 97 | G366 | Shadowclock Atelier | Shadow construction | 93.41 | YES | Build a geometric sculpture whose shadow marks the correct time |
| 98 | G308 | Hinge Labyrinth | Folded architecture | 93.40 | YES | Pivot groups of rooms to create a continuous walkable route |
| 99 | G398 | Spectrum Loomhouse | Chromatic logic | 93.39 | YES | Weave colored ribbons between pegs without invalid crossings |
| 100 | G405 | Chroma Ribbons | Chromatic logic | 93.39 | YES | Twist layered ribbons to make a specified projected color arrangement |
| 101 | G431 | Kinetic Tessera | Spatial origami | 93.39 | YES | Drag triangulated folds to form a target three-dimensional relief |
| 102 | G437 | Polyhedral Tea Garden | Spatial origami | 93.38 | YES | Fold garden terraces around a solid core to route water between plants |
| 103 | G224 | Chord Chamber | Acoustic geometry | 93.38 | YES | Rearrange floating resonators until three sound fields overlap at the goal |
| 104 | G429 | Polyhedron Courier | Spatial origami | 93.37 | YES | Guide a bead over faces of a rotating polyhedron by unfolding pathways |
| 105 | G432 | Origami Orbit | Spatial origami | 93.37 | YES | Fold thin solar sails to capture light and change a miniature orbit |
| 106 | G391 | Dustlight Labyrinth | Particle fields | 93.36 | YES | Illuminate particle streams only at correct points to infer invisible exits |
| 107 | G315 | Rotary Stairwell | Folded architecture | 93.35 | YES | Twist stacked tower floors to create a continuous helix to the summit |
| 108 | G206 | Chromatic Observatory | Wave optics | 93.35 | YES | Align observatory shutters to separate three overlapping constellations |
| 109 | G228 | Vibration Garden | Acoustic geometry | 93.35 | YES | Tune ground resonators to make dormant geometric plants unfold |
| 110 | G394 | Pulse Flock | Particle fields | 93.34 | YES | Synchronize multiple swarms by changing phase and field shape |
| 111 | G427 | Spiral Net | Spatial origami | 93.33 | YES | Flatten and refold connected surfaces until two geometric marks meet |
| 112 | G351 | Nebula Navigator | Celestial exploration | 93.31 | YES | Chart a safe route through drifting interstellar fog using timed beacon flashes |
| 113 | G221 | Sonic Origami | Acoustic geometry | 93.31 | YES | Fold sound-reflecting panels into resonant three-dimensional instruments |
| 114 | G362 | Nebular Weave | Celestial exploration | 93.30 | YES | Adjust magnetic controls to turn drifting dust into constellation curtains |
| 115 | G298 | Gemstone Transit | Crystal solids | 93.28 | YES | Switch faceted nodes so traveling pulses reach the correct gems |
| 116 | G214 | Radiant Staircase | Wave optics | 93.28 | YES | Place luminous stairs to guide bouncing light upward through a tower |
| 117 | G225 | Echo Current | Acoustic geometry | 93.28 | YES | Turn sound mirrors to push an acoustic energy packet through branching spaces |
| 118 | G226 | Tuning Forest | Acoustic geometry | 93.28 | YES | Find resonant paths through an array of glowing tuning-fork trees |
| 119 | G428 | Folded Constellations | Spatial origami | 93.25 | YES | Fold a paper star map to align distant star groups across depth |
| 120 | G440 | Accordion Universe | Spatial origami | 93.25 | YES | Compress linked space strips to bring drifting planets into alignment |
| 121 | G240 | Wavepool Mosaic | Fluid flow | 93.24 | YES | Arrange baffles so colliding ripples reveal a target colored floor pattern |
| 122 | G390 | Petal Swarm | Particle fields | 93.23 | YES | Direct geometric petals as a coherent flock through floating hoops |
| 123 | G205 | Mirror Orchard | Wave optics | 93.23 | YES | Redirect sunbeams among tiny reflective trees to ripen luminous fruit |
| 124 | G381 | Firefly Signal | Particle fields | 93.23 | YES | Organize swarms of light points into evolving formation signals |
| 125 | G386 | Borealis Swarm | Particle fields | 93.23 | YES | Shepherd illuminated particles through auroral portals |
| 126 | G387 | Meteor Sketch | Particle fields | 93.23 | YES | Aim showers of particles to sketch a star symbol before they fade |
| 127 | G319 | Cube Unfurl | Folded architecture | 93.23 | YES | Choose a net arrangement for a cube whose faces contain matching channels |
| 128 | G219 | Echo Gallery | Acoustic geometry | 93.23 | YES | Find the shortest route through invisible galleries using reflections of sound |
| 129 | G310 | Folded Lighthouse | Folded architecture | 93.21 | YES | Fold a tower outward to redirect its beacon into hidden coves |
| 130 | G435 | Unfolded City | Spatial origami | 93.20 | YES | Expand a tiny 3D city into a planar blueprint to connect streets |
| 131 | G385 | Plasma Sculpt | Particle fields | 93.19 | NO | Shape particle flows into a stable 3D sculpture with field emitters |
| 132 | G389 | Cosmic Sandtable | Particle fields | 93.19 | NO | Drag gravitational wells to assemble galaxies of tiny glowing grains |
| 133 | G223 | Pulse Beacon Chase | Acoustic geometry | 93.19 | YES | Track a moving beacon through obscured chambers using limited pings |
| 134 | G023 | Foldscape | Spatial puzzles | 93.18 | YES | Fold panels to connect safe paths for a moving light seed |
| 135 | G353 | Exoplanet Atlas | Celestial exploration | 93.17 | YES | Derive a target planetary composition from orbital readings |
| 136 | G176 | Wave Choir | Light and color | 93.15 | YES | Align phase and amplitude so interacting sound waves solve a spatial chord |
| 137 | G254 | Apsides Workshop | Orbital dynamics | 93.14 | YES | Tune orbital eccentricity to sweep precise regions of a miniature sky |
| 138 | G302 | Quartz Labyrinth | Crystal solids | 93.14 | YES | Carve a short corridor inside a rotating transparent mineral block |
| 139 | G266 | Sunset Alchemist | Atmospheric fields | 93.14 | NO | Adjust atmospheric components to match a color target before sunset |
| 140 | G203 | Lantern Interference | Wave optics | 93.13 | YES | Slide floating lamps until their overlapping wavefronts trace a solution glyph |
| 141 | G393 | Shooting Star Garden | Particle fields | 93.13 | YES | Plant gravity wells to catch falling stars without collisions |
| 142 | G262 | Auroral Tuning Fork | Atmospheric fields | 93.11 | NO | Move magnet poles to create three intersecting auroral curtains |
| 143 | G264 | Zephyr Loom | Atmospheric fields | 93.11 | NO | Knot wind vectors into stable woven flow patterns over valleys |
| 144 | G356 | Pulsar Keeper | Celestial exploration | 93.10 | YES | Rotate detection dishes to follow rhythmic pulsar beams through space |
| 145 | G358 | Comet Harbor | Celestial exploration | 93.10 | YES | Dock light sails at orbiting stations using prediction arcs |
| 146 | G365 | Interstellar Orchard | Celestial exploration | 93.10 | YES | Cultivate glowing seed-worlds by balancing starlight and orbital distance |
| 147 | G369 | Penumbra Puzzlebox | Shadow construction | 93.10 | YES | Adjust occluders until multiple overlapping shadow softness regions match |
| 148 | G377 | Shadow Orchard Keeper | Shadow construction | 93.10 | YES | Prune procedural tree branches until their projection matches a glyph |
| 149 | G307 | Origami Observatory | Folded architecture | 93.10 | YES | Reconfigure a folding dome so its star apertures align |
| 150 | G204 | Halo Locksmith | Wave optics | 93.08 | YES | Adjust concentric light gates until a spectral key can travel through them |
| 151 | G210 | Tesseract Lanterns | Wave optics | 93.08 | YES | Reorient rotating cube lanterns to illuminate inaccessible dimensional corners |
| 152 | G430 | Infinity Fold | Spatial origami | 93.07 | YES | Rotate linked panels to make an impossible-looking continuous walkway |
| 153 | G438 | Mirrorfold Lab | Spatial origami | 93.07 | YES | Fold reflective polygons until a beam loops back to its source |
| 154 | G415 | Microscopic Aurora | Micro ecosystems | 93.06 | YES | Manipulate magnetic swimmers to build a glowing bacterial pattern |
| 155 | G164 | Particle Ballet | Light and color | 93.05 | YES | Draw orbital gestures to move swarms into emergent shapes |
| 156 | G414 | Mushroom Weather | Micro ecosystems | 93.04 | YES | Arrange fungi to create a stable forest humidity network |
| 157 | G416 | Algae Planet | Micro ecosystems | 93.04 | YES | Balance daylight and nutrient rings around a tiny water-covered planet |
| 158 | G317 | Fold Tide | Folded architecture | 93.04 | YES | Lift and crease flexible water tiles to redirect a moving current |
| 159 | G318 | Origami Windmill | Folded architecture | 93.04 | YES | Fold and unfold a rotor to capture changing winds |
| 160 | G306 | Paper Skybridges | Folded architecture | 93.04 | YES | Fold connected panels to span a gap without breaking a path |
| 161 | G311 | Kaleidoscope Bridge | Folded architecture | 93.04 | YES | Rotate hinged mirrored plates to connect a fragmented world image |
| 162 | G171 | Color Currents | Light and color | 93.02 | YES | Move current sources to braid contrasting ribbons into goal vortices |
| 163 | G383 | Confetti Gravity | Particle fields | 93.02 | YES | Redirect gravity so multicolored particles pass through moving rings |
| 164 | G384 | Magnetic Snow | Particle fields | 93.02 | YES | Position polar magnets to build specific drifting snowflake constellations |
| 165 | G475 | Photon Postal | Network routing | 93.01 | NO | Schedule colored light packets across intersections with one shared switch |
| 166 | G481 | Light Circuit Maze | Network routing | 93.01 | NO | Turn nodes to close an exact graph without crossing forbidden zones |
| 167 | G484 | Prism Exchange | Network routing | 93.01 | NO | Assign spectral channels to a 3D network without color conflicts |
| 168 | G418 | Twilight Moths | Micro ecosystems | 93.00 | YES | Guide motion-reactive geometric moths through a nocturnal flower garden |
| 169 | G249 | Binary Gardens | Orbital dynamics | 93.00 | YES | Balance twin stars to keep orbiting flower worlds within a light zone |
| 170 | G246 | Comet Shepherd | Orbital dynamics | 93.00 | YES | Place temporary gravity wells to herd a family of comets into target orbits |
| 171 | G213 | Sundial Constellation | Wave optics | 93.00 | YES | Rotate miniature celestial mechanisms until multiple projected shadows agree |
| 172 | G392 | Prism Dust | Particle fields | 92.99 | NO | Split a single particle beam into spectral bands and reunite it |
| 173 | G357 | Dust Ring Sculptor | Celestial exploration | 92.96 | YES | Move planet moons to shape bright rings into geometric motifs |
| 174 | G364 | Ringed Worlds | Celestial exploration | 92.96 | YES | Arrange moons to make orbiting ring shadows hit prescribed coordinates |
| 175 | G439 | Origami Snow Globe | Spatial origami | 92.96 | YES | Fold an enclosing shell around a glittering swarm without trapping it |
| 176 | G216 | Sonar Ruins | Acoustic geometry | 92.96 | YES | Locate hidden landmarks by choosing pulse positions and interpreting returning echoes |
| 177 | G222 | Whisper Atlas | Acoustic geometry | 92.96 | YES | Reconstruct lost miniature cities from sparse sonar returns |
| 178 | G269 | Windshadow Spires | Atmospheric fields | 92.95 | NO | Build towers whose wakes steer luminous spores to safe landings |
| 179 | G421 | Sporefall | Micro ecosystems | 92.94 | YES | Choose safe release points for airborne glowing spores to seed distant islands |
| 180 | G272 | Mistfold Chambers | Atmospheric fields | 92.94 | NO | Fold vapor layers to reveal geometric hidden passageways |
| 181 | G417 | Crystal Pond | Micro ecosystems | 92.91 | YES | Grow tessellated lily pads to balance light and water circulation |
| 182 | G352 | Blacklight Planetarium | Celestial exploration | 92.91 | YES | Reveal hidden stars by rotating ultraviolet-like filters around a dome |
| 183 | G276 | Mycelium Architect | Organic growth | 92.91 | YES | Feed fungal networks so glowing veins form a target graph around rocks |
| 184 | G313 | Accordion Isles | Folded architecture | 92.91 | YES | Compress and stretch modular land strips until destinations touch |
| 185 | G316 | Mirror Page | Folded architecture | 92.91 | YES | Fold mirrored pages to project a specified shape into a shadow box |
| 186 | G320 | Sky Quilt | Folded architecture | 92.91 | YES | Sew polygon panels into a draped three-dimensional floating quilt |
| 187 | G033 | Glasshouse Prisms | Spatial puzzles | 92.91 | YES | Reorient rooms and prism edges to illuminate all flowers |
| 188 | G233 | Tidal Lens | Fluid flow | 92.91 | YES | Focus circular water waves to move tiny floating pearls into sockets |
| 189 | G321 | Erosion Painter | Terrain alchemy | 92.90 | YES | Raise and lower terrain to coax rain into carving a target canyon |
| 190 | G334 | Crystal Quarry | Terrain alchemy | 92.90 | YES | Choose fracture paths to reveal a target gem network in rock |
| 191 | G022 | Shadow Sculptor | Spatial puzzles | 92.89 | YES | Transform volume objects until their projected silhouette matches a target |
| 192 | G419 | Tidal Petals | Micro ecosystems | 92.88 | YES | Control wave amplitude to keep floating flowers in a safe pattern |
| 193 | G231 | Mercury Channels | Fluid flow | 92.88 | NO | Sculpt a network of channels to guide metallic fluid toward matching basins |
| 194 | G472 | Crystal Pipeline | Network routing | 92.87 | NO | Rotate faceted pipe junctions to distribute light evenly across a network |
| 195 | G495 | Prism Glider | Arcade light trails | 92.86 | NO | Change color phase to pass through matching crystalline gates |
| 196 | G255 | Tidal Trio | Orbital dynamics | 92.86 | YES | Use three orbital bodies to stretch a luminous ocean into a pattern |
| 197 | G280 | Vine Spiral | Organic growth | 92.85 | YES | Train recursive vines around towers to reach high solar patches |
| 198 | G273 | Polar Stream | Atmospheric fields | 92.85 | NO | Guide a particle kite through changing geomagnetic loops |
| 199 | G122 | Starlight Surveyors | Cosmic puzzles | 92.84 | YES | Rotate a 3D observatory until starlight aligns through viewports |
| 200 | G309 | Mobius Tram | Folded architecture | 92.82 | YES | Change twists in a looped railway to deliver a packet to the right side |
| 201 | G263 | Stormglass Navigator | Atmospheric fields | 92.82 | NO | Guide a glider between cloud towers using local pressure controls |
| 202 | G275 | Vortex Aviary | Atmospheric fields | 92.82 | NO | Tame a set of wind vortices to maintain floating feather-like geometric kites |
| 203 | G360 | Star Nursery | Celestial exploration | 92.81 | YES | Merge sparse gas clouds into a series of luminous protostars |
| 204 | G477 | Gravity Junction | Network routing | 92.81 | NO | Rotate a gravity-controlled pipe manifold to sort rolling pearls by color |
| 205 | G259 | Cosmic Pendulum | Orbital dynamics | 92.81 | YES | Dampen chained orbital oscillations before a timed planetary eclipse |
| 206 | G412 | Glass Reef Gardener | Micro ecosystems | 92.80 | YES | Plant algorithmic corals to shelter a moving school of luminous fish-like particles |
| 207 | G411 | Bioluminescent Tide | Micro ecosystems | 92.80 | YES | Guide nutrient currents so tiny tidepool organisms light in sequence |
| 208 | G420 | Myco River | Micro ecosystems | 92.80 | YES | Connect fungal nodes so nutrients cross a miniature forest stream |
| 209 | G283 | Moss Labyrinth | Organic growth | 92.79 | YES | Grow and prune moss to reveal safe corridors for moving light seeds |
| 210 | G163 | Crystal Resonance | Light and color | 92.79 | YES | Tap crystal nodes to tune resonance and open light gates |
| 211 | G395 | Glitter Atlas | Particle fields | 92.79 | NO | Reconstruct a missing shape from three projected views of particle clouds |
| 212 | G268 | Frostline Symphony | Atmospheric fields | 92.78 | NO | Balance cold and warm currents to create crystalline cloud patterns |
| 213 | G274 | Cloud Prism Relay | Atmospheric fields | 92.78 | NO | Route sunbeams between misty peaks as cloud banks continually move |
| 214 | G327 | Meteor Crater Lab | Terrain alchemy | 92.77 | YES | Choose impact angles to imprint target crater arrangements |
| 215 | G361 | Solar Flare Pilot | Celestial exploration | 92.76 | YES | Steer a drone through repeating safe lanes between star eruptions |
| 216 | G363 | Gravity Window | Celestial exploration | 92.75 | YES | Move lenses of distorted space to reveal hidden distant objects |
| 217 | G478 | Windmill Grid | Network routing | 92.75 | NO | Connect miniature wind turbines while balancing unpredictable gusts |
| 218 | G180 | Neon Clay | Light and color | 92.75 | YES | Press and split neon clay masses to match an expressive sculpture |
| 219 | G253 | Ringworld Courier | Orbital dynamics | 92.74 | YES | Dock a glowing capsule by synchronizing motion with rotating rings |
| 220 | G267 | Rainbow Cartographer | Atmospheric fields | 92.74 | NO | Place mist sources and observer viewpoints to complete spectral arches |
| 221 | G282 | Biolume Nursery | Organic growth | 92.72 | YES | Balance nutrients so tiny living lamps bloom in a coordinated sequence |
| 222 | G238 | Prismatic Rapids | Fluid flow | 92.72 | YES | Redirect colored currents through a field of translucent pylons |
| 223 | G121 | Orbital Orchard | Cosmic puzzles | 92.72 | YES | Tune moon orbits so solar light lands on floating garden seeds |
| 224 | G234 | Liquid Sundial | Fluid flow | 92.71 | NO | Rotate a basin so flowing liquid traces a time-dependent target glyph |
| 225 | G424 | Firefly Pollination | Micro ecosystems | 92.70 | YES | Lead firefly clusters through timed flower openings |
| 226 | G252 | Orbit Mosaic | Orbital dynamics | 92.69 | YES | Link time-synchronized satellite paths into a closed decorative pattern |
| 227 | G248 | Satellite Lace | Orbital dynamics | 92.68 | YES | Weave nonintersecting satellite paths through moving orbital gates |
| 228 | G250 | Moonrise Mechanic | Orbital dynamics | 92.68 | YES | Adjust a microplanet spin until three moon shadows create a target symbol |
| 229 | G260 | Solar Mirror Fleet | Orbital dynamics | 92.67 | YES | Position orbital reflectors to illuminate darkness on multiple small worlds |
| 230 | G244 | Cobalt Tide Clock | Fluid flow | 92.67 | YES | Synchronize wave gates to transport a bead at the crest of each surge |
| 231 | G476 | Rootline Express | Network routing | 92.66 | NO | Grow root rails between distant forest clearings under length limits |
| 232 | G492 | Pulse Wings | Arcade light trails | 92.65 | NO | Tap to compress or expand a geometric wing and thread changing gaps |
| 233 | G473 | Cloudrail Switchyard | Network routing | 92.65 | NO | Route miniature skytrains through moving cloud islands without collisions |
| 234 | G490 | Photon Skater | Arcade light trails | 92.64 | NO | Trace an unbroken path along illuminated 3D edges before their color fades |
| 235 | G496 | Ribbon Spiral | Arcade light trails | 92.64 | NO | Maintain momentum while swapping among concentric orbit rails |
| 236 | G354 | Meteor Ballet | Celestial exploration | 92.63 | YES | Time a tiny probe's maneuvers to pass between meteor showers |
| 237 | G169 | Laser Ribbon | Light and color | 92.63 | YES | Manipulate luminous 3D fields in laser ribbon to complete clear spatial goals. |
| 238 | G256 | Asteroid Calligrapher | Orbital dynamics | 92.62 | YES | Arrange small asteroids so their projected paths spell a glyph over time |
| 239 | G257 | Microgravity Meadows | Orbital dynamics | 92.62 | YES | Reorient gravity vector to guide seeds across a rounded asteroid garden |
| 240 | G261 | Cloudbreak Cartography | Atmospheric fields | 92.62 | NO | Sculpt high-altitude winds to expose a constellation through moving cloud bands |
| 241 | G236 | Whirlpool Architect | Fluid flow | 92.62 | NO | Position vortices to guide multiple colored droplets into safe drains |
| 242 | G281 | Spore Observatory | Organic growth | 92.61 | YES | Release timed spore clouds so colonies land on matching star-shaped beds |
| 243 | G422 | Root Constellation | Micro ecosystems | 92.61 | YES | Orient seeds so root networks form a specified underground star map |
| 244 | G483 | Canopy Circuits | Network routing | 92.61 | NO | Connect tiny canopy bridges to distribute nutrients through trees |
| 245 | G239 | Viscous Labyrinth | Fluid flow | 92.61 | NO | Open and close valves to route a single slow fluid through an intricate maze |
| 246 | G245 | Gelatin Constellations | Fluid flow | 92.61 | NO | Jostle a transparent elastic blob so internal stars align |
| 247 | G336 | Pendulum Cathedral | Kinetic geometry | 92.59 | NO | Adjust pendulum lengths until swinging bells illuminate a target pattern |
| 248 | G340 | Kinetic Constellator | Kinetic geometry | 92.59 | NO | Connect moving points with spring struts to trace a target star figure |
| 249 | G279 | Lichen Cathedral | Organic growth | 92.59 | YES | Grow patterned lichen across 3D arches according to moisture rules |
| 250 | G323 | Glacier Sculptor | Terrain alchemy | 92.59 | YES | Route slow-moving ice to connect isolated valleys |
| 251 | G325 | Terrace Rivers | Terrain alchemy | 92.59 | YES | Carve terraces that carry water through three target gardens |
| 252 | G350 | Crankwave Lab | Kinetic geometry | 92.58 | YES | Tune linkages to produce a specified three-dimensional wave trajectory |
| 253 | G498 | Orbit Hurdle | Arcade light trails | 92.57 | NO | Tap to transfer between orbital lanes while dodging rotating geometric walls |
| 254 | G413 | Pollen Courier | Micro ecosystems | 92.57 | NO | Redirect micro-winds so pollen reaches the right flowers |
| 255 | G322 | Volcano Glassworks | Terrain alchemy | 92.57 | YES | Dig channels to cool lava into a prescribed geometric structure |
| 256 | G237 | Rainchain Atelier | Fluid flow | 92.57 | YES | Construct suspended drip chains that strike bells in a required rhythm |
| 257 | G232 | Inkstorm Sculptor | Fluid flow | 92.57 | NO | Paint currents that gather fluid pigment into a target 3D structure |
| 258 | G177 | Glow Maze | Light and color | 92.56 | YES | Manipulate luminous 3D fields in glow maze to complete clear spatial goals. |
| 259 | G482 | Nebula Freight | Network routing | 92.55 | NO | Synchronize colored cargo pods through a moving constellation of stations |
| 260 | G251 | Stellar Pinball | Orbital dynamics | 92.55 | YES | Bend a tiny meteor through slingshot arcs to hit celestial targets |
| 261 | G284 | Capillary Conductor | Organic growth | 92.54 | YES | Redirect fluid through leaf-vein networks to revive a miniature canopy |
| 262 | G286 | Seed Orbitarium | Organic growth | 92.53 | YES | Choose microgravity plant growth directions to assemble closed canopy rings |
| 263 | G425 | Micro Rainforest | Micro ecosystems | 92.52 | NO | Balance canopy shadow and moisture to keep a tiny animated biome alive |
| 264 | G330 | Lava Maze | Terrain alchemy | 92.52 | YES | Open basalt gates before a flowing lava front hardens |
| 265 | G471 | Neon Canalworks | Network routing | 92.52 | NO | Connect transparent canal modules so luminous liquid reaches six hubs |
| 266 | G270 | Nimbus Crossing | Atmospheric fields | 92.52 | NO | Connect drifting cloud islands with wind-formed tunnels |
| 267 | G271 | Monsoon Dial | Atmospheric fields | 92.52 | NO | Time terrain vents to move storms across a rotating microplanet |
| 268 | G278 | Root Lanterns | Organic growth | 92.51 | YES | Steer underground roots toward nutrient nodes using directional gradients |
| 269 | G285 | Crystal Fungus | Organic growth | 92.51 | YES | Guide a hybrid fungal-crystal organism to bridge gaps without fracture |
| 270 | G287 | Phosphor Tangle | Organic growth | 92.51 | YES | Untangle luminous algae tendrils by manipulating local attraction fields |
| 271 | G288 | Branch Choir | Organic growth | 92.51 | YES | Arrange growth cues so tree branches produce spatial harmonic silhouettes |
| 272 | G265 | Thunderhead Garden | Atmospheric fields | 92.51 | NO | Guide rain clouds toward isolated glass gardens without flooding them |
| 273 | G485 | Kinetic Metro | Network routing | 92.50 | NO | Build a miniature rail circuit whose moving trains drive mechanical sculptures |
| 274 | G247 | Gravity Harp | Orbital dynamics | 92.50 | YES | Pluck planetoid orbits into a harmonic chord without collisions |
| 275 | G235 | Flowglass Foundry | Fluid flow | 92.48 | NO | Join fluid streams so they cool into exactly shaped glass sculptures |
| 276 | G025 | Glacier Garden | Spatial puzzles | 92.48 | NO | Slide/glide frozen blocks to open melt-water channels |
| 277 | G168 | Liquid Glass Tiles | Light and color | 92.47 | NO | Tile a reflective volume so light streams make a coherent pattern |
| 278 | G486 | Neon Slipstream | Arcade light trails | 92.46 | NO | Steer a glowing glider through a twisting ribbon tunnel by shifting between lanes |
| 279 | G488 | Aurora Surf | Arcade light trails | 92.46 | NO | Surf a bright moving ribbon while timing jumps between parallel auroral streams |
| 280 | G493 | Marble Comet | Arcade light trails | 92.46 | NO | Tilt a floating track to keep a comet marble inside its luminous lane |
| 281 | G290 | Petal Circuit | Organic growth | 92.46 | YES | Propagate electrical pulses through a garden of connected petal-flowers |
| 282 | G166 | Glow River | Light and color | 92.46 | YES | Manipulate luminous 3D fields in glow river to complete clear spatial goals. |
| 283 | G167 | Prism Garden | Light and color | 92.46 | YES | Manipulate luminous 3D fields in prism garden to complete clear spatial goals. |
| 284 | G342 | Spiral Escapement | Kinetic geometry | 92.45 | NO | Tune rotating wheel teeth to release a light droplet at exact moments |
| 285 | G329 | Dune Resonator | Terrain alchemy | 92.45 | YES | Set wind emitters to form specified rippling patterns in sand |
| 286 | G170 | Reflection Pool | Light and color | 92.44 | YES | Manipulate luminous 3D fields in reflection pool to complete clear spatial goals. |
| 287 | G479 | Plasma Switchboard | Network routing | 92.42 | NO | Route pulsed plasma through interlocking loops without overheating |
| 288 | G487 | Comet Slalom | Arcade light trails | 92.41 | NO | Swipe to weave a comet between moving orbit rings without touching them |
| 289 | G500 | Particle Runway | Arcade light trails | 92.41 | NO | Turn a minimal 3D particle stream into a coherent path through drifting obstacles |
| 290 | G243 | Silt Cartographer | Fluid flow | 92.41 | YES | Change current direction to uncover a hidden relief map in sand |
| 291 | G474 | Circuit Waterfall | Network routing | 92.40 | NO | Design stepped connections that carry water and energy between towers |
| 292 | G494 | Kaleido Dash | Arcade light trails | 92.39 | NO | Navigate a mirrored hall by choosing the one non-reflected route |
| 293 | G341 | Balance Bazaar | Kinetic geometry | 92.39 | YES | Arrange geometrical weights to keep a stack of moving sculpture plates steady |
| 294 | G242 | Ink Bloom Vault | Fluid flow | 92.39 | NO | Trigger growth pulses to make three-dimensional ink flowers fit a mold |
| 295 | G489 | Crystal Drift | Arcade light trails | 92.38 | NO | Drift a small orb around faceted pillars while chaining perfect near misses |
| 296 | G491 | Starboard Runner | Arcade light trails | 92.38 | NO | Jump between rotating spaceship rails to capture energy rings |
| 297 | G499 | Solar Streak | Arcade light trails | 92.38 | NO | Aim a solar sail through small sunbeams to maintain flight |
| 298 | G338 | Gyroscopic Abbey | Kinetic geometry | 92.38 | NO | Stabilize rotating suspended rooms using controllable spin axes |
| 299 | G328 | Mountain Lightkeeper | Terrain alchemy | 92.38 | YES | Reposition peaks so the sun touches marked landforms at sunrise |
| 300 | G332 | Ridge Relay | Terrain alchemy | 92.38 | YES | Raise mountain ridges to guide gliding light signals between summits |
| 301 | G423 | Gossamer Reef | Micro ecosystems | 92.36 | YES | Grow strands of silk-like coral to catch falling motes without blocking water |
| 302 | G258 | Kepler Carousel | Orbital dynamics | 92.36 | YES | Predict where multiple planets meet and place time-limited orbital gates |
| 303 | G179 | Spectrum Seasons | Light and color | 92.34 | YES | Manipulate luminous 3D fields in spectrum seasons to complete clear spatial goals. |
| 304 | G241 | Liquid Marble Maze | Fluid flow | 92.34 | NO | Tilt a glass labyrinth to merge and split luminous fluid marbles |
| 305 | G277 | Coral Calculus | Organic growth | 92.32 | YES | Guide reef growth to surround safe areas without blocking currents |
| 306 | G333 | River Meander | Terrain alchemy | 92.32 | YES | Nudge a river's banks to connect nutrient deposits without flooding |
| 307 | G480 | Terrace Trams | Network routing | 92.28 | NO | Assemble cable cars between floating mountain terraces using pulleys |
| 308 | G326 | Seafloor Cartographer | Terrain alchemy | 92.27 | YES | Change local currents to uncover a hidden 3D underwater map |
| 309 | G349 | Suspended Equilibrium | Kinetic geometry | 92.26 | YES | Place magnetic counterweights to hold a floating geometric shrine in balance |
| 310 | G337 | Clockwork Garden | Kinetic geometry | 92.25 | NO | Turn a small gear network so mechanical flowers open in sequence |
| 311 | G339 | Marble Resonator | Kinetic geometry | 92.21 | NO | Place bumpers so a rolling pearl strikes chimes in a chord |
| 312 | G497 | Gravity Surfboard | Arcade light trails | 92.20 | NO | Shift local gravity to ride a procedurally generated low-poly moon canyon |
| 313 | G346 | Helix Elevator | Kinetic geometry | 92.20 | NO | Set elevator pitches so a bead rides a moving corkscrew upward |
| 314 | G331 | Tidepool Relief | Terrain alchemy | 92.19 | YES | Alter coastline elevations to trap water in small safe pools |
| 315 | G335 | Horizon Sculpt | Terrain alchemy | 92.19 | YES | Move terrain control points to form a precise sky silhouette |
| 316 | G324 | Sandline Architect | Terrain alchemy | 92.18 | YES | Tilt a miniature desert to make dunes expose buried monuments |
| 317 | G344 | Orbiting Chimes | Kinetic geometry | 92.13 | YES | Route a bouncing point among rotating musical rings |
| 318 | G347 | Spinning Top Grove | Kinetic geometry | 92.12 | NO | Tune gyroscopic tops to maintain a network of fragile bridges |
| 319 | G348 | Kaleido Mechanism | Kinetic geometry | 92.12 | NO | Rewire a mechanical linkage to transform a moving mandala pattern |
| 320 | G289 | Bonsai Rain Engine | Organic growth | 92.08 | YES | Shape miniature canopies to collect enough rainfall for new shoots |
| 321 | G173 | Nebula Shaper | Light and color | 92.00 | NO | Sculpt floating nebula shells to uncover hidden constellation paths |
| 322 | G345 | Counterweight Cascade | Kinetic geometry | 91.96 | NO | Adjust lever lengths to guide luminous balls down interlocking machines |
| 323 | G343 | Harmonic Mobile | Kinetic geometry | 91.87 | NO | Suspend articulated branches until moving weights stop crossing |
| 324 | G137 | Solar Sail Racer | Cosmic puzzles | 91.69 | NO | Steer a light-driven craft through timed gravitational gates |
| 325 | G138 | Gravity Painter | Cosmic puzzles | 91.66 | NO | Paint gravitational fields until comet-streaks trace target shapes |
| 326 | G084 | Firefly Meadow | Nature simulations | 91.65 | NO | Guide firefly swarms to pollinate nocturnal meadow patches |
| 327 | G165 | Light Painting Lab | Light and color | 91.65 | NO | Manipulate luminous 3D fields in light painting lab to complete clear spatial goals. |
| 328 | G129 | Satellite Swarm | Cosmic puzzles | 91.62 | NO | Place and time orbiting relays to keep a beam network stable |
| 329 | G134 | Aurora Navigators | Cosmic puzzles | 91.60 | NO | Guide a magnetic explorer by twisting an aurora field |
| 330 | G135 | Plasma Cartographer | Cosmic puzzles | 91.53 | NO | Map safe routes between charge nodes while the field reshapes |
| 331 | G126 | Galaxy Cartographer | Cosmic puzzles | 91.52 | NO | Draw navigable routes among discovered galactic landmarks |
| 332 | G127 | Meteor Gardener | Cosmic puzzles | 91.48 | NO | Catch/redirect meteors to cultivate comet-flower islands |
| 333 | G081 | Pocket Planet Gardener | Nature simulations | 91.36 | NO | Balance moisture and sunlight to fill a planetoid with life |
| 334 | G175 | Shadow Theater | Light and color | 91.34 | NO | Manipulate luminous 3D fields in shadow theater to complete clear spatial goals. |
| 335 | G172 | Fractal Doodles | Light and color | 91.34 | NO | Manipulate luminous 3D fields in fractal doodles to complete clear spatial goals. |
| 336 | G188 | Elevation Logic | Logic and patterns | 91.33 | NO | Solve tactile geometric rules in elevation logic, with undo and seeded puzzles. |
| 337 | G195 | Polyhedral Puzzles | Logic and patterns | 91.27 | NO | Solve tactile geometric rules in polyhedral puzzles, with undo and seeded puzzles. |
| 338 | G174 | Kaleidoscope Towers | Light and color | 91.25 | NO | Manipulate luminous 3D fields in kaleidoscope towers to complete clear spatial goals. |
| 339 | G024 | Lantern Coast | Spatial puzzles | 91.24 | NO | Aim lighthouse lenses around cliffs to light safe shipping paths |
| 340 | G085 | Mycelium Grove | Nature simulations | 91.04 | NO | Connect nutrient nodes while preserving a living forest floor |
| 341 | G178 | Photon Pinball | Light and color | 90.87 | NO | Redirect photons to light a procedural pinball constellation |
| 342 | G140 | Nebula Mining | Cosmic puzzles | 90.86 | NO | Explore and solve spatial orbital riddles in nebula mining without real-time services. |
| 343 | G077 | Laser Logistics | Routing games | 90.83 | NO | Route glowing parcels around crossing constraints |
| 344 | G125 | Planetary Pinball | Cosmic puzzles | 90.81 | NO | Explore and solve spatial orbital riddles in planetary pinball without real-time services. |
| 345 | G102 | Kite Weather | Arcade movement | 90.79 | NO | Adjust kite line tension to navigate rising gust corridors |
| 346 | G139 | Planet Hopping | Cosmic puzzles | 90.76 | NO | Explore and solve spatial orbital riddles in planet hopping without real-time services. |
| 347 | G075 | Volcano Plumbing | Routing games | 90.72 | NO | Open valves to turn a small volcano into a functioning thermal machine |
| 348 | G131 | Starship Folding | Cosmic puzzles | 90.68 | NO | Explore and solve spatial orbital riddles in starship folding without real-time services. |
| 349 | G132 | Rings of Saturn | Cosmic puzzles | 90.66 | NO | Explore and solve spatial orbital riddles in rings of saturn without real-time services. |
| 350 | G039 | Lightwell Ladder | Spatial puzzles | 90.66 | NO | Rotate, fold or align 3D objects in lightwell ladder to satisfy a clear geometry rule. |
| 351 | G124 | Comet Collector | Cosmic puzzles | 90.63 | NO | Explore and solve spatial orbital riddles in comet collector without real-time services. |
| 352 | G133 | Stellar Garden | Cosmic puzzles | 90.57 | NO | Explore and solve spatial orbital riddles in stellar garden without real-time services. |
| 353 | G027 | Path of Reflections | Spatial puzzles | 90.47 | NO | Rotate, fold or align 3D objects in path of reflections to satisfy a clear geometry rule. |
| 354 | G136 | Eclipse Keeper | Cosmic puzzles | 90.45 | NO | Explore and solve spatial orbital riddles in eclipse keeper without real-time services. |
| 355 | G123 | Tiny Solar Smith | Cosmic puzzles | 90.43 | NO | Explore and solve spatial orbital riddles in tiny solar smith without real-time services. |
| 356 | G130 | Gravity Atlas | Cosmic puzzles | 90.41 | NO | Explore and solve spatial orbital riddles in gravity atlas without real-time services. |
| 357 | G082 | Tidepool Keepers | Nature simulations | 90.39 | NO | Position shelter/rocks and tune tide flow so a tidepool survives |
| 358 | G034 | Clockface Puzzles | Spatial puzzles | 90.33 | NO | Rotate, fold or align 3D objects in clockface puzzles to satisfy a clear geometry rule. |
| 359 | G062 | Windmill Valley | Routing games | 90.32 | NO | Channel variable winds to power small hillside communities |
| 360 | G128 | Moon Base Maze | Cosmic puzzles | 90.31 | NO | Explore and solve spatial orbital riddles in moon base maze without real-time services. |
| 361 | G109 | Neon Orbit Sprint | Arcade movement | 90.27 | NO | Swipe lanes and match orbit timing through short arcade courses |
| 362 | G120 | Star Sailor | Arcade movement | 90.23 | NO | Steer a light sail between pulsating star gateways |
| 363 | G141 | Mosaic Machines | Craft and arrange | 90.15 | NO | Rotate and assemble moving mosaics to trigger a kinetic reveal |
| 364 | G038 | Underworld Switches | Spatial puzzles | 90.06 | NO | Rotate, fold or align 3D objects in underworld switches to satisfy a clear geometry rule. |
| 365 | G030 | Hinge Harbor | Spatial puzzles | 90.03 | NO | Rotate, fold or align 3D objects in hinge harbor to satisfy a clear geometry rule. |
| 366 | G031 | Perspective Bridges | Spatial puzzles | 90.02 | NO | Rotate, fold or align 3D objects in perspective bridges to satisfy a clear geometry rule. |
| 367 | G035 | Paper Doorways | Spatial puzzles | 90.01 | NO | Rotate, fold or align 3D objects in paper doorways to satisfy a clear geometry rule. |
| 368 | G040 | Spatial Silk | Spatial puzzles | 89.94 | NO | Rotate, fold or align 3D objects in spatial silk to satisfy a clear geometry rule. |
| 369 | G037 | Topology Toys | Spatial puzzles | 89.94 | NO | Rotate, fold or align 3D objects in topology toys to satisfy a clear geometry rule. |
| 370 | G041 | Marble Garden Run | Physics toys | 89.87 | NO | Place a limited set of track pieces, then release the ball |
| 371 | G036 | Echo Shapes | Spatial puzzles | 89.87 | NO | Rotate, fold or align 3D objects in echo shapes to satisfy a clear geometry rule. |
| 372 | G032 | Model Box Escape | Spatial puzzles | 89.83 | NO | Rotate, fold or align 3D objects in model box escape to satisfy a clear geometry rule. |
| 373 | G028 | Pebble Portals | Spatial puzzles | 89.81 | NO | Rotate, fold or align 3D objects in pebble portals to satisfy a clear geometry rule. |
| 374 | G105 | Cavern Glider | Arcade movement | 89.80 | NO | Glide through gentle cave currents and collect light seeds |
| 375 | G092 | Kelp Forest Builder | Nature simulations | 89.67 | NO | Position kelp anchors to protect a miniature marine habitat |
| 376 | G026 | Mirror Maze Minis | Spatial puzzles | 89.64 | NO | Rotate, fold or align 3D objects in mirror maze minis to satisfy a clear geometry rule. |
| 377 | G007 | Crystal Bonsai | Cozy builders | 89.55 | NO | Prune and grow crystalline branches so light reaches fruit nodes |
| 378 | G029 | Magnetic Museums | Spatial puzzles | 89.47 | NO | Rotate, fold or align 3D objects in magnetic museums to satisfy a clear geometry rule. |
| 379 | G152 | Kinetic Ornament Studio | Craft and arrange | 89.46 | NO | Link gears that turn an ornament into a living motion sculpture |
| 380 | G086 | Coral Nursery | Nature simulations | 89.09 | NO | Balance a tiny living environment in coral nursery using local, stylized ecological rules. |
| 381 | G056 | Gyro Garden | Physics toys | 89.01 | NO | Tune gyroscopic spin to stabilize a miniature suspended garden |
| 382 | G048 | Magnetic Marbles | Physics toys | 88.88 | NO | Place magnets to guide a chain of rolling marbles |
| 383 | G185 | Crystal Circuit | Logic and patterns | 88.82 | NO | Solve tactile geometric rules in crystal circuit, with undo and seeded puzzles. |
| 384 | G182 | Isometric Numbers | Logic and patterns | 88.75 | NO | Solve tactile geometric rules in isometric numbers, with undo and seeded puzzles. |
| 385 | G193 | Gear Logic | Logic and patterns | 88.74 | NO | Solve tactile geometric rules in gear logic, with undo and seeded puzzles. |
| 386 | G189 | Pattern Painter | Logic and patterns | 88.69 | NO | Solve tactile geometric rules in pattern painter, with undo and seeded puzzles. |
| 387 | G199 | Pocket Observatory | Logic and patterns | 88.68 | NO | Solve tactile geometric rules in pocket observatory, with undo and seeded puzzles. |
| 388 | G200 | Paradox Blocks | Logic and patterns | 88.68 | NO | Solve tactile geometric rules in paradox blocks, with undo and seeded puzzles. |
| 389 | G198 | Beacon Builder | Logic and patterns | 88.67 | NO | Solve tactile geometric rules in beacon builder, with undo and seeded puzzles. |
| 390 | G187 | Hex Garden Paths | Logic and patterns | 88.65 | NO | Solve tactile geometric rules in hex garden paths, with undo and seeded puzzles. |
| 391 | G196 | Tile Logic | Logic and patterns | 88.64 | NO | Solve tactile geometric rules in tile logic, with undo and seeded puzzles. |
| 392 | G192 | Bridge of Arrows | Logic and patterns | 88.61 | NO | Solve tactile geometric rules in bridge of arrows, with undo and seeded puzzles. |
| 393 | G191 | Switchbox Stories | Logic and patterns | 88.57 | NO | Solve tactile geometric rules in switchbox stories, with undo and seeded puzzles. |
| 394 | G194 | Rotating Rooms | Logic and patterns | 88.53 | NO | Solve tactile geometric rules in rotating rooms, with undo and seeded puzzles. |
| 395 | G014 | Dream Lanterns | Cozy builders | 88.51 | NO | Build light patterns inside hovering lanterns to guide moths |
| 396 | G190 | Terrace Triangles | Logic and patterns | 88.48 | NO | Solve tactile geometric rules in terrace triangles, with undo and seeded puzzles. |
| 397 | G184 | Shape Stack | Logic and patterns | 88.47 | NO | Solve tactile geometric rules in shape stack, with undo and seeded puzzles. |
| 398 | G183 | Garden Sudoku | Logic and patterns | 88.46 | NO | Solve tactile geometric rules in garden sudoku, with undo and seeded puzzles. |
| 399 | G186 | Tactile Tangram | Logic and patterns | 88.44 | NO | Solve tactile geometric rules in tactile tangram, with undo and seeded puzzles. |
| 400 | G197 | Signal Post | Logic and patterns | 88.44 | NO | Solve tactile geometric rules in signal post, with undo and seeded puzzles. |
| 401 | G061 | Tiny Railworks | Routing games | 87.49 | NO | Build tiny, tactile railways across moving archipelagos |
| 402 | G043 | Gravity Post Office | Physics toys | 87.38 | NO | Deliver parcels through a rotating miniature gravity bureau |
| 403 | G001 | Pocket Terrarium Architect | Cozy builders | 87.26 | NO | Place terrain/plant rules to make a stable pocket ecosystem |
| 404 | G045 | Skybridge Builders | Physics toys | 87.23 | NO | Span hovering islands with playful load-bearing walkways |
| 405 | G114 | Pebble Skipper | Arcade movement | 86.93 | NO | Steer through short 3D courses in pebble skipper with minimal, skill-based touch controls. |
| 406 | G118 | Tunnel Tumbler | Arcade movement | 86.92 | NO | Steer through short 3D courses in tunnel tumbler with minimal, skill-based touch controls. |
| 407 | G108 | Tide Runner | Arcade movement | 86.91 | NO | Steer through short 3D courses in tide runner with minimal, skill-based touch controls. |
| 408 | G044 | Toybox Contraptions | Physics toys | 86.91 | NO | Link harmless wooden toys into silly chain-reaction machines |
| 409 | G110 | Toy Plane Pilot | Arcade movement | 86.86 | NO | Steer through short 3D courses in toy plane pilot with minimal, skill-based touch controls. |
| 410 | G103 | Cloud Hopper | Arcade movement | 86.85 | NO | Steer through short 3D courses in cloud hopper with minimal, skill-based touch controls. |
| 411 | G067 | Circuit Canals | Routing games | 86.82 | NO | Draw a little network in circuit canals, then optimize bottlenecks with touch gestures. |
| 412 | G116 | Spiral Dash | Arcade movement | 86.80 | NO | Steer through short 3D courses in spiral dash with minimal, skill-based touch controls. |
| 413 | G117 | Pinball Peaks | Arcade movement | 86.79 | NO | Steer through short 3D courses in pinball peaks with minimal, skill-based touch controls. |
| 414 | G112 | Moon Bounce | Arcade movement | 86.79 | NO | Steer through short 3D courses in moon bounce with minimal, skill-based touch controls. |
| 415 | G063 | Lunar Parcel Network | Routing games | 86.76 | NO | Draw a little network in lunar parcel network, then optimize bottlenecks with touch gestures. |
| 416 | G107 | Lava Hop | Arcade movement | 86.75 | NO | Steer through short 3D courses in lava hop with minimal, skill-based touch controls. |
| 417 | G119 | Wind Rider | Arcade movement | 86.72 | NO | Steer through short 3D courses in wind rider with minimal, skill-based touch controls. |
| 418 | G069 | Paper Boats Route | Routing games | 86.72 | NO | Draw a little network in paper boats route, then optimize bottlenecks with touch gestures. |
| 419 | G115 | Ice Skate Trail | Arcade movement | 86.70 | NO | Steer through short 3D courses in ice skate trail with minimal, skill-based touch controls. |
| 420 | G073 | Delivery Drones | Routing games | 86.70 | NO | Draw a little network in delivery drones, then optimize bottlenecks with touch gestures. |
| 421 | G078 | Micro Pipeline | Routing games | 86.68 | NO | Draw a little network in micro pipeline, then optimize bottlenecks with touch gestures. |
| 422 | G111 | Paper Wings | Arcade movement | 86.67 | NO | Steer through short 3D courses in paper wings with minimal, skill-based touch controls. |
| 423 | G065 | Pebble Post | Routing games | 86.66 | NO | Draw a little network in pebble post, then optimize bottlenecks with touch gestures. |
| 424 | G080 | Elevated City | Routing games | 86.63 | NO | Draw a little network in elevated city, then optimize bottlenecks with touch gestures. |
| 425 | G064 | Cable Car Islands | Routing games | 86.60 | NO | Draw a little network in cable car islands, then optimize bottlenecks with touch gestures. |
| 426 | G106 | Bubble Surf | Arcade movement | 86.58 | NO | Steer through short 3D courses in bubble surf with minimal, skill-based touch controls. |
| 427 | G066 | Tram Garden | Routing games | 86.57 | NO | Draw a little network in tram garden, then optimize bottlenecks with touch gestures. |
| 428 | G113 | Marble Drift | Arcade movement | 86.54 | NO | Steer through short 3D courses in marble drift with minimal, skill-based touch controls. |
| 429 | G068 | Pocket Airport | Routing games | 86.54 | NO | Draw a little network in pocket airport, then optimize bottlenecks with touch gestures. |
| 430 | G072 | Ferry Microstate | Routing games | 86.50 | NO | Draw a little network in ferry microstate, then optimize bottlenecks with touch gestures. |
| 431 | G104 | Sky Skater | Arcade movement | 86.49 | NO | Steer through short 3D courses in sky skater with minimal, skill-based touch controls. |
| 432 | G070 | Waterwheel Works | Routing games | 86.49 | NO | Draw a little network in waterwheel works, then optimize bottlenecks with touch gestures. |
| 433 | G079 | Space Dock Scheduling | Routing games | 86.40 | NO | Draw a little network in space dock scheduling, then optimize bottlenecks with touch gestures. |
| 434 | G076 | Orchard Pipes | Routing games | 86.33 | NO | Draw a little network in orchard pipes, then optimize bottlenecks with touch gestures. |
| 435 | G054 | Toy Sailboats | Physics toys | 86.22 | NO | Arrange a pocket-sized kinetic toy in toy sailboats and solve repeatable mechanical goals. |
| 436 | G050 | Bubble Buoyancy | Physics toys | 86.17 | NO | Arrange a pocket-sized kinetic toy in bubble buoyancy and solve repeatable mechanical goals. |
| 437 | G057 | Elastic Orbit | Physics toys | 86.16 | NO | Arrange a pocket-sized kinetic toy in elastic orbit and solve repeatable mechanical goals. |
| 438 | G046 | Rolling Ruins | Physics toys | 86.08 | NO | Arrange a pocket-sized kinetic toy in rolling ruins and solve repeatable mechanical goals. |
| 439 | G059 | Balance Bubbles | Physics toys | 86.03 | NO | Arrange a pocket-sized kinetic toy in balance bubbles and solve repeatable mechanical goals. |
| 440 | G051 | Mechanical Mini-Golf | Physics toys | 86.00 | NO | Arrange a pocket-sized kinetic toy in mechanical mini-golf and solve repeatable mechanical goals. |
| 441 | G052 | Tower Tumbler | Physics toys | 85.99 | NO | Arrange a pocket-sized kinetic toy in tower tumbler and solve repeatable mechanical goals. |
| 442 | G047 | Pendulum Park | Physics toys | 85.99 | NO | Arrange a pocket-sized kinetic toy in pendulum park and solve repeatable mechanical goals. |
| 443 | G053 | Driftwood Dams | Physics toys | 85.97 | NO | Arrange a pocket-sized kinetic toy in driftwood dams and solve repeatable mechanical goals. |
| 444 | G060 | Wind-Up Circus | Physics toys | 85.95 | NO | Arrange a pocket-sized kinetic toy in wind-up circus and solve repeatable mechanical goals. |
| 445 | G049 | Domino Docks | Physics toys | 85.89 | NO | Arrange a pocket-sized kinetic toy in domino docks and solve repeatable mechanical goals. |
| 446 | G074 | Beetle Bus Lines | Routing games | 85.77 | NO | Draw a little network in beetle bus lines, then optimize bottlenecks with touch gestures. |
| 447 | G071 | Conveyor Coffee | Routing games | 85.60 | NO | Draw a little network in conveyor coffee, then optimize bottlenecks with touch gestures. |
| 448 | G087 | Rainforest Terrarium | Nature simulations | 85.44 | NO | Balance a tiny living environment in rainforest terrarium using local, stylized ecological rules. |
| 449 | G101 | Rooftop Rendezvous | Arcade movement | 85.25 | NO | Guide a tiny courier along a looping city skyline without combat |
| 450 | G089 | Seedling Slope | Nature simulations | 84.93 | NO | Balance a tiny living environment in seedling slope using local, stylized ecological rules. |
| 451 | G042 | Clockwork Critter Workshop | Physics toys | 84.91 | NO | Assemble joyful wind-up animals from mechanical modules |
| 452 | G058 | Kaleidoscope Catcher | Physics toys | 84.82 | NO | Arrange a pocket-sized kinetic toy in kaleidoscope catcher and solve repeatable mechanical goals. |
| 453 | G091 | Pollinator Islands | Nature simulations | 84.79 | NO | Balance a tiny living environment in pollinator islands using local, stylized ecological rules. |
| 454 | G096 | Fossil Garden | Nature simulations | 84.79 | NO | Balance a tiny living environment in fossil garden using local, stylized ecological rules. |
| 455 | G099 | Alpine Streamkeeper | Nature simulations | 84.72 | NO | Balance a tiny living environment in alpine streamkeeper using local, stylized ecological rules. |
| 456 | G083 | Orchard Clouds | Nature simulations | 84.71 | NO | Balance a tiny living environment in orchard clouds using local, stylized ecological rules. |
| 457 | G093 | Meadow Microclimate | Nature simulations | 84.66 | NO | Balance a tiny living environment in meadow microclimate using local, stylized ecological rules. |
| 458 | G098 | Pond Balance | Nature simulations | 84.62 | NO | Balance a tiny living environment in pond balance using local, stylized ecological rules. |
| 459 | G095 | Snowcap Life | Nature simulations | 84.57 | NO | Balance a tiny living environment in snowcap life using local, stylized ecological rules. |
| 460 | G097 | Desert Bloom | Nature simulations | 84.56 | NO | Balance a tiny living environment in desert bloom using local, stylized ecological rules. |
| 461 | G090 | Mossy Rain Cycle | Nature simulations | 84.54 | NO | Balance a tiny living environment in mossy rain cycle using local, stylized ecological rules. |
| 462 | G100 | Feather Habitat | Nature simulations | 84.24 | NO | Balance a tiny living environment in feather habitat using local, stylized ecological rules. |
| 463 | G094 | Reef Cleanup | Nature simulations | 84.15 | NO | Balance a tiny living environment in reef cleanup using local, stylized ecological rules. |
| 464 | G055 | Catapult Cottage | Physics toys | 83.76 | NO | Arrange a pocket-sized kinetic toy in catapult cottage and solve repeatable mechanical goals. |
| 465 | G088 | Butterfly Bay | Nature simulations | 83.26 | NO | Balance a tiny living environment in butterfly bay using local, stylized ecological rules. |
| 466 | G002 | Snowglobe Stories | Cozy builders | 82.55 | NO | Compose tiny scenes inside interactive weather globes |
| 467 | G150 | Paper Mill Works | Craft and arrange | 78.54 | NO | Assemble and arrange tangible little 3D objects in paper mill works with purposeful end states. |
| 468 | G160 | Parcel Wrapping | Craft and arrange | 78.50 | NO | Assemble and arrange tangible little 3D objects in parcel wrapping with purposeful end states. |
| 469 | G158 | Clockmaker Desk | Craft and arrange | 78.40 | NO | Assemble and arrange tangible little 3D objects in clockmaker desk with purposeful end states. |
| 470 | G156 | Tea Blending | Craft and arrange | 78.37 | NO | Assemble and arrange tangible little 3D objects in tea blending with purposeful end states. |
| 471 | G153 | Bottle Boat Builder | Craft and arrange | 78.37 | NO | Assemble and arrange tangible little 3D objects in bottle boat builder with purposeful end states. |
| 472 | G147 | Musical Toymaker | Craft and arrange | 78.34 | NO | Assemble and arrange tangible little 3D objects in musical toymaker with purposeful end states. |
| 473 | G142 | Mechanical Matchbox | Craft and arrange | 78.34 | NO | Assemble and arrange tangible little 3D objects in mechanical matchbox with purposeful end states. |
| 474 | G148 | Toy Train Painting | Craft and arrange | 78.34 | NO | Assemble and arrange tangible little 3D objects in toy train painting with purposeful end states. |
| 475 | G155 | Candy Conveyor | Craft and arrange | 78.33 | NO | Assemble and arrange tangible little 3D objects in candy conveyor with purposeful end states. |
| 476 | G143 | Potion Bottle Lab | Craft and arrange | 78.23 | NO | Assemble and arrange tangible little 3D objects in potion bottle lab with purposeful end states. |
| 477 | G011 | Micro Townmaker | Cozy builders | 78.18 | NO | Build an original miniature 3D scene around the theme of micro townmaker; experiment with reversible scenic rules. |
| 478 | G015 | Little Castle Cartographer | Cozy builders | 78.16 | NO | Build an original miniature 3D scene around the theme of little castle cartographer; experiment with reversible scenic rules. |
| 479 | G009 | Floating Tea Garden | Cozy builders | 78.14 | NO | Build an original miniature 3D scene around the theme of floating tea garden; experiment with reversible scenic rules. |
| 480 | G154 | Ceramic Studio | Craft and arrange | 78.12 | NO | Assemble and arrange tangible little 3D objects in ceramic studio with purposeful end states. |
| 481 | G016 | Witch Hut Dioramas | Cozy builders | 78.04 | NO | Build an original miniature 3D scene around the theme of witch hut dioramas; experiment with reversible scenic rules. |
| 482 | G019 | Stack-a-Village | Cozy builders | 78.01 | NO | Build an original miniature 3D scene around the theme of stack-a-village; experiment with reversible scenic rules. |
| 483 | G008 | Moss Village | Cozy builders | 77.99 | NO | Build an original miniature 3D scene around the theme of moss village; experiment with reversible scenic rules. |
| 484 | G018 | Quiet Spaceport | Cozy builders | 77.99 | NO | Build an original miniature 3D scene around the theme of quiet spaceport; experiment with reversible scenic rules. |
| 485 | G012 | Island Postcards | Cozy builders | 77.95 | NO | Build an original miniature 3D scene around the theme of island postcards; experiment with reversible scenic rules. |
| 486 | G006 | Seaside Sculptures | Cozy builders | 77.91 | NO | Build an original miniature 3D scene around the theme of seaside sculptures; experiment with reversible scenic rules. |
| 487 | G010 | Bottle Biomes | Cozy builders | 77.77 | NO | Build an original miniature 3D scene around the theme of bottle biomes; experiment with reversible scenic rules. |
| 488 | G004 | Rooftop Gardens | Cozy builders | 77.77 | NO | Build an original miniature 3D scene around the theme of rooftop gardens; experiment with reversible scenic rules. |
| 489 | G013 | Pebble Gardens | Cozy builders | 77.76 | NO | Build an original miniature 3D scene around the theme of pebble gardens; experiment with reversible scenic rules. |
| 490 | G003 | Micro Museum Curator | Cozy builders | 77.47 | NO | Arrange a tiny museum where exhibits tell delightful visual stories |
| 491 | G146 | Clay Stamp Workshop | Craft and arrange | 77.30 | NO | Assemble and arrange tangible little 3D objects in clay stamp workshop with purposeful end states. |
| 492 | G149 | Micro Garden Shop | Craft and arrange | 77.29 | NO | Assemble and arrange tangible little 3D objects in micro garden shop with purposeful end states. |
| 493 | G151 | Puzzle Bakery | Craft and arrange | 77.11 | NO | Assemble and arrange tangible little 3D objects in puzzle bakery with purposeful end states. |
| 494 | G145 | Tiny Bakery 3D | Craft and arrange | 77.09 | NO | Assemble and arrange tangible little 3D objects in tiny bakery 3d with purposeful end states. |
| 495 | G157 | Dollhouse Arrange | Craft and arrange | 77.01 | NO | Assemble and arrange tangible little 3D objects in dollhouse arrange with purposeful end states. |
| 496 | G159 | Windup Shop | Craft and arrange | 76.93 | NO | Assemble and arrange tangible little 3D objects in windup shop with purposeful end states. |
| 497 | G144 | Cozy Camera Studio | Craft and arrange | 76.75 | NO | Assemble and arrange tangible little 3D objects in cozy camera studio with purposeful end states. |
| 498 | G005 | Clockwork Cottage | Cozy builders | 76.74 | NO | Build an original miniature 3D scene around the theme of clockwork cottage; experiment with reversible scenic rules. |
| 499 | G020 | Diorama Florist | Cozy builders | 76.72 | NO | Build an original miniature 3D scene around the theme of diorama florist; experiment with reversible scenic rules. |
| 500 | G017 | Miniature Film Sets | Cozy builders | 76.66 | NO | Build an original miniature 3D scene around the theme of miniature film sets; experiment with reversible scenic rules. |

## 11. Failure modes and the critical-thinking response

**A visual demo is not a game.** The required discriminator is a puzzle or simulation whose choices matter. If players enjoy watching but cannot describe a decision, move it to VisualCore demo gallery, not the $3.99 games catalog.

**A high score is not statistical prediction.** The 300 new candidates inherit category-specific priors and deterministic semantic adjustments. The earlier 200 use different, historically assessed hand-tuned judgments; this is *transparent but not blinded or independently calibrated*. Do not infer that new-vs-old rank differences are evidence of demand.

**The source landscape is not exhaustive.** The current study reviews a handful of influential PC titles and published top-paid charts, not every competitor in the App Store. Commission an exact keyword/name/trademark search and test competitor gameplay before final decisions.

**Technology scope risk.** ANGLE's iOS Metal support does not establish fast blur, transparency or signed-distance traversal on D3. Build efficient approximations and measure shader translation and pipeline compilation; preserve Xcode and ANGLE fork reproducibility.

**Visual similarity within the portfolio.** This is a real product and App Review threat. Prototype in themed waves; if two games feel interchangeable, merge mechanics into one richer app rather than releasing both.

**Paid market cost.** A no-ad strategy is a product quality choice, not evidence that organic discovery is free. Invest in genuine trailers captured from the real renderer, screenshots, player research, reviews and community participation—not promotional ad networks.

## 12. Final recommendation: build only what the evidence earns

**First three technical prototypes:** Aurora Loom for spectacular ribbon/color shader fundamentals; Lissajous Labyrinth for deterministic math-driven gameplay; Wave Knot Keeper for spatial depth and topology interaction. **But do not ship all three as separate apps before proving distinct mechanics**, because their visual language overlaps. A more diversified trial might use Aurora Loom, Echo Cartographer and Voxel Origami for different kinds of interaction.

**Two-stage proof:** (1) code-only complete playable vertical slices with simulator acceptance, distinctive art and a standalone paid-game loop; (2) after portfolio-wide implementation lock, D1/D2/D3 stress evidence and a small real-player comprehension test. Only then select release waves. This separates engineering possibility from actual customer appetite.

## Sources and audit references

- **apple:** https://apps.apple.com/us/iphone/room/6756363168
- **sensortower:** https://sensortower.com/press/press-release-sensor-tower-state-of-gaming-gaming-drove-52-billion-downloads-82b-iap-revenue-on-mobile-and-12b-premium-revenue-on-steam
- **steamdb:** https://steamdb.info/tag/1654/?min_reviews=500
- **tiny:** https://store.steampowered.com/app/2198150/Tiny_Glade/
- **dorf:** https://store.steampowered.com/app/1455840/Dorfromantik/
- **metro:** https://store.steampowered.com/app/287980/Mini_Metro/
- **glass:** https://store.steampowered.com/app/511470/Glass_Masquerade/
- **bridge:** https://store.steampowered.com/app/1850160/Poly_Bridge_3/
- **town:** https://store.steampowered.com/app/1291340/Townscaper/
- **hardware:** https://store.steampowered.com/hwsurvey/
- **angle:** https://github.com/google/angle
- **apple_perf:** https://developer.apple.com/documentation/Metal/improving-your-games-graphics-performance-and-settings
- **apple_hud:** https://developer.apple.com/videos/play/meet-with-apple/242/
- **apple_guidelines:** https://developer.apple.com/app-store/review/guidelines/
- **legal:** https://www.copyright.gov/register/tx-games.html

The accompanying `Market-Evidence-Register.csv` classifies each source and specifies what it does **not** establish. `Audit-Manifest.json` records SHA-256 hashes and selection weights, and `build_500_study.py` plus `candidate_seeds.txt` allow local regeneration from the preserved earlier 200. Source data and linked market pages should be refreshed before investment or release.

