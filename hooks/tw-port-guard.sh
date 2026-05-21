#!/bin/bash
# tw-port-guard.sh — PreToolUse hook for Bash commands
# Blocks kill/fuser commands targeting ports owned by other tw sessions.
#
# Input: JSON on stdin with tool_input.command
# Output: JSON with permissionDecision "deny" if blocked, or exit 0 to allow

set -euo pipefail

# Only active when running inside a tw session
my_session="${TW_SESSION:-}"
sessions_file="$HOME/.tiddly-winks/sessions.json"
[[ ! -f "$sessions_file" ]] && exit 0

# Read tool input
input=$(cat)
command=$(echo "$input" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null) || exit 0

# Quick exit for commands that don't look like port kills
echo "$command" | grep -qE 'kill|fuser' || exit 0

# Extract port numbers from common patterns:
#   kill $(lsof -ti :5180)
#   lsof -ti :5180 | xargs kill
#   fuser -k 5180/tcp
#   kill $(lsof -t -i:5180)
#   lsof -i :5180 -t | xargs kill -9
ports=$(echo "$command" | grep -oE '(:|(-i[ :]?:?))([0-9]{2,5})' | grep -oE '[0-9]{2,5}' || true)
# Also catch fuser patterns: fuser -k 5180/tcp
ports="$ports $(echo "$command" | grep -oE '[0-9]{2,5}/tcp' | grep -oE '[0-9]{2,5}' || true)"
ports=$(echo "$ports" | tr ' ' '\n' | sort -u | grep -E '^[0-9]+$' || true)

[[ -z "$ports" ]] && exit 0  # can't determine port — fail open

# Check each port against sessions.json
for port in $ports; do
    owner=$(python3 -c "
import json, sys
port, sf = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(sf))
except Exception:
    sys.exit(0)
for key, session in data.items():
    for svc, info in session.get('services', {}).items():
        p = info.get('port', '') if isinstance(info, dict) else info
        if str(p) == port:
            print(f'{key}|{svc}')
            sys.exit(0)
" "$port" "$sessions_file" 2>/dev/null) || continue

    [[ -z "$owner" ]] && continue

    owner_session="${owner%%|*}"
    owner_svc="${owner#*|}"

    # If port belongs to a different session, block it
    if [[ "$owner_session" != "$my_session" ]]; then
        python3 -c "
import json, sys
reason = sys.argv[1]
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': reason
    }
}))
" "BLOCKED: Port $port belongs to session '$owner_session' (service: $owner_svc). Use 'tw port-owner $port' to check ownership. Only kill ports owned by your session${my_session:+ ($my_session)}."
        exit 0
    fi
done

# All ports are ours or unmanaged — allow
exit 0
