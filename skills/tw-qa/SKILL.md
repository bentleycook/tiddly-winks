---
name: tw-qa
description: Run a human-in-the-loop QA cycle for a tiddly-winks feature space — verify services, produce a click-through checklist from the diff, watch logs while the user tests, and record outcomes. Use when the user says a feature is ready to QA, asks to test a feature in the browser, or reports a bug while clicking through.
---

# tw-qa — human-in-the-loop QA cycle

The user QAs by clicking through the running app; you prepare the ground,
watch the telemetry, and record what happens.

## 1. Preflight

- `tw status <feature>` — confirm every service is up and note the URLs.
  If a service is down, check its pane in the tmux `services` window
  (`tmux capture-pane -pt '=<session>:services'`) and surface the error.
  Fix proxy/port drift with `tw config` — do not start services by hand.
- `tw gates <feature>` — run quality gates first; QA time is expensive,
  don't spend it on a build that fails typecheck.
- Print the entry point: `http://{project}-{feature}.localhost` (remind:
  Chrome/Firefox only — Safari doesn't resolve `*.localhost`).

## 2. Build the QA checklist

Derive a click-through checklist from what actually changed:

- Diff the feature branch against its base (`git diff <base>...HEAD --stat`
  in each worktree) and read the feature bead (`bd show <bead-id>`) for
  intent and acceptance criteria.
- Write concrete steps a human can follow: URL to open, what to click or
  type, what they should see. Cover the happy path, the edge cases the diff
  touches (empty states, validation, permissions), and one regression check
  per adjacent feature the diff brushes against.
- Present the checklist to the user and tell them to start clicking.

## 3. Watch while they test

While the user clicks through:

- Tail service output for errors:
  `tmux capture-pane -pt '=<session>:services' -S -100`
  (repeat per pane; also tail any log files the services write).
- When the user reports something broken, triage immediately: find the
  matching stack trace/log line, locate the code in the worktree, and state
  a diagnosis. Ask before fixing if the fix is nontrivial — the user may
  want to finish the QA pass first.

## 4. Record the outcome

- Append results to the feature bead:
  `bd comments add <bead-id> "QA <date>: <pass/fail per checklist item, bugs found, fixes applied>"`
- On sign-off: run `tw gates` once more, then offer to prepare the PR.
- On failures: turn each into a concrete fix task (dispatch via tw-dispatch
  if parallelizable), then rerun this cycle.
