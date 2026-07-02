---
name: tw-review
description: Multi-perspective PR review for tiddly-winks projects — fan the workspace's reviewer profiles (.tw/reviews/*.md) out to parallel subagents, each posting a tagged review comment. Use when the user asks to review a PR in a tw-managed project (e.g. "/tw-review 42" or "run the reviewers on PR 42").
---

# tw-review — parallel multi-lens PR review

Each `.tw/reviews/*.md` file is a specialized reviewer profile generated for
this workspace (`tw review init`). Run them as parallel subagents against a
PR; each posts its own tagged `gh pr review` comment.

## 1. Resolve inputs

- PR number: from the user's request (required — ask if missing).
- Profiles: list `.tw/reviews/*.md` in the workspace root. If none exist,
  run `tw review init` first (it uses Claude to generate workspace-specific
  profiles) and let the user approve the generated set.
- Repo: from `.tw.yml` `issue_tracker.repo`, else `gh repo view`.

## 2. Dispatch — one subagent per profile, all in parallel

For each profile file:

1. Read its content and substitute `{pr_number}` with the actual PR number
   (also fill `{feature}` / `{repo}` if the profile uses them).
2. Spawn a subagent whose prompt is the substituted profile verbatim, plus:
   - the working directory (workspace root),
   - "Post exactly one review via the gh command in your profile's
     'How to Review' section. Return a one-paragraph summary of your
     findings as your final message."

Launch all reviewer subagents in a single batch so they run concurrently.
Each stays in its lane — the profiles' "What to Ignore" sections prevent
overlap.

## 3. Aggregate

When all reviewers finish:

- Collate their summaries into one digest: blocking issues first, then
  per-reviewer highlights, then anything two reviewers both flagged
  (cross-confirmation = high signal).
- Verify the comments actually landed: `gh pr view <pr> --comments | tail`.
- Report the digest to the user with a link to the PR.

## Notes

- Don't review lanes yourself in parallel with the subagents — your job is
  dispatch and synthesis.
- If a reviewer subagent fails (auth, rate limit), report which lens is
  missing rather than silently shipping a partial review.
