#!/usr/bin/env python3
"""Generate aesthetic DMG background and square icon for Mac Mistress."""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math


def generate_bg(w, h, filename):
    bg = Image.new("RGBA", (w, h))
    draw = ImageDraw.Draw(bg)

    # Dark gradient background
    for y in range(h):
        r = int(15 + (y / h) * 15)
        g = int(10 + (y / h) * 12)
        b = int(30 + (y / h) * 25)
        draw.line([(0, y), (w, y)], fill=(r, g, b, 255))

    # Add subtle purple radial glow in center
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    cx, cy = w // 2, h // 2
    max_r = int(min(w, h) * 0.5)
    for radius in range(max_r, 0, -1):
        alpha = int(25 * (1 - radius / max_r))
        glow_draw.ellipse(
            [cx - radius, cy - radius, cx + radius, cy + radius],
            fill=(120, 80, 200, alpha),
        )
    bg = Image.alpha_composite(bg, glow)

    # Add top accent line
    accent = Image.new("RGBA", (w, 3), (0, 0, 0, 0))
    accent_draw = ImageDraw.Draw(accent)
    for x in range(w):
        t = x / w
        r = int(100 + t * 80)
        g = int(60 + t * 40)
        b = int(200 - t * 40)
        accent_draw.point((x, 0), fill=(r, g, b, 200))
        accent_draw.point((x, 1), fill=(r, g, b, 120))
        accent_draw.point((x, 2), fill=(r, g, b, 40))
    bg.paste(accent, (0, 0), accent)

    # Arrow between icon positions (scale relative to width)
    arrow_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    arrow_draw = ImageDraw.Draw(arrow_layer)
    arrow_y = int(h * 0.45)
    arrow_x_start = int(w * 0.36)
    arrow_x_end = int(w * 0.64)

    for i in range(3):
        arrow_draw.line(
            [(arrow_x_start, arrow_y + i - 1), (arrow_x_end - 15, arrow_y + i - 1)],
            fill=(255, 255, 255, 50),
        )
    for i in range(int(15 * w / 660)):
        alpha = int(50 * (1 - i / (15 * w / 660)))
        arrow_draw.line(
            [(arrow_x_end - i, arrow_y - i), (arrow_x_end - i, arrow_y + i)],
            fill=(255, 255, 255, int(alpha)),
        )
    bg = Image.alpha_composite(bg, arrow_layer)

    # "Drag to Applications" text
    text_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    text_draw = ImageDraw.Draw(text_layer)
    font_size = max(12, int(24 * w / 660))
    label_font_size = max(11, int(13 * w / 660))
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
        label_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", label_font_size)
    except:
        font = ImageFont.load_default()
        label_font = font

    text_draw.text(
        (w // 2, int(h * 0.78)),
        "Drag to Applications",
        fill=(255, 255, 255, 80),
        font=font,
        anchor="mm",
    )

    # Icon labels (positioned below icon centers)
    # App icon at x=165, Applications at x=495 (in 660px space), icons at y=180, label ~60px below icon center
    app_label_x = int(165 * w / 660)
    apps_label_x = int(495 * w / 660)
    label_y = int(250 * h / 400)

    text_draw.text(
        (app_label_x, label_y),
        "Mac Mistress",
        fill=(255, 255, 255, 220),
        font=label_font,
        anchor="mt",
    )
    text_draw.text(
        (apps_label_x, label_y),
        "Applications",
        fill=(255, 255, 255, 220),
        font=label_font,
        anchor="mt",
    )
    bg = Image.alpha_composite(bg, text_layer)

    bg.convert("RGB").save(filename)
    print(f"  ✅ {filename}: {w}x{h}")


# 1x = exact window size, @2x = retina
generate_bg(660, 400, "assets/dmg-background.png")
generate_bg(1320, 800, "assets/dmg-background@2x.png")
