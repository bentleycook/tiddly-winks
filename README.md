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

- **Git worktrees** for each repo — branch `bentley/<feature>` cut from `staging`
- **Isolated database** — your project's `db_setup` script runs in the worktree
- **Named tmux session** — one window per service, services running from the worktrees
- **Caddy routing** — `http://{project}-{feature}.localhost` live immediately
- **Claude window** — dedicated `claude` tmux window, pre-seeded with context
- **Bead** — persistent memory: branch names, worktree paths, DB, URLs, wrap-up history, PRs

The bead replaces manual `/wrap-up` → paste. Context loss is a non-event:
wrap-up appends to the bead, new Claude reads the bead and picks up exactly where you left off.

---

## Install

### Prerequisites

- macOS
- [Caddy](https://caddyserver.com/docs/install): `brew install caddy`
- tmux: `brew install tmux`
- Python 3 + PyYAML: `pip3 install pyyaml`
- [beads](https://github.com/bentleycook/beads): `bd` CLI on PATH
- `~/.local/bin` in your PATH (add to `~/.zshrc`: `export PATH="$HOME/.local/bin:$PATH"`)

### Clone and install

```bash
git clone git@github.com:bentleycook/tiddly-winks.git ~/Programming/tiddly-winks
cd ~/Programming/tiddly-winks
./install.sh
```

### Install the Caddy daemon (one-time, requires sudo)

Caddy runs as root so it can bind to port 80 and resolve `*.localhost` domains.

```bash
sudo cp ~/.tiddly-winks/com.bentley.tw-caddy.plist /Library/LaunchDaemons/
sudo launchctl load /Library/LaunchDaemons/com.bentley.tw-caddy.plist
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

## Update

`tw` is symlinked to `~/Programming/tiddly-winks/bin/tw`, so a `git pull` updates it immediately — no reinstall needed for code changes.

```bash
git -C ~/Programming/tiddly-winks pull
```

Only re-run `install.sh` if the installer itself has changed (e.g. new runtime directories, plist changes):

```bash
~/Programming/tiddly-winks/install.sh
```

---

## Project config: `.tw.yml`

Place a `.tw.yml` in your workspace root. tiddly-winks walks up from `$PWD` to find it.
Also accepts `.devenv.yml` for backwards compatibility.

```yaml
project: myproject

issue_tracker:
  type: linear       # or: github, none
  team: FAI          # Linear team key (if type: linear)
  # repo: owner/repo # GitHub repo (if type: github)

worktrees:
  base: worktrees              # worktrees/<feature>/<service-name>
  branch_prefix: bentley/      # branches named bentley/<feature>

services:
  frontend:
    path: my-frontend          # path relative to workspace root
    command: "bun run dev -- --port {port}"
    port_hint: 5173
    window: frontend

  backend:
    path: my-backend
    command: "pipenv run python runner.py"
    port_hint: 5001
    env: "PORT={port}"         # injected before starting the service
    window: backend
    db_setup: "./dev/db.sh switch"   # run once after worktree is created

proxy:
  "": frontend        # http://myproject-<feature>.localhost → frontend
  api: backend        # http://myproject-<feature>-api.localhost → backend
```

**Local overrides** (gitignored) — override service paths without committing:

```yaml
# .tw.override.yml
services:
  backend:
    path: ../my-backend-local
```

---

## Day-in-the-life workflow

### Starting a new feature

```bash
cd ~/Programming/my-workspace
tw start my-feature
```

tiddly-winks will:

1. Find `.tw.yml` in the workspace
2. Find or create a Linear/GitHub issue for the feature
3. Find or create a bead titled `my-feature (myproject)`
4. For each service: create a `bentley/my-feature` branch from `origin/staging`, create a worktree at `worktrees/my-feature/<service>/`
5. Run `db_setup` in the backend worktree (e.g. creates an isolated test database)
6. Start all services in a tmux session `myproject-my-feature`
7. Add a `claude` tmux window running `claude` from the workspace root
8. Write all context into the bead body (branch, worktrees, DB, URLs)

Output looks like:

```
  Session:  myproject-my-feature
  Mode:     local
  Branch:   bentley/my-feature
  Bead:     FG-42
  DB:       myproject_test_bentley_my_feature
  Issue:    FAI-456  https://linear.app/...

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

This:
1. Attaches to the tmux session, focused on the `claude` window
2. Prints a context block to paste as your first message:

```
Resume work on my-feature (myproject).
Bead FG-42 has full context — run: bd show FG-42

Worktrees:
  frontend: worktrees/my-feature/frontend
  backend:  worktrees/my-feature/backend

DB: myproject_test_bentley_my_feature
URLs:
  http://myproject-my-feature.localhost
  http://myproject-my-feature-api.localhost
```

Paste that block, then `bd show FG-42` to load full session history. You're back in context.

### Recovering from context loss

When Claude's context fills up mid-session:

1. Run `/wrap-up` in Claude — copy the output
2. In a new terminal:
   ```bash
   tw append my-feature   # paste, then Ctrl-D
   ```
3. Start a new Claude session:
   ```bash
   tw claude my-feature   # paste the printed context block
   ```
4. Claude reads the full history from the bead: `bd show FG-42`

The bead accumulates every session's wrap-up, so no context is ever truly lost.

### Checking status

```bash
tw status my-feature
```

Shows session health, services + ports, worktree paths, DB name, URLs.

```bash
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
- Runs `bd sync`

### After a reboot

tmux sessions don't survive reboots. Clean up stale session records:

```bash
tw prune
```

---

## Reference

```
tw start <feature> [--mode staging]   Create feature space
tw stop <feature> [--done]            Stop (--done: tear down worktrees + close bead)
tw list [--project=X]                 List active sessions
tw status <feature>                   Full status: ports, worktrees, DB, bead
tw open <feature>                     Open primary URL in browser
tw claude <feature>                   Attach to Claude orchestrator window
tw append <feature>                   Append text to bead (reads from stdin)
tw prune                              Remove stale sessions after reboot
tw help                               Show usage
```

---

## Troubleshooting

**Caddy not routing requests:**
```bash
cat ~/.tiddly-winks/Caddyfile          # check routes are present
cat ~/.tiddly-winks/logs/caddy.log     # check for errors
curl -s http://localhost:2019/config/  # check admin API is up
sudo launchctl kickstart -k system/com.bentley.tw-caddy
```

**Port already in use:**
```bash
lsof -i :5173
```

**Stale sessions after reboot:**
```bash
tw prune
```

**Worktree already exists (session was stopped without --done):**
```bash
# tw start will reuse the existing worktree — this is intentional
# To force a clean start:
git -C worktrees/my-feature/backend worktree remove --force   # per repo
```

**Sessions not visible from another workspace:**
```bash
bd sync   # push bead state
# then in the other workspace:
git pull  # or bd sync --pull
```

---

## Architecture

```
~/.tiddly-winks/                     runtime state (not in repo)
  sessions.json                      active sessions: ports, worktrees, bead IDs
  Caddyfile                          auto-generated from sessions.json
  com.bentley.tw-caddy.plist         generated by install.sh
  logs/caddy.log

~/Programming/tiddly-winks/          this repo
  bin/tw                             the CLI (symlinked to ~/.local/bin/tw)
  install.sh                         idempotent installer
  system/caddy.plist.template        template — install.sh fills in paths
  README.md

workspace/
  .tw.yml                            project config (committed)
  .tw.override.yml                   local overrides (gitignored)
  worktrees/
    <feature>/
      <service>/                     git worktree, branch bentley/<feature>
```

**What lives where:**

| Data | Location |
|------|----------|
| Port numbers, URLs, tmux session name | `sessions.json` (ephemeral) |
| Worktree paths, DB name, branch | Both (sessions.json for runtime, bead for history) |
| Work context, wrap-up history, PRs, PM issue | Bead only (persistent, synced across workspaces) |
