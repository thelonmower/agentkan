#!/usr/bin/env bash
# setup-agents.sh — one-time setup: initialize git repo and create per-agent worktrees.
# Run this once after editing kanban.json to declare your agents.

set -euo pipefail
cd "$(dirname "$0")"

command -v git >/dev/null || { echo "git is required"; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required"; exit 1; }

# Ensure repo/ is a git repository
if [[ ! -d repo/.git ]]; then
  echo "Initializing repo/ as a git repository..."
  mkdir -p repo
  ( cd repo
    git init -b main
    # need at least one commit so worktrees can branch from it
    if [[ -z "$(git log --oneline 2>/dev/null || true)" ]]; then
      echo "# $(python3 -c "import json; print(json.load(open('../kanban.json'))['project_name'])")" > README.md
      git add README.md
      git -c user.email=agent@local -c user.name="Setup" commit -m "chore: initial commit" >/dev/null
    fi
  )
fi

# Read declared agents and create a worktree+branch for each one
mkdir -p worktrees
python3 -c "
import json
b = json.load(open('kanban.json'))
for name, cfg in b['agents'].items():
    print(name, cfg['branch'], cfg['worktree'])
" | while read -r AGENT BRANCH WORKTREE; do
  if [[ -d "$WORKTREE/.git" || -f "$WORKTREE/.git" ]]; then
    echo "[$AGENT] worktree already exists at $WORKTREE — skipping"
    continue
  fi
  echo "[$AGENT] creating worktree at $WORKTREE on branch $BRANCH"
  ( cd repo && git worktree add "../$WORKTREE" -b "$BRANCH" )
  mkdir -p "logs/$AGENT"
done

echo
echo "All worktrees ready. Inspect with: cd repo && git worktree list"
echo
echo "Next: ./runner.sh <agent-name> for a manual test tick"
