# Shader Studio (`a22.shader-studio`)

A mobile GLSL ES editor that compiles local shaders, shows diagnostics and safely previews bounded work (archived
manual `apps/22-shader-studio.md` §1–§2). Version 0.1 covers:
- a code editor with syntax assistance and line-numbered diagnostics;
- local GLSL ES fragment shader templates with defined uniforms and texture inputs;
- an explicit Compile and Run action with a last-known-good preview fallback;
- a parameter inspector for bounded uniforms;
- local project save and open with versioned shader files;
- resource and complexity limits, a watchdog and recoverable failures.

Non-goals: running privileged native code, a public shader marketplace, and any claim of a secure sandbox against a
hostile GPU shader. GLSL is GPU code; a shader can still stress a driver, so the preview is capped and can always be
stopped and reset.

Shader Studio is an experience of the one VisualCore app (ADR-0009). From Phase 01 on it is built in
`Packages/ExperiencesCreative/ShaderStudio`, and it never has a standalone target. Templates and their textures are
written in code. It works offline, sends nothing and needs no permission. Its rules are the A22 subsection of the
constitution (2.18.1).

| Document | Content |
|---|---|
| [visualcore-contract.json](visualcore-contract.json) / [.md](visualcore-contract.md) | Phase 00 inventory, capability matrix, gaps, decision (checked by `scripts/check_app_contract.py`) |
| [regression-baseline.md](regression-baseline.md) | Phase start, reference pin, the ProjectM reference regression results |
