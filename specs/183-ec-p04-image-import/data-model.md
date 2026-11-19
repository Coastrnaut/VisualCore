# Data Model: A25-P04

- **ImportedPicture:** width, height (8…limit), bytes (RGBA8 straight alpha, rows top-down, sRGB).
- **ImportRefusal:** `imageDamaged` (`a25.image-damaged`), `imageTooLarge` (`a25.image-too-large`, data above 50 MiB),
  `imageTooSmall` (`a25.image-too-small`, under 8 on a side); each with its sentence.
- **Picture source:** built-in test picture or an imported picture; not stored.
