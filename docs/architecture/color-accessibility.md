# Colour accessibility: perceptual colour, colour vision and non-colour clues

Feature 210 (R02-F10). Spec: [specs/210-spectral-color-non-color-clue-accessibility](../../specs/210-spectral-color-non-color-clue-accessibility/spec.md).

## The rule

A rule that an experience codes by colour must also be readable without colour. Each coded state carries a colour, a
drawn shape, a fill pattern and a written name. `CodedStateSet` (VisualCoreParameters) refuses a set in which two states
share both shape and pattern, a name is empty or repeated, an id is repeated or malformed, a colour is not finite or not
in 0…1, or there are more than 32 states (8 shapes × 4 patterns). The name is what VoiceOver reads.

## Perceptual colour

`PerceptualColor` converts sRGB ↔ linear light ↔ OKLab ↔ OKLCh. Colour difference is the Euclidean OKLab distance
(ΔE_OK). Hue rotation keeps lightness and chroma and turns only the hue; greys are unchanged. A result outside the sRGB
gamut is brought back by bisecting chroma for 24 steps at constant lightness and hue, never by clipping channels.
`relativeLuminance` and `contrastRatio` follow WCAG 2.x; `AccessibleColors.contrastRatio` (VisualCoreUI) uses the same
formula. `outlineRings(for:on:)` gives a clue an inner black or white ring that contrasts with the state colour (at least
4.58:1) and, where that ring is below 3:1 against the background, an outer ring of the opposite colour, so the outermost
ring always reaches 3:1 (WCAG 1.4.11); `outline(for:on:)` keeps the single best outline.

## Colour vision

`ColorVisionCondition` simulates protanopia, deuteranopia and tritanopia with the Machado, Oliveira and Fernandes
matrices at severity 1.0, in linear light, and achromatopsia by relative luminance. `PaletteSeparation.issues` reports
every pair of colours closer than ΔE_OK 0.08 under normal vision or any of the four conditions. The three presets of
`ColorVisionPresets` (`cvd-warm-cool`, `cvd-red-cyan`, `cvd-lightness`) were built in code from OKLCh lightness ladders,
pinned as sRGB stops, and pass that check under all five conditions. The player's choice is
`AccessibilityPreferences.colorVision` (`standard`, `warmCool`, `redCyan`, `lightness`), stored in the app's shell
preferences and handed to every experience.

## Drawing the clues

`vc/clue.glsl` draws the shapes and patterns as signed distances on the existing renderer, with the same formulas as the
CPU reference `ClueReference`; `vc/spectral.glsl` offers the OKLab conversions, hue rotation and the deficiency
simulation. Both match their CPU references within 2/255 on the iOS 27.2 and 26.5 simulators. No image, font or icon
file is used. `ClueBadge` (VisualCoreUI) draws a clue with its outline and name at Dynamic Type sizes.

## Failure reports

Every refusal throws `ColorAccessError`, whose `reasonCode` is one of `r2-f10.non-finite`, `r2-f10.out-of-range`,
`r2-f10.same-clue`, `r2-f10.empty-name`, `r2-f10.duplicate-name`, `r2-f10.duplicate-id`, `r2-f10.too-many-states`, with the
offending index or ids. The experience that reports it adds its own id, seed and tick.

## Sources and licences

- OKLab: Björn Ottosson, "A perceptual color space for image processing", 2020 (bottosson.github.io/posts/oklab).
  The conversion matrices are published there; the reference code is offered under the MIT licence or public domain.
- Colour-vision simulation: G. M. Machado, M. M. Oliveira, L. A. F. Fernandes, "A Physiologically-based Model for
  Simulation of Color Vision Deficiency", IEEE Transactions on Visualization and Computer Graphics 15(6), 2009. The
  severity-1.0 matrices are published in the paper; matrices are facts and carry no licence of their own.
- 2D signed-distance formulas (box, equilateral triangle, hexagon, five-point star): Inigo Quilez, "2D distance
  functions" (iquilezles.org/articles/distfunctions2d), code under the MIT licence.
- WCAG 2.x relative luminance and contrast ratio: W3C Recommendation (W3C document licence).

The presets, the choice of shapes and patterns and all code are original to VisualCore.
