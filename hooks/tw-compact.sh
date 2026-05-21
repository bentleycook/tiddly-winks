#!/usr/bin/env bash
# tw-compact: PreCompact hook — re-inject tw prime so context survives compaction.

# For workers, re-inject their specialized context
if [[ -n "${TW_SESSION:-}" && -n "${TW_WORKER:-}" ]]; then
    ~/.claude/hooks/tw-prime.sh 2>/dev/null
    exit 0
fi

# Skip entirely if user opted out
[[ -n "${TW_SKIP:-}" ]] && exit 0

# For non-workers in a tw project, re-inject tw prime
config_file=""
dir="$PWD"
while [[ "$dir" != "/" ]]; do
    [[ -f "$dir/.tw.yml" ]] && { config_file="$dir/.tw.yml"; break; }
    [[ -f "$dir/.devenv.yml" ]] && { config_file="$dir/.devenv.yml"; break; }
    dir="$(dirname "$dir")"
done
[[ -z "$config_file" ]] && exit 0

tw prime 2>/dev/null
echo ''
cat ~/.claude/tw-instructions.md 2>/dev/null
