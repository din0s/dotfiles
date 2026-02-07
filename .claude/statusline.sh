#!/usr/bin/env bash

# Read JSON input from stdin
input=$(cat)

# Extract values from JSON
dir=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Get short directory name (basename)
short_dir=$(basename "$dir")

# Get git branch if in a git repo (skip optional locks to avoid delays)
git_branch=""
if git -C "$dir" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$dir" -c core.fileMode=false -c core.preloadindex=true --no-optional-locks branch --show-current 2>/dev/null)
  if [ -n "$branch" ]; then
    git_branch=" (${branch})"
  fi
fi

# Format context window usage
context_info=""
if [ -n "$used_pct" ]; then
  # Round to integer
  used_int=$(printf "%.0f" "$used_pct")
  context_info=" | ${used_int}%"
fi

# Build the status line text
status_line=$(printf "%s%s | %s%s" "$short_dir" "$git_branch" "$model" "$context_info")

# If running inside tmux, update the window name for the pane's own window
if [ -n "$TMUX" ] && [ -n "$TMUX_PANE" ]; then
  target_window=$(tmux display-message -t "$TMUX_PANE" -p '#{window_id}' 2>/dev/null)
  if [ -n "$target_window" ]; then
    tmux rename-window -t "$target_window" "$status_line" 2>/dev/null
  fi
fi

# Output the status line (for Claude Code's display)
printf "%s" "$status_line"
