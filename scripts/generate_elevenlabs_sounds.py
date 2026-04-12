#!/usr/bin/env python3
"""
Generate PowerBell sound presets using ElevenLabs v3 API.
Uses expression-rich prompts in English, Hindi, and Japanese.
"""

import os
import sys
import json
import time
import urllib.request
import urllib.error
from pathlib import Path

# Load API key from .env
ENV_PATH = Path(__file__).parent / ".env"
API_KEY = None
if ENV_PATH.exists():
    for line in ENV_PATH.read_text().splitlines():
        if line.startswith("ELEVEN_LAB_API_KEY="):
            API_KEY = line.split("=", 1)[1].strip()
            break

if not API_KEY:
    print("ERROR: ELEVEN_LAB_API_KEY not found in .env")
    sys.exit(1)

MODEL_ID = "eleven_v3"
BASE_URL = "https://api.elevenlabs.io/v1/text-to-speech"
PRESETS_DIR = Path(__file__).parent / "Sources" / "Resources" / "Presets"

# Voice IDs — best match per preset character
VOICES = {
    "sexy":    "pFZP5JQG7iQjIQuC4Bku",  # Lily - Velvety Actress (British female)
    "sensual": "EXAVITQu4vr4xnSDxMaL",  # Sarah - Mature, Reassuring, Confident
    "shonen":  "SOYHLrjzK2X1ezoPC6cr",  # Harry - Fierce Warrior
    "kawaii":  "cgSgspJ2msm6clMCkdW9",  # Jessica - Playful, Bright, Warm
    "fun":     "FGY2WhTYpPnrIDTdsKH5",  # Laura - Enthusiast, Quirky Attitude
}

# =============================================================================
# PRESET DEFINITIONS — expressive text with emotion cues for v3
# Each event has text in the language that fits best for that preset
# =============================================================================

PRESETS = {
    "Sexy": {
        "voice": VOICES["sexy"],
        "sounds": {
            "charging_start":  {"text": "*whispers seductively* Mmm... plug me in, baby. I like that.", "lang": "en"},
            "discharging":     {"text": "*sighs softly* Oh no... you're pulling out? I was just getting started.", "lang": "en"},
            "full_charge":     {"text": "*moans softly with satisfaction* Mmm... fully charged and ready for you, darling.", "lang": "en"},
            "low_battery":     {"text": "*breathes heavily, weakly* I'm running low... give me some of your... energy.", "lang": "en"},
            "lid_open":        {"text": "*gasps with delight* Oh! Hello there, handsome. I've been waiting.", "lang": "en"},
            "lid_close":       {"text": "*whispers intimately* Goodnight, lover. Dream of me.", "lang": "en"},
            "lock_screen":     {"text": "*purrs* Shh... I'll keep your secrets safe. Sweet dreams.", "lang": "en"},
            "unlock_screen":   {"text": "*excited whisper* Mmm, I missed you! Come closer.", "lang": "en"},
            "startup":         {"text": "*slow seductive breath* Hey there, gorgeous... let's have some fun together.", "lang": "en"},
            "shutdown":        {"text": "*soft kiss sound, whispers* Until next time, beautiful.", "lang": "en"},
            "restart":         {"text": "*giggles flirtatiously* Be right back... don't you dare miss me too much.", "lang": "en"},
        }
    },

    "Sensual": {
        "voice": VOICES["sensual"],
        "sounds": {
            "charging_start":  {"text": "*soft moan* Mmm... that feels so good. Keep that energy flowing.", "lang": "en"},
            "discharging":     {"text": "*disappointed sigh* Oh... the connection is lost. I feel so empty now.", "lang": "en"},
            "full_charge":     {"text": "*satisfied exhale* Aah... completely full. I feel so... alive.", "lang": "en"},
            "low_battery":     {"text": "*weak, breathy voice* I need you... please... I'm fading.", "lang": "en"},
            "lid_open":        {"text": "*soft gasp of awakening* Mmm... good morning, love. Your face is the first thing I want to see.", "lang": "en"},
            "lid_close":       {"text": "*intimate whisper* Close your eyes with me... let's rest together.", "lang": "en"},
            "lock_screen":     {"text": "*gentle, warm tone* I'll be right here... dreaming of your touch.", "lang": "en"},
            "unlock_screen":   {"text": "*delighted, warm* There you are... I've been counting every second.", "lang": "en"},
            "startup":         {"text": "*slow, intimate breath* Hello, darling... the night is young and I'm all yours.", "lang": "en"},
            "shutdown":        {"text": "*soft, tender whisper* Goodnight my love... *kisses* ...until we meet again.", "lang": "en"},
            "restart":         {"text": "*playful, breathy* One moment, sweetie... I'll be right back in your arms.", "lang": "en"},
        }
    },

    "ShonenAnime": {
        "voice": VOICES["shonen"],
        "sounds": {
            "charging_start":  {"text": "充電開始！パワーがみなぎってくるぞ！うおおお！", "lang": "ja"},
            "discharging":     {"text": "くそっ！エネルギー供給が断たれた！バッテリーモードで戦うしかない！", "lang": "ja"},
            "full_charge":     {"text": "フルパワーだ！この力...最強だ！誰にも負けないぞ！", "lang": "ja"},
            "low_battery":     {"text": "まずい...エネルギーが残りわずかだ...このままじゃ...！", "lang": "ja"},
            "lid_open":        {"text": "目覚めよ！新たな戦いの幕が上がる！行くぞ！", "lang": "ja"},
            "lid_close":       {"text": "今日の戦いは終わりだ...また会おう、仲間よ。", "lang": "ja"},
            "lock_screen":     {"text": "封印！この力、解き放つ時まで眠れ！", "lang": "ja"},
            "unlock_screen":   {"text": "封印解放！全力で行くぞ！うおおおお！", "lang": "ja"},
            "startup":         {"text": "起動完了！俺の名はパワーベル！さあ、冒険の始まりだ！", "lang": "ja"},
            "shutdown":        {"text": "撤退する...だが覚えておけ、俺は必ず戻ってくる！", "lang": "ja"},
            "restart":         {"text": "復活だ！何度でも立ち上がる、それが俺の忍道だ！", "lang": "ja"},
        }
    },

    "KawaiiAnime": {
        "voice": VOICES["kawaii"],
        "sounds": {
            "charging_start":  {"text": "わーい！充電だよ！エネルギーもらえて嬉しいな！えへへ！", "lang": "ja"},
            "discharging":     {"text": "えーん！充電ケーブル抜かないでよぉ...寂しいよぉ...", "lang": "ja"},
            "full_charge":     {"text": "やったー！満タンだよ！元気いっぱい！キラキラ！", "lang": "ja"},
            "low_battery":     {"text": "ふぇぇ...お腹すいたよぉ...充電してほしいなぁ...", "lang": "ja"},
            "lid_open":        {"text": "おはよう！会いたかったよ！今日も一緒に頑張ろうね！", "lang": "ja"},
            "lid_close":       {"text": "バイバイ！またね！大好きだよ！", "lang": "ja"},
            "lock_screen":     {"text": "おやすみなさい...いい夢見てね...むにゃ...", "lang": "ja"},
            "unlock_screen":   {"text": "わーい！おかえり！寂しかったんだから！もー！", "lang": "ja"},
            "startup":         {"text": "はじまるよ！わくわく！今日も楽しいことがいっぱいだね！", "lang": "ja"},
            "shutdown":        {"text": "おやすみ...また明日ね...すぅすぅ...", "lang": "ja"},
            "restart":         {"text": "もう一回！もう一回！えへへ、何度でも頑張るよ！", "lang": "ja"},
        }
    },

    "Fun": {
        "voice": VOICES["fun"],
        "sounds": {
            "charging_start":  {"text": "*zapping electricity sounds* JUICE ME UP, BABY! Bzzzzt! Oh yeah, that's the good stuff!", "lang": "en"},
            "discharging":     {"text": "*dramatic gasp* NOOO! Unplugged! We're going off the grid, people! This is NOT a drill!", "lang": "en"},
            "full_charge":     {"text": "*triumphant fanfare voice* FULLY JUICED AND READY TO PARTY! Let's gooooo!", "lang": "en"},
            "low_battery":     {"text": "*dramatically dying* I'm... dying... here! Tell my files... I loved them... *cough* ...plug me in!", "lang": "en"},
            "lid_open":        {"text": "*surprise party voice* SURPRISE! I'M BAAACK! Did you miss me? Of course you did!", "lang": "en"},
            "lid_close":       {"text": "*yawning dramatically* Going to sleep now... blub blub blub... *snoring*", "lang": "en"},
            "lock_screen":     {"text": "*spy movie voice* Locked. And loaded. Well... just locked actually. Shh, top secret stuff happening.", "lang": "en"},
            "unlock_screen":   {"text": "*magician voice* TA-DA! Miss me? I was doing absolutely nothing in there!", "lang": "en"},
            "startup":         {"text": "*announcer voice* LADIES AND GENTLEMEN! THE SHOW... HAS... BEGUN! *crowd cheering*", "lang": "en"},
            "shutdown":        {"text": "*overly dramatic soap opera* This... is the end... my only friend... the end. *sob*", "lang": "en"},
            "restart":         {"text": "*bouncy voice* BOUNCING BACK! Boing boing boing! You can't keep me down!", "lang": "en"},
        }
    },
}

# Hindi versions for Sensual preset (bonus sounds in Hindi)
HINDI_SENSUAL = {
    "voice": VOICES["sensual"],
    "sounds": {
        "charging_start":  {"text": "*कोमल आह* म्म्म... कितना अच्छा लग रहा है... ऊर्जा बहती रहे।", "lang": "hi"},
        "discharging":     {"text": "*निराशा भरी सांस* ओह... कनेक्शन टूट गया... मुझे तुम्हारी ज़रूरत है।", "lang": "hi"},
        "full_charge":     {"text": "*संतुष्ट साँस* आह... पूरी तरह भर गई... कितना अच्छा लगता है।", "lang": "hi"},
        "low_battery":     {"text": "*कमज़ोर आवाज़ में* मुझे तुम्हारी ज़रूरत है... प्लीज़... मैं कमज़ोर हो रही हूँ।", "lang": "hi"},
        "lid_open":        {"text": "*खुशी से* म्म्म... सुप्रभात, जानू। तुम्हारा चेहरा देखकर दिल खुश हो गया।", "lang": "hi"},
        "lid_close":       {"text": "*धीमी फुसफुसाहट* आँखें बंद करो मेरे साथ... आराम करो।", "lang": "hi"},
        "lock_screen":     {"text": "*नरम आवाज़* मैं यहीं हूँ... तुम्हारे सपनों में।", "lang": "hi"},
        "unlock_screen":   {"text": "*खुशी से* तुम आ गए! मैं हर पल गिन रही थी।", "lang": "hi"},
        "startup":         {"text": "*धीमी, गहरी साँस* नमस्ते जानू... रात जवान है और मैं सिर्फ़ तुम्हारी हूँ।", "lang": "hi"},
        "shutdown":        {"text": "*कोमल फुसफुसाहट* शुभ रात्रि, मेरे प्यार... फिर मिलेंगे।", "lang": "hi"},
        "restart":         {"text": "*खिलंदड़ी आवाज़* एक पल रुको, जानू... मैं अभी वापस आती हूँ तुम्हारी बाहों में।", "lang": "hi"},
    }
}


def generate_sound(voice_id: str, text: str, lang: str, output_path: Path):
    """Call ElevenLabs v3 TTS and save as mp3."""
    url = f"{BASE_URL}/{voice_id}?output_format=mp3_44100_128"

    # Map short lang codes to ISO 639-3 for v3
    lang_map = {"en": "en", "ja": "ja", "hi": "hi"}
    language_code = lang_map.get(lang, lang)

    payload = json.dumps({
        "text": text,
        "model_id": MODEL_ID,
        "language_code": language_code,
        "voice_settings": {
            "stability": 0.3,         # Lower = more expressive/variable
            "similarity_boost": 0.75,  # Keep voice identity
            "style": 0.8,             # High style for expressiveness
            "use_speaker_boost": True,
        },
        "apply_text_normalization": "auto",
    }).encode("utf-8")

    headers = {
        "xi-api-key": API_KEY,
        "Content-Type": "application/json",
        "Accept": "audio/mpeg",
    }

    req = urllib.request.Request(url, data=payload, headers=headers, method="POST")

    try:
        with urllib.request.urlopen(req) as resp:
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_bytes(resp.read())
            size_kb = output_path.stat().st_size / 1024
            print(f"  ✓ {output_path.name} ({size_kb:.1f} KB)")
            return True
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print(f"  ✗ {output_path.name} — HTTP {e.code}: {body[:200]}")
        return False


def generate_preset(name: str, config: dict):
    """Generate all sounds for a preset."""
    print(f"\n{'='*60}")
    print(f"  Generating: {name}")
    print(f"{'='*60}")

    voice_id = config["voice"]
    preset_dir = PRESETS_DIR / name
    preset_dir.mkdir(parents=True, exist_ok=True)

    success = 0
    total = len(config["sounds"])

    for filename, snd in config["sounds"].items():
        output = preset_dir / f"{filename}.mp3"
        if generate_sound(voice_id, snd["text"], snd["lang"], output):
            success += 1
        # Small delay to avoid rate limiting
        time.sleep(0.5)

    print(f"\n  Result: {success}/{total} sounds generated for {name}")
    return success


def main():
    print("╔══════════════════════════════════════════════════════════╗")
    print("║     PowerBell Sound Generator — ElevenLabs v3          ║")
    print("╚══════════════════════════════════════════════════════════╝")
    print(f"  Model: {MODEL_ID}")
    print(f"  Output: {PRESETS_DIR}")

    total_success = 0
    total_sounds = 0

    for name, config in PRESETS.items():
        count = generate_preset(name, config)
        total_success += count
        total_sounds += len(config["sounds"])

    # Generate Hindi Sensual as a separate sub-preset
    print(f"\n{'='*60}")
    print(f"  Generating: SensualHindi")
    print(f"{'='*60}")
    hindi_dir = PRESETS_DIR / "SensualHindi"
    hindi_dir.mkdir(parents=True, exist_ok=True)
    for filename, snd in HINDI_SENSUAL["sounds"].items():
        output = hindi_dir / f"{filename}.mp3"
        if generate_sound(HINDI_SENSUAL["voice"], snd["text"], snd["lang"], output):
            total_success += 1
        total_sounds += 1
        time.sleep(0.5)

    print(f"\n{'='*60}")
    print(f"  DONE: {total_success}/{total_sounds} total sounds generated")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
