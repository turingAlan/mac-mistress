#!/usr/bin/env python3
"""Generate aesthetic DMG background and square icon for Mac Mistress."""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math


def generate_bg(w, h, filename):
    bg = Image.new("RGBA", (w, h))
    draw = ImageDraw.Draw(bg)

    # Light gradient background (soft white to light lavender)
    for y in range(h):
        t = y / h
        r = int(245 - t * 10)
        g = int(243 - t * 12)
        b = int(250 - t * 5)
        draw.line([(0, y), (w, y)], fill=(r, g, b, 255))

    # Subtle purple radial glow in center
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    cx, cy = w // 2, h // 2
    max_r = int(min(w, h) * 0.55)
    for radius in range(max_r, 0, -1):
        alpha = int(18 * (1 - radius / max_r))
        glow_draw.ellipse(
            [cx - radius, cy - radius, cx + radius, cy + radius],
            fill=(160, 120, 220, alpha),
        )
    bg = Image.alpha_composite(bg, glow)

    # Top accent gradient line (purple to blue)
    accent = Image.new("RGBA", (w, 3), (0, 0, 0, 0))
    accent_draw = ImageDraw.Draw(accent)
    for x in range(w):
        t = x / w
        r = int(140 + t * 40)
        g = int(80 + t * 50)
        b = int(220 - t * 30)
        accent_draw.point((x, 0), fill=(r, g, b, 180))
        accent_draw.point((x, 1), fill=(r, g, b, 100))
        accent_draw.point((x, 2), fill=(r, g, b, 30))
    bg.paste(accent, (0, 0), accent)

    # Arrow between icon positions
    arrow_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    arrow_draw = ImageDraw.Draw(arrow_layer)
    arrow_y = int(h * 0.45)
    arrow_x_start = int(w * 0.36)
    arrow_x_end = int(w * 0.64)

    # Soft purple arrow shaft
    for i in range(3):
        arrow_draw.line(
            [(arrow_x_start, arrow_y + i - 1), (arrow_x_end - 15, arrow_y + i - 1)],
            fill=(140, 100, 200, 70),
        )
    # Arrow head
    head_size = int(15 * w / 660)
    for i in range(head_size):
        alpha = int(70 * (1 - i / head_size))
        arrow_draw.line(
            [(arrow_x_end - i, arrow_y - i), (arrow_x_end - i, arrow_y + i)],
            fill=(140, 100, 200, int(alpha)),
        )
    bg = Image.alpha_composite(bg, arrow_layer)

    # Text layer
    text_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    text_draw = ImageDraw.Draw(text_layer)
    font_size = max(12, int(22 * w / 660))
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
    except:
        font = ImageFont.load_default()

    # "Drag to Applications" hint
    text_draw.text(
        (w // 2, int(h * 0.78)),
        "Drag to Applications",
        fill=(100, 70, 160, 100),
        font=font,
        anchor="mm",
    )

    bg = Image.alpha_composite(bg, text_layer)

    bg.convert("RGB").save(filename)
    print(f"  ✅ {filename}: {w}x{h}")


# 1x = exact window size, @2x = retina
generate_bg(660, 400, "assets/dmg-background.png")
generate_bg(1320, 800, "assets/dmg-background@2x.png")
