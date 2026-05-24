#!/usr/bin/env bash

# tmux-completion plugin main script

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Default key bindings
completion_key=$(tmux show-option -gqv "@completion_key")
completion_scrollback_key=$(tmux show-option -gqv "@completion_scrollback_key")
completion_fzf_key=$(tmux show-option -gqv "@completion_fzf_key")

# Set defaults if not configured
completion_key=${completion_key:-"/"}
completion_scrollback_key=${completion_scrollback_key:-"?"}
completion_fzf_key=${completion_fzf_key:-"F"}

# Set up key bindings
tmux bind-key "$completion_key" run-shell "$CURRENT_DIR/scripts/completion.sh"
tmux bind-key "$completion_scrollback_key" run-shell "$CURRENT_DIR/scripts/completion.sh --include-scrollback"
tmux bind-key "$completion_fzf_key" run-shell -b "$CURRENT_DIR/scripts/fzf-completion.sh"