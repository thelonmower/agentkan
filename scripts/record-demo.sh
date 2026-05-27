#!/usr/bin/env bash
# scripts/record-demo.sh — produces assets/demo.cast for the README.
#
# What this does:
#   1. Sets up a clean demo environment
#   2. Records a ~60-second asciinema session demonstrating the core flow
#   3. Saves to assets/demo.cast
#
# How to use:
#   1. Install asciinema:  brew install asciinema  /  apt install asciinema
#   2. Install agg (asciinema → gif): cargo install --git https://github.com/asciinema/agg
#   3. Run: ./scripts/record-demo.sh
#   4. Convert to gif: agg assets/demo.cast assets/demo.gif
#   5. Commit assets/demo.gif
#
# You'll narrate the demo by actually typing during recording.
# Aim for ~60s. Audience: a dev seeing the project for the first time.
#
# Suggested beats:
#   - kanban list             (empty — clean slate)
#   - kanban new "todo cli"   (intake interview kicks off in claude)
#   - [skip ahead: 20s of intake]
#   - kanban view             (browser shot)
#   - kanban cron             (the one cron line)
#   - kanban list             (showing it active)
#   - Time-lapse: dashboard with cards moving

set -e
cd "$(dirname "$0")/.."

command -v asciinema >/dev/null || {
  echo "asciinema not installed. brew install asciinema (or apt install asciinema)";
  exit 1;
}

mkdir -p assets
asciinema rec assets/demo.cast \
  --title "agentkan — autonomous Claude Code agents" \
  --cols 100 --rows 32 \
  --idle-time-limit 1.5

echo
echo "Recorded → assets/demo.cast"
echo "Convert to GIF for README:  agg assets/demo.cast assets/demo.gif"
echo
echo "Reminder: the demo GIF is what 80% of visitors will judge the project on."
echo "If it's slow or confusing, re-record. It's worth the time."
