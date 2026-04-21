#!/usr/bin/env python3
"""tw-mail-check: build additionalContext JSON from GUPP task + nudge messages.

Called by tw-mail-check.sh with args:
  argv[1] = messages (ephemeral nudge content, may be empty)
  argv[2] = gupp_task (persistent task from hooked file, may be empty)
  argv[3] = hooked_file path
  argv[4] = worker name
  argv[5] = gupp_task_bead (optional)
"""
import json
import re
import sys

messages = sys.argv[1].strip() if len(sys.argv) > 1 else ""
gupp_task = sys.argv[2].strip() if len(sys.argv) > 2 else ""
hooked_file = sys.argv[3] if len(sys.argv) > 3 else ""
worker = sys.argv[4] if len(sys.argv) > 4 else ""
task_bead = sys.argv[5] if len(sys.argv) > 5 and sys.argv[5] else ""

# Read feature name + feature bead id from hooked file. bead_id is used as a
# safety guard so we never render `bd close <feature-bead>` in the completion
# template — that would close the feature prematurely (feature beads are only
# closed via `tw stop --done`).
feature = ""
feature_bead_id = ""
if hooked_file:
    try:
        _hooked = json.load(open(hooked_file))
        feature = _hooked.get("feature", "")
        feature_bead_id = _hooked.get("bead_id", "")
    except Exception:
        pass

parts = []

# GUPP task — persistent, re-injected every turn until worker clears it
if gupp_task:
    # Only render the `bd close` instruction when the task bead is a real
    # task bead — not empty, and not the feature bead. A stale hooked file
    # from before the Bug A fix (or any flow that mis-populates
    # current_task_bead) could otherwise instruct the worker to close the
    # feature itself.
    task_bead_closeable = bool(task_bead) and task_bead != feature_bead_id
    bead_close_block = ""
    if task_bead_closeable:
        bead_close_block = f"""
Then close the task bead:
```bash
bd close {task_bead} --reason "Completed"
python3 -c "import json; f='{hooked_file}'; d=json.load(open(f)); d.pop('current_task_bead',None); json.dump(d,open(f,'w'),indent=2)"
```"""
    signal_step = ""
    if feature and worker:
        signal_step = f"""
First, signal completion to the orchestrator:
```bash
tw signal {feature} {worker} done
```
Then clear the task:"""
    else:
        signal_step = "\nWhen complete, run:"

    parts.append(f"""## CURRENT TASK (persistent — execute this)

**Task:** {gupp_task}

This task persists on every prompt turn until you clear it.{signal_step}
```bash
python3 -c "import json; f='{hooked_file}'; d=json.load(open(f)); d.pop('current_task',None); json.dump(d,open(f,'w'),indent=2)"
```{bead_close_block}""")

# Ephemeral nudge messages
if messages:
    # Scrub well-known secret patterns
    for p in [
        r'(?:sk|pk|ce|rk)_(?:live|test)_[A-Za-z0-9]{10,}',
        r'sk-[A-Za-z0-9_-]{20,}',
        r'AKIA[0-9A-Z]{16}',
        r'gh[pousr]_[A-Za-z0-9_]{16,}',
        r'xox[bpas]-[A-Za-z0-9-]{10,}',
        r'AIza[A-Za-z0-9_-]{30,}',
    ]:
        messages = re.sub(p, '[REDACTED]', messages)
    for p, repl in [
        (r'([Kk][Ee][Yy][\s=:]+)[A-Za-z0-9_-]{20,}', r'\1[REDACTED]'),
        (r'([Tt][Oo][Kk][Ee][Nn][\s=:]+)[A-Za-z0-9_-]{20,}', r'\1[REDACTED]'),
        (r'([Ss][Ee][Cc][Rr][Ee][Tt][\s=:]+)[A-Za-z0-9_-]{20,}', r'\1[REDACTED]'),
        (r'([Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd][\s=:]+)\S{8,}', r'\1[REDACTED]'),
        (r'([Bb]earer\s+)[A-Za-z0-9._-]{20,}', r'\1[REDACTED]'),
        (r'([Aa][Pp][Ii]\s[Kk][Ee][Yy]\s+)[A-Za-z0-9_-]{10,}', r'\1[REDACTED]'),
    ]:
        messages = re.sub(p, repl, messages)
    if worker == 'god':
        parts.append(f'## New messages\n\n{messages}')
    else:
        parts.append(f'## New work dispatched by orchestrator\n\n{messages}')

context = '\n\n'.join(parts)

output = {
    'hookSpecificOutput': {
        'hookEventName': 'UserPromptSubmit',
        'additionalContext': context
    }
}
print(json.dumps(output))
