# Research: A21-P04 (feature 155)

- **D1 Seamless by construction:** every partial and the swell have whole cycles per loop, so the buffer wraps with no
  click and needs no crossfade. Alternative: a crossfaded noise bed; rejected (a seam to hide, not to avoid).
- **D2 A player of its own:** a looping node per player, not a voice of `SoundEffectPlayer`, so one-shot tones and the
  loop never compete for voices. Alternative: extend `SoundEffectPlayer`; rejected (one-shot semantics).
- **D3 Still view over `CachedScene`:** the existing still-frame tool; the key is the digest and the size.
- **D4 Reduced flash by slowing, not filtering:** no twinkle and slower changes meet the step; `FlashLimiterModel` is
  for `EffectScene` and is not needed here.
- **D5 Fallback as a minimal shader:** a gradient compiles where the full shader fails; the clear colour is the last
  resort.
