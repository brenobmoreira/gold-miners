#!/usr/bin/env bash
#
# Ablation battery runner for the Gold Miners experiment.
#
#   ./experiments/run_battery.sh <timestamp> [reps]
#
# For each config C0..C4 it launches the MAS and waits for a PLATEAU: it stops a
# run once no new gold has been delivered for STALL seconds (or all TARGET pieces
# are collected, or a hard TIMEOUT). This is robust to gold that is effectively
# unreachable/undiscovered within a run -- map 3 has no obstacles, but a far
# corner piece (near 34,34, far from the depot at 0,0) is rarely reached, so runs
# plateau at ~12/13. Requiring 13 would waste the whole timeout every run.
#
# Per-team score is read from the log ("(<team>) I have dropped" prints). A
# screenshot of the frozen scoreboard is captured on rep 1 (it also shows which
# piece, if any, was left on the map). Team B is always naive; Team A adds
# mechanisms C0->C4 (see experiments/*.jcm).

set -u
export DISPLAY="${DISPLAY:-:1}"
cd "$(dirname "$0")/.." || exit 1

TS="${1:?usage: run_battery.sh <timestamp> [reps]}"
REPS="${2:-5}"
TARGET=13                 # total gold on map 3 (only ~12 are practically reachable)
STALL=30                  # stop after this many seconds with no new delivery
TIMEOUT=180               # hard cap per run (seconds)
OUT="experiments/runs/$TS"
mkdir -p "$OUT"
CSV="$OUT/results.csv"
echo "config,rep,teamA,teamB,total,secs,completed" > "$CSV"

pkill -f "JaCaMoLauncher" 2>/dev/null; sleep 2   # clear any leftovers

run_one() {
  local c="$1" rep="$2"
  rm -f log/mas-*.log
  ./gradlew run -Pjcm="experiments/exp_c${c}.jcm" -q >/dev/null 2>&1 &
  local t=0 a=0 b=0 tot=0 last=-1 stall=0 done_flag=0
  while [ "$t" -lt "$TIMEOUT" ]; do
    sleep 5; t=$((t+5))
    if [ -f log/mas-0.log ]; then
      a=$(cat log/mas-*.log 2>/dev/null | grep -c "teamA) I have dropped")
      b=$(cat log/mas-*.log 2>/dev/null | grep -c "teamB) I have dropped")
      tot=$((a+b))
    fi
    # the environment ends the game and logs GAME OVER when all gold is collected
    if grep -qh "GAME OVER" log/mas-*.log 2>/dev/null; then done_flag=1; break; fi
    if [ "$tot" -gt "$last" ]; then last="$tot"; stall=0; else stall=$((stall+5)); fi
    [ "$tot" -ge "$TARGET" ] && break
    [ "$stall" -ge "$STALL" ] && [ "$tot" -gt 0 ] && break
  done
  if [ "$rep" = "1" ]; then
    local wid
    wid=$(xwininfo -root -tree 2>/dev/null | grep -i "Mining World" | grep -o '0x[0-9a-f]*' | head -1)
    [ -n "$wid" ] && import -window "$wid" "$OUT/c${c}.png" 2>/dev/null
  fi
  # kill the MAS reliably: the java child's cmdline does NOT contain the .jcm
  # path, so pkill on the .jcm alone leaves it alive and it keeps writing to
  # the shared log -> inflated counts on the next run. Kill the launcher too.
  pkill -f "exp_c${c}.jcm" 2>/dev/null
  pkill -f "JaCaMoLauncher" 2>/dev/null
  sleep 3
  echo "c${c},${rep},${a},${b},${tot},${t},${done_flag}" >> "$CSV"
  echo "c${c} rep${rep}: A=${a} B=${b} total=${tot} done=${done_flag} in ${t}s"
}

for rep in $(seq 1 "$REPS"); do
  for c in 0 1 2 3 4; do
    run_one "$c" "$rep"
  done
done

echo "=== done -> $CSV ==="
cat "$CSV"
