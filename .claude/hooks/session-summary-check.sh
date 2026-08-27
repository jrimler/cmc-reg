#!/bin/bash
# Stop hook: if this session left uncommitted or unpushed changes in cmc-reg,
# ask Claude to update README.md with a summary, commit, and push before
# actually stopping. If the tree is already clean and pushed, do nothing.
cd /Users/jesserimler/Projects/cmc-reg || { echo '{}'; exit 0; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo '{}'; exit 0; }

DIRTY=$(git status --porcelain)
AHEAD=$(git rev-list '@{u}..' --count 2>/dev/null || echo 0)

if [ -n "$DIRTY" ] || [ "$AHEAD" != "0" ]; then
  echo '{"decision":"block","reason":"This session left uncommitted or unpushed changes in cmc-reg. Before stopping: update README.md with a concise summary of what changed this session, commit (including the README update) with a clear message, and push to origin/main."}'
else
  echo '{}'
fi
