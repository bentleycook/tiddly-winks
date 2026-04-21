#!/usr/bin/env bash
# tw-mail-check: UserPromptSubmit hook — drain nudge queue + enforce GUPP tasks
# Requires TW_SESSION and TW_WORKER env vars (set by tw spawn_worker)
# Exits silently (0) if not in a tw worker session or nothing to inject.

SESSION_KEY="${TW_SESSION:-}"
WORKER="${TW_WORKER:-}"

[[ -z "$SESSION_KEY" || -z "$WORKER" ]] && exit 0

# ─── 1. Check persistent GUPP task (survives nudge drain, persists until cleared) ───

HOOKED_FILE="$HOME/.tiddly-winks/hooked/${SESSION_KEY}/${WORKER}.json"
gupp_task=""
gupp_task_bead=""
if [[ -f "$HOOKED_FILE" ]]; then
    eval "$(python3 -c "
import json, shlex
try:
    d = json.load(open('$HOOKED_FILE'))
    print(f'gupp_task={shlex.quote(d.get(\"current_task\", \"\"))}')
    print(f'gupp_task_bead={shlex.quote(d.get(\"current_task_bead\", \"\"))}')
except: pass
" 2>/dev/null)"
fi

# ─── 2. Drain ephemeral nudge queue ───────────────────────────────────────────

NUDGE_DIR="$HOME/.tiddly-winks/nudge/${SESSION_KEY}/${WORKER}"
messages=""

if [[ -d "$NUDGE_DIR" ]]; then
    NOW=$(date +%s)

    for msg_file in "$NUDGE_DIR"/*.msg; do
        [[ -f "$msg_file" ]] || continue

        # Filename format: <timestamp>-<ttl_minutes>.msg
        basename=$(basename "$msg_file" .msg)
        ts="${basename%%-*}"
        ttl="${basename##*-}"
        expiry=$((ts + ttl * 60))

        if [[ "$NOW" -gt "$expiry" ]]; then
            rm -f "$msg_file"
            continue
        fi

        content=$(cat "$msg_file")
        messages+="${content}"$'\n'
        rm -f "$msg_file"
    done
fi

# ─── 3. Build context to inject ──────────────────────────────────────────────

# Nothing to inject — exit cleanly
[[ -z "$messages" && -z "$gupp_task" ]] && exit 0

python3 ~/.claude/hooks/tw-mail-check-inject.py "$messages" "$gupp_task" "$HOOKED_FILE" "$WORKER" "$gupp_task_bead"

exit 0
