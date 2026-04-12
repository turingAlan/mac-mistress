#!/usr/bin/env python3
"""
Generate Mac Mistress app logos using Google Gemini's image generation.
Uses the gemini-2.0-flash-exp model with image generation capability.
"""

import os
import sys
import base64
import json
import urllib.request
import urllib.error
from pathlib import Path

# Load API key from .env
env_path = Path(__file__).parent / ".env"
api_key = None
if env_path.exists():
    for line in env_path.read_text().splitlines():
        if line.startswith("GEMINI_API_KEY="):
            api_key = line.split("=", 1)[1].strip()
            break

if not api_key:
    print("Error: GEMINI_API_KEY not found in .env")
    sys.exit(1)

output_dir = Path(__file__).parent / "assets"
output_dir.mkdir(exist_ok=True)


def generate_image(prompt: str, filename: str):
    """Generate an image using Gemini API with Imagen."""
    url = f"https://generativelanguage.googleapis.com/v1beta/models/nano-banana-pro-preview:generateContent?key={api_key}"

    payload = {
        "contents": [
            {
                "parts": [
                    {
                        "text": prompt
                    }
                ]
            }
        ],
        "generationConfig": {
            "responseModalities": ["TEXT", "IMAGE"]
        }
    }

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    print(f"Generating: {filename}...")
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            result = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8") if e.fp else ""
        print(f"  HTTP {e.code}: {error_body[:500]}")
        return False

    # Extract image from response
    candidates = result.get("candidates", [])
    for candidate in candidates:
        parts = candidate.get("content", {}).get("parts", [])
        for part in parts:
            if "inlineData" in part:
                mime = part["inlineData"].get("mimeType", "image/png")
                ext = "png" if "png" in mime else "jpg" if "jpeg" in mime else "webp"
                b64 = part["inlineData"]["data"]
                img_bytes = base64.b64decode(b64)
                out_path = output_dir / f"{filename}.{ext}"
                out_path.write_bytes(img_bytes)
                print(f"  Saved: {out_path} ({len(img_bytes)} bytes)")
                return True

    print(f"  No image found in response. Response keys: {list(result.keys())}")
    if candidates:
        parts = candidates[0].get("content", {}).get("parts", [])
        for p in parts:
            if "text" in p:
                print(f"  Text response: {p['text'][:200]}")
    return False


# Logo prompts
prompts = {
    "logo": (
        "Generate a PNG image with a TRANSPARENT background (no background at all, alpha channel). "
        "A stylized liquid water splash forming a circular droplet shape. "
        "Use a gradient of deep purple to electric blue with subtle pink accents. "
        "The liquid should look dynamic and sensual, glossy, 3D feel. "
        "No text. No background. No rounded square. Just the liquid splash element itself "
        "floating on a completely transparent/empty background. "
        "High detail, photorealistic rendering. PNG with transparency."
    ),
    "logo-light": (
        "Generate a PNG image with a TRANSPARENT background (no background at all, alpha channel). "
        "A stylized liquid water splash forming an elegant droplet shape. "
        "Use a gradient of soft lavender to sky blue with white highlights. "
        "The liquid should look elegant and fluid, with a glossy, 3D feel. "
        "No text. No background. No rounded square. Just the liquid splash element itself "
        "floating on a completely transparent/empty background. "
        "High detail, photorealistic rendering. PNG with transparency."
    ),
    "banner": (
        "Create a wide banner image (aspect ratio 3:1) for a GitHub README. "
        "The banner should show the text 'Mac Mistress' in elegant, modern typography "
        "with a liquid splash effect around the letters. Use a gradient background from "
        "deep purple to midnight blue. Include subtle water droplet particles and "
        "a glossy, premium feel. The overall style should be sleek and sensual, "
        "like a premium macOS app marketing banner. High quality, 4K."
    ),
}

print("=" * 50)
print("  Mac Mistress Logo Generator (Gemini)")
print("=" * 50)

success_count = 0
for name, prompt in prompts.items():
    if generate_image(prompt, name):
        success_count += 1
    print()

print(f"Done! Generated {success_count}/{len(prompts)} images in {output_dir}/")
