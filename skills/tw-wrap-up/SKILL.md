---
name: tw-wrap-up
description: Save session context to a tiddly-winks feature bead so a fresh Claude session can resume exactly where this one left off. Use when the user says wrap up, hand off, or pass, when context is getting large, or before ending work on a tw-managed feature.
---

# tw-wrap-up — persist context to the feature bead

The feature bead is the durable memory that outlives this session. Write a
handoff that lets a successor (or future you) resume without re-deriving
anything.

## 1. Gather state

- Feature + bead: `tw status <feature>` (bead ID, branch, worktrees, URLs).
- Git state per worktree: current branch, uncommitted changes
  (`git status --short`), unpushed commits (`git log @{u}..` if upstream).
- Open PRs and their review state (`gh pr status` in the worktree).

## 2. Write the handoff

Compose a block with these sections (skip empty ones):

```
## Session handoff <YYYY-MM-DD HH:MM>

### Done
- <completed work, merged/pushed state>

### In flight
- <started but unfinished, exact file/function where you stopped>

### Decisions
- <choices made and WHY — the successor must not relitigate these>

### Gotchas
- <traps discovered: flaky tests, misleading names, env quirks>

### Next steps
- <ordered, concrete, first step actionable immediately>
```

## 3. Persist it

Append to the bead (either works):

- `bd comments add <bead-id> "<handoff block>"`, or
- pipe through `tw append <feature>` (reads stdin).

Commit or stash any uncommitted work first if the user is done for the day —
a handoff that points at dirty uncommitted state is fragile.

## 4. Resuming (successor session)

A new session recovers with: `bd show <bead-id>` (auto-injected by tw hooks
when starting Claude in the project), then follows "Next steps". `tw claude
<feature>` prints a ready-made context block for the first message.
