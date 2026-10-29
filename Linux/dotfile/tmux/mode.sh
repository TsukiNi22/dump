#!/bin/sh
# Global mode of tmux: every pane of the session (its grouped sessions share the same windows) is in the same mode
#   enter: CONTROL on every pane that is not in a full screen program (nvim, less...)
#   leave: back to EDIT on every pane
set -eu
exec >/dev/null 2>&1 # No output: run-shell would show it in the pane (one more mode)
case "${1:-}" in
    enter)
        tmux list-panes -s -F '#{pane_id} #{alternate_on} #{pane_in_mode}' | while read -r id alternate mode; do
            if [ "$alternate" = 0 ] && [ "$mode" = 0 ]; then tmux copy-mode -t "$id"; fi
        done ;;
    leave)
        tmux list-panes -s -F '#{pane_id} #{pane_in_mode}' | while read -r id mode; do
            if [ "$mode" = 1 ]; then tmux send-keys -X -t "$id" cancel; fi
        done ;;
esac
tmux refresh-client -S || true
