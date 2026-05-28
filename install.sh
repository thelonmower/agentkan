#!/usr/bin/env bash
# install.sh — installs agentkan from a local clone or via `curl | sh`.
#
# Usage (local):   ./install.sh
# Usage (remote):  curl -fsSL https://raw.githubusercontent.com/thelonmower/agentkan/main/install.sh | sh
#
# Environment overrides:
#   PREFIX=/usr/local sudo ./install.sh
#   KANBAN_REPO_URL=https://github.com/thelonmower/agentkan  (for remote install)
#   KANBAN_REF=main                                          (branch/tag)

set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"
BINDIR="$PREFIX/bin"
REPO_URL="${KANBAN_REPO_URL:-https://github.com/thelonmower/agentkan}"
REF="${KANBAN_REF:-main}"

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
warn()  { printf '\033[33m⚠ %s\033[0m\n' "$*"; }
die()   { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

bold "Installing agentkan..."

# --- preflight ------------------------------------------------------------
MISSING=()
for cmd in python3 git flock bash; do
  command -v "$cmd" >/dev/null || MISSING+=("$cmd")
done
if [ ${#MISSING[@]} -gt 0 ]; then
  die "missing required commands: ${MISSING[*]}
    macOS:   brew install ${MISSING[*]}
    Debian:  sudo apt install ${MISSING[*]}"
fi
if ! command -v claude >/dev/null; then
  warn "Claude Code CLI ('claude') not found in PATH."
  warn "Install it after this: npm install -g @anthropic-ai/claude-code"
fi
if ! command -v timeout >/dev/null 2>&1 && ! command -v gtimeout >/dev/null 2>&1; then
  warn "no 'timeout'/'gtimeout' on PATH — agent runs will have no 30m safety cap."
  warn "macOS: brew install coreutils  (provides gtimeout)"
fi

# --- find the source: local clone or remote tarball ----------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd 2>/dev/null || pwd)"
if [ -f "$SCRIPT_DIR/kanban" ] && [ -d "$SCRIPT_DIR/bin" ]; then
  SOURCE="$SCRIPT_DIR"
  echo "  source: $SOURCE (local)"
else
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  echo "  source: $REPO_URL @ $REF (downloading)"
  TARBALL_URL="$REPO_URL/archive/refs/heads/$REF.tar.gz"
  curl -fsSL "$TARBALL_URL" | tar -xz -C "$TMP" --strip-components=1
  SOURCE="$TMP"
fi

# --- install --------------------------------------------------------------
mkdir -p "$BINDIR"
cp "$SOURCE/kanban" "$BINDIR/kanban"
chmod 755 "$BINDIR/kanban"

KANBAN_SOURCE="$SOURCE" "$BINDIR/kanban" init >/dev/null

green "✓ installed: $BINDIR/kanban"
green "✓ hub: ~/.kanban-hub"

# --- PATH check -----------------------------------------------------------
case ":$PATH:" in
  *":$BINDIR:"*) ;;
  *)
    echo
    warn "$BINDIR is not on your PATH."
    echo "    Add this to your shell rc (~/.zshrc or ~/.bashrc):"
    echo "        export PATH=\"$BINDIR:\$PATH\""
    ;;
esac

echo
bold "Try it:"
echo "  kanban new \"my first project\""
echo "  kanban list"
echo "  kanban view        # browser dashboard"
echo "  kanban cron        # autonomous schedule"
echo
echo "Docs:  $REPO_URL"
