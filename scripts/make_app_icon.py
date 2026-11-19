#!/usr/bin/env python3
"""Draws the VisualCore app icon in code (CLAUDE.md rule 4: visuals are code; no purchased or generated art).

The icon is a deterministic procedural picture, 1024 x 1024 RGB with no alpha (App Store requirement):

- a deep-navy field with a soft violet glow toward the centre;
- six luminous orbit ellipses rotated by 30 degrees each, forming a rosette, each tinted along a cyan - violet -
  magenta - amber ramp by its angle around the centre;
- a bright core: a white-cyan orb with a wide halo.

Light is added in linear space and tone-mapped with 1 - exp(-x), then encoded to sRGB. Pure Python (zlib only), so
it runs without extra packages. Run from the repository root:

    python3 scripts/make_app_icon.py

It writes Apps/VisualCore/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png and its Contents.json.
"""
import json
import math
import struct
import sys
import zlib
from pathlib import Path

SIZE = 1024
OUT_DIR = Path("Apps/VisualCore/Resources/Assets.xcassets/AppIcon.appiconset")

# Colour ramp around the rosette (linear RGB).
RAMP = [
    (0.10, 0.85, 1.00),  # cyan
    (0.45, 0.35, 1.00),  # violet
    (1.00, 0.25, 0.80),  # magenta
    (1.00, 0.62, 0.18),  # amber
]


def ramp(t: float) -> tuple:
    """Colour at t in [0, 1) on the cyclic ramp."""
    t = (t % 1.0) * len(RAMP)
    i = int(t)
    f = t - i
    a, b = RAMP[i % len(RAMP)], RAMP[(i + 1) % len(RAMP)]
    f = f * f * (3 - 2 * f)
    return tuple(a[k] + (b[k] - a[k]) * f for k in range(3))


def srgb(x: float) -> int:
    """Linear 0..1 to an sRGB byte."""
    x = min(max(x, 0.0), 1.0)
    y = 12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055
    return int(round(y * 255))


# Six ellipses: semi-axes (a, b), rotation, ramp phase.
ORBITS = [(0.78, 0.26, math.radians(30 * k), k / 6.0) for k in range(6)]
ROT = [(math.cos(r), math.sin(r)) for _, _, r, _ in ORBITS]


def pixel(u: float, v: float) -> tuple:
    """Linear RGB at u, v in [-1, 1] (v up)."""
    r2 = u * u + v * v
    r = math.sqrt(r2)
    # Field: navy with a violet bloom toward the centre.
    bloom = math.exp(-r2 * 2.2)
    col = [0.004 + 0.030 * bloom, 0.005 + 0.012 * bloom, 0.020 + 0.070 * bloom]
    ang = math.atan2(v, u) / (2 * math.pi)
    for (a, b, _, phase), (c, s) in zip(ORBITS, ROT):
        x = c * u + s * v
        y = -s * u + c * v
        q = math.sqrt((x / a) ** 2 + (y / b) ** 2)
        d = abs(q - 1.0) * b  # approximate distance to the ellipse
        line = math.exp(-(d / 0.0085) ** 2) * 1.6 + math.exp(-d / 0.03) * 0.07
        if line < 1e-4:
            continue
        # Tint by the angle along the ellipse, so each orbit sweeps the ramp.
        t = math.atan2(y / b, x / a) / (2 * math.pi) + phase
        tint = ramp(t)
        fade = 0.55 + 0.45 * math.exp(-r2 * 0.8)
        for k in range(3):
            col[k] += tint[k] * line * fade
    # Core orb and halo.
    core = math.exp(-(r / 0.085) ** 2) * 6.0
    halo = math.exp(-(r / 0.22) ** 2) * 0.6
    col[0] += core * 0.85 + halo * 0.25
    col[1] += core * 0.95 + halo * 0.55
    col[2] += core * 1.00 + halo * 0.95
    # A faint outer ring framing the rosette.
    ring = math.exp(-((r - 0.9) / 0.008) ** 2) * 0.45
    tint = ramp(ang + 0.2)
    for k in range(3):
        col[k] += tint[k] * ring
    return tuple(1.0 - math.exp(-c * 1.05) for c in col)


def write_png(path: Path, rows: list) -> None:
    """Writes 8-bit RGB rows as a PNG."""
    raw = b"".join(b"\x00" + bytes(row) for row in rows)

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    path.write_bytes(png)


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    rows = []
    for j in range(SIZE):
        v = 1.0 - 2.0 * (j + 0.5) / SIZE
        row = bytearray()
        for i in range(SIZE):
            u = 2.0 * (i + 0.5) / SIZE - 1.0
            rgb = pixel(u, v)
            row += bytes(srgb(c) for c in rgb)
        rows.append(row)
    write_png(OUT_DIR / "AppIcon-1024.png", rows)
    contents = {
        "images": [{"filename": "AppIcon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
        "info": {"author": "xcode", "version": 1},
    }
    (OUT_DIR / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
    (OUT_DIR.parent / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    print(f"wrote {OUT_DIR / 'AppIcon-1024.png'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
