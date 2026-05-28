#!/usr/bin/env bash
# claim.sh AGENT — atomically claim the next eligible card for AGENT.
# Prints the claimed card ID to stdout, or empty if no work is available.
# Holds .board-lock for the duration of the read-modify-write.

set -euo pipefail
AGENT="${1:?usage: claim.sh <agent-name>}"

cd "$(dirname "$0")"

# Acquire the board lock (blocking, but with a short timeout to avoid deadlock)
exec 201>".board-lock"
flock -w 30 201 || { echo "ERROR: could not acquire board lock" >&2; exit 1; }

# Use python for the read-modify-write — it's clearer and more robust than jq for this
python3 - "$AGENT" <<'PY'
import json, sys, os, tempfile, datetime, uuid

agent = sys.argv[1]
path = "kanban.json"

with open(path) as f:
    board = json.load(f)

# Verify this agent is declared
if agent not in board.get("agents", {}):
    print(f"ERROR: agent '{agent}' not declared in kanban.json under .agents", file=sys.stderr)
    sys.exit(2)

# If this agent already has a card in_progress (e.g. partial progress from a previous run),
# pick that one back up. We resume rather than claim new.
for card in board["columns"]["in_progress"]:
    if card.get("claimed_by") == agent:
        print(card["id"])
        sys.exit(0)

# Build dependency-check structures.
#   done_ids   — cards marked done (on their owning agent's branch)
#   all_cards  — id -> card across every column, to inspect a dep's agent/merge state
done_ids = {c["id"] for c in board["columns"]["done"]}
all_cards = {}
for _col in board["columns"].values():
    for _c in _col:
        all_cards[_c["id"]] = _c

def dep_ok(dep_id):
    # An unknown or not-yet-done dependency is never satisfied.
    if dep_id not in done_ids:
        return False
    dep = all_cards.get(dep_id)
    if dep is None:
        return False
    # Same-agent dependency: the claiming agent shares the branch, so the work
    # is already in its worktree once the upstream card is done.
    if dep.get("agent") == agent:
        return True
    # Cross-agent dependency: the upstream work lives on another agent's branch.
    # It is only present in THIS agent's worktree after a human merges it to
    # main (the agent does `git merge main` at the start of each run). So a
    # cross-agent dep is satisfied only once it is merged_to_main — NOT merely
    # done. Without this gate, a dependent card claims before the code exists.
    return bool(dep.get("merged_to_main"))

# Find first eligible todo card for this agent
chosen = None
for i, card in enumerate(board["columns"]["todo"]):
    if card.get("agent") != agent:
        continue
    deps = card.get("depends_on", []) or []
    if not all(dep_ok(d) for d in deps):
        continue
    chosen = (i, card)
    break

if chosen is None:
    # nothing to do
    sys.exit(0)

idx, card = chosen
# move it to in_progress
card["claimed_by"] = agent
card["started_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
board["columns"]["todo"].pop(idx)
board["columns"]["in_progress"].append(card)
board["updated_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()

# atomic write
fd, tmp = tempfile.mkstemp(dir=".", prefix=".kanban.", suffix=".json")
with os.fdopen(fd, "w") as f:
    json.dump(board, f, indent=2)
os.replace(tmp, path)

print(card["id"])
PY
