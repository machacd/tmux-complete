#!/usr/bin/env bash

# Verify tmux-completion plugin installation

echo "=== tmux-completion Plugin Installation Verification ==="
echo

# Check tmux version
if command -v tmux >/dev/null 2>&1; then
    echo "✓ tmux found: $(tmux -V)"
else
    echo "✗ tmux not found"
    exit 1
fi

# Check if plugin is loaded
if tmux list-keys 2>/dev/null | grep -q "completion.sh"; then
    echo "✓ Plugin key bindings loaded"
    
    # Show key bindings
    echo
    echo "Active key bindings:"
    tmux list-keys | grep "completion.sh" | sed 's/^/  /'
else
    echo "✗ Plugin not loaded"
    echo "  Run: tmux source-file ~/.tmux.conf"
    exit 1
fi

# Test basic functionality
echo
echo "Testing basic functionality..."
if [ -x "./scripts/completion.sh" ]; then
    echo "✓ Completion script is executable"
else
    echo "✗ Completion script not found or not executable"
    exit 1
fi

echo
echo "=== Installation verified successfully! ==="
echo
echo "Usage:"
echo "  prefix + /     - Complete word (visible content)"
echo "  prefix + ?     - Complete word (scrollback history)"  
echo "  Alt + /        - Complete word (no prefix needed)"
echo
echo "Try typing a partial word and pressing the completion key!"