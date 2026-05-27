#!/usr/bin/env bash
# tests/run.sh — full test suite. Exercises syntax, claim race, tick parallelism, server.
# Designed to be run by CI and locally before pushing.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FAILED=0
pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAILED=$((FAILED+1)); }

section() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

# ---------- 1. syntax checks ----------------------------------------------
section "syntax"
python3 -c "import ast; ast.parse(open('kanban').read())" 2>/dev/null \
  && pass "kanban CLI parses" || fail "kanban CLI parse error"
for sh in install.sh bin/*.sh; do
  bash -n "$sh" 2>/dev/null && pass "$sh" || fail "$sh has syntax error"
done

# ---------- 2. install dry-run --------------------------------------------
section "install"
TESTHOME=$(mktemp -d)
export HOME=$TESTHOME
export KANBAN_HUB=$TESTHOME/.kanban-hub
export PATH=$TESTHOME/.local/bin:$PATH

# Stub claude so `kanban new` doesn't try to launch it
mkdir -p $TESTHOME/bin
cat > $TESTHOME/bin/claude <<'EOF'
#!/bin/bash
echo "[stub claude] $*"
exit 0
EOF
chmod +x $TESTHOME/bin/claude
export PATH=$TESTHOME/bin:$PATH

KANBAN_SOURCE="$ROOT" "$ROOT/install.sh" > /dev/null 2>&1 \
  && pass "install completes" || fail "install failed"

[ -x "$TESTHOME/.local/bin/kanban" ] \
  && pass "kanban binary placed" || fail "kanban binary missing"

[ -d "$TESTHOME/.kanban-hub/bin" ] \
  && pass "hub support files copied" || fail "hub support missing"

# ---------- 3. basic CLI commands -----------------------------------------
section "CLI commands"
kanban list > /dev/null 2>&1 && pass "kanban list (empty)" || fail "kanban list"
kanban cron > /dev/null 2>&1 && pass "kanban cron" || fail "kanban cron"

# ---------- 4. project creation -------------------------------------------
section "project lifecycle"
kanban new "Test Project" > /dev/null 2>&1 \
  && pass "kanban new" || fail "kanban new"
PROJ=$TESTHOME/.kanban-hub/projects/test-project
[ -f "$PROJ/INTAKE.md" ] && pass "INTAKE.md written" || fail "INTAKE.md missing"
[ -f "$PROJ/kanban.json" ] && pass "kanban.json scaffolded" || fail "kanban.json missing"
[ -x "$PROJ/runner.sh" ] && pass "runner.sh executable" || fail "runner.sh missing"

# ---------- 5. claim race condition ---------------------------------------
section "claim race"
# Populate the board
python3 <<PY
import json
p = "$PROJ/kanban.json"
b = json.load(open(p))
b["status"] = "active"
b["agents"] = {
  "ui": {"branch":"agent/ui","worktree":"worktrees/ui","role_file":"agents/ui.md","description":""},
  "backend": {"branch":"agent/backend","worktree":"worktrees/backend","role_file":"agents/backend.md","description":""},
}
b["columns"]["todo"] = [
  {"id":"U001","agent":"ui","title":"u","acceptance_criteria":[]},
  {"id":"B001","agent":"backend","title":"b","acceptance_criteria":[]},
]
json.dump(b, open(p,"w"), indent=2)
PY

# 8 concurrent claims (4 per agent)
cd "$PROJ"
for i in 1 2 3 4; do ./claim.sh ui & done > /tmp/claims.log 2>&1
for i in 1 2 3 4; do ./claim.sh backend & done >> /tmp/claims.log 2>&1
wait

# Validate: exactly two cards in_progress, no duplicates
RESULT=$(python3 <<PY
import json
b = json.load(open("kanban.json"))
ids = [c["id"] for c in b["columns"]["in_progress"]]
ok = sorted(ids) == ["B001","U001"]
print("OK" if ok else f"FAIL: in_progress={ids}")
PY
)
[ "$RESULT" = "OK" ] && pass "8 concurrent claims → exactly 2 in_progress" \
                     || fail "race: $RESULT"

cd "$ROOT"

# ---------- 6. tick across multiple projects ------------------------------
section "multi-project tick"
# Reset state
python3 <<PY
import json
p = "$PROJ/kanban.json"
b = json.load(open(p))
b["columns"]["todo"] = b["columns"]["in_progress"] + b["columns"]["todo"]
for c in b["columns"]["todo"]:
    c.pop("claimed_by", None); c.pop("started_at", None)
b["columns"]["in_progress"] = []
json.dump(b, open(p,"w"), indent=2)
PY

# Need worktrees for runner.sh to accept
git config --global user.email t@l > /dev/null
git config --global user.name T > /dev/null
( cd "$PROJ" && ./setup-agents.sh > /dev/null 2>&1 )

kanban tick > /dev/null 2>&1
sleep 1

CLAIMED=$(python3 -c "import json; print(len(json.load(open('$PROJ/kanban.json'))['columns']['in_progress']))")
[ "$CLAIMED" = "2" ] && pass "tick fires both agents in parallel" \
                     || fail "tick: expected 2 in_progress, got $CLAIMED"

# Reap background runners from the tick before the server test
wait 2>/dev/null || true

# ---------- 7. server endpoints ------------------------------------------
section "hub server"
PORT=$((20000 + RANDOM % 5000))
kanban view --port $PORT > /dev/null 2>&1 &
SERVER_PID=$!
# wait for the port to actually accept connections
for i in 1 2 3 4 5 6 7 8 9 10; do
  curl -fsS "http://127.0.0.1:$PORT/" -o /dev/null 2>/dev/null && break
  sleep 0.3
done

curl -fsS "http://127.0.0.1:$PORT/" > /dev/null 2>&1 \
  && pass "GET /" || fail "GET /"
curl -fsS "http://127.0.0.1:$PORT/api/projects" > /dev/null 2>&1 \
  && pass "GET /api/projects" || fail "GET /api/projects"
curl -fsS "http://127.0.0.1:$PORT/api/projects/test-project" > /dev/null 2>&1 \
  && pass "GET /api/projects/<slug>" || fail "GET /api/projects/<slug>"
SLUG_OK=0
for try in 1 2 3; do
  RESP=$(curl -fsS "http://127.0.0.1:$PORT/project/test-project/" 2>&1)
  if echo "$RESP" | grep -q 'const SLUG = "test-project"'; then
    SLUG_OK=1; break
  fi
  sleep 0.3
done
[ "$SLUG_OK" = "1" ] && pass "board.html slug interpolation" || fail "slug interpolation"

kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true

# ---------- summary -------------------------------------------------------
echo
if [ $FAILED -eq 0 ]; then
  printf '\033[1;32mAll tests passed.\033[0m\n'
  exit 0
else
  printf '\033[1;31m%d test(s) failed.\033[0m\n' $FAILED
  exit 1
fi
