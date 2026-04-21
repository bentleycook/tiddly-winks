#!/usr/bin/env bash
# tw-prime: SessionStart hook — inject bead context + role + output path for tw workers.
# Requires TW_SESSION, TW_WORKER, and TW_ROLE env vars (set by tw spawn_worker).
# Exits silently (0) if not in a tw worker session.

SESSION_KEY="${TW_SESSION:-}"
WORKER="${TW_WORKER:-}"
ROLE="${TW_ROLE:-}"

[[ -z "$SESSION_KEY" || -z "$WORKER" ]] && exit 0

HOOKED_DIR="$HOME/.tiddly-winks/hooked/${SESSION_KEY}"
HOOKED_FILE="${HOOKED_DIR}/${WORKER}.json"

[[ -f "$HOOKED_FILE" ]] || exit 0

# Parse all fields from hooked JSON in one call
eval "$(python3 -c "
import json, shlex
try:
    d = json.load(open('$HOOKED_FILE'))
    for k in ('bead_id', 'output_file', 'worker_bead_id', 'current_task', 'current_task_bead'):
        print(f'{k}={shlex.quote(d.get(k, \"\"))}')
except Exception:
    pass
" 2>/dev/null)"

# Default output_file derivation if not stored in hooked file
if [[ -z "$output_file" ]]; then
    output_file="$HOME/.tiddly-winks/agents/${SESSION_KEY}/${WORKER}.md"
fi

context=""

# 1. Bead context
if [[ -n "$bead_id" ]]; then
    bead_content=$(bd show "$bead_id" 2>/dev/null || true)
    if [[ -n "$bead_content" ]]; then
        context+="## Feature context (bead ${bead_id})

${bead_content}

"
    fi
fi

# 2. Worker identity (persistent across sessions)
if [[ -n "$worker_bead_id" ]]; then
    identity_content=$(bd show "$worker_bead_id" 2>/dev/null || true)
    if [[ -n "$identity_content" ]]; then
        context+="## Your identity (worker bead ${worker_bead_id})

You have a persistent identity bead that tracks your work history across sessions.
After completing significant work, append a summary to your identity bead:
  bd comments add ${worker_bead_id} \"<what you did, patterns learned, gotchas found>\"

${identity_content}

"
    fi
fi

# 3. Role content
role_file="$HOME/.claude/roles/${ROLE}.md"
if [[ -n "$ROLE" && -f "$role_file" ]]; then
    context+="## Your role

$(cat "$role_file")

"
fi

# 4. Task context — check hooked file first, then fall back to worker bead
# The task bead is the source of truth for task assignments.
if [[ -z "$current_task" && -n "$worker_bead_id" ]]; then
    current_task=$(bd comments "$worker_bead_id" 2>/dev/null \
        | grep -o '\[TASK [^]]*\] .*' | tail -1 \
        | sed 's/^\[TASK [^]]*\] //' || true)
fi

# If we have a task bead, mark it in_progress and use its description
if [[ -n "$current_task_bead" ]]; then
    bd update "$current_task_bead" --status=in_progress 2>/dev/null || true
fi

if [[ -n "$current_task" ]]; then
    # Only render the `bd close` instruction when current_task_bead is a real
    # task bead — not empty, and not the feature bead. (Feature beads should
    # only be closed via `tw stop --done`; a stale current_task_bead pointing
    # at bead_id would otherwise tell the worker to close the whole feature.)
    close_block=""
    if [[ -n "$current_task_bead" && "$current_task_bead" != "$bead_id" ]]; then
        close_block="
Then close the task bead:
\`\`\`bash
bd close ${current_task_bead} --reason \"Completed\"
python3 -c \"import json; f='${HOOKED_FILE}'; d=json.load(open(f)); d.pop('current_task_bead',None); json.dump(d,open(f,'w'),indent=2)\"
\`\`\`"
    fi
    context+="## CURRENT TASK (persistent — execute this)

**Task:** ${current_task}

**What to do:**
If you were previously working on this and your session was restarted, resume where
you left off. If this is new, execute it now. Do not wait for instructions.

When complete, run:
\`\`\`bash
python3 -c \"import json; f='${HOOKED_FILE}'; d=json.load(open(f)); d.pop('current_task',None); json.dump(d,open(f,'w'),indent=2)\"
\`\`\`${close_block}

"
fi

# 5. Output file instruction — emphasize incremental writes
context+="## Output file

Your output file for this session: ${output_file}

IMPORTANT: Write to your output file incrementally — append after each discrete
subtask, not just at the end. The orchestrator polls this file to track your
progress. If you only write at the end, you appear stuck/stalled.

Pattern:
  echo '## <subtask title>' >> ${output_file}
  echo '<what you did, what you found>' >> ${output_file}

Append after: completing a fix, finishing an investigation, finding a bug,
running tests, or reaching any meaningful checkpoint.
"

[[ -z "$context" ]] && exit 0

# Scrub secrets from context before injecting into Claude session
python3 -c "
import json, re, sys

text = sys.argv[1]

# 1. Well-known prefixed keys
for p in [
    r'(?:sk|pk|ce|rk)_(?:live|test)_[A-Za-z0-9]{10,}',
    r'sk-[A-Za-z0-9_-]{20,}',
    r'AKIA[0-9A-Z]{16}',
    r'gh[pousr]_[A-Za-z0-9_]{16,}',
    r'xox[bpas]-[A-Za-z0-9-]{10,}',
    r'AIza[A-Za-z0-9_-]{30,}',
]:
    text = re.sub(p, '[REDACTED]', text)

# 2. Label + separator + secret (keep label, redact value)
for p, repl in [
    (r'([Kk][Ee][Yy][\s=:]+)[A-Za-z0-9_-]{20,}', r'\1[REDACTED]'),
    (r'([Tt][Oo][Kk][Ee][Nn][\s=:]+)[A-Za-z0-9_-]{20,}', r'\1[REDACTED]'),
    (r'([Ss][Ee][Cc][Rr][Ee][Tt][\s=:]+)[A-Za-z0-9_-]{20,}', r'\1[REDACTED]'),
    (r'([Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd][\s=:]+)\S{8,}', r'\1[REDACTED]'),
    (r'([Bb]earer\s+)[A-Za-z0-9._-]{20,}', r'\1[REDACTED]'),
    (r'([Aa][Pp][Ii]\s[Kk][Ee][Yy]\s+)[A-Za-z0-9_-]{10,}', r'\1[REDACTED]'),
]:
    text = re.sub(p, repl, text)

# 3. Env-var style
text = re.sub(
    r'(?m)^([A-Z][A-Z0-9_]*(?:_KEY|_SECRET|_TOKEN|_PASSWORD|_CREDENTIALS)=)[^\s]{8,}',
    r'\1[REDACTED]', text)

output = {
    'hookSpecificOutput': {
        'hookEventName': 'SessionStart',
        'additionalContext': text
    }
}
print(json.dumps(output))
" "$context"

exit 0
