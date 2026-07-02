#!/usr/bin/env bash
# tw-compact: PreCompact hook — re-inject tw prime so context survives compaction.

# Skip entirely if user opted out
[[ -n "${TW_SKIP:-}" ]] && exit 0

# In a tw project, re-inject tw prime
config_file=""
dir="$PWD"
while [[ "$dir" != "/" ]]; do
    [[ -f "$dir/.tw.yml" ]] && { config_file="$dir/.tw.yml"; break; }
    [[ -f "$dir/.devenv.yml" ]] && { config_file="$dir/.devenv.yml"; break; }
    dir="$(dirname "$dir")"
done
[[ -z "$config_file" ]] && exit 0

tw prime 2>/dev/null
