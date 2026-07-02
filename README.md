# tiddly-winks

Feature space manager for local dev. Named tmux sessions, dynamic ports, Caddy `*.localhost` routing, git worktrees, isolated databases, and bead-backed context that survives context loss.

---

## The problem it solves

Working on a feature across multiple sessions and repos is messy:

- Services run on ad-hoc ports, manually started each time
- Git worktrees get created in random `/tmp/` directories
- Parallel features share a database and collide
- When Claude's context fills up, you paste a summary into a new session and hope you remembered everything

tiddly-winks handles all of this with one command.

---

## Concept

`tw start <feature>` creates a complete isolated environment:

- **Git worktrees** for each repo — branch `{user}/<feature>` cut from `staging` (or `main`)
- **Isolated database** — your project's `db_setup` script runs in the worktree
- **Named tmux session** — one window per service, services running from the worktrees
- **Caddy routing** — `http://{project}-{feature}.localhost` live immediately
- **Claude window** — dedicated orchestrator tmux window, pre-seeded with context
- **Bead** — persistent memory: branch names, worktree paths, DB, URLs, wrap-up history, PRs

The bead makes context loss a non-event: the tw-wrap-up skill appends a
handoff to the bead, and a new Claude session reads the bead and picks up
exactly where you left off.

Parallel and delegated agent work happens through Claude's native subagents,
steered by tw's skills (tw-dispatch, tw-qa, tw-wrap-up, tw-review) — tw
itself only manages the environment.

---

## Install

### Prerequisites

- macOS (Linux support is planned)
- [Caddy](https://caddyserver.com/docs/install): `brew install caddy`
- tmux: `brew install tmux`
- Python 3 + PyYAML: `pip3 install pyyaml`
- [beads](https://github.com/bentleycook/beads): `bd` CLI on PATH
- `~/.local/bin` in your PATH

### Clone and install

```bash
git clone https://github.com/bentleycook/tiddly-winks.git
cd tiddly-winks
./install.sh
```

The installer:
1. Creates `~/.tiddly-winks/` runtime directory
2. Symlinks `bin/tw` to `~/.local/bin/tw`
3. Initializes `sessions.json` and `Caddyfile`
4. Generates the Caddy LaunchDaemon plist

### Add to PATH

If `~/.local/bin` isn't already in your PATH:

```bash
# Add to ~/.zshrc or ~/.bashrc:
export PATH="$HOME/.local/bin:$PATH"
```

### Install the Caddy daemon (one-time, requires sudo)

Caddy runs as root so it can bind to port 80 and resolve `*.localhost` domains.

```bash
sudo cp ~/.tiddly-winks/com.tw.caddy.plist /Library/LaunchDaemons/
sudo launchctl load /Library/LaunchDaemons/com.tw.caddy.plist
```

Verify it's running:

```bash
curl -s http://localhost:2019/config/
```

### Verify

```bash
tw help
```

---

## First project setup

### Option 1: Auto-generate config with `tw init`

In your project root:

```bash
cd ~/my-project
tw init
```

`tw init` uses Claude to analyze your project structure and generate a `.tw.yml` config file. It detects:
- Frontend/backend service directories
- Package managers and start commands
- Port conventions
- Database setup scripts

Review the generated `.tw.yml` and adjust as needed. Run `tw init --force` to regenerate.

### Option 2: Write `.tw.yml` manually

Place a `.tw.yml` in your workspace root. tiddly-winks walks up from `$PWD` to find it.

```yaml
project: myproject

issue_tracker:
  type: github         # or: linear, none
  repo: owner/repo     # GitHub repo (if type: github)
  # team: FAI          # Linear team key (if type: linear)

worktrees:
  base: worktrees                # worktrees/<feature>/<service-name>
  # branch_prefix: yourname/     # defaults to $(whoami)/

services:
  frontend:
    path: frontend               # path relative to workspace root
    command: "npm run dev -- --port {port}"
    port_hint: 5173
    window: frontend

  backend:
    path: backend
    command: "python manage.py runserver 0.0.0.0:{port}"
    port_hint: 8000
    env: "PORT={port}"
    window: backend
    db_setup: "./scripts/db-setup.sh"

proxy:
  "": frontend          # http://myproject-<feature>.localhost → frontend
  api: backend           # http://myproject-<feature>-api.localhost → backend
```

### Single-repo projects

For projects without separate frontend/backend directories, omit the `worktrees` section:

```yaml
project: myapp

services:
  dev:
    path: .
    command: "npm run dev -- --port {port}"
    port_hint: 3000

proxy:
  "": dev
```

### Local overrides (gitignored)

Override service paths without committing:

```yaml
# .tw.override.yml
services:
  backend:
    path: ../my-backend-local
```

### Set up Claude hooks + skills

Install the tw hooks and skills so Claude gets automatic project context:

```bash
tw setup claude
```

This registers hooks that inject `tw prime` context into Claude sessions
automatically (session start and pre-compaction), and symlinks the tw skills
(tw-dispatch, tw-qa, tw-wrap-up, tw-review) into `~/.claude/skills`.

---

## Day-in-the-life workflow

### Starting a new feature

```bash
cd ~/my-workspace
tw start my-feature
```

tiddly-winks will:

1. Find `.tw.yml` in the workspace
2. Find or create a GitHub/Linear issue for the feature
3. Find or create a bead titled `my-feature (myproject)`
4. For each service: create a feature branch, create a worktree
5. Run `db_setup` in the backend worktree (if configured)
6. Start all services in a tmux session `myproject-my-feature`
7. Add an orchestrator tmux window running Claude
8. Write all context into the bead body (branch, worktrees, DB, URLs)

Output looks like:

```
  Session:  myproject-my-feature
  Mode:     local
  Branch:   alice/my-feature
  Bead:     MP-42
  DB:       myproject_test_alice_my_feature
  Issue:    #12  https://github.com/...

  Worktrees:
    frontend: /path/to/workspace/worktrees/my-feature/frontend
    backend:  /path/to/workspace/worktrees/my-feature/backend

  URLs:
    - frontend: http://myproject-my-feature.localhost
    - backend:  http://myproject-my-feature-api.localhost

  Attach:   tmux attach -t myproject-my-feature
  Claude:   tw claude my-feature
```

### Working with Claude

Use `tw claude` to jump into the feature's Claude window:

```bash
tw claude my-feature
```

This attaches to the tmux session focused on the orchestrator window with a context block for Claude.

### Recovering from context loss

When Claude's context fills up mid-session, ask it to wrap up (the
**tw-wrap-up** skill): it writes a structured handoff — done/in-flight/
decisions/next-steps — to the feature bead. Then:

```bash
tw claude my-feature   # start fresh; paste the printed context block
```

The new session reads the full history from the bead (`bd show MP-42`) and
resumes from the handoff's next steps. Manual fallback: copy a summary and
pipe it through `tw append my-feature`.

### Checking status

```bash
tw status my-feature     # full status: ports, worktrees, DB, URLs, bead
tw list                  # all active sessions
tw list --project=myproject
```

### Opening in browser

```bash
tw open my-feature   # opens http://myproject-my-feature.localhost
```

Chrome and Firefox only — Safari doesn't resolve `*.localhost`.

### Stopping a session

Stop services but keep the bead open (you'll resume later):

```bash
tw stop my-feature
```

Stop and tear everything down (done with the feature):

```bash
tw stop my-feature --done
```

With `--done`:
- Kills the tmux session
- Removes all worktrees (`git worktree remove --force`)
- Closes the bead

### Fixing proxy routes at runtime

If the proxy is pointing at the wrong service (e.g. backend instead of frontend):

```bash
tw config show my-feature                    # see current config
tw config proxy my-feature "" frontend       # fix primary URL → frontend
tw config proxy my-feature api backend       # fix -api subdomain → backend
tw config service my-feature web add 5173    # register a new service
```

Changes take effect immediately — Caddy reloads automatically.

### After a reboot

tmux sessions don't survive reboots. Clean up stale session records:

```bash
tw prune
```

---

## Agent workflows (skills)

tiddly-winks no longer runs its own worker agents. Each feature gets one
orchestrator Claude session (the `god` tmux window); parallel and delegated
work happens through Claude's **native subagents**, steered by four skills
that `tw setup claude` installs into `~/.claude/skills`:

| Skill | What it does |
|-------|--------------|
| **tw-dispatch** | Delegate/parallelize work via subagents pinned to the feature's worktrees — one concern per agent, services stay tw-managed |
| **tw-qa** | Human-in-the-loop QA cycle: preflight services + gates, build a click-through checklist from the diff, watch service logs while you test, record outcomes to the bead |
| **tw-wrap-up** | Write a structured session handoff (done / in-flight / decisions / next steps) to the feature bead |
| **tw-review** | Fan the workspace's reviewer profiles (`.tw/reviews/*.md`) out to parallel subagents; each posts a tagged `gh pr review` comment |

Generate workspace-specific reviewer profiles once per project:

```bash
tw review init          # uses Claude to tailor reviewer lenses to your stack
```

Why native subagents instead of tw-managed workers? Subagent prompts are
delivered in-band (no tmux pane-scraping), completion is reported by the
harness (no idle-detection regexes or patrol daemon), and agents exist only
while working (no idle Claude processes holding memory). The environment —
worktrees, ports, URLs, DBs, beads — is still tw's job.

---

## Reference

### Commands

```
tw init [--force]                     Analyze project and generate .tw.yml
tw start <feature> [--mode staging]   Create feature space (worktrees, DB, services)
tw stop <feature> [--done]            Stop session (--done: tear down + close bead)
tw list [--project=X] [--json]        List active sessions
tw attach [<N>|<name>] [--window=X]   Attach to a session's tmux (defaults to Claude window)
tw status <feature> [--json]          Full status: ports, worktrees, DB, bead
tw open <feature>                     Open primary URL in browser
tw editor <feature>                   Generate .code-workspace and open in VS Code
tw claude <feature>                   Attach to orchestrator window
tw append <feature>                   Append text to bead (reads from stdin)
tw prune                              Remove stale sessions after reboot
tw resume <feature> | --all           Resume feature(s) from bead state after reboot/reset
tw reconcile [<feature>]              Derive state from reality (filesystem, tmux, beads)
tw review init [--force]              Generate PR reviewer profiles for the tw-review skill
tw gates <feature> [--gate=NAME]      Run quality gates
tw config show <feature>              Show runtime services + proxy routes
tw config proxy <feature> <sub> <svc> Remap a proxy route (Caddy reloads)
tw config service <feature> ...       Add/update service ports
tw doctor [--fix]                     Run health checks on tw environment
tw setup claude                       Install Claude hooks + skills
tw prime                              Inject AI workflow context (via hooks)
tw onboard                            Generate AGENTS.md snippet
tw help                               Show usage
```

---

## Configuration reference

### `.tw.yml` fields

| Field | Required | Description |
|-------|----------|-------------|
| `project` | yes | Project name (used in session names, URLs) |
| `issue_tracker.type` | no | `github`, `linear`, or `none` |
| `issue_tracker.repo` | no | GitHub `owner/repo` (for github type) |
| `issue_tracker.team` | no | Linear team key (for linear type) |
| `worktrees.base` | no | Directory for worktrees (default: `worktrees`) |
| `worktrees.branch_prefix` | no | Branch prefix (default: `$(whoami)/`) |
| `services.<name>.path` | yes | Path relative to workspace root |
| `services.<name>.command` | yes | Start command (`{port}` is replaced) |
| `services.<name>.port_hint` | no | Preferred port (auto-allocated if taken) |
| `services.<name>.env` | no | Environment variables (`{port}` is replaced) |
| `services.<name>.window` | no | tmux window name |
| `services.<name>.db_setup` | no | Script to run after worktree creation |
| `proxy.<subdomain>` | no | Map subdomain to service for Caddy routing |
| `reviews.<name>.prompt` | no | Reviewer profile path for the tw-review skill |
| `quality_gates.<name>` | no | Command that must pass before PRs (`tw gates`) |

### Environment variables

| Variable | Description |
|----------|-------------|
| `CADDY_BIN` | Override Caddy binary path |
| `LINEAR_API_KEY` | Linear API key (set in `~/.tiddly-winks/.env`) |

---

## Update

`tw` is symlinked to the repo's `bin/tw`, so a `git pull` updates it immediately — no reinstall needed for code changes.

```bash
cd /path/to/tiddly-winks && git pull
```

Only re-run `install.sh` if the installer itself has changed (e.g. new runtime directories, plist changes).

---

## Troubleshooting

**Caddy not routing requests:**
```bash
cat ~/.tiddly-winks/Caddyfile          # check routes are present
cat ~/.tiddly-winks/logs/caddy.log     # check for errors
curl -s http://localhost:2019/config/  # check admin API is up
sudo launchctl kickstart -k system/com.tw.caddy
```

**Port already in use:**
```bash
lsof -i :5173
```

**Stale sessions after reboot:**
```bash
tw prune
```

**Run diagnostics:**
```bash
tw doctor
```

**Worktree already exists (session was stopped without --done):**
```bash
# tw start will reuse the existing worktree — this is intentional
# To force a clean start:
git worktree remove --force worktrees/my-feature/backend
```

---

## Architecture

```
~/.tiddly-winks/                     runtime state (not in repo)
  sessions.json                      active sessions: ports, worktrees, bead IDs
  Caddyfile                          auto-generated from sessions.json
  com.tw.caddy.plist                 generated by install.sh
  logs/caddy.log

<repo>/
  bin/tw                             the CLI (symlinked to ~/.local/bin/tw)
  hooks/                             Claude hooks (symlinked to ~/.claude/hooks)
  skills/                            Claude skills (symlinked to ~/.claude/skills)
  install.sh                         idempotent installer
  README.md

<workspace>/
  .tw.yml                            project config (committed)
  .tw.override.yml                   local overrides (gitignored)
  .tw/reviews/*.md                   reviewer profiles (tw review init)
  worktrees/
    <feature>/
      <service>/                     git worktree, branch {user}/<feature>
```

**What lives where:**

| Data | Location |
|------|----------|
| Port numbers, URLs, tmux session name | `sessions.json` (ephemeral, rebuilt on start) |
| Worktree paths, DB name, branch | Both (sessions.json for runtime, bead for history) |
| Work context, wrap-up history, PRs, PM issue | Bead only (persistent, synced across machines) |
