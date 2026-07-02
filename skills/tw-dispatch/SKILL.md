---
name: tw-dispatch
description: Delegate or parallelize coding work inside a tiddly-winks feature space using native subagents. Use when the user asks to fan out work, run tasks in parallel, or delegate a task while working in a tw-managed project (a .tw.yml is present).
---

# tw-dispatch — parallel work in a tw feature space

tiddly-winks manages the environment (worktrees, services, ports, DB); you
manage the agents. There are no tw worker windows — delegation happens with
your native subagent (Task/Agent) tooling.

## Before dispatching

1. Identify the feature space: `tw status <feature>` (or `tw list` to find it).
   Note the worktree paths, branch, bead ID, and URLs.
2. Read the feature bead for context: `bd show <bead-id>`.

## Dispatch rules

- **Work in the feature's worktrees.** Every subagent prompt must state the
  absolute worktree path to work in (from `tw status`). Never let a subagent
  work in the primary checkout — that's what the worktrees are for.
- **One concern per agent.** Split by workstream (frontend/backend/tests),
  not by file. Two or three well-scoped agents beat six overlapping ones.
- **Include context in the prompt.** Subagents don't inherit your
  conversation. Paste the relevant task description, the branch name, the
  feature URLs, and any constraints from the bead into each prompt.
- **Same worktree = sequential; different worktrees = parallel.** If two
  tasks touch the same service's worktree, run them one after another or
  give the second agent isolated worktree tooling if available.
- **Services stay tw-managed.** Tell subagents to never start dev servers
  (`npm run dev` etc.) — services already run in the tmux `services` window.
  App URLs are `http://{project}-{feature}.localhost` (never `localhost:PORT`).

## After completion

- Verify the result yourself (run quality gates: `tw gates <feature>`).
- Record significant outcomes on the feature bead:
  `bd comments add <bead-id> "<what was done, decisions, gotchas>"`.
- If the work is QA-ready, offer the tw-qa skill flow.
