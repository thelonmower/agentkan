#!/usr/bin/env bash
# runner.sh AGENT — run one tick for the given agent in the current project dir.
# Called either directly (manual test) or via `kanban tick` (cron).

set -euo pipefail

AGENT="${1:?usage: ./runner.sh <agent-name>}"

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

# Global kill switch (hub-level) — stops everything until released.
HUB_DIR="${KANBAN_HUB:-$HOME/.kanban-hub}"
[[ -f "$HUB_DIR/.killswitch" ]] && { echo "$(date -u +%FT%TZ) [$AGENT] kill switch engaged"; exit 0; }

# Skip if the whole project is paused, or just this agent is paused/stopped.
[[ -f .paused ]] && { echo "$(date -u +%FT%TZ) [$AGENT] project paused"; exit 0; }
[[ -f ".paused-$AGENT" ]] && { echo "$(date -u +%FT%TZ) [$AGENT] agent paused"; exit 0; }

# Per-agent lock: prevents overlapping runs of THIS agent on THIS project
LOCK="$PROJECT_DIR/.lock-$AGENT"
exec 200>"$LOCK"
if ! flock -n 200; then
  echo "$(date -u +%FT%TZ) [$AGENT] another run in progress, exiting."
  exit 0
fi

# Record our PID so the dashboard's stop button / kill switch can signal us.
# The server also cleans this up after killing; the trap covers normal exit.
echo $$ > ".run-$AGENT.pid"
trap 'rm -f "$PROJECT_DIR/.run-$AGENT.pid"' EXIT INT TERM

mkdir -p "logs/$AGENT"
LOG="logs/$AGENT/$(date -u +%Y%m%dT%H%M%SZ).log"
exec > >(tee -a "$LOG") 2>&1

echo "=== [$AGENT] run started $(date -u +%FT%TZ) ==="

for bin in claude python3 git flock; do
  command -v "$bin" >/dev/null || { echo "missing: $bin"; exit 1; }
done

# Project must be past intake
STATUS=$(python3 -c "import json; print(json.load(open('kanban.json')).get('status','active'))")
if [[ "$STATUS" == "intake" ]]; then
  echo "[$AGENT] project still in intake — skipping"
  exit 0
fi

# Worktree must exist
WORKTREE=$(python3 -c "import json; print(json.load(open('kanban.json'))['agents']['$AGENT']['worktree'])")
if [[ ! -d "$WORKTREE/.git" && ! -f "$WORKTREE/.git" ]]; then
  echo "[$AGENT] worktree '$WORKTREE' missing — run ./setup-agents.sh"
  exit 1
fi

# Claim a card
CARD_ID=$(./claim.sh "$AGENT")
if [[ -z "$CARD_ID" ]]; then
  echo "[$AGENT] no eligible cards. Exiting."
  REMAINING=$(python3 -c "import json; b=json.load(open('kanban.json')); print(len(b['columns']['todo'])+len(b['columns']['in_progress']))")
  if [[ "$REMAINING" -eq 0 && ! -f .completed_notified ]]; then
    PROJECT=$(python3 -c "import json; print(json.load(open('kanban.json'))['project_name'])")
    ./notify.sh "🎉 $PROJECT — all cards complete"
    touch .completed_notified
  fi
  exit 0
fi
rm -f .completed_notified

echo "[$AGENT] claimed card: $CARD_ID"

PROMPT=$(sed -e "s/{{AGENT}}/$AGENT/g" -e "s/{{CARD_ID}}/$CARD_ID/g" agent-prompt.md)
DONE_BEFORE=$(python3 -c "import json; print(len(json.load(open('kanban.json'))['columns']['done']))")

# Resolve a timeout command. GNU coreutils provides `timeout` on Linux and
# `gtimeout` on macOS (brew install coreutils). macOS ships NEITHER by default,
# so fall back to running without a hard cap rather than failing the whole run.
TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_BIN="gtimeout"
else
  echo "$(date -u +%FT%TZ) [$AGENT] WARN: no 'timeout'/'gtimeout' on PATH — running without the 30m cap. Install it with: brew install coreutils"
fi

CLAUDE_ARGS=(-p "$PROMPT"
  --permission-mode acceptEdits
  --allowedTools "Read,Write,Edit,Bash,Grep,Glob"
  --output-format json)

set +e
if [[ -n "$TIMEOUT_BIN" ]]; then
  "$TIMEOUT_BIN" 30m claude "${CLAUDE_ARGS[@]}" > "logs/$AGENT/last-result.json"
else
  claude "${CLAUDE_ARGS[@]}" > "logs/$AGENT/last-result.json"
fi
RC=$?
set -e

DONE_AFTER=$(python3 -c "import json; print(len(json.load(open('kanban.json'))['columns']['done']))")
if (( DONE_AFTER > DONE_BEFORE )); then
  LAST_TITLE=$(python3 -c "import json; print(json.load(open('kanban.json'))['columns']['done'][-1]['title'])")
  ./notify.sh "✓ [$AGENT] $LAST_TITLE"
fi

if python3 -c "import json; b=json.load(open('kanban.json')); exit(0 if any(c.get('claimed_by')=='$AGENT' for c in b['columns']['blocked']) else 1)" 2>/dev/null; then
  ./notify.sh "⚠ [$AGENT] blocked — see board"
fi

NOTES_COUNT=$(python3 -c "import json; print(len(json.load(open('kanban.json'))['notes_for_human']))")
if [[ "$NOTES_COUNT" -gt 0 ]]; then
  ./notify.sh "⚠ $NOTES_COUNT note(s) for human"
fi

if [[ $RC -ne 0 ]]; then
  echo "[$AGENT] claude exited with code $RC"
  ./notify.sh "[$AGENT] run errored (exit $RC). Check logs/$AGENT/"
fi

echo "=== [$AGENT] run finished $(date -u +%FT%TZ) (exit $RC) ==="
exit 0
