#!/usr/bin/env bash
# tw-context: SessionStart hook — inject tw prime for any session in a tw project.
# Skips if already in a tw worker session (tw-prime.sh handles those).

# Skip if this is a worker session (tw-prime.sh handles it)
[[ -n "${TW_SESSION:-}" && -n "${TW_WORKER:-}" ]] && exit 0

# Skip entirely if user opted out
[[ -n "${TW_SKIP:-}" ]] && exit 0

# Check if we are in a tw-managed project
config_file=""
dir="$PWD"
while [[ "$dir" != "/" ]]; do
    [[ -f "$dir/.tw.yml" ]] && { config_file="$dir/.tw.yml"; break; }
    [[ -f "$dir/.devenv.yml" ]] && { config_file="$dir/.devenv.yml"; break; }
    dir="$(dirname "$dir")"
done
[[ -z "$config_file" ]] && exit 0

tw prime 2>/dev/null
