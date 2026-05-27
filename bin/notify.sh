#!/usr/bin/env bash
# notify.sh — cross-platform desktop notification.
# Usage: ./notify.sh "message"

MSG="${1:-Kanban agent update}"
TITLE="Kanban Agent"

if [[ "$OSTYPE" == "darwin"* ]]; then
  osascript -e "display notification \"${MSG//\"/\\\"}\" with title \"$TITLE\" sound name \"Glass\"" 2>/dev/null || true
elif command -v notify-send >/dev/null 2>&1; then
  notify-send "$TITLE" "$MSG"
elif command -v powershell.exe >/dev/null 2>&1; then
  powershell.exe -Command "New-BurntToastNotification -Text '$TITLE','$MSG'" 2>/dev/null || \
    echo "[notify] $MSG"
else
  echo "[notify $(date -u +%FT%TZ)] $MSG"
fi

mkdir -p logs
echo "$(date -u +%FT%TZ)	$MSG" >> logs/notifications.log

# --- optional integrations (uncomment and configure) ---------------------
# Slack:
#   curl -X POST -H 'Content-type: application/json' \
#     --data "{\"text\":\"$TITLE: $MSG\"}" "$SLACK_WEBHOOK_URL"
# ntfy.sh:
#   curl -d "$MSG" "https://ntfy.sh/your-private-topic-name"
# Email:
#   echo "$MSG" | mail -s "$TITLE" you@example.com
