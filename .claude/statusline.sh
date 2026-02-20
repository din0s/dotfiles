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
    git_branch="${branch}"
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
if [ -n "$git_branch" ]; then
  status_line=$(printf "%s | %s%s" "$git_branch" "$model" "$context_info")
else
  status_line=$(printf "%s%s" "$model" "$context_info")
fi

# Mark this pane as a Claude Code pane (for tmux hook)
if [ -n "$TMUX" ] && [ -n "$TMUX_PANE" ]; then
  tmux set -p -t "$TMUX_PANE" @claude_dir "$short_dir" 2>/dev/null
fi

# Output the status line (for Claude Code's display)
printf "%s" "$status_line"
