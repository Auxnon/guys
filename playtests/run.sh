#!/usr/bin/env bash
# Run a scripted playtest on a hidden Hyprland output.
#
#   playtests/run.sh playtests/smoke.lua [seconds] [shot-frames...]
#
# Copies the game to $OUT/game, adds the test as scripts/zz_test.lua (sorts
# last, so its TEST_HOOK wins), launches it on the GUYTEST headless output and
# has the engine save its own frames at each shot frame (CHOR_SNAP, which works
# even while the session is locked): $OUT/shot-<frame>.png. The engine log
# lands in $OUT/game.log; test prints start with "T". Needs
# `hyprctl output create headless GUYTEST` first (see AGENTS.md in petrichor64).
# Mute the system audio first: the engine opens a real output device.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
test="${1:?test script}"
secs="${2:-12}"
shift 2 || true
shots=("$@")
OUT="${OUT:-${TMPDIR:-/tmp}/guys-test}"
CHOR="${CHOR:-$HOME/petrichor64/target/release/chor}"
WS="${WS:-11}"

rm -rf "$OUT"
mkdir -p "$OUT/game"
cp -r "$here/scripts" "$here/assets" "$OUT/game/"
cp "$here/icon.png" "$OUT/game/" 2>/dev/null || true
cp "$test" "$OUT/game/scripts/zz_test.lua"

at=$(IFS=,; echo "${shots[*]}")
cat > "$OUT/launch.sh" <<EOF
#!/usr/bin/env bash
export CHOR_SNAP="$OUT/shot" CHOR_SNAP_AT="$at"
exec "$CHOR" "$OUT/game" > "$OUT/game.log" 2>&1
EOF
chmod +x "$OUT/launch.sh"

pkill -x chor 2>/dev/null || true
hyprctl eval "hl.exec_cmd(\"[workspace $WS silent] $OUT/launch.sh\")" >/dev/null

sleep "$secs"
pkill -x chor 2>/dev/null || true
sleep 0.3
echo "== errors"
grep -E 'rror|not callable|corrupt|panic|Invalid|attempt' "$OUT/game.log" | sort | uniq -c | sort -rn | head -20 || true
echo "== fps"
grep -E '^fps|fps::' "$OUT/game.log" | tail -2 || true
echo "== test"
grep -E '^> "T"' "$OUT/game.log" | sed 's/^> //; s/"//g' | tail -80 || true
ls "$OUT"/shot-*.png 2>/dev/null || true
