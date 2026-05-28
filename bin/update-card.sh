#!/usr/bin/env bash
# update-card.sh — atomically record a card outcome under the board lock.
#
# This is the ONLY supported way for a runtime agent to write its result back
# to kanban.json. Writing the file directly races with other agents finishing
# at the same time (lost-update bug): two agents read the same snapshot, both
# write, and one completion is silently clobbered. This helper holds
# .board-lock for the whole read-modify-write so concurrent completions are
# serialized — the same guarantee claim.sh gives the claim path.
#
# Usage: pipe a JSON object on stdin:
#
#   echo '{
#     "agent": "business",
#     "card_id": "B001",
#     "outcome": "done",                 // done | blocked | partial
#     "notes": "shipped the .yyp + smoke framework",
#     "branch": "agent/business",
#     "commit": "abc1234",               // optional; appended to notes
#     "blocker": "...",                  // required when outcome=blocked
#     "progress_notes": "...",           // required when outcome=partial
#     "notes_for_human": ["..."],        // optional; appended
#     "proposed_tasks": [{"agent":"...","title":"...","why":"..."}]  // optional; appended
#   }' | ./update-card.sh
#
# Exits non-zero (and writes nothing) on any validation failure.

set -euo pipefail
cd "$(dirname "$0")"

# Read the caller's JSON payload from stdin NOW — before the python heredoc
# below, which would otherwise consume stdin itself (the heredoc IS python's
# stdin). We pass the payload through to python via an env var instead.
PAYLOAD="$(cat)"

# Acquire the board lock for the full read-modify-write.
exec 202>".board-lock"
flock -w 30 202 || { echo "ERROR: could not acquire board lock" >&2; exit 1; }

UPDATE_JSON="$PAYLOAD" python3 - <<'PY'
import json, sys, os, tempfile, datetime

def fail(msg, code=2):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(code)

try:
    upd = json.loads(os.environ["UPDATE_JSON"])
except Exception as e:
    fail(f"payload is not valid JSON: {e}")

agent   = upd.get("agent")
card_id = upd.get("card_id")
outcome = upd.get("outcome")
if not agent or not card_id or outcome not in ("done", "blocked", "partial"):
    fail("must supply agent, card_id, and outcome in (done|blocked|partial)")

path = "kanban.json"
# Read INSIDE the lock so we operate on the latest committed state.
with open(path) as f:
    board = json.load(f)

if agent not in board.get("agents", {}):
    fail(f"agent '{agent}' not declared in kanban.json")

cols = board["columns"]

# Locate the card in in_progress, owned by this agent. This enforces the
# "never touch a card you don't own" rule structurally, not just by prose.
idx = None
for i, c in enumerate(cols["in_progress"]):
    if c.get("id") == card_id:
        if c.get("claimed_by") != agent:
            fail(f"card {card_id} is claimed by '{c.get('claimed_by')}', not '{agent}'")
        idx = i
        break
if idx is None:
    fail(f"card {card_id} not found in in_progress for agent '{agent}' "
         f"(already resolved, or never claimed)")

card = cols["in_progress"][idx]
now = datetime.datetime.now(datetime.timezone.utc).isoformat()

def append_adjuncts():
    # notes_for_human / proposed_tasks live at board top-level and may be
    # appended on any outcome.
    for n in (upd.get("notes_for_human") or []):
        board.setdefault("notes_for_human", []).append(
            {"at": now, "agent": agent, "card": card_id, "note": n})
    for t in (upd.get("proposed_tasks") or []):
        board.setdefault("proposed_tasks", []).append({**t, "proposed_at": now, "by": agent})

if outcome == "done":
    notes = upd.get("notes", "") or ""
    if upd.get("commit"):
        notes = (notes + f" (commit {upd['commit']})").strip()
    card["completed_at"] = now
    card["branch"] = upd.get("branch") or board["agents"][agent].get("branch")
    card["notes"] = notes
    card["claimed_by"] = agent
    card["merged_to_main"] = False          # set true only by `kanban merge`
    cols["in_progress"].pop(idx)
    cols["done"].append(card)

elif outcome == "blocked":
    blocker = upd.get("blocker")
    if not blocker:
        fail("outcome=blocked requires a 'blocker' field")
    card["blocker"] = blocker
    cols["in_progress"].pop(idx)
    cols["blocked"].append(card)
    # surface to the human automatically
    board.setdefault("notes_for_human", []).append(
        {"at": now, "agent": agent, "card": card_id, "note": f"BLOCKED: {blocker}"})

elif outcome == "partial":
    pn = upd.get("progress_notes")
    if not pn:
        fail("outcome=partial requires a 'progress_notes' field")
    card["progress_notes"] = pn
    # stays in in_progress, claimed_by unchanged — next tick resumes it

append_adjuncts()
board["updated_at"] = now

# Atomic write (temp + replace) — torn-write protection on top of the lock.
fd, tmp = tempfile.mkstemp(dir=".", prefix=".kanban.", suffix=".json")
with os.fdopen(fd, "w") as f:
    json.dump(board, f, indent=2)
os.replace(tmp, path)

print(f"OK: {card_id} -> {outcome}")
PY
