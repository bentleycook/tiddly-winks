# Agent Instructions

## tiddly-winks Context

This repository is the source for **tiddly-winks** (`tw`), a local feature-space
manager. For current TW workflow context, run:

```bash
tw prime
```

`tw` uses beads internally for feature memory, worker identities, mail, and
TW-managed task dispatch. Generic coding agents should not create, update, or
close `bd` issues unless they are explicitly working inside a TW-managed task
that names a task bead, or the user directly asks for bead maintenance.

Quick reference:

```bash
tw list                          # See active sessions
tw attach <N>                    # Attach by index
tw status <feature>              # Session details
tw start <feature>               # New feature space
tw stop <feature> [--done]       # Stop [and tear down]
```

## Non-Interactive Shell Commands

Always use non-interactive flags with file operations to avoid hanging on
confirmation prompts. Shell commands like `cp`, `mv`, and `rm` may be aliased to
include `-i` on some systems.

Use these forms:

```bash
cp -f source dest
mv -f source dest
rm -f file
rm -rf directory
cp -rf source dest
```

Other commands that may prompt:

- `scp` - use `-o BatchMode=yes`
- `ssh` - use `-o BatchMode=yes`
- `apt-get` - use `-y`
- `brew` - use `HOMEBREW_NO_AUTO_UPDATE=1`
