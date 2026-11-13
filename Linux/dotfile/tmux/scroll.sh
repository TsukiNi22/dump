#!/bin/sh
# Scroll of the CONTROL mode with Up / Down: a few lines per press, faster the longer the arrow is held
#   usage: scroll.sh up|down <pane_id>
#   The key repeat of a held arrow sends a press every ~30-50 ms: presses closer than 150 ms make a streak, and the
#   longer the streak the more lines per press (1 -> 2 -> 4 -> 8)
set -eu
exec >/dev/null 2>&1 # No output: run-shell would show it in the pane

direction="${1:-up}"
pane="${2:-}"
state="${XDG_RUNTIME_DIR:-/tmp}/tmux-scroll-$(id -u)"

now=$(($(date +%s%N) / 1000000)) # Milliseconds
last=0
streak=0
last_direction=""
if [ -r "$state" ]; then read -r last streak last_direction < "$state" || true; fi

# A new press (or the other direction) starts again at 1 line
if [ $((now - last)) -lt 150 ] && [ "$direction" = "$last_direction" ]; then
    streak=$((streak + 1))
else
    streak=0
fi
echo "$now $streak $direction" > "$state"

if [ "$streak" -lt 6 ]; then lines=1     # Tap / start of a hold: line by line
elif [ "$streak" -lt 16 ]; then lines=2
elif [ "$streak" -lt 30 ]; then lines=4
else lines=8                             # Held for more than ~1 s
fi

if [ "$direction" = "up" ]; then command="scroll-up"; else command="scroll-down"; fi
if [ -n "$pane" ]; then
    tmux send-keys -t "$pane" -X -N "$lines" "$command"
else
    tmux send-keys -X -N "$lines" "$command"
fi
