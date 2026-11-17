# Contract: Living Wallpapers interface and campaign (A19-P05)

- **`LWExportUITests`:**
  - fresh start, iPhone SE template, Export: the progress finishes, the message names "PNG", "750 × 1334" and
    "sRGB", `share` exists, and a history line names iPhone SE;
  - with `-lwExportLimit 1024` and the iPhone 16 Pro template, `export-notice` names 2622 × 1206 or 1206 × 2622, the
    limit 1024 and the offered size; `export-offered` exports, and the message names the offered size.
- **`LWClaimsUITests`:** the joined static texts and button labels of the experience and its help sheet contain none
  of the refused phrases, and the help contains "You set the wallpaper yourself".
- **Each interface test:** under 60 s.
- **Campaign:** 8 rows, each with device, procedure, threshold and "pending device campaign"; no number.
