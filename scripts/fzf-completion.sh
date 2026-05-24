#!/usr/bin/env bash

# tmux-completion plugin - fzf completion script
# Pick a word from the visible panes using fzf and insert it at the cursor,
# replacing the partial word currently being typed.
#
# Two modes:
#   (default)  setup: capture context + build the word list, then open the popup
#   --popup    run inside the popup: run fzf and send the selection back

CACHE_DIR="/tmp/tmux-completion"
WORDS_FILE="$CACHE_DIR/fzf_words"

# --- Mode: inside the popup -------------------------------------------------
if [[ "$1" == "--popup" ]]; then
    target_pane="$2"
    delete_count="$3"
    query="$4"

    selected_word=$(fzf --reverse --prompt='complete> ' --query="$query" < "$WORDS_FILE")
    [[ -z "$selected_word" ]] && exit 0

    # Delete the partial word, then type the selection literally (-l).
    for ((i=0; i<delete_count; i++)); do
        tmux send-keys -t "$target_pane" "C-h"
    done
    tmux send-keys -t "$target_pane" -l -- "$selected_word"
    exit 0
fi

# --- Mode: setup ------------------------------------------------------------
if ! command -v fzf >/dev/null 2>&1; then
    tmux display-message "tmux-completion: fzf not found in PATH"
    exit 0
fi

mkdir -p "$CACHE_DIR"

pane_id="$(tmux display-message -p '#{pane_id}')"
cursor_x=$(tmux display-message -p -t "$pane_id" '#{cursor_x}')
cursor_y=$(tmux display-message -p -t "$pane_id" '#{cursor_y}')
window_id=$(tmux display-message -p '#{window_id}')

# Pane offset within the terminal, used to place the popup at the cursor
pane_left=$(tmux display-message -p -t "$pane_id" '#{pane_left}')
pane_top=$(tmux display-message -p -t "$pane_id" '#{pane_top}')

# Get current line and extract the partial word before the cursor
current_line=$(tmux capture-pane -t "$pane_id" -p | sed -n "$((cursor_y + 1))p")
before_cursor="${current_line:0:$cursor_x}"
current_word=$(echo "$before_cursor" | grep -oE '[a-zA-Z0-9_/.=-]+$' || echo "")

# Extract words (full tokens + path components, min 2 chars) from a file
extract_words() {
    local content_file="$1"
    grep -oE '[a-zA-Z0-9_/.=-]{2,}' "$content_file"
    grep -oE '[a-zA-Z0-9_/.=-]{2,}' "$content_file" | sed 's/[/.]/\n/g' | grep -E '^[a-zA-Z0-9_=-]{2,}$'
}

# Collect words from panes in priority order (current pane, current window,
# then other windows), keeping the first occurrence of each.
content="$CACHE_DIR/fzf_content"
{
    tmux capture-pane -t "$pane_id" -p > "$content"
    extract_words "$content"

    tmux list-panes -t "$window_id" -F '#{pane_id}' | grep -v "^$pane_id$" | while read -r pane; do
        tmux capture-pane -t "$pane" -p
    done > "$content"
    extract_words "$content"

    tmux list-panes -a -F '#{window_id} #{pane_id}' | grep -v "^$window_id " | cut -d' ' -f2 | while read -r pane; do
        tmux capture-pane -t "$pane" -p
    done > "$content"
    extract_words "$content"
} | awk 'NF && !seen[$0]++' > "$WORDS_FILE"

[[ -s "$WORDS_FILE" ]] || exit 0

# Re-invoke this script inside a tmux popup to run fzf. The selection is sent
# from inside the popup. current_word is restricted to a safe character set,
# so single-quoting it in the command string below is sufficient.
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

# Anchor the popup just below the cursor instead of the screen centre. tmux
# positions a popup by its bottom-left corner and grows it upward, so to make
# it grow downward we put that anchor popup_h rows below the cursor; the top
# edge then lands just under the cursor line. tmux still shifts it back on
# screen if the cursor is too close to the bottom edge for it to fit.
popup_w=50
popup_h=14
popup_x=$(( pane_left + cursor_x ))
popup_y=$(( pane_top + cursor_y + popup_h ))
tmux display-popup -E -w "$popup_w" -h "$popup_h" -x "$popup_x" -y "$popup_y" \
    "\"$SCRIPT_PATH\" --popup '$pane_id' '${#current_word}' '$current_word'"
