# Research: Fractal Explorer — Phase 04 High-resolution capture and tours

## R1 — Relative cost (G-COST)

- **Decision**: `RenderCostEstimate(pixels:iterations:samples:)` with `relative(to reference:) -> Double` =
  (p·i·s)/(p₀·i₀·s₀); `Level` light (≤ 2), moderate (≤ 10), heavy (> 10) via `level(ratio:lightMax:moderateMax:)`;
  `text(ratio:)` gives two significant digits ("1×", "2.5×", "63×"). Invalid (non-positive) inputs count as 1.
- **Rationale**: escape-time cost is proportional to pixels × iterations (an upper bound; interior pixels hit the cap).
  Relative only, so no device timing is implied. Generic for A22 Shader Studio loops and A24 benchmarks.
- **Alternatives**: a measured frame time (device-dependent; forbidden as a claim before the device campaign).

## R2 — Framing flight (G-TOUR)

- **Decision**: `FramingFlight(from:to:)` → `framing(at t: Double, curve: EasingCurve = .sine)`: u = ease(t);
  log s = lerp(log s₀, log s₁, u); c = c₁ + (c₀ − c₁)(s − s₁)/(s₀ − s₁) (linear in u when s₀ ≈ s₁); t ≥ 1 returns the
  target exactly. When |c₁ − c₀| > s₀/2, `FramingFlight.route(from:to:)` returns two flights via a framing at the
  midpoint with span max(s₀, s₁, 2|c₁ − c₀|).
- **Rationale**: proven property (spec clarification 2): the target's offset stays within |Δ|/s₀ of the view.
- **Alternatives**: van Wijk–Nuij optimal paths (heavier; unnecessary for curated stops).

## R3 — Tour timeline

- **Decision**: `TourTimeline(start:stops:flightDuration:hold:reduceMotion:)`; `state(at:)` → (framing, stopIndex,
  phase flying/holding/finished). Reduce Motion: flights take 0 s (jump), holds unchanged.
- **Rationale**: pure and host-testable; the app only feeds time.

## R4 — Still capture (G-CAPTURE)

- **Decision**: `StillCapture(folder: TemporaryFolder)`; `capture(host:size:prefix:) -> Result` with `state`
  (idle/done(URL)/failed(String)), `lastImage`, `removeFile()`; message mapping as A02 (`invalidSize` → "This picture
  size is too large for this device.").
- **Rationale**: identical needs in A01, A02, A03 and later apps.

## R5 — Precision-limited capture size

- **Decision**: `CaptureSizing.longEdge(requested:canvas:viewport:mantissaBits:)`: the largest even long edge ≤
  requested such that per-pixel step = span_long / longEdge ≥ advisor minimum, and never below the canvas's own long
  edge in pixels (screen scale). Then `ExportGeometry` applies the device caps.

## R6 — Float spacing fixture

- **Decision**: compare `PrecisionAdvisor.minimumPixelStep(mantissaBits: 23, magnitude: m)` with `Float(m).ulp` and
  10 bits with `Float16(m).ulp` (available on Apple platforms; on other hosts the 10-bit case uses 2^(⌊log2 m⌋−10)) for
  magnitudes 2⁻²⁰…4 (48 values including powers of two and their neighbours). Expect ulp ≤ step ≤ 2·ulp.

## R7 — Tours

- **Decision**: three Mandelbrot tours with published coordinates: Seahorse Valley (−0.743643887, 0.131825904),
  Elephant Valley (0.282, 0.0105), Mini Mandelbrot (−1.75, 0); each with 3 stops at spans 4 → ~0.05 → ~0.002, captions
  under 120 characters. Spans stay within 23-bit precision on a 3× display (checked by a test).
