# VisualCore — 25 standalone iOS app implementation manuals

These Markdown files expand the 25 concepts in the supplied `AppsBrainstorm.md` using the architecture constraints in its companion VisualCore `README.md`.

**Important:** These are detailed **implementation plans**, not completed repositories, tested apps, or verified new VisualCore APIs. They use the existing ProjectM / ANGLE / Metal foundation by consuming VisualCore as an independent framework.

**Spec Kit command note:** The current Claude Code integration uses `/speckit-<command>` skills; `specify init --here --integration claude --script py` selects Claude and Python helpers. Verify the installed release before running commands.

## Contents

| No. | App | Category | Brainstorm rank | File |
|---:|---|---|---:|---|
| 01 | Generative Art Studio | Creative and visual | 1 | [01-generative-art-studio.md](01-generative-art-studio.md) |
| 02 | Fluid Art Playground | Creative and visual | 2 | [02-fluid-art-playground.md](02-fluid-art-playground.md) |
| 03 | Fractal Explorer | Creative and visual | — | [03-fractal-explorer.md](03-fractal-explorer.md) |
| 04 | Particle Universe | Creative and visual | 7 | [04-particle-universe.md](04-particle-universe.md) |
| 05 | Infinite Geometry | Creative and visual | — | [05-infinite-geometry.md](05-infinite-geometry.md) |
| 06 | VisualCore Music Lab | Music and audio | — | [06-visualcore-music-lab.md](06-visualcore-music-lab.md) |
| 07 | Audio Odyssey | Music and audio | 6 | [07-audio-odyssey.md](07-audio-odyssey.md) |
| 08 | Oscilloscope Studio | Music and audio | — | [08-oscilloscope-studio.md](08-oscilloscope-studio.md) |
| 09 | Digital Aquarium | Music and audio | 3 | [09-digital-aquarium.md](09-digital-aquarium.md) |
| 10 | Neon Arcade | Games and interactive experiences | — | [10-neon-arcade.md](10-neon-arcade.md) |
| 11 | Physics Playground | Games and interactive experiences | — | [11-physics-playground.md](11-physics-playground.md) |
| 12 | Tiny Worlds | Games and interactive experiences | — | [12-tiny-worlds.md](12-tiny-worlds.md) |
| 13 | Light Maze | Games and interactive experiences | — | [13-light-maze.md](13-light-maze.md) |
| 14 | Solar System Explorer | Education and science | — | [14-solar-system-explorer.md](14-solar-system-explorer.md) |
| 15 | Molecular Explorer | Education and science | — | [15-molecular-explorer.md](15-molecular-explorer.md) |
| 16 | Simulation Lab | Education and science | 9 | [16-simulation-lab.md](16-simulation-lab.md) |
| 17 | Interactive Anatomy | Education and science | — | [17-interactive-anatomy.md](17-interactive-anatomy.md) |
| 18 | Ambient Clock | Ambient and lifestyle | 8 | [18-ambient-clock.md](18-ambient-clock.md) |
| 19 | Living Wallpapers | Ambient and lifestyle | — | [19-living-wallpapers.md](19-living-wallpapers.md) |
| 20 | Digital Zen Garden | Ambient and lifestyle | 5 | [20-digital-zen-garden.md](20-digital-zen-garden.md) |
| 21 | Aurora | Ambient and lifestyle | — | [21-aurora.md](21-aurora.md) |
| 22 | Shader Studio | Developer and creator tools | 4 | [22-shader-studio.md](22-shader-studio.md) |
| 23 | Visual Programming Lab | Developer and creator tools | — | [23-visual-programming-lab.md](23-visual-programming-lab.md) |
| 24 | Graphics Benchmark Lab | Developer and creator tools | — | [24-graphics-benchmark-lab.md](24-graphics-benchmark-lab.md) |
| 25 | Effects Composer | Developer and creator tools | 10 | [25-effects-composer.md](25-effects-composer.md) |

## Recommended use

1. Complete the read-only VisualCore audit and publish an actual, audited client integration before writing product-specific EGL/ANGLE code.
2. Start with one app that genuinely exercises the intended shared capability. The brainstorm identifies a VisualCore Studio experience as a recommended flagship; the dedicated Generative Art Studio plan is an appropriate narrow first vertical slice.
3. Keep each app as a consumer repository or as an explicitly approved app target in a monorepo. The individual plans assume a separate app repo with a local `../VisualCore` development checkout and ultimately a pinned package dependency.
4. Initialize Spec Kit once per new repository, generate and review feature artifacts, implement only bounded task groups, and validate on a physical iOS device.
5. Maintain independent content license, privacy, accessibility and evidence records for each app.

## Shared technical rules

- Preserve existing OpenGL ES through ANGLE to Metal. No duplicate render backend.
- Do not link unrelated applications against ProjectM internals; ProjectM is VisualCore’s pinned reference consumer.
- VisualCore API/package names are provisional until repository audit.
- Build and device graphics QA require macOS/Xcode.
- Unsupported other-app system audio capture, automatic live wallpaper installation, and unverified scientific or GPU precision claims are explicitly out of scope.
- The app-specific documentation includes Python automation examples, not PowerShell scripts.

## Source and command documentation

- Original supplied sources: `AppsBrainstorm.md` and `README.md` (not duplicated in this archive).
- Existing reference: https://github.com/Coastrnaut/projectm-ios
- Spec Kit: https://github.com/github/spec-kit
- Claude integration: https://github.github.com/spec-kit/integrations/claude.html
- Spec Kit CLI: https://github.github.com/spec-kit/reference/core.html

## Manifest checks

- File count: **25 standalone app manuals**.
- Total lines across manuals: **16,168**.
- Total bytes across manuals: **1,347,611**.
