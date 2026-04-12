#!/bin/bash
# Generate themed sound presets for PowerBell using macOS text-to-speech
# All sounds generated locally — no external downloads needed

PRESETS_DIR="$(dirname "$0")/Sources/Resources/Presets"
mkdir -p "$PRESETS_DIR"/{Sexy,ShonenAnime,KawaiiAnime,Fun}

echo "=== Generating Sexy preset (sultry voice) ==="
say -v Samantha -r 120 -o "$PRESETS_DIR/Sexy/charging_start.aiff" "Mmm, power me up"
say -v Samantha -r 110 -o "$PRESETS_DIR/Sexy/full_charge.aiff" "Fully charged, and ready for you"
say -v Samantha -r 100 -o "$PRESETS_DIR/Sexy/low_battery.aiff" "I'm running low, give me some energy"
say -v Samantha -r 120 -o "$PRESETS_DIR/Sexy/lid_open.aiff" "Hello there, handsome"
say -v Samantha -r 110 -o "$PRESETS_DIR/Sexy/lid_close.aiff" "See you soon, darling"
say -v Samantha -r 120 -o "$PRESETS_DIR/Sexy/lock_screen.aiff" "Goodnight, sweetie"
say -v Samantha -r 120 -o "$PRESETS_DIR/Sexy/unlock_screen.aiff" "I missed you"
say -v Samantha -r 100 -o "$PRESETS_DIR/Sexy/startup.aiff" "Hey there, gorgeous. Lets get started"
say -v Samantha -r 110 -o "$PRESETS_DIR/Sexy/shutdown.aiff" "Sweet dreams, beautiful"
say -v Samantha -r 120 -o "$PRESETS_DIR/Sexy/restart.aiff" "Be right back, dont miss me too much"

echo "=== Generating Shonen Anime preset (Japanese epic voice) ==="
say -v "Kyoko" -r 180 -o "$PRESETS_DIR/ShonenAnime/charging_start.aiff" "充電開始！パワーアップ！"
say -v "Kyoko" -r 200 -o "$PRESETS_DIR/ShonenAnime/full_charge.aiff" "フルパワー！最強だ！"
say -v "Kyoko" -r 150 -o "$PRESETS_DIR/ShonenAnime/low_battery.aiff" "エネルギーが足りない！ピンチだ！"
say -v "Kyoko" -r 180 -o "$PRESETS_DIR/ShonenAnime/lid_open.aiff" "目覚めよ！戦いの時だ！"
say -v "Kyoko" -r 160 -o "$PRESETS_DIR/ShonenAnime/lid_close.aiff" "また会おう、仲間よ"
say -v "Kyoko" -r 170 -o "$PRESETS_DIR/ShonenAnime/lock_screen.aiff" "封印！"
say -v "Kyoko" -r 200 -o "$PRESETS_DIR/ShonenAnime/unlock_screen.aiff" "解放！全力で行くぞ！"
say -v "Kyoko" -r 180 -o "$PRESETS_DIR/ShonenAnime/startup.aiff" "起動完了！行くぞ！"
say -v "Kyoko" -r 150 -o "$PRESETS_DIR/ShonenAnime/shutdown.aiff" "撤退する。次の戦いまで"
say -v "Kyoko" -r 180 -o "$PRESETS_DIR/ShonenAnime/restart.aiff" "復活！もう一度だ！"

echo "=== Generating Kawaii Anime preset (cute voice) ==="
say -v "Kyoko" -r 220 -o "$PRESETS_DIR/KawaiiAnime/charging_start.aiff" "わーい！充電だよ！"
say -v "Kyoko" -r 230 -o "$PRESETS_DIR/KawaiiAnime/full_charge.aiff" "やったー！満タンだよ！"
say -v "Kyoko" -r 200 -o "$PRESETS_DIR/KawaiiAnime/low_battery.aiff" "えーん、お腹すいたよ"
say -v "Kyoko" -r 230 -o "$PRESETS_DIR/KawaiiAnime/lid_open.aiff" "おはよう！会いたかった！"
say -v "Kyoko" -r 210 -o "$PRESETS_DIR/KawaiiAnime/lid_close.aiff" "バイバイ！またね！"
say -v "Kyoko" -r 220 -o "$PRESETS_DIR/KawaiiAnime/lock_screen.aiff" "おやすみなさい"
say -v "Kyoko" -r 230 -o "$PRESETS_DIR/KawaiiAnime/unlock_screen.aiff" "わーい！おかえり！"
say -v "Kyoko" -r 230 -o "$PRESETS_DIR/KawaiiAnime/startup.aiff" "はじまるよ！わくわく！"
say -v "Kyoko" -r 200 -o "$PRESETS_DIR/KawaiiAnime/shutdown.aiff" "おやすみ。また明日ね"
say -v "Kyoko" -r 220 -o "$PRESETS_DIR/KawaiiAnime/restart.aiff" "もう一回！もう一回！"

echo "=== Generating Fun preset (quirky voices) ==="
say -v Boing -r 180 -o "$PRESETS_DIR/Fun/charging_start.aiff" "Juice me up!"
say -v Bells -r 150 -o "$PRESETS_DIR/Fun/full_charge.aiff" "Fully juiced and ready to party!"
say -v "Bad News" -r 130 -o "$PRESETS_DIR/Fun/low_battery.aiff" "Im dying here! Plug me in!"
say -v Boing -r 200 -o "$PRESETS_DIR/Fun/lid_open.aiff" "Surprise! I am back!"
say -v Bubbles -r 150 -o "$PRESETS_DIR/Fun/lid_close.aiff" "Going to sleep, blub blub"
say -v Wobble -r 150 -o "$PRESETS_DIR/Fun/lock_screen.aiff" "Locked and loaded... I mean just locked"
say -v Boing -r 200 -o "$PRESETS_DIR/Fun/unlock_screen.aiff" "Ta da! Miss me?"
say -v Cellos -r 130 -o "$PRESETS_DIR/Fun/startup.aiff" "Ladies and gentlemen, the show begins!"
say -v "Bad News" -r 100 -o "$PRESETS_DIR/Fun/shutdown.aiff" "This is the end, my only friend"
say -v Boing -r 200 -o "$PRESETS_DIR/Fun/restart.aiff" "Bouncing back! Boing boing!"

echo "=== All presets generated! ==="
echo ""
echo "Sound files created:"
find "$PRESETS_DIR" -name "*.aiff" | sort | while read f; do
    size=$(stat -f%z "$f" 2>/dev/null || echo "?")
    echo "  $(echo $f | sed "s|.*Presets/||") ($size bytes)"
done
