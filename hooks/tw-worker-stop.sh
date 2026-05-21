#!/usr/bin/env bash
# tw-worker-stop: Stop hook — on every worker turn end, nudge the god window
# with a tail of the worker's output file so the orchestrator picks up progress
# without the user having to poll tw feed.
#
# Requires TW_SESSION and TW_WORKER env vars (set by tw spawn_worker).
# Skips god itself, and skips no-op turns where the output file wasn't touched.

SESSION_KEY="${TW_SESSION:-}"
WORKER="${TW_WORKER:-}"

[[ -z "$SESSION_KEY" || -z "$WORKER" ]] && exit 0
[[ "$WORKER" == "god" ]] && exit 0

OUTPUT_FILE="$HOME/.tiddly-winks/agents/${SESSION_KEY}/${WORKER}.md"
[[ -f "$OUTPUT_FILE" ]] || exit 0

STATE_DIR="$HOME/.tiddly-winks/state"
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0
MTIME_FILE="${STATE_DIR}/stop-hook-${SESSION_KEY}-${WORKER}.mtime"

cur_mtime=$(stat -f %m "$OUTPUT_FILE" 2>/dev/null || stat -c %Y "$OUTPUT_FILE" 2>/dev/null || echo 0)
last_mtime=0
[[ -f "$MTIME_FILE" ]] && last_mtime=$(cat "$MTIME_FILE" 2>/dev/null || echo 0)

# No change since last turn → nothing new worth nudging about
if [[ "$cur_mtime" -le "$last_mtime" ]]; then
    exit 0
fi

echo "$cur_mtime" > "$MTIME_FILE"

# Only nudge if god window actually exists in this tmux session
if ! tmux has-session -t "=${SESSION_KEY}" 2>/dev/null; then
    exit 0
fi
if ! tmux list-windows -t "=${SESSION_KEY}" -F '#{window_name}' 2>/dev/null | grep -qx "god"; then
    exit 0
fi

tail_text=$(tail -n 20 "$OUTPUT_FILE" 2>/dev/null)
[[ -z "$tail_text" ]] && exit 0

# Build message and enqueue via the tw CLI (ttl = 5 minutes)
msg="Worker ${WORKER} finished a turn. Tail of ${WORKER}.md:
${tail_text}"

tw nudge enqueue "$SESSION_KEY" "god" "$msg" 5 >/dev/null 2>&1 || true

# Kick god so it submits a new prompt turn and drains the nudge queue
tmux send-keys -t "=${SESSION_KEY}:god" -l "Worker ${WORKER} finished a turn — check nudge queue." 2>/dev/null || true
sleep 0.1
tmux send-keys -t "=${SESSION_KEY}:god" Enter 2>/dev/null || true

exit 0
