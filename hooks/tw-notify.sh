#!/usr/bin/env bash
# tw-notify: Notification hook — replace generic "waiting for input" with
# project/feature-aware notifications.
#
# Reads TW_SESSION and TW_WORKER env vars (set by tw spawn_worker).
# Falls back to CWD-based detection for non-worker sessions.

# Only handle idle_prompt notifications
# The hook receives JSON on stdin with: message, title, notification_type
INPUT=$(cat)
NTYPE=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('notification_type',''))" 2>/dev/null)
[[ "$NTYPE" != "idle_prompt" ]] && exit 0

# Build a descriptive session label
LABEL=""

if [[ -n "${TW_SESSION:-}" ]]; then
    # Worker session — we know exactly what this is
    LABEL="${TW_SESSION}"
    [[ -n "${TW_WORKER:-}" ]] && LABEL="${LABEL} → ${TW_WORKER}"
else
    # Not a tw worker — try to derive context from CWD
    # Check if we're in a worktree that matches a tw session
    if [[ -f "$PWD/.tw.yml" ]]; then
        PROJECT=$(python3 -c "
import re
text = open('$PWD/.tw.yml').read()
m = re.search(r'^project:\s*(.+)', text, re.M)
print(m.group(1).strip() if m else '')
" 2>/dev/null)
        [[ -n "$PROJECT" ]] && LABEL="$PROJECT"
    fi

    # Check git branch for feature name
    BRANCH=$(git -C "$PWD" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    if [[ -n "$BRANCH" && "$BRANCH" != "main" && "$BRANCH" != "master" ]]; then
        if [[ -n "$LABEL" ]]; then
            LABEL="${LABEL} (${BRANCH})"
        else
            LABEL="$BRANCH"
        fi
    fi
fi

# If we couldn't determine context, let the default notification through
[[ -z "$LABEL" ]] && exit 0

# Build click command: select the right tmux window + focus iTerm
CLICK_CMD="osascript -e 'tell application \"iTerm\" to activate'"
if [[ -n "${TW_SESSION:-}" ]]; then
    if [[ -n "${TW_WORKER:-}" ]]; then
        CLICK_CMD="tmux select-window -t '${TW_SESSION}:${TW_WORKER}'; ${CLICK_CMD}"
    else
        CLICK_CMD="tmux select-window -t '${TW_SESSION}'; ${CLICK_CMD}"
    fi
fi

# Send notification via terminal-notifier (click focuses iTerm + right tmux window)
TN="$(command -v terminal-notifier 2>/dev/null || echo /opt/homebrew/bin/terminal-notifier)"
if [[ -x "$TN" ]]; then
    "$TN" \
        -title "tw" \
        -message "${LABEL} — Claude needs input" \
        -sound Tink \
        -execute "$CLICK_CMD" \
        &>/dev/null &
else
    # Fallback to osascript (clicks will open Script Editor — not ideal)
    osascript -e "display notification \"${LABEL} — Claude needs input\" with title \"tw\" sound name \"Tink\"" 2>/dev/null &
fi

exit 0
