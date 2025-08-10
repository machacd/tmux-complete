#!/usr/bin/env bash

# tmux-completion plugin - Main completion script
# Provides emacs-style word completion with cycling for tmux

CACHE_DIR="/tmp/tmux-completion"
STATE_FILE="$CACHE_DIR/state"
WORDS_FILE="$CACHE_DIR/words"

# Parse arguments
INCLUDE_SCROLLBACK=false
for arg in "$@"; do
    case $arg in
        --include-scrollback)
            INCLUDE_SCROLLBACK=true
            ;;
    esac
done

mkdir -p "$CACHE_DIR"

pane_id="$(tmux display-message -p '#{pane_id}')"
cursor_x=$(tmux display-message -p -t "$pane_id" '#{cursor_x}')
cursor_y=$(tmux display-message -p -t "$pane_id" '#{cursor_y}')

# Get current line and extract word
current_line=$(tmux capture-pane -t "$pane_id" -p | sed -n "$((cursor_y + 1))p")
before_cursor="${current_line:0:$cursor_x}"
current_word=$(echo "$before_cursor" | grep -oE '[a-zA-Z0-9_/.=-]+$' || echo "")

if [[ -z "$current_word" ]]; then
    exit 0
fi

# Check cycling state
state_info=""
if [[ -f "$STATE_FILE" ]]; then
    state_info=$(cat "$STATE_FILE")
fi

original_word=$(echo "$state_info" | cut -d: -f1)
cycle_index=$(echo "$state_info" | cut -d: -f2)
last_pane=$(echo "$state_info" | cut -d: -f3)
last_completed=$(echo "$state_info" | cut -d: -f4)

# Check if we should reset the cycle or continue
reset_cycle=false

# Reset if different pane
if [[ "$pane_id" != "$last_pane" ]]; then
    reset_cycle=true
# Reset if original word is empty (first time)
elif [[ -z "$original_word" ]]; then
    reset_cycle=true
# Continue cycle if current word matches the last completion exactly
elif [[ "$current_word" == "$last_completed" ]]; then
    reset_cycle=false
# Reset if current word is different from both original word and last completion
else
    reset_cycle=true
fi

# Get all words from all panes
# Use original_word ONLY if continuing cycle, otherwise use current_word
search_word="$current_word"
if [[ "$reset_cycle" == "false" && -n "$original_word" ]]; then
    search_word="$original_word"
fi

# Extract words from all panes - both full paths and individual components
# First get all pane content
if [[ "$INCLUDE_SCROLLBACK" == "true" ]]; then
    # Include scrollback history (much larger word list)
    tmux list-panes -a -F '#{pane_id}' | while read -r pane; do
        tmux capture-pane -t "$pane" -S - -p
    done > "$CACHE_DIR/all_content"
else
    # Only visible content (current approach)
    tmux list-panes -a -F '#{pane_id}' | while read -r pane; do
        tmux capture-pane -t "$pane" -p
    done > "$CACHE_DIR/all_content"
fi

# Extract both full paths and components
grep -oE '[a-zA-Z0-9_/.=-]{2,}' "$CACHE_DIR/all_content" > "$CACHE_DIR/full_words"
grep -oE '[a-zA-Z0-9_/.=-]{2,}' "$CACHE_DIR/all_content" | sed 's/[/.]/\n/g' | grep -E '^[a-zA-Z0-9_=-]{2,}$' > "$CACHE_DIR/components"

# Combine and filter
cat "$CACHE_DIR/full_words" "$CACHE_DIR/components" | grep "^$search_word" | sort -u | grep -v "^$search_word$" > "$WORDS_FILE"

if [[ "$reset_cycle" == "true" ]]; then
    original_word="$current_word"
    cycle_index=0
fi

# Read words
words=()
while IFS= read -r word; do
    words+=("$word")
done < "$WORDS_FILE"

if [[ ${#words[@]} -eq 0 ]]; then
    exit 0
fi

# Get next completion
selected_word="${words[$cycle_index]}"
cycle_index=$(( (cycle_index + 1) % ${#words[@]} ))

# Calculate how many characters to delete
if [[ "$reset_cycle" == "false" && -n "$last_completed" ]]; then
    # When cycling, only delete the suffix that was added by the previous completion
    chars_to_delete=$((${#last_completed} - ${#original_word}))
else
    # Starting new cycle, delete the original partial word
    chars_to_delete=${#current_word}
fi

# Delete current word and type new one
for ((i=0; i<chars_to_delete; i++)); do
    tmux send-keys -t "$pane_id" "C-h"
done

# When cycling, only type the suffix of the new word
# When starting new cycle, type the entire selected word
if [[ "$reset_cycle" == "false" && -n "$original_word" ]]; then
    suffix="${selected_word:${#original_word}}"
    tmux send-keys -t "$pane_id" "$suffix"
else
    tmux send-keys -t "$pane_id" "$selected_word"
fi

# Save state
echo "$original_word:$cycle_index:$pane_id:$selected_word" > "$STATE_FILE"