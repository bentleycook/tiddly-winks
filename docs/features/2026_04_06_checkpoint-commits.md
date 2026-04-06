# Checkpoint Commits — WIP Squash on Completion

**Date:** 2026-04-06
**Project:** tiddly-winks
**Branch:** bentley/checkpoint-commits
**Epic:** tw-5e5
**Issue:** #10 https://github.com/bentleycook/tiddly-winks/issues/10

## Problem

The daemon creates WIP checkpoint commits every 10 minutes to prevent data loss from crashes, but these commits pollute branch history. PRs end up with dozens of "WIP: checkpoint" commits that obscure the real work.

## Solution

Add squash logic that collapses WIP checkpoint commits into a single combined commit, preserving non-WIP commit messages. Called automatically on `tw stop --done` and available manually via `tw checkpoint squash`.

## Implementation Plan

1. **`_checkpoint_squash()` helper** — Port gastown's SquashWIPCommits to bash. Find merge-base, count WIP commits, soft-reset, build combined message, commit.
2. **`tw checkpoint squash <feature>`** — Manual command to squash WIP commits across all feature worktrees.
3. **Hook into `tw stop --done`** — Auto-squash before worktree removal.

## References

- Bead: `tw-5e5`
- Branch: `bentley/checkpoint-commits`
- Workspace URLs: (none — CLI-only project)
- PM Issue: #10
- Inspiration: gastown `internal/checkpoint/squash.go`

## Notes

